#!/usr/bin/env python3
"""JSONC-aware, comment-preserving merge of a managed block into VS Code
user files (settings.json / keybindings.json).

The tool never rewrites the user's file wholesale. It inserts (or replaces)
a single block delimited by marker comments right before the closing
bracket of the top-level object/array. Everything outside the markers is
kept byte-for-byte, except a single comma that may be added after the last
existing entry.

Sub-commands
  merge   --kind settings|keybindings --target FILE --source FILE
          [--subst NAME=VALUE ...] [--backup-dir DIR] [--dry-run]
  remove  --kind settings|keybindings --target FILE [--backup-dir DIR]
  check   --kind settings|keybindings --target FILE --source FILE [--subst ...]
  validate FILE [FILE ...]     (parse JSONC files, report errors)
  tool-args --source FILE --tool NAME [--subst ...] [--var DOC=... ...]
          print "command\0arg\0arg..." of a latex-workshop.latex.tools entry,
          with LaTeX Workshop placeholders (%DOC%, %OUTDIR%, ...) expanded

Exit codes: 0 ok / unchanged, 1 error, 2 check found drift.
"""
from __future__ import annotations

import argparse
import datetime as _dt
import json
import os
import shutil
import sys
import tempfile

BEGIN = "// >>> latex-dev-environment (managed block, do not edit by hand) >>>"
END = "// <<< latex-dev-environment <<<"


# --------------------------------------------------------------------------
# JSONC tokenizer
# --------------------------------------------------------------------------
class JsoncError(ValueError):
    pass


def tokenize(text: str):
    """Yield significant tokens as (kind, start, end).

    kind is one of '{', '}', '[', ']', ':', ',', 'str', 'lit'.
    Comments and whitespace are skipped. Strings are handled correctly, so
    '//' inside a URL is never mistaken for a comment.
    """
    i, n = 0, len(text)
    while i < n:
        c = text[i]
        if c in " \t\r\n﻿":
            i += 1
        elif text.startswith("//", i):
            j = text.find("\n", i)
            i = n if j < 0 else j + 1
        elif text.startswith("/*", i):
            j = text.find("*/", i + 2)
            if j < 0:
                raise JsoncError(f"unterminated block comment at offset {i}")
            i = j + 2
        elif c == '"':
            j = i + 1
            while j < n:
                if text[j] == "\\":
                    j += 2
                    continue
                if text[j] == '"':
                    break
                if text[j] == "\n":
                    raise JsoncError(f"newline in string at offset {j}")
                j += 1
            if j >= n:
                raise JsoncError(f"unterminated string at offset {i}")
            yield ("str", i, j + 1)
            i = j + 1
        elif c in "{}[]:,":
            yield (c, i, i + 1)
            i += 1
        else:
            j = i
            while j < n and text[j] not in " \t\r\n{}[]:,\"/":
                j += 1
            if j == i:
                raise JsoncError(f"unexpected character {c!r} at offset {i}")
            yield ("lit", i, j)
            i = j


def to_strict_json(text: str) -> str:
    """Drop comments and trailing commas, returning strict JSON text."""
    toks = list(tokenize(text))
    out = []
    for idx, (kind, s, e) in enumerate(toks):
        if kind == ",":
            nxt = toks[idx + 1][0] if idx + 1 < len(toks) else None
            if nxt in ("}", "]", None):
                continue  # trailing comma
        out.append(text[s:e])
        out.append(" ")
    return "".join(out)


def loads(text: str, what: str = "input", allow_empty: bool = False):
    if not text.strip() or not list(tokenize(text)):
        if allow_empty:
            return None
        raise JsoncError(f"{what}: empty document")
    try:
        return json.loads(to_strict_json(text), object_pairs_hook=_no_dup_pairs(what))
    except json.JSONDecodeError as exc:
        raise JsoncError(f"{what}: {exc}") from exc


_DUPLICATES: list[tuple[str, str]] = []


def _no_dup_pairs(what):
    def hook(pairs):
        d = {}
        for k, v in pairs:
            if k in d:
                _DUPLICATES.append((what, k))
            d[k] = v
        return d
    return hook


# --------------------------------------------------------------------------
# Block handling
# --------------------------------------------------------------------------
def find_block(text: str):
    """Return (start, end) offsets of the managed block (full lines) or None."""
    b = text.find(BEGIN)
    if b < 0:
        if END in text:
            raise JsoncError("found end marker without begin marker")
        return None
    e = text.find(END, b)
    if e < 0:
        raise JsoncError("found begin marker without end marker")
    start = text.rfind("\n", 0, b) + 1          # beginning of BEGIN line
    stop = text.find("\n", e)
    stop = len(text) if stop < 0 else stop + 1  # include END line's newline
    return start, stop


def strip_block(text: str) -> str:
    """Remove the managed block and the comma that preceded it (if any)."""
    span = find_block(text)
    if not span:
        return text
    text = text[: span[0]] + text[span[1]:]
    return drop_trailing_comma(text)


def top_level_close(text: str, kind: str):
    toks = list(tokenize(text))
    opener, closer = ("{", "}") if kind == "settings" else ("[", "]")
    if not toks or toks[0][0] != opener:
        raise JsoncError(f"top-level value is not a JSON {'object' if kind == 'settings' else 'array'}")
    depth = 0
    for idx, (k, s, _e) in enumerate(toks):
        if k in "{[":
            depth += 1
        elif k in "}]":
            depth -= 1
            if depth == 0:
                if k != closer:
                    raise JsoncError("mismatched brackets")
                return toks, idx
    raise JsoncError("unbalanced brackets")


def drop_trailing_comma(text: str) -> str:
    for kind in ("settings", "keybindings"):
        try:
            toks, ci = top_level_close(text, kind)
        except JsoncError:
            continue
        if ci > 0 and toks[ci - 1][0] == ",":
            s, e = toks[ci - 1][1], toks[ci - 1][2]
            return text[:s] + text[e:]
        return text
    return text


def detect_indent(text: str) -> str:
    for line in text.splitlines():
        stripped = line.lstrip(" \t")
        if stripped.startswith('"') or stripped.startswith("{"):
            ind = line[: len(line) - len(stripped)]
            if ind:
                return ind
    return "    "


def render_value(value, indent: str) -> str:
    raw = json.dumps(value, indent=indent or "    ", ensure_ascii=False)
    return raw.replace("\n", "\n" + indent)


def build_block(kind: str, entries, indent: str) -> str:
    lines = [indent + BEGIN]
    rendered = []
    if kind == "settings":
        for key, value in entries:
            rendered.append(indent + json.dumps(key, ensure_ascii=False) + ": " + render_value(value, indent))
    else:
        for obj in entries:
            rendered.append(indent + render_value(obj, indent))
    if rendered:
        lines.append(",\n".join(rendered))
    lines.append(indent + END)
    return "\n".join(lines) + "\n"


def insert_block(text: str, kind: str, block: str) -> str:
    toks, ci = top_level_close(text, kind)
    close_start = toks[ci][1]
    prev_kind, _ps, prev_end = toks[ci - 1]
    has_entries = block.count("\n") > 2
    if has_entries and prev_kind not in ("{", "[", ","):
        text = text[:prev_end] + "," + text[prev_end:]
        close_start += 1
    # Put the block on its own lines right before the closing bracket.
    line_start = text.rfind("\n", 0, close_start) + 1
    before = text[:line_start]
    if text[line_start:close_start].strip():
        # closing bracket shares a line with content: break the line
        before = text[:close_start].rstrip(" \t") + "\n"
        line_start = close_start
    if not before.endswith("\n"):
        before += "\n"
    return before + block + text[line_start:]


def substitute(value, subst: dict):
    if isinstance(value, str):
        for k, v in subst.items():
            value = value.replace("${" + k + "}", v)
        return value
    if isinstance(value, list):
        return [substitute(v, subst) for v in value]
    if isinstance(value, dict):
        return {k: substitute(v, subst) for k, v in value.items()}
    return value


def load_source(path: str, kind: str, subst: dict):
    with open(path, encoding="utf-8") as fh:
        data = loads(fh.read(), path)
    data = substitute(data, subst)
    if kind == "settings":
        if not isinstance(data, dict):
            raise JsoncError(f"{path}: expected an object")
        return list(data.items())
    if not isinstance(data, list):
        raise JsoncError(f"{path}: expected an array")
    return data


def read_target(path: str, kind: str) -> str:
    if not os.path.exists(path):
        return "{\n}\n" if kind == "settings" else "// Place your key bindings in this file to override the defaults\n[\n]\n"
    with open(path, encoding="utf-8") as fh:
        text = fh.read()
    if loads(text, path, allow_empty=True) is None:
        return "{\n}\n" if kind == "settings" else "[\n]\n"
    return text


def plan_merge(text: str, kind: str, entries):
    """Return (new_text, skipped, notes)."""
    base = strip_block(text)
    user = loads(base, "target (outside managed block)")
    skipped, notes, keep = [], [], []
    if kind == "settings":
        for key, value in entries:
            if key in user:
                if user[key] == value:
                    notes.append(f"'{key}' already set to the same value outside the block; not duplicated")
                else:
                    skipped.append(key)
                continue
            keep.append((key, value))
    else:
        for obj in entries:
            if obj in user:
                notes.append(f"binding {obj.get('key')} -> {obj.get('command')} already present; not duplicated")
                continue
            for u in user:
                if isinstance(u, dict) and u.get("key") == obj.get("key") and not str(u.get("command", "")).startswith("-"):
                    notes.append(f"user binding {u.get('key')} -> {u.get('command')} also exists (when: {u.get('when', '-')}); "
                                 "check context overlap")
            keep.append(obj)
    new = insert_block(base, kind, build_block(kind, keep, detect_indent(base)))
    verify(new, kind, user, keep)
    return new, skipped, notes


def verify(new_text: str, kind: str, user, keep):
    _DUPLICATES.clear()
    result = loads(new_text, "merged result")
    if _DUPLICATES:
        raise JsoncError(f"merge would create duplicate keys: {_DUPLICATES}")
    if kind == "settings":
        for k, v in user.items():
            if result.get(k) != v:
                raise JsoncError(f"verification failed: user key '{k}' changed")
        for k, v in keep:
            if result.get(k) != v:
                raise JsoncError(f"verification failed: managed key '{k}' missing")
        if set(result) != set(user) | {k for k, _ in keep}:
            raise JsoncError("verification failed: unexpected keys")
    else:
        if result != list(user) + list(keep):
            raise JsoncError("verification failed: keybindings array mismatch")


def backup(path: str, backup_dir: str | None) -> str | None:
    if not os.path.exists(path):
        return None
    stamp = _dt.datetime.now().strftime("%Y%m%d-%H%M%S")
    bdir = backup_dir or os.path.dirname(path)
    os.makedirs(bdir, exist_ok=True)
    dest = os.path.join(bdir, f"{os.path.basename(path)}.{stamp}.bak")
    n = 1
    while os.path.exists(dest):
        dest = os.path.join(bdir, f"{os.path.basename(path)}.{stamp}-{n}.bak")
        n += 1
    shutil.copy2(path, dest)
    return dest


def atomic_write(path: str, text: str):
    os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
    fd, tmp = tempfile.mkstemp(prefix=".lde-", dir=os.path.dirname(os.path.abspath(path)))
    with os.fdopen(fd, "w", encoding="utf-8") as fh:
        fh.write(text)
    if os.path.exists(path):
        shutil.copymode(path, tmp)
    os.replace(tmp, path)


# --------------------------------------------------------------------------
# CLI
# --------------------------------------------------------------------------
def parse_subst(items):
    out = {}
    for it in items or []:
        if "=" not in it:
            raise SystemExit(f"--subst expects NAME=VALUE, got {it!r}")
        k, v = it.split("=", 1)
        out[k] = v
    return out


def cmd_merge(a) -> int:
    entries = load_source(a.source, a.kind, parse_subst(a.subst))
    old = read_target(a.target, a.kind)
    new, skipped, notes = plan_merge(old, a.kind, entries)
    for k in skipped:
        print(f"WARN  '{k}' is already set outside the managed block with a different value; "
              "keeping your value (remove it there to use the repository default)")
    for n in notes:
        print(f"INFO  {n}")
    exists = os.path.exists(a.target)
    if exists:
        with open(a.target, encoding="utf-8") as fh:
            if fh.read() == new:
                print(f"OK    {a.target} already up to date")
                return 0
    if a.dry_run:
        print(f"DRY   would update {a.target}")
        return 0
    b = backup(a.target, a.backup_dir)
    if b:
        print(f"BACKUP {b}")
    atomic_write(a.target, new)
    print(f"OK    {'updated' if exists else 'created'} {a.target} ({len(entries) - len(skipped)} managed entries)")
    return 0


def cmd_remove(a) -> int:
    if not os.path.exists(a.target):
        print(f"OK    {a.target} does not exist")
        return 0
    with open(a.target, encoding="utf-8") as fh:
        old = fh.read()
    if not find_block(old):
        print(f"OK    no managed block in {a.target}")
        return 0
    new = strip_block(old)
    loads(new, "result after removal")
    b = backup(a.target, a.backup_dir)
    print(f"BACKUP {b}")
    atomic_write(a.target, new)
    print(f"OK    removed managed block from {a.target}")
    return 0


def cmd_check(a) -> int:
    if not os.path.exists(a.target):
        print(f"missing: {a.target}")
        return 2
    with open(a.target, encoding="utf-8") as fh:
        text = fh.read()
    if not find_block(text):
        print("managed block not found")
        return 2
    entries = load_source(a.source, a.kind, parse_subst(a.subst))
    expected, skipped, _ = plan_merge(text, a.kind, entries)
    if expected != text:
        print("managed block is out of date (re-run configure-vscode.sh)")
        return 2
    print(f"managed block up to date ({len(entries) - len(skipped)} entries"
          + (f", {len(skipped)} overridden by user: {', '.join(skipped)}" if skipped else "") + ")")
    return 0


def cmd_validate(a) -> int:
    rc = 0
    for f in a.files:
        _DUPLICATES.clear()
        try:
            with open(f, encoding="utf-8") as fh:
                loads(fh.read(), f)
            if _DUPLICATES:
                print(f"FAIL  {f}: duplicate keys {[k for _, k in _DUPLICATES]}")
                rc = 1
            else:
                print(f"OK    {f}")
        except (OSError, JsoncError) as exc:
            print(f"FAIL  {f}: {exc}")
            rc = 1
    return rc


def cmd_tool_args(a) -> int:
    with open(a.source, encoding="utf-8") as fh:
        data = substitute(loads(fh.read(), a.source), parse_subst(a.subst))
    for tool in data.get("latex-workshop.latex.tools", []):
        if tool.get("name") == a.tool:
            vars_ = parse_subst(a.var)
            args = []
            for arg in tool.get("args", []):
                for k, v in vars_.items():
                    arg = arg.replace(f"%{k}%", v)
                args.append(arg)
            sys.stdout.write("\0".join([tool["command"], *args]))
            return 0
    print(f"ERROR tool {a.tool!r} not found", file=sys.stderr)
    return 1


def main(argv=None) -> int:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = p.add_subparsers(dest="cmd", required=True)
    for name in ("merge", "remove", "check"):
        sp = sub.add_parser(name)
        sp.add_argument("--kind", choices=("settings", "keybindings"), required=True)
        sp.add_argument("--target", required=True)
        if name != "remove":
            sp.add_argument("--source", required=True)
            sp.add_argument("--subst", action="append")
        sp.add_argument("--backup-dir")
        sp.add_argument("--dry-run", action="store_true")
    st = sub.add_parser("tool-args")
    st.add_argument("--source", required=True)
    st.add_argument("--tool", required=True)
    st.add_argument("--subst", action="append")
    st.add_argument("--var", action="append")
    sv = sub.add_parser("validate")
    sv.add_argument("files", nargs="+")
    a = p.parse_args(argv)
    try:
        return {"merge": cmd_merge, "remove": cmd_remove, "check": cmd_check,
                "validate": cmd_validate, "tool-args": cmd_tool_args}[a.cmd](a)
    except JsoncError as exc:
        print(f"ERROR {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())

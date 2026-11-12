#!/usr/bin/env python3
"""Validate vscode/latex.code-snippets and render it to compilable LaTeX.

Checks
  * strict JSON, no duplicate names or prefixes
  * every snippet has prefix/body/description and scope "latex"
  * body parses with VS Code snippet grammar (placeholders, choices,
    mirrors, escapes) and tab stops are numbered 1..n without gaps
  * rendered text has balanced braces and \\begin/\\end pairs

With --render FILE, writes a LaTeX document that contains every snippet
expanded with its default values (first choice for choice lists), so the
expansion can be compiled to prove it produces valid LaTeX.
"""
from __future__ import annotations

import argparse
import json
import re
import sys

REQUIRED_PREFIXES = ["eq", "eqs", "align", "fig", "subfig", "tbl", "sec", "ssec", "chap",
                     "cite", "ref", "item", "enum", "algo", "lst", "thm", "proof"]
MATH_MODE = {"mat", "cases"}   # snippets meant to be used inside math mode
# placeholders that are intentionally generic get a concrete value for the compile test
RENDER_OVERRIDES = {"beg": ("{environment}", "{center}")}


class SnippetError(ValueError):
    pass


def parse(body: str):
    """Parse VS Code snippet syntax. Returns (rendered_text, tabstops)."""
    values: dict[int, str] = {}
    stops: set[int] = set()

    def parse_seq(i: int, terminators: str) -> tuple[str, int]:
        buf = []
        while i < len(body):
            c = body[i]
            if c == "\\" and i + 1 < len(body) and body[i + 1] in "$}\\":
                buf.append(body[i + 1])
                i += 2
            elif c in terminators:
                return "".join(buf), i
            elif c == "$":
                text, i = parse_dollar(i)
                buf.append(text)
            else:
                buf.append(c)
                i += 1
        if terminators:
            raise SnippetError(f"unterminated placeholder (missing {terminators!r})")
        return "".join(buf), i

    def parse_dollar(i: int) -> tuple[str, int]:
        m = re.match(r"\$(\d+)", body[i:])
        if m:
            n = int(m.group(1))
            stops.add(n)
            return f"\x00{n}\x00", i + m.end()
        m = re.match(r"\$\{(\d+)\}", body[i:])
        if m:
            n = int(m.group(1))
            stops.add(n)
            return f"\x00{n}\x00", i + m.end()
        m = re.match(r"\$\{(\d+):", body[i:])
        if m:
            n = int(m.group(1))
            stops.add(n)
            text, j = parse_seq(i + m.end(), "}")
            values.setdefault(n, text)
            return text, j + 1
        m = re.match(r"\$\{(\d+)\|", body[i:])
        if m:
            n = int(m.group(1))
            stops.add(n)
            j = i + m.end()
            end = body.find("|}", j)
            if end < 0:
                raise SnippetError("unterminated choice")
            options = re.split(r"(?<!\\),", body[j:end])
            if not options or not options[0]:
                raise SnippetError("empty choice list")
            values.setdefault(n, options[0])
            return options[0], end + 2
        m = re.match(r"\$\{?([A-Z_]+)", body[i:])
        if m:
            raise SnippetError(f"variable {m.group(1)} used; not supported by this checker")
        raise SnippetError(f"stray '$' at offset {i} (escape it as \\\\$ in JSON)")

    text, _ = parse_seq(0, "")
    # resolve mirrors / bare tab stops
    text = re.sub(r"\x00(\d+)\x00", lambda m: values.get(int(m.group(1)), ""), text)
    return text, stops


def check_balance(name: str, text: str):
    depth = 0
    i = 0
    while i < len(text):
        c = text[i]
        if c == "\\":
            i += 2
            continue
        if c == "{":
            depth += 1
        elif c == "}":
            depth -= 1
            if depth < 0:
                raise SnippetError("unbalanced '}'")
        i += 1
    if depth:
        raise SnippetError("unbalanced '{'")
    begins = re.findall(r"\\begin\{([^}]*)\}", text)
    ends = re.findall(r"\\end\{([^}]*)\}", text)
    stack = []
    for kind, env in sorted([(m.start(), ("b", m.group(1))) for m in re.finditer(r"\\begin\{([^}]*)\}", text)] +
                            [(m.start(), ("e", m.group(1))) for m in re.finditer(r"\\end\{([^}]*)\}", text)]):
        if env[0] == "b":
            stack.append(env[1])
        else:
            if not stack or stack.pop() != env[1]:
                raise SnippetError(f"\\end{{{env[1]}}} does not match")
    if stack or len(begins) != len(ends):
        raise SnippetError(f"unclosed environment(s): {stack}")


def load(path: str):
    dup = []

    def hook(pairs):
        seen = {}
        for k, v in pairs:
            if k in seen:
                dup.append(k)
            seen[k] = v
        return seen

    with open(path, encoding="utf-8") as fh:
        data = json.load(fh, object_pairs_hook=hook)
    if dup:
        raise SnippetError(f"duplicate snippet names: {dup}")
    return data


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("snippets")
    ap.add_argument("--render", metavar="TEX")
    a = ap.parse_args()
    try:
        data = load(a.snippets)
    except (json.JSONDecodeError, SnippetError) as exc:
        print(f"FAIL  {a.snippets}: {exc}")
        return 1

    errors = 0
    prefixes: dict[str, str] = {}
    rendered: list[tuple[str, str]] = []
    for name, snip in data.items():
        try:
            for field in ("prefix", "body", "description"):
                if field not in snip:
                    raise SnippetError(f"missing '{field}'")
            if snip.get("scope") != "latex":
                raise SnippetError("scope must be 'latex'")
            plist = snip["prefix"] if isinstance(snip["prefix"], list) else [snip["prefix"]]
            for p in plist:
                if p in prefixes:
                    raise SnippetError(f"prefix '{p}' also used by '{prefixes[p]}'")
                prefixes[p] = name
            body = "\n".join(snip["body"]) if isinstance(snip["body"], list) else snip["body"]
            text, stops = parse(body)
            numbered = sorted(s for s in stops if s > 0)
            if numbered != list(range(1, len(numbered) + 1)) and numbered:
                # mirrors reuse numbers, so compare the set
                if sorted(set(numbered)) != list(range(1, max(numbered) + 1)):
                    raise SnippetError(f"tab stops not contiguous: {sorted(set(numbered))}")
            if 0 not in stops and "$0" not in body:
                raise SnippetError("no final tab stop $0")
            check_balance(name, text)
            rendered.append((plist[0], text))
        except SnippetError as exc:
            print(f"FAIL  snippet '{name}': {exc}")
            errors += 1

    missing = [p for p in REQUIRED_PREFIXES if p not in prefixes]
    if missing:
        print(f"FAIL  required prefixes missing: {missing}")
        errors += 1
    if errors:
        return 1
    print(f"OK    {len(data)} snippets valid; prefixes: {', '.join(sorted(prefixes))}")

    if a.render:
        with open(a.render, "w", encoding="utf-8") as fh:
            fh.write(PREAMBLE)
            for prefix, text in rendered:
                fh.write(f"\n% ---- snippet: {prefix} ----\n")
                if prefix in RENDER_OVERRIDES:
                    text = text.replace(*RENDER_OVERRIDES[prefix])
                if prefix in MATH_MODE:
                    fh.write("\\[\n" + text + "\n\\]\n")
                else:
                    fh.write(text + "\n")
            fh.write("\n\\printbibliography\n\\end{document}\n")
        print(f"OK    rendered expansion written to {a.render}")
    return 0


PREAMBLE = r"""% Generated by tests/snippet_check.py — every snippet expanded with defaults.
\documentclass{report}
\usepackage{amsmath,amssymb,amsthm}
\usepackage{graphicx}
\usepackage{subcaption}
\usepackage{booktabs}
\usepackage{listings}
\usepackage{algorithm}
\usepackage{algpseudocode}
\usepackage[backend=biber]{biblatex}
\addbibresource{references.bib}
\usepackage{hyperref}
\usepackage{cleveref}
\newtheorem{theorem}{Theorem}
\newtheorem{lemma}{Lemma}
\begin{document}
"""

if __name__ == "__main__":
    sys.exit(main())

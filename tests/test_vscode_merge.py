#!/usr/bin/env python3
"""Unit tests for scripts/lib/vscode_merge.py (run: python3 -m unittest)."""
import json
import os
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "scripts", "lib"))
import vscode_merge as vm  # noqa: E402

USER_SETTINGS = """{
    // THEME
    "workbench.colorTheme": "Catppuccin Mocha", // trailing comment
    "json.schemaDownload.trustedDomains": {
        "https://raw.githubusercontent.com/catppuccin/vscode/": true
    },
    /* block comment */
    "editor.formatOnSave": true
}
"""


class MergeSettings(unittest.TestCase):
    entries = [("latex-workshop.latex.outDir", "%DIR%/build"), ("[latex]", {"editor.tabSize": 2})]

    def test_preserves_user_text_and_values(self):
        new, skipped, _ = vm.plan_merge(USER_SETTINGS, "settings", self.entries)
        self.assertEqual(skipped, [])
        # all original lines survive verbatim (only a comma may be appended)
        for line in USER_SETTINGS.splitlines():
            if line.strip() and line.strip() != "}":
                self.assertTrue(line in new or line + "," in new, line)
        data = vm.loads(new)
        self.assertEqual(data["workbench.colorTheme"], "Catppuccin Mocha")
        self.assertEqual(data["latex-workshop.latex.outDir"], "%DIR%/build")

    def test_idempotent(self):
        once, _, _ = vm.plan_merge(USER_SETTINGS, "settings", self.entries)
        twice, _, _ = vm.plan_merge(once, "settings", self.entries)
        self.assertEqual(once, twice)

    def test_user_value_wins(self):
        text = USER_SETTINGS.replace('"editor.formatOnSave": true', '"editor.formatOnSave": true,\n    "latex-workshop.latex.outDir": "out"')
        new, skipped, _ = vm.plan_merge(text, "settings", self.entries)
        self.assertEqual(skipped, ["latex-workshop.latex.outDir"])
        self.assertEqual(vm.loads(new)["latex-workshop.latex.outDir"], "out")

    def test_remove_roundtrip(self):
        new, _, _ = vm.plan_merge(USER_SETTINGS, "settings", self.entries)
        self.assertEqual(vm.strip_block(new), USER_SETTINGS)

    def test_trailing_comma_and_tabs(self):
        text = '{\n\t"a": 1,\n}\n'
        new, _, _ = vm.plan_merge(text, "settings", self.entries)
        self.assertEqual(vm.loads(new)["a"], 1)
        self.assertIn('\t"latex-workshop.latex.outDir"', new)

    def test_empty_object(self):
        new, _, _ = vm.plan_merge("{}", "settings", self.entries)
        self.assertEqual(len(vm.loads(new)), 2)

    def test_comment_url_not_treated_as_comment(self):
        self.assertEqual(vm.loads('{"u": "http://x//y"}')["u"], "http://x//y")

    def test_rejects_invalid(self):
        with self.assertRaises(vm.JsoncError):
            vm.plan_merge('{"a": }', "settings", self.entries)


class MergeKeybindings(unittest.TestCase):
    kb = [{"key": "ctrl+alt+b", "command": "latex-workshop.build"}]

    def test_default_file_with_comment(self):
        text = "// Place your key bindings in this file\n[\n]\n"
        new, _, _ = vm.plan_merge(text, "keybindings", self.kb)
        self.assertEqual(vm.loads(new), self.kb)
        self.assertTrue(new.startswith("// Place"))

    def test_existing_bindings_kept_first(self):
        text = '[\n    { "key": "f5", "command": "x" }\n]\n'
        new, _, _ = vm.plan_merge(text, "keybindings", self.kb)
        self.assertEqual(vm.loads(new), [{"key": "f5", "command": "x"}] + self.kb)
        self.assertEqual(vm.strip_block(new), text)

    def test_no_duplicate_when_user_has_same(self):
        text = json.dumps(self.kb)
        new, _, notes = vm.plan_merge(text, "keybindings", self.kb)
        self.assertEqual(vm.loads(new), self.kb)
        self.assertTrue(notes)


class Cli(unittest.TestCase):
    def test_merge_backup_and_check(self):
        repo = os.path.join(os.path.dirname(__file__), "..")
        with tempfile.TemporaryDirectory() as d:
            target = os.path.join(d, "settings.json")
            with open(target, "w") as fh:
                fh.write(USER_SETTINGS)
            args = ["--kind", "settings", "--target", target,
                    "--source", os.path.join(repo, "vscode", "settings.json"), "--subst", "HOME=/home/test"]
            self.assertEqual(vm.main(["merge", *args, "--backup-dir", os.path.join(d, "bk")]), 0)
            self.assertEqual(len(os.listdir(os.path.join(d, "bk"))), 1)
            self.assertEqual(vm.main(["check", *args]), 0)
            with open(target) as fh:
                self.assertIn("/home/test/.config/chktex/chktexrc", fh.read())
            self.assertEqual(vm.main(["remove", "--kind", "settings", "--target", target,
                                      "--backup-dir", os.path.join(d, "bk")]), 0)
            with open(target) as fh:
                self.assertEqual(fh.read(), USER_SETTINGS)


if __name__ == "__main__":
    unittest.main()

"""Regression: checkout names must not change the committed Xcode project."""
from pathlib import Path
import difflib
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


@unittest.skipUnless(shutil.which("xcodegen"), "XcodeGen is required")
class ProjectGenerationTests(unittest.TestCase):
    def test_different_checkout_names_generate_identical_project_and_schemes(self):
        with tempfile.TemporaryDirectory(prefix="lith-generator-test-") as temporary:
            outputs = []
            for name in ("Lith", "different checkout with spaces"):
                root = Path(temporary) / name
                root.mkdir()
                for file in ("project.yml", "Package.swift"):
                    shutil.copy2(ROOT / file, root / file)
                shutil.copytree(ROOT / "Apps", root / "Apps")
                (root / "scripts").mkdir()
                shutil.copy2(ROOT / "scripts/generate-project.py", root / "scripts/generate-project.py")
                subprocess.run(["python3", str(root / "scripts/generate-project.py")], check=True, capture_output=True)
                project = root / "LithApps.xcodeproj"
                first = {str(path.relative_to(project)): path.read_bytes() for path in project.rglob("*") if path.is_file()}
                subprocess.run(["python3", str(root / "scripts/generate-project.py")], check=True, capture_output=True)
                second = {str(path.relative_to(project)): path.read_bytes() for path in project.rglob("*") if path.is_file()}
                self.assertEqual(first, second, "Generation must be idempotent")
                outputs.append(first)
            self.assertEqual(outputs[0].keys(), outputs[1].keys())
            for path in outputs[0]:
                if outputs[0][path] != outputs[1][path]:
                    difference = "\n".join(difflib.unified_diff(outputs[0][path].decode().splitlines(), outputs[1][path].decode().splitlines()))
                    self.fail(f"Checkout path changed {path}:\n{difference}")


if __name__ == "__main__":
    unittest.main()

#!/usr/bin/env python3
"""Generate the Xcode project with a checkout-independent local package identity."""
import hashlib
from pathlib import Path
import re
import subprocess

root = Path(__file__).resolve().parent.parent
subprocess.run(["xcodegen", "generate", "--spec", str(root / "project.yml")], cwd=root, check=True)
project = root / "LithApps.xcodeproj/project.pbxproj"
text = project.read_text()
# XcodeGen derives a local package reference UUID/comment from the checkout folder.
# Normalize only the root package reference. All source/build UUIDs stay generator-owned.
pattern = r'([A-F0-9]{24}) /\* XCLocalSwiftPackageReference "[^"]*" \*/ = \{\n\s*isa = XCLocalSwiftPackageReference;\n\s*relativePath = \.;\n\s*\};'
match = re.search(pattern, text)
if not match:
    raise SystemExit("Expected exactly one root XCLocalSwiftPackageReference; inspect XcodeGen output before updating this script.")
stable_id = hashlib.sha256(b"Lith:XCLocalSwiftPackageReference:.").hexdigest()[:24].upper()
text = text.replace(match.group(1), stable_id)
text = re.sub(rf'{stable_id} /\* XCLocalSwiftPackageReference "[^"]*" \*/', f'{stable_id} /* XCLocalSwiftPackageReference "Lith" */', text)
# XcodeGen also adds a navigator folder reference named after the checkout.
folder_pattern = r'([A-F0-9]{24}) /\* [^*]* \*/ = \{isa = PBXFileReference; lastKnownFileType = folder; name = [^;]+; path = \.; sourceTree = SOURCE_ROOT; \};'
folder = re.search(folder_pattern, text)
if not folder:
    raise SystemExit("Expected root package navigator reference; inspect generator output.")
folder_id = hashlib.sha256(b"Lith:PBXFileReference:root-package").hexdigest()[:24].upper()
text = re.sub(rf'{folder.group(1)} /\* [^*]* \*/', f'{folder_id} /* Lith */', text)
text = re.sub(rf'({folder_id} /\* Lith \*/ = \{{isa = PBXFileReference; lastKnownFileType = folder; name = )[^;]+;', r'\1Lith;', text)
# UUID substitutions must also preserve deterministic section ordering.
start = "/* Begin PBXFileReference section */\n"
end = "/* End PBXFileReference section */"
head, section = text.split(start, 1)
body, tail = section.split(end, 1)
text = head + start + "".join(sorted(body.splitlines(keepends=True))) + end + tail
project.write_text(text)

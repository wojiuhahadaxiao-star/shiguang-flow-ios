#!/usr/bin/env python3
"""Reject missing/stale release files before compilation. Allows Windows CRLF."""
from pathlib import Path
import hashlib, json, sys
ROOT = Path(__file__).resolve().parents[1]
manifest_path = ROOT / 'RELEASE.json'
if not manifest_path.exists():
    sys.exit('::error::Missing RELEASE.json. Upload all files from the release ZIP at repository root.')
manifest = json.loads(manifest_path.read_text(encoding='utf-8'))
failed = []
for name, expected in manifest['files'].items():
    path = ROOT / name
    if not path.is_file():
        failed.append(name + ' (missing)'); continue
    data = path.read_bytes()
    if path.suffix in {'.swift', '.py', '.yml', '.json', '.plist', '.pbxproj', '.xcscheme'}:
        data = data.replace(b'\r\n', b'\n')
    if hashlib.sha256(data).hexdigest() != expected:
        failed.append(name + ' (different from this release)')
if failed:
    for message in failed: print('::error::' + message)
    sys.exit('Release files are incomplete or mixed. Replace the listed files from the same ZIP.')
print('PASS: complete Shiguang Flow ' + manifest['version'] + ' / ' + manifest['release'])
print('Verified ' + str(len(manifest['files'])) + ' release files; no mixed source files detected.')

#!/usr/bin/env python3
"""Static deliverable integrity checks; these do not replace xcodebuild or swift test."""
from pathlib import Path
import json, plistlib, re, xml.etree.ElementTree as ET
ROOT = Path(__file__).resolve().parents[1]
info = plistlib.loads((ROOT/'ShiguangFlow/Info.plist').read_bytes())
assert info['NSPhotoLibraryUsageDescription']
assert info['CFBundleDisplayName'] == '拾光 Flow'
assert info['CFBundleIdentifier'] == '$(PRODUCT_BUNDLE_IDENTIFIER)'
assert 'UIApplicationSceneManifest' not in info  # UIApplicationDelegate window lifecycle
pbx = (ROOT/'ShiguangFlow.xcodeproj/project.pbxproj').read_text()
assert 'com.yang.shiguangflow.standalone' in pbx
sources = list((ROOT/'ShiguangFlow').glob('*.swift')) + [ROOT/'Sources/FlowCore/FlowSession.swift']
for source in sources:
    assert str(source.relative_to(ROOT)) in pbx, f'Unreferenced source: {source}'
assert len(sources) == 7
scheme = ET.parse(ROOT/'ShiguangFlow.xcodeproj/xcshareddata/xcschemes/ShiguangFlow.xcscheme')
for ref in scheme.iter('BuildableReference'):
    assert ref.attrib['BlueprintIdentifier'] in pbx
    assert ref.attrib['BuildableName'] == 'ShiguangFlow.app'
for path in (ROOT/'ShiguangFlow/Assets.xcassets').rglob('Contents.json'):
    data = json.loads(path.read_text())
    for image in data.get('images', []):
        assert (path.parent/image['filename']).is_file()
tests = (ROOT/'Tests/FlowCoreTests/FlowSessionTests.swift').read_text()
assert len(re.findall(r'func test\w+\(', tests)) == 10
workflow = (ROOT/'.github/workflows/build-ios.yml').read_text()
for expected in ['swift test', 'CODE_SIGNING_ALLOWED=NO', 'actions/upload-artifact@v4', 'workflow_dispatch', 'github.run_number']:
    assert expected in workflow
print('PASS: plist, source references, scheme, assets, 10 test declarations and build workflow presence')
print('NOT RUN: Swift type checking, XCTest execution, iOS builds, simulator or real-device interaction')

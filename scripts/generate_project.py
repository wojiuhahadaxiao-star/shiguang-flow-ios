#!/usr/bin/env python3
"""Generate a dependency-free Xcode project. No XcodeGen / CocoaPods required."""
from pathlib import Path
import hashlib, plistlib, json
ROOT = Path(__file__).resolve().parents[1]
def uid(name): return hashlib.sha1(name.encode()).hexdigest()[:24].upper()
def q(s): return json.dumps(s)
sources = sorted(str(p.relative_to(ROOT)) for p in (ROOT/'ShiguangFlow').glob('*.swift')) + ['Sources/FlowCore/FlowSession.swift']
objects = []
def obj(name, content):
    objects.append(f'\t\t{uid(name)} = {{ {content} }};')
    return uid(name)
file_ids=[]; build_ids=[]
for path in sources:
    f=obj('file:'+path, f'isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {q(path)}; sourceTree = "<group>";')
    b=obj('build:'+path, f'isa = PBXBuildFile; fileRef = {f};')
    file_ids.append(f); build_ids.append(b)
assets=obj('assets','isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = ShiguangFlow/Assets.xcassets; sourceTree = "<group>";')
assets_build=obj('assets-build',f'isa = PBXBuildFile; fileRef = {assets};')
info=obj('info','isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = ShiguangFlow/Info.plist; sourceTree = "<group>";')
product=obj('product','isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = ShiguangFlow.app; sourceTree = BUILT_PRODUCTS_DIR;')
products=obj('products',f'isa = PBXGroup; children = ({product},); name = Products; sourceTree = "<group>";')
main=obj('main',f'isa = PBXGroup; children = ({",".join(file_ids+[assets,info,products])},); sourceTree = "<group>";')
phase_sources=obj('sources',f'isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = ({",".join(build_ids)},); runOnlyForDeploymentPostprocessing = 0;')
phase_resources=obj('resources',f'isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = ({assets_build},); runOnlyForDeploymentPostprocessing = 0;')
phase_frameworks=obj('frameworks','isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0;')
for level in ['project','target']:
    configs=[]
    for mode in ['Debug','Release']:
        settings = {
            'CLANG_ENABLE_MODULES':'YES', 'CLANG_ENABLE_OBJC_ARC':'YES', 'IPHONEOS_DEPLOYMENT_TARGET':'16.0',
            'SDKROOT':'iphoneos', 'SWIFT_VERSION':'5.0', 'SWIFT_STRICT_CONCURRENCY':'minimal',
            'SWIFT_OPTIMIZATION_LEVEL':'-Onone' if mode=='Debug' else '-O',
            'DEBUG_INFORMATION_FORMAT':'dwarf' if mode=='Debug' else 'dwarf-with-dsym',
        } if level=='project' else {
            'PRODUCT_NAME':'$(TARGET_NAME)', 'PRODUCT_BUNDLE_IDENTIFIER':'com.yang.shiguangflow.standalone',
            'INFOPLIST_FILE':'ShiguangFlow/Info.plist', 'GENERATE_INFOPLIST_FILE':'NO',
            'CURRENT_PROJECT_VERSION':'1', 'MARKETING_VERSION':'1.0.0',
            'TARGETED_DEVICE_FAMILY':'1', 'SUPPORTED_PLATFORMS':'iphoneos iphonesimulator',
            'CODE_SIGN_STYLE':'Automatic', 'ASSETCATALOG_COMPILER_APPICON_NAME':'AppIcon',
            'LD_RUNPATH_SEARCH_PATHS':'$(inherited) @executable_path/Frameworks',
            'SWIFT_EMIT_LOC_STRINGS':'YES', 'ENABLE_USER_SCRIPT_SANDBOXING':'YES',
        }
        if level=='project' and mode=='Debug': settings['SWIFT_ACTIVE_COMPILATION_CONDITIONS']='DEBUG'
        body=' '.join(f'{key} = {q(value)};' for key,value in settings.items())
        configs.append(obj(level+mode, f'isa = XCBuildConfiguration; buildSettings = {{ {body} }}; name = {mode};'))
    obj(level+'configs',f'isa = XCConfigurationList; buildConfigurations = ({",".join(configs)},); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
target=obj('target',f'isa = PBXNativeTarget; buildConfigurationList = {uid("targetconfigs")}; buildPhases = ({phase_sources},{phase_frameworks},{phase_resources},); buildRules = (); dependencies = (); name = ShiguangFlow; productName = ShiguangFlow; productReference = {product}; productType = "com.apple.product-type.application";')
project=obj('project',f'isa = PBXProject; attributes = {{ BuildIndependentTargetsInParallel = YES; LastUpgradeCheck = 1600; }}; buildConfigurationList = {uid("projectconfigs")}; compatibilityVersion = "Xcode 14.0"; developmentRegion = "zh-Hans"; hasScannedForEncodings = 0; knownRegions = ("zh-Hans",en,Base,); mainGroup = {main}; productRefGroup = {products}; projectDirPath = ""; projectRoot = ""; targets = ({target},);')
p=ROOT/'ShiguangFlow.xcodeproj/project.pbxproj'
p.write_text('// !$*UTF8*$!\n{\n\tarchiveVersion = 1;\n\tclasses = {};\n\tobjectVersion = 56;\n\tobjects = {\n'+'\n'.join(objects)+f'\n\t}};\n\trootObject = {project};\n}}\n')
info = {
    'CFBundleDevelopmentRegion':'zh_CN','CFBundleDisplayName':'拾光 Flow','CFBundleExecutable':'$(EXECUTABLE_NAME)',
    'CFBundleIdentifier':'$(PRODUCT_BUNDLE_IDENTIFIER)','CFBundleInfoDictionaryVersion':'6.0','CFBundleName':'$(PRODUCT_NAME)',
    'CFBundlePackageType':'APPL','CFBundleShortVersionString':'$(MARKETING_VERSION)','CFBundleVersion':'$(CURRENT_PROJECT_VERSION)',
    'LSRequiresIPhoneOS': True,'NSPhotoLibraryUsageDescription':'用于随机浏览照片、按拍摄日期浏览，以及在你多次确认后删除选中的照片。',
    'PHPhotoLibraryPreventAutomaticLimitedAccessAlert':True,
    'UILaunchScreen':{'UIColorName':'LaunchBackground'},'UIUserInterfaceStyle':'Light',
    'UISupportedInterfaceOrientations':['UIInterfaceOrientationPortrait'],
    'CADisableMinimumFrameDurationOnPhone':True,
}
(ROOT/'ShiguangFlow/Info.plist').write_bytes(plistlib.dumps(info,sort_keys=False))
scheme=f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1600" version="1.3">
 <BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries>
  <BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">
   <BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target}" BuildableName="ShiguangFlow.app" BlueprintName="ShiguangFlow" ReferencedContainer="container:ShiguangFlow.xcodeproj"/>
  </BuildActionEntry>
 </BuildActionEntries></BuildAction>
 <TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables/></TestAction>
 <LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES">
  <BuildableProductRunnable runnableDebuggingMode="0"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target}" BuildableName="ShiguangFlow.app" BlueprintName="ShiguangFlow" ReferencedContainer="container:ShiguangFlow.xcodeproj"/></BuildableProductRunnable>
 </LaunchAction>
 <ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target}" BuildableName="ShiguangFlow.app" BlueprintName="ShiguangFlow" ReferencedContainer="container:ShiguangFlow.xcodeproj"/></BuildableProductRunnable></ProfileAction>
 <AnalyzeAction buildConfiguration="Debug"/>
 <ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>
'''
(ROOT/'ShiguangFlow.xcodeproj/xcshareddata/xcschemes/ShiguangFlow.xcscheme').write_text(scheme)
print(f'Generated project with {len(sources)} Swift sources')

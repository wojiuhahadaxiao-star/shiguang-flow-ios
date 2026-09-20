> **1.1.0 P2 更新**：随机与当日模式均支持右端继续左拉进入下一组、左端继续右拉回上一组；阈值触感与弹簧过渡。垃圾桶内部显示待删数量，初始为 0，每标记一张加 1，撤回一张减 1。已有仓库请用本包的内容更新根目录，保留目录层级，包括 `.github`。

> **编译修复 P1**：补齐 `FlowViewController.swift` 的 `import PhotosUI`，并保留 `PhotoViewer.swift` 的 `override` 修复。已有仓库只需替换 `ShiguangFlow/` 下这两个 Swift 文件即可；无需修改 Actions 或重建仓库。

# 拾光 Flow · 全新独立 iOS 工程

原生 UIKit / PhotoKit，iOS 16.0 及以上，iPhone 竖屏。版本 **1.1.0**。

- 应用名：**拾光 Flow**
- Bundle ID：**com.yang.shiguangflow.standalone**
- 建议新仓库名：**shiguang-flow-ios**
- 全新工程，不依赖、不替换旧 App 源码；安装时保持此独立 Bundle ID，即可与旧 App 共存。
- 没有第三方运行时依赖，无需 CocoaPods、XcodeGen 或服务器。

> 交付状态：完整源码工程，已做 Swift 语法解析和工程静态检查。当前生成环境没有 Xcode/iOS SDK，**尚未完成修复后 Xcode 编译或 iPhone 实机验证；用户提供的 CI 日志已确认 10 项核心测试通过**。包内不含已签名 IPA。GitHub Actions 配置负责运行逻辑测试、编译并输出待签名 IPA；只有构建成功后才能取得该产物。

## 本版操作

| 位置 / 手势 | 行为 |
|---|---|
| 左上角日期 | 显示当前照片拍摄日期；点击进入当天，再点返回原随机组和原浏览位置 |
| 右上角齿轮 | 换一组、照片权限、有限访问管理、触感、版本、操作说明 |
| 中央 Cover Flow | 随机最多 25 张；左右侧倾、中心放大；原生减速、吸附和弹性边界 |
| 上滑主照片 | 照片上移、缩小、淡出；右侧照片补位；最后一张则回退到左侧 |
| 左下角撤回 | 按标记顺序撤回，并恢复标记时的模式和照片位置 |
| 双击主照片 / 双指展开 | 动画进入全屏适屏原比例照片 |
| 全屏双指展开 / 收拢 | 原生 UIScrollView 连续缩放与拖动，收拢至适屏大小 |
| 全屏再次双击 | 以触点为中心放大 / 返回适屏 |
| 全屏适屏时下滑 | 跟手拖动并淡出背景，照片动画回到原卡片位置；放大状态下先捏回适屏 |
| 两种模式两端继续拉动 | 有前 / 后组时，拉过阈值松手，以弹簧动画切换，每组最多 25 张 |
| 右下角垃圾桶 | 回看待删除；左滑某项撤回，也可全部撤回；删除需两次 App 确认及系统删除授权 |

照片保持比例、不裁剪，以近似等面积排版并限制最大宽高。全屏“原图大小”按原比例适配屏幕理解，并非默认逐像素 1:1。放大清晰图按原比例请求，最长边最高 6000 像素，避免全尺寸超大照片带来过高内存占用。Live Photo 本版显示静态照片，视频不进入照片组。

当天模式以设备当前日历 / 时区划分日期，按拍摄时间升序排列；相同时间用资源 ID 稳定排序。从随机照片进入时，直接定位它所在的 25 张组。随机模式优先抽取尚未看过的照片；本轮看完后可重新抽取，但下一组不重复当前组。只有一组可浏览照片时，到边界只回弹。返回上一组时保留原组顺序；当日模式保持时间顺序，最后一组无下一组时只回弹。

## Windows + GitHub：建立新仓库并构建

这里需要新建 **Repository（代码仓库）**，不是 GitHub 的 Projects 看板。

1. 打开 https://github.com/new ，名称填写 `shiguang-flow-ios`，建议 Private。不勾选 README、.gitignore、License，因为源码包已有文件。点击 **Create repository**。
2. 解压源码包。进入包含 `ShiguangFlow.xcodeproj`、`ShiguangFlow`、`Package.swift`、`.github` 的那一层目录。
3. 安装 Git 后，在这个目录打开 PowerShell。把下方 `你的用户名` 换为 GitHub 用户名：

   ```powershell
   git init -b main
   git add .
   git commit -m "Initial standalone Shiguang Flow iOS app"
   git remote add origin https://github.com/你的用户名/shiguang-flow-ios.git
   git push -u origin main
   ```

   如果 Git 要求姓名和邮箱，按其提示配置后重试 commit。推送按 Git 提示完成 GitHub 登录。不要把凭据写进源码或仓库。

   **仅在全新解压的目录和新建空仓库中执行。不要在旧 App 的工作目录执行，也不要填旧仓库地址。** `git add .` 会包含 `.github`；不要只上传 ZIP，否则不会自动构建。
4. 仓库首页应直接看到 `ShiguangFlow.xcodeproj`、`ShiguangFlow`、`Sources`、`Tests`、`Package.swift` 和 `.github/workflows/build-ios.yml`，外面不要再套一层文件夹。
5. 点击 **Actions → Build Shiguang Flow**。首次推送会触发。也可在该页面选择 **Run workflow → main → Run workflow**。如果提示启用 Actions，先按页面提示启用。
6. 等所有步骤通过：逻辑测试 → 模拟器编译 → iPhone 编译 → 打包。失败时打开第一个红色步骤查看日志；失败不会生成可用 IPA。
7. 成功后在该次运行底部 **Artifacts** 下载 `ShiguangFlow-1.1.0-buildN-unsigned`。解压后才得到 `.ipa`；不要误选 GitHub 的源码 ZIP。

### 也可用 GitHub Desktop

先解压，再在 Desktop 的 **File → New repository** 新建一个新的本地仓库 `shiguang-flow-ios`。将解压目录内的全部内容（包括 `.github`）复制到该新本地仓库根目录，Commit 后选择 **Publish repository**。确认远程仓库为新名称。然后按上述第 5 步继续。若你已在网页建同名仓库，则应先 Clone 这个空仓库，再复制内容、Commit、Push。

### 安装到 iPhone

GitHub 生成的是 **unsigned IPA（未签名安装包）**，不能点击 IPA 直接安装。

- 可使用你已有的 Sideloadly 等签名工具给此 IPA 签名安装。选择本次 Artifacts 内最新 `.ipa`。
- 保留本应用的独立标识 `com.yang.shiguangflow.standalone`，或使用新的唯一标识，例如 `com.你的名称.shiguangflow`；**不要改成旧 App 的 Bundle ID**。
- 新图标和桌面名称是“拾光 Flow”。首次打开后点“允许访问照片”，选择允许全部或部分照片。有限访问可在设置中追加。
- 签名有效期、设备信任与开发者模式按你所用 Apple 账号和签名工具的实际提示处理。
- 在 App 右上角设置检查 `v1.1.0 (N)`。`N` 与 GitHub 的 buildN 一致；本地默认构建为 1。用这个号码核对是否安装了刚下载的版本。
- 已有 App 无需删除；两个 App 对同一个系统相册的实际删除操作会影响同一批照片。

## 有 Mac：Xcode 直接运行

1. 用 Xcode 16 或更高版本打开 `ShiguangFlow.xcodeproj`。
2. Target → Signing & Capabilities 选择自己的 Team；必要时将 Bundle ID 改为新的唯一 ID，保持与旧 App 不同。
3. Scheme 选 `ShiguangFlow`，选择已连接的 iPhone，点击 Run。
4. 照片权限被拒绝时，在“设置 → 拾光 Flow → 照片”调整，或点 App 中的权限按钮。

不需要从零创建 Xcode 工程；交付包已经包含 `.xcodeproj` 和共享 Scheme。

## 测试与结构

```bash
swift test
xcodebuild -project ShiguangFlow.xcodeproj -scheme ShiguangFlow \
  -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build
```

`swift test` 运行 14 项核心测试（P2 新增 4 项），覆盖随机 / 当日定位、跨页不丢失、最后一页删除、跨模式撤回、重新启动恢复标记、权限变化、缺失日期、空相册等。用户提供的 2026-09-20 GitHub Actions 日志已确认这 10 项核心测试全部通过（0 failures）；修复后的 iOS 编译仍需看新一次 CI 结果。

- `Sources/FlowCore/FlowSession.swift`：不依赖 UIKit 的分页、模式、标记 / 撤回状态。
- `ShiguangFlow/CoverFlowLayout.swift`：原生 UICollectionView 3D 排列、吸附、照片比例布局。
- `ShiguangFlow/PhotoViewer.swift`：全屏手势、原生缩放、交互下滑。
- `ShiguangFlow/FlowViewController.swift`：共享浏览器、转场、权限入口、删除确认。
- `ShiguangFlow/PhotoStore.swift`：PhotoKit 异步读取、取消过期请求、附近照片预缓存。
- `ShiguangFlow/BasketViewController.swift`：回看待删除、逐张恢复、全部恢复。
- `.github/workflows/build-ios.yml`：测试、双平台编译、构建号和 IPA 产物。
- `docs/ACCEPTANCE.md`：实机验收清单。
- `docs/VALIDATION.md`：本次交付的实际检查记录。

待删仅保存资源 ID 到本 App 的 UserDefaults，不保存或上传照片。照片读取由系统 PhotoKit 管理；iCloud 照片可能需要网络。系统删除成功后，App 内撤回不再适用，需使用系统相册的“最近删除”。

官方参考：
- 创建新仓库：https://docs.github.com/en/repositories/creating-and-managing-repositories/creating-a-new-repository
- 下载构建产物：https://docs.github.com/en/actions/how-tos/manage-workflow-runs/download-workflow-artifacts

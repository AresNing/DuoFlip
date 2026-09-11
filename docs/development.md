# 开发与验证

## 运行路径

`MenuBarApp.swift` 维护菜单栏生命周期、全局 Esc 和会议避让。`SettingsPopover.swift` 提供跟随系统外观的原生浮层，配置保存在本机 UserDefaults。关闭浮层不会退出应用。

`Sensor.swift` 使用 IOKit HID 读取翻盖角度，`Monitor.swift` 在专用队列约 30 Hz 采样。`Effect.swift` 平滑整数角度读数并通过 Core Image / Metal 呈现效果。`DesktopPolicy.swift` 控制正常展开后才允许触发、阈值回差和失效清理。

`Effect.swift` 中的 `LidAngles` 统一角度规则：滑块可选触发起点为 75°～125°（默认 90°、按整度保存），最大效果仍为 20°；准备、显示和退出阈值分别为起点 +5°、−2°、+1°。设置以 `triggerAngle` 存入 UserDefaults，修改后清除旧采样和覆盖层，重新等待展开；休眠恢复也使用同一准备阈值，暂停期间修改角度保持暂停状态。滑块和保存值校正共用 `range`，旧设置中的超界值也收敛到此范围。

`DesktopCapture.swift` 使用 ScreenCaptureKit，自动模式需要系统屏幕录制权限，手动模式遵循系统返回的单屏过滤器。两条路径均检查内置显示器。自动模式排除自身窗口，采集最大宽度 1920 像素、约 10 Hz、无音频。过渡期间冻结深拷贝的内存帧，结束后重新取得桌面画面。

`DesktopController.swift` 管理不激活应用的覆盖层。第一帧使用普通快照底图，在 Metal drawable 真正呈现后显示效果层，以避免黑色空帧闪烁。

为了保持已有用户的系统授权及偏好身份，初始独立仓库沿用 bundle identifier `local.codex.LidMotionLab`。不要在目录迁移时顺带改名；后续正式产品身份迁移需单独验证权限及设置迁移。

## 界面语言

`Localization.swift` 按系统首个受支持语言选择英文或简体中文，无匹配时使用英文。`interfaceLanguage` 仅保存应用内覆盖项（`system` / `en` / `zh-Hans`），不更改系统偏好。`Resources/*.lproj/Localizable.strings` 使用相同英文键；状态保留模板与参数，在显示时翻译，切换语言无需重建采集会话。新增状态时同步两个目录并保留 `%@` 占位符。

## 诊断

默认无日志。需要实机排查时，可显式指定仓库内被忽略的目录：

```sh
open --env "LID_LAB_VALIDATION_DIR=$PWD/validation" .build/DuoFlip.app --args --settings
```

诊断含角度、计数、尺寸、延迟及状态，不保存桌面像素。不要提交本机日志或用户截图。读取真实屏幕、访问传感器和开合操作不在 CI 内进行。

## 验证范围

独立仓库继承 0.7.0 的生产实现，迁移时不改变动画或授权策略。原型阶段实机确认过跟手、连续模糊、首帧闪黑修复、全局 Esc 关闭、菜单栏浮层及会议避让停止采集。历史私人日志留在原工作目录，不随仓库发布。

0.7.0 免选屏模式的权限不足路径已观察到；授予持续屏幕录制权限后的完整自动连接路径仍待专项实机验收。会议避让验证包括运行中启用规则后停止采集；尚未逐一运行各会议软件的真实共享场景。软件运行不代表正在开会或共享。

0.8.0 已验证中文系统默认、仅对应用进程指定英文语言的默认选择、手动中英文即时切换及重启保留选择；原生设置浮层无文字截断，语言与会议菜单不会残留旧翻译。67 条目录及嵌套状态插值检查、原有逻辑检查和 Metal 首帧显示检查通过。本轮未重新授予录屏权限或执行真实合盖采集，沿用以上采集与硬件验证边界。

触发角度改动（Unreleased）于 2026-09-11 在 macOS 26.6.2 / Mac16,8（arm64）完成 `scripts/test.sh --native` 和使用 ad-hoc 签名的 `scripts/build.sh`：可配置曲线、阈值回差、缺帧、重新展开、保存值越界校正、69 条本地化目录及生成棋盘格首帧检查通过。应用签名校验通过，构建内的第三方声明和许可证与源码一致。本轮未完成新构建的滑块鼠标/键盘交互、重启保留角度和真实合盖/休眠恢复验收；后续需覆盖 75°、90°、125°，以及过渡中和暂停时改值的场景。

日常检查：

1. `scripts/test.sh` 检查平滑连续性、反向/回零、角度范围、缺帧与失效恢复、会议软件标识与规则边界，以及本地化目录、系统语言优先级和动态状态翻译。
2. `scripts/build.sh` 构建完整应用并校验签名。
3. `scripts/test.sh --native` 使用生成棋盘格，延迟首帧并检查取消时不会重新显示过期层；需要已登录的图形会话和 Metal。
4. 改动采集、快捷键、Spaces 或传感器后，另做相应真实场景验证。逻辑检查和编译不能替代系统授权与硬件验证。

## 打包与发布

### README 演示素材

`./scripts/generate-demo.sh` 使用生产的 `EffectRenderer`、`MotionState`、`EffectMotion` 和 `DesktopPolicy`，生成 12 秒的开合演示。脚本只绘制示例桌面、输入模拟角度，不访问传感器或 ScreenCaptureKit，不采集音频。需要本机 Metal。

输出为 `docs/assets/duoflip-demo.en.mp4`（1600×1200、H.264、30 fps）及 README 内循环播放的 `duoflip-demo.en.gif`（800×600、15 fps）。默认素材为英文；另生成对应的 `duoflip-demo.zh-CN.mp4` 和 `duoflip-demo.zh-CN.gif`，供中文 README 使用。中间文件按语言留在忽略的 `.build/demo/`。这是可复现的动效示意，不替代真实硬件及窗口生命周期验证。英文首页使用显式 `.en` 文件名，避免沿用旧中文素材地址的缓存。原无语言后缀素材保留以兼容已分享的链接；Git 忽略规则仅对这些自有演示素材设例外。

视觉参考 [Apple MacBook Pro 产品展示](https://www.apple.com/macbook-pro/)，采用居中产品、浅色留白、柔和接触阴影和细金属边缘。屏幕依据 [14 英寸技术规格](https://www.apple.com/macbook-pro/specs/) 的 3024×1964 比例：生成桌面 1512×982，显示区域 1008×654⅔，横纵缩放均为 2/3，并在生成前断言比例一致。壁纸、窗口和机身均由代码绘制，不打包 Apple 官网图片；硬件外观为示意，不是精密三维模型。

### 应用安装包

`scripts/package.sh` 默认只在本地生成预览包，不上传。应用内包含第三方许可，DMG 和 ZIP 不含源码、原参考媒体或诊断记录。

如需 Developer ID 签名，设置 `LID_SIGNING_IDENTITY` 为钥匙串中已有的签名身份。只有同时显式设置 `LID_NOTARY_PROFILE` 时，脚本才会向 Apple 提交公证并装订票据。不要把证书、密钥或凭据放入仓库。参见 [Apple Developer ID](https://developer.apple.com/developer-id/)。

GitHub 源码发布与二进制 Release 分开：推送代码不会自动上传安装包或创建 Release。CI 不配置公证凭据，不操作开发者账号。

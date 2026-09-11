# Changelog

## Unreleased

- Add a persistent 75°–125° trigger-angle slider (default 90°, 1° steps), with matching animation, trigger and wake thresholds.
- Require a new open reading after angle changes; keep the ready status concise and omit the trigger-angle helper text.
- Clamp saved trigger angles to the slider's range, preserve the paused status when changing angles, and update bilingual packaged usage instructions.

## 0.8.0

- Add English and Simplified Chinese, with system-language defaults and persistent live switching in the menu bar popover.
- Localize settings, accessibility labels, capture status, meeting protection, and sensor errors.
- Make the default README and demo English; retain a Chinese README with its own matching demo.
- Add localization resolution, catalog parity, interpolation, and status re-rendering checks.

## 0.7.0

- 在系统权限有效时自动选择内置屏幕，保留手动选屏方式。
- 可配置飞书、腾讯会议、Zoom、Teams 运行时提前关闭效果。
- 自身采集中断、错误或持续无响应时关闭，不自动重试。
- 整理独立源码仓库、构建/测试/打包入口和第三方声明。

## 0.6.1

- 设置改为菜单栏下方原生浮层，不创建独立设置窗口。

## 0.6.0

- 左键单击菜单栏图标打开原生设置，加入持久化效果强度。

## 0.5.x

- 菜单栏常驻、全局 Esc 关闭效果、独立应用打包。
- 产品命名 DuoFlip，加入共享几何的应用及菜单栏图标。

## 早期原型

- 真实翻盖角度读取和桌面内存快照过渡。
- 连续模糊插值、首帧闪黑修复、暂停与恢复。

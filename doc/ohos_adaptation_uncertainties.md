# OHOS 适配待确认项（本地记录）

本文档记录本轮 OHOS 适配中，仍需最终确认的平台细节。代码已按“OHOS 独立分支 + 参考安卓行为”实现，但以下点请在合并前确认。

## 1. 动态链接器路径

- 目前将 OHOS 的动态链接器路径设为：
  - `arm-linux-ohoseabi -> /system/bin/linker`
  - `aarch64-linux-ohos -> /system/bin/linker64`
  - `x86_64-linux-ohos -> /system/bin/linker64`
- 位置：`lib/std/Target.zig` 的 `DynamicLinker.standard()`.
- 待确认：是否与当前 OHOS SDK/runtime 完全一致。

## 2. CRT 文件命名规则

- 目前为 OHOS 添加了独立分支，使用的 crt 文件名与 Android 对齐：
  - `crtbegin_so.o`, `crtbegin_dynamic.o`, `crtbegin_static.o`
  - `crtend_so.o`, `crtend_android.o`
- 位置：`lib/std/zig/LibCInstallation.zig`。
- 待确认：OHOS toolchain 中是否应使用 `crtend_android.o`，还是存在 OHOS 专用命名（例如 `crtend_ohos.o`）。

## 3. 头文件覆盖策略（OHOS overlay + musl fallback）

- 当前 `LibCDirs` 对 OHOS 的顺序为：
  1. `*-linux-ohos` / `*-linux-ohoseabi`
  2. `generic-ohos`
  3. `*-linux-musl`
  4. `generic-musl`
  5. `*-linux-any`
  6. `any-linux-any`
- 原因：`generic-ohos` 不是完整 libc 头集合，依赖 musl 公共头回退。
- 位置：`lib/std/zig/LibCDirs.zig`。
- 待确认：此顺序是否与 OHOS 预期完全一致（尤其是宏与结构体覆盖优先级）。

## 4. 部分架构 OHOS 头文件目录缺失

- 仓库当前存在：
  - `aarch64-linux-ohos`
  - `x86_64-linux-ohos`
  - `generic-ohos`
- 不存在：
  - `arm-linux-ohoseabi`
- 当前实现：
  - `ohoseabi` 头文件路径按 `*-linux-ohoseabi` 计算（避免和 `ohos` 混用）
  - 缺失目录时依赖 musl 架构目录作为回退
- 待确认：是否需要补齐缺失目录，或确认“仅 overlay + musl fallback”就是最终策略。

## 5. PIE 策略未强制改为 Android 行为

- 当前没有把 OHOS 加入“动态可执行必须 PIE”的强制条件。
- 位置：`src/Compilation/Config.zig`。
- 待确认：OHOS 是否和 Android 一样需要强制 PIE。

## 6. `available_libcs` 暂未加入 OHOS

- 这次没有把 OHOS 加入 `lib/std/zig/target.zig:available_libcs`。
- 原因：加入后会让系统误判为“Zig 可直接构建 OHOS libc”，但目前仍依赖 OHOS SDK 的 crt/so 布局。
- 当前通过 `LibCDirs.detect` 对 OHOS单独走“bundled headers”路径解决头文件问题。
- 待确认：后续是否要真正支持 Zig 原生构建 OHOS libc（若要，需要补齐 libs/crt 产物链路，而不只是 headers）。

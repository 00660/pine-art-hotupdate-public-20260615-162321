# Pine ART Hot Update - GitHub Actions 构建指南

## 概述

本仓库使用 GitHub Actions 同步 Android 12 AOSP 构建树，然后只构建 ART 模块的 APEX 热更新包，而不是完整的 ROM。这种方式：

- ✅ **构建范围小**：只编译 ART 模块，不构建 `otapackage`、`systemimage`、`bootimage` 等完整 ROM 目标
- ✅ **体积小**：APEX 文件只有几十 MB，而不是几百 MB 的 system.img
- ✅ **更新简单**：通过 `adb install --staged` 热更新，无需刷机
- ✅ **无缝集成**：保留原 ROM 的其他功能，只替换 ART 运行时

## 工作流程

```
1. 修改 patch → 2. Push 到 GitHub → 3. Actions 自动构建 → 4. 下载 APEX → 5. 安装到设备 → 6. 重启生效
```

## 触发构建

### 方式 1：自动触发（推送代码）

只要推送到 `main` 分支，GitHub Actions 会自动开始构建：

```bash
cd pine-art-hotupdate-public-20260615-162321
git add devices/pine/patches/art/android-12.0.0_r32/pine-art-registerdexfile-dump.patch
git commit -m "Update ART patch"
git push origin main
```

### 方式 2：手动触发（workflow_dispatch）

1. 打开仓库：`https://github.com/00660/pine-art-hotupdate-public-20260615-162321`
2. 进入 Actions 标签页
3. 选择 "Build pine Android 12 ART hot update"
4. 点击 "Run workflow"
5. 配置参数（可选，默认值已经适配 Android 12）：
   - `manifest_url`: 默认 `https://android.googlesource.com/platform/manifest`
   - `manifest_branch`: 默认 `android-12.0.0_r32`
   - `lunch_target`: 默认 `aosp_arm64-userdebug`
   - `build_targets`: 默认 `com.android.art`
   - `sync_jobs`: 默认 `4`
   - `build_jobs`: 默认 `2`
6. 点击 "Run workflow" 绿色按钮

## 构建过程

构建通常需要 **30-60 分钟**，包括以下步骤：

1. **清理磁盘空间** (~2 分钟)
   - 删除不需要的工具链
   - 释放约 40GB 空间

2. **安装依赖** (~5 分钟)
   - Android 构建工具链
   - ccache 加速

3. **同步 Android 源码** (~15 分钟或更久)
   - 同步 AOSP 构建树，保证 Soong/envsetup/lunch 能正确解析 ART 依赖
   - 使用 `--depth=1`、`--no-tags`、`--optimized-fetch` 减少下载量

4. **应用 ART patch** (~1 分钟)
   - 应用 `pine-art-registerdexfile-dump.patch`
   - 验证 patch 成功

5. **构建 ART 模块** (~20 分钟或更久)
   - 编译 `com.android.art` APEX
   - 生成 `.apex` 文件
   - 使用 `soong_ui.bash --make-mode --skip-soong-tests`，避免 GitHub runner 在 Soong bootstrap 自测阶段被 SIGTERM
   - 构建日志会上传到 `pine-art-build-diagnostics`，失败时优先看这个 artifact

6. **打包产物** (~1 分钟)
   - 收集所有 `.apex` 文件
   - 生成 SHA256 校验和
   - 创建 README

## 监控构建

### 查看实时日志

1. 打开仓库 Actions 页面
2. 点击正在运行的 workflow
3. 点击 `build-pine-art-rom` job
4. 展开各个步骤查看实时日志

### 常见构建状态

- 🟡 **Queued** - 等待 GitHub runner
- 🔵 **In progress** - 正在构建
- 🟢 **Success** - 构建成功
- 🔴 **Failure** - 构建失败

## 下载构建产物

### 方式 1：通过网页下载

1. 构建成功后，进入该 workflow run 页面
2. 滚动到底部 "Artifacts" 区域
3. 点击 `pine-art-hotupdate` 下载（保留 7 天）
4. 解压 zip 文件

### 方式 2：通过 GitHub CLI 下载（推荐）

```bash
# 列出最近的 runs
gh run list --repo 00660/pine-art-hotupdate-public-20260615-162321 --workflow "Build pine Android 12 ART hot update" --limit 5

# 下载最新成功的 artifact
gh run download --repo 00660/pine-art-hotupdate-public-20260615-162321 --name pine-art-hotupdate

# 或指定 run ID
gh run download <run-id> --repo 00660/pine-art-hotupdate-public-20260615-162321 --name pine-art-hotupdate
```

### 方式 3：通过 API 下载

```bash
# 获取 token
TOKEN=$(printf "protocol=https\nhost=github.com\n\n" | git credential fill 2>&1 | grep '^password=' | cut -d= -f2)

# 列出 runs
curl -H "Authorization: Bearer $TOKEN" \
     -H "Accept: application/vnd.github+json" \
     "https://api.github.com/repos/00660/pine-art-hotupdate-public-20260615-162321/actions/runs?per_page=5"

# 下载 artifact（需要从上面获取 artifact_id）
curl -L -H "Authorization: Bearer $TOKEN" \
     -H "Accept: application/vnd.github+json" \
     "https://api.github.com/repos/00660/pine-art-hotupdate-public-20260615-162321/actions/artifacts/<artifact_id>/zip" \
     -o pine-art-hotupdate.zip
```

## 产物内容

下载并解压后，你会得到：

```
pine-art-hotupdate/
├── files/
│   ├── com.android.art.debug.apex          # 主 ART APEX 文件
│   └── com.android.runtime.debug.apex      # Runtime APEX 文件（可选）
├── pine-art-build.env                      # 构建环境信息
├── pine-art-revision.txt                   # ART 源码版本
├── pine-art-rom-resolved-manifest.xml      # repo manifest
├── pine-art-rom-applied.diff               # 应用的 patch diff
├── apex-files.txt                          # APEX 文件列表
├── runtime-libs.txt                        # 运行时库列表
├── README.md                               # 说明文档
└── SHA256SUMS                              # 校验和
```

## 安装到设备

### 前置条件

- ✅ 7A 已连接到 PC（ADB 网络或 USB）
- ✅ 7A 已 root（能执行 `/debug_ramdisk/su`）
- ✅ 7A 运行 Android 12（PixelExtended 或兼容 ROM）

### 使用自动安装脚本

**Windows (PowerShell)**：

```powershell
cd pine-art-hotupdate-public-20260615-162321
.\devices\pine\scripts\install-pine-art-hotupdate.ps1 -ArtifactDir "..\..\pine-art-hotupdate" -DeviceSerial "192.168.2.103:5555"
```

**Linux/macOS (Bash)**：

```bash
cd pine-art-hotupdate-public-20260615-162321
chmod +x devices/pine/scripts/install-pine-art-hotupdate.sh
./devices/pine/scripts/install-pine-art-hotupdate.sh ../pine-art-hotupdate 192.168.2.103:5555
```

### 手动安装步骤

如果自动脚本失败，手动执行：

```bash
# 1. 连接设备
adb connect 192.168.2.103:5555

# 2. 创建 /data/temp 目录
adb shell su -c "mkdir -p /data/temp/pine-art-dumps"
adb shell su -c "chmod 0777 /data/temp /data/temp/pine-art-dumps"

# 3. 推送 APEX 文件
adb push pine-art-hotupdate/files/com.android.art.debug.apex /data/local/tmp/

# 4. 安装并 stage APEX
adb install --staged /data/local/tmp/com.android.art.debug.apex

# 5. 启用 DEX dump
adb shell setprop persist.sys.pine_art_dexdump true

# 6. 重启设备
adb reboot
```

## 验证安装

重启后验证 ART patch 是否生效：

```bash
# 1. 重新连接
adb connect 192.168.2.103:5555

# 2. 验证 /data/temp 目录
adb shell su -c "ls -ld /data/temp /data/temp/pine-art-dumps"

# 3. 测试 DEX dump
adb shell setprop persist.sys.pine_art_dexdump true
adb shell monkey -p com.android.settings 1
sleep 5

# 4. 查看输出
adb shell su -c "ls -lR /data/temp/pine-art-dumps/"

# 5. 检查日志
adb logcat -d | grep "pine ART dexdump"
```

期望看到：

```
I/art     (12345): pine ART dexdump wrote /data/temp/pine-art-dumps/com.android.settings/pid12345_102400_a1b2c3d4.dex
```

## 常见问题

### Q: 构建失败，提示磁盘空间不足

**A**: GitHub Actions runner 只有约 14GB 可用空间。Workflow 已经清理了不必要的文件。如果仍然失败，可能需要：
- 减少 `sync_jobs` 参数
- 使用更小的 `--depth` 值

### Q: 安装 APEX 后设备无法启动

**A**: 通过 TWRP 进入 recovery，执行：
```bash
adb shell rm -rf /data/apex/active/*
adb reboot
```

### Q: DEX dump 没有输出

**A**: 检查：
1. 系统属性是否设置：`adb shell getprop persist.sys.pine_art_dexdump`
2. ART 日志是否有错误：`adb logcat -d | grep art`
3. `/data/temp` 权限是否正确：`adb shell su -c "ls -ld /data/temp"`
4. SELinux 是否阻止：`adb shell su -c "dmesg | grep denied"`

### Q: 如何回滚 ART 更新

**A**: 通过 recovery 删除 staged APEX：
```bash
adb reboot recovery
# 在 recovery 中
adb shell rm -rf /data/apex/active/com.android.art*
adb reboot
```

## 性能优化

### 加速构建

1. **使用 ccache**（已启用）：首次构建慢，后续增量构建快
2. **增加并行任务**：如果 runner 性能好，可以提高 `build_jobs`
3. **缓存 repo 同步**：可以添加 actions/cache 缓存 `.repo/`

### 减少产物大小

当前 APEX 文件约 50-100MB。如果需要更小：
- 使用 `user` 构建变体而不是 `userdebug`
- 去除调试符号

## 下一步

安装并验证成功后：

1. 集成到 `pine-android12-unpack-internal-clean` 项目
2. 修改 `devices/pine/unpack-system/device/pine-run-dumper.sh` 收集 `/data/temp/pine-art-dumps/`
3. 测试完整的网页面板 → ADB 安装 → ART dump → 收集回传工作流

## 相关文档

- Workflow 配置：`.github/workflows/build-pine-art-rom.yml`
- ART Patch：`devices/pine/patches/art/android-12.0.0_r32/pine-art-registerdexfile-dump.patch`
- 快速参考：`../pine-android12-unpack-internal-clean-20260614/PINE-ART-QUICK-REF.md`
- 项目状态：`../pine-android12-unpack-internal-clean-20260614/PROJECT-STATUS-20260616.md`

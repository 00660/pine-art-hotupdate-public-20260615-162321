# Pine ART DEX Dump - /data/temp 版本修改总结

## 修改时间

2026-06-16

## 修改内容

### 2026-06-18 补充：OpenCommon 加载点覆盖

针对 `com.moutai.mall` 已能启动但 `/data/temp/pine-art-dumps/com.moutai.mall` 没有产出的现象，确认旧补丁只在 `ClassLinker::RegisterDexFile()` 且 `class_loader != nullptr` 时写出，覆盖面不足。

已更新 `devices/pine/patches/art/android-12.0.0_r32/pine-art-registerdexfile-dump.patch`：

- 新增 `libdexfile/dex/dex_file_loader.cc` 的 `DexFileLoader::OpenCommon()` dump 点。
- 支持 `dex` 与 `cdex` 头识别，输出后缀分别为 `.dex` 与 `.cdex`。
- `ClassLinker::RegisterDexFile()` 不再要求 `class_loader != nullptr`，并记录新建/复用来源。
- `.meta` 新增 `source=`，OpenCommon 产物额外新增 `kind=standard-dex|compact-dex`。
- 已用本地 Android 12 `art` 源码执行 `git apply --check`、实际 apply 和 `git diff --check` 验证通过。

验证目标：

```bash
adb shell setprop persist.sys.pine_art_dexdump true
adb shell setprop persist.sys.pine_art_dexdump_pkg com.moutai.mall
adb shell su -c "rm -rf /data/temp/pine-art-dumps/com.moutai.mall"
adb shell monkey -p com.moutai.mall -c android.intent.category.LAUNCHER 1
adb shell su -c "find /data/temp/pine-art-dumps/com.moutai.mall -maxdepth 1 -type f | head"
```

### 1. 核心 Patch 修改

**文件**：`devices/pine/patches/art/android-12.0.0_r32/pine-art-registerdexfile-dump.patch`

**变更**：
- 输出目录从 `/data/user/0/<pkg>/cache/pine-art-dumps/` 改为 `/data/temp/pine-art-dumps/<pkg>/`
- 目录权限从 `0700` 改为 `0777`（针对 `/data/temp` 及其子目录）
- 修改 `PineEnsureDir()` 函数，对 `/data/temp` 路径使用宽松权限

### 2. 新增文件

```
devices/pine/
├── ota/
│   ├── pine-art-dexdump-setup.sh          # OTA 包设置脚本
│   └── updater-script                     # TWRP/Recovery 刷机脚本
├── magisk-module/
│   ├── module.prop                        # Magisk 模块配置
│   └── post-fs-data.sh                    # Magisk 启动脚本
├── package-magisk-module.sh               # Magisk 模块打包脚本
└── DATA-TEMP-VERSION-README.md            # 详细使用说明
```

## 部署方案

### 方案 A：刷入修改后的 ROM（完整方案）

1. **构建 ROM**：
   - 使用修改后的 `pine-art-registerdexfile-dump.patch` 构建 ROM
   - 该 patch 会在 ART 加载 DEX 时自动 dump 到 `/data/temp/pine-art-dumps/<pkg>/`

2. **刷入 ROM 后创建目录**：
   ```bash
   adb shell su -c "mkdir -p /data/temp/pine-art-dumps && chmod 0777 /data/temp && chmod 0777 /data/temp/pine-art-dumps"
   ```

3. **启用 dump**：
   ```bash
   adb shell setprop persist.sys.pine_art_dexdump true
   adb shell setprop persist.sys.pine_art_dexdump_pkg com.target.app  # 可选
   ```

4. **启动应用并收集**：
   ```bash
   adb shell monkey -p com.target.app 1
   sleep 5
   adb pull /data/temp/pine-art-dumps/ ./dumps/
   ```

### 方案 B：Magisk 模块（推荐，最简单）

如果你的 7A 已经刷入了带 ART patch 的 ROM，只需安装 Magisk 模块自动创建目录：

1. **打包模块**（在 Linux/WSL 环境）：
   ```bash
   cd devices/pine/
   bash package-magisk-module.sh
   ```

2. **刷入模块**：
   ```bash
   adb push output/pine-art-dexdump-setup-magisk-v1.0.zip /sdcard/
   # 在 Magisk Manager 中刷入，重启
   ```

3. **验证**：
   ```bash
   adb shell su -c "ls -ld /data/temp /data/temp/pine-art-dumps"
   ```

### 方案 C：OTA 刷机包

1. **打包 OTA zip**（需要 ROM 构建环境或手动创建）：
   ```
   pine-art-dexdump-setup.zip
   ├── META-INF/
   │   └── com/google/android/
   │       ├── update-binary
   │       └── updater-script (使用 devices/pine/ota/updater-script)
   └── system/  (可选：包含设置脚本)
   ```

2. **TWRP 刷入**：
   ```bash
   adb push pine-art-dexdump-setup.zip /sdcard/
   # 在 TWRP 中刷入
   ```

## 使用流程

假设你已经：
- ✅ 刷入了带 ART patch 的 ROM
- ✅ 通过上述任一方案创建了 `/data/temp/pine-art-dumps/`

### 快速测试

```bash
# 1. 启用全局 dump
adb shell setprop persist.sys.pine_art_dexdump true

# 2. 启动目标应用
adb shell monkey -p com.example.target -c android.intent.category.LAUNCHER 1

# 3. 等待几秒，查看输出
adb shell su -c "ls -lR /data/temp/pine-art-dumps/"

# 4. 拉取结果
adb pull /data/temp/pine-art-dumps/com.example.target/ ./dumps/

# 5. 清理（可选）
adb shell su -c "rm -rf /data/temp/pine-art-dumps/*"
```

### 只 dump 特定应用

```bash
adb shell setprop persist.sys.pine_art_dexdump true
adb shell setprop persist.sys.pine_art_dexdump_pkg com.specific.app
```

### 禁用 dump

```bash
adb shell setprop persist.sys.pine_art_dexdump false
```

## 输出格式

```
/data/temp/pine-art-dumps/
└── com.example.app/
    ├── pid12345_102400_a1b2c3d4.dex
    ├── pid12345_102400_a1b2c3d4.dex.meta
    ├── pid12345_204800_e5f6g7h8.dex
    └── pid12345_204800_e5f6g7h8.dex.meta
```

`.meta` 文件内容：
```
package=com.example.app
pid=12345
location=/data/app/~~xxx/com.example.app/base.apk
size=102400
checksum=a1b2c3d4
```

## 与 pine-android12-unpack-internal-clean 集成

你提到 boot hook 已经刷入，现在只需要：

1. **构建 ART-patched ROM**：
   - 将此仓库的 `devices/pine/patches/art/android-12.0.0_r32/pine-art-registerdexfile-dump.patch` 应用到 PixelExtended ROM 的 ART 源码
   - 构建 system.img

2. **创建轻量级 OTA 包**：
   - 只包含 patched `system/framework/arm64/boot-framework.oat` 等 ART 相关文件
   - 加上 `devices/pine/ota/updater-script`

3. **集成到 unpack-system 面板**：
   - 修改 `devices/pine/unpack-system/device/pine-run-dumper.sh`，添加：
     ```bash
     # 收集 ART runtime dump
     if [ -d "/data/temp/pine-art-dumps/${PACKAGE}" ]; then
         cp -r "/data/temp/pine-art-dumps/${PACKAGE}" "${OUTPUT_DIR}/art-dumps/"
     fi
     ```

## 优势

1. **统一存储**：所有应用的 DEX 集中在 `/data/temp/pine-art-dumps/`
2. **跨应用访问**：`0777` 权限，root 工具可直接访问
3. **持久化**：不依赖应用 cache，应用卸载后数据仍在
4. **OTA 友好**：只需在刷机时创建一次目录
5. **简单清理**：`rm -rf /data/temp/pine-art-dumps/*`

## 下一步

你说 boot hook 已经刷了，现在你需要：

1. **构建带 ART patch 的 ROM**（主要工作）
2. **刷入 ROM**
3. **通过 Magisk 模块或手动创建 `/data/temp/pine-art-dumps/`**
4. **测试 dump 功能**

需要帮助构建 ROM 或集成到 GitHub Actions workflow 吗？

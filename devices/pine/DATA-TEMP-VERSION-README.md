# Pine ART DEX Dump - /data/temp 版本

修改后的 ART patch，将 DEX 输出到统一的 `/data/temp/pine-art-dumps/<package>/` 目录，便于制作 OTA 刷机包。

## 修改内容

相比原版 `pine-art-registerdexfile-dump.patch`，修改了以下部分：

### 1. 输出目录变更

**原版**：
```
/data/user/0/<package>/cache/pine-art-dumps/
```

**修改后**：
```
/data/temp/pine-art-dumps/<package>/
```

### 2. 目录权限调整

- `/data/temp` 及其子目录使用 `0777` 权限，允许跨应用访问
- `PineEnsureDir()` 函数会在创建目录后强制设置权限

### 3. 优势

- **不依赖应用 cache 目录**，避免应用卸载后数据丢失
- **统一集中存储**，便于批量收集和管理
- **适合 OTA 包**，只需在刷机时创建 `/data/temp` 即可
- **跨应用共享**，root 工具可以轻松访问所有应用的 dumps

## 使用方法

### 方案 A：刷入修改后的 ROM（推荐）

1. 使用修改后的 patch 构建包含 ART hook 的 ROM
2. 刷入 ROM 后，手动或通过 OTA 包创建目录：

```bash
adb shell
su
mkdir -p /data/temp/pine-art-dumps
chmod 0777 /data/temp
chmod 0777 /data/temp/pine-art-dumps
```

或使用 OTA 刷机包：

```bash
# 将 devices/pine/ota/ 下的文件打包成 flashable zip
# 通过 TWRP 刷入
```

### 方案 B：通过 Magisk/KernelSU 模块

如果你的 ROM 支持 Magisk 模块，可以创建一个 post-fs-data 脚本：

```bash
# /data/adb/modules/pine-art-dexdump/post-fs-data.sh
#!/system/bin/sh
mkdir -p /data/temp/pine-art-dumps
chmod 0777 /data/temp
chmod 0777 /data/temp/pine-art-dumps
```

## 启用 DEX dump

刷入 ROM 后，通过 adb 或终端设置系统属性：

```bash
# 启用全局 dump（所有应用）
adb shell setprop persist.sys.pine_art_dexdump true

# 或只 dump 特定应用
adb shell setprop persist.sys.pine_art_dexdump true
adb shell setprop persist.sys.pine_art_dexdump_pkg com.example.target

# 启动目标应用
adb shell monkey -p com.example.target -c android.intent.category.LAUNCHER 1

# 等待几秒，然后查看输出
adb shell su -c "ls -lR /data/temp/pine-art-dumps/"

# 拉取所有 dumps
adb pull /data/temp/pine-art-dumps/ ./dumps/
```

## 输出格式

每个 DEX 文件输出为：

```
/data/temp/pine-art-dumps/<package>/pid<pid>_<size>_<checksum>.dex
/data/temp/pine-art-dumps/<package>/pid<pid>_<size>_<checksum>.dex.meta
```

示例：

```
/data/temp/pine-art-dumps/com.example.app/
├── pid12345_102400_a1b2c3d4.dex
├── pid12345_102400_a1b2c3d4.dex.meta
├── pid12345_204800_e5f6g7h8.dex
└── pid12345_204800_e5f6g7h8.dex.meta
```

`.meta` 文件包含：

```
package=com.example.app
pid=12345
location=/data/app/~~xxx/com.example.app/base.apk
size=102400
checksum=a1b2c3d4
```

## 集成到 pine-android12-unpack-internal-clean

将此修改后的仓库内容复制到你的项目：

```bash
# 假设你在 pine-android12-unpack-internal-clean 目录
cp -r ../pine-art-hotupdate-public-20260615-162321/devices/pine/patches ./devices/pine/
cp -r ../pine-art-hotupdate-public-20260615-162321/devices/pine/ota ./devices/pine/
```

更新构建脚本，确保应用此 patch。

## 与现有 unpack-system 面板集成

修改 `devices/pine/unpack-system/device/pine-run-dumper.sh`，添加从 `/data/temp/pine-art-dumps/` 收集结果的逻辑：

```bash
# 收集 ART runtime dump 的 DEX
if [ -d "/data/temp/pine-art-dumps/${PACKAGE}" ]; then
    cp -r "/data/temp/pine-art-dumps/${PACKAGE}" "${OUTPUT_DIR}/art-dumps/"
fi
```

## 注意事项

1. **SELinux 上下文**：如果设备开启了 SELinux enforcing，可能需要额外的策略规则
2. **存储空间**：多个应用同时 dump 可能占用较多空间，建议定期清理
3. **权限**：ART 进程以应用 UID 运行，但因为目录权限是 0777，所以可以写入
4. **清理**：可以在每次测试前清空：`adb shell su -c "rm -rf /data/temp/pine-art-dumps/*"`

## 验证

刷入后验证目录创建成功：

```bash
adb shell su -c "ls -ld /data/temp /data/temp/pine-art-dumps"
```

期望输出：

```
drwxrwxrwx 3 root root 4096 2026-06-16 14:00 /data/temp
drwxrwxrwx 2 root root 4096 2026-06-16 14:00 /data/temp/pine-art-dumps
```

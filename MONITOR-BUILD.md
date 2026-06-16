# 快速监控构建

## 当前构建状态

**最新 run ID**: `27630460316`  
**状态**: `pending` (等待 runner)  
**触发 commit**: `75bdf60`  
**开始时间**: 2026-06-16 15:55:36 UTC

## 实时监控

### Windows (PowerShell)

```powershell
cd C:\Users\16547\Desktop\pine-art-hotupdate-public-20260615-162321
.\devices\pine\scripts\monitor-build.ps1
```

或监控特定 run：

```powershell
.\devices\pine\scripts\monitor-build.ps1 -RunId 27630460316
```

### Linux/macOS (Bash)

```bash
cd pine-art-hotupdate-public-20260615-162321
chmod +x devices/pine/scripts/monitor-build.sh
./devices/pine/scripts/monitor-build.sh
```

或监控特定 run：

```bash
./devices/pine/scripts/monitor-build.sh 27630460316
```

## 手动检查

### 通过网页

访问：`https://github.com/00660/pine-art-hotupdate-public-20260615-162321/actions`

### 通过 API

```bash
TOKEN=$(printf "protocol=https\nhost=github.com\n\n" | git credential fill 2>&1 | grep '^password=' | cut -d= -f2)

# 查看最新 run
curl -s -H "Authorization: Bearer $TOKEN" \
     -H "Accept: application/vnd.github+json" \
     "https://api.github.com/repos/00660/pine-art-hotupdate-public-20260615-162321/actions/runs?per_page=1" | \
grep -E '"id"|"status"|"conclusion"|"html_url"'
```

### 通过 gh CLI

```bash
# 安装 gh (如果没有)
# Windows: scoop install gh
# Linux: sudo apt install gh

# 列出最近的 runs
gh run list --repo 00660/pine-art-hotupdate-public-20260615-162321 --limit 5

# 查看特定 run 状态
gh run view 27630460316 --repo 00660/pine-art-hotupdate-public-20260615-162321

# 实时查看日志
gh run watch 27630460316 --repo 00660/pine-art-hotupdate-public-20260615-162321
```

## 构建时长

预计时间：**30-60 分钟**

- 清理磁盘：~2 分钟
- 安装依赖：~5 分钟
- 同步源码：~15 分钟
- 应用 patch：~1 分钟
- 构建 ART：~20-30 分钟
- 打包产物：~1 分钟

## 构建完成后

### 下载 artifact

**方式 1：gh CLI（推荐）**

```bash
gh run download 27630460316 --repo 00660/pine-art-hotupdate-public-20260615-162321 --name pine-art-hotupdate
```

**方式 2：网页**

1. 打开 `https://github.com/00660/pine-art-hotupdate-public-20260615-162321/actions/runs/27630460316`
2. 滚动到底部 "Artifacts"
3. 点击 `pine-art-hotupdate` 下载

### 安装到设备

```powershell
# Windows
.\devices\pine\scripts\install-pine-art-hotupdate.ps1 -ArtifactDir "pine-art-hotupdate"
```

```bash
# Linux/macOS
./devices/pine/scripts/install-pine-art-hotupdate.sh pine-art-hotupdate
```

## 常见状态

- 🟡 **queued** - 等待 GitHub runner（通常 1-5 分钟）
- 🔵 **in_progress** - 正在构建（30-60 分钟）
- 🟢 **success** - 构建成功，可以下载 artifact
- 🔴 **failure** - 构建失败，检查日志

## 如果构建失败

1. 查看失败日志：访问 run URL
2. 常见失败原因：
   - 磁盘空间不足
   - patch 应用失败
   - 依赖下载超时
3. 重新触发：
   ```bash
   # 在仓库页面 Actions -> 选择 workflow -> Re-run failed jobs
   ```

## 取消构建

如果需要取消正在运行的构建：

```bash
gh run cancel 27630460316 --repo 00660/pine-art-hotupdate-public-20260615-162321
```

或在网页界面点击 "Cancel workflow"。

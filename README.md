# Git Auto Sync

跨平台多仓库 Git 自动同步工具，支持 macOS / Windows / Linux。每天在指定时间自动检查、暂存、提交（带时间戳）并推送多个 Git 仓库。

## 功能

- ✅ 跨平台支持（macOS / Windows / Linux）
- ✅ 支持配置多个 Git 仓库
- ✅ 自动检查文件状态（暂存区 / 未暂存）
- ✅ 未暂存的变更自动加入暂存区
- ✅ 提交信息自动附带时间戳
- ✅ 先拉取远程变更（rebase 模式），再推送
- ✅ 详细的日志记录
- ✅ macOS 使用 launchd 定时，Windows 使用任务计划程序定时

## 文件结构

```
git-auto-sync/
├── git-auto-sync.py            # 主同步脚本（Python，跨平台）
├── git-repos.conf              # 仓库路径配置文件
├── setup-schedule-mac.sh       # macOS 定时任务设置脚本（launchd）
├── setup-schedule-windows.ps1  # Windows 定时任务设置脚本（任务计划程序）
├── logs/                       # 日志目录（自动创建）
└── README.md                   # 说明文档
```

## 前置条件

- **Python 3**（macOS 自带，Windows 需从 [python.org](https://python.org) 安装）
- **Git**（已安装并配置好远程仓库）
- **SSH 密钥或凭证**（确保 push 不需要手动输入密码）

## 快速开始

### 1. 配置仓库

编辑 `git-repos.conf`，每行填一个仓库路径：

```bash
# macOS / Linux
~/projects/my-app
~/work/backend-service

# Windows
~/projects/my-app
C:\Users\yourname\work\backend-service
```

### 2. 手动测试

```bash
# macOS / Linux
python3 git-auto-sync.py

# Windows
python git-auto-sync.py
```

### 3. 设置每天定时执行

脚本提供了自动化的定时任务设置工具，无需手动编辑系统配置。以下以 **每天 19:30 自动执行** 为例。

---

#### macOS（使用 setup-schedule-mac.sh）

**方式一：一键命令行设置（推荐）**

```bash
cd git-auto-sync

# 设置每天 19:30 执行
./setup-schedule-mac.sh "19:45"

# 如果使用自定义配置文件
./setup-schedule-mac.sh "19:30" ~/my-repos.conf
```

**方式二：交互式设置**

```bash
./setup-schedule-mac.sh
# 按提示输入：
#   执行时间 [默认 09:00]: 19:30
#   自定义配置文件路径？(留空使用默认): （直接回车）
```

设置完成后会自动创建 launchd 定时任务，输出类似：

```
[OK]  定时任务已加载！
==========================================
  设置完成！
  定时计划:  每天 19:30
  配置文件:  /Users/yourname/git-auto-sync/git-repos.conf
  日志目录:  /Users/yourname/git-auto-sync/logs/
==========================================
```

**验证任务是否生效：**

```bash
# 查看任务是否已注册
launchctl list | grep git-auto-sync

# 查看生成的 plist 文件
cat ~/Library/LaunchAgents/com.user.git-auto-sync.plist
```

**如果想改为其他时间，重新运行一次即可（会自动覆盖旧任务）：**

```bash
./setup-schedule-mac.sh "08:00"   # 改为每天 08:00
```

---

#### Windows（使用 setup-schedule-windows.ps1）

> ⚠️ 首次运行如果遇到执行策略限制，先执行：
> `Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned`

**方式一：一键命令行设置（推荐）**

```powershell
cd git-auto-sync

# 设置每天 19:30 执行
.\setup-schedule-windows.ps1 -Time "23:30"

# 如果使用自定义配置文件
.\setup-schedule-windows.ps1 -Time "19:30" -Config "C:\my-repos.conf"
```

**方式二：交互式设置**

```powershell
.\setup-schedule-windows.ps1
# 按提示输入：
#   执行时间 [默认 09:00]: 19:30
#   自定义配置文件路径？(留空使用默认): （直接回车）
```

设置完成后会自动创建 Windows 任务计划程序任务，输出类似：

```
[OK]  定时任务创建成功！
==========================================
  设置完成！
  定时计划:  每天 19:30
  配置文件:  C:\git-auto-sync\git-repos.conf
  日志目录:  C:\git-auto-sync\logs\
  任务名称:  GitAutoSync
==========================================
```

**验证任务是否生效：**

```powershell
# 查看任务详情
Get-ScheduledTask -TaskName GitAutoSync

# 也可以通过图形界面查看：
# Win+R → taskschd.msc → 任务计划程序库 → 找到 GitAutoSync
```

**如果想改为其他时间，重新运行一次即可（会自动覆盖旧任务）：**

```powershell
.\setup-schedule-windows.ps1 -Time "08:00"   # 改为每天 08:00
```

---

#### Linux（使用 crontab）

Linux 没有提供专用设置脚本，可手动添加 crontab 定时任务：

```bash
# 编辑 crontab
crontab -e

# 添加以下行：每天 19:30 执行（分 时 日 月 周 命令）
30 19 * * * /usr/bin/python3 /path/to/git-auto-sync/git-auto-sync.py >> /path/to/git-auto-sync/logs/cron.log 2>&1

# 保存退出后，查看是否添加成功
crontab -l
```

---

### 4. 定时任务管理

| 操作 | macOS | Windows |
|------|-------|---------|
| 查看任务状态 | `launchctl list \| grep git-auto-sync` | `Get-ScheduledTask -TaskName GitAutoSync` |
| 修改执行时间 | 重新运行 `./setup-schedule-mac.sh "新时间"` | 重新运行 `.\setup-schedule-windows.ps1 -Time "新时间"` |
| 移除定时任务 | `./setup-schedule-mac.sh --remove` | `.\setup-schedule-windows.ps1 -Remove` |
| 手动触发一次 | `python3 git-auto-sync.py` | `python git-auto-sync.py` |
| 立即触发定时任务 | `launchctl start com.user.git-auto-sync` | `Start-ScheduledTask -TaskName GitAutoSync` |

> **关机/休眠说明：** 如果在设定时间电脑处于关机或休眠状态，开机后系统会自动补执行一次（macOS launchd 和 Windows 任务计划程序均支持此特性）。

## 常用命令

### 查看日志

```bash
# macOS / Linux —— 查看今天日志
cat logs/git-sync-$(date +%Y-%m-%d).log

# macOS / Linux —— 实时跟踪日志
tail -f logs/git-sync-$(date +%Y-%m-%d).log

# Windows —— 查看今天日志
Get-Content "logs\git-sync-$(Get-Date -Format 'yyyy-MM-dd').log"

# Windows —— 实时跟踪日志
Get-Content "logs\git-sync-$(Get-Date -Format 'yyyy-MM-dd').log" -Wait
```

## 提交信息格式

```
auto-sync: 2026-07-04 09:30:12
```

## 工作流程

```
读取配置文件 → 遍历每个仓库：
  1. 验证路径和 Git 仓库
  2. 检查 origin 远程配置
  3. 获取当前分支
  4. git pull --rebase（失败回退 merge）
  5. git status --porcelain 检查变更
  6. git add -A（暂存未暂存的变更）
  7. git commit -m "auto-sync: 时间戳"
  8. git push origin 分支名
→ 输出汇总报告
```

## 注意事项

- 需要提前配置好 SSH 密钥或凭证，确保 push 不需要输入密码
- 如果 rebase 出现冲突，脚本会跳过该仓库并在日志中记录，不影响其他仓库
- macOS：如果电脑在设定时间处于关机/休眠状态，开机后 launchd 会自动补执行一次
- Windows：任务设置 `StartWhenAvailable`，错过时间后开机会自动补执行

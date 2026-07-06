<#
.SYNOPSIS
    Windows 定时任务设置脚本（任务计划程序）
    用于在 Windows 上创建每天定时执行 Git 同步的计划任务

.DESCRIPTION
    通过 Windows 任务计划程序（Task Scheduler）创建每日定时任务，
    自动运行 git-auto-sync.py 同步多个 Git 仓库。

.EXAMPLE
    # 交互式设置
    .\setup-schedule-windows.ps1

.EXAMPLE
    # 指定时间
    .\setup-schedule-windows.ps1 -Time "09:30"

.EXAMPLE
    # 指定时间 + 自定义配置文件
    .\setup-schedule-windows.ps1 -Time "09:30" -Config "C:\my-repos.conf"

.EXAMPLE
    # 移除定时任务
    .\setup-schedule-windows.ps1 -Remove
#>

param(
    # 执行时间（24小时制 HH:MM），不填则交互输入
    [string]$Time = "",

    # 自定义配置文件路径，不填则使用默认
    [string]$Config = "",

    # 移除定时任务
    [switch]$Remove
)

# ============================================================
# 配置项
# ============================================================

# 脚本所在目录
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Python 主同步脚本路径
$SyncScript = Join-Path $ScriptDir "git-auto-sync.py"

# 任务计划程序中的任务名称（唯一标识）
$TaskName = "GitAutoSync"

# ============================================================
# 辅助函数
# ============================================================

function Write-Info    { Write-Host "[INFO]  $args" }
function Write-WarnMsg { Write-Host "[WARN]  $args" -ForegroundColor Yellow }
function Write-ErrMsg  { Write-Host "[ERROR] $args" -ForegroundColor Red }
function Write-OK      { Write-Host "[OK]  $args" -ForegroundColor Green }

# ============================================================
# 处理移除任务
# ============================================================

if ($Remove) {
    Write-Info "正在移除定时任务..."
    $existingTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    if ($existingTask) {
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
        Write-OK "定时任务 '$TaskName' 已移除"
    } else {
        Write-WarnMsg "定时任务 '$TaskName' 不存在，无需移除"
    }
    exit 0
}

# ============================================================
# 解析时间参数
# ============================================================

# 交互模式：提示用户输入
if ([string]::IsNullOrWhiteSpace($Time)) {
    Write-Host ""
    Write-Host "=========================================="
    Write-Host "  Git Auto Sync - Windows 定时任务设置"
    Write-Host "=========================================="
    Write-Host ""
    Write-Host "将在 Windows 上创建每日定时任务（通过任务计划程序）"
    Write-Host ""
    Write-Host "请输入执行时间（24小时制，HH:MM）"
    Write-Host "例如: 09:30, 14:00, 23:00"
    Write-Host ""

    $Time = Read-Host "执行时间 [默认 09:00]"
    if ([string]::IsNullOrWhiteSpace($Time)) {
        $Time = "09:00"
    }

    $Config = Read-Host "自定义配置文件路径？(留空使用默认)"
}

# 校验时间格式 HH:MM
if ($Time -notmatch '^([01][0-9]|2[0-3]):([0-5][0-9])$') {
    Write-ErrMsg "时间格式无效: $Time（应为 HH:MM，如 09:30）"
    exit 1
}

# 拆分小时和分钟
$Hour, $Minute = $Time.Split(":")

# ============================================================
# 准备执行命令
# ============================================================

# 确认同步脚本存在
if (-not (Test-Path $SyncScript)) {
    Write-ErrMsg "同步脚本不存在: $SyncScript"
    exit 1
}

# 查找 python 路径（优先 python，其次 python3）
$PythonPath = (Get-Command python -ErrorAction SilentlyContinue).Source
if (-not $PythonPath) {
    $PythonPath = (Get-Command python3 -ErrorAction SilentlyContinue).Source
}
if (-not $PythonPath) {
    Write-ErrMsg "未找到 Python，请先安装 Python 3 并加入 PATH"
    exit 1
}

Write-Info "Python 路径: $PythonPath"

# 构建执行参数
$Arguments = "`"$SyncScript`""
if (-not [string]::IsNullOrWhiteSpace($Config)) {
    $Arguments += " `"$Config`""
}

Write-Info "执行命令: $PythonPath $Arguments"
Write-Info "定时计划: 每天 $Time"

# ============================================================
# 创建任务计划程序任务
# ============================================================

# 如果已存在同名任务，先删除
$existingTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if ($existingTask) {
    Write-Info "发现已有同名任务，正在更新..."
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
}

# 定义触发器：每天指定时间执行
$Trigger = New-ScheduledTaskTrigger -Daily -At "$Hour`:$Minute"

# 定义操作：运行 python 同步脚本
$Action = New-ScheduledTaskAction `
    -Execute $PythonPath `
    -Argument $Arguments `
    -WorkingDirectory $ScriptDir

# 定义设置：
#   - 允许任务按需运行
#   - 如果错过执行时间，开机后自动补执行
#   - 任务运行超时 30 分钟后自动停止
$Settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 30)

# 注册任务（以当前用户身份运行，不需要登录时也能执行）
try {
    Register-ScheduledTask `
        -TaskName $TaskName `
        -Trigger $Trigger `
        -Action $Action `
        -Settings $Settings `
        -Description "Git 多仓库自动同步任务 - 每天 $Time 执行" `
        -Force | Out-Null

    Write-OK "定时任务创建成功！"
} catch {
    Write-ErrMsg "定时任务创建失败: $_"
    Write-WarnMsg "请尝试以管理员身份运行 PowerShell 后重试"
    exit 1
}

# ============================================================
# 输出完成信息
# ============================================================

Write-Host ""
Write-Host "=========================================="
Write-Host "  设置完成！"
Write-Host "=========================================="
Write-Host ""
Write-Host "  定时计划:  每天 $Time"
Write-Host "  配置文件:  $ScriptDir\windows-git-repos.conf"
Write-Host "  日志目录:  $ScriptDir\logs\"
Write-Host "  任务名称:  $TaskName"
Write-Host ""
Write-Host "  移除任务:  .\setup-schedule-windows.ps1 -Remove"
Write-Host "  手动测试:  python git-auto-sync.py"
Write-Host "  查看任务:  Get-ScheduledTask -TaskName $TaskName"
Write-Host ""
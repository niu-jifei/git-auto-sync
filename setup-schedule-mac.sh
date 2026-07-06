#!/bin/bash
#
# macOS 定时任务设置脚本（launchd）
# 用于在 macOS 上创建每天定时执行 Git 同步的计划任务
#
# 使用方法：
#   ./setup-schedule-mac.sh                          # 交互式设置
#   ./setup-schedule-mac.sh "09:30"                  # 每天上午 09:30 执行
#   ./setup-schedule-mac.sh "09:30" "/path/to/conf"  # 指定时间 + 自定义配置
#
# 移除定时任务：
#   ./setup-schedule-mac.sh --remove
#

set -euo pipefail

# ============================================================
# 配置项
# ============================================================

# 脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Python 主同步脚本路径
SYNC_SCRIPT="$SCRIPT_DIR/git-auto-sync.py"

# launchd 任务标识符（唯一）
PLIST_LABEL="com.user.git-auto-sync"

# plist 文件存放目录和路径
PLIST_DIR="$HOME/Library/LaunchAgents"
PLIST_FILE="$PLIST_DIR/${PLIST_LABEL}.plist"

# ============================================================
# 辅助函数
# ============================================================

print_info()    { echo "[INFO]  $*"; }
print_warn()    { echo "[WARN]  $*"; }
print_error()   { echo "[ERROR] $*"; }
print_success() { echo "[✓]  $*"; }

# ============================================================
# 处理移除任务
# ============================================================

if [[ "${1:-}" == "--remove" || "${1:-}" == "-r" ]]; then
    print_info "正在移除定时任务..."
    launchctl unload "$PLIST_FILE" 2>/dev/null || true
    if [[ -f "$PLIST_FILE" ]]; then
        rm -f "$PLIST_FILE"
        print_success "plist 文件已删除"
    else
        print_warn "plist 文件不存在，无需移除"
    fi
    print_success "定时任务已移除"
    exit 0
fi

# ============================================================
# 解析时间参数
# ============================================================

SYNC_TIME="${1:-}"
CONFIG_ARG="${2:-}"

# 如果没有传参，进入交互模式
if [[ -z "$SYNC_TIME" ]]; then
    echo ""
    echo "=========================================="
    echo "  Git Auto Sync - macOS 定时任务设置"
    echo "=========================================="
    echo ""
    echo "将在 macOS 上创建每日定时任务（通过 launchd）"
    echo ""
    echo "请输入执行时间（24小时制，HH:MM）"
    echo "例如: 09:30, 14:00, 23:00"
    echo ""
    read -r -p "执行时间 [默认 09:00]: " SYNC_TIME
    SYNC_TIME="${SYNC_TIME:-09:00}"
    read -r -p "自定义配置文件路径？(留空使用默认): " CONFIG_ARG
fi

# 校验时间格式 HH:MM
if ! echo "$SYNC_TIME" | grep -qE '^[0-2][0-9]:[0-5][0-9]$'; then
    print_error "时间格式无效: $SYNC_TIME（应为 HH:MM，如 09:30）"
    exit 1
fi

# 拆分小时和分钟
HOUR="${SYNC_TIME%%:*}"
MINUTE="${SYNC_TIME##*:}"

if [[ "$HOUR" -gt 23 || "$MINUTE" -gt 59 ]]; then
    print_error "时间无效: $SYNC_TIME"
    exit 1
fi

# ============================================================
# 生成 plist 文件
# ============================================================

# 确认同步脚本存在
if [[ ! -f "$SYNC_SCRIPT" ]]; then
    print_error "同步脚本不存在: $SYNC_SCRIPT"
    exit 1
fi

# 查找 python3 路径
PYTHON_PATH="$(which python3)"
if [[ -z "$PYTHON_PATH" ]]; then
    print_error "未找到 python3，请先安装 Python 3"
    exit 1
fi

# 构建命令参数
SCRIPT_ARGS="$SYNC_SCRIPT"
if [[ -n "$CONFIG_ARG" ]]; then
    CONFIG_ARG="${CONFIG_ARG/#\~/$HOME}"
    SCRIPT_ARGS="$SYNC_SCRIPT $CONFIG_ARG"
fi

# 创建 launchd 目录
mkdir -p "$PLIST_DIR"

# 生成 plist 配置文件
# RunAtLoad=false: 不在加载时立即执行
# StartCalendarInterval: 每天指定时间执行
cat > "$PLIST_FILE" << PLIST_EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>${PLIST_LABEL}</string>

    <key>ProgramArguments</key>
    <array>
        <string>${PYTHON_PATH}</string>
        <string>${SCRIPT_ARGS}</string>
    </array>

    <key>StartCalendarInterval</key>
    <dict>
        <key>Hour</key>
        <integer>${HOUR}</integer>
        <key>Minute</key>
        <integer>${MINUTE}</integer>
    </dict>

    <key>StandardOutPath</key>
    <string>${SCRIPT_DIR}/logs/launchd-stdout.log</string>

    <key>StandardErrorPath</key>
    <string>${SCRIPT_DIR}/logs/launchd-stderr.log</string>

    <key>RunAtLoad</key>
    <false/>
</dict>
</plist>
PLIST_EOF

print_info "已创建 plist: $PLIST_FILE"
print_info "定时计划: 每天 ${HOUR}:${MINUTE}"
print_info "执行命令: ${PYTHON_PATH} ${SCRIPT_ARGS}"

# ============================================================
# 加载定时任务
# ============================================================

# 先卸载旧任务（如果已存在）
launchctl unload "$PLIST_FILE" 2>/dev/null || true

# 加载新任务
if launchctl load "$PLIST_FILE" 2>/dev/null; then
    print_success "定时任务已加载！"
else
    print_error "定时任务加载失败"
    print_warn "可手动加载: launchctl load \"$PLIST_FILE\""
    exit 1
fi

echo ""
echo "=========================================="
echo "  设置完成！"
echo "=========================================="
echo ""
echo "  定时计划:  每天 ${HOUR}:${MINUTE}"
echo "  配置文件:  ${SCRIPT_DIR}/git-repos.conf"
echo "  日志目录:  ${SCRIPT_DIR}/logs/"
echo "  plist:    ${PLIST_FILE}"
echo ""
echo "  移除任务:  ./setup-schedule-mac.sh --remove"
echo "  手动测试:  python3 git-auto-sync.py"
echo ""

#!/bin/bash
# launchd 包装脚本，用于捕获执行错误
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$SCRIPT_DIR/logs"
mkdir -p "$LOG_DIR"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] 包装脚本启动" >> "$LOG_DIR/wrapper.log"
echo "当前目录: $(pwd)" >> "$LOG_DIR/wrapper.log"
echo "PATH: $PATH" >> "$LOG_DIR/wrapper.log"
echo "Python 路径: $(which python3 2>&1)" >> "$LOG_DIR/wrapper.log"
echo "Python 版本: $(python3 --version 2>&1)" >> "$LOG_DIR/wrapper.log"
echo "脚本路径: $SCRIPT_DIR/git-auto-sync.py" >> "$LOG_DIR/wrapper.log"
echo "配置文件: $SCRIPT_DIR/mac-git-repos.conf" >> "$LOG_DIR/wrapper.log"
echo "配置文件存在: $([ -f "$SCRIPT_DIR/mac-git-repos.conf" ] && echo '是' || echo '否')" >> "$LOG_DIR/wrapper.log"

/usr/bin/python3 "$SCRIPT_DIR/git-auto-sync.py" "$SCRIPT_DIR/mac-git-repos.conf" >> "$LOG_DIR/wrapper.log" 2>&1
EXIT_CODE=$?

echo "[$(date '+%Y-%m-%d %H:%M:%S')] 执行完成，退出码: $EXIT_CODE" >> "$LOG_DIR/wrapper.log"
exit $EXIT_CODE

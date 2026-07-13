#!/bin/bash
#
# macOS Git 同步快捷脚本
# 通过 python3 执行 git-auto-sync.py，使用 mac-git-repos.conf 配置文件
#
# 使用方法：
#   ./mac-sync.sh                    # 使用默认配置文件
#   ./mac-sync.sh /path/to/config    # 使用自定义配置文件
#

# 脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Python 同步脚本路径
SYNC_SCRIPT="$SCRIPT_DIR/git-auto-sync.py"

# 默认配置文件
DEFAULT_CONFIG="$SCRIPT_DIR/mac-git-repos.conf"

# 如果传入了配置文件参数则使用传入的，否则使用默认配置
CONFIG_FILE="${1:-$DEFAULT_CONFIG}"

# 查找 python3
PYTHON_PATH="$(which python3)"
if [[ -z "$PYTHON_PATH" ]]; then
    echo "[ERROR] 未找到 python3，请先安装 Python 3"
    exit 1
fi

# 检查同步脚本是否存在
if [[ ! -f "$SYNC_SCRIPT" ]]; then
    echo "[ERROR] 同步脚本不存在: $SYNC_SCRIPT"
    exit 1
fi

# 执行同步脚本
echo "[INFO] 开始执行 Git 同步..."
echo "[INFO] 配置文件: $CONFIG_FILE"
"$PYTHON_PATH" "$SYNC_SCRIPT" "$CONFIG_FILE"

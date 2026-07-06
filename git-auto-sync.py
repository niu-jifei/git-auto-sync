#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Git Auto Sync —— 跨平台多仓库自动同步脚本

功能概述：
  1. 读取配置文件中的多个 Git 仓库路径
  2. 对每个仓库依次执行：拉取远程 → 检查变更 → 暂存 → 提交（带时间戳） → 推送
  3. 支持 macOS / Windows / Linux

使用方法：
  python git-auto-sync.py                     # 使用默认配置 git-repos.conf
  python git-auto-sync.py /path/to/config     # 使用自定义配置文件

配置文件格式（每行一个仓库路径）：
  ~/projects/my-app
  ~/work/backend-service
  # 以 # 开头的行为注释，空行会被忽略
"""

import os
import sys
import subprocess
import platform
from datetime import datetime
from pathlib import Path

# ============================================================
# 全局配置
# ============================================================

# 脚本所在目录（用于定位默认配置文件和日志目录）
SCRIPT_DIR = Path(__file__).resolve().parent

# 默认配置文件路径（可通过命令行参数覆盖）
DEFAULT_CONFIG = SCRIPT_DIR / "git-repos.conf"

# 日志目录（自动创建）
LOG_DIR = SCRIPT_DIR / "logs"

# 提交信息前缀，最终格式为 "auto-sync: 2026-07-04 09:30:12"
COMMIT_PREFIX = "auto-sync"


# ============================================================
# 日志工具函数
# ============================================================

def get_log_file():
    """
    获取日志文件路径（单一文件）。
    格式：logs/git-sync.log
    """
    LOG_DIR.mkdir(parents=True, exist_ok=True)
    return LOG_DIR / "git-sync.log"


def cleanup_old_logs():
    """
    清理日志文件中超过 7 天的记录。
    通过解析每行开头的时间戳 [YYYY-MM-DD HH:MM:SS] 判断是否过期。
    """
    log_file = get_log_file()
    if not log_file.exists():
        return

    cutoff = datetime.now().timestamp() - 7 * 24 * 3600  # 7 天前的时间戳
    kept_lines = []

    with open(log_file, "r", encoding="utf-8") as f:
        for line in f:
            # 尝试从行首解析时间戳 [YYYY-MM-DD HH:MM:SS]
            try:
                if line.startswith("[") and len(line) > 20:
                    ts_str = line[1:20]  # 提取 "YYYY-MM-DD HH:MM:SS"
                    line_time = datetime.strptime(ts_str, "%Y-%m-%d %H:%M:%S")
                    if line_time.timestamp() >= cutoff:
                        kept_lines.append(line)
                else:
                    # 非日志行（如分隔线等无时间戳的行），保留
                    kept_lines.append(line)
            except ValueError:
                # 解析失败的行保留
                kept_lines.append(line)

    with open(log_file, "w", encoding="utf-8") as f:
        f.writelines(kept_lines)


def log(level, message):
    """
    输出带时间戳和级别的日志，同时写入文件。
    level: INFO / WARN / ERROR
    """
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    line = f"[{timestamp}] [{level}] {message}"
    print(line)
    # 追加写入日志文件
    with open(get_log_file(), "a", encoding="utf-8") as f:
        f.write(line + "\n")


def log_info(msg):     log("INFO", msg)
def log_warn(msg):     log("WARN", msg)
def log_error(msg):    log("ERROR", msg)
def log_separator():
    """输出分隔线，便于日志阅读"""
    log_info("-" * 40)


# ============================================================
# Git 命令封装
# ============================================================

def run_git(repo_path, *args):
    """
    在指定仓库目录下执行 git 命令。
    返回 (return_code, stdout, stderr) 三元组。
    """
    result = subprocess.run(
        ["git"] + list(args),
        cwd=repo_path,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    return result.returncode, result.stdout.strip(), result.stderr.strip()


def run_git_quiet(repo_path, *args):
    """
    执行 git 命令，仅返回是否成功（return_code == 0）。
    用于不需要解析输出的场景。
    """
    code, _, _ = run_git(repo_path, *args)
    return code == 0


# ============================================================
# 核心同步逻辑
# ============================================================

def sync_repo(repo_path):
    """
    同步单个 Git 仓库。

    处理流程：
      1. 验证路径是否为有效的 Git 仓库
      2. 检查是否配置了 origin 远程
      3. 获取当前分支（跳过 detached HEAD 状态）
      4. 检查工作区状态，将所有文件加入版本控制并提交本地变更
      5. 拉取远程变更合并到本地（rebase 优先，失败回退 merge）
      6. 推送到远程

    返回: True 表示成功，False 表示失败
    """
    repo_name = os.path.basename(repo_path)

    log_separator()
    log_info(f"处理仓库: {repo_name} ({repo_path})")

    # --- 1. 验证路径 ---
    if not os.path.isdir(repo_path):
        log_error(f"目录不存在: {repo_path}")
        return False

    if not os.path.isdir(os.path.join(repo_path, ".git")):
        log_error(f"不是 Git 仓库: {repo_path}")
        return False

    # --- 2. 检查远程配置 ---
    code, remote_url, _ = run_git(repo_path, "remote", "get-url", "origin")
    if code != 0 or not remote_url:
        log_error(f"未配置 'origin' 远程: {repo_path}")
        return False
    log_info(f"远程地址: {remote_url}")

    # --- 3. 获取当前分支 ---
    code, current_branch, _ = run_git(repo_path, "rev-parse", "--abbrev-ref", "HEAD")
    if code != 0 or not current_branch or current_branch == "HEAD":
        log_error(f"处于 detached HEAD 状态，跳过: {repo_path}")
        return False
    log_info(f"当前分支: {current_branch}")

    # --- 4. 检查工作区状态，提交本地变更 ---
    # git status --porcelain 输出格式：每行前两个字符表示状态
    #   第1个字符：暂存区（index）状态
    #   第2个字符：工作区（working tree）状态
    #   空格表示无变更
    code, porcelain_output, _ = run_git(repo_path, "status", "--porcelain")
    has_local_changes = bool(porcelain_output.strip())

    if has_local_changes:
        lines = [l for l in porcelain_output.strip().split("\n") if l.strip()]
        log_info(f"检测到本地变更: 共 {len(lines)} 个文件")

        # 将所有文件加入版本控制（包括新增、修改、删除）
        log_info("将所有文件加入版本控制 (git add -A)...")
        if not run_git_quiet(repo_path, "add", "-A"):
            log_error("git add -A 失败")
            return False
        log_info("所有文件已暂存")

        # 确认暂存区有内容可提交
        code, staged_files, _ = run_git(repo_path, "diff", "--cached", "--name-only")
        if staged_files.strip():
            commit_time = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
            commit_msg = f"{COMMIT_PREFIX}: {commit_time}"
            log_info(f"提交本地变更: '{commit_msg}'")
            if not run_git_quiet(repo_path, "commit", "-m", commit_msg):
                log_error("提交失败")
                return False
            code, commit_hash, _ = run_git(repo_path, "rev-parse", "--short", "HEAD")
            log_info(f"已提交: {commit_hash}")
        else:
            log_info("暂存区为空，无需提交")
    else:
        log_info("工作区干净，无本地变更")

    # --- 5. 拉取远程变更 ---
    # 先提交本地再合并远程，减少冲突风险
    log_info("拉取远程变更 (rebase 模式)...")
    if not run_git_quiet(repo_path, "pull", "--rebase", "origin", current_branch):
        log_warn("rebase 拉取失败，尝试 merge 模式...")
        run_git_quiet(repo_path, "rebase", "--abort")
        if not run_git_quiet(repo_path, "pull", "--no-rebase", "origin", current_branch):
            log_error("拉取远程变更失败，可能存在冲突，跳过此仓库")
            return False

    # --- 6. 推送到远程 ---
    log_info(f"推送到 origin/{current_branch}...")
    if not run_git_quiet(repo_path, "push", "origin", current_branch):
        log_error("推送失败")
        return False

    log_info(f"推送成功，仓库 '{repo_name}' 同步完成")
    return True


# ============================================================
# 配置文件解析
# ============================================================

def load_repos(config_path):
    """
    从配置文件中读取仓库路径列表。

    处理规则：
      - 跳过空行
      - 跳过以 # 开头的注释行
      - 去除首尾空格
      - 将 ~ 展开为用户主目录（跨平台兼容）

    返回: 仓库路径列表
    """
    repos = []
    with open(config_path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            # 跳过空行和注释
            if not line or line.startswith("#"):
                continue
            # 展开 ~ 为用户主目录（macOS/Linux: ~/，Windows: %USERPROFILE%\）
            if line.startswith("~"):
                line = os.path.join(os.path.expanduser("~"), line[1:].lstrip("/").lstrip("\\"))
            repos.append(line)
    return repos


# ============================================================
# 主入口
# ============================================================

def main():
    """
    主函数：读取配置 → 遍历仓库 → 逐个同步 → 输出汇总报告
    """
    # 确定配置文件路径（命令行参数 or 默认）
    config_file = sys.argv[1] if len(sys.argv) > 1 else str(DEFAULT_CONFIG)

    # 清理超过 7 天的旧日志记录
    cleanup_old_logs()

    log_separator()
    log_info("===== Git Auto Sync 启动 =====")
    log_info(f"操作系统: {platform.system()} {platform.release()}")
    log_info(f"配置文件: {config_file}")

    # 验证配置文件存在
    if not os.path.isfile(config_file):
        log_error(f"配置文件不存在: {config_file}")
        log_error("请创建配置文件，每行填入一个仓库路径")
        sys.exit(1)

    # 检查 git 是否可用
    try:
        subprocess.run(["git", "--version"], capture_output=True, check=True)
    except (FileNotFoundError, subprocess.CalledProcessError):
        log_error("Git 未安装或不在 PATH 中")
        sys.exit(1)

    # 读取仓库列表
    repos = load_repos(config_file)

    # 逐个同步
    total = len(repos)
    success = 0
    failed = 0

    for repo_path in repos:
        if sync_repo(repo_path):
            success += 1
        else:
            failed += 1

    # 输出汇总
    log_separator()
    log_info("===== 同步汇总 =====")
    log_info(f"仓库总数: {total}")
    log_info(f"成功: {success}")
    log_info(f"失败: {failed}")
    log_info("===== Git Auto Sync 结束 =====")

    # 有失败则退出码为 1
    sys.exit(1 if failed > 0 else 0)


if __name__ == "__main__":
    main()

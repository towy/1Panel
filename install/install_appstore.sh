#!/bin/bash         
set -euo pipefail    
    
# --- 全局变量与常量定义 ---     
declare -a OFFICIAL_REPOS    
OFFICIAL_REPOS=(     
  "https://github.com/1Panel-dev/appstore dev"     
)     
    
declare -a THIRD_PARTY_REPOS    
THIRD_PARTY_REPOS=(     
  "https://github.com/okxlin/appstore localApps"     
  "https://github.com/QYG2297248353/appstore-1panel custom"     
)     
    
# 全局标志    
DEBUG_MODE=0    
FORCE_UPDATE_MODE=0    
    
# 全局临时工作目录变量，确保 trap 可以访问    
tmp_work_dir=""     
    
# 新增: 使用单一关联数组来追踪所有已暂存的应用，以强制执行优先级    
declare -A STAGED_APPS    

# 全局：1Panel 安装路径 & 目标应用目录
install_path=""
apps_target_dir=""

# --- 函数定义 ---     
    
# 打印错误信息并退出    
die() {     
  echo >&2 "错误: $1"     
  exit 1    
}     
    
# 打印调试信息（仅在调试模式下）     
debug_log() {     
  if [[ "${DEBUG_MODE}" -eq 1 ]]; then    
    echo >&2 "DEBUG: $1"     
  fi    
}     

# 选择 / 确认 1Panel 安装路径（供多次调用，配合菜单的“返回上一级”）
select_install_path() {
  local confirm install_dir

  install_path="/opt/1panel"
  read -p "1Panel 安装路径是否为 /opt/1panel? [Y/n] " confirm
  confirm=${confirm:-Y}
  if [[ ! ( "$confirm" == "y" || "$confirm" == "Y" ) ]]; then
    read -p "请输入 1Panel 的安装根目录 (例如 /opt): " install_dir
    install_path="${install_dir%/}/1panel"
  fi

  if [[ ! -d "$install_path" ]]; then
    die "1Panel 安装路径不存在: $install_path"
  fi
}

# 核心函数：处理单个应用仓库，并将其内容放入暂存区    
# 参数: $1 repo_url, $2 branch, $3 repo_work_dir, $4 staging_dir    
process_app_repo() {     
  local repo_url="$1"     
  local branch="$2"     
  local repo_work_dir="$3"     
  local staging_dir="$4"     
      
  local repo_name_unique    
  repo_name_unique=$(echo "$repo_url" | sed -E 's|https?://[^/]+/([^/]+/[^/]+).*|\1|g' | tr '/' '-')     
  local repo_path="${repo_work_dir}/${repo_name_unique}"     
    
  debug_log "正在处理仓库: ${repo_name_unique}"     
    
  if [[ ! -d "$repo_path" ]]; then    
    echo "克隆仓库: ${repo_name_unique} (分支: ${branch})..."     
    git clone -q --depth 1 -b "$branch" "$repo_url" "$repo_path"     
  else    
    echo "更新仓库: ${repo_name_unique} (分支: ${branch})..."     
    (     
      cd "$repo_path" && git fetch -q origin "$branch" && git reset -q --hard "origin/${branch}"     
    ) || die "更新仓库失败: ${repo_path}"     
  fi     
    
  local source_app_dir="${repo_path}/apps"     
  if [[ ! -d "$source_app_dir" ]]; then    
    echo "警告: 在仓库 ${repo_name_unique} 中未找到 'apps' 目录，跳过。"     
    return    
  fi     
    
  echo "从 ${repo_name_unique} 收集应用到暂存区..."     
  while IFS= read -r -d '' app_path; do    
    local app_name    
    app_name=$(basename "$app_path")     
    
    # 统一的优先级检查逻辑：     
    # 如果该应用名已存在于 STAGED_APPS 数组中，说明它已被一个    
    # 更高优先级的仓库（因为我们是按顺序处理的）添加到暂存区。     
    if [[ -v STAGED_APPS["$app_name"] ]]; then    
      echo "  -> 跳过: 应用 '${app_name}' 已由更高优先级的源提供。"     
      continue    
    fi     
    
    # 这是第一次遇到此应用，将其添加到暂存区并记录    
    cp -rf "$app_path" "$staging_dir/"     
    STAGED_APPS[""$app_name""]=1 # 标记此应用已被处理    
    debug_log "已将应用 '${app_name}' 从 '${repo_name_unique}' 添加到暂存区。"     
    
  done < <(find "$source_app_dir" -mindepth 1 -maxdepth 1 -type d -print0)     
}     
    
# 同步函数，将暂存区内容应用到最终目标目录    
# 参数: $1 staging_dir, $2 final_dest_dir, $3 force_mode (0/1)     
sync_to_destination() {     
  local staging_dir="$1"     
  local final_dest_dir="$2"     
  local force_mode="$3"     
    
  echo "--------------------------------------------------"     
  echo "开始将暂存区内容同步到目标目录: ${final_dest_dir}"     
    
  if [ -z "$(ls -A "$staging_dir")" ]; then    
    echo "暂存区为空，无需同步。"     
    return    
  fi     
    
  for staged_app_path in "${staging_dir}"/*; do    
    if [[ ! -d "$staged_app_path" ]]; then continue; fi     
    
    local app_name    
    app_name=$(basename "$staged_app_path")     
    local final_app_path="${final_dest_dir}/${app_name}"     
    
    if [[ -d "$final_app_path" ]]; then    
      # 目标目录已存在    
      if [[ "$force_mode" -eq 1 ]]; then    
        echo "  -> 强制更新: ${app_name}"     
        rm -rf "$final_app_path"     
        cp -rf "$staged_app_path" "$final_dest_dir/"     
      else    
        echo "  -> 跳过已存在的应用: ${app_name}"     
      fi    
    else    
      # 目标目录不存在，直接安装    
      echo "  -> 安装新应用: ${app_name}"     
      cp -rf "$staged_app_path" "$final_dest_dir/"     
    fi    
  done    
}     
    
# --- 主逻辑 ---     
main() {     
  local official_only=false    
    
  # --- 参数解析 ---     
  while [[ $# -gt 0 ]]; do    
    case "$1" in    
      -o|--official) official_only=true; shift ;;     
      -d|--debug) DEBUG_MODE=1; shift ;;     
      -f|--force) FORCE_UPDATE_MODE=1; shift ;;     
      *) die "未知参数: $1" ;;     
    esac    
  done    
    
  # --- 选择 1Panel 安装路径 ---     
  select_install_path

  # --- 新增：选择安装到 local 还是 remote 的菜单 ---  
  while true; do
    echo "--------------------------------------------------"
    echo "请选择应用安装目标目录："
    echo "  1) local  (安装到: \${install_path}/resource/apps/local)"
    echo "  2) remote (安装到: \${install_path}/resource/apps/remote)"
    echo "  3) 返回上一级，重新选择 1Panel 安装路径"
    echo "  4) 退出脚本"
    read -rp "请输入数字 [1-4]: " choice

    case "$choice" in
      1)
        apps_target_dir="${install_path}/resource/apps/local"
        ;;
      2)
        # 如果你的 remote 目录不是这个路径，改这里
        apps_target_dir="${install_path}/resource/apps/remote"
        ;;
      3)
        # 重新选择安装路径，然后回到菜单
        select_install_path
        continue
        ;;
      4)
        echo "已退出脚本。"
        exit 0
        ;;
      *)
        echo "无效选项，请重试。"
        continue
        ;;
    esac

    # 选了 1 或 2 时跳出循环，继续执行
    break
  done

  mkdir -p "$apps_target_dir"

  # --- 创建并注册临时工作目录 ---     
  tmp_work_dir=$(mktemp -d -t 1panel_app_update.XXXXXX)     
  trap 'echo "清理临时工作目录: ${tmp_work_dir}"; rm -rf "${tmp_work_dir}";' EXIT    
      
  local repo_work_dir="${tmp_work_dir}/repos"     
  local staging_dir="${tmp_work_dir}/staging"     
  mkdir -p "$repo_work_dir" "$staging_dir"     
      
  echo "临时工作目录位于: ${tmp_work_dir}"     
  echo "应用目标目录位于: ${apps_target_dir}"     
  if [[ "${FORCE_UPDATE_MODE}" -eq 1 ]]; then    
    echo "模式: 强制更新 (将覆盖目标目录中的同名应用)"     
  fi    
  echo "--------------------------------------------------"     
    
  # --- 阶段一: 收集应用到暂存区 (严格按优先级) ---     
  echo "阶段 1: 从所有源收集应用到暂存区..."     
  # 首先处理官方仓库，它们拥有最高优先级    
  for repo_info in "${OFFICIAL_REPOS[@]}"; do    
    read -r -a repo_parts <<< "$repo_info"     
    process_app_repo "${repo_parts[0]}" "${repo_parts[1]}" "$repo_work_dir" "$staging_dir"     
  done     
    
  # 然后按顺序处理第三方仓库    
  if [[ "$official_only" == false ]]; then    
    echo "---"     
    for repo_info in "${THIRD_PARTY_REPOS[@]}"; do    
      read -r -a repo_parts <<< "$repo_info"     
      process_app_repo "${repo_parts[0]}" "${repo_parts[1]}" "$repo_work_dir" "$staging_dir"     
    done    
  fi    
  echo "阶段 1 完成。"     
    
  # --- 阶段二: 从暂存区同步到最终目标 ---     
  echo ""     
  echo "阶段 2: 将暂存区的应用同步到最终目录..."     
  sync_to_destination "$staging_dir" "$apps_target_dir" "$FORCE_UPDATE_MODE"     
  echo "阶段 2 完成。"     
      
  echo "--------------------------------------------------"     
  echo "所有操作已完成。"     
}     
    
# 将所有命令行参数传递给主函数     
main "$@" 

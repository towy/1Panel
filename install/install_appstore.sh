#!/bin/bash

# 检查 git 是否安装
if ! command -v git &> /dev/null; then
    echo "git 未安装，请先安装 git。"
    exit 1
fi

# 解析参数
while [[ $# -gt 0 ]]; do
  case $1 in
    -o|--official)
      official_only=true
      shift
      ;;
    *)
      echo "未知参数: $1"
      exit 1
      ;;
  esac
done

# 获取 1Panel 安装路径
read -p "1Panel 安装路径是否为 /opt/1panel? [Y/n] " confirm
confirm=${confirm:-Y}  # 默认为 Y

if [[ $confirm == "y" || $confirm == "Y" ]]; then
    install_path="/opt/1panel"
else
    read -p "请输入 1Panel 所在的目录(例如 /home): " install_dir
    install_path="$install_dir/1panel"
fi

# 确保安装路径以 / 结尾
install_path=${install_path%/}

# 检查安装路径是否存在
if [ ! -d "$install_path" ]; then
    echo "安装路径不存在: $install_path"
    exit 1
fi

# 定义函数处理应用复制
copy_app() {
  local app_dir="$1"
  local app_name=$(basename "$app_dir")
  if [ ! -d "$install_path/resource/apps/local/$app_name" ]; then
      cp -rf "$app_dir" "$install_path/resource/apps/local/"
  else
      echo "跳过已存在的应用: $app_name"
  fi
}

# 定义函数处理仓库克隆和更新
handle_repo() {
  local repo_url="$1"
  local branch="$2"
  local target_dir="$3"

  if [ ! -d "$target_dir" ]; then
      echo "克隆仓库资源: $repo_url"
      git clone -b "$branch" --depth 1 "$repo_url" "$target_dir"
      if [ $? -ne 0 ]; then
          echo "克隆失败，请检查您的互联网连接和URL：$repo_url"
          exit 1
      fi
  else
      echo "更新仓库资源: $target_dir"
      cd "$target_dir"
      git pull
      if [ $? -ne 0 ]; then
          echo "更新失败，请检查您的互联网连接和仓库状态。"
          exit 1
      fi
  fi
}

# 官方应用商店
appstore_official_dir="$install_path/resource/apps/local/appstore-official"
handle_repo "https://github.com/1Panel-dev/appstore" "dev" "$appstore_official_dir"

# 复制官方应用
echo "复制应用..."
for app in "$appstore_official_dir/apps/"*; do
  copy_app "$app"
done

# 清理官方应用商店
rm -rf "$appstore_official_dir"

# 判断是否克隆第三方仓库
if [[ -z $official_only ]]; then
  # 第三方应用商店
  appstore_local_dir="$install_path/resource/apps/local/appstore-localApps"
  handle_repo "https://github.com/okxlin/appstore" "localApps" "$appstore_local_dir"

  # 复制第三方应用
  echo "复制第三方应用..."
  for app in "$appstore_local_dir/apps/"*; do
    copy_app "$app"
  done

  # 新增的第三方应用商店
  appstore_custom_dir="$install_path/resource/apps/local/appstore-custom"
  handle_repo "https://github.com/QYG2297248353/appstore-1panel" "custom" "$appstore_custom_dir"

  # 复制新增的第三方应用
  echo "复制新增的第三方应用..."
  for app in "$appstore_custom_dir/apps/"*; do
    copy_app "$app"
  done
fi

echo "完成。"

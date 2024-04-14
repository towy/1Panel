#!/bin/bash

# 检查 git 是否安装
if ! command -v git &> /dev/null; then
    echo "git 未安装，请先安装 git。"
    exit 1
fi

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

# 官方应用商店
appstore_dir="$install_path/resource/apps/local/appstore-official"

echo "克隆官方应用商店资源..."
git clone -b dev --depth 1 https://github.com/1Panel-dev/appstore "$appstore_dir"
if [ $? -ne 0 ]; then
    echo "克隆失败，请检查您的互联网连接和URL：https://github.com/1Panel-dev/appstore"
    exit 1
fi

echo "复制官方应用..."
for app in "$appstore_dir/apps/"*; do
    app_name=$(basename "$app")
    if [ ! -d "$install_path/resource/apps/local/$app_name" ]; then
        cp -rf "$app" "$install_path/resource/apps/local/"
    else
        echo "跳过已存在的应用: $app_name"
    fi
done
rm -rf "$appstore_dir"

# 第三方应用商店，使用 git 拉取更新
appstore_dir="$install_path/resource/apps/local/appstore-localApps"

if [ ! -d "$appstore_dir" ]; then
    echo "克隆第三方应用商店资源..."
    git clone -b localApps https://github.com/okxlin/appstore "$appstore_dir"
    if [ $? -ne 0 ]; then
        echo "克隆失败，请检查您的互联网连接和URL：https://github.com/okxlin/appstore"
        exit 1
    fi
else
    echo "更新第三方应用商店资源..."
    cd "$appstore_dir"
    git pull 
    if [ $? -ne 0 ]; then
        echo "更新失败，请检查您的互联网连接和仓库状态。"
        exit 1
    fi
fi

echo "复制第三方应用..."
for app in "$appstore_dir/apps/"*; do
    app_name=$(basename "$app")
    if [ ! -d "$install_path/resource/apps/local/$app_name" ]; then
        cp -rf "$app" "$install_path/resource/apps/local/"
    else
        echo "跳过已存在的应用: $app_name"
    fi
done

echo "完成。"

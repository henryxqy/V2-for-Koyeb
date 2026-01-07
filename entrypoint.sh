#!/usr/bin/env bash

# 1. 确定当前脚本所在目录
CURRENT_DIR=$(pwd)
WORK_DIR="/tmp"

# 2. 解码并配置
# 检查当前目录下是否有 config 文件
if [ -f "$CURRENT_DIR/config" ]; then
    base64 -d "$CURRENT_DIR/config" > /tmp/config.json
else
    echo "Error: config file not found in $CURRENT_DIR"
    exit 1
fi

# 3. 复制并修改 Nginx 配置
# 检查当前目录下是否有 nginx.conf
if [ -f "$CURRENT_DIR/nginx.conf" ]; then
    cp "$CURRENT_DIR/nginx.conf" /tmp/nginx.conf
else
    echo "Error: nginx.conf not found in $CURRENT_DIR"
    exit 1
fi

# 执行变量替换
UUID=${UUID:-'de04add9-5c68-8bab-950c-08cd5320df18'}
VMESS_WSPATH=${VMESS_WSPATH:-'/vmess'}
VLESS_WSPATH=${VLESS_WSPATH:-'/vless'}

sed -i "s#listen       80;#listen 8080;#g" /tmp/nginx.conf
sed -i "s#VMESS_WSPATH#${VMESS_WSPATH}#g;s#VLESS_WSPATH#${VLESS_WSPATH}#g" /tmp/nginx.conf
sed -i "s#UUID#$UUID#g;s#VMESS_WSPATH#${VMESS_WSPATH}#g;s#VLESS_WSPATH#${VLESS_WSPATH}#g" /tmp/config.json

# 4. 处理运行程序 v
RELEASE_RANDOMNESS=$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 6)
if [ -f "$CURRENT_DIR/v" ]; then
    cp "$CURRENT_DIR/v" "/tmp/${RELEASE_RANDOMNESS}"
    chmod +x "/tmp/${RELEASE_RANDOMNESS}"
else
    echo "Error: binary 'v' not found"
    exit 1
fi

# 5. 启动服务
mkdir -p /tmp/client_temp
nginx -c /tmp/nginx.conf -g "pid /tmp/nginx.pid; daemon on;"

cd /tmp
./${RELEASE_RANDOMNESS} run -config /tmp/config.json

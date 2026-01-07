#!/usr/bin/env bash

# 1. 所有的临时操作和配置文件都转移到可写的 /tmp 目录
WORK_DIR="/tmp"
CONF_FILE="$WORK_DIR/config.json"
NGINX_CONF="$WORK_DIR/nginx.conf"

# 2. 处理 V2 配置
base64 -d config > "$CONF_FILE"
UUID=${UUID:-'de04add9-5c68-8bab-950c-08cd5320df18'}
VMESS_WSPATH=${VMESS_WSPATH:-'/vmess'}
VLESS_WSPATH=${VLESS_WSPATH:-'/vless'}

# 在 /tmp 下进行 sed 修改，避免 Read-only 错误
sed -i "s#UUID#$UUID#g;s#VMESS_WSPATH#${VMESS_WSPATH}#g;s#VLESS_WSPATH#${VLESS_WSPATH}#g" "$CONF_FILE"

# 3. 处理 Nginx 配置
# 先把原始配置拷到 /tmp，再修改它
cp /etc/nginx/nginx.conf "$NGINX_CONF"
# 强制 Nginx 监听 8080 (Choreo 要求 >1024)
sed -i "s#listen 80;#listen 8080;#g" "$NGINX_CONF"
sed -i "s#VMESS_WSPATH#${VMESS_WSPATH}#g;s#VLESS_WSPATH#${VLESS_WSPATH}#g" "$NGINX_CONF"
# 核心：修复 Nginx 尝试写入只读目录的错误
sed -i "/http {/a \    client_body_temp_path /tmp/client_temp;\n    proxy_temp_path /tmp/proxy_temp;\n    fastcgi_temp_path /tmp/fastcgi_temp;\n    uwsgi_temp_path /tmp/uwsgi_temp;\n    scgi_temp_path /tmp/scgi_temp;" "$NGINX_CONF"

# 4. 伪装执行文件并移动到 /tmp 运行 (解决 noexec 问题)
RELEASE_RANDOMNESS=$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 6)
cp v "$WORK_DIR/${RELEASE_RANDOMNESS}"
chmod +x "$WORK_DIR/${RELEASE_RANDOMNESS}"

# 5. 哪吒探针处理 (如果需要，脚本也必须下载到 /tmp)
TLS=${NEZHA_TLS:+'--tls'}
if [ -n "${NEZHA_SERVER}" ] && [ -n "${NEZHA_PORT}" ] && [ -n "${NEZHA_KEY}" ]; then
    wget https://raw.githubusercontent.com/naiba/nezha/master/script/install.sh -O "$WORK_DIR/nezha.sh"
    chmod +x "$WORK_DIR/nezha.sh"
    # 注意：Choreo 下安装 agent 可能会因为权限受限失败，但此处保留逻辑
    echo '0' | "$WORK_DIR/nezha.sh" install_agent ${NEZHA_SERVER} ${NEZHA_PORT} ${NEZHA_KEY} ${TLS}
fi

# 6. 运行 Nginx
# 使用 -c 指定 /tmp 下的配置文件，-g 指定 PID 位置
mkdir -p /tmp/client_temp
nginx -c "$NGINX_CONF" -g "pid /tmp/nginx.pid; daemon on;"

# 7. 运行主程序
echo "Starting application with name: ${RELEASE_RANDOMNESS}"
cd "$WORK_DIR"
./${RELEASE_RANDOMNESS} run -config "$CONF_FILE" &

# 8. 自动访问 (端口改为 8080)
while true; do
  sleep 1800
  curl -m 10 http://127.0.0.1:8080/ >/dev/null 2>&1
done

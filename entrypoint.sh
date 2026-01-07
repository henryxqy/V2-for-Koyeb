#!/usr/bin/env bash

# 1. 强制所有操作在可写的 /tmp 下进行
WORK_DIR="/tmp"
# 确保临时目录存在
mkdir -p /tmp/client_temp /tmp/proxy_temp

# 2. 准备 V2-ray 配置
# 注意：一定要用绝对路径引用原始 config 文件
base64 -d /home/choreo/app/config > /tmp/config.json

# 替换变量 (确保 UUID 等环境变量已在 Choreo 后台设置)
UUID=${UUID:-'de04add9-5c68-8bab-950c-08cd5320df18'}
VMESS_WSPATH=${VMESS_WSPATH:-'/vmess'}
VLESS_WSPATH=${VLESS_WSPATH:-'/vless'}
sed -i "s#UUID#$UUID#g;s#VMESS_WSPATH#${VMESS_WSPATH}#g;s#VLESS_WSPATH#${VLESS_WSPATH}#g" /tmp/config.json

# 3. 准备 Nginx 配置 (这是解决 111 报错的关键)
# 从代码目录复制原始 nginx.conf 到 /tmp
cp /home/choreo/app/nginx.conf /tmp/nginx.conf

# 强制 Nginx 放弃监听 80，改为监听 8080
sed -i "s#listen       80;#listen 8080;#g" /tmp/nginx.conf
sed -i "s#listen  \[::\]:80;#listen [::]:8080;#g" /tmp/nginx.conf
sed -i "s#VMESS_WSPATH#${VMESS_WSPATH}#g;s#VLESS_WSPATH#${VLESS_WSPATH}#g" /tmp/nginx.conf

# 4. 运行二进制文件
RELEASE_RANDOMNESS=$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 6)
cp /home/choreo/app/v "/tmp/${RELEASE_RANDOMNESS}"
chmod +x "/tmp/${RELEASE_RANDOMNESS}"

# 5. 启动 Nginx (必须使用 -c 指定 /tmp 下的那个新配置)
# -g 指令强制覆盖 PID 位置和关闭用户切换
nginx -c /tmp/nginx.conf -g "pid /tmp/nginx.pid; user root; daemon on;" 2>&1 | tee /tmp/nginx_start.log

# 6. 运行主程序
cd /tmp
./${RELEASE_RANDOMNESS} run -config /tmp/config.json &

# 7. 保活并防止脚本退出
while true; do
  sleep 1800
  curl -m 10 http://127.0.0.1:8080/ >/dev/null 2>&1
done

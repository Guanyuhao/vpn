#!/bin/bash

# V2Ray 服务器安装脚本
# 使用 VLESS + WebSocket + TLS 配置（推荐用于中国大陆）
# 使用方法: sudo bash v2ray-server-setup.sh

set -e

echo "=========================================="
echo "V2Ray 服务器安装脚本"
echo "=========================================="

# 检查是否为 root 用户
if [ "$EUID" -ne 0 ]; then 
    echo "请使用 sudo 运行此脚本"
    exit 1
fi

# 更新系统
echo "更新系统包..."
apt-get update
apt-get upgrade -y

# 安装必要的依赖
echo "安装依赖..."
apt-get install -y curl wget unzip

# 安装 V2Ray
echo "安装 V2Ray..."
bash <(curl -L https://raw.githubusercontent.com/v2fly/fhs-install-v2ray/master/install-release.sh)

# 安装 Nginx（用于 WebSocket 和 TLS）
echo "安装 Nginx..."
apt-get install -y nginx

# 安装 Certbot（用于 SSL 证书）
echo "安装 Certbot..."
apt-get install -y certbot python3-certbot-nginx

# 生成 UUID
UUID=$(cat /proc/sys/kernel/random/uuid)
echo "生成的 UUID: ${UUID}"

# 获取服务器信息
echo ""
echo "=========================================="
echo "配置信息输入"
echo "=========================================="
read -p "请输入你的域名（用于 TLS 证书，必须输入）: " DOMAIN

if [ -z "$DOMAIN" ]; then
    echo "错误: 域名不能为空！"
    echo "此脚本需要域名来配置 TLS，如需无需域名的方案，请使用 v2ray-vmess-setup.sh"
    exit 1
fi

read -p "请输入 WebSocket 路径（默认: /v2ray，建议使用随机路径）: " WS_PATH
WS_PATH=${WS_PATH:-/v2ray}

# 如果用户没有输入路径，生成随机路径
if [ "$WS_PATH" == "/v2ray" ]; then
    read -p "是否使用随机路径以提高安全性？(y/n，默认 y): " USE_RANDOM_PATH
    USE_RANDOM_PATH=${USE_RANDOM_PATH:-y}
    if [ "$USE_RANDOM_PATH" == "y" ] || [ "$USE_RANDOM_PATH" == "Y" ]; then
        WS_PATH="/$(openssl rand -hex 8)"
        echo "生成的随机路径: ${WS_PATH}"
    fi
fi

# 创建 V2Ray 配置目录
mkdir -p /usr/local/etc/v2ray

# 创建 V2Ray 配置文件
cat > /usr/local/etc/v2ray/config.json <<EOF
{
  "log": {
    "loglevel": "warning"
  },
  "inbounds": [
    {
      "port": 10000,
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "${UUID}",
            "flow": "xtls-rprx-vision"
          }
        ],
        "decryption": "none",
        "fallbacks": [
          {
            "dest": 8080
          }
        ]
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": {
          "path": "${WS_PATH}"
        }
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom"
    }
  ]
}
EOF

# 配置 Nginx 和 SSL（域名已必填）
if [ ! -z "$DOMAIN" ]; then
    echo "配置 Nginx 和 SSL 证书..."
    
    # 配置 Nginx
    cat > /etc/nginx/sites-available/v2ray <<EOF
server {
    listen 80;
    server_name ${DOMAIN};
    
    location ${WS_PATH} {
        proxy_redirect off;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_pass http://127.0.0.1:10000;
    }
}
EOF
    
    ln -sf /etc/nginx/sites-available/v2ray /etc/nginx/sites-enabled/
    rm -f /etc/nginx/sites-enabled/default
    
    # 测试 Nginx 配置
    nginx -t
    
    # 重启 Nginx
    systemctl restart nginx
    
    # 获取 SSL 证书
    echo "获取 SSL 证书..."
    read -p "请输入邮箱地址（用于 Let's Encrypt 证书通知，可选）: " EMAIL
    EMAIL=${EMAIL:-admin@${DOMAIN}}
    
    certbot --nginx -d ${DOMAIN} --non-interactive --agree-tos --email ${EMAIL} || {
        echo "SSL 证书获取失败！"
        echo "请检查："
        echo "1. 域名 DNS 解析是否正确指向服务器 IP"
        echo "2. 防火墙是否开放 80 端口"
        echo "3. Nginx 是否正常运行"
        exit 1
    }
    
    # 更新 V2Ray 配置以使用 TLS
    cat > /usr/local/etc/v2ray/config.json <<EOF
{
  "log": {
    "loglevel": "warning"
  },
  "inbounds": [
    {
      "port": 443,
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "${UUID}",
            "flow": "xtls-rprx-vision"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "ws",
        "security": "tls",
        "wsSettings": {
          "path": "${WS_PATH}"
        },
        "tlsSettings": {
          "certificates": [
            {
              "certificateFile": "/etc/letsencrypt/live/${DOMAIN}/fullchain.pem",
              "keyFile": "/etc/letsencrypt/live/${DOMAIN}/privkey.pem"
            }
          ]
        }
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom"
    }
  ]
}
EOF
    
    SERVER_ADDRESS="${DOMAIN}"
    SERVER_PORT="443"
else
    echo "错误: 域名配置失败"
    exit 1
fi

# 启动 V2Ray 服务
echo "启动 V2Ray 服务..."
systemctl enable v2ray
systemctl restart v2ray

# 检查状态
if systemctl is-active --quiet v2ray; then
    echo "✓ V2Ray 服务已成功启动"
else
    echo "✗ V2Ray 服务启动失败"
    exit 1
fi

# 显示配置信息
echo ""
echo "=========================================="
echo "安装完成！"
echo "=========================================="
echo "服务器地址: ${SERVER_ADDRESS}"
echo "服务器端口: ${SERVER_PORT}"
echo "UUID: ${UUID}"
echo "WebSocket 路径: ${WS_PATH}"
echo ""
echo "V2Ray 客户端配置 (VLESS):"
echo "地址: ${SERVER_ADDRESS}"
echo "端口: ${SERVER_PORT}"
echo "UUID: ${UUID}"
echo "传输协议: WebSocket"
echo "路径: ${WS_PATH}"
echo "TLS: ${DOMAIN:+启用}${DOMAIN:-未启用}"
echo ""
echo "使用以下命令管理 V2Ray:"
echo "  查看状态: systemctl status v2ray"
echo "  查看日志: journalctl -u v2ray -f"
echo "  重启服务: systemctl restart v2ray"
echo "  停止服务: systemctl stop v2ray"
echo ""
echo "配置文件位置: /usr/local/etc/v2ray/config.json"
echo ""
echo "重要提示："
echo "1. 请妥善保管 UUID，不要泄露"
echo "2. WebSocket 路径建议不要公开"
echo "3. 定期更新 V2Ray: bash <(curl -L https://raw.githubusercontent.com/v2fly/fhs-install-v2ray/master/install-release.sh)"
echo "4. SSL 证书会自动续期，无需手动操作"
echo "5. 建议配置防火墙，只开放必要端口"
echo "=========================================="


#!/bin/bash

# V2Ray 服务器安装脚本
# 使用 VLESS + WebSocket + TLS 配置（推荐用于中国大陆）
# 使用方法: sudo bash v2ray-server-setup.sh
# 支持环境变量配置，详见 ENV.md

set -e

echo "=========================================="
echo "V2Ray 服务器安装脚本"
echo "=========================================="

# 检查是否为 root 用户
if [ "$EUID" -ne 0 ]; then 
    echo "请使用 sudo 运行此脚本"
    exit 1
fi

# ============================================
# 加载环境变量配置
# ============================================

# 加载 .env 文件（如果存在）
load_env_file() {
    local env_file="${1:-.env}"
    if [ -f "$env_file" ]; then
        echo "发现环境变量文件: $env_file"
        # 读取 .env 文件，忽略注释和空行
        set -a
        source <(grep -v '^#' "$env_file" | grep -v '^$' | sed 's/^/export /')
        set +a
        echo "✓ 环境变量已加载"
    fi
}

# 从当前目录或脚本所在目录加载 .env
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "${SCRIPT_DIR}/.env" ]; then
    load_env_file "${SCRIPT_DIR}/.env"
elif [ -f ".env" ]; then
    load_env_file ".env"
fi

# ============================================
# 配置默认值
# ============================================

# 必需配置
DOMAIN="${DOMAIN:-}"

# 可选配置
WS_PATH="${WS_PATH:-}"
EMAIL="${EMAIL:-}"
V2RAY_PORT="${V2RAY_PORT:-443}"
V2RAY_INTERNAL_PORT="${V2RAY_INTERNAL_PORT:-10000}"
LOG_LEVEL="${LOG_LEVEL:-warning}"
AUTO_GENERATE_WS_PATH="${AUTO_GENERATE_WS_PATH:-true}"
UUID="${UUID:-}"

# 高级配置（通常不需要修改）
NGINX_CONFIG_DIR="${NGINX_CONFIG_DIR:-/etc/nginx/sites-available}"
V2RAY_CONFIG_DIR="${V2RAY_CONFIG_DIR:-/usr/local/etc/v2ray}"
SSL_CERT_DIR="${SSL_CERT_DIR:-/etc/letsencrypt/live}"
CERTBOT_METHOD="${CERTBOT_METHOD:-nginx}"
ENABLE_TLS="${ENABLE_TLS:-true}"

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

# ============================================
# 获取配置信息（从环境变量或交互式输入）
# ============================================

echo ""
echo "=========================================="
echo "配置信息"
echo "=========================================="

# 获取域名
if [ -z "$DOMAIN" ]; then
    read -p "请输入你的域名（用于 TLS 证书，必须输入）: " DOMAIN
fi

if [ -z "$DOMAIN" ]; then
    echo "错误: 域名不能为空！"
    echo "可以通过以下方式设置："
    echo "1. 创建 .env 文件并设置 DOMAIN=your_domain.com"
    echo "2. 导出环境变量: export DOMAIN=your_domain.com"
    echo "3. 在命令行中设置: DOMAIN=your_domain.com sudo bash v2ray-server-setup.sh"
    exit 1
fi

echo "✓ 域名: ${DOMAIN}"

# 生成或使用已有 UUID
if [ -z "$UUID" ]; then
    UUID=$(cat /proc/sys/kernel/random/uuid)
    echo "✓ UUID: ${UUID} (自动生成)"
else
    echo "✓ UUID: ${UUID} (使用配置的值)"
fi

# 处理 WebSocket 路径
if [ -z "$WS_PATH" ]; then
    if [ "$AUTO_GENERATE_WS_PATH" == "true" ]; then
        WS_PATH="/$(openssl rand -hex 8)"
        echo "✓ WebSocket 路径: ${WS_PATH} (自动生成随机路径)"
    else
        WS_PATH="/v2ray"
        echo "✓ WebSocket 路径: ${WS_PATH} (使用默认值)"
    fi
else
    echo "✓ WebSocket 路径: ${WS_PATH} (使用配置的值)"
fi

# 处理邮箱
if [ -z "$EMAIL" ]; then
    EMAIL="admin@${DOMAIN}"
    echo "✓ 邮箱: ${EMAIL} (使用默认值)"
else
    echo "✓ 邮箱: ${EMAIL}"
fi

echo "✓ V2Ray 端口: ${V2RAY_PORT}"
echo "✓ 日志级别: ${LOG_LEVEL}"
echo "=========================================="

# 创建 V2Ray 配置目录
mkdir -p "${V2RAY_CONFIG_DIR}"

# 创建 V2Ray 配置文件
cat > "${V2RAY_CONFIG_DIR}/config.json" <<EOF
{
  "log": {
    "loglevel": "${LOG_LEVEL}"
  },
  "inbounds": [
    {
      "port": ${V2RAY_INTERNAL_PORT},
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
    cat > "${NGINX_CONFIG_DIR}/v2ray" <<EOF
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
        proxy_pass http://127.0.0.1:${V2RAY_INTERNAL_PORT};
    }
}
EOF
    
    ln -sf "${NGINX_CONFIG_DIR}/v2ray" /etc/nginx/sites-enabled/
    rm -f /etc/nginx/sites-enabled/default
    
    # 测试 Nginx 配置
    nginx -t
    
    # 重启 Nginx
    systemctl restart nginx
    
    # 获取 SSL 证书
    echo "获取 SSL 证书..."
    
    certbot --${CERTBOT_METHOD} -d ${DOMAIN} --non-interactive --agree-tos --email ${EMAIL} || {
        echo "SSL 证书获取失败！"
        echo "请检查："
        echo "1. 域名 DNS 解析是否正确指向服务器 IP"
        echo "2. 防火墙是否开放 80 端口"
        echo "3. Nginx 是否正常运行"
        exit 1
    }
    
    # 更新 V2Ray 配置以使用 TLS
    if [ "$ENABLE_TLS" == "true" ]; then
        cat > "${V2RAY_CONFIG_DIR}/config.json" <<EOF
{
  "log": {
    "loglevel": "${LOG_LEVEL}"
  },
  "inbounds": [
    {
      "port": ${V2RAY_PORT},
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
              "certificateFile": "${SSL_CERT_DIR}/${DOMAIN}/fullchain.pem",
              "keyFile": "${SSL_CERT_DIR}/${DOMAIN}/privkey.pem"
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
        SERVER_PORT="${V2RAY_PORT}"
    else
        echo "警告: TLS 已禁用，使用非加密连接（不推荐）"
        SERVER_ADDRESS="${DOMAIN}"
        SERVER_PORT="${V2RAY_PORT}"
    fi
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
echo "配置文件位置: ${V2RAY_CONFIG_DIR}/config.json"
echo ""
echo "重要提示："
echo "1. 请妥善保管 UUID，不要泄露"
echo "2. WebSocket 路径建议不要公开"
echo "3. 定期更新 V2Ray: bash <(curl -L https://raw.githubusercontent.com/v2fly/fhs-install-v2ray/master/install-release.sh)"
echo "4. SSL 证书会自动续期，无需手动操作"
echo "5. 建议配置防火墙，只开放必要端口"
echo "=========================================="


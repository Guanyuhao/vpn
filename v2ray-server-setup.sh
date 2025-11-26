#!/bin/bash

# V2Ray 服务器安装脚本
# 使用 VLESS + WebSocket 配置（TLS 由 Nginx 处理）
# 使用方法: sudo bash v2ray-server-setup.sh
# 支持环境变量配置，详见 ENV.md
# 注意: 脚本不处理 Nginx 配置，需要手动配置 Nginx 反向代理

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
V2RAY_PORT="${V2RAY_PORT:-443}"
V2RAY_INTERNAL_PORT="${V2RAY_INTERNAL_PORT:-10000}"
LOG_LEVEL="${LOG_LEVEL:-warning}"
AUTO_GENERATE_WS_PATH="${AUTO_GENERATE_WS_PATH:-true}"
UUID="${UUID:-}"

# 高级配置（通常不需要修改）
V2RAY_CONFIG_DIR="${V2RAY_CONFIG_DIR:-/usr/local/etc/v2ray}"

# ============================================
# 检测操作系统类型
# ============================================

detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        OS_VERSION=$VERSION_ID
    elif [ -f /etc/redhat-release ]; then
        # CentOS 7 等旧版本
        if grep -q "CentOS" /etc/redhat-release; then
            OS="centos"
            OS_VERSION=$(grep -oE '[0-9]+\.[0-9]+' /etc/redhat-release | head -1)
        elif grep -q "Red Hat" /etc/redhat-release; then
            OS="rhel"
            OS_VERSION=$(grep -oE '[0-9]+\.[0-9]+' /etc/redhat-release | head -1)
        fi
    else
        echo "无法检测操作系统类型"
        exit 1
    fi
    
    echo "检测到系统: ${OS} ${OS_VERSION}"
}

# 检测操作系统
detect_os


# ============================================
# 根据操作系统安装依赖
# ============================================

install_dependencies() {
    case "$OS" in
        ubuntu|debian)
            echo "使用 apt-get 安装依赖..."
            apt-get update
            apt-get upgrade -y
            apt-get install -y curl wget unzip
            ;;
        centos|rhel|fedora)
            echo "使用 yum 安装依赖..."
            # CentOS 7 需要启用 EPEL 仓库
            if [ "$OS" == "centos" ] && [ "$(echo "$OS_VERSION < 8" | bc 2>/dev/null || echo 1)" == "1" ]; then
                if ! rpm -q epel-release > /dev/null 2>&1; then
                    echo "安装 EPEL 仓库..."
                    yum install -y epel-release
                fi
            fi
            yum update -y
            yum install -y curl wget unzip
            ;;
        *)
            echo "不支持的操作系统: $OS"
            exit 1
            ;;
    esac
}

# 安装系统依赖
install_dependencies

# ============================================
# 安装 V2Ray
# ============================================

echo "安装 V2Ray..."
bash <(curl -L https://raw.githubusercontent.com/v2fly/fhs-install-v2ray/master/install-release.sh)


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

# ============================================
# 显示配置信息和 Nginx 配置说明
# ============================================

if [ ! -z "$DOMAIN" ]; then
    SERVER_ADDRESS="${DOMAIN}"
    SERVER_PORT="${V2RAY_PORT}"
    
    echo ""
    echo "=========================================="
    echo "V2Ray 配置完成"
    echo "=========================================="
    echo ""
    echo "⚠️  重要提示：请手动配置 Nginx"
    echo ""
    echo "需要在 Nginx 中添加以下配置："
    echo ""
    echo "server {"
    echo "    listen 443 ssl http2;"
    echo "    server_name ${DOMAIN};"
    echo ""
    echo "    # SSL 证书配置（请使用你自己的证书路径）"
    echo "    ssl_certificate /path/to/your/fullchain.pem;"
    echo "    ssl_certificate_key /path/to/your/privkey.pem;"
    echo ""
    echo "    location ${WS_PATH} {"
    echo "        proxy_redirect off;"
    echo "        proxy_http_version 1.1;"
    echo "        proxy_set_header Upgrade \$http_upgrade;"
    echo "        proxy_set_header Connection \"upgrade\";"
    echo "        proxy_set_header Host \$host;"
    echo "        proxy_set_header X-Real-IP \$remote_addr;"
    echo "        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;"
    echo "        proxy_pass http://127.0.0.1:${V2RAY_INTERNAL_PORT};"
    echo "    }"
    echo "}"
    echo ""
    echo "配置完成后，请重启 Nginx 服务"
    echo "=========================================="
else
    echo "警告: 未设置域名，V2Ray 将使用 IP 地址"
    SERVER_ADDRESS="$(hostname -I | awk '{print $1}')"
    SERVER_PORT="${V2RAY_PORT}"
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
echo "TLS: 由 Nginx 处理（需要手动配置）"
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
echo "4. ⚠️  请手动配置 Nginx 反向代理（见上方配置示例）"
echo "5. ⚠️  请手动配置 SSL 证书（TLS 由 Nginx 处理）"
echo "6. 建议配置防火墙，只开放必要端口"
echo ""
echo "防火墙配置命令："
case "$OS" in
    ubuntu|debian)
        echo "  ufw allow 443/tcp"
        echo "  ufw allow 80/tcp"
        echo "  ufw enable"
        ;;
    centos|rhel)
        echo "  # 使用 firewalld（推荐）"
        echo "  firewall-cmd --permanent --add-service=http"
        echo "  firewall-cmd --permanent --add-service=https"
        echo "  firewall-cmd --reload"
        echo ""
        echo "  # 或使用 iptables"
        echo "  iptables -A INPUT -p tcp --dport 443 -j ACCEPT"
        echo "  iptables -A INPUT -p tcp --dport 80 -j ACCEPT"
        echo "  service iptables save"
        ;;
esac
echo "=========================================="


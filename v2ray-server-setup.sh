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
# Nginx 配置目录会根据系统自动设置
V2RAY_CONFIG_DIR="${V2RAY_CONFIG_DIR:-/usr/local/etc/v2ray}"
SSL_CERT_DIR="${SSL_CERT_DIR:-/etc/letsencrypt/live}"
CERTBOT_METHOD="${CERTBOT_METHOD:-nginx}"
ENABLE_TLS="${ENABLE_TLS:-true}"

# 环境变量覆盖（如果设置了）
BT_PANEL="${BT_PANEL:-}"
NGINX_INSTALLED="${NGINX_INSTALLED:-}"

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
# 检测宝塔面板
# ============================================

detect_bt_panel() {
    if [ -n "$BT_PANEL" ]; then
        # 如果环境变量已设置，使用环境变量的值
        if [ "$BT_PANEL" == "true" ] || [ "$BT_PANEL" == "1" ]; then
            BT_PANEL=true
            return 0
        else
            BT_PANEL=false
            return 1
        fi
    fi
    
    # 自动检测宝塔面板
    if [ -f "/www/server/panel/BT-Panel" ] || [ -d "/www/server/panel" ] || [ -d "/www/server/nginx" ]; then
        BT_PANEL=true
        echo "✓ 检测到宝塔面板"
        return 0
    else
        BT_PANEL=false
        return 1
    fi
}

# 检测宝塔面板
detect_bt_panel

# ============================================
# 检测已安装的软件
# ============================================

check_nginx_installed() {
    if command -v nginx &> /dev/null; then
        echo "✓ 检测到 Nginx 已安装"
        nginx -v 2>&1 | head -1
        return 0
    else
        return 1
    fi
}

check_certbot_installed() {
    if command -v certbot &> /dev/null; then
        echo "✓ 检测到 Certbot 已安装"
        certbot --version 2>&1 | head -1
        return 0
    else
        return 1
    fi
}

# ============================================
# 根据操作系统和宝塔设置 Nginx 配置目录
# ============================================

if [ -z "$NGINX_CONFIG_DIR" ]; then
    if [ "$BT_PANEL" == "true" ]; then
        # 宝塔面板的 Nginx 配置目录
        NGINX_CONFIG_DIR="/www/server/nginx/conf/vhost"
        NGINX_SITES_ENABLED="/www/server/nginx/conf/vhost"
        echo "使用宝塔面板的 Nginx 配置目录: ${NGINX_CONFIG_DIR}"
    else
        # 标准安装
        case "$OS" in
            ubuntu|debian)
                NGINX_CONFIG_DIR="/etc/nginx/sites-available"
                NGINX_SITES_ENABLED="/etc/nginx/sites-enabled"
                ;;
            centos|rhel|fedora)
                NGINX_CONFIG_DIR="/etc/nginx/conf.d"
                NGINX_SITES_ENABLED="/etc/nginx/conf.d"
                ;;
            *)
                NGINX_CONFIG_DIR="/etc/nginx/sites-available"
                NGINX_SITES_ENABLED="/etc/nginx/sites-enabled"
                ;;
        esac
        echo "使用标准 Nginx 配置目录: ${NGINX_CONFIG_DIR}"
    fi
else
    NGINX_SITES_ENABLED="$NGINX_CONFIG_DIR"
fi

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
# 安装 Nginx
# ============================================

install_nginx() {
    # 检测 Nginx 是否已安装
    if check_nginx_installed; then
        if [ -n "$NGINX_INSTALLED" ] && [ "$NGINX_INSTALLED" == "false" ]; then
            echo "环境变量 NGINX_INSTALLED=false，强制重新安装..."
        else
            echo "跳过 Nginx 安装步骤"
            return 0
        fi
    fi
    
    case "$OS" in
        ubuntu|debian)
            echo "使用 apt-get 安装 Nginx..."
            apt-get install -y nginx
            ;;
        centos|rhel)
            echo "使用 yum 安装 Nginx..."
            if [ "$OS" == "centos" ] && [ "$(echo "$OS_VERSION < 8" | bc 2>/dev/null || echo 1)" == "1" ]; then
                # CentOS 7 需要添加 Nginx 仓库（如果使用标准安装）
                if [ "$BT_PANEL" != "true" ] && [ ! -f /etc/yum.repos.d/nginx.repo ]; then
                    cat > /etc/yum.repos.d/nginx.repo <<'EOF'
[nginx]
name=nginx repo
baseurl=http://nginx.org/packages/centos/$releasever/$basearch/
gpgcheck=0
enabled=1
EOF
                fi
            fi
            # 如果使用宝塔，Nginx 通常已通过宝塔安装，这里跳过
            if [ "$BT_PANEL" == "true" ]; then
                echo "检测到宝塔面板，Nginx 应由宝塔管理，跳过安装"
                return 0
            fi
            yum install -y nginx
            ;;
        *)
            echo "不支持的操作系统: $OS"
            exit 1
            ;;
    esac
}

install_nginx

# ============================================
# 安装 Certbot
# ============================================

install_certbot() {
    # 检测 Certbot 是否已安装
    if check_certbot_installed; then
        echo "跳过 Certbot 安装步骤"
        return 0
    fi
    
    case "$OS" in
        ubuntu|debian)
            echo "使用 apt-get 安装 Certbot..."
            apt-get install -y certbot python3-certbot-nginx
            ;;
        centos|rhel)
            echo "使用 yum 安装 Certbot..."
            if [ "$OS" == "centos" ] && [ "$(echo "$OS_VERSION < 8" | bc 2>/dev/null || echo 1)" == "1" ]; then
                # CentOS 7 需要启用 EPEL 和安装 certbot
                yum install -y certbot python2-certbot-nginx || {
                    # 如果 python2-certbot-nginx 不可用，尝试使用 snap 或 pip
                    echo "尝试使用 pip 安装 certbot..."
                    yum install -y python2-pip
                    pip install certbot certbot-nginx
                }
            else
                # CentOS 8+ 或 RHEL 8+
                yum install -y certbot python3-certbot-nginx
            fi
            ;;
        *)
            echo "不支持的操作系统: $OS"
            exit 1
            ;;
    esac
}

install_certbot

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
    
    # 确保配置目录存在
    mkdir -p "${NGINX_CONFIG_DIR}"
    
    # 根据是否使用宝塔面板设置配置文件名
    if [ "$BT_PANEL" == "true" ]; then
        # 宝塔面板：使用域名作为配置文件名
        NGINX_CONFIG_FILE="${NGINX_CONFIG_DIR}/${DOMAIN}.conf"
        echo "使用宝塔面板配置格式: ${NGINX_CONFIG_FILE}"
    else
        # 标准安装：使用 v2ray.conf
        NGINX_CONFIG_FILE="${NGINX_CONFIG_DIR}/v2ray.conf"
        echo "使用标准配置格式: ${NGINX_CONFIG_FILE}"
    fi
    
    # 检查配置文件是否已存在
    if [ -f "${NGINX_CONFIG_FILE}" ]; then
        echo "警告: 配置文件 ${NGINX_CONFIG_FILE} 已存在"
        BACKUP_FILE="${NGINX_CONFIG_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
        echo "将创建备份: ${BACKUP_FILE}"
        cp "${NGINX_CONFIG_FILE}" "${BACKUP_FILE}"
    fi
    
    # 配置 Nginx
    cat > "${NGINX_CONFIG_FILE}" <<EOF
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
    
    echo "✓ Nginx 配置文件已创建: ${NGINX_CONFIG_FILE}"
    
    # Ubuntu/Debian 标准安装需要创建符号链接
    if [ "$BT_PANEL" != "true" ] && ([ "$OS" == "ubuntu" ] || [ "$OS" == "debian" ]); then
        if [ -d "/etc/nginx/sites-enabled" ]; then
            ln -sf "${NGINX_CONFIG_FILE}" /etc/nginx/sites-enabled/v2ray.conf
            # 不删除 default，可能用户需要它
            # rm -f /etc/nginx/sites-enabled/default
        fi
    fi
    
    # 测试 Nginx 配置
    echo "测试 Nginx 配置..."
    if nginx -t; then
        echo "✓ Nginx 配置测试通过"
    else
        echo "✗ Nginx 配置测试失败，请检查配置文件"
        exit 1
    fi
    
    # 重启 Nginx
    echo "重启 Nginx..."
    if systemctl restart nginx 2>/dev/null; then
        echo "✓ Nginx 重启成功"
    else
        echo "⚠ Nginx 重启失败（可能是宝塔管理的 Nginx）"
        if [ "$BT_PANEL" == "true" ]; then
            echo "提示: 如果使用宝塔面板，请在宝塔面板中重启 Nginx"
        fi
        read -p "是否继续？(y/n): " continue_install
        if [ "$continue_install" != "y" ] && [ "$continue_install" != "Y" ]; then
            exit 1
        fi
    fi
    
    # 获取 SSL 证书
    echo "获取 SSL 证书..."
    
    # 如果使用宝塔面板，提示用户可以在宝塔面板中申请证书
    CERT_SKIP=false
    if [ "$BT_PANEL" == "true" ]; then
        echo ""
        echo "提示: 检测到宝塔面板，您可以选择："
        echo "1. 使用脚本自动申请证书（继续）"
        echo "2. 在宝塔面板中手动申请证书（推荐）"
        echo ""
        read -p "是否使用脚本自动申请证书？(y/n，默认 y): " auto_cert
        auto_cert=${auto_cert:-y}
        
        if [ "$auto_cert" != "y" ] && [ "$auto_cert" != "Y" ]; then
            echo "跳过证书申请，请在宝塔面板中手动申请 SSL 证书"
            echo "申请证书后，需要手动更新 V2Ray 配置以使用 TLS"
            CERT_SKIP=true
        fi
    fi
    
    if [ "$CERT_SKIP" != "true" ]; then
        certbot --${CERTBOT_METHOD} -d ${DOMAIN} --non-interactive --agree-tos --email ${EMAIL} || {
            echo "SSL 证书获取失败！"
            echo "请检查："
            echo "1. 域名 DNS 解析是否正确指向服务器 IP"
            echo "2. 防火墙是否开放 80 端口"
            echo "3. Nginx 是否正常运行"
            if [ "$BT_PANEL" == "true" ]; then
                echo "4. 如果使用宝塔面板，可以在面板中手动申请证书"
            fi
            echo ""
            read -p "是否继续安装（跳过证书申请）？(y/n): " skip_cert
            if [ "$skip_cert" != "y" ] && [ "$skip_cert" != "Y" ]; then
                exit 1
            fi
            CERT_SKIP=true
        }
    fi
    
    # 更新 V2Ray 配置以使用 TLS
    if [ "$ENABLE_TLS" == "true" ] && [ "$CERT_SKIP" != "true" ]; then
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
if [ "$BT_PANEL" == "true" ]; then
    echo "Nginx 配置文件: ${NGINX_CONFIG_FILE}"
    echo "提示: 如果需要在宝塔面板中管理，配置文件位于: ${NGINX_CONFIG_FILE}"
fi
echo ""
echo "重要提示："
echo "1. 请妥善保管 UUID，不要泄露"
echo "2. WebSocket 路径建议不要公开"
echo "3. 定期更新 V2Ray: bash <(curl -L https://raw.githubusercontent.com/v2fly/fhs-install-v2ray/master/install-release.sh)"
if [ "$CERT_SKIP" != "true" ]; then
    echo "4. SSL 证书会自动续期，无需手动操作"
else
    echo "4. SSL 证书未自动申请，请在宝塔面板中手动申请或使用 certbot"
fi
echo "5. 建议配置防火墙，只开放必要端口"
if [ "$BT_PANEL" == "true" ]; then
    echo "6. 如果使用宝塔面板，可以在面板中管理 Nginx 和 SSL 证书"
fi
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


#!/bin/bash

# V2Ray 管理脚本
# 提供常用的管理功能，包括一键添加 Shadowsocks 和 VMess 配置
# 使用方法: sudo bash v2ray-manage.sh
# 需要 Python 3 来修改 JSON 配置

set -e

V2RAY_CONFIG="/usr/local/etc/v2ray/config.json"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ============================================
# JSON 配置操作辅助函数
# ============================================

# 检查 Python 是否可用
check_python() {
    if command -v python3 &> /dev/null; then
        return 0
    elif command -v python &> /dev/null; then
        return 0
    else
        return 1
    fi
}

# 备份配置文件
backup_config_file() {
    local backup_file="${V2RAY_CONFIG}.backup.$(date +%Y%m%d_%H%M%S)"
    cp "${V2RAY_CONFIG}" "${backup_file}"
    echo "${backup_file}"
}

# 使用 Python 修改 JSON 配置
modify_json_config() {
    local python_script="$1"
    local backup_file=$(backup_config_file)
    
    if check_python; then
        local python_cmd=$(command -v python3 2>/dev/null || command -v python)
        if ${python_cmd} -c "${python_script}" "${V2RAY_CONFIG}"; then
            echo "${backup_file}"
            return 0
        else
            # 恢复备份
            cp "${backup_file}" "${V2RAY_CONFIG}"
            return 1
        fi
    else
        echo -e "${RED}错误: 需要 Python 来修改配置${NC}"
        return 1
    fi
}

# 检查是否为 root 用户
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}请使用 sudo 运行此脚本${NC}"
    exit 1
fi

# 显示菜单
show_menu() {
    echo ""
    echo "=========================================="
    echo "V2Ray 管理脚本"
    echo "=========================================="
    echo "1. 查看服务状态"
    echo "2. 查看实时日志"
    echo "3. 重启服务"
    echo "4. 停止服务"
    echo "5. 启动服务"
    echo "6. 添加新客户端 (VLESS)"
    echo "7. 一键添加 Shadowsocks"
    echo "8. 一键添加 VMess (TCP/mKCP/QUIC)"
    echo "9. 一键添加 VMess (WS/H2/gRPC + TLS)"
    echo "10. 查看当前配置"
    echo "11. 测试配置文件"
    echo "12. 更新 V2Ray"
    echo "13. 查看连接统计"
    echo "14. 备份配置"
    echo "15. 恢复配置"
    echo "0. 退出"
    echo "=========================================="
    read -p "请选择操作 [0-15]: " choice
}

# 查看服务状态
check_status() {
    echo ""
    echo "=========================================="
    echo "V2Ray 服务状态"
    echo "=========================================="
    systemctl status v2ray --no-pager -l
    
    if command -v nginx &> /dev/null; then
        echo ""
        echo "=========================================="
        echo "Nginx 服务状态"
        echo "=========================================="
        systemctl status nginx --no-pager -l
    fi
}

# 查看实时日志
view_logs() {
    echo ""
    echo "查看 V2Ray 实时日志（按 Ctrl+C 退出）..."
    journalctl -u v2ray -f
}

# 重启服务
restart_service() {
    echo ""
    echo "重启 V2Ray 服务..."
    systemctl restart v2ray
    
    if command -v nginx &> /dev/null; then
        echo "重启 Nginx 服务..."
        systemctl restart nginx
    fi
    
    sleep 2
    
    if systemctl is-active --quiet v2ray; then
        echo -e "${GREEN}✓ 服务重启成功${NC}"
    else
        echo -e "${RED}✗ 服务重启失败${NC}"
    fi
}

# 停止服务
stop_service() {
    echo ""
    echo "停止 V2Ray 服务..."
    systemctl stop v2ray
    
    if command -v nginx &> /dev/null; then
        read -p "是否同时停止 Nginx？(y/n): " stop_nginx
        if [ "$stop_nginx" == "y" ] || [ "$stop_nginx" == "Y" ]; then
            systemctl stop nginx
        fi
    fi
    
    echo -e "${GREEN}✓ 服务已停止${NC}"
}

# 启动服务
start_service() {
    echo ""
    echo "启动 V2Ray 服务..."
    systemctl start v2ray
    
    if command -v nginx &> /dev/null; then
        echo "启动 Nginx 服务..."
        systemctl start nginx
    fi
    
    sleep 2
    
    if systemctl is-active --quiet v2ray; then
        echo -e "${GREEN}✓ 服务启动成功${NC}"
    else
        echo -e "${RED}✗ 服务启动失败${NC}"
    fi
}

# 添加新客户端 (VLESS)
add_client() {
    echo ""
    echo "=========================================="
    echo "添加新客户端 (VLESS)"
    echo "=========================================="
    
    # 检查配置文件是否存在
    if [ ! -f "${V2RAY_CONFIG}" ]; then
        echo -e "${RED}错误: 配置文件不存在${NC}"
        return
    fi
    
    # 生成新 UUID
    NEW_UUID=$(cat /proc/sys/kernel/random/uuid)
    echo "生成的新 UUID: ${NEW_UUID}"
    
    read -p "是否添加此客户端？(y/n): " confirm
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        echo "已取消"
        return
    fi
    
    # 使用 Python 添加客户端
    backup_file=$(backup_config_file)
    
    if check_python; then
        local python_cmd=$(command -v python3 2>/dev/null || command -v python)
        local python_script="
import json
import sys

config_file = sys.argv[1]
new_uuid = sys.argv[2]

with open(config_file, 'r') as f:
    config = json.load(f)

# 找到 VLESS inbound
found = False
for inbound in config.get('inbounds', []):
    if inbound.get('protocol') == 'vless':
        if 'settings' in inbound and 'clients' in inbound['settings']:
            # 添加新客户端
            inbound['settings']['clients'].append({
                'id': new_uuid,
                'flow': 'xtls-rprx-vision'
            })
            found = True
            break

if not found:
    print('未找到 VLESS inbound', file=sys.stderr)
    sys.exit(1)

with open(config_file, 'w') as f:
    json.dump(config, f, indent=2)
"
        
        if ${python_cmd} -c "${python_script}" "${V2RAY_CONFIG}" "${NEW_UUID}" 2>/dev/null; then
            echo -e "${GREEN}✓ 客户端已添加${NC}"
            echo "UUID: ${NEW_UUID}"
            echo "备份文件: ${backup_file}"
            
            # 测试配置
            if /usr/local/bin/v2ray test -config ${V2RAY_CONFIG} > /dev/null 2>&1; then
                echo -e "${GREEN}✓ 配置文件测试通过${NC}"
                read -p "是否重启服务使配置生效？(y/n): " restart_confirm
                if [ "$restart_confirm" == "y" ] || [ "$restart_confirm" == "Y" ]; then
                    restart_service
                fi
            else
                echo -e "${RED}✗ 配置文件测试失败，已恢复备份${NC}"
                cp "${backup_file}" "${V2RAY_CONFIG}"
            fi
        else
            echo -e "${RED}✗ 添加客户端失败，已恢复备份${NC}"
            cp "${backup_file}" "${V2RAY_CONFIG}"
        fi
    else
        echo -e "${RED}错误: 需要 Python 来修改配置${NC}"
        echo -e "${YELLOW}请手动编辑配置文件添加客户端：${NC}"
        echo "配置文件: ${V2RAY_CONFIG}"
        echo ""
        echo "在 clients 数组中添加："
        echo '{'
        echo '  "id": "'${NEW_UUID}'",'
        echo '  "flow": "xtls-rprx-vision"'
        echo '}'
    fi
}

# 一键添加 Shadowsocks
add_shadowsocks() {
    echo ""
    echo "=========================================="
    echo "一键添加 Shadowsocks"
    echo "=========================================="
    
    # 检查配置文件是否存在
    if [ ! -f "${V2RAY_CONFIG}" ]; then
        echo -e "${RED}错误: 配置文件不存在${NC}"
        return
    fi
    
    # 生成密码
    SS_PASSWORD=$(openssl rand -base64 16 | tr -d "=+/" | cut -c1-16)
    echo "生成的密码: ${SS_PASSWORD}"
    
    # 选择加密方法
    echo ""
    echo "选择加密方法:"
    echo "1. aes-256-gcm (推荐)"
    echo "2. aes-128-gcm"
    echo "3. chacha20-poly1305"
    echo "4. 2022-blake3-aes-128-gcm (最新)"
    echo "5. 2022-blake3-aes-256-gcm (最新)"
    read -p "请选择 [1-5] (默认 1): " method_choice
    method_choice=${method_choice:-1}
    
    case $method_choice in
        1) SS_METHOD="aes-256-gcm" ;;
        2) SS_METHOD="aes-128-gcm" ;;
        3) SS_METHOD="chacha20-poly1305" ;;
        4) SS_METHOD="2022-blake3-aes-128-gcm" ;;
        5) SS_METHOD="2022-blake3-aes-256-gcm" ;;
        *) SS_METHOD="aes-256-gcm" ;;
    esac
    
    # 选择端口
    read -p "请输入端口 (默认随机): " SS_PORT
    if [ -z "$SS_PORT" ]; then
        SS_PORT=$((RANDOM % 50000 + 10000))
    fi
    
    echo ""
    echo "配置信息:"
    echo "  加密方法: ${SS_METHOD}"
    echo "  端口: ${SS_PORT}"
    echo "  密码: ${SS_PASSWORD}"
    echo ""
    read -p "确认添加？(y/n): " confirm
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        echo "已取消"
        return
    fi
    
    # 使用 Python 添加 Shadowsocks inbound
    local python_script="
import json
import sys

config_file = sys.argv[1]
ss_port = int(sys.argv[2])
ss_method = sys.argv[3]
ss_password = sys.argv[4]

with open(config_file, 'r') as f:
    config = json.load(f)

# 创建 Shadowsocks inbound
ss_inbound = {
    'port': ss_port,
    'protocol': 'shadowsocks',
    'settings': {
        'method': ss_method,
        'password': ss_password,
        'network': 'tcp,udp'
    }
}

# 添加到 inbounds
if 'inbounds' not in config:
    config['inbounds'] = []
config['inbounds'].append(ss_inbound)

with open(config_file, 'w') as f:
    json.dump(config, f, indent=2)
"
    
    backup_file=$(backup_config_file)
    if check_python; then
        local python_cmd=$(command -v python3 2>/dev/null || command -v python)
        if ${python_cmd} -c "${python_script}" "${V2RAY_CONFIG}" "${SS_PORT}" "${SS_METHOD}" "${SS_PASSWORD}"; then
            echo -e "${GREEN}✓ Shadowsocks 已添加${NC}"
            echo "备份文件: ${backup_file}"
            
            # 测试配置
            if /usr/local/bin/v2ray test -config ${V2RAY_CONFIG} > /dev/null 2>&1; then
                echo -e "${GREEN}✓ 配置文件测试通过${NC}"
                echo ""
                echo "客户端配置信息:"
                echo "  服务器地址: $(hostname -I | awk '{print $1}')"
                echo "  端口: ${SS_PORT}"
                echo "  密码: ${SS_PASSWORD}"
                echo "  加密方法: ${SS_METHOD}"
                echo ""
                read -p "是否重启服务使配置生效？(y/n): " restart_confirm
                if [ "$restart_confirm" == "y" ] || [ "$restart_confirm" == "Y" ]; then
                    restart_service
                fi
            else
                echo -e "${RED}✗ 配置文件测试失败，已恢复备份${NC}"
                cp "${backup_file}" "${V2RAY_CONFIG}"
            fi
        else
            echo -e "${RED}✗ 添加 Shadowsocks 失败${NC}"
            cp "${backup_file}" "${V2RAY_CONFIG}"
        fi
    else
        echo -e "${RED}错误: 需要 Python 来修改配置${NC}"
    fi
}

# 一键添加 VMess (TCP/mKCP/QUIC)
add_vmess_tcp() {
    echo ""
    echo "=========================================="
    echo "一键添加 VMess (TCP/mKCP/QUIC)"
    echo "=========================================="
    
    # 检查配置文件是否存在
    if [ ! -f "${V2RAY_CONFIG}" ]; then
        echo -e "${RED}错误: 配置文件不存在${NC}"
        return
    fi
    
    # 生成 UUID
    VMESS_UUID=$(cat /proc/sys/kernel/random/uuid)
    echo "生成的 UUID: ${VMESS_UUID}"
    
    # 选择传输方式
    echo ""
    echo "选择传输方式:"
    echo "1. TCP (默认)"
    echo "2. mKCP (伪装)"
    echo "3. QUIC"
    read -p "请选择 [1-3] (默认 1): " transport_choice
    transport_choice=${transport_choice:-1}
    
    case $transport_choice in
        1) TRANSPORT="tcp" ;;
        2) TRANSPORT="kcp" ;;
        3) TRANSPORT="quic" ;;
        *) TRANSPORT="tcp" ;;
    esac
    
    # 选择端口
    read -p "请输入端口 (默认随机): " VMESS_PORT
    if [ -z "$VMESS_PORT" ]; then
        VMESS_PORT=$((RANDOM % 50000 + 10000))
    fi
    
    echo ""
    echo "配置信息:"
    echo "  传输方式: ${TRANSPORT}"
    echo "  端口: ${VMESS_PORT}"
    echo "  UUID: ${VMESS_UUID}"
    echo ""
    read -p "确认添加？(y/n): " confirm
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        echo "已取消"
        return
    fi
    
    # 构建 streamSettings
    local stream_settings="{}"
    if [ "$TRANSPORT" == "kcp" ]; then
        stream_settings='{"network": "kcp", "kcpSettings": {"uplinkCapacity": 5, "downlinkCapacity": 20, "congestion": false, "header": {"type": "wechat-video"}}}'
    elif [ "$TRANSPORT" == "quic" ]; then
        stream_settings='{"network": "quic", "quicSettings": {"security": "none", "key": "", "header": {"type": "none"}}}'
    fi
    
    # 使用 Python 添加 VMess inbound
    local python_script="
import json
import sys

config_file = sys.argv[1]
vmess_port = int(sys.argv[2])
vmess_uuid = sys.argv[3]
transport = sys.argv[4]
stream_settings_json = sys.argv[5]

with open(config_file, 'r') as f:
    config = json.load(f)

# 解析 streamSettings
import json as json_module
stream_settings = json_module.loads(stream_settings_json) if stream_settings_json != '{}' else {}

# 创建 VMess inbound
vmess_inbound = {
    'port': vmess_port,
    'protocol': 'vmess',
    'settings': {
        'clients': [{'id': vmess_uuid}],
        'disableInsecureEncryption': False
    },
    'streamSettings': stream_settings if stream_settings else {'network': 'tcp'}
}

# 添加到 inbounds
if 'inbounds' not in config:
    config['inbounds'] = []
config['inbounds'].append(vmess_inbound)

with open(config_file, 'w') as f:
    json.dump(config, f, indent=2)
"
    
    backup_file=$(backup_config_file)
    if check_python; then
        local python_cmd=$(command -v python3 2>/dev/null || command -v python)
        if ${python_cmd} -c "${python_script}" "${V2RAY_CONFIG}" "${VMESS_PORT}" "${VMESS_UUID}" "${TRANSPORT}" "${stream_settings}"; then
            echo -e "${GREEN}✓ VMess 已添加${NC}"
            echo "备份文件: ${backup_file}"
            
            # 测试配置
            if /usr/local/bin/v2ray test -config ${V2RAY_CONFIG} > /dev/null 2>&1; then
                echo -e "${GREEN}✓ 配置文件测试通过${NC}"
                echo ""
                echo "客户端配置信息:"
                echo "  服务器地址: $(hostname -I | awk '{print $1}')"
                echo "  端口: ${VMESS_PORT}"
                echo "  UUID: ${VMESS_UUID}"
                echo "  传输方式: ${TRANSPORT}"
                echo ""
                read -p "是否重启服务使配置生效？(y/n): " restart_confirm
                if [ "$restart_confirm" == "y" ] || [ "$restart_confirm" == "Y" ]; then
                    restart_service
                fi
            else
                echo -e "${RED}✗ 配置文件测试失败，已恢复备份${NC}"
                cp "${backup_file}" "${V2RAY_CONFIG}"
            fi
        else
            echo -e "${RED}✗ 添加 VMess 失败${NC}"
            cp "${backup_file}" "${V2RAY_CONFIG}"
        fi
    else
        echo -e "${RED}错误: 需要 Python 来修改配置${NC}"
    fi
}

# 一键添加 VMess (WS/H2/gRPC + TLS)
add_vmess_tls() {
    echo ""
    echo "=========================================="
    echo "一键添加 VMess (WS/H2/gRPC + TLS)"
    echo "=========================================="
    
    # 检查配置文件是否存在
    if [ ! -f "${V2RAY_CONFIG}" ]; then
        echo -e "${RED}错误: 配置文件不存在${NC}"
        return
    fi
    
    # 生成 UUID
    VMESS_UUID=$(cat /proc/sys/kernel/random/uuid)
    echo "生成的 UUID: ${VMESS_UUID}"
    
    # 选择传输方式
    echo ""
    echo "选择传输方式:"
    echo "1. WebSocket (WS)"
    echo "2. HTTP/2 (H2)"
    echo "3. gRPC"
    read -p "请选择 [1-3] (默认 1): " transport_choice
    transport_choice=${transport_choice:-1}
    
    case $transport_choice in
        1) TRANSPORT="ws" ;;
        2) TRANSPORT="h2" ;;
        3) TRANSPORT="grpc" ;;
        *) TRANSPORT="ws" ;;
    esac
    
    # 选择端口
    read -p "请输入端口 (默认随机): " VMESS_PORT
    if [ -z "$VMESS_PORT" ]; then
        VMESS_PORT=$((RANDOM % 50000 + 10000))
    fi
    
    # 输入域名和证书路径
    read -p "请输入域名 (用于 TLS): " DOMAIN
    read -p "请输入 SSL 证书路径 (fullchain.pem): " CERT_PATH
    read -p "请输入 SSL 私钥路径 (privkey.pem): " KEY_PATH
    
    # WebSocket 路径
    if [ "$TRANSPORT" == "ws" ]; then
        WS_PATH="/$(openssl rand -hex 8)"
        echo "生成的 WebSocket 路径: ${WS_PATH}"
    fi
    
    # gRPC serviceName
    if [ "$TRANSPORT" == "grpc" ]; then
        GRPC_SERVICE="$(openssl rand -hex 4)"
        echo "生成的 gRPC serviceName: ${GRPC_SERVICE}"
    fi
    
    echo ""
    echo "配置信息:"
    echo "  传输方式: ${TRANSPORT}"
    echo "  端口: ${VMESS_PORT}"
    echo "  UUID: ${VMESS_UUID}"
    echo "  域名: ${DOMAIN}"
    echo ""
    read -p "确认添加？(y/n): " confirm
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        echo "已取消"
        return
    fi
    
    # 构建 streamSettings
    local stream_settings_json=""
    if [ "$TRANSPORT" == "ws" ]; then
        stream_settings_json="{\"network\": \"ws\", \"security\": \"tls\", \"wsSettings\": {\"path\": \"${WS_PATH}\"}, \"tlsSettings\": {\"certificates\": [{\"certificateFile\": \"${CERT_PATH}\", \"keyFile\": \"${KEY_PATH}\"}]}}"
    elif [ "$TRANSPORT" == "h2" ]; then
        stream_settings_json="{\"network\": \"h2\", \"security\": \"tls\", \"httpSettings\": {\"path\": \"/\", \"host\": [\"${DOMAIN}\"]}, \"tlsSettings\": {\"certificates\": [{\"certificateFile\": \"${CERT_PATH}\", \"keyFile\": \"${KEY_PATH}\"}]}}"
    elif [ "$TRANSPORT" == "grpc" ]; then
        stream_settings_json="{\"network\": \"grpc\", \"security\": \"tls\", \"grpcSettings\": {\"serviceName\": \"${GRPC_SERVICE}\"}, \"tlsSettings\": {\"certificates\": [{\"certificateFile\": \"${CERT_PATH}\", \"keyFile\": \"${KEY_PATH}\"}]}}"
    fi
    
    # 使用 Python 添加 VMess inbound
    local python_script="
import json
import sys

config_file = sys.argv[1]
vmess_port = int(sys.argv[2])
vmess_uuid = sys.argv[3]
stream_settings_json = sys.argv[4]

with open(config_file, 'r') as f:
    config = json.load(f)

# 解析 streamSettings
import json as json_module
stream_settings = json_module.loads(stream_settings_json)

# 创建 VMess inbound
vmess_inbound = {
    'port': vmess_port,
    'protocol': 'vmess',
    'settings': {
        'clients': [{'id': vmess_uuid}],
        'disableInsecureEncryption': False
    },
    'streamSettings': stream_settings
}

# 添加到 inbounds
if 'inbounds' not in config:
    config['inbounds'] = []
config['inbounds'].append(vmess_inbound)

with open(config_file, 'w') as f:
    json.dump(config, f, indent=2)
"
    
    backup_file=$(backup_config_file)
    if check_python; then
        local python_cmd=$(command -v python3 2>/dev/null || command -v python)
        if ${python_cmd} -c "${python_script}" "${V2RAY_CONFIG}" "${VMESS_PORT}" "${VMESS_UUID}" "${stream_settings_json}"; then
            echo -e "${GREEN}✓ VMess (${TRANSPORT} + TLS) 已添加${NC}"
            echo "备份文件: ${backup_file}"
            
            # 测试配置
            if /usr/local/bin/v2ray test -config ${V2RAY_CONFIG} > /dev/null 2>&1; then
                echo -e "${GREEN}✓ 配置文件测试通过${NC}"
                echo ""
                echo "客户端配置信息:"
                echo "  服务器地址: ${DOMAIN}"
                echo "  端口: ${VMESS_PORT}"
                echo "  UUID: ${VMESS_UUID}"
                echo "  传输方式: ${TRANSPORT}"
                if [ "$TRANSPORT" == "ws" ]; then
                    echo "  WebSocket 路径: ${WS_PATH}"
                elif [ "$TRANSPORT" == "grpc" ]; then
                    echo "  gRPC serviceName: ${GRPC_SERVICE}"
                fi
                echo "  TLS: 启用"
                echo ""
                read -p "是否重启服务使配置生效？(y/n): " restart_confirm
                if [ "$restart_confirm" == "y" ] || [ "$restart_confirm" == "Y" ]; then
                    restart_service
                fi
            else
                echo -e "${RED}✗ 配置文件测试失败，已恢复备份${NC}"
                cp "${backup_file}" "${V2RAY_CONFIG}"
            fi
        else
            echo -e "${RED}✗ 添加 VMess 失败${NC}"
            cp "${backup_file}" "${V2RAY_CONFIG}"
        fi
    else
        echo -e "${RED}错误: 需要 Python 来修改配置${NC}"
    fi
}

# 查看当前配置
view_config() {
    echo ""
    echo "=========================================="
    echo "当前 V2Ray 配置"
    echo "=========================================="
    
    if [ -f "${V2RAY_CONFIG}" ]; then
        # 提取关键信息
        echo "配置文件位置: ${V2RAY_CONFIG}"
        echo ""
        echo "客户端 UUID 列表:"
        grep -o '"id": "[^"]*"' ${V2RAY_CONFIG} | sed 's/"id": "\(.*\)"/  - \1/'
        echo ""
        echo "监听端口:"
        grep -o '"port": [0-9]*' ${V2RAY_CONFIG} | head -1
        echo ""
        echo "传输协议:"
        grep -A 5 '"streamSettings"' ${V2RAY_CONFIG} | grep -o '"network": "[^"]*"' | head -1
        echo ""
        read -p "是否查看完整配置？(y/n): " view_full
        if [ "$view_full" == "y" ] || [ "$view_full" == "Y" ]; then
            cat ${V2RAY_CONFIG} | python3 -m json.tool 2>/dev/null || cat ${V2RAY_CONFIG}
        fi
    else
        echo -e "${RED}配置文件不存在${NC}"
    fi
}

# 测试配置文件
test_config() {
    echo ""
    echo "测试 V2Ray 配置文件..."
    
    if /usr/local/bin/v2ray test -config ${V2RAY_CONFIG}; then
        echo -e "${GREEN}✓ 配置文件测试通过${NC}"
    else
        echo -e "${RED}✗ 配置文件测试失败${NC}"
    fi
}

# 更新 V2Ray
update_v2ray() {
    echo ""
    echo "=========================================="
    echo "更新 V2Ray"
    echo "=========================================="
    
    # 备份配置
    BACKUP_FILE="${V2RAY_CONFIG}.backup.$(date +%Y%m%d_%H%M%S)"
    cp ${V2RAY_CONFIG} ${BACKUP_FILE}
    echo "配置已备份到: ${BACKUP_FILE}"
    
    echo "开始更新 V2Ray..."
    bash <(curl -L https://raw.githubusercontent.com/v2fly/fhs-install-v2ray/master/install-release.sh)
    
    echo ""
    read -p "是否重启服务？(y/n): " restart_confirm
    if [ "$restart_confirm" == "y" ] || [ "$restart_confirm" == "Y" ]; then
        restart_service
    fi
    
    echo -e "${GREEN}✓ 更新完成${NC}"
}

# 查看连接统计
view_stats() {
    echo ""
    echo "=========================================="
    echo "连接统计"
    echo "=========================================="
    
    # 查看端口连接数
    PORT=$(grep -o '"port": [0-9]*' ${V2RAY_CONFIG} | head -1 | grep -o '[0-9]*')
    if [ ! -z "$PORT" ]; then
        echo "端口 ${PORT} 的连接数:"
        ss -tn | grep ":${PORT}" | wc -l
    fi
    
    echo ""
    echo "最近 20 条日志:"
    journalctl -u v2ray -n 20 --no-pager
}

# 备份配置
backup_config() {
    echo ""
    echo "=========================================="
    echo "备份配置"
    echo "=========================================="
    
    BACKUP_DIR="/root/v2ray-backups"
    mkdir -p ${BACKUP_DIR}
    
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    BACKUP_FILE="${BACKUP_DIR}/v2ray-config-${TIMESTAMP}.json"
    
    cp ${V2RAY_CONFIG} ${BACKUP_FILE}
    
    if command -v nginx &> /dev/null; then
        cp /etc/nginx/sites-available/v2ray ${BACKUP_DIR}/nginx-v2ray-${TIMESTAMP}.conf
    fi
    
    echo "配置已备份到: ${BACKUP_FILE}"
    echo -e "${GREEN}✓ 备份完成${NC}"
}

# 恢复配置
restore_config() {
    echo ""
    echo "=========================================="
    echo "恢复配置"
    echo "=========================================="
    
    BACKUP_DIR="/root/v2ray-backups"
    
    if [ ! -d "${BACKUP_DIR}" ]; then
        echo -e "${RED}备份目录不存在${NC}"
        return
    fi
    
    echo "可用的备份文件:"
    ls -lh ${BACKUP_DIR}/*.json 2>/dev/null | nl
    
    read -p "请输入要恢复的文件编号（或直接输入文件名）: " file_input
    
    if [[ "$file_input" =~ ^[0-9]+$ ]]; then
        BACKUP_FILE=$(ls ${BACKUP_DIR}/*.json | sed -n "${file_input}p")
    else
        BACKUP_FILE="${BACKUP_DIR}/${file_input}"
    fi
    
    if [ ! -f "${BACKUP_FILE}" ]; then
        echo -e "${RED}文件不存在${NC}"
        return
    fi
    
    echo "恢复文件: ${BACKUP_FILE}"
    read -p "确认恢复？(y/n): " confirm
    if [ "$confirm" == "y" ] || [ "$confirm" == "Y" ]; then
        cp ${V2RAY_CONFIG} ${V2RAY_CONFIG}.backup.$(date +%Y%m%d_%H%M%S)
        cp ${BACKUP_FILE} ${V2RAY_CONFIG}
        echo -e "${GREEN}✓ 配置已恢复${NC}"
        read -p "是否重启服务？(y/n): " restart_confirm
        if [ "$restart_confirm" == "y" ] || [ "$restart_confirm" == "Y" ]; then
            restart_service
        fi
    fi
}

# 主循环
while true; do
    show_menu
    case $choice in
        1)
            check_status
            ;;
        2)
            view_logs
            ;;
        3)
            restart_service
            ;;
        4)
            stop_service
            ;;
        5)
            start_service
            ;;
        6)
            add_client
            ;;
        7)
            add_shadowsocks
            ;;
        8)
            add_vmess_tcp
            ;;
        9)
            add_vmess_tls
            ;;
        10)
            view_config
            ;;
        11)
            test_config
            ;;
        12)
            update_v2ray
            ;;
        13)
            view_stats
            ;;
        14)
            backup_config
            ;;
        15)
            restore_config
            ;;
        0)
            echo "退出"
            exit 0
            ;;
        *)
            echo -e "${RED}无效选择${NC}"
            ;;
    esac
    
    read -p "按回车继续..."
done


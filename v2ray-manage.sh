#!/bin/bash

# V2Ray 管理脚本
# 提供常用的管理功能
# 使用方法: sudo bash v2ray-manage.sh

set -e

V2RAY_CONFIG="/usr/local/etc/v2ray/config.json"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

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
    echo "6. 添加新客户端"
    echo "7. 查看当前配置"
    echo "8. 测试配置文件"
    echo "9. 更新 V2Ray"
    echo "10. 查看连接统计"
    echo "11. 备份配置"
    echo "12. 恢复配置"
    echo "0. 退出"
    echo "=========================================="
    read -p "请选择操作 [0-12]: " choice
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

# 添加新客户端
add_client() {
    echo ""
    echo "=========================================="
    echo "添加新客户端"
    echo "=========================================="
    
    # 生成新 UUID
    NEW_UUID=$(cat /proc/sys/kernel/random/uuid)
    echo "生成的新 UUID: ${NEW_UUID}"
    
    read -p "是否添加此客户端？(y/n): " confirm
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        echo "已取消"
        return
    fi
    
    # 备份配置
    cp ${V2RAY_CONFIG} ${V2RAY_CONFIG}.backup.$(date +%Y%m%d_%H%M%S)
    
    # 检查配置文件是否存在
    if [ ! -f "${V2RAY_CONFIG}" ]; then
        echo -e "${RED}错误: 配置文件不存在${NC}"
        return
    fi
    
    # 使用 Python 或 sed 添加客户端（这里使用简单的方法）
    # 注意：这个方法假设配置文件格式标准
    echo ""
    echo -e "${YELLOW}请手动编辑配置文件添加客户端：${NC}"
    echo "配置文件: ${V2RAY_CONFIG}"
    echo ""
    echo "在 clients 数组中添加："
    echo '{'
    echo '  "id": "'${NEW_UUID}'",'
    echo '  "flow": "xtls-rprx-vision"  // 仅 VLESS 需要'
    echo '}'
    echo ""
    read -p "编辑完成后按回车继续..."
    
    # 测试配置
    if /usr/local/bin/v2ray test -config ${V2RAY_CONFIG} > /dev/null 2>&1; then
        echo -e "${GREEN}✓ 配置文件测试通过${NC}"
        read -p "是否重启服务使配置生效？(y/n): " restart_confirm
        if [ "$restart_confirm" == "y" ] || [ "$restart_confirm" == "Y" ]; then
            restart_service
        fi
    else
        echo -e "${RED}✗ 配置文件测试失败，请检查配置${NC}"
        echo "已创建备份文件，可以恢复"
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
            view_config
            ;;
        8)
            test_config
            ;;
        9)
            update_v2ray
            ;;
        10)
            view_stats
            ;;
        11)
            backup_config
            ;;
        12)
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


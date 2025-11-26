# V2Ray VPN 服务器搭建指南

本指南提供在香港服务器上搭建 V2Ray VPN 的完整解决方案，专门针对中国大陆用户长期使用，重点优化抗封锁能力和稳定性。

## 📋 目录

- [方案选择](#方案选择)
- [快速开始](#快速开始)
- [详细安装步骤](#详细安装步骤)
- [客户端配置](#客户端配置)
- [服务器管理](#服务器管理)
- [高级配置](#高级配置)
- [故障排查](#故障排查)
- [最佳实践](#最佳实践)

## 🎯 方案选择

### 方案 A: VLESS + WebSocket + TLS（推荐，最强抗封锁）

**特点**：
- ✅ **最强抗封锁能力** - WebSocket + TLS 伪装成 HTTPS 流量
- ✅ **长期稳定** - 流量特征与正常网站完全一致
- ✅ **安全性高** - TLS 加密，难以被检测
- ⚠️ **需要域名** - 需要拥有域名并配置 DNS 解析

**适用场景**：
- 追求最强抗封锁能力
- 需要长期稳定运行
- 有域名资源
- 网络环境严格

### 方案 B: VMESS + WebSocket（无需域名）

**特点**：
- ✅ **无需域名** - 直接使用 IP 地址
- ✅ **配置简单** - 快速部署
- ✅ **抗封锁能力中等** - WebSocket 伪装
- ⚠️ **抗封锁能力较弱** - 不如 TLS 版本

**适用场景**：
- 暂时没有域名
- 快速测试部署
- 网络环境相对宽松

**建议**：优先使用方案 A，如果没有域名可以先使用方案 B，后续再升级到方案 A。

## 🚀 快速开始

### 方案 A: VLESS + WebSocket + TLS（推荐）

```bash
# 1. 准备域名
# - 购买域名（如：example.com）
# - 将域名 A 记录解析到服务器 IP

# 2. 上传脚本到服务器
scp v2ray-server-setup.sh root@your_server_ip:/root/

# 3. 执行安装
ssh root@your_server_ip
chmod +x v2ray-server-setup.sh
sudo bash v2ray-server-setup.sh

# 4. 按提示输入域名和 WebSocket 路径
# 5. 保存输出的配置信息
```

### 方案 B: VMESS + WebSocket（无需域名）

```bash
# 1. 上传脚本到服务器
scp v2ray-vmess-setup.sh root@your_server_ip:/root/

# 2. 执行安装
ssh root@your_server_ip
chmod +x v2ray-vmess-setup.sh
sudo bash v2ray-vmess-setup.sh

# 3. 保存输出的配置信息
```

## 📖 详细安装步骤

### 前置准备

1. **服务器要求**
   - Ubuntu 18.04+ 或 Debian 9+
   - 至少 512MB 内存
   - Root 权限
   - 已配置防火墙

2. **域名准备（方案 A）**
   - 购买域名（推荐：Namecheap、Cloudflare、GoDaddy）
   - 将域名 A 记录解析到服务器 IP
   - 等待 DNS 解析生效（通常几分钟到几小时）

3. **检查 DNS 解析**
```bash
# 检查域名是否解析到服务器 IP
ping your_domain.com
# 或
nslookup your_domain.com
```

### 安装步骤

#### 方案 A: VLESS + TLS

1. **上传脚本**
```bash
scp v2ray-server-setup.sh root@your_server_ip:/root/
```

2. **SSH 登录服务器**
```bash
ssh root@your_server_ip
```

3. **执行安装脚本**
```bash
chmod +x v2ray-server-setup.sh
sudo bash v2ray-server-setup.sh
```

4. **按提示输入信息**
   - 域名：输入你的域名（如：example.com）
   - WebSocket 路径：默认 `/v2ray` 或自定义（如：`/ws`、`/api`）

5. **等待安装完成**
   - 脚本会自动安装 V2Ray、Nginx、Certbot
   - 自动申请 SSL 证书
   - 配置 Nginx 反向代理
   - 启动服务

6. **保存配置信息**
   - 服务器地址：你的域名
   - 服务器端口：443
   - UUID：脚本生成的 UUID
   - WebSocket 路径：你输入的路径
   - TLS：已启用

#### 方案 B: VMESS（无需域名）

1. **上传脚本**
```bash
scp v2ray-vmess-setup.sh root@your_server_ip:/root/
```

2. **执行安装**
```bash
ssh root@your_server_ip
chmod +x v2ray-vmess-setup.sh
sudo bash v2ray-vmess-setup.sh
```

3. **保存配置信息**
   - 服务器 IP：脚本输出的 IP
   - 服务器端口：随机生成的端口
   - UUID：脚本生成的 UUID
   - WebSocket 路径：随机生成的路径

### 配置防火墙

```bash
# 方案 A（VLESS + TLS）
ufw allow 443/tcp
ufw allow 80/tcp   # Let's Encrypt 证书申请需要

# 方案 B（VMESS）
# 查看脚本输出的端口号，然后开放
ufw allow <端口号>/tcp

# 启用防火墙
ufw enable
```

## 📱 客户端配置

### macOS

#### 推荐客户端：V2RayU

1. **下载安装**
   - 访问：https://github.com/yanue/V2rayU
   - 下载最新版本并安装

2. **添加服务器**
   - 打开 V2RayU
   - 点击菜单栏图标 → 服务器设置
   - 点击 + 号添加服务器

3. **配置信息（VLESS + TLS）**
   - 地址：你的域名
   - 端口：443
   - UUID：服务器生成的 UUID
   - 传输协议：WebSocket
   - 路径：`/v2ray`（或你自定义的路径）
   - TLS：启用
   - 跳过证书验证：关闭（推荐）

4. **配置信息（VMESS）**
   - 地址：服务器 IP
   - 端口：脚本输出的端口
   - UUID：服务器生成的 UUID
   - 传输协议：WebSocket
   - 路径：脚本输出的路径
   - TLS：关闭

5. **连接**
   - 保存配置后，点击菜单栏图标 → 启动 V2Ray
   - 选择你添加的服务器
   - 连接成功

#### 替代客户端：ClashX

1. 下载安装 ClashX
2. 创建配置文件，添加 V2Ray 节点
3. 启动代理

### Windows

#### 推荐客户端：V2RayN

1. **下载安装**
   - 访问：https://github.com/2dust/v2rayN
   - 下载最新版本并解压

2. **添加服务器**
   - 打开 V2RayN
   - 点击服务器 → 添加 VMESS/VLESS 服务器

3. **配置信息**
   - 按照 macOS 的配置方式填入信息
   - 保存配置

4. **连接**
   - 右键系统托盘图标 → 选择服务器
   - 点击"启用系统代理"

### iOS

#### 推荐客户端：Shadowrocket（付费）

1. **购买安装**
   - App Store 搜索 Shadowrocket（需付费）
   - 购买并安装

2. **添加服务器**
   - 打开 Shadowrocket
   - 点击右上角 + 号
   - 选择类型：VLESS 或 VMESS

3. **配置信息**
   - 填入服务器配置信息
   - 保存

4. **连接**
   - 选择服务器
   - 点击连接

### Android

#### 推荐客户端：V2RayNG

1. **下载安装**
   - Google Play 或 GitHub：https://github.com/2dust/v2rayNG
   - 下载并安装

2. **添加服务器**
   - 打开 V2RayNG
   - 点击右上角 + 号
   - 手动输入或扫描二维码

3. **配置信息**
   - 填入服务器配置信息
   - 保存

4. **连接**
   - 选择服务器
   - 点击连接按钮

## 🔧 服务器管理

### 查看服务状态

```bash
# 查看 V2Ray 状态
systemctl status v2ray

# 查看 Nginx 状态（方案 A）
systemctl status nginx
```

### 查看日志

```bash
# 查看 V2Ray 日志
journalctl -u v2ray -f

# 查看最近 100 行日志
journalctl -u v2ray -n 100

# 查看 Nginx 日志（方案 A）
journalctl -u nginx -f
tail -f /var/log/nginx/error.log
```

### 重启服务

```bash
# 重启 V2Ray
systemctl restart v2ray

# 重启 Nginx（方案 A）
systemctl restart nginx

# 重启所有相关服务
systemctl restart v2ray nginx
```

### 编辑配置

```bash
# 编辑 V2Ray 配置
nano /usr/local/etc/v2ray/config.json

# 编辑 Nginx 配置（方案 A）
nano /etc/nginx/sites-available/v2ray

# 测试配置文件
/usr/local/bin/v2ray test -config /usr/local/etc/v2ray/config.json
nginx -t  # 测试 Nginx 配置
```

### 添加新客户端

编辑 V2Ray 配置文件，在 `clients` 数组中添加新的 UUID：

```bash
nano /usr/local/etc/v2ray/config.json
```

添加新的客户端：
```json
{
  "id": "新的-UUID-这里",
  "flow": "xtls-rprx-vision"  // VLESS 需要
}
```

生成新 UUID：
```bash
cat /proc/sys/kernel/random/uuid
```

重启服务：
```bash
systemctl restart v2ray
```

## 🎓 高级配置

### 修改 WebSocket 路径

```bash
# 编辑 V2Ray 配置
nano /usr/local/etc/v2ray/config.json

# 修改 wsSettings 中的 path
# 同时修改 Nginx 配置（方案 A）
nano /etc/nginx/sites-available/v2ray

# 重启服务
systemctl restart v2ray nginx
```

### 配置多用户

在 `clients` 数组中添加多个用户：

```json
"clients": [
  {
    "id": "uuid-1",
    "flow": "xtls-rprx-vision"
  },
  {
    "id": "uuid-2",
    "flow": "xtls-rprx-vision"
  }
]
```

### 启用 CDN（Cloudflare）

1. 将域名 DNS 解析改为 Cloudflare
2. 在 Cloudflare 中启用代理（橙色云朵）
3. 在 Cloudflare SSL/TLS 设置中选择"完全"模式
4. 客户端连接时使用 Cloudflare 的 IP

### 配置自动更新

```bash
# 创建更新脚本
cat > /usr/local/bin/update-v2ray.sh <<EOF
#!/bin/bash
bash <(curl -L https://raw.githubusercontent.com/v2fly/fhs-install-v2ray/master/install-release.sh)
systemctl restart v2ray
EOF

chmod +x /usr/local/bin/update-v2ray.sh

# 添加到 crontab（每月更新一次）
crontab -e
# 添加：0 0 1 * * /usr/local/bin/update-v2ray.sh
```

### SSL 证书自动续期

Let's Encrypt 证书有效期 90 天，Certbot 会自动续期。检查续期状态：

```bash
# 测试续期
certbot renew --dry-run

# 查看证书到期时间
certbot certificates
```

## 🔍 故障排查

### 连接失败

1. **检查服务状态**
```bash
systemctl status v2ray
systemctl status nginx  # 方案 A
```

2. **检查防火墙**
```bash
ufw status
# 确保端口已开放
```

3. **检查端口占用**
```bash
netstat -tulpn | grep 443  # 方案 A
netstat -tulpn | grep <端口号>  # 方案 B
```

4. **检查日志**
```bash
journalctl -u v2ray -n 50
journalctl -u nginx -n 50  # 方案 A
```

### SSL 证书问题（方案 A）

1. **检查证书是否存在**
```bash
ls -la /etc/letsencrypt/live/your_domain.com/
```

2. **重新申请证书**
```bash
certbot certonly --nginx -d your_domain.com
```

3. **检查 Nginx 配置**
```bash
nginx -t
```

### DNS 解析问题（方案 A）

1. **检查 DNS 解析**
```bash
ping your_domain.com
nslookup your_domain.com
dig your_domain.com
```

2. **等待 DNS 传播**
   - DNS 解析可能需要几分钟到几小时
   - 使用 `dig` 命令检查不同 DNS 服务器的解析结果

### 速度慢

1. **检查服务器带宽**
```bash
# 安装 speedtest
apt-get install speedtest-cli
speedtest-cli
```

2. **检查服务器负载**
```bash
top
htop
```

3. **尝试更换端口**（方案 B）
   - 某些端口可能被限速
   - 编辑配置文件更换端口

## 💡 最佳实践

### 安全性

1. **使用强密码**
   - SSH 使用密钥认证
   - 禁用 root 登录（推荐）

2. **配置防火墙**
```bash
# 只开放必要端口
ufw allow 22/tcp    # SSH
ufw allow 443/tcp   # V2Ray（方案 A）
ufw allow 80/tcp    # HTTP（证书申请）
ufw enable
```

3. **定期更新**
```bash
# 更新系统
apt-get update && apt-get upgrade -y

# 更新 V2Ray
bash <(curl -L https://raw.githubusercontent.com/v2fly/fhs-install-v2ray/master/install-release.sh)
```

4. **备份配置**
```bash
# 备份 V2Ray 配置
cp /usr/local/etc/v2ray/config.json ~/v2ray-config-backup.json

# 备份 Nginx 配置（方案 A）
cp /etc/nginx/sites-available/v2ray ~/nginx-v2ray-backup.conf
```

### 性能优化

1. **调整系统参数**
```bash
# 编辑 sysctl.conf
nano /etc/sysctl.conf

# 添加以下内容
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
net.ipv4.tcp_congestion_control = bbr

# 应用配置
sysctl -p
```

2. **启用 BBR**
```bash
# 检查是否已启用
sysctl net.ipv4.tcp_congestion_control

# 如果未启用，添加内核参数
echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
sysctl -p
```

### 监控和维护

1. **监控连接数**
```bash
# 查看 V2Ray 连接
ss -tn | grep :443 | wc -l  # 方案 A
```

2. **监控流量**
```bash
# 安装 vnstat
apt-get install vnstat
vnstat -d  # 查看每日流量
vnstat -m  # 查看每月流量
```

3. **设置日志轮转**
```bash
# V2Ray 日志默认已配置轮转
# 检查日志大小
du -sh /var/log/v2ray/
```

## 📚 相关资源

- [V2Ray 官方文档](https://www.v2fly.org/)
- [V2Ray GitHub](https://github.com/v2fly/v2ray-core)
- [V2Ray 配置文档](https://www.v2fly.org/config/overview.html)

## 📄 许可证

本项目仅供学习和合法用途使用。

## ⚠️ 免责声明

请确保你的使用符合当地法律法规。本工具仅用于技术学习和合法用途。

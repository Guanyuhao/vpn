# V2Ray VPN 服务器搭建指南

在服务器上搭建 V2Ray VPN 的完整解决方案，专门针对xx用户长期使用，重点优化抗封锁能力和稳定性。

本方案使用 **VLESS + WebSocket + TLS** 配置，提供最强的抗封锁能力和长期稳定性。

## 📋 目录

- [方案特点](#方案特点)
- [快速开始](#快速开始)
- [环境变量配置](#环境变量配置)
- [详细安装步骤](#详细安装步骤)
- [CentOS 7 特殊说明](#centos-7-特殊说明)
- [客户端配置](#客户端配置)
- [服务器管理](#服务器管理)
- [高级配置](#高级配置)
- [故障排查](#故障排查)
- [最佳实践](#最佳实践)

## 🎯 方案特点

### VLESS + WebSocket + TLS

**核心优势**：
- ✅ **最强抗封锁能力** - WebSocket + TLS 伪装成 HTTPS 流量，与正常网站流量完全一致
- ✅ **长期稳定** - 流量特征难以被识别和阻断
- ✅ **安全性高** - TLS 加密，提供企业级安全保障
- ✅ **性能优秀** - VLESS 协议轻量高效，延迟低
- ✅ **易于维护** - 配置简单，管理方便

**技术架构**：
- 协议：VLESS（V2Ray 轻量级协议）
- 传输：WebSocket（伪装成 HTTP 请求）
- 加密：TLS（HTTPS 加密）
- 反向代理：Nginx（处理 WebSocket 和 TLS）

**前置要求**：
- ⚠️ **需要域名** - 必须拥有域名并配置 DNS 解析
- ⚠️ **需要服务器** - Ubuntu 18.04+, Debian 9+, CentOS 7+, RHEL 7+
- ⚠️ **需要 Root 权限** - 用于安装和配置服务

## 🚀 快速开始

### 方法 1: 使用环境变量配置（推荐）

```bash
# 1. 准备域名
# - 购买域名（如：example.com）
# - 将域名 A 记录解析到服务器 IP
# - 等待 DNS 解析生效（通常几分钟到几小时）

# 2. 创建环境变量文件
cp .env.example .env
nano .env  # 编辑配置，至少设置 DOMAIN=your_domain.com

# 3. 上传文件到服务器
scp v2ray-server-setup.sh .env root@your_server_ip:/root/

# 4. 执行安装
ssh root@your_server_ip
chmod +x v2ray-server-setup.sh
sudo bash v2ray-server-setup.sh

# 5. 保存输出的配置信息
```

### 方法 2: 交互式安装

```bash
# 1. 准备域名（同上）

# 2. 上传脚本到服务器
scp v2ray-server-setup.sh root@your_server_ip:/root/

# 3. 执行安装（会提示输入配置信息）
ssh root@your_server_ip
chmod +x v2ray-server-setup.sh
sudo bash v2ray-server-setup.sh

# 4. 按提示输入域名和 WebSocket 路径
# 5. 保存输出的配置信息
```

### 方法 3: 命令行环境变量

```bash
# 导出环境变量
export DOMAIN=your_domain.com
export WS_PATH=/v2ray
export EMAIL=admin@your_domain.com

# 执行安装
sudo bash v2ray-server-setup.sh
```

## ⚙️ 环境变量配置

脚本支持通过环境变量配置，避免交互式输入。详细说明请查看 [ENV.md](./ENV.md)。

### 快速配置示例

创建 `.env` 文件：

```bash
# 最小配置（只需域名）
DOMAIN=example.com

# 标准配置
DOMAIN=example.com
WS_PATH=/v2ray
EMAIL=admin@example.com
LOG_LEVEL=warning

# 使用随机路径（推荐）
DOMAIN=example.com
AUTO_GENERATE_WS_PATH=true
```

### 环境变量优先级

1. **命令行环境变量** - `export DOMAIN=xxx`
2. **.env 文件** - 当前目录的 `.env` 文件
3. **交互式输入** - 如果环境变量未设置，会提示输入
4. **默认值** - 脚本中的默认值

更多配置选项请参考 [ENV.md](./ENV.md)。

## 🚀 CI/CD 自动部署

本项目支持 GitHub Actions 自动部署到服务器。

### 快速开始

1. **配置 GitHub Secrets**：
   - `SSH_PRIVATE_KEY` - SSH 私钥
   - `SERVER_HOST` - 服务器地址
   - `SERVER_USER` - SSH 用户名（可选）

2. **推送到主分支**：
   ```bash
   git push origin main
   ```

3. **自动部署**：
   - 脚本文件自动上传到服务器
   - 可在服务器上执行安装

### 详细说明

- 📖 [CI/CD 部署指南](./DEPLOY.md) - 完整部署文档
- 📖 [GitHub Actions 工作流说明](./.github/workflows/README.md) - 工作流配置说明

### 部署方式

**方式 1: 自动部署（推送到主分支）**
- 修改脚本后推送到主分支
- GitHub Actions 自动上传到服务器

**方式 2: 手动触发**
- 在 GitHub Actions 页面手动触发
- 可以指定不同的服务器和路径

**方式 3: 发布版本**
- 创建 Git 标签（如 `v1.0.0`）
- 自动创建 Release 并打包文件

## 🔧 已安装软件检测

脚本会自动检测服务器上已安装的软件：

### 自动检测功能

- ✅ **Nginx 检测** - 如果已安装，跳过安装步骤
- ✅ **Certbot 检测** - 如果已安装，跳过安装步骤
- ✅ **宝塔面板检测** - 自动检测并使用宝塔的配置目录

### 宝塔面板支持

如果检测到宝塔面板，脚本会：

1. **使用宝塔的配置目录**：
   - Nginx 配置：`/www/server/nginx/conf/vhost/域名.conf`
   - 配置文件格式符合宝塔规范

2. **跳过 Nginx 安装**：
   - Nginx 由宝塔管理，脚本只添加配置

3. **SSL 证书选项**：
   - 可以选择脚本自动申请
   - 或提示在宝塔面板中手动申请（推荐）

### 手动指定（环境变量）

如果自动检测不准确，可以在 `.env` 文件中手动指定：

```bash
# 已安装 Nginx
NGINX_INSTALLED=true

# 使用宝塔面板
BT_PANEL=true
```

## 🐧 CentOS 7 特殊说明

如果您的服务器是 **CentOS 7**，请查看专门的 [CentOS 7 安装指南](./CENTOS.md)。

**CentOS 7 主要特点**：
- ✅ 脚本自动检测并使用 `yum` 包管理器
- ✅ 自动启用 EPEL 仓库（如果需要）
- ✅ 使用 `/etc/nginx/conf.d/` 配置目录（而非 sites-available）
- ✅ 支持 `firewalld` 和 `iptables` 防火墙
- ✅ 自动处理 Certbot 安装（Python 2/3）

**快速开始（CentOS 7）**：
```bash
# 1. 准备域名并解析到服务器 IP
# 2. 上传脚本
scp v2ray-server-setup.sh .env root@your_server_ip:/root/

# 3. 执行安装（脚本会自动检测 CentOS 7）
ssh root@your_server_ip
chmod +x v2ray-server-setup.sh
sudo bash v2ray-server-setup.sh
```

详细说明请参考 [CENTOS.md](./CENTOS.md)。

### 配置防火墙

#### Ubuntu/Debian（使用 ufw）

```bash
# 开放必要端口
ufw allow 443/tcp   # HTTPS/V2Ray
ufw allow 80/tcp    # HTTP（Let's Encrypt 证书申请需要）
ufw allow 22/tcp    # SSH（如果还没开放）

# 启用防火墙
ufw enable
```

#### CentOS/RHEL（使用 firewalld）

```bash
# 开放 HTTP 和 HTTPS 服务
firewall-cmd --permanent --add-service=http
firewall-cmd --permanent --add-service=https
firewall-cmd --permanent --add-service=ssh

# 重新加载防火墙规则
firewall-cmd --reload

# 查看防火墙状态
firewall-cmd --list-all
```

#### CentOS/RHEL（使用 iptables）

```bash
# 开放端口
iptables -A INPUT -p tcp --dport 443 -j ACCEPT
iptables -A INPUT -p tcp --dport 80 -j ACCEPT
iptables -A INPUT -p tcp --dport 22 -j ACCEPT

# 保存规则（CentOS 7）
service iptables save

# 或（CentOS 6）
/etc/init.d/iptables save
```

## 📖 详细安装步骤

### 前置准备

#### 1. 服务器要求

- **操作系统**：
  - Ubuntu 18.04+ / Debian 9+（使用 apt-get）
  - CentOS 7+ / RHEL 7+（使用 yum）
- **内存**：至少 512MB（推荐 1GB+）
- **磁盘**：至少 10GB 可用空间
- **网络**：公网 IP 地址
- **权限**：Root 或 sudo 权限

**注意**：脚本会自动检测操作系统类型并使用相应的包管理器。

#### 2. 域名准备

**购买域名**（推荐服务商）：
- [Cloudflare](https://www.cloudflare.com/) - 免费 DNS，CDN 加速
- [Namecheap](https://www.namecheap.com/) - 价格实惠
- [GoDaddy](https://www.godaddy.com/) - 老牌服务商

**配置 DNS 解析**：
1. 登录域名管理后台
2. 添加 A 记录：
   - 主机记录：`@` 或 `www`（根据需求）
   - 记录值：你的服务器 IP 地址
   - TTL：600（10分钟）或默认值

**验证 DNS 解析**：
```bash
# 检查域名是否解析到服务器 IP
ping your_domain.com

# 或使用其他工具
nslookup your_domain.com
dig your_domain.com

# 确保返回的是你的服务器 IP
```

**等待 DNS 传播**：
- 通常需要几分钟到几小时
- 全球 DNS 服务器同步可能需要更长时间
- 可以使用在线工具检查：https://www.whatsmydns.net/

### 安装步骤

#### 步骤 1: 上传脚本

```bash
# 从本地电脑上传脚本到服务器
scp v2ray-server-setup.sh root@your_server_ip:/root/
```

#### 步骤 2: SSH 登录服务器

```bash
ssh root@your_server_ip
```

#### 步骤 3: 执行安装脚本

```bash
# 添加执行权限
chmod +x v2ray-server-setup.sh

# 执行安装（需要 root 权限）
sudo bash v2ray-server-setup.sh
```

#### 步骤 4: 输入配置信息

脚本会提示你输入以下信息：

1. **域名**（必填）
   ```
   请输入你的域名（用于 TLS 证书，必须输入）: example.com
   ```
   - 输入你购买的域名
   - 确保域名已解析到服务器 IP

2. **WebSocket 路径**（可选）
   ```
   请输入 WebSocket 路径（默认: /v2ray，建议使用随机路径）: 
   ```
   - 默认：`/v2ray`
   - 建议：使用随机路径以提高安全性
   - 如果选择使用随机路径，脚本会自动生成

3. **邮箱地址**（可选）
   ```
   请输入邮箱地址（用于 Let's Encrypt 证书通知，可选）: 
   ```
   - 用于接收 SSL 证书到期提醒
   - 默认使用：`admin@your_domain.com`

#### 步骤 5: 等待安装完成

脚本会自动执行以下操作：
1. ✅ 更新系统包
2. ✅ 安装/更新 V2Ray
3. ✅ 生成 UUID（客户端标识）
4. ✅ 配置 V2Ray
5. ✅ 启动 V2Ray 服务

**⚠️ 重要提示**：
- 脚本**不负责**安装和配置 Nginx，需要手动配置 Nginx 反向代理
- 脚本**不负责**申请 SSL 证书，需要手动配置 SSL 证书
- 如果服务器已安装 V2Ray，脚本会：
  - ✅ 检测到已安装的 V2Ray
  - ✅ 更新 V2Ray 到最新版本
  - ✅ **自动备份现有配置文件**（如果存在）
  - ⚠️ **覆盖现有配置文件**（会询问确认，除非设置了 `FORCE_OVERWRITE_CONFIG=true`）
  - ⚠️ **重启 V2Ray 服务**（可能导致现有连接中断）

#### 步骤 6: 保存配置信息

安装完成后，脚本会输出以下配置信息，**请务必保存**：

```
==========================================
安装完成！
==========================================
服务器地址: your_domain.com
服务器端口: 443
UUID: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
WebSocket 路径: /v2ray
TLS: 启用
==========================================
```

**配置信息说明**：
- **服务器地址**：你的域名
- **服务器端口**：443（HTTPS 标准端口）
- **UUID**：客户端唯一标识，类似密码
- **WebSocket 路径**：你设置的路径
- **TLS**：已启用（HTTPS 加密）

## 📱 客户端配置

### macOS

#### 推荐客户端：V2RayU

1. **下载安装**
   - GitHub：https://github.com/yanue/V2rayU
   - 下载最新版本 DMG 文件
   - 安装到应用程序

2. **添加服务器**
   - 打开 V2RayU
   - 点击菜单栏图标 → 服务器设置
   - 点击左下角 `+` 号添加服务器
   - 选择类型：VLESS

3. **配置服务器信息**
   - **地址**：你的域名（如：example.com）
   - **端口**：443
   - **UUID**：服务器生成的 UUID
   - **传输协议**：WebSocket
   - **路径**：`/v2ray`（或你自定义的路径）
   - **TLS**：启用
   - **跳过证书验证**：关闭（推荐，更安全）

4. **连接使用**
   - 保存配置
   - 点击菜单栏图标 → 启动 V2Ray
   - 选择你添加的服务器
   - 连接成功后，菜单栏图标会显示为已连接状态

#### 替代客户端：ClashX

1. 下载安装 ClashX
2. 创建配置文件，添加 V2Ray VLESS 节点
3. 启动代理

### Windows

#### 推荐客户端：V2RayN

1. **下载安装**
   - GitHub：https://github.com/2dust/v2rayN
   - 下载最新版本 ZIP 文件
   - 解压到任意目录

2. **添加服务器**
   - 打开 V2RayN.exe
   - 点击服务器 → 添加 [VLESS] 服务器
   - 或右键系统托盘图标 → 服务器 → 添加 [VLESS] 服务器

3. **配置服务器信息**
   - **地址(Address)**：你的域名
   - **端口(Port)**：443
   - **用户ID(UUID)**：服务器生成的 UUID
   - **传输协议(Network)**：ws
   - **路径(Path)**：`/v2ray`
   - **TLS**：tls
   - **跳过证书验证**：false

4. **连接使用**
   - 保存配置
   - 右键系统托盘图标 → 选择服务器
   - 点击"启用系统代理"
   - 连接成功后，图标会显示为已连接状态

### iOS

#### 推荐客户端：Shadowrocket（付费）

1. **购买安装**
   - App Store 搜索 Shadowrocket
   - 价格：约 $2.99（一次性付费）
   - 购买并安装

2. **添加服务器**
   - 打开 Shadowrocket
   - 点击右上角 `+` 号
   - 选择类型：VLESS

3. **配置服务器信息**
   - **服务器**：你的域名
   - **端口**：443
   - **UUID**：服务器生成的 UUID
   - **传输方式**：WebSocket
   - **路径**：`/v2ray`
   - **TLS**：启用

4. **连接使用**
   - 保存配置
   - 选择服务器
   - 点击右上角连接按钮
   - 连接成功后，状态栏会显示 VPN 图标

### Android

#### 推荐客户端：V2RayNG

1. **下载安装**
   - Google Play：搜索 V2RayNG
   - 或 GitHub：https://github.com/2dust/v2rayNG
   - 下载并安装

2. **添加服务器**
   - 打开 V2RayNG
   - 点击右上角 `+` 号
   - 选择"手动输入"或"扫描二维码"（如果有）

3. **配置服务器信息**
   - **地址**：你的域名
   - **端口**：443
   - **用户ID**：服务器生成的 UUID
   - **传输协议**：WebSocket
   - **路径**：`/v2ray`
   - **TLS**：启用

4. **连接使用**
   - 保存配置
   - 选择服务器
   - 点击右下角连接按钮（圆形按钮）
   - 首次使用需要授予 VPN 权限
   - 连接成功后，通知栏会显示 VPN 图标

## 🔧 服务器管理

### 使用管理脚本（推荐）

我们提供了一个便捷的管理脚本，可以快速执行常用操作：

```bash
# 上传管理脚本到服务器
scp v2ray-manage.sh root@your_server_ip:/root/

# 在服务器上运行
ssh root@your_server_ip
chmod +x v2ray-manage.sh
sudo bash v2ray-manage.sh
```

**管理脚本功能**：
- ✅ 查看服务状态
- ✅ 查看实时日志
- ✅ 重启/启动/停止服务
- ✅ 添加新客户端 (VLESS)
- ✅ **一键添加 Shadowsocks**
- ✅ **一键添加 VMess (TCP/mKCP/QUIC)**
- ✅ **一键添加 VMess (WS/H2/gRPC + TLS)**
- ✅ 查看当前配置
- ✅ 测试配置文件
- ✅ 更新 V2Ray
- ✅ 查看连接统计
- ✅ 备份/恢复配置

### 手动管理命令

#### 查看服务状态

```bash
# 查看 V2Ray 状态
systemctl status v2ray

# 查看 Nginx 状态
systemctl status nginx

# 查看所有相关服务状态
systemctl status v2ray nginx
```

#### 查看日志

```bash
# 查看 V2Ray 实时日志（按 Ctrl+C 退出）
journalctl -u v2ray -f

# 查看最近 100 行日志
journalctl -u v2ray -n 100

# 查看 Nginx 实时日志
journalctl -u nginx -f

# 查看 Nginx 错误日志
tail -f /var/log/nginx/error.log
```

#### 重启服务

```bash
# 重启 V2Ray
systemctl restart v2ray

# 重启 Nginx
systemctl restart nginx

# 重启所有相关服务
systemctl restart v2ray nginx

# 检查服务状态
systemctl status v2ray nginx
```

#### 停止/启动服务

```bash
# 停止服务
systemctl stop v2ray nginx

# 启动服务
systemctl start v2ray nginx

# 设置开机自启
systemctl enable v2ray nginx
```

#### 编辑配置

```bash
# 编辑 V2Ray 配置
nano /usr/local/etc/v2ray/config.json

# 编辑 Nginx 配置
nano /etc/nginx/sites-available/v2ray

# 测试 V2Ray 配置文件
/usr/local/bin/v2ray test -config /usr/local/etc/v2ray/config.json

# 测试 Nginx 配置
nginx -t

# 重新加载 Nginx 配置（不中断服务）
nginx -s reload
```

#### 添加新客户端

1. **生成新 UUID**
```bash
cat /proc/sys/kernel/random/uuid
```

2. **编辑配置文件**
```bash
nano /usr/local/etc/v2ray/config.json
```

3. **在 `clients` 数组中添加新客户端**
```json
"clients": [
  {
    "id": "existing-uuid-1",
    "flow": "xtls-rprx-vision"
  },
  {
    "id": "new-uuid-here",
    "flow": "xtls-rprx-vision"
  }
]
```

4. **测试并重启服务**
```bash
# 测试配置
/usr/local/bin/v2ray test -config /usr/local/etc/v2ray/config.json

# 重启服务
systemctl restart v2ray
```

## 🎓 高级配置

### 添加 Shadowsocks 配置

使用管理脚本一键添加 Shadowsocks：

```bash
sudo bash v2ray-manage.sh
# 选择 7. 一键添加 Shadowsocks
```

**支持的加密方法**：
- `aes-256-gcm` - 推荐，性能好
- `aes-128-gcm` - 性能好
- `chacha20-poly1305` - 移动设备友好
- `2022-blake3-aes-128-gcm` - 最新加密方法
- `2022-blake3-aes-256-gcm` - 最新加密方法

**客户端配置示例**：
```
服务器地址: your_server_ip
端口: 12345
密码: generated_password
加密方法: aes-256-gcm
```

### 添加 VMess 配置

#### VMess (TCP/mKCP/QUIC)

使用管理脚本一键添加：

```bash
sudo bash v2ray-manage.sh
# 选择 8. 一键添加 VMess (TCP/mKCP/QUIC)
```

**传输方式说明**：
- **TCP**：标准传输，稳定可靠
- **mKCP**：伪装传输，抗封锁能力强，推荐
- **QUIC**：基于 UDP，速度快

#### VMess (WS/H2/gRPC + TLS)

使用管理脚本一键添加：

```bash
sudo bash v2ray-manage.sh
# 选择 9. 一键添加 VMess (WS/H2/gRPC + TLS)
```

**传输方式说明**：
- **WebSocket (WS)**：WebSocket 传输，需要 Nginx 反向代理
- **HTTP/2 (H2)**：HTTP/2 传输，需要 Nginx 反向代理
- **gRPC**：gRPC 传输，抗封锁能力强，推荐

**注意**：需要先配置好 SSL 证书和 Nginx 反向代理

### 修改 WebSocket 路径

如果需要修改 WebSocket 路径：

1. **编辑 V2Ray 配置**
```bash
nano /usr/local/etc/v2ray/config.json
```
修改 `wsSettings` 中的 `path` 值

2. **编辑 Nginx 配置**
```bash
nano /etc/nginx/sites-available/v2ray
```
修改 `location` 后的路径

3. **重启服务**
```bash
systemctl restart v2ray nginx
```

### 配置多用户

在 `clients` 数组中添加多个用户，每个用户使用不同的 UUID：

```json
"clients": [
  {
    "id": "uuid-user-1",
    "flow": "xtls-rprx-vision"
  },
  {
    "id": "uuid-user-2",
    "flow": "xtls-rprx-vision"
  },
  {
    "id": "uuid-user-3",
    "flow": "xtls-rprx-vision"
  }
]
```

### 启用 CDN（Cloudflare）

使用 Cloudflare CDN 可以进一步提高抗封锁能力：

1. **将域名 DNS 解析改为 Cloudflare**
   - 在 Cloudflare 添加你的域名
   - 将 DNS 服务器改为 Cloudflare 提供的地址

2. **在 Cloudflare 中启用代理**
   - 找到你的域名 A 记录
   - 点击云朵图标，使其变为橙色（启用代理）

3. **配置 SSL/TLS**
   - 进入 SSL/TLS 设置
   - 加密模式选择"完全"（Full）
   - 确保"始终使用 HTTPS"已启用

4. **客户端配置**
   - 客户端连接时使用 Cloudflare 的 IP
   - 或直接使用域名（Cloudflare 会自动处理）

### 配置自动更新

创建自动更新脚本：

```bash
# 创建更新脚本
cat > /usr/local/bin/update-v2ray.sh <<'EOF'
#!/bin/bash
bash <(curl -L https://raw.githubusercontent.com/v2fly/fhs-install-v2ray/master/install-release.sh)
systemctl restart v2ray
EOF

chmod +x /usr/local/bin/update-v2ray.sh

# 添加到 crontab（每月 1 号凌晨更新）
crontab -e
# 添加以下行：
# 0 0 1 * * /usr/local/bin/update-v2ray.sh
```

### SSL 证书自动续期

Let's Encrypt 证书有效期 90 天，Certbot 会自动续期。检查续期状态：

```bash
# 测试续期（不会实际续期）
certbot renew --dry-run

# 查看证书信息
certbot certificates

# 手动续期（如果需要）
certbot renew

# 查看续期日志
journalctl -u certbot.timer
```

Certbot 会自动配置定时任务，无需手动操作。

## 🔍 故障排查

### 连接失败

#### 1. 检查服务状态

```bash
# 检查 V2Ray 服务
systemctl status v2ray

# 检查 Nginx 服务
systemctl status nginx

# 如果服务未运行，启动服务
systemctl start v2ray nginx
```

#### 2. 检查防火墙

```bash
# 查看防火墙状态
ufw status

# 确保以下端口已开放
ufw allow 443/tcp
ufw allow 80/tcp
ufw allow 22/tcp

# 如果防火墙未启用，启用它
ufw enable
```

#### 3. 检查端口占用

```bash
# 检查 443 端口是否被占用
netstat -tulpn | grep :443

# 检查 80 端口是否被占用
netstat -tulpn | grep :80

# 如果端口被其他程序占用，需要停止该程序或修改配置
```

#### 4. 检查日志

```bash
# 查看 V2Ray 日志
journalctl -u v2ray -n 50

# 查看 Nginx 日志
journalctl -u nginx -n 50
tail -f /var/log/nginx/error.log

# 查看实时日志
journalctl -u v2ray -f
```

#### 5. 测试配置文件

```bash
# 测试 V2Ray 配置
/usr/local/bin/v2ray test -config /usr/local/etc/v2ray/config.json

# 测试 Nginx 配置
nginx -t
```

### SSL 证书问题

#### 1. 检查证书是否存在

```bash
ls -la /etc/letsencrypt/live/your_domain.com/
```

应该看到以下文件：
- `cert.pem` - 证书文件
- `chain.pem` - 证书链
- `fullchain.pem` - 完整证书链
- `privkey.pem` - 私钥

#### 2. 重新申请证书

如果证书不存在或已过期：

```bash
# 停止 Nginx（申请证书时需要）
systemctl stop nginx

# 申请证书
certbot certonly --standalone -d your_domain.com

# 启动 Nginx
systemctl start nginx

# 重启 V2Ray
systemctl restart v2ray
```

#### 3. 检查 Nginx 配置

```bash
# 测试 Nginx 配置
nginx -t

# 如果配置有误，检查配置文件
nano /etc/nginx/sites-available/v2ray
```

### DNS 解析问题

#### 1. 检查 DNS 解析

```bash
# 使用 ping 检查
ping your_domain.com

# 使用 nslookup 检查
nslookup your_domain.com

# 使用 dig 检查（更详细）
dig your_domain.com
dig your_domain.com @8.8.8.8  # 使用 Google DNS
```

#### 2. 等待 DNS 传播

- DNS 解析可能需要几分钟到几小时才能全球生效
- 使用在线工具检查：https://www.whatsmydns.net/
- 确保所有 DNS 服务器都返回正确的 IP

#### 3. 检查域名配置

- 确保 A 记录指向正确的服务器 IP
- 确保没有 CNAME 记录冲突
- 检查 TTL 设置是否合理

### 速度慢

#### 1. 检查服务器带宽

```bash
# 安装 speedtest
apt-get install speedtest-cli

# 测试服务器带宽
speedtest-cli

# 或使用其他工具
curl -s https://raw.githubusercontent.com/sivel/speedtest-cli/master/speedtest.py | python3 -
```

#### 2. 检查服务器负载

```bash
# 查看系统负载
top
htop  # 如果已安装

# 查看 CPU 和内存使用
free -h
df -h
```

#### 3. 优化系统参数

参考"最佳实践"章节中的性能优化部分。

### 其他问题

#### 客户端连接后无法访问网站

1. 检查客户端配置是否正确
2. 检查系统代理设置
3. 尝试重启客户端
4. 检查防火墙规则

#### 证书即将过期

Let's Encrypt 证书会自动续期，但可以手动检查：

```bash
# 查看证书到期时间
certbot certificates

# 手动续期
certbot renew
```

## 💡 最佳实践

### 安全性

#### 1. 使用强密码和密钥认证

```bash
# 禁用密码登录，使用 SSH 密钥
nano /etc/ssh/sshd_config
# 设置：PasswordAuthentication no

# 重启 SSH 服务
systemctl restart sshd
```

#### 2. 配置防火墙

```bash
# 只开放必要端口
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp    # SSH
ufw allow 443/tcp   # HTTPS/V2Ray
ufw allow 80/tcp    # HTTP（证书申请）

# 启用防火墙
ufw enable

# 查看防火墙状态
ufw status verbose
```

#### 3. 定期更新

```bash
# 更新系统
apt-get update && apt-get upgrade -y

# 更新 V2Ray
bash <(curl -L https://raw.githubusercontent.com/v2fly/fhs-install-v2ray/master/install-release.sh)

# 重启服务
systemctl restart v2ray nginx
```

#### 4. 备份配置

```bash
# 创建备份目录
mkdir -p ~/v2ray-backups

# 备份 V2Ray 配置
cp /usr/local/etc/v2ray/config.json ~/v2ray-backups/v2ray-config-$(date +%Y%m%d).json

# 备份 Nginx 配置
cp /etc/nginx/sites-available/v2ray ~/v2ray-backups/nginx-v2ray-$(date +%Y%m%d).conf

# 定期备份（添加到 crontab）
# 0 0 * * 0 cp /usr/local/etc/v2ray/config.json ~/v2ray-backups/v2ray-config-$(date +\%Y\%m\%d).json
```

### 性能优化

#### 1. 调整系统参数

```bash
# 编辑 sysctl.conf
nano /etc/sysctl.conf

# 添加以下内容
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
net.ipv4.tcp_congestion_control = bbr
net.ipv4.tcp_fastopen = 3

# 应用配置
sysctl -p
```

#### 2. 启用 BBR

BBR 是 Google 开发的 TCP 拥塞控制算法，可以显著提升网络性能：

```bash
# 检查内核版本（需要 4.9+）
uname -r

# 检查是否已启用 BBR
sysctl net.ipv4.tcp_congestion_control

# 如果未启用，添加以下内容到 /etc/sysctl.conf
echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf

# 应用配置
sysctl -p

# 验证 BBR 已启用
sysctl net.ipv4.tcp_congestion_control
# 应该输出：net.ipv4.tcp_congestion_control = bbr
```

#### 3. 优化 Nginx

```bash
# 编辑 Nginx 配置
nano /etc/nginx/nginx.conf

# 在 http 块中添加
worker_processes auto;
worker_connections 1024;

# 启用 gzip 压缩
gzip on;
gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;
```

### 监控和维护

#### 1. 监控连接数

```bash
# 查看当前连接数
ss -tn | grep :443 | wc -l

# 查看连接详情
ss -tn | grep :443
```

#### 2. 监控流量

```bash
# 安装 vnstat
apt-get install vnstat

# 初始化（首次使用）
vnstat -u -i eth0  # eth0 是你的网卡名称，使用 ifconfig 查看

# 查看每日流量
vnstat -d

# 查看每月流量
vnstat -m

# 实时监控
vnstat -l
```

#### 3. 设置日志轮转

V2Ray 和 Nginx 默认已配置日志轮转，但可以检查：

```bash
# 查看 V2Ray 日志大小
du -sh /var/log/v2ray/

# 查看 Nginx 日志大小
du -sh /var/log/nginx/

# 手动清理旧日志（谨慎操作）
journalctl --vacuum-time=30d  # 保留最近 30 天
```

#### 4. 定期健康检查

创建健康检查脚本：

```bash
cat > /usr/local/bin/v2ray-health-check.sh <<'EOF'
#!/bin/bash
if ! systemctl is-active --quiet v2ray; then
    echo "V2Ray is down, restarting..."
    systemctl restart v2ray
fi
if ! systemctl is-active --quiet nginx; then
    echo "Nginx is down, restarting..."
    systemctl restart nginx
fi
EOF

chmod +x /usr/local/bin/v2ray-health-check.sh

# 添加到 crontab（每 5 分钟检查一次）
crontab -e
# 添加：*/5 * * * * /usr/local/bin/v2ray-health-check.sh
```

## 📚 相关资源

- [V2Ray 官方文档](https://www.v2fly.org/)
- [V2Ray GitHub](https://github.com/v2fly/v2ray-core)
- [V2Ray 配置文档](https://www.v2fly.org/config/overview.html)
- [Let's Encrypt 文档](https://letsencrypt.org/docs/)

## 📄 许可证

本项目仅供学习和合法用途使用。

## ⚠️ 免责声明

请确保你的使用符合当地法律法规。本工具仅用于技术学习和合法用途。

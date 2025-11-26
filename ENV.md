# 环境变量配置文档

本文档说明如何使用环境变量配置 V2Ray 服务器。

## 📋 目录

- [快速开始](#快速开始)
- [环境变量说明](#环境变量说明)
- [使用方法](#使用方法)
- [配置示例](#配置示例)
- [常见问题](#常见问题)

## 🚀 快速开始

### 1. 创建环境变量文件

```bash
# 复制模板文件
cp .env.example .env

# 编辑配置文件
nano .env
```

### 2. 配置必需项

至少需要配置以下项：

```bash
DOMAIN=your_domain.com
```

### 3. 运行安装脚本

```bash
sudo bash v2ray-server-setup.sh
```

脚本会自动读取 `.env` 文件中的配置。

## 📝 环境变量说明

### 必需配置

#### `DOMAIN`
- **说明**: 你的域名，用于 TLS 证书
- **示例**: `example.com`
- **必需**: ✅ 是
- **注意**: 域名必须已解析到服务器 IP

#### `WS_PATH`
- **说明**: WebSocket 路径
- **默认值**: `/v2ray`
- **示例**: `/v2ray` 或 `/ws` 或 `/api`
- **必需**: ❌ 否（留空将使用默认值或自动生成）
- **建议**: 使用随机路径以提高安全性

### 可选配置

#### `EMAIL`
- **说明**: 邮箱地址，用于 Let's Encrypt 证书通知
- **默认值**: `admin@${DOMAIN}`
- **示例**: `admin@example.com`
- **必需**: ❌ 否

#### `V2RAY_PORT`
- **说明**: V2Ray 监听端口
- **默认值**: `443`
- **示例**: `443`
- **必需**: ❌ 否
- **注意**: 通常不需要修改，443 是 HTTPS 标准端口

#### `V2RAY_INTERNAL_PORT`
- **说明**: V2Ray 内部端口，Nginx 代理使用
- **默认值**: `10000`
- **示例**: `10000`
- **必需**: ❌ 否
- **注意**: 通常不需要修改

#### `LOG_LEVEL`
- **说明**: V2Ray 日志级别
- **默认值**: `warning`
- **可选值**: `debug`, `info`, `warning`, `error`, `none`
- **必需**: ❌ 否
- **建议**: 
  - 生产环境使用 `warning` 或 `error`
  - 调试时使用 `debug` 或 `info`

#### `AUTO_GENERATE_WS_PATH`
- **说明**: 是否自动生成随机 WebSocket 路径
- **默认值**: `true`
- **可选值**: `true`, `false`
- **必需**: ❌ 否
- **说明**: 
  - `true`: 自动生成随机路径（推荐，更安全）
  - `false`: 使用 `WS_PATH` 的值，如果为空则使用 `/v2ray`

#### `UUID`
- **说明**: 客户端 UUID
- **默认值**: 自动生成
- **示例**: `12345678-1234-1234-1234-123456789abc`
- **必需**: ❌ 否
- **注意**: 留空将自动生成新的 UUID

#### `NGINX_INSTALLED`
- **说明**: 是否已安装 Nginx
- **默认值**: 自动检测
- **可选值**: `true`, `false`, 留空（自动检测）
- **必需**: ❌ 否
- **注意**: 
  - 留空：脚本自动检测
  - `true`：跳过安装步骤
  - `false`：强制重新安装

#### `BT_PANEL`
- **说明**: 是否使用宝塔面板
- **默认值**: 自动检测
- **可选值**: `true`, `false`, 留空（自动检测）
- **必需**: ❌ 否
- **注意**: 
  - 留空：脚本自动检测宝塔面板
  - `true`：使用宝塔的配置目录（`/www/server/nginx/conf/vhost/`）
  - `false`：使用标准配置目录

### 高级配置

以下配置通常不需要修改，仅在特殊情况下使用：

#### `NGINX_CONFIG_DIR`
- **说明**: Nginx 配置目录
- **默认值**: `/etc/nginx/sites-available`
- **必需**: ❌ 否

#### `V2RAY_CONFIG_DIR`
- **说明**: V2Ray 配置目录
- **默认值**: `/usr/local/etc/v2ray`
- **必需**: ❌ 否

#### `FORCE_OVERWRITE_CONFIG`
- **说明**: 是否强制覆盖现有配置文件（不询问确认）
- **默认值**: `false`
- **可选值**: `true`, `false`
- **必需**: ❌ 否
- **警告**: 
  - 设置为 `true` 时，如果检测到现有配置，将自动备份并覆盖，不会询问确认
  - 适用于自动化部署场景（如 CI/CD）
  - **注意**: 即使设置为 `true`，脚本仍会创建备份文件

#### `SSL_CERT_DIR`
- **说明**: SSL 证书目录
- **默认值**: `/etc/letsencrypt/live`
- **必需**: ❌ 否

#### `CERTBOT_METHOD`
- **说明**: Let's Encrypt 证书申请方式
- **默认值**: `nginx`
- **可选值**: `standalone`, `nginx`, `apache`
- **必需**: ❌ 否

#### `ENABLE_TLS`
- **说明**: 是否启用 TLS
- **默认值**: `true`
- **可选值**: `true`, `false`
- **必需**: ❌ 否
- **警告**: 设置为 `false` 将不使用 TLS，不推荐！

## 💡 使用方法

### 方法 1: 使用 .env 文件（推荐）

1. **创建配置文件**
```bash
cp .env.example .env
nano .env
```

2. **编辑配置**
```bash
DOMAIN=your_domain.com
WS_PATH=/v2ray
EMAIL=your_email@example.com
```

3. **运行脚本**
```bash
sudo bash v2ray-server-setup.sh
```

脚本会自动读取 `.env` 文件。

### 方法 2: 导出环境变量

```bash
export DOMAIN=your_domain.com
export WS_PATH=/v2ray
export EMAIL=your_email@example.com

sudo bash v2ray-server-setup.sh
```

### 方法 3: 在命令行中设置

```bash
DOMAIN=your_domain.com WS_PATH=/v2ray sudo bash v2ray-server-setup.sh
```

## 📋 配置示例

### 示例 1: 最小配置

```bash
# .env
DOMAIN=example.com
```

### 示例 2: 标准配置

```bash
# .env
DOMAIN=example.com
WS_PATH=/v2ray
EMAIL=admin@example.com
LOG_LEVEL=warning
```

### 示例 3: 使用随机路径

```bash
# .env
DOMAIN=example.com
AUTO_GENERATE_WS_PATH=true
# WS_PATH 留空，将自动生成随机路径
```

### 示例 4: 自定义路径

```bash
# .env
DOMAIN=example.com
WS_PATH=/my-custom-path
AUTO_GENERATE_WS_PATH=false
```

### 示例 5: 使用已有 UUID

```bash
# .env
DOMAIN=example.com
UUID=12345678-1234-1234-1234-123456789abc
```

### 示例 6: 调试配置

```bash
# .env
DOMAIN=example.com
LOG_LEVEL=debug
```

### 示例 7: 宝塔面板配置

```bash
# .env
DOMAIN=example.com
BT_PANEL=true
NGINX_INSTALLED=true
# 脚本会自动使用宝塔的配置目录
```

### 示例 8: 已安装 Nginx 的服务器

```bash
# .env
DOMAIN=example.com
NGINX_INSTALLED=true
# 脚本会跳过 Nginx 安装，只配置现有 Nginx
```

## 🔍 环境变量优先级

脚本读取环境变量的优先级（从高到低）：

1. **命令行环境变量** - `export DOMAIN=xxx`
2. **.env 文件** - 当前目录的 `.env` 文件
3. **默认值** - 脚本中的默认值

## ❓ 常见问题

### Q1: 如何查看当前使用的配置？

安装完成后，脚本会输出所有配置信息。你也可以查看：

```bash
# 查看 V2Ray 配置
cat /usr/local/etc/v2ray/config.json

# 查看环境变量（如果使用 .env）
cat .env
```

### Q2: 修改 .env 后需要重新安装吗？

不需要重新安装。修改配置后：

1. 手动编辑配置文件：
```bash
nano /usr/local/etc/v2ray/config.json
nano /etc/nginx/sites-available/v2ray
```

2. 重启服务：
```bash
systemctl restart v2ray nginx
```

### Q3: 可以在安装后使用 .env 文件吗？

可以。管理脚本也会读取 `.env` 文件（如果存在）。但主要配置已经写入到配置文件中，修改 `.env` 不会自动更新已安装的配置。

### Q4: 如何生成随机 WebSocket 路径？

设置 `AUTO_GENERATE_WS_PATH=true` 并留空 `WS_PATH`，脚本会自动生成随机路径。

### Q5: 多个域名怎么办？

当前脚本只支持单个域名。如果需要多个域名，需要：

1. 手动编辑 Nginx 配置添加多个 server 块
2. 为每个域名申请 SSL 证书
3. 配置多个 V2Ray inbound

### Q6: 如何备份环境变量配置？

```bash
# 备份 .env 文件
cp .env .env.backup

# 或添加到版本控制（注意：不要提交包含敏感信息的 .env）
git add .env.example
# .env 应该在 .gitignore 中
```

## 🔒 安全建议

1. **不要提交 .env 文件到版本控制**
   ```bash
   # 添加到 .gitignore
   echo ".env" >> .gitignore
   ```

2. **使用强随机路径**
   - 设置 `AUTO_GENERATE_WS_PATH=true`
   - 不要使用常见的路径如 `/v2ray`、`/ws`

3. **保护 .env 文件权限**
   ```bash
   chmod 600 .env
   ```

4. **定期更新 UUID**
   - 如果 UUID 泄露，及时更换

## 📚 相关文档

- [README.md](./README.md) - 完整安装文档
- [QUICKSTART.md](./QUICKSTART.md) - 快速参考


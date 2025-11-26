# V2Ray 管理脚本使用指南

## 📋 功能列表

### 基础管理功能

1. **查看服务状态** - 查看 V2Ray 和 Nginx 服务状态
2. **查看实时日志** - 实时查看 V2Ray 日志
3. **重启服务** - 重启 V2Ray 和 Nginx 服务
4. **停止服务** - 停止 V2Ray 服务
5. **启动服务** - 启动 V2Ray 服务

### 配置管理功能

6. **添加新客户端 (VLESS)** - 为现有 VLESS 配置添加新用户
7. **一键添加 Shadowsocks** - 快速添加 Shadowsocks 配置
8. **一键添加 VMess (TCP/mKCP/QUIC)** - 添加 VMess 配置（无 TLS）
9. **一键添加 VMess (WS/H2/gRPC + TLS)** - 添加带 TLS 的 VMess 配置

### 其他功能

10. **查看当前配置** - 查看 V2Ray 配置信息
11. **测试配置文件** - 验证配置文件是否正确
12. **更新 V2Ray** - 更新 V2Ray 到最新版本
13. **查看连接统计** - 查看连接数和日志
14. **备份配置** - 备份当前配置
15. **恢复配置** - 从备份恢复配置

## 🚀 快速开始

```bash
# 运行管理脚本
sudo bash v2ray-manage.sh
```

## 📖 详细功能说明

### 6. 添加新客户端 (VLESS)

为现有的 VLESS + WebSocket 配置添加新用户。

**功能**：
- 自动生成 UUID
- 自动修改配置文件
- 自动测试配置
- 可选重启服务

**使用场景**：
- 需要为多个用户创建不同的账号
- 需要临时添加测试账号

### 7. 一键添加 Shadowsocks

快速添加 Shadowsocks 配置，无需手动编辑 JSON。

**支持的加密方法**：
- `aes-256-gcm` - 推荐，性能好，安全性高
- `aes-128-gcm` - 性能好
- `chacha20-poly1305` - 移动设备友好
- `2022-blake3-aes-128-gcm` - 最新加密方法
- `2022-blake3-aes-256-gcm` - 最新加密方法

**配置流程**：
1. 选择加密方法
2. 输入端口（或使用随机端口）
3. 自动生成密码
4. 确认并添加

**客户端配置示例**：
```
服务器地址: your_server_ip
端口: 12345
密码: generated_password
加密方法: aes-256-gcm
```

### 8. 一键添加 VMess (TCP/mKCP/QUIC)

快速添加 VMess 配置，支持多种传输方式。

**传输方式**：

#### TCP
- 标准 TCP 传输
- 稳定可靠
- 适合日常使用

#### mKCP (推荐)
- 伪装传输
- 抗封锁能力强
- 适合被封锁环境

**配置示例**：
```json
{
  "network": "kcp",
  "kcpSettings": {
    "uplinkCapacity": 5,
    "downlinkCapacity": 20,
    "congestion": false,
    "header": {
      "type": "wechat-video"
    }
  }
}
```

#### QUIC
- 基于 UDP 的快速传输
- 延迟低
- 适合游戏等低延迟场景

**配置流程**：
1. 选择传输方式（TCP/mKCP/QUIC）
2. 输入端口（或使用随机端口）
3. 自动生成 UUID
4. 确认并添加

### 9. 一键添加 VMess (WS/H2/gRPC + TLS)

快速添加带 TLS 加密的 VMess 配置，抗封锁能力强。

**传输方式**：

#### WebSocket (WS)
- WebSocket 传输
- 需要 Nginx 反向代理
- 适合已有 Nginx 配置

**配置示例**：
```json
{
  "network": "ws",
  "security": "tls",
  "wsSettings": {
    "path": "/random_path"
  },
  "tlsSettings": {
    "certificates": [{
      "certificateFile": "/path/to/fullchain.pem",
      "keyFile": "/path/to/privkey.pem"
    }]
  }
}
```

#### HTTP/2 (H2)
- HTTP/2 传输
- 需要 Nginx 反向代理
- 伪装成 HTTPS 流量

**配置示例**：
```json
{
  "network": "h2",
  "security": "tls",
  "httpSettings": {
    "path": "/",
    "host": ["your_domain.com"]
  },
  "tlsSettings": {
    "certificates": [{
      "certificateFile": "/path/to/fullchain.pem",
      "keyFile": "/path/to/privkey.pem"
    }]
  }
}
```

#### gRPC (推荐)
- gRPC 传输
- 抗封锁能力最强
- 推荐用于被严格封锁的环境

**配置示例**：
```json
{
  "network": "grpc",
  "security": "tls",
  "grpcSettings": {
    "serviceName": "random_service_name"
  },
  "tlsSettings": {
    "certificates": [{
      "certificateFile": "/path/to/fullchain.pem",
      "keyFile": "/path/to/privkey.pem"
    }]
  }
}
```

**配置流程**：
1. 选择传输方式（WS/H2/gRPC）
2. 输入端口（或使用随机端口）
3. 输入域名
4. 输入 SSL 证书路径
5. 自动生成路径/serviceName
6. 确认并添加

**注意**：
- 需要先配置好 SSL 证书
- gRPC 和 WS 需要配置 Nginx 反向代理
- H2 需要配置 Nginx HTTP/2 支持

## 🔧 技术实现

### JSON 配置修改

脚本使用 Python 3 来安全地修改 JSON 配置文件：

```python
import json
import sys

config_file = sys.argv[1]
# ... 修改配置 ...
with open(config_file, 'w') as f:
    json.dump(config, f, indent=2)
```

### 自动备份

每次修改配置前会自动创建备份：
- 备份文件名：`config.json.backup.YYYYMMDD_HHMMSS`
- 如果修改失败，自动恢复备份

### 配置测试

添加配置后会自动测试：
```bash
/usr/local/bin/v2ray test -config /usr/local/etc/v2ray/config.json
```

## 📝 使用示例

### 示例 1: 添加 Shadowsocks

```bash
sudo bash v2ray-manage.sh
# 选择 7
# 选择加密方法: 1 (aes-256-gcm)
# 输入端口: 12345
# 确认添加: y
# 重启服务: y
```

### 示例 2: 添加 VMess (mKCP)

```bash
sudo bash v2ray-manage.sh
# 选择 8
# 选择传输方式: 2 (mKCP)
# 输入端口: 23456
# 确认添加: y
# 重启服务: y
```

### 示例 3: 添加 VMess (gRPC + TLS)

```bash
sudo bash v2ray-manage.sh
# 选择 9
# 选择传输方式: 3 (gRPC)
# 输入端口: 34567
# 输入域名: example.com
# 输入证书路径: /etc/letsencrypt/live/example.com/fullchain.pem
# 输入私钥路径: /etc/letsencrypt/live/example.com/privkey.pem
# 确认添加: y
# 重启服务: y
```

## ⚠️ 注意事项

1. **Python 要求**：脚本需要 Python 3 来修改 JSON 配置
   - 大多数 Linux 系统已预装 Python 3
   - 如果没有，请安装：`apt-get install python3` 或 `yum install python3`

2. **配置文件备份**：
   - 每次修改前自动备份
   - 备份文件保存在配置文件同目录
   - 如果修改失败会自动恢复

3. **服务重启**：
   - 添加配置后需要重启 V2Ray 服务
   - 脚本会提示是否重启
   - 建议重启以确保配置生效

4. **端口冲突**：
   - 确保选择的端口未被占用
   - 可以使用 `netstat -tuln | grep PORT` 检查

5. **SSL 证书**：
   - VMess (WS/H2/gRPC + TLS) 需要 SSL 证书
   - 证书路径必须正确
   - 建议使用 Let's Encrypt 证书

## 🐛 故障排查

### 问题 1: Python 未安装

**错误信息**：
```
错误: 需要 Python 来修改配置
```

**解决方法**：
```bash
# Ubuntu/Debian
apt-get install python3

# CentOS/RHEL
yum install python3
```

### 问题 2: 配置文件测试失败

**错误信息**：
```
✗ 配置文件测试失败，已恢复备份
```

**解决方法**：
1. 检查 JSON 语法是否正确
2. 检查端口是否冲突
3. 查看详细错误：`/usr/local/bin/v2ray test -config /usr/local/etc/v2ray/config.json`

### 问题 3: 服务重启失败

**错误信息**：
```
✗ 服务重启失败
```

**解决方法**：
```bash
# 查看服务状态
systemctl status v2ray

# 查看日志
journalctl -u v2ray -n 50
```

## 📚 相关文档

- [README.md](./README.md) - 完整安装和使用文档
- [ENV.md](./ENV.md) - 环境变量配置文档


# CI/CD 部署指南

本文档说明如何使用 GitHub Actions 自动部署 V2Ray 安装脚本到服务器。

## 🚀 快速开始

### 1. 配置 GitHub Secrets

在 GitHub 仓库设置中添加以下 Secrets：

| Secret 名称 | 说明 | 必需 |
|------------|------|------|
| `SSH_PRIVATE_KEY` | SSH 私钥 | ✅ 是 |
| `SERVER_HOST` | 服务器地址 | ✅ 是 |
| `SERVER_USER` | SSH 用户名 | ❌ 否（默认：root） |
| `DEPLOY_PATH` | 部署路径 | ❌ 否（默认：/root/v2ray-setup） |
| `AUTO_INSTALL` | 自动安装 | ❌ 否（默认：false） |

### 2. 生成 SSH 密钥对

```bash
# 在本地生成 SSH 密钥对
ssh-keygen -t rsa -b 4096 -C "github-actions" -f ~/.ssh/github_actions

# 查看私钥（复制到 GitHub Secrets）
cat ~/.ssh/github_actions

# 查看公钥（添加到服务器 authorized_keys）
cat ~/.ssh/github_actions.pub
```

### 3. 配置服务器 SSH 访问

```bash
# 在服务器上添加公钥
mkdir -p ~/.ssh
chmod 700 ~/.ssh
echo "你的公钥内容" >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys

# 测试 SSH 连接
ssh -i ~/.ssh/github_actions user@server_host
```

### 4. 触发部署

#### 方法 1: 自动部署（推送到主分支）

```bash
git add .
git commit -m "Update scripts"
git push origin main
```

#### 方法 2: 手动触发

1. 进入 GitHub Actions 页面
2. 选择 "Deploy to Server" 工作流
3. 点击 "Run workflow"
4. 填写服务器信息并运行

## 📋 部署流程

### 自动部署流程

```
1. 代码推送到主分支
   ↓
2. GitHub Actions 触发
   ↓
3. 检查代码
   ↓
4. 建立 SSH 连接
   ↓
5. 创建部署目录
   ↓
6. 上传脚本文件
   ↓
7. 设置文件权限
   ↓
8. （可选）执行安装脚本
   ↓
9. 完成部署
```

### 部署的文件

- `v2ray-server-setup.sh` - 安装脚本
- `v2ray-manage.sh` - 管理脚本
- `.env.example` - 环境变量模板（如果存在）

## 🔧 配置说明

### GitHub Secrets 详细说明

#### SSH_PRIVATE_KEY

SSH 私钥内容，用于连接服务器。

**生成方法**：
```bash
ssh-keygen -t rsa -b 4096 -C "github-actions"
cat ~/.ssh/id_rsa  # 复制整个内容
```

**注意事项**：
- 包含 `-----BEGIN OPENSSH PRIVATE KEY-----` 和 `-----END OPENSSH PRIVATE KEY-----`
- 不要包含密码短语（passphrase）

#### SERVER_HOST

服务器地址，可以是 IP 或域名。

**示例**：
- `192.168.1.100`
- `server.example.com`
- `vpn.example.com`

#### SERVER_USER

SSH 用户名，默认为 `root`。

**示例**：
- `root`
- `ubuntu`
- `admin`

#### DEPLOY_PATH

文件部署路径，默认为 `/root/v2ray-setup`。

**示例**：
- `/root/v2ray-setup`
- `/opt/v2ray`
- `/home/user/v2ray`

#### AUTO_INSTALL

是否自动执行安装脚本，默认为 `false`。

**值**：
- `true` - 自动执行安装脚本
- `false` - 仅上传文件（推荐）

## 🎯 使用场景

### 场景 1: 仅上传文件（推荐）

**配置**：
- `AUTO_INSTALL` = `false`（或不设置）

**流程**：
1. 文件上传到服务器
2. 手动登录服务器执行安装
3. 更安全，可以检查文件后再安装

### 场景 2: 自动安装

**配置**：
- `AUTO_INSTALL` = `true`

**流程**：
1. 文件上传到服务器
2. 自动执行安装脚本
3. 适合测试环境或信任的环境

### 场景 3: 多服务器部署

**方法**：
1. 为每个服务器创建不同的 Secrets
2. 使用 GitHub Environments
3. 或创建多个工作流文件

## 🔒 安全最佳实践

### 1. SSH 密钥安全

```bash
# 使用强密钥
ssh-keygen -t ed25519 -C "github-actions"

# 限制密钥用途（在服务器上）
# 在 authorized_keys 中添加：
command="/bin/true",no-port-forwarding,no-X11-forwarding,no-pty ssh-ed25519 AAAAC3...
```

### 2. 服务器安全

```bash
# 禁用密码登录
sudo nano /etc/ssh/sshd_config
# 设置：PasswordAuthentication no

# 限制 SSH 访问 IP（如果可能）
# 在防火墙中限制 GitHub Actions IP 范围
```

### 3. 最小权限

```bash
# 创建专用部署用户
sudo useradd -m -s /bin/bash deploy
sudo mkdir -p /home/deploy/v2ray-setup
sudo chown deploy:deploy /home/deploy/v2ray-setup
```

## 🐛 故障排查

### 问题 1: SSH 连接失败

**错误信息**：
```
Permission denied (publickey)
```

**解决方法**：
1. 检查 SSH 私钥是否正确
2. 检查服务器公钥是否已添加
3. 检查服务器 SSH 配置
4. 检查防火墙设置

### 问题 2: 文件上传失败

**错误信息**：
```
scp: /root/v2ray-setup: Permission denied
```

**解决方法**：
1. 检查部署路径是否存在
2. 检查用户权限
3. 手动创建目录：`mkdir -p /root/v2ray-setup`

### 问题 3: 自动安装失败

**错误信息**：
```
安装脚本执行失败
```

**解决方法**：
1. 检查脚本权限：`chmod +x v2ray-server-setup.sh`
2. 检查服务器环境
3. 查看 GitHub Actions 日志
4. 手动登录服务器执行安装

## 📊 工作流状态

### 查看部署状态

1. 进入 GitHub 仓库
2. 点击 "Actions" 标签
3. 查看工作流运行状态

### 查看日志

1. 点击工作流运行
2. 展开各个步骤
3. 查看详细日志

## 🔄 回滚

如果部署出现问题，可以：

1. **回滚代码**：
```bash
git revert HEAD
git push origin main
```

2. **手动删除文件**：
```bash
ssh user@server_host
rm -rf /root/v2ray-setup
```

3. **使用之前的版本**：
```bash
git checkout <previous-commit>
git push origin main --force
```

## 📚 相关文档

- [GitHub Actions 文档](https://docs.github.com/en/actions)
- [SSH 密钥管理](https://docs.github.com/en/authentication/connecting-to-github-with-ssh)
- [工作流语法](https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions)

## 💡 提示

1. **首次部署建议**：
   - 使用 `AUTO_INSTALL=false`
   - 手动检查文件后再安装

2. **测试环境**：
   - 可以先在测试服务器上测试
   - 确认无误后再部署到生产环境

3. **版本管理**：
   - 使用 Git 标签管理版本
   - 使用 Release 工作流创建发布包


# GitHub Actions 工作流说明

本目录包含 GitHub Actions CI/CD 工作流配置。

## 📋 工作流文件

### 1. `deploy.yml` - 自动部署工作流

**触发条件**：
- 推送到 `main` 或 `master` 分支
- 发布 Release
- 手动触发（workflow_dispatch）

**功能**：
- ✅ 自动上传脚本文件到服务器
- ✅ 设置文件权限
- ✅ 可选自动执行安装脚本

**使用方法**：

#### 方法 1: 使用 GitHub Secrets（推荐）

1. 在 GitHub 仓库设置中添加 Secrets：
   - `SSH_PRIVATE_KEY` - SSH 私钥
   - `SERVER_HOST` - 服务器地址
   - `SERVER_USER` - SSH 用户名（默认：root）
   - `DEPLOY_PATH` - 部署路径（默认：/root/v2ray-setup）
   - `AUTO_INSTALL` - 是否自动安装（true/false，可选）

2. 推送到主分支即可自动部署

#### 方法 2: 手动触发

1. 进入 GitHub Actions 页面
2. 选择 "Deploy to Server" 工作流
3. 点击 "Run workflow"
4. 填写服务器信息
5. 选择是否执行安装脚本

### 2. `test.yml` - 代码检查工作流

**触发条件**：
- Pull Request
- 推送到主分支

**功能**：
- ✅ ShellCheck 代码检查
- ✅ Bash 语法检查

### 3. `release.yml` - 发布工作流

**触发条件**：
- 推送版本标签（如 `v1.0.0`）

**功能**：
- ✅ 自动创建 Release
- ✅ 打包文件（tar.gz 和 zip）
- ✅ 上传到 GitHub Release

**使用方法**：
```bash
# 创建并推送标签
git tag v1.0.0
git push origin v1.0.0

# Release 说明中会自动包含域名信息
```

## 🔐 配置 GitHub Secrets

### 必需配置

1. **SSH_PRIVATE_KEY**
   - 服务器 SSH 私钥
   - 生成方法：
     ```bash
     ssh-keygen -t rsa -b 4096 -C "github-actions"
     # 将私钥内容复制到 GitHub Secrets
     cat ~/.ssh/id_rsa
     ```

2. **SERVER_HOST**
   - 服务器 IP 地址或域名
   - 示例：`192.168.1.100` 或 `server.example.com`

### 可选配置

3. **SERVER_USER**
   - SSH 用户名
   - 默认：`root`

4. **DEPLOY_PATH**
   - 部署路径
   - 默认：`/root/v2ray-setup`

5. **AUTO_INSTALL**
   - 是否自动执行安装脚本
   - 可选值：`true` 或 `false`
   - 默认：`false`（仅上传文件）

## 📝 使用示例

### 示例 1: 自动部署（使用 Secrets）

```yaml
# 在 GitHub 仓库设置中配置 Secrets 后
# 推送到主分支即可自动部署
git add .
git commit -m "Update scripts"
git push origin main
```

### 示例 2: 手动触发部署

1. 进入 GitHub Actions
2. 选择 "Deploy to Server"
3. 点击 "Run workflow"
4. 填写：
   - Server Host: `192.168.1.100`
   - Server User: `root`
   - Deploy Path: `/root/v2ray-setup`
   - Run Install: `false`

### 示例 3: 创建 Release

```bash
# 创建版本标签
git tag -a v1.0.0 -m "Release version 1.0.0"
git push origin v1.0.0

# GitHub Actions 会自动：
# 1. 创建 Release
# 2. 打包文件
# 3. 上传到 Release 页面
```

## 🔒 安全建议

1. **使用 SSH 密钥认证**
   - 不要使用密码认证
   - 使用强密钥（至少 2048 位）

2. **限制 SSH 访问**
   - 使用防火墙限制 SSH 访问 IP
   - 禁用 root 密码登录

3. **保护 Secrets**
   - 不要在代码中硬编码敏感信息
   - 定期轮换 SSH 密钥

4. **最小权限原则**
   - 使用非 root 用户（如果可能）
   - 限制部署路径权限

## 🐛 故障排查

### SSH 连接失败

1. 检查 SSH 私钥是否正确
2. 检查服务器地址是否正确
3. 检查防火墙是否开放 SSH 端口（22）
4. 检查服务器 SSH 服务是否运行

### 文件上传失败

1. 检查部署路径是否存在
2. 检查用户权限是否足够
3. 检查磁盘空间是否充足

### 自动安装失败

1. 检查服务器是否已安装必要依赖
2. 检查脚本权限是否正确
3. 查看 GitHub Actions 日志

## 📚 相关文档

- [GitHub Actions 文档](https://docs.github.com/en/actions)
- [SSH 密钥生成指南](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent)


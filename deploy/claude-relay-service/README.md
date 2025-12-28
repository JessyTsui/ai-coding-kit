# Claude Relay Service - Zeabur 一键部署

让团队成员共享 Claude Code 订阅，无需命令行，网页操作即可完成部署。

## 一键部署（推荐）

### 步骤 1：Fork 本仓库

点击 GitHub 页面右上角的 **Fork** 按钮，将仓库 fork 到你的账号下。

### 步骤 2：登录 Zeabur

访问 [Zeabur](https://zeabur.com) 并登录（支持 GitHub 登录）。

### 步骤 3：创建项目

1. 点击 **Create Project**
2. 选择区域：**Hong Kong**（国内用户推荐）

### 步骤 4：部署服务

1. 点击 **Add Service** → **Git**
2. 选择你 fork 的 `ai-coding-kit` 仓库
3. **重要**：设置 Root Directory 为：
   ```
   /deploy/claude-relay-service
   ```
4. 点击 **Deploy**

![Root Directory 设置示意](https://img.shields.io/badge/Root_Directory-%2Fdeploy%2Fclaude--relay--service-blue)

### 步骤 5：添加 Redis

1. 点击 **Add Service** → **Marketplace**
2. 选择 **Redis**
3. Redis 会自动连接到你的服务

### 步骤 6：配置环境变量

点击你的服务 → **Variables** → 添加以下变量：

| 变量名 | 值 | 说明 |
|--------|-----|------|
| `JWT_SECRET` | `<随机32位字符串>` | [点击生成](https://generate-secret.vercel.app/32) |
| `ENCRYPTION_KEY` | `<随机32位字符串>` | [点击生成](https://generate-secret.vercel.app/32) |
| `REDIS_HOST` | `${REDIS_HOST}` | 引用 Redis 服务 |
| `REDIS_PORT` | `${REDIS_PORT}` | 引用 Redis 服务 |
| `REDIS_PASSWORD` | `${REDIS_PASSWORD}` | 引用 Redis 服务 |

> 点击变量输入框右侧的 **Link** 图标可以快速引用 Redis 服务的变量

### 步骤 7：绑定域名

1. 点击 **Networking** → **Domain**
2. Zeabur 会自动分配一个 `.zeabur.app` 域名
3. （可选）添加自定义域名

### 步骤 8：等待部署完成

首次构建约需 3-5 分钟，可在 **Deployments** 查看日志。

---

## 部署后配置

### 访问管理界面

```
https://你的域名/admin-next/
```

### 获取管理员密码

1. 进入 Zeabur 控制台 → 你的服务 → **Logs**
2. 搜索 `Admin credentials` 或 `password`
3. 或进入 **Files** → `data/init.json` 查看

### 添加 Claude 账户

1. 登录管理界面
2. Claude 账户 → 添加账户
3. 选择授权方式：
   - **OAuth 授权**：生成链接 → 浏览器打开 → 复制 Code
   - **Cookie 授权**：从 claude.ai 获取 sessionKey

### 创建 API Key

1. API Keys → 创建新 Key
2. 记录生成的 Key（格式：`cr_xxx`）

---

## 用户使用方式

将以下内容分享给你的用户：

### 环境变量配置

```bash
# Linux/macOS（添加到 ~/.bashrc 或 ~/.zshrc）
export ANTHROPIC_BASE_URL="https://你的域名/api/"
export ANTHROPIC_AUTH_TOKEN="cr_你的api_key"

# Windows PowerShell
$env:ANTHROPIC_BASE_URL = "https://你的域名/api/"
$env:ANTHROPIC_AUTH_TOKEN = "cr_你的api_key"
```

### 使用 Claude Code

```bash
# 配置后直接使用
claude
```

---

## 环境变量说明

### 必填变量

| 变量名 | 说明 |
|--------|------|
| `JWT_SECRET` | JWT 签名密钥，至少32字符 |
| `ENCRYPTION_KEY` | 数据加密密钥，必须32字符 |
| `REDIS_HOST` | Redis 主机地址 |
| `REDIS_PORT` | Redis 端口 |
| `REDIS_PASSWORD` | Redis 密码 |

### 可选变量

| 变量名 | 默认值 | 说明 |
|--------|--------|------|
| `PORT` | 3000 | 服务端口 |
| `NODE_ENV` | production | 运行环境 |
| `STICKY_SESSION_TTL_HOURS` | 1 | 会话保持时长（小时） |
| `USER_MANAGEMENT_ENABLED` | false | 启用用户管理 |
| `TIMEZONE_OFFSET` | 8 | 时区偏移（中国+8） |

---

## 成本估算

| 资源 | 预估成本 |
|------|----------|
| 计算资源 | ~$5/月 |
| Redis | ~$3/月 |
| **总计** | **~$8/月** |

---

## 常见问题

### Q: 构建失败怎么办？

1. 检查 Deployments 日志
2. 确认 Root Directory 设置正确：`/deploy/claude-relay-service`
3. 重新触发部署

### Q: 无法连接 Redis？

1. 确认已添加 Redis 服务
2. 检查环境变量是否正确引用（使用 `${REDIS_HOST}` 格式）
3. 重启服务

### Q: OAuth 授权失败？

香港节点通常可直连 Anthropic，如失败：
1. 尝试 Cookie 授权方式
2. 在添加账户时配置代理

### Q: 国内访问慢？

1. 确认选择了 **Hong Kong** 区域
2. 绑定自定义域名
3. 使用 Cloudflare CDN（可选）

---

## 更新服务

当 claude-relay-service 有更新时：

1. 进入 Zeabur 控制台
2. 点击你的服务 → **Redeploy**
3. 等待重新构建完成

---

## 相关链接

- [Claude Relay Service 源码](https://github.com/Wei-Shaw/claude-relay-service)
- [Zeabur 官网](https://zeabur.com)
- [Zeabur 文档](https://zeabur.com/docs)

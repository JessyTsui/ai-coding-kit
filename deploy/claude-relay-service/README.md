# Claude Relay Service - Zeabur 部署指南

一键部署 Claude Relay Service 到 Zeabur，让团队成员共享 Claude Code 订阅。

## 为什么选择 Zeabur

- **国内访问友好**：香港/东京节点，CN2优化线路
- **中文界面**：国内团队开发，文档完善
- **一键部署**：自动配置 Redis，无需手动管理
- **按量计费**：用多少付多少，无最低消费

## 快速部署

### 方式一：一键部署（推荐）

[![Deploy on Zeabur](https://zeabur.com/button.svg)](https://zeabur.com/templates/claude-relay)

### 方式二：手动部署

#### 1. 准备工作

```bash
# 安装 Zeabur CLI
npm install -g zeabur

# 登录 Zeabur
zeabur login
```

#### 2. 创建项目

```bash
# 克隆 claude-relay-service 仓库
git clone https://github.com/Wei-Shaw/claude-relay-service.git
cd claude-relay-service

# 复制 Zeabur 配置文件到项目根目录
cp /path/to/zeabur.json .
```

#### 3. 部署服务

```bash
# 部署到 Zeabur
zeabur deploy
```

或者通过 Zeabur Dashboard：
1. 登录 https://zeabur.com
2. 创建新项目
3. 选择 Git 仓库导入
4. 选择区域：**Hong Kong**（推荐国内用户）

#### 4. 添加 Redis 服务

在 Zeabur Dashboard 中：
1. 点击 "Add Service"
2. 选择 "Marketplace"
3. 选择 "Redis"
4. Redis 会自动连接到你的服务

#### 5. 配置环境变量

在 Zeabur Dashboard -> Service -> Variables 中设置：

**必填变量：**
```
JWT_SECRET=<随机32位字符串>
ENCRYPTION_KEY=<随机32位字符串>
```

**Redis 变量（Zeabur 自动注入）：**
```
REDIS_HOST=${REDIS_HOST}
REDIS_PORT=${REDIS_PORT}
REDIS_PASSWORD=${REDIS_PASSWORD}
```

> Zeabur 会自动将 Redis 服务的连接信息注入到环境变量中

**可选变量：**
```
STICKY_SESSION_TTL_HOURS=1
METRICS_WINDOW=5
USER_MANAGEMENT_ENABLED=false
```

#### 6. 绑定域名

Zeabur 提供免费域名 `*.zeabur.app`，也支持自定义域名：

1. Dashboard -> Networking -> Domain
2. 添加自定义域名
3. 按提示配置 DNS（CNAME 记录）

## 部署后配置

### 1. 访问管理界面

```
https://your-app.zeabur.app/admin-next/
```

首次访问查看部署日志获取管理员凭据，或检查 `data/init.json`

### 2. 测试网络连通性

在 Zeabur Console 中执行：
```bash
curl -I https://api.anthropic.com/v1/messages
```

香港节点通常可以直连 Anthropic API，无需配置代理。

### 3. 添加 Claude 账户

**方式A：OAuth 授权**
1. 管理界面 -> Claude账户 -> 添加账户
2. 点击"生成授权URL"
3. 浏览器打开链接并登录 Claude
4. 复制 Authorization Code 粘贴到输入框

**方式B：Cookie 授权（更简单）**
1. 登录 https://claude.ai
2. F12 -> Application -> Cookies -> 复制 `sessionKey`
3. 使用 Cookie 授权接口

### 4. 创建 API Key

管理界面 -> API Keys -> 创建新Key

格式示例：`cr_abc123xyz789`

## 用户使用方式

用户只需配置两个环境变量：

```bash
# Linux/macOS (~/.bashrc 或 ~/.zshrc)
export ANTHROPIC_BASE_URL="https://your-app.zeabur.app/api/"
export ANTHROPIC_AUTH_TOKEN="cr_your_api_key"

# Windows PowerShell
$env:ANTHROPIC_BASE_URL = "https://your-app.zeabur.app/api/"
$env:ANTHROPIC_AUTH_TOKEN = "cr_your_api_key"

# Windows CMD
set ANTHROPIC_BASE_URL=https://your-app.zeabur.app/api/
set ANTHROPIC_AUTH_TOKEN=cr_your_api_key
```

然后正常使用 Claude Code：
```bash
claude
```

## 环境变量完整列表

| 变量名 | 必填 | 默认值 | 说明 |
|--------|------|--------|------|
| `JWT_SECRET` | 是 | - | JWT 签名密钥，至少32字符 |
| `ENCRYPTION_KEY` | 是 | - | 数据加密密钥，必须32字符 |
| `REDIS_HOST` | 是 | - | Redis 主机（Zeabur自动注入） |
| `REDIS_PORT` | 是 | 6379 | Redis 端口（Zeabur自动注入） |
| `REDIS_PASSWORD` | 否 | - | Redis 密码（Zeabur自动注入） |
| `PORT` | 否 | 3000 | 服务端口 |
| `NODE_ENV` | 否 | production | 运行环境 |
| `STICKY_SESSION_TTL_HOURS` | 否 | 1 | 粘性会话时长（小时） |
| `USER_MANAGEMENT_ENABLED` | 否 | false | 启用用户管理系统 |
| `WEBHOOK_ENABLED` | 否 | true | 启用 Webhook 通知 |
| `TIMEZONE_OFFSET` | 否 | 8 | 时区偏移（中国+8） |

## 生成密钥

```bash
# 生成 JWT_SECRET
openssl rand -base64 32

# 生成 ENCRYPTION_KEY（必须32字符）
openssl rand -base64 24 | head -c 32
```

## 成本估算

Zeabur 按量计费：

| 资源 | 规格 | 预估成本 |
|------|------|----------|
| 计算资源 | 0.5 vCPU / 512MB | ~$3-5/月 |
| Redis | 基础版 | ~$2-3/月 |
| 流量 | 100GB | 免费 |
| **总计** | | **~$5-8/月** |

> 实际费用取决于使用量，低流量可能更便宜

## 区域选择建议

| 用户位置 | 推荐区域 | 延迟 |
|----------|----------|------|
| 中国大陆 | Hong Kong | 30-50ms |
| 东南亚 | Singapore | 50-80ms |
| 日韩 | Tokyo | 30-50ms |
| 全球 | 按需选择 | - |

## 故障排除

### 部署失败

1. 检查构建日志
2. 确认 Node.js 版本 >= 18
3. 检查环境变量是否完整

### Redis 连接失败

1. 确认 Redis 服务已添加
2. 检查环境变量是否正确注入
3. 重启服务

### OAuth 授权失败

1. 香港节点通常可直连，无需代理
2. 如仍失败，尝试添加代理配置
3. 使用 Cookie 授权作为备选

### 国内访问慢

1. 确认选择了 Hong Kong 区域
2. 绑定自定义域名
3. 使用 Cloudflare 作为 CDN（可选）

## 相关链接

- [Claude Relay Service 源码](https://github.com/Wei-Shaw/claude-relay-service)
- [Zeabur 官网](https://zeabur.com)
- [Zeabur 文档](https://zeabur.com/docs)
- [Zeabur 定价](https://zeabur.com/pricing)

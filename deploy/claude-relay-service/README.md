# Claude Relay Service - Zeabur 部署指南

让团队成员共享 Claude Code 订阅，5分钟完成部署。

## 部署方式（推荐：Docker 镜像）

直接使用官方预构建镜像，**无需 Fork、无需代码、最稳定**。

### 步骤 1：登录 Zeabur

访问 [Zeabur](https://zeabur.com) 并登录

### 步骤 2：创建项目

1. 点击 **Create Project**
2. 选择区域：**Hong Kong**（国内访问最优）

### 步骤 3：部署 Claude Relay Service

1. 点击 **Add Service**
2. 选择 **Prebuilt Image**（预构建镜像）
3. 输入镜像地址：
   ```
   weishaw/claude-relay-service:latest
   ```
4. 点击 **Deploy**

> 💡 想锁定版本？使用 `weishaw/claude-relay-service:v1.1.222` 等具体版本号

### 步骤 4：添加 Redis

1. 点击 **Add Service** → **Marketplace**
2. 选择 **Redis**

或者使用外部 Redis（如 Upstash）：跳过此步，在环境变量中直接配置

### 步骤 5：配置环境变量

点击你的服务 → **Variables** → 添加：

**必填：**
| 变量名 | 值 | 获取方式 |
|--------|-----|----------|
| `JWT_SECRET` | 随机32位字符串 | [点击生成](https://generate-secret.vercel.app/32) |
| `ENCRYPTION_KEY` | 随机32位字符串 | [点击生成](https://generate-secret.vercel.app/32) |

**Redis（使用 Zeabur Redis）：**
| 变量名 | 值 |
|--------|-----|
| `REDIS_HOST` | `${REDIS_HOST}` |
| `REDIS_PORT` | `${REDIS_PORT}` |
| `REDIS_PASSWORD` | `${REDIS_PASSWORD}` |

**Redis（使用外部 Redis，如 Upstash）：**
| 变量名 | 值 |
|--------|-----|
| `REDIS_HOST` | `your-redis.upstash.io` |
| `REDIS_PORT` | `6379` |
| `REDIS_PASSWORD` | `你的密码` |
| `REDIS_ENABLE_TLS` | `true` |

### 步骤 6：绑定域名

1. 点击 **Networking** → **Domain**
2. 获取 `.zeabur.app` 免费域名
3. （可选）添加自定义域名

### 步骤 7：完成

等待服务启动（约1分钟），访问：
```
https://你的域名/admin-next/
```

---

## 部署后配置

### 获取管理员密码

Zeabur 控制台 → 你的服务 → **Logs** → 搜索 `password`

### 添加 Claude 账户

1. 登录管理界面
2. Claude 账户 → 添加账户
3. 生成授权链接 → 浏览器打开 → 复制 Code

### 创建 API Key

API Keys → 创建 → 记录 Key（格式：`cr_xxx`）

---

## 用户使用

分享给你的用户：

```bash
# Linux/macOS
export ANTHROPIC_BASE_URL="https://你的域名/api/"
export ANTHROPIC_AUTH_TOKEN="cr_你的key"

# 然后正常使用
claude
```

---

## 更新服务

当需要更新到最新版本时：

1. Zeabur 控制台 → 你的服务
2. 点击 **Redeploy**

如果使用 `latest` 标签，会自动拉取最新镜像。

---

## 常见问题

### Q: 容器启动失败？
检查环境变量是否完整（JWT_SECRET、ENCRYPTION_KEY、REDIS_*）

### Q: Redis 连接失败？
- Zeabur Redis：确保变量使用 `${REDIS_HOST}` 格式引用
- 外部 Redis：如果是 `rediss://` URL，需设置 `REDIS_ENABLE_TLS=true`

### Q: OAuth 授权失败？
香港节点通常可直连 Anthropic，如失败可尝试 Cookie 授权方式

---

## 成本

| 资源 | 预估 |
|------|------|
| 服务 | ~$5/月 |
| Redis | ~$3/月 |
| **总计** | **~$8/月** |

---

## 相关链接

- [Claude Relay Service](https://github.com/Wei-Shaw/claude-relay-service)
- [Docker Hub 镜像](https://hub.docker.com/r/weishaw/claude-relay-service)
- [Zeabur](https://zeabur.com)

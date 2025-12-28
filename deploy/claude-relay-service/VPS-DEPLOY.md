# Claude Relay Service - VPS 部署指南

使用香港 VPS + 代理方案部署，让国内用户无需翻墙即可使用 Claude Code。

## 架构说明

```
国内用户 ──→ 香港VPS ──→ 美国/日本代理 ──→ Anthropic API
(不用翻墙)   (主服务)      (代理出口)
```

## 准备工作

### 购买 VPS

| 用途 | 推荐服务商 | 地区 | 配置 | 价格 |
|------|-----------|------|------|------|
| 主服务 | DMIT / 搬瓦工 | 香港 | 1核1G | ~$7/月 |
| 代理 | RackNerd | 美国 | 1核512M | ~$1.5/月 |

### 避坑指南

- **避免** 阿里云、腾讯云海外（会被 Cloudflare 拦截）
- **推荐** DMIT、搬瓦工、Lightnode 等

---

## 部署步骤

### 第一步：部署代理服务器（美国/日本 VPS）

SSH 登录到美国/日本 VPS，执行：

```bash
# 下载并运行安装脚本
curl -fsSL https://raw.githubusercontent.com/JessyTsui/ai-coding-kit/master/deploy/claude-relay-service/scripts/install-proxy.sh -o install-proxy.sh
chmod +x install-proxy.sh
sudo bash install-proxy.sh
```

按提示配置：
1. 代理端口（默认 1080）
2. 用户名和密码

**记录输出的代理信息**：
```
代理地址: x.x.x.x
代理端口: 1080
用户名: proxyuser
密码: xxxxxx
```

### 第二步：部署主服务（香港 VPS）

SSH 登录到香港 VPS，执行：

```bash
# 下载并运行安装脚本
curl -fsSL https://raw.githubusercontent.com/JessyTsui/ai-coding-kit/master/deploy/claude-relay-service/scripts/install-relay-service.sh -o install-relay-service.sh
chmod +x install-relay-service.sh
sudo bash install-relay-service.sh
```

按提示配置：
1. Redis 配置（推荐选择本地 Docker Redis）
2. 代理配置（填入第一步的代理信息）

### 第三步：配置服务

1. **访问管理界面**
   ```
   http://香港VPS的IP:3000/admin-next/
   ```

2. **获取管理员密码**
   ```bash
   docker exec claude-relay-service cat /app/data/init.json
   ```

3. **添加 Claude 账户**
   - 点击 "Claude 账户" → "添加账户"
   - 选择 "Access Token" 方式
   - 粘贴从本地获取的 token
   - **重要**：填入代理配置
     ```
     代理类型: socks5
     代理地址: 美国VPS的IP
     代理端口: 1080
     用户名: proxyuser
     密码: 你设置的密码
     ```

4. **创建 API Key**
   - 点击 "API Keys" → "创建"
   - 记录生成的 Key（格式：`cr_xxx`）

---

## 用户使用

分享给用户的配置：

```bash
# Linux/macOS（添加到 ~/.bashrc 或 ~/.zshrc）
export ANTHROPIC_BASE_URL="http://香港VPS的IP:3000/api/"
export ANTHROPIC_AUTH_TOKEN="cr_你的api_key"

# 然后使用 Claude Code
claude
```

---

## 常用命令

### 香港 VPS（主服务）

```bash
# 进入工作目录
cd /opt/claude-relay-service

# 查看服务状态
docker-compose ps

# 查看日志
docker-compose logs -f

# 重启服务
docker-compose restart

# 更新服务
docker-compose pull && docker-compose up -d
```

### 美国 VPS（代理）

```bash
# 查看代理状态
docker ps | grep socks5-proxy

# 查看代理日志
docker logs -f socks5-proxy

# 重启代理
docker restart socks5-proxy
```

---

## 绑定域名（可选）

### 使用 Nginx 反向代理

```bash
# 安装 Nginx
apt install -y nginx

# 配置反向代理
cat > /etc/nginx/sites-available/claude-relay << 'EOF'
server {
    listen 80;
    server_name your-domain.com;

    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_read_timeout 86400;
    }
}
EOF

ln -s /etc/nginx/sites-available/claude-relay /etc/nginx/sites-enabled/
nginx -t && systemctl reload nginx
```

### 配置 HTTPS（推荐）

```bash
# 安装 Certbot
apt install -y certbot python3-certbot-nginx

# 获取证书
certbot --nginx -d your-domain.com
```

---

## 故障排除

### 代理无法连接

1. 检查代理服务状态：`docker ps | grep socks5-proxy`
2. 检查防火墙：`ufw status` 或 `firewall-cmd --list-all`
3. 测试代理：`curl -x socks5://user:pass@127.0.0.1:1080 https://api.anthropic.com`

### 主服务无法启动

1. 检查日志：`docker-compose logs`
2. 检查 Redis 连接
3. 检查环境变量配置

### OAuth 授权失败

1. 确认代理配置正确
2. 测试代理是否能访问 Anthropic
3. 尝试使用 Access Token 方式

---

## 成本估算

| 项目 | 月费用 |
|------|--------|
| 香港 VPS (DMIT) | ~$7 |
| 美国 VPS (RackNerd) | ~$1.5 |
| **总计** | **~$8.5/月 ≈ 60元** |

---

## 相关链接

- [Claude Relay Service 源码](https://github.com/Wei-Shaw/claude-relay-service)
- [DMIT](https://www.dmit.io)
- [RackNerd](https://www.racknerd.com)

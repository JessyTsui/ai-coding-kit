# Claude Relay Service - Zeabur One-Click Deploy
# 用户 fork 后可直接在 Zeabur 部署

FROM node:20-alpine

WORKDIR /app

# 安装 git 和构建工具
RUN apk add --no-cache git python3 make g++

# 克隆 claude-relay-service 源码
ARG REPO_URL=https://github.com/Wei-Shaw/claude-relay-service.git
ARG REPO_BRANCH=main
RUN git clone --depth 1 --branch ${REPO_BRANCH} ${REPO_URL} .

# 安装后端依赖
RUN npm install --production=false

# 安装并构建前端
RUN npm run install:web && npm run build:web

# 初始化（生成管理员凭据）
RUN npm run setup

# 清理不需要的文件
RUN rm -rf .git && \
    npm prune --production && \
    apk del git python3 make g++

# 暴露端口
EXPOSE 3000

# 健康检查
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:3000/health || exit 1

# 启动服务
CMD ["node", "src/app.js"]

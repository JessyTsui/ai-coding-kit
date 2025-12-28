# Claude Relay Service - Zeabur One-Click Deploy
# 直接使用官方预构建镜像，避免构建超时

FROM weishaw/claude-relay-service:latest

# 暴露端口
EXPOSE 3000

# 健康检查
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:3000/health || exit 1

# 启动服务
CMD ["node", "src/app.js"]

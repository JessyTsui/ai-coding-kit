#!/bin/bash
# ============================================================================
# Claude Relay Service 一键部署脚本
# 用于香港 VPS 部署主服务
# ============================================================================

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 打印带颜色的信息
info() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# 检查是否为 root 用户
check_root() {
    if [ "$EUID" -ne 0 ]; then
        error "请使用 root 用户运行此脚本: sudo bash $0"
    fi
}

# 检测操作系统
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        VERSION=$VERSION_ID
    else
        error "无法检测操作系统"
    fi
    info "检测到操作系统: $OS $VERSION"
}

# 安装 Docker
install_docker() {
    if command -v docker &> /dev/null; then
        success "Docker 已安装: $(docker --version)"
        return
    fi

    info "正在安装 Docker..."

    case $OS in
        ubuntu|debian)
            apt-get update
            apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release
            curl -fsSL https://get.docker.com | sh
            ;;
        centos|rhel|fedora)
            yum install -y yum-utils
            curl -fsSL https://get.docker.com | sh
            ;;
        *)
            curl -fsSL https://get.docker.com | sh
            ;;
    esac

    systemctl start docker
    systemctl enable docker
    success "Docker 安装完成"
}

# 安装 Docker Compose
install_docker_compose() {
    if command -v docker-compose &> /dev/null || docker compose version &> /dev/null; then
        success "Docker Compose 已安装"
        return
    fi

    info "正在安装 Docker Compose..."
    curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    success "Docker Compose 安装完成"
}

# 生成随机字符串
generate_secret() {
    openssl rand -base64 32 | tr -d '/+=' | head -c 32
}

# 创建配置文件
create_config() {
    info "创建配置文件..."

    # 创建工作目录
    mkdir -p /opt/claude-relay-service
    cd /opt/claude-relay-service

    # 生成密钥
    JWT_SECRET=$(generate_secret)
    ENCRYPTION_KEY=$(generate_secret)

    # 询问 Redis 配置
    echo ""
    echo -e "${YELLOW}=== Redis 配置 ===${NC}"
    echo "选择 Redis 部署方式:"
    echo "1) 本地 Docker Redis (推荐)"
    echo "2) 外部 Redis (如 Upstash)"
    read -p "请选择 [1/2]: " redis_choice

    if [ "$redis_choice" = "2" ]; then
        read -p "Redis Host: " REDIS_HOST
        read -p "Redis Port [6379]: " REDIS_PORT
        REDIS_PORT=${REDIS_PORT:-6379}
        read -p "Redis Password: " REDIS_PASSWORD
        read -p "启用 TLS? (y/n) [n]: " redis_tls
        REDIS_ENABLE_TLS="false"
        [ "$redis_tls" = "y" ] && REDIS_ENABLE_TLS="true"
        USE_LOCAL_REDIS="false"
    else
        REDIS_HOST="redis"
        REDIS_PORT="6379"
        REDIS_PASSWORD=""
        REDIS_ENABLE_TLS="false"
        USE_LOCAL_REDIS="true"
    fi

    # 询问代理配置
    echo ""
    echo -e "${YELLOW}=== 代理配置 (用于访问 Anthropic API) ===${NC}"
    read -p "是否配置代理? (y/n) [n]: " use_proxy

    PROXY_CONFIG=""
    if [ "$use_proxy" = "y" ]; then
        echo "代理类型:"
        echo "1) socks5"
        echo "2) http"
        read -p "请选择 [1/2]: " proxy_type_choice
        [ "$proxy_type_choice" = "2" ] && PROXY_TYPE="http" || PROXY_TYPE="socks5"

        read -p "代理地址 (IP): " PROXY_HOST
        read -p "代理端口: " PROXY_PORT
        read -p "代理用户名 (无则留空): " PROXY_USER
        read -p "代理密码 (无则留空): " PROXY_PASS

        info "代理配置将在添加 Claude 账户时使用"
    fi

    # 创建 .env 文件
    cat > .env << EOF
# Claude Relay Service 配置
# 生成时间: $(date)

# 安全配置
JWT_SECRET=${JWT_SECRET}
ENCRYPTION_KEY=${ENCRYPTION_KEY}

# Redis 配置
REDIS_HOST=${REDIS_HOST}
REDIS_PORT=${REDIS_PORT}
REDIS_PASSWORD=${REDIS_PASSWORD}
REDIS_ENABLE_TLS=${REDIS_ENABLE_TLS}

# 服务配置
PORT=3000
NODE_ENV=production
TIMEZONE_OFFSET=8

# 会话配置
STICKY_SESSION_TTL_HOURS=1

# API Key 前缀
API_KEY_PREFIX=dubrify
EOF

    # 创建 docker-compose.yml
    if [ "$USE_LOCAL_REDIS" = "true" ]; then
        cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  claude-relay:
    image: weishaw/claude-relay-service:latest
    container_name: claude-relay-service
    restart: always
    ports:
      - "3000:3000"
    environment:
      - JWT_SECRET=${JWT_SECRET}
      - ENCRYPTION_KEY=${ENCRYPTION_KEY}
      - REDIS_HOST=redis
      - REDIS_PORT=6379
      - NODE_ENV=production
      - TIMEZONE_OFFSET=8
      - API_KEY_PREFIX=dubrify
    volumes:
      - ./data:/app/data
      - ./logs:/app/logs
    depends_on:
      - redis
    healthcheck:
      test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:3000/health"]
      interval: 30s
      timeout: 10s
      retries: 3

  redis:
    image: redis:7-alpine
    container_name: claude-relay-redis
    restart: always
    volumes:
      - ./redis_data:/data
    command: redis-server --appendonly yes
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 3
EOF
    else
        cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  claude-relay:
    image: weishaw/claude-relay-service:latest
    container_name: claude-relay-service
    restart: always
    ports:
      - "3000:3000"
    env_file:
      - .env
    volumes:
      - ./data:/app/data
      - ./logs:/app/logs
    healthcheck:
      test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:3000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
EOF
    fi

    success "配置文件创建完成"
}

# 获取 docker compose 命令
get_compose_cmd() {
    if docker compose version &> /dev/null; then
        echo "docker compose"
    elif command -v docker-compose &> /dev/null; then
        echo "docker-compose"
    else
        error "Docker Compose 未安装"
    fi
}

# 启动服务
start_service() {
    info "正在启动服务..."
    cd /opt/claude-relay-service

    COMPOSE_CMD=$(get_compose_cmd)
    info "使用命令: $COMPOSE_CMD"

    $COMPOSE_CMD pull
    $COMPOSE_CMD up -d

    # 等待服务启动
    info "等待服务启动..."
    sleep 10

    # 检查服务状态
    if $COMPOSE_CMD ps | grep -q "Up\|running"; then
        success "服务启动成功!"
    else
        error "服务启动失败，请检查日志: $COMPOSE_CMD logs"
    fi
}

# 配置防火墙
configure_firewall() {
    info "配置防火墙..."

    if command -v ufw &> /dev/null; then
        ufw allow 22/tcp
        ufw allow 3000/tcp
        ufw --force enable
        success "UFW 防火墙配置完成"
    elif command -v firewall-cmd &> /dev/null; then
        firewall-cmd --permanent --add-port=3000/tcp
        firewall-cmd --reload
        success "Firewalld 防火墙配置完成"
    else
        warning "未检测到防火墙，请手动开放 3000 端口"
    fi
}

# 显示完成信息
show_completion() {
    # 获取服务器 IP
    SERVER_IP=$(curl -s ifconfig.me || curl -s ip.sb || echo "YOUR_SERVER_IP")

    # 获取 docker compose 命令
    COMPOSE_CMD=$(get_compose_cmd)

    # 等待 init.json 生成
    sleep 3

    # 获取管理员凭据
    ADMIN_CREDS=$(docker exec claude-relay-service cat /app/data/init.json 2>/dev/null || echo "")

    echo ""
    echo -e "${GREEN}============================================${NC}"
    echo -e "${GREEN}   Claude Relay Service 部署完成!${NC}"
    echo -e "${GREEN}============================================${NC}"
    echo ""
    echo -e "管理界面: ${BLUE}http://${SERVER_IP}:3000/admin-next/${NC}"
    echo ""
    echo -e "${YELLOW}管理员凭据:${NC}"
    if [ -n "$ADMIN_CREDS" ]; then
        echo "$ADMIN_CREDS"
        echo ""
        echo -e "${YELLOW}(请妥善保存以上账号密码)${NC}"
    else
        echo "查看命令: docker exec claude-relay-service cat /app/data/init.json"
    fi
    echo ""
    echo -e "${YELLOW}常用命令:${NC}"
    echo "查看日志: cd /opt/claude-relay-service && $COMPOSE_CMD logs -f"
    echo "重启服务: cd /opt/claude-relay-service && $COMPOSE_CMD restart"
    echo "停止服务: cd /opt/claude-relay-service && $COMPOSE_CMD down"
    echo "更新服务: cd /opt/claude-relay-service && $COMPOSE_CMD pull && $COMPOSE_CMD up -d"
    echo "查看密码: docker exec claude-relay-service cat /app/data/init.json"
    echo ""

    if [ -n "$PROXY_HOST" ]; then
        echo -e "${YELLOW}代理配置信息 (添加账户时使用):${NC}"
        echo "类型: $PROXY_TYPE"
        echo "地址: $PROXY_HOST"
        echo "端口: $PROXY_PORT"
        [ -n "$PROXY_USER" ] && echo "用户名: $PROXY_USER"
        echo ""
    fi

    echo -e "${YELLOW}下一步:${NC}"
    echo "1. 访问管理界面"
    echo "2. 使用上面的管理员凭据登录"
    echo "3. 添加 Claude 账户"
    echo "4. 创建 API Key 分发给用户 (前缀: dubrify_)"
    echo ""
}

# 主函数
main() {
    echo ""
    echo -e "${BLUE}============================================${NC}"
    echo -e "${BLUE}   Claude Relay Service 一键部署脚本${NC}"
    echo -e "${BLUE}============================================${NC}"
    echo ""

    check_root
    detect_os
    install_docker
    install_docker_compose
    create_config
    start_service
    configure_firewall
    show_completion
}

# 运行主函数
main "$@"

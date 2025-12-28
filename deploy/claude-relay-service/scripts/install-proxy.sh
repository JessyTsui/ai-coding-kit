#!/bin/bash
# ============================================================================
# SOCKS5 代理服务器一键部署脚本
# 用于美国/日本 VPS 搭建代理
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

# 默认配置
DEFAULT_PORT=1080
DEFAULT_USER="proxyuser"

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

# 生成随机密码
generate_password() {
    openssl rand -base64 16 | tr -d '/+=' | head -c 16
}

# 配置代理
configure_proxy() {
    echo ""
    echo -e "${YELLOW}=== 代理配置 ===${NC}"
    echo ""

    # 端口配置
    read -p "代理端口 [${DEFAULT_PORT}]: " PROXY_PORT
    PROXY_PORT=${PROXY_PORT:-$DEFAULT_PORT}

    # 认证配置
    read -p "代理用户名 [${DEFAULT_USER}]: " PROXY_USER
    PROXY_USER=${PROXY_USER:-$DEFAULT_USER}

    GENERATED_PASS=$(generate_password)
    read -p "代理密码 [自动生成: ${GENERATED_PASS}]: " PROXY_PASS
    PROXY_PASS=${PROXY_PASS:-$GENERATED_PASS}
}

# 启动代理服务
start_proxy() {
    info "正在启动代理服务..."

    # 停止已有的代理容器
    docker stop socks5-proxy 2>/dev/null || true
    docker rm socks5-proxy 2>/dev/null || true

    # 启动新的代理容器
    docker run -d \
        --name socks5-proxy \
        --restart always \
        -p ${PROXY_PORT}:1080 \
        ginuerzh/gost \
        -L "socks5://${PROXY_USER}:${PROXY_PASS}@:1080"

    # 检查是否启动成功
    sleep 3
    if docker ps | grep -q socks5-proxy; then
        success "代理服务启动成功!"
    else
        error "代理服务启动失败"
    fi
}

# 配置防火墙
configure_firewall() {
    info "配置防火墙..."

    if command -v ufw &> /dev/null; then
        ufw allow 22/tcp
        ufw allow ${PROXY_PORT}/tcp
        ufw --force enable
        success "UFW 防火墙配置完成"

    elif command -v firewall-cmd &> /dev/null; then
        firewall-cmd --permanent --add-port=${PROXY_PORT}/tcp
        firewall-cmd --reload
        success "Firewalld 防火墙配置完成"

    else
        warning "未检测到防火墙，请手动配置安全规则"
    fi
}

# 测试代理
test_proxy() {
    info "测试代理连接..."

    SERVER_IP=$(curl -s ifconfig.me || curl -s ip.sb || echo "")

    if [ -n "$SERVER_IP" ]; then
        # 使用 curl 测试代理
        if curl -x socks5://${PROXY_USER}:${PROXY_PASS}@127.0.0.1:${PROXY_PORT} -s --max-time 10 https://api.anthropic.com -o /dev/null; then
            success "代理测试成功! 可以访问 Anthropic API"
        else
            warning "代理测试失败或超时，但服务可能仍然正常"
        fi
    fi
}

# 创建管理脚本
create_management_scripts() {
    info "创建管理脚本..."

    mkdir -p /opt/socks5-proxy

    # 保存配置信息
    cat > /opt/socks5-proxy/config.txt << EOF
# SOCKS5 代理配置
# 生成时间: $(date)

端口: ${PROXY_PORT}
用户名: ${PROXY_USER}
密码: ${PROXY_PASS}
EOF

    # 创建重启脚本
    cat > /opt/socks5-proxy/restart.sh << EOF
#!/bin/bash
docker restart socks5-proxy
echo "代理服务已重启"
EOF
    chmod +x /opt/socks5-proxy/restart.sh

    # 创建查看日志脚本
    cat > /opt/socks5-proxy/logs.sh << EOF
#!/bin/bash
docker logs -f socks5-proxy
EOF
    chmod +x /opt/socks5-proxy/logs.sh

    success "管理脚本创建完成"
}

# 显示完成信息
show_completion() {
    SERVER_IP=$(curl -s ifconfig.me || curl -s ip.sb || echo "YOUR_SERVER_IP")

    echo ""
    echo -e "${GREEN}============================================${NC}"
    echo -e "${GREEN}   SOCKS5 代理服务部署完成!${NC}"
    echo -e "${GREEN}============================================${NC}"
    echo ""
    echo -e "${YELLOW}代理配置信息 (复制到 Claude Relay Service):${NC}"
    echo ""
    echo "  代理类型: socks5"
    echo "  代理地址: ${SERVER_IP}"
    echo "  代理端口: ${PROXY_PORT}"
    echo "  用户名:   ${PROXY_USER}"
    echo "  密码:     ${PROXY_PASS}"
    echo ""
    echo -e "${YELLOW}完整代理 URL:${NC}"
    echo "  socks5://${PROXY_USER}:${PROXY_PASS}@${SERVER_IP}:${PROXY_PORT}"
    echo ""
    echo -e "${YELLOW}常用命令:${NC}"
    echo "  查看状态: docker ps | grep socks5-proxy"
    echo "  查看日志: docker logs -f socks5-proxy"
    echo "  重启代理: docker restart socks5-proxy"
    echo "  停止代理: docker stop socks5-proxy"
    echo ""
    echo -e "${YELLOW}配置文件保存在:${NC}"
    echo "  /opt/socks5-proxy/config.txt"
    echo ""
    echo -e "${YELLOW}下一步:${NC}"
    echo "  1. 在香港 VPS 的 Claude Relay Service 中添加 Claude 账户"
    echo "  2. 填入上面的代理配置信息"
    echo "  3. 测试是否能正常访问 Anthropic API"
    echo ""
}

# 主函数
main() {
    echo ""
    echo -e "${BLUE}============================================${NC}"
    echo -e "${BLUE}   SOCKS5 代理服务器一键部署脚本${NC}"
    echo -e "${BLUE}============================================${NC}"
    echo ""

    check_root
    detect_os
    install_docker
    configure_proxy
    start_proxy
    configure_firewall
    create_management_scripts
    test_proxy
    show_completion
}

# 运行主函数
main "$@"

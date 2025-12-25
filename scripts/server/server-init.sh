#!/bin/bash

#===============================================================================
# Ubuntu Server 初始化脚本
# 用法: curl -fsSL <url>/server-init.sh | bash
# 或者: bash server-init.sh
#===============================================================================

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 打印函数
print_header() {
    echo -e "\n${CYAN}============================================${NC}"
    echo -e "${CYAN}  $1${NC}"
    echo -e "${CYAN}============================================${NC}\n"
}

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查是否为 root 或有 sudo 权限
check_sudo() {
    if [[ $EUID -ne 0 ]]; then
        if ! sudo -v &>/dev/null; then
            print_error "此脚本需要 root 权限或 sudo 权限"
            exit 1
        fi
    fi
}

#===============================================================================
# 交互式菜单
#===============================================================================
show_menu() {
    clear
    echo -e "${CYAN}"
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║                                                            ║"
    echo "║           Ubuntu Server 初始化脚本 v1.0                    ║"
    echo "║                                                            ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"

    echo -e "${YELLOW}请选择服务器所在地区:${NC}"
    echo ""
    echo "  1) 国内服务器 (使用国内镜像源加速)"
    echo "  2) 海外服务器 (使用官方源)"
    echo ""
    read -p "请输入选项 [1/2]: " region_choice < /dev/tty

    case $region_choice in
        1)
            REGION="china"
            print_info "已选择: 国内服务器 - 将使用阿里云/清华镜像源"
            ;;
        2)
            REGION="overseas"
            print_info "已选择: 海外服务器 - 将使用官方源"
            ;;
        *)
            print_warning "无效选项，默认使用海外服务器配置"
            REGION="overseas"
            ;;
    esac

    echo ""
    echo -e "${YELLOW}请选择要安装的组件:${NC}"
    echo ""
    echo "  1) 全部安装 (推荐)"
    echo "  2) 仅安装基础软件"
    echo "  3) 基础软件 + Docker"
    echo "  4) 基础软件 + Docker + Miniconda"
    echo "  5) 自定义选择"
    echo ""
    read -p "请输入选项 [1-5]: " install_choice < /dev/tty

    # 初始化安装选项
    INSTALL_BASIC=false
    INSTALL_DOCKER=false
    INSTALL_MINICONDA=false
    INSTALL_NGINX_CONFIG=false
    INSTALL_CHINESE=false

    case $install_choice in
        1)
            INSTALL_BASIC=true
            INSTALL_DOCKER=true
            INSTALL_MINICONDA=true
            INSTALL_NGINX_CONFIG=true
            INSTALL_CHINESE=true
            ;;
        2)
            INSTALL_BASIC=true
            ;;
        3)
            INSTALL_BASIC=true
            INSTALL_DOCKER=true
            ;;
        4)
            INSTALL_BASIC=true
            INSTALL_DOCKER=true
            INSTALL_MINICONDA=true
            ;;
        5)
            custom_select
            ;;
        *)
            print_warning "无效选项，将执行全部安装"
            INSTALL_BASIC=true
            INSTALL_DOCKER=true
            INSTALL_MINICONDA=true
            INSTALL_NGINX_CONFIG=true
            INSTALL_CHINESE=true
            ;;
    esac

    # 如果选择配置 Nginx，询问域名
    if [[ "$INSTALL_NGINX_CONFIG" == true ]]; then
        echo ""
        read -p "请输入您的域名 (例如: example.com): " DOMAIN_NAME < /dev/tty
        if [[ -z "$DOMAIN_NAME" ]]; then
            print_warning "未输入域名，将跳过 Nginx 配置"
            INSTALL_NGINX_CONFIG=false
        fi
    fi

    # 确认安装
    echo ""
    echo -e "${YELLOW}======== 安装确认 ========${NC}"
    echo "服务器地区: $([ "$REGION" == "china" ] && echo "国内" || echo "海外")"
    echo "基础软件:   $([ "$INSTALL_BASIC" == true ] && echo "是" || echo "否")"
    echo "Docker:     $([ "$INSTALL_DOCKER" == true ] && echo "是" || echo "否")"
    echo "Miniconda:  $([ "$INSTALL_MINICONDA" == true ] && echo "是" || echo "否")"
    echo "Nginx配置:  $([ "$INSTALL_NGINX_CONFIG" == true ] && echo "是 ($DOMAIN_NAME)" || echo "否")"
    echo "中文支持:   $([ "$INSTALL_CHINESE" == true ] && echo "是" || echo "否")"
    echo -e "${YELLOW}==========================${NC}"
    echo ""
    read -p "确认开始安装? [Y/n]: " confirm < /dev/tty
    if [[ "$confirm" =~ ^[Nn]$ ]]; then
        print_info "安装已取消"
        exit 0
    fi
}

# 自定义选择
custom_select() {
    echo ""
    read -p "安装基础软件? [Y/n]: " choice < /dev/tty
    [[ ! "$choice" =~ ^[Nn]$ ]] && INSTALL_BASIC=true

    read -p "安装 Docker & Docker Compose? [Y/n]: " choice < /dev/tty
    [[ ! "$choice" =~ ^[Nn]$ ]] && INSTALL_DOCKER=true

    read -p "安装 Miniconda? [Y/n]: " choice < /dev/tty
    [[ ! "$choice" =~ ^[Nn]$ ]] && INSTALL_MINICONDA=true

    read -p "配置 Nginx 站点? [Y/n]: " choice < /dev/tty
    [[ ! "$choice" =~ ^[Nn]$ ]] && INSTALL_NGINX_CONFIG=true

    read -p "配置中文支持? [Y/n]: " choice < /dev/tty
    [[ ! "$choice" =~ ^[Nn]$ ]] && INSTALL_CHINESE=true
}

#===============================================================================
# 换源 (国内)
#===============================================================================
setup_china_mirrors() {
    print_header "配置国内镜像源"

    # 备份原有源
    sudo cp /etc/apt/sources.list /etc/apt/sources.list.backup.$(date +%Y%m%d%H%M%S)

    # 获取 Ubuntu 版本代号
    UBUNTU_CODENAME=$(lsb_release -cs)

    # 使用阿里云镜像源
    sudo tee /etc/apt/sources.list > /dev/null <<EOF
# 阿里云镜像源
deb http://mirrors.aliyun.com/ubuntu/ ${UBUNTU_CODENAME} main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ ${UBUNTU_CODENAME}-updates main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ ${UBUNTU_CODENAME}-backports main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ ${UBUNTU_CODENAME}-security main restricted universe multiverse
EOF

    print_success "APT 源已更换为阿里云镜像"
}

#===============================================================================
# 安装基础软件
#===============================================================================
install_basic_software() {
    print_header "安装基础软件"

    sudo apt update
    sudo apt install -y git curl wget htop net-tools tmux vim nginx

    print_success "基础软件安装完成"
}

#===============================================================================
# 安装 Docker
#===============================================================================
install_docker() {
    print_header "安装 Docker & Docker Compose"

    # 检测是否已安装
    if command -v docker &> /dev/null; then
        print_warning "Docker 已安装，跳过安装步骤"
        docker --version
        docker compose version 2>/dev/null || true

        # 确保服务运行
        sudo systemctl enable --now docker 2>/dev/null || true

        # 确保用户在 docker 组
        sudo usermod -aG docker $USER 2>/dev/null || true

        # 如果是国内且没有配置镜像加速，则配置
        if [[ "$REGION" == "china" ]] && [[ ! -f /etc/docker/daemon.json ]]; then
            sudo mkdir -p /etc/docker
            sudo tee /etc/docker/daemon.json > /dev/null <<DOCKEREOF
{
    "registry-mirrors": [
        "https://docker.1ms.run",
        "https://docker.xuanyuan.me"
    ]
}
DOCKEREOF
            sudo systemctl restart docker
            print_info "已配置 Docker 镜像加速"
        fi
        return 0
    fi

    # 卸载旧版本
    sudo apt remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true

    # 安装依赖
    sudo apt update
    sudo apt install -y ca-certificates curl gnupg lsb-release

    # 添加 Docker GPG key 和仓库
    if [[ "$REGION" == "china" ]]; then
        # 使用阿里云 Docker 镜像
        curl -fsSL https://mirrors.aliyun.com/docker-ce/linux/ubuntu/gpg | \
            sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

        echo \
            "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] \
            https://mirrors.aliyun.com/docker-ce/linux/ubuntu $(lsb_release -cs) stable" | \
            sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

        print_info "使用阿里云 Docker 镜像源"
    else
        # 使用官方源
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
            sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

        echo \
            "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] \
            https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | \
            sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    fi

    # 安装 Docker
    sudo apt update
    sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

    # 配置 Docker 镜像加速 (国内)
    if [[ "$REGION" == "china" ]]; then
        sudo mkdir -p /etc/docker
        sudo tee /etc/docker/daemon.json > /dev/null <<EOF
{
    "registry-mirrors": [
        "https://docker.1ms.run",
        "https://docker.xuanyuan.me"
    ]
}
EOF
        print_info "已配置 Docker 镜像加速"
    fi

    # 启动 Docker
    sudo systemctl enable --now docker

    # 添加当前用户到 docker 组
    sudo usermod -aG docker $USER

    # 验证安装
    docker --version
    docker compose version

    print_success "Docker 安装完成"
    print_warning "请重新登录以使 docker 组权限生效"
}

#===============================================================================
# 安装 Miniconda
#===============================================================================
install_miniconda() {
    print_header "安装 Miniconda"

    # 检测是否已安装
    if [[ -d "$HOME/miniconda" ]] || command -v conda &> /dev/null; then
        print_warning "Miniconda 已安装，跳过安装步骤"

        # 获取 conda 路径
        if [[ -f "$HOME/miniconda/bin/conda" ]]; then
            CONDA_BIN="$HOME/miniconda/bin/conda"
        elif command -v conda &> /dev/null; then
            CONDA_BIN="conda"
        else
            print_error "找到 miniconda 目录但未找到 conda 命令"
            return 1
        fi

        $CONDA_BIN --version

        # 如果是国内，检查并配置镜像源
        if [[ "$REGION" == "china" ]]; then
            if ! $CONDA_BIN config --show channels | grep -q "tuna.tsinghua"; then
                $CONDA_BIN config --add channels https://mirrors.tuna.tsinghua.edu.cn/anaconda/pkgs/main/
                $CONDA_BIN config --add channels https://mirrors.tuna.tsinghua.edu.cn/anaconda/pkgs/free/
                $CONDA_BIN config --set show_channel_urls yes
                print_info "已配置 Conda 清华镜像源"
            fi
        fi

        # 检查 py310 环境是否存在
        if ! $CONDA_BIN env list | grep -q "py310"; then
            print_info "创建 py310 环境..."
            $CONDA_BIN create -y -n py310 python=3.10
        else
            print_info "py310 环境已存在"
        fi

        return 0
    fi

    cd /tmp

    if [[ "$REGION" == "china" ]]; then
        # 使用清华镜像
        wget https://mirrors.tuna.tsinghua.edu.cn/anaconda/miniconda/Miniconda3-latest-Linux-x86_64.sh -O miniconda.sh
    else
        wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O miniconda.sh
    fi

    bash miniconda.sh -b -p $HOME/miniconda

    # 添加到 PATH (检查是否已添加)
    if ! grep -q 'miniconda/bin' ~/.bashrc; then
        echo 'export PATH="$HOME/miniconda/bin:$PATH"' >> ~/.bashrc
    fi
    export PATH="$HOME/miniconda/bin:$PATH"

    # 初始化 conda
    $HOME/miniconda/bin/conda init bash

    # 配置国内镜像 (如果是国内服务器)
    if [[ "$REGION" == "china" ]]; then
        $HOME/miniconda/bin/conda config --add channels https://mirrors.tuna.tsinghua.edu.cn/anaconda/pkgs/main/
        $HOME/miniconda/bin/conda config --add channels https://mirrors.tuna.tsinghua.edu.cn/anaconda/pkgs/free/
        $HOME/miniconda/bin/conda config --set show_channel_urls yes
        print_info "已配置 Conda 清华镜像源"
    fi

    # 创建 Python 3.10 环境
    $HOME/miniconda/bin/conda create -y -n py310 python=3.10

    # 清理安装文件
    rm -f /tmp/miniconda.sh

    print_success "Miniconda 安装完成"
    print_info "已创建 py310 环境，使用 'conda activate py310' 激活"
}

#===============================================================================
# 配置 Nginx
#===============================================================================
configure_nginx() {
    print_header "配置 Nginx"

    # 检查域名是否设置
    if [[ -z "$DOMAIN_NAME" ]]; then
        print_error "域名未设置，跳过 Nginx 配置"
        return 1
    fi

    print_info "正在为域名 ${DOMAIN_NAME} 配置 Nginx..."

    # 确保 nginx 已安装并运行
    sudo systemctl enable --now nginx

    # 开放防火墙
    sudo ufw allow 'Nginx Full' 2>/dev/null || true

    # 创建网站目录
    sudo mkdir -p /var/www/${DOMAIN_NAME}/html
    sudo mkdir -p /var/www/api.${DOMAIN_NAME}/html

    # 创建主域名静态页面
    sudo tee /var/www/${DOMAIN_NAME}/html/index.html > /dev/null <<'HTMLEOF'
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>DOMAIN_PLACEHOLDER</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', sans-serif;
            background: #0f0f23;
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            overflow: hidden;
            position: relative;
        }
        .bg-grid {
            position: absolute;
            inset: 0;
            background-image:
                linear-gradient(rgba(99, 102, 241, 0.03) 1px, transparent 1px),
                linear-gradient(90deg, rgba(99, 102, 241, 0.03) 1px, transparent 1px);
            background-size: 60px 60px;
        }
        .bg-glow {
            position: absolute;
            width: 600px;
            height: 600px;
            background: radial-gradient(circle, rgba(99, 102, 241, 0.15) 0%, transparent 70%);
            top: 50%;
            left: 50%;
            transform: translate(-50%, -50%);
            animation: breathe 8s ease-in-out infinite;
        }
        @keyframes breathe {
            0%, 100% { transform: translate(-50%, -50%) scale(1); opacity: 0.5; }
            50% { transform: translate(-50%, -50%) scale(1.1); opacity: 0.8; }
        }
        .container {
            text-align: center;
            color: #e2e8f0;
            padding: 3rem;
            position: relative;
            z-index: 1;
        }
        .logo {
            width: 80px;
            height: 80px;
            margin: 0 auto 2rem;
            background: linear-gradient(135deg, #6366f1 0%, #8b5cf6 100%);
            border-radius: 20px;
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 2rem;
            font-weight: bold;
            color: white;
            box-shadow: 0 20px 40px rgba(99, 102, 241, 0.3);
            animation: float 6s ease-in-out infinite;
        }
        @keyframes float {
            0%, 100% { transform: translateY(0); }
            50% { transform: translateY(-10px); }
        }
        h1 {
            font-size: 3rem;
            font-weight: 700;
            background: linear-gradient(135deg, #fff 0%, #a5b4fc 100%);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
            background-clip: text;
            margin-bottom: 1rem;
            letter-spacing: -0.02em;
        }
        .tagline {
            font-size: 1.25rem;
            color: #94a3b8;
            margin-bottom: 3rem;
            font-weight: 300;
        }
        .status-card {
            display: inline-flex;
            align-items: center;
            gap: 0.75rem;
            padding: 1rem 2rem;
            background: rgba(30, 41, 59, 0.8);
            border: 1px solid rgba(99, 102, 241, 0.2);
            border-radius: 100px;
            backdrop-filter: blur(10px);
        }
        .status-dot {
            width: 10px;
            height: 10px;
            background: #22c55e;
            border-radius: 50%;
            box-shadow: 0 0 10px rgba(34, 197, 94, 0.5);
            animation: pulse 2s ease-in-out infinite;
        }
        @keyframes pulse {
            0%, 100% { box-shadow: 0 0 10px rgba(34, 197, 94, 0.5); }
            50% { box-shadow: 0 0 20px rgba(34, 197, 94, 0.8); }
        }
        .status-text {
            color: #cbd5e1;
            font-size: 0.95rem;
            font-weight: 500;
        }
        .footer {
            position: absolute;
            bottom: 2rem;
            left: 50%;
            transform: translateX(-50%);
            color: #475569;
            font-size: 0.85rem;
        }
    </style>
</head>
<body>
    <div class="bg-grid"></div>
    <div class="bg-glow"></div>
    <div class="container">
        <div class="logo">LOGO_PLACEHOLDER</div>
        <h1>DOMAIN_PLACEHOLDER</h1>
        <p class="tagline">Building something amazing</p>
        <div class="status-card">
            <div class="status-dot"></div>
            <span class="status-text">All Systems Operational</span>
        </div>
    </div>
    <div class="footer">Powered by Nginx</div>
</body>
</html>
HTMLEOF

    # 替换占位符
    LOGO_LETTER=$(echo "${DOMAIN_NAME}" | cut -c1 | tr '[:lower:]' '[:upper:]')
    sudo sed -i "s/DOMAIN_PLACEHOLDER/${DOMAIN_NAME}/g" /var/www/${DOMAIN_NAME}/html/index.html
    sudo sed -i "s/LOGO_PLACEHOLDER/${LOGO_LETTER}/g" /var/www/${DOMAIN_NAME}/html/index.html

    # 创建 API 子域名静态页面
    sudo tee /var/www/api.${DOMAIN_NAME}/html/index.html > /dev/null <<'HTMLEOF'
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>API - DOMAIN_PLACEHOLDER</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: 'SF Mono', 'Fira Code', 'Monaco', monospace;
            background: linear-gradient(180deg, #0c0c1d 0%, #1a1a3e 100%);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            color: #e2e8f0;
            padding: 2rem;
        }
        .card {
            background: rgba(15, 23, 42, 0.8);
            border: 1px solid rgba(99, 102, 241, 0.2);
            border-radius: 16px;
            padding: 2.5rem;
            max-width: 520px;
            width: 100%;
            backdrop-filter: blur(20px);
            box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.5);
        }
        .header {
            display: flex;
            align-items: center;
            gap: 1rem;
            margin-bottom: 2rem;
            padding-bottom: 1.5rem;
            border-bottom: 1px solid rgba(99, 102, 241, 0.1);
        }
        .api-badge {
            background: linear-gradient(135deg, #6366f1 0%, #8b5cf6 100%);
            padding: 0.5rem 1rem;
            border-radius: 8px;
            font-weight: 600;
            font-size: 0.85rem;
            letter-spacing: 0.05em;
        }
        .domain {
            color: #94a3b8;
            font-size: 1.1rem;
        }
        .endpoint-section {
            margin-bottom: 1.5rem;
        }
        .section-title {
            color: #64748b;
            font-size: 0.75rem;
            text-transform: uppercase;
            letter-spacing: 0.1em;
            margin-bottom: 0.75rem;
        }
        .endpoint {
            background: rgba(30, 41, 59, 0.5);
            border: 1px solid rgba(71, 85, 105, 0.3);
            border-radius: 10px;
            padding: 1rem 1.25rem;
            display: flex;
            align-items: center;
            gap: 1rem;
        }
        .method {
            background: linear-gradient(135deg, #22c55e 0%, #16a34a 100%);
            color: white;
            padding: 0.35rem 0.75rem;
            border-radius: 6px;
            font-weight: 600;
            font-size: 0.8rem;
        }
        .path {
            color: #60a5fa;
            font-size: 0.95rem;
        }
        .response-section {
            margin-top: 1.5rem;
        }
        .response {
            background: #0f172a;
            border: 1px solid rgba(71, 85, 105, 0.3);
            border-radius: 10px;
            padding: 1.25rem;
            font-size: 0.9rem;
            line-height: 1.8;
            overflow-x: auto;
        }
        .line {
            display: block;
        }
        .brace { color: #94a3b8; }
        .key { color: #f472b6; }
        .string { color: #a5f3fc; }
        .status-value {
            display: inline-flex;
            align-items: center;
            gap: 0.5rem;
        }
        .status-dot {
            width: 8px;
            height: 8px;
            background: #22c55e;
            border-radius: 50%;
            animation: blink 2s ease-in-out infinite;
        }
        @keyframes blink {
            0%, 100% { opacity: 1; }
            50% { opacity: 0.4; }
        }
        .footer {
            margin-top: 2rem;
            padding-top: 1.5rem;
            border-top: 1px solid rgba(99, 102, 241, 0.1);
            display: flex;
            justify-content: space-between;
            align-items: center;
            color: #64748b;
            font-size: 0.8rem;
        }
        .version-badge {
            background: rgba(99, 102, 241, 0.1);
            border: 1px solid rgba(99, 102, 241, 0.2);
            padding: 0.25rem 0.75rem;
            border-radius: 100px;
            color: #a5b4fc;
        }
    </style>
</head>
<body>
    <div class="card">
        <div class="header">
            <span class="api-badge">API</span>
            <span class="domain">DOMAIN_PLACEHOLDER</span>
        </div>

        <div class="endpoint-section">
            <div class="section-title">Endpoint</div>
            <div class="endpoint">
                <span class="method">GET</span>
                <span class="path">/api/health</span>
            </div>
        </div>

        <div class="response-section">
            <div class="section-title">Response</div>
            <div class="response">
                <span class="line"><span class="brace">{</span></span>
                <span class="line">  <span class="key">"status"</span>: <span class="status-value"><span class="status-dot"></span><span class="string">"healthy"</span></span>,</span>
                <span class="line">  <span class="key">"service"</span>: <span class="string">"DOMAIN_PLACEHOLDER"</span>,</span>
                <span class="line">  <span class="key">"version"</span>: <span class="string">"1.0.0"</span>,</span>
                <span class="line">  <span class="key">"uptime"</span>: <span class="string">"running"</span></span>
                <span class="line"><span class="brace">}</span></span>
            </div>
        </div>

        <div class="footer">
            <span>Powered by Nginx</span>
            <span class="version-badge">v1.0.0</span>
        </div>
    </div>
</body>
</html>
HTMLEOF

    # 替换占位符
    sudo sed -i "s/DOMAIN_PLACEHOLDER/${DOMAIN_NAME}/g" /var/www/api.${DOMAIN_NAME}/html/index.html

    print_info "DEBUG: 开始配置 Nginx 站点文件..."

    # 删除默认配置的软链接
    print_info "DEBUG: 检查 sites-enabled/default..."
    if [[ -f /etc/nginx/sites-enabled/default ]]; then
        sudo rm -f /etc/nginx/sites-enabled/default
        print_info "已移除默认站点配置"
    else
        print_info "DEBUG: sites-enabled/default 不存在或已删除"
    fi

    # 备份默认配置文件
    print_info "DEBUG: 检查 sites-available/default..."
    if [[ -f /etc/nginx/sites-available/default ]]; then
        sudo mv /etc/nginx/sites-available/default /etc/nginx/sites-available/default.bak
        print_info "已备份 default 配置到 default.bak"
    else
        print_info "DEBUG: sites-available/default 不存在或已备份"
    fi

    # 创建 Nginx 配置
    print_info "DEBUG: 正在创建 /etc/nginx/sites-available/${DOMAIN_NAME}..."
    sudo tee /etc/nginx/sites-available/${DOMAIN_NAME} > /dev/null <<EOF
# ${DOMAIN_NAME}: HTTP to HTTPS Redirect
server {
    listen 80;
    server_name ${DOMAIN_NAME} www.${DOMAIN_NAME};

    # 如果没有 SSL 证书，先使用 HTTP
    root /var/www/${DOMAIN_NAME}/html;
    index index.html;

    location / {
        try_files \$uri \$uri/ =404;
    }

    # 如果有 SSL 证书，取消下面的注释并注释上面的 location
    # return 301 https://\$host\$request_uri;
}

# ${DOMAIN_NAME}: HTTPS (取消注释以启用)
# server {
#     listen 443 ssl http2;
#     server_name ${DOMAIN_NAME} www.${DOMAIN_NAME};
#
#     ssl_certificate     /etc/ssl/certs/${DOMAIN_NAME}/fullchain.crt;
#     ssl_certificate_key /etc/ssl/certs/${DOMAIN_NAME}/${DOMAIN_NAME}.key;
#     ssl_protocols TLSv1.2 TLSv1.3;
#
#     root /var/www/${DOMAIN_NAME}/html;
#     index index.html;
#
#     client_max_body_size 10240m;
#
#     proxy_set_header Host              \$host;
#     proxy_set_header X-Real-IP         \$remote_addr;
#     proxy_set_header X-Forwarded-For   \$proxy_add_x_forwarded_for;
#
#     location / {
#         try_files \$uri \$uri/ =404;
#         # 如需反向代理到后端服务，使用:
#         # proxy_pass http://localhost:9000/;
#     }
# }

# api.${DOMAIN_NAME}: HTTP
server {
    listen 80;
    server_name api.${DOMAIN_NAME};

    root /var/www/api.${DOMAIN_NAME}/html;
    index index.html;

    location / {
        try_files \$uri \$uri/ =404;
    }

    # 如果有 SSL 证书，取消下面的注释并注释上面的 location
    # return 301 https://\$host\$request_uri;
}

# api.${DOMAIN_NAME}: HTTPS (取消注释以启用)
# server {
#     listen 443 ssl http2;
#     server_name api.${DOMAIN_NAME};
#
#     ssl_certificate     /etc/ssl/certs/${DOMAIN_NAME}/fullchain.crt;
#     ssl_certificate_key /etc/ssl/certs/${DOMAIN_NAME}/${DOMAIN_NAME}.key;
#     ssl_protocols TLSv1.2 TLSv1.3;
#
#     client_max_body_size 16M;
#
#     proxy_connect_timeout 60s;
#     proxy_send_timeout    60s;
#     proxy_read_timeout    60s;
#
#     proxy_set_header Host              \$host;
#     proxy_set_header X-Real-IP         \$remote_addr;
#     proxy_set_header X-Forwarded-For   \$proxy_add_x_forwarded_for;
#
#     location / {
#         try_files \$uri \$uri/ =404;
#         # 如需反向代理到 API 后端服务，使用:
#         # proxy_pass http://localhost:9001/;
#     }
# }
EOF

    print_info "DEBUG: 配置文件创建完成，验证文件是否存在..."
    ls -la /etc/nginx/sites-available/ || true

    # 创建符号链接
    print_info "DEBUG: 创建符号链接..."
    sudo ln -sf /etc/nginx/sites-available/${DOMAIN_NAME} /etc/nginx/sites-enabled/${DOMAIN_NAME}

    print_info "DEBUG: 验证符号链接..."
    ls -la /etc/nginx/sites-enabled/ || true

    # 检查配置并重载
    print_info "DEBUG: 检查 Nginx 配置语法..."
    sudo nginx -t
    sudo systemctl reload nginx

    print_success "Nginx 配置完成"
    print_info "主站点: http://${DOMAIN_NAME}"
    print_info "API站点: http://api.${DOMAIN_NAME}"
    print_warning "SSL 配置已注释，请上传证书后手动启用 HTTPS"
}

#===============================================================================
# 配置中文支持
#===============================================================================
configure_chinese() {
    print_header "配置中文支持"

    sudo apt update
    sudo apt install -y \
        language-pack-zh-hans \
        fonts-noto-cjk \
        fonts-wqy-zenhei \
        fonts-wqy-microhei

    # 生成 locale
    sudo locale-gen zh_CN.UTF-8
    sudo update-locale LANG=zh_CN.UTF-8 LANGUAGE=zh_CN:zh

    print_success "中文支持配置完成"
    print_warning "需要重新登录或重启以使语言设置生效"
}

#===============================================================================
# 显示安装摘要
#===============================================================================
show_summary() {
    print_header "安装完成"

    echo -e "${GREEN}已完成以下安装:${NC}"
    echo ""

    [[ "$INSTALL_BASIC" == true ]] && echo "  [OK] 基础软件 (git, curl, wget, htop, net-tools, tmux, vim, nginx)"
    [[ "$INSTALL_DOCKER" == true ]] && echo "  [OK] Docker & Docker Compose"
    [[ "$INSTALL_MINICONDA" == true ]] && echo "  [OK] Miniconda (py310 环境)"
    [[ "$INSTALL_NGINX_CONFIG" == true ]] && echo "  [OK] Nginx 站点配置 (${DOMAIN_NAME})"
    [[ "$INSTALL_CHINESE" == true ]] && echo "  [OK] 中文语言支持"

    echo ""
    echo -e "${YELLOW}后续操作提示:${NC}"
    echo ""

    if [[ "$INSTALL_DOCKER" == true ]]; then
        echo "  - 重新登录以使 docker 用户组生效"
    fi

    if [[ "$INSTALL_MINICONDA" == true ]]; then
        echo "  - 运行 'source ~/.bashrc' 或重新登录以激活 conda"
        echo "  - 使用 'conda activate py310' 激活 Python 3.10 环境"
    fi

    if [[ "$INSTALL_NGINX_CONFIG" == true ]]; then
        echo "  - 配置 DNS 解析: ${DOMAIN_NAME} 和 api.${DOMAIN_NAME}"
        echo "  - 上传 SSL 证书后编辑 /etc/nginx/sites-available/${DOMAIN_NAME} 启用 HTTPS"
    fi

    if [[ "$INSTALL_CHINESE" == true ]]; then
        echo "  - 重新登录或重启以使中文设置生效"
    fi

    echo ""
    print_success "服务器初始化完成!"
}

#===============================================================================
# 主函数
#===============================================================================
main() {
    check_sudo
    show_menu

    # 调试输出
    print_info "DEBUG: INSTALL_NGINX_CONFIG = $INSTALL_NGINX_CONFIG"
    print_info "DEBUG: DOMAIN_NAME = $DOMAIN_NAME"

    # 执行安装
    [[ "$REGION" == "china" ]] && setup_china_mirrors

    # 更新系统
    print_header "更新系统"
    sudo apt update && sudo apt upgrade -y

    [[ "$INSTALL_BASIC" == true ]] && install_basic_software
    [[ "$INSTALL_DOCKER" == true ]] && install_docker
    [[ "$INSTALL_MINICONDA" == true ]] && install_miniconda

    if [[ "$INSTALL_NGINX_CONFIG" == true ]]; then
        print_info "准备配置 Nginx，域名: $DOMAIN_NAME"
        configure_nginx
    else
        print_warning "跳过 Nginx 配置 (INSTALL_NGINX_CONFIG=$INSTALL_NGINX_CONFIG)"
    fi

    [[ "$INSTALL_CHINESE" == true ]] && configure_chinese

    show_summary
}

# 运行主函数
main "$@"

#!/bin/bash

#===============================================================================
# Mihomo (Clash Meta) 透明代理安装脚本
# 用于国内服务器访问海外资源 (Docker Hub, GitHub, npm 等)
#
# 用法: bash proxy-setup.sh
#===============================================================================

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# 配置
MIHOMO_VERSION="v1.18.10"
MIHOMO_DIR="/opt/mihomo"
MIHOMO_CONFIG="$MIHOMO_DIR/config.yaml"
MIHOMO_BIN="/usr/local/bin/mihomo"

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

# 检查 root 权限
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "此脚本需要 root 权限运行"
        print_info "请使用: sudo bash proxy-setup.sh"
        exit 1
    fi
}

# 检测系统架构
get_arch() {
    ARCH=$(uname -m)
    case $ARCH in
        x86_64)
            echo "amd64"
            ;;
        aarch64|arm64)
            echo "arm64"
            ;;
        armv7l)
            echo "armv7"
            ;;
        *)
            print_error "不支持的架构: $ARCH"
            exit 1
            ;;
    esac
}

#===============================================================================
# 显示菜单
#===============================================================================
show_menu() {
    clear
    echo -e "${CYAN}"
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║                                                            ║"
    echo "║         Mihomo 透明代理安装脚本 v1.0                       ║"
    echo "║         (用于国内服务器访问海外资源)                       ║"
    echo "║                                                            ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"

    echo -e "${YELLOW}请选择操作:${NC}"
    echo ""
    echo "  1) 安装/更新 Mihomo"
    echo "  2) 配置系统代理 (设置环境变量)"
    echo "  3) 启用 TUN 透明代理 (全局接管)"
    echo "  4) 查看运行状态"
    echo "  5) 停止代理服务"
    echo "  6) 卸载 Mihomo"
    echo "  7) 退出"
    echo ""
    read -p "请输入选项 [1-7]: " choice

    case $choice in
        1) install_mihomo ;;
        2) setup_system_proxy ;;
        3) enable_tun_mode ;;
        4) show_status ;;
        5) stop_proxy ;;
        6) uninstall_mihomo ;;
        7) exit 0 ;;
        *) print_warning "无效选项"; show_menu ;;
    esac
}

#===============================================================================
# 安装 Mihomo
#===============================================================================
install_mihomo() {
    print_header "安装 Mihomo"

    ARCH=$(get_arch)
    print_info "检测到系统架构: $ARCH"

    # 创建目录
    mkdir -p $MIHOMO_DIR
    mkdir -p $MIHOMO_DIR/ui

    # 下载 mihomo
    print_info "下载 Mihomo ${MIHOMO_VERSION}..."

    # GitHub 原始地址
    GITHUB_URL="https://github.com/MetaCubeX/mihomo/releases/download/${MIHOMO_VERSION}/mihomo-linux-${ARCH}-${MIHOMO_VERSION}.gz"

    # 国内加速镜像列表
    MIRROR_URLS=(
        "https://mirror.ghproxy.com/${GITHUB_URL}"
        "https://gh.ddlc.top/${GITHUB_URL}"
        "https://github.moeyy.xyz/${GITHUB_URL}"
        "${GITHUB_URL}"
    )

    cd /tmp
    DOWNLOAD_SUCCESS=false

    for url in "${MIRROR_URLS[@]}"; do
        if [[ "$url" == "$GITHUB_URL" ]]; then
            print_info "尝试直接从 GitHub 下载..."
        else
            # 提取镜像域名
            MIRROR_HOST=$(echo "$url" | sed -E 's|https://([^/]+)/.*|\1|')
            print_info "尝试镜像: $MIRROR_HOST"
        fi

        if wget -q --show-progress --timeout=30 "$url" -O mihomo.gz 2>/dev/null; then
            # 验证文件大小（至少 1MB）
            FILE_SIZE=$(stat -c%s mihomo.gz 2>/dev/null || stat -f%z mihomo.gz 2>/dev/null)
            if [[ "$FILE_SIZE" -gt 1000000 ]]; then
                DOWNLOAD_SUCCESS=true
                print_success "下载成功!"
                break
            else
                print_warning "文件不完整，尝试下一个镜像..."
                rm -f mihomo.gz
            fi
        else
            print_warning "下载失败，尝试下一个镜像..."
        fi
    done

    if [[ "$DOWNLOAD_SUCCESS" != true ]]; then
        print_error "所有镜像下载失败"
        echo ""
        print_info "请手动下载后放到 /tmp/mihomo.gz:"
        print_info "  下载地址: $GITHUB_URL"
        echo ""
        print_info "或者在本地下载后用 scp 上传:"
        print_info "  scp mihomo.gz root@your-server:/tmp/"

        read -p "是否已手动下载到 /tmp/mihomo.gz? [y/N]: " manual_download
        if [[ ! "$manual_download" =~ ^[Yy]$ ]] || [[ ! -f /tmp/mihomo.gz ]]; then
            print_error "安装已取消"
            return 1
        fi
    fi

    # 解压安装
    print_info "安装 Mihomo..."
    gunzip -f /tmp/mihomo.gz
    chmod +x /tmp/mihomo
    mv /tmp/mihomo $MIHOMO_BIN

    # 验证安装
    if $MIHOMO_BIN -v &>/dev/null; then
        print_success "Mihomo 安装成功"
        $MIHOMO_BIN -v
    else
        print_error "Mihomo 安装失败"
        return 1
    fi

    # 下载 UI 面板 (可选)
    print_info "下载管理面板..."
    UI_GITHUB_URL="https://github.com/MetaCubeX/metacubexd/releases/download/v1.143.0/compressed-dist.tgz"
    UI_MIRROR_URLS=(
        "https://mirror.ghproxy.com/${UI_GITHUB_URL}"
        "https://gh.ddlc.top/${UI_GITHUB_URL}"
        "https://github.moeyy.xyz/${UI_GITHUB_URL}"
        "${UI_GITHUB_URL}"
    )

    UI_SUCCESS=false
    for url in "${UI_MIRROR_URLS[@]}"; do
        if wget -q --timeout=30 "$url" -O /tmp/ui.tgz 2>/dev/null; then
            if [[ -s /tmp/ui.tgz ]]; then
                tar -xzf /tmp/ui.tgz -C $MIHOMO_DIR/ui --strip-components=1 2>/dev/null || true
                rm -f /tmp/ui.tgz
                UI_SUCCESS=true
                print_success "管理面板安装成功"
                break
            fi
        fi
    done

    if [[ "$UI_SUCCESS" != true ]]; then
        print_warning "管理面板下载失败，可稍后手动安装"
    fi

    # 创建默认配置（如果不存在）
    if [[ ! -f "$MIHOMO_CONFIG" ]]; then
        create_default_config
    else
        print_info "配置文件已存在: $MIHOMO_CONFIG"
    fi

    # 创建 systemd 服务
    create_systemd_service

    print_success "Mihomo 安装完成"
    print_info "配置文件位置: $MIHOMO_CONFIG"
    print_info "请编辑配置文件添加你的代理节点"

    echo ""
    read -p "是否现在编辑配置文件? [y/N]: " edit_config
    if [[ "$edit_config" =~ ^[Yy]$ ]]; then
        ${EDITOR:-vim} $MIHOMO_CONFIG
    fi
}

#===============================================================================
# 创建默认配置
#===============================================================================
create_default_config() {
    print_info "创建默认配置文件..."

    cat > $MIHOMO_CONFIG <<'CONFIGEOF'
# Mihomo 配置文件
# 文档: https://wiki.metacubex.one/

# 基础配置
mixed-port: 7890           # HTTP/SOCKS5 混合代理端口
allow-lan: true            # 允许局域网连接
bind-address: "*"          # 绑定地址
mode: rule                 # 规则模式

# 日志级别
log-level: info

# Web UI
external-controller: 0.0.0.0:9090
external-ui: /opt/mihomo/ui
secret: ""                 # API 密钥，建议设置

# DNS 配置
dns:
  enable: true
  listen: 0.0.0.0:1053
  ipv6: false
  enhanced-mode: fake-ip
  fake-ip-range: 198.18.0.1/16
  fake-ip-filter:
    - "*.lan"
    - "*.local"
    - "*.localhost"
  default-nameserver:
    - 223.5.5.5
    - 119.29.29.29
  nameserver:
    - https://dns.alidns.com/dns-query
    - https://doh.pub/dns-query
  fallback:
    - https://dns.google/dns-query
    - https://cloudflare-dns.com/dns-query
  fallback-filter:
    geoip: true
    geoip-code: CN
    ipcidr:
      - 240.0.0.0/4

# TUN 模式配置 (透明代理)
tun:
  enable: false            # 默认关闭，使用 enable_tun_mode 启用
  stack: system
  dns-hijack:
    - any:53
  auto-route: true
  auto-detect-interface: true

# GeoIP/GeoSite 数据
geodata-mode: true
geox-url:
  geoip: "https://cdn.jsdelivr.net/gh/Loyalsoldier/v2ray-rules-dat@release/geoip.dat"
  geosite: "https://cdn.jsdelivr.net/gh/Loyalsoldier/v2ray-rules-dat@release/geosite.dat"

#===============================================================================
# 代理节点配置 - 请根据你的实际情况修改
#===============================================================================
proxies:
  # Shadowsocks 示例
  # - name: "SS-Example"
  #   type: ss
  #   server: your-server.com
  #   port: 8388
  #   cipher: chacha20-ietf-poly1305
  #   password: your-password

  # VMess 示例
  # - name: "VMess-Example"
  #   type: vmess
  #   server: your-server.com
  #   port: 443
  #   uuid: your-uuid
  #   alterId: 0
  #   cipher: auto
  #   tls: true

  # Trojan 示例
  # - name: "Trojan-Example"
  #   type: trojan
  #   server: your-server.com
  #   port: 443
  #   password: your-password
  #   sni: your-server.com

  # 订阅链接 (推荐)
  # 如果你有订阅链接，可以使用 proxy-providers 代替上面的 proxies

# 代理订阅 (推荐使用)
proxy-providers:
  # 取消下面注释并填入你的订阅链接
  # my-subscription:
  #   type: http
  #   url: "https://your-subscription-url"
  #   interval: 3600
  #   path: ./providers/my-sub.yaml
  #   health-check:
  #     enable: true
  #     interval: 600
  #     url: http://www.gstatic.com/generate_204

#===============================================================================
# 代理组配置
#===============================================================================
proxy-groups:
  # 手动选择节点
  - name: "Proxy"
    type: select
    proxies:
      - Auto
      - DIRECT
      # 如果使用 proxy-providers，添加:
      # use:
      #   - my-subscription

  # 自动选择最快节点
  - name: "Auto"
    type: url-test
    url: http://www.gstatic.com/generate_204
    interval: 300
    tolerance: 50
    proxies:
      - DIRECT  # 临时占位，配置节点后删除
      # 如果使用 proxy-providers，添加:
      # use:
      #   - my-subscription

  # 开发工具专用 (Docker, GitHub, npm 等)
  - name: "Developer"
    type: select
    proxies:
      - Proxy
      - Auto
      - DIRECT

  # AI 服务专用 (OpenAI, Claude, Gemini 等)
  - name: "AI-Services"
    type: select
    proxies:
      - Proxy
      - Auto
      - DIRECT

  # 兜底规则
  - name: "Final"
    type: select
    proxies:
      - Proxy
      - DIRECT

#===============================================================================
# 分流规则
#===============================================================================
rules:
  # ===== 开发工具 - 走代理 =====
  # Docker
  - DOMAIN-SUFFIX,docker.io,Developer
  - DOMAIN-SUFFIX,docker.com,Developer
  - DOMAIN-SUFFIX,dockerhub.com,Developer
  - DOMAIN-SUFFIX,gcr.io,Developer
  - DOMAIN-SUFFIX,ghcr.io,Developer
  - DOMAIN-SUFFIX,quay.io,Developer
  - DOMAIN-SUFFIX,k8s.io,Developer
  - DOMAIN-SUFFIX,kubernetes.io,Developer

  # GitHub
  - DOMAIN-SUFFIX,github.com,Developer
  - DOMAIN-SUFFIX,github.io,Developer
  - DOMAIN-SUFFIX,githubusercontent.com,Developer
  - DOMAIN-SUFFIX,githubassets.com,Developer
  - DOMAIN-SUFFIX,ghcr.io,Developer

  # NPM/Yarn
  - DOMAIN-SUFFIX,npmjs.org,Developer
  - DOMAIN-SUFFIX,npmjs.com,Developer
  - DOMAIN-SUFFIX,yarnpkg.com,Developer

  # PyPI (部分包)
  - DOMAIN-SUFFIX,pypi.org,Developer
  - DOMAIN-SUFFIX,pythonhosted.org,Developer

  # Go
  - DOMAIN-SUFFIX,golang.org,Developer
  - DOMAIN-SUFFIX,go.dev,Developer
  - DOMAIN-SUFFIX,proxy.golang.org,Developer

  # Rust
  - DOMAIN-SUFFIX,crates.io,Developer
  - DOMAIN-SUFFIX,rust-lang.org,Developer

  # 其他开发资源
  - DOMAIN-SUFFIX,githubusercontent.com,Developer
  - DOMAIN-SUFFIX,raw.githubusercontent.com,Developer
  - DOMAIN-SUFFIX,gist.github.com,Developer
  - DOMAIN-SUFFIX,gitlab.com,Developer
  - DOMAIN-SUFFIX,bitbucket.org,Developer

  # ===== AI 服务 - 走代理 =====
  - DOMAIN-SUFFIX,openai.com,AI-Services
  - DOMAIN-SUFFIX,ai.com,AI-Services
  - DOMAIN-SUFFIX,anthropic.com,AI-Services
  - DOMAIN-SUFFIX,claude.ai,AI-Services
  - DOMAIN-SUFFIX,gemini.google.com,AI-Services
  - DOMAIN-SUFFIX,bard.google.com,AI-Services
  - DOMAIN-SUFFIX,deepmind.com,AI-Services
  - DOMAIN-SUFFIX,cohere.ai,AI-Services
  - DOMAIN-SUFFIX,huggingface.co,AI-Services
  - DOMAIN-SUFFIX,replicate.com,AI-Services

  # ===== Google 服务 =====
  - DOMAIN-SUFFIX,google.com,Proxy
  - DOMAIN-SUFFIX,googleapis.com,Proxy
  - DOMAIN-SUFFIX,googlevideo.com,Proxy
  - DOMAIN-SUFFIX,youtube.com,Proxy
  - DOMAIN-SUFFIX,ytimg.com,Proxy
  - DOMAIN-SUFFIX,ggpht.com,Proxy
  - DOMAIN-SUFFIX,gstatic.com,Proxy

  # ===== 常见被墙站点 =====
  - DOMAIN-SUFFIX,telegram.org,Proxy
  - DOMAIN-SUFFIX,t.me,Proxy
  - DOMAIN-SUFFIX,twitter.com,Proxy
  - DOMAIN-SUFFIX,x.com,Proxy
  - DOMAIN-SUFFIX,twimg.com,Proxy
  - DOMAIN-SUFFIX,facebook.com,Proxy
  - DOMAIN-SUFFIX,instagram.com,Proxy
  - DOMAIN-SUFFIX,whatsapp.com,Proxy
  - DOMAIN-SUFFIX,wikipedia.org,Proxy
  - DOMAIN-SUFFIX,wikimedia.org,Proxy

  # ===== 国内直连 =====
  - GEOSITE,cn,DIRECT
  - GEOIP,cn,DIRECT

  # ===== 私有网络直连 =====
  - GEOIP,private,DIRECT
  - IP-CIDR,127.0.0.0/8,DIRECT
  - IP-CIDR,10.0.0.0/8,DIRECT
  - IP-CIDR,172.16.0.0/12,DIRECT
  - IP-CIDR,192.168.0.0/16,DIRECT

  # ===== 兜底规则 =====
  - MATCH,Final
CONFIGEOF

    print_success "默认配置文件已创建: $MIHOMO_CONFIG"
    print_warning "请编辑配置文件添加你的代理节点!"
}

#===============================================================================
# 创建 systemd 服务
#===============================================================================
create_systemd_service() {
    print_info "创建 systemd 服务..."

    cat > /etc/systemd/system/mihomo.service <<EOF
[Unit]
Description=Mihomo Proxy Service
After=network.target NetworkManager.service systemd-networkd.service

[Service]
Type=simple
LimitNPROC=500
LimitNOFILE=1000000
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_RAW CAP_NET_BIND_SERVICE CAP_SYS_TIME CAP_SYS_PTRACE CAP_DAC_READ_SEARCH
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_RAW CAP_NET_BIND_SERVICE CAP_SYS_TIME CAP_SYS_PTRACE CAP_DAC_READ_SEARCH
Restart=always
RestartSec=5
ExecStartPre=/usr/local/bin/mihomo -t -d /opt/mihomo
ExecStart=/usr/local/bin/mihomo -d /opt/mihomo
ExecReload=/bin/kill -HUP \$MAINPID

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    print_success "systemd 服务创建成功"
}

#===============================================================================
# 设置系统代理 (环境变量)
#===============================================================================
setup_system_proxy() {
    print_header "配置系统代理"

    # 检查服务是否运行
    if ! systemctl is-active --quiet mihomo; then
        print_warning "Mihomo 服务未运行"
        read -p "是否启动服务? [Y/n]: " start_service
        if [[ ! "$start_service" =~ ^[Nn]$ ]]; then
            systemctl start mihomo
            sleep 2
        fi
    fi

    PROXY_ENV_FILE="/etc/profile.d/proxy.sh"

    cat > $PROXY_ENV_FILE <<'EOF'
# Mihomo Proxy 环境变量
export http_proxy="http://127.0.0.1:7890"
export https_proxy="http://127.0.0.1:7890"
export HTTP_PROXY="http://127.0.0.1:7890"
export HTTPS_PROXY="http://127.0.0.1:7890"
export no_proxy="localhost,127.0.0.1,::1,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,.cn,.local"
export NO_PROXY="localhost,127.0.0.1,::1,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,.cn,.local"

# Docker 代理配置提示
# 如果需要让 Docker 使用代理，请运行:
# sudo mkdir -p /etc/systemd/system/docker.service.d
# sudo tee /etc/systemd/system/docker.service.d/proxy.conf <<EOD
# [Service]
# Environment="HTTP_PROXY=http://127.0.0.1:7890"
# Environment="HTTPS_PROXY=http://127.0.0.1:7890"
# Environment="NO_PROXY=localhost,127.0.0.1,.cn,.local"
# EOD
# sudo systemctl daemon-reload
# sudo systemctl restart docker
EOF

    chmod +x $PROXY_ENV_FILE

    # 启动服务
    systemctl enable mihomo
    systemctl start mihomo

    print_success "系统代理配置完成"
    print_info "代理地址: http://127.0.0.1:7890"
    print_info "SOCKS5 代理: socks5://127.0.0.1:7890"
    print_warning "请运行 'source /etc/profile.d/proxy.sh' 或重新登录以生效"

    echo ""
    print_info "立即生效 (当前终端):"
    echo "  source /etc/profile.d/proxy.sh"
    echo ""
    print_info "测试代理:"
    echo "  curl -I https://www.google.com"
}

#===============================================================================
# 启用 TUN 透明代理
#===============================================================================
enable_tun_mode() {
    print_header "启用 TUN 透明代理"

    print_warning "TUN 模式会接管系统全部流量"
    print_info "适用于需要让所有程序（包括 Docker 容器内）走代理的场景"
    echo ""
    read -p "确定启用 TUN 模式? [y/N]: " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        print_info "已取消"
        return 0
    fi

    # 修改配置启用 TUN
    if grep -q "tun:" $MIHOMO_CONFIG; then
        sed -i 's/enable: false/enable: true/' $MIHOMO_CONFIG
    fi

    # 配置系统允许 TUN
    print_info "配置系统网络..."

    # 启用 IP 转发
    echo 'net.ipv4.ip_forward=1' > /etc/sysctl.d/99-mihomo.conf
    echo 'net.ipv6.conf.all.forwarding=1' >> /etc/sysctl.d/99-mihomo.conf
    sysctl -p /etc/sysctl.d/99-mihomo.conf

    # 重启服务
    systemctl restart mihomo
    sleep 3

    if systemctl is-active --quiet mihomo; then
        print_success "TUN 透明代理已启用"
        print_info "所有网络流量将通过 Mihomo 处理"

        # 检查 TUN 接口
        if ip link show Meta 2>/dev/null; then
            print_success "TUN 接口 'Meta' 已创建"
        fi
    else
        print_error "服务启动失败，请检查配置"
        journalctl -u mihomo -n 20
    fi
}

#===============================================================================
# 查看状态
#===============================================================================
show_status() {
    print_header "Mihomo 运行状态"

    # 服务状态
    echo -e "${YELLOW}服务状态:${NC}"
    systemctl status mihomo --no-pager -l | head -20
    echo ""

    # 端口监听
    echo -e "${YELLOW}端口监听:${NC}"
    ss -tlnp | grep -E "(7890|9090|1053)" || echo "  无相关端口"
    echo ""

    # TUN 接口
    echo -e "${YELLOW}TUN 接口:${NC}"
    ip link show Meta 2>/dev/null || echo "  TUN 未启用"
    echo ""

    # 连接测试
    echo -e "${YELLOW}连接测试:${NC}"

    # 测试代理
    if curl -s --connect-timeout 5 -x http://127.0.0.1:7890 https://www.google.com >/dev/null 2>&1; then
        echo -e "  Google: ${GREEN}可访问${NC}"
    else
        echo -e "  Google: ${RED}不可访问${NC}"
    fi

    if curl -s --connect-timeout 5 -x http://127.0.0.1:7890 https://api.github.com >/dev/null 2>&1; then
        echo -e "  GitHub: ${GREEN}可访问${NC}"
    else
        echo -e "  GitHub: ${RED}不可访问${NC}"
    fi

    echo ""
    print_info "管理面板: http://服务器IP:9090/ui"
}

#===============================================================================
# 停止代理
#===============================================================================
stop_proxy() {
    print_header "停止代理服务"

    systemctl stop mihomo
    systemctl disable mihomo 2>/dev/null

    # 移除环境变量
    if [[ -f /etc/profile.d/proxy.sh ]]; then
        rm -f /etc/profile.d/proxy.sh
        print_info "已移除代理环境变量"
    fi

    print_success "代理服务已停止"
    print_warning "请重新登录以清除环境变量"
}

#===============================================================================
# 卸载
#===============================================================================
uninstall_mihomo() {
    print_header "卸载 Mihomo"

    read -p "确定要卸载 Mihomo? [y/N]: " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        print_info "已取消"
        return 0
    fi

    # 停止服务
    systemctl stop mihomo 2>/dev/null
    systemctl disable mihomo 2>/dev/null

    # 移除文件
    rm -f /etc/systemd/system/mihomo.service
    rm -f $MIHOMO_BIN
    rm -f /etc/profile.d/proxy.sh
    rm -f /etc/sysctl.d/99-mihomo.conf

    # 询问是否删除配置
    read -p "是否删除配置文件? [y/N]: " del_config
    if [[ "$del_config" =~ ^[Yy]$ ]]; then
        rm -rf $MIHOMO_DIR
        print_info "配置文件已删除"
    else
        print_info "配置文件保留在: $MIHOMO_DIR"
    fi

    systemctl daemon-reload
    sysctl --system >/dev/null 2>&1

    print_success "Mihomo 已卸载"
}

#===============================================================================
# Docker 代理配置
#===============================================================================
setup_docker_proxy() {
    print_header "配置 Docker 代理"

    if ! command -v docker &>/dev/null; then
        print_error "Docker 未安装"
        return 1
    fi

    mkdir -p /etc/systemd/system/docker.service.d

    cat > /etc/systemd/system/docker.service.d/proxy.conf <<EOF
[Service]
Environment="HTTP_PROXY=http://127.0.0.1:7890"
Environment="HTTPS_PROXY=http://127.0.0.1:7890"
Environment="NO_PROXY=localhost,127.0.0.1,.cn,.local,mirrors.aliyun.com"
EOF

    systemctl daemon-reload
    systemctl restart docker

    print_success "Docker 代理配置完成"
    print_info "Docker 现在会通过 Mihomo 代理拉取镜像"
}

#===============================================================================
# Git 代理配置
#===============================================================================
setup_git_proxy() {
    print_header "配置 Git 代理"

    git config --global http.proxy http://127.0.0.1:7890
    git config --global https.proxy http://127.0.0.1:7890

    print_success "Git 代理配置完成"
    print_info "取消代理: git config --global --unset http.proxy && git config --global --unset https.proxy"
}

#===============================================================================
# 快速安装模式 (非交互)
#===============================================================================
quick_install() {
    check_root
    install_mihomo
    setup_system_proxy

    echo ""
    read -p "是否配置 Docker 代理? [Y/n]: " docker_proxy
    if [[ ! "$docker_proxy" =~ ^[Nn]$ ]]; then
        setup_docker_proxy
    fi

    read -p "是否配置 Git 代理? [Y/n]: " git_proxy
    if [[ ! "$git_proxy" =~ ^[Nn]$ ]]; then
        setup_git_proxy
    fi

    show_status
}

#===============================================================================
# 主函数
#===============================================================================
main() {
    check_root

    case "${1:-}" in
        --quick|-q)
            quick_install
            ;;
        --status|-s)
            show_status
            ;;
        --stop)
            stop_proxy
            ;;
        --docker)
            setup_docker_proxy
            ;;
        --git)
            setup_git_proxy
            ;;
        --help|-h)
            echo "用法: $0 [选项]"
            echo ""
            echo "选项:"
            echo "  --quick, -q    快速安装模式"
            echo "  --status, -s   查看状态"
            echo "  --stop         停止代理"
            echo "  --docker       配置 Docker 代理"
            echo "  --git          配置 Git 代理"
            echo "  --help, -h     显示帮助"
            echo ""
            echo "无参数运行进入交互式菜单"
            ;;
        *)
            show_menu
            ;;
    esac
}

main "$@"

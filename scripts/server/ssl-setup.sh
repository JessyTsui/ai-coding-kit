#!/bin/bash

#===============================================================================
# SSL 证书管理脚本 (基于 acme.sh)
# 用法: curl -fsSL <url>/ssl-setup.sh | bash
# 或者: bash ssl-setup.sh
#
# 功能:
#   - 交互式添加域名和子域名
#   - 支持 Cloudflare / 阿里云 / 腾讯云 DNS 验证
#   - 自动申请和安装 SSL 证书
#   - 配置自动续期 (cron job)
#===============================================================================

# 禁用 apt 交互式提示 (内核更新、服务重启等)
export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 全局变量
DOMAIN_NAME=""
SUBDOMAINS=()
DNS_PROVIDER=""
CERT_PATH="/etc/ssl/certs"
ACME_HOME="$HOME/.acme.sh"
REGION="overseas"  # china or overseas

#===============================================================================
# 打印函数
#===============================================================================
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

#===============================================================================
# 检查是否为 root 或有 sudo 权限
#===============================================================================
check_sudo() {
    if [[ $EUID -ne 0 ]]; then
        if ! sudo -v &>/dev/null; then
            print_error "此脚本需要 root 权限或 sudo 权限"
            exit 1
        fi
    fi
}

#===============================================================================
# 显示主菜单
#===============================================================================
show_menu() {
    clear
    echo -e "${CYAN}"
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║                                                            ║"
    echo "║           SSL 证书管理脚本 v1.0 (acme.sh)                  ║"
    echo "║                                                            ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

#===============================================================================
# 选择服务器地区
#===============================================================================
select_region() {
    echo -e "${YELLOW}请选择服务器所在地区:${NC}"
    echo ""
    echo "  1) 国内服务器 (使用国内镜像源加速)"
    echo "  2) 海外服务器 (使用官方源)"
    echo ""
    read -p "请输入选项 [1/2]: " region_choice < /dev/tty

    case $region_choice in
        1)
            REGION="china"
            print_info "已选择: 国内服务器 - 将使用国内镜像源"
            ;;
        2|"")
            REGION="overseas"
            print_info "已选择: 海外服务器 - 将使用官方源"
            ;;
        *)
            print_warning "无效选项，默认使用海外服务器配置"
            REGION="overseas"
            ;;
    esac
    echo ""
}

#===============================================================================
# 输入域名
#===============================================================================
input_domain() {
    echo -e "${YELLOW}请输入主域名:${NC}"
    echo ""
    read -p "域名 (例如: example.com): " DOMAIN_NAME < /dev/tty

    if [[ -z "$DOMAIN_NAME" ]]; then
        print_error "域名不能为空"
        exit 1
    fi

    # 验证域名格式
    if ! echo "$DOMAIN_NAME" | grep -qE '^[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?)+$'; then
        print_error "域名格式不正确"
        exit 1
    fi

    print_success "主域名: ${DOMAIN_NAME}"
}

#===============================================================================
# 输入子域名
#===============================================================================
input_subdomains() {
    echo ""
    echo -e "${YELLOW}添加子域名 (可选):${NC}"
    echo "  输入子域名前缀，每行一个，输入空行结束"
    echo "  例如输入 'api' 将生成 api.${DOMAIN_NAME}"
    echo ""

    while true; do
        read -p "子域名 (回车结束): " subdomain < /dev/tty
        if [[ -z "$subdomain" ]]; then
            break
        fi
        # 去掉可能输入的完整域名后缀
        subdomain=$(echo "$subdomain" | sed "s/\.${DOMAIN_NAME}$//")
        SUBDOMAINS+=("$subdomain")
        print_info "已添加: ${subdomain}.${DOMAIN_NAME}"
    done

    echo ""
    echo -e "${YELLOW}======== 域名列表 ========${NC}"
    echo "  主域名: ${DOMAIN_NAME}"
    echo "  主域名: www.${DOMAIN_NAME}"
    for sub in "${SUBDOMAINS[@]}"; do
        echo "  子域名: ${sub}.${DOMAIN_NAME}"
    done
    echo -e "${YELLOW}==========================${NC}"
}

#===============================================================================
# 选择 DNS 服务商
#===============================================================================
select_dns_provider() {
    echo ""
    echo -e "${YELLOW}请选择 DNS 服务商:${NC}"
    echo ""
    echo "  1) Cloudflare"
    echo "  2) 阿里云 DNS"
    echo "  3) 腾讯云 DNS (腾讯云控制台)"
    echo "  4) DNSPod (dnspod.cn)"
    echo ""
    read -p "请输入选项 [1-4]: " dns_choice < /dev/tty

    case $dns_choice in
        1)
            DNS_PROVIDER="dns_cf"
            print_info "已选择: Cloudflare"
            input_cloudflare_credentials
            ;;
        2)
            DNS_PROVIDER="dns_ali"
            print_info "已选择: 阿里云 DNS"
            input_aliyun_credentials
            ;;
        3)
            DNS_PROVIDER="dns_tencent"
            print_info "已选择: 腾讯云 DNS"
            input_tencent_credentials
            ;;
        4)
            DNS_PROVIDER="dns_dp"
            print_info "已选择: DNSPod"
            input_dnspod_credentials
            ;;
        *)
            print_error "无效选项"
            exit 1
            ;;
    esac
}

#===============================================================================
# 输入 Cloudflare 凭证
#===============================================================================
input_cloudflare_credentials() {
    echo ""
    echo -e "${YELLOW}请输入 Cloudflare API 凭证:${NC}"
    echo "  获取方式: Cloudflare Dashboard -> My Profile -> API Tokens"
    echo "  推荐创建 Zone DNS 编辑权限的 Token"
    echo ""

    read -p "CF_Token (API Token): " CF_Token < /dev/tty
    read -p "CF_Zone_ID (可选, 回车跳过): " CF_Zone_ID < /dev/tty

    if [[ -z "$CF_Token" ]]; then
        print_error "CF_Token 不能为空"
        exit 1
    fi

    export CF_Token
    if [[ -n "$CF_Zone_ID" ]]; then
        export CF_Zone_ID
    fi

    print_success "Cloudflare 凭证已设置"
}

#===============================================================================
# 输入阿里云凭证
#===============================================================================
input_aliyun_credentials() {
    echo ""
    echo -e "${YELLOW}请输入阿里云 AccessKey:${NC}"
    echo "  获取方式: 阿里云控制台 -> AccessKey 管理"
    echo "  建议使用 RAM 子账号，仅授予 DNS 权限"
    echo ""

    read -p "Ali_Key (AccessKey ID): " Ali_Key < /dev/tty
    read -p "Ali_Secret (AccessKey Secret): " Ali_Secret < /dev/tty

    if [[ -z "$Ali_Key" ]] || [[ -z "$Ali_Secret" ]]; then
        print_error "Ali_Key 和 Ali_Secret 不能为空"
        exit 1
    fi

    export Ali_Key
    export Ali_Secret

    print_success "阿里云凭证已设置"
}

#===============================================================================
# 输入腾讯云 DNS 凭证 (腾讯云控制台)
#===============================================================================
input_tencent_credentials() {
    echo ""
    echo -e "${YELLOW}请输入腾讯云 API 凭证:${NC}"
    echo "  获取方式: https://console.cloud.tencent.com/cam/capi"
    echo ""

    read -p "Tencent_SecretId: " Tencent_SecretId < /dev/tty
    read -p "Tencent_SecretKey: " Tencent_SecretKey < /dev/tty

    if [[ -z "$Tencent_SecretId" ]] || [[ -z "$Tencent_SecretKey" ]]; then
        print_error "Tencent_SecretId 和 Tencent_SecretKey 不能为空"
        exit 1
    fi

    export Tencent_SecretId
    export Tencent_SecretKey

    print_success "腾讯云凭证已设置"
}

#===============================================================================
# 输入 DNSPod 凭证 (dnspod.cn)
#===============================================================================
input_dnspod_credentials() {
    echo ""
    echo -e "${YELLOW}请输入 DNSPod API 凭证:${NC}"
    echo "  获取方式: https://console.dnspod.cn/account/token/token"
    echo ""

    read -p "DP_Id (Token ID): " DP_Id < /dev/tty
    read -p "DP_Key (Token): " DP_Key < /dev/tty

    if [[ -z "$DP_Id" ]] || [[ -z "$DP_Key" ]]; then
        print_error "DP_Id 和 DP_Key 不能为空"
        exit 1
    fi

    export DP_Id
    export DP_Key

    print_success "DNSPod 凭证已设置"
}

#===============================================================================
# 安装 acme.sh
#===============================================================================
install_acme() {
    print_header "安装 acme.sh"

    if [[ -f "$ACME_HOME/acme.sh" ]]; then
        print_warning "acme.sh 已安装，跳过安装步骤"
        "$ACME_HOME/acme.sh" --version
        return 0
    fi

    print_info "正在安装 acme.sh..."

    # 安装依赖
    if command -v apt &> /dev/null; then
        sudo apt update
        sudo apt install -y curl socat git
    elif command -v yum &> /dev/null; then
        sudo yum install -y curl socat git
    fi

    # 安装 acme.sh (根据地区选择源)
    if [[ "$REGION" == "china" ]]; then
        print_info "使用国内镜像源安装..."
        # 使用 gitee 镜像
        git clone https://gitee.com/neilpang/acme.sh.git /tmp/acme.sh
        cd /tmp/acme.sh
        ./acme.sh --install -m admin@${DOMAIN_NAME}
        cd -
        rm -rf /tmp/acme.sh
    else
        curl https://get.acme.sh | sh -s email=admin@${DOMAIN_NAME}
    fi

    if [[ ! -f "$ACME_HOME/acme.sh" ]]; then
        print_error "acme.sh 安装失败"
        exit 1
    fi

    # 设置默认 CA 为 Let's Encrypt
    "$ACME_HOME/acme.sh" --set-default-ca --server letsencrypt

    print_success "acme.sh 安装完成"
}

#===============================================================================
# 申请证书
#===============================================================================
issue_certificate() {
    print_header "申请 SSL 证书"

    # 构建域名参数
    local domain_args="-d ${DOMAIN_NAME} -d www.${DOMAIN_NAME}"
    for sub in "${SUBDOMAINS[@]}"; do
        domain_args="$domain_args -d ${sub}.${DOMAIN_NAME}"
    done

    print_info "正在申请证书..."
    print_info "域名: ${domain_args}"
    print_info "DNS 验证: ${DNS_PROVIDER}"

    # 申请证书
    "$ACME_HOME/acme.sh" --issue $domain_args --dns $DNS_PROVIDER

    if [[ $? -ne 0 ]]; then
        print_error "证书申请失败"
        print_info "请检查 DNS API 凭证是否正确"
        print_info "日志位置: $ACME_HOME/${DOMAIN_NAME}/"
        exit 1
    fi

    print_success "证书申请成功"
}

#===============================================================================
# 安装证书到指定路径
#===============================================================================
install_certificate() {
    print_header "安装证书"

    local cert_dir="${CERT_PATH}/${DOMAIN_NAME}"

    # 创建证书目录
    sudo mkdir -p "$cert_dir"

    print_info "证书安装路径: $cert_dir"

    # 安装证书，并配置 reload 命令
    "$ACME_HOME/acme.sh" --install-cert -d ${DOMAIN_NAME} \
        --key-file       "$cert_dir/${DOMAIN_NAME}.key" \
        --fullchain-file "$cert_dir/fullchain.crt" \
        --reloadcmd      "sudo systemctl reload nginx 2>/dev/null || sudo nginx -s reload 2>/dev/null || true"

    if [[ $? -ne 0 ]]; then
        print_error "证书安装失败"
        exit 1
    fi

    # 设置权限
    sudo chmod 644 "$cert_dir/fullchain.crt"
    sudo chmod 600 "$cert_dir/${DOMAIN_NAME}.key"

    print_success "证书已安装到:"
    print_info "  证书: $cert_dir/fullchain.crt"
    print_info "  私钥: $cert_dir/${DOMAIN_NAME}.key"
}

#===============================================================================
# 更新 Nginx 配置 (可选)
#===============================================================================
update_nginx_config() {
    echo ""
    read -p "是否自动更新 Nginx 配置启用 HTTPS? [y/N]: " update_nginx < /dev/tty

    if [[ ! "$update_nginx" =~ ^[Yy]$ ]]; then
        print_info "跳过 Nginx 配置更新"
        return 0
    fi

    print_header "更新 Nginx 配置"

    local nginx_conf="/etc/nginx/sites-available/${DOMAIN_NAME}"

    if [[ ! -f "$nginx_conf" ]]; then
        print_warning "未找到 Nginx 配置文件: $nginx_conf"
        print_info "请手动配置 Nginx"
        return 0
    fi

    # 备份原配置
    sudo cp "$nginx_conf" "${nginx_conf}.bak.$(date +%Y%m%d%H%M%S)"
    print_info "已备份原配置"

    # 取消 HTTPS server block 的注释
    sudo sed -i 's/^# *\(listen 443 ssl\)/\1/' "$nginx_conf"
    sudo sed -i 's/^# *\(ssl_certificate\)/\1/' "$nginx_conf"
    sudo sed -i 's/^# *\(ssl_protocols\)/\1/' "$nginx_conf"
    sudo sed -i 's/^# *\(server_name.*443\)/\1/' "$nginx_conf"

    # 启用 HTTP 到 HTTPS 重定向
    sudo sed -i 's/^# *\(return 301 https:\/\/\)/\1/' "$nginx_conf"

    # 测试配置
    if sudo nginx -t; then
        sudo systemctl reload nginx
        print_success "Nginx 配置已更新并重载"
    else
        print_error "Nginx 配置语法错误，已保留备份"
        sudo mv "${nginx_conf}.bak."* "$nginx_conf" 2>/dev/null
    fi
}

#===============================================================================
# 显示完成摘要
#===============================================================================
show_summary() {
    print_header "安装完成"

    echo -e "${GREEN}SSL 证书配置成功!${NC}"
    echo ""
    echo -e "${YELLOW}======== 证书信息 ========${NC}"
    echo "  主域名: ${DOMAIN_NAME}"
    echo "  证书路径: ${CERT_PATH}/${DOMAIN_NAME}/fullchain.crt"
    echo "  私钥路径: ${CERT_PATH}/${DOMAIN_NAME}/${DOMAIN_NAME}.key"
    echo ""
    echo -e "${YELLOW}======== Nginx 配置 ========${NC}"
    echo "  在 Nginx server block 中添加:"
    echo ""
    echo -e "${CYAN}    ssl_certificate     ${CERT_PATH}/${DOMAIN_NAME}/fullchain.crt;${NC}"
    echo -e "${CYAN}    ssl_certificate_key ${CERT_PATH}/${DOMAIN_NAME}/${DOMAIN_NAME}.key;${NC}"
    echo ""
    echo -e "${YELLOW}======== 自动续期 ========${NC}"
    echo "  acme.sh 已配置 cron job，证书将自动续期"
    echo "  续期后会自动执行 nginx reload"
    echo ""
    echo "  查看 cron 任务: crontab -l"
    echo "  手动续期测试:   $ACME_HOME/acme.sh --renew -d ${DOMAIN_NAME} --force"
    echo ""
    echo -e "${YELLOW}==========================${NC}"

    print_success "配置完成!"
}

#===============================================================================
# 确认操作
#===============================================================================
confirm_operation() {
    echo ""
    echo -e "${YELLOW}======== 操作确认 ========${NC}"
    echo "  服务器地区: $([ "$REGION" == "china" ] && echo "国内" || echo "海外")"
    echo "  主域名: ${DOMAIN_NAME}"
    echo "  www:    www.${DOMAIN_NAME}"
    for sub in "${SUBDOMAINS[@]}"; do
        echo "  子域名: ${sub}.${DOMAIN_NAME}"
    done
    echo "  DNS 服务商: ${DNS_PROVIDER}"
    echo "  证书路径: ${CERT_PATH}/${DOMAIN_NAME}/"
    echo -e "${YELLOW}==========================${NC}"
    echo ""
    read -p "确认开始申请证书? [Y/n]: " confirm < /dev/tty
    if [[ "$confirm" =~ ^[Nn]$ ]]; then
        print_info "操作已取消"
        exit 0
    fi
}

#===============================================================================
# 主函数
#===============================================================================
main() {
    check_sudo
    show_menu
    select_region
    input_domain
    input_subdomains
    select_dns_provider
    confirm_operation
    install_acme
    issue_certificate
    install_certificate
    update_nginx_config
    show_summary
}

# 运行主函数
main "$@"

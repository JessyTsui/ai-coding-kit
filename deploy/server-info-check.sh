#!/bin/bash
# ============================================================================
# 服务器资源使用情况检查脚本
# ============================================================================

OUTPUT_FILE="server-info-$(date +%Y%m%d-%H%M%S).txt"

echo "正在收集服务器信息，请稍候..."
echo "输出文件: $OUTPUT_FILE"
echo ""

{
    echo "=========================================="
    echo "服务器资源使用情况报告"
    echo "生成时间: $(date)"
    echo "=========================================="
    echo ""

    echo "=== 1. 系统信息 ==="
    uname -a
    echo ""
    cat /etc/os-release | head -5
    echo ""

    echo "=== 2. 运行时间和负载 ==="
    uptime
    echo ""

    echo "=== 3. CPU 信息 ==="
    lscpu | grep -E "^CPU\(s\)|^Model name|^Thread|^Core"
    echo ""

    echo "=== 4. 当前内存使用 ==="
    free -h
    echo ""
    echo "详细内存信息:"
    cat /proc/meminfo | grep -E "MemTotal|MemFree|MemAvailable|Buffers|Cached|SwapTotal|SwapFree"
    echo ""

    echo "=== 5. 磁盘使用 ==="
    df -h
    echo ""

    echo "=== 6. 内存占用 TOP 10 进程 ==="
    ps aux --sort=-%mem | head -11
    echo ""

    echo "=== 7. CPU 占用 TOP 10 进程 ==="
    ps aux --sort=-%cpu | head -11
    echo ""

    echo "=== 8. Docker 状态 ==="
    if command -v docker &> /dev/null; then
        echo "Docker 版本:"
        docker --version
        echo ""

        echo "运行中的容器:"
        docker ps
        echo ""

        echo "所有容器:"
        docker ps -a
        echo ""

        echo "容器资源占用:"
        docker stats --no-stream 2>/dev/null || echo "无容器运行"
        echo ""
    else
        echo "Docker 未安装"
        echo ""
    fi

    echo "=== 9. 运行的服务 ==="
    systemctl list-units --type=service --state=running | head -20
    echo ""

    echo "=== 10. 监听端口 ==="
    if command -v netstat &> /dev/null; then
        sudo netstat -tulpn | grep LISTEN
    elif command -v ss &> /dev/null; then
        sudo ss -tulpn | grep LISTEN
    else
        echo "netstat 和 ss 都未安装"
    fi
    echo ""

    echo "=== 11. 历史资源使用（如果可用）==="
    if command -v sar &> /dev/null; then
        echo "过去 CPU 使用率（最近记录）:"
        sar -u 1 3
        echo ""

        echo "过去内存使用（最近记录）:"
        sar -r 1 3
        echo ""
    else
        echo "sar (sysstat) 未安装，无法查看历史数据"
        echo "安装命令: sudo apt install sysstat (Ubuntu/Debian) 或 sudo yum install sysstat (CentOS)"
        echo ""
    fi

    echo "=== 12. 网络连接数 ==="
    echo "当前连接数:"
    if command -v netstat &> /dev/null; then
        netstat -an | grep ESTABLISHED | wc -l
    elif command -v ss &> /dev/null; then
        ss -an | grep ESTAB | wc -l
    fi
    echo ""

    echo "=== 13. 系统日志最近错误（最后20条）==="
    if [ -f /var/log/syslog ]; then
        grep -i error /var/log/syslog | tail -20
    elif [ -f /var/log/messages ]; then
        grep -i error /var/log/messages | tail -20
    else
        echo "系统日志文件未找到"
    fi
    echo ""

    echo "=========================================="
    echo "报告生成完成"
    echo "=========================================="

} > "$OUTPUT_FILE" 2>&1

echo "✅ 信息收集完成！"
echo "输出文件: $OUTPUT_FILE"
echo ""
echo "请将此文件内容发送给我分析"
echo ""
echo "查看文件命令: cat $OUTPUT_FILE"
echo "或直接发送: 在本地电脑运行 scp ubuntu@129.226.67.166:~/$OUTPUT_FILE ."

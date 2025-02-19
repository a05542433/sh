#!/bin/bash

# 创建必要的目录和文件
SCRIPT_DIR="/opt/scripts"
if [ ! -d "$SCRIPT_DIR" ]; then
    echo "正在创建脚本目录 $SCRIPT_DIR ..."
    mkdir -p "$SCRIPT_DIR"
fi

# 配置参数
THRESHOLD=1600                  # TCP连接数阈值
CHECK_INTERVAL=10              # 检查间隔（秒）
WHITELIST_FILE="$SCRIPT_DIR/tcp_whitelist.txt"
BLACKLIST_LOG="$SCRIPT_DIR/blocked_ips.log"
DEBUG_LOG="$SCRIPT_DIR/debug.log"

# 创建必要的文件
touch "$WHITELIST_FILE"
touch "$BLACKLIST_LOG"
touch "$DEBUG_LOG"

# 确保文件权限正确
chmod 644 "$WHITELIST_FILE"
chmod 644 "$BLACKLIST_LOG"
chmod 644 "$DEBUG_LOG"

# 检查是否以root权限运行
if [ "$EUID" -ne 0 ]; then
    echo "请以root权限运行此脚本"
    exit 1
fi

# 检查必要的命令是否存在
for cmd in netstat awk sort uniq iptables grep ss; do
    if ! command -v $cmd &> /dev/null; then
        echo "错误: 找不到命令 $cmd"
        exit 1
    fi
done

# 日志函数
log_debug() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') UTC - DEBUG: $1" >> "$DEBUG_LOG"
}

# 检查IP是否在白名单中
is_whitelisted() {
    local ip_to_check=$1
    local ip_prefix
    
    # 首先检查完整IP匹配
    if grep -qE "^${ip_to_check}$" "$WHITELIST_FILE"; then
        log_debug "IP $ip_to_check 在白名单中找到完整匹配"
        return 0
    fi
    
    # 然后检查IP段匹配
    while read -r whitelist_entry; do
        # 跳过空行和注释行
        [ -z "$whitelist_entry" ] || [[ "$whitelist_entry" =~ ^# ]] && continue
        
        # 如果白名单条目不包含完整的4个点分位，则视为IP段
        if ! echo "$whitelist_entry" | grep -qE '^([0-9]+\.){3}[0-9]+$'; then
            # 获取IP段前缀
            ip_prefix=$(echo "$ip_to_check" | grep -oE "^${whitelist_entry}")
            if [ ! -z "$ip_prefix" ]; then
                log_debug "IP $ip_to_check 匹配白名单IP段 $whitelist_entry"
                return 0
            fi
        fi
    done < "$WHITELIST_FILE"
    
    log_debug "IP $ip_to_check 不在白名单中"
    return 1
}

# 检查IP是否已被封禁
is_blocked() {
    local ip=$1
    iptables -L INPUT -n | grep -E "^DROP.*${ip}(/32)?[[:space:]]" > /dev/null 2>&1
    local result=$?
    if [ $result -eq 0 ]; then
        log_debug "IP $ip 已经被封禁"
    else
        log_debug "IP $ip 未被封禁"
    fi
    return $result
}

# 获取已封禁IP列表
get_blocked_ips() {
    iptables -L INPUT -n | grep DROP | awk '{print $4}' | sed 's/\/32//'
}

# 封禁IP
block_ip() {
    local ip=$1
    local connections=$2
    if ! is_blocked "$ip" && ! is_whitelisted "$ip"; then
        log_debug "尝试封禁 IP: $ip (连接数: $connections)"
        # 使用 -A 在末尾添加规则
        if iptables -A INPUT -s "$ip" -j DROP; then
            local log_message="$(date '+%Y-%m-%d %H:%M:%S') UTC - 已封禁 IP: $ip (连接数: $connections)"
            echo "$log_message" | tee -a "$BLACKLIST_LOG"
            log_debug "成功添加封禁规则: $ip"
            
            # 立即断开现有连接
            ss -K dst "$ip" 2>/dev/null || true
            log_debug "已尝试断开与 $ip 的现有连接"
        else
            log_debug "添加封禁规则失败: $ip"
            echo "添加封禁规则失败: $ip" >&2
        fi
    fi
}

# 解封IP
unblock_ip() {
    local ip=$1
    if is_blocked "$ip"; then
        log_debug "尝试解封 IP: $ip"
        if iptables -D INPUT -s "$ip" -j DROP; then
            echo "$(date '+%Y-%m-%d %H:%M:%S') UTC - 已解封 IP: $ip" | tee -a "$BLACKLIST_LOG"
            log_debug "成功解封 IP: $ip"
        else
            log_debug "解封失败: $ip"
            echo "解封失败: $ip" >&2
        fi
    fi
}

# 获取连接统计
get_connection_stats() {
    netstat -tpn | grep tcp | \
    awk '{print $5}' | \
    awk -F: '{print $1}' | \
    sort | uniq -c | sort -r +0n
}

# 处理单次检查
process_connections() {
    log_debug "开始处理连接检查"
    local tmp_file=$(mktemp)
    get_connection_stats > "$tmp_file"
    
    while read count ip; do
        if [ ! -z "$ip" ] && [ "$count" -ge "$THRESHOLD" ]; then
            log_debug "发现高连接数IP: $ip (连接数: $count)"
            if ! is_whitelisted "$ip" && ! is_blocked "$ip"; then
                echo "检测到异常IP: $ip (连接数: $count)"
                block_ip "$ip" "$count"
            fi
        fi
    done < "$tmp_file"
    
    rm -f "$tmp_file"
    log_debug "完成连接检查"
}

# 显示状态信息
show_status() {
    local current_time=$(date '+%Y-%m-%d %H:%M:%S')
    echo ""
    echo "=== 当前监控状态 $current_time UTC ==="
    echo "连接阈值: $THRESHOLD"
    
    local blocked_count=$(iptables -L INPUT -n | grep -c DROP)
    echo "已封禁IP数量: $blocked_count"
    
    echo "当前TOP 10连接数统计："
    local tmp_file=$(mktemp)
    get_connection_stats > "$tmp_file"
    
    while read count ip; do
        if [ ! -z "$ip" ]; then
            status=""
            if is_blocked "$ip"; then
                status=" (已封禁)"
            elif is_whitelisted "$ip"; then
                status=" (白名单)"
            fi
            echo "IP: $ip - 连接数: $count$status"
        fi
    done < <(head -n 10 "$tmp_file")
    
    rm -f "$tmp_file"
    
    echo ""
    echo "当前已封禁的IP列表："
    get_blocked_ips
    echo ""
    
    echo "最近的封禁记录 (最新5条)："
    tail -n 5 "$BLACKLIST_LOG"
    echo "==========================================="
}

# 设置信号处理
trap 'echo "正在退出..."; exit 0' SIGINT SIGTERM

# 主循环
echo "=== TCP连接监控脚本启动 ==="
echo "启动时间: $(date '+%Y-%m-%d %H:%M:%S') UTC"
echo "连接阈值: $THRESHOLD"
echo "检查间隔: $CHECK_INTERVAL 秒"
echo "白名单文件: $WHITELIST_FILE"
echo "封禁日志: $BLACKLIST_LOG"
echo "调试日志: $DEBUG_LOG"
echo "=========================="

# 记录启动信息
log_debug "脚本启动 - 阈值: $THRESHOLD, 检查间隔: $CHECK_INTERVAL 秒"

while true; do
    echo "$(date '+%Y-%m-%d %H:%M:%S') UTC - 正在检查TCP连接..."
    
    # 执行连接检查
    process_connections
    
    # 显示状态
    show_status
    
    echo "下次检查时间: $(date -d "+$CHECK_INTERVAL seconds" '+%Y-%m-%d %H:%M:%S') UTC"
    echo "等待 $CHECK_INTERVAL 秒后进行下一次检查..."
    echo "按 Ctrl+C 停止监控"
    echo ""
    
    sleep $CHECK_INTERVAL &
    wait $!
done

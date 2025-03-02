#!/bin/bash

# 创建必要的目录和文件
SCRIPT_DIR="/opt/scripts"
if [ ! -d "$SCRIPT_DIR" ]; then
    echo "正在创建脚本目录 $SCRIPT_DIR ..."
    mkdir -p "$SCRIPT_DIR"
fi

# 配置参数
THRESHOLD=1000                  # 总TCP连接数阈值
CONN_RATE_THRESHOLD=30        # 连接速率阈值（每秒新增连接数）
SYN_THRESHOLD=30              # SYN连接阈值
ESTABLISHED_THRESHOLD=500     # ESTABLISHED连接阈值
CHECK_INTERVAL=3              # 检查间隔（秒）
WHITELIST_FILE="$SCRIPT_DIR/tcp_whitelist.txt"
BLACKLIST_LOG="$SCRIPT_DIR/blocked_ips.log"
DEBUG_LOG="$SCRIPT_DIR/debug.log"
HISTORY_FILE="$SCRIPT_DIR/connection_history.tmp"

# 创建必要的文件
touch "$WHITELIST_FILE"
touch "$BLACKLIST_LOG"
touch "$DEBUG_LOG"
touch "$HISTORY_FILE"

# 确保文件权限正确
chmod 644 "$WHITELIST_FILE"
chmod 644 "$BLACKLIST_LOG"
chmod 644 "$DEBUG_LOG"
chmod 644 "$HISTORY_FILE"

# 检查是否以root权限运行
if [ "$EUID" -ne 0 ]; then
    echo "请以root权限运行此脚本"
    exit 1
fi

# 检查必要的命令是否存在
for cmd in netstat awk sort uniq iptables grep; do
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
    local reason=$2
    if ! is_blocked "$ip" && ! is_whitelisted "$ip"; then
        log_debug "尝试封禁 IP: $ip (原因: $reason)"
        # 在INPUT链的最前面添加封禁规则
        if iptables -I INPUT 1 -s "$ip" -j DROP; then
            local log_message="$(date '+%Y-%m-%d %H:%M:%S') UTC - 已封禁 IP: $ip (原因: $reason)"
            echo "$log_message" | tee -a "$BLACKLIST_LOG"
            log_debug "成功添加封禁规则: $ip"
            
            # 立即断开现有连接
            netstat -tpn | grep "$ip" | awk '{print $7}' | cut -d/ -f1 | grep -v '-' | sort -u | xargs -r kill 2>/dev/null || true
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

# 获取所有TCP连接统计
get_connection_stats() {
    netstat -tpn | grep tcp | \
    awk '{print $5}' | \
    awk -F: '{print $1}' | \
    grep -E '^([0-9]{1,3}\.){3}[0-9]{1,3}$' | \
    sort | uniq -c | \
    sort -nr
}

# 获取SYN_RECV状态的连接统计
get_syn_recv_stats() {
    netstat -tpn | grep SYN_RECV | \
    awk '{print $5}' | \
    awk -F: '{print $1}' | \
    grep -E '^([0-9]{1,3}\.){3}[0-9]{1,3}$' | \
    sort | uniq -c | \
    sort -nr
}

# 获取ESTABLISHED状态的连接统计 - 新增函数
get_established_stats() {
    netstat -tpn | grep ESTABLISHED | \
    awk '{print $5}' | \
    awk -F: '{print $1}' | \
    grep -E '^([0-9]{1,3}\.){3}[0-9]{1,3}$' | \
    sort | uniq -c | \
    sort -nr
}

# 保存当前连接统计到历史文件
save_connection_history() {
    local timestamp=$(date +%s)
    local tmp_file=$(mktemp)
    
    # 获取当前所有连接
    get_connection_stats > "$tmp_file"
    
    # 将时间戳和连接数据写入历史文件
    echo "TIME:$timestamp" > "$HISTORY_FILE"
    cat "$tmp_file" >> "$HISTORY_FILE"
    
    rm -f "$tmp_file"
}

# 计算连接速率
calculate_connection_rate() {
    local ip=$1
    local current_count=$2
    local last_timestamp=$(grep -m 1 "TIME:" "$HISTORY_FILE" | cut -d':' -f2)
    local current_timestamp=$(date +%s)
    local time_diff=$((current_timestamp - last_timestamp))
    
    # 避免除以零
    [ "$time_diff" -eq 0 ] && time_diff=1
    
    # 获取上次检查时的连接数
    local last_count=$(grep -A 100 "TIME:" "$HISTORY_FILE" | grep -v "TIME:" | grep -w "$ip" | awk '{print $1}')
    [ -z "$last_count" ] && last_count=0
    
    # 计算连接速率（每秒新增连接数）
    local rate=$(( (current_count - last_count) / time_diff ))
    
    echo "$rate"
}

# 处理单次检查
process_connections() {
    log_debug "开始处理连接检查"
    
    # 创建临时文件
    local all_conn_file=$(mktemp)
    local syn_conn_file=$(mktemp)
    local established_conn_file=$(mktemp)  # 新增
    
    # 获取各种连接状态统计
    get_connection_stats > "$all_conn_file"
    get_syn_recv_stats > "$syn_conn_file"
    get_established_stats > "$established_conn_file"  # 新增
    
    # 检查总连接数
    log_debug "检查总TCP连接数"
    head -n 20 "$all_conn_file" | while read count ip; do
        if [ ! -z "$ip" ] && [ "$count" -ge "$THRESHOLD" ]; then
            log_debug "发现高连接数IP: $ip (连接数: $count)"
            if ! is_whitelisted "$ip" && ! is_blocked "$ip"; then
                # 计算连接速率
                local rate=$(calculate_connection_rate "$ip" "$count")
                echo "检测到异常IP: $ip (总连接数: $count, 连接速率: $rate/秒)"
                block_ip "$ip" "总连接数($count)超过阈值($THRESHOLD)"
            fi
        fi
    done
    
    # 检查SYN_RECV状态连接
    log_debug "检查SYN_RECV状态连接数"
    head -n 20 "$syn_conn_file" | while read count ip; do
        if [ ! -z "$ip" ] && [ "$count" -ge "$SYN_THRESHOLD" ]; then
            log_debug "发现SYN连接过多IP: $ip (SYN连接数: $count)"
            if ! is_whitelisted "$ip" && ! is_blocked "$ip"; then
                echo "检测到异常IP: $ip (SYN连接数: $count)"
                block_ip "$ip" "SYN连接数($count)超过阈值($SYN_THRESHOLD)"
            fi
        fi
    done
    
    # 检查ESTABLISHED状态连接 - 新增检查
    log_debug "检查ESTABLISHED状态连接数"
    head -n 20 "$established_conn_file" | while read count ip; do
        if [ ! -z "$ip" ] && [ "$count" -ge "$ESTABLISHED_THRESHOLD" ]; then
            log_debug "发现ESTABLISHED连接过多IP: $ip (ESTABLISHED连接数: $count)"
            if ! is_whitelisted "$ip" && ! is_blocked "$ip"; then
                echo "检测到异常IP: $ip (ESTABLISHED连接数: $count)"
                block_ip "$ip" "ESTABLISHED连接数($count)超过阈值($ESTABLISHED_THRESHOLD)"
            fi
        fi
    done
    
    # 检查连接速率
    log_debug "检查连接速率"
    head -n 30 "$all_conn_file" | while read count ip; do
        if [ ! -z "$ip" ] && [ "$count" -gt 10 ]; then  # 只检查有一定连接数的IP
            local rate=$(calculate_connection_rate "$ip" "$count")
            
            if [ "$rate" -ge "$CONN_RATE_THRESHOLD" ]; then
                log_debug "发现连接速率异常IP: $ip (速率: $rate/秒)"
                if ! is_whitelisted "$ip" && ! is_blocked "$ip"; then
                    echo "检测到异常IP: $ip (连接速率: $rate/秒)"
                    block_ip "$ip" "连接速率($rate/秒)超过阈值($CONN_RATE_THRESHOLD/秒)"
                fi
            fi
        fi
    done
    
    # 保存当前连接状态用于下次比较
    save_connection_history
    
    # 清理临时文件
    rm -f "$all_conn_file" "$syn_conn_file" "$established_conn_file"
    
    log_debug "完成连接检查"
}

# 显示状态信息
show_status() {
    local current_time=$(date '+%Y-%m-%d %H:%M:%S')
    echo ""
    echo "=== 当前监控状态 $current_time UTC ==="
    echo "总连接阈值: $THRESHOLD"
    echo "SYN连接阈值: $SYN_THRESHOLD"
    echo "ESTABLISHED连接阈值: $ESTABLISHED_THRESHOLD"  # 新增
    echo "连接速率阈值: $CONN_RATE_THRESHOLD/秒"
    
    local blocked_count=$(iptables -L INPUT -n | grep -c DROP)
    echo "已封禁IP数量: $blocked_count"
    
    echo "当前TOP 10连接数统计："
    local tmp_file=$(mktemp)
    get_connection_stats > "$tmp_file"
    
    head -n 10 "$tmp_file" | while read count ip; do
        if [ ! -z "$ip" ]; then
            status=""
            if is_blocked "$ip"; then
                status=" (已封禁)"
            elif is_whitelisted "$ip"; then
                status=" (白名单)"
            fi
            echo "IP: $ip - 连接数: $count$status"
        fi
    done
    
    echo ""
    echo "当前TOP 10 SYN_RECV状态连接统计："
    local syn_file=$(mktemp)
    get_syn_recv_stats > "$syn_file"
    
    head -n 10 "$syn_file" | while read count ip; do
        if [ ! -z "$ip" ]; then
            status=""
            if is_blocked "$ip"; then
                status=" (已封禁)"
            elif is_whitelisted "$ip"; then
                status=" (白名单)"
            fi
            echo "IP: $ip - SYN连接数: $count$status"
        fi
    done
    
    echo ""
    echo "当前TOP 10 ESTABLISHED状态连接统计："  # 新增状态显示
    local established_file=$(mktemp)
    get_established_stats > "$established_file"
    
    head -n 10 "$established_file" | while read count ip; do
        if [ ! -z "$ip" ]; then
            status=""
            if is_blocked "$ip"; then
                status=" (已封禁)"
            elif is_whitelisted "$ip"; then
                status=" (白名单)"
            fi
            echo "IP: $ip - ESTABLISHED连接数: $count$status"
        fi
    done
    
    rm -f "$tmp_file" "$syn_file" "$established_file"
    
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
echo "=== 增强版TCP连接监控脚本启动 ==="
echo "启动时间: $(date '+%Y-%m-%d %H:%M:%S') UTC"
echo "总连接阈值: $THRESHOLD"
echo "SYN连接阈值: $SYN_THRESHOLD" 
echo "ESTABLISHED连接阈值: $ESTABLISHED_THRESHOLD"  # 新增
echo "连接速率阈值: $CONN_RATE_THRESHOLD/秒"
echo "检查间隔: $CHECK_INTERVAL 秒"
echo "白名单文件: $WHITELIST_FILE"
echo "封禁日志: $BLACKLIST_LOG"
echo "调试日志: $DEBUG_LOG"
echo "=========================="

# 初始化连接历史记录
save_connection_history

# 记录启动信息
log_debug "脚本启动 - 总阈值: $THRESHOLD, SYN阈值: $SYN_THRESHOLD, ESTABLISHED阈值: $ESTABLISHED_THRESHOLD, 速率阈值: $CONN_RATE_THRESHOLD/秒, 检查间隔: $CHECK_INTERVAL 秒"

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

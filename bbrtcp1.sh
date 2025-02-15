Claude优化的BBR脚本
#!/usr/bin/env bash
Green_font_prefix="\033[32m"
Red_font_prefix="\033[31m"
Font_color_suffix="\033[0m"
Info="${Green_font_prefix}[信息]${Font_color_suffix}"
Error="${Red_font_prefix}[错误]${Font_color_suffix}"

copyright(){
    clear
echo "\
############################################################

Linux TCP网络优化脚本 - 精简版
适用于: 高并发、大流量(5Gbps+)环境
支持: IPv4/IPv6双栈优化
版本: 1.1.0
更新: 2024-02-15

############################################################
"
}

tcp_tune(){ 
    # 清理旧配置
    sed -i '/net.ipv4.tcp_no_metrics_save/d' /etc/sysctl.conf
    sed -i '/net.ipv4.tcp_ecn/d' /etc/sysctl.conf
    sed -i '/net.ipv4.tcp_frto/d' /etc/sysctl.conf
    sed -i '/net.ipv4.tcp_mtu_probing/d' /etc/sysctl.conf
    sed -i '/net.ipv4.tcp_rfc1337/d' /etc/sysctl.conf
    sed -i '/net.ipv4.tcp_sack/d' /etc/sysctl.conf
    sed -i '/net.ipv4.tcp_fack/d' /etc/sysctl.conf
    sed -i '/net.ipv4.tcp_window_scaling/d' /etc/sysctl.conf
    sed -i '/net.ipv4.tcp_adv_win_scale/d' /etc/sysctl.conf
    sed -i '/net.ipv4.tcp_moderate_rcvbuf/d' /etc/sysctl.conf
    sed -i '/net.ipv4.tcp_rmem/d' /etc/sysctl.conf
    sed -i '/net.ipv4.tcp_wmem/d' /etc/sysctl.conf
    sed -i '/net.core.rmem_max/d' /etc/sysctl.conf
    sed -i '/net.core.wmem_max/d' /etc/sysctl.conf
    sed -i '/net.ipv4.udp_rmem_min/d' /etc/sysctl.conf
    sed -i '/net.ipv4.udp_wmem_min/d' /etc/sysctl.conf
    sed -i '/net.core.default_qdisc/d' /etc/sysctl.conf
    sed -i '/net.ipv4.tcp_congestion_control/d' /etc/sysctl.conf
    sed -i '/net.ipv4.tcp_max_tw_buckets/d' /etc/sysctl.conf
    sed -i '/net.ipv4.tcp_max_syn_backlog/d' /etc/sysctl.conf
    sed -i '/net.core.somaxconn/d' /etc/sysctl.conf
    sed -i '/net.core.netdev_max_backlog/d' /etc/sysctl.conf
    sed -i '/net.ipv4.tcp_slow_start_after_idle/d' /etc/sysctl.conf
    sed -i '/net.ipv4.tcp_tw_reuse/d' /etc/sysctl.conf
    sed -i '/vm.min_free_kbytes/d' /etc/sysctl.conf
    
    # 写入新配置
    cat >> /etc/sysctl.conf << EOF
# 基础TCP配置
net.ipv4.tcp_no_metrics_save=1
net.ipv4.tcp_ecn=0
net.ipv4.tcp_frto=0
net.ipv4.tcp_mtu_probing=0
net.ipv4.tcp_rfc1337=1
net.ipv4.tcp_sack=1
net.ipv4.tcp_fack=1
net.ipv4.tcp_window_scaling=1
net.ipv4.tcp_adv_win_scale=1
net.ipv4.tcp_moderate_rcvbuf=1
net.ipv4.tcp_slow_start_after_idle=0

# 内存和缓冲区优化
net.core.rmem_max=67108864
net.core.wmem_max=67108864
net.core.rmem_default=67108864
net.core.wmem_default=67108864
net.core.optmem_max=67108864
net.ipv4.tcp_rmem=4096 87380 67108864
net.ipv4.tcp_wmem=4096 87380 67108864
net.ipv4.udp_rmem_min=8192
net.ipv4.udp_wmem_min=8192

# 并发连接优化
net.core.somaxconn=65535
net.core.netdev_max_backlog=262144
net.ipv4.tcp_max_syn_backlog=262144
net.ipv4.tcp_max_tw_buckets=262144

# 拥塞控制和队列调度
net.core.default_qdisc=fq_codel
net.ipv4.tcp_congestion_control=bbr

# TIME_WAIT状态优化
net.ipv4.tcp_tw_reuse=1
net.ipv4.tcp_timestamps=1

# 内存使用优化
vm.min_free_kbytes=1048576
EOF

    # 应用配置
    sysctl -p && sysctl --system
    echo "${Info} TCP优化完成！建议重启系统以获得最佳性能。"
}

# 检查是否为root用户
[[ $EUID -ne 0 ]] && echo -e "${Error} 必须使用root用户运行此脚本！" && exit 1

# 运行脚本
copyright
tcp_tune

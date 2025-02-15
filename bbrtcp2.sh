#!/usr/bin/env bash

# 颜色定义
Green_font_prefix="\033[32m"
Red_font_prefix="\033[31m"
Font_color_suffix="\033[0m"
Info="${Green_font_prefix}[信息]${Font_color_suffix}"
Error="${Red_font_prefix}[错误]${Font_color_suffix}"

# 检查是否为 root 用户
if [[ $EUID -ne 0 ]]; then
   echo -e "${Error} 必须使用 root 用户运行此脚本!"
   exit 1
fi

# 备份原配置
cp /etc/sysctl.conf /etc/sysctl.conf.bak

# 清空所有 TCP 相关配置
sed -i '/net\.ipv4\.tcp_/d' /etc/sysctl.conf
sed -i '/net\.ipv6\.tcp_/d' /etc/sysctl.conf
sed -i '/net\.core\./d' /etc/sysctl.conf
sed -i '/net\.ipv4\.ip_/d' /etc/sysctl.conf

# 写入新配置
cat > /etc/sysctl.conf << EOF
# 系统参数优化
# Last modified: $(date +"%Y-%m-%d %H:%M:%S")

#------------------------------
# IPv4/IPv6 双栈 TCP 核心优化
#------------------------------

# IPv4 基础优化
net.ipv4.tcp_no_metrics_save = 1
net.ipv4.tcp_ecn = 0
net.ipv4.tcp_frto = 0
net.ipv4.tcp_mtu_probing = 0
net.ipv4.tcp_rfc1337 = 0
net.ipv4.tcp_sack = 1
net.ipv4.tcp_fack = 1
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_adv_win_scale = 1
net.ipv4.tcp_moderate_rcvbuf = 1
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 15
net.ipv4.ip_forward = 1
net.ipv4.ip_local_port_range = 1024 65535

# IPv4 高性能缓冲区
net.ipv4.tcp_rmem = 4096 87380 67108864
net.ipv4.tcp_wmem = 4096 65536 67108864
net.core.rmem_max = 67108864
net.core.wmem_max = 67108864
net.core.rmem_default = 65536
net.core.wmem_default = 65536
net.core.netdev_max_backlog = 65536

# IPv6 优化
net.ipv6.tcp_sack = 1
net.ipv6.tcp_window_scaling = 1
net.ipv6.tcp_adv_win_scale = 1
net.ipv6.tcp_moderate_rcvbuf = 1

# 队列与拥塞控制
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
net.ipv6.tcp_congestion_control = bbr

# 连接数扩展
net.ipv4.tcp_max_syn_backlog = 65536
net.core.somaxconn = 65535
net.ipv4.tcp_max_tw_buckets = 2000000
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_max_orphans = 131072
net.ipv4.tcp_timestamps = 1
EOF

# 应用配置
if sysctl -p && sysctl --system; then
   echo -e "${Info} TCP 优化配置已成功应用!"
   echo -e "${Info} 原配置已备份至 /etc/sysctl.conf.bak"
else
   echo -e "${Error} TCP 优化配置应用失败!"
   # 如果应用失败，恢复备份
   mv /etc/sysctl.conf.bak /etc/sysctl.conf
   sysctl -p
   exit 1
fi

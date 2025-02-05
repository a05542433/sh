#!/bin/bash

# 确保以 root 权限运行
if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

# 生成优化配置 (保留系统原有其他参数)
tee /etc/sysctl.d/99-optimized-tcp.conf > /dev/null <<'EOL'
# ====== 核心连接控制 ======
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 15
net.ipv4.tcp_max_syn_backlog = 262144
net.ipv4.tcp_max_tw_buckets = 262144
net.ipv4.ip_local_port_range = 10000 60000

# ====== 流量控制与拥塞算法 ======
net.core.default_qdisc = fq_pie    # 综合吞吐/延迟优于 fq_codel
net.ipv4.tcp_congestion_control = bbr

# ====== 缓冲区动态调整 ======
net.ipv4.tcp_rmem = 4096 1048576 33554432  # [初始<默认<最大] 兼顾突发和稳定
net.ipv4.tcp_wmem = 8192 1048576 33554432
net.core.rmem_max = 33554432
net.core.wmem_max = 33554432

# ====== 高级特性控制 ======
net.ipv4.tcp_sack = 1             # 选择性确认(提升重传效率)
net.ipv4.tcp_fack = 0             # 禁用前向确认(避免 bufferbloat)
net.ipv4.tcp_ecn = 0              # 禁用显式拥塞通知(兼容性更好)
net.ipv4.tcp_mtu_probing = 1      # 启用 MTU 探测(适合 VPN/移动网络)

# ====== 内核资源优化 ======
vm.max_map_count = 262144         # 提高内存映射上限
net.core.netdev_max_backlog = 16384
net.core.netdev_budget = 600
EOL

# 立即应用配置
sysctl -p /etc/sysctl.d/99-optimized-tcp.conf

echo "TCP optimization applied. Recommended to reboot for full effect."

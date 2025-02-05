#!/bin/bash

# 高带宽网络专用优化脚本
if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

# 生成专业级优化配置
tee /etc/sysctl.d/99-highspeed-tcp.conf > /dev/null <<'EOL'
# ====== 核心连接优化 ======
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 10
net.ipv4.tcp_max_syn_backlog = 262144
net.ipv4.tcp_max_tw_buckets = 262144
net.ipv4.ip_local_port_range = 1024 65000

# ====== 高速传输控制 ======
net.core.default_qdisc = fq_pie
net.ipv4.tcp_congestion_control = bbr
net.ipv4.tcp_slow_start_after_idle = 0  # 禁用空闲后慢启动
net.ipv4.tcp_notsent_lowat = 16384      # 提升突发传输能力

# ====== 动态缓冲区优化 ======
net.ipv4.tcp_rmem = 8192 16777216 67108864  # 初始/默认/最大 (8K/16MB/64MB)
net.ipv4.tcp_wmem = 8192 16777216 67108864
net.core.rmem_max = 67108864
net.core.wmem_max = 67108864
net.ipv4.tcp_mem = 262144 524288 786432     # 内存页分配优化

# ====== BBR高级调参 ======
net.ipv4.tcp_congestion_control = bbr
net.core.wmem_default = 1048576      # 提升初始窗口
net.core.rmem_default = 1048576
net.ipv4.tcp_initcwnd_burst = 20     # 初始突发包量
net.ipv4.tcp_initcwnd = 20           # 初始拥塞窗口(CWND)

# ====== 硬件级优化 ======
net.core.netdev_max_backlog = 300000 # 适应高速网卡
net.core.netdev_budget = 60000       # CPU处理配额
net.core.somaxconn = 32768           # 大并发连接队列

# ====== 协议栈增强 ======
net.ipv4.tcp_autocorking = 1         # 智能数据包聚合
net.ipv4.tcp_limit_output_bytes = 0  # 禁用输出限制
net.ipv4.tcp_adv_win_scale = 2       # 优化窗口缩放因子
EOL

# 立即加载配置
sysctl -p /etc/sysctl.d/99-highspeed-tcp.conf

# 设置路由初始窗口 (需iproute2)
echo "#!/bin/sh" > /etc/network/if-up.d/set_initcwnd
echo "ip route change default initcwnd 20" >> /etc/network/if-up.d/set_initcwnd
chmod +x /etc/network/if-up.d/set_initcwnd

echo "High-speed TCP optimization applied! Recommended:"
echo "1. Reboot system"
echo "2. Verify with: ss -tin && tc -s qdisc"
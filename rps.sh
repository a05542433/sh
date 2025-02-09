#!/bin/bash

# 修复 bc 安装
bc -v >/dev/null 2>&1 || {
  if command -v apt >/dev/null; then
    apt install -y bc
  elif command -v yum >/dev/null; then
    yum install -y bc
  else
    echo "无法安装 bc，请手动安装"
    exit 1
  fi
}

# 动态获取最大流表值
sysctl -w net.core.rps_sock_flow_entries=65536
cc=$(grep -c processor /proc/cpuinfo)
if [ -f /sys/class/net/eth0/queues/rx-0/rps_flow_cnt_max ]; then
  max_flow=$(cat /sys/class/net/eth0/queues/rx-0/rps_flow_cnt_max)
else
  max_flow=65536
fi
rfc=$(( max_flow / cc ))

# 写入 rps_flow_cnt（兼容所有网卡）
for fileRfc in $(ls /sys/class/net/*/queues/rx-*/rps_flow_cnt 2>/dev/null); do
  echo $rfc > $fileRfc 2>/dev/null
done

# 生成 CPU 掩码
cc=$(grep -c processor /proc/cpuinfo)
mask=$(printf "%x" $(( (1 << cc) - 1 )) | sed 's/0/f/g')
for fileRps in $(ls /sys/class/net/*/queues/rx-*/rps_cpus 2>/dev/null); do
  echo $mask > $fileRps 2>/dev/null
done

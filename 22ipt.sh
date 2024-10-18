#!/bin/bash

# 安装 iptables-persistent，并自动确认
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y iptables-persistent

# 添加防火墙规则
iptables -A OUTPUT -d 0.0.0.0/0 -p tcp --dport 22 -j REJECT
iptables -A OUTPUT -d 0.0.0.0/0 -p udp --dport 22 -j REJECT
iptables -A OUTPUT -d 0.0.0.0/0 -p tcp --dport 25 -j REJECT
iptables -A OUTPUT -d 0.0.0.0/0 -p udp --dport 25 -j REJECT
iptables -A OUTPUT -d 0.0.0.0/0 -p tcp --dport 137 -j REJECT
iptables -A OUTPUT -d 0.0.0.0/0 -p udp --dport 137 -j REJECT
iptables -A OUTPUT -d 0.0.0.0/0 -p tcp --dport 465 -j REJECT
iptables -A OUTPUT -d 0.0.0.0/0 -p udp --dport 465 -j REJECT
iptables -A OUTPUT -d 0.0.0.0/0 -p tcp --dport 587 -j REJECT
iptables -A OUTPUT -d 0.0.0.0/0 -p udp --dport 587 -j REJECT
iptables -A OUTPUT -d 0.0.0.0/0 -p tcp --dport 389 -j REJECT
iptables -A OUTPUT -d 0.0.0.0/0 -p udp --dport 389 -j REJECT
iptables -A OUTPUT -d 0.0.0.0/0 -p tcp --dport 1900 -j REJECT
iptables -A OUTPUT -d 0.0.0.0/0 -p udp --dport 1900 -j REJECT
iptables -A OUTPUT -d 0.0.0.0/0 -p tcp --dport 3306 -j REJECT
iptables -A OUTPUT -d 0.0.0.0/0 -p udp --dport 3306 -j REJECT
iptables -A OUTPUT -d 0.0.0.0/0 -p tcp --dport 6881:6889 -j DROP
iptables -A FORWARD -m string --algo bm --string "BitTorrent" -j DROP
iptables -A FORWARD -p udp -m string --algo bm --string "BitTorrent" -j DROP
iptables -A FORWARD -p udp -m string --algo bm --string "BitTorrent protocol" -j DROP
iptables -A INPUT -p udp -m string --algo bm --string "BitTorrent" -j DROP
iptables -A INPUT -p udp -m string --algo bm --string "BitTorrent protocol" -j DROP

# 保存防火墙规则并确保重启后加载
iptables-save > /etc/iptables/rules.v4
ip6tables-save > /etc/iptables/rules.v6

echo "防火墙规则已设置完成，并将在系统重启后自动加载。"

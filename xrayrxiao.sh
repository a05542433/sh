#!/bin/bash

# XrayR 一键安装脚本

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

# 检查 root 权限
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "请使用 root 用户运行此脚本！"
    fi
}

# 安装依赖
install_dependencies() {
    info "正在安装依赖..."
    if command -v apt-get &> /dev/null; then
        apt-get update -y
        apt-get install -y wget unzip curl
    elif command -v yum &> /dev/null; then
        yum install -y wget unzip curl
    elif command -v dnf &> /dev/null; then
        dnf install -y wget unzip curl
    fi
}

# 下载并解压
download_xrayr() {
    info "正在下载 XrayR..."
    
    DOWNLOAD_URL="https://d6l5.c17.e2-5.dev/xrayr/XrayRxiao.zip"
    TMP_DIR="/tmp/xrayr_install"
    
    rm -rf "$TMP_DIR"
    mkdir -p "$TMP_DIR"
    cd "$TMP_DIR"
    
    wget -O XrayRxiao.zip "$DOWNLOAD_URL" || error "下载失败！"
    
    info "正在解压..."
    unzip -o XrayRxiao.zip || error "解压失败！"
}

# 安装文件
install_files() {
    info "正在安装文件..."
    
    TMP_DIR="/tmp/xrayr_install"
    SRC_DIR="$TMP_DIR/XrayRxiao"
    
    # 检查解压目录是否存在
    if [[ ! -d "$SRC_DIR" ]]; then
        error "解压目录不存在！"
    fi
    
    # 停止现有服务
    systemctl stop XrayR 2>/dev/null || true
    
    # 创建目录
    mkdir -p /usr/local/XrayR
    mkdir -p /etc/systemd/system
    
    # 复制 /usr/local/XrayR 目录
    info "复制配置文件目录..."
    cp -rf "$SRC_DIR/usr/local/XrayR/"* /usr/local/XrayR/
    
    # 复制 /usr/bin/XrayR 文件
    info "复制可执行文件..."
    cp -f "$SRC_DIR/usr/bin/XrayR" /usr/bin/XrayR
    
    # 复制 service 文件
    info "复制 systemd 服务文件..."
    cp -f "$SRC_DIR/etc/systemd/system/XrayR.service" /etc/systemd/system/XrayR.service
    
    # 创建软链接
    info "创建软链接..."
    rm -f /usr/bin/xrayr
    ln -s /usr/bin/XrayR /usr/bin/xrayr
    
    # 设置执行权限
    info "设置执行权限..."
    chmod +x /usr/bin/XrayR
    chmod +x /usr/bin/xrayr
    chmod +x /usr/local/XrayR/XrayR
    
    # 重新加载 systemd
    systemctl daemon-reload
    
    # 设置开机自启
    info "设置开机自启..."
    systemctl enable XrayR
}

# 清理
cleanup() {
    info "清理临时文件..."
    rm -rf /tmp/xrayr_install
}

# 完成信息
show_complete() {
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}    XrayR 安装完成！${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    echo "常用命令："
    echo "  启动：systemctl start XrayR"
    echo "  停止：systemctl stop XrayR"
    echo "  重启：systemctl restart XrayR"
    echo "  状态：systemctl status XrayR"
    echo "  日志：journalctl -u XrayR -f"
    echo ""
    echo "配置文件：/usr/local/XrayR/config.yml"
    echo ""
    echo -e "${GREEN}已设置开机自启动${NC}"
    echo ""
}

# 主函数
main() {
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}    XrayR 一键安装脚本${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    
    check_root
    install_dependencies
    download_xrayr
    install_files
    cleanup
    show_complete
}

main
#!/usr/bin/env bash

# quick_install.sh
#
# Script cài đặt nhanh Dante SOCKS5 proxy server
# Tác giả: ThienTranJP
#
# Script này sẽ tải về và cài đặt Dante SOCKS5 proxy server
# với các cài đặt mặc định và tạo một số proxy user ngẫu nhiên

# Màu sắc
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Kiểm tra quyền root
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}Script này yêu cầu quyền root.${NC}"
    echo -e "${YELLOW}Vui lòng chạy với sudo hoặc với tư cách root.${NC}"
    exit 1
fi

# Hiển thị banner
echo -e "${BLUE}=======================================================${NC}"
echo -e "${GREEN}       Cài đặt nhanh Dante SOCKS5 Proxy Server        ${NC}"
echo -e "${BLUE}=======================================================${NC}"
echo -e "${YELLOW}Tác giả: ThienTranJP${NC}"
echo -e "${BLUE}=======================================================${NC}"
echo ""

# Phát hiện hệ điều hành
if [[ -f /etc/os-release ]]; then
    source /etc/os-release
    OS=$ID
    VERSION=$VERSION_ID
    
    if [[ "$OS" == "debian" || "$OS" == "ubuntu" ]]; then
        echo -e "${GREEN}Đã phát hiện ${OS^} ${VERSION}${NC}"
    elif [[ "$OS" == "centos" ]]; then
        echo -e "${GREEN}Đã phát hiện CentOS ${VERSION}${NC}"
    else
        echo -e "${RED}Hệ điều hành không được hỗ trợ.${NC}"
        echo -e "${YELLOW}Script này chỉ hỗ trợ Debian, Ubuntu và CentOS.${NC}"
        exit 1
    fi
else
    echo -e "${RED}Không thể phát hiện hệ điều hành.${NC}"
    exit 1
fi

# Cài đặt các gói phụ thuộc
echo -e "${CYAN}Đang cài đặt các gói phụ thuộc...${NC}"
if [[ "$OS" == "debian" || "$OS" == "ubuntu" ]]; then
    apt-get update
    apt-get install -y git curl wget zip unzip make gcc g++ openssl libssl-dev
elif [[ "$OS" == "centos" ]]; then
    yum -y update
    yum -y install git curl wget zip unzip make gcc openssl openssl-devel
fi

# Tải về repository
echo -e "${CYAN}Đang tải về ProxyDante...${NC}"
cd /tmp
git clone https://github.com/yourusername/ProxyDante.git
cd ProxyDante

# Cấp quyền thực thi
echo -e "${CYAN}Đang cấp quyền thực thi cho các script...${NC}"
chmod +x install.sh
chmod +x scripts/*.sh
chmod +x lib/*.sh

# Chạy script cài đặt
echo -e "${GREEN}Bắt đầu cài đặt Dante SOCKS5 proxy server...${NC}"
./install.sh

# Tạo 5 proxy user ngẫu nhiên
echo -e "${CYAN}Đang tạo 5 proxy user ngẫu nhiên...${NC}"
./scripts/add_random_users.sh

# Xuất danh sách proxy
echo -e "${CYAN}Đang xuất danh sách proxy...${NC}"
./scripts/export_proxy_list.sh

# Hoàn thành
echo -e "${GREEN}Cài đặt hoàn tất!${NC}"
echo -e "${YELLOW}Bạn có thể quản lý proxy bằng cách chạy: ./install.sh${NC}"
echo -e "${YELLOW}Danh sách proxy đã được xuất ra file proxy_list.txt${NC}"

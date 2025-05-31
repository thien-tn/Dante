#!/usr/bin/env bash

# lib/install_dante.sh
#
# Chứa các hàm cài đặt Dante SOCKS5 proxy server
# Tác giả: akmaslov-dev
# Chỉnh sửa bởi: ThienTranJP

# Cài đặt các gói phụ thuộc
install_dependencies() {
    info_message "Đang cài đặt các gói phụ thuộc..."
    
    if [[ "$OStype" = 'deb' ]]; then
        # Nếu là hệ điều hành dựa trên Debian
        apt-get update
        apt-get -y install openssl make gcc zip jq
    else
        # Nếu là CentOS
        yum -y install epel-release
        yum -y install openssl make gcc zip jq
    fi
    
    success_message "Đã cài đặt các gói phụ thuộc"
}

# Tải và biên dịch Dante
download_and_compile_dante() {
    local dante_version="1.4.3"
    info_message "Đang tải Dante phiên bản $dante_version..."
    
    # Tải Dante
    if ! wget -q "https://www.inet.no/dante/files/dante-$dante_version.tar.gz"; then
        error_message "Không thể tải Dante. Kiểm tra kết nối mạng và thử lại."
        exit 5
    fi
    
    # Giải nén
    if ! tar xfz "dante-$dante_version.tar.gz"; then
        error_message "Không thể giải nén gói Dante."
        exit 6
    fi
    
    # Di chuyển vào thư mục Dante
    cd "dante-$dante_version" || {
        error_message "Không thể truy cập thư mục dante-$dante_version."
        exit 7
    }
    
    # Cấu hình Dante
    info_message "Đang cấu hình Dante..."
    ./configure \
    --prefix=/usr \
    --sysconfdir=/etc \
    --localstatedir=/var \
    --disable-client \
    --without-libwrap \
    --without-bsdauth \
    --without-gssapi \
    --without-krb5 \
    --without-upnp \
    --without-pam
    
    # Biên dịch và cài đặt
    info_message "Đang biên dịch và cài đặt Dante..."
    if ! make && make install; then
        error_message "Không thể biên dịch hoặc cài đặt Dante."
        exit 8
    fi
    
    # Quay lại thư mục gốc
    cd .. || exit
    
    # Dọn dẹp
    rm -rf "dante-$dante_version" "dante-$dante_version.tar.gz"
    
    success_message "Đã cài đặt Dante thành công"
}

# Tạo file cấu hình sockd.conf
create_sockd_conf() {
    local port=$1
    
    info_message "Đang tạo file cấu hình /etc/sockd.conf..."
    
    cat > /etc/sockd.conf <<-EOF
	internal: $interface port = $port
	external: $interface
	user.privileged: root
	user.unprivileged: nobody
	socksmethod: username
	logoutput: /var/log/sockd.log
	client pass {
		from: 0.0.0.0/0 to: 0.0.0.0/0
		log: error
		socksmethod: username
	}
	socks pass {
		from: 0.0.0.0/0 to: 0.0.0.0/0
		command: bind connect udpassociate
		log: error
		socksmethod: username
	}
	EOF
    
    success_message "Đã tạo file cấu hình /etc/sockd.conf"
}

# Tạo ngẫu nhiên nhiều proxy user
create_random_proxy_users() {
    local num=$1
    local users=()
    local passwords=()
    
    info_message "Đang tạo $num proxy user ngẫu nhiên..."
    
    for i in $(seq 1 $num); do
        # Tạo user ngẫu nhiên với 5 ký tự (gồm a-z, A-Z, 0-9)
        users[$i]="user_$(generate_random_string 5)"
        
        # Tạo password ngẫu nhiên với 5 ký tự (gồm a-z, A-Z, 0-9)
        passwords[$i]="pass_$(generate_random_string 5)"
        
        # Kiểm tra nếu username hợp lệ
        if [[ -z "${users[$i]}" ]]; then
            warning_message "Tên người dùng thứ $i không hợp lệ, bỏ qua."
            continue
        fi
        
        # Tạo user
        useradd -M -s /usr/sbin/nologin "${users[$i]}"
        echo "${users[$i]}:${passwords[$i]}" | chpasswd
        
        success_message "Đã tạo proxy user: ${users[$i]}"
    done
    
    export proxy_users=("${users[@]}")
    export proxy_passwords=("${passwords[@]}")
    
    success_message "Đã tạo $num proxy user ngẫu nhiên thành công"
}

# Cài đặt Dante proxy server
install_dante_proxy() {
    # Kiểm tra môi trường
    check_environment
    
    # Lấy thông tin cấu hình từ người dùng
    get_configuration
    
    # Cài đặt các gói phụ thuộc
    install_dependencies
    
    # Tải và biên dịch Dante
    download_and_compile_dante
    
    # Tạo file cấu hình
    create_sockd_conf "$port"
    
    # Tạo service
    create_service
    
    # Tạo proxy users
    create_random_proxy_users "$numofproxy"
    
    # Xuất danh sách proxy
    export_proxy_list
    
    success_message "Cài đặt Dante SOCKS5 proxy server hoàn tất!"
}

# Lấy thông tin cấu hình từ người dùng
get_configuration() {
    # Lấy số cổng
    while true; do
        read -p "Nhập số cổng cho proxy server: " -e -i 1080 port
        if is_valid_number "$port" 1 65535; then
            break
        else
            error_message "Số cổng không hợp lệ! Vui lòng nhập một số từ 1 đến 65535."
        fi
    done
    
    # Mở cổng trong tường lửa
    open_firewall_port "$port"
    
    # Lấy số lượng proxy
    while true; do
        read -p "Nhập số lượng proxy cần tạo: " -e numofproxy
        if is_valid_number "$numofproxy" 1; then
            break
        else
            error_message "Số lượng không hợp lệ! Vui lòng nhập một số lớn hơn 0."
        fi
    done
    
    export port
    export numofproxy
}

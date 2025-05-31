#!/usr/bin/env bash

# lib/limit_speed.sh
#
# Chứa các hàm giới hạn tốc độ proxy
# Tác giả: akmaslov-dev
# Chỉnh sửa bởi: ThienTranJP

# Kiểm tra và cài đặt tc (traffic control)
check_tc_installed() {
    if ! command -v tc &> /dev/null; then
        warning_message "Công cụ tc (traffic control) chưa được cài đặt"
        
        # Cài đặt tc
        if [[ "$OStype" = 'deb' ]]; then
            apt-get -y install iproute2
        else
            yum -y install iproute-tc
        fi
        
        success_message "Đã cài đặt tc (traffic control)"
    fi
}

# Khởi tạo tc qdisc
initialize_tc() {
    local interface=$1
    
    # Xóa qdisc hiện tại nếu có
    tc qdisc del dev "$interface" root 2>/dev/null
    
    # Thiết lập root qdisc
    tc qdisc add dev "$interface" root handle 1: htb default 1
    
    # Tạo class chính
    tc class add dev "$interface" parent 1: classid 1:1 htb rate 1000mbit
    
    success_message "Đã khởi tạo tc qdisc trên giao diện $interface"
}

# Thiết lập giới hạn tốc độ cho user
# $1: Tên user
# $2: Giới hạn tốc độ (Mbps)
set_user_speed_limit() {
    local username=$1
    local limit=$2
    local interface=$3
    
    # Kiểm tra user tồn tại
    if ! user_exists "$username"; then
        error_message "User '$username' không tồn tại"
        return 1
    fi
    
    # Kiểm tra giới hạn tốc độ hợp lệ
    if ! is_valid_number "$limit" 1; then
        error_message "Giới hạn tốc độ không hợp lệ"
        return 2
    fi
    
    # Lấy UID của user
    local uid=$(id -u "$username")
    
    # Kiểm tra nếu chưa có root qdisc, tạo mới
    if ! tc qdisc show dev "$interface" | grep -q "qdisc htb 1:"; then
        initialize_tc "$interface"
    fi
    
    # Tạo class cho user
    local class_id=$((uid + 100))
    tc class add dev "$interface" parent 1: classid 1:$class_id htb rate ${limit}mbit
    
    # Tạo filter để phân loại lưu lượng của user
    tc filter add dev "$interface" protocol ip parent 1: prio 1 handle $uid fw flowid 1:$class_id
    
    # Thiết lập iptables để đánh dấu gói tin
    iptables -t mangle -A OUTPUT -m owner --uid-owner $uid -j MARK --set-mark $uid
    
    success_message "Đã thiết lập giới hạn tốc độ ${limit}Mbps cho user $username"
}

# Xóa giới hạn tốc độ cho user
# $1: Tên user
remove_user_speed_limit() {
    local username=$1
    local interface=$2
    
    # Kiểm tra user tồn tại
    if ! user_exists "$username"; then
        error_message "User '$username' không tồn tại"
        return 1
    fi
    
    # Lấy UID của user
    local uid=$(id -u "$username")
    
    # Xóa filter
    tc filter del dev "$interface" protocol ip parent 1: prio 1 handle $uid fw flowid 1:$((uid + 100)) 2>/dev/null
    
    # Xóa class
    tc class del dev "$interface" parent 1: classid 1:$((uid + 100)) 2>/dev/null
    
    # Xóa iptables rule
    iptables -t mangle -D OUTPUT -m owner --uid-owner $uid -j MARK --set-mark $uid 2>/dev/null
    
    success_message "Đã xóa giới hạn tốc độ cho user $username"
}

# Hiển thị giới hạn tốc độ hiện tại
show_speed_limits() {
    local interface=$1
    
    info_message "Danh sách giới hạn tốc độ hiện tại:"
    
    # Kiểm tra nếu có root qdisc
    if ! tc qdisc show dev "$interface" | grep -q "qdisc htb 1:"; then
        warning_message "Chưa có giới hạn tốc độ nào được thiết lập"
        return 1
    fi
    
    # Hiển thị danh sách class
    tc class show dev "$interface" | grep "class htb 1:"
}

# Thay đổi giới hạn tốc độ proxy
change_speed_limit() {
    info_message "Thay đổi giới hạn tốc độ proxy"
    
    # Kiểm tra tc đã được cài đặt
    check_tc_installed
    
    # Lấy giao diện mạng
    local interface=$(ip -o -4 route show to default | awk '{print $5}')
    
    # Hiển thị danh sách proxy user
    echo "Danh sách proxy user:"
    local users=$(get_proxy_users)
    
    if [[ -z "$users" ]]; then
        warning_message "Không có proxy user nào"
        pause
        return 1
    fi
    
    echo "$users"
    echo ""
    
    # Hiển thị giới hạn tốc độ hiện tại
    show_speed_limits "$interface"
    
    # Lấy tên user cần thay đổi giới hạn tốc độ
    read -p "Nhập tên user cần thay đổi giới hạn tốc độ: " username
    
    # Kiểm tra user tồn tại
    if ! user_exists "$username"; then
        error_message "User '$username' không tồn tại"
        pause
        return 2
    fi
    
    # Lấy giới hạn tốc độ mới
    read -p "Nhập giới hạn tốc độ mới (Mbps): " newlimit
    
    # Kiểm tra giới hạn tốc độ hợp lệ
    if ! is_valid_number "$newlimit" 1; then
        error_message "Giới hạn tốc độ không hợp lệ"
        pause
        return 3
    fi
    
    # Xóa giới hạn tốc độ cũ nếu có
    remove_user_speed_limit "$username" "$interface"
    
    # Thiết lập giới hạn tốc độ mới
    set_user_speed_limit "$username" "$newlimit" "$interface"
    
    success_message "Đã thay đổi giới hạn tốc độ thành ${newlimit}Mbps cho user $username"
    pause
}

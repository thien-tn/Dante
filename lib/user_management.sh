#!/usr/bin/env bash

# lib/user_management.sh
#
# Chứa các hàm quản lý người dùng proxy
# Tác giả: akmaslov-dev
# Chỉnh sửa bởi: ThienTranJP

# Hiển thị danh sách proxy user
list_proxy_users() {
    info_message "Danh sách proxy user hiện tại:"
    
    # Lấy danh sách user proxy
    local users=$(get_proxy_users)
    
    if [[ -z "$users" ]]; then
        warning_message "Không có proxy user nào"
    else
        echo "$users"
    fi
    
    pause
}

# Thêm một proxy user mới
add_proxy_user() {
    info_message "Thêm proxy user mới"
    
    # Lấy tên đăng nhập mới
    read -p "Nhập tên cho proxy user mới: " -e -i proxyuser usernew
    echo ""
    
    # Kiểm tra tên user không được để trống
    if [[ -z "$usernew" ]]; then
        error_message "Lỗi: Tên user không được để trống."
        pause
        return 1
    fi
    
    # Kiểm tra user đã tồn tại chưa
    if user_exists "$usernew"; then
        error_message "Lỗi: User '$usernew' đã tồn tại."
        pause
        return 2
    fi
    
    # Lấy mật khẩu mới
    while true; do
        read -s -p "Nhập mật khẩu MẠNH cho proxy user mới: " passwordnew
        echo ""
        read -s -p "Nhập lại mật khẩu: " passwordnew2
        echo ""
        
        if [[ "$passwordnew" = "$passwordnew2" ]]; then
            break
        fi
        
        error_message "Mật khẩu không khớp"
        echo ""
        warning_message "Vui lòng thử lại"
        echo ""
    done
    
    # Kiểm tra mật khẩu không được để trống
    if [[ -z "$passwordnew" ]]; then
        error_message "Lỗi: Mật khẩu không được để trống."
        pause
        return 3
    fi
    
    # Tạo proxy user mới
    useradd -M -s /usr/sbin/nologin -p "$(openssl passwd -1 "$passwordnew")" "$usernew"
    
    if user_exists "$usernew"; then
        success_message "Đã thêm user mới: $usernew"
    else
        error_message "Không thể tạo user: $usernew"
    fi
    
    pause
}

# Thêm ngẫu nhiên nhiều proxy
add_random_proxies() {
    info_message "Thêm ngẫu nhiên nhiều proxy"
    
    # Lấy số lượng proxy muốn thêm
    read -p "Số lượng proxy muốn thêm ngẫu nhiên: " num
    
    # Kiểm tra số lượng hợp lệ
    if ! is_valid_number "$num" 1; then
        error_message "Số lượng không hợp lệ! Vui lòng nhập một số lớn hơn 0."
        pause
        return 1
    fi
    
    # Lấy cổng từ file cấu hình
    local port=$(get_dante_port)
    
    info_message "Thêm $num proxy ngẫu nhiên với cổng $port"
    
    # Lấy địa chỉ IP máy chủ
    local hostname=$(get_server_ip)
    
    # Danh sách proxy
    local proxy_list=""
    
    for i in $(seq 1 $num); do
        # Tạo user ngẫu nhiên với 5 ký tự (gồm a-z, A-Z, 0-9)
        local user="user_$(generate_random_string 5)"
        
        # Tạo password ngẫu nhiên với 5 ký tự (gồm a-z, A-Z, 0-9)
        local password="pass_$(generate_random_string 5)"
        
        # Thêm user vào hệ thống với mật khẩu đã mã hóa
        useradd -M -s /usr/sbin/nologin -p "$(openssl passwd -1 "$password")" "$user"
        
        # Kiểm tra user đã được tạo thành công
        if user_exists "$user"; then
            # Lưu format IP:Port:User:Pass vào danh sách proxy
            proxy_list+="$hostname:$port:$user:$password\n"
        else
            warning_message "Không thể tạo user: $user"
        fi
    done
    
    success_message "Đã thêm $num proxy ngẫu nhiên thành công."
    
    # Xuất danh sách proxy ra màn hình
    echo -e "Danh sách proxy:\n$proxy_list"
    
    # Lưu danh sách proxy vào file
    echo -e "$proxy_list" > random_proxies.txt
    info_message "Danh sách proxy đã được lưu vào file random_proxies.txt"
    
    pause
}

# Xóa một proxy user
delete_proxy_user() {
    info_message "Xóa một proxy user"
    
    # Hiển thị danh sách proxy user hiện tại
    echo "Danh sách proxy user hiện tại:"
    local users=$(get_proxy_users)
    
    if [[ -z "$users" ]]; then
        warning_message "Không có proxy user nào"
        pause
        return 1
    fi
    
    echo "$users"
    echo ""
    
    # Lấy tên user cần xóa
    read -p "Nhập tên user cần xóa: " deluser
    echo ""
    
    # Kiểm tra user tồn tại
    if user_exists "$deluser"; then
        # Xác nhận xóa
        read -p "Bạn có chắc chắn muốn xóa user '$deluser'? (y/n): " confirm
        if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
            userdel "$deluser"
            success_message "Đã xóa user: $deluser"
        else
            info_message "Đã hủy xóa user"
        fi
    else
        error_message "Không tìm thấy user: $deluser"
    fi
    
    pause
}

# Xóa toàn bộ proxy user
delete_all_proxy_users() {
    info_message "Xóa toàn bộ proxy user"
    
    # Hiển thị danh sách proxy user hiện tại
    echo "Danh sách proxy user sẽ bị xóa:"
    local users=$(get_proxy_users)
    
    if [[ -z "$users" ]]; then
        warning_message "Không có proxy user nào"
        pause
        return 1
    fi
    
    echo "$users"
    echo ""
    
    # Xác nhận xóa
    read -p "Bạn có chắc chắn muốn xóa TẤT CẢ proxy user? (y/n): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        info_message "Đã hủy xóa toàn bộ proxy user"
        pause
        return 2
    fi
    
    # Xóa tất cả proxy user
    echo "$users" | while read -r user; do
        userdel -r "$user"
        success_message "Đã xóa user: $user"
    done
    
    success_message "Đã xóa toàn bộ proxy user"
    pause
}

# Xuất danh sách proxy
export_proxy_list() {
    info_message "Xuất danh sách proxy"
    
    # Lấy danh sách proxy user
    local users=$(get_proxy_users)
    
    if [[ -z "$users" ]]; then
        warning_message "Không có proxy user nào"
        pause
        return 1
    fi
    
    # Lấy cổng từ file cấu hình
    local port=$(get_dante_port)
    
    # Lấy địa chỉ IP máy chủ
    local hostname=$(get_server_ip)
    
    # Tạo hoặc làm trống tệp proxy.txt
    > proxy.txt
    
    # Xuất danh sách proxy
    echo "Danh sách proxy (IP:PORT:LOGIN:PASS):"
    
    # Lặp qua từng user và lấy mật khẩu
    echo "$users" | while read -r user; do
        # Lưu vào file proxy.txt
        echo "$hostname:$port:$user:******" >> proxy.txt
        echo "$hostname:$port:$user:******"
    done
    
    success_message "Đã xuất danh sách proxy vào file proxy.txt"
    
    # Hỏi người dùng có muốn nén và upload file không
    read -p "Bạn có muốn nén và upload file proxy.txt không? (y/n): " confirm
    if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
        upload_proxy_file
    fi
    
    pause
}

# Nén và upload file proxy
upload_proxy_file() {
    info_message "Đang nén và upload file proxy..."
    
    # Kiểm tra các công cụ cần thiết
    if ! command -v zip &> /dev/null || ! command -v curl &> /dev/null || ! command -v jq &> /dev/null; then
        warning_message "Cần cài đặt các gói zip, curl và jq"
        
        # Cài đặt các gói cần thiết
        if [[ "$OStype" = 'deb' ]]; then
            apt-get -y install zip curl jq
        else
            yum -y install zip curl jq
        fi
    fi
    
    # Tạo mật khẩu ngẫu nhiên
    local PASS=$(openssl rand -base64 12)
    
    # Nén file với mật khẩu
    zip --password "$PASS" proxy.zip proxy.txt
    
    # Upload lên file.io
    local JSON=$(curl -F "file=@proxy.zip" https://file.io)
    local URL=$(echo "$JSON" | jq --raw-output '.link')
    
    success_message "Proxy đã sẵn sàng! Format IP:PORT:LOGIN:PASS"
    info_message "Tải file zip từ: ${URL}"
    info_message "Mật khẩu: ${PASS}"
}

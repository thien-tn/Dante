#!/usr/bin/env bash

# lib/user_management.sh
#
# Chứa các hàm quản lý người dùng proxy
# Tác giả: akmaslov-dev
# Chỉnh sửa bởi: ThienTranJP

# Đường dẫn đến file proxy chung
PROXY_FILE="/etc/dante/proxy_list.txt"

# Tạo thư mục chứa file proxy nếu chưa tồn tại
ensure_proxy_dir() {
    if [[ ! -d "/etc/dante" ]]; then
        mkdir -p /etc/dante
    fi
    
    # Tạo file proxy nếu chưa tồn tại
    if [[ ! -f "$PROXY_FILE" ]]; then
        touch "$PROXY_FILE"
        chmod 600 "$PROXY_FILE"
    fi
}

# Thêm proxy vào file proxy chung
add_to_proxy_file() {
    local ip=$1
    local port=$2
    local username=$3
    local password=$4
    
    # Đảm bảo thư mục và file tồn tại
    ensure_proxy_dir
    
    # Kiểm tra xem proxy đã tồn tại chưa
    if grep -q "^$ip:$port:$username:" "$PROXY_FILE" 2>/dev/null; then
        # Cập nhật mật khẩu nếu proxy đã tồn tại
        sed -i "s|^$ip:$port:$username:.*|$ip:$port:$username:$password|" "$PROXY_FILE"
    else
        # Thêm proxy mới vào file
        echo "$ip:$port:$username:$password" >> "$PROXY_FILE"
    fi
    
    info_message "Đã thêm/cập nhật proxy $ip:$port:$username:$password vào file quản lý"
}

# Xóa proxy khỏi file proxy chung
remove_from_proxy_file() {
    local username=$1
    
    # Đảm bảo thư mục và file tồn tại
    ensure_proxy_dir
    
    # Kiểm tra xem proxy có tồn tại không
    if grep -q ":$username:" "$PROXY_FILE" 2>/dev/null; then
        # Xóa proxy khỏi file
        sed -i "/:$username:/d" "$PROXY_FILE"
        info_message "Đã xóa proxy với username $username khỏi file quản lý"
    else
        warning_message "Không tìm thấy proxy với username $username trong file quản lý"
    fi
}

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
    
    # Hiển thị danh sách proxy từ file quản lý
    if [[ -f "$PROXY_FILE" ]]; then
        info_message "Danh sách proxy từ file quản lý (IP:Port:Username:Password):"
        cat "$PROXY_FILE"
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
        
        # Lấy cổng từ file cấu hình
        local port=$(get_dante_port)
        
        # Lấy địa chỉ IP máy chủ
        local hostname=$(get_server_ip)
        
        # Thêm proxy vào file quản lý
        add_to_proxy_file "$hostname" "$port" "$usernew" "$passwordnew"
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
        # Tạo user ngẫu nhiên với 8 ký tự (gồm a-z, A-Z, 0-9)
        local user="user_$(generate_random_string 8)"
        
        # Tạo password ngẫu nhiên với 12 ký tự (gồm a-z, A-Z, 0-9)
        local password="pass_$(generate_random_string 12)"
        
        # Thêm user vào hệ thống với mật khẩu đã mã hóa
        useradd -M -s /usr/sbin/nologin -p "$(openssl passwd -1 "$password")" "$user"
        
        # Kiểm tra user đã được tạo thành công
        if user_exists "$user"; then
            # Lưu format IP:Port:User:Pass vào danh sách proxy
            proxy_list+="$hostname:$port:$user:$password\n"
            
            # Thêm proxy vào file quản lý
            add_to_proxy_file "$hostname" "$port" "$user" "$password"
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
            # Xóa user khỏi hệ thống
            userdel "$deluser"
            success_message "Đã xóa user: $deluser"
            
            # Xóa proxy khỏi file quản lý
            remove_from_proxy_file "$deluser"
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
        
        # Xóa proxy khỏi file quản lý
        remove_from_proxy_file "$user"
    done
    
    success_message "Đã xóa toàn bộ proxy user"
    
    # Nếu muốn xóa hoàn toàn file proxy
    read -p "Bạn có muốn xóa hoàn toàn file quản lý proxy? (y/n): " confirm_file
    if [[ "$confirm_file" == "y" || "$confirm_file" == "Y" ]]; then
        > "$PROXY_FILE"
        success_message "Đã xóa nội dung file quản lý proxy"
    fi
    
    pause
}

# Xuất danh sách proxy
export_proxy_list() {
    info_message "Xuất danh sách proxy"
    
    # Kiểm tra file quản lý proxy
    ensure_proxy_dir
    
    if [[ ! -s "$PROXY_FILE" ]]; then
        # Nếu file proxy rỗng, tạo lại từ danh sách user
        info_message "File quản lý proxy rỗng, tạo lại từ danh sách user..."
        
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
        
        # Làm trống file proxy
        > "$PROXY_FILE"
        
        # Lặp qua từng user và thêm vào file proxy
        echo "$users" | while read -r user; do
            # Không thể lấy mật khẩu thực từ hệ thống, sử dụng placeholder
            echo "$hostname:$port:$user:password_placeholder" >> "$PROXY_FILE"
        done
        
        warning_message "Mật khẩu trong file proxy là placeholder, cần cập nhật thủ công"
    fi
    
    # Tạo hoặc làm trống tệp proxy.txt
    > proxy.txt
    
    # Xuất danh sách proxy từ file quản lý
    echo "Danh sách proxy (IP:PORT:LOGIN:PASS):"
    
    # Sao chép nội dung từ file quản lý sang file proxy.txt
    cat "$PROXY_FILE" | tee proxy.txt
    
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

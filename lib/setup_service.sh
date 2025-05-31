#!/usr/bin/env bash

# lib/setup_service.sh
#
# Chứa các hàm thiết lập dịch vụ Dante SOCKS5 proxy
# Tác giả: akmaslov-dev
# Chỉnh sửa bởi: ThienTranJP

# Tạo service systemd cho Dante
create_service() {
    info_message "Đang tạo dịch vụ systemd cho Dante..."
    
    # Tạo file service
    cat > /etc/systemd/system/sockd.service <<-'EOF'
	[Unit]
	Description=Dante Socks Proxy v1.4.3
	After=network.target

	[Service]
	Type=forking
	PIDFile=/var/run/sockd.pid
	ExecStart=/usr/sbin/sockd -D -f /etc/sockd.conf
	ExecReload=/bin/kill -HUP $MAINPID
	KillMode=process
	Restart=on-failure

	[Install]
	WantedBy=multi-user.target
	EOF
    
    # Khởi động lại daemon systemd
    systemctl daemon-reload
    
    # Kích hoạt dịch vụ tự động khởi động
    systemctl enable sockd
    
    # Khởi động dịch vụ
    systemctl start sockd
    
    # Kiểm tra trạng thái dịch vụ
    if systemctl is-active --quiet sockd; then
        success_message "Dịch vụ Dante đã được khởi động thành công"
    else
        error_message "Không thể khởi động dịch vụ Dante"
        systemctl status sockd
        exit 9
    fi
}

# Dừng dịch vụ Dante
stop_service() {
    info_message "Đang dừng dịch vụ Dante..."
    
    if systemctl is-active --quiet sockd; then
        systemctl stop sockd
        success_message "Dịch vụ Dante đã được dừng"
    else
        warning_message "Dịch vụ Dante không đang chạy"
    fi
}

# Khởi động lại dịch vụ Dante
restart_service() {
    info_message "Đang khởi động lại dịch vụ Dante..."
    
    systemctl restart sockd
    
    if systemctl is-active --quiet sockd; then
        success_message "Dịch vụ Dante đã được khởi động lại thành công"
    else
        error_message "Không thể khởi động lại dịch vụ Dante"
        systemctl status sockd
        exit 10
    fi
}

# Kiểm tra trạng thái dịch vụ Dante
check_service_status() {
    info_message "Trạng thái dịch vụ Dante:"
    systemctl status sockd
}

# Gỡ bỏ dịch vụ Dante
remove_service() {
    info_message "Đang gỡ bỏ dịch vụ Dante..."
    
    # Dừng dịch vụ
    stop_service
    
    # Vô hiệu hóa dịch vụ
    systemctl disable sockd
    
    # Xóa file service
    rm -f /etc/systemd/system/sockd.service
    
    # Khởi động lại daemon systemd
    systemctl daemon-reload
    
    success_message "Đã gỡ bỏ dịch vụ Dante"
}

#!/bin/bash

# ============================================================
# Script cấu hình Network Bonding và VLAN bằng nmcli
# ============================================================

# --- Biến cấu hình ---
# !!! Vui lòng thay đổi các giá trị dưới đây cho phù hợp !!!

# Cấu hình Bond
BOND_NAME="bond0"
BOND_MODE="802.3ad" # Các chế độ phổ biến khác: active-backup, balance-rr, etc. Phải phù hợp với cấu hình switch.

# Tên các card mạng vật lý sẽ được gộp (thay enoX và enoY bằng tên thực tế)
# Sử dụng lệnh 'ip link' hoặc 'nmcli device status' để xem tên card mạng
SLAVE1_IFNAME="enoX" # Ví dụ: eno1, eth0, enp3s0
SLAVE2_IFNAME="enoY" # Ví dụ: eno3, eth1, enp4s0

# Cấu hình VLAN
VLAN_ID="X" # Thay X bằng ID VLAN số cụ thể (ví dụ: 100, 205)
VLAN_CON_NAME="VLAN_${VLAN_ID}" # Tên connection cho VLAN (ví dụ: VLAN_100)
VLAN_IFNAME="VLAN_${VLAN_ID}"   # Tên interface cho VLAN (ví dụ: VLAN_100). Lưu ý: Một số hệ thống có thể dùng định dạng bond0.X

# Cấu hình IP cho VLAN
# Thay YY.xx bằng địa chỉ IP và subnet cụ thể
VLAN_IP_ADDRESS="10.64.YY.xx/24" # Ví dụ: 10.64.100.55/24
# Thay YY bằng phần subnet của gateway
VLAN_GATEWAY="10.64.YY.1"        # Ví dụ: 10.64.100.1
# Thay bằng địa chỉ DNS server của mạng bạn
VLAN_DNS_SERVERS="10.64.89.11 10.64.89.13" # Ví dụ: "8.8.8.8 1.1.1.1" (cách nhau bởi dấu cách)

# Hostname
# Thay X bằng định danh duy nhất cho máy này
NEW_HOSTNAME="dri-ehd_X" # Ví dụ: dri-ehd_01

# --- Bắt đầu thực thi Script ---

echo ">>> Đang tạo Bond Interface: ${BOND_NAME}..."
nmcli connection add type bond con-name "${BOND_NAME}" ifname "${BOND_NAME}" bond.options "mode=${BOND_MODE}" ipv4.method disable ipv6.method ignore connection.autoconnect yes
if [ $? -ne 0 ]; then echo "Lỗi khi tạo bond ${BOND_NAME}. Thoát."; exit 1; fi
# Bạn có thể kiểm tra lại bằng lệnh: nmcli connection show "${BOND_NAME}"

echo ">>> Đang thêm card mạng vật lý ${SLAVE1_IFNAME} vào ${BOND_NAME}..."
# Đảm bảo card mạng không bị quản lý bởi connection khác
nmcli device disconnect "${SLAVE1_IFNAME}" > /dev/null 2>&1
nmcli connection add type ethernet slave-type bond con-name "${BOND_NAME}-port1" ifname "${SLAVE1_IFNAME}" master "${BOND_NAME}"
if [ $? -ne 0 ]; then echo "Lỗi khi thêm ${SLAVE1_IFNAME} vào ${BOND_NAME}. Thoát."; exit 1; fi

echo ">>> Đang thêm card mạng vật lý ${SLAVE2_IFNAME} vào ${BOND_NAME}..."
# Đảm bảo card mạng không bị quản lý bởi connection khác
nmcli device disconnect "${SLAVE2_IFNAME}" > /dev/null 2>&1
# Lưu ý: Tên connection là bond0-port3 trong yêu cầu gốc, nếu bạn muốn dùng port2 thì sửa lại tên connection ở đây
nmcli connection add type ethernet slave-type bond con-name "${BOND_NAME}-port3" ifname "${SLAVE2_IFNAME}" master "${BOND_NAME}"
if [ $? -ne 0 ]; then echo "Lỗi khi thêm ${SLAVE2_IFNAME} vào ${BOND_NAME}. Thoát."; exit 1; fi

echo ">>> Đang tạo VLAN Interface: ${VLAN_CON_NAME} (ID: ${VLAN_ID}) trên ${BOND_NAME}..."
nmcli connection add type vlan con-name "${VLAN_CON_NAME}" ifname "${VLAN_IFNAME}" vlan.parent "${BOND_NAME}" vlan.id "${VLAN_ID}"
if [ $? -ne 0 ]; then echo "Lỗi khi tạo VLAN ${VLAN_CON_NAME}. Thoát."; exit 1; fi

echo ">>> Đang cấu hình địa chỉ IP cho VLAN ${VLAN_CON_NAME}..."
nmcli connection modify "${VLAN_CON_NAME}" \
    ipv4.addresses "${VLAN_IP_ADDRESS}" \
    ipv4.gateway "${VLAN_GATEWAY}" \
    ipv4.dns "${VLAN_DNS_SERVERS}" \
    ipv4.method manual \
    ipv6.method ignore \
    connection.autoconnect yes
if [ $? -ne 0 ]; then echo "Lỗi khi cấu hình IP cho VLAN ${VLAN_CON_NAME}. Thoát."; exit 1; fi

echo ">>> Đang tải lại cấu hình NetworkManager..."
nmcli connection reload
if [ $? -ne 0 ]; then echo "Lỗi khi tải lại cấu hình NetworkManager. Thoát."; exit 1; fi

echo ">>> Đang kích hoạt các kết nối (Bond và VLAN)..."
# Có thể cần chờ một chút để thiết bị sẵn sàng sau khi reload
sleep 5
nmcli connection up "${BOND_NAME}" || echo "Cảnh báo: Không thể bật ${BOND_NAME} (có thể đã được bật)."
nmcli connection up "${VLAN_CON_NAME}" || echo "Cảnh báo: Không thể bật ${VLAN_CON_NAME} (có thể đã được bật)."

echo ">>> Đang đặt Hostname thành: ${NEW_HOSTNAME}..."
hostnamectl set-hostname "${NEW_HOSTNAME}"
if [ $? -ne 0 ]; then echo "Lỗi khi đặt hostname. Thoát."; exit 1; fi

echo "============================================================"
echo ">>> Cấu hình hoàn tất! <<<"
echo "Hostname hiện tại: $(hostname)"
echo "Kiểm tra trạng thái kết nối:"
nmcli connection show --active
echo "Kiểm tra địa chỉ IP của VLAN ${VLAN_IFNAME}:"
ip addr show "${VLAN_IFNAME}"
echo "============================================================"

exit 0
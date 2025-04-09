#!/bin/bash

# ====================================================================
# Script cấu hình Network Bonding, VLAN và Hostname bằng nmcli
# Phiên bản: Interactive
# ====================================================================

# --- Giá trị cấu hình cố định ---
BOND_NAME="bond0"
BOND_MODE="802.3ad" # Đảm bảo chế độ này phù hợp với cấu hình switch

# --- Giá trị mặc định (Người dùng có thể thay đổi) ---
DEFAULT_SLAVE1="eno12399np0"
DEFAULT_SLAVE2="eno12419np2"
DEFAULT_DNS="10.64.89.11 10.64.89.13" # DNS Server gợi ý

# --- Lấy thông tin hệ thống ---
CURRENT_HOSTNAME=$(hostname) # Lấy hostname hiện tại

# --- Bắt đầu tương tác với người dùng ---
echo "============================================================"
echo "Script Cấu Hình Mạng & Hostname (Interactive)"
echo "============================================================"
echo "Nhập các giá trị cấu hình yêu cầu."
echo "Nhấn Enter để chấp nhận giá trị mặc định trong dấu ngoặc []."
echo ""

# 1. Nhập Hostname (Mặc định là hostname hiện tại)
read -p "Nhập Hostname mới [${CURRENT_HOSTNAME}]: " -e -i "${CURRENT_HOSTNAME}" NEW_HOSTNAME
# Nếu người dùng chỉ nhấn Enter, NEW_HOSTNAME sẽ giữ giá trị CURRENT_HOSTNAME

# 2. Nhập tên card mạng vật lý (có giá trị mặc định)
read -p "Nhập tên card mạng vật lý thứ nhất [${DEFAULT_SLAVE1}]: " -e -i "${DEFAULT_SLAVE1}" SLAVE1_IFNAME
read -p "Nhập tên card mạng vật lý thứ hai [${DEFAULT_SLAVE2}]: " -e -i "${DEFAULT_SLAVE2}" SLAVE2_IFNAME

# 3. Nhập VLAN ID (Bắt buộc, phải là số)
while true; do
    read -p "Nhập VLAN ID (ví dụ: 100, 205): " VLAN_ID
    # Kiểm tra xem có phải là số nguyên dương không
    if [[ "$VLAN_ID" =~ ^[1-9][0-9]*$ ]] && [ "$VLAN_ID" -ge 1 ] && [ "$VLAN_ID" -le 4094 ]; then
        break # Thoát vòng lặp nếu hợp lệ
    else
        echo "Lỗi: VLAN ID phải là một số nguyên dương từ 1 đến 4094."
    fi
done

# 4. Nhập cấu hình IP cho VLAN (Bắt buộc)
read -p "Nhập địa chỉ IP và Prefix cho VLAN (ví dụ: 10.64.100.55/24): " VLAN_IP_ADDRESS
while [[ -z "$VLAN_IP_ADDRESS" ]]; do
    echo "Lỗi: Địa chỉ IP không được để trống."
    read -p "Nhập địa chỉ IP và Prefix cho VLAN (ví dụ: 10.64.100.55/24): " VLAN_IP_ADDRESS
done

read -p "Nhập địa chỉ Gateway cho VLAN (ví dụ: 10.64.100.1): " VLAN_GATEWAY
while [[ -z "$VLAN_GATEWAY" ]]; do
    echo "Lỗi: Gateway không được để trống."
    read -p "Nhập địa chỉ Gateway cho VLAN (ví dụ: 10.64.100.1): " VLAN_GATEWAY
done

read -p "Nhập địa chỉ DNS Server (cách nhau bởi dấu cách) [${DEFAULT_DNS}]: " -e -i "${DEFAULT_DNS}" VLAN_DNS_SERVERS
# Nếu người dùng nhấn Enter, VLAN_DNS_SERVERS sẽ giữ giá trị DEFAULT_DNS

# --- Tạo tên động cho VLAN ---
VLAN_CON_NAME="VLAN_${VLAN_ID}"
VLAN_IFNAME="VLAN_${VLAN_ID}" # Hoặc có thể dùng bond0.${VLAN_ID} tùy hệ thống/sở thích

# --- Bắt đầu thực thi cấu hình ---

# 1. Cấu hình Hostname
echo ""
echo ">>> Đang cấu hình Hostname thành: ${NEW_HOSTNAME}..."
hostnamectl set-hostname "${NEW_HOSTNAME}"
if [ $? -ne 0 ]; then
    echo "Lỗi khi cấu hình hostname. Vui lòng kiểm tra quyền (cần chạy bằng root/sudo)."
    # Quyết định có nên thoát hay không tùy thuộc vào mức độ quan trọng
    # exit 1
else
    echo "Hostname đã được cập nhật thành công (có thể cần đăng nhập lại để thấy thay đổi ở mọi nơi)."
fi


# 2. Tạo Bond Interface
echo ">>> Đang tạo Bond Interface: ${BOND_NAME}..."
nmcli connection add type bond con-name "${BOND_NAME}" ifname "${BOND_NAME}" bond.options "mode=${BOND_MODE}" ipv4.method disabled ipv6.method ignore connection.autoconnect yes
if [ $? -ne 0 ]; then echo "Lỗi khi tạo bond ${BOND_NAME}. Thoát."; exit 1; fi

# 3. Thêm card mạng vật lý vào Bond
echo ">>> Đang thêm card mạng vật lý ${SLAVE1_IFNAME} vào ${BOND_NAME}..."
nmcli device disconnect "${SLAVE1_IFNAME}" > /dev/null 2>&1 # Ngắt kết nối cũ nếu có
nmcli connection add type ethernet slave-type bond con-name "${BOND_NAME}-port1" ifname "${SLAVE1_IFNAME}" master "${BOND_NAME}" connection.autoconnect yes
if [ $? -ne 0 ]; then echo "Lỗi khi thêm ${SLAVE1_IFNAME} vào ${BOND_NAME}. Thoát."; exit 1; fi

echo ">>> Đang thêm card mạng vật lý ${SLAVE2_IFNAME} vào ${BOND_NAME}..."
nmcli device disconnect "${SLAVE2_IFNAME}" > /dev/null 2>&1 # Ngắt kết nối cũ nếu có
# Đảm bảo tên connection là duy nhất, ví dụ: port2 hoặc port3 tùy ý
nmcli connection add type ethernet slave-type bond con-name "${BOND_NAME}-port2" ifname "${SLAVE2_IFNAME}" master "${BOND_NAME}" connection.autoconnect yes
if [ $? -ne 0 ]; then echo "Lỗi khi thêm ${SLAVE2_IFNAME} vào ${BOND_NAME}. Thoát."; exit 1; fi

# 4. Tạo VLAN Interface trên Bond
echo ">>> Đang tạo VLAN Interface: ${VLAN_CON_NAME} (ID: ${VLAN_ID}) trên ${BOND_NAME}..."
nmcli connection add type vlan con-name "${VLAN_CON_NAME}" ifname "${VLAN_IFNAME}" vlan.parent "${BOND_NAME}" vlan.id "${VLAN_ID}" connection.autoconnect yes
if [ $? -ne 0 ]; then echo "Lỗi khi tạo VLAN ${VLAN_CON_NAME}. Thoát."; exit 1; fi

# 5. Cấu hình IP cho VLAN
echo ">>> Đang cấu hình địa chỉ IP cho VLAN ${VLAN_CON_NAME}..."
nmcli connection modify "${VLAN_CON_NAME}" \
    ipv4.addresses "${VLAN_IP_ADDRESS}" \
    ipv4.gateway "${VLAN_GATEWAY}" \
    ipv4.dns "${VLAN_DNS_SERVERS}" \
    ipv4.method manual \
    ipv6.method ignore \
    connection.autoconnect yes
if [ $? -ne 0 ]; then echo "Lỗi khi cấu hình IP cho VLAN ${VLAN_CON_NAME}. Thoát."; exit 1; fi

# 6. Tải lại cấu hình và kích hoạt
echo ">>> Đang tải lại cấu hình NetworkManager..."
nmcli connection reload
if [ $? -ne 0 ]; then echo "Lỗi khi tải lại cấu hình NetworkManager."; fi # Không cần thoát nếu chỉ reload lỗi nhẹ

echo ">>> Đang kích hoạt các kết nối (Bond và VLAN)..."
# Chờ một chút để các thiết bị sẵn sàng
sleep 5

# Kích hoạt Bond trước, sau đó đến VLAN
nmcli connection up "${BOND_NAME}" || echo "Cảnh báo: Không thể bật ${BOND_NAME} (có thể đã được bật hoặc có lỗi khác)."
sleep 2 # Thêm độ trễ nhỏ giữa việc bật bond và vlan
nmcli connection up "${VLAN_CON_NAME}" || echo "Cảnh báo: Không thể bật ${VLAN_CON_NAME} (có thể đã được bật hoặc có lỗi khác)."

# --- Hiển thị kết quả ---
echo "============================================================"
echo ">>> Cấu hình mạng và hostname hoàn tất! <<<"
echo "Hostname hiện tại: $(hostname)"
echo "------------------------------------------------------------"
echo "Kiểm tra trạng thái kết nối:"
nmcli connection show --active
echo "------------------------------------------------------------"
echo "Kiểm tra địa chỉ IP của VLAN ${VLAN_IFNAME}:"
ip addr show "${VLAN_IFNAME}"
echo "------------------------------------------------------------"
echo ">>> Đang kiểm tra kết nối đến Gateway (${VLAN_GATEWAY})..."
ping -c 4 -W 1 "${VLAN_GATEWAY}"
if [ $? -eq 0 ]; then
    echo ">>> Ping đến Gateway thành công!"
else
    echo ">>> !!! Cảnh báo: Không thể ping đến Gateway ${VLAN_GATEWAY}. Kiểm tra lại cấu hình IP/Gateway/VLAN hoặc kết nối vật lý."
fi
echo "============================================================"

exit 0
#!/bin/bash

# ====================================================================
# Script cau hinh Network Bonding, VLAN va Hostname bang nmcli
# Phien ban: Interactive (Tieng Viet khong dau)
# ====================================================================

# --- Gia tri cau hinh co dinh ---
BOND_NAME="bond0"
BOND_MODE="802.3ad" # Dam bao che do nay phu hop voi cau hinh switch

# --- Gia tri mac dinh (Nguoi dung co the thay doi) ---
DEFAULT_SLAVE1="eno12399np0"
DEFAULT_SLAVE2="eno12419np2"
DEFAULT_DNS="10.64.89.11 10.64.89.13" # DNS Server goi y

# --- Lay thong tin he thong ---
CURRENT_HOSTNAME=$(hostname) # Lay hostname hien tai

# --- Bat dau tuong tac voi nguoi dung ---
echo "============================================================"
echo "   Script Cau Hinh Mang & Hostname (Interactive)"
echo "============================================================"
echo "Nhap cac gia tri cau hinh yeu cau."
echo "Nhan Enter de chap nhan gia tri mac dinh trong dau ngoac []."
echo ""

# 1. Nhap Hostname (Mac dinh la hostname hien tai)
read -p "Nhap Hostname moi [${CURRENT_HOSTNAME}]: " -e -i "${CURRENT_HOSTNAME}" NEW_HOSTNAME

# 2. Nhap ten card mang vat ly (co gia tri mac dinh)
read -p "Nhap ten card mang vat ly thu nhat [${DEFAULT_SLAVE1}]: " -e -i "${DEFAULT_SLAVE1}" SLAVE1_IFNAME
read -p "Nhap ten card mang vat ly thu hai [${DEFAULT_SLAVE2}]: " -e -i "${DEFAULT_SLAVE2}" SLAVE2_IFNAME

# 3. Nhap VLAN ID (Bat buoc, phai la so)
# Cap nhat chi dan VLAN
while true; do
    read -p "Nhap VLAN ID (232: Trans, 233: Search, 234: Ana, 235: Docs): " VLAN_ID
    # Kiem tra xem co phai la so nguyen duong khong
    if [[ "$VLAN_ID" =~ ^[1-9][0-9]*$ ]] && [ "$VLAN_ID" -ge 1 ] && [ "$VLAN_ID" -le 4094 ]; then
        break # Thoat vong lap neu hop le
    else
        echo "Loi: VLAN ID phai la mot so nguyen duong tu 1 den 4094."
    fi
done

# 4. Nhap cau hinh IP cho VLAN (Bat buoc)
read -p "Nhap dia chi IP va Prefix cho VLAN (Vi du: 10.64.100.55/24): " VLAN_IP_ADDRESS
while [[ -z "$VLAN_IP_ADDRESS" ]]; do
    echo "Loi: Dia chi IP khong duoc de trong."
    read -p "Nhap dia chi IP va Prefix cho VLAN (Vi du: 10.64.100.55/24): " VLAN_IP_ADDRESS
done

read -p "Nhap dia chi Gateway cho VLAN (Vi du: 10.64.100.1): " VLAN_GATEWAY
while [[ -z "$VLAN_GATEWAY" ]]; do
    echo "Loi: Gateway khong duoc de trong."
    read -p "Nhap dia chi Gateway cho VLAN (Vi du: 10.64.100.1): " VLAN_GATEWAY
done

read -p "Nhap dia chi DNS Server (cach nhau boi dau cach) [${DEFAULT_DNS}]: " -e -i "${DEFAULT_DNS}" VLAN_DNS_SERVERS

# --- Tao ten dong cho VLAN ---
VLAN_CON_NAME="VLAN_${VLAN_ID}"
VLAN_IFNAME="VLAN_${VLAN_ID}" # Hoac co the dung bond0.${VLAN_ID} tuy he thong/so thich

# --- Hien thi Tom Tat Thong Tin Da Nhap ---
echo ""
echo "============================================================"
echo ">>> Tom Tat Thong Tin Cau Hinh Da Nhap <<<"
echo "============================================================"
echo "Hostname              : ${NEW_HOSTNAME}"
echo "Card Mang 1 (Slave 1) : ${SLAVE1_IFNAME}"
echo "Card Mang 2 (Slave 2) : ${SLAVE2_IFNAME}"
echo "VLAN ID               : ${VLAN_ID}"
echo "   => Ten Ket Noi VLAN : ${VLAN_CON_NAME}"
echo "   => Ten Interface VLAN: ${VLAN_IFNAME}"
echo "IP/Prefix VLAN        : ${VLAN_IP_ADDRESS}"
echo "Gateway VLAN          : ${VLAN_GATEWAY}"
echo "DNS Servers           : ${VLAN_DNS_SERVERS}"
echo "Bond Interface        : ${BOND_NAME} (Mode: ${BOND_MODE})"
echo "============================================================"
# Tam dung de nguoi dung xem lai (tuy chon)
# read -p "Nhan Enter de tiep tuc hoac Ctrl+C de huy..."
echo ""

# --- Bat dau thuc thi cau hinh ---

# 1. Cau hinh Hostname
echo ">>> Dang cau hinh Hostname thanh: ${NEW_HOSTNAME}..."
hostnamectl set-hostname "${NEW_HOSTNAME}"
if [ $? -ne 0 ]; then
    echo "Loi khi cau hinh hostname. Vui long kiem tra quyen (can chay bang root/sudo)."
else
    echo "Hostname da duoc cap nhat thanh cong (co the can dang nhap lai de thay thay doi o moi noi)."
fi

# 2. Tao Bond Interface
echo ">>> Dang tao Bond Interface: ${BOND_NAME}..."
nmcli connection add type bond con-name "${BOND_NAME}" ifname "${BOND_NAME}" bond.options "mode=${BOND_MODE}" ipv4.method disabled ipv6.method ignore connection.autoconnect yes
if [ $? -ne 0 ]; then echo "Loi khi tao bond ${BOND_NAME}. Thoat."; exit 1; fi

# 3. Them card mang vat ly vao Bond
echo ">>> Dang them card mang vat ly ${SLAVE1_IFNAME} vao ${BOND_NAME}..."
nmcli device disconnect "${SLAVE1_IFNAME}" > /dev/null 2>&1 # Ngat ket noi cu neu co
nmcli connection add type ethernet slave-type bond con-name "${BOND_NAME}-port1" ifname "${SLAVE1_IFNAME}" master "${BOND_NAME}" connection.autoconnect yes
if [ $? -ne 0 ]; then echo "Loi khi them ${SLAVE1_IFNAME} vao ${BOND_NAME}. Thoat."; exit 1; fi

echo ">>> Dang them card mang vat ly ${SLAVE2_IFNAME} vao ${BOND_NAME}..."
nmcli device disconnect "${SLAVE2_IFNAME}" > /dev/null 2>&1 # Ngat ket noi cu neu co
nmcli connection add type ethernet slave-type bond con-name "${BOND_NAME}-port2" ifname "${SLAVE2_IFNAME}" master "${BOND_NAME}" connection.autoconnect yes
if [ $? -ne 0 ]; then echo "Loi khi them ${SLAVE2_IFNAME} vao ${BOND_NAME}. Thoat."; exit 1; fi

# 4. Tao VLAN Interface tren Bond
echo ">>> Dang tao VLAN Interface: ${VLAN_CON_NAME} (ID: ${VLAN_ID}) tren ${BOND_NAME}..."
# Kiem tra xem connection VLAN da ton tai chua, neu co thi xoa di truoc khi tao moi
EXISTING_VLAN=$(nmcli -g NAME connection show | grep "^${VLAN_CON_NAME}$")
if [ -n "$EXISTING_VLAN" ]; then
    echo "Canh bao: Ket noi VLAN ${VLAN_CON_NAME} da ton tai. Dang xoa de tao moi..."
    nmcli connection delete "${VLAN_CON_NAME}" || echo "Loi khi xoa ket noi VLAN cu."
    sleep 1
fi
nmcli connection add type vlan con-name "${VLAN_CON_NAME}" ifname "${VLAN_IFNAME}" vlan.parent "${BOND_NAME}" vlan.id "${VLAN_ID}" connection.autoconnect yes
if [ $? -ne 0 ]; then echo "Loi khi tao VLAN ${VLAN_CON_NAME}. Thoat."; exit 1; fi

# 5. Cau hinh IP cho VLAN
echo ">>> Dang cau hinh dia chi IP cho VLAN ${VLAN_CON_NAME}..."
nmcli connection modify "${VLAN_CON_NAME}" \
    ipv4.addresses "${VLAN_IP_ADDRESS}" \
    ipv4.gateway "${VLAN_GATEWAY}" \
    ipv4.dns "${VLAN_DNS_SERVERS}" \
    ipv4.method manual \
    ipv6.method ignore \
    connection.autoconnect yes
if [ $? -ne 0 ]; then echo "Loi khi cau hinh IP cho VLAN ${VLAN_CON_NAME}. Thoat."; exit 1; fi

# 6. Tai lai cau hinh va kich hoat
echo ">>> Dang tai lai cau hinh NetworkManager..."
nmcli connection reload
if [ $? -ne 0 ]; then echo "Loi khi tai lai cau hinh NetworkManager."; fi

echo ">>> Dang kich hoat cac ket noi (Bond va VLAN)..."
sleep 5

# Kich hoat Bond truoc, sau do den VLAN
nmcli connection up "${BOND_NAME}" || echo "Canh bao: Khong the bat ${BOND_NAME} (co the da duoc bat hoac co loi khac)."
sleep 2
nmcli connection up "${VLAN_CON_NAME}" || echo "Canh bao: Khong the bat ${VLAN_CON_NAME} (co the da duoc bat hoac co loi khac)."

# --- Hien thi ket qua ---
echo "============================================================"
echo ">>> Cau hinh mang va hostname hoan tat! <<<"
echo "Hostname hien tai: $(hostname)"
echo "------------------------------------------------------------"
echo "Kiem tra trang thai ket noi:"
nmcli connection show --active
echo "------------------------------------------------------------"
echo "Kiem tra dia chi IP cua VLAN ${VLAN_IFNAME}:"
ip addr show "${VLAN_IFNAME}"
echo "============================================================"

exit 0
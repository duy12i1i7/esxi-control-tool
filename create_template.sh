#!/bin/bash
# Script tạo máy ảo Template gốc trên ESXi

echo "=========================================="
echo "    ESXi Control Tool - Create Template   "
echo "=========================================="

read -p "ESXi IP/Domain (VD: 192.168.100.3): " ESXI_IP
read -p "ESXi Username [root]: " ESXI_USER
ESXI_USER=${ESXI_USER:-root}
read -s -p "ESXi Password: " ESXI_PASS
echo ""

# URL encode password for govc
ESXI_PASS_ENCODED=$(python3 -c "import urllib.parse, sys; print(urllib.parse.quote(sys.argv[1]))" "$ESXI_PASS")
export GOVC_URL="https://${ESXI_USER}:${ESXI_PASS_ENCODED}@${ESXI_IP}/sdk"
export GOVC_INSECURE=1

# Kiểm tra kết nối
echo "[*] Đang kết nối tới ESXi..."
if ! ./govc about > /dev/null 2>&1; then
    if ! govc about > /dev/null 2>&1; then
        echo "[!] Lỗi: Không kết nối được tới ESXi hoặc chưa cài đặt govc!"
        exit 1
    else
        GOVC_CMD="govc"
    fi
else
    GOVC_CMD="./govc"
fi

echo "[*] Kết nối thành công!"

read -p "Tên Datastore [datastore1]: " DS_NAME
DS_NAME=${DS_NAME:-datastore1}

read -p "Tên Network Port Group [VM Network 3]: " NET_NAME
NET_NAME=${NET_NAME:-VM Network 3}

read -p "Đường dẫn file ISO trong datastore (VD: image/ubuntu-24.04.4-live-server-amd64.iso): " ISO_PATH

read -p "Tên Template muốn tạo [Ubuntu-Template]: " VM_NAME
VM_NAME=${VM_NAME:-Ubuntu-Template}

echo "------------------------------------------"
echo "[*] Đang khởi tạo máy ảo: $VM_NAME"
$GOVC_CMD vm.create -g ubuntu64Guest -m 2048 -c 2 -net "$NET_NAME" -ds "$DS_NAME" "$VM_NAME"

echo "[*] Đang thêm ổ cứng 20GB..."
$GOVC_CMD vm.power -off -force=true "$VM_NAME" > /dev/null 2>&1
$GOVC_CMD vm.disk.create -vm "$VM_NAME" -name "$VM_NAME/disk1" -size 20G

echo "[*] Đang cắm đĩa CD chứa ISO..."
$GOVC_CMD device.cdrom.add -vm "$VM_NAME"
$GOVC_CMD device.cdrom.insert -vm "$VM_NAME" "$ISO_PATH"

echo "[*] Bật nguồn máy ảo..."
$GOVC_CMD vm.power -on "$VM_NAME"

echo "=========================================="
echo " HOÀN TẤT! Máy ảo $VM_NAME đã bật nguồn.  "
echo " Tiếp theo:"
echo " 1. Mở giao diện ESXi, vào Console máy ảo này."
echo " 2. Cài đặt hệ điều hành Ubuntu."
echo " 3. Cài đặt xong, tắt nguồn (Shut down) máy ảo."
echo " 4. Chuyển sang chạy script 'deploy_vm.sh' để nhân bản máy."
echo "=========================================="

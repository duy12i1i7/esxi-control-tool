#!/bin/bash

export GOVC_INSECURE=1
export GOVC_URL="https://${ESXI_USER}:${ESXI_PASS}@${ESXI_IP}/sdk"

# Determine path to govc
if ! ./govc about > /dev/null 2>&1; then
    if ! govc about > /dev/null 2>&1; then
        echo "[!] Error: govc command not found. Please install govc."
        exit 1
    else
        GOVC_CMD="govc"
    fi
else
    GOVC_CMD="./govc"
fi

read -p "Nhập IP của ESXi (VD: 192.168.100.3): " ESXI_IP
read -p "Nhập Username ESXi: " ESXI_USER
read -sp "Nhập Password ESXi: " ESXI_PASS
echo ""
read -p "Nhập Tên máy ảo gốc (Template): " TPL_NAME
read -p "Nhập Tên máy ảo mới cần tạo: " VM_NAME
read -p "Số Core CPU (VD: 2): " VM_CPU
read -p "Dung lượng RAM (MB, VD: 2048): " VM_RAM
read -p "Dung lượng ổ cứng (GB, VD: 20): " VM_DISK
read -p "Network Port Group (VD: VM Network): " VM_NET
read -p "Username OS (VD: ubuntu): " OS_USER
read -sp "Password OS (VD: Avis@11235813): " OS_PASS
echo ""

export GOVC_INSECURE=1
export GOVC_URL="https://${ESXI_USER}:${ESXI_PASS}@${ESXI_IP}/sdk"

echo ""
echo "=========================================="
echo "    ESXi Control Tool - Deploy New VM     "
echo "=========================================="
echo ""
echo "------------------------------------------"
echo "--- Cấu hình Hệ điều hành (Cloud-init) ---"
echo ""

echo "[*] Đang mã hóa mật khẩu..."
if command -v python3 &>/dev/null; then
    PASS_HASH=$(python3 -c "import crypt; print(crypt.crypt('${OS_PASS}', crypt.mksalt(crypt.METHOD_SHA512)))")
else
    PASS_HASH=$(perl -e 'print crypt($ARGV[0], "\$6\$" . join("", map { (0..9,"a".."z","A".."Z")[rand 62] } 1..8))' "${OS_PASS}")
fi

echo "[*] Đang khởi tạo file cấu hình Cloud-init..."
cat << META > metadata.yaml
instance-id: ${VM_NAME}
local-hostname: ${VM_NAME}
META

cat << USER > userdata.yaml
#cloud-config
users:
  - default
  - name: ${OS_USER}
    sudo: ALL=(ALL) NOPASSWD:ALL
    lock_passwd: false
    passwd: ${PASS_HASH}
    shell: /bin/bash
ssh_pwauth: true
chpasswd:
  list: |
    ${OS_USER}:${OS_PASS}
  expire: false
USER

CLOUD_CONFIG=$(gzip -c userdata.yaml | base64 | tr -d '\n')
CLOUD_META=$(gzip -c metadata.yaml | base64 | tr -d '\n')

echo "------------------------------------------"
echo "[*] 1. Đang sao chép Virtual Disk từ $TPL_NAME..."
$GOVC_CMD datastore.mkdir "$VM_NAME"
$GOVC_CMD datastore.cp "$TPL_NAME/disk1.vmdk" "$VM_NAME/disk1.vmdk"

echo "[*] 2. Đang tạo máy ảo $VM_NAME mới..."
$GOVC_CMD vm.create -g ubuntu64Guest -c "$VM_CPU" -m "$VM_RAM" -net "$VM_NET" -disk "$VM_NAME/disk1.vmdk" "$VM_NAME"

echo "[*] 3. Đang mở rộng ổ cứng lên ${VM_DISK}GB..."
$GOVC_CMD vm.disk.change -vm "$VM_NAME" -size "${VM_DISK}G"

echo "[*] 4. Đang nhúng cấu hình Cloud-init vào ESXi GuestInfo..."
$GOVC_CMD vm.change -vm "$VM_NAME" \
  -e guestinfo.metadata="$CLOUD_META" \
  -e guestinfo.metadata.encoding="gzip+base64" \
  -e guestinfo.userdata="$CLOUD_CONFIG" \
  -e guestinfo.userdata.encoding="gzip+base64"

echo "[*] 5. Đang bật nguồn máy ảo..."
$GOVC_CMD vm.power -on "$VM_NAME"

echo "------------------------------------------"
echo " Dọn dẹp file rác..."
rm -f metadata.yaml userdata.yaml

echo "=========================================="
echo " HOÀN TẤT! Máy ảo $VM_NAME đã được khởi động."
echo " Máy sẽ nhận IP động (DHCP). Vui lòng kiểm tra Router"
echo " để lấy IP và SSH vào bằng tài khoản: $OS_USER"
echo "=========================================="

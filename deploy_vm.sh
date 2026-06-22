#!/bin/bash
# Script tự động Clone và Cấu hình máy ảo (Cloud-init)

echo "=========================================="
echo "    ESXi Control Tool - Deploy New VM     "
echo "=========================================="

read -p "ESXi IP/Domain (VD: 192.168.100.3): " ESXI_IP
read -p "ESXi Username [root]: " ESXI_USER
ESXI_USER=${ESXI_USER:-root}
read -s -p "ESXi Password: " ESXI_PASS
echo ""

ESXI_PASS_ENCODED=$(python3 -c "import urllib.parse, sys; print(urllib.parse.quote(sys.argv[1]))" "$ESXI_PASS")
export GOVC_URL="https://${ESXI_USER}:${ESXI_PASS_ENCODED}@${ESXI_IP}/sdk"
export GOVC_INSECURE=1

if ! ./govc about > /dev/null 2>&1; then
    if ! govc about > /dev/null 2>&1; then
        echo "[!] Lỗi kết nối ESXi."
        exit 1
    else
        GOVC_CMD="govc"
    fi
else
    GOVC_CMD="./govc"
fi

echo "------------------------------------------"
read -p "Tên máy ảo gốc (Template) [Ubuntu-Template]: " TPL_NAME
TPL_NAME=${TPL_NAME:-Ubuntu-Template}

read -p "Tên máy ảo mới muốn tạo (VD: Moodle-Web): " VM_NAME
read -p "Số Core CPU [2]: " VM_CPU
VM_CPU=${VM_CPU:-2}
read -p "Dung lượng RAM (MB) [2048]: " VM_RAM
VM_RAM=${VM_RAM:-2048}
read -p "Dung lượng Ổ cứng (GB) [20]: " VM_DISK
VM_DISK=${VM_DISK:-20}
read -p "Network Port Group [VM Network 3]: " VM_NET
VM_NET=${VM_NET:-VM Network 3}

echo "--- Cấu hình Hệ điều hành (Cloud-init) ---"
read -p "Tạo Username (VD: admin): " OS_USER
read -s -p "Tạo Password cho user $OS_USER: " OS_PASS
echo ""

# Sinh mã Hash SHA-512 cho Password
echo "[*] Đang mã hóa mật khẩu..."
PASS_HASH=$(python3 -c "
import crypt, string, random
salt = ''.join(random.choices(string.ascii_letters + string.digits, k=16))
print(crypt.crypt('$OS_PASS', '\$6\$' + salt))
")

echo "[*] Đang khởi tạo file cấu hình Cloud-init..."
cat <<EOF > metadata.yaml
instance-id: ${VM_NAME,,}
local-hostname: ${VM_NAME}
EOF

cat <<EOF > userdata.yaml
#cloud-config
ssh_pwauth: true
users:
  - name: $OS_USER
    groups: sudo
    shell: /bin/bash
    sudo: ['ALL=(ALL) NOPASSWD:ALL']
    lock_passwd: false
    passwd: "$PASS_HASH"
runcmd:
  - echo "Deployed via ESXi Control Tool" > /var/log/esxi-deploy.log
EOF

gzip -c9 metadata.yaml | base64 > metadata.b64
gzip -c9 userdata.yaml | base64 > userdata.b64

echo "------------------------------------------"
echo "[*] 1. Đang nhân bản máy ảo từ $TPL_NAME..."
$GOVC_CMD vm.clone -vm "$TPL_NAME" -name "$VM_NAME" -c "$VM_CPU" -m "$VM_RAM" -net "$VM_NET"

echo "[*] 2. Đang mở rộng ổ cứng lên ${VM_DISK}GB..."
$GOVC_CMD vm.disk.change -vm "$VM_NAME" -disk "$VM_NAME/disk1" -size "${VM_DISK}G"

echo "[*] 3. Đang nhúng cấu hình Cloud-init vào ESXi GuestInfo..."
$GOVC_CMD vm.change -vm "$VM_NAME" \
  -e guestinfo.metadata="$(cat metadata.b64)" \
  -e guestinfo.metadata.encoding="gzip+base64" \
  -e guestinfo.userdata="$(cat userdata.b64)" \
  -e guestinfo.userdata.encoding="gzip+base64"

echo "[*] 4. Đang bật nguồn máy ảo..."
$GOVC_CMD vm.power -on "$VM_NAME"

echo "------------------------------------------"
echo " Dọn dẹp file rác..."
rm -f metadata.yaml userdata.yaml metadata.b64 userdata.b64

echo "=========================================="
echo " HOÀN TẤT! Máy ảo $VM_NAME đã được khởi động."
echo " Máy sẽ nhận IP động (DHCP). Vui lòng kiểm tra Router"
echo " để lấy IP và SSH vào bằng tài khoản: $OS_USER"
echo "=========================================="

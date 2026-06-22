# ESXi Control Tool

Công cụ dòng lệnh giúp tự động hóa hoàn toàn quy trình tạo và nhân bản máy ảo trên nền tảng VMware ESXi (Standalone - không cần vCenter) sử dụng `govc` và `cloud-init`.

## Điều kiện tiên quyết
Máy tính chạy công cụ này (MacOS/Linux) cần được cài đặt sẵn:
- **`govc`**: Công cụ CLI của VMware.
- **`python3`**: Dùng để mã hóa mật khẩu theo chuẩn SHA-512.

## Quy trình sử dụng (2 Bước)

### Bước 1: Tạo Bản Mẫu Gốc (Golden Template)
Chạy kịch bản sau để tự động tạo ra một máy ảo trống với file đĩa cài đặt (ISO) được cắm sẵn:

```bash
chmod +x create_template.sh
./create_template.sh
```

**Thao tác thủ công:**
1. Mở giao diện Web của ESXi, truy cập vào Console của máy ảo vừa tạo.
2. Cài đặt hệ điều hành Ubuntu Server.
3. Khi quá trình cài đặt hoàn tất, **Tắt nguồn (Shut down)** máy ảo. Máy này chính thức trở thành bản mẫu (Template). Đừng bao giờ bật lại nó.

### Bước 2: Nhân bản và Cấu hình tự động (Cloud-init)
Mỗi khi bạn cần tạo một máy chủ mới, chỉ cần chạy kịch bản sau:

```bash
chmod +x deploy_vm.sh
./deploy_vm.sh
```

**Kịch bản sẽ hỏi bạn:**
- Tên máy ảo mới.
- Cấu hình phần cứng muốn ép (CPU, RAM, Storage).
- Tên tài khoản và Mật khẩu bạn muốn đặt cho máy tính đó.

Ngay lập tức, kịch bản sẽ:
1. Nhân bản từ con máy Template.
2. Ép thông số CPU, RAM, tự động mở rộng ổ cứng.
3. Tiêm kịch bản `cloud-init` để tự động đổi tên Hostname và thiết lập Tài khoản đăng nhập.
4. Bật máy ảo lên sẵn sàng phục vụ.

*(Máy ảo mới sẽ tự động lấy IP từ dịch vụ DHCP trong mạng của bạn).*

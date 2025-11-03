#!/bin/bash

# Script cài đặt tự động cho Percy Project
set -e  # Dừng nếu có lỗi

# Tắt tất cả các prompt interactive
export DEBIAN_FRONTEND=noninteractive

# Màu xanh lá
GREEN='\033[1;32m'
NC='\033[0m' # No Color

echo -e "${GREEN}"
echo "╔════════════════════════════════════════════════╗"
echo "║                                                ║"
echo "║     HỒ CỬA NAM BÁO CÁ CHO TÈO MÓM              ║"
echo "║                                                ║"
echo "╚════════════════════════════════════════════════╝"
echo -e "${NC}"
echo ""

# Kiểm tra quyền root
if [ "$EUID" -ne 0 ]; then 
    echo "❌ Vui lòng chạy với quyền root (sudo)"
    exit 1
fi

# 1. Cập nhật hệ thống
echo "📦 Đang cập nhật hệ thống..."
apt update

# 2. Cài đặt Node.js 18
echo "📦 Đang cài đặt Node.js 18..."
curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
apt install -y nodejs

# 3. Cài đặt Nginx
echo "📦 Đang cài đặt Nginx..."
apt install -y nginx

# 4. Khởi động Nginx
echo "🚀 Đang khởi động Nginx..."
systemctl start nginx
systemctl enable nginx

# 5. Cài đặt unrar để giải nén
echo "📦 Đang cài đặt unrar..."
apt install -y unrar

# 6. Di chuyển đến thư mục project
echo "📂 Chuyển đến thư mục /home/teo..."
cd /home/teo

# 7. Giải nén file teo.rar
echo "📦 Đang giải nén percy.rar..."
unrar x teo.rar -y

# Đợi giải nén hoàn tất
echo "⏳ Đang đợi giải nén hoàn tất..."
sleep 2

# Xóa file percy.rar sau khi giải nén xong
echo "🗑️  Đang xóa file percy.rar..."
rm -rf /home/percy/percy.rar

echo ""
echo -e "${GREEN}✅ Ứng dụng đã được khởi động!${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 12. Nhập domain SAU KHI PM2 đã chạy
echo "🌐 Nhập domain của bạn (VD: example.com)"
echo "   Nếu có nhiều domain, cách nhau bằng dấu cách"
echo "   VD: domain1.com domain2.com sub.domain.com"
read -p "Domain: " USER_DOMAINS < /dev/tty

# Kiểm tra domain có được nhập không
if [ -z "$USER_DOMAINS" ]; then
    echo "❌ Bạn chưa nhập domain!"
    exit 1
fi

echo -e "${GREEN}✅ Domain của bạn: $USER_DOMAINS${NC}"
echo ""

# 13. Tạo file cấu hình Nginx với domain đã nhập
echo "⚙️  Đang tạo cấu hình Nginx với domain: $USER_DOMAINS"
cat > /etc/nginx/conf.d/teo.conf << 'EOF'
server {
    listen 80;
    server_name USER_DOMAINS_PLACEHOLDER;

    root /home/teo;
    index index.html;

    location / {
        try_files $uri $uri/ =404;
    }
}
EOF

# Thay thế placeholder bằng domain thực
sed -i "s/USER_DOMAINS_PLACEHOLDER/$USER_DOMAINS/g" /etc/nginx/conf.d/teo.conf

# 14. Kiểm tra cấu hình Nginx
echo "✅ Đang kiểm tra cấu hình Nginx..."
nginx -t

# 15. Restart Nginx
echo "🔄 Đang restart Nginx..."
systemctl restart nginx

echo ""
echo -e "${GREEN}✅ Cấu hình Nginx hoàn tất!${NC}"
echo ""

# 16. Hỏi có muốn cài SSL không (ở cuối cùng)
read -p "🔒 Bạn có muốn cài đặt SSL/HTTPS cho domain không? (y/n): " INSTALL_SSL < /dev/tty
echo ""

if [[ "$INSTALL_SSL" =~ ^[Yy]$ ]]; then
    echo -e "${GREEN}"
    echo "╔════════════════════════════════════════════════╗"
    echo "║           Đang cài đặt SSL                     ║"
    echo "╚════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    echo "⚠️  Lưu ý: Domain phải đã trỏ về IP server này!"
    echo "⚠️  Port 80 và 443 phải đã mở!"
    echo ""
    
    # Hỏi email
    read -p "📧 Nhập email của bạn (để nhận thông báo SSL, hoặc Enter để bỏ qua): " USER_EMAIL < /dev/tty
    echo ""
    
    sleep 2
    
    # Cài đặt certbot (bỏ qua mọi prompt)
    echo "📦 Đang cài đặt python3-certbot-nginx..."
    apt install -y python3-certbot-nginx
    
    # Tạo lệnh certbot với tất cả domain
    CERTBOT_DOMAINS=""
    for domain in $USER_DOMAINS; do
        CERTBOT_DOMAINS="$CERTBOT_DOMAINS -d $domain"
    done
    
    # Chạy certbot với các tham số tự động
    echo "🔐 Đang cài đặt SSL cho: $USER_DOMAINS"
    echo ""
    
    if [ -z "$USER_EMAIL" ]; then
        # Không có email - dùng register-unsafely-without-email
        certbot --nginx $CERTBOT_DOMAINS \
            --non-interactive \
            --agree-tos \
            --register-unsafely-without-email \
            --redirect
    else
        # Có email
        certbot --nginx $CERTBOT_DOMAINS \
            --non-interactive \
            --agree-tos \
            --email "$USER_EMAIL" \
            --no-eff-email \
            --redirect
    fi
    
    # Restart Nginx sau khi cài SSL
    echo ""
    echo "🔄 Đang restart Nginx..."
    systemctl restart nginx
    
    echo ""
    echo -e "${GREEN}✅ SSL đã được cài đặt thành công!${NC}"
fi

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║            🎉 HOÀN TẤT!                        ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════╝${NC}"

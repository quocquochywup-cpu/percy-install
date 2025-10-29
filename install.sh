#!/bin/bash

# Script cài đặt tự động cho Percy Project
set -e  # Dừng nếu có lỗi

echo "================================"
echo "   Cài Đặt Percy Project"
echo "================================"
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

# 5. Di chuyển đến thư mục project
echo "📂 Chuyển đến thư mục /home/percy..."
cd /home/percy

# 6. Cài đặt npm packages
echo "📦 Đang cài đặt npm packages..."
npm i

# 7. Cài đặt PM2 global
echo "📦 Đang cài đặt PM2..."
npm i pm2 -g

# 8. Build project
echo "🔨 Đang build project..."
npm run build

# 9. Khởi động ứng dụng với PM2
echo "🚀 Đang khởi động ứng dụng..."
pm2 start "npm run start" --name percy-app
pm2 save
pm2 startup

echo ""
echo "✅ Ứng dụng đã được khởi động!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 10. Nhập domain SAU KHI PM2 đã chạy
echo "🌐 Nhập domain của bạn (VD: example.com)"
echo "   Nếu có nhiều domain, cách nhau bằng dấu cách"
echo "   VD: domain1.com domain2.com sub.domain.com"
read -p "Domain: " USER_DOMAINS

# Kiểm tra domain có được nhập không
if [ -z "$USER_DOMAINS" ]; then
    echo "❌ Bạn chưa nhập domain!"
    exit 1
fi

echo "✅ Domain của bạn: $USER_DOMAINS"
echo ""

# 11. Tạo file cấu hình Nginx với domain đã nhập
echo "⚙️  Đang tạo cấu hình Nginx với domain: $USER_DOMAINS"
cat > /etc/nginx/conf.d/percy.conf << 'EOF'
server {
    listen 80;
    server_name USER_DOMAINS_PLACEHOLDER;
    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }
    error_page 404 /index.html;
}
EOF

# Thay thế placeholder bằng domain thực
sed -i "s/USER_DOMAINS_PLACEHOLDER/$USER_DOMAINS/g" /etc/nginx/conf.d/percy.conf

# 12. Kiểm tra cấu hình Nginx
echo "✅ Đang kiểm tra cấu hình Nginx..."
nginx -t

# 13. Restart Nginx
echo "🔄 Đang restart Nginx..."
systemctl restart nginx

echo ""
echo "✅ Cấu hình Nginx hoàn tất!"
echo ""

# 14. Hỏi có muốn cài SSL không (ở cuối cùng)
read -p "🔒 Bạn có muốn cài đặt SSL/HTTPS cho domain không? (y/n): " INSTALL_SSL
echo ""

if [[ "$INSTALL_SSL" =~ ^[Yy]$ ]]; then
    echo "================================"
    echo "   Đang cài đặt SSL"
    echo "================================"
    echo ""
    echo "⚠️  Lưu ý: Domain phải đã trỏ về IP server này!"
    echo "⚠️  Port 80 và 443 phải đã mở!"
    echo ""
    
    # Hỏi email
    read -p "📧 Nhập email của bạn (để nhận thông báo SSL, hoặc Enter để bỏ qua): " USER_EMAIL
    echo ""
    
    sleep 2
    
    # Cài đặt certbot (bỏ qua mọi prompt)
    echo "📦 Đang cài đặt python3-certbot-nginx..."
    DEBIAN_FRONTEND=noninteractive apt install -y python3-certbot-nginx
    
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
    echo "✅ SSL đã được cài đặt thành công!"
fi

echo ""
echo "================================"
echo "   🎉 Hoàn tất!"
echo "================================"

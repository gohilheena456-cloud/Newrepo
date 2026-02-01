#!/bin/bash
# Deployment script for Flask backend + Express frontend on single EC2 instance

# --- VARIABLES (edit these) ---
FLASK_REPO="https://github.com/yourusername/flask-backend.git"
EXPRESS_REPO="https://github.com/yourusername/express-frontend.git"
FLASK_PORT=5000
EXPRESS_PORT=3000

# --- UPDATE SYSTEM ---
sudo apt update -y
sudo apt upgrade -y

# --- INSTALL ESSENTIALS ---
sudo apt install -y python3 python3-pip python3-venv git nginx curl

# --- INSTALL NODEJS & NPM ---
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt install -y nodejs

# --- CLONE REPOS ---
cd /home/ubuntu
git clone $FLASK_REPO
git clone $EXPRESS_REPO

# --- SETUP FLASK BACKEND ---
cd flask-backend
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt
deactivate

# --- SETUP EXPRESS FRONTEND ---
cd ../express-frontend
npm install
npm run build

# --- CONFIGURE NGINX ---
sudo tee /etc/nginx/sites-available/default > /dev/null <<EOF
server {
    listen 80;

    location /api/ {
        proxy_pass http://127.0.0.1:$FLASK_PORT/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }

    location / {
        root /home/ubuntu/express-frontend/build;
        index index.html index.htm;
        try_files \$uri /index.html;
    }
}
EOF

# --- RESTART NGINX ---
sudo nginx -t
sudo systemctl restart nginx

# --- INSTALL PM2 FOR EXPRESS ---
sudo npm install -g pm2
pm2 start /home/ubuntu/express-frontend/server.js --name express-app
pm2 startup systemd
pm2 save

# --- OPTIONAL: RUN FLASK WITH GUNICORN ---
cd /home/ubuntu/flask-backend
source venv/bin/activate
pip install gunicorn
nohup gunicorn --bind 0.0.0.0:$FLASK_PORT wsgi:app &
deactivate

echo "Deployment complete!"
echo "Frontend: http://<EC2-IP>/"
echo "Backend API: http://<EC2-IP>/api/"

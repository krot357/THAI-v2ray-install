#!/bin/bash

#PTH=$1
#IP=$2
echo "Wellcome to v2ray+nginx install script. Please enter input parameters. "
echo "Enter Name: "
read PTH
echo
echo "Enter server IP address: "
read IP
echo
#echo "path name = $PTH and ip address= $IP"

homeDir=$(pwd)
#yum -y update
yum -y install nano wget
yum -y install zip unzip

# SE Linux config
sed -i 's/^SELINUX=.*$/SELINUX=disabled/g' /etc/selinux/config 
setenforce 0

# install nginx
yum install epel-release -y
yum install nginx -y
sed -i 's/worker_connections.*/#& \n    worker_connections 1024\x3B\n    multi_accept on\x3B\n    use epoll\x3B/' /etc/nginx/nginx.conf   

# create certificate
mkdir /etc/nginx/ssl
cd /etc/nginx/ssl/
openssl genrsa -out $PTH.local.key 2048
openssl req  -new  -subj /C=US/ST=OR/O=Blah/localityName=Portland/commonName=$PTH/organizationalUnitName=Blah/emailAddress=admin@$PTH.com -key $PTH.local.key -out $PTH.local.csr
openssl x509 -req -days 365 -in $PTH.local.csr -signkey $PTH.local.key -out $PTH.local.crt


# nginx v2ray config
cat << EOF > /etc/nginx/conf.d/v2ray.conf
server {
  listen  443 ssl;
  ssl_certificate       /etc/nginx/ssl/$PTH.local.crt;
  ssl_certificate_key   /etc/nginx/ssl/$PTH.local.key;
  ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
  ssl_prefer_server_ciphers on;
  ssl_ciphers           HIGH:!aNULL:!MD5;


  server_name           $PTH.local;
        location /$PTH {
        proxy_redirect off;
        proxy_pass http://127.0.0.1:10800;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$http_host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        }
}
EOF
sleep 5

systemctl start nginx && systemctl enable nginx

#install v2ray server
#curl -Ls https://install.direct/go.sh | sudo bash 
#sleep 15 
#mv /etc/v2ray/config.json config.backup 
# mkdir ~/v2ray
cd $homeDir
if [[ -d v2ray ]]; then
  rm -Rf v2ray
fi
mkdir v2ray
cd v2ray/
wget "https://github.com/v2ray/v2ray-core/releases/download/v4.26.0/v2ray-linux-64.zip"
unzip v2ray-linux-64.zip
mkdir -p '/etc/v2ray' '/var/log/v2ray'
mkdir /usr/bin/v2ray
cp v2ray /usr/bin/v2ray
cp v2ctl /usr/bin/v2ray
cp geoip.dat /usr/bin/v2ray
cp geosite.dat /usr/bin/v2ray
chmod +x '/usr/bin/v2ray/v2ray' '/usr/bin/v2ray/v2ctl'
cp systemd/v2ray.service /etc/systemd/system/v2ray.service

cat << EOF > /etc/v2ray/config.json 
{
  "inbounds": [
    {
      "port": 10800,
      "listen":"0.0.0.0",
      "protocol": "vmess",
      "settings": {
        "clients": [
          {
            "id": "bffce3d2-3c89-4cfc-989b-baca4708a477",
            "alterId": 70
          }
        ]
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": {
        "path": "/$PTH"
        }
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "settings": {}
    }
  ]
}
EOF
#sleep 5
systemctl enable v2ray.service
systemctl start v2ray.service 
cfgName=$(echo $PTH"_cfg.json")

cat << EOF > $homeDir/$cfgName 
{

  "dns": {
    "hosts": {
      "domain:googleapis.cn": "googleapis.com"
    },
    "servers": [
      "1.1.1.1"
    ]
  },
  "inbounds": [
    {
      "listen": "127.0.0.1",
      "port": 10808,
      "protocol": "socks",
      "settings": {
        "auth": "noauth",
        "udp": true,
        "userLevel": 8
      },
      "sniffing": {
        "destOverride": [
          "http",
          "tls"
        ],
        "enabled": true
      },
      "tag": "socks"
    },
    {
      "listen": "127.0.0.1",
      "port": 10809,
      "protocol": "http",
      "settings": {
        "userLevel": 8
      },
      "tag": "http"
    },
    {
      "listen": "127.0.0.1",
      "port": 10853,
      "protocol": "dokodemo-door",
      "settings": {
        "address": "1.1.1.1",
        "network": "tcp,udp",
        "port": 53
      },
      "tag": "dns-in"
    }
  ],
  "outbounds": [
    {
      "mux": {
        "concurrency": -1,
        "enabled": false
      },
      "protocol": "vmess",
      "settings": {
        "vnext": [
          {
            "address": "$IP",
            "port": 443,
            "users": [
              {
                "alterId": 70,
                "id": "bffce3d2-3c89-4cfc-989b-baca4708a477",
                "level": 8,
                "security": "auto"
              }
            ]
          }
        ]
      },
      "streamSettings": {
        "network": "ws",
        "security": "tls",
        "tlssettings": {
          "allowInsecure": true,
          "serverName": "$IP"
        },
        "wssettings": {
          "connectionReuse": true,
          "headers": {
            "Host": "$IP"
          },
          "path": "$PTH"
        }
      },
      "tag": "proxy"
    },
    {
      "protocol": "freedom",
      "settings": {},
      "tag": "direct"
    },
    {
      "protocol": "blackhole",
      "settings": {
        "response": {
          "type": "http"
        }
      },
      "tag": "block"
    },
    {
      "protocol": "dns",
      "tag": "dns-out"
    }
  ],
  "policy": {
    "levels": {
      "8": {
        "connIdle": 300,
        "downlinkOnly": 1,
        "handshake": 4,
        "uplinkOnly": 1
      }
    },
    "system": {
      "statsInboundUplink": true,
      "statsInboundDownlink": true
    }
  },
  "routing": {
    "domainStrategy": "IPIfNonMatch",
    "rules": [
      {
        "inboundTag": [
          "dns-in"
        ],
        "outboundTag": "dns-out",
        "type": "field"
      },
      {
        "ip": [
          "1.1.1.1"
        ],
        "outboundTag": "proxy",
        "port": "53",
        "type": "field"
      },
      {
        "ip": [
          "223.5.5.5"
        ],
        "outboundTag": "direct",
        "port": "53",
        "type": "field"
      }
    ]
  },
  "stats": {}
}
EOF






---
title: 'Melborp'
weight: 510
draft: false
---

# melborp server

## solution for problem running pgadmin container and nginx

Configure Nginx: Create a new configuration file for your domain in /etc/nginx/sites-available/melborp.solutions:

nginx

server {
: listen 80;
  server_name www.melborp.solutions;
  <br/>
  location / {
  : proxy_pass [http://localhost:8888](http://localhost:8888);  # Forward traffic to the pgAdmin container
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
  <br/>
  }

}

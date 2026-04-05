# General settings for both WordPress and ownCloud
location = /favicon.ico {
    log_not_found off;
    access_log off;
}

location = /robots.txt {
    allow all;
    log_not_found off;
    access_log off;
}

# Performance: Cache static assets
location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)$ {
    expires max;
    log_not_found off;
    access_log off;
}

# Security: Deny hidden files (like .env or .git)
location ~ /\. {
    deny all;
}

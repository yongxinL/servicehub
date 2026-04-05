# configuration file for WordPress
location / {
    try_files $uri $uri/ /index.php?$args;
}

# Handle all WordPress PHP files
location ~ \.php$ {
    try_files $uri =404;
    fastcgi_split_path_info ^(.+\.php)(/.+)$;
    fastcgi_pass 127.0.0.1:9000;
    fastcgi_index index.php;
    include fastcgi_params;
    fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
    fastcgi_param PATH_INFO $fastcgi_path_info;
    fastcgi_buffering off;
    
    # Add the timeout
    fastcgi_read_timeout 300;
}
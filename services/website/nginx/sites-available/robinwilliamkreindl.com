server {
    listen 80;
    server_name robinwilliamkreindl.com;
    root /var/www/robinwilliamkreindl.com/html;
    index index.html;

    location /pdfs {
        autoindex on;
        autoindex_exact_size off;
        autoindex_localtime on;
    }
}

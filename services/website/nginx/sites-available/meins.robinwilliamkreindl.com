server {
    listen 80;
    server_name meins.robinwilliamkreindl.com;
    root /var/www/meins.robinwilliamkreindl.com/html;
    index index.html;
}

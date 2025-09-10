#!/bin/sh
if [ "$ENABLE_SSL" = "true" ]; then
  cp ssl_common.conf ssl_enabled.conf
else
  echo "# SSL disabled" > ssl_enabled.conf
fi

nginx
php-fpm

#!/bin/bash

set -e

MYDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$MYDIR"

source "$MYDIR/config"

#--- Constants ---
if ! [[ "$SERVER_TYPE" = "apache" || "$SERVER_TYPE" = "nginx" ]]; then
  echo "Unrecognized SERVER_TYPE: $SERVER_TYPE. Choose from: apache, nginx"
  exit 1
fi

if [[ "$PORT" = "77777" ]]; then
  echo "Invalid port: $PORT. Please use the port assigned to the Proxy Port application."
  exit 1
fi

declare -A fpms
fpms=(
  ['5.6']='/opt/remi/php56/root/usr/sbin/php-fpm'
  ['7.3']='/usr/sbin/php-fpm'
  ['7.4']='/opt/remi/php74/root/usr/sbin/php-fpm'
  ['8.0']='/opt/remi/php80/root/usr/sbin/php-fpm'
  ['8.1']='/opt/remi/php81/root/usr/sbin/php-fpm'
)
if [[ -z ${fpms[$PHP_VERSION]} ]]; then
  echo "Unrecognized PHP version: $PHP_VERSION. Choose from: $(printf '%s\n, \n' "${!fpms[@]}" | head -n-1 | paste -sd '')"
  exit 1
fi

#--- Do Substitutions ---
mkdir -p "$PREFIX/src"
cp -r "$MYDIR/templates" "$PREFIX/src"
cd "$PREFIX/src/templates"
source substitutions.bash

#--- Initial Config ---
mkdir -p "$PREFIX"/{bin,conf,etc,lib,var/run,tmp}
cp "$PREFIX/src/templates/httpd.conf.template" "$PREFIX/conf/httpd.conf"
cp "$PREFIX/src/templates/nginx.conf.template" "$PREFIX/conf/nginx.conf"
cp "$PREFIX/src/templates/php-fpm.conf.template" "$PREFIX/etc/php-fpm.conf"
touch "$PREFIX/lib/php.ini"

mkdir -p "$LOGDIR"
ln -s "$LOGDIR" "$PREFIX/log"

#--- Create start/stop/restart scripts ---
cd "$PREFIX/bin"

ln -s "/usr/sbin/httpd" "$PREFIX/bin/httpd"
ln -s "/usr/sbin/nginx" "$PREFIX/bin/nginx"
ln -s "${fpms[$PHP_VERSION]}" "$PREFIX/bin/php-fpm"

cat << "EOF" > start-httpd
#!/bin/bash
MYDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
$MYDIR/php-fpm --prefix "$(dirname $MYDIR)"
$MYDIR/httpd -d "$(dirname $MYDIR)"
EOF

cat << "EOF" > stop-httpd
#!/bin/bash
MYDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
kill $(cat "$MYDIR/../var/run/httpd.pid") &> /dev/null
kill $(cat "$MYDIR/../var/run/php-fpm.pid") &> /dev/null
EOF

cat << "EOF" > start-nginx
#!/bin/bash
MYDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
$MYDIR/php-fpm --prefix "$(dirname $MYDIR)"
$MYDIR/nginx -c "$(dirname $MYDIR)/conf/nginx.conf" -p "$(dirname $MYDIR)" 2>/dev/null
EOF

cat << "EOF" > stop-nginx
#!/bin/bash
MYDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
kill $(cat "$MYDIR/../var/run/nginx.pid") &> /dev/null
kill $(cat "$MYDIR/../var/run/php-fpm.pid") &> /dev/null
EOF

cat << "EOF" > restart
#!/bin/bash
MYDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
"$MYDIR/stop"
sleep 3
"$MYDIR/start"
EOF

chmod 755 start-httpd stop-httpd
chmod 755 start-nginx stop-nginx
chmod 755 restart

if [[ "$SERVER_TYPE" = "apache" ]]; then
  ln -s start-httpd start
  ln -s stop-httpd stop
else
  ln -s start-nginx start
  ln -s stop-nginx stop
fi

#--- Remove temporary files ---
rm -r "$PREFIX/src"

#--- Create cron entry ---
M=$((RANDOM % 10))
line="\n# $STACKNAME stack\n0$M,1$M,2$M,3$M,4$M,5$M * * * * $PREFIX/bin/start &>/dev/null"
(crontab -l 2>/dev/null || true; echo -e "$line" ) | crontab -

#--- Start the application ---
$PREFIX/bin/start

#!/bin/bash -e

# It is expected this script will be executed as root. It's final step is
# to start the uwsgi gateway and to do so it will drop privilege to the
# variant-server user and www-data group. It needs root however if it
# needs to perform the chores of starting nginx and mongod. Those could
# have already been done by an upstream script that calls this one.

# Start nginx if it is not yet started by something else
# Someone out there - I would love to know if there is a simpler more direct
# way of checking if a program is running. This works though.
if [ -z "`ps ax | grep -e nginx | grep -v grep 2> /dev/null`" ]; then
    echo
    echo "nginx is not started yet, starting it... "
    /etc/init.d/nginx start
fi

# Start mongod if it is not yet started by something else
if [ -z "`ps ax | grep -e mongod | grep -v grep 2> /dev/null`" ]; then
    echo
    echo "mongod is not started yet, starting it... "
    # Make sure we can access and write to the directory
    chgrp mongodb /home/variant-server/database/live
    chmod g+w /home/variant-server/database/live
    # Remove a lingering lock file as this will prevent launch
    rm -f /home/variant-server/database/live/mongod.lock
    mongod --fork -f /etc/mongod.conf
fi

echo
echo Starting uWSGI gateway...
cd /home/variant-server
sudo -u variant-server -g www-data uwsgi --ini variant-server-uwsgi.ini

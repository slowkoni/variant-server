#!/bin/bash -e
# KONI - 2016-12-11
# Script to download a mongo database dump and mongorestore it. This is
# difficult to generalize for another user, so sort of specific for the
# needs of the Bustamante Lab and the ClinGen project which motivated the
# development of any of this. Unless modified by a user forking the repo
# this script will pull the latest backup/dump of the mongo database from
# the live (or dev) server from S3 and unpack it. Then it will mongo restore
#
# HOWEVER: Having the Dockerfile do this from within the container is
#          probably a bad idea as this will result in the mongo database
#          full payload living inside the container image. Better practice
#          would be to mount a host directory to the container when
#          docker run is executed, and mongod inside the container pointed
#          to where that directory is mounted. This script should then be
#          run by the docker run command with the -v option to map the
#          host directory where you want the mongo database to live, to
#          /home/variant-server/database/initial. (replace initial with
#          a dated directory if you are loading up a new version from S3,
#          then update the "live" link inside the container and commit the
#          container - otherwise the live link will revert to pointing to
#          initial because that is where the docker build command will
#          point it). 
#
#          to whomever ends up with a TB sized docker image one day because
#          the mongo database is inside the container, YOU WERE WARNED!
#          (if you read comments)

if [ -n "$1" ]; then
    curl -L $1 > tmp.download.mongodump
    echo
    echo "NOTE: Downloaded "
    echo       "$1"
    echo "      to tmp.download.mongodump inside container but this script "
    echo "      does not know how to unpack your mongo database and run "
    echo "      mongorestore on it. You will have to do this yourself."
    echo "NOTE: if the docker container just exited without commit, then "
    echo "      this file was probably lost already. :/ To try again, run"
    echo "      the container with /bin/bash to get a shell, do the download"
    echo "      but don't exit the shell. Then do your mongorestore to a host"
    echo "      mapped directory inside /home/variant-server/database. Or, if"
    echo "      you want to keep that file inside the container, commit the "
    echo "      container before exiting the shell"

    # Need to figure out if this is a plain tar archive, gzip'd, bzip'd, or .zip
    # or whatever to figure out how to unpack or load. Or, perhaps if the user
    # wants to roll their own, they should just fork the repo and add the logic
    # as per their needs
    exit 0
fi


cd /home/variant-server

# NOTE: I can't seem to get amazon S3 to actually send a 301 redirect as it
#       is supposed to from the empty file variant-server-mongodump-current.tar.bz2
#       to the dated file that is the latest mongodump in the bucket, like a
#       symlink though this is how the docs said to do it - by setting the
#       metatag for website redirect location. However, the headers sent back
#       do have an extended field saying the redirect location that a 301 would
#       go to, so we grab that from stderr of curl, and then pull that below
CURRENT_DATABASE=$(curl --verbose https://variant-server-current-dump.s3-us-west-2.amazonaws.com/variant-server-mongodump-current.tar.bz2 2>&1 | grep -e x-amz-website-redirect-location | cut -f 3 -d\ | sed -e 's/\s*$//')
echo
echo "Current database is found at "
echo "$CURRENT_DATABASE"
echo

# pull and unpack the pbzip2'd tar archive into a temporary directory. If
# we follow my (probably undocumented) convention of having a leading path
# with the date of the dump embedded in the name, then we aren't going to
# know what it is. So unpack into an empty directory to that leading path
# is the only directory in there. The mongodump should live directly inside
# that (if following my probably undocumented convention)
echo "Pulling that shit down ... "
mkdir -p /home/variant-server/database/tmp.download/
curl -L $CURRENT_DATABASE | ( cd /home/variant-server/database/tmp.download && pbzip2 -dc - | tar -xf - )

# At time of writing, we are expecting to be inside the docker container
# this means mongod is not running as its a different container for every
# RUN command in the Dockerfile. So start it. We want to restore through
# it because hopefully then it will automatically rebuild the indexes.
echo "Starting mongod server... "
mongod --fork -f /etc/mongod.conf

# Ok, we'll see how this shit show goes...
echo Attempting to restore database from /home/variant-server/database/tmp.download/*/
mongorestore /home/variant-server/database/tmp.download/*/

# Give a chance for things to flush to disk through mongod
sync
sleep 5
sync

# I really hope this causes mongod to sync and stop. The start script won't work
# we really want a clean shutdown otherwise the lockfile will persist and the
# full data may not be written yet, but when this script exits, the docker
# container will exit and automatically kill everything mid-sentance
/etc/init.d/mongod stop

sleep 5

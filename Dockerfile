FROM nginx
# Start with official nginx docker image release

# Yeah, I did this shit - I'm an academic, give me a break you silicon valley pros
MAINTAINER Mark Koni Hamilton Wright <mhwright@stanford.edu>
LABEL version="0.04"

# Add to APT repository lists the those we need to pull in non-ubuntu packages
# namely, mongodb
ADD apt-sources/ /etc/apt/sources.list.d/

# Get the mongodb release official signing keys so apt can verify the packages
RUN apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys D68FA50FEA312927 9ECBEC467F0CEB10

# Always need to make sure apt package list is current, plus we need it to add
# to its knowledge of packages the mongo packages from the sources above we just
# added to its lists of repos
RUN apt-get update -y

# apt complains, though doesn't fail, about apt-utils not being installed
# during other installs, so try installing it first
RUN apt-get install -y apt-utils

# Make sure we have all security updates and anything else since the nginx
# official build that we started from
RUN apt-get upgrade -y

# Now get the ubuntu packages we are going to need to do anything else
RUN apt-get install -y git gcc make python-pip python-dev wget curl sudo net-tools telnet links2 vim pbzip2

# Now get from python's package manager, the python web gateway (uWSGI) that
# nginx will speak with, and Flask, the web framework we are using that uWSGI
# with interface to on behalf of nginx
RUN pip install uWSGI
RUN pip install Flask

# Now install mongodb - this can be a little touchy, so if you are trying to
# build the container and find it fails here, that is why I separated it from
# the above installs. You will need to troubleshoot the issue - just google
# the exact error message from the install, it will be buried among a bunch of
# other noise from apt which is itself complaining there was a problem. But
# it is probably not apt's problem that you want to troubleshoot, it is the
# problem encountered during the mongodb package installations reported by
# those package's install scripts before that
RUN apt-get install -y mongodb-org-server mongodb-org-shell mongodb-org-tools mongodb-org python-pymongo

# Add a user with normal user level privs to this container. The UID can be
# changed on the command line for the build with --build-arg UID=$UID to make
# it match YOUR user id on the system you are building on. Then, host
# directories can be shared between the container and the host with -v on the
# docker run command line and you can write files from inside the container to
# the host. For reasons I don't understand, there are permission problems
# even if that directory is mode 777 on the host, unless the user id running
# inside the container matches the user id on the host that executed docker run
ARG UID=1000
RUN useradd --non-unique -u $UID --home /home/variant-server --user-group --create-home --shell /bin/bash variant-server
#RUN echo "variant-server  ALL=(ALL:ALL) NOPASSWD: ALL" >> /etc/sudoers

# After the above /home/variant-server exists and there is the user variant-server
# We will add all our files of the docker build context to this directory,
# though some are not needed there, like the files we are about to copy into
# /etc for nginx and mongodb config
ADD . /home/variant-server
RUN chown -R variant-server:variant-server /home/variant-server

# Inside nginx-conf/ is a conf.d/ directory and inside that is the server
# configuration files, which the main default-installed /etc/nginx/nginx.conf
# configuration will pull in. That will allow the file we have here in
# nginx-conf/conf.d/ to configure our server for nginx
ADD nginx-conf/ /etc/nginx/

# Remove the default nginx config, so all behavior, good or bad, must be our fault
RUN rm -f /etc/nginx/conf.d/default.conf

# I cant get uWSGI configuration ini to chown the socket to nginx group
# it defaults to www-data, so just add nginx to that group. Otherwise
# they can't talk due to permissions problems with the socket
RUN adduser nginx www-data

# Set a place in our play space for nginx logs to go
RUN mkdir /home/variant-server/nginx-logs
RUN chown nginx:www-data /home/variant-server/nginx-logs

# Make the mongodb database directory and lets try to keep all our shit inside
# our play space, the /home/variant-server directory. So mongodb's files will
# live in there. 
RUN mkdir -p /home/variant-server/database

# Because we might have a live and development version, or a running version
# and then we are going to update to a new release and want to save the
# previously working mongo database, create a directory which we will call
# "initial" here, and make a symlink from "live" to initial. The mongod.conf
# configuration file will point mongod server to /home/variant-server/database/live
# as its database location. If we drop a new one in there, under a different name
# preferably with a date (I don't know how to get today's date inside this file)
# to make the pivot we just briefly stop mongod, change the symlink, and restart
# mongod. Test the server. If everything works, great. If not, switch it back, and
# start scratching our heads. Go build another container on another host and
# figure it out there.
RUN mkdir /home/variant-server/database/initial
RUN ln -s /home/variant-server/database/initial /home/variant-server/database/live

# We'll also direct mongod to write its logs and problems into our play space
RUN mkdir /home/variant-server/database/logs

# We also need to set permissions and group ownership so mongod can access
RUN chown -R root:mongodb /home/variant-server/database
RUN chmod -R 775 /home/variant-server/database

# Set the mongod configuration. Ideally, I'd just like to change the database
# directory setting and maybe the logging directory settings, and leave mongo's
# defaults, presumably good settings, as is. Those may change with new mongo
# releases, but since we are copying an entire configuration file, we won't get
# those presumably new general purpose optimal settings. Also, this means there
# is the potential to fail if the older mongod.conf file here disagrees with
# some new update to how the files are interpreted or what is required in them.
# If mongod fails to start, get the original mongod.conf file, and manually make
# changes that matter for us, copy that to the docker build context (where you
# find this file), and rebuild the container
ADD mongod.conf /etc/

# The server serves HTTP/HTTPS so it needs those ports open, and mongo
# might be needed from the host or at least most convenient that way. It is up
# to the user to make sure access to the exposed mongo port is restricted
# from the internet by the host's firewall and forwarding rules, or docker
# run port mappings
EXPOSE 80 443 27017

# Switch to the variant-server user because I want all these files created
# as the variant-server user and not as root. If --build-arg DOWNLOAD=yes was
# set, then we will download from S3 the most recent dump of the our lab's
# running variant server, and also then load mongo with it.
USER variant-server

# We will not download and install a database unless explicitly requested
# this will take a long time otherwise. Use --build-arg DOWNLOAD=yes to
# pull the latest snapshot of the lab's variant server mongodb database to
# the image build and load mongo inside the image.
#
# NOTE: You may instead want the mongo database data itself to live outside
#       the docker image on the host filesystem and share the mongo database
#       directory with the container with -v on the docker run command line
#
# WARNING: You may run into problems building the container due to the payload
#          pacticularly on Macs where the workspace docker has for building
#          images does have a limit that can only be extended through some
#          manual crap. Thus the build of this image w/ download may fail
#          due to this. That can happen on Linux too.
# Please see https://forums.docker.com/t/no-space-left-on-device-error/10894/33
# for more information if you see "no space left on device" and failure at this
# step.
#
# This command will remove exited containers:
#    docker rm $(docker ps -q -f 'status=exited')
# This command will remove "dangling" images - images not needed for anything
#    docker rmi $(docker images -q -f "dangling=true")
# Doing both will clear out some of your docker build workspace
ARG DATABASE_SITE=http://variant-server-current-dump.s3-accelerate.amazonaws.com/variant-server-mongodump-2016-12-10.tar.bz2
RUN /home/variant-server/download-database.sh $DATABASE_SITE


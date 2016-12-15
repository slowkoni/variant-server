### Instructions for building and launching this server on AWS

Note: presently it will build, load database, and run even on a
t2.small instance. The power of the instance will most likely only
impact the database load time, and that is more likely to be I/O
bounded than CPU bounded. If you use an instance with little or no
built-in storage, you will need to create and connect an EBS volume to
store the database. This can be of any type but an SSD volume is
recommended, provisioned IOPS is not necessary unless you expect your
server will be taking a heavy load of queries. To load and use the
Bustamante Lab predicted variant impact database, you should create an
EBS volume of about 128 GB at the time of writing, but mongo will
ultimately only use about 40 GB of this. More space is needed during
the loading procedure.

### Start an AWS instance

+ Create an AWS instance using the dashboard (or however you like)
  using the stock Amazon Linux AMI that includes the docker repository
  preinstalled.

Alternatively, use any AMI you like that supplies a Linux distribution
and has docker already installed or already has the relevant docker
distribution site repositories installed, or add those yourself. All
steps using `yum` below may need equivalents for `apt-get` for Debian
or Ubuntu based distributions.

Make sure tcp ports 22 (ssh) 80 (http) and 443 (https) are allowed
from any host (0.0.0.0/0) through your security group rules for the
instance. 

+ Add your AWS ssh access key to your ssh-agent

`ssh-add <your-user-key>.pem`

Note: if you don't use ssh-agent, you need `-i <your AWS key>.pem` below

+ When running, log into your instance

`ssh ec2-user@<your instance hostname/ip>`

+ Run all security updates since AMI was created

`sudo yum update`

+ install git

`sudo yum install git`

+ Install docker engine

`sudo yum install docker.x86_64`

+ Add ec2-user to docker group

`sudo usermod -a -G docker ec2-user`

+ Log out of ssh, you need to re-login so that ec2-user is recoginzed as part of the docker group

+ Start docker daemon

`sudo /etc/init.d/docker start`

+Get into something that will keep our session if we get disconnected
and also keep it running after we log out purposely

`screen -D -R variant-server`

Note: if you are disconnected or choose to log out of ssh, the same
command above will reconnect you to your screen session. tmux or byobu
will do the same for you, use whatever you prefer.

### Allocate sufficient space for the database

+ Create an EBS volume for the database if not done already at
instance launch time.

NOTE: If creating now, connect it to the running instance and note
which Linux device it is connecting as, and substitute in place of
/dev/sdb below. /dev/sdb assumes you requested the EBS volume as part
of creating the instance.

NOTE: A freshly created EBS volume is a raw disk with no partition
table and no filesystem. So we are going to take care of that.

+ Create the mount point for it

`sudo mkdir /mnt/database`

+ Create a partition table

`sudo fdisk /dev/sdb`

  + in fdisk, press 'n' for new partition
  + say 'p' primary partition
  + say 1 for partition number
  + accept default for first sector
  + accept default for last sector
  + press 'w' to write the partition table to the disk
  + This will create a single partition occupying the entire disk

+ format the disk with XFS filesystem (don't forget the 1 after sdb)

`sudo mkfs.xfs /dev/sdb1`

+ mount the newly formatted filesystem to /mnt/database

`sudo mount -t xfs -o noatime /dev/sdb1 /mnt/database`

+ chown it to ec2-user, set permissions

```
sudo chown ec2-user:ec2-user /mnt/database
sudo chmod 750 /mnt/database
```

### Set up the server stack and load the database

Now the instance is set up, we can follow instructions on github 

+ First clone the repository

```
git clone https://github.com/slowkoni/variant-server.git
cd variant-server
```

+ Build the docker container.

This will install and set up the entire
stack inside the docker container and save the image
Some warnings/errors/noise in red during installs are
expected and normal

`docker build --build-arg UID=$UID -t variant-server .`

+ Download and install the latest dump of the database

This will run inside the container, but place the downloaded and
unpacked mongodump files inside /mnt/database. It will then call
mongorestore to load the mongo BSON dumps into the mongo database
which will also go into /mnt/database outside the container, which
is what you want.

NOTE: This command may take a long time to finish because the
       mongorestore isn't particularly fast, and it will depend on
       how fast your instance is that you chose.

`docker run -i -t -v /mnt/database/:/home/variant-server/database/initial variant-server /home/variant-server/download-database.sh`

NOTE: The database needs to be loaded only once and stays in the EBS
volume even when you terminate the amazon instance. It can simply be
reconnected to a new instance and skip to the below. However, you will
probably need to rebuild the docker container unless you export it and
save it somewhere, or upload to docker hub or quay.

### Running the server

+ Start the server stack

```
docker run -i -t -v /mnt/database/:/home/variant-server/database/initial variant-server /home/variant-server/uwsgi-start.sh`
```

This command will stay running in the foreground in your screen
session. To stop the server stack and docker container, press
ctrl-c. To disconnect your ssh session but leave it all running,
disconnect from screen, and just log out.

Test it by pointing your web browser to the running instance hostname
and suitable test variant to query:
http://my-ec2-instance-hostname/variant/rsid/rs4680/

If you want, allocate and bind an elastic IP and then register a
proper hostname using AWS Route 53.




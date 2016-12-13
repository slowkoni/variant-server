## variant-server

A simple web-based service to return JSON objects describing known and predicted effects of genetic variants


### Building the variant server docker container

This will build the container. The --build-arg part will set the user
id of the home directory of the play space for the server to that of
the building user, allowing that user to share a directory of the host
with the container using -v in docker run with read/write in both
directions. I can't figure out how to get around the permission
problems otherwise.

`docker build --build-arg UID=$UID -t variant-server .`

This is only needed once per update to the repo you've forked or cloned.

### Loading the current database for the Bustamante Lab variant server

```
docker run -i -t -v <your local storage path>:/home/variant-server/database/initial variant-server /home/variant-server/download-database.sh
```

Where <your local storage path> means the *absolute* pathname of the
place on the host where you want the mongo database to live. This
should not live inside the container, plus the container filesystem is
ephemeral and unless you commit the image its gone when docker run
completes. Of course you must have write privileges in that host
directory. DO NOT TRY THIS ON AN NFS MOUNTED FILESYSTEM. Database load
can put a serious strain on the I/O subsystem of the computer and
depending on the capabilities of your system this may seriously slow
down your computer, and in the case of NFS, really bog it down and the
database load will go quite slowly.

This command will pull the latest saved snapshot of the running live
Bustamante Lab variant server from Amazon S3 and unpack it and call
mongorestore to rebuild the database and index. Inside the container,
this will be seen as the directory
/home/variant-server/database/initial, which
/home/variant/database/live is a symlink to. If you want it to go to
somewhere else, create that in the container and map the host
directory to that and adjust the symlink accordingly. Just don't
forget to commit the container image, otherwise you will lose the
symlink update as well as the directory you create. The files on the
host will stay, so recovery doesn't mean you need to reload the
database again. In the case you want to do this, do the docker run
command just starting /bin/bash rather than the download-database.sh
script, do your directory creation, then run the download-database.sh
script from within the container, making sure the symlink for live is
updated first, then commit the container.

### Running the variant server

This will start the server inside the docker container running in the
foreground though nginx, mongod, and uWSGI logs should go inside the
container into directories under /home/variant-server. Python/Flask
errors should be found within the uWSGI logs.

```
docker run -i -t variant-server /home/variant-server/uwsgi-start.sh
```

NOTE: This will run in the foreground and not return, and also not
show much of interest as all the logs are going into log files inside
the container. But if you ctrl-c to get your shell back, you stop the
container and the entire stack and server. So start this in screen
where you can detach from screen and leave it going, then reattach and
look for anything suspicious since put to the terminal rather than the
logs. Also, to check on the logs, do `docker ps` to find your
running container ID, and do

```
docker exec -i -t <container id> /bin/bash
```

to get a shell inside. Then navigate to /home/variant-server and
inspect or monitor logs. Python/Flask errors will be in the uwsgi
logs, nginx routing errors to uwsgi will be in the nginx logs. Mongo
problems will be in the mongo logs. 

### Checking it out from the inside

Somewhat redundant to the above, to connect with a shell to the running container to inspect the logs,
or dork with something, use `docker ps` to find the container id of
the running container. Then do 

```
docker exec -i -t <container id> /bin/bash
```

That will give you a root shell inside the container. All the business
end of things should be inside /home/variant-server/. Everything
outside that directory should be boilerplate system stuff.

### Ending the show

To stop the server, running in the foreground in the shell you started
the docker run command in, just CTRL-C. That will exit the entire
container and kill any shell you may have started with `docker
exec`. The whole thing is gone, sort of. You need to use `docker rm` to
get completely rid of the container as usual, otherwise the exited
container hangs around in some way I don't quite understand. To find
these accumulated containers that aren't running but retained, use
`docker ps -a`

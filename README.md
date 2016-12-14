## variant-server

A simple web-based service to return JSON objects describing known and predicted effects of genetic variants.


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
docker run -i -t -v <your local storage path>/:/home/variant-server/database/initial variant-server /home/variant-server/download-database.sh
```

IMPORTANT: Do not forget the trailing / on the local storage path!

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
docker run -i -t -v <your local storage path>/:/home/variant-server/database/initial -p 80:80 -p 443:443 variant-server /home/variant-server/uwsgi-start.sh
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

### Checking it out from the outside

From your host, point a web browser at [http://localhost/ ](http://localhost/). You should see a page saying not found on this server. That is correct, there is no static content at this time for this server and no home or landing page. Now try [http://localhost/variant/rsid/rs4680/](http://localhost/variant/rsid/rs4680/). This should give you a JSON response with the predicted consequences (probably only from REVEL at this point) for the dbSNP variant known as rs4680. If you have a JSON viewer installed in your browser, it will look a little nicer and easier to read. If you see a JSON response with data, the server is working. If you see a JSON response that just effectively says no results, the server stack is working, and mongo is responding to the query generated, but the data is not loaded or not available somehow so mongo is not returning it. Now, try the same with https instead. You should see a warning from your browser about an untrusted certificate. This is normal, the github version of this includes a self-signed certificate for localhost and and is considered invalid by the browser or not authoritative - the browser can not prove the identity of the server is who it reports to be. Of course the Bustamante Lab domain signed certificate is not in the github repository. Click past the warnings or whatever to go forward and you should again see the same JSON response. If so, https is working, just identity of server not validated. For other users of this server, it is left as an exercise as how to install and use your own properly signed SSL certificate. The nginx configs will need to be updated and you will need to install your certificate and private key in /home/variant-server/ssl-certificates/.

If you get connection refused, make sure you used the -p options as given above. Also, make sure your host system firewall and forwarding rules are not blocking the port mapping of the host system to the docker container. The -p option should result in any incoming connection to the host on ports 80 and 443, on any interface, to be forwarded to the running docker container at the same ports, which is what nginx is listening on, but any number of various security layers can interfere with that, more than can be documented here. In this case, go to below and check out from the inside - use the links2 text based browser to connect to localhost of the container, same addresses as above. If you get results, the container is working, but the port mapping/forwarding between host and container is not.

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

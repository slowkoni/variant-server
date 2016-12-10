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

### Running the variant server

This will start the server inside the docker container running in the
foreground though nginx, mongod, and uWSGI logs should go inside the
container into directories under /home/variant-server. Python/Flask
errors should be found within the uWSGI logs.

```
docker run -i -t variant-server /home/variant-server/uwsgi-start.sh
```

### Checking it out from the inside

To connect with a shell to the running container to inspect the logs,
or dork with something, use `docker ps` to find the container id of
the running container. Then do 

```
docker exec -i -t <container id> /bin/bash
```

That will give you a root shell inside the container. All the business
end of things should be inside /home/variant-server/. Everything
outside should be boilerplate system stuff.

### Ending the show

To stop the server, running in the foreground in the shell you started
the docker run command in, just CTRL-C. That will exit the entire
container and kill any shell you may have started with `docker
exec`. The whole thing is gone, sort of. You need to use `docker rm` to
get completely rid of the container as usual, otherwise the exited
container hangs around in some way I don't quite understand. To find
these accumulated containers that aren't running but retained, use
`docker ps -a`

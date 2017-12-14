
Developer notes
===============

*   One way to give the container access to the Engine is via the same REST API
    that is used by the client to talk to the same Docker Engine.

    Mounting the socket file while creating the container::

        docker run -it -v/var/run/docker.sock:/var/run/docker.sock ensemblorg/ensembl-hive

    Using it from inside (make sure the container has *curl*)::

        curl --unix-socket /var/run/docker.sock http:/v1.30/info | json_pp

    or::

        curl --unix-socket /var/run/docker.sock http:/v1.30/info | python3 -m json.tool

*   Docker Engine REST API:
    https://docs.docker.com/engine/api/v1.30/

*   We need both *curl* and *json_pp* for development, but can probably do without them in production:
    https://stackoverflow.com/questions/34582918/how-to-work-with-http-web-server-via-file-socket-in-perl
    and::
    
       use JSON;

* Hostname on each container is a 12-hexdigit prefix of the container_id obtainable from::

    curl --unix-socket /var/run/docker.sock http:/v1.30/containers/json | json_pp

  May need to truncate the output of the latter to 12 hexadigits to make them comparable.

* Container_ids (esp. truncated!) are unique within one Docker Engine,
  but are not guaranteed to be unique across the Swarm

Cheat-sheet
===========

* Start a single-node swarm (and provide the command for others to join)::

    docker swarm init


* Check swarm status (says "active")::

    docker info | grep Swarm:


* Stop the single-node swarm::

    docker swarm leave --force


* Check swarm status (says "inactive")::

    docker info | grep Swarm:


* Ask for the command for others to join::

    docker swarm join-token worker


* Joining an existing swarm::

    docker swarm join --token SWMTKN-.... 192.168.65.2:2377


* Show the participating nodes (only available on manager nodes)::

    docker node ls


* Create a service that maps ports::

    docker service create --name blackboard --publish 8306:3306 --env MYSQL_RANDOM_ROOT_PASSWORD=1 --env MYSQL_USER=ensrw --env MYSQL_PASSWORD=ensrw_password --env 'MYSQL_DATABASE=%' mysql/mysql-server:5.5


* Create a one-time batch job that is allowed to exit (NOTE Docker host's name in the URL!)::

    docker service create --name=init_pipeline --restart-condition=none ensemblorg/ensembl-hive init_pipeline.pl Bio::EnsEMBL::Hive::Examples::LongMult::PipeConfig::LongMult_conf -pipeline_url mysql://ensrw:ensrw_password@lg4-ml:8306/lg4_long_mult_inside -hive_force_init 1


* Create a "zero-replicas" worker batch job::

    docker service create --name=worker --replicas=0 --restart-condition=none ensemblorg/ensembl-hive runWorker.pl -url mysql://ensrw:ensrw_password@lg4-ml:8306/lg4_long_mult_inside


* Rescale the worker service (make sure the number only goes up from the number of currently running replicas)::

    docker service scale worker=2


* guihive_server service::

    docker service create --name=guihive_server --publish 8081:8080 ensemblorg/guihive


* List the existing services with current/max replica numbers::

    docker service ls


* Inspect a service::

    docker service inspect --pretty worker


* Delete a service::

    docker service rm init_pipeline



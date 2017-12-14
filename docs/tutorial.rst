Tutorial
========

This document will go through the steps needed to configure a Docker Swarm
environment, and running a toy eHive pipeline.

1. Set up a swarm

   .. tip::
      To set up Docker Swarm *in the cloud*, follow these instructions

      * For Amazon Web Services: https://docs.docker.com/docker-cloud/cloud-swarm/create-cloud-swarm-aws/
      * For Microsoft Azure: https://docs.docker.com/docker-cloud/cloud-swarm/create-cloud-swarm-azure/

   .. caution::
       Make sure you don't have any docker swarm leftover from previous attempts, or the times when dynamically allocated IPs were different.

       On the worker nodes run::

          docker swarm leave

       On the manager node run::

          docker swarm leave --force

   .. attention::
      On Linux, one of the default network layers needed for the swarm to
      work (the *ingress* network) overlaps with the `WTGC` wireless
      network (IP range 10.255.0.0/16 vs 10.255.0.0/21). You will have to
      either disconnect from WTGC or re-configure the ingress network
      following the instructions found at
      https://docs.docker.com/engine/swarm/networking/#customize-the-ingress-network

   .. important::
      These instructions have been fully tested on a swarm composed of
      Ubuntu 14.04 machines. MacOS machines can be added to the swarm, but
      with a few restrictions due to the way the network is configured on
      this OS. For instance, MacOS *cannot* be swarm managers, or host the
      blackboard.

   1. Pick a master node for your swarm and make sure its Docker engine is
      listening on a TCP interface. Under Ubuntu, this is configured in
      ``/etc/default/docker``, by adding this to ``DOCKER_OPTS``::

          -H tcp://0.0.0.0 -H unix:///var/run/docker.sock

      The first -H enables the TCP server on *all* network interfaces, the
      second -H is to keep the engine listening on its standard UNIX socket,
      which is needed by the docker CLI interface.

      .. note::
          ``-H tcp://`` alone makes the TCP server listen on the *local*
          interface only, which would make it invisible from the other
          nodes.

   2. Init a fresh swarm on the master::

         docker swarm init

   3. Copy the command to join the swarm to the worker nodes and run it there

      .. tip::
         If you lose the command, just run this to get it back::

            docker swarm join-token worker

   4. Take note of the last part of that connection command, change the
      port number from 2377 to 2375 and use this value to set
      ``DOCKER_MASTER_ADDR`` in all the terminals in which you will run
      ``beekeeper.pl`` or the debug script ``dev/docker_jobs.pl``.::

         export DOCKER_MASTER_ADDR=123.45.67.89:2375

      .. note::
         By default, Docker containers use the Google Public DNS servers
         8.8.8.8 and 8.8.4.4. If you want to use DNS names to refer to
         servers (``DOCKER_MASTER_ADDR`` and the MySQL server below) and
         those are not publicly advertised, you will need to add
         ``--dns my.dns.ip.address`` parameter(s) to the Docker daemon
         (``/etc/default/docker`` under Ubuntu)

   5. Check that the swarm has all the nodes you want (from the manager node)::

         docker node ls

   .. note::
      Docker services can only be created from the *master* node. This
      affects all the ``docker service create`` commands listed below.

2. Create the pipeline database (blackboard)

   a. The easiest is to set up a database server *outside* of the swarm.
      You need to make sure it is visible from *all* the swarm nodes. Do
      check that:

      * you use the public IP address in the URL for that database (neither
        "localhost" nor "127.0.0.1" will do)
      * the server allows external access (check both MySQL server's config
        and your firewalls)
      * the swarm nodes are able to access the server's network

   b. You can also submit the database as a Docker service, for instance::

         docker service create --name blackboard --publish 8306:3306 --reserve-cpu 1 --env MYSQL_RANDOM_ROOT_PASSWORD=1 --env MYSQL_USER=ensrw --env MYSQL_PASSWORD=ensrw_password --env 'MYSQL_DATABASE=%' mysql/mysql-server:5.5

      This will create a MySQL 5.5 server with the user/password
      credentials you wish. ``MYSQL_DATABASE=%`` is a trick to make this
      image grant permissions to the user on **all** (``%``) databases.

      The server will run on *any* node, but the local port 3306 (MySQL's
      default) will be mapped to the manager node's port 8306. Hence, the
      MySQL server URL would be on the manager's IP address and port 8306.

      .. caution::
         Be aware that this way of running MySQL is considered unreliable
         since the database files only exist *within* the container, and won't
         be kept upon restart (if the server crashes) or when the service
         ends.

   c. ``init_pipeline.pl`` can run either on the swarm or outside. The base
      command-line to initialize the long-multiplication pipeline is::

          init_pipeline.pl Bio::EnsEMBL::Hive::Examples::LongMult::PipeConfig::LongMult_conf -pipeline_url $EHIVE_URL -hive_force_init 1

      To run as a service, prefix it with::

          docker service create --name=init_pipeline --restart-condition=none ensemblorg/ensembl-hive-docker-swarm

3. Run the pipeline

   .. tip::
      Docker will automatically pull the latest image before starting the
      containers, you don't need to update the image yourself.

   a. If you are restarting a  pipeline, you may need to delete the
      services created by the previous attempt, as the service names have to
      be unique. Find out which services are still registered with ``docker
      service ls`` (see below) and delete the ones you don't need any more::

          $ docker service rm long_mult-Hive-default-2_1 long_mult-Hive-default-1_2 long_mult-Hive-default-1_3

   b. Beekeeper

      1. You can run ``beekeeper.pl`` on any of the machines participating
         in the Swarm as long as you have set ``DOCKER_MASTER_ADDR``
         variable there: it doesn't have to be the master node !

      2. You can also submit the beeekeeper to the Swarm as a *service*::

            docker service create --name long_mult_beekeeper1 --replicas 1 --restart-condition none --env DOCKER_MASTER_ADDR=$DOCKER_MASTER_ADDR --reserve-cpu 1 ensemblorg/ensembl-hive-docker-swarm \
              beekeeper.pl -url $EHIVE_URL -loop

         For debugging, you may have to share a directory with the
         container. Add this to the command-line *before* the image name::

            --mount type=bind,source=/tmp/leo,destination=/tmp/leo

         Make sure that the source directory exists on *all* the nodes,
         since you cannot control on which node the service will be
         executed.

      3. Remember that LOCAL analyses will be run on the beekeeper's
         environment, and won't be submitted.

      4. You can also run beekeeper with the ``-run`` option instead of
         ``-loop``. The beekeeper service will scale down to 0 when
         beekeeper ends and you'll need to rescale it to 1 every time you
         want another iteration::

             docker service scale long_mult_beekeeper1=1

         This is something I would call "debug mode".  When everything
         works, just switch it to ``-loop`` and enjoy.

   c. In parallel, open a database connection and watch the pipeline being
      worked on !

   d. Monitor the workers (services) with ``docker service``::

        $ docker service ls
          ID                  NAME                         MODE                REPLICAS            IMAGE                                 PORTS
          quqiykcjmnhk        long_mult-Hive-default-2_1   replicated          0/4                 ensemblorg/ensembl-hive-docker-swarm
          t0eundxn55m6        long_mult-Hive-default-1_2   replicated          0/4                 ensemblorg/ensembl-hive-docker-swarm
          xi9f3ffbid5e        long_mult-Hive-default-1_3   replicated          0/2                 ensemblorg/ensembl-hive-docker-swarm

        $ docker service ps long_mult-Hive-default-1_2
          ID                  NAME                            IMAGE                                  NODE                DESIRED STATE       CURRENT STATE           ERROR                              PORTS
          ekx78eij8veb        long_mult-Hive-default-1_2.1    ensemblorg/ensembl-hive-docker-swarm   mattxps             Shutdown            Failed 19 hours ago     "starting container failed: oc…"
          m13t6brngmwl        long_mult-Hive-default-1_2.2    ensemblorg/ensembl-hive-docker-swarm   matttop             Shutdown            Complete 19 hours ago
          nb3pvz5daep4        long_mult-Hive-default-1_2.3    ensemblorg/ensembl-hive-docker-swarm   mattxps             Shutdown            Failed 19 hours ago     "starting container failed: oc…"
          j3j4vlm9b4m3        long_mult-Hive-default-1_2.4    ensemblorg/ensembl-hive-docker-swarm   matttop             Shutdown            Complete 19 hours ago

        $ docker service logs long_mult-Hive-default-1_2
          long_mult-Hive-default-1_2.1.ekx78eij8veb@mattxps    | container_linux.go:262: starting container process caused "exec: \"/repo/ensembl-hive/scripts/dev/simple_init.py\": stat /repo/ensembl-hive/scripts/dev/simple_init.py: no such file or directory"
          long_mult-Hive-default-1_2.3.nb3pvz5daep4@mattxps    | container_linux.go:262: starting container process caused "exec: \"/repo/ensembl-hive/scripts/dev/simple_init.py\": stat /repo/ensembl-hive/scripts/dev/simple_init.py: no such file or directory"

        $ docker service logs ekx78eij8veb
          long_mult-Hive-default-1_2.1.ekx78eij8veb@mattxps    | container_linux.go:262: starting container process caused "exec: \"/repo/ensembl-hive/scripts/dev/simple_init.py\": stat /repo/ensembl-hive/scripts/dev/simple_init.py: no such file or directory"

      .. tip::
         When given a service name, ``docker service logs`` will print the
         logs of *all* the tasks of that service. When given a task ID (the
         first column of ``docker service ps``), the output is restricted
         to that task. This is the only way of getting the output of a
         specific worker as ``docker service logs`` doesn't accept "task
         names" (e.g. *long_mult-Hive-default-1_2.2*).

      .. note::
         ``docker service logs`` dumps the standard-output logs onto your
         standard-output and the standard-error logs onto your
         standard-error.

      We also provide a script ``docker_jobs.pl``, located in
      ``ensembl-hive/scripts/dev/`` (which is *not* in the default PATH) to
      list either all the service replicas, or only the replicas of the
      service of your choice. The script uses Docker's REST API on
      ``DOCKER_MASTER_ADDR``, and is a good way of checking that the
      information available to the DockerSwarm meadow is the same as on the
      command-line.

      ::

          $ ensembl-hive/scripts/dev/docker_jobs.pl
            Service_ID      Service_name_and_index  Task_ID Status  Node_ID Node_name
            0cjyvrg56e6a4qt666b161oky       init_pipeline[1]        mxibbp4s5mjxf2x9i8y2rt9fu       complete        hw7a5jd8tx20e51istjp3dp1i       172.22.70.252/matttop
            kldfgtvg6lehifcz7ggggw7cy       long_mult_beekeeper1[1] 9ifvq4os3b8jm69ogngmck6jo       complete        hw7a5jd8tx20e51istjp3dp1i       172.22.70.252/matttop
            mwtzqypba2tnrrmfi4lg7wc43       long_mult-Hive-default-1_2[1]   v96yhbbv7yli4xr3855d18x1y       complete        hw7a5jd8tx20e51istjp3dp1i       172.22.70.252/matttop
            mwtzqypba2tnrrmfi4lg7wc43       long_mult-Hive-default-1_2[2]   0448t1akalt8coak7vj1q2d9l       complete        9m8hh96du7220yxtv65a8840q       172.22.68.27/mattxps
            mwtzqypba2tnrrmfi4lg7wc43       long_mult-Hive-default-1_2[3]   mf2oev5kcltklz9hgenas1xc4       complete        hw7a5jd8tx20e51istjp3dp1i       172.22.70.252/matttop
            mwtzqypba2tnrrmfi4lg7wc43       long_mult-Hive-default-1_2[4]   36a7uxdqc0l6m0kxkunp6rjn9       complete        9m8hh96du7220yxtv65a8840q       172.22.68.27/mattxps
            z7nz4ivyhnvja1o7ndobvqd26       long_mult-Hive-default-1_3[1]   7bofm0n7kp2d9dv5cy4hudg6w       complete        hw7a5jd8tx20e51istjp3dp1i       172.22.70.252/matttop
            z7nz4ivyhnvja1o7ndobvqd26       long_mult-Hive-default-1_3[2]   tgk2hddhbuxiaxi6lsjzjnavf       complete        9m8hh96du7220yxtv65a8840q       172.22.68.27/mattxps

          $ ensembl-hive/scripts/dev/docker_jobs.pl long_mult-Hive-default-1_2
            Service_ID      Service_name_and_index  Task_ID Status  Node_ID Node_name
            mwtzqypba2tnrrmfi4lg7wc43       long_mult-Hive-default-1_2[1]   v96yhbbv7yli4xr3855d18x1y       complete        hw7a5jd8tx20e51istjp3dp1i       172.22.70.252/matttop
            mwtzqypba2tnrrmfi4lg7wc43       long_mult-Hive-default-1_2[2]   0448t1akalt8coak7vj1q2d9l       complete        9m8hh96du7220yxtv65a8840q       172.22.68.27/mattxps
            mwtzqypba2tnrrmfi4lg7wc43       long_mult-Hive-default-1_2[3]   mf2oev5kcltklz9hgenas1xc4       complete        hw7a5jd8tx20e51istjp3dp1i       172.22.70.252/matttop
            mwtzqypba2tnrrmfi4lg7wc43       long_mult-Hive-default-1_2[4]   36a7uxdqc0l6m0kxkunp6rjn9       complete        9m8hh96du7220yxtv65a8840q       172.22.68.27/mattxps

   e. You can submit new workers to the swarm by creating a service that
      would run runWorker.pl::

          docker service create --name=worker --replicas=1 --restart-condition=none ensemblorg/ensembl-hive-docker-swarm runWorker.pl -url $EHIVE_URL



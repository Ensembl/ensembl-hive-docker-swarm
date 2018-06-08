Packaging instructions
======================

.. important::
   This document assumes you have already package your own code
   and its dependencies in a Docker image, or know how to do it.

First of all, you may need to encode the Resource Classes of your pipeline
with the DockerSwarm syntax: by default, the meadow will otherwise request
just one CPU and not constraint the memory.

The Resource Class should be a stringified Perl hash. As of the `version
1.30 of the Docker Engine API
<https://docs.docker.com/engine/api/v1.30/#operation/ServiceCreate>`__,
these parameters are accepted:

.. code-block:: perl

    {
        'Limits'  => {
            'NanoCPUs'     => 1000000000,       # 1 CPU
            'MemoryBytes'  => 1073741824,       # 1 GiB
        },
        'Reservations'  => {
            'NanoCPUs'     => 1000000000,       # 1 CPU
            'MemoryBytes'  => 1073741824,       # 1 GiB
        },
    }

Then, it is a matter of packaging the application as a Docker image.
The Dockerfile should essentially be a merge of both ensembl-hive's
and ensembl-hive-docker-swarm's Dockerfiles.
Here's how it might look::

    # NOTE-1
    FROM ${BASE_IMAGE_NAME}

    # NOTE-2
    # Install git
    ARG DEBIAN_FRONTEND=noninteractive
    RUN apt-get update -y && apt-get install -y git && apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

    # NOTE-3
    # Clone the repos
    RUN mkdir /repo \
        && git clone -b version/2.5 https://github.com/Ensembl/ensembl-hive.git /repo/ensembl-hive \
        && git clone -b version/2.5 https://github.com/Ensembl/ensembl-hive-docker-swarm.git /repo/ensembl-hive-docker-swarm

    # NOTE-4
    # Install all the dependencies
    RUN /repo/ensembl-hive/docker/setup_os.Ubuntu-16.04.sh \
        && /repo/ensembl-hive/docker/setup_cpan.Ubuntu-16.04.sh /repo/ensembl-hive /repo/ensembl-hive-docker-swarm

    # NOTE-5
    # Setup eHive (image name, and installation path)
    COPY hive_config.json /root/.hive_config.json

    ENV EHIVE_ROOT_DIR "/repo/ensembl-hive"
    ENV PATH "/repo/ensembl-hive/scripts:$PATH"
    ENV PERL5LIB "/repo/ensembl-hive-docker-swarm/modules:/repo/ensembl-hive/modules:$PERL5LIB"

    # NOTE-6
    ENTRYPOINT [ "/repo/ensembl-hive/scripts/dev/simple_init.py" ]
    CMD [ "/bin/bash" ]

Comments:

1. You will have to either replace ``${BASE_IMAGE_NAME}`` with your own
   image or include the instructions to install and setup your own code.

2. If ``git`` is already installed, you obviously don't need to install it
   again.

3. Instead of the master branch, you should probably use one of the
   released, stable, branches (e.g. ``version/2.5``). For reproducibility,
   you can also consider using specific commits.

4. eHive comes with a scripts to setup a few OSes (e.g. Ubuntu-16.04,
   CentOS-7). If your OS is not listed, write a script to adapt
   these.

5. The configuration file is a JSON file that mostly tells eHive the name
   of the image it will be running. You can also set up the path to
   :ref:`runWorker.pl <script-runWorker>` in case you can't setup $PATH correctly, and define
   mount-points that are needed by your application.

   .. code-block:: json

        {
            "Meadow" : {
                "DockerSwarm" : {
                    "ImageName"     : "ensemblorg/ensembl-hive-docker-swarm",
                    "RunWorkerPath" : "/repo/ensembl-hive/scripts/",
                    "Mounts"        : [
                        {
                            "Type"      : "bind",
                            "Source"    : "/opt/deps",
                            "Target"    : "/opt/deps"
                        }
                    ]
                }
            }
        }

6. An "init" system is required for Beekeeper to run "LOCAL" Workers. It is
   also generally required if your application contains services or
   daemons.  eHive's minimalistic script only ensures that all the
   processes are properly ripped.

That's it! You're all set to build or push your new image to a hub.
Then, simply come back to our :ref:`docker-swarm-tutorial`, replacing both
the image name and the PipeConfig name.

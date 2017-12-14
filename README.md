
Docker Swarm Meadow for eHive
==============================

[eHive](https://github.com/Ensembl/ensembl-hive) is a system for running computation pipelines on distributed computing resources - clusters, farms or grids.
This repository is the implementation of eHive's _Meadow_ interface for the [Docker Swarm](https://docs.docker.com/engine/swarm/swarm-tutorial/) container orchestrator.

Version numbering and compatibility
-----------------------------------

This repository is versioned the same way as eHive itself, and both
checkouts are expected to be on the same branch name to function properly.
* `master` is the development branch and follows eHive's `master`. We
  primarily maintain eHive, so both repos may sometimes go out of sync
  until we upgrade the DockerSwarm module too
When future stable versions of eHive will be released (named `version/2.5`
etc) we'll create such branches here as well.

Testing the Docker Swarm meadow
-------------------------------

Find the documentation on ensembl-hive's [user
manual](http://ensembl-hive.readthedocs.io/en/master/contrib/docker-swarm/tutorial.html)

Contributors
------------

This module has been written by [Leo Gordon](https://github.com/ens-lg4)
and [Matthieu Muffato](https://github.com/ensemblorg) (EMBL-EBI).


Contact us
----------

eHive is maintained by the [Ensembl](http://www.ensembl.org/info/about/) project.
We (Ensembl) are only using Platform LSF to run our computation
pipelines, and have only tried Docker Swarm on toy examples.

There is eHive users' mailing list for questions, suggestions, discussions and announcements.
To subscribe to it please visit [this link](http://listserver.ebi.ac.uk/mailman/listinfo/ehive-users)


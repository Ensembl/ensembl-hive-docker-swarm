
Docker Swarm Meadow for eHive
==============================

> [!IMPORTANT]  
> As per eHive version 2.7.0, all the meadows other than `SLURM` and `Local` are deprecated and not supported anymore.
> This repository should remain in sync with eHive's `version/2.6`, as we do not plan to apply any change to it.
> `main` branch will instead get out of sync, because of the changes we apply to eHive's.
> Please, do not hesitate to contact us, should this be a problem.

[eHive](https://github.com/Ensembl/ensembl-hive) is a system for running computation pipelines on distributed computing resources - clusters, farms or grids.
This repository is the implementation of eHive's _Meadow_ interface for the [Docker Swarm](https://docs.docker.com/engine/swarm/swarm-tutorial/) container orchestrator.

Version numbering and compatibility
-----------------------------------

This repository is versioned the same way as eHive itself, and both
checkouts are expected to be on the same branch name to function properly.
* `version/2.5`, `version/2.6`, etc. are stable branches that work with eHive's
  branches of the same name. These branches are _stable_ and _only_ receive bugfixes.
* `main` is the development branch and follows eHive's `main`. We
  primarily maintain eHive, so both repos may sometimes go out of sync
  until we upgrade the DockerSwarm module too

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
We (Ensembl) are only using SLURM to run our computation
pipelines, and have only tried Docker Swarm on toy examples.

There is eHive users' mailing list for questions, suggestions, discussions and announcements.
To subscribe to it please visit [this link](http://listserver.ebi.ac.uk/mailman/listinfo/ehive-users)


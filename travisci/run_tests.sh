#!/bin/bash

# Stop the script at the first failure
set -e

export EHIVE_ROOT_DIR=$PWD/ensembl-hive
export PERL5LIB=$EHIVE_ROOT_DIR/modules:$PWD/modules
export EHIVE_MEADOW_TO_TEST=DockerSwarm

export DOCKER_MASTER_ADDR=$(docker swarm join-token worker | awk '$0 ~/docker swarm join/ {gsub("2377", "2375", $NF); print $NF}')
export EHIVE_TEST_PIPELINE_URLS="mysql://travis@${DOCKER_MASTER_ADDR//2375/3306}/"

echo "DEBUG: Environment of $0"; env; id; echo "END_DEBUG"

$EHIVE_ROOT_DIR/scripts/beekeeper.pl -version

prove -rv --ext .t --ext .mt "$EHIVE_ROOT_DIR/t/04.meadow/meadow-longmult.mt"


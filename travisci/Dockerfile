# Dockerfile to build a custom version of the image with the latest
# DockerSwarm code and the right configuration to run it under TravisCI

# Start from the base image which has all the dependencies
FROM ensemblorg/ensembl-hive-docker-swarm

# Update the Meadow
RUN rm -rf /repo/ensembl-hive-docker-swarm/modules
COPY modules /repo/ensembl-hive-docker-swarm/modules


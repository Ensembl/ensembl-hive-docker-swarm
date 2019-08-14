# This is a Dockerfile to extend the basic eHive image with the modules to
# work under Docker Swarm

# 1. Get the current ensembl-hive-docker-swarm repo and remove stuff we don't want
FROM alpine:3.9.4 AS repo
RUN apk add git
ADD . /tmp/ensembl-hive-docker-swarm
# git clean will remove things listed in .gitignore, incl. .pyc, .jar etc
# but will leave local modifications and other files, thus allowing local tests
RUN cd /tmp/ensembl-hive-docker-swarm && git clean -d -X -f
RUN rm -rf /tmp/ensembl-hive-docker-swarm/.git


# 2. Make the real image
FROM ensemblorg/ensembl-hive

# Copy the repo
COPY --from=repo /tmp/ensembl-hive-docker-swarm /repo/ensembl-hive-docker-swarm

# Currently there are no Perl dependencies
#RUN /repo/ensembl-hive/docker/setup_cpan.Ubuntu-16.04.sh /repo/ensembl-hive-docker-swarm

# Expand PERL5LIB
ENV PERL5LIB "/repo/ensembl-hive-docker-swarm/modules:$PERL5LIB"

# Setup eHive (image name, and installation path)
COPY docker/hive_config.json /root/.hive_config.json


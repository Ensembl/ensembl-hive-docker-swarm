# This is a Dockerfile to extend the basic eHive image with the modules to
# work under Docker Swarm

FROM ensemblorg/ensembl-hive

# Clone the repo
ADD . /repo/ensembl-hive-docker-swarm

# Currently there are no Perl dependencies
#RUN /repo/ensembl-hive/docker/setup_cpan.Ubuntu-16.04.sh /repo/ensembl-hive-docker-swarm

# Expand PERL5LIB
ENV PERL5LIB "/repo/ensembl-hive-docker-swarm/modules:$PERL5LIB"

# Setup eHive (image name, and installation path)
COPY docker/hive_config.json /root/.hive_config.json


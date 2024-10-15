#!/usr/bin/env perl
# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2024] EMBL-European Bioinformatics Institute
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#      http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


# An equivalent of 'bjobs' for Docker Swarm meadow
#
# For REST API documentation see  https://docs.docker.com/engine/api/v1.30/

use strict;
use warnings;
use Bio::EnsEMBL::Hive::Utils::RESTclient;

my $docker_master_addr      = $ENV{DOCKER_MASTER_ADDR}
    || die "Please make sure the environment variable DOCKER_MASTER_ADDR is set to your Docker Master's IP followed by colon and Docker REST port number (usually 2375)\n";

my $optional_service_name   = $ARGV[0];     # this is the only optional argument of this script

my $common_url              = "http://$docker_master_addr/v1.30";
my $rest_client             = Bio::EnsEMBL::Hive::Utils::RESTclient->new( $common_url );

my $swarm_id                = $rest_client->GET( '/swarm' )->{'ID'};

my $nodes_listref           = $rest_client->GET( '/nodes' );
#my %node_id2addr            = map { $_->{'ID'} => $_->{'Status'}{'Addr'} } @$nodes_listref;
#my %node_id2name            = map { $_->{'ID'} => $_->{'Description'}{'Hostname'} } @$nodes_listref;    # NB: these are not unique!
my %node_id2addrname        = map { $_->{'ID'} => $_->{'Status'}{'Addr'} .'/'. $_->{'Description'}{'Hostname'} } @$nodes_listref;

my $services_listref        = $rest_client->GET( '/services', 'services.json');
my %service_id2name         = map { $_->{'ID'} => $_->{'Spec'}{'Name'} } @$services_listref;

my $service_tasks_list      = $optional_service_name
                                ? $rest_client->GET( '/tasks?filters={"name":["' . $optional_service_name . '"]}' )     # either filtered data...
                                : $rest_client->GET( '/tasks' );                                                        # ... or all available task data

print join("\t",    'Service_ID', 'Service_name_and_index', 'Task_ID', 'Status', 'Node_ID', 'Node_name')."\n";
foreach my $entry (sort { ($a->{'ServiceID'} cmp $b->{'ServiceID'}) or ($a->{'Slot'} <=> $b->{'Slot'}) } @$service_tasks_list) {
    my $service_id      = $entry->{'ServiceID'};
    my $service_name    = $service_id2name{ $service_id };
    my $slot            = $entry->{'Slot'};
    my $task_id         = $entry->{'ID'};
    my $status          = $entry->{'Status'}{'State'};
    my $node_id         = $entry->{'NodeID'};
    my $node_name       = $node_id && $node_id2addrname{ $node_id };

    print join("\t",    $service_id, $service_name.'['.$slot.']', $task_id, $status, $node_id || '-', $node_name || '-')."\n";
}

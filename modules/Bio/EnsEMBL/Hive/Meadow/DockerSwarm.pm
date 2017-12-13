=pod 

=head1 NAME

    Bio::EnsEMBL::Hive::Meadow::DockerSwarm

=head1 DESCRIPTION

    This is the implementation of Meadow for a Swarm or Docker Engines

=head1 LICENSE

    Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
    Copyright [2016-2017] EMBL-European Bioinformatics Institute

    Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License.
    You may obtain a copy of the License at

         http://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing, software distributed under the License
    is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and limitations under the License.

=head1 CONTACT

    Please subscribe to the Hive mailing list:  http://listserver.ebi.ac.uk/mailman/listinfo/ehive-users  to discuss Hive-related questions or to be notified of our updates

=cut


package Bio::EnsEMBL::Hive::Meadow::DockerSwarm;

use strict;
use warnings;
use Cwd ('cwd');
use Bio::EnsEMBL::Hive::Utils ('split_for_bash');

use base ('Bio::EnsEMBL::Hive::Utils::RESTclient', 'Bio::EnsEMBL::Hive::Meadow');


our $VERSION = '5.1';       # Semantic version of the Meadow interface:
                            #   change the Major version whenever an incompatible change is introduced,
                            #   change the Minor version whenever the interface is extended, but compatibility is retained.

sub construct_base_url {
    my $dma = $ENV{'DOCKER_MASTER_ADDR'};
    return $dma && "http://$dma/v1.30";
}


sub new {
    my $class   = shift @_;

    my $self    = $class->SUPER::new( $class->construct_base_url );     # First construct a RESTclient extension,
    $self->_init_meadow( @_ );                                          # then top it up with Meadowy things
    $self->{_DOCKER_MASTER_ADDR} = $ENV{'DOCKER_MASTER_ADDR'};          # saves the location of the manager node

    return $self;
}


sub name {  # also called to check for availability
    my ($self) = @_;

    my $url = '';
    unless (ref($self)) {
        # Object instances have defined the base URL in the parent class
        $url = $self->construct_base_url;
        return undef unless $url;
    }
    $url .= '/swarm';

    my $swarm_attribs   = $self->GET( $url ) || {};

    return $swarm_attribs->{'ID'};
}


sub _get_our_task_attribs {
    my ($self) = @_;

    my $container_prefix    = `hostname`; chomp $container_prefix;
    my $tasks_list          = $self->GET( '/tasks' );
    my ($our_task_attribs)  = grep { ($_->{'Status'}{'ContainerStatus'}{'ContainerID'} || '') =~ /^${container_prefix}/ } @$tasks_list;

    return $our_task_attribs;
}


sub get_current_hostname {
    my ($self) = @_;

    my $nodes_list          = $self->GET( '/nodes' );
    my %node_id_2_ip        = map { ($_->{'ID'} => $_->{'Status'}{'Addr'}) } @$nodes_list;
    my $our_node_ip         = $node_id_2_ip{ $self->_get_our_task_attribs()->{'NodeID'} };

    return $our_node_ip;
}


sub get_current_worker_process_id {
    my ($self) = @_;

    my $our_task_id         = $self->_get_our_task_attribs()->{'ID'};

    return $our_task_id;
}


sub deregister_local_process {
    my $self = shift @_;
    # so that the LOCAL child processes don't think they belong to the DockerSwarm meadow
    delete $ENV{'DOCKER_MASTER_ADDR'};
}


sub status_of_all_our_workers { # returns an arrayref
    my ($self) = @_;

    # my $service_tasks_struct    = $self->GET( '/tasks?filters={"name":["' . $service_name . '"]}' );
    my $service_tasks_struct    = $self->GET( '/tasks' );

    my @status_list = ();
    foreach my $task_entry (@$service_tasks_struct) {
        my $slot        = $task_entry->{'Slot'};                # an index within the given service
        my $task_id     = $task_entry->{'ID'};
        my $prestatus   = lc $task_entry->{'Status'}{'State'};

        # Some statuses are explained at https://docs.docker.com/datacenter/ucp/2.2/guides/admin/monitor-and-troubleshoot/troubleshoot-task-state/
        my $status      = {
                            'new'       => 'PEND',
                            'pending'   => 'PEND',
                            'assigned'  => 'PEND',
                            'accepted'  => 'PEND',
                            'preparing' => 'RUN',
                            'starting'  => 'RUN',
                            'running'   => 'RUN',
                            'complete'  => 'DONE',
                            'shutdown'  => 'DONE',
                            'failed'    => 'EXIT',
                            'rejected'  => 'EXIT',
                            'orphaned'  => 'EXIT',
                        }->{$prestatus} || $prestatus;

        push @status_list, [ $task_id, 'docker_user', $status ];
    }

    return \@status_list;
}


#sub check_worker_is_alive_and_mine {
#    my ($self, $worker) = @_;
#
#    my $wpid = $worker->process_id();
#    my $is_alive_and_mine = kill 0, $wpid;
#
#    return $is_alive_and_mine;
#}
#
#
#sub kill_worker {
#    my ($self, $worker, $fast) = @_;
#
#    system('kill', '-9', $worker->process_id());
#}


sub submit_workers_return_meadow_pids {
    my ($self, $worker_cmd, $required_worker_count, $iteration, $rc_name, $rc_specific_submission_cmd_args, $submit_log_subdir) = @_;

    my $worker_cmd_components = [ split_for_bash($worker_cmd) ];

    my $job_array_common_name = $self->job_array_common_name($rc_name, $iteration);

    # Name collision detection
    my $extra_suffix = 0;
    my $service_name = $job_array_common_name;
    while (scalar(@{ $self->GET( '/tasks?filters={"name":["' . $service_name . '"]}' ) })) {
        $extra_suffix++;
        $service_name = "$job_array_common_name-$extra_suffix";
    }
    if ($extra_suffix) {
        warn "'$job_array_common_name' already used to name a service. Using '$service_name' instead.\n";
        $job_array_common_name = $service_name;
    }

    my $service_create_data = {
        'Name'          => $job_array_common_name,      # NB: service names in DockerSwarm have to be unique!
        'TaskTemplate'  => {
            'ContainerSpec' => {
                'Image'     => $self->config_get('ImageName'),
                'Args'      => $worker_cmd_components,
                'Mounts'    => $self->config_get('Mounts'),
                'Env'       => [
                               "DOCKER_MASTER_ADDR=$self->{'_DOCKER_MASTER_ADDR'}",             # propagate it to the workers
                               "EHIVE_PASS=$ENV{'EHIVE_PASS'}",                                 # -----------,,--------------
                               $submit_log_subdir ? ("REPORT_DIR=${submit_log_subdir}") : (),   # FIXME: temporary?
                ],
            },
            'Resources'     => {
                'Reservations'  => {
                    'NanoCPUs'  => 1000000000,
                },
            },
            'RestartPolicy' => {
                'Condition' => 'none',
            },
        },
        'Mode'          => {
            'Replicated'    => {
                'Replicas'  => int($required_worker_count),
            },
        },
    };

    my $service_created_struct  = $self->POST( '/services/create', $service_create_data );
#    my $service_id              = $service_created_struct->{'ID'};

    my $service_tasks_list      = $self->GET( '/tasks?filters={"name":["' . $job_array_common_name . '"]}' );

    my @children_task_ids       = map { $_->{'ID'} } @$service_tasks_list;

    return \@children_task_ids;
}


sub run_on_host {   # Overrides Meadow::run_on_host ; not supported yet - it's just a placeholder to block the base class' functionality
    my ($self, $meadow_host, $meadow_user, $command) = @_;

    return undef;
}

1;

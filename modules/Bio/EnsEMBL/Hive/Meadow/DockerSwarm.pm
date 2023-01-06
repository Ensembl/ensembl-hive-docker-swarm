=pod 

=head1 NAME

Bio::EnsEMBL::Hive::Meadow::DockerSwarm

=head1 DESCRIPTION

    This is the implementation of Meadow for a Swarm or Docker Engines

=head1 LICENSE

    Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
    Copyright [2016-2023] EMBL-European Bioinformatics Institute

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
use Bio::EnsEMBL::Hive::Utils ('destringify', 'split_for_bash', 'stringify');

use base ('Bio::EnsEMBL::Hive::Meadow', 'Bio::EnsEMBL::Hive::Utils::RESTclient');


our $VERSION = '5.2';       # Semantic version of the Meadow interface:
                            #   change the Major version whenever an incompatible change is introduced,
                            #   change the Minor version whenever the interface is extended, but compatibility is retained.

sub construct_base_url {
    my $dma = $ENV{'DOCKER_MASTER_ADDR'};
    return $dma && "http://$dma/v1.30";
}


sub new {
    my $class   = shift @_;

    my $self    = $class->SUPER::new( @_ );                             # First construct a Meadow
    $self->base_url( $class->construct_base_url // '' );                # Then initialise the RESTclient extension
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

    return $self->{_task_attribs} if $self->{_task_attribs};

    # Get the container ID. Although in simple cases, the hostname is the same as
    # the container ID, it is not always true. So we need to dig into cgroup stuff

# # docker node ls
# ID                            HOSTNAME            STATUS              AVAILABILITY        MANAGER STATUS      ENGINE VERSION
# lcprncbmd0z1523t0ft8ej9uy *   head-node           Ready               Active              Leader              18.09.0
# ksactwapa4nxaaokcj1xw62pr     worker-1            Ready               Active                                  18.09.0
# wcms6zxgq0hocoutznggs9r0u     worker-2            Ready               Active                                  18.09.0
# ior43tdjz9x7n4bzzmr5njvcr     worker-3            Ready               Active                                  18.09.0
# l6khe63f71z3ntv4abii3n9o1     worker-4            Ready               Active                                  18.09.0
# nvmy341e4a3sqtt9k3cfdmc7w     worker-5            Ready               Active                                  18.09.0
# w42pyk5wvoa0qrzbnjhn1yyt7     worker-6            Ready               Active                                  18.09.0
# 28h1sk9zwkw53bkv4bi95q2f1     worker-7            Ready               Active                                  18.09.0
# rldg2wm4h19oo9cxxrdbpx5n4     worker-8            Ready               Active                                  18.09.0
# 72cv6frnei4gjdv3p3l8bmd3c     worker-9            Ready               Active                                  18.09.0
# u21fny9eapmh09sflk45zzscz     worker-10           Ready               Active                                  18.09.0

# # cat /proc/self/cgroup
#13:name=systemd:/docker/c8ecf8b2f3f2a26543971b57fd37205164a19908871d7bd43405914fcd054bfd
#12:pids:/docker/c8ecf8b2f3f2a26543971b57fd37205164a19908871d7bd43405914fcd054bfd
#11:hugetlb:/docker/c8ecf8b2f3f2a26543971b57fd37205164a19908871d7bd43405914fcd054bfd
#10:net_prio:/docker/c8ecf8b2f3f2a26543971b57fd37205164a19908871d7bd43405914fcd054bfd
#9:perf_event:/docker/c8ecf8b2f3f2a26543971b57fd37205164a19908871d7bd43405914fcd054bfd
#8:net_cls:/docker/c8ecf8b2f3f2a26543971b57fd37205164a19908871d7bd43405914fcd054bfd
#7:freezer:/docker/c8ecf8b2f3f2a26543971b57fd37205164a19908871d7bd43405914fcd054bfd
#6:devices:/docker/c8ecf8b2f3f2a26543971b57fd37205164a19908871d7bd43405914fcd054bfd
#5:memory:/docker/c8ecf8b2f3f2a26543971b57fd37205164a19908871d7bd43405914fcd054bfd
#4:blkio:/docker/c8ecf8b2f3f2a26543971b57fd37205164a19908871d7bd43405914fcd054bfd
#3:cpuacct:/docker/c8ecf8b2f3f2a26543971b57fd37205164a19908871d7bd43405914fcd054bfd
#2:cpu:/docker/c8ecf8b2f3f2a26543971b57fd37205164a19908871d7bd43405914fcd054bfd
#1:cpuset:/docker/c8ecf8b2f3f2a26543971b57fd37205164a19908871d7bd43405914fcd054bfd

    open(my $fh, '<', '/proc/self/cgroup');
    my $container_prefix;
    while (<$fh>) {
        if (m{:/docker/(.*)$}) {
            $container_prefix = $1;
            last;
        }
    }
    # Not running in a container
    return unless $container_prefix;

    my $tasks_list          = $self->GET( '/tasks' );
    my ($our_task_attribs)  = grep { ($_->{'Status'}{'ContainerStatus'}{'ContainerID'} || '') =~ /^${container_prefix}/ } @$tasks_list;
    $self->{_task_attribs}  = $our_task_attribs;

    return $self->{_task_attribs};
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

sub type_resources_as_numeric {

    # In Perl, large numbers would be stringified as strings by stringify
    # and then JSON. Here we force them to be numeric
    #
    # 'Resources' => {
    #     'Reservations' => {
    #         'NanoCPUs' => 1000000000,
    #         'MemoryBytes' => '34359738368'
    #     },
    #     'Limits' => {
    #         'NanoCPUs' => 1000000000,
    #         'MemoryBytes' => '34359738368'
    #     }
    # }
    #

    my $resources = shift;

    if (exists $resources->{'Reservations'}) {
        $resources->{'Reservations'}->{'NanoCPUs'}      += 0 if exists $resources->{'Reservations'}->{'NanoCPUs'};
        $resources->{'Reservations'}->{'MemoryBytes'}   += 0 if exists $resources->{'Reservations'}->{'MemoryBytes'};
    }
    if (exists $resources->{'Limits'}) {
        $resources->{'Limits'}->{'NanoCPUs'}    += 0 if exists $resources->{'Limits'}->{'NanoCPUs'};
        $resources->{'Limits'}->{'MemoryBytes'} += 0 if exists $resources->{'Limits'}->{'MemoryBytes'};
    }
}


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

    die "The image name for the ".$self->name." DockerSwarm meadow is not configured. Cannot submit jobs !" unless $self->config_get('ImageName');

    # If the resource description is missing, use 1 core
    my $default_resources = {
        'Reservations'  => {
            'NanoCPUs'  => 1_000_000_000,
        },
    };
    my $resources = destringify($rc_specific_submission_cmd_args);

    my $service_create_data = {
        'Name'          => $job_array_common_name,      # NB: service names in DockerSwarm have to be unique!
        'TaskTemplate'  => {
            'ContainerSpec' => {
                'Image'     => $self->config_get('ImageName'),
                'Args'      => $worker_cmd_components,
                'Mounts'    => $self->config_get('Mounts'),
                'Env'       => [
                                # Propagate these to the workers
                               "DOCKER_MASTER_ADDR=$self->{'_DOCKER_MASTER_ADDR'}",
                               "_EHIVE_HIDDEN_PASS=$ENV{'_EHIVE_HIDDEN_PASS'}",
                ],
            },
            # NOTE: By default, docker alway keeps logs. Should we disable them here
            #       $submit_log_subdir has been set ? There are no options to redirect
            #       the logs, so the option's value would be ignored.
            #'LogDriver' => {
                #'Name'      => 'none',
            #},
            'Resources'     => $resources || $default_resources,
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
    type_resources_as_numeric($service_create_data->{'TaskTemplate'}->{'Resources'});

    my $service_created_struct  = $self->POST( '/services/create', $service_create_data );
    unless (exists $service_created_struct->{'ID'}) {
        die "Submission unsuccessful: " . ($service_created_struct->{'message'} // stringify($service_created_struct)) . "\n";
    }

    # Give some time to the Docker daemon to process the request
    sleep(5);

    my $service_id              = $service_created_struct->{'ID'};
    my $service_tasks_list      = $self->GET( qq{/tasks?filters={"service":["$service_id"]}} );
    if (scalar(@$service_tasks_list) != int($required_worker_count)) {
        die "Submission unsuccessful: found " . scalar(@$service_tasks_list) . " tasks instead of " . int($required_worker_count) . "\n";
    }

    my @children_task_ids       = map { $_->{'ID'} } @$service_tasks_list;

    return \@children_task_ids;
}


sub run_on_host {   # Overrides Meadow::run_on_host ; not supported yet - it's just a placeholder to block the base class' functionality
    my ($self, $meadow_host, $meadow_user, $command) = @_;

    return undef;
}

1;

package Thruk::Controller::extinfo;

use strict;
use warnings;
use utf8;
use parent 'Catalyst::Controller';
use Data::Page;

=head1 NAME

Thruk::Controller::extinfo - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 index

=cut

##########################################################
sub index :Path :Args(0) :MyAction('AddDefaults') {
    my ( $self, $c ) = @_;
    my $type = $c->{'request'}->{'parameters'}->{'type'} || 0;

    my $infoBoxTitle;
    if($type == 0) {
        $infoBoxTitle = 'Process Information';
        $c->detach('/error/index/1') unless $c->check_user_roles( "authorized_for_system_information" );
        $self->_process_process_info_page($c);
    }
    if($type == 1) {
        $infoBoxTitle = 'Host Information';
        $self->_process_host_page($c);
    }
    if($type == 2) {
        $infoBoxTitle = 'Service Information';
        $self->_process_service_page($c);
    }
    if($type == 3) {
        $infoBoxTitle = 'All Host and Service Comments';
        $self->_process_comments_page($c);
    }
    if($type == 4) {
        $infoBoxTitle = 'Performance Information';
        $self->_process_perf_info_page($c);
    }
    if($type == 5) {
        $infoBoxTitle = 'Hostgroup Information';
        $self->_process_hostgroup_cmd_page($c);
    }
    if($type == 6) {
        $infoBoxTitle = 'All Host and Service Scheduled Downtime';
        $self->_process_downtimes_page($c);
    }
    if($type == 7) {
        $infoBoxTitle = 'Check Scheduling Queue';
        $self->_process_scheduling_page($c);
    }
    if($type == 8) {
        $infoBoxTitle = 'Servicegroup Information';
        $self->_process_servicegroup_cmd_page($c);
    }

    $c->stash->{title}          = 'Extended Information';
    $c->stash->{infoBoxTitle}   = $infoBoxTitle;
    $c->stash->{page}           = 'extinfo';
    $c->stash->{template}       = 'extinfo_type_'.$type.'.tt';

    Thruk::Utils::ssi_include($c);

    return 1;
}


##########################################################
# SUBS
##########################################################

##########################################################
# create the downtimes page
sub _process_comments_page {
    my ( $self, $c ) = @_;
    $c->stash->{'hostcomments'}    = $c->{'db'}->get_comments(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'comments'), { 'service_description' => undef }]);
    $c->stash->{'servicecomments'} = $c->{'db'}->get_comments(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'comments'), { 'service_description' => { '!=' => undef } }]);
    return 1;
}

##########################################################
# create the downtimes page
sub _process_downtimes_page {
    my ( $self, $c ) = @_;
    $c->stash->{'hostdowntimes'}    = $c->{'db'}->get_downtimes(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'downtimes'), { 'service_description' => undef }]);
    $c->stash->{'servicedowntimes'} = $c->{'db'}->get_downtimes(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'downtimes'), { 'service_description' => { '!=' => undef } }]);
    return 1;
}

##########################################################
# create the host info page
sub _process_host_page {
    my ( $self, $c ) = @_;
    my $host;

    my $backend  = $c->{'request'}->{'parameters'}->{'backend'};
    my $hostname = $c->{'request'}->{'parameters'}->{'host'};
    return $c->detach('/error/index/5') unless defined $hostname;
    my $hosts = $c->{'db'}->get_hosts(filter => [Thruk::Utils::Auth::get_auth_filter($c, 'hosts'),
                                                 { 'name' => $hostname }]
                                     );

    return $c->detach('/error/index/5') unless defined $hosts;

    # we only got one host
    $host = $hosts->[0];
    # we have more and backend param is used
    if(scalar @{$hosts} == 1 and defined $backend) {
        for my $h (@{$hosts}) {
            if($h->{'peer_key'} eq $backend) {
                $host = $h;
                last;
            }
        }
    }

    return $c->detach('/error/index/5') unless defined $host;

    my @backends;
    for my $h (@{$hosts}) {
        push @backends, $h->{'peer_key'};
    }
    $self->_set_backend_selector($c, \@backends, $host->{'peer_key'});

    $c->stash->{'host'}     = $host;
    my $comments   = $c->{'db'}->get_comments(filter =>  [Thruk::Utils::Auth::get_auth_filter($c, 'comments'),
                                                         { 'host_name' => $hostname },
                                                         { 'service_description' => undef }],
                                              sort   =>  {'id' => 'DESC'});
    my $downtimes  = $c->{'db'}->get_downtimes(filter => [Thruk::Utils::Auth::get_auth_filter($c, 'downtimes'),
                                                         { 'host_name' => $hostname },
                                                         { 'service_description' => undef }],
                                               sort   => {'id' => 'DESC'});

    $c->stash->{'comments'}  = $comments;
    $c->stash->{'downtimes'} = $downtimes;

    return 1;
}

##########################################################
# create the hostgroup cmd page
sub _process_hostgroup_cmd_page {
    my ( $self, $c ) = @_;

    my $hostgroup = $c->{'request'}->{'parameters'}->{'hostgroup'};
    return $c->detach('/error/index/5') unless defined $hostgroup;

    my $groups = $c->{'live'}->selectall_hashref("GET hostgroups\n".Thruk::Utils::Auth::get_auth_filter($c, 'hostgroups')."\nColumns: name alias\nFilter: name = $hostgroup\nLimit: 1", 'name');
    my @groups = values %{$groups};
    return $c->detach('/error/index/5') unless defined $groups[0];

    $c->stash->{'hostgroup'}       = $groups[0]->{'name'};
    $c->stash->{'hostgroup_alias'} = $groups[0]->{'alias'};
    return 1;
}

##########################################################
# create the service info page
sub _process_service_page {
    my ( $self, $c ) = @_;
    my $service;
    my $backend  = $c->{'request'}->{'parameters'}->{'backend'};

    my $hostname = $c->{'request'}->{'parameters'}->{'host'};
    return $c->detach('/error/index/15') unless defined $hostname;

    my $servicename = $c->{'request'}->{'parameters'}->{'service'};
    return $c->detach('/error/index/15') unless defined $servicename;

    my $services = $c->{'db'}->get_services(filter => [Thruk::Utils::Auth::get_auth_filter($c, 'services'),
                                                      { 'host_name' => $hostname },
                                                      { 'description' => $servicename },
                                                ]
                                     );

    return $c->detach('/error/index/15') unless defined $services;

    # we only got one service
    $service = $services->[0];
    # we have more and backend param is used
    if(scalar @{$services} == 1 and defined $services) {
        for my $s (@{$services}) {
            if($s->{'peer_key'} eq $backend) {
                $service = $s;
                last;
            }
        }
    }

    return $c->detach('/error/index/15') unless defined $service;

    my @backends;
    for my $s (@{$services}) {
        push @backends, $s->{'peer_key'};
    }
    $self->_set_backend_selector($c, \@backends, $service->{'peer_key'});

    $c->stash->{'service'}  = $service;


    my $comments   = $c->{'db'}->get_comments(filter =>  [Thruk::Utils::Auth::get_auth_filter($c, 'comments'),
                                                         { 'host_name' => $hostname },
                                                         { 'service_description' => $servicename }],
                                              sort   =>  {'id' => 'DESC'});
    my $downtimes  = $c->{'db'}->get_downtimes(filter => [Thruk::Utils::Auth::get_auth_filter($c, 'downtimes'),
                                                         { 'host_name' => $hostname },
                                                         { 'service_description' => $servicename }],
                                               sort   => {'id' => 'DESC'});
    $c->stash->{'comments'} = $comments;
    $c->stash->{'downtimes'} = $downtimes;

    return 1;
}

##########################################################
# create the servicegroup cmd page
sub _process_servicegroup_cmd_page {
    my ( $self, $c ) = @_;

    my $servicegroup = $c->{'request'}->{'parameters'}->{'servicegroup'};
    return $c->detach('/error/index/5') unless defined $servicegroup;

    my $groups = $c->{'live'}->selectall_hashref("GET servicegroups\n".Thruk::Utils::Auth::get_auth_filter($c, 'servicegroups')."\nColumns: name alias\nFilter: name = $servicegroup\nLimit: 1", 'name');
    my @groups = values %{$groups};
    $c->detach('/error/index/5') unless defined $groups[0];

    $c->stash->{'servicegroup'}       = $groups[0]->{'name'};
    $c->stash->{'servicegroup_alias'} = $groups[0]->{'alias'};

    return 1;
}

##########################################################
# create the scheduling page
sub _process_scheduling_page {
    my ( $self, $c ) = @_;

    my $sorttype   = $c->{'request'}->{'parameters'}->{'sorttype'}   || 1;
    my $sortoption = $c->{'request'}->{'parameters'}->{'sortoption'} || 7;

    my $order = "ASC";
    $order = "DESC" if $sorttype == 2;

    my $sortoptions = {
                '1' => [ ['host_name', 'description'],   'host name'       ],
                '2' => [ 'description',                  'service name'    ],
                '4' => [ 'last_check',                   'last check time' ],
                '7' => [ 'next_check',                   'next check time' ],
    };
    $sortoption = 7 if !defined $sortoptions->{$sortoption};

    my $services = $c->{'live'}->selectall_arrayref("GET services\n".Thruk::Utils::Auth::get_auth_filter($c, 'services')."\nColumns: host_name description next_check last_check check_options active_checks_enabled\nFilter: active_checks_enabled = 1\nFilter: check_options != 0\nOr: 2", { Slice => {} });
    my $hosts    = $c->{'live'}->selectall_arrayref("GET hosts\n".Thruk::Utils::Auth::get_auth_filter($c, 'hosts')."\nColumns: name next_check last_check check_options active_checks_enabled\nFilter: active_checks_enabled = 1\nFilter: check_options != 0\nOr: 2", { Slice => {}, rename => { 'name' => 'host_name' } });

    if(defined $services and defined $hosts) {
        my $queue    = Thruk::Utils::sort($c, [@{$hosts}, @{$services}], $sortoptions->{$sortoption}->[0], $order);
        Thruk::Utils::page_data($c, $queue);
    }

    $c->stash->{'order'}   = $order;
    $c->stash->{'sortkey'} = $sortoptions->{$sortoption}->[1];

    return 1;
}


##########################################################
# create the process info page
sub _process_process_info_page {
    my ( $self, $c ) = @_;

    return $c->detach('/error/index/1') unless $c->check_user_roles( "authorized_for_system_information" );
    return 1;
}

##########################################################
# create the performance info page
sub _process_perf_info_page {
    my ( $self, $c ) = @_;

    my $stats      = Thruk::Utils::get_service_execution_stats_old($c);
    my $live_stats = $c->{'live'}->selectrow_arrayref("GET status\n".Thruk::Utils::Auth::get_auth_filter($c, 'status')."\nColumns: cached_log_messages connections connections_rate host_checks host_checks_rate requests requests_rate service_checks service_checks_rate neb_callbacks neb_callbacks_rate", { Slice => 1, Sum => 1 });

    $c->stash->{'stats'}      = $stats;
    $c->stash->{'live_stats'} = $live_stats;
    return 1;
}

##########################################################
# show backend selector
sub _set_backend_selector {
    my ( $self, $c, $backends, $selected ) = @_;
    my %backends = map { $_ => 1 } @{$backends};

    my @backends;
    my @possible_backends = $c->{'db'}->peer_key();
    for my $back (@possible_backends) {
        next if !defined $backends{$back};
        push @backends, $back;
    }

    $c->stash->{'matching_backends'} = \@backends;
    $c->stash->{'backend'}           = $selected;
    return 1;
}

=head1 AUTHOR

Sven Nierlein, 2009, <nierlein@cpan.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;

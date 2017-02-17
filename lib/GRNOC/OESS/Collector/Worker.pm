package GRNOC::OESS::Collector::Worker;

use strict;
use warnings;

use Moo;
use Types::Standard qw(Str Bool);
use Data::Dumper;

use AnyEvent;
use GRNOC::RabbitMQ::Client;
use GRNOC::OESS::Collector::TSDSPusher;

has logger => (is => 'rwp');
has simp_config => (is => 'rwp');
has tsds_config => (is => 'rwp');
has hosts => (is => 'rwp', default => sub { [] });
has interval => (is => 'rwp');
has composite_name => (is => 'rwp');
has simp_client => (is => 'rwp');
has tsds_pusher => (is => 'rwp');
has poll_w => (is => 'rwp');
has push_w => (is => 'rwp');
has msg_list => (is => 'rwp', default => sub { [] });

sub run {
    my ($self) = @_;

    $self->_load_config();

    AnyEvent->condvar()->wait();
}

sub _load_config {
    my ($self) = @_;

    $self->_set_simp_client(GRNOC::RabbitMQ::Client->new(
				host => $self->simp_config->{'host'},
				port => $self->simp_config->{'port'},
				user => $self->simp_config->{'user'},
				pass => $self->simp_config->{'password'},
				exchange => 'Simp',
				topic => 'Simp.CompData'
			    ));

    $self->_set_tsds_pusher(GRNOC::OESS::Collector::TSDSPusher->new(
    				tsds_config => $self->tsds_config,
    			    ));

    my $interval = $self->interval;
    $interval = 60 if !defined($interval);

    my $composite = $self->composite_name;
    $composite = "interfaces" if !defined($composite);

    $self->logger->info(Dumper($self->hosts));

    $self->_set_poll_w(AnyEvent->timer(after => 5, interval => $interval, cb => sub {
	my $tm = time;
	
	foreach my $host (@{$self->hosts}) {
	    $self->logger->info("processing $host->{'node_name'}");
	    my $res = $self->simp_client->$composite(
		node => $host->{'node_name'},
		period => $interval,
		async_callback => sub {
		    my $res = shift;
		    $self->_process_host($res, $tm);
		    $self->_set_push_w(AnyEvent->idle(cb => sub { $self->_push_data; }));
		});
	}
	$self->_set_push_w(AnyEvent->idle(cb => sub { $self->_push_data; }));
				  }));

    $self->logger->info("Done setting up event callbacks");
}

sub _process_host {
    my ($self, $res, $tm) = @_;

    if (!defined($res) || $res->{'error'}) {
	$self->logger->error("Comp error: " . _error_message($res));
	return;
    }
    $self->logger->info(Dumper($res));
    foreach my $node_name (keys %{$res->{'results'}}) {
	my $interfaces = $res->{'results'}->{$node_name};
	foreach my $intf_name (keys %{$interfaces}) {
	    my $intf = $interfaces->{$intf_name};
	    my %vals;
	    my %meta;
	    my $intf_tm = $tm;

	    foreach my $key (keys %{$intf}) {
		next if !defined($intf->{$key});

		if ($key eq 'time') {
		    $intf_tm = $intf->{$key} + 0;
		} elsif ($key =~ /^\*/) {
		    my $meta_key = substr($key, 1);
		    $meta{$meta_key} = $intf->{$key};
		} else {
		    $vals{$key} = $intf->{$key} + 0;
		}
	    }

	    next if !defined($vals{'input'}) || !defined($vals{'output'});

	    $meta{'node'} = $node_name;

	    push @{$self->msg_list}, {
		type => 'interface',
		time => $intf_tm,
		interval => $self->interval,
		values => \%vals,
		meta => \%meta
	    };
	}
    }
}

sub _push_data {
    my ($self) = @_;
    my $msg_list = $self->msg_list;
    $self->tsds_pusher->push($msg_list);
}

1;

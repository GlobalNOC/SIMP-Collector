package OESS::Collector::Worker;

use strict;
use warnings;

use Moo;
use AnyEvent;
use Data::Dumper;

use GRNOC::RabbitMQ::Client;
use GRNOC::RabbitMQ::Dispatcher;
use GRNOC::RabbitMQ::Method;
use OESS::Collector::TSDSPusher;

has worker_name => (is => 'ro',
		    required => 1);

has logger => (is => 'rwp',
	       required => 1);

has simp_config => (is => 'rwp',
		    required => 1);

has tsds_config => (is => 'rwp',
		    required => 1);

has hosts => (is => 'rwp',
	      required => 1);

has interval => (is => 'rwp',
		 required => 1);

has composite_name => (is => 'rwp',
		       required => 1);

has simp_client => (is => 'rwp');
has tsds_pusher => (is => 'rwp');
has poll_w => (is => 'rwp');
has push_w => (is => 'rwp');
has msg_list => (is => 'rwp', default => sub { [] });
has cv => (is => 'rwp');
has stop_me => (is => 'rwp', default => 0);

# 
# Run worker
#
sub run {
    my ($self) = @_;

    # Set logging object
    my $logger = GRNOC::Log->get_logger($self->worker_name);
    $self->_set_logger($logger);

    # Set worker properties
    $self->_load_config();

    # Enter event loop, loop until condvar met
    $self->logger->info("Entering event loop");
    $self->_set_cv(AnyEvent->condvar());
    $self->cv->recv;

    $self->logger->info($self->worker_name . " loop ended, terminating");
}

#
# Load config
#
sub _load_config {
    my ($self) = @_;
    $self->logger->info($self->worker_name . " starting");

    # Create dispatcher to watch for messages from Master
    my $dispatcher = GRNOC::RabbitMQ::Dispatcher->new(
	host => $self->simp_config->{'host'},
	port => $self->simp_config->{'port'},
	user => $self->simp_config->{'user'},
	pass => $self->simp_config->{'password'},
	exchange => 'SNAPP',
	topic => "SNAPP." . $self->worker_name
	);

    # Create and register stop method
    my $stop_method = GRNOC::RabbitMQ::Method->new(
	name => "stop",
	description => "stops worker",
	callback => sub {
	    # Set stop flag
	    $self->_set_stop_me(1);
	});
    $dispatcher->register_method($stop_method);

    # Create SIMP client object
    $self->_set_simp_client(GRNOC::RabbitMQ::Client->new(
				host => $self->simp_config->{'host'},
				port => $self->simp_config->{'port'},
				user => $self->simp_config->{'user'},
				pass => $self->simp_config->{'password'},
				exchange => 'Simp',
				topic => 'Simp.CompData'
			    ));

    # Create TSDS Pusher object
    $self->_set_tsds_pusher(OESS::Collector::TSDSPusher->new(
				logger => $self->logger,
				worker_name => $self->worker_name,
    				tsds_config => $self->tsds_config,
    			    ));

    # set interval - default to 60
    my $interval = $self->interval;
    $interval = 60 if !defined($interval);

    # set composite name, default to "interfaces" 
    my $composite = $self->composite_name;
    $composite = "interfaces" if !defined($composite);

    # Create polling timer for event loop
    $self->_set_poll_w(AnyEvent->timer(after => 5, interval => $interval, cb => sub {
	my $tm = time;
	
	# Pull data for each host from Comp
	foreach my $host (@{$self->hosts}) {
	    $self->logger->info($self->worker_name . " processing $host");
	    my $res = $self->simp_client->$composite(
		node => $host,
		period => $interval,
		async_callback => sub {
		    # Process results and push when idle
		    my $res = shift;
		    $self->_process_host($res, $tm);
		    $self->_set_push_w(AnyEvent->idle(cb => sub { $self->_push_data; }));
		});
	}
	# Push when idle
	$self->_set_push_w(AnyEvent->idle(cb => sub { $self->_push_data; }));
				  }));

    $self->logger->info($self->worker_name . " Done setting up event callbacks");
}

#
# Process host for publishing to TSDS
#
sub _process_host {
    my ($self, $res, $tm) = @_;

    # Drop out if we get an error from Comp
    if (!defined($res) || $res->{'error'}) {
	$self->logger->error($self->worker_id . " Comp error: " . _error_message($res));
	return;
    }

    # Take data from Comp and "package" for a post to TSDS
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

	    # Needed to handle bug in 3135:160
	    next if !defined($vals{'input'}) || !defined($vals{'output'});

	    $meta{'node'} = $node_name;

	    # push onto our queue for posting to TSDS
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

#
# Push to TSDS
#
sub _push_data {
    my ($self) = @_;
    my $msg_list = $self->msg_list;
    my $res = $self->tsds_pusher->push($msg_list);
    unless ($res) {
	# If queue is empty and stop flag is set, end event loop
	$self->cv->send() if $self->stop_me;
	# Otherwise clear push timer
	$self->_set_push_w(undef);
    }
}

#
# parse error messages
#
sub _error_message {
    my $res = shift;
    if (!defined($res)) {
        my $msg = ' [no response object]';
        $msg .= " \$!='$!'" if defined($!) && ($! ne '');
        return $msg;
    }

    my $msg = '';
    $msg .= " error=\"$res->{'error'}\"" if defined($res->{'error'});
    $msg .= " error_text=\"$res->{'error_text'}\"" if defined($res->{'error_text'});
    $msg .= " \$!=\"$!\"" if defined($!) && ($! ne '');
    $msg .= " \$@=\"$@\"" if defined($@) && ($@ ne '');
    return $msg;
}

1;

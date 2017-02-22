package GRNOC::OESS::Collector::Master;

use strict;
use warnings;

use Moo;
use Types::Standard qw(Str Bool);
use Proc::Daemon;
use Parallel::ForkManager;
use Data::Dumper; 

use GRNOC::Config;
use GRNOC::RabbitMQ::Client;
use GRNOC::OESS::Collector::Worker;

has config_file => (is => 'ro', isa => Str, required => 1);
has pidfile => (is => 'ro', isa => Str, required => 1);
has daemonize => (is => 'ro', isa => Bool, required => 1);

has logger => (is => 'rwp');
has simp_config => (is => 'rwp');
has tsds_config => (is => 'rwp');
has hosts => (is => 'rwp', default => sub { [] });
has interval => (is => 'rwp');
has composite_name => (is => 'rwp');
has workers => (is => 'rwp');
has worker_clients => (is => 'rwp',
		       default => sub { [] });
has hup => (is => 'rwp', default => 0);

sub BUILD {
    my $self = shift;

    $self->_set_logger(GRNOC::Log->get_logger());

    return $self;
}

sub start {
    my ($self) = @_;
    
    $self->logger->info('Starting.');
    $self->logger->debug('Setting up signal handlers.');

    $SIG{'TERM'} = sub {
	$self->logger->info('Received SIGTERM.');
	foreach my $client (@{$self->worker_clients}) {
	    my $res = $client->stop();
	}
    };

    $SIG{'INT'} = sub {
	$self->logger->info('Received SIGTERM.');
	foreach my $client (@{$self->worker_clients}) {
	    $client->stop();
	}
    };

    $SIG{'HUP'} = sub {
	$self->logger->info('Received SIGHUP.');
	foreach my $client (@{$self->worker_clients}) {
	    $client->stop();
	}
#	$self->_set_hup(1);
    };

    if ($self->daemonize) {
	$self->logger->debug('Daemonizing.');

	my $daemon = Proc::Daemon->new(pid_file => $self->pidfile);
	my $pid = $daemon->Init();

	if ($pid) {
	    sleep 1;
	    die 'Spawning child process failed' if !$daemon->Status();
	    exit(0);
	}
    }

    while (1) {
	$self->_load_config();
	$self->_create_workers();
	last unless $self->hup;
    }

    $self->logger->info("Master terminating");
}

sub _load_config {
    my ($self) = @_;

    $self->logger->info("Reading configuration from " . $self->config_file);

    my $conf = GRNOC::Config->new(config_file => $self->config_file,
				       force_array => 1);

    $self->_set_simp_config($conf->get('/config/simp')->[0]);

    $self->_set_tsds_config($conf->get('/config/tsds')->[0]);
    
    my @hosts;
    foreach my $host (@{$conf->get('/config/hosts/host')}) {
	push @hosts, $host if defined($host);
    }
    $self->_set_hosts(\@hosts);

    $self->_set_interval($conf->get('/config/collection/@interval')->[0]);

    $self->_set_composite_name($conf->get('/config/collection/@composite-name')->[0]);

    $self->_set_workers($conf->get('/config/hosts/@workers')->[0]);

    $self->_set_worker_clients([]);

    $self->_set_hup(0);
}

sub _create_workers {
    my ($self) = @_;

    my $forker = Parallel::ForkManager->new($self->workers);

    my %hosts_by_worker;
    my $idx = 0;

    foreach my $host (@{$self->hosts}) {
	push(@{$hosts_by_worker{$idx}}, $host);
	$idx++;
	if ($idx >= $self->workers) {
	    $idx = 0;
	}
    }

    for (my $worker_id=0; $worker_id<$self->workers; $worker_id++) {
	$forker->start() and next;
	
	my $worker_name = $self->composite_name . $worker_id;
	$self->logger->info("Creating $worker_name");
	my $worker = GRNOC::OESS::Collector::Worker->new( 
	    worker_name => $worker_name,
	    logger => $self->logger,
	    composite_name => $self->composite_name,
	    hosts => $hosts_by_worker{$worker_id},
	    simp_config => $self->simp_config,
	    tsds_config => $self->tsds_config,
	    interval => $self->interval,
	    );

	$worker->run();
    
	$forker->finish();
    }

    my @clients;
    for (my $worker_id=0; $worker_id<$self->workers; $worker_id++) {
	my $worker_name = $self->composite_name . $worker_id;	
	$self->logger->info("Creating Rabbit client for $worker_name");
	my $client = GRNOC::RabbitMQ::Client->new(
	    host => $self->simp_config->{'host'},
	    port => $self->simp_config->{'port'},
	    user => $self->simp_config->{'user'},
	    pass => $self->simp_config->{'password'},
	    exchange => 'SNAPP',
	    topic => "SNAPP." . $worker_name
	    );

	push(@clients, $client);
    }
    $self->_set_worker_clients(\@clients);

    $forker->wait_all_children();
    $self->logger->info("All children are dead");
}
    
1;

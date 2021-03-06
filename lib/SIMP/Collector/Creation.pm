package SIMP::Collector::Creation;

use strict;
use warnings;

use Data::Dumper;
use GRNOC::Config;
use GRNOC::RabbitMQ::Dispatcher;
use GRNOC::RabbitMQ::Method;
use Log::Log4perl;

Log::Log4perl->init('/etc/simp/collector/logging.conf');
my $log = Log::Log4perl->get_logger('SIMP.Collector.Creation');

my $conf = GRNOC::Config->new(
    config_file => '/etc/simp/collector/config.xml',
    force_array => 1
);

my $rabbitmq = $conf->get('/config/simp')->[0];

sub run {
    my ($condvar, $id) = @_;
    $log->info("Started worker $id");

    my $dispatcher = GRNOC::RabbitMQ::Dispatcher->new(
        host => $rabbitmq->{'host'},
        port => $rabbitmq->{'port'},
        user => $rabbitmq->{'user'},
        pass => $rabbitmq->{'password'},
        exchange => 'SNAPP',
        topic    => "SNAPP.$id"
    );

    my $stop_method = GRNOC::RabbitMQ::Method->new(
        name        => "stop",
        description => "stops worker",
        async       => 1,
        callback    => sub {
            my $method = shift;
            my $params = shift;

            my $success = $method->{'success_callback'};
            &$success("Worker $id is stopping.");

            $dispatcher->stop_consuming();
        }
    );

    $dispatcher->register_method($stop_method);

    $dispatcher->start_consuming();

    $log->info("Worker $id stopped.");
}

1;

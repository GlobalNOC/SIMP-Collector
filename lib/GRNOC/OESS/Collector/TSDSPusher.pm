package GRNOC::OESS::Collector::TSDSPusher;

use strict;
use warnings;

use Moo;
use Data::Dumper;

use GRNOC::WebService::Client;

has tsds_config => (is => 'rwp');
has tsds_svc => (is => 'rwp');

sub BUILD {
    my ($self) = @_;

    $self->_set_tsds_svc(GRNOC::WebService::Client->new(

			 ));
}


sub push {
    my ($self, $msg_list) = @_;
}

1;

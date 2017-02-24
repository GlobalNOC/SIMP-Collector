package OESS::Collector;

use strict;
use warnings;

our $VERSION = '1.0.0';

sub new {
    my $caller = shift;
    my $class = ref($caller);
    $class = $caller if (!$class);
    my $self = { @_ };
    bless($self, $class);
    return $self;
}

sub get_version {
    my $self = shift;
    return $VERSION;
}

1;

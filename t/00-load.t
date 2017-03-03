#!perl

use Test::More tests => 4;

BEGIN {
    use_ok('OESS::Collector');
    use_ok('OESS::Collector::Master');
    use_ok('OESS::Collector::Worker');
    use_ok('OESS::Collector::TSDSPusher');
}

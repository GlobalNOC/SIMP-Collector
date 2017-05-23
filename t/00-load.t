#!perl

use Test::More tests => 4;

BEGIN {
    use_ok('SIMP::Collector');
    use_ok('SIMP::Collector::Master');
    use_ok('SIMP::Collector::Worker');
    use_ok('SIMP::Collector::TSDSPusher');
}

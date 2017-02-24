use strict;
use warnings;
use ExtUtils::MakeMaker;

sub MY::postamble { << 'END';}
rpm:    dist
	rpmbuild -ta oess-vlan-collector-$(VERSION).tar.gz
END

WriteMakefile(
    NAME                => 'oess-vlan-collector',
    AUTHOR              => 'GRNOC Systems Engineering <syseng@grnoc.iu.edu>',
    VERSION_FROM        => 'lib/OESS/Collector.pm',
    PL_FILES            => {},
    PREREQ_PM => {},
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'perl-OESS-*' },
    );

sub MY::test
{
    q(
TEST_VERBOSE=1
test : pure_all
	$(FULLPERL) t/TEST $(TEST_VERBOSE)

test_jenkins : pure_all
	$(FULLPERL) t/TEST $(TEST_VERBOSE) --formatter=TAP::Formatter::Console

    );
}


use strict;
use warnings;
use ExtUtils::MakeMaker;

sub MY::postamble { << 'END';}
rpm:    dist
	rpmbuild -ta simp-collector-$(VERSION).tar.gz
END

WriteMakefile(
    NAME                => 'simp-collector',
    AUTHOR              => 'GRNOC Systems Engineering <syseng@grnoc.iu.edu>',
    VERSION_FROM        => 'lib/SIMP/Collector.pm',
    PL_FILES            => {},
    PREREQ_PM => {},
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'simp-collector-*' },
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


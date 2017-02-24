#!/usr/bin/perl

#---------------------------------------------------------------------
#----- Copyright(C) 2016 The Trustees of Indiana University
#---------------------------------------------------------------------
#----- This script makes the Makefile for this module.  Run it using
#----- perl Makefile.PL on the command before running make.
#---------------------------------------------------------------------

use strict;
use warnings;

use ExtUtils::MakeMaker;
use FindBin;

sub MY::postamble { <<"END"; }

rpm: dist
    rpmbuild -ta oess-vlan-collector-\$(VERSION).tar.gz

END

WriteMakefile(
    NAME                => 'oess-vlan-collector',
    AUTHOR              => 'GRNOC Software Engineering',
    VERSION_FROM        => 'lib/OESS/Collector/Master.pm',
    PL_FILES            => {},
    PREREQ_PM     => {},
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'oess-vlan-collector*.gz' },
    );

Summary: OESS VLAN Collector
Name: oess-vlan-collector
Version: 1.0.0
Release: 1
License: APL 2.0
Group: Network
URL: http://globalnoc.iu.edu
Source0: %{name}-%{version}.tar.gz
BuildRoot: %(mktemp -ud %{_tmppath}/%{name}-%{version}-%{release}-XXXXXX)
BuildArch:noarch

BuildRequires: perl
Requires: perl(Data::Dumper), perl(Getopt::Long), perl(AnyEvent), perl(Moo), perl(Types::Standard), perl(JSON::XS), perl(Proc::Daemon, perl(GRNOC::Config), perl(GRNOC::WebService::Client), perl(GRNOC::RabbitMQ::Client), perl(GRNOC::Log), perl(Parallel::ForkManager)

%define execdir /usr/sbin
%define configdir /etc/oess/oess-vlan-collector
%define initdir /etc/rc.d/init.d

%description
This program pulls SNMP network interface rate data from Simp and publishes to TSDS.

%prep
%setup -q

%build

%install
rm -rf $RPM_BUILD_ROOT
%__mkdir -p -m 0775 $RPM_BUILD_ROOT%{execdir}
%__mkdir -p -m 0775 $RPM_BUILD_ROOT%{configdir}
%__mkdir -p -m 0775 $RPM_BUILD_ROOT%{initdir}
%__mkdir -p -m 0775 $RPM_BUILD_ROOT%{perl_vendorlib}/OESS/Collector
%__install bin/oess-vlan-collector $RPM_BUILD_ROOT/%{execdir}/
%__install conf/config.xml.example $RPM_BUILD_ROOT/%{configdir}/
%__install conf/logging.xml.example $RPM_BUILD_ROOT/%{configdir}/
%__install init.d/oess-vlan-collector $RPM_BUILD_ROOT/%{initdir}/
%__install lib/OESS/Collector.pm $RPM_BUILD_ROOT/%{perl_vendorlib}/OESS/
%__install lib/OESS/Collector/Master.pm $RPM_BUILD_ROOT/%{perl_vendorlib}/OESS/Collector/
%__install lib/OESS/Collector/Worker.pm $RPM_BUILD_ROOT/%{perl_vendorlib}/OESS/Collector/
%__install lib/OESS/Collector/TSDSPusher.pm $RPM_BUILD_ROOT/%{perl_vendorlib}/OESS/Collector/

%{_fixperms} $RPM_BUILD_ROOT/*

%clean
rm -rf $RPM_BUILD_ROOT


%files
%defattr(-,root,root,-)
%attr(755,root,root) %{execdir}/oess-vlan-collector
%attr(755,root,root) %config %{initdir}/oess-vlan-collector
%{perl_vendorlib}/OESS/Collector.pm
%{perl_vendorlib}/OESS/Collector/Master.pm
%{perl_vendorlib}/OESS/Collector/Worker.pm
%{perl_vendorlib}/OESS/Collector/TSDSPusher.pm
%config(noreplace) %{configdir}/config.xml.example
%config(noreplace) %{configdir}/config.xml.example

%changelog
* Fri Feb 24 2017 CJ Kloote <ckloote@globalnoc.iu.edu> - OESS VLAN Collector
- Initial build.

Summary: OESS VLAN Collector
Name: oess-vlan-collector
Version: 1.1.0
Release: 2
License: APL 2.0
Group: Network
URL: http://globalnoc.iu.edu
Source0: %{name}-%{version}.tar.gz
BuildRoot: %(mktemp -ud %{_tmppath}/%{name}-%{version}-%{release}-XXXXXX)
BuildArch:noarch

BuildRequires: perl
Requires: perl(Data::Dumper), perl(Getopt::Long), perl(AnyEvent), perl(Moo), perl(Types::Standard), perl(JSON::XS), perl(Proc::Daemon), perl(GRNOC::Config), perl(GRNOC::WebService::Client), perl(GRNOC::RabbitMQ::Client), perl(GRNOC::Log), perl(Parallel::ForkManager)

%define execdir /usr/sbin
%define configdir /etc/oess/oess-vlan-collector
%define initdir /etc/rc.d/init.d
%define sysconfdir /etc/sysconfig

%description
This program pulls SNMP network interface rate data from Simp and publishes to TSDS.

%pre
/usr/bin/getent group oess-collector > /dev/null || /usr/sbin/groupadd -r oess-collector
/usr/bin/getent passwd oess-collector > /dev/null || /usr/sbin/useradd -r -s /sbin/nologin -g oess-collector oess-collector

%prep
%setup -q

%build
%{__perl} Makefile.PL PREFIX="%{buildroot}%{_prefix}" INSTALLDIRS="vendor"
make

%install
rm -rf $RPM_BUILD_ROOT
make pure_install
%__mkdir -p -m 0775 $RPM_BUILD_ROOT%{execdir}
%__mkdir -p -m 0775 $RPM_BUILD_ROOT%{configdir}
%__mkdir -p -m 0775 $RPM_BUILD_ROOT%{initdir}
%__mkdir -p -m 0775 $RPM_BUILD_ROOT%{sysconfdir}
%__mkdir -p -m 0775 $RPM_BUILD_ROOT%{perl_vendorlib}/OESS/Collector
%__install bin/oess-vlan-collector $RPM_BUILD_ROOT/%{execdir}/
%__install conf/config.xml.example $RPM_BUILD_ROOT/%{configdir}/config.xml
%__install conf/logging.conf.example $RPM_BUILD_ROOT/%{configdir}/logging.conf
%if 0%{?rhel} == 7
%__install -d -p %{buildroot}/etc/systemd/system/
%__install conf/oess-vlan-collector.service $RPM_BUILD_ROOT/etc/systemd/system/oess-vlan-collector.service
%else
%__install conf/sysconfig $RPM_BUILD_ROOT/%{sysconfdir}/oess-vlan-collector
%__install init.d/oess-vlan-collector $RPM_BUILD_ROOT/%{initdir}/
%endif
%__install lib/OESS/Collector.pm $RPM_BUILD_ROOT/%{perl_vendorlib}/OESS/
%__install lib/OESS/Collector/Master.pm $RPM_BUILD_ROOT/%{perl_vendorlib}/OESS/Collector/
%__install lib/OESS/Collector/Worker.pm $RPM_BUILD_ROOT/%{perl_vendorlib}/OESS/Collector/
%__install lib/OESS/Collector/TSDSPusher.pm $RPM_BUILD_ROOT/%{perl_vendorlib}/OESS/Collector/
# clean up buildroot
find %{buildroot} -name .packlist -exec %{__rm} {} \;

%{_fixperms} $RPM_BUILD_ROOT/*

%clean
rm -rf $RPM_BUILD_ROOT


%files
%defattr(-,root,root,-)
%attr(755,root,root) %{execdir}/oess-vlan-collector
%if 0%{?rhel} == 7
%attr(644,root,root) /etc/systemd/system/oess-vlan-collector.service
%else
%attr(755,root,root) %config %{initdir}/oess-vlan-collector
%config(noreplace) %{sysconfdir}/oess-vlan-collector
%endif
%{perl_vendorlib}/OESS/Collector.pm
%{perl_vendorlib}/OESS/Collector/Master.pm
%{perl_vendorlib}/OESS/Collector/Worker.pm
%{perl_vendorlib}/OESS/Collector/TSDSPusher.pm
%config(noreplace) %{configdir}/config.xml
%config(noreplace) %{configdir}/logging.conf

%changelog
* Fri Feb 24 2017 CJ Kloote <ckloote@globalnoc.iu.edu> - OESS VLAN Collector
- Initial build.

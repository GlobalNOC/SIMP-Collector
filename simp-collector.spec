Summary: SIMP Collector
Name: simp-collector
Version: 1.0.5
Release: 1%{dist}
License: APL 2.0
Group: Network
URL: http://globalnoc.iu.edu
Source0: %{name}-%{version}.tar.gz
BuildRoot: %(mktemp -ud %{_tmppath}/%{name}-%{version}-%{release}-XXXXXX)
BuildArch:noarch

BuildRequires: perl
Requires: perl(Data::Dumper), perl(Getopt::Long), perl(AnyEvent), perl(Moo), perl(Types::Standard), perl(JSON::XS), perl(Proc::Daemon), perl(GRNOC::Config), perl(GRNOC::WebService::Client), perl(GRNOC::RabbitMQ::Client), perl(GRNOC::Log), perl(Parallel::ForkManager), perl(MooseX::Clone)

%define execdir /usr/sbin
%define configdir /etc/simp/collector
%define initdir /etc/rc.d/init.d
%define sysconfdir /etc/sysconfig

%description
This program pulls SNMP-derived data from Simp and publishes it to TSDS.

%pre
/usr/bin/getent group simp-collector > /dev/null || /usr/sbin/groupadd -r simp-collector
/usr/bin/getent passwd simp-collector > /dev/null || /usr/sbin/useradd -r -s /sbin/nologin -g simp-collector simp-collector

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
%__mkdir -p -m 0775 $RPM_BUILD_ROOT%{perl_vendorlib}/SIMP/Collector
%__install bin/simp-collector $RPM_BUILD_ROOT/%{execdir}/
%__install conf/config.xml.example $RPM_BUILD_ROOT/%{configdir}/config.xml
%__install conf/logging.conf.example $RPM_BUILD_ROOT/%{configdir}/logging.conf
%if 0%{?rhel} == 7
%__install -d -p %{buildroot}/etc/systemd/system/
%__install conf/simp-collector.service $RPM_BUILD_ROOT/etc/systemd/system/simp-collector.service
%else
%__install conf/sysconfig $RPM_BUILD_ROOT/%{sysconfdir}/simp-collector
%__install init.d/simp-collector $RPM_BUILD_ROOT/%{initdir}/
%endif
%__install lib/SIMP/Collector.pm $RPM_BUILD_ROOT/%{perl_vendorlib}/SIMP/
%__install lib/SIMP/Collector/Master.pm $RPM_BUILD_ROOT/%{perl_vendorlib}/SIMP/Collector/
%__install lib/SIMP/Collector/Worker.pm $RPM_BUILD_ROOT/%{perl_vendorlib}/SIMP/Collector/
%__install lib/SIMP/Collector/TSDSPusher.pm $RPM_BUILD_ROOT/%{perl_vendorlib}/SIMP/Collector/
# clean up buildroot
find %{buildroot} -name .packlist -exec %{__rm} {} \;

%{_fixperms} $RPM_BUILD_ROOT/*

%clean
rm -rf $RPM_BUILD_ROOT


%files
%defattr(644,root,root,755)
%attr(755,root,root) %{execdir}/simp-collector
%if 0%{?rhel} == 7
%attr(644,root,root) /etc/systemd/system/simp-collector.service
%else
%attr(755,root,root) %config %{initdir}/simp-collector
%config(noreplace) %{sysconfdir}/simp-collector
%endif
%{perl_vendorlib}/SIMP/Collector.pm
%{perl_vendorlib}/SIMP/Collector/Master.pm
%{perl_vendorlib}/SIMP/Collector/Worker.pm
%{perl_vendorlib}/SIMP/Collector/TSDSPusher.pm
%config(noreplace) %{configdir}/config.xml
%config(noreplace) %{configdir}/logging.conf

%changelog
* Tue May 23 2017 AJ Ragusa <aragusa@globalnoc.iu.edu> - SIMP Collector
* Fri Feb 24 2017 CJ Kloote <ckloote@globalnoc.iu.edu> - OESS VLAN Collector
- Initial build.

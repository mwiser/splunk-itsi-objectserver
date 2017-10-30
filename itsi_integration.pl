
#!/usr/bin/perl
use strict;
use warnings;
use Data::Dumper;
use POSIX qw(strftime);
use IO::Handle;
use IPC::Open3;
use Digest::MD5;

## Date: 20171119
## Desc: Called from omnibus external procedure to send data to Splunk via HEC for ITSI integrations ## Auth: jslay@splunk.com | @rolltide

## Example curl call:
## curl -k -H "Authorization: Splunk a507ef56-d3a4-457b-a59a-b1df20d47e89"
##
##https://127.0.0.1:8088/services/collector/event -d '{"sourcetype": "mysourcetype", "event":
##
##{"event_id": "a507ef56-d3a4-457b-a59a-b1df20d47e89", "key": "value", "an integer": 2}}'

my $command = "/usr/bin/curl";
my $timeout = 10;
my $logfile = "/tmp/itsi_integration.log"; my $token = "6A6E2442-7EAB-4C99-B71D-B8E7F78BA6B3";
my $splunkHEC = "https://heregoesthenameofyoursplunkserver:8088/services/collector/event";
my $ignoreHTTPSCerts = 1;
my $sourcetype = "netcool_event";
my $ts      = '%Y-%m-%d %H:%M:%S%z';
my $lguid = uc sprintf("%x",$$.time);
my $md5 = Digest::MD5->new;
$md5->add($lguid);
my $guid = $md5->hexdigest;

local $SIG{__DIE__} = sub {
   my $msg = @_;

   _log("Fatal error: $msg");
   exit(5);
};

open(LOGFILE, '>>', $logfile) || die "Cannot open logfile: $logfile: $!";
LOGFILE->autoflush(1);

_log("START");



if ( ($#ARGV + 1) % 2 == 1  ) {
  die "Odd number of args passed to script...Must pass even number for proper formatting"
}

my %data = @ARGV;

_log("Invoked with ARGV: " . join(' ', @ARGV)); _log(Dumper(\%ENV)); _log(Dumper(\%data));


sub _log {
   my $msg = shift;
   my $ts_str = POSIX::strftime($ts, localtime);

   print LOGFILE "\[$ts_str\] $lguid $msg\n"; }

sub main {
   my $cmd = parse_input($command => {
      token     => "\"Authorization: Splunk $token\"",
      HEC => $splunkHEC,
      sourcetype => $sourcetype,
   });
   #print "@$cmd\n";
	run_curl($cmd);

}

sub parse_input {
   my $curl = shift;
   my $event = shift;
   my $cmd = [
      $curl,
      '-k', ## Should make this configurable with the #ignore HTTPSCerts var
      '-H',  $event->{token},
      $event->{HEC},
      '-d',
		qq/'{"sourcetype": "$event->{sourcetype}",/  ,
		qq/"event": {"event_id": "$guid",/
   ];
  

   push(@$cmd, sprintf('"netcool_source": "%s"',  'NETCOOL'));

	foreach (keys %data) {
		s/\!/\./g;
		s/('|")//g;
		$data{$_} =~ s/\!/\./g;
		$data{$_} =~ s/('|")//g;
		push(@$cmd, ",\"$_\": \"$data{$_}\"");
	}

	push(@$cmd, '}}\'');
   return $cmd;
}

sub run_curl {
   my $cmd = shift;
   my $pid;
   my $exit_code;
   my $run_in;
   my $run_out;
   my $run_err;
   _log(sprintf('Running: %s', join(' ', @$cmd)));

   eval {
      local $SIG{ALRM} = sub { die 'timeout'; };

      alarm $timeout;
      $pid = open3($run_in, $run_out, $run_err, join(' ', @$cmd)) || die $?;

      close($run_in);
      waitpid($pid, 0);
      $exit_code = $? >> 8;
      alarm 0;
   };
   alarm 0;
   if ($@) {
      _log("Error: $@");
   } else {
      _log(sprintf('Command completed (%d) with exit code: %d', $pid, $exit_code));
   }
}

main();
_log("END");
close(LOGFILE);
exit(0);

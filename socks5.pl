#!/usr/local/bin/perl
# Copyright (c) 1995-1998 NEC Corporation.  All rights reserved. 
#
# The redistribution, use and modification in source or binary forms of
# this software is subject to the conditions set forth in the copyright
# document ("COPYRIGHT") included with this distribution.
#
# $Id: socks5-stat 1.4 1998/07/24 18:41:15 steve Exp $
#
# $Log: socks5-stat $
# Revision 1.4  1998/07/24 18:41:15  steve
# sunos core dumps if you gethostbyaddr on a null
# Revision 1.3  1998/07/24 17:23:57  steve
# added reverse mapping and showprogress
# Revision 1.2  1998/07/23 22:25:32  steve
# added "Auth Failed" handler
#
# ##### Local Definitions #####

# $LOGPATH
# Path/directory where default log files are located.  This is
# over-ridden when the -c option is used.
$LOGPATH = "/var/adm";

# $LOGFILE
# The name of the default file where your SOCKS logs go.  This is
# over-ridden when the -c option is used.
$LOGFILE = "messages";

# $MAILPATH
# This is the full path and name of your sendmail program.  This is
# used when the "mailout" keyword is used in the config file.
$MAILPATH = "/usr/lib/sendmail";

# $CONFFILE
# The default location of the configuration file.  This is over-ridden
# by the -c option.
$CONFFILE = "/etc/socks5-stat.conf";

# $DAEMONNAME
# The name of the Socks5 daemon.  Socks5-stat uses this to parse out
# the appropriate lines in the syslog file.
$DAEMONNAME = "Socks5";

# ##### End of Local Definitions #####


require "timelocal.pl";
require "ctime.pl";

%MONTHS = (
	   'Jan', 0, 'Feb', 1, 'Mar', 2, 'Apr', 3, 'May', 4, 'Jun', 5,
	   'Jul', 6, 'Aug', 7, 'Sep', 8, 'Oct', 9, 'Nov', 10, 'Dec', 11,
	   );

$times{'now'} = time;
$times{'current_month'} = (localtime($times{'now'}))[4];
$times{'current_year'} = (localtime($times{'now'}))[5];

$VERSION = "980722";

# initialize
$config{'conffile'} = $CONFFILE;
$config{'all_users'} = 0;
$config{'top_users'} = 0;
$config{'user_list'} = '';
$config{'user_detail'} = 'none';
$config{'all_shosts'} = 0;
$config{'top_shosts'} = 0;
$config{'shost_list'} = '';
$config{'all_dhosts'} = 0;
$config{'top_dhosts'} = 0;
$config{'dhost_list'} = '';
$config{'all_dports'} = 0;
$config{'top_dports'} = 0;
$config{'dport_list'} = '';
$config{'failed'} = 'all';
$config{'authfail'} = 'all';
$config{'reversemap'} = 'none';
$config{'showprogress'} = 'all';
$config{'restart'} = 'none';
$config{'mail_output'} = 0;
$config{'mail_address'} = '';

# process the command line
#
while ( $ARGV[0] =~ /^-/ ) {
  $_ = shift;
  if ( /^-d(.+)$/ ) {		# the number of days prior to now to summarize
    $NUMDAYS = $1;
  }
  elsif ( /^-c(.+)$/ ) {	# specify config file
    $config{'conffile'} = $1;
  }
  elsif ( /^-c$/ ) {		# specify NO config file
    $config{'conffile'} = '';
  }
  elsif ( /^-e(.+)$/ ) {	# ending date to summarize
    $ENDDATE = $1;
  }
  elsif ( /^-f(.+)$/ ) {	# comma separated files as input data
    $FILELIST = $1;
  }
  elsif ( /^-m(.+)$/ ) {	# path to sendmail binary
    $MAILPATH = $1;
  }
  elsif ( /^-s(.+)$/ ) {	# starting date to summarize
    $STARTDATE = $1;
  }
  elsif ( /^-v$/ ) {		# print the version information and exit
    print STDERR "$0: $VERSION\n";
    exit 0;
  }
  elsif ( /^-h$/ ) {		# print help
    &Usage;
    exit 0;
  }
}

#
# figure out time boundaries to summarize
#
if (defined($STARTDATE)) {
  if ($STARTDATE =~ /^(\d\d)(\d\d)(\d\d)$/) {
    $year = $1; $month = $2; $day = $3;
    if ( ($month < 1) || ($month > 12) || ($day < 1) || ($day > 31) ) {
      die "$0: Starting date is invalid.\n";
    }
    $times{'early'} = &timelocal(0,0,0, $day, $month - 1, $year);
  }
  else {
    die "$0: Starting date is invalid.\n";
  }
}
if (defined($ENDDATE)) {
  if ($ENDDATE =~ /^(\d\d)(\d\d)(\d\d)$/) {
    $year = $1; $month = $2; $day = $3;
    if ( ($month < 1) || ($month > 12) || ($day < 1) || ($day > 31) ) {
      die "$0: Ending date is invalid.\n";
    }
    $times{'late'} = &timelocal(0,0,0, $day, $month - 1, $year);
  }
  else {
    die "$0: Ending date is invalid.\n";
  }
}
if ( (defined($NUMDAYS)) && ($NUMDAYS >= 0) && (!defined($STARTDATE)) &&
     (!defined($ENDDATE)) ) {
  $times{'early'} = $times{'now'} - ($NUMDAYS * 24 * 3600);
  $times{'late'} = $times{'now'};
}
$times{'early'} = 0 if (!defined($times{'early'}));
$times{'late'} = $times{'now'} if (!defined($times{'late'}));

if (defined($FILELIST)) {	# only if user defined filelist
  #
  # use the input files specified on the command line
  #
  ($filenames = $FILELIST) =~ tr/,/ /;
  foreach $file (split(/\s+/, $filenames)) {
    if (!-f $file) {
      die "$0: Can't find file: $file\n";
    }
  }
}
else {
  #
  # use all the available /var/log/messages files
  #
  $filenames = "$LOGPATH/$LOGFILE";
  for ($i = 0; $i <=9; $i++) {
    if (-f "$LOGPATH/$LOGFILE.$i") {
      $filenames = "$LOGPATH/$LOGFILE.$i " . "$filenames";
    }
  }
}
unless (open (LOG, "cat $filenames |")) {
  die "$0: Can't open $filenames: $!\n";
}

#
# Read the config file
#
%config = &readconfig(%config) if ($config{'conffile'} !~ /^$/);
print STDERR "$0: start\n" if ($config{'showprogress'} eq 'all');

# more initialization
$totals{'TCP_success'} = 0;	# number of successful TCP connections
$totals{'UDP'} = 0;		# total number of UDP connections
$totals{'ICMP'} = 0;		# total number of ICMP connections
$totals{'src_bytes'} = 0;	# total number of bytes from inside to outside
$totals{'dest_bytes'} = 0;	# total number of bytes from outside to in
$totals{'seconds'} = 0;		# total number of seconds connected
$totals{'input_lines'} = 0;	# number of lines read in
$totals{'daemon_lines'} = 0;	# log lines examined for daemon

undef(%userarr);		# clear the user array
undef(%detailarr);		# clear the user detail array
undef(%dhostarr);		# clear the dest host array
undef(%shostarr);		# clear the source host array
undef(%dportarr);		# clear the dport array
undef(%connarr);		# array of connections
undef(@refarr);			# array of refused connections
undef(%autharr);		# array of failed auths
undef(@incomparr);		# array of incomplete connections
undef(@startarr);		# array of daemon starting messages

$first = 1;			# flags first entry in log file (get date)

print STDERR "parse log ... start\n" if ($config{'showprogress'} eq 'all');
while (<LOG>) {
  $totals{'input_lines'}++;
  if (/^(\S+)\s+(\d+)\s(\d+):(\d+):(\d+)\s\S+\s$DAEMONNAME\[(\d+)\]:\s+(.*)$/i) {
    $totals{'daemon_lines'}++;
    $monthname = $1;
    $day = $2;
    $hour = $3;
    $min = $4;
    $sec = $5;
    $process = $6;
    $message = $7;
    #
    # if running as threaded, append the thread id to the process id
    #
    if ($message =~ /^\s?(\d{4,6}):\s(.*)$/) {
      $process = $process . ":" . $1;
      $message = $2;
    }
    
    
    if ($MONTHS{$monthname} > $times{'current_month'}) { # log spans Jan. 1
      $year = $times{'current_year'} - 1;
    }
    else {
      $year = $times{'current_year'};
    }
    $thistime = &timelocal($sec,$min,$hour,$day,$MONTHS{$monthname},$year);
    if ($first) {
      #
      # save the time from the first line in the log
      #
      $times{'first'} = $thistime;
      $first = 0;
    }
    $times{'last'} = $thistime;
    
    #
    # do not continue if out of specified time range
    #
    next if ( ($thistime < $times{'early'}) || 
	      ($thistime > $times{'late'}) );
    
    if ($message =~ /^$DAEMONNAME starting/i) {
      $startarr[$#startarr+1] = $message;
      next;
    }
    
    #
    # figure out if it is a message that we care about
    #
    $message = &tolower($message);
    if ($message =~ /^udp proxy request:\s+\((.+)\).*user\s*(\S*)$/) {
      $totals{'UDP'} = &connreq($process, $thistime, $totals{'UDP'}, UDP, "", $1, $2);
    }
    elsif ($message =~ /^udp proxy established:\s+\((.+)\).*user\s*(\S*)$/) {
      &connestab("UDP", $process, $thistime, "", $1);
    }
    elsif ($message =~ /^udp proxy termination:\s+\((.+)\).*user\s*\S*;\s(\d+)\sbytes\sout\s(\d+)\sbytes\sin$/) {
      %totals = &termnorm("UDP", $process, $thistime, $1, $2, $3, %totals);
    }
    elsif ($message =~ /^(ping|traceroute) proxy request:\s+\((.+)\).*user\s*(\S*)$/) {
      &connreq($process, $thistime, 0, ICMP, $1, $2, $3);
      #print "req: >$1<>$2<>$3<\n";
    }
    elsif ($message =~ /^(ping|traceroute) proxy established:\s+\(([^\)]+)\)/) {
      &connestab("ICMP", $process, $thistime, $1, $2);
      #print "est: >$1<>$2<\n";
    }
    elsif ($message =~ /^(ping|traceroute) proxy terminated:\s+normal\s+\((.*)\)[^:]*:\s+(\d+)\sbytes out,\s+(\d+) bytes in$/) {
      %totals = &termnorm("ICMP", $process, $thistime, $2, $3, $4, %totals);
      #print "trm: >$2<>$3<>$4<\n";
    }
    elsif ($message =~ /^tcp connection request:\s+(\S+)\s+\((.+)\).*user\s*(\S*)$/) {
      &connreq($process, $thistime, 0, TCP, $1, $2, $3);
      #print "TCP req: >$1<>$2<>$3<\n";
    }
    elsif ($message =~ /^tcp connection established:\s+(\S+)\s+\(([^\)]+)\)/) {
      &connestab("TCP", $process, $thistime, $1, $2);
      #print "TCP est: >$1<>$2<\n";
    }
    elsif ( ($message =~ /^tcp connection terminated:\s+abnormal.*$/) ||
	    ($message =~ /^Error\s+/) ) {
      &termabnorm($process, $thistime, $_);
    }
    elsif ($message =~ /^tcp connection terminated:\s+normal\s+\((.*)\)[^:]*:\s+(\d+)\sbytes out,\s+(\d+) bytes in$/) {
      %totals = &termnorm("TCP", $process, $thistime, $1, $2, $3, %totals);
      #print "TCP trm: >$1<>$2<>$3<\n";
	}
    elsif ($message =~ /^auth failed:\s*\((.*):(.*)\)$/) {
      &authfail($1,$2, *autharr);
    }
    else {
      #print STDERR $_;
    }
  }
}
close (LOG);
$times{'early'} = $times{'first'} if ($times{'early'} == 0);
print STDERR "parse log ... done\n" if ($config{'showprogress'} eq 'all');

##########
# As of socks5-v1.0r6, IP addresses and service numbers
# are used in the log file.
##########
if (($config{'reversemap'} eq 'ip') || ($config{'reversemap'} eq 'all') ) {
  print STDERR "reverse IP ... start\n" if ($config{'showprogress'} eq 'all');
  &reverseip('nameataddr', *userarr);
  &reverseip('nameataddr', *detailarr);
  &reverseip('addr', *dhostarr);
  &reverseip('addr', *shostarr);
  &reverseip('addr', *autharr);
  print STDERR "reverse IP ... done\n" if ($config{'showprogress'} eq 'all');
}
if (($config{'reversemap'} eq 'service') || ($config{'reversemap'} eq 'all') ) {  
  print STDERR "reverse service ... start\n" if ($config{'showprogress'} eq 'all');
  &reverseservice(*dportarr);
  print STDERR "reverse service ... done\n" if ($config{'showprogress'} eq 'all');
}


#
# open the sendmail pipe or STDOUT
#
if ($config{'mail_output'}) {
  print STDERR "generating mail\n" if ($config{'showprogress'} eq 'all');
  unless(open(OUT, "| $MAILPATH $config{'mail_address'}")) {
    die "$0: Can't open pipe to $MAILPATH: $!\n";
  }
  print OUT "To: $config{'mail_address'}\n";
  print OUT "Subject: Result from $0\n";
  print OUT "X-Generated-By: $0 $VERSION\n";
  print OUT "\n";
}
else {
  print STDERR "writing stdout\n" if ($config{'showprogress'} eq 'all');
  open(OUT, "> -") || die "$0: Can't open STDOUT: $!\n";
}
    
#
# summarize
#
printf OUT "Connection summary - %s to %s\n", 
	&Ctime($times{'early'}),  &Ctime($times{'late'});
print OUT "=====================================";
print OUT "====================================\n";

&sum_header(OUT, $filenames, %times);
&sum_total(OUT, %totals);
&sum_failed(OUT, $config{'failed'}, @refarr);
&sum_authfail(OUT, $config{'authfail'}, %autharr);

&sum_userlist(OUT, $config{'user_list'},%userarr) 
  if ($config{'user_list'} !~ /^$/);

&sum_detail(OUT, %detailarr) if ($config{'user_detail'} eq 'all');

&sum_top(OUT, 'users',$config{'top_users'},%userarr)
  if ($config{'top_users'} > 0);

&sum_allusers(OUT, %userarr) if ($config{'all_users'} > 0);

&sum_hostlist(OUT, 'source addresses',$config{'shost_list'},%shostarr) 
  if ($config{'shost_list'} !~ /^$/);

&sum_top(OUT, 'source addresses',$config{'top_shosts'},%shostarr) 
  if ($config{'top_shosts'} > 0);

&sum_allhosts(OUT, 'source addresses',%shostarr)
  if ($config{'all_shosts'} > 0);

&sum_hostlist(OUT, 'destination addresses',$config{'dhost_list'},%dhostarr) 
  if ($config{'dhost_list'} !~ /^$/);

&sum_top(OUT, 'destination addresses',$config{'top_dhosts'},%dhostarr) 
  if ($config{'top_dhosts'} > 0);

&sum_allhosts(OUT, 'destination addresses',%dhostarr)
  if ($config{'all_dhosts'} > 0);

&sum_portlist(OUT, $config{'dport_list'},%dportarr) 
  if ($config{'dport_list'} !~ /^$/);

&sum_top(OUT, 'ports/services',$config{'top_dports'},%dportarr) 
  if ($config{'top_dports'} > 0);

&sum_allports(OUT, %dportarr) if ($config{'all_dports'} > 0);

&sum_starts(OUT, @startarr) if ($config{'restart'} eq 'all');

print OUT "=====================================";
print OUT "====================================\n";
print OUT "End of summary.\n\n";

close(OUT) || die "$0: Can't close OUTPUT: $!\n";
print STDERR "$0: done\n" if ($config{'showprogress'} eq 'all');
#
# end of main program
#

# ##########
# sub Ctime
#
# Takes the &ctime results and puts them in
# a form more desirable.
# ##########
sub Ctime {
  local($intime) = @_;
  local($str);
  
  ($str = &ctime($intime)) =~ s/^(.*)\s(\d:.*)/${1}0${2}/;
chop($str);

return($str);
}


# ##########
# sub rebyte
#
# Take the number of bytes and convert to
# whichever is more sensible of Gb, Mb, Kb.
# Return the result as a single string containing
# the number and label (i.e. 2.3 Mb).
# ##########
sub rebyte {
  local($bytes) = @_;
  local($number, $label);
  
  if ($bytes > 1024 * 1024 * 1024) { # Gigabytes
    $number = sprintf("%.1f", $bytes / (1024 * 1024 * 1024));
    $label = 'Gb';
  }
  elsif ($bytes > 1024 * 1024) { # Megabytes
    $number = sprintf("%.1f", $bytes / (1024 * 1024));
    $label = 'Mb';
  }
  elsif ($bytes > 1024) {	# kilobytes
    $number = sprintf("%.1f", $bytes / 1024);
    $label = 'Kb';
  }
  else {
    $number = sprintf("%.1f", $bytes);
    $label = ' b';
  }
  $number =~ /^(\d+)\.(\d+)$/;
  return sprintf("%s.%s %s", &commas($1), $2, $label);
}


# ##########
# sub commas
#
# Insert commas into big numbers
# for readability.
# ##########
sub commas {
  local($_) = @_;
  1 while s/(.*\d)(\d\d\d)/$1,$2/;
  $_;
}


# ##########
# Take the number of seconds and
# convert to days:hours:minutes:seconds.
# ##########
sub sec2dhms {
  local($num) = @_;
  local($timestring);
  
  local($day) = int($num / 86400);
  local($hr) = int(($num % 86400) / 3600);
  local($min) = int(($num % 3600) / 60);
  local($sec) = $num % 60;
  ($timestring = sprintf("%2d:%2d:%2d:%2d", $day,$hr,$min,$sec)) =~ tr/ /0/;
  
  return $timestring;
}


sub tolower {
  local($str) = @_;
  
  $str =~ tr/A-Z/a-z/;
  return $str;
}

############
# sub reverseip
############
sub reverseip {
  local ($arrtype, *arr) = @_;
  local ($AF_INET) = 2;
  local ($rkey, $rdata, $ruser, $rhost, $resolv, $i);
  if ($arrtype eq 'nameataddr') {
    foreach $rkey (keys (%arr)) {
      ($ruser,$rhost) = split(/\@/, $rkey);
      $resolv = (gethostbyname($rhost))[0];  # some OSes core if null
      if ($resolv =~ /.+/) {
	$rhost = (gethostbyaddr(((gethostbyname($rhost))[4])[0],$AF_INET))[0] || $rhost;
      }
      $rdata = delete $arr{$rkey};
      # if a host has multiple IP addresses
      # lets just make the key unique so we do not overwrite
      # we would have to know $rdata for each array to sum contents ... yuk!
      $i = 1;
      if (defined $arr{"$ruser\@$rhost"}) {
	while(defined $arr{"$ruser\@$rhost-$i"}) {
	  $i++;
	}
	$arr{"$ruser\@$rhost-$i"} = $rdata;
      }
      else {
	$arr{"$ruser\@$rhost"} = $rdata;
      }
    }
  }
  elsif ($arrtype eq 'addr') {
    foreach $rkey (keys (%arr)) {
      $rhost = $rkey;
      $resolv = (gethostbyname($rhost))[0];  # some OSes core if null
      if ($resolv =~ /.+/) {
	$rhost = (gethostbyaddr(((gethostbyname($rhost))[4])[0],$AF_INET))[0] || $rhost;
      }
      $rdata = delete $arr{$rkey};
      $i = 1;
      if (defined $arr{"$rhost"}) {
	while(defined $arr{"$rhost-$i"}) {
	  $i++;
	}
	$arr{"$rhost-$i"} = $rdata;
      }
      else {
	$arr{"$rhost"} = $rdata;
      }
    }
  }
  else {
    print STDERR "reverseip - bad parameter";
  }
  return;
}


############
# sub reverseservice
############
sub reverseservice {
  local (*arr) = @_;
  local ($rkey, $rdata, $rport, $i);
  foreach $rkey (keys (%arr)) {
    if ($rkey =~ /^\d+$/) {
      $rport = (getservbyport($rkey, 'tcp'))[0] || $rkey;
      $rdata = delete $arr{$rkey};
      $arr{"$rport"} = $rdata;
    }
  }
  return;
}


# sort routines
sub top_conn_byvalue { $top_conn{$a} <=> $top_conn{$b}; }
sub top_bytes_byvalue { $top_bytes{$a} <=> $top_bytes{$b}; }
sub top_time_byvalue { $top_time{$a} <=> $top_time{$b}; }


# ###########
# sub readconfig
#
# Reads the user configuration file.  If there is no
# user configuration file it assumes defaults.  It
# checks each non-comment and non-blank line for keywords
# (described in socks5-stat.conf(5)) and fills the appropriate
# variables for each.
# ###########
sub readconfig {
  local(%conf) = @_;
  local($keyword, $arglist);
  
  #
  # File might not exist but only warn and continue with
  # defaults config options.
  #
  unless (open(CONF, "< $conf{'conffile'}")) {
    print STDERR "$0: Warning: Can't open $conf{'conffile'}: $!.\n";
    print STDERR "$0: Continuing with default configuration options.\n";
    return %conf;
  }
  
  local($linecount) = 0;
  while (<CONF>) {
    $linecount++;
    
    #
    # Remove any comments on the line
    # as well as beginning or trailing whitespace.
    #
    s/^(.*)#.*$/$1/;
      s/^\s+$//;
    s/^\s+(\S.*)$/$1/;
    s/^(.*\S)\s+$/$1/;
    next if (/^$/);		# ignore blank lines
    
    $_ = &tolower($_);
    if ( /^(\S+)\s+(\S.*)$/ ) {
      $keyword = $1;
      $arglist = $2;
      
      if ($keyword eq 'user') {
	($conf{'all_users'},$conf{'top_users'},$conf{'user_list'}) =
	  &readfields($conf{'all_users'}, $conf{'top_users'},
		      $conf{'user_list'}, $arglist);
      }
      elsif ($keyword eq 'detail') {
	if ( ($arglist eq 'none') || ($arglist eq 'all')) {
	  $conf{'user_detail'} = $arglist;
	}
	else {
	  print STDERR "$0: Warning: Malformed line in ",
	  "$conf{'conffile'}: line $linecount.\n";
	}
      }
      elsif ($keyword eq 'source') { 
	($conf{'all_shosts'},$conf{'top_shosts'},$conf{'shost_list'}) =
	  &readfields($conf{'all_shosts'}, $conf{'top_shosts'},
		      $conf{'shost_list'}, $arglist);
      }
      elsif ($keyword eq 'dest') { 
	($conf{'all_dhosts'},$conf{'top_dhosts'},$conf{'dhost_list'}) =
	  &readfields($conf{'all_dhosts'}, $conf{'top_dhosts'},
		      $conf{'dhost_list'}, $arglist);
      }
      elsif ( ($keyword eq 'port') || ($keyword eq 'service') ) {
	($conf{'all_dports'},$conf{'top_dports'},$conf{'dport_list'}) =
	  &readfields($conf{'all_dports'}, $conf{'top_dports'},
		      $conf{'dport_list'}, $arglist);
      }
      elsif ($keyword eq 'failed') {
	if ( ($arglist eq 'none') || ($arglist eq 'all') ||
	     ($arglist eq 'minimum') ) {
	  $conf{'failed'} = $arglist;
	}
	else {
	  print STDERR "$0: Warning: Malformed line in ",
	  "$conf{'conffile'}: line $linecount.\n";
	}
      }
      elsif ($keyword eq 'authfail') {
	if ( ($arglist eq 'none') || ($arglist eq 'all') ||
	     ($arglist eq 'minimum') ) {
	  $conf{'authfail'} = $arglist;
	}
	else {
	  print STDERR "$0: Warning: Malformed line in ",
	  "$conf{'conffile'}: line $linecount.\n";
	}
      }
      elsif ($keyword eq 'showprogress') {
	if ( ($arglist eq 'none') || ($arglist eq 'all') ) {
	  $conf{'showprogress'} = $arglist;
	}
	else {
	  print STDERR "$0: Warning: Malformed line in ",
	  "$conf{'conffile'}: line $linecount.\n";
	}
      }
      elsif ($keyword eq 'reversemap') {
	if ( ($arglist eq 'none') || ($arglist eq 'all') ||
	     ($arglist eq 'ip') || ($arglist eq 'service') ) {
	  $conf{'reversemap'} = $arglist;
	}
	else {
	  print STDERR "$0: Warning: Malformed line in ",
	  "$conf{'conffile'}: line $linecount.\n";
	}
      }
      elsif ($keyword eq 'restart') {
	if ( ($arglist eq 'none') || ($arglist eq 'all') ) {
	  $conf{'restart'} = $arglist;
	}
	else {
	  print STDERR "$0: Warning: Malformed line in ",
	  "$conf{'conffile'}: line $linecount.\n";
	}
      }
      elsif ($keyword eq 'mailout') {
	if ($arglist ne 'none') {
	  $conf{'mail_output'} = 1;
	  $conf{'mail_address'} .= $arglist;
	  $conf{'mail_address'} =~ tr/,/ /;
	}
      }
      else {
	print STDERR
	  "$0: Warning: Malformed line in $conf{'conffile'}: ",
	  "line $linecount.\n";
      }
    }
    else {
      print STDERR "$0: Warning: Malformed line in $conf{'conffile'}: ",
      "line $linecount.\n";
    }
  }
  close (CONF);
  
  return %conf;
}


# ###########
# sub readfields
#
# Examines each field that is given as arguments to
# each keyword of type user, source, dest, and port
# and returns appropriate values for the top number
# to summarize, summarize all, and/or a list to look
# for.
# ###########
sub readfields {
  local($all, $top, $list, $args) = @_;
  local($field);
  
  foreach $field (split(/[\s,]+/,$args)) {
    if ($field =~ /^-$/) {	# summarize all
      $all = 1;
    }
    elsif ($field =~ /^t=(\d+)$/) {	# summarize the top numbers
      $top = $1;
    }
    else {
      $list .= ",$field";
    }
  }
  
  return $all, $top, $list, $args;
}


# ###########
# sub connreq
#
# Called if a connection request log line was found.  If the
# process ID is already in the array of connection requests,
# that means that there was an unresolved connection.  There is
# no further information on that old connection so go ahead
# and store it in the array of incompleted connections.  In
# any case, store the information about the request in the
# array of pending connections (%connarr).  Counters for UDP
# connections can be updated already.
# ###########
sub connreq {
  local($pid, $time, $totudp, $proto, $command, $info, $user) = @_;
  local($tcp, $udp, $icmp, $sb, $db, $secs);
  
  $user = "unknown" if ($user =~ /^$/);
  if (defined($connarr{$pid})) {
    if ( (split(/\|/, $connarr{$pid}))[7] != 0 ) {
      #
      # looks like incomplete data from earlier log with
      # same process ID
      #
      if ( (split(/\|/, $connarr{$pid}))[9] eq 'TCP') {
	#
	# make note of this only if TCP protocol
	#
	$incomparr[$#incomparr+1] = 
	  join('|', $pid, $connarr{$pid});
      }
      undef($connarr{$pid});
    }
  }
  
  if ($proto eq 'UDP') {
    #
    # Go ahead and count the UDP connection and save info
    # just in case there is an error message associated later
    # on.
    #
    $totudp++;
    $info =~ /^(\S+):(\S+)$/;
    local($shost) = $1;
    local($sport) = $2;
    local($dhost) = 'unknown';
    local($dport) = 'unknown';
    $connarr{$pid} = "$user|$shost|$sport|0|$dhost|$dport|0|$time|0|" .
      "$proto|$command";
    
    #
    # update counting arrays
    #
    $userarr{"$user\@$shost"} = '0,0,0,0,0,0'
      if (!defined($userarr{"$user\@$shost"}));
    ($tcp, $udp, $icmp, $sb, $db, $secs) = split(/,/,$userarr{"$user\@$shost"});
    $userarr{"$user\@$shost"} = join (',', $tcp, $udp + 1, $icmp, $sb ,$db,$secs);
    
    $shostarr{"$shost"} = '0,0,0,0,0,0' if (!defined($shostarr{"$shost"}));
    ($tcp, $udp, $icmp, $sb, $db, $secs) = split(/,/, $shostarr{"$shost"});
    $shostarr{"$shost"} = join (',', $tcp, $udp + 1, $icmp, $sb, $db,$secs);
    
    $dhostarr{"$dhost"} = '0,0,0,0,0,0' if (!defined($dhostarr{"$dhost"}));
    ($tcp, $udp, $icmp, $sb, $db, $secs) = split(/,/, $dhostarr{"$dhost"});
    $dhostarr{"$dhost"} = join (',', $tcp, $udp + 1, $icmp, $sb, $db,$secs);
    
    $dportarr{"$dport"} = '0,0,0,0,0' if (!defined($dportarr{"$dport"}));
    ($tcp, $udp, $icmp, $sb, $db, $secs) = split(/,/, $dportarr{"$dport"});
    $dportarr{"$dport"} = join (',', $tcp, $udp + 1, $icmp, $sb, $db,$secs);
    $detailarr{"$user\@$dhost"} = '0,0,0,0,0,0'
      if (!defined($detailarr{"$user\@$dhost"}));
    ($tcp, $udp, $icmp, $sb, $db, $secs) = split (/,/,$detailarr{"$user\@$dhost"});
    $detailarr{"$user\@$dhost"} = join (',', $tcp, $udp + 1, $icmp, $sb, $db, $secs);
  }
  elsif ($proto eq 'ICMP') {
    #
    # extract source host, source port, dest host, dest port
    #
    $info =~ /^(\S+)\s+to\s+(\S+)$/;
    $connarr{$pid} = "$user|$1|ICMP|0|$2|ICMP|0|$time|0|$proto|$command";
  }
  else {			# proto is TCP
    #
    # extract source host, source port, dest host, dest port
    #
    $info =~ /^(\S+):(\S+)\s+to\s+(\S+):(\S+)$/;
    $connarr{$pid} = "$user|$1|$2|0|$3|$4|0|$time|0|$proto|$command";
  }
  
  return $totudp;		# just in case it changed
}


# ###########
# sub connestab
#
# A connection has been established.  Check if it has the same
# information as the connection request.  With the exception of
# ports ftp and ftp-data, the source information should match up with what
# was found at that connection request.  Otherwise, the previous data and the
# current data are parts of connections that we do not have complete
# information for.  Grab the destination information.
# ###########
sub connestab {
  local($parmproto, $pid, $time, $command, $info) = @_;
  local($ouser,$osh,$osp,$osb,$odh,$odp,$odb,$ost,$oet,$oproto,$ocomm);
  
  local($sh,$sp,$dh,$dp);
  if ($parmproto =~ /TCP/) {
    $info =~ /^(\S+):(\S+)\s+to\s+(\S+):(\S+)$/;
    $sh=$1;
    $sp=$2;
    $dh=$3;
    $dp=$4;
  }
  elsif ($parmproto =~ /ICMP/) {
    $info =~ /^(\S+)\s+to\s+(\S+)$/;
    $sh=$1;
    $dh=$2;
    $sp=ICMP;
    $dp=ICMP;
  }
  else {
    $info =~ /^(\S+):(\S+)$/;
    $sh=$1;
    $sp=$2;
    $dh="";
    $dp=0;
  }
  
  #
  # set some defaults just in case they should be needed
  #
  local($user) = 'unknown';
  local($proto) = 'unknown';

  if (defined($connarr{$pid})) {
    ($ouser,$osh,$osp,$osb,$odh,$odp,$odb,$ost,$oet,$oproto,$ocomm) =
      split(/\|/, $connarr{$pid});
    #
    # compare old values with new to make sure it is the
    # same connection (it should be)
    #
    if (($osh ne $sh) || ($osp ne $sp) || ($odh ne $dh) ||
	(($odp ne $dp) && !(($odp eq 'ftp') && ($dp eq 'ftp-data')) &&
	 !(($odp eq 0) && ($dp eq 'ftp-data')))) {
      #
      # Something is not the same that should
      # be so consider that one to be incomplete.
      # Also, there seems to be something unique
      # about the way destination ports of ftp and
      # ftp-data show up in the log so make an exception.
      #
      $incomparr[$#incomparr + 1] = $connarr{$pid}
    }
    else {
      #
      # This is the same connection so use
      # some of the info already gathered.
      #
      $user = $ouser;
      $proto = $oproto;
    }
  }
  $connarr{$pid} = join('|', $user, $sh, $sp, 0, $dh, $dp, 0, 
			$time, 0, $proto, $command);
  
  return;
}


# ##########
# termabnorm
#
# This is called when a Terminated Abnormally message is found
# for a connection.  It adds information to the array of refused
# connections (%refarr) and it frees up the array holder in the
# pending connection array (%connarr).
# ##########
sub termabnorm {
  local($pid, $time, $line) = @_;
  
  if (!defined($connarr{$pid})) {
    #
    # This is the first this process id showed up.
    #
    $connarr{$pid} = "unknown|unknown|unknown|0|" .
      "unknown|unknown|0|$time|$time|unknown|unknown";
  }
  else {
    #
    # fill in the time as the ending time
    #
    local(@arr) = split(/\|/, $connarr{$pid});
    $connarr{$pid} = join('|', $arr[0], $arr[1], $arr[2], $arr[3],
			  $arr[4], $arr[5], $arr[6], $time, $arr[8],
			  $arr[9], $arr[10]);
  }
  $refarr[$#refarr+1] = join('|', $pid, $connarr{$pid}, $line);
  undef($connarr{$pid});
  
  return;
}


# ##########
# sub termnorm
#
# A connection has terminated normally.  Make sure that
# the connection request and established information have
# already appeared for this connection.  Update the summaries
# and free up the array value for this connection.
# ##########
sub termnorm {
  local($parmproto,$pid,$time,$info,$sb,$db,%tots) = @_;
  local($user,$osh,$osp,$osb,$odh,$odp,$odb,$stime,$etime,$proto,$comm);
  local($elapsed,$tcp,$udp,$icmp,$secs);
  local($iinc,$tinc);
  
  local($sh,$sp,$dh,$dp);
  if ($parmproto =~ /TCP/) {
    $info =~ /^(\S+):(\S+)\s+to\s+(\S+):(\S+)$/;
    $sh=$1;
    $sp=$2;
    $dh=$3;
    $dp=$4;
  }
  elsif ($parmproto =~ /ICMP/) {
    $info =~ /^(\S+)\s+to\s+(\S+)$/;
    $sh=$1;
    $dh=$2;
    $sp=ICMP;
    $dp=ICMP;
  }
  else {
    $info =~ /^(\S+):(\S+)$/;
    $sh=$1;
    $sp=$2;
    $dh="";
    $dp=0;
  }
  
  if (!defined($connarr{$pid})) {
    #
    # have not seen this one before so must be
    # incomplete carryover from another log file
    #
    $incomparr[$#incomparr+1] = join('|', $pid, 'unknown', $sh, $sp, $sb,
				     $dh, $dp, $db, 'unknown', $time,
				     'unknown', 'unknown');
  }
  else {
    ($user,$osh,$osp,$osb,$odh,$odp,$odb,$stime,$etime,$proto,$comm) =
      split(/\|/, $connarr{$pid});
    if ( ($osh ne $sh) || ($osp ne $sp) || ($odh ne $dh) || ($odp ne $dp)
	 || ($stime == 0)) {
      #
      # something does not match up here so consider
      # this to be two incomplete processes
      #
      $stime = 'unknown' if ($stime == 0);
      $incomparr[$#incomparr+1] = join('|', $pid, $user, $osh, $osp, 
				       $osb, $odh, $odp, $odb, 
				       $stime, 'unknown',
				       $proto, $comm);
      $incomparr[$#incomparr+1] = join('|', $pid, 'unknown',
				       $sh, $sp, $sb, $dh, $dp,
				       $db, 'unknown', $time,
				       'unknown', 'unknown');
      undef($connarr{$pid});
    }
    else {
      #
      # finally this is the end of a good connection
      #
      undef($connarr{$pid});
      if ($proto eq 'ICMP') {
	$tots{'ICMP'}++;
      } else {
	$tots{'TCP_success'}++;
      }
      $tots{'src_bytes'} += $sb;
      $tots{'dest_bytes'} += $db;
      if ($time > $stime) {
	$elapsed = $time - $stime;
	$tots{'seconds'} += $elapsed;
      }
      else {
	$elapsed = 0;
      }
      
      #
      # update counting arrays
      #
      if ($proto eq 'ICMP') {
	$iinc=1;
	$tinc=0;
      } else {
	$tinc=1;
		$iinc=0;
      }
      
      $userarr{"$user\@$sh"} = '0,0,0,0,0,0'
	if (!defined($userarr{"$user\@$sh"}));
      ($tcp,$udp,$icmp,$osb,$odb,$secs) =
	split(/,/, $userarr{"$user\@$sh"});
      $userarr{"$user\@$sh"} = join (',', $tcp + $tinc, $udp, $icmp + $iinc,
				     $osb + $sb, $odb + $db,
				     $secs + $elapsed);
      
      $shostarr{"$sh"} = '0,0,0,0,0,0' if (!defined($shostarr{"$sh"}));
      ($tcp, $udp, $icmp, $osb, $odb, $secs) = split(/,/,$shostarr{"$sh"});
      $shostarr{"$sh"} = join (',', $tcp + $tinc, $udp, $icmp + $iinc,$osb + $sb, 
			       $odb + $db, $secs + $elapsed);
      
      $dhostarr{"$dh"} = '0,0,0,0,0,0' if (!defined($dhostarr{"$dh"}));
      ($tcp, $udp, $icmp, $osb, $odb, $secs) = split(/,/,$dhostarr{"$dh"});
      $dhostarr{"$dh"} = join (',', $tcp + $tinc, $udp, $icmp + $iinc, $osb + $sb, 
			       $odb + $db, $secs + $elapsed);
      
      $dportarr{"$dp"} = '0,0,0,0,0,0' if (!defined($dportarr{"$dp"}));
      ($tcp, $udp, $icmp, $osb, $odb, $secs) = split(/,/,$dportarr{"$dp"});
      $dportarr{"$dp"} = join (',', $tcp + $tinc, $udp, $icmp + $iinc, $osb + $sb, 
			       $odb + $db, $secs + $elapsed);
      $detailarr{"$user\@$dh"} = '0,0,0,0,0,0'
	if (!defined($detailarr{"$user\@$dh"}));
      ($tcp, $udp, $icmp, $osb, $odb, $secs) = split (/,/,$detailarr{"$user\@$dh"});
      $detailarr{"$user\@$dh"} = join (',', $tcp + $tinc, $udp, $icmp + $iinc, $osb + $sb, $odb + $db, $secs + $elapsed);
    }
    }
  
  return %tots;
}


# ##########
# authfail
#
# As of v1.0r6, all failed authentication attempts are logged.
# The source address & port are all that is available.  The source
# port is ignored.
# ##########
sub authfail {
  local($addr, $port, *arr) = @_;
  $arr{$addr}++;
  return;
}


# ##########
# sub sum_header
#
# Print the header for the summary.
# ##########
sub sum_header {
  local($FDS, $names, %tim) = @_;
  local($file);
  
  printf $FDS "Current time: %s\n", &Ctime($tim{'now'});
  print $FDS "Input files:\n";
  foreach $file (split(/\s+/, $names)) {
    print $FDS "   $file\n";
  }
  if (defined($tim{'first'})) {
    printf $FDS "Date of first daemon log encountered in input: %s\n", 
    &Ctime($tim{'first'});
  }
  if (defined($tim{'last'})) {
    printf $FDS "Date of last daemon log encountered in input: %s\n", 
    &Ctime($tim{'last'});
  }
}


# ##########
# sub sum_total
#
# Prints a summary of overall totals.
# ##########
sub sum_total {
  local($FDS, %tot) = @_;
  
  printf $FDS "Number of input lines processed: %d\n", $tot{'input_lines'};
  printf $FDS "Number of daemon lines processed: %d\n\n",$tot{'daemon_lines'};
  printf $FDS "Number of successful TCP connections: %d\n",$tot{'TCP_success'};
  printf $FDS "Number of requested UDP connections: %d\n",$tot{'UDP'};
  printf $FDS "Number of requested ICMP connections: %d\n",$tot{'ICMP'};
  printf $FDS "\nTotal combined connection time (da:hr:mi:se):%s\n\n", &sec2dhms($tot{'seconds'});
  printf $FDS "Data transferred from inside to out: %s\n",&rebyte($tot{'src_bytes'});
  printf $FDS "Data transferred from outside to in: %s\n",&rebyte($tot{'dest_bytes'});
}


# ##########
# sub sum_failed
#
# Print a summary of failed connections.
# ##########
sub sum_failed {
  local($FDS, $key, @arr) = @_;
  local($i);
  
  return if ($key eq 'none');
  
  print $FDS "\nFailed Connections\n";
  print $FDS "------------------\n";
  printf $FDS "Number of failed connections: %d\n", $#arr+1;
  for ($i=0; $i <= $#arr; $i++) {
    local($pid,$user,$sh,$sp,$x,$dh,$dp,$x,$x,$x,$proto,$cmd,$msg) = 
      split(/\|/, $arr[$i]);
    chop($msg);
    $msg =~ s/^(\S+\s+\S+\s+\S+\s+)\S+\s+\S+\s+(.*)$/$1$2/;
    print $FDS "$msg\n";
    if ($key eq 'all') {
      print $FDS "   $proto $cmd $user@$sh:$sp to $dh:$dp\n";
      print $FDS "\n";
    }
  }
}


# ##########
# sub sum_authfail
#
# Print a summary of failed authentications.
# ##########
sub sum_authfail {
  local($FDS, $config, %arr) = @_;
  local($total) = 0;
  
  return if ($config eq 'none');
  
  print $FDS "\nFailed Authentications\n";
  print $FDS   "----------------------\n";
  
  foreach $key (sort(keys(%arr))) {
    print $FDS "   $key" . " " x (25-length($key)) .  " $arr{$key}\n" if ($config eq 'all');
    $total += $arr{$key};
  }
  print $FDS "Number of failed authentications: $total\n\n";
}


# ##########
# sub sum_starts
#
# Print a summary of when the daemon was started.
# ##########
sub sum_starts {
  local($FDS, @arr) = @_;
  local($i);
  
  print $FDS "\nRestarts\n";
  print $FDS "--------\n";
  printf $FDS "$DAEMONNAME was (re)started %d times:\n", $#arr + 1;
  for ($i = 0; $i <= $#arr; $i++) {
    printf $FDS "   $arr[$i]\n";
  }
}


# ##########
# sub sum_top
#
# Print a summary of the top usage of a particular
# category of events.
# ##########
sub sum_top {
  local($FDS, $category, $num, %arr) = @_;
  local(%top_conn, %top_bytes, %top_time);
  local($key, $tcp, $udp, $icmp, $sb, $db, $secs, $i);
  
  #
  # fill in key for each array type
  #
  foreach $key (keys(%arr)) {
    ($tcp, $udp, $icmp, $sb, $db, $secs) = split(',', $arr{$key});
    $top_conn{$key} = $tcp + $udp + $icmp;
    $top_bytes{$key} = $sb + $db;
    $top_time{$key} = $secs;
  }
  
  print $FDS "\nTop $num $category by number of connections:\n";
  printf $FDS " %-30.30s ", "User\@address" if ($category =~ /^u/);
  printf $FDS " %-30.30s ", "Source Address" if ($category =~ /^s/);
  printf $FDS " %-30.30s ", "Destination Address" if ($category =~ /^d/);
  printf $FDS " %-30.30s ", "Port/Service" if ($category =~ /^p/);
  printf $FDS "%12s ", "Total Conn.";
  printf $FDS "%10s %10s %10s", "TCP Conn.", "UDP Conn.", "ICMP Conn."
    if ($category !~ /^p/);
  print $FDS "\n";
  print $FDS " ------------------------------ ------------ ";
  print $FDS "---------- ---------- ----------" if ($category !~ /^p/);
  print $FDS "\n";
  $i = 0;
  foreach $key (reverse(sort top_conn_byvalue(keys(%top_conn)))) {
    ($tcp, $udp, $icmp, $sb, $db, $secs) = split(',', $arr{$key});
    printf $FDS " %-30.30s %12s ", $key, &commas($top_conn{$key});
    printf $FDS "%10s %10s %10s", &commas($tcp), &commas($udp), &commas($icmp)
      if ($category !~ /^p/);
    print $FDS "\n";
    $i++;
    last if ($i >= $num);
  }
  
  print $FDS "\nTop $num $category by amount of data transferred:\n";
  printf $FDS " %-30.30s ", "User\@address" if ($category =~ /^u/);
  printf $FDS " %-30.30s ", "Source Address" if ($category =~ /^s/);
  printf $FDS " %-30.30s ", "Destination Address" if ($category =~ /^d/);
  printf $FDS " %-30.30s ", "Port/Service" if ($category =~ /^p/);
  printf $FDS "%15s %15s %15s\n", "Total Data", "Source->Dest","Dest->Source";
  print $FDS " ------------------------------ --------------- ",
  "--------------- ---------------\n";
  $i = 0;
    foreach $key (reverse(sort top_bytes_byvalue(keys(%top_bytes)))) {
      ($tcp, $udp, $icmp, $sb, $db, $secs) = split(',', $arr{$key});
      printf $FDS " %-30.30s %15s %15s %15s\n", $key, 
      &rebyte($top_bytes{$key}), &rebyte($sb), &rebyte($db);
      $i++;
      last if ($i >= $num);
    }
  
  print $FDS "\nTop $num $category by time elapsed:\n";
  printf $FDS " %-30.30s ", "User\@address" if ($category =~ /^u/);
  printf $FDS " %-30.30s ", "Source Address" if ($category =~ /^s/);
  printf $FDS " %-30.30s ", "Destination Address" if ($category =~ /^d/);
  printf $FDS " %-30.30s ", "Port/Service" if ($category =~ /^p/);
  printf $FDS "%15s\n", "da:hr:mi:se";
  print $FDS " ------------------------------ --------------- \n";
  $i = 0;
  foreach $key (reverse(sort top_time_byvalue(keys(%top_time)))) {
    ($tcp, $udp, $icmp, $sb, $db, $secs) = split(',', $arr{$key});
    printf $FDS " %-30.30s %15s\n", $key, &sec2dhms($top_time{$key});
    $i++;
    last if ($i >= $num);
  }
}


# ##########
# sub sum_userlist
#
# Print a summary by user names.
# ##########
sub sum_userlist {
  local($FDS, $list, %arr) = @_;
  local(%data);
  local($tcp, $udp, $icmp, $sb, $db, $secs);
  local($user, $name, $host, $key);
  
  print $FDS "\nSpecific users:\n";
  printf $FDS " %-30.30s %6s %6s %10s %10s %12s\n", 'User', 'TCP', 'UDP',
  'ICMP', 'Src->Dst', 'Dst->Src', 'da:hr:mi:se';
  print $FDS " ------------------------------ ------ ------ ",
  "---------- ---------- ------------\n";
  foreach $user (split(/,/, $list)) {
    next if ($user =~ /^$/);
    
    #
    # remove trailing '@' or '.' if someone
    # used that syntax
    #
    $user =~ s/^(\S+)[\@\.]$/$1/; 
    
    if ($user =~ /\@/) {
      ($name, $host) = split (/\@/, $user);
    }
    else {
      $name = $user;
      $host = '';
    }
    $name =~ s/(\W)/\\$1/g;	# backslash possible meta-characters
    $host =~ s/(\W)/\\$1/g;	# backslash possible meta-characters
    
    %data = ('tcp', 0, 'udp', 0, 'icmp', 0, 'sb', 0, 'db', 0, 'secs', 0);
    foreach $key (keys(%arr)) {
      if ( (($host =~ /^$/) && ($key =~ /^$name\@.*/)) || 
	   ($key =~ /^$name\@$host$/) ) {
	($tcp, $udp, $icmp, $sb, $db, $secs) = split(/,/, $arr{$key});
	$data{'tcp'} += $tcp;
	$data{'udp'} += $udp;
	$data{'icmp'} += $icmp;
	$data{'sb'} += $sb;
	$data{'db'} += $db;
	$data{'secs'} += $secs;
      }
    }
    printf $FDS " %-30.30s %6s %6s %10s %10s %12s\n", $user,
    &commas($data{'tcp'}), &commas($data{'udp'}), 
    &rebyte($data{'sb'}), &rebyte($data{'db'}), 
    &sec2dhms($data{'secs'});
  }
}


# ##########
# sub sum_allusers
#
# Print a summary for all users.
# ##########
sub sum_allusers {
  local($FDS, %arr) = @_;
  local($tcp, $udp, $icmp, $sb, $db, $secs);
  local($key);
  
  print $FDS "\nAll users:\n";
  printf $FDS " %-23.23s %6s %6s %6s %10s %10s %12s\n", 'User', 'TCP', 'UDP',
  'ICMP', 'Src->Dst', 'Dst->Src', 'da:hr:mi:se';
  print $FDS " ----------------------- ------ ------ ------ ",
  "---------- ---------- ------------\n";
  foreach $key (sort(keys(%arr))) {
    ($tcp, $udp, $icmp, $sb, $db, $secs) = split(/,/, $arr{$key});
    printf $FDS " %-23.23s %6s %6s %6s %10s %10s %12s\n", $key, 
    &commas($tcp), &commas($udp), &commas($icmp),
    &rebyte($sb), &rebyte($db), &sec2dhms($secs);
  }
}


# ##########
# sub sum_hostlist
#
# Print a summary of a set of hostnames.
# ##########
sub sum_hostlist {
  local($FDS, $category, $list, %arr) = @_;
  local($key, $addr, $unmeta_addr, %data);
  local($tcp, $udp, $sb, $db, $secs);
  
  print $FDS "\nSpecific $category:\n";
  printf $FDS " %-30.30s %6s %6s %10s %10s %12s\n", 'Address', 'TCP', 'UDP',
  'ICMP', 'Src->Dst', 'Dst->Src', 'da:hr:mi:se';
  print $FDS " ------------------------------ ------ ------ ",
  "---------- ---------- ------------\n";
  foreach $addr (split(/,/, $list)) {
    next if ($addr =~ /^$/);
    
    ($unmeta_addr = $addr) =~ s/(\W)/\\$1/g; # watch out for meta-chars
    %data = ('tcp', 0, 'udp', 0, 'icmp', 0, 'sb', 0, 'db', 0, 'secs', 0);
    foreach $key (keys(%arr)) {
      if ( ($key =~ /^$unmeta_addr$/) ||
	   (($addr =~ /^\./) && ($key =~ /^.*$unmeta_addr$/)) || 
	   (($addr =~ /^[\d\.]+\.$/) && ($key =~ /^$unmeta_addr.*$/)) ) {
	($tcp, $udp, $icmp, $sb, $db, $secs) = split(/,/, $arr{$key});
	$data{'tcp'} += $tcp;
	$data{'udp'} += $udp;
	$data{'icmp'} += $icmp;
	$data{'sb'} += $sb;
	$data{'db'} += $db;
	$data{'secs'} += $secs;
      }
    }
    printf $FDS " %-30.30s %6s %6s %10s %10s %12s\n", $addr,
    &commas($data{'tcp'}), &commas($data{'udp'}), 
    &rebyte($data{'sb'}), &rebyte($data{'db'}), 
    &sec2dhms($data{'secs'});
  }
}   


# ##########
# sub sum_allhosts
#
# Print a summary of all hostnames.
# ##########
sub sum_allhosts {
  local($FDS, $category, %arr) = @_;
  local($tcp, $udp, $icmp, $sb, $db, $secs);
  local($key, $val, %newarr);
  
  #
  # We actually need to sort these with the fields reversed
  # for alphanumeric addresses so that they are grouped by
  # domain.
  #
  while (($key, $val) = each %arr) {
    #
    # flip it around if it is not numeric
    #
    $key = join('.', reverse(split(/\./, $key))) if ($key !~ /^[\d\.]+$/);
    $newarr{$key} = $val;
  }
  
  print $FDS "\nAll $category:\n";
  printf $FDS " %-23.23s %6s %6s %6s %10s %10s %12s\n", 'Address', 'TCP', 'UDP',
  'ICMP', 'Src->Dst', 'Dst->Src', 'dy:hr:mn:sc';
  print $FDS " ----------------------- ------ ------ ------ ",
  "---------- ---------- ------------\n";
  foreach $key (sort(keys(%newarr))) {
    ($tcp, $udp, $icmp, $sb, $db, $secs) = split(/,/, $newarr{$key});
    $key = join('.', reverse(split(/\./, $key))) if ($key !~ /^[\d\.]+$/);
    printf $FDS " %-23.23s %6s %6s %6s %10s %10s %12s\n", $key, 
    &commas($tcp), &commas($udp), &commas($icmp),
    &rebyte($sb), &rebyte($db), &sec2dhms($secs);
  }
}


# ##########
# sub sum_portlist
#
# Print a summary of a list of ports.
# ##########
sub sum_portlist {
  local($FDS, $list, %arr) = @_;
  local($key, $port, $unmeta_port, %data);
  local($tcp, $udp, $sb, $db, $secs);
  
  print $FDS "\nSpecific ports/services:\n";
  printf $FDS " %-23.23s %6s %6s %6s %10s %10s %12s\n", 'Port/service', 'TCP',
  'UDP', 'ICMP', 'Src->Dst', 'Dst->Src', 'da:hr:mi:se';
  print $FDS " -------------------- ------ ------ ------ ",
  "---------- ---------- ------------\n";
  foreach $port (split(/,/, $list)) {
    next if ($port =~ /^$/);
    
    ($unmeta_port = $port) =~ s/(\W)/\\$1/g; # watch out for meta-chars
    %data = ('tcp', 0, 'udp', 0, 'icmp', 0, 'sb', 0, 'db', 0, 'secs', 0);
    foreach $key (keys(%arr)) {
      if ($key =~ /^$unmeta_port$/) {
	($tcp, $udp, $icmp, $sb, $db, $secs) = split(/,/, $arr{$key});
	$data{'tcp'} += $tcp;
	$data{'udp'} += $udp;
	$data{'icmp'} += $icmp;
	$data{'sb'} += $sb;
	$data{'db'} += $db;
	$data{'secs'} += $secs;
      }
    }
    printf $FDS " %-23.23s %6s %6s %6s %10s %10s %12s\n", $port,
    &commas($data{'tcp'}), &commas($data{'udp'}),
    &commas($data{'icmp'}), &rebyte($data{'sb'}),
    &rebyte($data{'db'}), &sec2dhms($data{'secs'});
  }
}   


# ##########
# sub sum_allports
#
# Print a summary of all ports used.
# ##########
sub sum_allports {
  local($FDS, %arr) = @_;
  local($tcp, $udp, $sb, $db, $secs);
  local($key);
  
  print $FDS "\nAll ports/services:\n";
  printf $FDS " %-23.23s %6s %6s %6s %10s %10s %12s\n",'Port/service', 'TCP',
  'UDP', 'ICMP', 'Src->Dst', 'Dst->Src', 'da:hr:mi:se';
  print $FDS " ----------------------- ------ ------ ------ ",
  "---------- ---------- ------------\n";
  foreach $key (sort(keys(%arr))) {
    ($tcp, $udp, $icmp, $sb, $db, $secs) = split(/,/, $arr{$key});
    printf $FDS " %-23.23s %6s %6s %6s %10s %10s %12s\n", $key, &commas($tcp), 
    &commas($udp), &commas($icmp), &rebyte($sb), &rebyte($db), &sec2dhms($secs);
  }
}

# ##########
# sub sum_detail
#
# Print detailed summary for all users.
# ##########
sub sum_detail {
  local($FDS, %arr) = @_;
  local($tcp, $udp, $icmp, $sb, $db, $secs);
  local($key);
  local($user,$dest);
  
  print $FDS "\nUser detail:\n";
  printf $FDS " %-8.8s %-14.14s %6s %6s %6s %10s %10s %12s\n",'User',
  'Destination', 'TCP', 'UDP',
  'ICMP', 'Src->Dst', 'Dst->Src', 'da:hr:mi:se';
  print $FDS " -------- -------------- ------ ------ ------ ",
  "---------- ---------- ------------\n";
  foreach $key (sort(keys(%arr))) {
    ($tcp, $udp, $icmp, $sb, $db, $secs) = split(/,/, $arr{$key});
    ($user, $dest) = split(/@/, $key);
    printf $FDS " %-8.8s %-14.14s %6s %6s %6s %10s %10s %12s\n", $user, 
    $dest, &commas($tcp), &commas($udp), &commas($icmp),
    &rebyte($sb), &rebyte($db), &sec2dhms($secs);
  }
}

sub Usage {
  print "$0 [-ddays][-cconfigfile][-eenddate][-ffile,..][-msendmail][-sstartdate][-v
][-h]\n";
}

#!/bin/perl
# Copyright (c) 1995,1996,1997 NEC Corporation.  All rights reserved. 
#
# The redistribution, use and modification in source or binary forms of
# this software is subject to the conditions set forth in the copyright
# document ("COPYRIGHT") included with this distribution.
#
# * $Log: sockd4to5.pl,v $
# * Revision 1.4  1997/05/22 22:45:12  steve
# * updated comments/docs
# *
# * Revision 1.3  1996/05/21 21:05:10  steve
# * Escaped $Id in &Usage so perl doesn't try to interpret
# *
# * Revision 1.2  1996/05/21 21:02:56  steve
# * Added RCS Logging & ID to source
# *

sub Usage {
 ($thisfile = $0) =~  s/^.*\///g;
 print "\$Id: sockd4to5.pl,v 1.4 1997/05/22 22:45:12 steve Exp $\n\n";
 print "\nUsage: $thisfile [-t] <sockd.conf file> [sockd.route file]\n\n";
 exit 1;
}

# ** prints simplified hostpattern
sub Simplify_Hostpattern {
  local($hostip,$mask) = @_;
  local($ha,$hb,$hc,$hd,$ma,$mb,$mc,$md);
  ($ha,$hb,$hc,$hd) = split(/\./, $hostip);
  if ($mask =~ /^0\.0\.0\.0$/) {
    print "-";
  }
  elsif ($mask =~ /^255\.0\.0\.0$/) {
    print "$ha.";
  }
  elsif ($mask =~ /^255\.255\.0\.0$/) {
    print "$ha.$hb.";
  }
  elsif ($mask =~ /^255\.255\.255\.0$/) {
    print "$ha.$hb.$hc.";
  }
  elsif ($mask =~ /^255\.255\.255\.255$/) {
    print "$ha.$hb.$hc.$hd";
  }
  else {
    print "$hostip/$mask";
  }
}


################
# program starts
################


$terse = 0;
if ($ARGV[0] =~ /^\-t$/) {
  $terse = 1;
  shift(@ARGV);
}

if (! -e $ARGV[0]){
  print "$ARGV[0] does not exist\n";
  &Usage;
}

print <<EOF unless $terse;
# sockd.conf 
#
# lines that begin with "#" are comments
# Section 1 - Authentication
#\tkey      = "auth"
#\tsrc_addr = {hostname, fully qualified name, ip addr, domain, subnet, "-"(any)}
#\tsrc_port = {port number, service name, "-"(any)}
#\tmethods  = ["n"one, "u"sername, "k"erberos, "-" any]
#
#key\tsrc_addr\tsrc_port\tmethods
EOF
print "auth\t-\t\t-\t\t-\n";
print <<EOF unless $terse;
#
#
# Section 2 - Route Specification (multi-homed servers)
#\tkey       = "route"
#\tdest_addr = {ip addr, subnet, "-" any}
#\tdest_port = {port number, service name, "-' any}
#\tinterface = {ip addr, interface}
#
#key\tdest_addr\tdest_port\tinterface
EOF

if (-e $ARGV[1]) {
  open (ROUTE, "$ARGV[1]") || die "Couldn't open $ARGV[1]";
  print "#------ translated from sockd.route -----\n" unless $terse;
  while(<ROUTE>) {
    $line = $_;
    # print comments and blank lines verbatim
    if (($line =~ /^#/ ) || ($line =~ /^\s*$/) ) {
      print "$line" unless $terse;
    }
    else {
      print "# -> $line" unless $terse;
      ($code, $comment) = split("#", $line);
      ($int,$da,$dm) = split(/\s+/, $code);
      print "route\t";
      &Simplify_Hostpattern($da,$dm);
      print "\t\t-\t$int\n";
    }
  }

  print "#------ end sockd.route translate -------\n" unless $terse;
}
else {
  print "#no route given - leaving blank\n" unless $terse;
}

print <<EOF unless $terse;
# Section 3 - Variables/Flags
#
#\tkey      = "set"
#\tvariable = text
#\tvalue    = {[0,1],text}
#
#key\t\tvariable\t\tvalue
#set\t\tSOCKS5_DEBUG\t\t1
#set\t\tSOCKS5_LOG_STDERR\t1
#
#
# Section 4 - Proxy Config
#
#\tkey       = [noproxy,np,socks4,s4,socks5,s5]
#\tdest_addr = {ip addr,subnet,domain}
#\tdest_port = {port number, service name, "-" any}
#\tpxy_addr  = {ip addr, hostname, fully qualified name}
#\tpxy_port  = {port number, service name}
#
#key\tdest-addr\tdest-port\tpxy-addr\tpxy-port
#noproxy\t111.222.333.\t-\tsocksserver.domain.com\t1080
#socks4\t\t-\t\t-\tparentsocksserver.domain.com\t1080
#
#
# Section 5 - Access Control
#
#\tkey         = [permit,deny]
#\tauth        = ["n" none, "k"erberos, "-" any]
#\tcommand     = ["b"ind, "c"onnect, "u"dp, "-"(any)]
#\tsrc_addr    = {hostname, fully qualified name, ip addr, domain, 
#\t                subnet, subnet/netmask, "-"(any)}
#\tdest_addr   = {hostname, fully qualified name, ip addr, domain, 
#\t                subnet, subnet/netmask, "-"(any)}
#\tsrc_port    = {port number, service name, "-"(any)}
#\tdest_port   = {port number, service name, "-"(any)}
#\tuserlist    = {login name(s) [comma separated],"-"(any)}
#
#key  auth command  src_addr dest_addr src_port dest_port [userlist]
EOF

if (-e $ARGV[0]) {
  open (CONF, "$ARGV[0]") || die "Couldn't open $ARGV[0]";
  print "#------ translated from sockd.conf -----\n" unless $terse;
  while(<CONF>) {
    undef $action;
    undef $src_addr;
    undef $src_msk;
    undef $dest_addr;
    undef $dest_msk;
    undef $dest_port;
    undef $users;
    $line = $_;
    ## line continuations
    while ( (! ($line =~ /^.+#/)) &&                   ## no comments
	    ($line =~ /\\$/) ) {
	$line =~ s/\\$//;         ## get rid of char
	chop($line);              ## get rid of newline
	$line .= <CONF>;          ## append
    }
    if ($line =~ /^#NO_IDENTD/) {
      print "# !obsolete! $line" unless $terse;
    }
    elsif ($line =~ /^#BAD_ID/) {
      print "# !obsolete! $line" unless $terse;
    }
    elsif ( ($line =~ /^#/ ) || ($line =~ /^\s*$/) ) {
      print "$line" unless $terse;
    }
    else {
      print "# -> $line" unless $terse;
      ($code, $comment) = split("#", $line, 2);
      @words = split(/\s+/, $code);
      $action = shift(@words);  # permit or deny
      if ($words[0] =~ /\?=/) {
        print "#    -- ?=i obsolete\n" unless $terse;
        shift(@words);
      }
      if ($words[0] =~ /\*=/) {
        ($users = $words[0]) =~ s/^\*=//g;
        shift(@words);
      }
      $src_addr = shift(@words);
      $src_msk  = shift(@words);
      # destination specification
      if ($words[0] =~ /\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}/) {
        $dest_addr = shift(@words);
        $dest_msk  = shift(@words);
      }

      # destination port specification
      if ($words[0] =~ /^eq$/) {
        shift(@words);
        $dest_port = shift(@words);
      }
      elsif ($words[0] =~ /^neq$/) {
	  print "# ***  !not supported: neq <dest port> comparison\n" unless $terse;
	  shift(@words);
	  shift(@words);
      }
      elsif ($words[0] =~ /^lt$/) {
	  $dest_port = "(0,";
	  shift(@words);
	  $dest_port .= shift(@words) . ")";
      }
      elsif ($words[0] =~ /^le$/) {
	  $dest_port = "(0,";
	  shift(@words);
	  $dest_port .= shift(@words) . "]";
      }
      elsif ($words[0] =~ /^gt$/) {
	  $dest_port = "(";
	  shift(@words);
	  $dest_port .= shift(@words) . ",65535)";
      }
      elsif ($words[0] =~ /^ge$/) {
	  $dest_port = "[";
	  shift(@words);
	  $dest_port .= shift(@words) . ",65535)";
      }

      if ($words[0] =~ /:/) {
        print "# ***  !shell commands not supported\n" unless $terse;
      }

      # Print the converted line
      print "$action\t-\t-\t";
      &Simplify_Hostpattern($src_addr,$src_msk);
      print "\t";
      if (defined($dest_addr)) {
        &Simplify_Hostpattern($dest_addr,$dest_msk);
        print "\t";
      }
      else {
        print "-\t";
      }
      print "-\t";                   # src port
      if (defined($dest_port)) {
        print "$dest_port\t";
      }
      else {
        print "-\t";
      }
      if (defined($users)) {
        print "$users";
      }
      if ($comments =~ /\S/) {
        print "\t# $comments\n";
      }
      else {
        print "\n";
      }
    }
  }

  print "#------ end sockd.conf translate -------\n" unless $terse;  
}
else {
  print "#bad sockd.conf specified - leaving blank\n" unless $terse;
}


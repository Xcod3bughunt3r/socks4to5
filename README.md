==========================
## socks5 & socks4to5
==========================

File: [README](https://github.com/Xcod3bughunt3r/socks4to5/blob/master/socks4to5.md)

Socks5-stat is a Perl script that generates summaries from the log
messages created by socks5.  It can generate a very simple summary or
be configured to generate very complex summaries.  By default, it uses
your system's message log file and its predecessors (e.g. for SunOS,
this would be /var/adm/messages, /var/adm/messages.0,
/var/adm/messages.1, ...) as input.  However, it can be configured to
use any log files that you specify.

At its simplest, socks5-stat will provide the following information:
	- Number of lines processed.
	- Number of successful connections.
	- Number of bytes transferred.
	- Total connection time.
	- Number of failed connections.
	- Number of failed authentications.
	- Message, host, and user for each failed connection.

Through a configuration file, socks5-stat can be configured to provide
the following summary information:
	- Summary by any or all user names, source addresses,
	  destination addresses, or services.
	- Summary by user and destination address.
	- Ranking and summary of top users, source addresses,
	  destination addresses, or services based on number of
	  connections, data transferred, and connection time.
	- Summary of daemon starts and restarts.

Through command line options and other configuration file information,
socks5-stat can:
	- Mail output to a set of addresses.
	- Use alternate input files.
   	- Use an alternate config file.
	- Summarize over a range of days.


Files
=====
Following is a description of files needed for socks5-stat:
	HISTORY - Revision history.
	COPYRIGHT - Copyright, license, and disclaimer.
	README - This file.
	socks5-stat - Socks5-stat Perl script.
	socks5-stat.1 - Man page for socks5-stat.
	socks5-stat.conf - Sample configuration file.
	socks5-stat.conf.5 - Man page for configuration file.


Installation
============
Perform the following steps on the machine where your socks5 logs are
stored.  This might be on your socks5 server or on your loghost.

0. Obtain and install Perl.  You should be able to find Perl at any
   site that carries the GNU sources.

1. Edit socks5-stat and make the following verifications/changes:
	- First line should reflect the path to your Perl binary.
	- Go to the Local Definitions section and verify/edit as
	  necessary for your system:
		$LOGPATH
		$LOGFILE
		$MAILPATH
		$CONFFILE
		$DAEMONNAME
	  Descriptions of each of these are given.

2. Copy socks5-stat to an appropriate path (e.g. /usr/local/bin).  Set
   mode to 755 (or as desired).

3. Copy socks5-stat.1 and socks5-stat.conf.5 to the appropriate man
   page directories (e.g. /usr/local/man/man1 and
   /usr/local/man/man5).

4. If you want to use a config file, create it in the appropriate
   place (e.g. /etc/socks5-stat.conf).  You might want to use the
   sample config file provided as a guideline.

5. Read the socks5-stat and socks5-stat.conf man pages.


****

#### Follow Me:
* [HackerOne](https://hackerone.com/xcod3bughunt3r)
* [LinkedIn](https://www.linkedin.com/in/xcod3bughunt3r)
* [Quora](https://id.quora.com/profile/ALIF-FUSOBAR?ch=10&oid=1837835981&share=f20a095b&srid=hk8GQ9&target_type=user)
* [Telegram](https://t.me/xcod3bughunt3r)
* [Twitter](https://mobile.twitter.com/Xcod3bughunt3r)
* [Instagram](https://www.instagram.com/xcod3bughunt3r)
* [Facebook](https://www.facebook.com/profile.php?id=100082527189835)
* [TikTok](https://tiktok.com/xcod3bughunt3r)
* [YouTube](https://www.youtube.com/channel/UCDRFcjutewkhAioAuqTB5wg)
* [TryHackMe](https://tryhackme.com/p/Xcod3bughunt3r)
* [IT People](https://t.me/itpeopleindonesia)

****

Takes a sockd version 4 configuration file and optionally a
sockd version 4 routing table file (for multi-homed hosts)
and prints the version 5 configuration file to stdout.  The
output can be used as a template for the socks version 5
server configuration file (/etc/socks5.conf).

Certains parameters in the version 4 configuration file have
no translation to version 5.  The special entries #NO_IDENTD
and #BAD_ID are obsolete.  This prevents a true 1-to-1 
translation.

[socks4to5.pl](https://github.com/Xcod3bughunt3r/socks4&5/blob/master/socks4to5.pl)

[socks4to5.1](https://github.com/Xcod3bughunt3r/socks4&5/blob/master/socks4to5.1)




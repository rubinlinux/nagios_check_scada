nagios_check_scada
==================

A Nagios plugin that checks a sensaphone SCADA 3000 report (exported to the web) for values or ranges

Setup your SCADA 3000 software to drop a report in a directory exported by IIS. I suggest at least 5 minute updates. 

Usage: Copy to the location defined as $USER2$ in your resources.cfg nagios file. Then set up a check_command as $USER2$/check_scada.pl <arguments>



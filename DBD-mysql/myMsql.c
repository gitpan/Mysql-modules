/*
 *  myMsql.c - Connect function for use in msql/mysql sources
 *
 *
 *  Copyright (c) 1997  Jochen Wiedmann
 *
 *  You may distribute this under the terms of either the GNU General Public
 *  License or the Artistic License, as specified in the Perl README file,
 *  with the exception that it cannot be placed on a CD-ROM or similar media
 *  for commercial distribution without the prior approval of the author.
 *
 *  Author:  Jochen Wiedmann
 *           Am Eisteich 9
 *           72555 Metzingen
 *           Germany
 *
 *           Email: wiedmann@neckar-alb.de
 *           Fax: +49 7123 / 14892
 *
 *  $Id: myMsql.c,v 1.1806 1997/09/03 22:39:05 joe Exp $
 */

/*
 *  Header files we use
 */
#include <stdlib.h>
#include <string.h>
#include "myMsql.h"

#ifndef FALSE
#define FALSE 0
#endif
#ifndef TRUE
#define TRUE (!FALSE)
#endif


/***************************************************************************
 *
 *  Name:    MyConnect
 *
 *  Purpose: Replacement for mysql_connect or msqlConnect; the
 *           difference is, that it supports "host:port".
 *
 *  Input:   sock - pointer where to store the MYSQL pointer being
 *               initialized (mysql) or to an integer where to store
 *               a socket number (msql)
 *           host - the host to connect to, a value "host:port" is
 *               valid
 *           user - user name to connect as; ignored for msql
 *           password - passwort to connect with; ignored for mysql
 *
 *  Returns: TRUE for success, FALSE otherwise; you have to call
 *           do_error in the latter case.
 *
 *  Bugs:    The mysql version uses the undocumented mysql_port
 *           variable, but this was suggested by Monty, so I
 *           assume it is safe.
 *
 *           The msql version needs to set the environment
 *           variable MSQL_TCP_PORT. There's absolutely no
 *           portable way of setting environment variables
 *           from within C: Neither setenv() nor putenv()
 *           are guaranteed to work. I have decided to use
 *           the internal perl functions setenv_getix()
 *           and my_setenv() instead, let's hope, this is safe.
 *
 *           Another problem was pointed out by Andreas:
 *           Both versions aren't thread safe. We'll have
 *           fun with perl 5.005 ... :-)
 *
 **************************************************************************/

#ifdef DBD_MSQL
int MyConnect(dbh_t* sock, char* host, char* user, char* password) {
#else
int MyConnect(dbh_t sock, char* host, char* user, char* password) {
#endif
    int port = 0;
    char* ptr;

    if (host  &&  (ptr = strchr(host, ':'))) {
        *ptr++ = '\0';
	port = atoi(ptr);
    }
    
    if (host && !*host) host = NULL;
    if (user && !*user) user = NULL;
    if (password && !*password) password = NULL;

#ifdef DBD_MYSQL
    {
        /*
	 *  Setting a port for mysql's client is ugly: We have to use
	 *  the not documented variable mysql_port.
	 */
	int oldPort = mysql_port;
	MYSQL* result;

        mysql_port = port;
        result = mysql_connect(sock, host, user, password);
	mysql_port = oldPort;
	return result ? TRUE: FALSE;
    }
#else
    {
        /*
	 *  Setting a port for msql's client is extremely ugly: We have
	 *  to set an environment variable. Even worse, we cannot trust
	 *  in setenv or putenv being present, thus we need to use
	 *  internal, not documented, perl functions. :-(
	 */
        char buffer[32];
	char* oldPort = NULL;

	sprintf(buffer, "%d", port);
	if (port) {
	    oldPort = environ[setenv_getix("MSQL_TCP_PORT")];
	    if (oldPort) {
	        char* copy = (char*) malloc(strlen(oldPort)+1);
		if (!copy) {
		    return FALSE;
		}
		strcpy(copy, oldPort);
		oldPort = copy;
	    }
	    my_setenv("MSQL_TCP_PORT", buffer);
	}
	*sock = msqlConnect(host);
	if (oldPort) {
	    my_setenv("MSQL_TCP_PORT", oldPort);
	    if (oldPort) { free(oldPort); }
	}
	return (*sock == -1) ? FALSE : TRUE;
    }
#endif
}

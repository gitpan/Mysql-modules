/*
 *  DBD::mysql - DBI driver for the mysql database
 *
 *  Copyright (c) 1997  Jochen Wiedmann
 *
 *  Based on DBD::Oracle; DBD::Oracle is
 *
 *  Copyright (c) 1994,1995  Tim Bunce
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
 *
 *  $Id: dbdimp.c,v 1.1805 1997/09/03 12:21:36 joe Exp $
 */


#include "dbdimp.h"

DBISTATE_DECLARE;

static SV* dbd_errnum = NULL;
static SV* dbd_errstr = NULL;


#if defined(DBD_MYSQL)  &&  defined(mysql_errno)
#define DO_ERROR(h, c, s) do_error(h, (int) mysql_errno(s), mysql_error(s))
#else
#define DO_ERROR(h, c, s) do_error(h, c, MyError(s))
#endif



/***************************************************************************
 *
 *  Name:    dbd_init
 *
 *  Purpose: Called when the driver is installed by DBI
 *
 *  Input:   dbistate - pointer to the DBIS variable, used for some
 *               DBI internal things
 *
 *  Returns: Nothing
 *
 **************************************************************************/

void dbd_init(dbistate_t* dbistate) {
    DBIS = dbistate;
#ifdef DBD_MYSQL
    dbd_errnum = GvSV(gv_fetchpv("DBD::mysql::err",    1, SVt_IV));
    dbd_errstr = GvSV(gv_fetchpv("DBD::mysql::errstr", 1, SVt_PV));
#else
    dbd_errnum = GvSV(gv_fetchpv("DBD::mSQL::err",    1, SVt_IV));
    dbd_errstr = GvSV(gv_fetchpv("DBD::mSQL::errstr", 1, SVt_PV));
#endif
}


/***************************************************************************
 *
 *  Name:    do_error
 *
 *  Purpose: Called to associate an error code and an error message
 *           to some handle
 *
 *  Input:   h - the handle in error condition
 *           rc - the error code
 *           what - the error message
 *
 *  Returns: Nothing
 *
 **************************************************************************/

void do_error(SV* h, int rc, char* what) {
    D_imp_xxh(h);
    SV *errstr = DBIc_ERRSTR(imp_xxh);
    sv_setiv(DBIc_ERR(imp_xxh), (IV)rc);	/* set err early	*/
    sv_setpv(errstr, what);
    DBIh_EVENT2(h, ERROR_event, DBIc_ERR(imp_xxh), errstr);
    if (dbis->debug >= 2)
	fprintf(DBILOGFP, "%s error %d recorded: %s\n",
		what, rc, SvPV(errstr,na));
}


/***************************************************************************
 *
 *  Name:    dbd_db_login
 *
 *  Purpose: Called for connecting to a database and logging in.
 *
 *  Input:   dbh - database handle being initialized
 *           dbname - the database we want to log into; may be like
 *               "dbname:host" or "dbname:host:port"
 *           user - user name to connect as
 *           password - passwort to connect with
 *
 *  Returns: TRUE for success, FALSE otherwise; do_error has already
 *           been called in the latter case
 *
 **************************************************************************/
int dbd_db_login(SV* dbh, char* dbname, char* user, char* password) {
    D_imp_dbh(dbh);
    char* copy = NULL;
    char* host = NULL;

    if (dbis->debug >= 2)
        fprintf(DBILOGFP, "imp_dbh->connect: db = %s, uid = %s, pwd = %s\n",
	       dbname ? dbname : "NULL",
	       user ? user : "NULL",
	       password ? password : "NULL");

    /*
     *  dbname may be "db:host"
     */
    if (strchr(dbname, ':')) {
        New(0, copy, strlen(dbname)+1, char);
	strcpy(copy, dbname);
	dbname = copy;
	host = strchr(copy, ':');
	*host++ = '\0';
    }

    /*
     *  Try to connect
     */
#ifdef DBD_MYSQL
    imp_dbh->svsock = &imp_dbh->mysql;
    if (!dbd_db_connect(imp_dbh->svsock, host, user, password)) {
#else
    if (!dbd_db_connect(&imp_dbh->svsock, host, user, password)) {
#endif
	DO_ERROR(dbh, JW_ERR_CONNECT, imp_dbh->svsock);
	Safefree(copy);
	return FALSE;
    }

    /*
     *  Connected, now try to login
     */
    if (MySelectDb(imp_dbh->svsock, dbname)) {
        Safefree(copy);
	DO_ERROR(dbh, JW_ERR_SELECT_DB, imp_dbh->svsock);
	MyClose(imp_dbh->svsock);
	return FALSE;
    }

    Safefree(copy);

    /*
     *  Tell DBI, that dbh->disconnect should be called for this handle
     */
    DBIc_on(imp_dbh, DBIcf_ACTIVE);

    /*
     *  Tell DBI, that dbh->destroy should be called for this handle
     */
    DBIc_on(imp_dbh, DBIcf_IMPSET);

    return TRUE;
}


/***************************************************************************
 *
 *  Name:    dbd_db_commit
 *           dbd_db_rollback
 *
 *  Purpose: You guess what they should do. Unfortunately mysql doesn't
 *           support transactions so far. (Most important lack of
 *           feature, Monty! :-) So we stub commit to return OK
 *           and rollback to return ERROR in any case.
 *
 *  Input:   dbh - database handle being commited or rolled back
 *
 *  Returns: TRUE for success, FALSE otherwise; do_error has already
 *           been called in the latter case
 *
 **************************************************************************/

int dbd_db_commit(SV* dbh) {
    return TRUE;
}

int dbd_db_rollback(SV* dbh) {
    do_error(dbh, JW_ERR_NOT_IMPLEMENTED,
		   "Rollback not implemented in mysql");
    return 0;
}


/***************************************************************************
 *
 *  Name:    dbd_db_disconnect
 *
 *  Purpose: Disconnect a database handle from its database
 *
 *  Input:   dbh - database handle being disconnected
 *
 *  Returns: TRUE for success, FALSE otherwise; do_error has already
 *           been called in the latter case
 *
 **************************************************************************/

int dbd_db_disconnect(SV* dbh) {
    D_imp_dbh(dbh);
    /* We assume that disconnect will always work       */
    /* since most errors imply already disconnected.    */
    DBIc_off(imp_dbh, DBIcf_ACTIVE);
    if (dbis->debug >= 2)
        fprintf(DBILOGFP, "imp_dbh->svsock: %lx\n", (long) &imp_dbh->svsock);
    MyClose(imp_dbh->svsock );

    /* We don't free imp_dbh since a reference still exists    */
    /* The DESTROY method is the only one to 'free' memory.    */
    return TRUE;
}


/***************************************************************************
 *
 *  Name:    dbd_db_destroy
 *
 *  Purpose: Our part of the dbh destructor
 *
 *  Input:   dbh - database handle being destroyed
 *
 *  Returns: Nothing
 *
 **************************************************************************/

void dbd_db_destroy(SV* dbh) {
    D_imp_dbh(dbh);

    /*
     *  Being on the safe side never hurts ...
     */
    if (DBIc_ACTIVE(imp_dbh))
        dbd_db_disconnect(dbh);

    /*
     *  Tell DBI, that dbh->destroy must no longer be called
     */
    DBIc_off(imp_dbh, DBIcf_IMPSET);
}


/***************************************************************************
 *
 *  Name:    dbd_db_STORE_attrib
 *
 *  Purpose: Function for storing dbh attributes; we currently support
 *           just nothing. :-)
 *
 *  Input:   dbh - database handle being modified
 *           keysv - the attribute name
 *           valuesv - the attribute value
 *
 *  Returns: TRUE for success, FALSE otherwise
 *
 **************************************************************************/

int dbd_db_STORE_attrib(SV* dbh, SV* keysv, SV* valuesv) {
    STRLEN kl;
    char *key = SvPV(keysv, kl);
    SV *cachesv = Nullsv;
    int cacheit = FALSE;

    if (kl==10 && strEQ(key, "AutoCommit")){
        /*
	 *  We do support neither transactions nor "AutoCommit".
	 *  But we stub it. :-)
	 */
        if (!SvTRUE(valuesv)) {
	    do_error(dbh, JW_ERR_NOT_IMPLEMENTED,
			   "Transactions not supported by mysql");
	    return FALSE;
	}
    } else {
        return FALSE;
    }

    if (cacheit) /* cache value for later DBI 'quick' fetch? */
        hv_store((HV*)SvRV(dbh), key, kl, cachesv, 0);
    return TRUE;
}


/***************************************************************************
 *
 *  Name:    dbd_db_FETCH_attrib
 *
 *  Purpose: Function for fetching dbh attributes; we currently support
 *           just nothing. :-)
 *
 *  Input:   dbh - database handle being queried
 *           keysv - the attribute name
 *           valuesv - the attribute value
 *
 *  Returns: An SV*, if sucessfull; NULL otherwise
 *
 *  Notes:   Do not forget to call sv_2mortal in the former case!
 *
 **************************************************************************/

SV* dbd_db_FETCH_attrib(SV* dbh, SV* keysv) {
    STRLEN kl;
    char *key = SvPV(keysv, kl);
    D_imp_dbh(dbh);

    if (kl==10 && strEQ(key, "AutoCommit")){
        /*
	 *  We do support neither transactions nor "AutoCommit".
	 *  But we stub it. :-)
	 */
        return &sv_yes;
    }
    if (kl == 5  &&  strEQ(key, "errno")) {
#if defined(DBD_MYSQL)  &&  defined(mysql_errno)
	return sv_2mortal(newSViv((IV)mysql_errno(imp_dbh->svsock)));
#else
	return sv_2mortal(newSViv(-1));
#endif
    } else if (kl == 6  &&  strEQ(key, "errmsg")) {
	char* msg = MyError(imp_dbh->svsock);
	return sv_2mortal(newSVpv(msg, strlen(msg)));
    }
    return Nullsv;
}


/***************************************************************************
 *
 *  Name:    x_stricmp
 *
 *  Purpose: Case insensitive strncmp
 *
 *  Input:   a, b - strings being compared
 *           n - maximum number of bytes being read
 *
 *  Returns: Zero, if strings match, nonzero otherwise
 *
 **************************************************************************/

static int x_strnicmp(char* a, char* b, unsigned int n) {
    int c;

    do {
        if (!n--) {
	    return 0;
	}
        c = tolower(*a) - tolower(*b);
    } while (*a  &&  c == 0);

    return c;
}


/***************************************************************************
 *
 *  Name:    CommandHasResult
 *
 *  Purpose: Reads the first word from an SQL statement and tries
 *           to detect, what kind of statement it is.
 *
 *  Input:   statement - pointer to string with SQL statement
 *
 *  Returns: positive number, if statement will return a result (SELECT
 *           statement), negative number otherwise
 *
 **************************************************************************/

static int CommandHasResult(char* statement) {
    static struct commands_st {
        char* command;
        int code;
    } *cptr, commands[] = {
        { "CREATE", COMMAND_CREATE },
	{ "DROP",   COMMAND_DROP },
	{ "DELETE", COMMAND_DELETE },
	{ "INSERT", COMMAND_INSERT },
	{ "SELECT", COMMAND_SELECT },
	{ "SYSTABLES", COMMAND_SYSTABLES },
        { "UPDATE", COMMAND_UPDATE },
	{ "ALTER", COMMAND_ALTER },
	{ "LISTFIELDS", COMMAND_LISTFIELDS },
	{ NULL, COMMAND_UNKNOWN }
    };

    while (*statement  &&  isspace(*statement)) {
        ++statement;
    }

    for (cptr = commands;  cptr->code;  ++cptr) {
        if (!x_strnicmp(cptr->command, statement, strlen(cptr->command))) {
	    if (dbis->debug >= 2) {
	        fprintf (DBILOGFP, "Statement command is %s, %s\n",
			 cptr->command,
			 cptr->code >= 0 ? "returns result" : "no result");
	    }
	    return cptr->code;
	}
    }

    /*
     *  Dunno, assume result is present.
     */
    if (dbis->debug >= 2) {
        fprintf(DBILOGFP, "Statement command is unknown, assuming result\n");
    }
    return cptr->code;
}


/***************************************************************************
 *
 *  Name:    dbd_st_prepare
 *
 *  Purpose: Called for preparing an SQL statement; our part of the
 *           statement handle constructor
 *
 *  Input:   sth - statement handle being initialized
 *           statement - pointer to string with SQL statement
 *           attribs - statement attributes, currently not in use
 *
 *  Returns: TRUE for success, FALSE otherwise; do_error will
 *           be called in the latter case
 *
 **************************************************************************/

int dbd_st_prepare(SV* sth, char* statement, SV* attribs) {
    D_imp_sth(sth);
    char* ptr = statement;
    int num_param;
    int i;

    /*
     *  Count the number of parameters
     */
    num_param = 0;
    while (*ptr) {
        switch (*ptr++) {
	  case '\'':
	    /*
	     *  Skip string
	     */
	    while (*ptr  &&  *ptr != '\'') {
	        if (*ptr == '\\') {
		    ++ptr;
		}
		if (*ptr) {
		    ++ptr;
		}
	    }
	    if (*ptr) {
	        ++ptr;
	    }
	    break;
	  case '?':
	    ++num_param;
	    break;
	  default:
	    break;
	}
    }
    DBIc_NUM_PARAMS(imp_sth) = num_param;

    /*
     *  Initialize our data
     */
    imp_sth->done_desc = 0;
    imp_sth->cda = NULL;
    imp_sth->currow = 0;
    imp_sth->command = CommandHasResult(statement);
    for (i = 0;  i < AV_ATTRIB_LAST;  i++) {
	imp_sth->av_attr[i] = Nullav;
    }

    /*
     *  Allocate memory for parameters
     */
    if (num_param) {
        Newz(908, imp_sth->params, num_param, imp_sth_ph_t);
    } else {
        imp_sth->params = NULL;
    }

    DBIc_IMPSET_on(imp_sth);

    return 1;
}


/***************************************************************************
 *
 *  Name:    dbd_st_execute
 *
 *  Purpose: Called for preparing an SQL statement; our part of the
 *           statement handle constructor
 *
 *  Input:   sth - statement handle being initialized
 *           statement - pointer to string with SQL statement
 *           attribs - statement attributes, currently not in use
 *
 *  Returns: TRUE for success, FALSE otherwise; do_error will
 *           be called in the latter case
 *
 **************************************************************************/

int dbd_st_execute(SV* sth) {
    D_imp_sth(sth);
    D_imp_dbh_from_sth;
    SV** statement;
    STRLEN slen;
    char* sbuf;
    char* salloc = NULL;
    int i;

    if (dbis->debug >= 2) {
        fprintf(DBILOGFP, "    -> dbd_st_execute for %08lx\n", (u_long) sth);
    }

    if (!SvROK(sth)  ||  SvTYPE(SvRV(sth)) != SVt_PVHV) {
        croak("Expected hash array");
    }

    /*
     *  Free cached array attributes
     */
    for (i = 0;  i < AV_ATTRIB_LAST;  i++) {
	if (imp_sth->av_attr[i]) {
	    SvREFCNT_dec(imp_sth->av_attr[i]);
	}
	imp_sth->av_attr[i] = Nullav;
    }

    statement = hv_fetch((HV*) SvRV(sth), "Statement", 9, FALSE);
    sbuf = SvPV(*statement, slen);

    if (imp_sth->params) {
        int i,j;
	imp_sth_ph_t* ph;
	char* valbuf;
	STRLEN vallen;
	int alen;
	char* ptr;
	int num_params = DBIc_NUM_PARAMS(imp_sth);

        /*
	 *  Count the number of bytes being allocated for the statement
	 */
	alen = slen;
	for (i = 0, ph = imp_sth->params;  i < num_params;  i++, ph++) {
	    if (ph->value) {
	        valbuf = SvPV(ph->value, vallen);
		alen += 2*vallen+2; /* Strings will be quoted */
	    }
	}

	/*
	 *  Allocate memory
	 */
	New(908, salloc, alen+1, char);
	ptr = salloc;

	/*
	 *  Now create the statement string; compare dbd_st_prepare
	 */
	i = 0;
	j = 0;
	while (j < slen) {
	    switch(sbuf[j]) {
	      case '\'':
	        /*
		 * Skip string
		 */
		*ptr++ = sbuf[j++];
		while (j < slen  &&  sbuf[j] != '\'') {
		    if (sbuf[j] == '\\') {
		        *ptr++ = sbuf[j++];
		    }
		    if (j < slen) {
		        *ptr++ = sbuf[j++];
		    }
		}
	        if (j < slen) {
		    *ptr++ = sbuf[j++];
		}
		break;
	      case '?':
	        /*
		 * Insert parameter
		 */
	        j++;
		if (i < num_params  &&  (ph = &imp_sth->params[i])->value) {
		    int isint;

		    ++i;
		    valbuf = SvPV(ph->value, vallen);
		    if (valbuf) {
		        switch (ph->type) {
			  case SQL_NUMERIC:
			  case SQL_DECIMAL:
			  case SQL_INTEGER:
			  case SQL_SMALLINT:
			  case SQL_FLOAT:
			  case SQL_REAL:
			  case SQL_DOUBLE:
			    /* case SQL_BIGINT:     These are commented out */
			    /* case SQL_TINYINT:    in DBI's dbi_sql.h      */
			    isint = TRUE;
			    break;
			  case SQL_CHAR:
			  case SQL_VARCHAR:
			    /* case SQL_DATE:       These are commented out */
			    /* case SQL_TIME:       in DBI's dbi_sql.h      */
			    /* case SQL_TIMESTAMP:                          */
			    /* case LONGVARCHAR:                            */
			    /* case BINARY:                                 */
			    /* case VARBINARY:                              */
			    /* case LONGVARBINARY                           */
			    isint = FALSE;
			    break;
			  default:
			    isint = SvIOK(ph->value) || SvNOK(ph->value);
			    break;
			}

			if (isint) {
			    while (vallen--) {
			        *ptr++ = *valbuf++;
			    }
			} else {
			    *ptr++ = '\'';
			    while (vallen--) {
			        int c;
				switch ((c = *valbuf++)) {
				  case '\0':
				    *ptr++ = '\\';
				    *ptr++ = '0';
				    break;
				  case '\'':
				  case '\\':
				    *ptr++ = '\\';
				    /* No break! */
				  default:
				    *ptr++ = c;
				    break;
				}
			    }
			    *ptr++ = '\'';
			}
		    }
		}
		break;
	      default:
	        *ptr++ = sbuf[j++];
		break;
	    }
	}
	slen = ptr - salloc;
	*ptr++ = '\0';
	sbuf = salloc;
	if (dbis->debug >= 2) {
	    fprintf(DBILOGFP, "      Binding parameters: %s\n", sbuf);
	}
    }

    if (imp_sth->command == COMMAND_LISTFIELDS) {
	char* table;

	while (slen && isspace(*sbuf)) { --slen;  ++sbuf; }
	while (slen && !isspace(*sbuf)) { --slen;  ++sbuf; }
	while (slen && isspace(*sbuf)) { --slen;  ++sbuf; }

	if (!slen) {
	    do_error(sth, JW_ERR_QUERY, "Missing table name");
	    return -2;
	}

	if (!(table = malloc(slen+1))) {
	    do_error(sth, JW_ERR_MEM, "Out of memory");
	    return -2;
	}
	strncpy(table, sbuf, slen);
	table[slen] = '\0';
	imp_sth->cda = MyListFields(imp_dbh->svsock, sbuf);
	free(table);

	if (!imp_sth->cda) {
	    DO_ERROR(sth, JW_ERR_LIST_FIELDS, imp_dbh->svsock);
	    return -2;
	}

	imp_sth->row_num = 0;
    } else {
	if (MyQuery(imp_dbh->svsock, sbuf, slen) == -1) {
	    Safefree(salloc);
	    DO_ERROR(sth, JW_ERR_QUERY, imp_dbh->svsock);
	    return -2;
	}
	Safefree(salloc);

	/** Store the result from the Query */
	if (imp_sth->command < 0) {
#ifdef DBD_MYSQL
	    imp_sth->row_num = mysql_affected_rows(imp_dbh->svsock);
	    if (imp_sth->command == COMMAND_INSERT) {
		imp_sth->insertid = mysql_insert_id(imp_dbh->svsock);
	    }
	    return imp_sth->row_num;
#else
	    imp_sth->row_num = 0;
	    return -1;
#endif
	}

	if (!(imp_sth->cda = MyStoreResult(imp_dbh->svsock))) {
	    DO_ERROR(sth, JW_ERR_QUERY, imp_dbh->svsock);
	    return -2;
	}

	imp_sth->row_num = MyNumRows(imp_sth->cda);
    }

    /** Store the result in the current statement handle */
    DBIc_ACTIVE_on(imp_sth);
    DBIc_NUM_FIELDS(imp_sth) = MyNumFields(imp_sth->cda);
    imp_sth->done_desc = 0;

    if (dbis->debug >= 2) {
        fprintf(DBILOGFP, "    <- dbd_st_execute %d rows\n",
		imp_sth->row_num);
    }
    return imp_sth->row_num;
}


/***************************************************************************
 *
 *  Name:    dbd_describe
 *
 *  Purpose: Called from within the fetch method to describe the result
 *
 *  Input:   sth - statement handle being initialized
 *           imp_sth - our part of the statement handle, there's no
 *               need for supplying both; Tim just doesn't remove it
 *
 *  Returns: TRUE for success, FALSE otherwise; do_error will
 *           be called in the latter case
 *
 **************************************************************************/

int dbd_describe(SV* sth, imp_sth_t* imp_sth) {
    imp_sth->done_desc = 1;
    return TRUE;
}


/***************************************************************************
 *
 *  Name:    dbd_st_fetch
 *
 *  Purpose: Called for fetching a result row
 *
 *  Input:   sth - statement handle being initialized
 *
 *  Returns: array of columns; the array is allocated by DBI via
 *           DBIS->get_fbav(imp_sth), even the values of the array
 *           are prepared, we just need to modify them appropriately
 *
 **************************************************************************/

AV* dbd_st_fetch(SV* sth) {
    D_imp_sth(sth);
    int num_fields;
    int ChopBlanks;
    int i;
    AV *av;
    row_t cols;
#ifdef DBD_MYSQL
    unsigned int* lengths;
#endif

    ChopBlanks = DBIc_is(imp_sth, DBIcf_ChopBlanks);
    if (dbis->debug >= 2) {
        fprintf(DBILOGFP, "    -> dbd_st_fetch for %08lx, chopblanks %d\n",
		(u_long) sth, ChopBlanks);
    }

    if (!imp_sth->cda) {
        return Nullav;
    }

    imp_sth->currow++;
    if (!(cols = MyFetchRow(imp_sth->cda))) {
#ifdef DBD_MYSQL
        if (!mysql_eof(imp_sth->cda)) {
	    D_imp_dbh_from_sth;
	    DO_ERROR(sth, JW_ERR_FETCH_ROW, imp_dbh->svsock);
	}
#endif
	return Nullav;
    }
#ifdef DBD_MYSQL
    lengths = mysql_fetch_lengths(imp_sth->cda);
#endif
    av = DBIS->get_fbav(imp_sth);
    num_fields = AvFILL(av)+1;

    for(i=0; i < num_fields; ++i) {
        char* col = cols[i];
	SV *sv = AvARRAY(av)[i]; /* Note: we (re)use the SV in the AV	*/

	if (col) {
#ifdef DBD_MYSQL
	    STRLEN len = lengths[i];
#else
	    STRLEN len = strlen(col);
#endif
	    if (ChopBlanks) {
		while(len && isspace(*col)) {
		    ++col;
		    --len;
		}
		while(len && isspace(col[len-1])) {
		    --len;
		}
	    }

	    if (dbis->debug >= 2) {
		fprintf(DBILOGFP, "      Storing row %d (%s) in %08lx\n",
			i, col, (u_long) sv);
	    }
	    sv_setpvn(sv, col, len);
	} else {
	    (void) SvOK_off(sv);  /*  Field is NULL, return undef  */
	}
    }

    if (dbis->debug >= 2) {
        fprintf(DBILOGFP, "    <- dbd_st_fetch, %d cols\n", num_fields);
    }
    return av;
}


/***************************************************************************
 *
 *  Name:    dbd_st_finish
 *
 *  Purpose: Called for freeing a mysql result
 *
 *  Input:   sth - statement handle being finished
 *
 *  Returns: TRUE for success, FALSE otherwise; do_error() will
 *           be called in the latter case
 *
 **************************************************************************/

int dbd_st_finish(SV* sth) {
    D_imp_sth(sth);

    /* Cancel further fetches from this cursor.                 */
    /* We don't close the cursor till DESTROY.                  */
    /* The application may re execute it.                       */
    if (imp_sth && imp_sth->cda) {
        MyFreeResult(imp_sth->cda);
	imp_sth->cda = NULL;
    }
    DBIc_ACTIVE_off(imp_sth);
    return 1;
}


/***************************************************************************
 *
 *  Name:    dbd_st_destroy
 *
 *  Purpose: Our part of the statement handles destructor
 *
 *  Input:   sth - statement handle being destroyed
 *
 *  Returns: Nothing
 *
 **************************************************************************/

void dbd_st_destroy(SV* sth) {
    D_imp_sth(sth);
    int i;

    /*
     *  Free values allocated by dbd_bind_ph
     */
    if (imp_sth->params) {
        int i, num_param;
	num_param = DBIc_NUM_PARAMS(imp_sth);
	for (i = 0;  i < num_param;  i++) {
	    imp_sth_ph_t* ph = &imp_sth->params[i];
	    if (ph->value) {
	        (void) SvREFCNT_dec(ph->value);
		ph->value = NULL;
	    }
	}
	Safefree(imp_sth->params);
	imp_sth->params = NULL;
    }

    /*
     *  Free cached array attributes
     */
    for (i = 0;  i < AV_ATTRIB_LAST;  i++) {
	if (imp_sth->av_attr[i]) {
	    SvREFCNT_dec(imp_sth->av_attr[i]);
	}
	imp_sth->av_attr[i] = Nullav;
    }

    DBIc_IMPSET_off(imp_sth);           /* let DBI know we've done it   */
}


/***************************************************************************
 *
 *  Name:    dbd_st_STORE_attrib
 *
 *  Purpose: Modifies a statement handles attributes; we currently
 *           support just nothing
 *
 *  Input:   sth - statement handle being destroyed
 *           keysv - attribute name
 *           valuesv - attribute value
 *
 *  Returns: TRUE for success, FALSE otrherwise; do_error will
 *           be called in the latter case
 *
 **************************************************************************/

int dbd_st_STORE_attrib(SV* sth, SV* keysv, SV* valuesv) {
    STRLEN(kl);
    char* key = SvPV(keysv, kl);
    int result = FALSE;

    if (dbis->debug >= 2) {
        fprintf(DBILOGFP,
		"    -> dbd_st_STORE_attrib for %08lx, key %s\n",
		(u_long) sth, key);
    }

    if (dbis->debug >= 2) {
        fprintf(DBILOGFP,
		"    <- dbd_st_STORE_attrib for %08lx, result %d\n",
		(u_long) sth, result);
    }

    return result;
}


/***************************************************************************
 *
 *  Name:    dbd_st_FETCH_internal
 *
 *  Purpose: Retrieves a statement handles array attributes; we use
 *           a separate function, because creating the array
 *           attributes shares much code and it aids in supporting
 *           enhanced features like caching.
 *
 *  Input:   sth - statement handle; may even be a database handle,
 *               in which case this will be used for storing error
 *               messages only. This is only valid, if cacheit (the
 *               last argument) is set to TRUE.
 *           what - internal attribute number
 *           res - pointer to a DBMS result
 *           cacheit - TRUE, if results may be cached in the sth.
 *
 *  Returns: RV pointing to result array in case of success, NULL
 *           otherwise; do_error has already been called in the latter
 *           case.
 *
 **************************************************************************/

#ifndef IS_KEY
#define IS_KEY(A) (((A) & (PRI_KEY_FLAG | UNIQUE_KEY_FLAG | MULTIPLE_KEY_FLAG)) != 0)
#endif
#ifndef IS_NUM
#ifdef DBD_MYSQL
#define IS_NUM(A) ((A) >= (int) FIELD_TYPE_DECIMAL && (A) <= FIELD_TYPE_DATETIME)
#else
#define IS_NUM(A) ((A) == INT_TYPE || (A) == REAL_TYPE || (A) == UINT_TYPE)
#endif
#endif

SV* dbd_st_FETCH_internal(SV* sth, int what, result_t res, int cacheit) {
    imp_sth_t* imp_sth;
    AV *av = Nullav;
    field_t curField;

    /*
     *  Are we asking for a legal value?
     */
    if (what < 0 ||  what >= AV_ATTRIB_LAST) {
	do_error(sth, JW_ERR_NOT_IMPLEMENTED, "Not implemented");

    /*
     *  Return cached value, if possible
     */
    } else if (cacheit  &&
	       (imp_sth = (imp_sth_t*) DBIh_COM(sth))->av_attr[what]) {
	av = imp_sth->av_attr[what];

    /*
     *  Does this sth really have a result?
     */
    } else if (!res) {
	do_error(sth, JW_ERR_NOT_ACTIVE,
		 "statement contains no result");

    /*
     *  Do the real work.
     */
    } else {
	av = newAV();
	MyFieldSeek(res, 0);
	while ((curField = MyFetchField(res))) {
	    SV* sv;

	    switch(what) {
	      case AV_ATTRIB_NAME:
		sv = newSVpv(curField->name, strlen(curField->name));
		break;
	      case AV_ATTRIB_TABLE:
		sv = newSVpv(curField->table, strlen(curField->table));
		break;
	      case AV_ATTRIB_TYPE:
		sv = newSViv((int) curField->type);
		break;
	      case AV_ATTRIB_IS_PRI_KEY:
		sv = boolSV(IS_PRI_KEY(curField->flags));
		break;
	      case AV_ATTRIB_IS_NOT_NULL:
		sv = boolSV(IS_NOT_NULL(curField->flags));
		break;
	      case AV_ATTRIB_NULLABLE:
		sv = boolSV(!IS_NOT_NULL(curField->flags));
		break;
	      case AV_ATTRIB_LENGTH:
		sv = newSViv((int) curField->length);
		break;
	      case AV_ATTRIB_IS_NUM:
		sv = boolSV(IS_NUM(curField->flags));
		break;
	      case AV_ATTRIB_TYPE_NAME:
	        {
		    static struct db_types {
			int id;
			const char* name;
		    } types [] = {
#ifdef DBD_MYSQL
			{ FIELD_TYPE_BLOB, "blob" },
			{ FIELD_TYPE_CHAR, "char" },
			{ FIELD_TYPE_DECIMAL, "decimal" },
			{ FIELD_TYPE_DATE, "date" },
			{ FIELD_TYPE_DATETIME, "datetime" },
			{ FIELD_TYPE_DOUBLE, "double" },
			{ FIELD_TYPE_FLOAT, "float" },
			{ FIELD_TYPE_INT24, "int24" },
			{ FIELD_TYPE_LONGLONG, "longlong" },
			{ FIELD_TYPE_LONG_BLOB, "longblob" },
			{ FIELD_TYPE_LONG, "long" },
			{ FIELD_TYPE_NULL, "null" },
			{ FIELD_TYPE_SHORT, "short" },
			{ FIELD_TYPE_STRING, "string" },
			{ FIELD_TYPE_TINY_BLOB, "tinyblob" },
			{ FIELD_TYPE_TIMESTAMP, "timestamp" },
			{ FIELD_TYPE_TIME, "time" },
			{ FIELD_TYPE_VAR_STRING, "varstring" }
#else
			{ INT_TYPE, "int" },
			{ CHAR_TYPE, "char" },
			{ REAL_TYPE, "real" },
			{ IDENT_TYPE, "ident" },
			{ IDX_TYPE, "index" },
			{ TEXT_TYPE, "text" },
			{ DATE_TYPE, "date" },
			{ UINT_TYPE, "uint" },
			{ MONEY_TYPE, "money" },
			{ TIME_TYPE, "time" },
			{ SYSVAR_TYPE, "sys" }
#endif
		    };
		    int i, found = FALSE;
		    for (i = 0;  i < sizeof(types) / sizeof(struct db_types);
			 i++) {
			if (curField->type == types[i].id) {
			    sv = newSVpv((char*) types[i].name,
					 strlen(types[i].name));
			    found = TRUE;
			    break;
			}
		    }
		    if (!found) {
			sv = newSVpv((char*) "unknown", 7);
		    }
		}
	        break;
#ifdef DBD_MYSQL
	      case AV_ATTRIB_MAX_LENGTH:
		sv = newSViv((int) curField->max_length);
		break;
	      case AV_ATTRIB_IS_KEY:
		sv = boolSV(IS_KEY(curField->flags));
		break;
	      case AV_ATTRIB_IS_BLOB:
		sv = boolSV(IS_BLOB(curField->flags));
		break;
#endif
	    }

	    av_push(av, sv);
	}

	/*
	 *  Ensure that this value is kept, decremented in
	 *  dbd_st_destroy and dbd_st_execute.
	 */
	if (cacheit) {
	    imp_sth->av_attr[what] = (AV*) SvREFCNT_inc((SV*)av);
	}
    }

    if (av == Nullav) {
	return &sv_undef;
    }
    return sv_2mortal(newRV_noinc((SV*)av));
}


/***************************************************************************
 *
 *  Name:    dbd_st_FETCH_attrib
 *
 *  Purpose: Retrieves a statement handles attributes
 *
 *  Input:   sth - statement handle being destroyed
 *           keysv - attribute name
 *
 *  Returns: NULL for an unknown attribute, "undef" for error,
 *           attribute value otherwise.
 *
 **************************************************************************/

#define ST_FETCH_AV(what) \
    dbd_st_FETCH_internal(sth, (what), imp_sth->cda, TRUE)

SV* dbd_st_FETCH_attrib(SV* sth, SV* keysv) {
    D_imp_sth(sth);
    STRLEN(kl);
    char* key = SvPV(keysv, kl);
    SV* retsv = Nullsv;

    if (dbis->debug >= 2) {
        fprintf(DBILOGFP,
		"    -> dbd_st_FETCH_attrib for %08lx, key %s\n",
		(u_long) sth, key);
    }

    switch (*key) {
      case 'I':
	/*
	 *  Deprecated, use lower case versions.
	 */
	if (strEQ(key, "IS_PRI_KEY")) {
	    retsv = ST_FETCH_AV(AV_ATTRIB_IS_PRI_KEY);
	} else if (strEQ(key, "IS_NOT_NULL")) {
	    retsv = ST_FETCH_AV(AV_ATTRIB_IS_NOT_NULL);
#ifdef DBD_MYSQL
	} else if (strEQ(key, "IS_KEY")) {
	    retsv = ST_FETCH_AV(AV_ATTRIB_IS_KEY);
	} else if (strEQ(key, "IS_BLOB")) {
	    retsv = ST_FETCH_AV(AV_ATTRIB_IS_BLOB);
#endif
	} else if (strEQ(key, "IS_NUM")) {
	    retsv = ST_FETCH_AV(AV_ATTRIB_IS_NUM);
	}
	break;
      case 'L':
	/*
	 *  Deprecated, use lower case versions.
	 */
	if (strEQ(key, "LENGTH")) {
	    retsv = ST_FETCH_AV(AV_ATTRIB_LENGTH);
	}
	break;
#ifdef DBD_MYSQL
      case 'M':
	/*
	 *  Deprecated, use max_length
	 */
	if (strEQ(key, "MAXLENGTH")) {
	    retsv = ST_FETCH_AV(AV_ATTRIB_MAX_LENGTH);
	}
	break;
#endif
      case 'N':
	if (strEQ(key, "NAME")) {
	    retsv = ST_FETCH_AV(AV_ATTRIB_NAME);
	} else if (strEQ(key, "NULLABLE")) {
	    retsv = ST_FETCH_AV(AV_ATTRIB_NULLABLE);
	} else if (strEQ(key, "NUMROWS")) {
	    retsv = sv_2mortal(newSViv((IV)imp_sth->row_num));
	} else if (strEQ(key, "NUMFIELDS")) {
	    retsv = sv_2mortal(newSViv((IV) DBIc_NUM_FIELDS(imp_sth)));
	}
	break;
      case 'R':
	/*
	 * Deprecated, use 'result'
	 */
	if (strEQ(key, "RESULT")) {
	    retsv = sv_2mortal(newSViv((IV) imp_sth->cda));
	}
	break;
      case 'T':
	/*
	 *  Deprecated, use lower case versions.
	 */
	if (strEQ(key, "TABLE")) {
	    retsv = ST_FETCH_AV(AV_ATTRIB_TABLE);
	} else if (strEQ(key, "TYPE")) {
	    retsv = ST_FETCH_AV(AV_ATTRIB_TYPE);
	}
      case 'f':
	if (strEQ(key, "format_max_size")) {
	    retsv = ST_FETCH_AV(AV_ATTRIB_LENGTH);
#ifdef DBD_MYSQL
	} else if (strEQ(key, "format_default_size")) {
	    retsv = ST_FETCH_AV(AV_ATTRIB_MAX_LENGTH);
#endif
	} else if (strEQ(key, "format_right_justify")) {
	    retsv = ST_FETCH_AV(AV_ATTRIB_IS_NUM);
	} else if (strEQ(key, "format_type_name")) {
	    retsv = ST_FETCH_AV(AV_ATTRIB_TYPE_NAME);
	}
	break;
      case 'i':
	if (strEQ(key, "insertid")) {
	    retsv = sv_2mortal(newSViv(imp_sth->insertid));
	} else if (strEQ(key, "is_pri_key")) {
	    retsv = ST_FETCH_AV(AV_ATTRIB_IS_PRI_KEY);
	} else if (strEQ(key, "is_not_null")) {
	    retsv = ST_FETCH_AV(AV_ATTRIB_IS_NOT_NULL);
#ifdef DBD_MYSQL
	} else if (strEQ(key, "is_key")) {
	    retsv = ST_FETCH_AV(AV_ATTRIB_IS_KEY);
	} else if (strEQ(key, "is_blob")) {
	    retsv = ST_FETCH_AV(AV_ATTRIB_IS_BLOB);
#endif
	} else if (strEQ(key, "is_num")) {
	    retsv = ST_FETCH_AV(AV_ATTRIB_IS_NUM);
	}
	break;
      case 'l':
	if (strEQ(key, "length")) {
	    retsv = ST_FETCH_AV(AV_ATTRIB_LENGTH);
	}
	break;
#ifdef DBD_MYSQL
      case 'm':
	if (strEQ(key, "max_length")) {
	    retsv = ST_FETCH_AV(AV_ATTRIB_MAX_LENGTH);
	}
	break;
#endif
      case 'r':
	/*
	 * Deprecated, use 'result'
	 */
	if (strEQ(key, "result")) {
	    retsv = sv_2mortal(newSViv((IV) imp_sth->cda));
	}
	break;
      case 't':
	if (strEQ(key, "table")) {
	    retsv = ST_FETCH_AV(AV_ATTRIB_TABLE);
	} else if (strEQ(key, "type")) {
	    retsv = ST_FETCH_AV(AV_ATTRIB_TYPE);
	}
    }

    if (dbis->debug >= 2) {
        fprintf(DBILOGFP,
		"    <- dbd_st_FETCH_attrib for %08lx, key %s: result %s\n",
		(u_long) sth, key, retsv ? SvPV(retsv, na) : "NULL");
    }

    return retsv;
}


/***************************************************************************
 *
 *  Name:    dbd_st_blob_read
 *
 *  Purpose: Used for blob reads if the statement handles "LongTruncOk"
 *           attribute (currently not supported by DBD::mysql)
 *
 *  Input:   SV* - statement handle from which a blob will be fetched
 *           field - field number of the blob (note, that a row may
 *               contain more than one blob)
 *           offset - the offset of the field, where to start reading
 *           len - maximum number of bytes to read
 *           destrv - RV* that tells us where to store
 *           destoffset - destination offset
 *
 *  Returns: TRUE for success, FALSE otrherwise; do_error will
 *           be called in the latter case
 *
 **************************************************************************/

int dbd_st_blob_read(SV* sth, int field, long offset, long len,
		     SV* destrv, long destoffset) {
    return FALSE;
}


/***************************************************************************
 *
 *  Name:    dbd_st_rows
 *
 *  Purpose: Reads number of result rows
 *
 *  Input:   sth - statement handle
 *
 *  Returns: Number of rows returned or affected by executing the
 *           statement
 *
 **************************************************************************/

int dbd_st_rows(SV* sth) {
    D_imp_sth(sth);

    return imp_sth->row_num;
}


/***************************************************************************
 *
 *  Name:    dbd_bind_ph
 *
 *  Purpose: Binds a statement value to a parameter
 *
 *  Input:   sth - statement handle
 *           param - parameter number, counting starts with 1
 *           value - value being inserted for parameter "param"
 *           attribs - bind parameter attributes, currently this must be
 *               one of the values SQL_CHAR, ...
 *           inout - TRUE, if parameter is an output variable (currently
 *               this is not supported)
 *           b - ???
 *
 *  Returns: TRUE for success, FALSE otherwise
 *
 **************************************************************************/

int
dbd_bind_ph(sth, param, value, attribs, inout, b)
    SV *sth;
    SV *param;
    SV *value;
    SV *attribs;
    int inout,b;
{
    D_imp_sth(sth);
    int paramNum = SvIV(param);
    imp_sth_ph_t* ph;

    if (paramNum <= 0  ||  paramNum > DBIc_NUM_PARAMS(imp_sth)) {
        do_error(sth, JW_ERR_ILLEGAL_PARAM_NUM,
		       "Illegal parameter number");
	return FALSE;
    }

    if (inout) {
        do_error(sth, JW_ERR_NOT_IMPLEMENTED,
		       "Output parameters not implemented");
	return FALSE;
    }

    ph = &imp_sth->params[paramNum - 1];
    if (ph->value) {
        (void) SvREFCNT_dec(ph->value);
    }
    (void) SvREFCNT_inc(ph->value = value);
    ph->type = attribs ? SvIV(attribs) : 0;
    return TRUE;
}

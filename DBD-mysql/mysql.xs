/* Hej, Emacs, this is -*- C -*- mode!

   $Id: mysql.xs,v 1.1.1.1 1997/08/27 10:32:15 joe Exp $

   Copyright (c) 1994,1995  Tim Bunce

   You may distribute under the terms of either the GNU General Public
   License or the Artistic License, as specified in the Perl README file,
   with the exception that it cannot be placed on a CD-ROM or similar media
   for commercial distribution without the prior approval of the author.

*/

#include "dbdimp.h"


/* --- Variables --- */


DBISTATE_DECLARE;


MODULE = DBD::mysql	PACKAGE = DBD::mysql

REQUIRE:    1.929
PROTOTYPES: DISABLE

BOOT:
    items = 0;	/* avoid 'unused variable' warning */
    DBISTATE_INIT;
    /* XXX this interface will change: */
    DBI_IMP_SIZE("DBD::mysql::dr::imp_data_size", sizeof(imp_drh_t));
    DBI_IMP_SIZE("DBD::mysql::db::imp_data_size", sizeof(imp_dbh_t));
    DBI_IMP_SIZE("DBD::mysql::st::imp_data_size", sizeof(imp_sth_t));
    dbd_init(DBIS);


MODULE = DBD::mysql	PACKAGE = DBD::mysql::dr

# disconnect_all renamed and ALIAS'd to avoid length clash on VMS :-(
void
discon_all_(drh)
    SV *	drh
	ALIAS:
	disconnect_all = 1
    CODE:
    if (!dirty && !SvTRUE(perl_get_sv("DBI::PERL_ENDING",0))) {
	D_imp_drh(drh);
	sv_setiv(DBIc_ERR(imp_drh), (IV)1);
	sv_setpv(DBIc_ERRSTR(imp_drh),
		(char*)"disconnect_all not implemented");
	DBIh_EVENT2(drh, ERROR_event,
                    DBIc_ERR(imp_drh), DBIc_ERRSTR(imp_drh));
	XSRETURN(0);
    }
    /* perl_destruct with perl_destruct_level and $SIG{__WARN__} set	*/
    /* to a code ref core dumps when sv_2cv triggers warn loop.		*/
    if (perl_destruct_level)
	perl_destruct_level = 0;
    XST_mIV(0, 1);


void
_ListDBs(drh, host)
    SV *        drh
    char *	host
  PPCODE:
#ifdef DBD_MYSQL
    MYSQL mysql;
    dbh_t sock = &mysql;
    if (dbd_db_connect(sock,host,NULL,NULL)) {
#else
    dbh_t sock;
    if (dbd_db_connect(&sock,host,NULL,NULL)) {
#endif
        result_t res;
        row_t cur;
        res = MyListDbs(sock);
        if (!res) {
            do_error(drh, JW_ERR_LIST_DB, MyError(sock));
        } else {
            EXTEND(sp, MyNumRows(res));
	    while ((cur = MyFetchRow(res))) {
	        PUSHs(sv_2mortal((SV*)newSVpv(cur[0], strlen(cur[0]))));
	    }
	    MyFreeResult(res);
        }
        MyClose(sock);
    }


void
_CreateDB(drh, host, dbname)
    SV *        drh
    char *      host
    char *      dbname
    PPCODE:
#ifdef DBD_MYSQL
    MYSQL mysql;
    dbh_t sock = &mysql;
    if (dbd_db_connect(sock,host,NULL,NULL)) {
#else
    dbh_t sock;
    if (dbd_db_connect(&sock,host,NULL,NULL)) {
#endif
        if (!MyCreateDb(sock,dbname)) {
            XPUSHs(sv_2mortal((SV*)newSVpv("OK", 2)));
        } else {
            do_error(drh, JW_ERR_CREATE_DB, MyError(sock));
        }
        MyClose(sock);
    } else {
        do_error(drh, JW_ERR_CONNECT, MyError(sock));
    }


void
_DropDB(drh, host, dbname)
    SV *        drh
    char *      host
    char *      dbname
    PPCODE:
#ifdef DBD_MYSQL
    MYSQL mysql;
    dbh_t sock = &mysql;
    if (dbd_db_connect(sock,host,NULL,NULL)) {
#else
    dbh_t sock;
    if (dbd_db_connect(&sock,host,NULL,NULL)) {
#endif
        if (MyDropDb(sock,dbname) != -1) {
            XPUSHs(sv_2mortal((SV*)newSVpv("OK", 2)));
        } else {
            do_error(drh, JW_ERR_DROP_DB, MyError(sock));
        }
        MyClose(sock);
    } else {
        do_error(drh, JW_ERR_CONNECT, MyError(sock));
    }


MODULE = DBD::mysql    PACKAGE = DBD::mysql::db

void
_login(dbh, dbname, uid, pwd)
    SV *	dbh
    char *	dbname
    char *	uid
    char *	pwd
    CODE:
    ST(0) = dbd_db_login(dbh, dbname, uid, pwd) ? &sv_yes : &sv_no;


void
commit(dbh)
    SV *	dbh
    CODE:
    ST(0) = dbd_db_commit(dbh) ? &sv_yes : &sv_no;

void
rollback(dbh)
    SV *	dbh
    CODE:
    ST(0) = dbd_db_rollback(dbh) ? &sv_yes : &sv_no;


void
STORE(dbh, keysv, valuesv)
    SV *	dbh
    SV *	keysv
    SV *	valuesv
    CODE:
    ST(0) = &sv_yes;
    if (!dbd_db_STORE_attrib(dbh, keysv, valuesv))
	if (!DBIS->set_attr(dbh, keysv, valuesv))
	    ST(0) = &sv_no;

void
FETCH(dbh, keysv)
    SV *	dbh
    SV *	keysv
    CODE:
    SV *valuesv = dbd_db_FETCH_attrib(dbh, keysv);
    if (!valuesv)
	valuesv = DBIS->get_attr(dbh, keysv);
    ST(0) = valuesv;	/* dbd_db_FETCH_attrib did sv_2mortal	*/


void
disconnect(dbh)
    SV *	dbh
    CODE:
    D_imp_dbh(dbh);
    if ( !DBIc_ACTIVE(imp_dbh) ) {
	XSRETURN_YES;
    }
    /* Check for disconnect() being called whilst refs to cursors	*/
    /* still exists. This possibly needs some more thought.		*/
    if (DBIc_ACTIVE_KIDS(imp_dbh) && DBIc_WARN(imp_dbh) && !dirty) {
	warn("disconnect(%s) invalidates %d active cursor(s)",
	    SvPV(dbh,na), (int)DBIc_ACTIVE_KIDS(imp_dbh));
    }
    ST(0) = dbd_db_disconnect(dbh) ? &sv_yes : &sv_no;


void
DESTROY(dbh)
    SV *	dbh
    PPCODE:
    D_imp_dbh(dbh);
    ST(0) = &sv_yes;
    if (!DBIc_IMPSET(imp_dbh)) {	/* was never fully set up	*/
	if (DBIc_WARN(imp_dbh) && !dirty && dbis->debug >= 2)
	     warn("Database handle %s DESTROY ignored - never set up",
		SvPV(dbh,na));
    }
    else {
	if (DBIc_ACTIVE(imp_dbh)) {
	    static int auto_rollback = -1;
	    if (DBIc_WARN(imp_dbh) && (!dirty || dbis->debug >= 3))
		 warn("Database handle destroyed without explicit disconnect");
	    /* The application has not explicitly disconnected. That's bad.  */
	    /* To ensure integrity we *must* issue a rollback. This will be  */
	    /* harmless	if the application has issued a commit. If it hasn't */
	    /* then it'll ensure integrity. Consider a Ctrl-C killing perl   */
	    /* between two statements that must be executed as a transaction.*/
	    /* Perl will call DESTROY on the dbh and, if we don't rollback,  */
	    /* the server will automatically commit! Bham! Corrupt database! */
	    if (auto_rollback == -1) {	  /* need to determine behaviour     */
	        /* DBD_ORACLE_AUTO_ROLLBACK is offered as a _temporary_ sop  */
		/* to those who can't fix their code in a short timescale.   */
		char *p = getenv("DBD_ORACLE_AUTO_ROLLBACK");
		auto_rollback = (p) ? atoi(p) : 1;
	    }
	    if (auto_rollback)
		dbd_db_rollback(dbh);	/* ROLLBACK! */
	    dbd_db_disconnect(dbh);
	}
	dbd_db_destroy(dbh);
    }


#ifdef DBD_MYSQL

void
_InsertID(dbh)
    SV *	dbh
    PPCODE:
    D_imp_dbh(dbh);
    int id;
    MYSQL *sock = &imp_dbh->svsock;
    EXTEND( sp, 1 );
    id = mysql_insert_id(sock);
    PUSHs( sv_2mortal((SV*)newSViv(id)) );

#endif

void
_ListDBs(dbh)
    SV*	dbh
  PPCODE:
    D_imp_dbh(dbh);
    result_t res;
    row_t cur;
    res = MyListDbs(imp_dbh->svsock);
    if (!res) {
        do_error(dbh, JW_ERR_LIST_DB, MyError(imp_dbh->svsock));
    } else {
        EXTEND(sp, MyNumRows(res));
	while ((cur = MyFetchRow(res))) {
	    PUSHs(sv_2mortal((SV*)newSVpv(cur[0], strlen(cur[0]))));
	}
	MyFreeResult(res);
    }
    MyClose(imp_dbh->svsock);



void
_SelectDB(dbh, dbname)
    SV *	dbh
    char *	dbname
    PPCODE:
    D_imp_dbh(dbh);
#ifdef DBD_MYSQL
    if (imp_dbh->svsock->net.fd != -1) {
#else
    if (imp_dbh->svsock != -1) {
#endif
        if (MySelectDb(imp_dbh->svsock, dbname) == -1) {
            do_error(dbh, JW_ERR_SELECT_DB, 
			   MyError(imp_dbh->svsock));
        }
    }


void
_ListTables(dbh)
    SV *	dbh
    PPCODE:
    D_imp_dbh(dbh);
    result_t res;
    row_t cur;
    res = MyListTables(imp_dbh->svsock);
    if (!res) {
        do_error(dbh, JW_ERR_LIST_TABLES, MyError(imp_dbh->svsock));
    } else {
        while ((cur = MyFetchRow(res))) {
            XPUSHs(sv_2mortal((SV*)newSVpv( cur[0], strlen(cur[0]))));
        }
        MyFreeResult(res);
    }
 


void
_ListFields(dbh, tabname)
    SV* 	dbh
    char*	tabname
  PPCODE:
    D_imp_dbh(dbh);
    result_t res;
    if (!tabname || *tabname == '\0') {
        do_error(dbh, -1,
	         "Error in _ListFields! Table name was NULL!\n" );
        return;
    }
    res = MyListFields(imp_dbh->svsock, tabname);
    if (!res) {
        do_error(dbh, JW_ERR_LIST_FIELDS, MyError(imp_dbh->svsock));
    } else {
        SV* rv;
        if ((rv = dbd_db_fieldlist(res))) {
            XPUSHs( (SV*)rv );
            MyFreeResult(res);
        }
    }


MODULE = DBD::mysql    PACKAGE = DBD::mysql::st


void
_prepare(sth, statement, attribs=Nullsv)
    SV *	sth
    char *	statement
    SV *	attribs
    CODE:
    DBD_ATTRIBS_CHECK("_prepare", sth, attribs);
    ST(0) = dbd_st_prepare(sth, statement, attribs) ? &sv_yes : &sv_no;


void
rows(sth)
    SV *	sth
    CODE:
    XST_mIV(0, dbd_st_rows(sth));



void
bind_param(sth, param, value, attribs=Nullsv)
    SV *	sth
    SV *	param
    SV *	value
    SV *	attribs
    CODE:
    DBD_ATTRIBS_CHECK("bind_param", sth, attribs);
    ST(0) = dbd_bind_ph(sth, param, value, attribs, FALSE, 0) ? &sv_yes : &sv_no;


void
bind_param_inout(sth, param, value_ref, maxlen, attribs=Nullsv)
    SV *	sth
    SV *	param
    SV *	value_ref
    IV 		maxlen
    SV *	attribs
    CODE:
    DBD_ATTRIBS_CHECK("bind_param_inout", sth, attribs);
    if (!SvROK(value_ref) || SvTYPE(SvRV(value_ref)) > SVt_PVMG)
	croak("bind_param_inout needs a reference to a scalar value");
    if (SvREADONLY(SvRV(value_ref)))
	croak(no_modify);
    ST(0) = dbd_bind_ph(sth, param, SvRV(value_ref), attribs, TRUE, maxlen) ? &sv_yes : &sv_no;


void
execute(sth, ...)
    SV *	sth
    CODE:
    D_imp_sth(sth);
    int retval;
    if (items > 1) {
	/* Handle binding supplied values to placeholders	*/
	int i, error = 0;
        SV *idx;
	if (items-1 != DBIc_NUM_PARAMS(imp_sth)) {
	    croak("execute called with %ld bind variables, %d needed",
		    items-1, DBIc_NUM_PARAMS(imp_sth));
	    XSRETURN_UNDEF;
	}
        idx = sv_2mortal(newSViv(0));
	for(i=1; i < items ; ++i) {
	    sv_setiv(idx, i);
	    if (!dbd_bind_ph(sth, idx, ST(i), Nullsv, FALSE, 0))
		++error;
	}
	if (error) {
	    XSRETURN_UNDEF;	/* dbd_bind_ph already registered error	*/
	}
    }
    retval = dbd_st_execute(sth);
    /* remember that dbd_st_execute must return <= -2 for error	*/
    if (retval == 0)		/* ok with no rows affected	*/
	XST_mPV(0, "0E0");	/* (true but zero)		*/
    else if (retval < -1)	/* -1 == unknown number of rows	*/
	XST_mUNDEF(0);		/* <= -2 means error   		*/
    else
	XST_mIV(0, retval);	/* typically 1, rowcount or -1	*/


void
fetch(sth)
    SV *	sth
    CODE:
    AV *av = dbd_st_fetch(sth);
    ST(0) = (av) ? sv_2mortal(newRV((SV *)av)) : &sv_undef;


void
fetchrow(sth)
    SV *	sth
    PPCODE:
    D_imp_sth(sth);
    AV *av;
    if (DBIc_COMPAT(imp_sth) && GIMME == G_SCALAR) {	/* XXX Oraperl	*/
	/* This non-standard behaviour added only to increase the	*/
	/* performance of the oraperl emulation layer (Oraperl.pm)	*/
	if (!imp_sth->done_desc && !dbd_describe(sth, imp_sth))
		XSRETURN_UNDEF;
	XSRETURN_IV(DBIc_NUM_FIELDS(imp_sth));
    }
    av = dbd_st_fetch(sth);
    if (av) {
	int num_fields = AvFILL(av)+1;
	int i;
	EXTEND(sp, num_fields);
	for(i=0; i < num_fields; ++i) {
	    PUSHs(AvARRAY(av)[i]);
	}
    }



void
blob_read(sth, field, offset, len, destrv=Nullsv, destoffset=0)
    SV *	sth
    int	field
    long	offset
    long	len
    SV *	destrv
    long	destoffset
    CODE:
    if (!destrv)
	destrv = sv_2mortal(newRV(sv_2mortal(newSV(0))));
    if (dbd_st_blob_read(sth, field, offset, len, destrv, destoffset))
	 ST(0) = SvRV(destrv);
    else ST(0) = &sv_undef;


void
STORE(sth, keysv, valuesv)
    SV *	sth
    SV *	keysv
    SV *	valuesv
    CODE:
    ST(0) = &sv_yes;
    if (!dbd_st_STORE_attrib(sth, keysv, valuesv))
	if (!DBIS->set_attr(sth, keysv, valuesv))
	    ST(0) = &sv_no;


# FETCH renamed and ALIAS'd to avoid case clash on VMS :-(
void
FETCH_attrib(sth, keysv)
    SV *	sth
    SV *	keysv
	ALIAS:
	FETCH = 1
    CODE:
    SV *valuesv = dbd_st_FETCH_attrib(sth, keysv);
    if (!valuesv)
	valuesv = DBIS->get_attr(sth, keysv);
    ST(0) = valuesv;	/* dbd_st_FETCH_attrib did sv_2mortal	*/


void
finish(sth)
    SV *	sth
    CODE:
    D_imp_sth(sth);
    D_imp_dbh_from_sth;
    if (!DBIc_ACTIVE(imp_dbh)) {
	/* Either an explicit disconnect() or global destruction	*/
	/* has disconnected us from the database. Finish is meaningless	*/
	/* XXX warn */
	XSRETURN_YES;
    }
    if (!DBIc_ACTIVE(imp_sth)) {
	/* No active statement to finish	*/
	XSRETURN_YES;
    }
    ST(0) = dbd_st_finish(sth) ? &sv_yes : &sv_no;


void
DESTROY(sth)
    SV *	sth
    PPCODE:
    D_imp_sth(sth);
    ST(0) = &sv_yes;
    if (!DBIc_IMPSET(imp_sth)) {	/* was never fully set up	*/
	if (DBIc_WARN(imp_sth) && !dirty && dbis->debug >= 2)
	     warn("Statement handle %s DESTROY ignored - never set up",
		SvPV(sth,na));
    }
    else {
	if (DBIc_ACTIVE(imp_sth))
	    dbd_st_finish(sth);
	dbd_st_destroy(sth);
    }


void
_NumRows(sth)
    SV *	sth
    PPCODE:
    D_imp_sth(sth);
    EXTEND( sp, 1 );
    PUSHs( sv_2mortal((SV*)newSViv(imp_sth->row_num)));


void
_ListSelectedFields(sth)
    SV *	sth
    PPCODE:
    D_imp_sth(sth);
    result_t res;
    SV * rv;
    /**
     *  Set up an empty reference in case of error...
     *  I really have no idea how to do this.
     */
    if (!(res = imp_sth->cda)) {
        do_error(sth, JW_ERR_NO_RESULT,
                       "missing MSQL_RES in mSQLListSelectedFields!");
        XPUSHs(Nullsv);
    } else {
        if (!(rv = dbd_db_fieldlist(res))) {
	    do_error(sth, JW_ERR_LIST_FIELDS,
                           "fieldlist() error in mSQLListSelectedFields!" );
        } else {
	    XPUSHs((SV*)rv);
	}
    }

# end of mSQL.xs

/* Hej, Emacs, this is -*- C -*- mode!

   $Id: mysql.xs,v 1.1809 1997/09/12 18:34:10 joe Exp $

   Copyright (c) 1997 Jochen Wiedmann

   You may distribute under the terms of either the GNU General Public
   License or the Artistic License, as specified in the Perl README file,
   with the exception that it cannot be placed on a CD-ROM or similar media
   for commercial distribution without the prior approval of the author.

*/

#include "dbdimp.h"


/* --- Variables --- */


DBISTATE_DECLARE;


MODULE = DBD::mysql	PACKAGE = DBD::mysql

INCLUDE: mysql.xsi


MODULE = DBD::mysql	PACKAGE = DBD::mysql::dr

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
 

MODULE = DBD::mysql    PACKAGE = DBD::mysql::st

void
_NumRows(sth)
    SV *	sth
    PPCODE:
    D_imp_sth(sth);
    EXTEND( sp, 1 );
    PUSHs( sv_2mortal((SV*)newSViv(imp_sth->row_num)));

# end of mysql.xs

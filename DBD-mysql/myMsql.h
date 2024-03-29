/*
 *  myMsql.h - compatibility support header for msql and mysql
 *
 *  Using this is straightforward. You include this by defining
 *  either DBD_MYSQL or DBD_MSQL and use the macros below. For
 *  example you don't write
 *
 *     m_row row = msqlFetchRow(res);
 *
 *  or
 *
 *     MYSQL_ROW row = mysql_fetch_row(res)
 *
 *  but
 *
 *     row_t row = MyFetchRow(res)
 *
 *  The only important difference is how to connect to a database.
 *  I suggest that you use the dbd_db_connect function for that.
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
 *  $Id: myMsql.h 1.1 Tue, 30 Sep 1997 01:28:08 +0200 joe $
 */

#ifndef MYMSQL_H_INCLUDED
#define MYMSQL_H_INCLUDED 1

#include <sys/types.h>

#ifdef __sun__
extern char** environ;
#endif


/*
 *  Switch between mysql and msql
 */
#ifdef DBD_MSQL

#include <msql.h>   /* installed during the installation of msql itself   */
typedef int dbh_t;
typedef m_result* result_t;
typedef m_row row_t;
typedef m_field* field_t;
#define MyListDbs(s) msqlListDBs(s)
#define MyListTables(s) msqlListTables(s)
#define MyListFields(s, t) msqlListFields(s, t)
#define MySelectDb(s, d) msqlSelectDB(s, d)
#define MyCreateDb(s, d) msqlCreateDB(s, d)
#define MyDropDb(s, d) msqlDropDB(s, d)
#define MyClose(s) msqlClose(s)
#define MyError(s) msqlErrMsg
#define MyQuery(s, q, l) msqlQuery(s, q)
#define MyStoreResult(s) msqlStoreResult()
#define MyGetHostInfo(s) msqlGetHostInfo(s)
#define MyGetServerInfo(s) msqlGetServerInfo()
#define MyGetProtoInfo(s) msqlGetProtoInfo()
#define MyShutdown(s) msqlShutdown(s)
#define MyReload(s) msqlReloadAcls(s)
#define MyNumRows(r) msqlNumRows(r)
#define MyNumFields(r) msqlNumFields(r)
#define MyFetchRow(r) msqlFetchRow(r)
#define MyFetchField(r) msqlFetchField(r)
#define MyFreeResult(r) msqlFreeResult(r)
#define MyFieldSeek(r, i) msqlFieldSeek(r, i)
#define MyDataSeek(r, i) msqlDataSeek(r, i)
#if !defined(IS_PRI_KEY)
#define IS_PRI_KEY(n) ((n) & 4)
#endif

int MyConnect(dbh_t*, char*, char*, char*);

#else

#include <mysql.h>  /* installed during the installation of mysql itself  */
typedef MYSQL* dbh_t;
typedef MYSQL_RES* result_t;
typedef MYSQL_ROW row_t;
typedef MYSQL_FIELD* field_t;
#define MyListDbs(s) mysql_list_dbs(s, NULL)
#define MyListTables(s) mysql_list_tables(s, NULL)
#define MyListFields(s, t) mysql_list_fields(s, t, NULL)
#define MySelectDb(s, d) mysql_select_db(s, d)
#define MyCreateDb(s, d) mysql_create_db(s, d)
#define MyDropDb(s, d) mysql_drop_db(s, d)
#define MyClose(s) mysql_close(s)
#define MyError(s) mysql_error(s)
#define MyQuery(s, q, l) mysql_real_query(s, q, l)
#define MyStoreResult(s) mysql_store_result(s)
#define MyGetHostInfo(s) mysql_get_host_info(s)
#define MyGetServerInfo(s) mysql_get_server_info(s)
#define MyGetProtoInfo(s) mysql_get_proto_info(s)
#define MyShutdown(s) mysql_shutdown(s)
#define MyReload(s) mysql_reload(s)
#define MyNumRows(r) mysql_num_rows(r)
#define MyNumFields(r) mysql_num_fields(r)
#define MyFetchRow(r) mysql_fetch_row(r)
#define MyFetchField(r) mysql_fetch_field(r)
#define MyFreeResult(r) mysql_free_result(r)
#define MyFieldSeek(r, i) mysql_field_seek(r, i)
#define MyDataSeek(r, i) mysql_data_seek(r, i)

int MyConnect(dbh_t, char*, char*, char*);

#if !defined(IS_UNIQUE_KEY)
#define IS_UNIQUE_KEY(n) ((n) & (UNIQUE_KEY_FLAG | PRI_KEY_FLAG))
#endif
#if !defined(IS_KEY)
#define IS_KEY(n) ((n) & (UNIQUE_KEY_FLAG | PRI_KEY_FLAG | MULTIPLE_KEY_FLAG))
#endif

#endif


#endif

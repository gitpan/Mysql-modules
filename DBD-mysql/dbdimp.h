/*
 *  DBD::mSQL - DBI driver for the mysql database
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
 *  $Id: dbdimp.h,v 1.1805 1997/09/03 12:21:36 joe Exp $
 */

/*
 *  Header files we use
 */
#include <DBIXS.h>  /* installed by the DBI module                        */
#include "myMsql.h"


/*
 *  The following are return codes passed in $h->err in case of
 *  errors by DBD::mysql.
 */
enum errMsgs {
    JW_ERR_CONNECT = 1,
    JW_ERR_SELECT_DB,
    JW_ERR_STORE_RESULT,
    JW_ERR_NOT_ACTIVE,
    JW_ERR_QUERY,
    JW_ERR_FETCH_ROW,
    JW_ERR_LIST_DB,
    JW_ERR_CREATE_DB,
    JW_ERR_DROP_DB,
    JW_ERR_LIST_TABLES,
    JW_ERR_LIST_FIELDS,
    JW_ERR_LIST_FIELDS_INT,
    JW_ERR_LIST_SEL_FIELDS,
    JW_ERR_NO_RESULT,
    JW_ERR_NOT_IMPLEMENTED,
    JW_ERR_ILLEGAL_PARAM_NUM,
    JW_ERR_MEM
};


/*
 *  The following values are stored in imp_sth->type.
 *
 *  Positive values indicate a command returning a result, other
 *  commands have negative values.
 */
enum command_types {
    COMMAND_UNKNOWN = 0,
    COMMAND_SELECT,
    COMMAND_SYSTABLES,
    COMMAND_LISTFIELDS,
    COMMAND_CREATE = -1,
    COMMAND_DROP = -2,
    COMMAND_INSERT = -3,
    COMMAND_DELETE = -4,
    COMMAND_UPDATE = -5,
    COMMAND_ALTER = -6
};


/*
 *  Internal constants, used for fetching array attributes
 */
enum av_attribs {
    AV_ATTRIB_NAME = 0,
    AV_ATTRIB_TABLE,
    AV_ATTRIB_TYPE,
    AV_ATTRIB_IS_PRI_KEY,
    AV_ATTRIB_IS_NOT_NULL,
    AV_ATTRIB_NULLABLE,
    AV_ATTRIB_LENGTH,
    AV_ATTRIB_IS_NUM,
    AV_ATTRIB_TYPE_NAME,
#ifdef DBD_MYSQL
    AV_ATTRIB_MAX_LENGTH,
    AV_ATTRIB_IS_KEY,
    AV_ATTRIB_IS_BLOB,
#endif
    AV_ATTRIB_LAST         /*  Dummy attribute, never used, for allocation  */
};                         /*  purposes only                                */


/*
 *  This is our part of the driver handle. We receive the handle as
 *  an "SV*", say "drh", and receive a pointer to the structure below
 *  by declaring
 *
 *    D_imp_drh(drh);
 *
 *  This declares a variable called "imp_drh" of type
 *  "struct imp_drh_st *".
 */
struct imp_drh_st {
    dbih_drc_t com;         /* MUST be first element in structure   */
};


/*
 *  Likewise, this is our part of the database handle, as returned
 *  by DBI->connect. We receive the handle as an "SV*", say "dbh",
 *  and receive a pointer to the structure below by declaring
 *
 *    D_imp_dbh(dbh);
 *
 *  This declares a variable called "imp_dbh" of type
 *  "struct imp_dbh_st *".
 */
struct imp_dbh_st {
    dbih_dbc_t com;         /*  MUST be first element in structure   */
    
#ifdef DBD_MYSQL
    MYSQL mysql;
#endif
    dbh_t svsock;           /*  socket number for msql, &mysql for
			     *  mysql
			     */
};


/*
 *  The bind_param method internally uses this structure for storing
 *  parameters.
 */
typedef struct imp_sth_ph_st {
    SV* value;
    int type;
} imp_sth_ph_t;


/*
 *  Finally our part of the statement handle. We receive the handle as
 *  an "SV*", say "dbh", and receive a pointer to the structure below
 *  by declaring
 *
 *    D_imp_sth(sth);
 *
 *  This declares a variable called "imp_sth" of type
 *  "struct imp_sth_st *".
 */
struct imp_sth_st {
    dbih_stc_t com;       /* MUST be first element in structure     */

    result_t cda;            /* result                                 */
    int currow;           /* number of current row                  */
    int row_num;          /* total number of rows                   */

    int   done_desc;      /* have we described this sth yet ?	    */
    long  long_buflen;    /* length for long/longraw (if >0)	    */
    bool  long_trunc_ok;  /* is truncating a long an error	    */
    int   command;        /* Statement command, e.g. COMMAND_SELECT */
    int   insertid;       /* ID of auto insert                      */
    imp_sth_ph_t* params; /* Pointer to parameter array             */
    AV* av_attr[AV_ATTRIB_LAST];/*  For caching array attributes        */
};


/*
 *  And last, not least: The prototype definitions.
 */
void     dbd_init _((dbistate_t *dbistate));
void	 do_error _((SV* h, int rc, char *what));
int     dbd_db_login _((SV *dbh, char *dbname, char *uid, char *pwd));
int     dbd_db_commit _((SV *dbh));
int     dbd_db_rollback _((SV *dbh));
int     dbd_db_disconnect _((SV *dbh));
void    dbd_db_destroy _((SV *dbh));
int     dbd_db_STORE_attrib _((SV *dbh, SV *keysv, SV *valuesv));
SV      *dbd_db_FETCH_attrib _((SV *dbh, SV *keysv));
SV	*dbd_db_fieldlist _((result_t res));

int     dbd_st_prepare _((SV *sth, char *statement, SV *attribs));
int     dbd_st_finish _((SV *sth));
void    dbd_st_destroy _((SV *sth));
int     dbd_st_STORE_attrib _((SV *sth, SV *keysv, SV *valuesv));
SV      *dbd_st_FETCH_attrib _((SV *sth, SV *keysv));

void    dbd_preparse _((imp_sth_t *imp_sth, SV *statement));
int     dbd_describe _((SV *h, imp_sth_t* sth));
AV      *dbd_st_fetch _((SV *h));
int     dbd_st_rows _((SV *h));
int     dbd_st_execute _((SV* h));

int dbd_bind_ph _((SV *sth, SV *param, SV *value, SV *attribs, int a, int b));
int dbd_st_blob_read _((SV *sth, int field, long offset, long len,
			SV *destrv, long destoffset));

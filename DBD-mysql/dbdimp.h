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
 *  $Id: dbdimp.h,v 1.1.1.1 1997/08/27 10:32:15 joe Exp $
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
#define JW_ERR_CONNECT               1
#define JW_ERR_SELECT_DB             2
#define JW_ERR_STORE_RESULT          3
#define JW_ERR_NOT_ACTIVE            4
#define JW_ERR_QUERY                 5
#define JW_ERR_FETCH_ROW             6
#define JW_ERR_LIST_DB               7
#define JW_ERR_CREATE_DB             8
#define JW_ERR_DROP_DB               9
#define JW_ERR_LIST_TABLES           10
#define JW_ERR_LIST_FIELDS           11
#define JW_ERR_LIST_FIELDS_INT       12
#define JW_ERR_LIST_SEL_FIELDS       13
#define JW_ERR_NO_RESULT             14
#define JW_ERR_NOT_IMPLEMENTED       15
#define JW_ERR_ILLEGAL_PARAM_NUM     16


/*
 *  The following values are stored in imp_sth->type.
 *
 *  Positive values indicate a command returning a result, other
 *  commands have negative values.
 */
#define COMMAND_UNKNOWN    0
#define COMMAND_SELECT     1
#define COMMAND_SYSTABLES  2
#define COMMAND_CREATE    -1
#define COMMAND_DROP      -2
#define COMMAND_INSERT    -3
#define COMMAND_DELETE    -4
#define COMMAND_UPDATE    -5
#define COMMAND_ALTER     -6



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

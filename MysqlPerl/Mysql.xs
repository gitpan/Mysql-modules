/* -*-C-*- */

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include <myMsql.h>

#ifndef IS_PRI_KEY
#define IS_PRI_KEY(a) IS_UNIQUE(a)
#endif

typedef int SysRet;
typedef result_t My__Result;
typedef HV *my_sth_t;
typedef HV *my_dbh_t;

#ifdef DBD_MSQL
static const char* Package   = "Msql";
static const char* StPackage = "Msql::Statement";
static const char* ErrVar    = "Msql::db_errstr";
static const char* QuietVar  = "Msql::QUIET";
#else
static const char* Package   = "Mysql";
static const char* StPackage = "Mysql::Statement";
static const char* ErrVar    = "Mysql::db_errstr";
static const char* QuietVar  = "Mysql::QUIET";
#endif


#define dBSV				        \
  HV *          hv;				\
  HV *          stash;				\
  SV *          rv;				\
  SV *          sv;				\
  SV *          svsock;				\
  SV *          svdb;				\
  SV *          svhost

#define dRESULT					\
  dBSV;					        \
  My__Result	result = NULL;			\
  SV **		svp;				\
  dbh_t		sock

#define dFETCH		\
  dRESULT;			\
  int		off;		\
  field_t	curField;	\
  row_t		cur

#define dQUERY		\
  HV *          hv;    	       	       	     \
  HV *          stash;			     \
  SV *          rv;			     \
  SV *          sv;			     \
  My__Result  result = NULL;		     \
  SV **         svp;			     \
  dbh_t         sock;			     \
  int           tmp = -1

#define ERRMSG_GENERIC(errmsg)                            \
    {                                                     \
        char* msg = errmsg;                               \
        sv = perl_get_sv((char*)ErrVar, TRUE);            \
        sv_setpv(sv,msg);                                 \
        if (dowarn &&                                     \
	    !SvTRUE(perl_get_sv((char*) QuietVar,TRUE))){ \
	    warn("%s's message: %s", Package, msg);       \
	}                                                 \
        XST_mUNDEF(0);                                    \
        XSRETURN(1);                                      \
    }

#define ERRMSG(sock) ERRMSG_GENERIC(MyError(sock))


#ifdef DBD_MSQL
#define readMYSOCKET                            \
  if ((svp = hv_fetch(handle,"SOCK",4,0))) {    \
    sock = SvIV(*svp);                          \
  } else {                                      \
    sock = -1;                                  \
  }
#define validSOCKET (sock != -1)
#else
#define readMYSOCKET                            \
  if ((svp = hv_fetch(handle,"SOCK",4,0))) {    \
    sock = (dbh_t) SvIV(*svp);                  \
  } else {                                      \
    sock = NULL;                                \
  }
#define validSOCKET (sock != NULL)
#endif

#define readSOCKET				    \
  readMYSOCKET;                                     \
  if ((svp = hv_fetch(handle,"DATABASE",8,FALSE))){ \
    svdb = (SV*)newSVsv(*svp);	                    \
  } else {					    \
    svdb = &sv_undef;		                    \
  }						    \
  if ((svp = hv_fetch(handle,"HOST",4,FALSE))){	    \
    svhost = (SV*)newSVsv(*svp);	            \
  } else {					    \
    svhost = &sv_undef;		                    \
  }

#define readRESULT				  \
  if ((svp = hv_fetch(handle,"RESULT",6,FALSE))){ \
    sv = *svp;					  \
    result = (My__Result)SvIV(sv);		  \
  } else {					  \
    sv =  &sv_undef;		                  \
  }

#define iniHV 	hv = (HV*)sv_2mortal((SV*)newHV())

#define iniAV 	av = (AV*)sv_2mortal((SV*)newAV())

#define MYPERL_FETCH_INTERNAL(a)	\
      iniAV;				\
      MyFieldSeek(result,0);		\
      numfields = MyNumFields(result);  \
      while (off< numfields){		\
	curField = MyFetchField(result);\
	a				\
	off++;				\
      }					\
      RETVAL = newRV((SV*)av)

#ifdef DBD_MYSQL
#define checkRETVAL(r)                    \
      RETVAL = (r);                       \
      if (RETVAL) { ERRMSG(sock); }
#else
#define checkRETVAL(r)                    \
      RETVAL = (r);                       \
      if (RETVAL == -1) { ERRMSG(sock); }
#endif

static int
not_here(s)
char *s;
{
    croak("%s::%s not implemented on this architecture", Package, s);
    return -1;
}



MODULE = Mysql	PACKAGE = Mysql::Statement

PROTOTYPES: ENABLE

SV *
fetchinternal(handle, key)
    my_sth_t handle
    char * key
   PROTOTYPE: $$
   CODE:
{
  /* fetchinternal */
  SV *          sv;
  My__Result	result = NULL;
  SV **		svp;
  AV*	av;
  int	off = 0;
  int	numfields;
  field_t	curField;

  readRESULT;
  switch (*key){
#ifdef DBD_MYSQL
  case 'A':
    if (strEQ(key, "AFFECTEDROWS")){
      if ((svp = hv_fetch(handle,key,13,FALSE))) {
        RETVAL = newSViv((IV) SvIV(*svp));
      }
    }
    break;
#endif
  case 'I':
    if (strEQ(key, "ISNOTNULL")){
	MYPERL_FETCH_INTERNAL(av_push(av,(SV*)newSViv((IV)IS_NOT_NULL(curField->flags))););
    }
    else if (strEQ(key, "ISPRIKEY")) {
	MYPERL_FETCH_INTERNAL(av_push(av,(SV*)newSViv((IV)IS_PRI_KEY(curField->flags))););
    }
#ifdef DBD_MYSQL
    else if (strEQ(key, "ISUNIQUEKEY")) {
	MYPERL_FETCH_INTERNAL(av_push(av,(SV*)newSViv((IV)IS_UNIQUE_KEY(curField->flags))););
    }
    else if (strEQ(key, "ISKEY")) {
	MYPERL_FETCH_INTERNAL(av_push(av,(SV*)newSViv((IV)IS_KEY(curField->flags))););
    }
    else if (strEQ(key, "ISBLOB")) {
	MYPERL_FETCH_INTERNAL(av_push(av,(SV*)newSViv((IV)IS_BLOB(curField->flags))););
    }
    else if (strEQ(key, "ISBLOB")) {
	MYPERL_FETCH_INTERNAL(av_push(av,(SV*)newSViv((IV)IS_NUM(curField->flags))););
    }
    else if (strEQ(key, "INSERTID")) {
	if ((svp = hv_fetch(handle, key, 8, 0))) {
	    RETVAL = newSViv(SvIV(*svp));
	}
    }
#endif
    break;
  case 'L':
    if (strEQ(key, "LENGTH")) {
	MYPERL_FETCH_INTERNAL(av_push(av,(SV*)newSViv((IV)curField->length)););
    }
    break;
  case 'N':
    if (strEQ(key, "NAME")) {
	MYPERL_FETCH_INTERNAL(av_push(av,(SV*)newSVpv(curField->name,strlen(curField->name))););
    }
    else if (strEQ(key, "NUMFIELDS")){
      RETVAL = newSViv((IV)MyNumFields(result));
    }
    else if (strEQ(key, "NUMROWS")){
      RETVAL = newSViv((IV)MyNumRows(result));
    }
    break;
  case 'R':
    if (strEQ(key, "RESULT"))
      RETVAL = newSViv((IV)result);
    break;
  case 'T':
    if (strEQ(key, "TABLE")) {
	MYPERL_FETCH_INTERNAL(av_push(av,(SV*)newSVpv(curField->table,strlen(curField->table))););
    }
    else if (strEQ(key, "TYPE")) {
	MYPERL_FETCH_INTERNAL(av_push(av,(SV*)newSViv((IV) curField->type)););
    }
    break;
  }
}
   OUTPUT:
     RETVAL

SV *
fetchrow(handle)
   my_sth_t	handle
   PROTOTYPE: $
   PPCODE:
{
/* This one is very simple, it just returns us an array of the fields
   of a row. If we want to know more about the fields, we look into
   $sth->{XXX}, where XXX may be one of NAME, TABLE, TYPE, IS_PRI_KEY,
   and IS_NOT_NULL */

  dFETCH;
  int		placeholder = 1;

  readRESULT;
  if (result && (cur = MyFetchRow(result))) {
#ifdef DBD_MYSQL
    unsigned int* lengths = mysql_fetch_lengths(result);
#endif
    off = 0;
    MyFieldSeek(result,0);
    if (MyNumFields(result) > 0)
      placeholder = MyNumFields(result);
    EXTEND(sp,placeholder);
    while(off < placeholder){
      curField = MyFetchField(result);

      if (cur[off]){
#ifdef DBD_MYSQL
	STRLEN len = lengths[off];
#else
	STRLEN len = strlen(cur[off]);
#endif
	PUSHs(sv_2mortal((SV*)newSVpv(cur[off], len)));
      }else{
	PUSHs(&sv_undef);
      }
      off++;
    }
  } else if (!result) {
    ERRMSG_GENERIC("Can't call method; query produced no result.");
  }
}

SV *
fetchcol(handle,col)
   my_sth_t	handle
   int col
   PROTOTYPE: $$
   PPCODE:
{
  /*  This method returns an array containing all the elements of a
   *  given column.
   */

  dFETCH;
  readRESULT;
  if (result && (col >= 0  &&  col < MyNumFields(result))) {
    EXTEND(sp, MyNumRows(result));
    MyDataSeek(result, 0);
    while ((cur = MyFetchRow(result))) {
      if (cur[col]) {
	STRLEN len;
#ifdef DBD_MYSQL
	unsigned int* lengths = mysql_fetch_lengths(result);
	len = lengths[col];
#else
	len = strlen(cur[col]);
#endif
	PUSHs(sv_2mortal((SV*)newSVpv(cur[col], len)));
      } else {
	PUSHs(&sv_undef);
      }
    }
  } else if (!result) {
    ERRMSG_GENERIC("Can't call method; query produced no result.");
  }
}

SV *
fetchhash(handle)
   my_sth_t	handle
   PROTOTYPE: $
   PPCODE:
{

  dFETCH;
  int		placeholder = 1;

  readRESULT;
  if (result && (cur = MyFetchRow(result))) {
#ifdef DBD_MYSQL
    unsigned int* lengths = mysql_fetch_lengths(result);
#endif
    off = 0;
    MyFieldSeek(result,0);
    if (MyNumFields(result) > 0)
      placeholder = MyNumFields(result);
    EXTEND(sp,placeholder*2);
    while(off < placeholder){
      curField = MyFetchField(result);
      PUSHs(sv_2mortal((SV*)newSVpv(curField->name,strlen(curField->name))));
      if (cur[off]){
#ifdef DBD_MYSQL
	STRLEN len = lengths[off];
#else
	STRLEN len = strlen(cur[off]);
#endif
	PUSHs(sv_2mortal((SV*)newSVpv(cur[off], len)));
      }else{
	PUSHs(&sv_undef);
      }

      off++;
    }
  } else if (!result) {
    ERRMSG_GENERIC("Can't call method; query produced no result.");
  }
}


SV *
dataseek(handle,pos)
   my_sth_t	handle
   unsigned int			pos
   PROTOTYPE: $$
   CODE:
{
/* In my eyes, we don't need that, but as it's there we implement it,
   of course: set the position of the cursor to a specified record
   number. */

  My__Result	result = NULL;
  SV *		sv;
  SV **		svp;

  readRESULT;
  if (result)
    MyDataSeek(result,pos);
  else
    croak("Could not DataSeek, no result handle found");
}

SV *
DESTROY(handle)
   my_sth_t	handle
   PROTOTYPE: $
   CODE:
{
/* We have to free memory, when a handle is not used anymore */

  My__Result	result = NULL;
  SV *		sv;
  SV **		svp;

  readRESULT;
  if (result){
    MyFreeResult(result);
  }
}

char *
info(handle)
  my_sth_t handle
  PROTOTYPE: $
  CODE:
{
  int ok = FALSE;
#ifdef DBD_MYSQL
  SV **		svp;				\
  dbh_t		sock;

  readMYSOCKET;
  if (validSOCKET  &&  (RETVAL = mysql_info(sock))) {
    ok = TRUE;
  }
#endif
  if (!ok)
    XSRETURN_UNDEF;
}
   OUTPUT:

   RETVAL



MODULE = Mysql		PACKAGE = Mysql

double
constant(name,arg)
	char *		name
	char *		arg
      CODE:
        extern double mymsql_constant _((char*, char*));
        RETVAL = mymsql_constant(name, arg);
      OUTPUT:
        RETVAL


char *
errmsg(handle=NULL)
   SV* handle
   PROTOTYPE: ;$
   CODE:
{
   dbh_t sock;
#ifdef DBD_MYSQL
   SV** svp;
   if (ST(0) && sv_isa(ST(0), "Mysql"))
       handle = SvRV(ST(0));
   else
       croak("handle is not of type Mysql.\n");
   readMYSOCKET;
   if (validSOCKET) {
     RETVAL = MyError(sock);
   } else {
     XSRETURN_UNDEF;
   }
#else
   RETVAL = MyError(sock);
#endif
}
   OUTPUT:
   RETVAL

char *
errno(handle=NULL)
   SV* handle
   PROTOTYPE: ;$
   CODE:
{
   dbh_t sock;
#if defined(DBD_MYSQL)  &&  defined(mysql_errno)
   SV** svp;
   if (ST(0) && sv_isa(ST(0), "Mysql"))
       handle = SvRV(ST(0));
   else
       croak("handle is not of type Mysql.\n");
   readMYSOCKET;
   if (validSOCKET) {
     RETVAL = mysql_errno(sock);
   } else {
     XSRETURN_UNDEF;
   }
#else
   RETVAL = MyError(sock);
#endif
}
   OUTPUT:
   RETVAL


char *
gethostinfo(handle=NULL)
   my_dbh_t handle
   PROTOTYPE: ;$
   CODE:
{
   dbh_t sock;
#ifdef DBD_MYSQL
   SV** svp;
   readMYSOCKET;
   if (validSOCKET) {
     RETVAL = MyGetHostInfo(sock);
   } else {
     XSRETURN_UNDEF;
   }
#else
   RETVAL = MyError(sock);
#endif
}
   OUTPUT:
   RETVAL

char *
getserverinfo(handle=NULL)
   SV* handle
   PROTOTYPE: ;$
   CODE:
{
   dbh_t sock;
#ifdef DBD_MYSQL
   SV** svp;
   if (ST(0) && sv_isa(ST(0), "Mysql"))
       handle = SvRV(ST(0));
   else
       croak("handle is not of type Mysql.\n");
   readMYSOCKET;
   if (validSOCKET) {
     RETVAL = MyGetServerInfo(sock);
   } else {
     XSRETURN_UNDEF;
   }
#else
   RETVAL = MyGetServerInfo(sock);
#endif
}
     OUTPUT:
     RETVAL

SV*
getprotoinfo(handle=NULL)
   my_dbh_t handle
   PROTOTYPE: ;$
   CODE:
{
   dbh_t sock;
#ifdef DBD_MYSQL
   SV** svp;
   readMYSOCKET;
   if (validSOCKET) {
     char* proto = MyGetProtoInfo(sock);
     RETVAL = sv_2mortal(newSVpv(proto, strlen(proto)));
   } else {
     XSRETURN_UNDEF;
   }
#else
   RETVAL = sv_2mortal(newSViv(MyGetProtoInfo(sock)));
#endif
}
   OUTPUT:
   RETVAL

char *
unixtimetodate(package = Package, clock)
     time_t clock
     PROTOTYPE: $$
     CODE:
#ifdef DBD_MSQL
#if defined(IDX_TYPE) && defined(HAVE_STRPTIME)
     RETVAL = msqlUnixTimeToDate(clock);
#else
     RETVAL = "";
#endif
#else
   croak("not implemented");
#endif
     OUTPUT:
     RETVAL

char *
unixtimetotime(package = Package, clock)
     time_t clock
     PROTOTYPE: $$
     CODE:
#ifdef DBD_MSQL
#if defined(IDX_TYPE) && defined(HAVE_STRPTIME)
     RETVAL = msqlUnixTimeToTime(clock);
#else
     RETVAL = "";
#endif
#else
   croak("not implemented");
#endif
     OUTPUT:
     RETVAL

time_t
datetounixtime(package = Package, clock)
     char * clock
     PROTOTYPE: $$
     CODE:
#ifdef DBD_MSQL
#if defined(IDX_TYPE) && defined(HAVE_STRPTIME)
     RETVAL = msqlDateToUnixTime(clock);
#else
     RETVAL = 0;
#endif
#else
   croak("not implemented");
#endif
     OUTPUT:
     RETVAL

time_t
timetounixtime(package = Package, clock)
     char * clock
     PROTOTYPE: $$
     CODE:
#ifdef DBD_MSQL
#if defined(IDX_TYPE) && defined(HAVE_STRPTIME)
     RETVAL = msqlTimeToUnixTime(clock);
#else
     RETVAL = 0;
#endif
#else
   croak("not implemented");
#endif
     OUTPUT:
     RETVAL

char*
getserverstats(handle)
     my_dbh_t handle
     PROTOTYPE: $
     CODE:
{
#if defined(IDX_TYPE)  ||  defined(DBD_MYSQL)
  dRESULT;
  readMYSOCKET;
  if (validSOCKET) {
#ifdef DBD_MSQL
    /* The reason I leave this undocumented is that I can't believe that's
       all */
    if (msqlGetServerStats(sock)==0){
      msqlClose(sock);
    } else {
	ERRMSG(sock);
    }
#else
    RETVAL = mysql_stat(sock);
  } else {
    XSRETURN_UNDEF;
#endif
  }
#endif
  RETVAL = "0";
}
     OUTPUT:
     RETVAL

SysRet
dropdb(handle,db)
     my_dbh_t		handle
     char *	db
     PROTOTYPE: $$
     CODE:
     {
      dRESULT;
      readMYSOCKET;
      if (validSOCKET) {
	checkRETVAL(MyDropDb(sock,db));
      }
     }
     OUTPUT:
     RETVAL

SysRet
createdb(handle,db)
     my_dbh_t		handle
     char *	db
     PROTOTYPE: $$
     CODE:
     {
      dRESULT;
      readMYSOCKET;
      if (validSOCKET) {
	checkRETVAL(MyCreateDb(sock,db));
      }
     }
     OUTPUT:
     RETVAL

SysRet
shutdown(handle)
     my_dbh_t	handle
     PROTOTYPE: $
     CODE:
     {
      dRESULT;
      readMYSOCKET;
      if (validSOCKET) {
	checkRETVAL(MyShutdown(sock));
      }
     }
     OUTPUT:
     RETVAL

SysRet
reloadacls(handle)
     my_dbh_t		handle
     PROTOTYPE: $
     CODE:
     {
      dRESULT;
      readMYSOCKET;
      if (validSOCKET) {
	checkRETVAL(MyReload(sock));
      }
     }
     OUTPUT:
     RETVAL

SV *
getsequenceinfo(handle,table)
     my_dbh_t		handle
     char *		table
   PROTOTYPE: $$
   PPCODE:
{
#ifdef DBD_MSQL
#ifdef IDX_TYPE
  m_seq	*seq;
  dFETCH;
  readSOCKET;

  if (sock){
    seq = msqlGetSequenceInfo(sock,table);
  }
  if (!seq){
    ERRMSG(sock);
  } else {
    EXTEND(sp,2);
    PUSHs(sv_2mortal((SV*)newSViv(seq->step)));
    PUSHs(sv_2mortal((SV*)newSViv(seq->value)));
    Safefree(seq);
  }
#endif
#else
     croak("Not implemented.");
#endif
}

SV *
connect(package,host=NULL,db=NULL,user=NULL,password=NULL)
     char *		package
     char *		host
     char *		db
     char *             user
     char *             password
   PROTOTYPE: $;$$$$
   CODE:
   /* As we may have multiple simultaneous sessions with more than one
      connect, we bless an object, as soon as a connection is established
      by Msql->Connect(host, db). The object is a hash, where we put the
      socket returned by msqlConnect under the key "SOCK".  An extra
      argument may be given to select the database we are going to access
      with this handle. As soon as a database is selected, we add it to
      the hash table in the key DATABASE. */
{
  dBSV;
#ifdef DBD_MSQL
  dbh_t sock;
  int result;

  result = MyConnect(&sock, host, user, password);
  if (!result || (db && (MySelectDb(sock,db) < 0))) {
    ERRMSG(sock);
  } else {
    iniHV;
    svsock = (SV*)newSViv(sock);
    if (db)
      svdb = (SV*)newSVpv(db,0);
    else
      svdb = &sv_undef;
    if (host)
      svhost = (SV*)newSVpv(host,0);
    else
      svhost = &sv_undef;
    hv_store(hv,"SOCK",4,svsock,0);
    hv_store(hv,"HOST",4,svhost,0);
    hv_store(hv,"DATABASE",8,svdb,0);
#else
  dbh_t sock;
  int result;

  if (!(sock = malloc(sizeof(*sock)))) { XSRETURN_UNDEF; }
  result = MyConnect(sock, host, user, password);

  if (!result || (db && (MySelectDb(sock,db) < 0))) {
    ERRMSG(sock);
    if (result) { MyClose(sock); }
    free(sock);
  } else {
    iniHV;
    hv_store(hv, "SOCK", 4, newSViv((IV) sock), 0);
    hv_store(hv, "HOST", 4, (db ? newSVpv(host, 0) : &sv_undef), 0);
    hv_store(hv, "DATABASE", 8, (db ? newSVpv(db, 0) : &sv_undef),0);
    hv_store(hv, "SOCKFD", 6, newSViv(sock->net.fd), 0);
    hv_store(hv, "USER", 4, (user ? newSVpv(user,0) : &sv_undef), 0);
#endif
    rv = newRV((SV*)hv);
    stash = gv_stashpv(package, TRUE);
    ST(0) = sv_2mortal(sv_bless(rv, stash));
  }
}

SysRet
selectdb(handle, db)
     my_dbh_t		handle
     char *		db
   PROTOTYPE: $$
   CODE:
{
/* This routine does not return an object, it just sets a database
   within the connection. */

  dRESULT;

  readSOCKET;
  if (validSOCKET && db)
    RETVAL = MySelectDb(sock,db);
  else
    RETVAL = -1;
  if (RETVAL == -1){
    ERRMSG(sock);
  } else {
    hv_store(handle,"DATABASE",8,(SV*)newSVpv(db,0),0);
  }
}
 OUTPUT:
  RETVAL

SV *
query(handle, query)
   my_dbh_t		handle
   SV *	query
   PROTOTYPE: $$
   CODE:
{
/* A successful query returns a statement handle in the
   mysql::Statement class. In that class we have a FetchRow() method,
   that returns us one row after the other. We may repeat the fetching
   of rows beginning with an arbitrary row number after we reset the
   position-pointer with DataSeek().
   */

  dQUERY;
  STRLEN len;
  char* querystr = SvPV(query, len); /* Note: SvPV is a macro */

  readMYSOCKET;
  if (validSOCKET) {
    tmp = MyQuery(sock,querystr,len);
  }

  if (tmp < 0 ) {
    ERRMSG(sock);
  } else {
    if ((result = MyStoreResult(sock))){
      hv = (HV*)sv_2mortal((SV*)newHV());
      hv_store(hv,"RESULT",6,(SV *)newSViv((IV)result),0);
      hv_store(hv,"SOCK",9,newSViv((IV)sock),0);
      rv = newRV((SV*)hv);
      stash = gv_stashpv((char*) StPackage, TRUE);
      ST(0) = sv_2mortal(sv_bless(rv, stash));
    } else {
#ifdef DBD_MSQL
      ST(0) = sv_newmortal();
      if (tmp > 0){
	sv_setiv( ST(0), tmp);
      } else {
	sv_setpv( ST(0), "0e0");
      }
#else
      hv = (HV*)sv_2mortal((SV*)newHV());
      hv_store(hv, "AFFECTEDROWS", 13,
	       newSViv((IV)mysql_affected_rows(sock)), 0);
      hv_store(hv, "INSERTID", 9, newSViv((IV)mysql_insert_id(sock)), 0);
      hv_store(hv,"SOCK",9,newSViv((IV)sock),0);
      rv = newRV((SV*)hv);
      stash = gv_stashpv(StPackage, TRUE);
      ST(0) = sv_2mortal(sv_bless(rv, stash));      
#endif
    }
  }
}

SV *
listdbs(handle)
   my_dbh_t		handle
   PROTOTYPE: $
   PPCODE:
{
/* We return an array, of course. */

  dFETCH;

  readSOCKET;
  if (sock)
    result = MyListDbs(sock);
  if (result == NULL ) {
    ERRMSG(sock);
  } else {
    while ((cur = MyFetchRow(result))){
      EXTEND(sp,1);
      curField = MyFetchField(result);
      PUSHs(sv_2mortal((SV*)newSVpv(cur[0], strlen(cur[0]))));
    }
    MyFreeResult(result);
  }
}

SV *
listtables(handle)
   my_dbh_t		handle
   PROTOTYPE: $
   PPCODE:
{
/* We return an array, of course. */

  dFETCH;

  readSOCKET;
  if (sock)
    result = MyListTables(sock);
  if (result == NULL ) {
    ERRMSG(sock);
  } else {
    while ((cur = MyFetchRow(result))){
      EXTEND(sp,1);
      curField = MyFetchField(result);
      PUSHs(sv_2mortal((SV*)newSVpv(cur[0], strlen(cur[0]))));
    }
    MyFreeResult(result);
  }
}

SV *
listfields(handle, table)
   my_dbh_t			handle
   char *		table
   PROTOTYPE: $$
   CODE:
{
/* This is similar to a query with 0 rows in the result. Unlike with
   the query we are guaranteed by the API to have field information
   where we also have it after a successful query. That means, we find
   no result with FetchRow, but we have a ref to a filled Hash with
   NAME, TABLE, TYPE, IS_PRI_KEY, and IS_NOT_NULL. We do bless into
   msqlStatement, so DESTROY will free the query. */

  dQUERY;

  readMYSOCKET;
  if (validSOCKET && table)
    result = MyListFields(sock,table);
  if (result == NULL ) {
    ERRMSG(sock);
  } else {
    hv = (HV*)sv_2mortal((SV*)newHV());
    hv_store(hv,"RESULT",6,(SV *)newSViv((IV)result),0);
    hv_store(hv,"NUMROWS",7,(SV *)newSVpv("N/A",3),0);
    rv = newRV((SV*)hv);
    stash = gv_stashpv((char*) StPackage, TRUE);
    ST(0) = sv_2mortal(sv_bless(rv, stash));
  }
}

SV *
listindex(handle, table, index)
   my_dbh_t		handle
   char *		table
   char *		index
   PROTOTYPE: $$$
   CODE:
#ifdef IDX_TYPE
{
  dQUERY;

  if (svp = hv_fetch(handle,"SOCK",4,FALSE))
    sock = SvIV(*svp);
  if (sock && table)
    result = msqlListIndex(sock,table,index);
  if (result == NULL ) {
    ERRMSG(sock);
  } else {
    hv = (HV*)sv_2mortal((SV*)newHV());
    hv_store(hv,"RESULT",6,(SV *)newSViv((IV)result),0);
    rv = newRV((SV*)hv);
    stash = gv_stashpv((char*) StPackage, TRUE);
    ST(0) = sv_2mortal(sv_bless(rv, stash));
  }
}
#else
    not_here("listfields");
#endif

SV *
DESTROY(handle)
   my_dbh_t handle
   PROTOTYPE: $
   CODE:
{
   /* Somebody has freed the object that keeps us connected with the
      database, so we have to tell the server, that we are done. */

  SV **	svp;
  dbh_t sock;

  readMYSOCKET;
  if (validSOCKET) {
    MyClose(sock);
#ifdef DBD_MYSQL
    free(sock);
#endif
  }
}

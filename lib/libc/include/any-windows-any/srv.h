/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _ODS_SRV_H_
#define _ODS_SRV_H_

#ifndef COMPILE_FOR_CLR
#include "windows.h"
#endif

#pragma pack(4)

#ifdef __cplusplus
extern "C" {
#endif

#ifndef FAR
#define FAR
#endif

#ifndef DBTYPEDEFS
#ifndef MAXNUMERICLEN
#define DBTYPEDEFS

  typedef unsigned char DBBOOL;
  typedef unsigned char DBBYTE;
  typedef unsigned char DBTINYINT;
  typedef short DBSMALLINT;
  typedef unsigned short DBUSMALLINT;
  typedef __LONG32 DBINT;
  typedef char DBCHAR;
  typedef unsigned char DBBINARY;
  typedef unsigned char DBBIT;
  typedef double DBFLT8;

  typedef struct srv_datetime {
    __LONG32 dtdays;
    unsigned __LONG32 dttime;
  } DBDATETIME;

  typedef struct srv_money {
    __LONG32 mnyhigh;
    unsigned __LONG32 mnylow;
  } DBMONEY;

  typedef float DBFLT4;
  typedef __LONG32 DBMONEY4;

  typedef struct dbdatetime4 {
    unsigned short numdays;
    unsigned short nummins;
  } DBDATETIM4;

#define MAXNUMERICLEN 16
  typedef struct dbnumeric {
    BYTE precision;
    BYTE scale;
    BYTE sign;
    BYTE val[MAXNUMERICLEN];
  } DBNUMERIC;
  typedef DBNUMERIC DBDECIMAL;
#endif
#endif

#define SRV_TDS_NULL (BYTE) 0x1f
#define SRV_TDS_TEXT (BYTE) 0x23
#define SRV_TDS_GUID (BYTE) 0x24
#define SRV_TDS_VARBINARY (BYTE) 0x25
#define SRV_TDS_INTN (BYTE) 0x26
#define SRV_TDS_VARCHAR (BYTE) 0x27
#define SRV_TDS_BINARY (BYTE) 0x2d
#define SRV_TDS_IMAGE (BYTE) 0x22
#define SRV_TDS_CHAR (BYTE) 0x2f
#define SRV_TDS_INT1 (BYTE) 0x30
#define SRV_TDS_BIT (BYTE) 0x32
#define SRV_TDS_INT2 (BYTE) 0x34
#define SRV_TDS_DECIMAL (BYTE) 0x37
#define SRV_TDS_INT4 (BYTE) 0x38
#define SRV_TDS_DATETIM4 (BYTE) 0x3a
#define SRV_TDS_FLT4 (BYTE) 0x3b
#define SRV_TDS_MONEY (BYTE) 0x3c
#define SRV_TDS_DATETIME (BYTE) 0x3d
#define SRV_TDS_FLT8 (BYTE) 0x3e
#define SRV_TDS_NUMERIC (BYTE) 0x3f
#define SRV_TDS_SSVARIANT (BYTE) 0x62
#define SRV_TDS_NTEXT (BYTE) 0x63
#define SRV_TDS_BITN (BYTE) 0x68
#define SRV_TDS_DECIMALN (BYTE) 0x6a
#define SRV_TDS_NUMERICN (BYTE) 0x6c
#define SRV_TDS_FLTN (BYTE) 0x6d
#define SRV_TDS_MONEYN (BYTE) 0x6e
#define SRV_TDS_DATETIMN (BYTE) 0x6f
#define SRV_TDS_MONEY4 (BYTE) 0x7a
#define SRV_TDS_INT8 (BYTE) 0x7f
#define SRV_TDS_BIGVARBINARY (BYTE) 0xA5
#define SRV_TDS_BIGVARCHAR (BYTE) 0xA7
#define SRV_TDS_BIGBINARY (BYTE) 0xAD
#define SRV_TDS_BIGCHAR (BYTE) 0xAF
#define SRV_TDS_NVARCHAR (BYTE) 0xe7
#define SRV_TDS_NCHAR (BYTE) 0xef

#define SRVNULL SRV_TDS_NULL
#define SRVTEXT SRV_TDS_TEXT
#define SRVGUID SRV_TDS_GUID
#define SRVVARBINARY SRV_TDS_VARBINARY
#define SRVINTN SRV_TDS_INTN
#define SRVVARCHAR SRV_TDS_VARCHAR
#define SRVBINARY SRV_TDS_BINARY
#define SRVIMAGE SRV_TDS_IMAGE
#define SRVCHAR SRV_TDS_CHAR
#define SRVINT1 SRV_TDS_INT1
#define SRVBIT SRV_TDS_BIT
#define SRVINT2 SRV_TDS_INT2
#define SRVDECIMAL SRV_TDS_DECIMAL
#define SRVINT4 SRV_TDS_INT4
#define SRVDATETIM4 SRV_TDS_DATETIM4
#define SRVFLT4 SRV_TDS_FLT4
#define SRVMONEY SRV_TDS_MONEY
#define SRVDATETIME SRV_TDS_DATETIME
#define SRVFLT8 SRV_TDS_FLT8
#define SRVNUMERIC SRV_TDS_NUMERIC
#define SRVSSVARIANT SRV_TDS_SSVARIANT
#define SRVNTEXT SRV_TDS_NTEXT
#define SRVBITN SRV_TDS_BITN
#define SRVDECIMALN SRV_TDS_DECIMALN
#define SRVNUMERICN SRV_TDS_NUMERICN
#define SRVFLTN SRV_TDS_FLTN
#define SRVMONEYN SRV_TDS_MONEYN
#define SRVDATETIMN SRV_TDS_DATETIMN
#define SRVMONEY4 SRV_TDS_MONEY4
#define SRVINT8 SRV_TDS_INT8
#define SRVBIGVARBINARY SRV_TDS_BIGVARBINARY
#define SRVBIGVARCHAR SRV_TDS_BIGVARCHAR
#define SRVBIGBINARY SRV_TDS_BIGBINARY
#define SRVBIGCHAR SRV_TDS_BIGCHAR
#define SRVNVARCHAR SRV_TDS_NVARCHAR
#define SRVNCHAR SRV_TDS_NCHAR

#define SRV_ERROR 0
#define SRV_DONE 1
#define SRV_DATATYPE 2
#define SRV_EVENT 4

#define SRV_ENO_OS_ERR 0
#define SRV_INFO 1
#define SRV_FATAL_PROCESS 10
#define SRV_FATAL_SERVER 19

#define SRV_CONTINUE 0
#define SRV_LANGUAGE 1
#define SRV_CONNECT 2
#define SRV_RPC 3
#define SRV_RESTART 4
#define SRV_DISCONNECT 5
#define SRV_ATTENTION 6
#define SRV_SLEEP 7
#define SRV_START 8
#define SRV_STOP 9
#define SRV_EXIT 10
#define SRV_CANCEL 11
#define SRV_SETUP 12
#define SRV_CLOSE 13
#define SRV_PRACK 14
#define SRV_PRERROR 15
#define SRV_ATTENTION_ACK 16
#define SRV_CONNECT_V7 16
#define SRV_SKIP 17
#define SRV_TRANSMGR 18
#define SRV_PRELOGIN 19
#define SRV_OLEDB 20
#define SRV_INTERNAL_HANDLER 99
#define SRV_PROGRAMMER_DEFINED 100

#define SRV_SERVERNAME 0
#define SRV_VERSION 6

#define SRV_NULLTERM -1

#define SRV_MSG_INFO 1
#define SRV_MSG_ERROR 2

#define SRV_DONE_FINAL (USHORT) 0x0000
#define SRV_DONE_MORE (USHORT) 0x0001
#define SRV_DONE_ERROR (USHORT) 0x0002
#define SRV_DONE_COUNT (USHORT) 0x0010
#define SRV_DONE_RPC_IN_BATCH (USHORT) 0x0080

#define SRV_PARAMRETURN 0x0001
#define SRV_PARAMDEFAULT 0x0002
#define SRV_PARAMSORTORDER 0x0004

#define SRV_RECOMPILE 0x0001
#define SRV_NOMETADATA 0x0002

#define SRV_SPID 10
#define SRV_NETSPID 11
#define SRV_TYPE 12
#define SRV_STATUS 13
#define SRV_RMTSERVER 14
#define SRV_HOST 15
#define SRV_USER 16
#define SRV_PWD 17
#define SRV_CPID 18
#define SRV_APPLNAME 19
#define SRV_TDS 20
#define SRV_CLIB 21
#define SRV_LIBVERS 22
#define SRV_ROWSENT 23
#define SRV_BCPFLAG 24
#define SRV_NATLANG 25
#define SRV_PIPEHANDLE 26
#define SRV_NETWORK_MODULE 27
#define SRV_NETWORK_VERSION 28
#define SRV_NETWORK_CONNECTION 29
#define SRV_LSECURE 30
#define SRV_SAXP 31
#define SRV_UNICODE_USER 33
#define SRV_UNICODE_PWD 35
#define SRV_SPROC_CODEPAGE 36
#define SRV_MSGLCID 37
#define SRV_INSTANCENAME 38
#define SRV_HASHPWD 39
#define SRV_UNICODE_CURRENTLOGIN 40

#define SRV_TDS_NONE 0
#define SRV_TDS_2_0 1
#define SRV_TDS_3_4 2
#define SRV_TDS_4_2 3
#define SRV_TDS_6_0 4
#define SRV_TDS_7_0 5

  typedef int SRVRETCODE;
#ifndef ODBCVER
  typedef int RETCODE;
#endif

#ifndef SUCCEED
#define SUCCEED 1
#endif

#ifndef FAIL
#define FAIL 0
#endif

#define SRV_DUPLICATE_HANDLER 2

#ifndef COMPILE_FOR_CLR
  struct srv_server;
  typedef struct srv_server SRV_SERVER;

  struct srv_config;
  typedef struct srv_config SRV_CONFIG;

  struct CXPData;
  typedef struct CXPData SRV_PROC;

  int __cdecl srv_describe(SRV_PROC *,int,char*,int,__LONG32,__LONG32,__LONG32,__LONG32,void *);
  int __cdecl srv_setutype(SRV_PROC *srvproc,int column,__LONG32 usertype);
  int __cdecl srv_setcoldata(SRV_PROC *srvproc,int column,void *data);
  int __cdecl srv_setcollen(SRV_PROC *srvproc,int column,int len);
  int __cdecl srv_sendrow(SRV_PROC *srvproc);
  int __cdecl srv_senddone(SRV_PROC *srvproc,USHORT status,USHORT curcmd,__LONG32 count);
  int __cdecl srv_rpcparams(SRV_PROC *);
  int __cdecl srv_paraminfo(SRV_PROC *,int,BYTE *,ULONG *,ULONG *,BYTE *,WINBOOL *);
  int __cdecl srv_paramsetoutput(SRV_PROC *,int,BYTE *,ULONG,WINBOOL);
  void *__cdecl srv_paramdata(SRV_PROC *,int);
  int __cdecl srv_paramlen(SRV_PROC *,int);
  int __cdecl srv_parammaxlen(SRV_PROC *,int);
  int __cdecl srv_paramtype(SRV_PROC *,int);
  int __cdecl srv_paramset(SRV_PROC *,int,void *,int);
  char *__cdecl srv_paramname(SRV_PROC *,int,int*);
  int __cdecl srv_paramnumber(SRV_PROC *,char*,int);

#define SRV_GETSERVER(a) srv_getserver (a)
#define SRV_GOT_ATTENTION(a) srv_got_attention (a)
#define SRV_TDSVERSION(a) srv_tdsversion (a)

  SRV_SERVER *__cdecl srv_getserver(SRV_PROC *srvproc);
  WINBOOL __cdecl srv_got_attention(SRV_PROC *srvproc);

  void *__cdecl srv_alloc(__LONG32 ulSize);
  int __cdecl srv_bmove(void *from,void *to,__LONG32 count);
  int __cdecl srv_bzero(void *location,__LONG32 count);
  int __cdecl srv_free(void *ptr);
  int __cdecl srv_convert(SRV_PROC *,int,void *,__LONG32,int,void *,__LONG32);
  void *__cdecl srv_getuserdata(SRV_PROC *srvproc);
  int __cdecl srv_getbindtoken(SRV_PROC *srvproc,char *token_buf);
  int __cdecl srv_getdtcxact(SRV_PROC *srvproc,void **ppv);

  typedef int (*EventHandler)(void *);

  int __cdecl srv_impersonate_client(SRV_PROC *srvproc);
  __LONG32 __cdecl srv_langcpy(SRV_PROC *srvproc,__LONG32 start,__LONG32 nbytes,char *buffer);
  __LONG32 __cdecl srv_langlen(SRV_PROC *srvproc);
  void *__cdecl srv_langptr(SRV_PROC *srvproc);

  int __cdecl srv_log(SRV_SERVER *server,WINBOOL datestamp,char *msg,int msglen);
  int __cdecl srv_paramstatus(SRV_PROC *,int);
  void *__cdecl srv_pfieldex(SRV_PROC *srvproc,int field,int *len);
  char *__cdecl srv_pfield(SRV_PROC *srvproc,int field,int *len);
  int __cdecl srv_returnval(SRV_PROC *srvproc,char *valuename,int len,BYTE status,__LONG32 type,__LONG32 maxlen,__LONG32 datalen,void *value);
  int __cdecl srv_revert_to_self(SRV_PROC *srvproc);
  char *__cdecl srv_rpcdb(SRV_PROC *srvproc,int *len);
  char *__cdecl srv_rpcname(SRV_PROC *srvproc,int *len);
  int __cdecl srv_rpcnumber(SRV_PROC *srvproc);
  USHORT __cdecl srv_rpcoptions(SRV_PROC *srvproc);
  char *__cdecl srv_rpcowner(SRV_PROC *srvproc,int *len);
  int __cdecl srv_wsendmsg(SRV_PROC *srvproc,__LONG32 msgnum,BYTE msgclass,WCHAR *message,int msglen);
  int __cdecl srv_sendmsg(SRV_PROC *srvproc,int msgtype,__LONG32 msgnum,BYTE msgclass,BYTE state,char *rpcname,int rpcnamelen,USHORT linenum,char *message,int msglen);
  int __cdecl srv_sendstatus(SRV_PROC *srvproc,__LONG32 status);
  int __cdecl srv_setuserdata(SRV_PROC *srvproc,void *ptr);
  char *__cdecl srv_sfield(SRV_SERVER *server,int field,int *len);
  char *__cdecl srv_symbol(int type,int symbol,int *len);
  int __cdecl srv_tdsversion(SRV_PROC *srvproc);
  WINBOOL __cdecl srv_willconvert(int srctype,int desttype);
  int __cdecl srv_terminatethread(SRV_PROC *srvproc);
  int __cdecl srv_sendstatistics(SRV_PROC *srvproc);
  int __cdecl srv_clearstatistics(SRV_PROC *srvproc);
  int __cdecl srv_message_handler(SRV_PROC *srvproc,int errornum,BYTE severity,BYTE state,int oserrnum,char *errtext,int errtextlen,char *oserrtext,int oserrtextlen);
  int __cdecl srv_pre_handle(SRV_SERVER *server,SRV_PROC *srvproc,__LONG32 event,EventHandler handler,WINBOOL remove);
  int __cdecl srv_post_handle(SRV_SERVER *server,SRV_PROC *srvproc,__LONG32 event,EventHandler handler,WINBOOL remove);
  int __cdecl srv_IgnoreAnsiToOem(SRV_PROC *srvproc,WINBOOL bTF);
#endif

#ifdef __cplusplus
}
#endif

#pragma pack()

#define SS_MAJOR_VERSION 7
#define SS_MINOR_VERSION 00
#define SS_LEVEL_VERSION 0000
#define SS_MINIMUM_VERSION "7.00.00.0000"
#define ODS_VERSION ((SS_MAJOR_VERSION << 24) | (SS_MINOR_VERSION << 16))
#endif

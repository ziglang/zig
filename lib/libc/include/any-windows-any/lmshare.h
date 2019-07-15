/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _LMSHARE_
#define _LMSHARE_

#ifdef __cplusplus
extern "C" {
#endif

#include <lmcons.h>

  NET_API_STATUS WINAPI NetShareAdd(LMSTR servername,DWORD level,LPBYTE buf,LPDWORD parm_err);
  NET_API_STATUS WINAPI NetShareEnum(LMSTR servername,DWORD level,LPBYTE *bufptr,DWORD prefmaxlen,LPDWORD entriesread,LPDWORD totalentries,LPDWORD resume_handle);
  NET_API_STATUS WINAPI NetShareEnumSticky(LMSTR servername,DWORD level,LPBYTE *bufptr,DWORD prefmaxlen,LPDWORD entriesread,LPDWORD totalentries,LPDWORD resume_handle);
  NET_API_STATUS WINAPI NetShareGetInfo(LMSTR servername,LMSTR netname,DWORD level,LPBYTE *bufptr);
  NET_API_STATUS WINAPI NetShareSetInfo(LMSTR servername,LMSTR netname,DWORD level,LPBYTE buf,LPDWORD parm_err);
  NET_API_STATUS WINAPI NetShareDel(LMSTR servername,LMSTR netname,DWORD reserved);
  NET_API_STATUS WINAPI NetShareDelSticky(LMSTR servername,LMSTR netname,DWORD reserved);
  NET_API_STATUS WINAPI NetShareCheck(LMSTR servername,LMSTR device,LPDWORD type);

  typedef struct _SHARE_INFO_0 {
    LMSTR shi0_netname;
  } SHARE_INFO_0,*PSHARE_INFO_0,*LPSHARE_INFO_0;

  typedef struct _SHARE_INFO_1 {
    LMSTR shi1_netname;
    DWORD shi1_type;
    LMSTR shi1_remark;
  } SHARE_INFO_1,*PSHARE_INFO_1,*LPSHARE_INFO_1;

  typedef struct _SHARE_INFO_2 {
    LMSTR shi2_netname;
    DWORD shi2_type;
    LMSTR shi2_remark;
    DWORD shi2_permissions;
    DWORD shi2_max_uses;
    DWORD shi2_current_uses;
    LMSTR shi2_path;
    LMSTR shi2_passwd;
  } SHARE_INFO_2,*PSHARE_INFO_2,*LPSHARE_INFO_2;

  typedef struct _SHARE_INFO_501 {
    LMSTR shi501_netname;
    DWORD shi501_type;
    LMSTR shi501_remark;
    DWORD shi501_flags;
  } SHARE_INFO_501,*PSHARE_INFO_501,*LPSHARE_INFO_501;

  typedef struct _SHARE_INFO_502 {
    LMSTR shi502_netname;
    DWORD shi502_type;
    LMSTR shi502_remark;
    DWORD shi502_permissions;
    DWORD shi502_max_uses;
    DWORD shi502_current_uses;
    LMSTR shi502_path;
    LMSTR shi502_passwd;
    DWORD shi502_reserved;
    PSECURITY_DESCRIPTOR shi502_security_descriptor;
  } SHARE_INFO_502,*PSHARE_INFO_502,*LPSHARE_INFO_502;

  typedef struct _SHARE_INFO_1004 {
    LMSTR shi1004_remark;
  } SHARE_INFO_1004,*PSHARE_INFO_1004,*LPSHARE_INFO_1004;

  typedef struct _SHARE_INFO_1005 {
    DWORD shi1005_flags;
  } SHARE_INFO_1005,*PSHARE_INFO_1005,*LPSHARE_INFO_1005;

  typedef struct _SHARE_INFO_1006 {
    DWORD shi1006_max_uses;
  } SHARE_INFO_1006,*PSHARE_INFO_1006,*LPSHARE_INFO_1006;

  typedef struct _SHARE_INFO_1501 {
    DWORD shi1501_reserved;
    PSECURITY_DESCRIPTOR shi1501_security_descriptor;
  } SHARE_INFO_1501,*PSHARE_INFO_1501,*LPSHARE_INFO_1501;

#define SHARE_NETNAME_PARMNUM 1
#define SHARE_TYPE_PARMNUM 3
#define SHARE_REMARK_PARMNUM 4
#define SHARE_PERMISSIONS_PARMNUM 5
#define SHARE_MAX_USES_PARMNUM 6
#define SHARE_CURRENT_USES_PARMNUM 7
#define SHARE_PATH_PARMNUM 8
#define SHARE_PASSWD_PARMNUM 9
#define SHARE_FILE_SD_PARMNUM 501

#define SHARE_REMARK_INFOLEVEL (PARMNUM_BASE_INFOLEVEL + SHARE_REMARK_PARMNUM)
#define SHARE_MAX_USES_INFOLEVEL (PARMNUM_BASE_INFOLEVEL + SHARE_MAX_USES_PARMNUM)
#define SHARE_FILE_SD_INFOLEVEL (PARMNUM_BASE_INFOLEVEL + SHARE_FILE_SD_PARMNUM)

#define SHI1_NUM_ELEMENTS 4
#define SHI2_NUM_ELEMENTS 10

#define STYPE_DISKTREE 0
#define STYPE_PRINTQ 1
#define STYPE_DEVICE 2
#define STYPE_IPC 3

#define STYPE_TEMPORARY 0x40000000
#define STYPE_SPECIAL 0x80000000

#define SHI_USES_UNLIMITED (DWORD)-1

#define SHI1005_FLAGS_DFS 0x01
#define SHI1005_FLAGS_DFS_ROOT 0x02

#define CSC_MASK 0x30

#define CSC_CACHE_MANUAL_REINT 0x00
#define CSC_CACHE_AUTO_REINT 0x10
#define CSC_CACHE_VDO 0x20
#define CSC_CACHE_NONE 0x30

#define SHI1005_FLAGS_RESTRICT_EXCLUSIVE_OPENS 0x0100
#define SHI1005_FLAGS_FORCE_SHARED_DELETE 0x0200
#define SHI1005_FLAGS_ALLOW_NAMESPACE_CACHING 0x0400
#define SHI1005_FLAGS_ACCESS_BASED_DIRECTORY_ENUM 0x0800

#define SHI1005_VALID_FLAGS_SET (CSC_MASK| SHI1005_FLAGS_RESTRICT_EXCLUSIVE_OPENS| SHI1005_FLAGS_FORCE_SHARED_DELETE| SHI1005_FLAGS_ALLOW_NAMESPACE_CACHING| SHI1005_FLAGS_ACCESS_BASED_DIRECTORY_ENUM)
#endif

#ifndef _LMSESSION_
#define _LMSESSION_

  NET_API_STATUS WINAPI NetSessionEnum(LMSTR servername,LMSTR UncClientName,LMSTR username,DWORD level,LPBYTE *bufptr,DWORD prefmaxlen,LPDWORD entriesread,LPDWORD totalentries,LPDWORD resume_handle);
  NET_API_STATUS WINAPI NetSessionDel(LMSTR servername,LMSTR UncClientName,LMSTR username);
  NET_API_STATUS WINAPI NetSessionGetInfo(LMSTR servername,LMSTR UncClientName,LMSTR username,DWORD level,LPBYTE *bufptr);

  typedef struct _SESSION_INFO_0 {
    LMSTR sesi0_cname;
  } SESSION_INFO_0,*PSESSION_INFO_0,*LPSESSION_INFO_0;

  typedef struct _SESSION_INFO_1 {
    LMSTR sesi1_cname;
    LMSTR sesi1_username;
    DWORD sesi1_num_opens;
    DWORD sesi1_time;
    DWORD sesi1_idle_time;
    DWORD sesi1_user_flags;
  } SESSION_INFO_1,*PSESSION_INFO_1,*LPSESSION_INFO_1;

  typedef struct _SESSION_INFO_2 {
    LMSTR sesi2_cname;
    LMSTR sesi2_username;
    DWORD sesi2_num_opens;
    DWORD sesi2_time;
    DWORD sesi2_idle_time;
    DWORD sesi2_user_flags;
    LMSTR sesi2_cltype_name;
  } SESSION_INFO_2,*PSESSION_INFO_2,*LPSESSION_INFO_2;

  typedef struct _SESSION_INFO_10 {
    LMSTR sesi10_cname;
    LMSTR sesi10_username;
    DWORD sesi10_time;
    DWORD sesi10_idle_time;
  } SESSION_INFO_10,*PSESSION_INFO_10,*LPSESSION_INFO_10;

  typedef struct _SESSION_INFO_502 {
    LMSTR sesi502_cname;
    LMSTR sesi502_username;
    DWORD sesi502_num_opens;
    DWORD sesi502_time;
    DWORD sesi502_idle_time;
    DWORD sesi502_user_flags;
    LMSTR sesi502_cltype_name;
    LMSTR sesi502_transport;
  } SESSION_INFO_502,*PSESSION_INFO_502,*LPSESSION_INFO_502;

#define SESS_GUEST 0x00000001
#define SESS_NOENCRYPTION 0x00000002

#define SESI1_NUM_ELEMENTS 8
#define SESI2_NUM_ELEMENTS 9
#endif

#ifndef _LMCONNECTION_

#define _LMCONNECTION_

  NET_API_STATUS WINAPI NetConnectionEnum(LMSTR servername,LMSTR qualifier,DWORD level,LPBYTE *bufptr,DWORD prefmaxlen,LPDWORD entriesread,LPDWORD totalentries,LPDWORD resume_handle);

  typedef struct _CONNECTION_INFO_0 {
    DWORD coni0_id;
  } CONNECTION_INFO_0,*PCONNECTION_INFO_0,*LPCONNECTION_INFO_0;

  typedef struct _CONNECTION_INFO_1 {
    DWORD coni1_id;
    DWORD coni1_type;
    DWORD coni1_num_opens;
    DWORD coni1_num_users;
    DWORD coni1_time;
    LMSTR coni1_username;
    LMSTR coni1_netname;
  } CONNECTION_INFO_1,*PCONNECTION_INFO_1,*LPCONNECTION_INFO_1;
#endif

#ifndef _LMFILE_
#define _LMFILE_

  NET_API_STATUS WINAPI NetFileClose(LMSTR servername,DWORD fileid);
  NET_API_STATUS WINAPI NetFileEnum(LMSTR servername,LMSTR basepath,LMSTR username,DWORD level,LPBYTE *bufptr,DWORD prefmaxlen,LPDWORD entriesread,LPDWORD totalentries,PDWORD_PTR resume_handle);
  NET_API_STATUS WINAPI NetFileGetInfo(LMSTR servername,DWORD fileid,DWORD level,LPBYTE *bufptr);

  typedef struct _FILE_INFO_2 {
    DWORD fi2_id;
  } FILE_INFO_2,*PFILE_INFO_2,*LPFILE_INFO_2;

  typedef struct _FILE_INFO_3 {
    DWORD fi3_id;
    DWORD fi3_permissions;
    DWORD fi3_num_locks;
    LMSTR fi3_pathname;
    LMSTR fi3_username;
  } FILE_INFO_3,*PFILE_INFO_3,*LPFILE_INFO_3;

#define PERM_FILE_READ 0x1
#define PERM_FILE_WRITE 0x2
#define PERM_FILE_CREATE 0x4

#ifdef __cplusplus
}
#endif
#endif

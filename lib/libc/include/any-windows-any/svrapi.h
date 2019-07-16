/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef SVRAPI_INCLUDED
#define SVRAPI_INCLUDED

#include <lmcons.h>
#include <lmerr.h>

#ifndef RC_INVOKED
#pragma pack(1)
#endif

#ifdef __cplusplus
extern "C" {
#endif

#ifndef _SVRAPI_
#define API_FUNCTION DECLSPEC_IMPORT API_RET_TYPE WINAPI
#else
#define API_FUNCTION API_RET_TYPE WINAPI
#endif

  extern API_FUNCTION NetAccessAdd(const char *pszServer,short sLevel,char *pbBuffer,unsigned short cbBuffer);
  extern API_FUNCTION NetAccessCheck (char *pszReserved,char *pszUserName,char *pszResource,unsigned short usOperation,unsigned short *pusResult);
  extern API_FUNCTION NetAccessDel(const char *pszServer,char *pszResource);
  extern API_FUNCTION NetAccessEnum(const char *pszServer,char *pszBasePath,short fsRecursive,short sLevel,char *pbBuffer,unsigned short cbBuffer,unsigned short *pcEntriesRead,unsigned short *pcTotalAvail);
  extern API_FUNCTION NetAccessGetInfo(const char *pszServer,char *pszResource,short sLevel,char *pbBuffer,unsigned short cbBuffer,unsigned short *pcbTotalAvail);
  extern API_FUNCTION NetAccessSetInfo(const char *pszServer,char *pszResource,short sLevel,char *pbBuffer,unsigned short cbBuffer,short sParmNum);
  extern API_FUNCTION NetAccessGetUserPerms (char *pszServer,char *pszUgName,char *pszResource,unsigned short *pusPerms);

  struct access_list {
    char acl_ugname[LM20_UNLEN+1];
    char acl_ugname_pad_1;
    short acl_access;
  };

  struct access_list_2 {
    char *acl2_ugname;
    unsigned short acl2_access;
  };

  struct access_list_12 {
    char *acl12_ugname;
    unsigned short acl12_access;
  };

  struct access_info_0 {
    char *acc0_resource_name;
  };

  struct access_info_1 {
    char *acc1_resource_name;
    short acc1_attr;
    short acc1_count;
  };

  struct access_info_2 {
    char *acc2_resource_name;
    short acc2_attr;
    short acc2_count;
  };

  struct access_info_10 {
    char *acc10_resource_name;
  };

  struct access_info_12 {
    char *acc12_resource_name;
    short acc12_attr;
    short acc12_count;
  };

#define MAXPERMENTRIES 64

#define ACCESS_NONE 0
#define ACCESS_ALL (ACCESS_READ|ACCESS_WRITE|ACCESS_CREATE|ACCESS_EXEC|ACCESS_DELETE|ACCESS_ATRIB|ACCESS_PERM|ACCESS_FINDFIRST)

#define ACCESS_READ 0x1
#define ACCESS_WRITE 0x2
#define ACCESS_CREATE 0x4
#define ACCESS_EXEC 0x8
#define ACCESS_DELETE 0x10
#define ACCESS_ATRIB 0x20
#define ACCESS_PERM 0x40
#define ACCESS_FINDFIRST 0x80
#define ACCESS_GROUP 0x8000
#define ACCESS_AUDIT 0x1
#define ACCESS_ATTR_PARMNUM 2
#define ACCESS_LETTERS "RWCXDAP         "

  extern API_FUNCTION NetShareAdd(const char *pszServer,short sLevel,const char *pbBuffer,unsigned short cbBuffer);
  extern API_FUNCTION NetShareDel(const char *pszServer,const char *pszNetName,unsigned short usReserved);
  extern API_FUNCTION NetShareEnum(const char *pszServer,short sLevel,char *pbBuffer,unsigned short cbBuffer,unsigned short *pcEntriesRead,unsigned short *pcTotalAvail);
  extern API_FUNCTION NetShareGetInfo(const char *pszServer,const char *pszNetName,short sLevel,char *pbBuffer,unsigned short cbBuffer,unsigned short *pcbTotalAvail);
  extern API_FUNCTION NetShareSetInfo(const char *pszServer,const char *pszNetName,short sLevel,const char *pbBuffer,unsigned short cbBuffer,short sParmNum);

  struct share_info_0 {
    char shi0_netname[LM20_NNLEN+1];
  };

  struct share_info_1 {
    char shi1_netname[LM20_NNLEN+1];
    char shi1_pad1;
    unsigned short shi1_type;
    char *shi1_remark;
  };

  struct share_info_2 {
    char shi2_netname[LM20_NNLEN+1];
    char shi2_pad1;
    unsigned short shi2_type;
    char *shi2_remark;
    unsigned short shi2_permissions;
    unsigned short shi2_max_uses;
    unsigned short shi2_current_uses;
    char *shi2_path;
    char shi2_passwd[SHPWLEN+1];
    char shi2_pad2;
  };

  struct share_info_50 {
    char shi50_netname[LM20_NNLEN+1];
    unsigned char shi50_type;
    unsigned short shi50_flags;
    char *shi50_remark;
    char *shi50_path;
    char shi50_rw_password[SHPWLEN+1];
    char shi50_ro_password[SHPWLEN+1];
  };

#define SHI50F_RDONLY 0x0001
#define SHI50F_FULL 0x0002
#define SHI50F_DEPENDSON (SHI50F_RDONLY|SHI50F_FULL)
#define SHI50F_ACCESSMASK (SHI50F_RDONLY|SHI50F_FULL)

#define SHI50F_PERSIST 0x0100

#define SHI50F_SYSTEM 0x0200

#ifndef PARMNUM_ALL
#define PARMNUM_ALL 0
#endif

#define SHI_REMARK_PARMNUM 4
#define SHI_PERMISSIONS_PARMNUM 5
#define SHI_MAX_USES_PARMNUM 6
#define SHI_PASSWD_PARMNUM 9

#define SHI1_NUM_ELEMENTS 4
#define SHI2_NUM_ELEMENTS 10

#define STYPE_DISKTREE 0
#define STYPE_PRINTQ 1
#define STYPE_DEVICE 2
#define STYPE_IPC 3

#define SHI_USES_UNLIMITED -1

  extern API_FUNCTION NetSessionDel(const char *pszServer,const char *pszClientName,short sReserved);
  extern API_FUNCTION NetSessionEnum(const char *pszServer,short sLevel,char *pbBuffer,unsigned short cbBuffer,unsigned short *pcEntriesRead,unsigned short *pcTotalAvail);
  extern API_FUNCTION NetSessionGetInfo(const char *pszServer,const char *pszClientName,short sLevel,char *pbBuffer,unsigned short cbBuffer,unsigned short *pcbTotalAvail);

  struct session_info_0 {
    char *sesi0_cname;
  };

  struct session_info_1 {
    char *sesi1_cname;
    char *sesi1_username;
    unsigned short sesi1_num_conns;
    unsigned short sesi1_num_opens;
    unsigned short sesi1_num_users;
    unsigned __LONG32 sesi1_time;
    unsigned __LONG32 sesi1_idle_time;
    unsigned __LONG32 sesi1_user_flags;
  };

  struct session_info_2 {
    char *sesi2_cname;
    char *sesi2_username;
    unsigned short sesi2_num_conns;
    unsigned short sesi2_num_opens;
    unsigned short sesi2_num_users;
    unsigned __LONG32 sesi2_time;
    unsigned __LONG32 sesi2_idle_time;
    unsigned __LONG32 sesi2_user_flags;
    char *sesi2_cltype_name;
  };

  struct session_info_10 {
    char *sesi10_cname;
    char *sesi10_username;
    unsigned __LONG32 sesi10_time;
    unsigned __LONG32 sesi10_idle_time;
  };

  struct session_info_50 {
    char *sesi50_cname;
    char *sesi50_username;
    unsigned __LONG32 sesi50_key;
    unsigned short sesi50_num_conns;
    unsigned short sesi50_num_opens;
    unsigned __LONG32 sesi50_time;
    unsigned __LONG32 sesi50_idle_time;
    unsigned char sesi50_protocol;
    unsigned char pad1;
  };

#define SESS_GUEST 1
#define SESS_NOENCRYPTION 2

#define SESI1_NUM_ELEMENTS 8
#define SESI2_NUM_ELEMENTS 9

  extern API_FUNCTION NetConnectionEnum(const char *pszServer,const char *pszQualifier,short sLevel,char *pbBuffer,unsigned short cbBuffer,unsigned short *pcEntriesRead,unsigned short *pcTotalAvail);

  struct connection_info_0 {
    unsigned short coni0_id;
  };

  struct connection_info_1 {
    unsigned short coni1_id;
    unsigned short coni1_type;
    unsigned short coni1_num_opens;
    unsigned short coni1_num_users;
    unsigned __LONG32 coni1_time;
    char *coni1_username;
    char *coni1_netname;
  };

  struct connection_info_50 {
    unsigned short coni50_type;
    unsigned short coni50_num_opens;
    unsigned __LONG32 coni50_time;
    char *coni50_netname;
    char *coni50_username;
  };

  extern API_FUNCTION NetFileClose2(const char *pszServer,unsigned __LONG32 ulFileId);
  extern API_FUNCTION NetFileEnum(const char *pszServer,const char *pszBasePath,short sLevel,char *pbBuffer,unsigned short cbBuffer,unsigned short *pcEntriesRead,unsigned short *pcTotalAvail);

  struct file_info_0 {
    unsigned short fi0_id;
  };

  struct file_info_1 {
    unsigned short fi1_id;
    unsigned short fi1_permissions;
    unsigned short fi1_num_locks;
    char *fi1_pathname;
    char *fi1_username;
  };

  struct file_info_2 {
    unsigned __LONG32 fi2_id;
  };

  struct file_info_3 {
    unsigned __LONG32 fi3_id;
    unsigned short fi3_permissions;
    unsigned short fi3_num_locks;
    char *fi3_pathname;
    char *fi3_username;
  };

  struct file_info_50 {
    unsigned __LONG32 fi50_id;
    unsigned short fi50_permissions;
    unsigned short fi50_num_locks;
    char *fi50_pathname;
    char *fi50_username;
    char *fi50_sharename;
  };

  struct res_file_enum_2 {
    unsigned short res_pad;
    unsigned short res_fs;
    unsigned __LONG32 res_pro;
  };

#define PERM_FILE_READ 0x1
#define PERM_FILE_WRITE 0x2
#define PERM_FILE_CREATE 0x4

  typedef struct res_file_enum_2 FRK;

#define FRK_INIT(f) { (f).res_pad = 0; (f).res_fs = 0; (f).res_pro = 0; }

  extern API_FUNCTION NetServerGetInfo(const char *pszServer,short sLevel,char *pbBuffer,unsigned short cbBuffer,unsigned short *pcbTotalAvail);

  struct server_info_0 {
    char sv0_name[CNLEN + 1];
  };

  struct server_info_1 {
    char sv1_name[CNLEN + 1];
    unsigned char sv1_version_major;
    unsigned char sv1_version_minor;
    unsigned __LONG32 sv1_type;
    char *sv1_comment;
  };

  struct server_info_50 {
    char sv50_name[CNLEN + 1];
    unsigned char sv50_version_major;
    unsigned char sv50_version_minor;
    unsigned __LONG32 sv50_type;
    char *sv50_comment;
    unsigned short sv50_security;
    unsigned short sv50_auditing;
    char *sv50_container;
    char *sv50_ab_server;
    char *sv50_ab_dll;
  };

  struct server_info_2 {
    char sv2_name[CNLEN + 1];
    unsigned char sv2_version_major;
    unsigned char sv2_version_minor;
    unsigned __LONG32 sv2_type;
    char *sv2_comment;
    unsigned __LONG32 sv2_ulist_mtime;
    unsigned __LONG32 sv2_glist_mtime;
    unsigned __LONG32 sv2_alist_mtime;
    unsigned short sv2_users;
    unsigned short sv2_disc;
    char *sv2_alerts;
    unsigned short sv2_security;
    unsigned short sv2_auditing;
    unsigned short sv2_numadmin;
    unsigned short sv2_lanmask;
    unsigned short sv2_hidden;
    unsigned short sv2_announce;
    unsigned short sv2_anndelta;
    char sv2_guestacct[LM20_UNLEN + 1];
    unsigned char sv2_pad1;
    char *sv2_userpath;
    unsigned short sv2_chdevs;
    unsigned short sv2_chdevq;
    unsigned short sv2_chdevjobs;
    unsigned short sv2_connections;
    unsigned short sv2_shares;
    unsigned short sv2_openfiles;
    unsigned short sv2_sessopens;
    unsigned short sv2_sessvcs;
    unsigned short sv2_sessreqs;
    unsigned short sv2_opensearch;
    unsigned short sv2_activelocks;
    unsigned short sv2_numreqbuf;
    unsigned short sv2_sizreqbuf;
    unsigned short sv2_numbigbuf;
    unsigned short sv2_numfiletasks;
    unsigned short sv2_alertsched;
    unsigned short sv2_erroralert;
    unsigned short sv2_logonalert;
    unsigned short sv2_accessalert;
    unsigned short sv2_diskalert;
    unsigned short sv2_netioalert;
    unsigned short sv2_maxauditsz;
    char *sv2_srvheuristics;
  };

  struct server_info_3 {
    char sv3_name[CNLEN + 1];
    unsigned char sv3_version_major;
    unsigned char sv3_version_minor;
    unsigned __LONG32 sv3_type;
    char *sv3_comment;
    unsigned __LONG32 sv3_ulist_mtime;
    unsigned __LONG32 sv3_glist_mtime;
    unsigned __LONG32 sv3_alist_mtime;
    unsigned short sv3_users;
    unsigned short sv3_disc;
    char *sv3_alerts;
    unsigned short sv3_security;
    unsigned short sv3_auditing;
    unsigned short sv3_numadmin;
    unsigned short sv3_lanmask;
    unsigned short sv3_hidden;
    unsigned short sv3_announce;
    unsigned short sv3_anndelta;
    char sv3_guestacct[LM20_UNLEN + 1];
    unsigned char sv3_pad1;
    char *sv3_userpath;
    unsigned short sv3_chdevs;
    unsigned short sv3_chdevq;
    unsigned short sv3_chdevjobs;
    unsigned short sv3_connections;
    unsigned short sv3_shares;
    unsigned short sv3_openfiles;
    unsigned short sv3_sessopens;
    unsigned short sv3_sessvcs;
    unsigned short sv3_sessreqs;
    unsigned short sv3_opensearch;
    unsigned short sv3_activelocks;
    unsigned short sv3_numreqbuf;
    unsigned short sv3_sizreqbuf;
    unsigned short sv3_numbigbuf;
    unsigned short sv3_numfiletasks;
    unsigned short sv3_alertsched;
    unsigned short sv3_erroralert;
    unsigned short sv3_logonalert;
    unsigned short sv3_accessalert;
    unsigned short sv3_diskalert;
    unsigned short sv3_netioalert;
    unsigned short sv3_maxauditsz;
    char *sv3_srvheuristics;
    unsigned __LONG32 sv3_auditedevents;
    unsigned short sv3_autoprofile;
    char *sv3_autopath;
  };

#define MAJOR_VERSION_MASK 0x0F

#define SV_TYPE_WORKSTATION 0x00000001
#define SV_TYPE_SERVER 0x00000002
#define SV_TYPE_SQLSERVER 0x00000004
#define SV_TYPE_DOMAIN_CTRL 0x00000008
#define SV_TYPE_DOMAIN_BAKCTRL 0x00000010
#define SV_TYPE_TIME_SOURCE 0x00000020
#define SV_TYPE_AFP 0x00000040
#define SV_TYPE_NOVELL 0x00000080
#define SV_TYPE_DOMAIN_MEMBER 0x00000100
#define SV_TYPE_PRINTQ_SERVER 0x00000200
#define SV_TYPE_DIALIN_SERVER 0x00000400
#define SV_TYPE_ALL 0xFFFFFFFF

#define SV_NODISC 0xFFFF

#define SV_USERSECURITY 1
#define SV_SHARESECURITY 0

#define SV_SECURITY_SHARE 0
#define SV_SECURITY_WINNT 1
#define SV_SECURITY_WINNTAS 2
#define SV_SECURITY_NETWARE 3

#define SV_HIDDEN 1
#define SV_VISIBLE 0

#define SVI1_NUM_ELEMENTS 5
#define SVI2_NUM_ELEMENTS 44
#define SVI3_NUM_ELEMENTS 45

#define SW_AUTOPROF_LOAD_MASK 0x1
#define SW_AUTOPROF_SAVE_MASK 0x2

  extern API_FUNCTION NetSecurityGetInfo(const char *pszServer,short sLevel,char *pbBuffer,unsigned short cbBuffer,unsigned short *pcbTotalAvail);

  struct security_info_1 {
    unsigned __LONG32 sec1_security;
    char *sec1_container;
    char *sec1_ab_server;
    char *sec1_ab_dll;
  };

#define SEC_SECURITY_SHARE SV_SECURITY_SHARE
#define SEC_SECURITY_WINNT SV_SECURITY_WINNT
#define SEC_SECURITY_WINNTAS SV_SECURITY_WINNTAS
#define SEC_SECURITY_NETWARE SV_SECURITY_NETWARE

#ifdef __cplusplus
}
#endif

#ifndef RC_INVOKED
#pragma pack()
#endif
#endif

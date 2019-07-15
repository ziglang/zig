/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _LMAUDIT_
#define _LMAUDIT_

#ifdef __cplusplus
extern "C" {
#endif

#ifndef _LMHLOGDEFINED_
#define _LMHLOGDEFINED_

  typedef struct _HLOG {
    DWORD time;
    DWORD last_flags;
    DWORD offset;
    DWORD rec_offset;
  } HLOG,*PHLOG,*LPHLOG;

#define LOGFLAGS_FORWARD 0
#define LOGFLAGS_BACKWARD 0x1
#define LOGFLAGS_SEEK 0x2
#endif

  DWORD WINAPI NetAuditClear(LPCWSTR server,LPCWSTR backupfile,LPCWSTR service);
  DWORD WINAPI NetAuditRead(LPCWSTR server,LPCWSTR service,LPHLOG auditloghandle,DWORD offset,LPDWORD reserved1,DWORD reserved2,DWORD offsetflag,LPBYTE *bufptr,DWORD prefmaxlen,LPDWORD bytesread,LPDWORD totalavailable);
  DWORD WINAPI NetAuditWrite(DWORD type,LPBYTE buf,DWORD numbytes,LPCWSTR service,LPBYTE reserved);

  typedef struct _AUDIT_ENTRY {
    DWORD ae_len;
    DWORD ae_reserved;
    DWORD ae_time;
    DWORD ae_type;
    DWORD ae_data_offset;
    DWORD ae_data_size;
  } AUDIT_ENTRY,*PAUDIT_ENTRY,*LPAUDIT_ENTRY;

#define REVISED_AUDIT_ENTRY_STRUCT

  typedef struct _AE_SRVSTATUS {
    DWORD ae_sv_status;
  } AE_SRVSTATUS,*PAE_SRVSTATUS,*LPAE_SRVSTATUS;

  typedef struct _AE_SESSLOGON {
    DWORD ae_so_compname;
    DWORD ae_so_username;
    DWORD ae_so_privilege;
  } AE_SESSLOGON,*PAE_SESSLOGON,*LPAE_SESSLOGON;

  typedef struct _AE_SESSLOGOFF {
    DWORD ae_sf_compname;
    DWORD ae_sf_username;
    DWORD ae_sf_reason;
  } AE_SESSLOGOFF,*PAE_SESSLOGOFF,*LPAE_SESSLOGOFF;

  typedef struct _AE_SESSPWERR {
    DWORD ae_sp_compname;
    DWORD ae_sp_username;
  } AE_SESSPWERR,*PAE_SESSPWERR,*LPAE_SESSPWERR;

  typedef struct _AE_CONNSTART {
    DWORD ae_ct_compname;
    DWORD ae_ct_username;
    DWORD ae_ct_netname;
    DWORD ae_ct_connid;
  } AE_CONNSTART,*PAE_CONNSTART,*LPAE_CONNSTART;

  typedef struct _AE_CONNSTOP {
    DWORD ae_cp_compname;
    DWORD ae_cp_username;
    DWORD ae_cp_netname;
    DWORD ae_cp_connid;
    DWORD ae_cp_reason;
  } AE_CONNSTOP,*PAE_CONNSTOP,*LPAE_CONNSTOP;

  typedef struct _AE_CONNREJ {
    DWORD ae_cr_compname;
    DWORD ae_cr_username;
    DWORD ae_cr_netname;
    DWORD ae_cr_reason;
  } AE_CONNREJ,*PAE_CONNREJ,*LPAE_CONNREJ;

  typedef struct _AE_RESACCESS {
    DWORD ae_ra_compname;
    DWORD ae_ra_username;
    DWORD ae_ra_resname;
    DWORD ae_ra_operation;
    DWORD ae_ra_returncode;
    DWORD ae_ra_restype;
    DWORD ae_ra_fileid;
  } AE_RESACCESS,*PAE_RESACCESS,*LPAE_RESACCESS;

  typedef struct _AE_RESACCESSREJ {
    DWORD ae_rr_compname;
    DWORD ae_rr_username;
    DWORD ae_rr_resname;
    DWORD ae_rr_operation;
  } AE_RESACCESSREJ,*PAE_RESACCESSREJ,*LPAE_RESACCESSREJ;

  typedef struct _AE_CLOSEFILE {
    DWORD ae_cf_compname;
    DWORD ae_cf_username;
    DWORD ae_cf_resname;
    DWORD ae_cf_fileid;
    DWORD ae_cf_duration;
    DWORD ae_cf_reason;
  } AE_CLOSEFILE,*PAE_CLOSEFILE,*LPAE_CLOSEFILE;

  typedef struct _AE_SERVICESTAT {
    DWORD ae_ss_compname;
    DWORD ae_ss_username;
    DWORD ae_ss_svcname;
    DWORD ae_ss_status;
    DWORD ae_ss_code;
    DWORD ae_ss_text;
    DWORD ae_ss_returnval;
  } AE_SERVICESTAT,*PAE_SERVICESTAT,*LPAE_SERVICESTAT;

  typedef struct _AE_ACLMOD {
    DWORD ae_am_compname;
    DWORD ae_am_username;
    DWORD ae_am_resname;
    DWORD ae_am_action;
    DWORD ae_am_datalen;
  } AE_ACLMOD,*PAE_ACLMOD,*LPAE_ACLMOD;

  typedef struct _AE_UASMOD {
    DWORD ae_um_compname;
    DWORD ae_um_username;
    DWORD ae_um_resname;
    DWORD ae_um_rectype;
    DWORD ae_um_action;
    DWORD ae_um_datalen;
  } AE_UASMOD,*PAE_UASMOD,*LPAE_UASMOD;

  typedef struct _AE_NETLOGON {
    DWORD ae_no_compname;
    DWORD ae_no_username;
    DWORD ae_no_privilege;
    DWORD ae_no_authflags;
  } AE_NETLOGON,*PAE_NETLOGON,*LPAE_NETLOGON;

  typedef struct _AE_NETLOGOFF {
    DWORD ae_nf_compname;
    DWORD ae_nf_username;
    DWORD ae_nf_reserved1;
    DWORD ae_nf_reserved2;
  } AE_NETLOGOFF,*PAE_NETLOGOFF,*LPAE_NETLOGOFF;

  typedef struct _AE_ACCLIM {
    DWORD ae_al_compname;
    DWORD ae_al_username;
    DWORD ae_al_resname;
    DWORD ae_al_limit;
  } AE_ACCLIM,*PAE_ACCLIM,*LPAE_ACCLIM;

#define ACTION_LOCKOUT 00
#define ACTION_ADMINUNLOCK 01

  typedef struct _AE_LOCKOUT {
    DWORD ae_lk_compname;
    DWORD ae_lk_username;
    DWORD ae_lk_action;
    DWORD ae_lk_bad_pw_count;
  } AE_LOCKOUT,*PAE_LOCKOUT,*LPAE_LOCKOUT;

  typedef struct _AE_GENERIC {
    DWORD ae_ge_msgfile;
    DWORD ae_ge_msgnum;
    DWORD ae_ge_params;
    DWORD ae_ge_param1;
    DWORD ae_ge_param2;
    DWORD ae_ge_param3;
    DWORD ae_ge_param4;
    DWORD ae_ge_param5;
    DWORD ae_ge_param6;
    DWORD ae_ge_param7;
    DWORD ae_ge_param8;
    DWORD ae_ge_param9;
  } AE_GENERIC,*PAE_GENERIC,*LPAE_GENERIC;

#define AE_SRVSTATUS 0
#define AE_SESSLOGON 1
#define AE_SESSLOGOFF 2
#define AE_SESSPWERR 3
#define AE_CONNSTART 4
#define AE_CONNSTOP 5
#define AE_CONNREJ 6
#define AE_RESACCESS 7
#define AE_RESACCESSREJ 8
#define AE_CLOSEFILE 9
#define AE_SERVICESTAT 11
#define AE_ACLMOD 12
#define AE_UASMOD 13
#define AE_NETLOGON 14
#define AE_NETLOGOFF 15
#define AE_NETLOGDENIED 16
#define AE_ACCLIMITEXCD 17
#define AE_RESACCESS2 18
#define AE_ACLMODFAIL 19
#define AE_LOCKOUT 20
#define AE_GENERIC_TYPE 21

#define AE_SRVSTART 0
#define AE_SRVPAUSED 1
#define AE_SRVCONT 2
#define AE_SRVSTOP 3

#define AE_GUEST 0
#define AE_USER 1
#define AE_ADMIN 2

#define AE_NORMAL 0
#define AE_USERLIMIT 0
#define AE_GENERAL 0
#define AE_ERROR 1
#define AE_SESSDIS 1
#define AE_BADPW 1
#define AE_AUTODIS 2
#define AE_UNSHARE 2
#define AE_ADMINPRIVREQD 2
#define AE_ADMINDIS 3
#define AE_NOACCESSPERM 3
#define AE_ACCRESTRICT 4

#define AE_NORMAL_CLOSE 0
#define AE_SES_CLOSE 1
#define AE_ADMIN_CLOSE 2

#define AE_LIM_UNKNOWN 0
#define AE_LIM_LOGONHOURS 1
#define AE_LIM_EXPIRED 2
#define AE_LIM_INVAL_WKSTA 3
#define AE_LIM_DISABLED 4
#define AE_LIM_DELETED 5

#define AE_MOD 0
#define AE_DELETE 1
#define AE_ADD 2

#define AE_UAS_USER 0
#define AE_UAS_GROUP 1
#define AE_UAS_MODALS 2

#define SVAUD_SERVICE 0x1
#define SVAUD_GOODSESSLOGON 0x6
#define SVAUD_BADSESSLOGON 0x18
#define SVAUD_SESSLOGON (SVAUD_GOODSESSLOGON | SVAUD_BADSESSLOGON)
#define SVAUD_GOODNETLOGON 0x60
#define SVAUD_BADNETLOGON 0x180
#define SVAUD_NETLOGON (SVAUD_GOODNETLOGON | SVAUD_BADNETLOGON)
#define SVAUD_LOGON (SVAUD_NETLOGON | SVAUD_SESSLOGON)
#define SVAUD_GOODUSE 0x600
#define SVAUD_BADUSE 0x1800
#define SVAUD_USE (SVAUD_GOODUSE | SVAUD_BADUSE)
#define SVAUD_USERLIST 0x2000
#define SVAUD_PERMISSIONS 0x4000
#define SVAUD_RESOURCE 0x8000
#define SVAUD_LOGONLIM 0x00010000

#define AA_AUDIT_ALL 0x0001
#define AA_A_OWNER 0x0004
#define AA_CLOSE 0x0008
#define AA_S_OPEN 0x0010
#define AA_S_WRITE 0x0020
#define AA_S_CREATE 0x0020
#define AA_S_DELETE 0x0040
#define AA_S_ACL 0x0080
#define AA_S_ALL (AA_S_OPEN | AA_S_WRITE | AA_S_DELETE | AA_S_ACL)
#define AA_F_OPEN 0x0100
#define AA_F_WRITE 0x0200
#define AA_F_CREATE 0x0200
#define AA_F_DELETE 0x0400
#define AA_F_ACL 0x0800
#define AA_F_ALL (AA_F_OPEN | AA_F_WRITE | AA_F_DELETE | AA_F_ACL)

#define AA_A_OPEN 0x1000
#define AA_A_WRITE 0x2000
#define AA_A_CREATE 0x2000
#define AA_A_DELETE 0x4000
#define AA_A_ACL 0x8000
#define AA_A_ALL (AA_F_OPEN | AA_F_WRITE | AA_F_DELETE | AA_F_ACL)

#ifdef __cplusplus
}
#endif
#endif

/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _DBT_H
#define _DBT_H
#include <_mingw_unicode.h>

#define WM_DEVICECHANGE 0x0219

#ifdef IS_32
#define DBTFAR
#else
#define DBTFAR far
#endif

#ifndef _WCHAR_T_DEFINED
#define _WCHAR_T_DEFINED
typedef unsigned short wchar_t;
#endif

#include <guiddef.h>

#define BSF_QUERY 0x00000001
#define BSF_IGNORECURRENTTASK 0x00000002
#define BSF_FLUSHDISK 0x00000004
#define BSF_NOHANG 0x00000008
#define BSF_POSTMESSAGE 0x00000010
#define BSF_FORCEIFHUNG 0x00000020
#define BSF_NOTIMEOUTIFNOTHUNG 0x00000040
#define BSF_MSGSRV32ISOK 0x80000000
#define BSF_MSGSRV32ISOK_BIT 31

#define BSM_ALLCOMPONENTS 0x00000000
#define BSM_VXDS 0x00000001
#define BSM_NETDRIVER 0x00000002
#define BSM_INSTALLABLEDRIVERS 0x00000004
#define BSM_APPLICATIONS 0x00000008

#define DBT_APPYBEGIN 0x0000
#define DBT_APPYEND 0x0001
#define DBT_DEVNODES_CHANGED 0x0007
#define DBT_QUERYCHANGECONFIG 0x0017
#define DBT_CONFIGCHANGED 0x0018
#define DBT_CONFIGCHANGECANCELED 0x0019
#define DBT_MONITORCHANGE 0x001B
#define DBT_SHELLLOGGEDON 0x0020
#define DBT_CONFIGMGAPI32 0x0022
#define DBT_VXDINITCOMPLETE 0x0023
#define DBT_VOLLOCKQUERYLOCK 0x8041
#define DBT_VOLLOCKLOCKTAKEN 0x8042
#define DBT_VOLLOCKLOCKFAILED 0x8043
#define DBT_VOLLOCKQUERYUNLOCK 0x8044
#define DBT_VOLLOCKLOCKRELEASED 0x8045
#define DBT_VOLLOCKUNLOCKFAILED 0x8046

struct _DEV_BROADCAST_HDR {
  DWORD dbch_size;
  DWORD dbch_devicetype;
  DWORD dbch_reserved;
};

typedef struct _DEV_BROADCAST_HDR DEV_BROADCAST_HDR;
typedef DEV_BROADCAST_HDR DBTFAR *PDEV_BROADCAST_HDR;
typedef struct VolLockBroadcast VolLockBroadcast;
typedef VolLockBroadcast *pVolLockBroadcast;

struct VolLockBroadcast {
  struct _DEV_BROADCAST_HDR vlb_dbh;
  DWORD vlb_owner;
  BYTE vlb_perms;
  BYTE vlb_lockType;
  BYTE vlb_drive;
  BYTE vlb_flags;
};

#define LOCKP_ALLOW_WRITES 0x01
#define LOCKP_FAIL_WRITES 0x00
#define LOCKP_FAIL_MEM_MAPPING 0x02
#define LOCKP_ALLOW_MEM_MAPPING 0x00
#define LOCKP_USER_MASK 0x03
#define LOCKP_LOCK_FOR_FORMAT 0x04

#define LOCKF_LOGICAL_LOCK 0x00
#define LOCKF_PHYSICAL_LOCK 0x01

#define DBT_NO_DISK_SPACE 0x0047
#define DBT_LOW_DISK_SPACE 0x0048
#define DBT_CONFIGMGPRIVATE 0x7FFF
#define DBT_DEVICEARRIVAL 0x8000
#define DBT_DEVICEQUERYREMOVE 0x8001
#define DBT_DEVICEQUERYREMOVEFAILED 0x8002
#define DBT_DEVICEREMOVEPENDING 0x8003
#define DBT_DEVICEREMOVECOMPLETE 0x8004
#define DBT_DEVICETYPESPECIFIC 0x8005
#define DBT_CUSTOMEVENT 0x8006
#define DBT_DEVTYP_OEM 0x00000000
#define DBT_DEVTYP_DEVNODE 0x00000001
#define DBT_DEVTYP_VOLUME 0x00000002
#define DBT_DEVTYP_PORT 0x00000003
#define DBT_DEVTYP_NET 0x00000004
#define DBT_DEVTYP_DEVICEINTERFACE 0x00000005
#define DBT_DEVTYP_HANDLE 0x00000006

struct _DEV_BROADCAST_HEADER {
  DWORD dbcd_size;
  DWORD dbcd_devicetype;
  DWORD dbcd_reserved;
};

struct _DEV_BROADCAST_OEM {
  DWORD dbco_size;
  DWORD dbco_devicetype;
  DWORD dbco_reserved;
  DWORD dbco_identifier;
  DWORD dbco_suppfunc;
};

typedef struct _DEV_BROADCAST_OEM DEV_BROADCAST_OEM;
typedef DEV_BROADCAST_OEM DBTFAR *PDEV_BROADCAST_OEM;

struct _DEV_BROADCAST_DEVNODE {
  DWORD dbcd_size;
  DWORD dbcd_devicetype;
  DWORD dbcd_reserved;
  DWORD dbcd_devnode;
};

typedef struct _DEV_BROADCAST_DEVNODE DEV_BROADCAST_DEVNODE;
typedef DEV_BROADCAST_DEVNODE DBTFAR *PDEV_BROADCAST_DEVNODE;

struct _DEV_BROADCAST_VOLUME {
  DWORD dbcv_size;
  DWORD dbcv_devicetype;
  DWORD dbcv_reserved;
  DWORD dbcv_unitmask;
  WORD dbcv_flags;
};

typedef struct _DEV_BROADCAST_VOLUME DEV_BROADCAST_VOLUME;
typedef DEV_BROADCAST_VOLUME DBTFAR *PDEV_BROADCAST_VOLUME;

#define DBTF_MEDIA 0x0001
#define DBTF_NET 0x0002

typedef struct _DEV_BROADCAST_PORT_A {
  DWORD dbcp_size;
  DWORD dbcp_devicetype;
  DWORD dbcp_reserved;
  char dbcp_name[1];
} DEV_BROADCAST_PORT_A,*PDEV_BROADCAST_PORT_A;

typedef struct _DEV_BROADCAST_PORT_W {
  DWORD dbcp_size;
  DWORD dbcp_devicetype;
  DWORD dbcp_reserved;
  wchar_t dbcp_name[1];
} DEV_BROADCAST_PORT_W,DBTFAR *PDEV_BROADCAST_PORT_W;

__MINGW_TYPEDEF_UAW(DEV_BROADCAST_PORT)
__MINGW_TYPEDEF_UAW(PDEV_BROADCAST_PORT)

struct _DEV_BROADCAST_NET {
  DWORD dbcn_size;
  DWORD dbcn_devicetype;
  DWORD dbcn_reserved;
  DWORD dbcn_resource;
  DWORD dbcn_flags;
};

typedef struct _DEV_BROADCAST_NET DEV_BROADCAST_NET;
typedef DEV_BROADCAST_NET DBTFAR *PDEV_BROADCAST_NET;

typedef struct _DEV_BROADCAST_DEVICEINTERFACE_A {
  DWORD dbcc_size;
  DWORD dbcc_devicetype;
  DWORD dbcc_reserved;
  GUID dbcc_classguid;
  char dbcc_name[1];
} DEV_BROADCAST_DEVICEINTERFACE_A,*PDEV_BROADCAST_DEVICEINTERFACE_A;

typedef struct _DEV_BROADCAST_DEVICEINTERFACE_W {
  DWORD dbcc_size;
  DWORD dbcc_devicetype;
  DWORD dbcc_reserved;
  GUID dbcc_classguid;
  wchar_t dbcc_name[1];
} DEV_BROADCAST_DEVICEINTERFACE_W,*PDEV_BROADCAST_DEVICEINTERFACE_W;

__MINGW_TYPEDEF_UAW(DEV_BROADCAST_DEVICEINTERFACE)
__MINGW_TYPEDEF_UAW(PDEV_BROADCAST_DEVICEINTERFACE)

typedef struct _DEV_BROADCAST_HANDLE {
  DWORD dbch_size;
  DWORD dbch_devicetype;
  DWORD dbch_reserved;
  HANDLE dbch_handle;
  HDEVNOTIFY dbch_hdevnotify;

  GUID dbch_eventguid;
  LONG dbch_nameoffset;
  BYTE dbch_data[1];
} DEV_BROADCAST_HANDLE,*PDEV_BROADCAST_HANDLE;

typedef struct _DEV_BROADCAST_HANDLE32 {
  DWORD dbch_size;
  DWORD dbch_devicetype;
  DWORD dbch_reserved;
  ULONG32 dbch_handle;
  ULONG32 dbch_hdevnotify;
  GUID dbch_eventguid;
  LONG dbch_nameoffset;
  BYTE dbch_data[1];
} DEV_BROADCAST_HANDLE32,*PDEV_BROADCAST_HANDLE32;

typedef struct _DEV_BROADCAST_HANDLE64 {
  DWORD dbch_size;
  DWORD dbch_devicetype;
  DWORD dbch_reserved;
  ULONG64 dbch_handle;
  ULONG64 dbch_hdevnotify;
  GUID dbch_eventguid;
  LONG dbch_nameoffset;
  BYTE dbch_data[1];
} DEV_BROADCAST_HANDLE64,*PDEV_BROADCAST_HANDLE64;

#define DBTF_RESOURCE 0x00000001
#define DBTF_XPORT 0x00000002
#define DBTF_SLOWNET 0x00000004

#define DBT_VPOWERDAPI 0x8100

#define DBT_USERDEFINED 0xFFFF

struct _DEV_BROADCAST_USERDEFINED {
  struct _DEV_BROADCAST_HDR dbud_dbh;
  char dbud_szName[1];
};

#endif

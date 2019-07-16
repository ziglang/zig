/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef __REQUIRED_RPCNDR_H_VERSION__
#define __REQUIRED_RPCNDR_H_VERSION__ 475
#endif

#include "rpc.h"
#include "rpcndr.h"

#ifndef __RPCNDR_H_VERSION__
#error This stub requires an updated version of <rpcndr.h>
#endif

#ifndef __mddefw_h__
#define __mddefw_h__

#include "unknwn.h"

#ifdef __cplusplus
extern "C" {
#endif

#ifndef __MIDL_user_allocate_free_DEFINED__
#define __MIDL_user_allocate_free_DEFINED__
  void *__RPC_API MIDL_user_allocate(size_t);
  void __RPC_API MIDL_user_free(void *);
#endif

#ifndef _MD_DEFW_
#define _MD_DEFW_
#include <mdmsg.h>
#include <mdcommsg.h>

#define METADATA_MAX_NAME_LEN 256

#define METADATA_PERMISSION_READ 0x00000001
#define METADATA_PERMISSION_WRITE 0x00000002

  enum METADATATYPES {
    ALL_METADATA = 0,DWORD_METADATA,STRING_METADATA,BINARY_METADATA,
    EXPANDSZ_METADATA,MULTISZ_METADATA,INVALID_END_METADATA
  };

#define METADATA_NO_ATTRIBUTES 0
#define METADATA_INHERIT 0x00000001
#define METADATA_PARTIAL_PATH 0x00000002
#define METADATA_SECURE 0x00000004
#define METADATA_REFERENCE 0x00000008
#define METADATA_VOLATILE 0x00000010
#define METADATA_ISINHERITED 0x00000020
#define METADATA_INSERT_PATH 0x00000040
#define METADATA_LOCAL_MACHINE_ONLY 0x00000080
#define METADATA_NON_SECURE_ONLY 0x00000100

#define MD_BACKUP_OVERWRITE 0x00000001
#define MD_BACKUP_SAVE_FIRST 0x00000002
#define MD_BACKUP_FORCE_BACKUP 0x00000004

#define MD_BACKUP_NEXT_VERSION 0xffffffff
#define MD_BACKUP_HIGHEST_VERSION 0xfffffffe
#define MD_BACKUP_MAX_VERSION 9999
#define MD_BACKUP_MAX_LEN (100)

#define MD_DEFAULT_BACKUP_LOCATION TEXT("MDBackUp")

#define MD_HISTORY_LATEST 0x00000001

#define MD_EXPORT_INHERITED 0x00000001
#define MD_EXPORT_NODE_ONLY 0x00000002

#define MD_IMPORT_INHERITED 0x00000001
#define MD_IMPORT_NODE_ONLY 0x00000002
#define MD_IMPORT_MERGE 0x00000004

#define MD_INSERT_PATH_STRINGA "<%INSERT_PATH%>"
#define MD_INSERT_PATH_STRINGW L##"<%INSERT_PATH%>"
#define MD_INSERT_PATH_STRING TEXT("<%INSERT_PATH%>")

#define METADATA_MASTER_ROOT_HANDLE 0

  typedef struct _METADATA_RECORD {
    DWORD dwMDIdentifier;
    DWORD dwMDAttributes;
    DWORD dwMDUserType;
    DWORD dwMDDataType;
    DWORD dwMDDataLen;
    unsigned char *pbMDData;
    DWORD dwMDDataTag;
  } METADATA_RECORD;

  typedef struct _METADATA_RECORD *PMETADATA_RECORD;

  typedef struct _METADATA_GETALL_RECORD {
    DWORD dwMDIdentifier;
    DWORD dwMDAttributes;
    DWORD dwMDUserType;
    DWORD dwMDDataType;
    DWORD dwMDDataLen;
    DWORD dwMDDataOffset;
    DWORD dwMDDataTag;
  } METADATA_GETALL_RECORD;

  typedef struct _METADATA_GETALL_RECORD *PMETADATA_GETALL_RECORD;

  typedef struct _METADATA_GETALL_INTERNAL_RECORD {
    DWORD dwMDIdentifier;
    DWORD dwMDAttributes;
    DWORD dwMDUserType;
    DWORD dwMDDataType;
    DWORD dwMDDataLen;
    union {
      DWORD_PTR dwMDDataOffset;
      unsigned char *pbMDData;
    };
    DWORD dwMDDataTag;
  } METADATA_GETALL_INTERNAL_RECORD;

  typedef struct _METADATA_GETALL_INTERNAL_RECORD *PMETADATA_GETALL_INTERNAL_RECORD;
  typedef DWORD METADATA_HANDLE;
  typedef DWORD *PMETADATA_HANDLE;

  typedef struct _METADATA_HANDLE_INFO {
    DWORD dwMDPermissions;
    DWORD dwMDSystemChangeNumber;
  } METADATA_HANDLE_INFO;

  typedef struct _METADATA_HANDLE_INFO *PMETADATA_HANDLE_INFO;

#define MD_CHANGE_OBJECT MD_CHANGE_OBJECT_W
#define PMD_CHANGE_OBJECT PMD_CHANGE_OBJECT_W
  typedef struct _MD_CHANGE_OBJECT_W {
    LPWSTR pszMDPath;
    DWORD dwMDChangeType;
    DWORD dwMDNumDataIDs;
    DWORD *pdwMDDataIDs;
  } MD_CHANGE_OBJECT_W;

  typedef struct _MD_CHANGE_OBJECT_W *PMD_CHANGE_OBJECT_W;

#define MD_CHANGE_TYPE_DELETE_OBJECT 0x00000001
#define MD_CHANGE_TYPE_ADD_OBJECT 0x00000002
#define MD_CHANGE_TYPE_SET_DATA 0x00000004
#define MD_CHANGE_TYPE_DELETE_DATA 0x00000008
#define MD_CHANGE_TYPE_RENAME_OBJECT 0x00000010

#define MD_MAX_CHANGE_ENTRIES 100
#endif

  extern RPC_IF_HANDLE __MIDL_itf_mddefw_0000_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_mddefw_0000_v0_0_s_ifspec;

#ifdef __cplusplus
}
#endif
#endif

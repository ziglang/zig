/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _INC_NDATTRIB
#define _INC_NDATTRIB

#if (_WIN32_WINNT >= 0x0600)

/* In ndhelper.idl
typedef struct tagDIAG_SOCKADDR {
  USHORT family;
  CHAR   data[126];
} DIAG_SOCKADDR, *PDIAG_SOCKADDR;
*/

#ifdef __cplusplus
extern "C" {
#endif

typedef struct tagDIAG_SOCKADDR DIAG_SOCKADDR;

typedef enum tagATTRIBUTE_TYPE {
  AT_INVALID        = 0,
  AT_BOOLEAN,
  AT_INT8,
  AT_UINT8,
  AT_INT16,
  AT_UINT16,
  AT_INT32,
  AT_UINT32,
  AT_INT64,
  AT_UINT64,
  AT_STRING,
  AT_GUID,
  AT_LIFE_TIME,
  AT_SOCKADDR,
  AT_OCTET_STRING
} ATTRIBUTE_TYPE;

typedef enum tagREPAIR_SCOPE {
  RS_SYSTEM        = 0,
  RS_USER          = 1,
  RS_APPLICATION   = 2,
  RS_PROCESS       = 3
} REPAIR_SCOPE;

typedef enum tagREPAIR_RISK {
  RR_NOROLLBACK   = 0,
  RR_ROLLBACK     = 1,
  RR_NORISK       = 2
} REPAIR_RISK;

typedef enum tagUI_INFO_TYPE {
  UIT_NONE            = 0,
  UIT_SHELL_COMMAND,
  UIT_HELP_PANE,
  UIT_DUI
} UI_INFO_TYPE;

typedef enum tagPROBLEM_TYPE {
  PT_LOW_HEALTH              = 1,
  PT_LOWER_HEALTH            = 2,
  PT_DOWN_STREAM_HEALTH      = 4,
  PT_HIGH_UTILIZATION        = 8,
  PT_HIGHER_UTILIZATION      = 16,
  PT_UP_STREAM_UTILIZATION   = 32
} PROBLEM_TYPE;

typedef enum tagREPAIR_STATUS {
  RS_NOT_IMPLEMENTED   = 0,
  RS_REPAIRED          = 1,
  RS_UNREPAIRED        = 2,
  RS_DEFERRED          = 3,
  RS_USER_ACTION       = 4
} REPAIR_STATUS;

typedef struct tagLIFE_TIME {
  FILETIME startTime;
  FILETIME endTime;
} LIFE_TIME, *PLIFE_TIME;

typedef struct tagOCTET_STRING {
  DWORD dwLength;
  BYTE  *lpValue;
} OCTET_STRING, *POCTET_STRING;

typedef struct tagUiInfo {
  UI_INFO_TYPE type;
  __C89_NAMELESS union {
    LPWSTR pwzNull;
    ShellCommandInfo ShellInfo;
    LPWSTR pwzHelpURL;
    LPWSTR pwzDui;
  };
} UiInfo, *PUiInfo;

typedef struct tagRepairInfo {
  GUID            guid;
  LPWSTR          pwszClassName;
  LPWSTR          pwszDescription;
  DWORD           sidType;
  __LONG32            cost;
  ULONG           flags;
  REPAIR_SCOPE    scope;
  REPAIR_RISK     risk;
  UiInfo          UiInfo;
} RepairInfo, *PRepairInfo;

typedef struct tagShellCommandInfo {
  LPWSTR pwszOperation;
  LPWSTR pwszFile;
  LPWSTR pwszParameters;
  LPWSTR pwszDirectory;
  ULONG  nShowCmd;
} ShellCommandInfo, *PShellCommandInfo;

typedef struct tagHELPER_ATTRIBUTE {
  LPWSTR pwszName;
  ATTRIBUTE_TYPE  type;
  __C89_NAMELESS union {
    WINBOOL Boolean;
    char Char;
    byte Byte;
    short Short;
    WORD Word;
    int Int;
    DWORD DWord;
    LONGLONG Int64;
    ULONGLONG UInt64;
    LPWSTR PWStr;
    GUID Guid;
    LIFE_TYPE LifeTime;
    DIAG_SOCKADDR Address;
    OCTET_STRING OctetString;
  };
} HELPER_ATTRIBUTE;

#ifdef __cplusplus
}
#endif


#if (_WIN32_WINNT >= 0x0601)

#ifdef __cplusplus
extern "C" {
#endif

#define RCF_ISLEAF 0x1
#define RCF_ISCONFIRMED 0x2
#define RCF_ISTHIRDPARTY 0x4

typedef struct tagRepairInfoEx {
  RepairInfo repair;
  USHORT     repairRank;
} RepairInfoEx, *PRepairInfoEx;

typedef struct tagRootCauseInfo {
  LPWSTR       pwszDescription;
  GUID         rootCauseID;
  DWORD        rootCauseFlags;
  GUID         networkInterfaceID;
  RepairInfoEx *pRepairs;
  USHORT       repairCount;
} RootCauseInfo;

#ifdef __cplusplus
}
#endif

#endif /*(_WIN32_WINNT >= 0x0601)*/


#endif /*(_WIN32_WINNT >= 0x0600)*/

#endif /*_INC_NDATTRIB*/


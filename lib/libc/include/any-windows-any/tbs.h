/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#ifndef _TBS_H_
#define _TBS_H_

#include <winapifamily.h>

#if WINAPI_FAMILY_PARTITION(WINAPI_PARTITION_DESKTOP)

#if defined(__cplusplus)
extern "C" {
#endif

#if (NTDDI_VERSION >= NTDDI_VISTA)

#ifndef WINAPI
#define WINAPI __stdcall
#endif

#define CONST const

typedef signed int INT32, *PINT32;
typedef const INT32 *PCINT32;
typedef unsigned int UINT32, *PUINT32;
typedef const UINT32 *PCUINT32;

#define VOID void
typedef VOID *PVOID;
typedef const VOID *PCVOID;

typedef INT32 WINBOOL, *PBOOL;
typedef const WINBOOL *PCBOOL;

typedef UINT8 BYTE, *PBYTE;
typedef const BYTE *PCBYTE;

typedef WINBOOL TBS_BOOL;
typedef UINT32 TBS_RESULT;
typedef PVOID TBS_HCONTEXT, *PTBS_HCONTEXT;
typedef UINT32 TBS_COMMAND_PRIORITY;
typedef UINT32 TBS_COMMAND_LOCALITY;
typedef UINT32 TBS_OWNERAUTH_TYPE;
typedef UINT32 TBS_HANDLE;

#define TBS_CONTEXT_VERSION_ONE 1

#define TBS_COMMAND_PRIORITY_LOW 100
#define TBS_COMMAND_PRIORITY_NORMAL 200
#define TBS_COMMAND_PRIORITY_HIGH 300
#define TBS_COMMAND_PRIORITY_SYSTEM 400
#define TBS_COMMAND_PRIORITY_MAX 0x80000000

#define TBS_COMMAND_LOCALITY_ZERO 0
#define TBS_COMMAND_LOCALITY_ONE 1
#define TBS_COMMAND_LOCALITY_TWO 2
#define TBS_COMMAND_LOCALITY_THREE 3
#define TBS_COMMAND_LOCALITY_FOUR 4

#define TBS_SUCCESS 0

#define TBS_IN_OUT_BUF_SIZE_MAX (256 * 1024)

#define TBS_OWNERAUTH_TYPE_FULL 1
#define TBS_OWNERAUTH_TYPE_ADMIN 2
#define TBS_OWNERAUTH_TYPE_USER 3
#define TBS_OWNERAUTH_TYPE_ENDORSEMENT 4

#define TBS_OWNERAUTH_TYPE_ENDORSEMENT_20 12
#define TBS_OWNERAUTH_TYPE_STORAGE_20 13

typedef struct tdTBS_CONTEXT_PARAMS {
    UINT32 version;
} TBS_CONTEXT_PARAMS, *PTBS_CONTEXT_PARAMS;
typedef const TBS_CONTEXT_PARAMS *PCTBS_CONTEXT_PARAMS;

TBS_RESULT WINAPI Tbsi_Context_Create(PCTBS_CONTEXT_PARAMS pContextParams, PTBS_HCONTEXT phContext);
TBS_RESULT WINAPI Tbsip_Context_Close(TBS_HCONTEXT hContext);
TBS_RESULT WINAPI Tbsip_Submit_Command(TBS_HCONTEXT hContext, TBS_COMMAND_LOCALITY Locality, TBS_COMMAND_PRIORITY Priority, PCBYTE pabCommand, UINT32 cbCommand, PBYTE pabResult, PUINT32 pcbResult);
TBS_RESULT WINAPI Tbsip_Cancel_Commands(TBS_HCONTEXT hContext);
TBS_RESULT WINAPI Tbsi_Physical_Presence_Command(TBS_HCONTEXT hContext, PCBYTE pabInput, UINT32 cbInput, PBYTE pabOutput, PUINT32 pcbOutput);

#endif /* (NTDDI_VERSION >= NTDDI_VISTA) */

#if (NTDDI_VERSION >= NTDDI_VISTASP1)

TBS_RESULT WINAPI Tbsi_Get_TCG_Log(TBS_HCONTEXT hContext, PBYTE pOutputBuf, PUINT32 pOutputBufLen);

#endif /* _WIN32_WINNT_VISTASP1 */

#if (NTDDI_VERSION >= NTDDI_WIN8)

#define TBS_CONTEXT_VERSION_TWO 2

typedef struct tdTBS_CONTEXT_PARAMS2 {
    UINT32 version;
    __C89_NAMELESS union {
        __C89_NAMELESS struct {
            UINT32 requestRaw : 1;
            UINT32 includeTpm12 : 1;
            UINT32 includeTpm20 : 1;
        };
        UINT32 asUINT32;
    };
} TBS_CONTEXT_PARAMS2, *PTBS_CONTEXT_PARAMS2;
typedef const TBS_CONTEXT_PARAMS2 *PCTBS_CONTEXT_PARAMS2;

typedef struct tdTPM_WNF_PROVISIONING {
    UINT32 status;
    BYTE message[28];
} TPM_WNF_PROVISIONING;

#define TPM_WNF_INFO_CLEAR_SUCCESSFUL 0x00000001
#define TPM_WNF_INFO_OWNERSHIP_SUCCESSFUL 0x00000002

#define TPM_WNF_INFO_NO_REBOOT_REQUIRED 1

#ifndef TPM_VERSION_UNKNOWN

#define TPM_VERSION_UNKNOWN 0
#define TPM_VERSION_12 1
#define TPM_VERSION_20 2

#define TPM_IFTYPE_UNKNOWN 0
#define TPM_IFTYPE_1 1
#define TPM_IFTYPE_TRUSTZONE 2
#define TPM_IFTYPE_HW 3
#define TPM_IFTYPE_EMULATOR 4
#define TPM_IFTYPE_SPB 5

typedef struct _TPM_DEVICE_INFO {
    UINT32 structVersion;
    UINT32 tpmVersion;
    UINT32 tpmInterfaceType;
    UINT32 tpmImpRevision;
} TPM_DEVICE_INFO, *PTPM_DEVICE_INFO;
typedef const TPM_DEVICE_INFO *PCTPM_DEVICE_INFO;

#endif /* TPM_VERSION_UNKNOWN */

TBS_RESULT WINAPI Tbsi_GetDeviceInfo(UINT32 Size, PVOID Info);
TBS_RESULT WINAPI Tbsi_Get_OwnerAuth(TBS_HCONTEXT hContext, TBS_OWNERAUTH_TYPE ownerauthType, PBYTE pOutputBuf, PUINT32 pOutputBufLen);
TBS_RESULT WINAPI Tbsi_Revoke_Attestation(void);

#endif /* (NTDDI_VERSION >= NTDDI_WIN8) */

#if (NTDDI_VERSION >= NTDDI_WINBLUE)

#ifndef _NTDDK_

HRESULT GetDeviceID(PBYTE pbWindowsAIK, UINT32 cbWindowsAIK, PUINT32 pcbResult, WINBOOL *pfProtectedByTPM);
HRESULT GetDeviceIDString(PWSTR pszWindowsAIK, UINT32 cchWindowsAIK, PUINT32 pcchResult, WINBOOL *pfProtectedByTPM);

#endif /* ifndef _NTDDK_ */

#endif /* (NTDDI_VERSION >= NTDDI_WINBLUE) */

#if (NTDDI_VERSION >= NTDDI_WINTHRESHOLD)

TBS_RESULT WINAPI Tbsi_Create_Windows_Key(TBS_HANDLE keyHandle);

#endif /* (NTDDI_VERSION >= NTDDI_WINTHRESHOLD) */

#if (NTDDI_VERSION >= NTDDI_WIN10_RS4)

#define TBS_TCGLOG_SRTM_CURRENT 0
#define TBS_TCGLOG_DRTM_CURRENT 1
#define TBS_TCGLOG_SRTM_BOOT 2
#define TBS_TCGLOG_SRTM_RESUME 3
#define TBS_TCGLOG_DRTM_BOOT 4
#define TBS_TCGLOG_DRTM_RESUME 5

TBS_RESULT WINAPI Tbsi_Get_TCG_Log_Ex(UINT32 logType, PBYTE pbOutput, PUINT32 pcbOutput);

#endif /* (NTDDI_VERSION >= NTDDI_WIN10_RS4) */

#if (NTDDI_VERSION >= NTDDI_WIN10_NI)

WINBOOL WINAPI Tbsi_Is_Tpm_Present(void);

#endif /* (NTDDI_VERSION >= NTDDI_WIN10_NI) */

#if defined(__cplusplus)
}
#endif

#endif /* WINAPI_FAMILY_PARTITION(WINAPI_PARTITION_DESKTOP) */

#endif /* _TBS_H_ */

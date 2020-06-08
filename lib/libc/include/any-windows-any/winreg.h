/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _WINREG_
#define _WINREG_

#include <_mingw_unicode.h>
#include <winapifamily.h>

#ifdef __cplusplus
extern "C" {
#endif

#ifndef WINVER
#define WINVER 0x0502
#endif

#define RRF_RT_REG_NONE 0x00000001
#define RRF_RT_REG_SZ 0x00000002
#define RRF_RT_REG_EXPAND_SZ 0x00000004
#define RRF_RT_REG_BINARY 0x00000008
#define RRF_RT_REG_DWORD 0x00000010
#define RRF_RT_REG_MULTI_SZ 0x00000020
#define RRF_RT_REG_QWORD 0x00000040

#define RRF_RT_DWORD (RRF_RT_REG_BINARY | RRF_RT_REG_DWORD)
#define RRF_RT_QWORD (RRF_RT_REG_BINARY | RRF_RT_REG_QWORD)
#define RRF_RT_ANY 0x0000ffff

#if (_WIN32_WINNT >= 0x0A00)
#define RRF_SUBKEY_WOW6464KEY 0x00010000
#define RRF_SUBKEY_WOW6432KEY 0x00020000
#define RRF_WOW64_MASK 0x00030000
#endif

#define RRF_NOEXPAND 0x10000000
#define RRF_ZEROONFAILURE 0x20000000

#define REG_PROCESS_APPKEY 0x00000001

  typedef ACCESS_MASK REGSAM;
  typedef LONG LSTATUS;

#define HKEY_CLASSES_ROOT ((HKEY) (ULONG_PTR)((LONG)0x80000000))
#define HKEY_CURRENT_USER ((HKEY) (ULONG_PTR)((LONG)0x80000001))
#define HKEY_LOCAL_MACHINE ((HKEY) (ULONG_PTR)((LONG)0x80000002))
#define HKEY_USERS ((HKEY) (ULONG_PTR)((LONG)0x80000003))
#define HKEY_PERFORMANCE_DATA ((HKEY) (ULONG_PTR)((LONG)0x80000004))
#define HKEY_PERFORMANCE_TEXT ((HKEY) (ULONG_PTR)((LONG)0x80000050))
#define HKEY_PERFORMANCE_NLSTEXT ((HKEY) (ULONG_PTR)((LONG)0x80000060))
#if (WINVER >= 0x0400)
#define HKEY_CURRENT_CONFIG ((HKEY) (ULONG_PTR)((LONG)0x80000005))
#define HKEY_DYN_DATA ((HKEY) (ULONG_PTR)((LONG)0x80000006))
#define HKEY_CURRENT_USER_LOCAL_SETTINGS ((HKEY) (ULONG_PTR)((LONG)0x80000007))

#ifndef _PROVIDER_STRUCTS_DEFINED
#define _PROVIDER_STRUCTS_DEFINED

#define PROVIDER_KEEPS_VALUE_LENGTH 0x1
  struct val_context {
    int valuelen;
    LPVOID value_context;
    LPVOID val_buff_ptr;
  };

  typedef struct val_context *PVALCONTEXT;

  typedef struct pvalueA {
    LPSTR pv_valuename;
    int pv_valuelen;
    LPVOID pv_value_context;
    DWORD pv_type;
  }PVALUEA,*PPVALUEA;

  typedef struct pvalueW {
    LPWSTR pv_valuename;
    int pv_valuelen;
    LPVOID pv_value_context;
    DWORD pv_type;
  }PVALUEW,*PPVALUEW;

  __MINGW_TYPEDEF_AW(PVALUE)
  __MINGW_TYPEDEF_AW(PPVALUE)

  typedef DWORD __cdecl QUERYHANDLER(LPVOID keycontext,PVALCONTEXT val_list,DWORD num_vals,LPVOID outputbuffer,DWORD *total_outlen,DWORD input_blen);

  typedef QUERYHANDLER *PQUERYHANDLER;

  typedef struct provider_info {
    PQUERYHANDLER pi_R0_1val;
    PQUERYHANDLER pi_R0_allvals;
    PQUERYHANDLER pi_R3_1val;
    PQUERYHANDLER pi_R3_allvals;
    DWORD pi_flags;
    LPVOID pi_key_context;
  } REG_PROVIDER;

  typedef struct provider_info *PPROVIDER;

  typedef struct value_entA {
    LPSTR ve_valuename;
    DWORD ve_valuelen;
    DWORD_PTR ve_valueptr;
    DWORD ve_type;
  } VALENTA,*PVALENTA;

  typedef struct value_entW {
    LPWSTR ve_valuename;
    DWORD ve_valuelen;
    DWORD_PTR ve_valueptr;
    DWORD ve_type;
  } VALENTW,*PVALENTW;

  __MINGW_TYPEDEF_AW(VALENT)
  __MINGW_TYPEDEF_AW(PVALENT)
#endif
#endif

#define WIN31_CLASS NULL

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_DESKTOP)

#define REG_MUI_STRING_TRUNCATE 0x00000001

#if (WINVER >= 0x0400)
#define REG_SECURE_CONNECTION 1
#endif

#define RegConnectRegistry __MINGW_NAME_AW(RegConnectRegistry)
#define RegConnectRegistryEx __MINGW_NAME_AW(RegConnectRegistryEx)
#define RegCreateKey __MINGW_NAME_AW(RegCreateKey)
#define RegCreateKeyEx __MINGW_NAME_AW(RegCreateKeyEx)
#define RegDeleteKey __MINGW_NAME_AW(RegDeleteKey)
#define RegDeleteKeyEx __MINGW_NAME_AW(RegDeleteKeyEx)
#define RegDeleteValue __MINGW_NAME_AW(RegDeleteValue)
#define RegEnumKey __MINGW_NAME_AW(RegEnumKey)
#define RegEnumKeyEx __MINGW_NAME_AW(RegEnumKeyEx)
#define RegEnumValue __MINGW_NAME_AW(RegEnumValue)
#define RegLoadKey __MINGW_NAME_AW(RegLoadKey)
#define RegOpenKey __MINGW_NAME_AW(RegOpenKey)
#define RegOpenKeyEx __MINGW_NAME_AW(RegOpenKeyEx)
#define RegQueryInfoKey __MINGW_NAME_AW(RegQueryInfoKey)
#define RegQueryValue __MINGW_NAME_AW(RegQueryValue)
#define RegQueryMultipleValues __MINGW_NAME_AW(RegQueryMultipleValues)
#define RegQueryValueEx __MINGW_NAME_AW(RegQueryValueEx)
#define RegReplaceKey __MINGW_NAME_AW(RegReplaceKey)
#define RegRestoreKey __MINGW_NAME_AW(RegRestoreKey)
#define RegSaveKey __MINGW_NAME_AW(RegSaveKey)
#define RegSetValue __MINGW_NAME_AW(RegSetValue)
#define RegSetValueEx __MINGW_NAME_AW(RegSetValueEx)
#define RegUnLoadKey __MINGW_NAME_AW(RegUnLoadKey)
#define RegGetValue __MINGW_NAME_AW(RegGetValue)
#define InitiateSystemShutdown __MINGW_NAME_AW(InitiateSystemShutdown)
#define AbortSystemShutdown __MINGW_NAME_AW(AbortSystemShutdown)

  WINADVAPI LONG WINAPI RegCloseKey(HKEY hKey);
  WINADVAPI LONG WINAPI RegOverridePredefKey(HKEY hKey,HKEY hNewHKey);
  WINADVAPI LONG WINAPI RegOpenUserClassesRoot(HANDLE hToken,DWORD dwOptions,REGSAM samDesired,PHKEY phkResult);
  WINADVAPI LONG WINAPI RegOpenCurrentUser(REGSAM samDesired,PHKEY phkResult);
  WINADVAPI LONG WINAPI RegDisablePredefinedCache(void);
  WINADVAPI LONG WINAPI RegDisablePredefinedCacheEx(void);
  WINADVAPI LONG WINAPI RegConnectRegistryA(LPCSTR lpMachineName,HKEY hKey,PHKEY phkResult);
  WINADVAPI LONG WINAPI RegConnectRegistryW(LPCWSTR lpMachineName,HKEY hKey,PHKEY phkResult);
  WINADVAPI LONG WINAPI RegConnectRegistryExA(LPCSTR lpMachineName,HKEY hKey,ULONG Flags,PHKEY phkResult);
  WINADVAPI LONG WINAPI RegConnectRegistryExW(LPCWSTR lpMachineName,HKEY hKey,ULONG Flags,PHKEY phkResult);
  WINADVAPI LONG WINAPI RegCreateKeyA(HKEY hKey,LPCSTR lpSubKey,PHKEY phkResult);
  WINADVAPI LONG WINAPI RegCreateKeyW(HKEY hKey,LPCWSTR lpSubKey,PHKEY phkResult);
  WINADVAPI LONG WINAPI RegCreateKeyExA(HKEY hKey,LPCSTR lpSubKey,DWORD Reserved,LPSTR lpClass,DWORD dwOptions,REGSAM samDesired,LPSECURITY_ATTRIBUTES lpSecurityAttributes,PHKEY phkResult,LPDWORD lpdwDisposition);
  WINADVAPI LONG WINAPI RegCreateKeyExW(HKEY hKey,LPCWSTR lpSubKey,DWORD Reserved,LPWSTR lpClass,DWORD dwOptions,REGSAM samDesired,LPSECURITY_ATTRIBUTES lpSecurityAttributes,PHKEY phkResult,LPDWORD lpdwDisposition);
  WINADVAPI LONG WINAPI RegDeleteKeyA(HKEY hKey,LPCSTR lpSubKey);
  WINADVAPI LONG WINAPI RegDeleteKeyW(HKEY hKey,LPCWSTR lpSubKey);
  WINADVAPI LONG WINAPI RegDeleteKeyExA(HKEY hKey,LPCSTR lpSubKey,REGSAM samDesired,DWORD Reserved);
  WINADVAPI LONG WINAPI RegDeleteKeyExW(HKEY hKey,LPCWSTR lpSubKey,REGSAM samDesired,DWORD Reserved);
  WINADVAPI LONG WINAPI RegDisableReflectionKey(HKEY hBase);
  WINADVAPI LONG WINAPI RegEnableReflectionKey(HKEY hBase);
  WINADVAPI LONG WINAPI RegQueryReflectionKey(HKEY hBase,WINBOOL *bIsReflectionDisabled);
  WINADVAPI LONG WINAPI RegDeleteValueA(HKEY hKey,LPCSTR lpValueName);
  WINADVAPI LONG WINAPI RegDeleteValueW(HKEY hKey,LPCWSTR lpValueName);
  WINADVAPI LONG WINAPI RegEnumKeyA(HKEY hKey,DWORD dwIndex,LPSTR lpName,DWORD cchName);
  WINADVAPI LONG WINAPI RegEnumKeyW(HKEY hKey,DWORD dwIndex,LPWSTR lpName,DWORD cchName);
  WINADVAPI LONG WINAPI RegEnumKeyExA(HKEY hKey,DWORD dwIndex,LPSTR lpName,LPDWORD lpcchName,LPDWORD lpReserved,LPSTR lpClass,LPDWORD lpcchClass,PFILETIME lpftLastWriteTime);
  WINADVAPI LONG WINAPI RegEnumKeyExW(HKEY hKey,DWORD dwIndex,LPWSTR lpName,LPDWORD lpcchName,LPDWORD lpReserved,LPWSTR lpClass,LPDWORD lpcchClass,PFILETIME lpftLastWriteTime);
  WINADVAPI LONG WINAPI RegEnumValueA(HKEY hKey,DWORD dwIndex,LPSTR lpValueName,LPDWORD lpcchValueName,LPDWORD lpReserved,LPDWORD lpType,LPBYTE lpData,LPDWORD lpcbData);
  WINADVAPI LONG WINAPI RegEnumValueW(HKEY hKey,DWORD dwIndex,LPWSTR lpValueName,LPDWORD lpcchValueName,LPDWORD lpReserved,LPDWORD lpType,LPBYTE lpData,LPDWORD lpcbData);
  WINADVAPI LONG WINAPI RegFlushKey(HKEY hKey);
  WINADVAPI LONG WINAPI RegGetKeySecurity(HKEY hKey,SECURITY_INFORMATION SecurityInformation,PSECURITY_DESCRIPTOR pSecurityDescriptor,LPDWORD lpcbSecurityDescriptor);
  WINADVAPI LONG WINAPI RegLoadKeyA(HKEY hKey,LPCSTR lpSubKey,LPCSTR lpFile);
  WINADVAPI LONG WINAPI RegLoadKeyW(HKEY hKey,LPCWSTR lpSubKey,LPCWSTR lpFile);
  WINADVAPI LONG WINAPI RegNotifyChangeKeyValue(HKEY hKey,WINBOOL bWatchSubtree,DWORD dwNotifyFilter,HANDLE hEvent,WINBOOL fAsynchronous);
  WINADVAPI LONG WINAPI RegOpenKeyA(HKEY hKey,LPCSTR lpSubKey,PHKEY phkResult);
  WINADVAPI LONG WINAPI RegOpenKeyW(HKEY hKey,LPCWSTR lpSubKey,PHKEY phkResult);
  WINADVAPI LONG WINAPI RegOpenKeyExA(HKEY hKey,LPCSTR lpSubKey,DWORD ulOptions,REGSAM samDesired,PHKEY phkResult);
  WINADVAPI LONG WINAPI RegOpenKeyExW(HKEY hKey,LPCWSTR lpSubKey,DWORD ulOptions,REGSAM samDesired,PHKEY phkResult);
  WINADVAPI LONG WINAPI RegQueryInfoKeyA(HKEY hKey,LPSTR lpClass,LPDWORD lpcchClass,LPDWORD lpReserved,LPDWORD lpcSubKeys,LPDWORD lpcbMaxSubKeyLen,LPDWORD lpcbMaxClassLen,LPDWORD lpcValues,LPDWORD lpcbMaxValueNameLen,LPDWORD lpcbMaxValueLen,LPDWORD lpcbSecurityDescriptor,PFILETIME lpftLastWriteTime);
  WINADVAPI LONG WINAPI RegQueryInfoKeyW(HKEY hKey,LPWSTR lpClass,LPDWORD lpcchClass,LPDWORD lpReserved,LPDWORD lpcSubKeys,LPDWORD lpcbMaxSubKeyLen,LPDWORD lpcbMaxClassLen,LPDWORD lpcValues,LPDWORD lpcbMaxValueNameLen,LPDWORD lpcbMaxValueLen,LPDWORD lpcbSecurityDescriptor,PFILETIME lpftLastWriteTime);
  WINADVAPI LONG WINAPI RegQueryValueA(HKEY hKey,LPCSTR lpSubKey,LPSTR lpData,PLONG lpcbData);
  WINADVAPI LONG WINAPI RegQueryValueW(HKEY hKey,LPCWSTR lpSubKey,LPWSTR lpData,PLONG lpcbData);
  WINADVAPI LONG WINAPI RegQueryMultipleValuesA(HKEY hKey,PVALENTA val_list,DWORD num_vals,LPSTR lpValueBuf,LPDWORD ldwTotsize);
  WINADVAPI LONG WINAPI RegQueryMultipleValuesW(HKEY hKey,PVALENTW val_list,DWORD num_vals,LPWSTR lpValueBuf,LPDWORD ldwTotsize);
  WINADVAPI LONG WINAPI RegQueryValueExA(HKEY hKey,LPCSTR lpValueName,LPDWORD lpReserved,LPDWORD lpType,LPBYTE lpData,LPDWORD lpcbData);
  WINADVAPI LONG WINAPI RegQueryValueExW(HKEY hKey,LPCWSTR lpValueName,LPDWORD lpReserved,LPDWORD lpType,LPBYTE lpData,LPDWORD lpcbData);
  WINADVAPI LONG WINAPI RegReplaceKeyA(HKEY hKey,LPCSTR lpSubKey,LPCSTR lpNewFile,LPCSTR lpOldFile);
  WINADVAPI LONG WINAPI RegReplaceKeyW(HKEY hKey,LPCWSTR lpSubKey,LPCWSTR lpNewFile,LPCWSTR lpOldFile);
  WINADVAPI LONG WINAPI RegRestoreKeyA(HKEY hKey,LPCSTR lpFile,DWORD dwFlags);
  WINADVAPI LONG WINAPI RegRestoreKeyW(HKEY hKey,LPCWSTR lpFile,DWORD dwFlags);
  WINADVAPI LONG WINAPI RegSaveKeyA(HKEY hKey,LPCSTR lpFile,LPSECURITY_ATTRIBUTES lpSecurityAttributes);
  WINADVAPI LONG WINAPI RegSaveKeyW(HKEY hKey,LPCWSTR lpFile,LPSECURITY_ATTRIBUTES lpSecurityAttributes);
  WINADVAPI LONG WINAPI RegSetKeySecurity(HKEY hKey,SECURITY_INFORMATION SecurityInformation,PSECURITY_DESCRIPTOR pSecurityDescriptor);
  WINADVAPI LONG WINAPI RegSetValueA(HKEY hKey,LPCSTR lpSubKey,DWORD dwType,LPCSTR lpData,DWORD cbData);
  WINADVAPI LONG WINAPI RegSetValueW(HKEY hKey,LPCWSTR lpSubKey,DWORD dwType,LPCWSTR lpData,DWORD cbData);
  WINADVAPI LONG WINAPI RegSetValueExA(HKEY hKey,LPCSTR lpValueName,DWORD Reserved,DWORD dwType,CONST BYTE *lpData,DWORD cbData);
  WINADVAPI LONG WINAPI RegSetValueExW(HKEY hKey,LPCWSTR lpValueName,DWORD Reserved,DWORD dwType,CONST BYTE *lpData,DWORD cbData);
  WINADVAPI LONG WINAPI RegUnLoadKeyA(HKEY hKey,LPCSTR lpSubKey);
  WINADVAPI LONG WINAPI RegUnLoadKeyW(HKEY hKey,LPCWSTR lpSubKey);
  WINADVAPI LONG WINAPI RegGetValueA(HKEY hkey,LPCSTR lpSubKey,LPCSTR lpValue,DWORD dwFlags,LPDWORD pdwType,PVOID pvData,LPDWORD pcbData);
  WINADVAPI LONG WINAPI RegGetValueW(HKEY hkey,LPCWSTR lpSubKey,LPCWSTR lpValue,DWORD dwFlags,LPDWORD pdwType,PVOID pvData,LPDWORD pcbData);
  WINADVAPI WINBOOL WINAPI InitiateSystemShutdownA(LPSTR lpMachineName,LPSTR lpMessage,DWORD dwTimeout,WINBOOL bForceAppsClosed,WINBOOL bRebootAfterShutdown);
  WINADVAPI WINBOOL WINAPI InitiateSystemShutdownW(LPWSTR lpMachineName,LPWSTR lpMessage,DWORD dwTimeout,WINBOOL bForceAppsClosed,WINBOOL bRebootAfterShutdown);
  WINADVAPI WINBOOL WINAPI AbortSystemShutdownA(LPSTR lpMachineName);
  WINADVAPI WINBOOL WINAPI AbortSystemShutdownW(LPWSTR lpMachineName);

#include <reason.h>

#define REASON_SWINSTALL SHTDN_REASON_MAJOR_SOFTWARE|SHTDN_REASON_MINOR_INSTALLATION
#define REASON_HWINSTALL SHTDN_REASON_MAJOR_HARDWARE|SHTDN_REASON_MINOR_INSTALLATION
#define REASON_SERVICEHANG SHTDN_REASON_MAJOR_SOFTWARE|SHTDN_REASON_MINOR_HUNG
#define REASON_UNSTABLE SHTDN_REASON_MAJOR_SYSTEM|SHTDN_REASON_MINOR_UNSTABLE
#define REASON_SWHWRECONF SHTDN_REASON_MAJOR_SOFTWARE|SHTDN_REASON_MINOR_RECONFIG
#define REASON_OTHER SHTDN_REASON_MAJOR_OTHER|SHTDN_REASON_MINOR_OTHER
#define REASON_UNKNOWN SHTDN_REASON_UNKNOWN
#define REASON_LEGACY_API SHTDN_REASON_LEGACY_API
#define REASON_PLANNED_FLAG SHTDN_REASON_FLAG_PLANNED

#define MAX_SHUTDOWN_TIMEOUT (10*365*24*60*60)

#define InitiateSystemShutdownEx __MINGW_NAME_AW(InitiateSystemShutdownEx)
#define RegSaveKeyEx __MINGW_NAME_AW(RegSaveKeyEx)

  WINADVAPI WINBOOL WINAPI InitiateSystemShutdownExA(LPSTR lpMachineName,LPSTR lpMessage,DWORD dwTimeout,WINBOOL bForceAppsClosed,WINBOOL bRebootAfterShutdown,DWORD dwReason);
  WINADVAPI WINBOOL WINAPI InitiateSystemShutdownExW(LPWSTR lpMachineName,LPWSTR lpMessage,DWORD dwTimeout,WINBOOL bForceAppsClosed,WINBOOL bRebootAfterShutdown,DWORD dwReason);
  WINADVAPI LONG WINAPI RegSaveKeyExA(HKEY hKey,LPCSTR lpFile,LPSECURITY_ATTRIBUTES lpSecurityAttributes,DWORD Flags);
  WINADVAPI LONG WINAPI RegSaveKeyExW(HKEY hKey,LPCWSTR lpFile,LPSECURITY_ATTRIBUTES lpSecurityAttributes,DWORD Flags);
  WINADVAPI LONG WINAPI Wow64Win32ApiEntry (DWORD dwFuncNumber,DWORD dwFlag,DWORD dwRes);

#if (_WIN32_WINNT >= 0x0600)

#define RegCopyTree __MINGW_NAME_AW(RegCopyTree)
WINADVAPI LONG WINAPI RegCopyTreeA(
  HKEY hKeySrc,
  LPCSTR lpSubKey,
  HKEY hKeyDest
);

WINADVAPI LONG WINAPI RegCopyTreeW(
  HKEY hKeySrc,
  LPCWSTR lpSubKey,
  HKEY hKeyDest
);

#define RegCreateKeyTransacted __MINGW_NAME_AW(RegCreateKeyTransacted)
WINADVAPI LONG WINAPI RegCreateKeyTransactedA(
  HKEY hKey,
  LPCSTR lpSubKey,
  DWORD Reserved,
  LPSTR lpClass,
  DWORD dwOptions,
  REGSAM samDesired,
  const LPSECURITY_ATTRIBUTES lpSecurityAttributes,
  PHKEY phkResult,
  LPDWORD lpdwDisposition,
  HANDLE hTransaction,
  PVOID pExtendedParemeter
);

WINADVAPI LONG WINAPI RegCreateKeyTransactedW(
  HKEY hKey,
  LPCWSTR lpSubKey,
  DWORD Reserved,
  LPWSTR lpClass,
  DWORD dwOptions,
  REGSAM samDesired,
  const LPSECURITY_ATTRIBUTES lpSecurityAttributes,
  PHKEY phkResult,
  LPDWORD lpdwDisposition,
  HANDLE hTransaction,
  PVOID pExtendedParemeter
);

#define RegDeleteKeyTransacted __MINGW_NAME_AW(RegDeleteKeyTransacted)
WINADVAPI LONG WINAPI RegDeleteKeyTransactedA(
  HKEY hKey,
  LPCSTR lpSubKey,
  REGSAM samDesired,
  DWORD Reserved,
  HANDLE hTransaction,
  PVOID pExtendedParameter
);

WINADVAPI LONG WINAPI RegDeleteKeyTransactedW(
  HKEY hKey,
  LPCWSTR lpSubKey,
  REGSAM samDesired,
  DWORD Reserved,
  HANDLE hTransaction,
  PVOID pExtendedParameter
);

#define RegDeleteKeyValue __MINGW_NAME_AW(RegDeleteKeyValue)
WINADVAPI LONG WINAPI RegDeleteKeyValueA(
  HKEY hKey,
  LPCSTR lpSubKey,
  LPCSTR lpValueName
);

WINADVAPI LONG WINAPI RegDeleteKeyValueW(
  HKEY hKey,
  LPCWSTR lpSubKey,
  LPCWSTR lpValueName
);

#define RegDeleteTree __MINGW_NAME_AW(RegDeleteTree)
WINADVAPI LONG WINAPI RegDeleteTreeA(
  HKEY hKey,
  LPCSTR lpSubKey
);

WINADVAPI LONG WINAPI RegDeleteTreeW(
  HKEY hKey,
  LPCWSTR lpSubKey
);

WINADVAPI LONG WINAPI RegLoadAppKeyA(
  LPCSTR lpFile,
  PHKEY phkResult,
  REGSAM samDesired,
  DWORD dwOptions,
  DWORD Reserved
);

WINADVAPI LONG WINAPI RegLoadAppKeyW(
  LPCWSTR lpFile,
  PHKEY phkResult,
  REGSAM samDesired,
  DWORD dwOptions,
  DWORD Reserved
);

#define RegLoadAppKey __MINGW_NAME_AW(RegLoadAppKey)

WINADVAPI LONG WINAPI RegLoadMUIStringA(HKEY hKey, LPCSTR pszValue, LPSTR pszOutBuf, DWORD cbOutBuf, LPDWORD pcbData, DWORD Flags, LPCSTR pszDirectory);
WINADVAPI LONG WINAPI RegLoadMUIStringW(HKEY hKey, LPCWSTR pszValue, LPWSTR pszOutBuf, DWORD cbOutBuf, LPDWORD pcbData, DWORD Flags, LPCWSTR pszDirectory);

#define RegLoadMUIString __MINGW_NAME_AW(RegLoadMUIString)

WINADVAPI LONG WINAPI RegOpenKeyTransactedA(
  HKEY hKey,
  LPCSTR lpSubKey,
  DWORD ulOptions,
  REGSAM samDesired,
  PHKEY phkResult,
  HANDLE hTransaction,
  PVOID pExtendedParameter
);

WINADVAPI LONG WINAPI RegOpenKeyTransactedW(
  HKEY hKey,
  LPCWSTR lpSubKey,
  DWORD ulOptions,
  REGSAM samDesired,
  PHKEY phkResult,
  HANDLE hTransaction,
  PVOID pExtendedParameter
);

WINADVAPI LONG WINAPI RegRenameKey(
  HKEY hKey,
  LPCWSTR lpSubKeyName,
  LPCWSTR lpNewKeyName);

#define RegOpenKeyTransacted __MINGW_NAME_AW(RegOpenKeyTransacted)

WINADVAPI LONG WINAPI RegSetKeyValueA(
  HKEY hKey,
  LPCSTR lpSubKey,
  LPCSTR lpValueName,
  DWORD dwType,
  LPCVOID lpData,
  DWORD cbData
);

WINADVAPI LONG WINAPI RegSetKeyValueW(
  HKEY hKey,
  LPCWSTR lpSubKey,
  LPCWSTR lpValueName,
  DWORD dwType,
  LPCVOID lpData,
  DWORD cbData
);
#define RegSetKeyValue __MINGW_NAME_AW(RegSetKeyValue)

#define SHUTDOWN_FORCE_OTHERS 0x00000001
#define SHUTDOWN_FORCE_SELF 0x00000002
#define SHUTDOWN_RESTART 0x00000004
#define SHUTDOWN_POWEROFF 0x00000008
#define SHUTDOWN_NOREBOOT 0x00000010
#define SHUTDOWN_GRACE_OVERRIDE 0x00000020
#define SHUTDOWN_INSTALL_UPDATES 0x00000040
#define SHUTDOWN_RESTARTAPPS 0x00000080
#define SHUTDOWN_SKIP_SVC_PRESHUTDOWN 0x00000100
#define SHUTDOWN_HYBRID 0x00000200
#define SHUTDOWN_RESTART_BOOTOPTIONS 0x00000400
#define SHUTDOWN_SOFT_REBOOT 0x00000800
#define SHUTDOWN_MOBILE_UI 0x00001000
#define SHUTDOWN_ARSO 0x00002000

WINADVAPI DWORD WINAPI InitiateShutdownA(
  LPSTR lpMachineName,
  LPSTR lpMessage,
  DWORD dwGracePeriod,
  DWORD dwShutdownFlags,
  DWORD dwReason
);

WINADVAPI DWORD WINAPI InitiateShutdownW(
  LPWSTR lpMachineName,
  LPWSTR lpMessage,
  DWORD dwGracePeriod,
  DWORD dwShutdownFlags,
  DWORD dwReason
);

#define InitiateShutdown __MINGW_NAME_AW(InitiateShutdown)

WINADVAPI DWORD WINAPI CheckForHiberboot(
  PBOOLEAN pHiberboot,
  BOOLEAN bClearFlag
);

#endif /* (_WIN32_WINNT >= 0x0600) */

#endif /* WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_DESKTOP) */

#ifdef __cplusplus
}
#endif
#endif

/**
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER within this package.
 */

#ifndef _INC_USERENV
#define _INC_USERENV

#include <winapifamily.h>

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_DESKTOP)

#include <_mingw_unicode.h>
#include <wbemcli.h>

#if !defined (_USERENV_)
#define USERENVAPI DECLSPEC_IMPORT
#else
#define USERENVAPI
#endif

#ifdef __cplusplus
extern "C" {
#endif

#include <profinfo.h>

#define PI_NOUI 0x00000001
#define PI_APPLYPOLICY 0x00000002

#define PT_TEMPORARY 0x00000001
#define PT_ROAMING 0x00000002
#define PT_MANDATORY 0x00000004

#define RP_FORCE 1
#define RP_SYNC 2

#define GPC_BLOCK_POLICY 0x00000001

#define GPO_FLAG_DISABLE 0x00000001
#define GPO_FLAG_FORCE 0x00000002

#define LoadUserProfile __MINGW_NAME_AW(LoadUserProfile)
#define GetProfilesDirectory __MINGW_NAME_AW(GetProfilesDirectory)
#define DeleteProfile __MINGW_NAME_AW(DeleteProfile)
#define GetDefaultUserProfileDirectory __MINGW_NAME_AW(GetDefaultUserProfileDirectory)
#define GetAllUsersProfileDirectory __MINGW_NAME_AW(GetAllUsersProfileDirectory)
#define GetUserProfileDirectory __MINGW_NAME_AW(GetUserProfileDirectory)
#define ExpandEnvironmentStringsForUser __MINGW_NAME_AW(ExpandEnvironmentStringsForUser)

  USERENVAPI WINBOOL WINAPI LoadUserProfileA (HANDLE hToken, LPPROFILEINFOA lpProfileInfo);
  USERENVAPI WINBOOL WINAPI LoadUserProfileW (HANDLE hToken, LPPROFILEINFOW lpProfileInfo);
  USERENVAPI WINBOOL WINAPI UnloadUserProfile (HANDLE hToken, HANDLE hProfile);
  USERENVAPI WINBOOL WINAPI GetProfilesDirectoryA (LPSTR lpProfileDir, LPDWORD lpcchSize);
  USERENVAPI WINBOOL WINAPI GetProfilesDirectoryW (LPWSTR lpProfileDir, LPDWORD lpcchSize);
  USERENVAPI WINBOOL WINAPI GetProfileType (DWORD *dwFlags);
  USERENVAPI WINBOOL WINAPI DeleteProfileA (LPCSTR lpSidString, LPCSTR lpProfilePath, LPCSTR lpComputerName);
  USERENVAPI WINBOOL WINAPI DeleteProfileW (LPCWSTR lpSidString, LPCWSTR lpProfilePath, LPCWSTR lpComputerName);
  USERENVAPI WINBOOL WINAPI GetDefaultUserProfileDirectoryA (LPSTR lpProfileDir, LPDWORD lpcchSize);
  USERENVAPI WINBOOL WINAPI GetDefaultUserProfileDirectoryW (LPWSTR lpProfileDir, LPDWORD lpcchSize);
  USERENVAPI WINBOOL WINAPI GetAllUsersProfileDirectoryA (LPSTR lpProfileDir, LPDWORD lpcchSize);
  USERENVAPI WINBOOL WINAPI GetAllUsersProfileDirectoryW (LPWSTR lpProfileDir, LPDWORD lpcchSize);
  USERENVAPI WINBOOL WINAPI GetUserProfileDirectoryA (HANDLE hToken, LPSTR lpProfileDir, LPDWORD lpcchSize);
  USERENVAPI WINBOOL WINAPI GetUserProfileDirectoryW (HANDLE hToken, LPWSTR lpProfileDir, LPDWORD lpcchSize);
  WINBOOL WINAPI CreateEnvironmentBlock (LPVOID *lpEnvironment, HANDLE hToken, WINBOOL bInherit);
  WINBOOL WINAPI DestroyEnvironmentBlock (LPVOID lpEnvironment);
  USERENVAPI WINBOOL WINAPI ExpandEnvironmentStringsForUserA (HANDLE hToken, LPCSTR lpSrc, LPSTR lpDest, DWORD dwSize);
  USERENVAPI WINBOOL WINAPI ExpandEnvironmentStringsForUserW (HANDLE hToken, LPCWSTR lpSrc, LPWSTR lpDest, DWORD dwSize);
  USERENVAPI WINBOOL WINAPI RefreshPolicy (WINBOOL bMachine);
  USERENVAPI WINBOOL WINAPI RefreshPolicyEx (WINBOOL bMachine, DWORD dwOptions);
  USERENVAPI HANDLE WINAPI EnterCriticalPolicySection (WINBOOL bMachine);
  USERENVAPI WINBOOL WINAPI LeaveCriticalPolicySection (HANDLE hSection);
  USERENVAPI WINBOOL WINAPI RegisterGPNotification (HANDLE hEvent, WINBOOL bMachine);
  USERENVAPI WINBOOL WINAPI UnregisterGPNotification (HANDLE hEvent);
#if WINVER >= 0x0600
  USERENVAPI HRESULT WINAPI CreateProfile (LPCWSTR pszUserSid, LPCWSTR pszUserName, LPWSTR pszProfilePath, DWORD cchProfilePath);
#endif

  typedef enum _GPO_LINK {
    GPLinkUnknown = 0,
    GPLinkMachine,
    GPLinkSite,
    GPLinkDomain,
    GPLinkOrganizationalUnit
  } GPO_LINK, *PGPO_LINK;

  typedef struct _GROUP_POLICY_OBJECTA {
    DWORD dwOptions;
    DWORD dwVersion;
    LPSTR lpDSPath;
    LPSTR lpFileSysPath;
    LPSTR lpDisplayName;
    CHAR szGPOName[50];
    GPO_LINK GPOLink;
    LPARAM lParam;
    struct _GROUP_POLICY_OBJECTA *pNext;
    struct _GROUP_POLICY_OBJECTA *pPrev;
    LPSTR lpExtensions;
    LPARAM lParam2;
    LPSTR lpLink;
  } GROUP_POLICY_OBJECTA, *PGROUP_POLICY_OBJECTA;

  typedef struct _GROUP_POLICY_OBJECTW {
    DWORD dwOptions;
    DWORD dwVersion;
    LPWSTR lpDSPath;
    LPWSTR lpFileSysPath;
    LPWSTR lpDisplayName;
    WCHAR szGPOName[50];
    GPO_LINK GPOLink;
    LPARAM lParam;
    struct _GROUP_POLICY_OBJECTW *pNext;
    struct _GROUP_POLICY_OBJECTW *pPrev;
    LPWSTR lpExtensions;
    LPARAM lParam2;
    LPWSTR lpLink;
  } GROUP_POLICY_OBJECTW,*PGROUP_POLICY_OBJECTW;

   __MINGW_TYPEDEF_AW(GROUP_POLICY_OBJECT)
   __MINGW_TYPEDEF_AW(PGROUP_POLICY_OBJECT)

#define GPO_LIST_FLAG_MACHINE 0x00000001
#define GPO_LIST_FLAG_SITEONLY 0x00000002
#define GPO_LIST_FLAG_NO_WMIFILTERS 0x00000004
#define GPO_LIST_FLAG_NO_SECURITYFILTERS 0x00000008

#define GetGPOList __MINGW_NAME_AW(GetGPOList)
#define FreeGPOList __MINGW_NAME_AW(FreeGPOList)
#define GetAppliedGPOList __MINGW_NAME_AW(GetAppliedGPOList)

  USERENVAPI WINBOOL WINAPI GetGPOListA (HANDLE hToken, LPCSTR lpName, LPCSTR lpHostName, LPCSTR lpComputerName, DWORD dwFlags, PGROUP_POLICY_OBJECTA *pGPOList);
  USERENVAPI WINBOOL WINAPI GetGPOListW (HANDLE hToken, LPCWSTR lpName, LPCWSTR lpHostName, LPCWSTR lpComputerName, DWORD dwFlags, PGROUP_POLICY_OBJECTW *pGPOList);
  USERENVAPI WINBOOL WINAPI FreeGPOListA (PGROUP_POLICY_OBJECTA pGPOList);
  USERENVAPI WINBOOL WINAPI FreeGPOListW (PGROUP_POLICY_OBJECTW pGPOList);
  USERENVAPI DWORD WINAPI GetAppliedGPOListA (DWORD dwFlags, LPCSTR pMachineName, PSID pSidUser, GUID *pGuidExtension, PGROUP_POLICY_OBJECTA *ppGPOList);
  USERENVAPI DWORD WINAPI GetAppliedGPOListW (DWORD dwFlags, LPCWSTR pMachineName, PSID pSidUser, GUID *pGuidExtension, PGROUP_POLICY_OBJECTW *ppGPOList);

#define GP_DLLNAME TEXT ("DllName")
#define GP_ENABLEASYNCHRONOUSPROCESSING TEXT ("EnableAsynchronousProcessing")
#define GP_MAXNOGPOLISTCHANGESINTERVAL TEXT ("MaxNoGPOListChangesInterval")
#define GP_NOBACKGROUNDPOLICY TEXT ("NoBackgroundPolicy")
#define GP_NOGPOLISTCHANGES TEXT ("NoGPOListChanges")
#define GP_NOMACHINEPOLICY TEXT ("NoMachinePolicy")
#define GP_NOSLOWLINK TEXT ("NoSlowLink")
#define GP_NOTIFYLINKTRANSITION TEXT ("NotifyLinkTransition")
#define GP_NOUSERPOLICY TEXT ("NoUserPolicy")
#define GP_PERUSERLOCALSETTINGS TEXT ("PerUserLocalSettings")
#define GP_PROCESSGROUPPOLICY TEXT ("ProcessGroupPolicy")
#define GP_REQUIRESSUCCESSFULREGISTRY TEXT ("RequiresSuccessfulRegistry")

#define GPO_INFO_FLAG_MACHINE 0x00000001
#define GPO_INFO_FLAG_BACKGROUND 0x00000010
#define GPO_INFO_FLAG_SLOWLINK 0x00000020
#define GPO_INFO_FLAG_VERBOSE 0x00000040
#define GPO_INFO_FLAG_NOCHANGES 0x00000080
#define GPO_INFO_FLAG_LINKTRANSITION 0x00000100
#define GPO_INFO_FLAG_LOGRSOP_TRANSITION 0x00000200
#define GPO_INFO_FLAG_FORCED_REFRESH 0x00000400
#define GPO_INFO_FLAG_SAFEMODE_BOOT 0x00000800
#define GPO_INFO_FLAG_ASYNC_FOREGROUND 0x00001000

  typedef UINT_PTR ASYNCCOMPLETIONHANDLE;
  typedef DWORD (*PFNSTATUSMESSAGECALLBACK) (WINBOOL bVerbose, LPWSTR lpMessage);
  typedef DWORD (*PFNPROCESSGROUPPOLICY) (DWORD dwFlags, HANDLE hToken, HKEY hKeyRoot, PGROUP_POLICY_OBJECT pDeletedGPOList, PGROUP_POLICY_OBJECT pChangedGPOList, ASYNCCOMPLETIONHANDLE pHandle, WINBOOL *pbAbort, PFNSTATUSMESSAGECALLBACK pStatusCallback);
  typedef DWORD (*PFNPROCESSGROUPPOLICYEX) (DWORD dwFlags, HANDLE hToken, HKEY hKeyRoot, PGROUP_POLICY_OBJECT pDeletedGPOList, PGROUP_POLICY_OBJECT pChangedGPOList, ASYNCCOMPLETIONHANDLE pHandle, WINBOOL *pbAbort, PFNSTATUSMESSAGECALLBACK pStatusCallback, IWbemServices *pWbemServices, HRESULT *pRsopStatus);
  typedef PVOID PRSOPTOKEN;

  typedef struct _RSOP_TARGET {
    WCHAR *pwszAccountName;
    WCHAR *pwszNewSOM;
    SAFEARRAY *psaSecurityGroups;
    PRSOPTOKEN pRsopToken;
    PGROUP_POLICY_OBJECT pGPOList;
    IWbemServices *pWbemServices;
  } RSOP_TARGET, *PRSOP_TARGET;

  typedef DWORD (*PFNGENERATEGROUPPOLICY) (DWORD dwFlags, WINBOOL *pbAbort, WCHAR *pwszSite, PRSOP_TARGET pComputerTarget, PRSOP_TARGET pUserTarget);

#define REGISTRY_EXTENSION_GUID { 0x35378eac, 0x683f, 0x11d2, 0xa8, 0x9a, 0x00, 0xc0, 0x4f, 0xbb, 0xcf, 0xa2 }

#define GROUP_POLICY_TRIGGER_EVENT_PROVIDER_GUID { 0xbd2f4252, 0x5e1e, 0x49fc, 0x9a, 0x30, 0xf3, 0x97, 0x8a, 0xd8, 0x9e, 0xe2 }
#define MACHINE_POLICY_PRESENT_TRIGGER_GUID { 0x659fcae6, 0x5bdb, 0x4da9, 0xb1, 0xff, 0xca, 0x2a, 0x17, 0x8d, 0x46, 0xe0 }
#define USER_POLICY_PRESENT_TRIGGER_GUID { 0x54fb46c8, 0xf089, 0x464c, 0xb1, 0xfd, 0x59, 0xd1, 0xb6, 0x2c, 0x3b, 0x50 }

  typedef GUID *REFGPEXTENSIONID;

  USERENVAPI DWORD WINAPI ProcessGroupPolicyCompleted (REFGPEXTENSIONID extensionId, ASYNCCOMPLETIONHANDLE pAsyncHandle, DWORD dwStatus);
  USERENVAPI DWORD WINAPI ProcessGroupPolicyCompletedEx (REFGPEXTENSIONID extensionId, ASYNCCOMPLETIONHANDLE pAsyncHandle, DWORD dwStatus, HRESULT RsopStatus);
  USERENVAPI HRESULT WINAPI RsopAccessCheckByType (PSECURITY_DESCRIPTOR pSecurityDescriptor, PSID pPrincipalSelfSid, PRSOPTOKEN pRsopToken, DWORD dwDesiredAccessMask, POBJECT_TYPE_LIST pObjectTypeList, DWORD ObjectTypeListLength, PGENERIC_MAPPING pGenericMapping, PPRIVILEGE_SET pPrivilegeSet, LPDWORD pdwPrivilegeSetLength, LPDWORD pdwGrantedAccessMask, LPBOOL pbAccessStatus);
  USERENVAPI HRESULT WINAPI RsopFileAccessCheck (LPWSTR pszFileName, PRSOPTOKEN pRsopToken, DWORD dwDesiredAccessMask, LPDWORD pdwGrantedAccessMask, LPBOOL pbAccessStatus);

  typedef enum _SETTINGSTATUS {
    RSOPUnspecified = 0,
    RSOPApplied,
    RSOPIgnored,
    RSOPFailed,
    RSOPSubsettingFailed
  } SETTINGSTATUS;

  typedef struct _POLICYSETTINGSTATUSINFO {
    LPWSTR szKey;
    LPWSTR szEventSource;
    LPWSTR szEventLogName;
    DWORD dwEventID;
    DWORD dwErrorCode;
    SETTINGSTATUS status;
    SYSTEMTIME timeLogged;
  } POLICYSETTINGSTATUSINFO,*LPPOLICYSETTINGSTATUSINFO;

  USERENVAPI HRESULT WINAPI RsopSetPolicySettingStatus (DWORD dwFlags, IWbemServices *pServices, IWbemClassObject *pSettingInstance, DWORD nInfo, POLICYSETTINGSTATUSINFO *pStatus);
  USERENVAPI HRESULT WINAPI RsopResetPolicySettingStatus (DWORD dwFlags, IWbemServices *pServices, IWbemClassObject *pSettingInstance);

#define FLAG_NO_GPO_FILTER 0x80000000
#define FLAG_NO_CSE_INVOKE 0x40000000
#define FLAG_ASSUME_SLOW_LINK 0x20000000
#define FLAG_LOOPBACK_MERGE 0x10000000
#define FLAG_LOOPBACK_REPLACE 0x08000000
#define FLAG_ASSUME_USER_WQLFILTER_TRUE 0x04000000
#define FLAG_ASSUME_COMP_WQLFILTER_TRUE 0x02000000
#define FLAG_PLANNING_MODE 0x01000000

#define FLAG_NO_USER 0x00000001
#define FLAG_NO_COMPUTER 0x00000002
#define FLAG_FORCE_CREATENAMESPACE 0x00000004

#define RSOP_USER_ACCESS_DENIED 0x00000001
#define RSOP_COMPUTER_ACCESS_DENIED 0x00000002
#define RSOP_TEMPNAMESPACE_EXISTS 0x00000004

#if WINVER >= 0x0600
  USERENVAPI DWORD WINAPI GenerateGPNotification (WINBOOL bMachine, LPCWSTR lpwszMgmtProduct, DWORD dwMgmtProductOptions);
#endif
#if WINVER >= 0x0602
  USERENVAPI HRESULT WINAPI CreateAppContainerProfile (PCWSTR pszAppContainerName, PCWSTR pszDisplayName, PCWSTR pszDescription, PSID_AND_ATTRIBUTES pCapabilities, DWORD dwCapabilityCount, PSID *ppSidAppContainerSid);
  USERENVAPI HRESULT WINAPI DeleteAppContainerProfile (PCWSTR pszAppContainerName);
  USERENVAPI HRESULT WINAPI GetAppContainerRegistryLocation (REGSAM desiredAccess, PHKEY phAppContainerKey);
  USERENVAPI HRESULT WINAPI GetAppContainerFolderPath (PCWSTR pszAppContainerSid, PWSTR *ppszPath);
  USERENVAPI HRESULT WINAPI DeriveAppContainerSidFromAppContainerName (PCWSTR pszAppContainerName, PSID *ppsidAppContainerSid);
#endif

#ifdef __cplusplus
}
#endif

#endif

#endif

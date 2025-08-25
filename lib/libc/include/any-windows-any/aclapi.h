/**
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER within this package.
 */
#ifndef __ACCESS_CONTROL_API__
#define __ACCESS_CONTROL_API__

#include <winapifamily.h>

#include <_mingw_unicode.h>
#include <windows.h>
#include <accctrl.h>

#ifdef __cplusplus
extern "C" {
#endif

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_DESKTOP)

  typedef VOID (*FN_PROGRESS) (LPWSTR pObjectName, DWORD Status, PPROG_INVOKE_SETTING pInvokeSetting, PVOID Args, WINBOOL SecuritySet);

#define GetEffectiveRightsFromAcl __MINGW_NAME_AW(GetEffectiveRightsFromAcl)
#define GetAuditedPermissionsFromAcl __MINGW_NAME_AW(GetAuditedPermissionsFromAcl)
#define GetInheritanceSource __MINGW_NAME_AW(GetInheritanceSource)
#define TreeResetNamedSecurityInfo __MINGW_NAME_AW(TreeResetNamedSecurityInfo)
#define BuildSecurityDescriptor __MINGW_NAME_AW(BuildSecurityDescriptor)
#define LookupSecurityDescriptorParts __MINGW_NAME_AW(LookupSecurityDescriptorParts)
#define BuildExplicitAccessWithName __MINGW_NAME_AW(BuildExplicitAccessWithName)
#define BuildImpersonateExplicitAccessWithName __MINGW_NAME_AW(BuildImpersonateExplicitAccessWithName)
#define BuildTrusteeWithName __MINGW_NAME_AW(BuildTrusteeWithName)
#define BuildImpersonateTrustee __MINGW_NAME_AW(BuildImpersonateTrustee)
#define BuildTrusteeWithSid __MINGW_NAME_AW(BuildTrusteeWithSid)
#define BuildTrusteeWithObjectsAndSid __MINGW_NAME_AW(BuildTrusteeWithObjectsAndSid)
#define BuildTrusteeWithObjectsAndName __MINGW_NAME_AW(BuildTrusteeWithObjectsAndName)
#define GetTrusteeName __MINGW_NAME_AW(GetTrusteeName)
#define GetTrusteeType __MINGW_NAME_AW(GetTrusteeType)
#define GetTrusteeForm __MINGW_NAME_AW(GetTrusteeForm)
#define GetMultipleTrusteeOperation __MINGW_NAME_AW(GetMultipleTrusteeOperation)
#define GetMultipleTrustee __MINGW_NAME_AW(GetMultipleTrustee)
#if NTDDI_VERSION >= 0x06000000
#define TreeSetNamedSecurityInfo __MINGW_NAME_AW(TreeSetNamedSecurityInfo)
#endif

#define AccProvInit(err)

  WINADVAPI DWORD WINAPI GetEffectiveRightsFromAclA (PACL pacl, PTRUSTEE_A pTrustee, PACCESS_MASK pAccessRights);
  WINADVAPI DWORD WINAPI GetEffectiveRightsFromAclW (PACL pacl, PTRUSTEE_W pTrustee, PACCESS_MASK pAccessRights);
  WINADVAPI DWORD WINAPI GetAuditedPermissionsFromAclA (PACL pacl, PTRUSTEE_A pTrustee, PACCESS_MASK pSuccessfulAuditedRights, PACCESS_MASK pFailedAuditRights);
  WINADVAPI DWORD WINAPI GetAuditedPermissionsFromAclW (PACL pacl, PTRUSTEE_W pTrustee, PACCESS_MASK pSuccessfulAuditedRights, PACCESS_MASK pFailedAuditRights);
  WINADVAPI DWORD WINAPI GetInheritanceSourceA (LPSTR pObjectName, SE_OBJECT_TYPE ObjectType, SECURITY_INFORMATION SecurityInfo, WINBOOL Container, GUID **pObjectClassGuids, DWORD GuidCount, PACL pAcl, PFN_OBJECT_MGR_FUNCTS pfnArray, PGENERIC_MAPPING pGenericMapping, PINHERITED_FROMA pInheritArray);
  WINADVAPI DWORD WINAPI GetInheritanceSourceW (LPWSTR pObjectName, SE_OBJECT_TYPE ObjectType, SECURITY_INFORMATION SecurityInfo, WINBOOL Container, GUID **pObjectClassGuids, DWORD GuidCount, PACL pAcl, PFN_OBJECT_MGR_FUNCTS pfnArray, PGENERIC_MAPPING pGenericMapping, PINHERITED_FROMW pInheritArray);
  WINADVAPI DWORD WINAPI FreeInheritedFromArray (PINHERITED_FROMW pInheritArray, USHORT AceCnt, PFN_OBJECT_MGR_FUNCTS pfnArray);
  WINADVAPI DWORD WINAPI TreeResetNamedSecurityInfoA (LPSTR pObjectName, SE_OBJECT_TYPE ObjectType, SECURITY_INFORMATION SecurityInfo, PSID pOwner, PSID pGroup, PACL pDacl, PACL pSacl, WINBOOL KeepExplicit, FN_PROGRESS fnProgress, PROG_INVOKE_SETTING ProgressInvokeSetting, PVOID Args);
  WINADVAPI DWORD WINAPI TreeResetNamedSecurityInfoW (LPWSTR pObjectName, SE_OBJECT_TYPE ObjectType, SECURITY_INFORMATION SecurityInfo, PSID pOwner, PSID pGroup, PACL pDacl, PACL pSacl, WINBOOL KeepExplicit, FN_PROGRESS fnProgress, PROG_INVOKE_SETTING ProgressInvokeSetting, PVOID Args);
  WINADVAPI DWORD WINAPI BuildSecurityDescriptorA (PTRUSTEE_A pOwner, PTRUSTEE_A pGroup, ULONG cCountOfAccessEntries, PEXPLICIT_ACCESS_A pListOfAccessEntries, ULONG cCountOfAuditEntries, PEXPLICIT_ACCESS_A pListOfAuditEntries, PSECURITY_DESCRIPTOR pOldSD, PULONG pSizeNewSD, PSECURITY_DESCRIPTOR *pNewSD);
  WINADVAPI DWORD WINAPI BuildSecurityDescriptorW (PTRUSTEE_W pOwner, PTRUSTEE_W pGroup, ULONG cCountOfAccessEntries, PEXPLICIT_ACCESS_W pListOfAccessEntries, ULONG cCountOfAuditEntries, PEXPLICIT_ACCESS_W pListOfAuditEntries, PSECURITY_DESCRIPTOR pOldSD, PULONG pSizeNewSD, PSECURITY_DESCRIPTOR *pNewSD);
  WINADVAPI DWORD WINAPI LookupSecurityDescriptorPartsA (PTRUSTEE_A *ppOwner, PTRUSTEE_A *ppGroup, PULONG pcCountOfAccessEntries, PEXPLICIT_ACCESS_A *ppListOfAccessEntries, PULONG pcCountOfAuditEntries, PEXPLICIT_ACCESS_A *ppListOfAuditEntries, PSECURITY_DESCRIPTOR pSD);
  WINADVAPI DWORD WINAPI LookupSecurityDescriptorPartsW (PTRUSTEE_W *ppOwner, PTRUSTEE_W *ppGroup, PULONG pcCountOfAccessEntries, PEXPLICIT_ACCESS_W *ppListOfAccessEntries, PULONG pcCountOfAuditEntries, PEXPLICIT_ACCESS_W *ppListOfAuditEntries, PSECURITY_DESCRIPTOR pSD);
  WINADVAPI VOID WINAPI BuildExplicitAccessWithNameA (PEXPLICIT_ACCESS_A pExplicitAccess, LPSTR pTrusteeName, DWORD AccessPermissions, ACCESS_MODE AccessMode, DWORD Inheritance);
  WINADVAPI VOID WINAPI BuildExplicitAccessWithNameW (PEXPLICIT_ACCESS_W pExplicitAccess, LPWSTR pTrusteeName, DWORD AccessPermissions, ACCESS_MODE AccessMode, DWORD Inheritance);
  WINADVAPI VOID WINAPI BuildImpersonateExplicitAccessWithNameA (PEXPLICIT_ACCESS_A pExplicitAccess, LPSTR pTrusteeName, PTRUSTEE_A pTrustee, DWORD AccessPermissions, ACCESS_MODE AccessMode, DWORD Inheritance);
  WINADVAPI VOID WINAPI BuildImpersonateExplicitAccessWithNameW (PEXPLICIT_ACCESS_W pExplicitAccess, LPWSTR pTrusteeName, PTRUSTEE_W pTrustee, DWORD AccessPermissions, ACCESS_MODE AccessMode, DWORD Inheritance);
  WINADVAPI VOID WINAPI BuildTrusteeWithNameA (PTRUSTEE_A pTrustee, LPSTR pName);
  WINADVAPI VOID WINAPI BuildTrusteeWithNameW (PTRUSTEE_W pTrustee, LPWSTR pName);
  WINADVAPI VOID WINAPI BuildImpersonateTrusteeA (PTRUSTEE_A pTrustee, PTRUSTEE_A pImpersonateTrustee);
  WINADVAPI VOID WINAPI BuildImpersonateTrusteeW (PTRUSTEE_W pTrustee, PTRUSTEE_W pImpersonateTrustee);
  WINADVAPI VOID WINAPI BuildTrusteeWithSidA (PTRUSTEE_A pTrustee, PSID pSid);
  WINADVAPI VOID WINAPI BuildTrusteeWithSidW (PTRUSTEE_W pTrustee, PSID pSid);
  WINADVAPI VOID WINAPI BuildTrusteeWithObjectsAndSidA (PTRUSTEE_A pTrustee, POBJECTS_AND_SID pObjSid, GUID *pObjectGuid, GUID *pInheritedObjectGuid, PSID pSid);
  WINADVAPI VOID WINAPI BuildTrusteeWithObjectsAndSidW (PTRUSTEE_W pTrustee, POBJECTS_AND_SID pObjSid, GUID *pObjectGuid, GUID *pInheritedObjectGuid, PSID pSid);
  WINADVAPI VOID WINAPI BuildTrusteeWithObjectsAndNameA (PTRUSTEE_A pTrustee, POBJECTS_AND_NAME_A pObjName, SE_OBJECT_TYPE ObjectType, LPSTR ObjectTypeName, LPSTR InheritedObjectTypeName, LPSTR Name);
  WINADVAPI VOID WINAPI BuildTrusteeWithObjectsAndNameW (PTRUSTEE_W pTrustee, POBJECTS_AND_NAME_W pObjName, SE_OBJECT_TYPE ObjectType, LPWSTR ObjectTypeName, LPWSTR InheritedObjectTypeName, LPWSTR Name);
  WINADVAPI LPSTR WINAPI GetTrusteeNameA (PTRUSTEE_A pTrustee);
  WINADVAPI LPWSTR WINAPI GetTrusteeNameW (PTRUSTEE_W pTrustee);
  WINADVAPI TRUSTEE_TYPE WINAPI GetTrusteeTypeA (PTRUSTEE_A pTrustee);
  WINADVAPI TRUSTEE_TYPE WINAPI GetTrusteeTypeW (PTRUSTEE_W pTrustee);
  WINADVAPI TRUSTEE_FORM WINAPI GetTrusteeFormA (PTRUSTEE_A pTrustee);
  WINADVAPI TRUSTEE_FORM WINAPI GetTrusteeFormW (PTRUSTEE_W pTrustee);
  WINADVAPI MULTIPLE_TRUSTEE_OPERATION WINAPI GetMultipleTrusteeOperationA (PTRUSTEE_A pTrustee);
  WINADVAPI MULTIPLE_TRUSTEE_OPERATION WINAPI GetMultipleTrusteeOperationW (PTRUSTEE_W pTrustee);
  WINADVAPI PTRUSTEE_A WINAPI GetMultipleTrusteeA (PTRUSTEE_A pTrustee);
  WINADVAPI PTRUSTEE_W WINAPI GetMultipleTrusteeW (PTRUSTEE_W pTrustee);

#if NTDDI_VERSION >= 0x06000000
  WINADVAPI DWORD WINAPI TreeSetNamedSecurityInfoA (LPSTR pObjectName, SE_OBJECT_TYPE ObjectType, SECURITY_INFORMATION SecurityInfo, PSID pOwner, PSID pGroup, PACL pDacl, PACL pSacl, DWORD dwAction, FN_PROGRESS fnProgress, PROG_INVOKE_SETTING ProgressInvokeSetting, PVOID Args);
  WINADVAPI DWORD WINAPI TreeSetNamedSecurityInfoW (LPWSTR pObjectName, SE_OBJECT_TYPE ObjectType, SECURITY_INFORMATION SecurityInfo, PSID pOwner, PSID pGroup, PACL pDacl, PACL pSacl, DWORD dwAction, FN_PROGRESS fnProgress, PROG_INVOKE_SETTING ProgressInvokeSetting, PVOID Args);
#endif

#endif /* WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_DESKTOP) */

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_APP)
#define SetEntriesInAcl __MINGW_NAME_AW(SetEntriesInAcl)
#define GetExplicitEntriesFromAcl __MINGW_NAME_AW(GetExplicitEntriesFromAcl)
#define GetNamedSecurityInfo __MINGW_NAME_AW(GetNamedSecurityInfo)
#define SetNamedSecurityInfo __MINGW_NAME_AW(SetNamedSecurityInfo)

  WINADVAPI DWORD WINAPI SetEntriesInAclA (ULONG cCountOfExplicitEntries, PEXPLICIT_ACCESS_A pListOfExplicitEntries, PACL OldAcl, PACL *NewAcl);
  WINADVAPI DWORD WINAPI SetEntriesInAclW (ULONG cCountOfExplicitEntries, PEXPLICIT_ACCESS_W pListOfExplicitEntries, PACL OldAcl, PACL *NewAcl);
  WINADVAPI DWORD WINAPI GetExplicitEntriesFromAclA (PACL pacl, PULONG pcCountOfExplicitEntries, PEXPLICIT_ACCESS_A *pListOfExplicitEntries);
  WINADVAPI DWORD WINAPI GetExplicitEntriesFromAclW (PACL pacl, PULONG pcCountOfExplicitEntries, PEXPLICIT_ACCESS_W *pListOfExplicitEntries);
  WINADVAPI DWORD WINAPI GetNamedSecurityInfoA (LPCSTR pObjectName, SE_OBJECT_TYPE ObjectType, SECURITY_INFORMATION SecurityInfo, PSID *ppsidOwner, PSID *ppsidGroup, PACL *ppDacl, PACL *ppSacl, PSECURITY_DESCRIPTOR *ppSecurityDescriptor);
  WINADVAPI DWORD WINAPI GetNamedSecurityInfoW (LPCWSTR pObjectName, SE_OBJECT_TYPE ObjectType, SECURITY_INFORMATION SecurityInfo, PSID *ppsidOwner, PSID *ppsidGroup, PACL *ppDacl, PACL *ppSacl, PSECURITY_DESCRIPTOR *ppSecurityDescriptor);
  WINADVAPI DWORD WINAPI GetSecurityInfo (HANDLE handle, SE_OBJECT_TYPE ObjectType, SECURITY_INFORMATION SecurityInfo, PSID *ppsidOwner, PSID *ppsidGroup, PACL *ppDacl, PACL *ppSacl, PSECURITY_DESCRIPTOR *ppSecurityDescriptor);
  WINADVAPI DWORD WINAPI SetNamedSecurityInfoA (LPSTR pObjectName, SE_OBJECT_TYPE ObjectType, SECURITY_INFORMATION SecurityInfo, PSID psidOwner, PSID psidGroup, PACL pDacl, PACL pSacl);
  WINADVAPI DWORD WINAPI SetNamedSecurityInfoW (LPWSTR pObjectName, SE_OBJECT_TYPE ObjectType, SECURITY_INFORMATION SecurityInfo, PSID psidOwner, PSID psidGroup, PACL pDacl, PACL pSacl);
  WINADVAPI DWORD WINAPI SetSecurityInfo (HANDLE handle, SE_OBJECT_TYPE ObjectType, SECURITY_INFORMATION SecurityInfo, PSID psidOwner, PSID psidGroup, PACL pDacl, PACL pSacl);
#endif /* WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_APP) */

#ifdef __cplusplus
}
#endif
#endif /* __ACCESS_CONTROL_API__ */

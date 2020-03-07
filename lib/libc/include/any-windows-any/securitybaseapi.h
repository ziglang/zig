/**
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER within this package.
 */
#ifndef _APISECUREBASE_
#define _APISECUREBASE_

#include <apiset.h>
#include <apisetcconv.h>
#include <minwindef.h>
#include <minwinbase.h>

#ifdef __cplusplus
extern "C" {
#endif

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_DESKTOP)
  WINADVAPI WINBOOL WINAPI AccessCheck (PSECURITY_DESCRIPTOR pSecurityDescriptor, HANDLE ClientToken, DWORD DesiredAccess, PGENERIC_MAPPING GenericMapping, PPRIVILEGE_SET PrivilegeSet, LPDWORD PrivilegeSetLength, LPDWORD GrantedAccess, LPBOOL AccessStatus);
  WINADVAPI WINBOOL WINAPI AccessCheckAndAuditAlarmW (LPCWSTR SubsystemName, LPVOID HandleId, LPWSTR ObjectTypeName, LPWSTR ObjectName, PSECURITY_DESCRIPTOR SecurityDescriptor, DWORD DesiredAccess, PGENERIC_MAPPING GenericMapping, WINBOOL ObjectCreation, LPDWORD GrantedAccess, LPBOOL AccessStatus, LPBOOL pfGenerateOnClose);
#ifdef UNICODE
#define AccessCheckAndAuditAlarm AccessCheckAndAuditAlarmW
#endif

  WINADVAPI WINBOOL WINAPI AccessCheckByType (PSECURITY_DESCRIPTOR pSecurityDescriptor, PSID PrincipalSelfSid, HANDLE ClientToken, DWORD DesiredAccess, POBJECT_TYPE_LIST ObjectTypeList, DWORD ObjectTypeListLength, PGENERIC_MAPPING GenericMapping, PPRIVILEGE_SET PrivilegeSet, LPDWORD PrivilegeSetLength, LPDWORD GrantedAccess, LPBOOL AccessStatus);
  WINADVAPI WINBOOL WINAPI AccessCheckByTypeResultList (PSECURITY_DESCRIPTOR pSecurityDescriptor, PSID PrincipalSelfSid, HANDLE ClientToken, DWORD DesiredAccess, POBJECT_TYPE_LIST ObjectTypeList, DWORD ObjectTypeListLength, PGENERIC_MAPPING GenericMapping, PPRIVILEGE_SET PrivilegeSet, LPDWORD PrivilegeSetLength, LPDWORD GrantedAccessList, LPDWORD AccessStatusList);
  WINADVAPI WINBOOL WINAPI AccessCheckByTypeAndAuditAlarmW (LPCWSTR SubsystemName, LPVOID HandleId, LPCWSTR ObjectTypeName, LPCWSTR ObjectName, PSECURITY_DESCRIPTOR SecurityDescriptor, PSID PrincipalSelfSid, DWORD DesiredAccess, AUDIT_EVENT_TYPE AuditType, DWORD Flags, POBJECT_TYPE_LIST ObjectTypeList, DWORD ObjectTypeListLength, PGENERIC_MAPPING GenericMapping, WINBOOL ObjectCreation, LPDWORD GrantedAccess, LPBOOL AccessStatus, LPBOOL pfGenerateOnClose);
#ifdef UNICODE
#define AccessCheckByTypeAndAuditAlarm AccessCheckByTypeAndAuditAlarmW
#endif

  WINADVAPI WINBOOL WINAPI AccessCheckByTypeResultListAndAuditAlarmW (LPCWSTR SubsystemName, LPVOID HandleId, LPCWSTR ObjectTypeName, LPCWSTR ObjectName, PSECURITY_DESCRIPTOR SecurityDescriptor, PSID PrincipalSelfSid, DWORD DesiredAccess, AUDIT_EVENT_TYPE AuditType, DWORD Flags, POBJECT_TYPE_LIST ObjectTypeList, DWORD ObjectTypeListLength, PGENERIC_MAPPING GenericMapping, WINBOOL ObjectCreation, LPDWORD GrantedAccessList, LPDWORD AccessStatusList, LPBOOL pfGenerateOnClose);
#ifdef UNICODE
#define AccessCheckByTypeResultListAndAuditAlarm AccessCheckByTypeResultListAndAuditAlarmW
#endif

  WINADVAPI WINBOOL WINAPI AccessCheckByTypeResultListAndAuditAlarmByHandleW (LPCWSTR SubsystemName, LPVOID HandleId, HANDLE ClientToken, LPCWSTR ObjectTypeName, LPCWSTR ObjectName, PSECURITY_DESCRIPTOR SecurityDescriptor, PSID PrincipalSelfSid, DWORD DesiredAccess, AUDIT_EVENT_TYPE AuditType, DWORD Flags, POBJECT_TYPE_LIST ObjectTypeList, DWORD ObjectTypeListLength, PGENERIC_MAPPING GenericMapping, WINBOOL ObjectCreation, LPDWORD GrantedAccessList, LPDWORD AccessStatusList, LPBOOL pfGenerateOnClose);
#ifdef UNICODE
#define AccessCheckByTypeResultListAndAuditAlarmByHandle AccessCheckByTypeResultListAndAuditAlarmByHandleW
#endif

  WINADVAPI WINBOOL WINAPI AddAccessAllowedAce (PACL pAcl, DWORD dwAceRevision, DWORD AccessMask, PSID pSid);
  WINADVAPI WINBOOL WINAPI AddAccessAllowedAceEx (PACL pAcl, DWORD dwAceRevision, DWORD AceFlags, DWORD AccessMask, PSID pSid);
  WINADVAPI WINBOOL WINAPI AddAccessAllowedObjectAce (PACL pAcl, DWORD dwAceRevision, DWORD AceFlags, DWORD AccessMask, GUID *ObjectTypeGuid, GUID *InheritedObjectTypeGuid, PSID pSid);
  WINADVAPI WINBOOL WINAPI AddAccessDeniedAce (PACL pAcl, DWORD dwAceRevision, DWORD AccessMask, PSID pSid);
  WINADVAPI WINBOOL WINAPI AddAccessDeniedAceEx (PACL pAcl, DWORD dwAceRevision, DWORD AceFlags, DWORD AccessMask, PSID pSid);
  WINADVAPI WINBOOL WINAPI AddAccessDeniedObjectAce (PACL pAcl, DWORD dwAceRevision, DWORD AceFlags, DWORD AccessMask, GUID *ObjectTypeGuid, GUID *InheritedObjectTypeGuid, PSID pSid);
  WINADVAPI WINBOOL WINAPI AddAce (PACL pAcl, DWORD dwAceRevision, DWORD dwStartingAceIndex, LPVOID pAceList, DWORD nAceListLength);
  WINADVAPI WINBOOL WINAPI AddAuditAccessAce (PACL pAcl, DWORD dwAceRevision, DWORD dwAccessMask, PSID pSid, WINBOOL bAuditSuccess, WINBOOL bAuditFailure);
  WINADVAPI WINBOOL WINAPI AddAuditAccessAceEx (PACL pAcl, DWORD dwAceRevision, DWORD AceFlags, DWORD dwAccessMask, PSID pSid, WINBOOL bAuditSuccess, WINBOOL bAuditFailure);
  WINADVAPI WINBOOL WINAPI AddAuditAccessObjectAce (PACL pAcl, DWORD dwAceRevision, DWORD AceFlags, DWORD AccessMask, GUID *ObjectTypeGuid, GUID *InheritedObjectTypeGuid, PSID pSid, WINBOOL bAuditSuccess, WINBOOL bAuditFailure);
#if _WIN32_WINNT >= 0x0600
  WINADVAPI WINBOOL WINAPI AddMandatoryAce (PACL pAcl, DWORD dwAceRevision, DWORD AceFlags, DWORD MandatoryPolicy, PSID pLabelSid);
#endif

#if _WIN32_WINNT >= 0x0602
  WINADVAPI WINBOOL WINAPI AddResourceAttributeAce (PACL pAcl, DWORD dwAceRevision, DWORD AceFlags, DWORD AccessMask, PSID pSid, PCLAIM_SECURITY_ATTRIBUTES_INFORMATION pAttributeInfo, PDWORD pReturnLength);
  WINADVAPI WINBOOL WINAPI AddScopedPolicyIDAce (PACL pAcl, DWORD dwAceRevision, DWORD AceFlags, DWORD AccessMask, PSID pSid);
#endif

  WINADVAPI WINBOOL WINAPI AdjustTokenGroups (HANDLE TokenHandle, WINBOOL ResetToDefault, PTOKEN_GROUPS NewState, DWORD BufferLength, PTOKEN_GROUPS PreviousState, PDWORD ReturnLength);
  WINADVAPI WINBOOL WINAPI AdjustTokenPrivileges (HANDLE TokenHandle, WINBOOL DisableAllPrivileges, PTOKEN_PRIVILEGES NewState, DWORD BufferLength, PTOKEN_PRIVILEGES PreviousState, PDWORD ReturnLength);
  WINADVAPI WINBOOL WINAPI AllocateAndInitializeSid (PSID_IDENTIFIER_AUTHORITY pIdentifierAuthority, BYTE nSubAuthorityCount, DWORD nSubAuthority0, DWORD nSubAuthority1, DWORD nSubAuthority2, DWORD nSubAuthority3, DWORD nSubAuthority4, DWORD nSubAuthority5, DWORD nSubAuthority6, DWORD nSubAuthority7, PSID *pSid);
  WINADVAPI WINBOOL WINAPI AllocateLocallyUniqueId (PLUID Luid);
  WINADVAPI WINBOOL WINAPI AreAllAccessesGranted (DWORD GrantedAccess, DWORD DesiredAccess);
  WINADVAPI WINBOOL WINAPI AreAnyAccessesGranted (DWORD GrantedAccess, DWORD DesiredAccess);
  WINADVAPI WINBOOL APIENTRY CheckTokenMembership (HANDLE TokenHandle, PSID SidToCheck, PBOOL IsMember);

#if _WIN32_WINNT >= 0x0602
  WINADVAPI WINBOOL APIENTRY CheckTokenCapability (HANDLE TokenHandle, PSID CapabilitySidToCheck, PBOOL HasCapability);
  WINADVAPI WINBOOL APIENTRY GetAppContainerAce (PACL Acl, DWORD StartingAceIndex, PVOID *AppContainerAce, DWORD *AppContainerAceIndex);
  WINADVAPI WINBOOL APIENTRY CheckTokenMembershipEx (HANDLE TokenHandle, PSID SidToCheck, DWORD Flags, PBOOL IsMember);
#endif

  WINADVAPI WINBOOL WINAPI ConvertToAutoInheritPrivateObjectSecurity (PSECURITY_DESCRIPTOR ParentDescriptor, PSECURITY_DESCRIPTOR CurrentSecurityDescriptor, PSECURITY_DESCRIPTOR *NewSecurityDescriptor, GUID *ObjectType, BOOLEAN IsDirectoryObject, PGENERIC_MAPPING GenericMapping);
  WINADVAPI WINBOOL WINAPI CopySid (DWORD nDestinationSidLength, PSID pDestinationSid, PSID pSourceSid);
  WINADVAPI WINBOOL WINAPI CreatePrivateObjectSecurity (PSECURITY_DESCRIPTOR ParentDescriptor, PSECURITY_DESCRIPTOR CreatorDescriptor, PSECURITY_DESCRIPTOR *NewDescriptor, WINBOOL IsDirectoryObject, HANDLE Token, PGENERIC_MAPPING GenericMapping);
  WINADVAPI WINBOOL WINAPI CreatePrivateObjectSecurityEx (PSECURITY_DESCRIPTOR ParentDescriptor, PSECURITY_DESCRIPTOR CreatorDescriptor, PSECURITY_DESCRIPTOR *NewDescriptor, GUID *ObjectType, WINBOOL IsContainerObject, ULONG AutoInheritFlags, HANDLE Token, PGENERIC_MAPPING GenericMapping);
  WINADVAPI WINBOOL WINAPI CreatePrivateObjectSecurityWithMultipleInheritance (PSECURITY_DESCRIPTOR ParentDescriptor, PSECURITY_DESCRIPTOR CreatorDescriptor, PSECURITY_DESCRIPTOR *NewDescriptor, GUID **ObjectTypes, ULONG GuidCount, WINBOOL IsContainerObject, ULONG AutoInheritFlags, HANDLE Token, PGENERIC_MAPPING GenericMapping);
  WINADVAPI WINBOOL APIENTRY CreateRestrictedToken (HANDLE ExistingTokenHandle, DWORD Flags, DWORD DisableSidCount, PSID_AND_ATTRIBUTES SidsToDisable, DWORD DeletePrivilegeCount, PLUID_AND_ATTRIBUTES PrivilegesToDelete, DWORD RestrictedSidCount, PSID_AND_ATTRIBUTES SidsToRestrict, PHANDLE NewTokenHandle);
  WINADVAPI WINBOOL WINAPI CreateWellKnownSid (WELL_KNOWN_SID_TYPE WellKnownSidType, PSID DomainSid, PSID pSid, DWORD *cbSid);
  WINADVAPI WINBOOL WINAPI EqualDomainSid (PSID pSid1, PSID pSid2, WINBOOL *pfEqual);

  WINADVAPI WINBOOL WINAPI DeleteAce (PACL pAcl, DWORD dwAceIndex);
  WINADVAPI WINBOOL WINAPI DestroyPrivateObjectSecurity (PSECURITY_DESCRIPTOR *ObjectDescriptor);
  WINADVAPI WINBOOL WINAPI DuplicateToken (HANDLE ExistingTokenHandle, SECURITY_IMPERSONATION_LEVEL ImpersonationLevel, PHANDLE DuplicateTokenHandle);
  WINADVAPI WINBOOL WINAPI DuplicateTokenEx (HANDLE hExistingToken, DWORD dwDesiredAccess, LPSECURITY_ATTRIBUTES lpTokenAttributes, SECURITY_IMPERSONATION_LEVEL ImpersonationLevel, TOKEN_TYPE TokenType, PHANDLE phNewToken);
  WINADVAPI WINBOOL WINAPI EqualPrefixSid (PSID pSid1, PSID pSid2);
  WINADVAPI WINBOOL WINAPI EqualSid (PSID pSid1, PSID pSid2);
  WINADVAPI WINBOOL WINAPI FindFirstFreeAce (PACL pAcl, LPVOID *pAce);
  WINADVAPI PVOID WINAPI FreeSid (PSID pSid);
  WINADVAPI WINBOOL WINAPI GetAce (PACL pAcl, DWORD dwAceIndex, LPVOID *pAce);
  WINADVAPI WINBOOL WINAPI GetAclInformation (PACL pAcl, LPVOID pAclInformation, DWORD nAclInformationLength, ACL_INFORMATION_CLASS dwAclInformationClass);
  WINADVAPI WINBOOL WINAPI GetFileSecurityW (LPCWSTR lpFileName, SECURITY_INFORMATION RequestedInformation, PSECURITY_DESCRIPTOR pSecurityDescriptor, DWORD nLength, LPDWORD lpnLengthNeeded);
#ifdef UNICODE
#define GetFileSecurity GetFileSecurityW
#endif

  WINADVAPI WINBOOL WINAPI GetKernelObjectSecurity (HANDLE Handle, SECURITY_INFORMATION RequestedInformation, PSECURITY_DESCRIPTOR pSecurityDescriptor, DWORD nLength, LPDWORD lpnLengthNeeded);
  WINADVAPI DWORD WINAPI GetLengthSid (PSID pSid);
  WINADVAPI WINBOOL WINAPI GetPrivateObjectSecurity (PSECURITY_DESCRIPTOR ObjectDescriptor, SECURITY_INFORMATION SecurityInformation, PSECURITY_DESCRIPTOR ResultantDescriptor, DWORD DescriptorLength, PDWORD ReturnLength);
  WINADVAPI WINBOOL WINAPI GetSecurityDescriptorControl (PSECURITY_DESCRIPTOR pSecurityDescriptor, PSECURITY_DESCRIPTOR_CONTROL pControl, LPDWORD lpdwRevision);
  WINADVAPI WINBOOL WINAPI GetSecurityDescriptorDacl (PSECURITY_DESCRIPTOR pSecurityDescriptor, LPBOOL lpbDaclPresent, PACL *pDacl, LPBOOL lpbDaclDefaulted);
  WINADVAPI WINBOOL WINAPI GetSecurityDescriptorGroup (PSECURITY_DESCRIPTOR pSecurityDescriptor, PSID *pGroup, LPBOOL lpbGroupDefaulted);
  WINADVAPI DWORD WINAPI GetSecurityDescriptorLength (PSECURITY_DESCRIPTOR pSecurityDescriptor);
  WINADVAPI WINBOOL WINAPI GetSecurityDescriptorOwner (PSECURITY_DESCRIPTOR pSecurityDescriptor, PSID *pOwner, LPBOOL lpbOwnerDefaulted);
  WINADVAPI DWORD WINAPI GetSecurityDescriptorRMControl (PSECURITY_DESCRIPTOR SecurityDescriptor, PUCHAR RMControl);
  WINADVAPI WINBOOL WINAPI GetSecurityDescriptorSacl (PSECURITY_DESCRIPTOR pSecurityDescriptor, LPBOOL lpbSaclPresent, PACL *pSacl, LPBOOL lpbSaclDefaulted);
  WINADVAPI PSID_IDENTIFIER_AUTHORITY WINAPI GetSidIdentifierAuthority (PSID pSid);
  WINADVAPI DWORD WINAPI GetSidLengthRequired (UCHAR nSubAuthorityCount);
  WINADVAPI PDWORD WINAPI GetSidSubAuthority (PSID pSid, DWORD nSubAuthority);
  WINADVAPI PUCHAR WINAPI GetSidSubAuthorityCount (PSID pSid);
  WINADVAPI WINBOOL WINAPI GetTokenInformation (HANDLE TokenHandle, TOKEN_INFORMATION_CLASS TokenInformationClass, LPVOID TokenInformation, DWORD TokenInformationLength, PDWORD ReturnLength);
  WINADVAPI WINBOOL WINAPI GetWindowsAccountDomainSid (PSID pSid, PSID pDomainSid, DWORD *cbDomainSid);
  WINADVAPI WINBOOL APIENTRY ImpersonateAnonymousToken (HANDLE ThreadHandle);
  WINADVAPI WINBOOL WINAPI ImpersonateLoggedOnUser (HANDLE hToken);
  WINADVAPI WINBOOL WINAPI ImpersonateSelf (SECURITY_IMPERSONATION_LEVEL ImpersonationLevel);
  WINADVAPI WINBOOL WINAPI InitializeAcl (PACL pAcl, DWORD nAclLength, DWORD dwAclRevision);
  WINADVAPI WINBOOL WINAPI InitializeSecurityDescriptor (PSECURITY_DESCRIPTOR pSecurityDescriptor, DWORD dwRevision);
  WINADVAPI WINBOOL WINAPI InitializeSid (PSID Sid, PSID_IDENTIFIER_AUTHORITY pIdentifierAuthority, BYTE nSubAuthorityCount);
  WINADVAPI WINBOOL WINAPI IsTokenRestricted (HANDLE TokenHandle);
  WINADVAPI WINBOOL WINAPI IsValidAcl (PACL pAcl);
  WINADVAPI WINBOOL WINAPI IsValidSecurityDescriptor (PSECURITY_DESCRIPTOR pSecurityDescriptor);
  WINADVAPI WINBOOL WINAPI IsValidSid (PSID pSid);
  WINADVAPI WINBOOL WINAPI IsWellKnownSid (PSID pSid, WELL_KNOWN_SID_TYPE WellKnownSidType);
  WINADVAPI WINBOOL WINAPI MakeAbsoluteSD (PSECURITY_DESCRIPTOR pSelfRelativeSecurityDescriptor, PSECURITY_DESCRIPTOR pAbsoluteSecurityDescriptor, LPDWORD lpdwAbsoluteSecurityDescriptorSize, PACL pDacl, LPDWORD lpdwDaclSize, PACL pSacl, LPDWORD lpdwSaclSize, PSID pOwner, LPDWORD lpdwOwnerSize, PSID pPrimaryGroup, LPDWORD lpdwPrimaryGroupSize);
  WINADVAPI WINBOOL WINAPI MakeSelfRelativeSD (PSECURITY_DESCRIPTOR pAbsoluteSecurityDescriptor, PSECURITY_DESCRIPTOR pSelfRelativeSecurityDescriptor, LPDWORD lpdwBufferLength);
  WINADVAPI VOID WINAPI MapGenericMask (PDWORD AccessMask, PGENERIC_MAPPING GenericMapping);
  WINADVAPI WINBOOL WINAPI ObjectCloseAuditAlarmW (LPCWSTR SubsystemName, LPVOID HandleId, WINBOOL GenerateOnClose);
#ifdef UNICODE
#define ObjectCloseAuditAlarm ObjectCloseAuditAlarmW
#endif

  WINADVAPI WINBOOL WINAPI ObjectDeleteAuditAlarmW (LPCWSTR SubsystemName, LPVOID HandleId, WINBOOL GenerateOnClose);
#ifdef UNICODE
#define ObjectDeleteAuditAlarm ObjectDeleteAuditAlarmW
#endif

  WINADVAPI WINBOOL WINAPI ObjectOpenAuditAlarmW (LPCWSTR SubsystemName, LPVOID HandleId, LPWSTR ObjectTypeName, LPWSTR ObjectName, PSECURITY_DESCRIPTOR pSecurityDescriptor, HANDLE ClientToken, DWORD DesiredAccess, DWORD GrantedAccess, PPRIVILEGE_SET Privileges, WINBOOL ObjectCreation, WINBOOL AccessGranted, LPBOOL GenerateOnClose);
#ifdef UNICODE
#define ObjectOpenAuditAlarm ObjectOpenAuditAlarmW
#endif

  WINADVAPI WINBOOL WINAPI ObjectPrivilegeAuditAlarmW (LPCWSTR SubsystemName, LPVOID HandleId, HANDLE ClientToken, DWORD DesiredAccess, PPRIVILEGE_SET Privileges, WINBOOL AccessGranted);
#ifdef UNICODE
#define ObjectPrivilegeAuditAlarm ObjectPrivilegeAuditAlarmW
#endif

  WINADVAPI WINBOOL WINAPI PrivilegeCheck (HANDLE ClientToken, PPRIVILEGE_SET RequiredPrivileges, LPBOOL pfResult);
  WINADVAPI WINBOOL WINAPI PrivilegedServiceAuditAlarmW (LPCWSTR SubsystemName, LPCWSTR ServiceName, HANDLE ClientToken, PPRIVILEGE_SET Privileges, WINBOOL AccessGranted);
#ifdef UNICODE
#define PrivilegedServiceAuditAlarm PrivilegedServiceAuditAlarmW
#endif

#if _WIN32_WINNT >= 0x0600
  WINADVAPI VOID WINAPI QuerySecurityAccessMask (SECURITY_INFORMATION SecurityInformation, LPDWORD DesiredAccess);
#endif

  WINADVAPI WINBOOL WINAPI RevertToSelf (VOID);
  WINADVAPI WINBOOL WINAPI SetAclInformation (PACL pAcl, LPVOID pAclInformation, DWORD nAclInformationLength, ACL_INFORMATION_CLASS dwAclInformationClass);
  WINADVAPI WINBOOL WINAPI SetFileSecurityW (LPCWSTR lpFileName, SECURITY_INFORMATION SecurityInformation, PSECURITY_DESCRIPTOR pSecurityDescriptor);
#ifdef UNICODE
#define SetFileSecurity SetFileSecurityW
#endif

  WINADVAPI WINBOOL WINAPI SetKernelObjectSecurity (HANDLE Handle, SECURITY_INFORMATION SecurityInformation, PSECURITY_DESCRIPTOR SecurityDescriptor);
  WINADVAPI WINBOOL WINAPI SetPrivateObjectSecurity (SECURITY_INFORMATION SecurityInformation, PSECURITY_DESCRIPTOR ModificationDescriptor, PSECURITY_DESCRIPTOR *ObjectsSecurityDescriptor, PGENERIC_MAPPING GenericMapping, HANDLE Token);
  WINADVAPI WINBOOL WINAPI SetPrivateObjectSecurityEx (SECURITY_INFORMATION SecurityInformation, PSECURITY_DESCRIPTOR ModificationDescriptor, PSECURITY_DESCRIPTOR *ObjectsSecurityDescriptor, ULONG AutoInheritFlags, PGENERIC_MAPPING GenericMapping, HANDLE Token);

#if _WIN32_WINNT >= 0x0600
  WINADVAPI VOID WINAPI SetSecurityAccessMask (SECURITY_INFORMATION SecurityInformation, LPDWORD DesiredAccess);
#endif

  WINADVAPI WINBOOL WINAPI SetSecurityDescriptorControl (PSECURITY_DESCRIPTOR pSecurityDescriptor, SECURITY_DESCRIPTOR_CONTROL ControlBitsOfInterest, SECURITY_DESCRIPTOR_CONTROL ControlBitsToSet);
  WINADVAPI WINBOOL WINAPI SetSecurityDescriptorDacl (PSECURITY_DESCRIPTOR pSecurityDescriptor, WINBOOL bDaclPresent, PACL pDacl, WINBOOL bDaclDefaulted);
  WINADVAPI WINBOOL WINAPI SetSecurityDescriptorGroup (PSECURITY_DESCRIPTOR pSecurityDescriptor, PSID pGroup, WINBOOL bGroupDefaulted);
  WINADVAPI WINBOOL WINAPI SetSecurityDescriptorOwner (PSECURITY_DESCRIPTOR pSecurityDescriptor, PSID pOwner, WINBOOL bOwnerDefaulted);
  WINADVAPI DWORD WINAPI SetSecurityDescriptorRMControl (PSECURITY_DESCRIPTOR SecurityDescriptor, PUCHAR RMControl);
  WINADVAPI WINBOOL WINAPI SetSecurityDescriptorSacl (PSECURITY_DESCRIPTOR pSecurityDescriptor, WINBOOL bSaclPresent, PACL pSacl, WINBOOL bSaclDefaulted);
  WINADVAPI WINBOOL WINAPI SetTokenInformation (HANDLE TokenHandle, TOKEN_INFORMATION_CLASS TokenInformationClass, LPVOID TokenInformation, DWORD TokenInformationLength);
#if _WIN32_WINNT >= 0x0602
  WINADVAPI WINBOOL WINAPI SetCachedSigningLevel (PHANDLE SourceFiles, ULONG SourceFileCount, ULONG Flags, HANDLE TargetFile);
  WINADVAPI WINBOOL WINAPI GetCachedSigningLevel (HANDLE File, PULONG Flags, PULONG SigningLevel, PUCHAR Thumbprint, PULONG ThumbprintSize, PULONG ThumbprintAlgorithm);
#endif
#endif

#if _WIN32_WINNT >= 0x0A00
  WINADVAPI LONG WINAPI CveEventWrite (PCWSTR CveId, PCWSTR AdditionalDetails);
  WINADVAPI WINBOOL WINAPI DeriveCapabilitySidsFromName(LPCWSTR CapName, PSID** CapabilityGroupSids, DWORD* CapabilityGroupSidCount, PSID** CapabilitySids, DWORD* CapabilitySidCount);
#endif

#ifdef __cplusplus
}
#endif
#endif

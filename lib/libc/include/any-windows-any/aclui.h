/**
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER within this package.
 */
#ifndef _ACLUI_H_
#define _ACLUI_H_

#include <winapifamily.h>

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_DESKTOP)

#include <objbase.h>
#include <commctrl.h>
#include <accctrl.h>
#include <authz.h>

#ifndef _ACLUI_
#define ACLUIAPI DECLSPEC_IMPORT WINAPI
#else
#define ACLUIAPI WINAPI
#endif

#ifdef __cplusplus
extern "C" {
#endif

  typedef struct _SI_OBJECT_INFO {
    DWORD dwFlags;
    HINSTANCE hInstance;
    LPWSTR pszServerName;
    LPWSTR pszObjectName;
    LPWSTR pszPageTitle;
    GUID guidObjectType;
  } SI_OBJECT_INFO,*PSI_OBJECT_INFO;

#define SI_EDIT_PERMS __MSABI_LONG(0x00000000)
#define SI_EDIT_OWNER __MSABI_LONG(0x00000001)
#define SI_EDIT_AUDITS __MSABI_LONG(0x00000002)
#define SI_CONTAINER __MSABI_LONG(0x00000004)
#define SI_READONLY __MSABI_LONG(0x00000008)
#define SI_ADVANCED __MSABI_LONG(0x00000010)
#define SI_RESET __MSABI_LONG(0x00000020)
#define SI_OWNER_READONLY __MSABI_LONG(0x00000040)
#define SI_EDIT_PROPERTIES __MSABI_LONG(0x00000080)
#define SI_OWNER_RECURSE __MSABI_LONG(0x00000100)
#define SI_NO_ACL_PROTECT __MSABI_LONG(0x00000200)
#define SI_NO_TREE_APPLY __MSABI_LONG(0x00000400)
#define SI_PAGE_TITLE __MSABI_LONG(0x00000800)
#define SI_SERVER_IS_DC __MSABI_LONG(0x00001000)
#define SI_RESET_DACL_TREE __MSABI_LONG(0x00004000)
#define SI_RESET_SACL_TREE __MSABI_LONG(0x00008000)
#define SI_OBJECT_GUID __MSABI_LONG(0x00010000)
#define SI_EDIT_EFFECTIVE __MSABI_LONG(0x00020000)
#define SI_RESET_DACL __MSABI_LONG(0x00040000)
#define SI_RESET_SACL __MSABI_LONG(0x00080000)
#define SI_RESET_OWNER __MSABI_LONG(0x00100000)
#define SI_NO_ADDITIONAL_PERMISSION __MSABI_LONG(0x00200000)
#if NTDDI_VERSION >= 0x06000000
#define SI_VIEW_ONLY __MSABI_LONG(0x00400000)
#define SI_PERMS_ELEVATION_REQUIRED __MSABI_LONG(0x01000000)
#define SI_AUDITS_ELEVATION_REQUIRED __MSABI_LONG(0x02000000)
#define SI_OWNER_ELEVATION_REQUIRED __MSABI_LONG(0x04000000)
#endif
#if NTDDI_VERSION >= 0x06020000
#define SI_SCOPE_ELEVATION_REQUIRED __MSABI_LONG(0x08000000)
#endif
#define SI_MAY_WRITE __MSABI_LONG(0x10000000)
#if NTDDI_VERSION >= 0x06020000
#define SI_ENABLE_EDIT_ATTRIBUTE_CONDITION __MSABI_LONG(0x20000000)
#define SI_ENABLE_CENTRAL_POLICY __MSABI_LONG(0x40000000)
#define SI_DISABLE_DENY_ACE __MSABI_LONG(0x80000000)
#endif

#define SI_EDIT_ALL (SI_EDIT_PERMS | SI_EDIT_OWNER | SI_EDIT_AUDITS)

  typedef struct _SI_ACCESS {
    const GUID *pguid;
    ACCESS_MASK mask;
    LPCWSTR pszName;
    DWORD dwFlags;
  } SI_ACCESS, *PSI_ACCESS;

#define SI_ACCESS_SPECIFIC __MSABI_LONG(0x00010000)
#define SI_ACCESS_GENERAL __MSABI_LONG(0x00020000)
#define SI_ACCESS_CONTAINER __MSABI_LONG(0x00040000)
#define SI_ACCESS_PROPERTY __MSABI_LONG(0x00080000)

  typedef struct _SI_INHERIT_TYPE {
    const GUID *pguid;
    ULONG dwFlags;
    LPCWSTR pszName;
  } SI_INHERIT_TYPE, *PSI_INHERIT_TYPE;

  typedef enum _SI_PAGE_TYPE {
    SI_PAGE_PERM=0,
    SI_PAGE_ADVPERM,
    SI_PAGE_AUDIT,
    SI_PAGE_OWNER,
    SI_PAGE_EFFECTIVE
#if NTDDI_VERSION >= 0x06000000
    , SI_PAGE_TAKEOWNERSHIP
#endif
#if NTDDI_VERSION >= 0x06020000
    , SI_PAGE_SHARE
#endif
  } SI_PAGE_TYPE;

  typedef enum _SI_PAGE_ACTIVATED {
    SI_SHOW_DEFAULT=0,
    SI_SHOW_PERM_ACTIVATED,
    SI_SHOW_AUDIT_ACTIVATED,
    SI_SHOW_OWNER_ACTIVATED,
    SI_SHOW_EFFECTIVE_ACTIVATED,
    SI_SHOW_SHARE_ACTIVATED,
    SI_SHOW_CENTRAL_POLICY_ACTIVATED,
  } SI_PAGE_ACTIVATED;

#define GET_PAGE_TYPE(X) (UINT) ((X) &0x0000ffff)
#define GET_ACTIVATION_TYPE(Y) (UINT) (((Y) >> 16) &0x0000ffff)
#define COMBINE_PAGE_ACTIVATION(X, Y) (UINT) (((Y) << 16) | X)

#define DOBJ_RES_CONT __MSABI_LONG(0x00000001)
#define DOBJ_RES_ROOT __MSABI_LONG(0x00000002)
#define DOBJ_VOL_NTACLS __MSABI_LONG(0x00000004)
#define DOBJ_COND_NTACLS __MSABI_LONG(0x00000008)
#define DOBJ_RIBBON_LAUNCH __MSABI_LONG(0x00000010)

#define PSPCB_SI_INITDIALOG (WM_USER + 1)

#undef INTERFACE
#define INTERFACE ISecurityInformation

  DECLARE_INTERFACE_IID_ (ISecurityInformation, IUnknown, "965FC360-16FF-11d0-91CB-00AA00BBB723") {
    STDMETHOD (QueryInterface) (THIS_ REFIID riid, void **ppvObj) PURE;
    STDMETHOD_ (ULONG, AddRef) (THIS) PURE;
    STDMETHOD_ (ULONG, Release) (THIS) PURE;
    STDMETHOD (GetObjectInformation) (THIS_ PSI_OBJECT_INFO pObjectInfo) PURE;
    STDMETHOD (GetSecurity) (THIS_ SECURITY_INFORMATION RequestedInformation, PSECURITY_DESCRIPTOR *ppSecurityDescriptor, WINBOOL fDefault) PURE;
    STDMETHOD (SetSecurity) (THIS_ SECURITY_INFORMATION SecurityInformation, PSECURITY_DESCRIPTOR pSecurityDescriptor) PURE;
    STDMETHOD (GetAccessRights) (THIS_ const GUID *pguidObjectType, DWORD dwFlags, PSI_ACCESS *ppAccess, ULONG *pcAccesses, ULONG *piDefaultAccess) PURE;
    STDMETHOD (MapGeneric) (THIS_ const GUID *pguidObjectType, UCHAR *pAceFlags, ACCESS_MASK *pMask) PURE;
    STDMETHOD (GetInheritTypes) (THIS_ PSI_INHERIT_TYPE *ppInheritTypes, ULONG *pcInheritTypes) PURE;
    STDMETHOD (PropertySheetPageCallback) (THIS_ HWND hwnd, UINT uMsg, SI_PAGE_TYPE uPage) PURE;
  };

  typedef ISecurityInformation *LPSECURITYINFO;
#undef INTERFACE
#define INTERFACE ISecurityInformation2

  DECLARE_INTERFACE_IID_ (ISecurityInformation2, IUnknown, "c3ccfdb4-6f88-11d2-a3ce-00c04fb1782a") {
    STDMETHOD (QueryInterface) (THIS_ REFIID riid, void **ppvObj) PURE;
    STDMETHOD_ (ULONG, AddRef) (THIS) PURE;
    STDMETHOD_ (ULONG, Release) (THIS) PURE;
    STDMETHOD_ (WINBOOL, IsDaclCanonical) (THIS_ PACL pDacl) PURE;
    STDMETHOD (LookupSids) (THIS_ ULONG cSids, PSID *rgpSids, LPDATAOBJECT *ppdo) PURE;
  };

  typedef ISecurityInformation2 *LPSECURITYINFO2;

#define CFSTR_ACLUI_SID_INFO_LIST TEXT ("CFSTR_ACLUI_SID_INFO_LIST")

  typedef struct _SID_INFO {
    PSID pSid;
    PWSTR pwzCommonName;
    PWSTR pwzClass;
    PWSTR pwzUPN;
  } SID_INFO, *PSID_INFO;

  typedef struct _SID_INFO_LIST {
    ULONG cItems;
    SID_INFO aSidInfo[ANYSIZE_ARRAY];
  } SID_INFO_LIST, *PSID_INFO_LIST;

#undef INTERFACE
#define INTERFACE IEffectivePermission

  DECLARE_INTERFACE_IID_ (IEffectivePermission, IUnknown, "3853DC76-9F35-407c-88A1-D19344365FBC") {
    STDMETHOD (QueryInterface) (THIS_ REFIID riid, void **ppvObj) PURE;
    STDMETHOD_ (ULONG, AddRef) (THIS) PURE;
    STDMETHOD_ (ULONG, Release) (THIS) PURE;
    STDMETHOD (GetEffectivePermission) (THIS_ const GUID *pguidObjectType, PSID pUserSid, LPCWSTR pszServerName, PSECURITY_DESCRIPTOR pSD, POBJECT_TYPE_LIST *ppObjectTypeList, ULONG *pcObjectTypeListLength, PACCESS_MASK *ppGrantedAccessList, ULONG *pcGrantedAccessListLength) PURE;
  };

  typedef IEffectivePermission *LPEFFECTIVEPERMISSION;

#undef INTERFACE
#define INTERFACE ISecurityObjectTypeInfo

  DECLARE_INTERFACE_IID_ (ISecurityObjectTypeInfo, IUnknown, "FC3066EB-79EF-444b-9111-D18A75EBF2FA") {
    STDMETHOD (QueryInterface) (THIS_ REFIID riid, void **ppvObj) PURE;
    STDMETHOD_ (ULONG, AddRef) (THIS) PURE;
    STDMETHOD_ (ULONG, Release) (THIS) PURE;
    STDMETHOD (GetInheritSource) (SECURITY_INFORMATION si, PACL pACL, PINHERITED_FROM *ppInheritArray) PURE;
  };

  typedef ISecurityObjectTypeInfo *LPSecurityObjectTypeInfo;

#if NTDDI_VERSION >= 0x06000000
#undef INTERFACE
#define INTERFACE ISecurityInformation3
  DECLARE_INTERFACE_IID_ (ISecurityInformation3, IUnknown, "E2CDC9CC-31BD-4f8f-8C8B-B641AF516A1A") {
    STDMETHOD (QueryInterface) (THIS_ REFIID riid, void **ppvObj) PURE;
    STDMETHOD_ (ULONG, AddRef) (THIS) PURE;
    STDMETHOD_ (ULONG, Release) (THIS) PURE;
    STDMETHOD (GetFullResourceName) (THIS_ LPWSTR *ppszResourceName) PURE;
    STDMETHOD (OpenElevatedEditor) (THIS_ HWND hWnd, SI_PAGE_TYPE uPage) PURE;
  };

  typedef ISecurityInformation3 *LPSECURITYINFO3;
#endif

#if NTDDI_VERSION >= 0x06020000
  typedef struct _SECURITY_OBJECT {
    PWSTR pwszName;
    PVOID pData;
    DWORD cbData;
    PVOID pData2;
    DWORD cbData2;
    DWORD Id;
    BOOLEAN fWellKnown;
  } SECURITY_OBJECT, *PSECURITY_OBJECT;

#define SECURITY_OBJECT_ID_OBJECT_SD 1
#define SECURITY_OBJECT_ID_SHARE 2
#define SECURITY_OBJECT_ID_CENTRAL_POLICY 3
#define SECURITY_OBJECT_ID_CENTRAL_ACCESS_RULE 4

  typedef struct _EFFPERM_RESULT_LIST {
    BOOLEAN fEvaluated;
    ULONG cObjectTypeListLength;
    OBJECT_TYPE_LIST *pObjectTypeList;
    ACCESS_MASK *pGrantedAccessList;
  } EFFPERM_RESULT_LIST, *PEFFPERM_RESULT_LIST;

#undef INTERFACE
#define INTERFACE ISecurityInformation4

  DECLARE_INTERFACE_IID_ (ISecurityInformation4, IUnknown, "EA961070-CD14-4621-ACE4-F63C03E583E4") {
    STDMETHOD (QueryInterface) (THIS_ REFIID riid, void **ppvObj) PURE;
    STDMETHOD_ (ULONG, AddRef) (THIS) PURE;
    STDMETHOD_ (ULONG, Release) (THIS) PURE;
    STDMETHOD (GetSecondarySecurity) (THIS_ PSECURITY_OBJECT *pSecurityObjects, PULONG pSecurityObjectCount) PURE;
  };

  typedef ISecurityInformation4 *LPSECURITYINFO4;

#undef INTERFACE
#define INTERFACE IEffectivePermission

  DECLARE_INTERFACE_IID_ (IEffectivePermission2, IUnknown, "941FABCA-DD47-4FCA-90BB-B0E10255F20D") {
    STDMETHOD (QueryInterface) (THIS_ REFIID riid, void **ppvObj) PURE;
    STDMETHOD_ (ULONG, AddRef) (THIS) PURE;
    STDMETHOD_ (ULONG, Release) (THIS) PURE;
    STDMETHOD (ComputeEffectivePermissionWithSecondarySecurity) (THIS_ PSID pSid, PSID pDeviceSid, PCWSTR pszServerName, PSECURITY_OBJECT pSecurityObjects, DWORD dwSecurityObjectCount, PTOKEN_GROUPS pUserGroups, PAUTHZ_SID_OPERATION pAuthzUserGroupsOperations, PTOKEN_GROUPS pDeviceGroups, PAUTHZ_SID_OPERATION pAuthzDeviceGroupsOperations, PAUTHZ_SECURITY_ATTRIBUTES_INFORMATION pAuthzUserClaims, PAUTHZ_SECURITY_ATTRIBUTE_OPERATION pAuthzUserClaimsOperations, PAUTHZ_SECURITY_ATTRIBUTES_INFORMATION pAuthzDeviceClaims, PAUTHZ_SECURITY_ATTRIBUTE_OPERATION pAuthzDeviceClaimsOperations, PEFFPERM_RESULT_LIST pEffpermResultLists);
  };

  typedef IEffectivePermission2 *LPEFFECTIVEPERMISSION2;
#endif

  EXTERN_GUID (IID_ISecurityInformation, 0x965fc360, 0x16ff, 0x11d0, 0x91, 0xcb, 0x0, 0xaa, 0x0, 0xbb, 0xb7, 0x23);
  EXTERN_GUID (IID_ISecurityInformation2, 0xc3ccfdb4, 0x6f88, 0x11d2, 0xa3, 0xce, 0x0, 0xc0, 0x4f, 0xb1, 0x78, 0x2a);
  EXTERN_GUID (IID_IEffectivePermission, 0x3853dc76, 0x9f35, 0x407c, 0x88, 0xa1, 0xd1, 0x93, 0x44, 0x36, 0x5f, 0xbc);
  EXTERN_GUID (IID_ISecurityObjectTypeInfo, 0xfc3066eb, 0x79ef, 0x444b, 0x91, 0x11, 0xd1, 0x8a, 0x75, 0xeb, 0xf2, 0xfa);
#if NTDDI_VERSION >= 0x06000000
  EXTERN_GUID (IID_ISecurityInformation3, 0xe2cdc9cc, 0x31bd, 0x4f8f, 0x8c, 0x8b, 0xb6, 0x41, 0xaf, 0x51, 0x6a, 0x1a);
#endif
#if NTDDI_VERSION >= 0x06020000
  EXTERN_GUID (IID_ISecurityInformation4, 0xea961070, 0xcd14, 0x4621, 0xac, 0xe4, 0xf6, 0x3c, 0x3, 0xe5, 0x83, 0xe4);
  EXTERN_GUID (IID_IEffectivePermission2, 0x941fabca, 0xdd47, 0x4fca, 0x90, 0xbb, 0xb0, 0xe1, 0x2, 0x55, 0xf2, 0xd);
#endif

  HPROPSHEETPAGE ACLUIAPI CreateSecurityPage (LPSECURITYINFO psi);
  WINBOOL ACLUIAPI EditSecurity (HWND hwndOwner, LPSECURITYINFO psi);
#if NTDDI_VERSION >= 0x06000000
  HRESULT ACLUIAPI EditSecurityAdvanced (HWND hwndOwner, LPSECURITYINFO psi, SI_PAGE_TYPE uSIPage);
#endif

#ifdef __cplusplus
}
#endif
#endif
#endif

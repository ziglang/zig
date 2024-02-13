/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#ifndef _APPMODEL_H_
#define _APPMODEL_H_

#include <minappmodel.h>

#if defined(__cplusplus)
extern "C" {
#endif

#if WINAPI_FAMILY_PARTITION(WINAPI_PARTITION_APP)

#include <pshpack4.h>

typedef struct PACKAGE_VERSION {
  __C89_NAMELESS union {
    UINT64 Version;
    __C89_NAMELESS struct {
      USHORT Revision;
      USHORT Build;
      USHORT Minor;
      USHORT Major;
    };
  };
} PACKAGE_VERSION;

typedef struct PACKAGE_ID {
  UINT32 reserved;
  UINT32 processorArchitecture;
  PACKAGE_VERSION version;
  PWSTR name;
  PWSTR publisher;
  PWSTR resourceId;
  PWSTR publisherId;
} PACKAGE_ID;

#include <poppack.h>

WINBASEAPI LONG WINAPI GetCurrentPackageId(UINT32 *bufferLength, BYTE *buffer);
WINBASEAPI LONG WINAPI GetCurrentPackageFullName(UINT32 *packageFullNameLength, PWSTR packageFullName);
WINBASEAPI LONG WINAPI GetCurrentPackageFamilyName(UINT32 *packageFamilyNameLength, PWSTR packageFamilyName);
WINBASEAPI LONG WINAPI GetCurrentPackagePath(UINT32 *pathLength, PWSTR path);
WINBASEAPI LONG WINAPI GetPackageId(HANDLE hProcess, UINT32 *bufferLength, BYTE *buffer);
WINBASEAPI LONG WINAPI GetPackageFullName(HANDLE hProcess, UINT32 *packageFullNameLength, PWSTR packageFullName);
WINBASEAPI LONG WINAPI GetPackageFullNameFromToken(HANDLE token, UINT32 *packageFullNameLength, PWSTR packageFullName);
WINBASEAPI LONG WINAPI GetPackageFamilyName(HANDLE hProcess, UINT32 *packageFamilyNameLength, PWSTR packageFamilyName);
WINBASEAPI LONG WINAPI GetPackageFamilyNameFromToken(HANDLE token, UINT32 *packageFamilyNameLength, PWSTR packageFamilyName);
WINBASEAPI LONG WINAPI GetPackagePath(const PACKAGE_ID *packageId, const UINT32 reserved, UINT32 *pathLength, PWSTR path);
WINBASEAPI LONG WINAPI GetPackagePathByFullName(PCWSTR packageFullName, UINT32 *pathLength, PWSTR path);
WINBASEAPI LONG WINAPI GetStagedPackagePathByFullName(PCWSTR packageFullName, UINT32 *pathLength, PWSTR path);

#if NTDDI_VERSION >= NTDDI_WIN10_19H1
typedef enum PackagePathType {
  PackagePathType_Install = 0,
  PackagePathType_Mutable = 1,
  PackagePathType_Effective = 2
#if NTDDI_VERSION >= NTDDI_WIN10_VB
  ,PackagePathType_MachineExternal = 3
  ,PackagePathType_UserExternal = 4
  ,PackagePathType_EffectiveExternal = 5
#endif
} PackagePathType;

WINBASEAPI LONG WINAPI GetPackagePathByFullName2(PCWSTR packageFullName, PackagePathType packagePathType, UINT32 *pathLength, PWSTR path);
WINBASEAPI LONG WINAPI GetStagedPackagePathByFullName2(PCWSTR packageFullName, PackagePathType packagePathType, UINT32 *pathLength, PWSTR path);
WINBASEAPI LONG WINAPI GetCurrentPackageInfo2(const UINT32 flags, PackagePathType packagePathType, UINT32 *bufferLength, BYTE *buffer, UINT32 *count);
WINBASEAPI LONG WINAPI GetCurrentPackagePath2(PackagePathType packagePathType, UINT32 *pathLength, PWSTR path);

#endif /* NTDDI_VERSION >= NTDDI_WIN10_19H1 */

WINBASEAPI LONG WINAPI GetCurrentApplicationUserModelId(UINT32 *applicationUserModelIdLength, PWSTR applicationUserModelId);
WINBASEAPI LONG WINAPI GetApplicationUserModelId(HANDLE hProcess, UINT32 *applicationUserModelIdLength, PWSTR applicationUserModelId);
WINBASEAPI LONG WINAPI GetApplicationUserModelIdFromToken(HANDLE token, UINT32 *applicationUserModelIdLength, PWSTR applicationUserModelId);
WINBASEAPI LONG WINAPI VerifyPackageFullName(PCWSTR packageFullName);
WINBASEAPI LONG WINAPI VerifyPackageFamilyName(PCWSTR packageFamilyName);
WINBASEAPI LONG WINAPI VerifyPackageId(const PACKAGE_ID *packageId);
WINBASEAPI LONG WINAPI VerifyApplicationUserModelId(PCWSTR applicationUserModelId);
WINBASEAPI LONG WINAPI VerifyPackageRelativeApplicationId(PCWSTR packageRelativeApplicationId);
WINBASEAPI LONG WINAPI PackageIdFromFullName(PCWSTR packageFullName, const UINT32 flags, UINT32 *bufferLength, BYTE *buffer);
WINBASEAPI LONG WINAPI PackageFullNameFromId(const PACKAGE_ID *packageId, UINT32 *packageFullNameLength, PWSTR packageFullName);
WINBASEAPI LONG WINAPI PackageFamilyNameFromId(const PACKAGE_ID *packageId, UINT32 *packageFamilyNameLength, PWSTR packageFamilyName);
WINBASEAPI LONG WINAPI PackageFamilyNameFromFullName(PCWSTR packageFullName, UINT32 *packageFamilyNameLength, PWSTR packageFamilyName);
WINBASEAPI LONG WINAPI PackageNameAndPublisherIdFromFamilyName(PCWSTR packageFamilyName, UINT32 *packageNameLength, PWSTR packageName, UINT32 *packagePublisherIdLength, PWSTR packagePublisherId);
WINBASEAPI LONG WINAPI FormatApplicationUserModelId(PCWSTR packageFamilyName, PCWSTR packageRelativeApplicationId, UINT32 *applicationUserModelIdLength, PWSTR applicationUserModelId);
WINBASEAPI LONG WINAPI ParseApplicationUserModelId(PCWSTR applicationUserModelId, UINT32 *packageFamilyNameLength, PWSTR packageFamilyName, UINT32 *packageRelativeApplicationIdLength, PWSTR packageRelativeApplicationId);
WINBASEAPI LONG WINAPI GetPackagesByPackageFamily(PCWSTR packageFamilyName, UINT32 *count, PWSTR *packageFullNames, UINT32 *bufferLength, WCHAR *buffer);
WINBASEAPI LONG WINAPI FindPackagesByPackageFamily(PCWSTR packageFamilyName, UINT32 packageFilters, UINT32 *count, PWSTR *packageFullNames, UINT32 *bufferLength, WCHAR *buffer, UINT32 *packageProperties);

typedef enum PackageOrigin {
  PackageOrigin_Unknown = 0,
  PackageOrigin_Unsigned = 1,
  PackageOrigin_Inbox = 2,
  PackageOrigin_Store = 3,
  PackageOrigin_DeveloperUnsigned = 4,
  PackageOrigin_DeveloperSigned = 5,
  PackageOrigin_LineOfBusiness = 6
} PackageOrigin;

WINBASEAPI LONG WINAPI GetStagedPackageOrigin(PCWSTR packageFullName, PackageOrigin *origin);

#define PACKAGE_PROPERTY_FRAMEWORK 0x00000001
#define PACKAGE_PROPERTY_RESOURCE 0x00000002
#define PACKAGE_PROPERTY_BUNDLE 0x00000004
#define PACKAGE_PROPERTY_OPTIONAL 0x00000008
#define PACKAGE_FILTER_HEAD 0x00000010
#define PACKAGE_FILTER_DIRECT 0x00000020
#define PACKAGE_FILTER_RESOURCE 0x00000040
#define PACKAGE_FILTER_BUNDLE 0x00000080
#define PACKAGE_INFORMATION_BASIC 0x00000000
#define PACKAGE_INFORMATION_FULL 0x00000100
#define PACKAGE_PROPERTY_DEVELOPMENT_MODE 0x00010000
#define PACKAGE_FILTER_OPTIONAL 0x00020000
#define PACKAGE_PROPERTY_IS_IN_RELATED_SET 0x00040000
#define PACKAGE_FILTER_IS_IN_RELATED_SET PACKAGE_PROPERTY_IS_IN_RELATED_SET
#define PACKAGE_PROPERTY_STATIC 0x00080000
#define PACKAGE_FILTER_STATIC PACKAGE_PROPERTY_STATIC
#define PACKAGE_PROPERTY_DYNAMIC 0x00100000
#define PACKAGE_FILTER_DYNAMIC PACKAGE_PROPERTY_DYNAMIC
#if NTDDI_VERSION >= NTDDI_WIN10_MN
#define PACKAGE_PROPERTY_HOSTRUNTIME 0x00200000
#define PACKAGE_FILTER_HOSTRUNTIME PACKAGE_PROPERTY_HOSTRUNTIME
#endif

typedef struct _PACKAGE_INFO_REFERENCE {
  void *reserved;
} PACKAGE_INFO_REFERENCE;

#include <pshpack4.h>

typedef struct PACKAGE_INFO {
  UINT32 reserved;
  UINT32 flags;
  PWSTR path;
  PWSTR packageFullName;
  PWSTR packageFamilyName;
  PACKAGE_ID packageId;
} PACKAGE_INFO;

#include <poppack.h>

WINBASEAPI LONG WINAPI GetCurrentPackageInfo(const UINT32 flags, UINT32 *bufferLength, BYTE *buffer, UINT32 *count);
WINBASEAPI LONG WINAPI OpenPackageInfoByFullName(PCWSTR packageFullName, const UINT32 reserved, PACKAGE_INFO_REFERENCE *packageInfoReference);
WINBASEAPI LONG WINAPI OpenPackageInfoByFullNameForUser(PSID userSid, PCWSTR packageFullName, const UINT32 reserved, PACKAGE_INFO_REFERENCE *packageInfoReference);
WINBASEAPI LONG WINAPI ClosePackageInfo(PACKAGE_INFO_REFERENCE packageInfoReference);
WINBASEAPI LONG WINAPI GetPackageInfo(PACKAGE_INFO_REFERENCE packageInfoReference, const UINT32 flags, UINT32 *bufferLength, BYTE *buffer, UINT32 *count);
WINBASEAPI LONG WINAPI GetPackageApplicationIds(PACKAGE_INFO_REFERENCE packageInfoReference, UINT32 *bufferLength, BYTE *buffer, UINT32 *count);

#if NTDDI_VERSION >= NTDDI_WIN10_19H1
WINBASEAPI LONG WINAPI GetPackageInfo2(PACKAGE_INFO_REFERENCE packageInfoReference, const UINT32 flags, PackagePathType packagePathType, UINT32 *bufferLength, BYTE *buffer, UINT32 *count);
#endif

WINBASEAPI HRESULT WINAPI CheckIsMSIXPackage(PCWSTR packageFullName, WINBOOL *isMSIXPackage);

#if NTDDI_VERSION >= NTDDI_WIN10_CO

typedef enum CreatePackageDependencyOptions {
  CreatePackageDependencyOptions_None = 0,
  CreatePackageDependencyOptions_DoNotVerifyDependencyResolution = 0x00000001,
  CreatePackageDependencyOptions_ScopeIsSystem = 0x00000002
} CreatePackageDependencyOptions;
DEFINE_ENUM_FLAG_OPERATORS(CreatePackageDependencyOptions)

typedef enum PackageDependencyLifetimeKind {
  PackageDependencyLifetimeKind_Process = 0,
  PackageDependencyLifetimeKind_FilePath = 1,
  PackageDependencyLifetimeKind_RegistryKey = 2
} PackageDependencyLifetimeKind;

typedef enum AddPackageDependencyOptions {
  AddPackageDependencyOptions_None = 0,
  AddPackageDependencyOptions_PrependIfRankCollision = 0x00000001
} AddPackageDependencyOptions;
DEFINE_ENUM_FLAG_OPERATORS(AddPackageDependencyOptions)

#define PACKAGE_DEPENDENCY_RANK_DEFAULT 0

typedef enum PackageDependencyProcessorArchitectures {
  PackageDependencyProcessorArchitectures_None = 0,
  PackageDependencyProcessorArchitectures_Neutral = 0x00000001,
  PackageDependencyProcessorArchitectures_X86 = 0x00000002,
  PackageDependencyProcessorArchitectures_X64 = 0x00000004,
  PackageDependencyProcessorArchitectures_Arm = 0x00000008,
  PackageDependencyProcessorArchitectures_Arm64 = 0x00000010,
  PackageDependencyProcessorArchitectures_X86A64 = 0x00000020
} PackageDependencyProcessorArchitectures;
DEFINE_ENUM_FLAG_OPERATORS(PackageDependencyProcessorArchitectures)

DECLARE_HANDLE(PACKAGEDEPENDENCY_CONTEXT);

WINBASEAPI HRESULT WINAPI TryCreatePackageDependency(PSID user, PCWSTR packageFamilyName, PACKAGE_VERSION minVersion, PackageDependencyProcessorArchitectures packageDependencyProcessorArchitectures, PackageDependencyLifetimeKind lifetimeKind, PCWSTR lifetimeArtifact, CreatePackageDependencyOptions options, PWSTR *packageDependencyId);
WINBASEAPI HRESULT WINAPI DeletePackageDependency(PCWSTR packageDependencyId);
WINBASEAPI HRESULT WINAPI AddPackageDependency(PCWSTR packageDependencyId, INT32 rank, AddPackageDependencyOptions options, PACKAGEDEPENDENCY_CONTEXT *packageDependencyContext, PWSTR *packageFullName);
WINBASEAPI HRESULT WINAPI RemovePackageDependency(PACKAGEDEPENDENCY_CONTEXT packageDependencyContext);
WINBASEAPI HRESULT WINAPI GetResolvedPackageFullNameForPackageDependency(PCWSTR packageDependencyId, PWSTR *packageFullName);
WINBASEAPI HRESULT WINAPI GetIdForPackageDependencyContext(PACKAGEDEPENDENCY_CONTEXT packageDependencyContext, PWSTR *packageDependencyId);

#endif /* NTDDI_VERSION >= NTDDI_WIN10_CO */

#if NTDDI_VERSION >= NTDDI_WIN10_NI
WINBASEAPI UINT32 WINAPI GetPackageGraphRevisionId(void);
#endif

typedef enum AppPolicyLifecycleManagement {
  AppPolicyLifecycleManagement_Unmanaged = 0,
  AppPolicyLifecycleManagement_Managed = 1
} AppPolicyLifecycleManagement;

WINBASEAPI LONG WINAPI AppPolicyGetLifecycleManagement(HANDLE processToken, AppPolicyLifecycleManagement *policy);

typedef enum AppPolicyWindowingModel {
  AppPolicyWindowingModel_None = 0,
  AppPolicyWindowingModel_Universal = 1,
  AppPolicyWindowingModel_ClassicDesktop = 2,
  AppPolicyWindowingModel_ClassicPhone = 3
} AppPolicyWindowingModel;

WINBASEAPI LONG WINAPI AppPolicyGetWindowingModel(HANDLE processToken, AppPolicyWindowingModel *policy);

typedef enum AppPolicyMediaFoundationCodecLoading {
  AppPolicyMediaFoundationCodecLoading_All = 0,
  AppPolicyMediaFoundationCodecLoading_InboxOnly = 1
} AppPolicyMediaFoundationCodecLoading;

WINBASEAPI LONG WINAPI AppPolicyGetMediaFoundationCodecLoading(HANDLE processToken, AppPolicyMediaFoundationCodecLoading *policy);

typedef enum AppPolicyClrCompat {
  AppPolicyClrCompat_Other = 0,
  AppPolicyClrCompat_ClassicDesktop = 1,
  AppPolicyClrCompat_Universal = 2,
  AppPolicyClrCompat_PackagedDesktop = 3
} AppPolicyClrCompat;

WINBASEAPI LONG WINAPI AppPolicyGetClrCompat(HANDLE processToken, AppPolicyClrCompat *policy);

typedef enum AppPolicyThreadInitializationType {
  AppPolicyThreadInitializationType_None = 0,
  AppPolicyThreadInitializationType_InitializeWinRT = 1
} AppPolicyThreadInitializationType;

WINBASEAPI LONG WINAPI AppPolicyGetThreadInitializationType(HANDLE processToken, AppPolicyThreadInitializationType *policy);

typedef enum AppPolicyShowDeveloperDiagnostic {
  AppPolicyShowDeveloperDiagnostic_None = 0,
  AppPolicyShowDeveloperDiagnostic_ShowUI = 1
} AppPolicyShowDeveloperDiagnostic;

WINBASEAPI LONG WINAPI AppPolicyGetShowDeveloperDiagnostic(HANDLE processToken, AppPolicyShowDeveloperDiagnostic *policy);

typedef enum AppPolicyProcessTerminationMethod {
  AppPolicyProcessTerminationMethod_ExitProcess = 0,
  AppPolicyProcessTerminationMethod_TerminateProcess = 1
} AppPolicyProcessTerminationMethod;

WINBASEAPI LONG WINAPI AppPolicyGetProcessTerminationMethod(HANDLE processToken, AppPolicyProcessTerminationMethod *policy);

typedef enum AppPolicyCreateFileAccess {
  AppPolicyCreateFileAccess_Full = 0,
  AppPolicyCreateFileAccess_Limited = 1
} AppPolicyCreateFileAccess;

WINBASEAPI LONG WINAPI AppPolicyGetCreateFileAccess(HANDLE processToken, AppPolicyCreateFileAccess *policy);

#endif /* WINAPI_FAMILY_PARTITION(WINAPI_PARTITION_APP) */

#if defined(__cplusplus)
}
#endif

#endif /* _APPMODEL_H_ */

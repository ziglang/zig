/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#ifndef _DISMAPI_H_
#define _DISMAPI_H_

#include <winapifamily.h>

#if WINAPI_FAMILY_PARTITION(WINAPI_PARTITION_DESKTOP)

#ifdef __cplusplus
extern "C"
{
#endif

typedef UINT DismSession;

typedef void(CALLBACK *DISM_PROGRESS_CALLBACK)(UINT Current, UINT Total, PVOID UserData);

#define DISM_ONLINE_IMAGE L"DISM_{53BFAE52-B167-4E2F-A258-0A37B57FF845}"

#define DISM_SESSION_DEFAULT 0

#define DISM_MOUNT_READWRITE 0x00000000
#define DISM_MOUNT_READONLY 0x00000001
#define DISM_MOUNT_OPTIMIZE 0x00000002
#define DISM_MOUNT_CHECK_INTEGRITY 0x00000004

#define DISM_COMMIT_IMAGE 0x00000000
#define DISM_DISCARD_IMAGE 0x00000001

#define DISM_COMMIT_GENERATE_INTEGRITY 0x00010000
#define DISM_COMMIT_APPEND 0x00020000
#define DISM_COMMIT_MASK 0xffff0000

/* https://docs.microsoft.com/en-us/windows-hardware/manufacture/desktop/dism/dism-api-enumerations */

typedef enum _DismLogLevel
{
    DismLogErrors = 0,
    DismLogErrorsWarnings,
    DismLogErrorsWarningsInfo
} DismLogLevel;

typedef enum _DismImageIdentifier
{
    DismImageIndex = 0,
    DismImageName
} DismImageIdentifier;

typedef enum _DismMountMode
{
    DismReadWrite = 0,
    DismReadOnly
} DismMountMode;

typedef enum _DismImageType
{
    DismImageTypeUnsupported = -1,
    DismImageTypeWim = 0,
    DismImageTypeVhd = 1
} DismImageType;

typedef enum _DismImageBootable
{
    DismImageBootableYes = 0,
    DismImageBootableNo,
    DismImageBootableUnknown
} DismImageBootable;

typedef enum _DismMountStatus
{
    DismMountStatusOk = 0,
    DismMountStatusNeedsRemount,
    DismMountStatusInvalid
} DismMountStatus;

typedef enum _DismImageHealthState
{
    DismImageHealthy = 0,
    DismImageRepairable,
    DismImageNonRepairable
} DismImageHealthState;

typedef enum _DismPackageIdentifier
{
    DismPackageNone = 0,
    DismPackageName,
    DismPackagePath
} DismPackageIdentifier;

typedef enum _DismPackageFeatureState
{
    DismStateNotPresent = 0,
    DismStateUninstallPending,
    DismStateStaged,
    DismStateResolved,
    DismStateRemoved = DismStateResolved,
    DismStateInstalled,
    DismStateInstallPending,
    DismStateSuperseded,
    DismStatePartiallyInstalled
} DismPackageFeatureState;

typedef enum _DismReleaseType
{
    DismReleaseTypeCriticalUpdate = 0,
    DismReleaseTypeDriver,
    DismReleaseTypeFeaturePack,
    DismReleaseTypeHotfix,
    DismReleaseTypeSecurityUpdate,
    DismReleaseTypeSoftwareUpdate,
    DismReleaseTypeUpdate,
    DismReleaseTypeUpdateRollup,
    DismReleaseTypeLanguagePack,
    DismReleaseTypeFoundation,
    DismReleaseTypeServicePack,
    DismReleaseTypeProduct,
    DismReleaseTypeLocalPack,
    DismReleaseTypeOther,
    DismReleaseTypeOnDemandPack
} DismReleaseType;

typedef enum _DismRestartType
{
    DismRestartNo = 0,
    DismRestartPossible,
    DismRestartRequired
} DismRestartType;

typedef enum _DismDriverSignature
{
    DismDriverSignatureUnknown = 0,
    DismDriverSignatureUnsigned = 1,
    DismDriverSignatureSigned = 2
} DismDriverSignature;

typedef enum _DismFullyOfflineInstallableType
{
    DismFullyOfflineInstallable = 0,
    DismFullyOfflineNotInstallable,
    DismFullyOfflineInstallableUndetermined
} DismFullyOfflineInstallableType;

/* https://docs.microsoft.com/en-us/windows-hardware/manufacture/desktop/dism/dism-api-structures */

#pragma pack(push, 1)

typedef struct _DismPackage
{
    PCWSTR PackageName;
    DismPackageFeatureState PackageState;
    DismReleaseType ReleaseType;
    SYSTEMTIME InstallTime;
} DismPackage;

typedef struct _DismCustomProperty
{
    PCWSTR Name;
    PCWSTR Value;
    PCWSTR Path;
} DismCustomProperty;

typedef struct _DismFeature
{
    PCWSTR FeatureName;
    DismPackageFeatureState State;
} DismFeature;

typedef struct _DismCapability
{
    PCWSTR Name;
    DismPackageFeatureState State;
} DismCapability;

typedef struct _DismPackageInfo
{
    PCWSTR PackageName;
    DismPackageFeatureState PackageState;
    DismReleaseType ReleaseType;
    SYSTEMTIME InstallTime;
    WINBOOL Applicable;
    PCWSTR Copyright;
    PCWSTR Company;
    SYSTEMTIME CreationTime;
    PCWSTR DisplayName;
    PCWSTR Description;
    PCWSTR InstallClient;
    PCWSTR InstallPackageName;
    SYSTEMTIME LastUpdateTime;
    PCWSTR ProductName;
    PCWSTR ProductVersion;
    DismRestartType RestartRequired;
    DismFullyOfflineInstallableType FullyOffline;
    PCWSTR SupportInformation;
    DismCustomProperty *CustomProperty;
    UINT CustomPropertyCount;
    DismFeature *Feature;
    UINT FeatureCount;
} DismPackageInfo;

#ifdef __cplusplus
typedef struct _DismPackageInfoEx : public _DismPackageInfo
{
#else
typedef struct _DismPackageInfoEx
{
    DismPackageInfo;
#endif
    PCWSTR CapabilityId;
} DismPackageInfoEx;

typedef struct _DismFeatureInfo
{
    PCWSTR FeatureName;
    DismPackageFeatureState FeatureState;
    PCWSTR DisplayName;
    PCWSTR Description;
    DismRestartType RestartRequired;
    DismCustomProperty *CustomProperty;
    UINT CustomPropertyCount;
} DismFeatureInfo;

typedef struct _DismCapabilityInfo
{
    PCWSTR Name;
    DismPackageFeatureState State;
    PCWSTR DisplayName;
    PCWSTR Description;
    DWORD DownloadSize;
    DWORD InstallSize;
} DismCapabilityInfo;

typedef struct _DismString
{
    PCWSTR Value;
} DismString;

typedef DismString DismLanguage;

typedef struct _DismWimCustomizedInfo
{
    UINT Size;
    UINT DirectoryCount;
    UINT FileCount;
    SYSTEMTIME CreatedTime;
    SYSTEMTIME ModifiedTime;
} DismWimCustomizedInfo;

typedef struct _DismImageInfo
{
    DismImageType ImageType;
    UINT ImageIndex;
    PCWSTR ImageName;
    PCWSTR ImageDescription;
    UINT64 ImageSize;
    UINT Architecture;
    PCWSTR ProductName;
    PCWSTR EditionId;
    PCWSTR InstallationType;
    PCWSTR Hal;
    PCWSTR ProductType;
    PCWSTR ProductSuite;
    UINT MajorVersion;
    UINT MinorVersion;
    UINT Build;
    UINT SpBuild;
    UINT SpLevel;
    DismImageBootable Bootable;
    PCWSTR SystemRoot;
    DismLanguage *Language;
    UINT LanguageCount;
    UINT DefaultLanguageIndex;
    VOID *CustomizedInfo;
} DismImageInfo;

typedef struct _DismMountedImageInfo
{
    PCWSTR MountPath;
    PCWSTR ImageFilePath;
    UINT ImageIndex;
    DismMountMode MountMode;
    DismMountStatus MountStatus;
} DismMountedImageInfo;

typedef struct _DismDriverPackage
{
    PCWSTR PublishedName;
    PCWSTR OriginalFileName;
    WINBOOL InBox;
    PCWSTR CatalogFile;
    PCWSTR ClassName;
    PCWSTR ClassGuid;
    PCWSTR ClassDescription;
    WINBOOL BootCritical;
    DismDriverSignature DriverSignature;
    PCWSTR ProviderName;
    SYSTEMTIME Date;
    UINT MajorVersion;
    UINT MinorVersion;
    UINT Build;
    UINT Revision;
} DismDriverPackage;

typedef struct _DismDriver
{
    PCWSTR ManufacturerName;
    PCWSTR HardwareDescription;
    PCWSTR HardwareId;
    UINT Architecture;
    PCWSTR ServiceName;
    PCWSTR CompatibleIds;
    PCWSTR ExcludeIds;
} DismDriver;

#pragma pack(pop)

/* https://docs.microsoft.com/en-us/windows-hardware/manufacture/desktop/dism/dism-api-functions */

HRESULT WINAPI DismInitialize (DismLogLevel LogLevel, PCWSTR LogFilePath, PCWSTR ScratchDirectory);
HRESULT WINAPI DismShutdown (void);
HRESULT WINAPI DismMountImage (PCWSTR ImageFilePath, PCWSTR MountPath, UINT ImageIndex, PCWSTR ImageName, DismImageIdentifier ImageIdentifier, DWORD Flags, HANDLE CancelEvent, DISM_PROGRESS_CALLBACK Progress, PVOID UserData);
HRESULT WINAPI DismUnmountImage (PCWSTR MountPath, DWORD Flags, HANDLE CancelEvent, DISM_PROGRESS_CALLBACK Progress, PVOID UserData);
HRESULT WINAPI DismOpenSession (PCWSTR ImagePath, PCWSTR WindowsDirectory, PCWSTR SystemDrive, DismSession *Session);
HRESULT WINAPI DismCloseSession (DismSession Session);
HRESULT WINAPI DismGetLastErrorMessage (DismString **ErrorMessage);
HRESULT WINAPI DismRemountImage (PCWSTR MountPath);
HRESULT WINAPI DismCommitImage (DismSession Session, DWORD Flags, HANDLE CancelEvent, DISM_PROGRESS_CALLBACK Progress, PVOID UserData);
HRESULT WINAPI DismGetImageInfo (PCWSTR ImageFilePath, DismImageInfo **ImageInfo, UINT *Count);
HRESULT WINAPI DismGetMountedImageInfo (DismMountedImageInfo **MountedImageInfo, UINT *Count);
HRESULT WINAPI DismCleanupMountpoints (void);
HRESULT WINAPI DismCheckImageHealth (DismSession Session, WINBOOL ScanImage, HANDLE CancelEvent, DISM_PROGRESS_CALLBACK Progress, PVOID UserData, DismImageHealthState *ImageHealth);
HRESULT WINAPI DismRestoreImageHealth (DismSession Session, PCWSTR *SourcePaths, UINT SourcePathCount, WINBOOL LimitAccess, HANDLE CancelEvent, DISM_PROGRESS_CALLBACK Progress, PVOID UserData);
HRESULT WINAPI DismDelete (VOID *DismStructure);
HRESULT WINAPI DismAddPackage (DismSession Session, PCWSTR PackagePath, WINBOOL IgnoreCheck, WINBOOL PreventPending, HANDLE CancelEvent, DISM_PROGRESS_CALLBACK Progress, PVOID UserData);
HRESULT WINAPI DismRemovePackage (DismSession Session, PCWSTR Identifier, DismPackageIdentifier PackageIdentifier, HANDLE CancelEvent, DISM_PROGRESS_CALLBACK Progress, PVOID UserData);
HRESULT WINAPI DismEnableFeature (DismSession Session, PCWSTR FeatureName, PCWSTR Identifier, DismPackageIdentifier PackageIdentifier, WINBOOL LimitAccess, PCWSTR *SourcePaths, UINT SourcePathCount, WINBOOL EnableAll, HANDLE CancelEvent, DISM_PROGRESS_CALLBACK Progress, PVOID UserData);
HRESULT WINAPI DismDisableFeature (DismSession Session, PCWSTR FeatureName, PCWSTR PackageName, WINBOOL RemovePayload, HANDLE CancelEvent, DISM_PROGRESS_CALLBACK Progress, PVOID UserData);
HRESULT WINAPI DismGetPackages (DismSession Session, DismPackage **Package, UINT *Count);
HRESULT WINAPI DismGetPackageInfo (DismSession Session, PCWSTR Identifier, DismPackageIdentifier PackageIdentifier, DismPackageInfo **PackageInfo);
HRESULT WINAPI DismGetPackageInfoEx (DismSession Session, PCWSTR Identifier, DismPackageIdentifier PackageIdentifier, DismPackageInfoEx **PackageInfoEx);
HRESULT WINAPI DismGetFeatures (DismSession Session, PCWSTR Identifier, DismPackageIdentifier PackageIdentifier, DismFeature **Feature, UINT *Count);
HRESULT WINAPI DismGetFeatureInfo (DismSession Session, PCWSTR FeatureName, PCWSTR Identifier, DismPackageIdentifier PackageIdentifier, DismFeatureInfo **FeatureInfo);
HRESULT WINAPI DismGetFeatureParent (DismSession Session, PCWSTR FeatureName, PCWSTR Identifier, DismPackageIdentifier PackageIdentifier, DismFeature **Feature, UINT *Count);
HRESULT WINAPI DismApplyUnattend (DismSession Session, PCWSTR UnattendFile, WINBOOL SingleSession);
HRESULT WINAPI DismAddDriver (DismSession Session, PCWSTR DriverPath, WINBOOL ForceUnsigned);
HRESULT WINAPI DismRemoveDriver (DismSession Session, PCWSTR DriverPath);
HRESULT WINAPI DismGetDrivers (DismSession Session, WINBOOL AllDrivers, DismDriverPackage **DriverPackage, UINT *Count);
HRESULT WINAPI DismGetDriverInfo (DismSession Session, PCWSTR DriverPath, DismDriver **Driver, UINT *Count, DismDriverPackage **DriverPackage);
HRESULT WINAPI DismGetCapabilities (DismSession Session, DismCapability **Capability, UINT *Count);
HRESULT WINAPI DismGetCapabilityInfo (DismSession Session, PCWSTR Name, DismCapabilityInfo **Info);
HRESULT WINAPI DismAddCapability (DismSession Session, PCWSTR Name, WINBOOL LimitAccess, PCWSTR *SourcePaths, UINT SourcePathCount, HANDLE CancelEvent, DISM_PROGRESS_CALLBACK Progress, PVOID UserData);
HRESULT WINAPI DismRemoveCapability (DismSession Session, PCWSTR Name, HANDLE CancelEvent, DISM_PROGRESS_CALLBACK Progress, PVOID UserData);

#define DISMAPI_S_RELOAD_IMAGE_SESSION_REQUIRED 0x00000001
#define DISMAPI_E_DISMAPI_NOT_INITIALIZED 0xc0040001
#define DISMAPI_E_SHUTDOWN_IN_PROGRESS 0xc0040002
#define DISMAPI_E_OPEN_SESSION_HANDLES 0xc0040003
#define DISMAPI_E_INVALID_DISM_SESSION 0xc0040004
#define DISMAPI_E_INVALID_IMAGE_INDEX 0xc0040005
#define DISMAPI_E_INVALID_IMAGE_NAME 0xc0040006
#define DISMAPI_E_UNABLE_TO_UNMOUNT_IMAGE_PATH 0xc0040007
#define DISMAPI_E_LOGGING_DISABLED 0xc0040009
#define DISMAPI_E_OPEN_HANDLES_UNABLE_TO_UNMOUNT_IMAGE_PATH 0xc004000a
#define DISMAPI_E_OPEN_HANDLES_UNABLE_TO_MOUNT_IMAGE_PATH 0xc004000b
#define DISMAPI_E_OPEN_HANDLES_UNABLE_TO_REMOUNT_IMAGE_PATH 0xc004000c
#define DISMAPI_E_PARENT_FEATURE_DISABLED 0xc004000d
#define DISMAPI_E_MUST_SPECIFY_ONLINE_IMAGE 0xc004000e
#define DISMAPI_E_INVALID_PRODUCT_KEY 0xc004000f
#define DISMAPI_E_NEEDS_REMOUNT 0xc1510114
#define DISMAPI_E_UNKNOWN_FEATURE 0x800f080c
#define DISMAPI_E_BUSY 0x800f0902

#ifdef __cplusplus
}
#endif

#endif /* WINAPI_PARTITION_DESKTOP */

#endif /* _DISMAPI_H_ */

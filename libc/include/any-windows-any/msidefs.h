/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef __MSIDEFS
#define __MSIDEFS

#ifndef NTDDI_WIN2K
#define NTDDI_WIN2K 0x05000000
#endif
#ifndef NTDDI_WINXP
#define NTDDI_WINXP 0x05010000
#endif
#ifndef NTDDI_WINXPSP2
#define NTDDI_WINXPSP2 0x05010200
#endif
#ifndef NTDDI_WS03SP1
#define NTDDI_WS03SP1 0x05020100
#endif
#ifndef NTDDI_VISTA
#define NTDDI_VISTA 0x06000000
#endif
#ifndef NTDDI_VISTASP1
#define NTDDI_VISTASP1 0x6000100
#endif

#ifndef _WIN32_MSI
#if _WIN32_WINNT >= 0x0600 || (defined(NTDDI_VERSION) && NTDDI_VERSION >= NTDDI_VISTA)
#if defined(NTDDI_VERSION) && NTDDI_VERSION >= NTDDI_VISTASP1
#define _WIN32_MSI 450
#else
#define _WIN32_MSI 400
#endif 
#elif (defined(NTDDI_VERSION) && NTDDI_VERSION >= NTDDI_WS03SP1)
#define _WIN32_MSI 310
#elif defined(NTDDI_VERSION) && NTDDI_VERSION >= NTDDI_WINXPSP2
#define _WIN32_MSI 300
#else
#define _WIN32_MSI 200
#endif
#endif

#define IPROPNAME_PRODUCTNAME TEXT("ProductName")
#define IPROPNAME_PRODUCTCODE TEXT("ProductCode")
#define IPROPNAME_PRODUCTVERSION TEXT("ProductVersion")
#define IPROPNAME_INSTALLLANGUAGE TEXT("ProductLanguage")
#define IPROPNAME_MANUFACTURER TEXT("Manufacturer")

#define IPROPNAME_UPGRADECODE TEXT("UpgradeCode")
#define IPROPNAME_PIDTEMPLATE TEXT("PIDTemplate")
#define IPROPNAME_DISKPROMPT TEXT("DiskPrompt")
#define IPROPNAME_LEFTUNIT TEXT("LeftUnit")
#define IPROPNAME_ADMIN_PROPERTIES TEXT("AdminProperties")
#define IPROPNAME_DEFAULTUIFONT TEXT("DefaultUIFont")
#define IPROPNAME_ALLOWEDPROPERTIES TEXT("SecureCustomProperties")
#define IPROPNAME_ENABLEUSERCONTROL TEXT("EnableUserControl")
#define IPROPNAME_HIDDEN_PROPERTIES TEXT("MsiHiddenProperties")

#define IPROPNAME_USERNAME TEXT("USERNAME")
#define IPROPNAME_COMPANYNAME TEXT("COMPANYNAME")
#define IPROPNAME_PIDKEY TEXT("PIDKEY")
#define IPROPNAME_PATCH TEXT("PATCH")
#define IPROPNAME_MSIPATCHREMOVE TEXT("MSIPATCHREMOVE")
#define IPROPNAME_TARGETDIR TEXT("TARGETDIR")
#define IPROPNAME_ACTION TEXT("ACTION")
#define IPROPNAME_LIMITUI TEXT("LIMITUI")
#define IPROPNAME_LOGACTION TEXT("LOGACTION")
#define IPROPNAME_ALLUSERS TEXT("ALLUSERS")
#define IPROPNAME_INSTALLLEVEL TEXT("INSTALLLEVEL")
#define IPROPNAME_REBOOT TEXT("REBOOT")
#if (_WIN32_MSI >= 110)
#define IPROPNAME_REBOOTPROMPT TEXT("REBOOTPROMPT")
#endif
#define IPROPNAME_EXECUTEMODE TEXT("EXECUTEMODE")
#define IPROPVALUE_EXECUTEMODE_NONE TEXT("NONE")
#define IPROPVALUE_EXECUTEMODE_SCRIPT TEXT("SCRIPT")
#define IPROPNAME_EXECUTEACTION TEXT("EXECUTEACTION")
#define IPROPNAME_SOURCELIST TEXT("SOURCELIST")
#define IPROPNAME_ROOTDRIVE TEXT("ROOTDRIVE")
#define IPROPNAME_TRANSFORMS TEXT("TRANSFORMS")
#define IPROPNAME_TRANSFORMSATSOURCE TEXT("TRANSFORMSATSOURCE")
#define IPROPNAME_TRANSFORMSSECURE TEXT("TRANSFORMSSECURE")
#define IPROPNAME_SEQUENCE TEXT("SEQUENCE")
#define IPROPNAME_SHORTFILENAMES TEXT("SHORTFILENAMES")
#define IPROPNAME_PRIMARYFOLDER TEXT("PRIMARYFOLDER")
#define IPROPNAME_AFTERREBOOT TEXT("AFTERREBOOT")
#define IPROPNAME_NOCOMPANYNAME TEXT("NOCOMPANYNAME")
#define IPROPNAME_NOUSERNAME TEXT("NOUSERNAME")
#define IPROPNAME_DISABLEROLLBACK TEXT("DISABLEROLLBACK")
#define IPROPNAME_AVAILABLEFREEREG TEXT("AVAILABLEFREEREG")
#define IPROPNAME_DISABLEADVTSHORTCUTS TEXT("DISABLEADVTSHORTCUTS")
#define IPROPNAME_PATCHNEWPACKAGECODE TEXT("PATCHNEWPACKAGECODE")

#define IPROPNAME_PATCHNEWSUMMARYSUBJECT TEXT("PATCHNEWSUMMARYSUBJECT")

#define IPROPNAME_PATCHNEWSUMMARYCOMMENTS TEXT("PATCHNEWSUMMARYCOMMENTS")

#define IPROPNAME_PRODUCTLANGUAGE TEXT("PRODUCTLANGUAGE")

#if (_WIN32_MSI >= 150)
#define IPROPNAME_CHECKCRCS TEXT("MSICHECKCRCS")
#define IPROPNAME_MSINODISABLEMEDIA TEXT("MSINODISABLEMEDIA")

#define IPROPNAME_CARRYINGNDP TEXT("CARRYINGNDP")
#define IPROPVALUE__CARRYINGNDP_URTREINSTALL TEXT("URTREINSTALL")
#define IPROPVALUE__CARRYINGNDP_URTUPGRADE TEXT("URTUPGRADE")
#define IPROPNAME_ENFORCE_UPGRADE_COMPONENT_RULES TEXT("MSIENFORCEUPGRADECOMPONENTRULES")

#define IPROPNAME_MSINEWINSTANCE TEXT("MSINEWINSTANCE")
#define IPROPNAME_MSIINSTANCEGUID TEXT("MSIINSTANCEGUID")

#define IPROPNAME_MSIPACKAGEDOWNLOADLOCALCOPY TEXT("MSIPACKAGEDOWNLOADLOCALCOPY")
#define IPROPNAME_MSIPATCHDOWNLOADLOCALCOPY TEXT("MSIPATCHDOWNLOADLOCALCOPY")
#endif

#if (_WIN32_MSI >= 300)
#define IPROPNAME_MSIDISABLELUAPATCHING TEXT("MSIDISABLELUAPATCHING")
#endif

#if _WIN32_MSI >= 400
#define IPROPNAME_MSILOGGINGMODE TEXT("MsiLogging")
#define IPROPNAME_MSILOGFILELOCATION TEXT("MsiLogFileLocation")
#define IPROPNAME_MSI_RM_CONTROL TEXT("MSIRESTARTMANAGERCONTROL")
#define IPROPVALUE_MSI_RM_CONTROL_DISABLE TEXT("Disable")
#define IPROPVALUE_MSI_RM_CONTROL_DISABLESHUTDOWN TEXT("DisableShutdown")
#define IPROPNAME_MSI_RM_SESSION_KEY TEXT("MsiRestartManagerSessionKey")
#define IPROPNAME_MSI_REBOOT_PENDING TEXT("MsiSystemRebootPending")
#define IPROPNAME_MSI_RM_SHUTDOWN TEXT("MSIRMSHUTDOWN")
#define IPROPNAME_MSI_RM_DISABLE_RESTART TEXT("MSIDISABLERMRESTART")
#define IPROPNAME_MSI_UAC_DEPLOYMENT_COMPLIANT TEXT("MSIDEPLOYMENTCOMPLIANT")
#define IPROPNAME_MSI_USE_REAL_ADMIN_DETECTION TEXT("MSIUSEREALADMINDETECTION")
#endif

#define IPROPNAME_ARPAUTHORIZEDCDFPREFIX TEXT("ARPAUTHORIZEDCDFPREFIX")
#define IPROPNAME_ARPCOMMENTS TEXT("ARPCOMMENTS")
#define IPROPNAME_ARPCONTACT TEXT("ARPCONTACT")
#define IPROPNAME_ARPHELPLINK TEXT("ARPHELPLINK")
#define IPROPNAME_ARPHELPTELEPHONE TEXT("ARPHELPTELEPHONE")
#define IPROPNAME_ARPINSTALLLOCATION TEXT("ARPINSTALLLOCATION")
#define IPROPNAME_ARPNOMODIFY TEXT("ARPNOMODIFY")
#define IPROPNAME_ARPNOREMOVE TEXT("ARPNOREMOVE")
#define IPROPNAME_ARPNOREPAIR TEXT("ARPNOREPAIR")
#define IPROPNAME_ARPREADME TEXT("ARPREADME")
#define IPROPNAME_ARPSIZE TEXT("ARPSIZE")
#define IPROPNAME_ARPSYSTEMCOMPONENT TEXT("ARPSYSTEMCOMPONENT")
#define IPROPNAME_ARPURLINFOABOUT TEXT("ARPURLINFOABOUT")
#define IPROPNAME_ARPURLUPDATEINFO TEXT("ARPURLUPDATEINFO")
#if (_WIN32_MSI >= 110)
#define IPROPNAME_ARPPRODUCTICON TEXT("ARPPRODUCTICON")
#if _WIN32_MSI >=  400
#define IPROPNAME_ARPSETTINGSIDENTIFIER TEXT("MSIARPSETTINGSIDENTIFIER")
#endif
#endif

#define IPROPNAME_INSTALLED TEXT("Installed")
#define IPROPNAME_PRODUCTSTATE TEXT("ProductState")
#define IPROPNAME_PRESELECTED TEXT("Preselected")
#define IPROPNAME_RESUME TEXT("RESUME")
#define IPROPNAME_UPDATESTARTED TEXT("UpdateStarted")
#define IPROPNAME_PRODUCTID TEXT("ProductID")
#define IPROPNAME_OUTOFDISKSPACE TEXT("OutOfDiskSpace")
#define IPROPNAME_OUTOFNORBDISKSPACE TEXT("OutOfNoRbDiskSpace")
#define IPROPNAME_COSTINGCOMPLETE TEXT("CostingComplete")
#define IPROPNAME_SOURCEDIR TEXT("SourceDir")
#define IPROPNAME_REPLACEDINUSEFILES TEXT("ReplacedInUseFiles")
#define IPROPNAME_PRIMARYFOLDER_PATH TEXT("PrimaryVolumePath")
#define IPROPNAME_PRIMARYFOLDER_SPACEAVAILABLE TEXT("PrimaryVolumeSpaceAvailable")
#define IPROPNAME_PRIMARYFOLDER_SPACEREQUIRED TEXT("PrimaryVolumeSpaceRequired")
#define IPROPNAME_PRIMARYFOLDER_SPACEREMAINING TEXT("PrimaryVolumeSpaceRemaining")
#define IPROPNAME_ISADMINPACKAGE TEXT("IsAdminPackage")
#define IPROPNAME_ROLLBACKDISABLED TEXT("RollbackDisabled")
#define IPROPNAME_RESTRICTEDUSERCONTROL TEXT("RestrictedUserControl")
#if (_WIN32_MSI >= 300)
#define IPROPNAME_SOURCERESONLY TEXT("MsiUISourceResOnly")
#define IPROPNAME_HIDECANCEL TEXT("MsiUIHideCancel")
#define IPROPNAME_PROGRESSONLY TEXT("MsiUIProgressOnly")
#endif

#define IPROPNAME_TIME TEXT("Time")
#define IPROPNAME_DATE TEXT("Date")
#define IPROPNAME_DATETIME TEXT("DateTime")

#define IPROPNAME_INTEL TEXT("Intel")
#if (_WIN32_MSI >= 150)
#define IPROPNAME_TEMPLATE_AMD64 TEXT("AMD64")
#define IPROPNAME_TEMPLATE_X64 TEXT("x64")
#define IPROPNAME_MSIAMD64 TEXT("MsiAMD64")
#define IPROPNAME_MSIX64 TEXT("Msix64")
#define IPROPNAME_INTEL64 TEXT("Intel64")
#else
#define IPROPNAME_IA64 TEXT("IA64")
#endif
#define IPROPNAME_TEXTHEIGHT TEXT("TextHeight")
#define IPROPNAME_SCREENX TEXT("ScreenX")
#define IPROPNAME_SCREENY TEXT("ScreenY")
#define IPROPNAME_CAPTIONHEIGHT TEXT("CaptionHeight")
#define IPROPNAME_BORDERTOP TEXT("BorderTop")
#define IPROPNAME_BORDERSIDE TEXT("BorderSide")
#define IPROPNAME_COLORBITS TEXT("ColorBits")
#define IPROPNAME_PHYSICALMEMORY TEXT("PhysicalMemory")
#define IPROPNAME_VIRTUALMEMORY TEXT("VirtualMemory")
#if (_WIN32_MSI >= 150)
#define IPROPNAME_TEXTHEIGHT_CORRECTION TEXT("TextHeightCorrection")
#if _WIN32_MSI >= 400
#define IPROPNAME_MSITABLETPC TEXT("MsiTabletPC")
#endif
#endif

#define IPROPNAME_VERSIONNT TEXT("VersionNT")
#define IPROPNAME_VERSION9X TEXT("Version9X")
#if (_WIN32_MSI >= 150)
#define IPROPNAME_VERSIONNT64 TEXT("VersionNT64")
#endif
#define IPROPNAME_WINDOWSBUILD TEXT("WindowsBuild")
#define IPROPNAME_SERVICEPACKLEVEL TEXT("ServicePackLevel")
#if (_WIN32_MSI >= 110)
#define IPROPNAME_SERVICEPACKLEVELMINOR TEXT("ServicePackLevelMinor")
#endif
#define IPROPNAME_SHAREDWINDOWS TEXT("SharedWindows")
#define IPROPNAME_COMPUTERNAME TEXT("ComputerName")
#define IPROPNAME_SHELLADVTSUPPORT TEXT("ShellAdvtSupport")
#define IPROPNAME_OLEADVTSUPPORT TEXT("OLEAdvtSupport")
#define IPROPNAME_SYSTEMLANGUAGEID TEXT("SystemLanguageID")
#define IPROPNAME_TTCSUPPORT TEXT("TTCSupport")
#define IPROPNAME_TERMSERVER TEXT("TerminalServer")
#if (_WIN32_MSI >= 110)
#define IPROPNAME_REMOTEADMINTS TEXT("RemoteAdminTS")
#define IPROPNAME_REDIRECTEDDLLSUPPORT TEXT("RedirectedDllSupport")
#endif
#if (_WIN32_MSI >= 150)
#define IPROPNAME_NTPRODUCTTYPE TEXT("MsiNTProductType")
#define IPROPNAME_NTSUITEBACKOFFICE TEXT("MsiNTSuiteBackOffice")
#define IPROPNAME_NTSUITEDATACENTER TEXT("MsiNTSuiteDataCenter")
#define IPROPNAME_NTSUITEENTERPRISE TEXT("MsiNTSuiteEnterprise")
#define IPROPNAME_NTSUITESMALLBUSINESS TEXT("MsiNTSuiteSmallBusiness")
#define IPROPNAME_NTSUITESMALLBUSINESSRESTRICTED TEXT("MsiNTSuiteSmallBusinessRestricted")
#define IPROPNAME_NTSUITEPERSONAL TEXT("MsiNTSuitePersonal")
#define IPROPNAME_NTSUITEWEBSERVER TEXT("MsiNTSuiteWebServer")
#define IPROPNAME_NETASSEMBLYSUPPORT TEXT("MsiNetAssemblySupport")
#define IPROPNAME_WIN32ASSEMBLYSUPPORT TEXT("MsiWin32AssemblySupport")
#endif

#define IPROPNAME_LOGONUSER TEXT("LogonUser")
#define IPROPNAME_USERSID TEXT("UserSID")
#define IPROPNAME_ADMINUSER TEXT("AdminUser")
#define IPROPNAME_USERLANGUAGEID TEXT("UserLanguageID")
#define IPROPNAME_PRIVILEGED TEXT("Privileged")
#if _WIN32_MSI >= 400
#define IPROPNAME_RUNNINGELEVATED TEXT("MsiRunningElevated")
#endif

#define IPROPNAME_WINDOWS_FOLDER TEXT("WindowsFolder")
#define IPROPNAME_SYSTEM_FOLDER TEXT("SystemFolder")
#define IPROPNAME_SYSTEM16_FOLDER TEXT("System16Folder")
#define IPROPNAME_WINDOWS_VOLUME TEXT("WindowsVolume")
#define IPROPNAME_TEMP_FOLDER TEXT("TempFolder")
#define IPROPNAME_PROGRAMFILES_FOLDER TEXT("ProgramFilesFolder")
#define IPROPNAME_COMMONFILES_FOLDER TEXT("CommonFilesFolder")
#if (_WIN32_MSI >= 150)
#define IPROPNAME_SYSTEM64_FOLDER TEXT("System64Folder")
#define IPROPNAME_PROGRAMFILES64_FOLDER TEXT("ProgramFiles64Folder")
#define IPROPNAME_COMMONFILES64_FOLDER TEXT("CommonFiles64Folder")
#endif
#define IPROPNAME_STARTMENU_FOLDER TEXT("StartMenuFolder")
#define IPROPNAME_PROGRAMMENU_FOLDER TEXT("ProgramMenuFolder")
#define IPROPNAME_STARTUP_FOLDER TEXT("StartupFolder")
#define IPROPNAME_NETHOOD_FOLDER TEXT("NetHoodFolder")
#define IPROPNAME_PERSONAL_FOLDER TEXT("PersonalFolder")
#define IPROPNAME_SENDTO_FOLDER TEXT("SendToFolder")
#define IPROPNAME_DESKTOP_FOLDER TEXT("DesktopFolder")
#define IPROPNAME_TEMPLATE_FOLDER TEXT("TemplateFolder")
#define IPROPNAME_FONTS_FOLDER TEXT("FontsFolder")
#define IPROPNAME_FAVORITES_FOLDER TEXT("FavoritesFolder")
#define IPROPNAME_RECENT_FOLDER TEXT("RecentFolder")
#define IPROPNAME_APPDATA_FOLDER TEXT("AppDataFolder")
#define IPROPNAME_PRINTHOOD_FOLDER TEXT("PrintHoodFolder")
#if (_WIN32_MSI >= 110)
#define IPROPNAME_ADMINTOOLS_FOLDER TEXT("AdminToolsFolder")
#define IPROPNAME_COMMONAPPDATA_FOLDER TEXT("CommonAppDataFolder")
#define IPROPNAME_LOCALAPPDATA_FOLDER TEXT("LocalAppDataFolder")
#define IPROPNAME_MYPICTURES_FOLDER TEXT("MyPicturesFolder")
#endif

#define IPROPNAME_FEATUREADDLOCAL TEXT("ADDLOCAL")
#define IPROPNAME_FEATUREADDSOURCE TEXT("ADDSOURCE")
#define IPROPNAME_FEATUREADDDEFAULT TEXT("ADDDEFAULT")
#define IPROPNAME_FEATUREREMOVE TEXT("REMOVE")
#define IPROPNAME_FEATUREADVERTISE TEXT("ADVERTISE")
#define IPROPVALUE_FEATURE_ALL TEXT("ALL")

#define IPROPNAME_COMPONENTADDLOCAL TEXT("COMPADDLOCAL")
#define IPROPNAME_COMPONENTADDSOURCE TEXT("COMPADDSOURCE")
#define IPROPNAME_COMPONENTADDDEFAULT TEXT("COMPADDDEFAULT")

#define IPROPNAME_FILEADDLOCAL TEXT("FILEADDLOCAL")
#define IPROPNAME_FILEADDSOURCE TEXT("FILEADDSOURCE")
#define IPROPNAME_FILEADDDEFAULT TEXT("FILEADDDEFAULT")

#define IPROPNAME_REINSTALL TEXT("REINSTALL")
#define IPROPNAME_REINSTALLMODE TEXT("REINSTALLMODE")
#define IPROPNAME_PROMPTROLLBACKCOST TEXT("PROMPTROLLBACKCOST")
#define IPROPVALUE_RBCOST_PROMPT TEXT("P")
#define IPROPVALUE_RBCOST_SILENT TEXT("D")
#define IPROPVALUE_RBCOST_FAIL TEXT("F")

#define IPROPNAME_CUSTOMACTIONDATA TEXT("CustomActionData")

#define IACTIONNAME_INSTALL TEXT("INSTALL")
#define IACTIONNAME_ADVERTISE TEXT("ADVERTISE")
#define IACTIONNAME_ADMIN TEXT("ADMIN")
#define IACTIONNAME_SEQUENCE TEXT("SEQUENCE")
#define IACTIONNAME_COLLECTUSERINFO TEXT("CollectUserInfo")
#define IACTIONNAME_FIRSTRUN TEXT("FirstRun")

#undef PID_SECURITY

#define PID_DICTIONARY (0)
#define PID_CODEPAGE (0x1)
#define PID_TITLE 2
#define PID_SUBJECT 3
#define PID_AUTHOR 4
#define PID_KEYWORDS 5
#define PID_COMMENTS 6
#define PID_TEMPLATE 7
#define PID_LASTAUTHOR 8
#define PID_REVNUMBER 9
#define PID_EDITTIME 10
#define PID_LASTPRINTED 11
#define PID_CREATE_DTM 12
#define PID_LASTSAVE_DTM 13
#define PID_PAGECOUNT 14
#define PID_WORDCOUNT 15
#define PID_CHARCOUNT 16
#define PID_THUMBNAIL 17
#define PID_APPNAME 18
#define PID_SECURITY 19

#define PID_MSIVERSION PID_PAGECOUNT
#define PID_MSISOURCE PID_WORDCOUNT
#define PID_MSIRESTRICT PID_CHARCOUNT

enum msidbControlAttributes {
  msidbControlAttributesVisible = 0x00000001,msidbControlAttributesEnabled = 0x00000002,msidbControlAttributesSunken = 0x00000004,
  msidbControlAttributesIndirect = 0x00000008,msidbControlAttributesInteger = 0x00000010,msidbControlAttributesRTLRO = 0x00000020,
  msidbControlAttributesRightAligned = 0x00000040,msidbControlAttributesLeftScroll = 0x00000080,
  msidbControlAttributesBiDi = msidbControlAttributesRTLRO | msidbControlAttributesRightAligned | msidbControlAttributesLeftScroll,
  msidbControlAttributesTransparent = 0x00010000,msidbControlAttributesNoPrefix = 0x00020000,msidbControlAttributesNoWrap = 0x00040000,
  msidbControlAttributesFormatSize = 0x00080000,msidbControlAttributesUsersLanguage = 0x00100000,msidbControlAttributesMultiline = 0x00010000,
#if (_WIN32_MSI >= 110)
  msidbControlAttributesPasswordInput = 0x00200000,
#endif
  msidbControlAttributesProgress95 = 0x00010000,msidbControlAttributesRemovableVolume = 0x00010000,msidbControlAttributesFixedVolume = 0x00020000,
  msidbControlAttributesRemoteVolume = 0x00040000,msidbControlAttributesCDROMVolume = 0x00080000,msidbControlAttributesRAMDiskVolume = 0x00100000,
  msidbControlAttributesFloppyVolume = 0x00200000,msidbControlShowRollbackCost = 0x00400000,msidbControlAttributesSorted = 0x00010000,
  msidbControlAttributesComboList = 0x00020000,msidbControlAttributesImageHandle = 0x00010000,msidbControlAttributesPushLike = 0x00020000,
  msidbControlAttributesBitmap = 0x00040000,msidbControlAttributesIcon = 0x00080000,msidbControlAttributesFixedSize = 0x00100000,
  msidbControlAttributesIconSize16 = 0x00200000,msidbControlAttributesIconSize32 = 0x00400000,msidbControlAttributesIconSize48 = 0x00600000,
  msidbControlAttributesHasBorder = 0x01000000
};

typedef enum _msidbLocatorType {
  msidbLocatorTypeDirectory = 0x0,
  msidbLocatorTypeFileName = 0x1
#if (_WIN32_MSI >= 110)
  ,msidbLocatorTypeRawValue = 0x2
#endif
#if (_WIN32_MSI >= 150)
  ,msidbLocatorType64bit = 0x10
#endif
} msidbLocatorType;

enum msidbComponentAttributes {
  msidbComponentAttributesLocalOnly = 0x00000000,msidbComponentAttributesSourceOnly = 0x00000001,msidbComponentAttributesOptional = 0x00000002,
  msidbComponentAttributesRegistryKeyPath = 0x00000004,msidbComponentAttributesSharedDllRefCount = 0x00000008,
  msidbComponentAttributesPermanent = 0x00000010,msidbComponentAttributesODBCDataSource = 0x00000020,msidbComponentAttributesTransitive = 0x00000040,
  msidbComponentAttributesNeverOverwrite = 0x00000080
#if (_WIN32_MSI >= 150)
  ,msidbComponentAttributes64bit = 0x00000100
#if _WIN32_MSI >= 400
  ,msidbComponentAttributesDisableRegistryReflection = 0x00000200
#endif
#endif
};

#if (_WIN32_MSI >= 150)
enum msidbAssemblyAttributes {
  msidbAssemblyAttributesURT = 0x00000000,msidbAssemblyAttributesWin32 = 0x00000001
};
#endif

enum msidbCustomActionType {
  msidbCustomActionTypeDll = 0x00000001,msidbCustomActionTypeExe = 0x00000002,msidbCustomActionTypeTextData = 0x00000003,
  msidbCustomActionTypeJScript = 0x00000005,msidbCustomActionTypeVBScript = 0x00000006,msidbCustomActionTypeInstall = 0x00000007,
  msidbCustomActionTypeBinaryData = 0x00000000,msidbCustomActionTypeSourceFile = 0x00000010,msidbCustomActionTypeDirectory = 0x00000020,
  msidbCustomActionTypeProperty = 0x00000030,msidbCustomActionTypeContinue = 0x00000040,msidbCustomActionTypeAsync = 0x00000080,
  msidbCustomActionTypeFirstSequence = 0x00000100,msidbCustomActionTypeOncePerProcess = 0x00000200,msidbCustomActionTypeClientRepeat = 0x00000300,
  msidbCustomActionTypeInScript = 0x00000400,msidbCustomActionTypeRollback = 0x00000100,msidbCustomActionTypeCommit = 0x00000200,
  msidbCustomActionTypeNoImpersonate = 0x00000800
#if (_WIN32_MSI >= 150)
  ,msidbCustomActionTypeTSAware = 0x00004000
#endif
#if (_WIN32_MSI >= 150)
  ,msidbCustomActionType64BitScript = 0x00001000,msidbCustomActionTypeHideTarget = 0x00002000
#if _WIN32_MSI >= 450
  ,msidbCustomActionTypePatchUninstall = 0x00008000
#endif
#endif
};

enum msidbDialogAttributes {
  msidbDialogAttributesVisible = 0x00000001,msidbDialogAttributesModal = 0x00000002,msidbDialogAttributesMinimize = 0x00000004,
  msidbDialogAttributesSysModal = 0x00000008,msidbDialogAttributesKeepModeless = 0x00000010,msidbDialogAttributesTrackDiskSpace = 0x00000020,
  msidbDialogAttributesUseCustomPalette = 0x00000040,msidbDialogAttributesRTLRO = 0x00000080,msidbDialogAttributesRightAligned = 0x00000100,
  msidbDialogAttributesLeftScroll = 0x00000200,msidbDialogAttributesBiDi = msidbDialogAttributesRTLRO | msidbDialogAttributesRightAligned | msidbDialogAttributesLeftScroll,
  msidbDialogAttributesError = 0x00010000
};

enum msidbFeatureAttributes {
  msidbFeatureAttributesFavorLocal = 0x00000000,msidbFeatureAttributesFavorSource = 0x00000001,msidbFeatureAttributesFollowParent = 0x00000002,
  msidbFeatureAttributesFavorAdvertise = 0x00000004,msidbFeatureAttributesDisallowAdvertise = 0x00000008,
  msidbFeatureAttributesUIDisallowAbsent = 0x00000010,msidbFeatureAttributesNoUnsupportedAdvertise= 0x00000020
};

enum msidbFileAttributes {
  msidbFileAttributesReadOnly = 0x00000001,msidbFileAttributesHidden = 0x00000002,msidbFileAttributesSystem = 0x00000004,
  msidbFileAttributesReserved0 = 0x00000008,msidbFileAttributesReserved1 = 0x00000040,msidbFileAttributesReserved2 = 0x00000080,
  msidbFileAttributesReserved3 = 0x00000100,msidbFileAttributesVital = 0x00000200,msidbFileAttributesChecksum = 0x00000400,
  msidbFileAttributesPatchAdded = 0x00001000,msidbFileAttributesNoncompressed = 0x00002000,msidbFileAttributesCompressed = 0x00004000,
  msidbFileAttributesReserved4 = 0x00008000
};

typedef enum _msidbIniFileAction {
  msidbIniFileActionAddLine = 0x00000000,msidbIniFileActionCreateLine = 0x00000001,msidbIniFileActionRemoveLine = 0x00000002,
  msidbIniFileActionAddTag = 0x00000003,msidbIniFileActionRemoveTag = 0x00000004
} msidbIniFileAction;

enum msidbMoveFileOptions {
  msidbMoveFileOptionsMove = 0x00000001
};

typedef enum _msidbODBCDataSourceRegistration {
  msidbODBCDataSourceRegistrationPerMachine = 0x00000000,msidbODBCDataSourceRegistrationPerUser = 0x00000001
} msidbODBCDataSourceRegistration;

#if (_WIN32_MSI >= 110)
enum msidbClassAttributes {
  msidbClassAttributesRelativePath = 0x00000001
};
#endif

enum msidbPatchAttributes {
  msidbPatchAttributesNonVital = 0x00000001
};

enum msidbRegistryRoot {
  msidbRegistryRootClassesRoot = 0,msidbRegistryRootCurrentUser = 1,msidbRegistryRootLocalMachine = 2,msidbRegistryRootUsers = 3
};

enum msidbRemoveFileInstallMode {
  msidbRemoveFileInstallModeOnInstall = 0x00000001,msidbRemoveFileInstallModeOnRemove = 0x00000002,msidbRemoveFileInstallModeOnBoth = 0x00000003
};

enum msidbServiceControlEvent {
  msidbServiceControlEventStart = 0x00000001,msidbServiceControlEventStop = 0x00000002,msidbServiceControlEventDelete = 0x00000008,
  msidbServiceControlEventUninstallStart = 0x00000010,msidbServiceControlEventUninstallStop = 0x00000020,
  msidbServiceControlEventUninstallDelete = 0x00000080
};

enum msidbServiceInstallErrorControl {
  msidbServiceInstallErrorControlVital = 0x00008000
};

enum msidbTextStyleStyleBits {
  msidbTextStyleStyleBitsBold = 0x00000001,msidbTextStyleStyleBitsItalic = 0x00000002,msidbTextStyleStyleBitsUnderline = 0x00000004,
  msidbTextStyleStyleBitsStrike = 0x00000008
};

#if (_WIN32_MSI >= 110)
enum msidbUpgradeAttributes {
  msidbUpgradeAttributesMigrateFeatures = 0x00000001,msidbUpgradeAttributesOnlyDetect = 0x00000002,
  msidbUpgradeAttributesIgnoreRemoveFailure = 0x00000004,msidbUpgradeAttributesVersionMinInclusive = 0x00000100,
  msidbUpgradeAttributesVersionMaxInclusive = 0x00000200,msidbUpgradeAttributesLanguagesExclusive = 0x00000400
};
#endif

#if _WIN32_MSI >= 450
enum msidbEmbeddedUIAttributes {
  msidbEmbeddedUI = 0x1, msidbEmbeddedHandlesBasic = 0x02
};
#endif

enum msidbSumInfoSourceType {
  msidbSumInfoSourceTypeSFN = 0x00000001,msidbSumInfoSourceTypeCompressed = 0x00000002,
  msidbSumInfoSourceTypeAdminImage = 0x00000004
#if _WIN32_MSI >= 400
  ,msidbSumInfoSourceTypeLUAPackage = 0x00000008
#endif
};

#if _WIN32_MSI >= 400
enum msirbRebootType {
  msirbRebootImmediate = 1, msirbRebootDeferred = 2
};

enum msirbRebootReason {
  msirbRebootUndeterminedReason = 0, msirbRebootInUseFilesReason = 1,
  msirbRebootScheduleRebootReason = 2, msirbRebootForceRebootReason = 3,
  msirbRebootCustomActionReason = 4
};
#endif
#endif

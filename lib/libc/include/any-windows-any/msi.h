/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _MSI_H_
#define _MSI_H_

#include <_mingw_unicode.h>

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
#define NTDDI_VISTASP1 0x06000100
#endif

#ifndef _WIN32_MSI
#if defined(NTDDI_VERSION) && NTDDI_VERSION >= NTDDI_VISTASP1
#define _WIN32_MSI 450
#elif defined(NTDDI_VERSION) && NTDDI_VERSION >= NTDDI_VISTA
#define _WIN32_MSI 400
#elif defined(NTDDI_VERSION) && NTDDI_VERSION >= NTDDI_WS03SP1
#define _WIN32_MSI 310
#elif defined(NTDDI_VERSION) && NTDDI_VERSION >= NTDDI_WINXPSP2
#define _WIN32_MSI 300
#else
#define _WIN32_MSI 200
#endif
#endif

#ifndef MAX_GUID_CHARS
#define MAX_GUID_CHARS  38
#endif

#if _WIN32_MSI >= 150 && !defined (_MSI_NO_CRYPTO)
#include "wincrypt.h"
#endif

typedef unsigned __LONG32 MSIHANDLE;

#ifdef __cplusplus
extern "C" {
#endif

  UINT WINAPI MsiCloseHandle(MSIHANDLE hAny);
  UINT WINAPI MsiCloseAllHandles();

#ifdef __cplusplus
}
#endif

#ifdef __cplusplus
class PMSIHANDLE {
  MSIHANDLE m_h;
public:
  PMSIHANDLE():m_h(0){}
  PMSIHANDLE(MSIHANDLE h):m_h(h) { }
  ~PMSIHANDLE() { if (m_h!=0) MsiCloseHandle (m_h); }
  void operator =(MSIHANDLE h) { if (m_h) MsiCloseHandle (m_h); m_h=h; }
  operator MSIHANDLE() { return m_h; }
  MSIHANDLE *operator &() { if (m_h) MsiCloseHandle (m_h); m_h = 0; return &m_h; }
};
#endif

typedef enum tagINSTALLMESSAGE {
  INSTALLMESSAGE_FATALEXIT = 0x00000000,INSTALLMESSAGE_ERROR = 0x01000000,INSTALLMESSAGE_WARNING = 0x02000000,INSTALLMESSAGE_USER = 0x03000000,
  INSTALLMESSAGE_INFO = 0x04000000,INSTALLMESSAGE_FILESINUSE = 0x05000000,INSTALLMESSAGE_RESOLVESOURCE = 0x06000000,
  INSTALLMESSAGE_OUTOFDISKSPACE = 0x07000000,INSTALLMESSAGE_ACTIONSTART = 0x08000000,INSTALLMESSAGE_ACTIONDATA = 0x09000000,
  INSTALLMESSAGE_PROGRESS = 0x0A000000,INSTALLMESSAGE_COMMONDATA = 0x0B000000,INSTALLMESSAGE_INITIALIZE = 0x0C000000,
  INSTALLMESSAGE_TERMINATE = 0x0D000000,INSTALLMESSAGE_SHOWDIALOG = 0x0E000000
#if _WIN32_MSI >= 400
  ,INSTALLMESSAGE_RMFILESINUSE = 0x19000000
#endif
#if _WIN32_MSI >= 450
  ,INSTALLMESSAGE_INSTALLSTART = 0x1A000000
  ,INSTALLMESSAGE_INSTALLEND = 0x1B000000
#endif
} INSTALLMESSAGE;

typedef int (WINAPI *INSTALLUI_HANDLERA)(LPVOID pvContext,UINT iMessageType,LPCSTR szMessage);
typedef int (WINAPI *INSTALLUI_HANDLERW)(LPVOID pvContext,UINT iMessageType,LPCWSTR szMessage);
#define INSTALLUI_HANDLER __MINGW_NAME_AW(INSTALLUI_HANDLER)

#if (_WIN32_MSI >= 310)
typedef int (WINAPI *INSTALLUI_HANDLER_RECORD)(LPVOID pvContext,UINT iMessageType,MSIHANDLE hRecord);
typedef INSTALLUI_HANDLER_RECORD *PINSTALLUI_HANDLER_RECORD;
#endif

typedef enum tagINSTALLUILEVEL {
  INSTALLUILEVEL_NOCHANGE = 0,INSTALLUILEVEL_DEFAULT = 1,INSTALLUILEVEL_NONE = 2,INSTALLUILEVEL_BASIC = 3,INSTALLUILEVEL_REDUCED = 4,
  INSTALLUILEVEL_FULL = 5,INSTALLUILEVEL_ENDDIALOG = 0x80,INSTALLUILEVEL_PROGRESSONLY = 0x40,INSTALLUILEVEL_HIDECANCEL = 0x20,
  INSTALLUILEVEL_SOURCERESONLY = 0x100
} INSTALLUILEVEL;

typedef enum tagINSTALLSTATE {
  INSTALLSTATE_NOTUSED = -7,INSTALLSTATE_BADCONFIG = -6,INSTALLSTATE_INCOMPLETE = -5,INSTALLSTATE_SOURCEABSENT = -4,INSTALLSTATE_MOREDATA = -3,
  INSTALLSTATE_INVALIDARG = -2,INSTALLSTATE_UNKNOWN = -1,INSTALLSTATE_BROKEN = 0,INSTALLSTATE_ADVERTISED = 1,INSTALLSTATE_REMOVED = 1,
  INSTALLSTATE_ABSENT = 2,INSTALLSTATE_LOCAL = 3,INSTALLSTATE_SOURCE = 4,INSTALLSTATE_DEFAULT = 5
} INSTALLSTATE;

typedef enum tagUSERINFOSTATE {
  USERINFOSTATE_MOREDATA = -3,USERINFOSTATE_INVALIDARG = -2,USERINFOSTATE_UNKNOWN = -1,USERINFOSTATE_ABSENT = 0,
  USERINFOSTATE_PRESENT = 1
} USERINFOSTATE;

typedef enum tagINSTALLLEVEL {
  INSTALLLEVEL_DEFAULT = 0,INSTALLLEVEL_MINIMUM = 1,INSTALLLEVEL_MAXIMUM = 0xffff
} INSTALLLEVEL;

typedef enum tagREINSTALLMODE {
  REINSTALLMODE_REPAIR = 0x00000001,REINSTALLMODE_FILEMISSING = 0x00000002,REINSTALLMODE_FILEOLDERVERSION = 0x00000004,
  REINSTALLMODE_FILEEQUALVERSION = 0x00000008,REINSTALLMODE_FILEEXACT = 0x00000010,REINSTALLMODE_FILEVERIFY = 0x00000020,
  REINSTALLMODE_FILEREPLACE = 0x00000040,REINSTALLMODE_MACHINEDATA = 0x00000080,REINSTALLMODE_USERDATA = 0x00000100,
  REINSTALLMODE_SHORTCUT = 0x00000200,REINSTALLMODE_PACKAGE = 0x00000400
} REINSTALLMODE;

typedef enum tagINSTALLOGMODE {
  INSTALLLOGMODE_FATALEXIT = (1 << (INSTALLMESSAGE_FATALEXIT >> 24)),INSTALLLOGMODE_ERROR = (1 << (INSTALLMESSAGE_ERROR >> 24)),
  INSTALLLOGMODE_WARNING = (1 << (INSTALLMESSAGE_WARNING >> 24)),INSTALLLOGMODE_USER = (1 << (INSTALLMESSAGE_USER >> 24)),
  INSTALLLOGMODE_INFO = (1 << (INSTALLMESSAGE_INFO >> 24)),INSTALLLOGMODE_RESOLVESOURCE = (1 << (INSTALLMESSAGE_RESOLVESOURCE >> 24)),
  INSTALLLOGMODE_OUTOFDISKSPACE = (1 << (INSTALLMESSAGE_OUTOFDISKSPACE >> 24)),INSTALLLOGMODE_ACTIONSTART = (1 << (INSTALLMESSAGE_ACTIONSTART >> 24)),
  INSTALLLOGMODE_ACTIONDATA = (1 << (INSTALLMESSAGE_ACTIONDATA >> 24)),INSTALLLOGMODE_COMMONDATA = (1 << (INSTALLMESSAGE_COMMONDATA >> 24)),
  INSTALLLOGMODE_PROPERTYDUMP = (1 << (INSTALLMESSAGE_PROGRESS >> 24)),INSTALLLOGMODE_VERBOSE = (1 << (INSTALLMESSAGE_INITIALIZE >> 24)),
  INSTALLLOGMODE_EXTRADEBUG = (1 << (INSTALLMESSAGE_TERMINATE >> 24)),INSTALLLOGMODE_LOGONLYONERROR = (1 << (INSTALLMESSAGE_SHOWDIALOG >> 24)),
  INSTALLLOGMODE_PROGRESS = (1 << (INSTALLMESSAGE_PROGRESS >> 24)),INSTALLLOGMODE_INITIALIZE = (1 << (INSTALLMESSAGE_INITIALIZE >> 24)),
  INSTALLLOGMODE_TERMINATE = (1 << (INSTALLMESSAGE_TERMINATE >> 24)),INSTALLLOGMODE_SHOWDIALOG = (1 << (INSTALLMESSAGE_SHOWDIALOG >> 24)),
  INSTALLLOGMODE_FILESINUSE = (1 << (INSTALLMESSAGE_FILESINUSE >> 24))
#if _WIN32_MSI >= 400
  ,INSTALLLOGMODE_RMFILESINUSE = (1 << (INSTALLMESSAGE_RMFILESINUSE >> 24))
#endif
#if _WIN32_MSI >= 450
  ,INSTALLLOGMODE_INSTALLSTART = (1 << (INSTALLMESSAGE_INSTALLSTART >> 24))
  ,INSTALLLOGMODE_INSTALLEND = (1 << (INSTALLMESSAGE_INSTALLEND >> 24))
#endif
} INSTALLLOGMODE;

typedef enum tagINSTALLLOGATTRIBUTES {
  INSTALLLOGATTRIBUTES_APPEND = (1 << 0),INSTALLLOGATTRIBUTES_FLUSHEACHLINE = (1 << 1)
} INSTALLLOGATTRIBUTES;

typedef enum tagINSTALLFEATUREATTRIBUTE {
  INSTALLFEATUREATTRIBUTE_FAVORLOCAL = 1 << 0,INSTALLFEATUREATTRIBUTE_FAVORSOURCE = 1 << 1,
  INSTALLFEATUREATTRIBUTE_FOLLOWPARENT = 1 << 2,INSTALLFEATUREATTRIBUTE_FAVORADVERTISE = 1 << 3,
  INSTALLFEATUREATTRIBUTE_DISALLOWADVERTISE = 1 << 4,INSTALLFEATUREATTRIBUTE_NOUNSUPPORTEDADVERTISE = 1 << 5
} INSTALLFEATUREATTRIBUTE;

typedef enum tagINSTALLMODE {
#if (_WIN32_MSI >= 150)
  INSTALLMODE_NODETECTION_ANY = -4,
#endif
  INSTALLMODE_NOSOURCERESOLUTION = -3,INSTALLMODE_NODETECTION = -2,INSTALLMODE_EXISTING = -1,INSTALLMODE_DEFAULT = 0
} INSTALLMODE;

#if (_WIN32_MSI >= 300)
typedef enum tagMSIPATCHSTATE {
  MSIPATCHSTATE_INVALID = 0,MSIPATCHSTATE_APPLIED = 1,MSIPATCHSTATE_SUPERSEDED = 2,MSIPATCHSTATE_OBSOLETED = 4,MSIPATCHSTATE_REGISTERED = 8,
  MSIPATCHSTATE_ALL = (MSIPATCHSTATE_APPLIED | MSIPATCHSTATE_SUPERSEDED | MSIPATCHSTATE_OBSOLETED | MSIPATCHSTATE_REGISTERED)
} MSIPATCHSTATE;

typedef enum tagMSIINSTALLCONTEXT {
  MSIINSTALLCONTEXT_FIRSTVISIBLE = 0,MSIINSTALLCONTEXT_NONE = 0,MSIINSTALLCONTEXT_USERMANAGED = 1,MSIINSTALLCONTEXT_USERUNMANAGED = 2,
  MSIINSTALLCONTEXT_MACHINE = 4,
  MSIINSTALLCONTEXT_ALL = (MSIINSTALLCONTEXT_USERMANAGED | MSIINSTALLCONTEXT_USERUNMANAGED | MSIINSTALLCONTEXT_MACHINE),
  MSIINSTALLCONTEXT_ALLUSERMANAGED = 8
} MSIINSTALLCONTEXT;

typedef enum tagMSIPATCHDATATYPE {
  MSIPATCH_DATATYPE_PATCHFILE = 0,MSIPATCH_DATATYPE_XMLPATH = 1,MSIPATCH_DATATYPE_XMLBLOB = 2
} MSIPATCHDATATYPE,*PMSIPATCHDATATYPE;

typedef struct tagMSIPATCHSEQUENCEINFOA {
  LPCSTR szPatchData;
  MSIPATCHDATATYPE ePatchDataType;
  DWORD dwOrder;
  UINT uStatus;
} MSIPATCHSEQUENCEINFOA,*PMSIPATCHSEQUENCEINFOA;

typedef struct tagMSIPATCHSEQUENCEINFOW {
  LPCWSTR szPatchData;
  MSIPATCHDATATYPE ePatchDataType;
  DWORD dwOrder;
  UINT uStatus;
} MSIPATCHSEQUENCEINFOW,*PMSIPATCHSEQUENCEINFOW;

__MINGW_TYPEDEF_AW(MSIPATCHSEQUENCEINFO)
__MINGW_TYPEDEF_AW(PMSIPATCHSEQUENCEINFO)
#endif

#define MAX_FEATURE_CHARS 38

#define INSTALLPROPERTY_PACKAGENAME __TEXT("PackageName")
#define INSTALLPROPERTY_TRANSFORMS __TEXT("Transforms")
#define INSTALLPROPERTY_LANGUAGE __TEXT("Language")
#define INSTALLPROPERTY_PRODUCTNAME __TEXT("ProductName")
#define INSTALLPROPERTY_ASSIGNMENTTYPE __TEXT("AssignmentType")
#if (_WIN32_MSI >= 150)
#define INSTALLPROPERTY_INSTANCETYPE __TEXT("InstanceType")
#endif
#if (_WIN32_MSI >= 300)
#define INSTALLPROPERTY_AUTHORIZED_LUA_APP __TEXT("AuthorizedLUAApp")
#endif

#define INSTALLPROPERTY_PACKAGECODE __TEXT("PackageCode")
#define INSTALLPROPERTY_VERSION __TEXT("Version")
#if (_WIN32_MSI >= 110)
#define INSTALLPROPERTY_PRODUCTICON __TEXT("ProductIcon")
#endif

#define INSTALLPROPERTY_INSTALLEDPRODUCTNAME __TEXT("InstalledProductName")
#define INSTALLPROPERTY_VERSIONSTRING __TEXT("VersionString")
#define INSTALLPROPERTY_HELPLINK __TEXT("HelpLink")
#define INSTALLPROPERTY_HELPTELEPHONE __TEXT("HelpTelephone")
#define INSTALLPROPERTY_INSTALLLOCATION __TEXT("InstallLocation")
#define INSTALLPROPERTY_INSTALLSOURCE __TEXT("InstallSource")
#define INSTALLPROPERTY_INSTALLDATE __TEXT("InstallDate")
#define INSTALLPROPERTY_PUBLISHER __TEXT("Publisher")
#define INSTALLPROPERTY_LOCALPACKAGE __TEXT("LocalPackage")
#define INSTALLPROPERTY_URLINFOABOUT __TEXT("URLInfoAbout")
#define INSTALLPROPERTY_URLUPDATEINFO __TEXT("URLUpdateInfo")
#define INSTALLPROPERTY_VERSIONMINOR __TEXT("VersionMinor")
#define INSTALLPROPERTY_VERSIONMAJOR __TEXT("VersionMajor")
#define INSTALLPROPERTY_PRODUCTID __TEXT("ProductID")
#define INSTALLPROPERTY_REGCOMPANY __TEXT("RegCompany")
#define INSTALLPROPERTY_REGOWNER __TEXT("RegOwner")

#if (_WIN32_MSI >= 300)
#define INSTALLPROPERTY_UNINSTALLABLE __TEXT("Uninstallable")
#define INSTALLPROPERTY_PRODUCTSTATE __TEXT("State")
#define INSTALLPROPERTY_PATCHSTATE __TEXT("State")
#define INSTALLPROPERTY_PATCHTYPE __TEXT("PatchType")
#define INSTALLPROPERTY_LUAENABLED __TEXT("LUAEnabled")
#define INSTALLPROPERTY_DISPLAYNAME __TEXT("DisplayName")
#define INSTALLPROPERTY_MOREINFOURL __TEXT("MoreInfoURL")

#define INSTALLPROPERTY_LASTUSEDSOURCE __TEXT("LastUsedSource")
#define INSTALLPROPERTY_LASTUSEDTYPE __TEXT("LastUsedType")
#define INSTALLPROPERTY_MEDIAPACKAGEPATH __TEXT("MediaPackagePath")
#define INSTALLPROPERTY_DISKPROMPT __TEXT("DiskPrompt")
#endif

typedef enum tagSCRIPTFLAGS {
  SCRIPTFLAGS_CACHEINFO = 0x00000001,SCRIPTFLAGS_SHORTCUTS = 0x00000004,SCRIPTFLAGS_MACHINEASSIGN = 0x00000008,
  SCRIPTFLAGS_REGDATA_CNFGINFO = 0x00000020,SCRIPTFLAGS_VALIDATE_TRANSFORMS_LIST = 0x00000040,
#if (_WIN32_MSI >= 110)
  SCRIPTFLAGS_REGDATA_CLASSINFO = 0x00000080,SCRIPTFLAGS_REGDATA_EXTENSIONINFO = 0x00000100,
  SCRIPTFLAGS_REGDATA_APPINFO = SCRIPTFLAGS_REGDATA_CLASSINFO | SCRIPTFLAGS_REGDATA_EXTENSIONINFO,
#else
  SCRIPTFLAGS_REGDATA_APPINFO = 0x00000010,
#endif
  SCRIPTFLAGS_REGDATA = SCRIPTFLAGS_REGDATA_APPINFO | SCRIPTFLAGS_REGDATA_CNFGINFO
} SCRIPTFLAGS;

typedef enum tagADVERTISEFLAGS {
  ADVERTISEFLAGS_MACHINEASSIGN = 0,ADVERTISEFLAGS_USERASSIGN = 1
} ADVERTISEFLAGS;

typedef enum tagINSTALLTYPE {
  INSTALLTYPE_DEFAULT = 0,INSTALLTYPE_NETWORK_IMAGE = 1,INSTALLTYPE_SINGLE_INSTANCE = 2
} INSTALLTYPE;

#if (_WIN32_MSI >= 150)
typedef struct _MSIFILEHASHINFO {
  ULONG dwFileHashInfoSize;
  ULONG dwData [4];
} MSIFILEHASHINFO,*PMSIFILEHASHINFO;

typedef enum tagMSIARCHITECTUREFLAGS {
  MSIARCHITECTUREFLAGS_X86 = 0x00000001,MSIARCHITECTUREFLAGS_IA64 = 0x00000002,MSIARCHITECTUREFLAGS_AMD64 = 0x00000004
} MSIARCHITECTUREFLAGS;

typedef enum tagMSIOPENPACKAGEFLAGS {
  MSIOPENPACKAGEFLAGS_IGNOREMACHINESTATE = 0x00000001
} MSIOPENPACKAGEFLAGS;

typedef enum tagMSIADVERTISEOPTIONFLAGS {
  MSIADVERTISEOPTIONFLAGS_INSTANCE = 0x00000001
} MSIADVERTISEOPTIONFLAGS;
#endif

#if (_WIN32_MSI >= 300)
typedef enum tagMSISOURCETYPE {
  MSISOURCETYPE_UNKNOWN = 0x00000000,MSISOURCETYPE_NETWORK = 0x00000001,MSISOURCETYPE_URL = 0x00000002,MSISOURCETYPE_MEDIA = 0x00000004
} MSISOURCETYPE;

typedef enum tagMSICODE {
  MSICODE_PRODUCT = 0x00000000,MSICODE_PATCH = 0x40000000
} MSICODE;

#if _WIN32_MSI >= 450
typedef enum tagMSITRANSACTION {
  MSITRANSACTION_CHAIN_EMBEDDEDUI = 0x00000001,
  MSITRANSACTION_JOIN_EXISTING_EMBEDDEDUI = 0x00000002
} MSITRANSACTION;

typedef enum tagMSITRANSACTIONSTATE {
  MSITRANSACTIONSTATE_ROLLBACK = 0x00000000,
  MSITRANSACTIONSTATE_COMMIT = 0x00000001
} MSITRANSACTIONSTATE;
#endif
#endif

#ifdef __cplusplus
extern "C" {
#endif

  INSTALLUILEVEL WINAPI MsiSetInternalUI(INSTALLUILEVEL dwUILevel,HWND *phWnd);
  INSTALLUI_HANDLERA WINAPI MsiSetExternalUIA(INSTALLUI_HANDLERA puiHandler,DWORD dwMessageFilter,LPVOID pvContext);
  INSTALLUI_HANDLERW WINAPI MsiSetExternalUIW(INSTALLUI_HANDLERW puiHandler,DWORD dwMessageFilter,LPVOID pvContext);
#define MsiSetExternalUI __MINGW_NAME_AW(MsiSetExternalUI)

#if (_WIN32_MSI >= 310)
  UINT WINAPI MsiSetExternalUIRecord(INSTALLUI_HANDLER_RECORD puiHandler,DWORD dwMessageFilter,LPVOID pvContext,PINSTALLUI_HANDLER_RECORD ppuiPrevHandler);
#endif

  UINT WINAPI MsiEnableLogA(DWORD dwLogMode,LPCSTR szLogFile,DWORD dwLogAttributes);
  UINT WINAPI MsiEnableLogW(DWORD dwLogMode,LPCWSTR szLogFile,DWORD dwLogAttributes);
#define MsiEnableLog __MINGW_NAME_AW(MsiEnableLog)

  INSTALLSTATE WINAPI MsiQueryProductStateA(LPCSTR szProduct);
  INSTALLSTATE WINAPI MsiQueryProductStateW(LPCWSTR szProduct);
#define MsiQueryProductState __MINGW_NAME_AW(MsiQueryProductState)

  UINT WINAPI MsiGetProductInfoA(LPCSTR szProduct,LPCSTR szAttribute,LPSTR lpValueBuf,DWORD *pcchValueBuf);
  UINT WINAPI MsiGetProductInfoW(LPCWSTR szProduct,LPCWSTR szAttribute,LPWSTR lpValueBuf,DWORD *pcchValueBuf);
#define MsiGetProductInfo __MINGW_NAME_AW(MsiGetProductInfo)

#if (_WIN32_MSI >= 300)
  UINT WINAPI MsiGetProductInfoExA(LPCSTR szProductCode,LPCSTR szUserSid,MSIINSTALLCONTEXT dwContext,LPCSTR szProperty,LPSTR szValue,LPDWORD pcchValue);
  UINT WINAPI MsiGetProductInfoExW(LPCWSTR szProductCode,LPCWSTR szUserSid,MSIINSTALLCONTEXT dwContext,LPCWSTR szProperty,LPWSTR szValue,LPDWORD pcchValue);
#define MsiGetProductInfoEx __MINGW_NAME_AW(MsiGetProductInfoEx)
#endif

  UINT WINAPI MsiInstallProductA(LPCSTR szPackagePath,LPCSTR szCommandLine);
  UINT WINAPI MsiInstallProductW(LPCWSTR szPackagePath,LPCWSTR szCommandLine);
#define MsiInstallProduct __MINGW_NAME_AW(MsiInstallProduct)

  UINT WINAPI MsiConfigureProductA(LPCSTR szProduct,int iInstallLevel,INSTALLSTATE eInstallState);
  UINT WINAPI MsiConfigureProductW(LPCWSTR szProduct,int iInstallLevel,INSTALLSTATE eInstallState);
#define MsiConfigureProduct __MINGW_NAME_AW(MsiConfigureProduct)

  UINT WINAPI MsiConfigureProductExA(LPCSTR szProduct,int iInstallLevel,INSTALLSTATE eInstallState,LPCSTR szCommandLine);
  UINT WINAPI MsiConfigureProductExW(LPCWSTR szProduct,int iInstallLevel,INSTALLSTATE eInstallState,LPCWSTR szCommandLine);
#define MsiConfigureProductEx __MINGW_NAME_AW(MsiConfigureProductEx)

  UINT WINAPI MsiReinstallProductA(LPCSTR szProduct,DWORD szReinstallMode);
  UINT WINAPI MsiReinstallProductW(LPCWSTR szProduct,DWORD szReinstallMode);
#define MsiReinstallProduct __MINGW_NAME_AW(MsiReinstallProduct)

#if (_WIN32_MSI >= 150)
  UINT WINAPI MsiAdvertiseProductExA(LPCSTR szPackagePath,LPCSTR szScriptfilePath,LPCSTR szTransforms,LANGID lgidLanguage,DWORD dwPlatform,DWORD dwOptions);
  UINT WINAPI MsiAdvertiseProductExW(LPCWSTR szPackagePath,LPCWSTR szScriptfilePath,LPCWSTR szTransforms,LANGID lgidLanguage,DWORD dwPlatform,DWORD dwOptions);
#define MsiAdvertiseProductEx __MINGW_NAME_AW(MsiAdvertiseProductEx)
#endif

  UINT WINAPI MsiAdvertiseProductA(LPCSTR szPackagePath,LPCSTR szScriptfilePath,LPCSTR szTransforms,LANGID lgidLanguage);
  UINT WINAPI MsiAdvertiseProductW(LPCWSTR szPackagePath,LPCWSTR szScriptfilePath,LPCWSTR szTransforms,LANGID lgidLanguage);
#define MsiAdvertiseProduct __MINGW_NAME_AW(MsiAdvertiseProduct)

#if (_WIN32_MSI >= 150)
  UINT WINAPI MsiProcessAdvertiseScriptA(LPCSTR szScriptFile,LPCSTR szIconFolder,HKEY hRegData,WINBOOL fShortcuts,WINBOOL fRemoveItems);
  UINT WINAPI MsiProcessAdvertiseScriptW(LPCWSTR szScriptFile,LPCWSTR szIconFolder,HKEY hRegData,WINBOOL fShortcuts,WINBOOL fRemoveItems);
#define MsiProcessAdvertiseScript __MINGW_NAME_AW(MsiProcessAdvertiseScript)
#endif

  UINT WINAPI MsiAdvertiseScriptA(LPCSTR szScriptFile,DWORD dwFlags,PHKEY phRegData,WINBOOL fRemoveItems);
  UINT WINAPI MsiAdvertiseScriptW(LPCWSTR szScriptFile,DWORD dwFlags,PHKEY phRegData,WINBOOL fRemoveItems);
#define MsiAdvertiseScript __MINGW_NAME_AW(MsiAdvertiseScript)

  UINT WINAPI MsiGetProductInfoFromScriptA(LPCSTR szScriptFile,LPSTR lpProductBuf39,LANGID *plgidLanguage,DWORD *pdwVersion,LPSTR lpNameBuf,DWORD *pcchNameBuf,LPSTR lpPackageBuf,DWORD *pcchPackageBuf);
  UINT WINAPI MsiGetProductInfoFromScriptW(LPCWSTR szScriptFile,LPWSTR lpProductBuf39,LANGID *plgidLanguage,DWORD *pdwVersion,LPWSTR lpNameBuf,DWORD *pcchNameBuf,LPWSTR lpPackageBuf,DWORD *pcchPackageBuf);
#define MsiGetProductInfoFromScript __MINGW_NAME_AW(MsiGetProductInfoFromScript)

  UINT WINAPI MsiGetProductCodeA(LPCSTR szComponent,LPSTR lpBuf39);
  UINT WINAPI MsiGetProductCodeW(LPCWSTR szComponent,LPWSTR lpBuf39);
#define MsiGetProductCode __MINGW_NAME_AW(MsiGetProductCode)

  USERINFOSTATE WINAPI MsiGetUserInfoA(LPCSTR szProduct,LPSTR lpUserNameBuf,DWORD *pcchUserNameBuf,LPSTR lpOrgNameBuf,DWORD *pcchOrgNameBuf,LPSTR lpSerialBuf,DWORD *pcchSerialBuf);
  USERINFOSTATE WINAPI MsiGetUserInfoW(LPCWSTR szProduct,LPWSTR lpUserNameBuf,DWORD *pcchUserNameBuf,LPWSTR lpOrgNameBuf,DWORD *pcchOrgNameBuf,LPWSTR lpSerialBuf,DWORD *pcchSerialBuf);
#define MsiGetUserInfo __MINGW_NAME_AW(MsiGetUserInfo)

  UINT WINAPI MsiCollectUserInfoA(LPCSTR szProduct);
  UINT WINAPI MsiCollectUserInfoW(LPCWSTR szProduct);
#define MsiCollectUserInfo __MINGW_NAME_AW(MsiCollectUserInfo)

  UINT WINAPI MsiApplyPatchA(LPCSTR szPatchPackage,LPCSTR szInstallPackage,INSTALLTYPE eInstallType,LPCSTR szCommandLine);
  UINT WINAPI MsiApplyPatchW(LPCWSTR szPatchPackage,LPCWSTR szInstallPackage,INSTALLTYPE eInstallType,LPCWSTR szCommandLine);
#define MsiApplyPatch __MINGW_NAME_AW(MsiApplyPatch)

  UINT WINAPI MsiGetPatchInfoA(LPCSTR szPatch,LPCSTR szAttribute,LPSTR lpValueBuf,DWORD *pcchValueBuf);
  UINT WINAPI MsiGetPatchInfoW(LPCWSTR szPatch,LPCWSTR szAttribute,LPWSTR lpValueBuf,DWORD *pcchValueBuf);
#define MsiGetPatchInfo __MINGW_NAME_AW(MsiGetPatchInfo)

  UINT WINAPI MsiEnumPatchesA(LPCSTR szProduct,DWORD iPatchIndex,LPSTR lpPatchBuf,LPSTR lpTransformsBuf,DWORD *pcchTransformsBuf);
  UINT WINAPI MsiEnumPatchesW(LPCWSTR szProduct,DWORD iPatchIndex,LPWSTR lpPatchBuf,LPWSTR lpTransformsBuf,DWORD *pcchTransformsBuf);
#define MsiEnumPatches __MINGW_NAME_AW(MsiEnumPatches)

#if (_WIN32_MSI >= 300)
  UINT WINAPI MsiRemovePatchesA(LPCSTR szPatchList,LPCSTR szProductCode,INSTALLTYPE eUninstallType,LPCSTR szPropertyList);
  UINT WINAPI MsiRemovePatchesW(LPCWSTR szPatchList,LPCWSTR szProductCode,INSTALLTYPE eUninstallType,LPCWSTR szPropertyList);
#define MsiRemovePatches __MINGW_NAME_AW(MsiRemovePatches)

  UINT WINAPI MsiExtractPatchXMLDataA(LPCSTR szPatchPath,DWORD dwReserved,LPSTR szXMLData,DWORD *pcchXMLData);
  UINT WINAPI MsiExtractPatchXMLDataW(LPCWSTR szPatchPath,DWORD dwReserved,LPWSTR szXMLData,DWORD *pcchXMLData);
#define MsiExtractPatchXMLData __MINGW_NAME_AW(MsiExtractPatchXMLData)

  UINT WINAPI MsiGetPatchInfoExA(LPCSTR szPatchCode,LPCSTR szProductCode,LPCSTR szUserSid,MSIINSTALLCONTEXT dwContext,LPCSTR szProperty,LPSTR lpValue,DWORD *pcchValue);
  UINT WINAPI MsiGetPatchInfoExW(LPCWSTR szPatchCode,LPCWSTR szProductCode,LPCWSTR szUserSid,MSIINSTALLCONTEXT dwContext,LPCWSTR szProperty,LPWSTR lpValue,DWORD *pcchValue);
#define MsiGetPatchInfoEx __MINGW_NAME_AW(MsiGetPatchInfoEx)

  UINT WINAPI MsiApplyMultiplePatchesA(LPCSTR szPatchPackages,LPCSTR szProductCode,LPCSTR szPropertiesList);
  UINT WINAPI MsiApplyMultiplePatchesW(LPCWSTR szPatchPackages,LPCWSTR szProductCode,LPCWSTR szPropertiesList);
#define MsiApplyMultiplePatches __MINGW_NAME_AW(MsiApplyMultiplePatches)

  UINT WINAPI MsiDeterminePatchSequenceA(LPCSTR szProductCode,LPCSTR szUserSid,MSIINSTALLCONTEXT dwContext,DWORD cPatchInfo,PMSIPATCHSEQUENCEINFOA pPatchInfo);
  UINT WINAPI MsiDeterminePatchSequenceW(LPCWSTR szProductCode,LPCWSTR szUserSid,MSIINSTALLCONTEXT dwContext,DWORD cPatchInfo,PMSIPATCHSEQUENCEINFOW pPatchInfo);
#define MsiDeterminePatchSequence __MINGW_NAME_AW(MsiDeterminePatchSequence)

  UINT WINAPI MsiDetermineApplicablePatchesA(LPCSTR szProductPackagePath,DWORD cPatchInfo,PMSIPATCHSEQUENCEINFOA pPatchInfo);
  UINT WINAPI MsiDetermineApplicablePatchesW(LPCWSTR szProductPackagePath,DWORD cPatchInfo,PMSIPATCHSEQUENCEINFOW pPatchInfo);
#define MsiDetermineApplicablePatches __MINGW_NAME_AW(MsiDetermineApplicablePatches)

  UINT WINAPI MsiEnumPatchesExA(LPCSTR szProductCode,LPCSTR szUserSid,DWORD dwContext,DWORD dwFilter,DWORD dwIndex,CHAR szPatchCode[39],CHAR szTargetProductCode[39],MSIINSTALLCONTEXT *pdwTargetProductContext,LPSTR szTargetUserSid,LPDWORD pcchTargetUserSid);
  UINT WINAPI MsiEnumPatchesExW(LPCWSTR szProductCode,LPCWSTR szUserSid,DWORD dwContext,DWORD dwFilter,DWORD dwIndex,WCHAR szPatchCode[39],WCHAR szTargetProductCode[39],MSIINSTALLCONTEXT *pdwTargetProductContext,LPWSTR szTargetUserSid,LPDWORD pcchTargetUserSid);
#define MsiEnumPatchesEx __MINGW_NAME_AW(MsiEnumPatchesEx)
#endif

  INSTALLSTATE WINAPI MsiQueryFeatureStateA(LPCSTR szProduct,LPCSTR szFeature);
  INSTALLSTATE WINAPI MsiQueryFeatureStateW(LPCWSTR szProduct,LPCWSTR szFeature);
#define MsiQueryFeatureState __MINGW_NAME_AW(MsiQueryFeatureState)

#if (_WIN32_MSI >= 300)
  UINT WINAPI MsiQueryFeatureStateExA(LPCSTR szProductCode,LPCSTR szUserSid,MSIINSTALLCONTEXT dwContext,LPCSTR szFeature,INSTALLSTATE *pdwState);
  UINT WINAPI MsiQueryFeatureStateExW(LPCWSTR szProductCode,LPCWSTR szUserSid,MSIINSTALLCONTEXT dwContext,LPCWSTR szFeature,INSTALLSTATE *pdwState);
#define MsiQueryFeatureStateEx __MINGW_NAME_AW(MsiQueryFeatureStateEx)
#endif

  INSTALLSTATE WINAPI MsiUseFeatureA(LPCSTR szProduct,LPCSTR szFeature);
  INSTALLSTATE WINAPI MsiUseFeatureW(LPCWSTR szProduct,LPCWSTR szFeature);
#define MsiUseFeature __MINGW_NAME_AW(MsiUseFeature)

  INSTALLSTATE WINAPI MsiUseFeatureExA(LPCSTR szProduct,LPCSTR szFeature,DWORD dwInstallMode,DWORD dwReserved);
  INSTALLSTATE WINAPI MsiUseFeatureExW(LPCWSTR szProduct,LPCWSTR szFeature,DWORD dwInstallMode,DWORD dwReserved);
#define MsiUseFeatureEx __MINGW_NAME_AW(MsiUseFeatureEx)

  UINT WINAPI MsiGetFeatureUsageA(LPCSTR szProduct,LPCSTR szFeature,DWORD *pdwUseCount,WORD *pwDateUsed);
  UINT WINAPI MsiGetFeatureUsageW(LPCWSTR szProduct,LPCWSTR szFeature,DWORD *pdwUseCount,WORD *pwDateUsed);
#define MsiGetFeatureUsage __MINGW_NAME_AW(MsiGetFeatureUsage)

  UINT WINAPI MsiConfigureFeatureA(LPCSTR szProduct,LPCSTR szFeature,INSTALLSTATE eInstallState);
  UINT WINAPI MsiConfigureFeatureW(LPCWSTR szProduct,LPCWSTR szFeature,INSTALLSTATE eInstallState);
#define MsiConfigureFeature __MINGW_NAME_AW(MsiConfigureFeature)

  UINT WINAPI MsiReinstallFeatureA(LPCSTR szProduct,LPCSTR szFeature,DWORD dwReinstallMode);
  UINT WINAPI MsiReinstallFeatureW(LPCWSTR szProduct,LPCWSTR szFeature,DWORD dwReinstallMode);
#define MsiReinstallFeature __MINGW_NAME_AW(MsiReinstallFeature)

  UINT WINAPI MsiProvideComponentA(LPCSTR szProduct,LPCSTR szFeature,LPCSTR szComponent,DWORD dwInstallMode,LPSTR lpPathBuf,DWORD *pcchPathBuf);
  UINT WINAPI MsiProvideComponentW(LPCWSTR szProduct,LPCWSTR szFeature,LPCWSTR szComponent,DWORD dwInstallMode,LPWSTR lpPathBuf,DWORD *pcchPathBuf);
#define MsiProvideComponent __MINGW_NAME_AW(MsiProvideComponent)

  UINT WINAPI MsiProvideQualifiedComponentA(LPCSTR szCategory,LPCSTR szQualifier,DWORD dwInstallMode,LPSTR lpPathBuf,DWORD *pcchPathBuf);
  UINT WINAPI MsiProvideQualifiedComponentW(LPCWSTR szCategory,LPCWSTR szQualifier,DWORD dwInstallMode,LPWSTR lpPathBuf,DWORD *pcchPathBuf);
#define MsiProvideQualifiedComponent __MINGW_NAME_AW(MsiProvideQualifiedComponent)

  UINT WINAPI MsiProvideQualifiedComponentExA(LPCSTR szCategory,LPCSTR szQualifier,DWORD dwInstallMode,LPCSTR szProduct,DWORD dwUnused1,DWORD dwUnused2,LPSTR lpPathBuf,DWORD *pcchPathBuf);
  UINT WINAPI MsiProvideQualifiedComponentExW(LPCWSTR szCategory,LPCWSTR szQualifier,DWORD dwInstallMode,LPCWSTR szProduct,DWORD dwUnused1,DWORD dwUnused2,LPWSTR lpPathBuf,DWORD *pcchPathBuf);
#define MsiProvideQualifiedComponentEx __MINGW_NAME_AW(MsiProvideQualifiedComponentEx)

  INSTALLSTATE WINAPI MsiGetComponentPathA(LPCSTR szProduct,LPCSTR szComponent,LPSTR lpPathBuf,DWORD *pcchBuf);
  INSTALLSTATE WINAPI MsiGetComponentPathW(LPCWSTR szProduct,LPCWSTR szComponent,LPWSTR lpPathBuf,DWORD *pcchBuf);
#define MsiGetComponentPath __MINGW_NAME_AW(MsiGetComponentPath)

#if (_WIN32_MSI >= 150)
#define MSIASSEMBLYINFO_NETASSEMBLY 0
#define MSIASSEMBLYINFO_WIN32ASSEMBLY 1

  UINT WINAPI MsiProvideAssemblyA(LPCSTR szAssemblyName,LPCSTR szAppContext,DWORD dwInstallMode,DWORD dwAssemblyInfo,LPSTR lpPathBuf,DWORD *pcchPathBuf);
  UINT WINAPI MsiProvideAssemblyW(LPCWSTR szAssemblyName,LPCWSTR szAppContext,DWORD dwInstallMode,DWORD dwAssemblyInfo,LPWSTR lpPathBuf,DWORD *pcchPathBuf);
#define MsiProvideAssembly __MINGW_NAME_AW(MsiProvideAssembly)
#endif

#if (_WIN32_MSI >= 300)
  UINT WINAPI MsiQueryComponentStateA(LPCSTR szProductCode,LPCSTR szUserSid,MSIINSTALLCONTEXT dwContext,LPCSTR szComponentCode,INSTALLSTATE *pdwState);
  UINT WINAPI MsiQueryComponentStateW(LPCWSTR szProductCode,LPCWSTR szUserSid,MSIINSTALLCONTEXT dwContext,LPCWSTR szComponentCode,INSTALLSTATE *pdwState);
#define MsiQueryComponentState __MINGW_NAME_AW(MsiQueryComponentState)
#endif

  UINT WINAPI MsiEnumProductsA(DWORD iProductIndex,LPSTR lpProductBuf);
  UINT WINAPI MsiEnumProductsW(DWORD iProductIndex,LPWSTR lpProductBuf);
#define MsiEnumProducts __MINGW_NAME_AW(MsiEnumProducts)

#if (_WIN32_MSI >= 300)
  UINT WINAPI MsiEnumProductsExA(LPCSTR szProductCode,LPCSTR szUserSid,DWORD dwContext,DWORD dwIndex,CHAR szInstalledProductCode[39],MSIINSTALLCONTEXT *pdwInstalledContext,LPSTR szSid,LPDWORD pcchSid);
  UINT WINAPI MsiEnumProductsExW(LPCWSTR szProductCode,LPCWSTR szUserSid,DWORD dwContext,DWORD dwIndex,WCHAR szInstalledProductCode[39],MSIINSTALLCONTEXT *pdwInstalledContext,LPWSTR szSid,LPDWORD pcchSid);

#define MsiEnumProductsEx __MINGW_NAME_AW(MsiEnumProductsEx)
#endif

#if (_WIN32_MSI >= 110)
  UINT WINAPI MsiEnumRelatedProductsA(LPCSTR lpUpgradeCode,DWORD dwReserved,DWORD iProductIndex,LPSTR lpProductBuf);
  UINT WINAPI MsiEnumRelatedProductsW(LPCWSTR lpUpgradeCode,DWORD dwReserved,DWORD iProductIndex,LPWSTR lpProductBuf);
#define MsiEnumRelatedProducts __MINGW_NAME_AW(MsiEnumRelatedProducts)
#endif

  UINT WINAPI MsiEnumFeaturesA(LPCSTR szProduct,DWORD iFeatureIndex,LPSTR lpFeatureBuf,LPSTR lpParentBuf);
  UINT WINAPI MsiEnumFeaturesW(LPCWSTR szProduct,DWORD iFeatureIndex,LPWSTR lpFeatureBuf,LPWSTR lpParentBuf);
#define MsiEnumFeatures __MINGW_NAME_AW(MsiEnumFeatures)

  UINT WINAPI MsiEnumComponentsA(DWORD iComponentIndex,LPSTR lpComponentBuf);
  UINT WINAPI MsiEnumComponentsW(DWORD iComponentIndex,LPWSTR lpComponentBuf);
#define MsiEnumComponents __MINGW_NAME_AW(MsiEnumComponents)

  UINT WINAPI MsiEnumClientsA(LPCSTR szComponent,DWORD iProductIndex,LPSTR lpProductBuf);
  UINT WINAPI MsiEnumClientsW(LPCWSTR szComponent,DWORD iProductIndex,LPWSTR lpProductBuf);
#define MsiEnumClients __MINGW_NAME_AW(MsiEnumClients)

  UINT WINAPI MsiEnumComponentQualifiersA(LPCSTR szComponent,DWORD iIndex,LPSTR lpQualifierBuf,DWORD *pcchQualifierBuf,LPSTR lpApplicationDataBuf,DWORD *pcchApplicationDataBuf);
  UINT WINAPI MsiEnumComponentQualifiersW(LPCWSTR szComponent,DWORD iIndex,LPWSTR lpQualifierBuf,DWORD *pcchQualifierBuf,LPWSTR lpApplicationDataBuf,DWORD *pcchApplicationDataBuf);
#define MsiEnumComponentQualifiers __MINGW_NAME_AW(MsiEnumComponentQualifiers)

  UINT WINAPI MsiOpenProductA(LPCSTR szProduct,MSIHANDLE *hProduct);
  UINT WINAPI MsiOpenProductW(LPCWSTR szProduct,MSIHANDLE *hProduct);
#define MsiOpenProduct __MINGW_NAME_AW(MsiOpenProduct)

  UINT WINAPI MsiOpenPackageA(LPCSTR szPackagePath,MSIHANDLE *hProduct);
  UINT WINAPI MsiOpenPackageW(LPCWSTR szPackagePath,MSIHANDLE *hProduct);
#define MsiOpenPackage __MINGW_NAME_AW(MsiOpenPackage)

#if (_WIN32_MSI >= 150)
  UINT WINAPI MsiOpenPackageExA(LPCSTR szPackagePath,DWORD dwOptions,MSIHANDLE *hProduct);
  UINT WINAPI MsiOpenPackageExW(LPCWSTR szPackagePath,DWORD dwOptions,MSIHANDLE *hProduct);
#define MsiOpenPackageEx __MINGW_NAME_AW(MsiOpenPackageEx)

#if _WIN32_MSI >= 400
UINT WINAPI MsiGetPatchFileListA(LPCSTR szProductCode, LPCSTR szPatchPackages, LPDWORD pcFiles, MSIHANDLE **pphFileRecords);
UINT WINAPI MsiGetPatchFileListW(LPCWSTR szProductCode, LPCWSTR szPatchPackages, LPDWORD pcFiles, MSIHANDLE **pphFileRecords);
#define MsiGetPatchFileList __MINGW_NAME_AW(MsiGetPatchFileList)
#endif
#endif

  UINT WINAPI MsiGetProductPropertyA(MSIHANDLE hProduct,LPCSTR szProperty,LPSTR lpValueBuf,DWORD *pcchValueBuf);
  UINT WINAPI MsiGetProductPropertyW(MSIHANDLE hProduct,LPCWSTR szProperty,LPWSTR lpValueBuf,DWORD *pcchValueBuf);
#define MsiGetProductProperty __MINGW_NAME_AW(MsiGetProductProperty)

  UINT WINAPI MsiVerifyPackageA(LPCSTR szPackagePath);
  UINT WINAPI MsiVerifyPackageW(LPCWSTR szPackagePath);
#define MsiVerifyPackage __MINGW_NAME_AW(MsiVerifyPackage)

  UINT WINAPI MsiGetFeatureInfoA(MSIHANDLE hProduct,LPCSTR szFeature,DWORD *lpAttributes,LPSTR lpTitleBuf,DWORD *pcchTitleBuf,LPSTR lpHelpBuf,DWORD *pcchHelpBuf);
  UINT WINAPI MsiGetFeatureInfoW(MSIHANDLE hProduct,LPCWSTR szFeature,DWORD *lpAttributes,LPWSTR lpTitleBuf,DWORD *pcchTitleBuf,LPWSTR lpHelpBuf,DWORD *pcchHelpBuf);
#define MsiGetFeatureInfo __MINGW_NAME_AW(MsiGetFeatureInfo)

  UINT WINAPI MsiInstallMissingComponentA(LPCSTR szProduct,LPCSTR szComponent,INSTALLSTATE eInstallState);
  UINT WINAPI MsiInstallMissingComponentW(LPCWSTR szProduct,LPCWSTR szComponent,INSTALLSTATE eInstallState);
#define MsiInstallMissingComponent __MINGW_NAME_AW(MsiInstallMissingComponent)

  UINT WINAPI MsiInstallMissingFileA(LPCSTR szProduct,LPCSTR szFile);
  UINT WINAPI MsiInstallMissingFileW(LPCWSTR szProduct,LPCWSTR szFile);
#define MsiInstallMissingFile __MINGW_NAME_AW(MsiInstallMissingFile)

  INSTALLSTATE WINAPI MsiLocateComponentA(LPCSTR szComponent,LPSTR lpPathBuf,DWORD *pcchBuf);
  INSTALLSTATE WINAPI MsiLocateComponentW(LPCWSTR szComponent,LPWSTR lpPathBuf,DWORD *pcchBuf);
#define MsiLocateComponent __MINGW_NAME_AW(MsiLocateComponent)

#if (_WIN32_MSI >= 110)
  UINT WINAPI MsiSourceListClearAllA(LPCSTR szProduct,LPCSTR szUserName,DWORD dwReserved);
  UINT WINAPI MsiSourceListClearAllW(LPCWSTR szProduct,LPCWSTR szUserName,DWORD dwReserved);
#define MsiSourceListClearAll __MINGW_NAME_AW(MsiSourceListClearAll)

  UINT WINAPI MsiSourceListAddSourceA(LPCSTR szProduct,LPCSTR szUserName,DWORD dwReserved,LPCSTR szSource);
  UINT WINAPI MsiSourceListAddSourceW(LPCWSTR szProduct,LPCWSTR szUserName,DWORD dwReserved,LPCWSTR szSource);
#define MsiSourceListAddSource __MINGW_NAME_AW(MsiSourceListAddSource)

  UINT WINAPI MsiSourceListForceResolutionA(LPCSTR szProduct,LPCSTR szUserName,DWORD dwReserved);
  UINT WINAPI MsiSourceListForceResolutionW(LPCWSTR szProduct,LPCWSTR szUserName,DWORD dwReserved);
#define MsiSourceListForceResolution __MINGW_NAME_AW(MsiSourceListForceResolution)
#endif

#if (_WIN32_MSI >= 300)
  UINT WINAPI MsiSourceListAddSourceExA(LPCSTR szProductCodeOrPatchCode,LPCSTR szUserSid,MSIINSTALLCONTEXT dwContext,DWORD dwOptions,LPCSTR szSource,DWORD dwIndex);
  UINT WINAPI MsiSourceListAddSourceExW(LPCWSTR szProductCodeOrPatchCode,LPCWSTR szUserSid,MSIINSTALLCONTEXT dwContext,DWORD dwOptions,LPCWSTR szSource,DWORD dwIndex);
#define MsiSourceListAddSourceEx __MINGW_NAME_AW(MsiSourceListAddSourceEx)

  UINT WINAPI MsiSourceListAddMediaDiskA(LPCSTR szProductCodeOrPatchCode,LPCSTR szUserSid,MSIINSTALLCONTEXT dwContext,DWORD dwOptions,DWORD dwDiskId,LPCSTR szVolumeLabel,LPCSTR szDiskPrompt);
  UINT WINAPI MsiSourceListAddMediaDiskW(LPCWSTR szProductCodeOrPatchCode,LPCWSTR szUserSid,MSIINSTALLCONTEXT dwContext,DWORD dwOptions,DWORD dwDiskId,LPCWSTR szVolumeLabel,LPCWSTR szDiskPrompt);
#define MsiSourceListAddMediaDisk __MINGW_NAME_AW(MsiSourceListAddMediaDisk)

  UINT WINAPI MsiSourceListClearSourceA(LPCSTR szProductCodeOrPatchCode,LPCSTR szUserSid,MSIINSTALLCONTEXT dwContext,DWORD dwOptions,LPCSTR szSource);
  UINT WINAPI MsiSourceListClearSourceW(LPCWSTR szProductCodeOrPatchCode,LPCWSTR szUserSid,MSIINSTALLCONTEXT dwContext,DWORD dwOptions,LPCWSTR szSource);
#define MsiSourceListClearSource __MINGW_NAME_AW(MsiSourceListClearSource)

  UINT WINAPI MsiSourceListClearMediaDiskA(LPCSTR szProductCodeOrPatchCode,LPCSTR szUserSid,MSIINSTALLCONTEXT dwContext,DWORD dwOptions,DWORD dwDiskId);
  UINT WINAPI MsiSourceListClearMediaDiskW(LPCWSTR szProductCodeOrPatchCode,LPCWSTR szUserSid,MSIINSTALLCONTEXT dwContext,DWORD dwOptions,DWORD dwDiskId);
#define MsiSourceListClearMediaDisk __MINGW_NAME_AW(MsiSourceListClearMediaDisk)

  UINT WINAPI MsiSourceListClearAllExA(LPCSTR szProductCodeOrPatchCode,LPCSTR szUserSid,MSIINSTALLCONTEXT dwContext,DWORD dwOptions);
  UINT WINAPI MsiSourceListClearAllExW(LPCWSTR szProductCodeOrPatchCode,LPCWSTR szUserSid,MSIINSTALLCONTEXT dwContext,DWORD dwOptions);
#define MsiSourceListClearAllEx __MINGW_NAME_AW(MsiSourceListClearAllEx)

  UINT WINAPI MsiSourceListForceResolutionExA(LPCSTR szProductCodeOrPatchCode,LPCSTR szUserSid,MSIINSTALLCONTEXT dwContext,DWORD dwOptions);
  UINT WINAPI MsiSourceListForceResolutionExW(LPCWSTR szProductCodeOrPatchCode,LPCWSTR szUserSid,MSIINSTALLCONTEXT dwContext,DWORD dwOptions);
#define MsiSourceListForceResolutionEx __MINGW_NAME_AW(MsiSourceListForceResolutionEx)

  UINT WINAPI MsiSourceListSetInfoA(LPCSTR szProductCodeOrPatchCode,LPCSTR szUserSid,MSIINSTALLCONTEXT dwContext,DWORD dwOptions,LPCSTR szProperty,LPCSTR szValue);
  UINT WINAPI MsiSourceListSetInfoW(LPCWSTR szProductCodeOrPatchCode,LPCWSTR szUserSid,MSIINSTALLCONTEXT dwContext,DWORD dwOptions,LPCWSTR szProperty,LPCWSTR szValue);
#define MsiSourceListSetInfo __MINGW_NAME_AW(MsiSourceListSetInfo)

  UINT WINAPI MsiSourceListGetInfoA(LPCSTR szProductCodeOrPatchCode,LPCSTR szUserSid,MSIINSTALLCONTEXT dwContext,DWORD dwOptions,LPCSTR szProperty,LPSTR szValue,LPDWORD pcchValue);
  UINT WINAPI MsiSourceListGetInfoW(LPCWSTR szProductCodeOrPatchCode,LPCWSTR szUserSid,MSIINSTALLCONTEXT dwContext,DWORD dwOptions,LPCWSTR szProperty,LPWSTR szValue,LPDWORD pcchValue);
#define MsiSourceListGetInfo __MINGW_NAME_AW(MsiSourceListGetInfo)

  UINT WINAPI MsiSourceListEnumSourcesA(LPCSTR szProductCodeOrPatchCode,LPCSTR szUserSid,MSIINSTALLCONTEXT dwContext,DWORD dwOptions,DWORD dwIndex,LPSTR szSource,LPDWORD pcchSource);
  UINT WINAPI MsiSourceListEnumSourcesW(LPCWSTR szProductCodeOrPatchCode,LPCWSTR szUserSid,MSIINSTALLCONTEXT dwContext,DWORD dwOptions,DWORD dwIndex,LPWSTR szSource,LPDWORD pcchSource);
#define MsiSourceListEnumSources __MINGW_NAME_AW(MsiSourceListEnumSources)

  UINT WINAPI MsiSourceListEnumMediaDisksA(LPCSTR szProductCodeOrPatchCode,LPCSTR szUserSid,MSIINSTALLCONTEXT dwContext,DWORD dwOptions,DWORD dwIndex,LPDWORD pdwDiskId,LPSTR szVolumeLabel,LPDWORD pcchVolumeLabel,LPSTR szDiskPrompt,LPDWORD pcchDiskPrompt);
  UINT WINAPI MsiSourceListEnumMediaDisksW(LPCWSTR szProductCodeOrPatchCode,LPCWSTR szUserSid,MSIINSTALLCONTEXT dwContext,DWORD dwOptions,DWORD dwIndex,LPDWORD pdwDiskId,LPWSTR szVolumeLabel,LPDWORD pcchVolumeLabel,LPWSTR szDiskPrompt,LPDWORD pcchDiskPrompt);
#define MsiSourceListEnumMediaDisks __MINGW_NAME_AW(MsiSourceListEnumMediaDisks)
#endif

  UINT WINAPI MsiGetFileVersionA(LPCSTR szFilePath,LPSTR lpVersionBuf,DWORD *pcchVersionBuf,LPSTR lpLangBuf,DWORD *pcchLangBuf);
  UINT WINAPI MsiGetFileVersionW(LPCWSTR szFilePath,LPWSTR lpVersionBuf,DWORD *pcchVersionBuf,LPWSTR lpLangBuf,DWORD *pcchLangBuf);
#define MsiGetFileVersion __MINGW_NAME_AW(MsiGetFileVersion)

#if (_WIN32_MSI >= 150)
  UINT WINAPI MsiGetFileHashA(LPCSTR szFilePath,DWORD dwOptions,PMSIFILEHASHINFO pHash);
  UINT WINAPI MsiGetFileHashW(LPCWSTR szFilePath,DWORD dwOptions,PMSIFILEHASHINFO pHash);
#define MsiGetFileHash __MINGW_NAME_AW(MsiGetFileHash)

#ifndef _MSI_NO_CRYPTO
  HRESULT WINAPI MsiGetFileSignatureInformationA(LPCSTR szSignedObjectPath,DWORD dwFlags,PCCERT_CONTEXT *ppcCertContext,BYTE *pbHashData,DWORD *pcbHashData);
  HRESULT WINAPI MsiGetFileSignatureInformationW(LPCWSTR szSignedObjectPath,DWORD dwFlags,PCCERT_CONTEXT *ppcCertContext,BYTE *pbHashData,DWORD *pcbHashData);
#define MsiGetFileSignatureInformation __MINGW_NAME_AW(MsiGetFileSignatureInformation)

#define MSI_INVALID_HASH_IS_FATAL 0x1
#endif
#endif

#if (_WIN32_MSI >= 110)
  UINT WINAPI MsiGetShortcutTargetA(LPCSTR szShortcutPath,LPSTR szProductCode,LPSTR szFeatureId,LPSTR szComponentCode);
  UINT WINAPI MsiGetShortcutTargetW(LPCWSTR szShortcutPath,LPWSTR szProductCode,LPWSTR szFeatureId,LPWSTR szComponentCode);
#define MsiGetShortcutTarget __MINGW_NAME_AW(MsiGetShortcutTarget)

  UINT WINAPI MsiIsProductElevatedA(LPCSTR szProduct,WINBOOL *pfElevated);
  UINT WINAPI MsiIsProductElevatedW(LPCWSTR szProduct,WINBOOL *pfElevated);
#define MsiIsProductElevated __MINGW_NAME_AW(MsiIsProductElevated)
#endif

#if (_WIN32_MSI >= 310)
  UINT WINAPI MsiNotifySidChangeA(LPCSTR pOldSid,LPCSTR pNewSid);
  UINT WINAPI MsiNotifySidChangeW(LPCWSTR pOldSid,LPCWSTR pNewSid);
#define MsiNotifySidChange __MINGW_NAME_AW(MsiNotifySidChange)

#if _WIN32_MSI >= 450
UINT WINAPI MsiBeginTransactionA(LPCSTR szName, DWORD dwTransactionAttributes, MSIHANDLE *phTransactionHandle, HANDLE *phChangeOfOwnerEvent);
UINT WINAPI MsiBeginTransactionW(LPCWSTR szName, DWORD dwTransactionAttributes, MSIHANDLE *phTransactionHandle, HANDLE *phChangeOfOwnerEvent);
#define MsiBeginTransaction __MINGW_NAME_AW(MsiBeginTransaction)

UINT WINAPI MsiEndTransaction(DWORD dwTransactionState);
UINT WINAPI MsiJoinTransaction(MSIHANDLE hTransactionHandle, DWORD dwTransactionAttributes, HANDLE *phChangeOfOwnerEvent);
#endif
#endif

#ifdef __cplusplus
}
#endif

#ifndef ERROR_INSTALL_FAILURE
#define ERROR_INSTALL_USEREXIT __MSABI_LONG(1602)
#define ERROR_INSTALL_FAILURE __MSABI_LONG(1603)
#define ERROR_INSTALL_SUSPEND __MSABI_LONG(1604)

#define ERROR_UNKNOWN_PRODUCT __MSABI_LONG(1605)

#define ERROR_UNKNOWN_FEATURE __MSABI_LONG(1606)
#define ERROR_UNKNOWN_COMPONENT __MSABI_LONG(1607)
#define ERROR_UNKNOWN_PROPERTY __MSABI_LONG(1608)
#define ERROR_INVALID_HANDLE_STATE __MSABI_LONG(1609)

#define ERROR_BAD_CONFIGURATION __MSABI_LONG(1610)

#define ERROR_INDEX_ABSENT __MSABI_LONG(1611)

#define ERROR_INSTALL_SOURCE_ABSENT __MSABI_LONG(1612)

#define ERROR_PRODUCT_UNINSTALLED __MSABI_LONG(1614)
#define ERROR_BAD_QUERY_SYNTAX __MSABI_LONG(1615)
#define ERROR_INVALID_FIELD __MSABI_LONG(1616)
#endif

#ifndef ERROR_INSTALL_SERVICE_FAILURE
#define ERROR_INSTALL_SERVICE_FAILURE __MSABI_LONG(1601)
#define ERROR_INSTALL_PACKAGE_VERSION __MSABI_LONG(1613)
#define ERROR_INSTALL_ALREADY_RUNNING __MSABI_LONG(1618)
#define ERROR_INSTALL_PACKAGE_OPEN_FAILED __MSABI_LONG(1619)
#define ERROR_INSTALL_PACKAGE_INVALID __MSABI_LONG(1620)
#define ERROR_INSTALL_UI_FAILURE __MSABI_LONG(1621)
#define ERROR_INSTALL_LOG_FAILURE __MSABI_LONG(1622)
#define ERROR_INSTALL_LANGUAGE_UNSUPPORTED __MSABI_LONG(1623)
#define ERROR_INSTALL_PACKAGE_REJECTED __MSABI_LONG(1625)

#define ERROR_FUNCTION_NOT_CALLED __MSABI_LONG(1626)
#define ERROR_FUNCTION_FAILED __MSABI_LONG(1627)
#define ERROR_INVALID_TABLE __MSABI_LONG(1628)
#define ERROR_DATATYPE_MISMATCH __MSABI_LONG(1629)
#define ERROR_UNSUPPORTED_TYPE __MSABI_LONG(1630)

#define ERROR_CREATE_FAILED __MSABI_LONG(1631)
#endif

#ifndef ERROR_INSTALL_TEMP_UNWRITABLE
#define ERROR_INSTALL_TEMP_UNWRITABLE __MSABI_LONG(1632)
#endif

#ifndef ERROR_INSTALL_PLATFORM_UNSUPPORTED
#define ERROR_INSTALL_PLATFORM_UNSUPPORTED __MSABI_LONG(1633)
#endif

#ifndef ERROR_INSTALL_NOTUSED
#define ERROR_INSTALL_NOTUSED __MSABI_LONG(1634)
#endif

#ifndef ERROR_INSTALL_TRANSFORM_FAILURE
#define ERROR_INSTALL_TRANSFORM_FAILURE __MSABI_LONG(1624)
#endif

#ifndef ERROR_PATCH_PACKAGE_OPEN_FAILED
#define ERROR_PATCH_PACKAGE_OPEN_FAILED __MSABI_LONG(1635)
#define ERROR_PATCH_PACKAGE_INVALID __MSABI_LONG(1636)
#define ERROR_PATCH_PACKAGE_UNSUPPORTED __MSABI_LONG(1637)
#endif

#ifndef ERROR_PRODUCT_VERSION
#define ERROR_PRODUCT_VERSION __MSABI_LONG(1638)
#endif

#ifndef ERROR_INVALID_COMMAND_LINE
#define ERROR_INVALID_COMMAND_LINE __MSABI_LONG(1639)
#endif

#ifndef ERROR_INSTALL_REMOTE_DISALLOWED
#define ERROR_INSTALL_REMOTE_DISALLOWED __MSABI_LONG(1640)
#endif

#ifndef ERROR_SUCCESS_REBOOT_INITIATED
#define ERROR_SUCCESS_REBOOT_INITIATED __MSABI_LONG(1641)
#endif

#ifndef ERROR_PATCH_TARGET_NOT_FOUND
#define ERROR_PATCH_TARGET_NOT_FOUND __MSABI_LONG(1642)
#endif

#ifndef ERROR_PATCH_PACKAGE_REJECTED
#define ERROR_PATCH_PACKAGE_REJECTED __MSABI_LONG(1643)
#endif

#ifndef ERROR_INSTALL_TRANSFORM_REJECTED
#define ERROR_INSTALL_TRANSFORM_REJECTED __MSABI_LONG(1644)
#endif

#ifndef ERROR_INSTALL_REMOTE_PROHIBITED
#define ERROR_INSTALL_REMOTE_PROHIBITED __MSABI_LONG(1645)
#endif

#ifndef ERROR_PATCH_REMOVAL_UNSUPPORTED
#define ERROR_PATCH_REMOVAL_UNSUPPORTED __MSABI_LONG(1646)
#endif

#ifndef ERROR_UNKNOWN_PATCH
#define ERROR_UNKNOWN_PATCH __MSABI_LONG(1647)
#endif

#ifndef ERROR_PATCH_NO_SEQUENCE
#define ERROR_PATCH_NO_SEQUENCE __MSABI_LONG(1648)
#endif

#ifndef ERROR_PATCH_REMOVAL_DISALLOWED
#define ERROR_PATCH_REMOVAL_DISALLOWED __MSABI_LONG(1649)
#endif

#ifndef ERROR_INVALID_PATCH_XML
#define ERROR_INVALID_PATCH_XML __MSABI_LONG(1650)
#endif

#ifndef ERROR_PATCH_MANAGED_ADVERTISED_PRODUCT
#define ERROR_PATCH_MANAGED_ADVERTISED_PRODUCT __MSABI_LONG(1651)
#endif

#ifndef ERROR_INSTALL_SERVICE_SAFEBOOT
#define ERROR_INSTALL_SERVICE_SAFEBOOT __MSABI_LONG(1652)
#endif

#ifndef ERROR_ROLLBACK_DISABLED
#define ERROR_ROLLBACK_DISABLED __MSABI_LONG(1653)
#endif

#endif

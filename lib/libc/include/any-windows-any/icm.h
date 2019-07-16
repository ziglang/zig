/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _ICM_H_
#define _ICM_H_

#include <_mingw_unicode.h>

#ifdef __cplusplus
extern "C" {
#endif

  typedef char COLOR_NAME[32];
  typedef COLOR_NAME *PCOLOR_NAME,*LPCOLOR_NAME;

  typedef struct tagNAMED_PROFILE_INFO {
    DWORD dwFlags;
    DWORD dwCount;
    DWORD dwCountDevCoordinates;
    COLOR_NAME szPrefix;
    COLOR_NAME szSuffix;
  } NAMED_PROFILE_INFO;
  typedef NAMED_PROFILE_INFO *PNAMED_PROFILE_INFO,*LPNAMED_PROFILE_INFO;

#define MAX_COLOR_CHANNELS 8

  struct GRAYCOLOR {
    WORD gray;
  };

  struct RGBCOLOR {
    WORD red;
    WORD green;
    WORD blue;
  };

  struct CMYKCOLOR {
    WORD cyan;
    WORD magenta;
    WORD yellow;
    WORD black;
  };

  struct XYZCOLOR {
    WORD X;
    WORD Y;
    WORD Z;
  };

  struct YxyCOLOR {
    WORD Y;
    WORD x;
    WORD y;
  };

  struct LabCOLOR {
    WORD L;
    WORD a;
    WORD b;
  };

  struct GENERIC3CHANNEL {
    WORD ch1;
    WORD ch2;
    WORD ch3;
  };

  struct NAMEDCOLOR {
    DWORD dwIndex;
  };

  struct HiFiCOLOR {
    BYTE channel[MAX_COLOR_CHANNELS];
  };

  typedef union tagCOLOR {
    struct GRAYCOLOR gray;
    struct RGBCOLOR rgb;
    struct CMYKCOLOR cmyk;
    struct XYZCOLOR XYZ;
    struct YxyCOLOR Yxy;
    struct LabCOLOR Lab;
    struct GENERIC3CHANNEL gen3ch;
    struct NAMEDCOLOR named;
    struct HiFiCOLOR hifi;
    struct {
      DWORD reserved1;
      VOID *reserved2;
    };
  } COLOR;
  typedef COLOR *PCOLOR,*LPCOLOR;

  typedef enum {
    COLOR_GRAY = 1,COLOR_RGB,COLOR_XYZ,COLOR_Yxy,COLOR_Lab,COLOR_3_CHANNEL,COLOR_CMYK,COLOR_5_CHANNEL,COLOR_6_CHANNEL,COLOR_7_CHANNEL,
    COLOR_8_CHANNEL,COLOR_NAMED
  } COLORTYPE;
  typedef COLORTYPE *PCOLORTYPE,*LPCOLORTYPE;

  typedef enum {
    BM_x555RGB = 0x0000,BM_x555XYZ = 0x0101,BM_x555Yxy,BM_x555Lab,BM_x555G3CH,BM_RGBTRIPLETS = 0x0002,BM_BGRTRIPLETS = 0x0004,BM_XYZTRIPLETS = 0x0201,
    BM_YxyTRIPLETS,BM_LabTRIPLETS,BM_G3CHTRIPLETS,BM_5CHANNEL,BM_6CHANNEL,BM_7CHANNEL,BM_8CHANNEL,BM_GRAY,BM_xRGBQUADS = 0x0008,BM_xBGRQUADS = 0x0010,
    BM_xG3CHQUADS = 0x0304,BM_KYMCQUADS,BM_CMYKQUADS = 0x0020,BM_10b_RGB = 0x0009,BM_10b_XYZ = 0x0401,BM_10b_Yxy,BM_10b_Lab,BM_10b_G3CH,BM_NAMED_INDEX,
    BM_16b_RGB = 0x000A,BM_16b_XYZ = 0x0501,BM_16b_Yxy,BM_16b_Lab,BM_16b_G3CH,BM_16b_GRAY,BM_565RGB = 0x0001
  } BMFORMAT;
  typedef BMFORMAT *PBMFORMAT,*LPBMFORMAT;

  typedef WINBOOL (WINAPI *PBMCALLBACKFN)(ULONG,ULONG,LPARAM);
  typedef PBMCALLBACKFN LPBMCALLBACKFN;

  typedef struct tagPROFILEHEADER {
    DWORD phSize;
    DWORD phCMMType;
    DWORD phVersion;
    DWORD phClass;
    DWORD phDataColorSpace;
    DWORD phConnectionSpace;
    DWORD phDateTime[3];
    DWORD phSignature;
    DWORD phPlatform;
    DWORD phProfileFlags;
    DWORD phManufacturer;
    DWORD phModel;
    DWORD phAttributes[2];
    DWORD phRenderingIntent;
    CIEXYZ phIlluminant;
    DWORD phCreator;
    BYTE phReserved[44];
  } PROFILEHEADER;
  typedef PROFILEHEADER *PPROFILEHEADER,*LPPROFILEHEADER;

#define CLASS_MONITOR 'mntr'
#define CLASS_PRINTER 'prtr'
#define CLASS_SCANNER 'scnr'
#define CLASS_LINK 'link'
#define CLASS_ABSTRACT 'abst'
#define CLASS_COLORSPACE 'spac'
#define CLASS_NAMED 'nmcl'

#define SPACE_XYZ 'XYZ '
#define SPACE_Lab 'Lab '
#define SPACE_Luv 'Luv '
#define SPACE_YCbCr 'YCbr'
#define SPACE_Yxy 'Yxy '
#define SPACE_RGB 'RGB '
#define SPACE_GRAY 'GRAY'
#define SPACE_HSV 'HSV '
#define SPACE_HLS 'HLS '
#define SPACE_CMYK 'CMYK'
#define SPACE_CMY 'CMY '
#define SPACE_2_CHANNEL '2CLR'
#define SPACE_3_CHANNEL '3CLR'
#define SPACE_4_CHANNEL '4CLR'
#define SPACE_5_CHANNEL '5CLR'
#define SPACE_6_CHANNEL '6CLR'
#define SPACE_7_CHANNEL '7CLR'
#define SPACE_8_CHANNEL '8CLR'

#define FLAG_EMBEDDEDPROFILE 0x00000001
#define FLAG_DEPENDENTONDATA 0x00000002

#define ATTRIB_TRANSPARENCY 0x00000001
#define ATTRIB_MATTE 0x00000002

#define INTENT_PERCEPTUAL 0
#define INTENT_RELATIVE_COLORIMETRIC 1
#define INTENT_SATURATION 2
#define INTENT_ABSOLUTE_COLORIMETRIC 3

  typedef struct tagPROFILE {
    DWORD dwType;
    PVOID pProfileData;
    DWORD cbDataSize;
  } PROFILE;
  typedef PROFILE *PPROFILE,*LPPROFILE;

#define PROFILE_FILENAME 1
#define PROFILE_MEMBUFFER 2

#define PROFILE_READ 1
#define PROFILE_READWRITE 2

  typedef HANDLE HPROFILE;
  typedef HPROFILE *PHPROFILE;
  typedef HANDLE HTRANSFORM;

#define INDEX_DONT_CARE 0

#define CMM_FROM_PROFILE INDEX_DONT_CARE
#define CMM_WINDOWS_DEFAULT 'Win '

  typedef DWORD TAGTYPE;
  typedef TAGTYPE *PTAGTYPE,*LPTAGTYPE;

#define ENUM_TYPE_VERSION 0x0300

  typedef struct tagENUMTYPEA {
    DWORD dwSize;
    DWORD dwVersion;
    DWORD dwFields;
    PCSTR pDeviceName;
    DWORD dwMediaType;
    DWORD dwDitheringMode;
    DWORD dwResolution[2];
    DWORD dwCMMType;
    DWORD dwClass;
    DWORD dwDataColorSpace;
    DWORD dwConnectionSpace;
    DWORD dwSignature;
    DWORD dwPlatform;
    DWORD dwProfileFlags;
    DWORD dwManufacturer;
    DWORD dwModel;
    DWORD dwAttributes[2];
    DWORD dwRenderingIntent;
    DWORD dwCreator;
    DWORD dwDeviceClass;
  } ENUMTYPEA,*PENUMTYPEA,*LPENUMTYPEA;

  typedef struct tagENUMTYPEW {
    DWORD dwSize;
    DWORD dwVersion;
    DWORD dwFields;
    PCWSTR pDeviceName;
    DWORD dwMediaType;
    DWORD dwDitheringMode;
    DWORD dwResolution[2];
    DWORD dwCMMType;
    DWORD dwClass;
    DWORD dwDataColorSpace;
    DWORD dwConnectionSpace;
    DWORD dwSignature;
    DWORD dwPlatform;
    DWORD dwProfileFlags;
    DWORD dwManufacturer;
    DWORD dwModel;
    DWORD dwAttributes[2];
    DWORD dwRenderingIntent;
    DWORD dwCreator;
    DWORD dwDeviceClass;
  } ENUMTYPEW,*PENUMTYPEW,*LPENUMTYPEW;

#define ET_DEVICENAME 0x00000001
#define ET_MEDIATYPE 0x00000002
#define ET_DITHERMODE 0x00000004
#define ET_RESOLUTION 0x00000008
#define ET_CMMTYPE 0x00000010
#define ET_CLASS 0x00000020
#define ET_DATACOLORSPACE 0x00000040
#define ET_CONNECTIONSPACE 0x00000080
#define ET_SIGNATURE 0x00000100
#define ET_PLATFORM 0x00000200
#define ET_PROFILEFLAGS 0x00000400
#define ET_MANUFACTURER 0x00000800
#define ET_MODEL 0x00001000
#define ET_ATTRIBUTES 0x00002000
#define ET_RENDERINGINTENT 0x00004000
#define ET_CREATOR 0x00008000
#define ET_DEVICECLASS 0x00010000

#define PROOF_MODE 0x00000001
#define NORMAL_MODE 0x00000002
#define BEST_MODE 0x00000003
#define ENABLE_GAMUT_CHECKING 0x00010000
#define USE_RELATIVE_COLORIMETRIC 0x00020000
#define FAST_TRANSLATE 0x00040000
#define RESERVED 0x80000000

#define CSA_A 1
#define CSA_ABC 2
#define CSA_DEF 3
#define CSA_DEFG 4
#define CSA_GRAY 5
#define CSA_RGB 6
#define CSA_CMYK 7
#define CSA_Lab 8

#define CMM_WIN_VERSION 0
#define CMM_IDENT 1
#define CMM_DRIVER_VERSION 2
#define CMM_DLL_VERSION 3
#define CMM_VERSION 4
#define CMM_DESCRIPTION 5
#define CMM_LOGOICON 6

#define CMS_FORWARD 0
#define CMS_BACKWARD 1

#define COLOR_MATCH_VERSION 0x0200

#define CMS_DISABLEICM 1
#define CMS_ENABLEPROOFING 2

#define CMS_SETRENDERINTENT 4
#define CMS_SETPROOFINTENT 8
#define CMS_SETMONITORPROFILE 0x10
#define CMS_SETPRINTERPROFILE 0x20
#define CMS_SETTARGETPROFILE 0x40

#define CMS_USEHOOK 0x80
#define CMS_USEAPPLYCALLBACK 0x100
#define CMS_USEDESCRIPTION 0x200

#define CMS_DISABLEINTENT 0x400
#define CMS_DISABLERENDERINTENT 0x800

#define CMS_MONITOROVERFLOW __MSABI_LONG(0x80000000)
#define CMS_PRINTEROVERFLOW __MSABI_LONG(0x40000000)
#define CMS_TARGETOVERFLOW __MSABI_LONG(0x20000000)

  struct _tagCOLORMATCHSETUPW;
  struct _tagCOLORMATCHSETUPA;

  typedef WINBOOL (WINAPI *PCMSCALLBACKW)(struct _tagCOLORMATCHSETUPW *,LPARAM);
  typedef WINBOOL (WINAPI *PCMSCALLBACKA)(struct _tagCOLORMATCHSETUPA *,LPARAM);

  typedef struct _tagCOLORMATCHSETUPW {
    DWORD dwSize;
    DWORD dwVersion;
    DWORD dwFlags;
    HWND hwndOwner;
    PCWSTR pSourceName;
    PCWSTR pDisplayName;
    PCWSTR pPrinterName;
    DWORD dwRenderIntent;
    DWORD dwProofingIntent;
    PWSTR pMonitorProfile;
    DWORD ccMonitorProfile;
    PWSTR pPrinterProfile;
    DWORD ccPrinterProfile;
    PWSTR pTargetProfile;
    DWORD ccTargetProfile;
    DLGPROC lpfnHook;
    LPARAM lParam;
    PCMSCALLBACKW lpfnApplyCallback;
    LPARAM lParamApplyCallback;
  } COLORMATCHSETUPW,*PCOLORMATCHSETUPW,*LPCOLORMATCHSETUPW;

  typedef struct _tagCOLORMATCHSETUPA {
    DWORD dwSize;
    DWORD dwVersion;
    DWORD dwFlags;
    HWND hwndOwner;
    PCSTR pSourceName;
    PCSTR pDisplayName;
    PCSTR pPrinterName;
    DWORD dwRenderIntent;
    DWORD dwProofingIntent;
    PSTR pMonitorProfile;
    DWORD ccMonitorProfile;
    PSTR pPrinterProfile;
    DWORD ccPrinterProfile;
    PSTR pTargetProfile;
    DWORD ccTargetProfile;
    DLGPROC lpfnHook;
    LPARAM lParam;
    PCMSCALLBACKA lpfnApplyCallback;
    LPARAM lParamApplyCallback;
  } COLORMATCHSETUPA,*PCOLORMATCHSETUPA,*LPCOLORMATCHSETUPA;

  HPROFILE WINAPI OpenColorProfileA(PPROFILE,DWORD,DWORD,DWORD);
  HPROFILE WINAPI OpenColorProfileW(PPROFILE,DWORD,DWORD,DWORD);
  WINBOOL WINAPI CloseColorProfile(HPROFILE);
  WINBOOL WINAPI GetColorProfileFromHandle(HPROFILE,PBYTE,PDWORD);
  WINBOOL WINAPI IsColorProfileValid(HPROFILE,PBOOL);
  WINBOOL WINAPI CreateProfileFromLogColorSpaceA(LPLOGCOLORSPACEA,PBYTE*);
  WINBOOL WINAPI CreateProfileFromLogColorSpaceW(LPLOGCOLORSPACEW,PBYTE*);
  WINBOOL WINAPI GetCountColorProfileElements(HPROFILE,PDWORD);
  WINBOOL WINAPI GetColorProfileHeader(HPROFILE,PPROFILEHEADER);
  WINBOOL WINAPI GetColorProfileElementTag(HPROFILE,DWORD,PTAGTYPE);
  WINBOOL WINAPI IsColorProfileTagPresent(HPROFILE,TAGTYPE,PBOOL);
  WINBOOL WINAPI GetColorProfileElement(HPROFILE,TAGTYPE,DWORD,PDWORD,PVOID,PBOOL);
  WINBOOL WINAPI SetColorProfileHeader(HPROFILE,PPROFILEHEADER);
  WINBOOL WINAPI SetColorProfileElementSize(HPROFILE,TAGTYPE,DWORD);
  WINBOOL WINAPI SetColorProfileElement(HPROFILE,TAGTYPE,DWORD,PDWORD,PVOID);
  WINBOOL WINAPI SetColorProfileElementReference(HPROFILE,TAGTYPE,TAGTYPE);
  WINBOOL WINAPI GetPS2ColorSpaceArray (HPROFILE,DWORD,DWORD,PBYTE,PDWORD,PBOOL);
  WINBOOL WINAPI GetPS2ColorRenderingIntent(HPROFILE,DWORD,PBYTE,PDWORD);
  WINBOOL WINAPI GetPS2ColorRenderingDictionary(HPROFILE,DWORD,PBYTE,PDWORD,PBOOL);
  WINBOOL WINAPI GetNamedProfileInfo(HPROFILE,PNAMED_PROFILE_INFO);
  WINBOOL WINAPI ConvertColorNameToIndex(HPROFILE,PCOLOR_NAME,PDWORD,DWORD);
  WINBOOL WINAPI ConvertIndexToColorName(HPROFILE,PDWORD,PCOLOR_NAME,DWORD);
  WINBOOL WINAPI CreateDeviceLinkProfile(PHPROFILE,DWORD,PDWORD,DWORD,DWORD,PBYTE*,DWORD);
  HTRANSFORM WINAPI CreateColorTransformA(LPLOGCOLORSPACEA,HPROFILE,HPROFILE,DWORD);
  HTRANSFORM WINAPI CreateColorTransformW(LPLOGCOLORSPACEW,HPROFILE,HPROFILE,DWORD);
  HTRANSFORM WINAPI CreateMultiProfileTransform(PHPROFILE,DWORD,PDWORD,DWORD,DWORD,DWORD);
  WINBOOL WINAPI DeleteColorTransform(HTRANSFORM);
  WINBOOL WINAPI TranslateBitmapBits(HTRANSFORM,PVOID,BMFORMAT,DWORD,DWORD,DWORD,PVOID,BMFORMAT,DWORD,PBMCALLBACKFN,LPARAM);
  WINBOOL WINAPI CheckBitmapBits(HTRANSFORM ,PVOID,BMFORMAT,DWORD,DWORD,DWORD,PBYTE,PBMCALLBACKFN,LPARAM);
  WINBOOL WINAPI TranslateColors(HTRANSFORM,PCOLOR,DWORD,COLORTYPE,PCOLOR,COLORTYPE);
  WINBOOL WINAPI CheckColors(HTRANSFORM,PCOLOR,DWORD,COLORTYPE,PBYTE);
  DWORD WINAPI GetCMMInfo(HTRANSFORM,DWORD);
  WINBOOL WINAPI RegisterCMMA(PCSTR,DWORD,PCSTR);
  WINBOOL WINAPI RegisterCMMW(PCWSTR,DWORD,PCWSTR);
  WINBOOL WINAPI UnregisterCMMA(PCSTR,DWORD);
  WINBOOL WINAPI UnregisterCMMW(PCWSTR,DWORD);
  WINBOOL WINAPI SelectCMM(DWORD);
  WINBOOL WINAPI GetColorDirectoryA(PCSTR pMachineName,PSTR pBuffer,PDWORD pdwSize);
  WINBOOL WINAPI GetColorDirectoryW(PCWSTR pMachineName,PWSTR pBuffer,PDWORD pdwSize);
  WINBOOL WINAPI InstallColorProfileA(PCSTR,PCSTR);
  WINBOOL WINAPI InstallColorProfileW(PCWSTR,PCWSTR);
  WINBOOL WINAPI UninstallColorProfileA(PCSTR,PCSTR,WINBOOL);
  WINBOOL WINAPI UninstallColorProfileW(PCWSTR,PCWSTR,WINBOOL);
  WINBOOL WINAPI EnumColorProfilesA(PCSTR,PENUMTYPEA,PBYTE,PDWORD,PDWORD);
  WINBOOL WINAPI EnumColorProfilesW(PCWSTR,PENUMTYPEW,PBYTE,PDWORD,PDWORD);
  WINBOOL WINAPI SetStandardColorSpaceProfileA(PCSTR,DWORD,PCSTR);
  WINBOOL WINAPI SetStandardColorSpaceProfileW(PCWSTR,DWORD,PCWSTR);
  WINBOOL WINAPI GetStandardColorSpaceProfileA(PCSTR pMachineName,DWORD dwSCS,PSTR pBuffer,PDWORD pcbSize);
  WINBOOL WINAPI GetStandardColorSpaceProfileW(PCWSTR pMachineName,DWORD dwSCS,PWSTR pBuffer,PDWORD pcbSize);
  WINBOOL WINAPI AssociateColorProfileWithDeviceA(PCSTR,PCSTR,PCSTR);
  WINBOOL WINAPI AssociateColorProfileWithDeviceW(PCWSTR,PCWSTR,PCWSTR);
  WINBOOL WINAPI DisassociateColorProfileFromDeviceA(PCSTR,PCSTR,PCSTR);
  WINBOOL WINAPI DisassociateColorProfileFromDeviceW(PCWSTR,PCWSTR,PCWSTR);
  WINBOOL WINAPI SetupColorMatchingW(PCOLORMATCHSETUPW pcms);
  WINBOOL WINAPI SetupColorMatchingA(PCOLORMATCHSETUPA pcms);

#define ENUMTYPE __MINGW_NAME_AW(ENUMTYPE)
#define PENUMTYPE __MINGW_NAME_AW(PENUMTYPE)
#define COLORMATCHSETUP __MINGW_NAME_AW(COLORMATCHSETUP)
#define PCOLORMATCHSETUP __MINGW_NAME_AW(PCOLORMATCHSETUP)
#define LPCOLORMATCHSETUP __MINGW_NAME_AW(LPCOLORMATCHSETUP)
#define PCMSCALLBACK __MINGW_NAME_AW(PCMSCALLBACK)

#define CreateColorTransform __MINGW_NAME_AW(CreateColorTransform)
#define OpenColorProfile __MINGW_NAME_AW(OpenColorProfile)
#define CreateProfileFromLogColorSpace __MINGW_NAME_AW(CreateProfileFromLogColorSpace)
#define RegisterCMM __MINGW_NAME_AW(RegisterCMM)
#define UnregisterCMM __MINGW_NAME_AW(UnregisterCMM)
#define GetColorDirectory __MINGW_NAME_AW(GetColorDirectory)
#define InstallColorProfile __MINGW_NAME_AW(InstallColorProfile)
#define UninstallColorProfile __MINGW_NAME_AW(UninstallColorProfile)
#define AssociateColorProfileWithDevice __MINGW_NAME_AW(AssociateColorProfileWithDevice)
#define DisassociateColorProfileFromDevice __MINGW_NAME_AW(DisassociateColorProfileFromDevice)
#define EnumColorProfiles __MINGW_NAME_AW(EnumColorProfiles)
#define SetStandardColorSpaceProfile __MINGW_NAME_AW(SetStandardColorSpaceProfile)
#define GetStandardColorSpaceProfile __MINGW_NAME_AW(GetStandardColorSpaceProfile)
#define SetupColorMatching __MINGW_NAME_AW(SetupColorMatching)

  typedef HANDLE HCMTRANSFORM;
  typedef PVOID LPDEVCHARACTER;

  WINBOOL WINAPI CMCheckColors(HCMTRANSFORM hcmTransform,LPCOLOR lpaInputColors,DWORD nColors,COLORTYPE ctInput,LPBYTE lpaResult);
  WINBOOL WINAPI CMCheckColorsInGamut(HCMTRANSFORM hcmTransform,RGBTRIPLE *lpaRGBTriple,LPBYTE lpaResult,UINT nCount);
  WINBOOL WINAPI CMCheckRGBs(HCMTRANSFORM hcmTransform,LPVOID lpSrcBits,BMFORMAT bmInput,DWORD dwWidth,DWORD dwHeight,DWORD dwStride,LPBYTE lpaResult,PBMCALLBACKFN pfnCallback,LPARAM ulCallbackData);
  WINBOOL WINAPI CMConvertColorNameToIndex(HPROFILE hProfile,PCOLOR_NAME paColorName,PDWORD paIndex,DWORD dwCount);
  WINBOOL WINAPI CMConvertIndexToColorName(HPROFILE hProfile,PDWORD paIndex,PCOLOR_NAME paColorName,DWORD dwCount);
  WINBOOL WINAPI CMCreateDeviceLinkProfile(PHPROFILE pahProfiles,DWORD nProfiles,PDWORD padwIntents,DWORD nIntents,DWORD dwFlags,LPBYTE *lpProfileData);
  HCMTRANSFORM WINAPI CMCreateMultiProfileTransform(PHPROFILE pahProfiles,DWORD nProfiles,PDWORD padwIntents,DWORD nIntents,DWORD dwFlags);
  WINBOOL WINAPI CMCreateProfile(LPLOGCOLORSPACEA lpColorSpace,LPDEVCHARACTER *lpProfileData);
  WINBOOL WINAPI CMCreateProfileW(LPLOGCOLORSPACEW lpColorSpace,LPDEVCHARACTER *lpProfileData);
  HCMTRANSFORM WINAPI CMCreateTransform(LPLOGCOLORSPACEA lpColorSpace,LPDEVCHARACTER lpDevCharacter,LPDEVCHARACTER lpTargetDevCharacter);
  HCMTRANSFORM WINAPI CMCreateTransformW(LPLOGCOLORSPACEW lpColorSpace,LPDEVCHARACTER lpDevCharacter,LPDEVCHARACTER lpTargetDevCharacter);
  HCMTRANSFORM WINAPI CMCreateTransformExt(LPLOGCOLORSPACEA lpColorSpace,LPDEVCHARACTER lpDevCharacter,LPDEVCHARACTER lpTargetDevCharacter,DWORD dwFlags);
  HCMTRANSFORM WINAPI CMCreateTransformExtW(LPLOGCOLORSPACEW lpColorSpace,LPDEVCHARACTER lpDevCharacter,LPDEVCHARACTER lpTargetDevCharacter,DWORD dwFlags);
  WINBOOL WINAPI CMDeleteTransform(HCMTRANSFORM hcmTransform);
  DWORD WINAPI CMGetInfo(DWORD dwInfo);
  WINBOOL WINAPI CMGetNamedProfileInfo(HPROFILE hProfile,PNAMED_PROFILE_INFO pNamedProfileInfo);
  WINBOOL WINAPI CMGetPS2ColorRenderingDictionary(HPROFILE hProfile,DWORD dwIntent,LPBYTE lpBuffer,LPDWORD lpcbSize,LPBOOL lpbBinary);
  WINBOOL WINAPI CMGetPS2ColorRenderingIntent(HPROFILE hProfile,DWORD dwIntent,LPBYTE lpBuffer,LPDWORD lpcbSize);
  WINBOOL WINAPI CMGetPS2ColorSpaceArray(HPROFILE hProfile,DWORD dwIntent,DWORD dwCSAType,LPBYTE lpBuffer,LPDWORD lpcbSize,LPBOOL lpbBinary);
  WINBOOL WINAPI CMIsProfileValid(HPROFILE hProfile,LPBOOL lpbValid);
  WINBOOL WINAPI CMTranslateColors(HCMTRANSFORM hcmTransform,LPCOLOR lpaInputColors,DWORD nColors,COLORTYPE ctInput,LPCOLOR lpaOutputColors,COLORTYPE ctOutput);
  WINBOOL WINAPI CMTranslateRGB(HCMTRANSFORM hcmTransform,COLORREF ColorRef,LPCOLORREF lpColorRef,DWORD dwFlags);
  WINBOOL WINAPI CMTranslateRGBs(HCMTRANSFORM hcmTransform,LPVOID lpSrcBits,BMFORMAT bmInput,DWORD dwWidth,DWORD dwHeight,DWORD dwStride,LPVOID lpDestBits,BMFORMAT bmOutput,DWORD dwTranslateDirection);
  WINBOOL WINAPI CMTranslateRGBsExt(HCMTRANSFORM hcmTransform,LPVOID lpSrcBits,BMFORMAT bmInput,DWORD dwWidth,DWORD dwHeight,DWORD dwInputStride,LPVOID lpDestBits,BMFORMAT bmOutput,DWORD dwOutputStride,LPBMCALLBACKFN lpfnCallback,LPARAM ulCallbackData);

#if (_WIN32_WINNT >= 0x0600)
  typedef enum tagCOLORDATATYPE {
  COLOR_BYTE                 = 1,
  COLOR_WORD,
  COLOR_FLOAT,
  COLOR_S2DOT13FIXED,
  COLOR_10b_R10G10B10A2,
  COLOR_10b_R10G10B10A2_XR
} COLORDATATYPE, *PCOLORDATATYPE, *LPCOLORDATATYPE;

#define INTENT_PERCEPTUAL 0
#define INTENT_RELATIVE_COLORIMETRIC 1
#define INTENT_SATURATION 2
#define INTENT_ABSOLUTE_COLORIMETRIC 3

typedef enum tagCOLORPROFILESUBTYPE {
  CPST_PERCEPTUAL            = INTENT_PERCEPTUAL,
  CPST_RELATIVE_COLORIMETRIC = INTENT_RELATIVE_COLORIMETRIC,
  CPST_SATURATION            = INTENT_SATURATION,
  CPST_ABSOLUTE_COLORIMETRIC = INTENT_ABSOLUTE_COLORIMETRIC,
  CPST_NONE,
  CPST_RGB_WORKING_SPACE,
  CPST_CUSTOM_WORKING_SPACE
} COLORPROFILESUBTYPE, *PCOLORPROFILESUBTYPE, *LPCOLORPROFILESUBTYPE;

typedef enum tagCOLORPROFILETYPE {
  CPT_ICC  = 0,
  CPT_DMP  = 1,
  CPT_CAMP = 2,
  CPT_GMMP = 3
} COLORPROFILETYPE, *PCOLORPROFILETYPE, *LPCOLORPROFILETYPE;

typedef enum tagWCS_PROFILE_MANAGEMENT_SCOPE {
  WCS_PROFILE_MANAGEMENT_SCOPE_SYSTEM_WIDE = 0,
  WCS_PROFILE_MANAGEMENT_SCOPE_CURRENT_USER
} WCS_PROFILE_MANAGEMENT_SCOPE;

WINBOOL WINAPI WcsAssociateColorProfileWithDevice(
  WCS_PROFILE_MANAGEMENT_SCOPE profileManagementScope,
  PCWSTR pProfileName,
  PCWSTR pDeviceName
);

WINBOOL WINAPI WcsCheckColors(
  HTRANSFORM hColorTransform,
  DWORD nColors,
  DWORD nInputChannels,
  COLORDATATYPE cdtInput,
  DWORD cbInput,
  PVOID pInputData,
  PBYTE paResult
);

HPROFILE WINAPI WcsCreateIccProfile(
  HPROFILE hWcsProfile,
  DWORD dwOptions
);

WINBOOL WINAPI WcsDisassociateColorProfileFromDevice(
  WCS_PROFILE_MANAGEMENT_SCOPE profileManagementScope,
  PCWSTR pProfileName,
  PCWSTR pDeviceName
);

WINBOOL WINAPI WcsEnumColorProfiles(
  WCS_PROFILE_MANAGEMENT_SCOPE profileManagementScope,
  PENUMTYPEW pEnumRecord,
  PBYTE pBuffer,
  DWORD dwSize,
  PDWORD pnProfiles
);

WINBOOL WINAPI WcsEnumColorProfilesSize(
  WCS_PROFILE_MANAGEMENT_SCOPE profileManagementScope,
  PENUMTYPEW pEnumRecord,
  PDWORD pdwSize
);

WINBOOL WINAPI WcsGetDefaultColorProfile(
  WCS_PROFILE_MANAGEMENT_SCOPE profileManagementScope,
  PCWSTR pDeviceName,
  COLORPROFILETYPE cptColorProfileType,
  COLORPROFILESUBTYPE cpstColorProfileSubType,
  DWORD dwProfileID,
  DWORD cbProfileName,
  LPWSTR pProfileName
);

WINBOOL WINAPI WcsGetDefaultColorProfileSize(
  WCS_PROFILE_MANAGEMENT_SCOPE profileManagementScope,
  PCWSTR pDeviceName,
  COLORPROFILETYPE cptColorProfileType,
  COLORPROFILESUBTYPE cpstColorProfileSubType,
  DWORD dwProfileID,
  PDWORD pcbProfileName
);

WINBOOL WINAPI WcsGetDefaultRenderingIntent(
  WCS_PROFILE_MANAGEMENT_SCOPE scope,
  PDWORD pdwRenderingIntent
);

WINBOOL WINAPI WcsGetUsePerUserProfiles(
  LPCWSTR pDeviceName,
  DWORD dwDeviceClass,
  WINBOOL *pUsePerUserProfiles
);

#define WcsOpenColorProfile __MINGW_NAME_AW(WcsOpenColorProfile)

HPROFILE WINAPI WcsOpenColorProfileA(
  PPROFILE pCDMPProfile,
  PPROFILE pCAMPProfile,
  PPROFILE pGMMPProfile,
  DWORD dwDesiredAccess,
  DWORD dwShareMode,
  DWORD dwCreationMode,
  DWORD dwFlags
);

HPROFILE WINAPI WcsOpenColorProfileW(
  PPROFILE pCDMPProfile,
  PPROFILE pCAMPProfile,
  PPROFILE pGMMPProfile,
  DWORD dwDesiredAccess,
  DWORD dwShareMode,
  DWORD dwCreationMode,
  DWORD dwFlags
);

WINBOOL WINAPI WcsSetDefaultColorProfile(
  WCS_PROFILE_MANAGEMENT_SCOPE profileManagementScope,
  PCWSTR pDeviceName,
  COLORPROFILETYPE cptColorProfileType,
  COLORPROFILESUBTYPE cpstColorProfileSubType,
  DWORD dwProfileID,
  LPCWSTR pProfileName
);

WINBOOL WINAPI WcsSetDefaultRenderingIntent(
  WCS_PROFILE_MANAGEMENT_SCOPE scope,
  DWORD dwRenderingIntent
);

WINBOOL WINAPI WcsSetUsePerUserProfiles(
  LPCWSTR pDeviceName,
  DWORD dwDeviceClass,
  WINBOOL usePerUserProfiles
);

WINBOOL WINAPI WcsTranslateColors(
  HTRANSFORM hColorTransform,
  DWORD nColors,
  DWORD nInputChannels,
  COLORDATATYPE cdtInput,
  DWORD cbInput,
  PVOID pInputData,
  DWORD nOutputChannels,
  COLORDATATYPE cdtOutput,
  DWORD cbOutput,
  PVOID pOutputData
);

#endif /*(_WIN32_WINNT >= 0x0600)*/

#ifdef __cplusplus
}
#endif
#endif

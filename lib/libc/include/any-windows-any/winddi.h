/*
 * winddi.h
 *
 * GDI device driver interface
 *
 * This file is part of the w32api package.
 *
 * Contributors:
 *   Created by Casper S. Hornstrup <chorns@users.sourceforge.net>
 *
 * THIS SOFTWARE IS NOT COPYRIGHTED
 *
 * This source code is offered for use in the public domain. You may
 * use, modify or distribute it freely.
 *
 * This code is distributed in the hope that it will be useful but
 * WITHOUT ANY WARRANTY. ALL WARRANTIES, EXPRESS OR IMPLIED ARE HEREBY
 * DISCLAIMED. This includes but is not limited to warranties of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 *
 */

#ifndef _WINDDI_
#define _WINDDI_

#ifdef __VIDEO_H__
#error video.h cannot be included with winddi.h
#else

#include <ddrawint.h>
#include <d3dnthal.h>

#ifdef __cplusplus
extern "C" {
#endif

#ifndef DECLSPEC_IMPORT
#ifndef __WIDL__
#define DECLSPEC_IMPORT __declspec(dllimport)
#else
#define DECLSPEC_IMPORT
#endif
#endif

#ifndef WIN32KAPI
#define WIN32KAPI DECLSPEC_ADDRSAFE
#endif

#define DDI_DRIVER_VERSION_NT4            0x00020000
#define DDI_DRIVER_VERSION_SP3            0x00020003
#define DDI_DRIVER_VERSION_NT5            0x00030000
#define DDI_DRIVER_VERSION_NT5_01         0x00030100

#define GDI_DRIVER_VERSION                0x4000

#ifdef _X86_

typedef DWORD FLOATL;

#else /* !_X86_ */

typedef FLOAT FLOATL;

#endif

typedef SHORT FWORD;
typedef LONG LDECI4;
typedef ULONG IDENT;

typedef ULONG_PTR HFF;
typedef ULONG_PTR HFC;

typedef LONG PTRDIFF;
typedef PTRDIFF *PPTRDIFF;
typedef LONG FIX;
typedef FIX *PFIX;
typedef ULONG ROP4;
typedef ULONG MIX;
typedef ULONG HGLYPH;
typedef HGLYPH *PHGLYPH;

typedef LONG_PTR (APIENTRY *PFN)();

DECLARE_HANDLE(HBM);
DECLARE_HANDLE(HDEV);
DECLARE_HANDLE(HSURF);
DECLARE_HANDLE(DHSURF);
DECLARE_HANDLE(DHPDEV);
DECLARE_HANDLE(HDRVOBJ);

#ifndef _NTDDVDEO_
typedef struct _ENG_EVENT *PEVENT;
#endif

#define OPENGL_CMD                        4352
#define OPENGL_GETINFO                    4353
#define WNDOBJ_SETUP                      4354

#define FD_ERROR                          0xFFFFFFFF
#define DDI_ERROR                         0xFFFFFFFF

#define HFF_INVALID                       ((HFF) 0)
#define HFC_INVALID                       ((HFC) 0)
#define HGLYPH_INVALID                    ((HGLYPH) -1)

#define FP_ALTERNATEMODE                  1
#define FP_WINDINGMODE                    2

#define DN_ACCELERATION_LEVEL             1
#define DN_DEVICE_ORIGIN                  2
#define DN_SLEEP_MODE                     3
#define DN_DRAWING_BEGIN                  4

#define DCR_SOLID                         0
#define DCR_DRIVER                        1
#define DCR_HALFTONE                      2

#define GX_IDENTITY                       0
#define GX_OFFSET                         1
#define GX_SCALE                          2
#define GX_GENERAL                        3

#define LTOFX(x)        ((x) << 4)
#define FXTOL(x)        ((x) >> 4)
#define FXTOLFLOOR(x)   ((x) >> 4)
#define FXTOLCEILING(x) ((x + 0x0F) >> 4)
#define FXTOLROUND(x)   ((((x) >> 3) + 1) >> 1)

typedef struct _POINTE {
	FLOATL  x;
	FLOATL  y;
} POINTE, *PPOINTE;

typedef union _FLOAT_LONG {
  FLOATL  e;
  LONG  l;
} FLOAT_LONG, *PFLOAT_LONG;

typedef struct _POINTFIX {
  FIX  x;
  FIX  y;
} POINTFIX, *PPOINTFIX;

typedef struct _RECTFX {
  FIX  xLeft;
  FIX  yTop;
  FIX  xRight;
  FIX  yBottom;
} RECTFX, *PRECTFX;

typedef struct _POINTQF {
  LARGE_INTEGER  x;
  LARGE_INTEGER  y;
} POINTQF, *PPOINTQF;


typedef struct _BLENDOBJ {
  BLENDFUNCTION  BlendFunction;
} BLENDOBJ,*PBLENDOBJ;

/* BRUSHOBJ.flColorType */
#define BR_DEVICE_ICM    0x01
#define BR_HOST_ICM      0x02
#define BR_CMYKCOLOR     0x04
#define BR_ORIGCOLOR     0x08

typedef struct _BRUSHOBJ {
  ULONG  iSolidColor;
  PVOID  pvRbrush;
  FLONG  flColorType;
} BRUSHOBJ;

typedef struct _CIECHROMA {
  LDECI4  x;
  LDECI4  y;
  LDECI4  Y;
} CIECHROMA;

typedef struct _RUN {
  LONG  iStart;
  LONG  iStop;
} RUN, *PRUN;

typedef struct _CLIPLINE {
  POINTFIX  ptfxA;
  POINTFIX  ptfxB;
  LONG  lStyleState;
  ULONG  c;
  RUN  arun[1];
} CLIPLINE, *PCLIPLINE;

/* CLIPOBJ.iDComplexity constants */
#define DC_TRIVIAL                        0
#define DC_RECT                           1
#define DC_COMPLEX                        3

/* CLIPOBJ.iFComplexity constants */
#define FC_RECT                           1
#define FC_RECT4                          2
#define FC_COMPLEX                        3

/* CLIPOBJ.iMode constants */
#define TC_RECTANGLES                     0
#define TC_PATHOBJ                        2

/* CLIPOBJ.fjOptions constants */
#define OC_BANK_CLIP                      1

typedef struct _CLIPOBJ {
  ULONG  iUniq;
  RECTL  rclBounds;
  BYTE  iDComplexity;
  BYTE  iFComplexity;
  BYTE  iMode;
  BYTE  fjOptions;
} CLIPOBJ;

typedef struct _COLORINFO {
  CIECHROMA  Red;
  CIECHROMA  Green;
  CIECHROMA  Blue;
  CIECHROMA  Cyan;
  CIECHROMA  Magenta;
  CIECHROMA  Yellow;
  CIECHROMA  AlignmentWhite;
  LDECI4  RedGamma;
  LDECI4  GreenGamma;
  LDECI4  BlueGamma;
  LDECI4  MagentaInCyanDye;
  LDECI4  YellowInCyanDye;
  LDECI4  CyanInMagentaDye;
  LDECI4  YellowInMagentaDye;
  LDECI4  CyanInYellowDye;
  LDECI4  MagentaInYellowDye;
} COLORINFO, *PCOLORINFO;

/* DEVHTADJDATA.DeviceFlags constants */
#define DEVHTADJF_COLOR_DEVICE            0x00000001
#define DEVHTADJF_ADDITIVE_DEVICE         0x00000002

typedef struct _DEVHTINFO {
  DWORD  HTFlags;
  DWORD  HTPatternSize;
  DWORD  DevPelsDPI;
  COLORINFO  ColorInfo;
} DEVHTINFO, *PDEVHTINFO;

typedef struct _DEVHTADJDATA {
  DWORD   DeviceFlags;
  DWORD   DeviceXDPI;
  DWORD   DeviceYDPI;
  PDEVHTINFO  pDefHTInfo;
  PDEVHTINFO  pAdjHTInfo;
} DEVHTADJDATA, *PDEVHTADJDATA;

/* DEVINFO.flGraphicsCaps flags */
#define GCAPS_BEZIERS           0x00000001
#define GCAPS_GEOMETRICWIDE     0x00000002
#define GCAPS_ALTERNATEFILL     0x00000004
#define GCAPS_WINDINGFILL       0x00000008
#define GCAPS_HALFTONE          0x00000010
#define GCAPS_COLOR_DITHER      0x00000020
#define GCAPS_HORIZSTRIKE       0x00000040
#define GCAPS_VERTSTRIKE        0x00000080
#define GCAPS_OPAQUERECT        0x00000100
#define GCAPS_VECTORFONT        0x00000200
#define GCAPS_MONO_DITHER       0x00000400
#define GCAPS_ASYNCCHANGE       0x00000800
#define GCAPS_ASYNCMOVE         0x00001000
#define GCAPS_DONTJOURNAL       0x00002000
#define GCAPS_DIRECTDRAW        0x00004000
#define GCAPS_ARBRUSHOPAQUE     0x00008000
#define GCAPS_PANNING           0x00010000
#define GCAPS_HIGHRESTEXT       0x00040000
#define GCAPS_PALMANAGED        0x00080000
#define GCAPS_DITHERONREALIZE   0x00200000
#define GCAPS_NO64BITMEMACCESS  0x00400000
#define GCAPS_FORCEDITHER       0x00800000
#define GCAPS_GRAY16            0x01000000
#define GCAPS_ICM               0x02000000
#define GCAPS_CMYKCOLOR         0x04000000
#define GCAPS_LAYERED           0x08000000
#define GCAPS_ARBRUSHTEXT       0x10000000
#define GCAPS_SCREENPRECISION   0x20000000
#define GCAPS_FONT_RASTERIZER   0x40000000
#define GCAPS_NUP               0x80000000

/* DEVINFO.iDitherFormat constants */
#define BMF_1BPP       __MSABI_LONG(1)
#define BMF_4BPP       __MSABI_LONG(2)
#define BMF_8BPP       __MSABI_LONG(3)
#define BMF_16BPP      __MSABI_LONG(4)
#define BMF_24BPP      __MSABI_LONG(5)
#define BMF_32BPP      __MSABI_LONG(6)
#define BMF_4RLE       __MSABI_LONG(7)
#define BMF_8RLE       __MSABI_LONG(8)
#define BMF_JPEG       __MSABI_LONG(9)
#define BMF_PNG       __MSABI_LONG(10)

/* DEVINFO.flGraphicsCaps2 flags */
#define GCAPS2_JPEGSRC          0x00000001
#define GCAPS2_xxxx             0x00000002
#define GCAPS2_PNGSRC           0x00000008
#define GCAPS2_CHANGEGAMMARAMP  0x00000010
#define GCAPS2_ALPHACURSOR      0x00000020
#define GCAPS2_SYNCFLUSH        0x00000040
#define GCAPS2_SYNCTIMER        0x00000080
#define GCAPS2_ICD_MULTIMON     0x00000100
#define GCAPS2_MOUSETRAILS      0x00000200
#define GCAPS2_RESERVED1        0x00000400

typedef struct _DEVINFO {
  FLONG  flGraphicsCaps;
  LOGFONTW  lfDefaultFont;
  LOGFONTW  lfAnsiVarFont;
  LOGFONTW  lfAnsiFixFont;
  ULONG  cFonts;
  ULONG  iDitherFormat;
  USHORT  cxDither;
  USHORT  cyDither;
  HPALETTE  hpalDefault;
  FLONG  flGraphicsCaps2;
} DEVINFO, *PDEVINFO;

struct _DRIVEROBJ;

typedef WINBOOL
(APIENTRY CALLBACK *FREEOBJPROC)(
  struct _DRIVEROBJ  *pDriverObj);

typedef struct _DRIVEROBJ {
  PVOID  pvObj;
  FREEOBJPROC  pFreeProc;
  HDEV  hdev;
  DHPDEV  dhpdev;
} DRIVEROBJ;

/* DRVFN.iFunc constants */
#define INDEX_DrvEnablePDEV               __MSABI_LONG(0)
#define INDEX_DrvCompletePDEV             __MSABI_LONG(1)
#define INDEX_DrvDisablePDEV              __MSABI_LONG(2)
#define INDEX_DrvEnableSurface            __MSABI_LONG(3)
#define INDEX_DrvDisableSurface           __MSABI_LONG(4)
#define INDEX_DrvAssertMode               __MSABI_LONG(5)
#define INDEX_DrvOffset                   __MSABI_LONG(6)
#define INDEX_DrvResetPDEV                __MSABI_LONG(7)
#define INDEX_DrvDisableDriver            __MSABI_LONG(8)
#define INDEX_DrvUnknown1                 __MSABI_LONG(9)
#define INDEX_DrvCreateDeviceBitmap       __MSABI_LONG(10)
#define INDEX_DrvDeleteDeviceBitmap       __MSABI_LONG(11)
#define INDEX_DrvRealizeBrush             __MSABI_LONG(12)
#define INDEX_DrvDitherColor              __MSABI_LONG(13)
#define INDEX_DrvStrokePath               __MSABI_LONG(14)
#define INDEX_DrvFillPath                 __MSABI_LONG(15)
#define INDEX_DrvStrokeAndFillPath        __MSABI_LONG(16)
#define INDEX_DrvPaint                    __MSABI_LONG(17)
#define INDEX_DrvBitBlt                   __MSABI_LONG(18)
#define INDEX_DrvCopyBits                 __MSABI_LONG(19)
#define INDEX_DrvStretchBlt               __MSABI_LONG(20)
#define INDEX_DrvUnknown2                 __MSABI_LONG(21)
#define INDEX_DrvSetPalette               __MSABI_LONG(22)
#define INDEX_DrvTextOut                  __MSABI_LONG(23)
#define INDEX_DrvEscape                   __MSABI_LONG(24)
#define INDEX_DrvDrawEscape               __MSABI_LONG(25)
#define INDEX_DrvQueryFont                __MSABI_LONG(26)
#define INDEX_DrvQueryFontTree            __MSABI_LONG(27)
#define INDEX_DrvQueryFontData            __MSABI_LONG(28)
#define INDEX_DrvSetPointerShape          __MSABI_LONG(29)
#define INDEX_DrvMovePointer              __MSABI_LONG(30)
#define INDEX_DrvLineTo                   __MSABI_LONG(31)
#define INDEX_DrvSendPage                 __MSABI_LONG(32)
#define INDEX_DrvStartPage                __MSABI_LONG(33)
#define INDEX_DrvEndDoc                   __MSABI_LONG(34)
#define INDEX_DrvStartDoc                 __MSABI_LONG(35)
#define INDEX_DrvUnknown3                 __MSABI_LONG(36)
#define INDEX_DrvGetGlyphMode             __MSABI_LONG(37)
#define INDEX_DrvSynchronize              __MSABI_LONG(38)
#define INDEX_DrvUnknown4                 __MSABI_LONG(39)
#define INDEX_DrvSaveScreenBits           __MSABI_LONG(40)
#define INDEX_DrvGetModes                 __MSABI_LONG(41)
#define INDEX_DrvFree                     __MSABI_LONG(42)
#define INDEX_DrvDestroyFont              __MSABI_LONG(43)
#define INDEX_DrvQueryFontCaps            __MSABI_LONG(44)
#define INDEX_DrvLoadFontFile             __MSABI_LONG(45)
#define INDEX_DrvUnloadFontFile           __MSABI_LONG(46)
#define INDEX_DrvFontManagement           __MSABI_LONG(47)
#define INDEX_DrvQueryTrueTypeTable       __MSABI_LONG(48)
#define INDEX_DrvQueryTrueTypeOutline     __MSABI_LONG(49)
#define INDEX_DrvGetTrueTypeFile          __MSABI_LONG(50)
#define INDEX_DrvQueryFontFile            __MSABI_LONG(51)
#define INDEX_DrvMovePanning              __MSABI_LONG(52)
#define INDEX_DrvQueryAdvanceWidths       __MSABI_LONG(53)
#define INDEX_DrvSetPixelFormat           __MSABI_LONG(54)
#define INDEX_DrvDescribePixelFormat      __MSABI_LONG(55)
#define INDEX_DrvSwapBuffers              __MSABI_LONG(56)
#define INDEX_DrvStartBanding             __MSABI_LONG(57)
#define INDEX_DrvNextBand                 __MSABI_LONG(58)
#define INDEX_DrvGetDirectDrawInfo        __MSABI_LONG(59)
#define INDEX_DrvEnableDirectDraw         __MSABI_LONG(60)
#define INDEX_DrvDisableDirectDraw        __MSABI_LONG(61)
#define INDEX_DrvQuerySpoolType           __MSABI_LONG(62)
#define INDEX_DrvUnknown5                 __MSABI_LONG(63)
#define INDEX_DrvIcmCreateColorTransform  __MSABI_LONG(64)
#define INDEX_DrvIcmDeleteColorTransform  __MSABI_LONG(65)
#define INDEX_DrvIcmCheckBitmapBits       __MSABI_LONG(66)
#define INDEX_DrvIcmSetDeviceGammaRamp    __MSABI_LONG(67)
#define INDEX_DrvGradientFill             __MSABI_LONG(68)
#define INDEX_DrvStretchBltROP            __MSABI_LONG(69)
#define INDEX_DrvPlgBlt                   __MSABI_LONG(70)
#define INDEX_DrvAlphaBlend               __MSABI_LONG(71)
#define INDEX_DrvSynthesizeFont           __MSABI_LONG(72)
#define INDEX_DrvGetSynthesizedFontFiles  __MSABI_LONG(73)
#define INDEX_DrvTransparentBlt           __MSABI_LONG(74)
#define INDEX_DrvQueryPerBandInfo         __MSABI_LONG(75)
#define INDEX_DrvQueryDeviceSupport       __MSABI_LONG(76)
#define INDEX_DrvReserved1                __MSABI_LONG(77)
#define INDEX_DrvReserved2                __MSABI_LONG(78)
#define INDEX_DrvReserved3                __MSABI_LONG(79)
#define INDEX_DrvReserved4                __MSABI_LONG(80)
#define INDEX_DrvReserved5                __MSABI_LONG(81)
#define INDEX_DrvReserved6                __MSABI_LONG(82)
#define INDEX_DrvReserved7                __MSABI_LONG(83)
#define INDEX_DrvReserved8                __MSABI_LONG(84)
#define INDEX_DrvDeriveSurface            __MSABI_LONG(85)
#define INDEX_DrvQueryGlyphAttrs          __MSABI_LONG(86)
#define INDEX_DrvNotify                   __MSABI_LONG(87)
#define INDEX_DrvSynchronizeSurface       __MSABI_LONG(88)
#define INDEX_DrvResetDevice              __MSABI_LONG(89)
#define INDEX_DrvReserved9                __MSABI_LONG(90)
#define INDEX_DrvReserved10               __MSABI_LONG(91)
#define INDEX_DrvReserved11               __MSABI_LONG(92)
#define INDEX_LAST                        __MSABI_LONG(93)

typedef struct _DRVFN {
  ULONG  iFunc;
  PFN  pfn;
} DRVFN, *PDRVFN;

/* DRVENABLEDATA.iDriverVersion constants */
#define DDI_DRIVER_VERSION_NT4            0x00020000
#define DDI_DRIVER_VERSION_SP3            0x00020003
#define DDI_DRIVER_VERSION_NT5            0x00030000
#define DDI_DRIVER_VERSION_NT5_01         0x00030100
#define DDI_DRIVER_VERSION_NT5_01_SP1     0x00030101

typedef struct _DRVENABLEDATA {
  ULONG  iDriverVersion;
  ULONG  c;
  DRVFN  *pdrvfn;
} DRVENABLEDATA, *PDRVENABLEDATA;

DECLARE_HANDLE(HSEMAPHORE);

typedef struct {
  DWORD  nSize;
  HDC  hdc;
  PBYTE  pvEMF;
  PBYTE  pvCurrentRecord;
} EMFINFO, *PEMFINFO;

typedef struct _ENGSAFESEMAPHORE {
  HSEMAPHORE  hsem;
  LONG  lCount;
} ENGSAFESEMAPHORE;

typedef struct _ENG_TIME_FIELDS {
  USHORT  usYear;
  USHORT  usMonth;
  USHORT  usDay;
  USHORT  usHour;
  USHORT  usMinute;
  USHORT  usSecond;
  USHORT  usMilliseconds;
  USHORT  usWeekday;
} ENG_TIME_FIELDS, *PENG_TIME_FIELDS;

typedef struct _ENUMRECTS {
  ULONG  c;
  RECTL  arcl[1];
} ENUMRECTS;

typedef struct _FD_XFORM {
  FLOATL  eXX;
  FLOATL  eXY;
  FLOATL  eYX;
  FLOATL  eYY;
} FD_XFORM, *PFD_XFORM;

/* FD_DEVICEMETRICS.flRealizedType constants */
#define FDM_TYPE_BM_SIDE_CONST            0x00000001
#define FDM_TYPE_MAXEXT_EQUAL_BM_SIDE     0x00000002
#define FDM_TYPE_CHAR_INC_EQUAL_BM_BASE   0x00000004
#define FDM_TYPE_ZERO_BEARINGS            0x00000008
#define FDM_TYPE_CONST_BEARINGS           0x00000010

typedef struct _FD_DEVICEMETRICS {
  FLONG  flRealizedType;
  POINTE  pteBase;
  POINTE  pteSide;
  LONG  lD;
  FIX  fxMaxAscender;
  FIX  fxMaxDescender;
  POINTL  ptlUnderline1;
  POINTL  ptlStrikeout;
  POINTL  ptlULThickness;
  POINTL  ptlSOThickness;
  ULONG  cxMax;
  ULONG  cyMax;
  ULONG  cjGlyphMax;
  FD_XFORM  fdxQuantized;
  LONG  lNonLinearExtLeading;
  LONG  lNonLinearIntLeading;
  LONG  lNonLinearMaxCharWidth;
  LONG  lNonLinearAvgCharWidth;
  LONG  lMinA;
  LONG  lMinC;
  LONG  lMinD;
  LONG  alReserved[1];
} FD_DEVICEMETRICS, *PFD_DEVICEMETRICS;

/* FD_GLYPHATTR.iMode constants */
#define FO_ATTR_MODE_ROTATE               1

typedef struct _FD_GLYPHATTR {
  ULONG  cjThis;
  ULONG  cGlyphs;
  ULONG  iMode;
  BYTE  aGlyphAttr[1];
} FD_GLYPHATTR, *PFD_GLYPHATTR;

/* FD_GLYPHSET.flAccel */
#define GS_UNICODE_HANDLES                0x00000001
#define GS_8BIT_HANDLES                   0x00000002
#define GS_16BIT_HANDLES                  0x00000004

typedef struct _WCRUN {
  WCHAR  wcLow;
  USHORT  cGlyphs;
  HGLYPH  *phg;
} WCRUN, *PWCRUN;

typedef struct _FD_GLYPHSET {
  ULONG  cjThis;
  FLONG  flAccel;
  ULONG  cGlyphsSupported;
  ULONG  cRuns;
  WCRUN  awcrun[1];
} FD_GLYPHSET, *PFD_GLYPHSET;

typedef struct _FD_KERNINGPAIR {
  WCHAR  wcFirst;
  WCHAR  wcSecond;
  FWORD  fwdKern;
} FD_KERNINGPAIR;

#if defined(_X86_) && !defined(USERMODE_DRIVER)
typedef struct _FLOATOBJ
{
  ULONG  ul1;
  ULONG  ul2;
} FLOATOBJ, *PFLOATOBJ;
#else
typedef FLOAT FLOATOBJ, *PFLOATOBJ;
#endif

typedef struct _FLOATOBJ_XFORM {
  FLOATOBJ  eM11;
  FLOATOBJ  eM12;
  FLOATOBJ  eM21;
  FLOATOBJ  eM22;
  FLOATOBJ  eDx;
  FLOATOBJ  eDy;
} FLOATOBJ_XFORM, *PFLOATOBJ_XFORM, FAR *LPFLOATOBJ_XFORM;

/* FONTDIFF.fsSelection */
#define FM_SEL_ITALIC                     0x0001
#define FM_SEL_UNDERSCORE                 0x0002
#define FM_SEL_NEGATIVE                   0x0004
#define FM_SEL_OUTLINED                   0x0008
#define FM_SEL_STRIKEOUT                  0x0010
#define FM_SEL_BOLD                       0x0020
#define FM_SEL_REGULAR                    0x0040

typedef struct _FONTDIFF {
  BYTE  jReserved1;
  BYTE  jReserved2;
  BYTE  jReserved3;
  BYTE  bWeight;
  USHORT  usWinWeight;
  FSHORT  fsSelection;
  FWORD  fwdAveCharWidth;
  FWORD  fwdMaxCharInc;
  POINTL  ptlCaret;
} FONTDIFF;

typedef struct _FONTSIM {
  PTRDIFF  dpBold;
  PTRDIFF  dpItalic;
  PTRDIFF  dpBoldItalic;
} FONTSIM;

/* FONTINFO.flCaps constants */
#define FO_DEVICE_FONT                    __MSABI_LONG(1)
#define FO_OUTLINE_CAPABLE                __MSABI_LONG(2)

typedef struct _FONTINFO {
  ULONG  cjThis;
  FLONG  flCaps;
  ULONG  cGlyphsSupported;
  ULONG  cjMaxGlyph1;
  ULONG  cjMaxGlyph4;
  ULONG  cjMaxGlyph8;
  ULONG  cjMaxGlyph32;
} FONTINFO, *PFONTINFO;

/* FONTOBJ.flFontType constants */
#define FO_TYPE_RASTER   RASTER_FONTTYPE
#define FO_TYPE_DEVICE   DEVICE_FONTTYPE
#define FO_TYPE_TRUETYPE TRUETYPE_FONTTYPE
#define FO_TYPE_OPENTYPE OPENTYPE_FONTTYPE

#define FO_SIM_BOLD      0x00002000
#define FO_SIM_ITALIC    0x00004000
#define FO_EM_HEIGHT     0x00008000
#define FO_GRAY16        0x00010000
#define FO_NOGRAY16      0x00020000
#define FO_NOHINTS       0x00040000
#define FO_NO_CHOICE     0x00080000
#define FO_CFF            0x00100000
#define FO_POSTSCRIPT     0x00200000
#define FO_MULTIPLEMASTER 0x00400000
#define FO_VERT_FACE      0x00800000
#define FO_DBCS_FONT      0X01000000
#define FO_NOCLEARTYPE    0x02000000
#define FO_CLEARTYPE_X    0x10000000
#define FO_CLEARTYPE_Y    0x20000000

typedef struct _FONTOBJ {
  ULONG  iUniq;
  ULONG  iFace;
  ULONG  cxMax;
  FLONG  flFontType;
  ULONG_PTR  iTTUniq;
  ULONG_PTR  iFile;
  SIZE  sizLogResPpi;
  ULONG  ulStyleSize;
  PVOID  pvConsumer;
  PVOID  pvProducer;
} FONTOBJ;

typedef struct _GAMMARAMP {
  WORD  Red[256];
  WORD  Green[256];
  WORD  Blue[256];
} GAMMARAMP, *PGAMMARAMP;

/* GDIINFO.ulPrimaryOrder constants */
#define PRIMARY_ORDER_ABC                 0
#define PRIMARY_ORDER_ACB                 1
#define PRIMARY_ORDER_BAC                 2
#define PRIMARY_ORDER_BCA                 3
#define PRIMARY_ORDER_CBA                 4
#define PRIMARY_ORDER_CAB                 5

/* GDIINFO.ulHTPatternSize constants */
#define HT_PATSIZE_2x2                    0
#define HT_PATSIZE_2x2_M                  1
#define HT_PATSIZE_4x4                    2
#define HT_PATSIZE_4x4_M                  3
#define HT_PATSIZE_6x6                    4
#define HT_PATSIZE_6x6_M                  5
#define HT_PATSIZE_8x8                    6
#define HT_PATSIZE_8x8_M                  7
#define HT_PATSIZE_10x10                  8
#define HT_PATSIZE_10x10_M                9
#define HT_PATSIZE_12x12                  10
#define HT_PATSIZE_12x12_M                11
#define HT_PATSIZE_14x14                  12
#define HT_PATSIZE_14x14_M                13
#define HT_PATSIZE_16x16                  14
#define HT_PATSIZE_16x16_M                15
#define HT_PATSIZE_SUPERCELL              16
#define HT_PATSIZE_SUPERCELL_M            17
#define HT_PATSIZE_USER                   18
#define HT_PATSIZE_MAX_INDEX              HT_PATSIZE_USER
#define HT_PATSIZE_DEFAULT                HT_PATSIZE_SUPERCELL_M
#define HT_USERPAT_CX_MIN                 4
#define HT_USERPAT_CX_MAX                 256
#define HT_USERPAT_CY_MIN                 4
#define HT_USERPAT_CY_MAX                 256

/* GDIINFO.ulHTOutputFormat constants */
#define HT_FORMAT_1BPP                    0
#define HT_FORMAT_4BPP                    2
#define HT_FORMAT_4BPP_IRGB               3
#define HT_FORMAT_8BPP                    4
#define HT_FORMAT_16BPP                   5
#define HT_FORMAT_24BPP                   6
#define HT_FORMAT_32BPP                   7

/* GDIINFO.flHTFlags */
#define HT_FLAG_SQUARE_DEVICE_PEL         0x00000001
#define HT_FLAG_HAS_BLACK_DYE             0x00000002
#define HT_FLAG_ADDITIVE_PRIMS            0x00000004
#define HT_FLAG_USE_8BPP_BITMASK          0x00000008
#define HT_FLAG_INK_HIGH_ABSORPTION       0x00000010
#define HT_FLAG_INK_ABSORPTION_INDICES    0x00000060
#define HT_FLAG_DO_DEVCLR_XFORM           0x00000080
#define HT_FLAG_OUTPUT_CMY                0x00000100
#define HT_FLAG_PRINT_DRAFT_MODE          0x00000200
#define HT_FLAG_INVERT_8BPP_BITMASK_IDX   0x00000400
#define HT_FLAG_8BPP_CMY332_MASK          0xFF000000

#define MAKE_CMYMASK_BYTE(c,m,y)          ((BYTE)(((BYTE)(c) & 0x07) << 5) \
                                          |(BYTE)(((BYTE)(m) & 0x07) << 2) \
                                          |(BYTE)((BYTE)(y) & 0x03))

#define MAKE_CMY332_MASK(c,m,y)           ((DWORD)(((DWORD)(c) & 0x07) << 29)\
                                          |(DWORD)(((DWORD)(m) & 0x07) << 26)\
                                          |(DWORD)(((DWORD)(y) & 0x03) << 24))

/* GDIINFO.flHTFlags constants */
#define HT_FLAG_INK_ABSORPTION_IDX0       0x00000000
#define HT_FLAG_INK_ABSORPTION_IDX1       0x00000020
#define HT_FLAG_INK_ABSORPTION_IDX2       0x00000040
#define HT_FLAG_INK_ABSORPTION_IDX3       0x00000060

#define HT_FLAG_HIGHEST_INK_ABSORPTION    (HT_FLAG_INK_HIGH_ABSORPTION \
                                          |HT_FLAG_INK_ABSORPTION_IDX3)
#define HT_FLAG_HIGHER_INK_ABSORPTION     (HT_FLAG_INK_HIGH_ABSORPTION \
                                          |HT_FLAG_INK_ABSORPTION_IDX2)
#define HT_FLAG_HIGH_INK_ABSORPTION       (HT_FLAG_INK_HIGH_ABSORPTION \
                                          |HT_FLAG_INK_ABSORPTION_IDX1)
#define HT_FLAG_NORMAL_INK_ABSORPTION     HT_FLAG_INK_ABSORPTION_IDX0
#define HT_FLAG_LOW_INK_ABSORPTION        HT_FLAG_INK_ABSORPTION_IDX1
#define HT_FLAG_LOWER_INK_ABSORPTION      HT_FLAG_INK_ABSORPTION_IDX2
#define HT_FLAG_LOWEST_INK_ABSORPTION     HT_FLAG_INK_ABSORPTION_IDX3

#define HT_BITMASKPALRGB                  (DWORD)'0BGR'
#define HT_SET_BITMASKPAL2RGB(pPal)       (*((LPDWORD)(pPal)) = HT_BITMASKPALRGB)
#define HT_IS_BITMASKPALRGB(pPal)         (*((LPDWORD)(pPal)) == (DWORD)0)

/* GDIINFO.ulPhysicalPixelCharacteristics constants */
#define PPC_DEFAULT                       0x0
#define PPC_UNDEFINED                     0x1
#define PPC_RGB_ORDER_VERTICAL_STRIPES    0x2
#define PPC_BGR_ORDER_VERTICAL_STRIPES    0x3
#define PPC_RGB_ORDER_HORIZONTAL_STRIPES  0x4
#define PPC_BGR_ORDER_HORIZONTAL_STRIPES  0x5

#define PPG_DEFAULT                       0
#define PPG_SRGB                          1

typedef struct _GDIINFO {
  ULONG  ulVersion;
  ULONG  ulTechnology;
  ULONG  ulHorzSize;
  ULONG  ulVertSize;
  ULONG  ulHorzRes;
  ULONG  ulVertRes;
  ULONG  cBitsPixel;
  ULONG  cPlanes;
  ULONG  ulNumColors;
  ULONG  flRaster;
  ULONG  ulLogPixelsX;
  ULONG  ulLogPixelsY;
  ULONG  flTextCaps;
  ULONG  ulDACRed;
  ULONG  ulDACGreen;
  ULONG  ulDACBlue;
  ULONG  ulAspectX;
  ULONG  ulAspectY;
  ULONG  ulAspectXY;
  LONG  xStyleStep;
  LONG  yStyleStep;
  LONG  denStyleStep;
  POINTL  ptlPhysOffset;
  SIZEL  szlPhysSize;
  ULONG  ulNumPalReg;
  COLORINFO  ciDevice;
  ULONG  ulDevicePelsDPI;
  ULONG  ulPrimaryOrder;
  ULONG  ulHTPatternSize;
  ULONG  ulHTOutputFormat;
  ULONG  flHTFlags;
  ULONG  ulVRefresh;
  ULONG  ulBltAlignment;
  ULONG  ulPanningHorzRes;
  ULONG  ulPanningVertRes;
  ULONG  xPanningAlignment;
  ULONG  yPanningAlignment;
  ULONG  cxHTPat;
  ULONG  cyHTPat;
  LPBYTE  pHTPatA;
  LPBYTE  pHTPatB;
  LPBYTE  pHTPatC;
  ULONG  flShadeBlend;
  ULONG  ulPhysicalPixelCharacteristics;
  ULONG  ulPhysicalPixelGamma;
} GDIINFO, *PGDIINFO;

/* PATHDATA.flags constants */
#define PD_BEGINSUBPATH                   0x00000001
#define PD_ENDSUBPATH                     0x00000002
#define PD_RESETSTYLE                     0x00000004
#define PD_CLOSEFIGURE                    0x00000008
#define PD_BEZIERS                        0x00000010
#define PD_ALL                            (PD_BEGINSUBPATH \
                                          |PD_ENDSUBPATH \
                                          |PD_RESETSTYLE \
                                          |PD_CLOSEFIGURE \
                                          PD_BEZIERS)

typedef struct _PATHDATA {
  FLONG  flags;
  ULONG  count;
  POINTFIX  *pptfx;
} PATHDATA, *PPATHDATA;

/* PATHOBJ.fl constants */
#define PO_BEZIERS                        0x00000001
#define PO_ELLIPSE                        0x00000002
#define PO_ALL_INTEGERS                   0x00000004
#define PO_ENUM_AS_INTEGERS               0x00000008

typedef struct _PATHOBJ {
  FLONG  fl;
  ULONG  cCurves;
} PATHOBJ;

typedef struct _GLYPHBITS {
  POINTL  ptlOrigin;
  SIZEL  sizlBitmap;
  BYTE  aj[1];
} GLYPHBITS;

typedef union _GLYPHDEF {
  GLYPHBITS  *pgb;
  PATHOBJ  *ppo;
} GLYPHDEF;

typedef struct _GLYPHPOS {
  HGLYPH  hg;
  GLYPHDEF  *pgdf;
  POINTL  ptl;
} GLYPHPOS, *PGLYPHPOS;

typedef struct _GLYPHDATA {
  GLYPHDEF  gdf;
  HGLYPH  hg;
  FIX  fxD;
  FIX  fxA;
  FIX  fxAB;
  FIX  fxInkTop;
  FIX  fxInkBottom;
  RECTL  rclInk;
  POINTQF  ptqD;
} GLYPHDATA;

typedef struct _IFIEXTRA {
  ULONG  ulIdentifier;
  PTRDIFF  dpFontSig;
  ULONG  cig;
  PTRDIFF  dpDesignVector;
  PTRDIFF  dpAxesInfoW;
  ULONG  aulReserved[1];
} IFIEXTRA, *PIFIEXTRA;

/* IFIMETRICS constants */

#define FM_VERSION_NUMBER                 0x0

/* IFIMETRICS.fsType constants */
#define FM_TYPE_LICENSED                  0x2
#define FM_READONLY_EMBED                 0x4
#define FM_EDITABLE_EMBED                 0x8
#define FM_NO_EMBEDDING                   FM_TYPE_LICENSED

/* IFIMETRICS.flInfo constants */
#define FM_INFO_TECH_TRUETYPE             0x00000001
#define FM_INFO_TECH_BITMAP               0x00000002
#define FM_INFO_TECH_STROKE               0x00000004
#define FM_INFO_TECH_OUTLINE_NOT_TRUETYPE 0x00000008
#define FM_INFO_ARB_XFORMS                0x00000010
#define FM_INFO_1BPP                      0x00000020
#define FM_INFO_4BPP                      0x00000040
#define FM_INFO_8BPP                      0x00000080
#define FM_INFO_16BPP                     0x00000100
#define FM_INFO_24BPP                     0x00000200
#define FM_INFO_32BPP                     0x00000400
#define FM_INFO_INTEGER_WIDTH             0x00000800
#define FM_INFO_CONSTANT_WIDTH            0x00001000
#define FM_INFO_NOT_CONTIGUOUS            0x00002000
#define FM_INFO_TECH_MM                   0x00004000
#define FM_INFO_RETURNS_OUTLINES          0x00008000
#define FM_INFO_RETURNS_STROKES           0x00010000
#define FM_INFO_RETURNS_BITMAPS           0x00020000
#define FM_INFO_DSIG                      0x00040000
#define FM_INFO_RIGHT_HANDED              0x00080000
#define FM_INFO_INTEGRAL_SCALING          0x00100000
#define FM_INFO_90DEGREE_ROTATIONS        0x00200000
#define FM_INFO_OPTICALLY_FIXED_PITCH     0x00400000
#define FM_INFO_DO_NOT_ENUMERATE          0x00800000
#define FM_INFO_ISOTROPIC_SCALING_ONLY    0x01000000
#define FM_INFO_ANISOTROPIC_SCALING_ONLY  0x02000000
#define FM_INFO_TECH_CFF                  0x04000000
#define FM_INFO_FAMILY_EQUIV              0x08000000
#define FM_INFO_DBCS_FIXED_PITCH          0x10000000
#define FM_INFO_NONNEGATIVE_AC            0x20000000
#define FM_INFO_IGNORE_TC_RA_ABLE         0x40000000
#define FM_INFO_TECH_TYPE1                0x80000000

#define MAXCHARSETS                       16

/* IFIMETRICS.ulPanoseCulture constants */
#define  FM_PANOSE_CULTURE_LATIN          0x0

typedef struct _IFIMETRICS {
  ULONG  cjThis;
  ULONG  cjIfiExtra;
  PTRDIFF  dpwszFamilyName;
  PTRDIFF  dpwszStyleName;
  PTRDIFF  dpwszFaceName;
  PTRDIFF  dpwszUniqueName;
  PTRDIFF  dpFontSim;
  LONG  lEmbedId;
  LONG  lItalicAngle;
  LONG  lCharBias;
  PTRDIFF  dpCharSets;
  BYTE  jWinCharSet;
  BYTE  jWinPitchAndFamily;
  USHORT  usWinWeight;
  ULONG  flInfo;
  USHORT  fsSelection;
  USHORT  fsType;
  FWORD  fwdUnitsPerEm;
  FWORD  fwdLowestPPEm;
  FWORD  fwdWinAscender;
  FWORD  fwdWinDescender;
  FWORD  fwdMacAscender;
  FWORD  fwdMacDescender;
  FWORD  fwdMacLineGap;
  FWORD  fwdTypoAscender;
  FWORD  fwdTypoDescender;
  FWORD  fwdTypoLineGap;
  FWORD  fwdAveCharWidth;
  FWORD  fwdMaxCharInc;
  FWORD  fwdCapHeight;
  FWORD  fwdXHeight;
  FWORD  fwdSubscriptXSize;
  FWORD  fwdSubscriptYSize;
  FWORD  fwdSubscriptXOffset;
  FWORD  fwdSubscriptYOffset;
  FWORD  fwdSuperscriptXSize;
  FWORD  fwdSuperscriptYSize;
  FWORD  fwdSuperscriptXOffset;
  FWORD  fwdSuperscriptYOffset;
  FWORD  fwdUnderscoreSize;
  FWORD  fwdUnderscorePosition;
  FWORD  fwdStrikeoutSize;
  FWORD  fwdStrikeoutPosition;
  BYTE  chFirstChar;
  BYTE  chLastChar;
  BYTE  chDefaultChar;
  BYTE  chBreakChar;
  WCHAR  wcFirstChar;
  WCHAR  wcLastChar;
  WCHAR  wcDefaultChar;
  WCHAR  wcBreakChar;
  POINTL  ptlBaseline;
  POINTL  ptlAspect;
  POINTL  ptlCaret;
  RECTL  rclFontBox;
  BYTE  achVendId[4];
  ULONG  cKerningPairs;
  ULONG  ulPanoseCulture;
  PANOSE  panose;
#if defined(_WIN64)
  PVOID  Align;
#endif
} IFIMETRICS, *PIFIMETRICS;

/* LINEATTRS.fl */
#define LA_GEOMETRIC                      0x00000001
#define LA_ALTERNATE                      0x00000002
#define LA_STARTGAP                       0x00000004
#define LA_STYLED                         0x00000008

/* LINEATTRS.iJoin */
#define JOIN_ROUND                        __MSABI_LONG(0)
#define JOIN_BEVEL                        __MSABI_LONG(1)
#define JOIN_MITER                        __MSABI_LONG(2)

/* LINEATTRS.iEndCap */
#define ENDCAP_ROUND                      __MSABI_LONG(0)
#define ENDCAP_SQUARE                     __MSABI_LONG(1)
#define ENDCAP_BUTT                       __MSABI_LONG(2)

typedef struct _LINEATTRS {
  FLONG  fl;
  ULONG  iJoin;
  ULONG  iEndCap;
  FLOAT_LONG  elWidth;
  FLOATL  eMiterLimit;
  ULONG  cstyle;
  PFLOAT_LONG  pstyle;
  FLOAT_LONG  elStyleState;
} LINEATTRS, *PLINEATTRS;

typedef struct _PALOBJ {
  ULONG  ulReserved;
} PALOBJ;

typedef struct _PERBANDINFO {
  WINBOOL  bRepeatThisBand;
  SIZEL  szlBand;
  ULONG  ulHorzRes;
  ULONG  ulVertRes;
} PERBANDINFO, *PPERBANDINFO;

/* STROBJ.flAccel constants */
#define SO_FLAG_DEFAULT_PLACEMENT        0x00000001
#define SO_HORIZONTAL                    0x00000002
#define SO_VERTICAL                      0x00000004
#define SO_REVERSED                      0x00000008
#define SO_ZERO_BEARINGS                 0x00000010
#define SO_CHAR_INC_EQUAL_BM_BASE        0x00000020
#define SO_MAXEXT_EQUAL_BM_SIDE          0x00000040
#define SO_DO_NOT_SUBSTITUTE_DEVICE_FONT 0x00000080
#define SO_GLYPHINDEX_TEXTOUT            0x00000100
#define SO_ESC_NOT_ORIENT                0x00000200
#define SO_DXDY                          0x00000400
#define SO_CHARACTER_EXTRA               0x00000800
#define SO_BREAK_EXTRA                   0x00001000

typedef struct _STROBJ {
  ULONG  cGlyphs;
  FLONG  flAccel;
  ULONG  ulCharInc;
  RECTL  rclBkGround;
  GLYPHPOS  *pgp;
  LPWSTR  pwszOrg;
} STROBJ;



/* SURFOBJ.iType constants */
#define STYPE_BITMAP                      __MSABI_LONG(0)
#define STYPE_DEVICE                      __MSABI_LONG(1)
#define STYPE_DEVBITMAP                   __MSABI_LONG(3)

/* SURFOBJ.fjBitmap constants */
#define BMF_TOPDOWN                       0x0001
#define BMF_NOZEROINIT                    0x0002
#define BMF_DONTCACHE                     0x0004
#define BMF_USERMEM                       0x0008
#define BMF_KMSECTION                     0x0010
#define BMF_NOTSYSMEM                     0x0020
#define BMF_WINDOW_BLT                    0x0040
#define BMF_UMPDMEM                       0x0080
#define BMF_RESERVED                      0xFF00

typedef struct _SURFOBJ {
  DHSURF  dhsurf;
  HSURF  hsurf;
  DHPDEV  dhpdev;
  HDEV  hdev;
  SIZEL  sizlBitmap;
  ULONG  cjBits;
  PVOID  pvBits;
  PVOID  pvScan0;
  LONG  lDelta;
  ULONG  iUniq;
  ULONG  iBitmapFormat;
  USHORT  iType;
  USHORT  fjBitmap;
} SURFOBJ;

typedef struct _TYPE1_FONT {
  HANDLE  hPFM;
  HANDLE  hPFB;
  ULONG  ulIdentifier;
} TYPE1_FONT;

typedef struct _WNDOBJ {
  CLIPOBJ  coClient;
  PVOID  pvConsumer;
  RECTL  rclClient;
  SURFOBJ  *psoOwner;
} WNDOBJ, *PWNDOBJ;

typedef struct _XFORML {
  FLOATL  eM11;
  FLOATL  eM12;
  FLOATL  eM21;
  FLOATL  eM22;
  FLOATL  eDx;
  FLOATL  eDy;
} XFORML, *PXFORML;

typedef struct _XFORMOBJ {
  ULONG  ulReserved;
} XFORMOBJ;

/* XLATEOBJ.flXlate constants */
#define XO_TRIVIAL                        0x00000001
#define XO_TABLE                          0x00000002
#define XO_TO_MONO                        0x00000004
#define XO_FROM_CMYK                      0x00000008
#define XO_DEVICE_ICM                     0x00000010
#define XO_HOST_ICM                       0x00000020

typedef struct _XLATEOBJ {
  ULONG  iUniq;
  FLONG  flXlate;
  USHORT  iSrcType;
  USHORT  iDstType;
  ULONG  cEntries;
  ULONG  *pulXlate;
} XLATEOBJ;

/* WNDOBJCHANGEPROC.fl constants */
#define WOC_RGN_CLIENT_DELTA              0x00000001
#define WOC_RGN_CLIENT                    0x00000002
#define WOC_RGN_SURFACE_DELTA             0x00000004
#define WOC_RGN_SURFACE                   0x00000008
#define WOC_CHANGED                       0x00000010
#define WOC_DELETE                        0x00000020
#define WOC_DRAWN                         0x00000040
#define WOC_SPRITE_OVERLAP                0x00000080
#define WOC_SPRITE_NO_OVERLAP             0x00000100

typedef VOID (APIENTRY CALLBACK *WNDOBJCHANGEPROC)(
  WNDOBJ  *pwo,
  FLONG  fl);


WIN32KAPI
HANDLE
APIENTRY
BRUSHOBJ_hGetColorTransform(
  BRUSHOBJ  *pbo);

WIN32KAPI
PVOID
APIENTRY
BRUSHOBJ_pvAllocRbrush(
  BRUSHOBJ  *pbo,
  ULONG  cj);

WIN32KAPI
PVOID
APIENTRY
BRUSHOBJ_pvGetRbrush(
  BRUSHOBJ  *pbo);

WIN32KAPI
ULONG
APIENTRY
BRUSHOBJ_ulGetBrushColor(
  BRUSHOBJ  *pbo);

WIN32KAPI
WINBOOL
APIENTRY
CLIPOBJ_bEnum(
  CLIPOBJ  *pco,
  ULONG  cj,
  ULONG  *pv);

/* CLIPOBJ_cEnumStart.iType constants */
#define CT_RECTANGLES                     __MSABI_LONG(0)

/* CLIPOBJ_cEnumStart.iDirection constants */
#define CD_RIGHTDOWN                      0x00000000
#define CD_LEFTDOWN                       0x00000001
#define CD_LEFTWARDS                      0x00000001
#define CD_RIGHTUP                        0x00000002
#define CD_UPWARDS                        0x00000002
#define CD_LEFTUP                         0x00000003
#define CD_ANY                            0x00000004

WIN32KAPI
ULONG
APIENTRY
CLIPOBJ_cEnumStart(
  CLIPOBJ  *pco,
  WINBOOL  bAll,
  ULONG  iType,
  ULONG  iDirection,
  ULONG  cLimit);

WIN32KAPI
PATHOBJ*
APIENTRY
CLIPOBJ_ppoGetPath(
  CLIPOBJ  *pco);

WIN32KAPI
VOID
APIENTRY
EngAcquireSemaphore(
  HSEMAPHORE  hsem);

#define FL_ZERO_MEMORY                    0x00000001
#define FL_NONPAGED_MEMORY                0x00000002

WIN32KAPI
PVOID
APIENTRY
EngAllocMem(
  ULONG  Flags,
  ULONG  MemSize,
  ULONG  Tag);

WIN32KAPI
PVOID
APIENTRY
EngAllocPrivateUserMem(
  PDD_SURFACE_LOCAL  psl,
  SIZE_T  cj,
  ULONG  tag);

WIN32KAPI
PVOID
APIENTRY
EngAllocUserMem(
  SIZE_T  cj,
  ULONG  tag);

WIN32KAPI
WINBOOL
APIENTRY
EngAlphaBlend(
  SURFOBJ  *psoDest,
  SURFOBJ  *psoSrc,
  CLIPOBJ  *pco,
  XLATEOBJ  *pxlo,
  RECTL  *prclDest,
  RECTL  *prclSrc,
  BLENDOBJ  *pBlendObj);

/* EngAssociateSurface.flHooks constants */
#define HOOK_BITBLT                       0x00000001
#define HOOK_STRETCHBLT                   0x00000002
#define HOOK_PLGBLT                       0x00000004
#define HOOK_TEXTOUT                      0x00000008
#define HOOK_PAINT                        0x00000010
#define HOOK_STROKEPATH                   0x00000020
#define HOOK_FILLPATH                     0x00000040
#define HOOK_STROKEANDFILLPATH            0x00000080
#define HOOK_LINETO                       0x00000100
#define HOOK_COPYBITS                     0x00000400
#define HOOK_MOVEPANNING                  0x00000800
#define HOOK_SYNCHRONIZE                  0x00001000
#define HOOK_STRETCHBLTROP                0x00002000
#define HOOK_SYNCHRONIZEACCESS            0x00004000
#define HOOK_TRANSPARENTBLT               0x00008000
#define HOOK_ALPHABLEND                   0x00010000
#define HOOK_GRADIENTFILL                 0x00020000
#define HOOK_FLAGS                        0x0003b5ff

WIN32KAPI
WINBOOL
APIENTRY
EngAssociateSurface(
  HSURF  hsurf,
  HDEV  hdev,
  FLONG  flHooks);

WIN32KAPI
WINBOOL
APIENTRY
EngBitBlt(
  SURFOBJ  *psoTrg,
  SURFOBJ  *psoSrc,
  SURFOBJ  *psoMask,
  CLIPOBJ  *pco,
  XLATEOBJ  *pxlo,
  RECTL  *prclTrg,
  POINTL  *pptlSrc,
  POINTL  *pptlMask,
  BRUSHOBJ  *pbo,
  POINTL  *pptlBrush,
  ROP4  rop4);

WIN32KAPI
WINBOOL
APIENTRY
EngCheckAbort(
  SURFOBJ  *pso);

WIN32KAPI
VOID
APIENTRY
EngClearEvent(
  PEVENT  pEvent);

WIN32KAPI
FD_GLYPHSET*
APIENTRY
EngComputeGlyphSet(
  INT  nCodePage,
  INT  nFirstChar,
  INT  cChars);

/* EngControlSprites.fl constants */
#define ECS_TEARDOWN                      0x00000001
#define ECS_REDRAW                        0x00000002

WIN32KAPI
WINBOOL
APIENTRY
EngControlSprites(
  WNDOBJ  *pwo,
  FLONG  fl);

WIN32KAPI
WINBOOL
APIENTRY
EngCopyBits(
  SURFOBJ  *psoDest,
  SURFOBJ  *psoSrc,
  CLIPOBJ  *pco,
  XLATEOBJ  *pxlo,
  RECTL  *prclDest,
  POINTL  *pptlSrc);

WIN32KAPI
HBITMAP
APIENTRY
EngCreateBitmap(
  SIZEL  sizl,
  LONG  lWidth,
  ULONG  iFormat,
  FLONG  fl,
  PVOID  pvBits);

WIN32KAPI
CLIPOBJ*
APIENTRY
EngCreateClip(
  VOID);

WIN32KAPI
HBITMAP
APIENTRY
EngCreateDeviceBitmap(
  DHSURF  dhsurf,
  SIZEL  sizl,
  ULONG  iFormatCompat);

WIN32KAPI
HSURF
APIENTRY
EngCreateDeviceSurface(
  DHSURF  dhsurf,
  SIZEL  sizl,
  ULONG  iFormatCompat);

#if 0
WIN32KAPI
HDRVOBJ
APIENTRY
EngCreateDriverObj(
  PVOID  pvObj,
  FREEOBJPROC  pFreeObjProc,
  HDEV  hdev);
#endif

WIN32KAPI
WINBOOL
APIENTRY
EngCreateEvent(
  PEVENT  *ppEvent);

/* EngCreatePalette.iMode constants */
#define PAL_INDEXED                       0x00000001
#define PAL_BITFIELDS                     0x00000002
#define PAL_RGB                           0x00000004
#define PAL_BGR                           0x00000008
#define PAL_CMYK                          0x00000010

WIN32KAPI
HPALETTE
APIENTRY
EngCreatePalette(
  ULONG  iMode,
  ULONG  cColors,
  ULONG  *pulColors,
  FLONG  flRed,
  FLONG  flGreen,
  FLONG  flBlue);

WIN32KAPI
PATHOBJ*
APIENTRY
EngCreatePath(
  VOID);

WIN32KAPI
HSEMAPHORE
APIENTRY
EngCreateSemaphore(
  VOID);

/* EngCreateWnd.fl constants */
#define WO_RGN_CLIENT_DELTA               0x00000001
#define WO_RGN_CLIENT                     0x00000002
#define WO_RGN_SURFACE_DELTA              0x00000004
#define WO_RGN_SURFACE                    0x00000008
#define WO_RGN_UPDATE_ALL                 0x00000010
#define WO_RGN_WINDOW                     0x00000020
#define WO_DRAW_NOTIFY                    0x00000040
#define WO_SPRITE_NOTIFY                  0x00000080
#define WO_RGN_DESKTOP_COORD              0x00000100

WIN32KAPI
WNDOBJ*
APIENTRY
EngCreateWnd(
  SURFOBJ  *pso,
  HWND  hwnd,
  WNDOBJCHANGEPROC  pfn,
  FLONG  fl,
  int  iPixelFormat);

WIN32KAPI
VOID
APIENTRY
EngDebugBreak(
  VOID);

WIN32KAPI
VOID
APIENTRY
EngDebugPrint(
  PCHAR StandardPrefix,
  PCHAR DebugMessage,
  va_list ap);

WIN32KAPI
VOID
APIENTRY
EngDeleteClip(
  CLIPOBJ  *pco);

WIN32KAPI
WINBOOL
APIENTRY
EngDeleteDriverObj(
  HDRVOBJ  hdo,
  WINBOOL  bCallBack,
  WINBOOL  bLocked);

WIN32KAPI
WINBOOL
APIENTRY
EngDeleteEvent(
  PEVENT  pEvent);

WIN32KAPI
WINBOOL
APIENTRY
EngDeleteFile(
  LPWSTR  pwszFileName);

WIN32KAPI
WINBOOL
APIENTRY
EngDeletePalette(
  HPALETTE  hpal);

WIN32KAPI
VOID
APIENTRY
EngDeletePath(
  PATHOBJ  *ppo);

WIN32KAPI
VOID
APIENTRY
EngDeleteSafeSemaphore(
  ENGSAFESEMAPHORE  *pssem);

WIN32KAPI
VOID
APIENTRY
EngDeleteSemaphore(
  HSEMAPHORE  hsem);

WIN32KAPI
WINBOOL
APIENTRY
EngDeleteSurface(
  HSURF  hsurf);

WIN32KAPI
VOID
APIENTRY
EngDeleteWnd(
  WNDOBJ  *pwo);

WIN32KAPI
DWORD
APIENTRY
EngDeviceIoControl(
  HANDLE  hDevice,
  DWORD  dwIoControlCode,
  LPVOID  lpInBuffer,
  DWORD  nInBufferSize,
  LPVOID  lpOutBuffer,
  DWORD  nOutBufferSize,
  LPDWORD  lpBytesReturned);

WIN32KAPI
ULONG
APIENTRY
EngDitherColor(
  HDEV  hdev,
  ULONG  iMode,
  ULONG  rgb,
  ULONG  *pul);

WIN32KAPI
WINBOOL
APIENTRY
EngEnumForms(
  HANDLE  hPrinter,
  DWORD  Level,
  LPBYTE  pForm,
  DWORD  cbBuf,
  LPDWORD  pcbNeeded,
  LPDWORD  pcReturned);

WIN32KAPI
WINBOOL
APIENTRY
EngEraseSurface(
  SURFOBJ  *pso,
  RECTL  *prcl,
  ULONG  iColor);

WIN32KAPI
WINBOOL
APIENTRY
EngFillPath(
  SURFOBJ  *pso,
  PATHOBJ  *ppo,
  CLIPOBJ  *pco,
  BRUSHOBJ  *pbo,
  POINTL  *pptlBrushOrg,
  MIX  mix,
  FLONG  flOptions);

WIN32KAPI
PVOID
APIENTRY
EngFindImageProcAddress(
  HANDLE  hModule,
  LPSTR  lpProcName);

WIN32KAPI
PVOID
APIENTRY
EngFindResource(
  HANDLE  h,
  int  iName,
  int  iType,
  PULONG  pulSize);

WIN32KAPI
PVOID
APIENTRY
EngFntCacheAlloc(
  ULONG  FastCheckSum,
  ULONG  ulSize);

/* EngFntCacheFault.iFaultMode constants */
#define ENG_FNT_CACHE_READ_FAULT          0x00000001
#define ENG_FNT_CACHE_WRITE_FAULT         0x00000002

WIN32KAPI
VOID
APIENTRY
EngFntCacheFault(
  ULONG  ulFastCheckSum,
  ULONG  iFaultMode);

WIN32KAPI
PVOID
APIENTRY
EngFntCacheLookUp(
  ULONG  FastCheckSum,
  ULONG  *pulSize);

WIN32KAPI
VOID
APIENTRY
EngFreeMem(
  PVOID  Mem);

WIN32KAPI
VOID
APIENTRY
EngFreeModule(
  HANDLE  h);

WIN32KAPI
VOID
APIENTRY
EngFreePrivateUserMem(
  PDD_SURFACE_LOCAL  psl,
  PVOID  pv);

WIN32KAPI
VOID
APIENTRY
EngFreeUserMem(
  PVOID  pv);

WIN32KAPI
VOID
APIENTRY
EngGetCurrentCodePage(
  PUSHORT  OemCodePage,
  PUSHORT  AnsiCodePage);

WIN32KAPI
HANDLE
APIENTRY
EngGetCurrentProcessId(
  VOID);

WIN32KAPI
HANDLE
APIENTRY
EngGetCurrentThreadId(
  VOID);

WIN32KAPI
LPWSTR
APIENTRY
EngGetDriverName(
  HDEV  hdev);

WIN32KAPI
WINBOOL
APIENTRY
EngGetFileChangeTime(
  HANDLE  h,
  LARGE_INTEGER  *pChangeTime);

WIN32KAPI
WINBOOL
APIENTRY
EngGetFilePath(
  HANDLE  h,
  WCHAR  (*pDest)[MAX_PATH+1]);

WIN32KAPI
WINBOOL
APIENTRY
EngGetForm(
  HANDLE  hPrinter,
  LPWSTR  pFormName,
  DWORD  Level,
  LPBYTE  pForm,
  DWORD  cbBuf,
  LPDWORD  pcbNeeded);

WIN32KAPI
ULONG
APIENTRY
EngGetLastError(
  VOID);

WIN32KAPI
WINBOOL
APIENTRY
EngGetPrinter(
  HANDLE  hPrinter,
  DWORD  dwLevel,
  LPBYTE  pPrinter,
  DWORD  cbBuf,
  LPDWORD  pcbNeeded);

WIN32KAPI
DWORD
APIENTRY
EngGetPrinterData(
  HANDLE  hPrinter,
  LPWSTR  pValueName,
  LPDWORD  pType,
  LPBYTE  pData,
  DWORD  nSize,
  LPDWORD  pcbNeeded);

WIN32KAPI
LPWSTR
APIENTRY
EngGetPrinterDataFileName(
  HDEV  hdev);

WIN32KAPI
WINBOOL
APIENTRY
EngGetPrinterDriver(
  HANDLE  hPrinter,
  LPWSTR  pEnvironment,
  DWORD  dwLevel,
  BYTE  *lpbDrvInfo,
  DWORD  cbBuf,
  DWORD  *pcbNeeded);

WIN32KAPI
HANDLE
APIENTRY
EngGetProcessHandle(
  VOID);

WIN32KAPI
WINBOOL
APIENTRY
EngGetType1FontList(
  HDEV  hdev,
  TYPE1_FONT  *pType1Buffer,
  ULONG  cjType1Buffer,
  PULONG  pulLocalFonts,
  PULONG  pulRemoteFonts,
  LARGE_INTEGER  *pLastModified);

WIN32KAPI
WINBOOL
APIENTRY
EngGradientFill(
  SURFOBJ  *psoDest,
  CLIPOBJ  *pco,
  XLATEOBJ  *pxlo,
  TRIVERTEX  *pVertex,
  ULONG  nVertex,
  PVOID  pMesh,
  ULONG  nMesh,
  RECTL  *prclExtents,
  POINTL  *pptlDitherOrg,
  ULONG  ulMode);

/* EngHangNotification return values */
#define EHN_RESTORED                      0x00000000
#define EHN_ERROR                         0x00000001

WIN32KAPI
ULONG
APIENTRY
EngHangNotification(
  HDEV  hDev,
  PVOID  Reserved);

WIN32KAPI
WINBOOL
APIENTRY
EngInitializeSafeSemaphore(
  ENGSAFESEMAPHORE  *pssem);

WIN32KAPI
WINBOOL
APIENTRY
EngIsSemaphoreOwned(
  HSEMAPHORE  hsem);

WIN32KAPI
WINBOOL
APIENTRY
EngIsSemaphoreOwnedByCurrentThread(
  HSEMAPHORE  hsem);

WIN32KAPI
WINBOOL
APIENTRY
EngLineTo(
  SURFOBJ  *pso,
  CLIPOBJ  *pco,
  BRUSHOBJ  *pbo,
  LONG  x1,
  LONG  y1,
  LONG  x2,
  LONG  y2,
  RECTL  *prclBounds,
  MIX  mix);

WIN32KAPI
HANDLE
APIENTRY
EngLoadImage(
  LPWSTR  pwszDriver);

WIN32KAPI
HANDLE
APIENTRY
EngLoadModule(
  LPWSTR  pwsz);

WIN32KAPI
HANDLE
APIENTRY
EngLoadModuleForWrite(
  LPWSTR  pwsz,
  ULONG  cjSizeOfModule);

WIN32KAPI
PDD_SURFACE_LOCAL
APIENTRY
EngLockDirectDrawSurface(
  HANDLE  hSurface);

WIN32KAPI
DRIVEROBJ*
APIENTRY
EngLockDriverObj(
  HDRVOBJ  hdo);

WIN32KAPI
SURFOBJ*
APIENTRY
EngLockSurface(
  HSURF  hsurf);

WIN32KAPI
WINBOOL
APIENTRY
EngLpkInstalled(
  VOID);

WIN32KAPI
PEVENT
APIENTRY
EngMapEvent(
  HDEV  hDev,
  HANDLE  hUserObject,
  PVOID  Reserved1,
  PVOID  Reserved2,
  PVOID  Reserved3);

WIN32KAPI
PVOID
APIENTRY
EngMapFile(
  LPWSTR  pwsz,
  ULONG  cjSize,
  ULONG_PTR  *piFile);

WIN32KAPI
WINBOOL
APIENTRY
EngMapFontFile(
  ULONG_PTR  iFile,
  PULONG  *ppjBuf,
  ULONG  *pcjBuf);

WIN32KAPI
WINBOOL
APIENTRY
EngMapFontFileFD(
  ULONG_PTR  iFile,
  PULONG  *ppjBuf,
  ULONG  *pcjBuf);

WIN32KAPI
PVOID
APIENTRY
EngMapModule(
  HANDLE  h,
  PULONG  pSize);

WIN32KAPI
WINBOOL
APIENTRY
EngMarkBandingSurface(
  HSURF  hsurf);

/* EngModifySurface.flSurface constants */
#define MS_NOTSYSTEMMEMORY                0x00000001
#define MS_SHAREDACCESS                   0x00000002

WIN32KAPI
WINBOOL
APIENTRY
EngModifySurface(
  HSURF  hsurf,
  HDEV  hdev,
  FLONG  flHooks,
  FLONG  flSurface,
  DHSURF  dhsurf,
  VOID  *pvScan0,
  LONG  lDelta,
  VOID  *pvReserved);

WIN32KAPI
VOID
APIENTRY
EngMovePointer(
  SURFOBJ  *pso,
  LONG  x,
  LONG  y,
  RECTL  *prcl);

WIN32KAPI
int
APIENTRY
EngMulDiv(
  int  a,
  int  b,
  int  c);

WIN32KAPI
VOID
APIENTRY
EngMultiByteToUnicodeN(
  LPWSTR  UnicodeString,
  ULONG  MaxBytesInUnicodeString,
  PULONG  BytesInUnicodeString,
  PCHAR  MultiByteString,
  ULONG  BytesInMultiByteString);

WIN32KAPI
INT
APIENTRY
EngMultiByteToWideChar(
  UINT  CodePage,
  LPWSTR  WideCharString,
  INT  BytesInWideCharString,
  LPSTR  MultiByteString,
  INT  BytesInMultiByteString);

WIN32KAPI
WINBOOL
APIENTRY
EngPaint(
  SURFOBJ  *pso,
  CLIPOBJ  *pco,
  BRUSHOBJ  *pbo,
  POINTL  *pptlBrushOrg,
  MIX  mix);

WIN32KAPI
WINBOOL
APIENTRY
EngPlgBlt(
  SURFOBJ  *psoTrg,
  SURFOBJ  *psoSrc,
  SURFOBJ  *psoMsk,
  CLIPOBJ  *pco,
  XLATEOBJ  *pxlo,
  COLORADJUSTMENT  *pca,
  POINTL  *pptlBrushOrg,
  POINTFIX  *pptfx,
  RECTL  *prcl,
  POINTL  *pptl,
  ULONG  iMode);

WIN32KAPI
VOID
APIENTRY
EngProbeForRead(
  PVOID  Address,
  ULONG  Length,
  ULONG  Alignment);

WIN32KAPI
VOID
APIENTRY
EngProbeForReadAndWrite(
  PVOID  Address,
  ULONG  Length,
  ULONG  Alignment);

typedef enum _ENG_DEVICE_ATTRIBUTE {
  QDA_RESERVED = 0,
  QDA_ACCELERATION_LEVEL
} ENG_DEVICE_ATTRIBUTE;

WIN32KAPI
WINBOOL
APIENTRY
EngQueryDeviceAttribute(
  HDEV  hdev,
  ENG_DEVICE_ATTRIBUTE  devAttr,
  VOID  *pvIn,
  ULONG  ulInSize,
  VOID  *pvOut,
  ULONG  ulOutSize);

WIN32KAPI
LARGE_INTEGER
APIENTRY
EngQueryFileTimeStamp(
  LPWSTR  pwsz);

WIN32KAPI
VOID
APIENTRY
EngQueryLocalTime(
  PENG_TIME_FIELDS  ptf);

WIN32KAPI
ULONG
APIENTRY
EngQueryPalette(
  HPALETTE  hPal,
  ULONG  *piMode,
  ULONG  cColors,
  ULONG  *pulColors);

WIN32KAPI
VOID
APIENTRY
EngQueryPerformanceCounter(
  LONGLONG  *pPerformanceCount);

WIN32KAPI
VOID
APIENTRY
EngQueryPerformanceFrequency(
  LONGLONG  *pFrequency);

typedef enum _ENG_SYSTEM_ATTRIBUTE {
  EngProcessorFeature = 1,
  EngNumberOfProcessors,
  EngOptimumAvailableUserMemory,
  EngOptimumAvailableSystemMemory
} ENG_SYSTEM_ATTRIBUTE;

#define QSA_MMX                           0x00000100
#define QSA_SSE                           0x00002000
#define QSA_3DNOW                         0x00004000

WIN32KAPI
WINBOOL
APIENTRY
EngQuerySystemAttribute(
  ENG_SYSTEM_ATTRIBUTE  CapNum,
  PDWORD  pCapability);

WIN32KAPI
LONG
APIENTRY
EngReadStateEvent(
  PEVENT  pEvent);

WIN32KAPI
VOID
APIENTRY
EngReleaseSemaphore(
  HSEMAPHORE  hsem);

WIN32KAPI
WINBOOL
APIENTRY
EngRestoreFloatingPointState(
  VOID  *pBuffer);

WIN32KAPI
ULONG
APIENTRY
EngSaveFloatingPointState(
  VOID  *pBuffer,
  ULONG  cjBufferSize);

WIN32KAPI
HANDLE
APIENTRY
EngSecureMem(
  PVOID  Address,
  ULONG  Length);

WIN32KAPI
LONG
APIENTRY
EngSetEvent(
  PEVENT  pEvent);

WIN32KAPI
VOID
APIENTRY
EngSetLastError(
  ULONG  iError);

WIN32KAPI
ULONG
APIENTRY
EngSetPointerShape(
  SURFOBJ  *pso,
  SURFOBJ  *psoMask,
  SURFOBJ  *psoColor,
  XLATEOBJ  *pxlo,
  LONG  xHot,
  LONG  yHot,
  LONG  x,
  LONG  y,
  RECTL  *prcl,
  FLONG  fl);

WIN32KAPI
WINBOOL
APIENTRY
EngSetPointerTag(
  HDEV  hdev,
  SURFOBJ  *psoMask,
  SURFOBJ  *psoColor,
  XLATEOBJ  *pxlo,
  FLONG  fl);

WIN32KAPI
DWORD
APIENTRY
EngSetPrinterData(
  HANDLE  hPrinter,
  LPWSTR  pType,
  DWORD  dwType,
  LPBYTE  lpbPrinterData,
  DWORD  cjPrinterData);

typedef int (CDECL *SORTCOMP)(const void *pv1, const void *pv2);

WIN32KAPI
VOID
APIENTRY
EngSort(
  PBYTE  pjBuf,
  ULONG  c,
  ULONG  cjElem,
  SORTCOMP  pfnComp);

WIN32KAPI
WINBOOL
APIENTRY
EngStretchBlt(
  SURFOBJ  *psoDest,
  SURFOBJ  *psoSrc,
  SURFOBJ  *psoMask,
  CLIPOBJ  *pco,
  XLATEOBJ  *pxlo,
  COLORADJUSTMENT  *pca,
  POINTL  *pptlHTOrg,
  RECTL  *prclDest,
  RECTL  *prclSrc,
  POINTL  *pptlMask,
  ULONG  iMode);

WIN32KAPI
WINBOOL
APIENTRY
EngStretchBltROP(
  SURFOBJ  *psoDest,
  SURFOBJ  *psoSrc,
  SURFOBJ  *psoMask,
  CLIPOBJ  *pco,
  XLATEOBJ  *pxlo,
  COLORADJUSTMENT  *pca,
  POINTL  *pptlHTOrg,
  RECTL  *prclDest,
  RECTL  *prclSrc,
  POINTL  *pptlMask,
  ULONG  iMode,
  BRUSHOBJ  *pbo,
  DWORD  rop4);

WIN32KAPI
WINBOOL
APIENTRY
EngStrokeAndFillPath(
  SURFOBJ  *pso,
  PATHOBJ  *ppo,
  CLIPOBJ  *pco,
  XFORMOBJ  *pxo,
  BRUSHOBJ  *pboStroke,
  LINEATTRS  *plineattrs,
  BRUSHOBJ  *pboFill,
  POINTL  *pptlBrushOrg,
  MIX  mixFill,
  FLONG  flOptions);

WIN32KAPI
WINBOOL
APIENTRY
EngStrokePath(
  SURFOBJ  *pso,
  PATHOBJ  *ppo,
  CLIPOBJ  *pco,
  XFORMOBJ  *pxo,
  BRUSHOBJ  *pbo,
  POINTL  *pptlBrushOrg,
  LINEATTRS  *plineattrs,
  MIX  mix);

WIN32KAPI
WINBOOL
APIENTRY
EngTextOut(
  SURFOBJ  *pso,
  STROBJ  *pstro,
  FONTOBJ  *pfo,
  CLIPOBJ  *pco,
  RECTL  *prclExtra,
  RECTL  *prclOpaque,
  BRUSHOBJ  *pboFore,
  BRUSHOBJ  *pboOpaque,
  POINTL  *pptlOrg,
  MIX  mix);

WIN32KAPI
WINBOOL
APIENTRY
EngTransparentBlt(
  SURFOBJ  *psoDst,
  SURFOBJ  *psoSrc,
  CLIPOBJ  *pco,
  XLATEOBJ  *pxlo,
  RECTL  *prclDst,
  RECTL  *prclSrc,
  ULONG  iTransColor,
  ULONG  ulReserved);

WIN32KAPI
VOID
APIENTRY
EngUnicodeToMultiByteN(
  PCHAR  MultiByteString,
  ULONG  MaxBytesInMultiByteString,
  PULONG  BytesInMultiByteString,
  PWSTR  UnicodeString,
  ULONG  BytesInUnicodeString);

WIN32KAPI
VOID
APIENTRY
EngUnloadImage(
  HANDLE  hModule);

WIN32KAPI
WINBOOL
APIENTRY
EngUnlockDirectDrawSurface(
  PDD_SURFACE_LOCAL  pSurface);

WIN32KAPI
WINBOOL
APIENTRY
EngUnlockDriverObj(
  HDRVOBJ  hdo);

WIN32KAPI
VOID
APIENTRY
EngUnlockSurface(
  SURFOBJ  *pso);

WIN32KAPI
WINBOOL
APIENTRY
EngUnmapEvent(
  PEVENT  pEvent);

WIN32KAPI
WINBOOL
APIENTRY
EngUnmapFile(
  ULONG_PTR  iFile);

WIN32KAPI
VOID
APIENTRY
EngUnmapFontFile(
  ULONG_PTR  iFile);

WIN32KAPI
VOID
APIENTRY
EngUnmapFontFileFD(
  ULONG_PTR  iFile);

WIN32KAPI
VOID
APIENTRY
EngUnsecureMem(
  HANDLE  hSecure);

WIN32KAPI
WINBOOL
APIENTRY
EngWaitForSingleObject(
  PEVENT  pEvent,
  PLARGE_INTEGER  pTimeOut);

WIN32KAPI
INT
APIENTRY
EngWideCharToMultiByte(
  UINT  CodePage,
  LPWSTR  WideCharString,
  INT  BytesInWideCharString,
  LPSTR  MultiByteString,
  INT  BytesInMultiByteString);

WIN32KAPI
WINBOOL
APIENTRY
EngWritePrinter(
  HANDLE  hPrinter,
  LPVOID  pBuf,
  DWORD  cbBuf,
  LPDWORD  pcWritten);

#if defined(_X86_) && !defined(USERMODE_DRIVER)
WIN32KAPI
VOID
APIENTRY
FLOATOBJ_Add(
  PFLOATOBJ  pf,
  PFLOATOBJ  pf1);

WIN32KAPI
VOID
APIENTRY
FLOATOBJ_AddFloat(
  PFLOATOBJ  pf,
  FLOATL  f);

WIN32KAPI
VOID
APIENTRY
FLOATOBJ_AddLong(
  PFLOATOBJ  pf,
  LONG  l);

WIN32KAPI
VOID
APIENTRY
FLOATOBJ_Div(
  PFLOATOBJ  pf,
  PFLOATOBJ  pf1);

WIN32KAPI
VOID
APIENTRY
FLOATOBJ_DivFloat(
  PFLOATOBJ  pf,
  FLOATL  f);

WIN32KAPI
VOID
APIENTRY
FLOATOBJ_DivLong(
  PFLOATOBJ  pf,
  LONG  l);

WIN32KAPI
WINBOOL
APIENTRY
FLOATOBJ_Equal(
  PFLOATOBJ  pf,
  PFLOATOBJ  pf1);

WIN32KAPI
WINBOOL
APIENTRY
FLOATOBJ_EqualLong(
  PFLOATOBJ  pf,
  LONG  l);

WIN32KAPI
LONG
APIENTRY
FLOATOBJ_GetFloat(
  PFLOATOBJ  pf);

WIN32KAPI
LONG
APIENTRY
FLOATOBJ_GetLong(
  PFLOATOBJ  pf);

WIN32KAPI
WINBOOL
APIENTRY
FLOATOBJ_GreaterThan(
  PFLOATOBJ  pf,
  PFLOATOBJ  pf1);

WIN32KAPI
WINBOOL
APIENTRY
FLOATOBJ_GreaterThanLong(
  PFLOATOBJ  pf,
  LONG  l);

WIN32KAPI
WINBOOL
APIENTRY
FLOATOBJ_LessThan(
  PFLOATOBJ  pf,
  PFLOATOBJ  pf1);

WIN32KAPI
WINBOOL
APIENTRY
FLOATOBJ_LessThanLong(
  PFLOATOBJ  pf,
  LONG  l);

WIN32KAPI
VOID
APIENTRY
FLOATOBJ_Mul(
  PFLOATOBJ  pf,
  PFLOATOBJ  pf1);

WIN32KAPI
VOID
APIENTRY
FLOATOBJ_MulFloat(
  PFLOATOBJ  pf,
  FLOATL  f);

WIN32KAPI
VOID
APIENTRY
FLOATOBJ_MulLong(
  PFLOATOBJ  pf,
  LONG  l);

WIN32KAPI
VOID
APIENTRY
FLOATOBJ_Neg(
  PFLOATOBJ  pf);

WIN32KAPI
VOID
APIENTRY
FLOATOBJ_SetFloat(
  PFLOATOBJ  pf,
  FLOATL  f);

WIN32KAPI
VOID
APIENTRY
FLOATOBJ_SetLong(
  PFLOATOBJ  pf,
  LONG  l);

WIN32KAPI
VOID
APIENTRY
FLOATOBJ_Sub(
  PFLOATOBJ  pf,
  PFLOATOBJ  pf1);

WIN32KAPI
VOID
APIENTRY
FLOATOBJ_SubFloat(
  PFLOATOBJ  pf,
  FLOATL  f);

WIN32KAPI
VOID
APIENTRY
FLOATOBJ_SubLong(
  PFLOATOBJ  pf,
  LONG  l);

#else

#define FLOATOBJ_SetFloat(pf, f)        {*(pf) = (f);}
#define FLOATOBJ_SetLong(pf, l)         {*(pf) = (FLOAT)(l);}
#define FLOATOBJ_GetFloat(pf)           (*(PULONG)(pf))
#define FLOATOBJ_GetLong(pf)            ((LONG)*(pf))
#define FLOATOBJ_Add(pf, pf1)           {*(pf) += *(pf1);}
#define FLOATOBJ_AddFloat(pf, f)        {*(pf) += (f);}
#define FLOATOBJ_AddLong(pf, l)         {*(pf) += (l);}
#define FLOATOBJ_Sub(pf, pf1)           {*(pf) -= *(pf1);}
#define FLOATOBJ_SubFloat(pf, f)        {*(pf) -= (f);}
#define FLOATOBJ_SubLong(pf, l)         {*(pf) -= (l);}
#define FLOATOBJ_Mul(pf, pf1)           {*(pf) *= *(pf1);}
#define FLOATOBJ_MulFloat(pf, f)        {*(pf) *= (f);}
#define FLOATOBJ_MulLong(pf, l)         {*(pf) *= (l);}
#define FLOATOBJ_Div(pf, pf1)           {*(pf) /= *(pf1);}
#define FLOATOBJ_DivFloat(pf, f)        {*(pf) /= (f);}
#define FLOATOBJ_DivLong(pf, l)         {*(pf) /= (l);}
#define FLOATOBJ_Neg(pf)                {*(pf) = -(*(pf));}
#define FLOATOBJ_Equal(pf, pf1)         (*(pf) == *(pf1))
#define FLOATOBJ_GreaterThan(pf, pf1)   (*(pf) > *(pf1))
#define FLOATOBJ_LessThan(pf, pf1)      (*(pf) < *(pf1))
#define FLOATOBJ_EqualLong(pf, l)       (*(pf) == (FLOAT)(l))
#define FLOATOBJ_GreaterThanLong(pf, l) (*(pf) > (FLOAT)(l))
#define FLOATOBJ_LessThanLong(pf, l)    (*(pf) < (FLOAT)(l))

#endif

WIN32KAPI
ULONG
APIENTRY
FONTOBJ_cGetAllGlyphHandles(
  FONTOBJ  *pfo,
  HGLYPH  *phg);

WIN32KAPI
ULONG
APIENTRY
FONTOBJ_cGetGlyphs(
  FONTOBJ  *pfo,
  ULONG  iMode,
  ULONG  cGlyph,
  HGLYPH  *phg,
  PVOID  *ppvGlyph);

WIN32KAPI
FD_GLYPHSET*
APIENTRY
FONTOBJ_pfdg(
  FONTOBJ  *pfo);

WIN32KAPI
IFIMETRICS*
APIENTRY
FONTOBJ_pifi(
  FONTOBJ  *pfo);

WIN32KAPI
PBYTE
APIENTRY
FONTOBJ_pjOpenTypeTablePointer(
  FONTOBJ  *pfo,
  ULONG  ulTag,
  ULONG  *pcjTable);

WIN32KAPI
PFD_GLYPHATTR
APIENTRY
FONTOBJ_pQueryGlyphAttrs(
  FONTOBJ  *pfo,
  ULONG  iMode);

WIN32KAPI
PVOID
APIENTRY
FONTOBJ_pvTrueTypeFontFile(
  FONTOBJ  *pfo,
  ULONG  *pcjFile);

WIN32KAPI
LPWSTR
APIENTRY
FONTOBJ_pwszFontFilePaths(
  FONTOBJ  *pfo,
  ULONG  *pcwc);

WIN32KAPI
XFORMOBJ*
APIENTRY
FONTOBJ_pxoGetXform(
  FONTOBJ  *pfo);

WIN32KAPI
VOID
APIENTRY
FONTOBJ_vGetInfo(
  FONTOBJ  *pfo,
  ULONG  cjSize,
  FONTINFO  *pfi);



WIN32KAPI
LONG
APIENTRY
HT_ComputeRGBGammaTable(
  USHORT  GammaTableEntries,
  USHORT  GammaTableType,
  USHORT  RedGamma,
  USHORT  GreenGamma,
  USHORT  BlueGamma,
  LPBYTE  pGammaTable);

WIN32KAPI
LONG
APIENTRY
HT_Get8BPPFormatPalette(
  LPPALETTEENTRY  pPaletteEntry,
  USHORT  RedGamma,
  USHORT  GreenGamma,
  USHORT  BlueGamma);

WIN32KAPI
LONG
APIENTRY
HT_Get8BPPMaskPalette(
  LPPALETTEENTRY  pPaletteEntry,
  WINBOOL  Use8BPPMaskPal,
  BYTE  CMYMask,
  USHORT  RedGamma,
  USHORT  GreenGamma,
  USHORT  BlueGamma);

WIN32KAPI
LONG
APIENTRY
HTUI_DeviceColorAdjustment(
  LPSTR  pDeviceName,
  PDEVHTADJDATA  pDevHTAdjData);

WIN32KAPI
ULONG
APIENTRY
PALOBJ_cGetColors(
  PALOBJ  *ppalo,
  ULONG  iStart,
  ULONG  cColors,
  ULONG  *pulColors);

WIN32KAPI
WINBOOL
APIENTRY
PATHOBJ_bCloseFigure(
  PATHOBJ  *ppo);

WIN32KAPI
WINBOOL
APIENTRY
PATHOBJ_bEnum(
  PATHOBJ  *ppo,
  PATHDATA  *ppd);

WIN32KAPI
WINBOOL
APIENTRY
PATHOBJ_bEnumClipLines(
  PATHOBJ  *ppo,
  ULONG  cb,
  CLIPLINE  *pcl);

WIN32KAPI
WINBOOL
APIENTRY
PATHOBJ_bMoveTo(
  PATHOBJ  *ppo,
  POINTFIX  ptfx);

WIN32KAPI
WINBOOL
APIENTRY
PATHOBJ_bPolyBezierTo(
  PATHOBJ  *ppo,
  POINTFIX  *pptfx,
  ULONG  cptfx);

WIN32KAPI
WINBOOL
APIENTRY
PATHOBJ_bPolyLineTo(
  PATHOBJ  *ppo,
  POINTFIX  *pptfx,
  ULONG  cptfx);

WIN32KAPI
VOID
APIENTRY
PATHOBJ_vEnumStart(
  PATHOBJ  *ppo);

WIN32KAPI
VOID
APIENTRY
PATHOBJ_vEnumStartClipLines(
  PATHOBJ  *ppo,
  CLIPOBJ  *pco,
  SURFOBJ  *pso,
  LINEATTRS  *pla);

WIN32KAPI
VOID
APIENTRY
PATHOBJ_vGetBounds(
  PATHOBJ  *ppo,
  PRECTFX  prectfx);

WIN32KAPI
WINBOOL
APIENTRY
STROBJ_bEnum(
  STROBJ  *pstro,
  ULONG  *pc,
  PGLYPHPOS  *ppgpos);

WIN32KAPI
WINBOOL
APIENTRY
STROBJ_bEnumPositionsOnly(
  STROBJ  *pstro,
  ULONG  *pc,
  PGLYPHPOS  *ppgpos);

WIN32KAPI
WINBOOL
APIENTRY
STROBJ_bGetAdvanceWidths(
  STROBJ  *pso,
  ULONG  iFirst,
  ULONG  c,
  POINTQF  *pptqD);

WIN32KAPI
DWORD
APIENTRY
STROBJ_dwGetCodePage(
  STROBJ  *pstro);

WIN32KAPI
FIX
APIENTRY
STROBJ_fxBreakExtra(
  STROBJ  *pstro);

WIN32KAPI
FIX
APIENTRY
STROBJ_fxCharacterExtra(
  STROBJ  *pstro);

WIN32KAPI
VOID
APIENTRY
STROBJ_vEnumStart(
  STROBJ  *pstro);

WIN32KAPI
WINBOOL
APIENTRY
WNDOBJ_bEnum(
  WNDOBJ  *pwo,
  ULONG  cj,
  ULONG  *pul);

WIN32KAPI
ULONG
APIENTRY
WNDOBJ_cEnumStart(
  WNDOBJ  *pwo,
  ULONG  iType,
  ULONG  iDirection,
  ULONG  cLimit);

WIN32KAPI
VOID
APIENTRY
WNDOBJ_vSetConsumer(
  WNDOBJ  *pwo,
  PVOID  pvConsumer);

/* XFORMOBJ_bApplyXform.iMode constants */
#define XF_LTOL                           __MSABI_LONG(0)
#define XF_INV_LTOL                       __MSABI_LONG(1)
#define XF_LTOFX                          __MSABI_LONG(2)
#define XF_INV_FXTOL                      __MSABI_LONG(3)

WIN32KAPI
WINBOOL
APIENTRY
XFORMOBJ_bApplyXform(
  XFORMOBJ  *pxo,
  ULONG  iMode,
  ULONG  cPoints,
  PVOID  pvIn,
  PVOID  pvOut);

WIN32KAPI
ULONG
APIENTRY
XFORMOBJ_iGetFloatObjXform(
  XFORMOBJ  *pxo,
  FLOATOBJ_XFORM  *pxfo);

WIN32KAPI
ULONG
APIENTRY
XFORMOBJ_iGetXform(
  XFORMOBJ  *pxo,
  XFORML  *pxform);

/* XLATEOBJ_cGetPalette.iPal constants */
#define XO_SRCPALETTE                     1
#define XO_DESTPALETTE                    2
#define XO_DESTDCPALETTE                  3
#define XO_SRCBITFIELDS                   4
#define XO_DESTBITFIELDS                  5

WIN32KAPI
ULONG
APIENTRY
XLATEOBJ_cGetPalette(
  XLATEOBJ  *pxlo,
  ULONG  iPal,
  ULONG  cPal,
  ULONG  *pPal);

WIN32KAPI
HANDLE
APIENTRY
XLATEOBJ_hGetColorTransform(
  XLATEOBJ  *pxlo);

WIN32KAPI
ULONG
APIENTRY
XLATEOBJ_iXlate(
  XLATEOBJ  *pxlo,
  ULONG  iColor);

WIN32KAPI
ULONG*
APIENTRY
XLATEOBJ_piVector(
  XLATEOBJ  *pxlo);



/* Graphics Driver Functions */

WINBOOL
APIENTRY
DrvAlphaBlend(
  SURFOBJ  *psoDest,
  SURFOBJ  *psoSrc,
  CLIPOBJ  *pco,
  XLATEOBJ  *pxlo,
  RECTL  *prclDest,
  RECTL  *prclSrc,
  BLENDOBJ  *pBlendObj);

WINBOOL
APIENTRY
DrvAssertMode(
  DHPDEV  dhpdev,
  WINBOOL  bEnable);

WINBOOL
APIENTRY
DrvBitBlt(
  SURFOBJ  *psoTrg,
  SURFOBJ  *psoSrc,
  SURFOBJ  *psoMask,
  CLIPOBJ  *pco,
  XLATEOBJ  *pxlo,
  RECTL  *prclTrg,
  POINTL  *pptlSrc,
  POINTL  *pptlMask,
  BRUSHOBJ  *pbo,
  POINTL  *pptlBrush,
  ROP4  rop4);

VOID
APIENTRY
DrvCompletePDEV(
  DHPDEV  dhpdev,
  HDEV  hdev);

WINBOOL
APIENTRY
DrvCopyBits(
  SURFOBJ  *psoDest,
  SURFOBJ  *psoSrc,
  CLIPOBJ  *pco,
  XLATEOBJ  *pxlo,
  RECTL  *prclDest,
  POINTL  *pptlSrc);

HBITMAP
APIENTRY
DrvCreateDeviceBitmap(
  DHPDEV  dhpdev,
  SIZEL  sizl,
  ULONG  iFormat);

VOID
APIENTRY
DrvDeleteDeviceBitmap(
  DHSURF  dhsurf);

HBITMAP
APIENTRY
DrvDeriveSurface(
  DD_DIRECTDRAW_GLOBAL  *pDirectDraw,
  DD_SURFACE_LOCAL  *pSurface);

LONG
APIENTRY
DrvDescribePixelFormat(
  DHPDEV  dhpdev,
  LONG  iPixelFormat,
  ULONG  cjpfd,
  PIXELFORMATDESCRIPTOR  *ppfd);

VOID
APIENTRY
DrvDestroyFont(
  FONTOBJ  *pfo);

VOID
APIENTRY
DrvDisableDriver(
  VOID);

VOID
APIENTRY
DrvDisablePDEV(
  DHPDEV  dhpdev);

VOID
APIENTRY
DrvDisableSurface(
  DHPDEV  dhpdev);

#define DM_DEFAULT                        0x00000001
#define DM_MONOCHROME                     0x00000002

ULONG
APIENTRY
DrvDitherColor(
  DHPDEV  dhpdev,
  ULONG  iMode,
  ULONG  rgb,
  ULONG  *pul);

ULONG
APIENTRY
DrvDrawEscape(
  SURFOBJ  *pso,
  ULONG  iEsc,
  CLIPOBJ  *pco,
  RECTL  *prcl,
  ULONG  cjIn,
  PVOID  pvIn);

WINBOOL
APIENTRY
DrvEnableDriver(
  ULONG  iEngineVersion,
  ULONG  cj,
  DRVENABLEDATA  *pded);

DHPDEV
APIENTRY
DrvEnablePDEV(
  DEVMODEW  *pdm,
  LPWSTR  pwszLogAddress,
  ULONG  cPat,
  HSURF  *phsurfPatterns,
  ULONG  cjCaps,
  ULONG  *pdevcaps,
  ULONG  cjDevInfo,
  DEVINFO  *pdi,
  HDEV  hdev,
  LPWSTR  pwszDeviceName,
  HANDLE  hDriver);

HSURF
APIENTRY
DrvEnableSurface(
  DHPDEV  dhpdev);

/* DrvEndDoc.fl constants */
#define ED_ABORTDOC                       0x00000001

WINBOOL
APIENTRY
DrvEndDoc(
  SURFOBJ  *pso,
  FLONG  fl);

ULONG
APIENTRY
DrvEscape(
  SURFOBJ  *pso,
  ULONG  iEsc,
  ULONG  cjIn,
  PVOID  pvIn,
  ULONG  cjOut,
  PVOID  pvOut);

WINBOOL
APIENTRY
DrvFillPath(
  SURFOBJ  *pso,
  PATHOBJ  *ppo,
  CLIPOBJ  *pco,
  BRUSHOBJ  *pbo,
  POINTL  *pptlBrushOrg,
  MIX  mix,
  FLONG  flOptions);

ULONG
APIENTRY
DrvFontManagement(
  SURFOBJ  *pso,
  FONTOBJ  *pfo,
  ULONG  iMode,
  ULONG  cjIn,
  PVOID  pvIn,
  ULONG  cjOut,
  PVOID  pvOut);

VOID
APIENTRY
DrvFree(
  PVOID  pv,
  ULONG_PTR  id);

/* DrvGetGlyphMode return values */
#define FO_HGLYPHS                        __MSABI_LONG(0)
#define FO_GLYPHBITS                      __MSABI_LONG(1)
#define FO_PATHOBJ                        __MSABI_LONG(2)

ULONG
APIENTRY
DrvGetGlyphMode(
  DHPDEV  dhpdev,
  FONTOBJ  *pfo);

ULONG
APIENTRY
DrvGetModes(
  HANDLE  hDriver,
  ULONG  cjSize,
  DEVMODEW  *pdm);

PVOID
APIENTRY
DrvGetTrueTypeFile(
  ULONG_PTR  iFile,
  ULONG  *pcj);

WINBOOL
APIENTRY
DrvGradientFill(
  SURFOBJ  *psoDest,
  CLIPOBJ  *pco,
  XLATEOBJ  *pxlo,
  TRIVERTEX  *pVertex,
  ULONG  nVertex,
  PVOID  pMesh,
  ULONG  nMesh,
  RECTL  *prclExtents,
  POINTL  *pptlDitherOrg,
  ULONG  ulMode);

WINBOOL
APIENTRY
DrvIcmCheckBitmapBits(
  DHPDEV  dhpdev,
  HANDLE  hColorTransform,
  SURFOBJ  *pso,
  PBYTE  paResults);

HANDLE
APIENTRY
DrvIcmCreateColorTransform(
  DHPDEV  dhpdev,
  LPLOGCOLORSPACEW  pLogColorSpace,
  PVOID  pvSourceProfile,
  ULONG  cjSourceProfile,
  PVOID  pvDestProfile,
  ULONG  cjDestProfile,
  PVOID  pvTargetProfile,
  ULONG  cjTargetProfile,
  DWORD  dwReserved);

WINBOOL
APIENTRY
DrvIcmDeleteColorTransform(
  DHPDEV  dhpdev,
  HANDLE  hcmXform);

/* DrvIcmSetDeviceGammaRamp.iFormat constants */
#define IGRF_RGB_256BYTES                 0x00000000
#define IGRF_RGB_256WORDS                 0x00000001

WINBOOL
APIENTRY
DrvIcmSetDeviceGammaRamp(
  DHPDEV  dhpdev,
  ULONG  iFormat,
  LPVOID  lpRamp);

WINBOOL
APIENTRY
DrvLineTo(
  SURFOBJ  *pso,
  CLIPOBJ  *pco,
  BRUSHOBJ  *pbo,
  LONG  x1,
  LONG  y1,
  LONG  x2,
  LONG  y2,
  RECTL  *prclBounds,
  MIX  mix);

ULONG_PTR
APIENTRY
DrvLoadFontFile(
  ULONG  cFiles,
  ULONG_PTR  *piFile,
  PVOID  *ppvView,
  ULONG  *pcjView,
  DESIGNVECTOR  *pdv,
  ULONG  ulLangID,
  ULONG  ulFastCheckSum);

VOID
APIENTRY
DrvMovePointer(
  SURFOBJ  *pso,
  LONG  x,
  LONG  y,
  RECTL  *prcl);

WINBOOL
APIENTRY
DrvNextBand(
  SURFOBJ  *pso,
  POINTL  *pptl);

VOID
APIENTRY
DrvNotify(
  SURFOBJ  *pso,
  ULONG  iType,
  PVOID  pvData);

WINBOOL
APIENTRY
DrvOffset(
  SURFOBJ  *pso,
  LONG  x,
  LONG  y,
  FLONG  flReserved);

WINBOOL
APIENTRY
DrvPaint(
  SURFOBJ  *pso,
  CLIPOBJ  *pco,
  BRUSHOBJ  *pbo,
  POINTL  *pptlBrushOrg,
  MIX  mix);

WINBOOL
APIENTRY
DrvPlgBlt(
  SURFOBJ  *psoTrg,
  SURFOBJ  *psoSrc,
  SURFOBJ  *psoMsk,
  CLIPOBJ  *pco,
  XLATEOBJ  *pxlo,
  COLORADJUSTMENT  *pca,
  POINTL  *pptlBrushOrg,
  POINTFIX  *pptfx,
  RECTL  *prcl,
  POINTL  *pptl,
  ULONG  iMode);

/* DrvQueryAdvanceWidths.iMode constants */
#define QAW_GETWIDTHS                     0
#define QAW_GETEASYWIDTHS                 1

WINBOOL
APIENTRY
DrvQueryAdvanceWidths(
  DHPDEV  dhpdev,
  FONTOBJ  *pfo,
  ULONG  iMode,
  HGLYPH  *phg,
  PVOID  pvWidths,
  ULONG  cGlyphs);

/* DrvQueryDeviceSupport.iType constants */
#define QDS_CHECKJPEGFORMAT               0x00000000
#define QDS_CHECKPNGFORMAT                0x00000001

WINBOOL
APIENTRY
DrvQueryDeviceSupport(
  SURFOBJ  *pso,
  XLATEOBJ  *pxlo,
  XFORMOBJ  *pxo,
  ULONG  iType,
  ULONG  cjIn,
  PVOID  pvIn,
  ULONG  cjOut,
  PVOID  pvOut);

/* DrvQueryDriverInfo.dwMode constants */
#define DRVQUERY_USERMODE                 0x00000001

WINBOOL
APIENTRY
DrvQueryDriverInfo(
  DWORD  dwMode,
  PVOID  pBuffer,
  DWORD  cbBuf,
  PDWORD  pcbNeeded);

PIFIMETRICS
APIENTRY
DrvQueryFont(
  DHPDEV  dhpdev,
  ULONG_PTR  iFile,
  ULONG  iFace,
  ULONG_PTR  *pid);

/* DrvQueryFontCaps.pulCaps constants */
#define QC_OUTLINES                       0x00000001
#define QC_1BIT                           0x00000002
#define QC_4BIT                           0x00000004

#define QC_FONTDRIVERCAPS (QC_OUTLINES | QC_1BIT | QC_4BIT)

LONG
APIENTRY
DrvQueryFontCaps(
  ULONG  culCaps,
  ULONG  *pulCaps);

/* DrvQueryFontData.iMode constants */
#define QFD_GLYPHANDBITMAP                __MSABI_LONG(1)
#define QFD_GLYPHANDOUTLINE               __MSABI_LONG(2)
#define QFD_MAXEXTENTS                    __MSABI_LONG(3)
#define QFD_TT_GLYPHANDBITMAP             __MSABI_LONG(4)
#define QFD_TT_GRAY1_BITMAP               __MSABI_LONG(5)
#define QFD_TT_GRAY2_BITMAP               __MSABI_LONG(6)
#define QFD_TT_GRAY4_BITMAP               __MSABI_LONG(8)
#define QFD_TT_GRAY8_BITMAP               __MSABI_LONG(9)

#define QFD_TT_MONO_BITMAP QFD_TT_GRAY1_BITMAP

LONG
APIENTRY
DrvQueryFontData(
  DHPDEV  dhpdev,
  FONTOBJ  *pfo,
  ULONG  iMode,
  HGLYPH  hg,
  GLYPHDATA  *pgd,
  PVOID  pv,
  ULONG  cjSize);

/* DrvQueryFontFile.ulMode constants */
#define QFF_DESCRIPTION                   0x00000001
#define QFF_NUMFACES                      0x00000002

LONG
APIENTRY
DrvQueryFontFile(
  ULONG_PTR  iFile,
  ULONG  ulMode,
  ULONG  cjBuf,
  ULONG  *pulBuf);

/* DrvQueryFontTree.iMode constants */
#define QFT_UNICODE                       __MSABI_LONG(0)
#define QFT_LIGATURES                     __MSABI_LONG(1)
#define QFT_KERNPAIRS                     __MSABI_LONG(2)
#define QFT_GLYPHSET                      __MSABI_LONG(3)

PVOID
APIENTRY
DrvQueryFontTree(
  DHPDEV  dhpdev,
  ULONG_PTR  iFile,
  ULONG  iFace,
  ULONG  iMode,
  ULONG_PTR  *pid);

PFD_GLYPHATTR
APIENTRY
DrvQueryGlyphAttrs(
  FONTOBJ  *pfo,
  ULONG  iMode);

ULONG
APIENTRY
DrvQueryPerBandInfo(
  SURFOBJ  *pso,
  PERBANDINFO  *pbi);

/* DrvQueryTrueTypeOutline.bMetricsOnly constants */
#define TTO_METRICS_ONLY                  0x00000001
#define TTO_QUBICS                        0x00000002
#define TTO_UNHINTED                      0x00000004

LONG
APIENTRY
DrvQueryTrueTypeOutline(
  DHPDEV  dhpdev,
  FONTOBJ  *pfo,
  HGLYPH  hglyph,
  WINBOOL  bMetricsOnly,
  GLYPHDATA  *pgldt,
  ULONG  cjBuf,
  TTPOLYGONHEADER  *ppoly);

LONG
APIENTRY
DrvQueryTrueTypeTable(
  ULONG_PTR  iFile,
  ULONG  ulFont,
  ULONG  ulTag,
  PTRDIFF  dpStart,
  ULONG  cjBuf,
  BYTE  *pjBuf,
  PBYTE  *ppjTable,
  ULONG *pcjTable);

/* DrvRealizeBrush.iHatch constants */
#define RB_DITHERCOLOR                    __MSABI_LONG(0x80000000)

#define HS_DDI_MAX                        6

WINBOOL
APIENTRY
DrvRealizeBrush(
  BRUSHOBJ  *pbo,
  SURFOBJ  *psoTarget,
  SURFOBJ  *psoPattern,
  SURFOBJ  *psoMask,
  XLATEOBJ  *pxlo,
  ULONG  iHatch);

/* DrvResetDevice return values */
#define DRD_SUCCESS                       0
#define DRD_ERROR                         1

ULONG
APIENTRY
DrvResetDevice(
  DHPDEV dhpdev,
  PVOID Reserved);

WINBOOL
APIENTRY
DrvResetPDEV(
  DHPDEV  dhpdevOld,
  DHPDEV  dhpdevNew);

/* DrvSaveScreenBits.iMode constants */
#define SS_SAVE                           0x00000000
#define SS_RESTORE                        0x00000001
#define SS_FREE                           0x00000002

ULONG_PTR
APIENTRY
DrvSaveScreenBits(
  SURFOBJ  *pso,
  ULONG  iMode,
  ULONG_PTR  ident,
  RECTL  *prcl);

WINBOOL
APIENTRY
DrvSendPage(
  SURFOBJ  *pso);

WINBOOL
APIENTRY
DrvSetPalette(
  DHPDEV  dhpdev,
  PALOBJ  *ppalo,
  FLONG  fl,
  ULONG  iStart,
  ULONG  cColors);

WINBOOL
APIENTRY
DrvSetPixelFormat(
  SURFOBJ  *pso,
  LONG  iPixelFormat,
  HWND  hwnd);

/* DrvSetPointerShape return values */
#define SPS_ERROR                         0x00000000
#define SPS_DECLINE                       0x00000001
#define SPS_ACCEPT_NOEXCLUDE              0x00000002
#define SPS_ACCEPT_EXCLUDE                0x00000003
#define SPS_ACCEPT_SYNCHRONOUS            0x00000004

/* DrvSetPointerShape.fl constants */
#define SPS_CHANGE                        __MSABI_LONG(0x00000001)
#define SPS_ASYNCCHANGE                   __MSABI_LONG(0x00000002)
#define SPS_ANIMATESTART                  __MSABI_LONG(0x00000004)
#define SPS_ANIMATEUPDATE                 __MSABI_LONG(0x00000008)
#define SPS_ALPHA                         __MSABI_LONG(0x00000010)
#define SPS_LENGTHMASK                    __MSABI_LONG(0x00000F00)
#define SPS_FREQMASK                      __MSABI_LONG(0x000FF000)

ULONG
APIENTRY
DrvSetPointerShape(
  SURFOBJ  *pso,
  SURFOBJ  *psoMask,
  SURFOBJ  *psoColor,
  XLATEOBJ  *pxlo,
  LONG  xHot,
  LONG  yHot,
  LONG  x,
  LONG  y,
  RECTL  *prcl,
  FLONG  fl);

WINBOOL
APIENTRY
DrvStartBanding(
  SURFOBJ  *pso,
  POINTL  *pptl);

WINBOOL
APIENTRY
DrvStartDoc(
  SURFOBJ  *pso,
  LPWSTR  pwszDocName,
  DWORD  dwJobId);

WINBOOL
APIENTRY
DrvStartPage(
  SURFOBJ  *pso);

WINBOOL
APIENTRY
DrvStretchBlt(
  SURFOBJ  *psoDest,
  SURFOBJ  *psoSrc,
  SURFOBJ  *psoMask,
  CLIPOBJ  *pco,
  XLATEOBJ  *pxlo,
  COLORADJUSTMENT  *pca,
  POINTL  *pptlHTOrg,
  RECTL  *prclDest,
  RECTL  *prclSrc,
  POINTL  *pptlMask,
  ULONG  iMode);

WINBOOL
APIENTRY
DrvStretchBltROP(
  SURFOBJ  *psoDest,
  SURFOBJ  *psoSrc,
  SURFOBJ  *psoMask,
  CLIPOBJ  *pco,
  XLATEOBJ  *pxlo,
  COLORADJUSTMENT  *pca,
  POINTL  *pptlHTOrg,
  RECTL  *prclDest,
  RECTL  *prclSrc,
  POINTL  *pptlMask,
  ULONG  iMode,
  BRUSHOBJ  *pbo,
  DWORD  rop4);

WINBOOL
APIENTRY
DrvStrokeAndFillPath(
  SURFOBJ  *pso,
  PATHOBJ  *ppo,
  CLIPOBJ  *pco,
  XFORMOBJ  *pxo,
  BRUSHOBJ  *pboStroke,
  LINEATTRS  *plineattrs,
  BRUSHOBJ  *pboFill,
  POINTL  *pptlBrushOrg,
  MIX  mixFill,
  FLONG  flOptions);

WINBOOL
APIENTRY
DrvStrokePath(
  SURFOBJ  *pso,
  PATHOBJ  *ppo,
  CLIPOBJ  *pco,
  XFORMOBJ  *pxo,
  BRUSHOBJ  *pbo,
  POINTL  *pptlBrushOrg,
  LINEATTRS  *plineattrs,
  MIX  mix);

WINBOOL
APIENTRY
DrvSwapBuffers(
  SURFOBJ  *pso,
  WNDOBJ  *pwo);

VOID
APIENTRY
DrvSynchronize(
  DHPDEV  dhpdev,
  RECTL  *prcl);

/* DrvSynchronizeSurface.fl constants */
#define DSS_TIMER_EVENT                   0x00000001
#define DSS_FLUSH_EVENT                   0x00000002

VOID
APIENTRY
DrvSynchronizeSurface(
  SURFOBJ  *pso,
  RECTL  *prcl,
  FLONG  fl);

WINBOOL
APIENTRY
DrvTextOut(
  SURFOBJ  *pso,
  STROBJ  *pstro,
  FONTOBJ  *pfo,
  CLIPOBJ  *pco,
  RECTL  *prclExtra,
  RECTL  *prclOpaque,
  BRUSHOBJ  *pboFore,
  BRUSHOBJ  *pboOpaque,
  POINTL  *pptlOrg,
  MIX  mix);

WINBOOL
APIENTRY
DrvTransparentBlt(
  SURFOBJ  *psoDst,
  SURFOBJ  *psoSrc,
  CLIPOBJ  *pco,
  XLATEOBJ  *pxlo,
  RECTL  *prclDst,
  RECTL  *prclSrc,
  ULONG  iTransColor,
  ULONG  ulReserved);

WINBOOL
APIENTRY
DrvUnloadFontFile(
  ULONG_PTR  iFile);

typedef WINBOOL
(APIENTRY *PFN_DrvAlphaBlend)(
  SURFOBJ  *psoDest,
  SURFOBJ  *psoSrc,
  CLIPOBJ  *pco,
  XLATEOBJ  *pxlo,
  RECTL  *prclDest,
  RECTL  *prclSrc,
  BLENDOBJ  *pBlendObj);

typedef WINBOOL
(APIENTRY *PFN_DrvAssertMode)(
  DHPDEV  dhpdev,
  WINBOOL  bEnable);

typedef WINBOOL
(APIENTRY *PFN_DrvBitBlt)(
  SURFOBJ  *psoTrg,
  SURFOBJ  *psoSrc,
  SURFOBJ  *psoMask,
  CLIPOBJ  *pco,
  XLATEOBJ  *pxlo,
  RECTL  *prclTrg,
  POINTL  *pptlSrc,
  POINTL  *pptlMask,
  BRUSHOBJ  *pbo,
  POINTL  *pptlBrush,
  ROP4  rop4);

typedef VOID
(APIENTRY *PFN_DrvCompletePDEV)(
  DHPDEV  dhpdev,
  HDEV  hdev);

typedef WINBOOL
(APIENTRY *PFN_DrvCopyBits)(
  SURFOBJ  *psoDest,
  SURFOBJ  *psoSrc,
  CLIPOBJ  *pco,
  XLATEOBJ  *pxlo,
  RECTL  *prclDest,
  POINTL  *pptlSrc);

typedef HBITMAP
(APIENTRY *PFN_DrvCreateDeviceBitmap)(
  DHPDEV  dhpdev,
  SIZEL  sizl,
  ULONG  iFormat);

typedef VOID
(APIENTRY *PFN_DrvDeleteDeviceBitmap)(
  DHSURF  dhsurf);

typedef HBITMAP
(APIENTRY *PFN_DrvDeriveSurface)(
  DD_DIRECTDRAW_GLOBAL  *pDirectDraw,
  DD_SURFACE_LOCAL  *pSurface);

typedef LONG
(APIENTRY *PFN_DrvDescribePixelFormat)(
  DHPDEV  dhpdev,
  LONG  iPixelFormat,
  ULONG  cjpfd,
  PIXELFORMATDESCRIPTOR  *ppfd);

typedef VOID
(APIENTRY *PFN_DrvDestroyFont)(
  FONTOBJ  *pfo);

typedef VOID
(APIENTRY *PFN_DrvDisableDriver)(
  VOID);

typedef VOID
(APIENTRY *PFN_DrvDisablePDEV)(
  DHPDEV  dhpdev);

typedef VOID
(APIENTRY *PFN_DrvDisableSurface)(
  DHPDEV  dhpdev);

typedef ULONG
(APIENTRY *PFN_DrvDitherColor)(
  DHPDEV  dhpdev,
  ULONG  iMode,
  ULONG  rgb,
  ULONG  *pul);

typedef ULONG
(APIENTRY *PFN_DrvDrawEscape)(
  SURFOBJ  *pso,
  ULONG  iEsc,
  CLIPOBJ  *pco,
  RECTL  *prcl,
  ULONG  cjIn,
  PVOID  pvIn);

typedef WINBOOL
(APIENTRY *PFN_DrvEnableDriver)(
  ULONG  iEngineVersion,
  ULONG  cj,
  DRVENABLEDATA  *pded);

typedef DHPDEV 
(APIENTRY *PFN_DrvEnablePDEV)(
  DEVMODEW  *pdm,
  LPWSTR  pwszLogAddress,
  ULONG  cPat,
  HSURF  *phsurfPatterns,
  ULONG  cjCaps,
  GDIINFO  *pdevcaps,
  ULONG  cjDevInfo,
  DEVINFO  *pdi,
  HDEV  hdev,
  LPWSTR  pwszDeviceName,
  HANDLE  hDriver);

typedef HSURF
(APIENTRY *PFN_DrvEnableSurface)(
  DHPDEV  dhpdev);

typedef WINBOOL
(APIENTRY *PFN_DrvEndDoc)(
  SURFOBJ  *pso,
  FLONG  fl);

typedef ULONG
(APIENTRY *PFN_DrvEscape)(
  SURFOBJ  *pso,
  ULONG  iEsc,
  ULONG  cjIn,
  PVOID  pvIn,
  ULONG  cjOut,
  PVOID  pvOut);

typedef WINBOOL
(APIENTRY *PFN_DrvFillPath)(
  SURFOBJ  *pso,
  PATHOBJ  *ppo,
  CLIPOBJ  *pco,
  BRUSHOBJ  *pbo,
  POINTL  *pptlBrushOrg,
  MIX  mix,
  FLONG  flOptions);

typedef ULONG
(APIENTRY *PFN_DrvFontManagement)(
  SURFOBJ  *pso,
  FONTOBJ  *pfo,
  ULONG  iMode,
  ULONG  cjIn,
  PVOID  pvIn,
  ULONG  cjOut,
  PVOID  pvOut);

typedef VOID
(APIENTRY *PFN_DrvFree)(
  PVOID  pv,
  ULONG_PTR  id);

typedef ULONG
(APIENTRY *PFN_DrvGetGlyphMode)(
  DHPDEV  dhpdev,
  FONTOBJ  *pfo);

typedef ULONG
(APIENTRY *PFN_DrvGetModes)(
  HANDLE  hDriver,
  ULONG  cjSize,
  DEVMODEW  *pdm);

typedef PVOID
(APIENTRY *PFN_DrvGetTrueTypeFile)(
  ULONG_PTR  iFile,
  ULONG  *pcj);

typedef WINBOOL
(APIENTRY *PFN_DrvGradientFill)(
  SURFOBJ  *psoDest,
  CLIPOBJ  *pco,
  XLATEOBJ  *pxlo,
  TRIVERTEX  *pVertex,
  ULONG  nVertex,
  PVOID  pMesh,
  ULONG  nMesh,
  RECTL  *prclExtents,
  POINTL  *pptlDitherOrg,
  ULONG  ulMode);

typedef WINBOOL
(APIENTRY *PFN_DrvIcmCheckBitmapBits)(
  DHPDEV  dhpdev,
  HANDLE  hColorTransform,
  SURFOBJ  *pso,
  PBYTE  paResults);

typedef HANDLE
(APIENTRY *PFN_DrvIcmCreateColorTransform)(
  DHPDEV  dhpdev,
  LPLOGCOLORSPACEW  pLogColorSpace,
  PVOID  pvSourceProfile,
  ULONG  cjSourceProfile,
  PVOID  pvDestProfile,
  ULONG  cjDestProfile,
  PVOID  pvTargetProfile,
  ULONG  cjTargetProfile,
  DWORD  dwReserved);

typedef WINBOOL
(APIENTRY *PFN_DrvIcmDeleteColorTransform)(
  DHPDEV  dhpdev,
  HANDLE  hcmXform);

typedef WINBOOL
(APIENTRY *PFN_DrvIcmSetDeviceGammaRamp)(
  DHPDEV  dhpdev,
  ULONG  iFormat,
  LPVOID  lpRamp);

typedef WINBOOL
(APIENTRY *PFN_DrvLineTo)(
  SURFOBJ  *pso,
  CLIPOBJ  *pco,
  BRUSHOBJ  *pbo,
  LONG  x1,
  LONG  y1,
  LONG  x2,
  LONG  y2,
  RECTL  *prclBounds,
  MIX  mix);

typedef ULONG_PTR
(APIENTRY *PFN_DrvLoadFontFile)(
  ULONG  cFiles,
  ULONG_PTR  *piFile,
  PVOID  *ppvView,
  ULONG  *pcjView,
  DESIGNVECTOR  *pdv,
  ULONG  ulLangID,
  ULONG  ulFastCheckSum);

typedef VOID
(APIENTRY *PFN_DrvMovePointer)(
  SURFOBJ  *pso,
  LONG  x,
  LONG  y,
  RECTL  *prcl);

typedef WINBOOL
(APIENTRY *PFN_DrvNextBand)(
  SURFOBJ  *pso,
  POINTL  *pptl);

typedef VOID
(APIENTRY *PFN_DrvNotify)(
  SURFOBJ  *pso,
  ULONG  iType,
  PVOID  pvData);

typedef WINBOOL
(APIENTRY *PFN_DrvOffset)(
  SURFOBJ  *pso,
  LONG  x,
  LONG  y,
  FLONG  flReserved);

typedef WINBOOL
(APIENTRY *PFN_DrvPaint)(
  SURFOBJ  *pso,
  CLIPOBJ  *pco,
  BRUSHOBJ  *pbo,
  POINTL  *pptlBrushOrg,
  MIX  mix);

typedef WINBOOL
(APIENTRY *PFN_DrvPlgBlt)(
  SURFOBJ  *psoTrg,
  SURFOBJ  *psoSrc,
  SURFOBJ  *psoMsk,
  CLIPOBJ  *pco,
  XLATEOBJ  *pxlo,
  COLORADJUSTMENT  *pca,
  POINTL  *pptlBrushOrg,
  POINTFIX  *pptfx,
  RECTL  *prcl,
  POINTL  *pptl,
  ULONG  iMode);

typedef WINBOOL
(APIENTRY *PFN_DrvQueryAdvanceWidths)(
  DHPDEV  dhpdev,
  FONTOBJ  *pfo,
  ULONG  iMode,
  HGLYPH  *phg,
  PVOID  pvWidths,
  ULONG  cGlyphs);

typedef WINBOOL
(APIENTRY *PFN_DrvQueryDeviceSupport)(
  SURFOBJ  *pso,
  XLATEOBJ  *pxlo,
  XFORMOBJ  *pxo,
  ULONG  iType,
  ULONG  cjIn,
  PVOID  pvIn,
  ULONG  cjOut,
  PVOID  pvOut);

typedef WINBOOL
(APIENTRY *PFN_DrvQueryDriverInfo)(
  DWORD  dwMode,
  PVOID  pBuffer,
  DWORD  cbBuf,
  PDWORD  pcbNeeded);

typedef PIFIMETRICS
(APIENTRY *PFN_DrvQueryFont)(
  DHPDEV  dhpdev,
  ULONG_PTR  iFile,
  ULONG  iFace,
  ULONG_PTR  *pid);

typedef LONG
(APIENTRY *PFN_DrvQueryFontCaps)(
  ULONG  culCaps,
  ULONG  *pulCaps);

typedef LONG
(APIENTRY *PFN_DrvQueryFontData)(
  DHPDEV  dhpdev,
  FONTOBJ  *pfo,
  ULONG  iMode,
  HGLYPH  hg,
  GLYPHDATA  *pgd,
  PVOID  pv,
  ULONG  cjSize);

typedef LONG
(APIENTRY *PFN_DrvQueryFontFile)(
  ULONG_PTR  iFile,
  ULONG  ulMode,
  ULONG  cjBuf,
  ULONG  *pulBuf);

typedef PVOID
(APIENTRY *PFN_DrvQueryFontTree)(
  DHPDEV  dhpdev,
  ULONG_PTR  iFile,
  ULONG  iFace,
  ULONG  iMode,
  ULONG_PTR  *pid);

typedef PFD_GLYPHATTR
(APIENTRY *PFN_DrvQueryGlyphAttrs)(
  FONTOBJ  *pfo,
  ULONG  iMode);

typedef ULONG
(APIENTRY *PFN_DrvQueryPerBandInfo)(
  SURFOBJ  *pso,
  PERBANDINFO  *pbi);

typedef LONG
(APIENTRY *PFN_DrvQueryTrueTypeOutline)(
  DHPDEV  dhpdev,
  FONTOBJ  *pfo,
  HGLYPH  hglyph,
  WINBOOL  bMetricsOnly,
  GLYPHDATA  *pgldt,
  ULONG  cjBuf,
  TTPOLYGONHEADER  *ppoly);

typedef LONG
(APIENTRY *PFN_DrvQueryTrueTypeTable)(
  ULONG_PTR  iFile,
  ULONG  ulFont,
  ULONG  ulTag,
  PTRDIFF  dpStart,
  ULONG  cjBuf,
  BYTE  *pjBuf,
  PBYTE  *ppjTable,
  ULONG *pcjTable);

typedef WINBOOL
(APIENTRY *PFN_DrvRealizeBrush)(
  BRUSHOBJ  *pbo,
  SURFOBJ  *psoTarget,
  SURFOBJ  *psoPattern,
  SURFOBJ  *psoMask,
  XLATEOBJ  *pxlo,
  ULONG  iHatch);

typedef ULONG
(APIENTRY *PFN_DrvResetDevice)(
  DHPDEV dhpdev,
  PVOID Reserved);

typedef WINBOOL
(APIENTRY *PFN_DrvResetPDEV)(
  DHPDEV  dhpdevOld,
  DHPDEV  dhpdevNew);

typedef ULONG_PTR
(APIENTRY *PFN_DrvSaveScreenBits)(
  SURFOBJ  *pso,
  ULONG  iMode,
  ULONG_PTR  ident,
  RECTL  *prcl);

typedef WINBOOL
(APIENTRY *PFN_DrvSendPage)(
  SURFOBJ  *pso);

typedef WINBOOL
(APIENTRY *PFN_DrvSetPalette)(
  DHPDEV  dhpdev,
  PALOBJ  *ppalo,
  FLONG  fl,
  ULONG  iStart,
  ULONG  cColors);

typedef WINBOOL
(APIENTRY *PFN_DrvSetPixelFormat)(
  SURFOBJ  *pso,
  LONG  iPixelFormat,
  HWND  hwnd);

typedef ULONG
(APIENTRY *PFN_DrvSetPointerShape)(
  SURFOBJ  *pso,
  SURFOBJ  *psoMask,
  SURFOBJ  *psoColor,
  XLATEOBJ  *pxlo,
  LONG  xHot,
  LONG  yHot,
  LONG  x,
  LONG  y,
  RECTL  *prcl,
  FLONG  fl);

typedef WINBOOL
(APIENTRY *PFN_DrvStartBanding)(
  SURFOBJ  *pso,
  POINTL  *pptl);

typedef WINBOOL
(APIENTRY *PFN_DrvStartDoc)(
  SURFOBJ  *pso,
  LPWSTR  pwszDocName,
  DWORD  dwJobId);

typedef WINBOOL
(APIENTRY *PFN_DrvStartPage)(
  SURFOBJ  *pso);

typedef WINBOOL
(APIENTRY *PFN_DrvStretchBlt)(
  SURFOBJ  *psoDest,
  SURFOBJ  *psoSrc,
  SURFOBJ  *psoMask,
  CLIPOBJ  *pco,
  XLATEOBJ  *pxlo,
  COLORADJUSTMENT  *pca,
  POINTL  *pptlHTOrg,
  RECTL  *prclDest,
  RECTL  *prclSrc,
  POINTL  *pptlMask,
  ULONG  iMode);

typedef WINBOOL
(APIENTRY *PFN_DrvStretchBltROP)(
  SURFOBJ  *psoDest,
  SURFOBJ  *psoSrc,
  SURFOBJ  *psoMask,
  CLIPOBJ  *pco,
  XLATEOBJ  *pxlo,
  COLORADJUSTMENT  *pca,
  POINTL  *pptlHTOrg,
  RECTL  *prclDest,
  RECTL  *prclSrc,
  POINTL  *pptlMask,
  ULONG  iMode,
  BRUSHOBJ  *pbo,
  DWORD  rop4);

typedef WINBOOL
(APIENTRY *PFN_DrvStrokeAndFillPath)(
  SURFOBJ  *pso,
  PATHOBJ  *ppo,
  CLIPOBJ  *pco,
  XFORMOBJ  *pxo,
  BRUSHOBJ  *pboStroke,
  LINEATTRS  *plineattrs,
  BRUSHOBJ  *pboFill,
  POINTL  *pptlBrushOrg,
  MIX  mixFill,
  FLONG  flOptions);

typedef WINBOOL
(APIENTRY *PFN_DrvStrokePath)(
  SURFOBJ  *pso,
  PATHOBJ  *ppo,
  CLIPOBJ  *pco,
  XFORMOBJ  *pxo,
  BRUSHOBJ  *pbo,
  POINTL  *pptlBrushOrg,
  LINEATTRS  *plineattrs,
  MIX  mix);

typedef WINBOOL
(APIENTRY *PFN_DrvSwapBuffers)(
  SURFOBJ  *pso,
  WNDOBJ  *pwo);

typedef VOID
(APIENTRY *PFN_DrvSynchronize)(
  DHPDEV  dhpdev,
  RECTL  *prcl);

typedef VOID
(APIENTRY *PFN_DrvSynchronizeSurface)(
  SURFOBJ  *pso,
  RECTL  *prcl,
  FLONG  fl);

typedef WINBOOL
(APIENTRY *PFN_DrvTextOut)(
  SURFOBJ  *pso,
  STROBJ  *pstro,
  FONTOBJ  *pfo,
  CLIPOBJ  *pco,
  RECTL  *prclExtra,
  RECTL  *prclOpaque,
  BRUSHOBJ  *pboFore,
  BRUSHOBJ  *pboOpaque,
  POINTL  *pptlOrg,
  MIX  mix);

typedef WINBOOL
(APIENTRY *PFN_DrvTransparentBlt)(
  SURFOBJ  *psoDst,
  SURFOBJ  *psoSrc,
  CLIPOBJ  *pco,
  XLATEOBJ  *pxlo,
  RECTL  *prclDst,
  RECTL  *prclSrc,
  ULONG  iTransColor,
  ULONG  ulReserved);

typedef WINBOOL
(APIENTRY *PFN_DrvUnloadFontFile)(
  ULONG_PTR  iFile);


WIN32KAPI
VOID
APIENTRY
DrvDisableDirectDraw(
  DHPDEV  dhpdev);

typedef VOID
(APIENTRY *PFN_DrvDisableDirectDraw)(
  DHPDEV  dhpdev);

WIN32KAPI
WINBOOL
APIENTRY
DrvEnableDirectDraw(
  DHPDEV  dhpdev,
  DD_CALLBACKS  *pCallBacks,
  DD_SURFACECALLBACKS  *pSurfaceCallBacks,
  DD_PALETTECALLBACKS  *pPaletteCallBacks);

typedef WINBOOL
(APIENTRY *PFN_DrvEnableDirectDraw)(
  DHPDEV  dhpdev,
  DD_CALLBACKS  *pCallBacks,
  DD_SURFACECALLBACKS  *pSurfaceCallBacks,
  DD_PALETTECALLBACKS  *pPaletteCallBacks);

WIN32KAPI
WINBOOL
APIENTRY
DrvGetDirectDrawInfo(
  DHPDEV  dhpdev,
  DD_HALINFO  *pHalInfo,
  DWORD  *pdwNumHeaps,
  VIDEOMEMORY  *pvmList,
  DWORD  *pdwNumFourCCCodes,
  DWORD  *pdwFourCC);

typedef WINBOOL
(APIENTRY *PFN_DrvGetDirectDrawInfo)(
  DHPDEV  dhpdev,
  DD_HALINFO  *pHalInfo,
  DWORD  *pdwNumHeaps,
  VIDEOMEMORY  *pvmList,
  DWORD  *pdwNumFourCCCodes,
  DWORD  *pdwFourCC);

//DECLSPEC_DEPRECATED_DDK
WINBOOL
APIENTRY
DrvQuerySpoolType(
  DHPDEV dhpdev,
  LPWSTR pwchType);

typedef WINBOOL
(APIENTRY *PFN_DrvQuerySpoolType)(
  DHPDEV dhpdev,
  LPWSTR pwchType);


#ifdef __cplusplus
}
#endif

#endif /* defined __VIDEO_H__ */

#endif /* _WINDDI_ */

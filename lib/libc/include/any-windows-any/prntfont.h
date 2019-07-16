/*
 * prntfont.h
 *
 * Declarations for Windows NT printer driver font metrics
 *
 * This file is part of the w32api package.
 *
 * Contributors:
 *   Created by Filip Navara <xnavara@volny.cz>
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

#ifndef __PRNTFONT_H
#define __PRNTFONT_H

#define UNIFM_VERSION_1_0		0x10000
#define UNI_GLYPHSETDATA_VERSION_1_0	0x10000

#define UFM_SOFT	1
#define UFM_CART        2
#define UFM_SCALABLE    4

#define DF_TYPE_HPINTELLIFONT	0
#define DF_TYPE_TRUETYPE	1
#define DF_TYPE_PST1		2
#define DF_TYPE_CAPSL		3
#define DF_TYPE_OEM1		4
#define DF_TYPE_OEM2		5
#define DF_NOITALIC		1
#define DF_NOUNDER		2
#define DF_XM_CR		4
#define DF_NO_BOLD		8
#define DF_NO_DOUBLE_UNDERLINE	16
#define DF_NO_STRIKETHRU	32
#define DF_BKSP_OK		64

#define MTYPE_COMPOSE			1
#define MTYPE_DIRECT			2
#define MTYPE_PAIRED			4
#define MTYPE_FORMAT_MASK		7
#define MTYPE_SINGLE			8
#define MTYPE_DOUBLE			16
#define MTYPE_DOUBLEBYTECHAR_MASK	24
#define MTYPE_REPLACE			32
#define MTYPE_ADD			64
#define MTYPE_DISABLE			128
#define MTYPE_PREDEFIN_MASK		192

#define CC_NOPRECNV	0x0000FFFF
#define CC_DEFAULT	0
#define CC_CP437	-1
#define CC_CP850	-2
#define CC_CP863	-3
#define CC_BIG5		-10
#define CC_ISC		-11
#define CC_JIS		-12
#define CC_JIS_ANK	-13
#define CC_NS86		-14
#define CC_TCA		-15
#define CC_GB2312	-16
#define CC_SJIS		-17
#define CC_WANSUNG	-18

#define UFF_FILE_MAGIC		'UFF1'
#define UFF_VERSION_NUMBER	0x10001
#define FONT_DIR_SORTED		1
#define FONT_REC_SIG            'CERF'
#define WINNT_INSTALLER_SIG     'IFTN'

#define FONT_FL_UFM             0x0001
#define FONT_FL_IFI             0x0002
#define FONT_FL_SOFTFONT        0x0004
#define FONT_FL_PERMANENT_SF    0x0008
#define FONT_FL_DEVICEFONT      0x0010
#define FONT_FL_GLYPHSET_GTT    0x0020
#define FONT_FL_GLYPHSET_RLE    0x0040
#define FONT_FL_RESERVED        0x8000

#define DATA_UFM_SIG        'MFUD'
#define DATA_IFI_SIG        'IFID'
#define DATA_GTT_SIG        'TTGD'
#define DATA_CTT_SIG        'TTCD'
#define DATA_VAR_SIG        'RAVD'

#define FG_CANCHANGE	128
#define WM_FI_FILENAME	900

#define GET_UNIDRVINFO(pUFM) ((PUNIDRVINFO)((ULONG_PTR)(pUFM) + (pUFM)->loUnidrvInfo))
#define GET_IFIMETRICS(pUFM) ((IFIMETRICS*)((ULONG_PTR)(pUFM) + (pUFM)->loIFIMetrics))
#define GET_EXTTEXTMETRIC(pUFM) ((EXTTEXTMETRIC*)((ULONG_PTR)(pUFM) + (pUFM)->loExtTextMetric))
#define GET_WIDTHTABLE(pUFM) ((PWIDTHTABLE)((ULONG_PTR)(pUFM) + (pUFM)->loWidthTable))
#define GET_KERNDATA(pUFM) ((PKERNDATA)((ULONG_PTR)(pUFM) + (pUFM)->loKernPair))
#define GET_SELECT_CMD(pUni) ((PCHAR)(pUni) + (pUni)->SelectFont.loOffset)
#define GET_UNSELECT_CMD(pUni) ((PCHAR)(pUni) + (pUni)->UnSelectFont.loOffset)
#define GET_GLYPHRUN(pGTT) ((PGLYPHRUN)((ULONG_PTR)(pGTT) + ((PUNI_GLYPHSETDATA)pGTT)->loRunOffset))
#define GET_CODEPAGEINFO(pGTT) ((PUNI_CODEPAGEINFO)((ULONG_PTR)(pGTT) + ((PUNI_GLYPHSETDATA)pGTT)->loCodePageOffset))
#define GET_MAPTABLE(pGTT) ((PMAPTABLE)((ULONG_PTR)(pGTT) + ((PUNI_GLYPHSETDATA)pGTT)->loMapTableOffset))

typedef struct _UNIFM_HDR
{
  DWORD  dwSize;
  DWORD  dwVersion;
  ULONG  ulDefaultCodepage;
  LONG  lGlyphSetDataRCID;
  DWORD  loUnidrvInfo;
  DWORD  loIFIMetrics;
  DWORD  loExtTextMetric;
  DWORD  loWidthTable;
  DWORD  loKernPair;
  DWORD  dwReserved[2];
} UNIFM_HDR, *PUNIFM_HDR;

typedef struct _INVOC
{
  DWORD  dwCount;
  DWORD  loOffset;
} INVOC, *PINVOC;

typedef struct _UNIDRVINFO
{
  DWORD  dwSize;
  DWORD  flGenFlags;
  WORD  wType;
  WORD  fCaps;
  WORD  wXRes;
  WORD  wYRes;
  SHORT  sYAdjust;
  SHORT  sYMoved;
  WORD  wPrivateData;
  SHORT  sShift;
  INVOC  SelectFont;
  INVOC  UnSelectFont;
  WORD  wReserved[4];
} UNIDRVINFO, *PUNIDRVINFO;

typedef struct _EXTTEXTMETRIC
{
  SHORT  emSize;
  SHORT  emPointSize;
  SHORT  emOrientation;
  SHORT  emMasterHeight;
  SHORT  emMinScale;
  SHORT  emMaxScale;
  SHORT  emMasterUnits;
  SHORT  emCapHeight;
  SHORT  emXHeight;
  SHORT  emLowerCaseAscent;
  SHORT  emLowerCaseDescent;
  SHORT  emSlant;
  SHORT  emSuperScript;
  SHORT  emSubScript;
  SHORT  emSuperScriptSize;
  SHORT  emSubScriptSize;
  SHORT  emUnderlineOffset;
  SHORT  emUnderlineWidth;
  SHORT  emDoubleUpperUnderlineOffset;
  SHORT  emDoubleLowerUnderlineOffset;
  SHORT  emDoubleUpperUnderlineWidth;
  SHORT  emDoubleLowerUnderlineWidth;
  SHORT  emStrikeOutOffset;
  SHORT  emStrikeOutWidth;
  WORD  emKernPairs;
  WORD  emKernTracks;
} EXTTEXTMETRIC, *PEXTTEXTMETRIC;

typedef struct _WIDTHRUN
{
  WORD  wStartGlyph;
  WORD  wGlyphCount;
  DWORD  loCharWidthOffset;
} WIDTHRUN, *PWIDTHRUN;

typedef struct _WIDTHTABLE
{
  DWORD  dwSize;
  DWORD  dwRunNum;
  WIDTHRUN  WidthRun[1];
} WIDTHTABLE, *PWIDTHTABLE;

typedef struct _KERNDATA
{
  DWORD  dwSize;
  DWORD  dwKernPairNum;
  FD_KERNINGPAIR  KernPair[1];
} KERNDATA, *PKERNDATA;

typedef struct _UNI_GLYPHSETDATA
{
  DWORD  dwSize;
  DWORD  dwVersion;
  DWORD  dwFlags;
  LONG  lPredefinedID;
  DWORD  dwGlyphCount;
  DWORD  dwRunCount;
  DWORD  loRunOffset;
  DWORD  dwCodePageCount;
  DWORD  loCodePageOffset;
  DWORD  loMapTableOffset;
  DWORD  dwReserved[2];
} UNI_GLYPHSETDATA, *PUNI_GLYPHSETDATA;

typedef struct _UNI_CODEPAGEINFO
{
  DWORD  dwCodePage;
  INVOC  SelectSymbolSet;
  INVOC  UnSelectSymbolSet;
} UNI_CODEPAGEINFO, *PUNI_CODEPAGEINFO;

typedef struct _GLYPHRUN
{
  WCHAR  wcLow;
  WORD  wGlyphCount;
} GLYPHRUN, *PGLYPHRUN;

typedef struct _TRANSDATA
{
  BYTE  ubCodePageID;
  BYTE  ubType;
  union
  {
    SHORT  sCode;
    BYTE  ubCode;
    BYTE  ubPairs[2];
  } uCode;
} TRANSDATA, *PTRANSDATA;

typedef struct _MAPTABLE {
  DWORD  dwSize;
  DWORD  dwGlyphNum;
  TRANSDATA  Trans[1];
} MAPTABLE, *PMAPTABLE;

typedef struct _UFF_FILEHEADER {
  DWORD  dwSignature;
  DWORD  dwVersion;
  DWORD  dwSize;
  DWORD  nFonts;
  DWORD  nGlyphSets;
  DWORD  nVarData;
  DWORD  offFontDir;
  DWORD  dwFlags;
  DWORD  dwReserved[4];
} UFF_FILEHEADER, *PUFF_FILEHEADER;

typedef struct _UFF_FONTDIRECTORY {
  DWORD  dwSignature;
  WORD  wSize;
  WORD  wFontID;
  SHORT  sGlyphID;
  WORD  wFlags;
  DWORD  dwInstallerSig;
  DWORD  offFontName;
  DWORD  offCartridgeName;
  DWORD  offFontData;
  DWORD  offGlyphData;
  DWORD  offVarData;
} UFF_FONTDIRECTORY, *PUFF_FONTDIRECTORY;

typedef struct _DATA_HEADER {
  DWORD  dwSignature;
  WORD  wSize;
  WORD  wDataID;
  DWORD  dwDataSize;
  DWORD  dwReserved;
} DATA_HEADER, *PDATA_HEADER;

typedef struct _OEMFONTINSTPARAM {
  DWORD  cbSize;
  HANDLE  hPrinter;
  HANDLE  hModule;
  HANDLE  hHeap;
  DWORD  dwFlags;
  PWSTR  pFontInstallerName;
} OEMFONTINSTPARAM, *POEMFONTINSTPARAM;

#endif /* __PRNTFONT_H */

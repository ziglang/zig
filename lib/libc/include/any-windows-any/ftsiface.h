/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef __FTSIFACE_H__
#define __FTSIFACE_H__

#ifdef __cplusplus
extern "C" {
#endif

  typedef HANDLE HINDEX;
  typedef HANDLE HSEARCHER;
  typedef HANDLE HCOMPRESSOR;
  typedef HANDLE HHILITER;
  typedef INT ERRORCODE;
  typedef struct { int base; int limit; } HILITE;

#define NO_TITLE UINT(-1)
#define NOT_INDEXER UINT(-2)
#define NOT_SEARCHER UINT(-3)
#define NOT_COMPRESSOR UINT(-4)
#define CANNOT_SAVE UINT(-5)
#define OUT_OF_MEMORY UINT(-6)
#define CANNOT_OPEN UINT(-7)
#define CANNOT_LOAD UINT(-8)
#define INVALID_INDEX UINT(-9)
#define ALREADY_WEIGHED UINT(-10)
#define NO_TEXT_SCANNED UINT(-11)
#define ALIGNMENT_ERROR UINT(-12)
#define INVALID_PHRASE_TABLE UINT(-13)
#define INVALID_LCID UINT(-14)
#define NO_INDICES_LOADED UINT(-15)
#define INDEX_LOADED_ALREADY UINT(-16)
#define GROUP_LOADED_ALREADY UINT(-17)
#define DIALOG_ALREADY_ACTIVE UINT(-18)
#define EMPTY_PHRASE_TABLE UINT(-19)
#define OUT_OF_DISK UINT(-20)
#define DISK_READ_ERROR UINT(-21)
#define DISK_WRITE_ERROR UINT(-22)
#define SEARCH_ABORTED UINT(-23)
#define UNKNOWN_EXCEPTION UINT(-24)
#define SYSTEM_ERROR UINT(-25)
#define NOT_HILITER UINT(-26)
#define INVALID_CHARSET UINT(-27)
#define INVALID_SOURCE_NAME UINT(-28)
#define INVALID_TIMESTAMP UINT(-29)

#define ERR_NO_DISK_SPACE 0xE0000001
#define ERR_DISK_CREATE_ERROR 0xE0000002
#define ERR_DISK_OPEN_ERROR 0xE0000003
#define ERR_DISK_READ_ERROR 0xE0000004
#define ERR_DISK_WRITE_ERROR 0xE0000005
#define ERR_SYSTEM_ERROR 0xE0000006
#define ERR_ABORT_SEARCH 0xE0000007
#define ERR_INVALID_TIMESTAMP 0xE0000008
#define ERR_INVALID_SOURCE_NAME 0xE0000009
#define ERR_FILE_MAP_FAILED 0xE000000A
#define ERR_INVALID_FILE_TYPE 0xE000000B
#define ERR_DAMAGED_FILE 0xE000000C
#define ERR_FUTURE_VERSION 0xE000000D

#define TOPIC_SEARCH 0x00000001
#define PHRASE_SEARCH 0x00000002
#define PHRASE_FEEDBACK 0x00000004
#define VECTOR_SEARCH 0x00000008
#define WINHELP_INDEX 0x00000010
#define USE_VA_ADDR 0x00000020
#define USE_QWORD_JUMP 0x00000040

#define USE_DEFAULT UINT(-1)

  HINDEX WINAPI NewIndex(const PBYTE pbSourceName,UINT uiTime1,UINT uiTime2,UINT iCharsetDefault,UINT lcidDefault,UINT fdwOptions);
  ERRORCODE WINAPI ScanTopicTitle(HINDEX hinx,PBYTE pbTitle,UINT cbTitle,UINT iTopic,HANDLE hTopic,UINT iCharset,UINT lcid);
  ERRORCODE WINAPI ScanTopicText (HINDEX hinx,PBYTE pbText,UINT cbText,UINT iCharset,UINT lcid);
  ERRORCODE WINAPI SaveIndex (HINDEX hinx,PSZ pszFileName);
  ERRORCODE WINAPI DeleteIndex (HINDEX hinx);

  typedef void (WINAPI *ANIMATOR)(void);

  ERRORCODE WINAPI RegisterAnimator(ANIMATOR pAnimator,HWND hwndAnimator);
  WINBOOL WINAPI IsValidIndex(PSZ pszFileName,UINT dwOptions);
  void WINAPI SetDirectoryLocator(HWND hwndLocator);
  HSEARCHER WINAPI NewSearcher();
  INT WINAPI OpenIndex(HSEARCHER hsrch,PSZ pszIndexFileName,PBYTE pbSourceName,PUINT pcbSourceNameLimit,PUINT pTime1,PUINT pTime2);
  ERRORCODE WINAPI DiscardIndex (HSEARCHER hsrch,INT iIndex);
  ERRORCODE WINAPI QueryOptions (HSEARCHER hsrch,INT iIndex,PUINT pfdwOptions);
  ERRORCODE WINAPI SaveGroup (HSEARCHER hsrch,PSZ pszFileName);
  ERRORCODE WINAPI LoadGroup (HSEARCHER hsrch,PSZ pszFileName);
  HWND WINAPI OpenDialog (HSEARCHER hsrch,HWND hwndParent);
  ERRORCODE WINAPI DeleteSearcher(HSEARCHER hsrch);

#define MSG_FTS_JUMP_HASH (WM_USER + 32)
#define MSG_FTS_JUMP_VA (WM_USER + 33)
#define MSG_FTS_GET_TITLE (WM_USER + 34)
#define MSG_FTS_JUMP_QWORD (WM_USER + 35)
#define MSG_REINDEX_REQUEST (WM_USER + 36)
#define MSG_FTS_WHERE_IS_IT (WM_USER + 37)
#define MSG_GET_DEFFONT (WM_USER + 45)

  typedef struct _QWordAddress {
    UINT iSerial;
    HANDLE hTopic;
  } QWordAddress,*PQWordAddress;

  HCOMPRESSOR WINAPI NewCompressor(UINT iCharsetDefault);
  ERRORCODE WINAPI ScanText(HCOMPRESSOR hcmp,PBYTE pbText,UINT cbText,UINT iCharset);
  ERRORCODE WINAPI GetPhraseTable(HCOMPRESSOR hcmp,PUINT pcPhrases,PBYTE *ppbImages,PUINT pcbImages,PBYTE *ppacbImageCompressed,PUINT pcbCompressed);
  ERRORCODE WINAPI SetPhraseTable(HCOMPRESSOR hcmp,PBYTE pbImages,UINT cbImages,PBYTE pacbImageCompressed,UINT cbCompressed);
  INT WINAPI CompressText (HCOMPRESSOR hcmp,PBYTE pbText,UINT cbText,PBYTE *ppbCompressed,UINT iCharset);
  INT WINAPI DecompressText(HCOMPRESSOR hcmp,PBYTE pbCompressed,UINT cbCompressed,PBYTE pbText);
  ERRORCODE WINAPI DeleteCompressor(HCOMPRESSOR hcmp);
  HHILITER WINAPI NewHiliter(HSEARCHER hSearch);
  ERRORCODE WINAPI DeleteHiliter(HHILITER hhil);
  ERRORCODE WINAPI ScanDisplayText(HHILITER hhil,PBYTE pbText,int cbText,UINT iCharset,LCID lcid);
  ERRORCODE WINAPI ClearDisplayText(HHILITER hhil);
  int WINAPI CountHilites(HHILITER hhil,int base,int limit);
  int WINAPI QueryHilites(HHILITER hhil,int base,int limit,int cHilites,HILITE *paHilites);

#ifdef __cplusplus
}
#endif
#endif

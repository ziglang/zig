/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef INCLUDED_TYPES_FCI_FDI
#define INCLUDED_TYPES_FCI_FDI 1

#ifdef __cplusplus
extern "C" {
#endif

#ifndef HUGE
#define HUGE
#endif

#ifndef FAR
#define FAR
#endif

#ifndef DIAMONDAPI
#define DIAMONDAPI __cdecl
#endif

#ifndef _WIN64
#include <pshpack4.h>
#endif

#ifndef BASETYPES
#define BASETYPES
  typedef unsigned __LONG32 ULONG;
  typedef ULONG *PULONG;
  typedef unsigned short USHORT;
  typedef USHORT *PUSHORT;
  typedef unsigned char UCHAR;
  typedef UCHAR *PUCHAR;
  typedef char *PSZ;
#endif

#if !defined(_INC_WINDOWS) && !defined(_WINDOWS_)
  typedef int WINBOOL;
  typedef unsigned char BYTE;
  typedef unsigned int UINT;
#endif

  typedef unsigned __LONG32 CHECKSUM;
  typedef unsigned __LONG32 UOFF;
  typedef unsigned __LONG32 COFF;

#ifndef TRUE
#define TRUE 1
#endif

#ifndef FALSE
#define FALSE 0
#endif

#ifndef NULL
#define NULL 0
#endif

  typedef struct {
    int erfOper;
    int erfType;
    WINBOOL fError;
  } ERF;
  typedef ERF *PERF;

#define STATIC static

#define CB_MAX_CHUNK 32768U
#define CB_MAX_DISK __MSABI_LONG(0x7fffffff)
#define CB_MAX_FILENAME 256
#define CB_MAX_CABINET_NAME 256
#define CB_MAX_CAB_PATH 256
#define CB_MAX_DISK_NAME 256

  typedef unsigned short TCOMP;

#define tcompMASK_TYPE 0x000F
#define tcompTYPE_NONE 0x0000
#define tcompTYPE_MSZIP 0x0001
#define tcompTYPE_QUANTUM 0x0002
#define tcompTYPE_LZX 0x0003
#define tcompBAD 0x000F

#define tcompMASK_LZX_WINDOW 0x1F00
#define tcompLZX_WINDOW_LO 0x0F00
#define tcompLZX_WINDOW_HI 0x1500
#define tcompSHIFT_LZX_WINDOW 8

#define tcompMASK_QUANTUM_LEVEL 0x00F0
#define tcompQUANTUM_LEVEL_LO 0x0010
#define tcompQUANTUM_LEVEL_HI 0x0070
#define tcompSHIFT_QUANTUM_LEVEL 4

#define tcompMASK_QUANTUM_MEM 0x1F00
#define tcompQUANTUM_MEM_LO 0x0A00
#define tcompQUANTUM_MEM_HI 0x1500
#define tcompSHIFT_QUANTUM_MEM 8

#define tcompMASK_RESERVED 0xE000

#define CompressionTypeFromTCOMP(tc) ((tc) & tcompMASK_TYPE)
#define CompressionLevelFromTCOMP(tc) (((tc) & tcompMASK_QUANTUM_LEVEL) >> tcompSHIFT_QUANTUM_LEVEL)
#define CompressionMemoryFromTCOMP(tc) (((tc) & tcompMASK_QUANTUM_MEM) >> tcompSHIFT_QUANTUM_MEM)
#define TCOMPfromTypeLevelMemory(t,l,m) (((m) << tcompSHIFT_QUANTUM_MEM) | ((l) << tcompSHIFT_QUANTUM_LEVEL) | (t))
#define LZXCompressionWindowFromTCOMP(tc) (((tc) & tcompMASK_LZX_WINDOW) >> tcompSHIFT_LZX_WINDOW)
#define TCOMPfromLZXWindow(w) (((w) << tcompSHIFT_LZX_WINDOW) | (tcompTYPE_LZX))

#ifndef _WIN64
#include <poppack.h>
#endif

#ifdef __cplusplus
}
#endif
#endif

#ifndef INCLUDED_FCI
#define INCLUDED_FCI 1

#include <basetsd.h>

#ifdef __cplusplus
extern "C" {
#endif

#ifndef _WIN64
#pragma pack(4)
#endif

  typedef enum {
    FCIERR_NONE,FCIERR_OPEN_SRC,FCIERR_READ_SRC,FCIERR_ALLOC_FAIL,FCIERR_TEMP_FILE,FCIERR_BAD_COMPR_TYPE,FCIERR_CAB_FILE,FCIERR_USER_ABORT,
    FCIERR_MCI_FAIL
  } FCIERROR;

#ifndef _A_NAME_IS_UTF
#define _A_NAME_IS_UTF 0x80
#endif

#ifndef _A_EXEC
#define _A_EXEC 0x40
#endif

  typedef void *HFCI;

  typedef struct {
    ULONG cb;
    ULONG cbFolderThresh;
    UINT cbReserveCFHeader;
    UINT cbReserveCFFolder;
    UINT cbReserveCFData;
    int iCab;
    int iDisk;
#ifndef REMOVE_CHICAGO_M6_HACK
    int fFailOnIncompressible;
#endif
    USHORT setID;
    char szDisk[CB_MAX_DISK_NAME];
    char szCab[CB_MAX_CABINET_NAME];
    char szCabPath[CB_MAX_CAB_PATH];
  } CCAB;

  typedef CCAB *PCCAB;

  typedef void *(DIAMONDAPI *PFNFCIALLOC)(ULONG cb);
#define FNFCIALLOC(fn) void *DIAMONDAPI fn(ULONG cb)

  typedef void (DIAMONDAPI *PFNFCIFREE)(void *memory);
#define FNFCIFREE(fn) void DIAMONDAPI fn(void *memory)

  typedef INT_PTR (DIAMONDAPI *PFNFCIOPEN) (char *pszFile,int oflag,int pmode,int *err,void *pv);
  typedef UINT (DIAMONDAPI *PFNFCIREAD) (INT_PTR hf,void *memory,UINT cb,int *err,void *pv);
  typedef UINT (DIAMONDAPI *PFNFCIWRITE)(INT_PTR hf,void *memory,UINT cb,int *err,void *pv);
  typedef int (DIAMONDAPI *PFNFCICLOSE)(INT_PTR hf,int *err,void *pv);
  typedef __LONG32 (DIAMONDAPI *PFNFCISEEK) (INT_PTR hf,__LONG32 dist,int seektype,int *err,void *pv);
  typedef int (DIAMONDAPI *PFNFCIDELETE) (char *pszFile,int *err,void *pv);

#define FNFCIOPEN(fn) INT_PTR DIAMONDAPI fn(char *pszFile,int oflag,int pmode,int *err,void *pv)
#define FNFCIREAD(fn) UINT DIAMONDAPI fn(INT_PTR hf,void *memory,UINT cb,int *err,void *pv)
#define FNFCIWRITE(fn) UINT DIAMONDAPI fn(INT_PTR hf,void *memory,UINT cb,int *err,void *pv)
#define FNFCICLOSE(fn) int DIAMONDAPI fn(INT_PTR hf,int *err,void *pv)
#define FNFCISEEK(fn) __LONG32 DIAMONDAPI fn(INT_PTR hf,__LONG32 dist,int seektype,int *err,void *pv)
#define FNFCIDELETE(fn) int DIAMONDAPI fn(char *pszFile,int *err,void *pv)

  typedef WINBOOL (DIAMONDAPI *PFNFCIGETNEXTCABINET)(PCCAB pccab,ULONG cbPrevCab,void *pv);
#define FNFCIGETNEXTCABINET(fn) WINBOOL DIAMONDAPI fn(PCCAB pccab,ULONG cbPrevCab,void *pv)
  typedef int (DIAMONDAPI *PFNFCIFILEPLACED)(PCCAB pccab,char *pszFile,__LONG32 cbFile,WINBOOL fContinuation,void *pv);
#define FNFCIFILEPLACED(fn) int DIAMONDAPI fn(PCCAB pccab,char *pszFile,__LONG32 cbFile,WINBOOL fContinuation,void *pv)
  typedef INT_PTR (DIAMONDAPI *PFNFCIGETOPENINFO)(char *pszName,USHORT *pdate,USHORT *ptime,USHORT *pattribs,int *err,void *pv);
#define FNFCIGETOPENINFO(fn) INT_PTR DIAMONDAPI fn(char *pszName,USHORT *pdate,USHORT *ptime,USHORT *pattribs,int *err,void *pv)

#define statusFile 0
#define statusFolder 1
#define statusCabinet 2

  typedef __LONG32 (DIAMONDAPI *PFNFCISTATUS)(UINT typeStatus,ULONG cb1,ULONG cb2,void *pv);
#define FNFCISTATUS(fn) __LONG32 DIAMONDAPI fn(UINT typeStatus,ULONG cb1,ULONG cb2,void *pv)
  typedef WINBOOL (DIAMONDAPI *PFNFCIGETTEMPFILE)(char *pszTempName,int cbTempName,void *pv);
#define FNFCIGETTEMPFILE(fn) WINBOOL DIAMONDAPI fn(char *pszTempName,int cbTempName,void *pv)

  HFCI DIAMONDAPI FCICreate(PERF perf,PFNFCIFILEPLACED pfnfcifp,PFNFCIALLOC pfna,PFNFCIFREE pfnf,PFNFCIOPEN pfnopen,PFNFCIREAD pfnread,PFNFCIWRITE pfnwrite,PFNFCICLOSE pfnclose,PFNFCISEEK pfnseek,PFNFCIDELETE pfndelete,PFNFCIGETTEMPFILE pfnfcigtf,PCCAB pccab,void *pv);
  WINBOOL DIAMONDAPI FCIAddFile(HFCI hfci,char *pszSourceFile,char *pszFileName,WINBOOL fExecute,PFNFCIGETNEXTCABINET pfnfcignc,PFNFCISTATUS pfnfcis,PFNFCIGETOPENINFO pfnfcigoi,TCOMP typeCompress);
  WINBOOL DIAMONDAPI FCIFlushCabinet(HFCI hfci,WINBOOL fGetNextCab,PFNFCIGETNEXTCABINET pfnfcignc,PFNFCISTATUS pfnfcis);
  WINBOOL DIAMONDAPI FCIFlushFolder(HFCI hfci,PFNFCIGETNEXTCABINET pfnfcignc,PFNFCISTATUS pfnfcis);
  WINBOOL DIAMONDAPI FCIDestroy (HFCI hfci);

#ifndef _WIN64
#pragma pack()
#endif

#ifdef __cplusplus
}
#endif
#endif

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

#include <basetsd.h>

#ifndef INCLUDED_FDI
#define INCLUDED_FDI 1

#ifdef __cplusplus
extern "C" {
#endif

#ifndef _WIN64
#pragma pack(4)
#endif

  typedef enum {
    FDIERROR_NONE,FDIERROR_CABINET_NOT_FOUND,FDIERROR_NOT_A_CABINET,FDIERROR_UNKNOWN_CABINET_VERSION,FDIERROR_CORRUPT_CABINET,FDIERROR_ALLOC_FAIL,
    FDIERROR_BAD_COMPR_TYPE,FDIERROR_MDI_FAIL,FDIERROR_TARGET_FILE,FDIERROR_RESERVE_MISMATCH,FDIERROR_WRONG_CABINET,FDIERROR_USER_ABORT
  } FDIERROR;

#ifndef _A_NAME_IS_UTF
#define _A_NAME_IS_UTF 0x80
#endif

#ifndef _A_EXEC
#define _A_EXEC 0x40
#endif

  typedef void *HFDI;

  typedef struct {
    __LONG32 cbCabinet;
    USHORT cFolders;
    USHORT cFiles;
    USHORT setID;
    USHORT iCabinet;
    WINBOOL fReserve;
    WINBOOL hasprev;
    WINBOOL hasnext;
  } FDICABINETINFO;

  typedef FDICABINETINFO *PFDICABINETINFO;

  typedef enum {
    fdidtNEW_CABINET,fdidtNEW_FOLDER,fdidtDECRYPT
  } FDIDECRYPTTYPE;

  typedef struct {
    FDIDECRYPTTYPE fdidt;
    void *pvUser;
    __C89_NAMELESS union {
      struct {
	void *pHeaderReserve;
	USHORT cbHeaderReserve;
	USHORT setID;
	int iCabinet;
      } cabinet;
      struct {
	void *pFolderReserve;
	USHORT cbFolderReserve;
	USHORT iFolder;
      } folder;

      struct {
	void *pDataReserve;
	USHORT cbDataReserve;
	void *pbData;
	USHORT cbData;
	WINBOOL fSplit;
	USHORT cbPartial;

      } decrypt;
    };
  } FDIDECRYPT;

  typedef FDIDECRYPT *PFDIDECRYPT;

  typedef void *(DIAMONDAPI *PFNALLOC)(ULONG cb);
#define FNALLOC(fn) void *DIAMONDAPI fn(ULONG cb)

  typedef void (DIAMONDAPI *PFNFREE)(void *pv);
#define FNFREE(fn) void DIAMONDAPI fn(void *pv)

  typedef INT_PTR (DIAMONDAPI *PFNOPEN) (char *pszFile,int oflag,int pmode);
  typedef UINT (DIAMONDAPI *PFNREAD) (INT_PTR hf,void *pv,UINT cb);
  typedef UINT (DIAMONDAPI *PFNWRITE)(INT_PTR hf,void *pv,UINT cb);
  typedef int (DIAMONDAPI *PFNCLOSE)(INT_PTR hf);
  typedef __LONG32 (DIAMONDAPI *PFNSEEK) (INT_PTR hf,__LONG32 dist,int seektype);

#define FNOPEN(fn) INT_PTR DIAMONDAPI fn(char *pszFile,int oflag,int pmode)
#define FNREAD(fn) UINT DIAMONDAPI fn(INT_PTR hf,void *pv,UINT cb)
#define FNWRITE(fn) UINT DIAMONDAPI fn(INT_PTR hf,void *pv,UINT cb)
#define FNCLOSE(fn) int DIAMONDAPI fn(INT_PTR hf)
#define FNSEEK(fn) __LONG32 DIAMONDAPI fn(INT_PTR hf,__LONG32 dist,int seektype)

  typedef int (DIAMONDAPI *PFNFDIDECRYPT)(PFDIDECRYPT pfdid);
#define FNFDIDECRYPT(fn) int DIAMONDAPI fn(PFDIDECRYPT pfdid)

  typedef struct {
    __LONG32 cb;
    char *psz1;
    char *psz2;
    char *psz3;
    void *pv;
    INT_PTR hf;
    USHORT date;
    USHORT time;
    USHORT attribs;
    USHORT setID;
    USHORT iCabinet;
    USHORT iFolder;
    FDIERROR fdie;
  } FDINOTIFICATION,*PFDINOTIFICATION;

  typedef enum {
    fdintCABINET_INFO,fdintPARTIAL_FILE,fdintCOPY_FILE,fdintCLOSE_FILE_INFO,fdintNEXT_CABINET,fdintENUMERATE
  } FDINOTIFICATIONTYPE;

  typedef INT_PTR (DIAMONDAPI *PFNFDINOTIFY)(FDINOTIFICATIONTYPE fdint,PFDINOTIFICATION pfdin);

#define FNFDINOTIFY(fn) INT_PTR DIAMONDAPI fn(FDINOTIFICATIONTYPE fdint,PFDINOTIFICATION pfdin)

#ifndef _WIN64
#pragma pack (1)
#endif

  typedef struct {
    char ach[2];
    __LONG32 cbFile;
  } FDISPILLFILE;

  typedef FDISPILLFILE *PFDISPILLFILE;

#ifndef _WIN64
#pragma pack ()
#endif

#define cpuUNKNOWN (-1)
#define cpu80286 (0)
#define cpu80386 (1)

  HFDI DIAMONDAPI FDICreate(PFNALLOC pfnalloc,PFNFREE pfnfree,PFNOPEN pfnopen,PFNREAD pfnread,PFNWRITE pfnwrite,PFNCLOSE pfnclose,PFNSEEK pfnseek,int cpuType,PERF perf);
  WINBOOL DIAMONDAPI FDIIsCabinet(HFDI hfdi,INT_PTR hf,PFDICABINETINFO pfdici);
  WINBOOL DIAMONDAPI FDICopy(HFDI hfdi,char *pszCabinet,char *pszCabPath,int flags,PFNFDINOTIFY pfnfdin,PFNFDIDECRYPT pfnfdid,void *pvUser);
  WINBOOL DIAMONDAPI FDIDestroy(HFDI hfdi);
  WINBOOL DIAMONDAPI FDITruncateCabinet(HFDI hfdi,char *pszCabinetName,USHORT iFolderToDelete);

#ifndef _WIN64
#pragma pack()
#endif

#ifdef __cplusplus
}
#endif
#endif

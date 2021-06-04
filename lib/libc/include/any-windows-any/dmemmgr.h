/**
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER within this package.
 */

#ifndef __DMEMMGR_INCLUDED__
#define __DMEMMGR_INCLUDED__

#include <winapifamily.h>

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_DESKTOP)

#define VMEMHEAP_LINEAR __MSABI_LONG(0x1)
#define VMEMHEAP_RECTANGULAR __MSABI_LONG(0x2)
#define VMEMHEAP_ALIGNMENT __MSABI_LONG(0x4)

#define SURFACEALIGN_DISCARDABLE __MSABI_LONG(0x1)

#ifdef __cplusplus
extern "C" {
#endif

  typedef ULONG_PTR FLATPTR;

  typedef struct _SURFACEALIGNMENT {
    __C89_NAMELESS union {
      struct {
	DWORD dwStartAlignment;
	DWORD dwPitchAlignment;
	DWORD dwFlags;
	DWORD dwReserved2;
      } Linear;
      struct {
	DWORD dwXAlignment;
	DWORD dwYAlignment;
	DWORD dwFlags;
	DWORD dwReserved2;
      } Rectangular;
    };
  } SURFACEALIGNMENT;

  typedef struct _HEAPALIGNMENT {
    DWORD dwSize;
    DDSCAPS ddsCaps;
    DWORD dwReserved;
    SURFACEALIGNMENT ExecuteBuffer;
    SURFACEALIGNMENT Overlay;
    SURFACEALIGNMENT Texture;
    SURFACEALIGNMENT ZBuffer;
    SURFACEALIGNMENT AlphaBuffer;
    SURFACEALIGNMENT Offscreen;
    SURFACEALIGNMENT FlipTarget;
  } HEAPALIGNMENT;

  typedef struct _DD_GETHEAPALIGNMENTDATA {
    ULONG_PTR dwInstance;
    DWORD dwHeap;
    HRESULT ddRVal;
    VOID *GetHeapAlignment;
    HEAPALIGNMENT Alignment;
  } DD_GETHEAPALIGNMENTDATA;

  typedef struct _VMEML {
    struct _VMEML *next;
    FLATPTR ptr;
    DWORD size;
    WINBOOL bDiscardable;
  } VMEML,*LPVMEML,**LPLPVMEML;

  typedef struct _VMEMR {
    struct _VMEMR *next;
    struct _VMEMR *prev;
    struct _VMEMR *pUp;
    struct _VMEMR *pDown;
    struct _VMEMR *pLeft;
    struct _VMEMR *pRight;
    FLATPTR ptr;
    DWORD size;
    DWORD x;
    DWORD y;
    DWORD cx;
    DWORD cy;
    DWORD flags;
    FLATPTR pBits;
    WINBOOL bDiscardable;
  } VMEMR,*LPVMEMR,**LPLPVMEMR;

  typedef struct _VMEMHEAP {
    DWORD dwFlags;
    DWORD stride;
    LPVOID freeList;
    LPVOID allocList;
    DWORD dwTotalSize;
    FLATPTR fpGARTLin;
    FLATPTR fpGARTDev;
    DWORD dwCommitedSize;
    DWORD dwCoalesceCount;
    HEAPALIGNMENT Alignment;
    DDSCAPSEX ddsCapsEx;
    DDSCAPSEX ddsCapsExAlt;
#ifndef IS_16
    LARGE_INTEGER liPhysAGPBase;
#endif
    HANDLE hdevAGP;
    LPVOID pvPhysRsrv;
#if NTDDI_VERSION >= 0x05010000
    BYTE *pAgpCommitMask;
    DWORD dwAgpCommitMaskSize;
#endif
  } VMEMHEAP;

#ifndef __NTDDKCOMP__
  typedef struct _VIDMEM *LPVIDMEM;
#else
  typedef struct _VIDEOMEMORY *LPVIDMEM;
#endif

  typedef struct _SURFACEALIGNMENT *LPSURFACEALIGNMENT;
  typedef struct _HEAPALIGNMENT *LPHEAPALIGNMENT;
  typedef struct _DD_GETHEAPALIGNMENTDATA *PDD_GETHEAPALIGNMENTDATA;
  typedef VMEMHEAP *LPVMEMHEAP;

#ifndef __NTDDKCOMP__
  extern FLATPTR WINAPI VidMemAlloc (LPVMEMHEAP pvmh, DWORD width, DWORD height);
#endif
  extern FLATPTR WINAPI HeapVidMemAllocAligned (LPVIDMEM lpVidMem, DWORD dwWidth, DWORD dwHeight, LPSURFACEALIGNMENT lpAlignment, LPLONG lpNewPitch);
  extern void WINAPI VidMemFree (LPVMEMHEAP pvmh, FLATPTR ptr);

#ifdef __cplusplus
};
#endif

#endif
#endif

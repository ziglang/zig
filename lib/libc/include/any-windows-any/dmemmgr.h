
/* $Id: $
 *
 * COPYRIGHT:            This file is in the public domain.
 * PROJECT:              ReactOS kernel
 * FILE:
 * PURPOSE:              Directx headers
 * PROGRAMMER:           Magnus Olsen (greatlrd)
 *
 */

#ifndef __DMEMMGR_INCLUDED__
#define __DMEMMGR_INCLUDED__

#ifdef __cplusplus
extern "C" {
#endif

#ifndef __NTDDKCOMP__

#ifndef FLATPTR_DEFINED
typedef ULONG_PTR FLATPTR;
#define FLATPTR_DEFINED
#endif

typedef struct _VIDMEM *LPVIDMEM;

#else /* __NTDDKCOMP__ */

#ifndef FLATPTR_DEFINED
typedef ULONG_PTR FLATPTR;
#define FLATPTR_DEFINED
#endif

typedef struct _VIDEOMEMORY *LPVIDMEM;
#endif /* __NTDDKCOMP__ */

#define SURFACEALIGN_DISCARDABLE 0x00000001
#define VMEMHEAP_LINEAR 0x00000001
#define VMEMHEAP_RECTANGULAR 0x00000002
#define VMEMHEAP_ALIGNMENT 0x00000004

typedef struct _VMEML
{
  struct _VMEML *next;
  FLATPTR ptr;
  DWORD size;
  WINBOOL bDiscardable;
} VMEML, *LPVMEML, *LPLPVMEML;

typedef struct _VMEMR
{
  struct _VMEMR *next;
  struct _VMEMR *prev;

  struct _VMEMR *pUp;
  struct _VMEMR *pDown;
  struct _VMEMR *pLeft;
  struct _VMEMR *pRight;
  FLATPTR  ptr;
  DWORD size;
  DWORD x;
  DWORD y;
  DWORD cx;
  DWORD cy;
  DWORD flags;
  FLATPTR pBits;
  WINBOOL bDiscardable;
} VMEMR,  *LPVMEMR,  *LPLPVMEMR;

typedef struct _SURFACEALIGNMENT
{
  __GNU_EXTENSION union {
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
} SURFACEALIGNMENT, *LPSURFACEALIGNMENT;

typedef struct _HEAPALIGNMENT
{
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
} HEAPALIGNMENT, *LPHEAPALIGNMENT;

typedef struct _VMEMHEAP
{
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
    BYTE* pAgpCommitMask;
    DWORD dwAgpCommitMaskSize;
} VMEMHEAP, *LPVMEMHEAP;

typedef struct _DD_GETHEAPALIGNMENTDATA
{
    ULONG_PTR dwInstance;
    DWORD dwHeap;
    HRESULT ddRVal;
    VOID* GetHeapAlignment;
    HEAPALIGNMENT Alignment;
} DD_GETHEAPALIGNMENTDATA;

#ifndef DD_GETHEAPALIGNMENTDATA_DECLARED
typedef DD_GETHEAPALIGNMENTDATA *PDD_GETHEAPALIGNMENTDATA;
#define DD_GETHEAPALIGNMENTDATA_DECLARED
#endif

extern void WINAPI VidMemFree (LPVMEMHEAP pvmh, FLATPTR ptr);
extern FLATPTR WINAPI VidMemAlloc (LPVMEMHEAP pvmh, DWORD width, DWORD height);

extern FLATPTR WINAPI
       HeapVidMemAllocAligned(
                               LPVIDMEM lpVidMem,
                               DWORD dwWidth,
                               DWORD dwHeight,
                               LPSURFACEALIGNMENT lpAlignment,
                               LPLONG lpNewPitch );

#ifdef __cplusplus
}
#endif

#endif /* __DMEMMGR_INCLUDED__ */


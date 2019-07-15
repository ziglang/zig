/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _INC_DCIDDI
#define _INC_DCIDDI

#ifdef __cplusplus
extern "C" {
#endif

#define DCICOMMAND 3075
#define DCI_VERSION 0x0100

#define DCICREATEPRIMARYSURFACE 1
#define DCICREATEOFFSCREENSURFACE 2
#define DCICREATEOVERLAYSURFACE 3
#define DCIENUMSURFACE 4
#define DCIESCAPE 5

#define DCI_OK 0
#define DCI_FAIL_GENERIC -1
#define DCI_FAIL_UNSUPPORTEDVERSION -2
#define DCI_FAIL_INVALIDSURFACE -3
#define DCI_FAIL_UNSUPPORTED -4

#define DCI_ERR_CURRENTLYNOTAVAIL -5
#define DCI_ERR_INVALIDRECT -6
#define DCI_ERR_UNSUPPORTEDFORMAT -7
#define DCI_ERR_UNSUPPORTEDMASK -8
#define DCI_ERR_TOOBIGHEIGHT -9
#define DCI_ERR_TOOBIGWIDTH -10
#define DCI_ERR_TOOBIGSIZE -11
#define DCI_ERR_OUTOFMEMORY -12
#define DCI_ERR_INVALIDPOSITION -13
#define DCI_ERR_INVALIDSTRETCH -14
#define DCI_ERR_INVALIDCLIPLIST -15
#define DCI_ERR_SURFACEISOBSCURED -16
#define DCI_ERR_XALIGN -17
#define DCI_ERR_YALIGN -18
#define DCI_ERR_XYALIGN -19
#define DCI_ERR_WIDTHALIGN -20
#define DCI_ERR_HEIGHTALIGN -21

#define DCI_STATUS_POINTERCHANGED 1
#define DCI_STATUS_STRIDECHANGED 2
#define DCI_STATUS_FORMATCHANGED 4
#define DCI_STATUS_SURFACEINFOCHANGED 8
#define DCI_STATUS_CHROMAKEYCHANGED 16
#define DCI_STATUS_WASSTILLDRAWING 32

#define DCI_SUCCESS(error) (((DCIRVAL)error) >= 0)

#define DCI_SURFACE_TYPE 0x0000000F
#define DCI_PRIMARY 0x00000000
#define DCI_OFFSCREEN 0x00000001
#define DCI_OVERLAY 0x00000002
#define DCI_VISIBLE 0x00000010
#define DCI_CHROMAKEY 0x00000020
#define DCI_1632_ACCESS 0x00000040
#define DCI_DWORDSIZE 0x00000080
#define DCI_DWORDALIGN 0x00000100
#define DCI_WRITEONLY 0x00000200
#define DCI_ASYNC 0x00000400

#define DCI_CAN_STRETCHX 0x00001000
#define DCI_CAN_STRETCHY 0x00002000
#define DCI_CAN_STRETCHXY (DCI_CAN_STRETCHX | DCI_CAN_STRETCHY)

#define DCI_CAN_STRETCHXN 0x00004000
#define DCI_CAN_STRETCHYN 0x00008000
#define DCI_CAN_STRETCHXYN (DCI_CAN_STRETCHXN | DCI_CAN_STRETCHYN)

#define DCI_CANOVERLAY 0x00010000

  typedef int DCIRVAL;

  typedef struct _DCICMD {
    DWORD dwCommand;
    DWORD dwParam1;
    DWORD dwParam2;
    DWORD dwVersion;
    DWORD dwReserved;
  } DCICMD;

  typedef struct _DCICREATEINPUT {
    DCICMD cmd;
    DWORD dwCompression;
    DWORD dwMask[3];
    DWORD dwWidth;
    DWORD dwHeight;
    DWORD dwDCICaps;
    DWORD dwBitCount;
    LPVOID lpSurface;
  } DCICREATEINPUT,*LPDCICREATEINPUT;

  typedef struct _DCISURFACEINFO {
    DWORD dwSize;
    DWORD dwDCICaps;
    DWORD dwCompression;
    DWORD dwMask[3];
    DWORD dwWidth;
    DWORD dwHeight;
    LONG lStride;
    DWORD dwBitCount;
    ULONG_PTR dwOffSurface;
    WORD wSelSurface;
    WORD wReserved;
    DWORD dwReserved1;
    DWORD dwReserved2;
    DWORD dwReserved3;
    DCIRVAL (CALLBACK *BeginAccess) (LPVOID,LPRECT);
    void (CALLBACK *EndAccess) (LPVOID);
    void (CALLBACK *DestroySurface) (LPVOID);
  } DCISURFACEINFO,*LPDCISURFACEINFO;

  typedef void (*ENUM_CALLBACK)(LPDCISURFACEINFO lpSurfaceInfo,LPVOID lpContext);

  typedef struct _DCIENUMINPUT {
    DCICMD cmd;
    RECT rSrc;
    RECT rDst;
    void (CALLBACK *EnumCallback)(LPDCISURFACEINFO,LPVOID);
    LPVOID lpContext;
  } DCIENUMINPUT,*LPDCIENUMINPUT;

  typedef DCISURFACEINFO DCIPRIMARY,*LPDCIPRIMARY;

  typedef struct _DCIOFFSCREEN {
    DCISURFACEINFO dciInfo;
    DCIRVAL (CALLBACK *Draw) (LPVOID);
    DCIRVAL (CALLBACK *SetClipList) (LPVOID,LPRGNDATA);
    DCIRVAL (CALLBACK *SetDestination) (LPVOID,LPRECT,LPRECT);
  } DCIOFFSCREEN,*LPDCIOFFSCREEN;

  typedef struct _DCIOVERLAY {
    DCISURFACEINFO dciInfo;
    DWORD dwChromakeyValue;
    DWORD dwChromakeyMask;
  } DCIOVERLAY,*LPDCIOVERLAY;

#ifndef YVU9
#define YVU9 mmioFOURCC('Y','V','U','9')
#endif
#ifndef Y411
#define Y411 mmioFOURCC('Y','4','1','1')
#endif
#ifndef YUY2
#define YUY2 mmioFOURCC('Y','U','Y','2')
#endif
#ifndef YVYU
#define YVYU mmioFOURCC('Y','V','Y','U')
#endif
#ifndef UYVY
#define UYVY mmioFOURCC('U','Y','V','Y')
#endif
#ifndef Y211
#define Y211 mmioFOURCC('Y','2','1','1')
#endif

#ifdef __cplusplus
}
#endif
#endif

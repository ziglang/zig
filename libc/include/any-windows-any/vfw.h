/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _INC_VFW
#define _INC_VFW

#include <_mingw_unicode.h>

#ifdef __cplusplus
extern "C" {
#endif

#define VFWAPI WINAPI
#define VFWAPIV WINAPIV
#define VFWAPI_INLINE WINAPI

  DWORD WINAPI VideoForWindowsVersion(void);
  LONG WINAPI InitVFW(void);
  LONG WINAPI TermVFW(void);

#ifdef __cplusplus
}
#endif

#if !defined(_INC_MMSYSTEM) && (!defined(NOVIDEO) || !defined(NOAVICAP))
#include <mmsystem.h>
#endif

#ifdef __cplusplus
extern "C" {
#endif

#ifndef MKFOURCC
#define MKFOURCC(ch0,ch1,ch2,ch3) ((DWORD)(BYTE)(ch0) | ((DWORD)(BYTE)(ch1) << 8) | ((DWORD)(BYTE)(ch2) << 16) | ((DWORD)(BYTE)(ch3) << 24))
#endif

#if !defined(_INC_MMSYSTEM)
#define mmioFOURCC MKFOURCC
#endif

#ifndef NOCOMPMAN

#define ICVERSION 0x0104

  DECLARE_HANDLE(HIC);

#define BI_1632 0x32333631

#ifndef mmioFOURCC
#define mmioFOURCC(ch0,ch1,ch2,ch3) ((DWORD)(BYTE)(ch0) | ((DWORD)(BYTE)(ch1) << 8) | ((DWORD)(BYTE)(ch2) << 16) | ((DWORD)(BYTE)(ch3) << 24))
#endif

#ifndef aviTWOCC
#define aviTWOCC(ch0,ch1) ((WORD)(BYTE)(ch0) | ((WORD)(BYTE)(ch1) << 8))
#endif

#ifndef ICTYPE_VIDEO
#define ICTYPE_VIDEO mmioFOURCC('v','i','d','c')
#define ICTYPE_AUDIO mmioFOURCC('a','u','d','c')
#endif

#ifndef ICERR_OK
#define ICERR_OK __MSABI_LONG(0)
#define ICERR_DONTDRAW __MSABI_LONG(1)
#define ICERR_NEWPALETTE __MSABI_LONG(2)
#define ICERR_GOTOKEYFRAME __MSABI_LONG(3)
#define ICERR_STOPDRAWING __MSABI_LONG(4)

#define ICERR_UNSUPPORTED __MSABI_LONG(-1)
#define ICERR_BADFORMAT __MSABI_LONG(-2)
#define ICERR_MEMORY __MSABI_LONG(-3)
#define ICERR_INTERNAL __MSABI_LONG(-4)
#define ICERR_BADFLAGS __MSABI_LONG(-5)
#define ICERR_BADPARAM __MSABI_LONG(-6)
#define ICERR_BADSIZE __MSABI_LONG(-7)
#define ICERR_BADHANDLE __MSABI_LONG(-8)
#define ICERR_CANTUPDATE __MSABI_LONG(-9)
#define ICERR_ABORT __MSABI_LONG(-10)
#define ICERR_ERROR __MSABI_LONG(-100)
#define ICERR_BADBITDEPTH __MSABI_LONG(-200)
#define ICERR_BADIMAGESIZE __MSABI_LONG(-201)

#define ICERR_CUSTOM __MSABI_LONG(-400)
#endif

#ifndef ICMODE_COMPRESS
#define ICMODE_COMPRESS 1
#define ICMODE_DECOMPRESS 2
#define ICMODE_FASTDECOMPRESS 3
#define ICMODE_QUERY 4
#define ICMODE_FASTCOMPRESS 5
#define ICMODE_DRAW 8
#endif

#define AVIIF_LIST __MSABI_LONG(0x00000001)
#define AVIIF_TWOCC __MSABI_LONG(0x00000002)
#define AVIIF_KEYFRAME __MSABI_LONG(0x00000010)

#define ICQUALITY_LOW 0
#define ICQUALITY_HIGH 10000
#define ICQUALITY_DEFAULT -1

#define ICM_USER (DRV_USER+0x0000)

#define ICM_RESERVED ICM_RESERVED_LOW
#define ICM_RESERVED_LOW (DRV_USER+0x1000)
#define ICM_RESERVED_HIGH (DRV_USER+0x2000)

#define ICM_GETSTATE (ICM_RESERVED+0)
#define ICM_SETSTATE (ICM_RESERVED+1)
#define ICM_GETINFO (ICM_RESERVED+2)

#define ICM_CONFIGURE (ICM_RESERVED+10)
#define ICM_ABOUT (ICM_RESERVED+11)

#define ICM_GETERRORTEXT (ICM_RESERVED+12)
#define ICM_GETFORMATNAME (ICM_RESERVED+20)
#define ICM_ENUMFORMATS (ICM_RESERVED+21)

#define ICM_GETDEFAULTQUALITY (ICM_RESERVED+30)
#define ICM_GETQUALITY (ICM_RESERVED+31)
#define ICM_SETQUALITY (ICM_RESERVED+32)

#define ICM_SET (ICM_RESERVED+40)
#define ICM_GET (ICM_RESERVED+41)

#define ICM_FRAMERATE mmioFOURCC('F','r','m','R')
#define ICM_KEYFRAMERATE mmioFOURCC('K','e','y','R')

#define ICM_COMPRESS_GET_FORMAT (ICM_USER+4)
#define ICM_COMPRESS_GET_SIZE (ICM_USER+5)
#define ICM_COMPRESS_QUERY (ICM_USER+6)
#define ICM_COMPRESS_BEGIN (ICM_USER+7)
#define ICM_COMPRESS (ICM_USER+8)
#define ICM_COMPRESS_END (ICM_USER+9)

#define ICM_DECOMPRESS_GET_FORMAT (ICM_USER+10)
#define ICM_DECOMPRESS_QUERY (ICM_USER+11)
#define ICM_DECOMPRESS_BEGIN (ICM_USER+12)
#define ICM_DECOMPRESS (ICM_USER+13)
#define ICM_DECOMPRESS_END (ICM_USER+14)
#define ICM_DECOMPRESS_SET_PALETTE (ICM_USER+29)
#define ICM_DECOMPRESS_GET_PALETTE (ICM_USER+30)

#define ICM_DRAW_QUERY (ICM_USER+31)
#define ICM_DRAW_BEGIN (ICM_USER+15)
#define ICM_DRAW_GET_PALETTE (ICM_USER+16)
#define ICM_DRAW_UPDATE (ICM_USER+17)
#define ICM_DRAW_START (ICM_USER+18)
#define ICM_DRAW_STOP (ICM_USER+19)
#define ICM_DRAW_BITS (ICM_USER+20)
#define ICM_DRAW_END (ICM_USER+21)
#define ICM_DRAW_GETTIME (ICM_USER+32)
#define ICM_DRAW (ICM_USER+33)
#define ICM_DRAW_WINDOW (ICM_USER+34)
#define ICM_DRAW_SETTIME (ICM_USER+35)
#define ICM_DRAW_REALIZE (ICM_USER+36)
#define ICM_DRAW_FLUSH (ICM_USER+37)
#define ICM_DRAW_RENDERBUFFER (ICM_USER+38)

#define ICM_DRAW_START_PLAY (ICM_USER+39)
#define ICM_DRAW_STOP_PLAY (ICM_USER+40)

#define ICM_DRAW_SUGGESTFORMAT (ICM_USER+50)
#define ICM_DRAW_CHANGEPALETTE (ICM_USER+51)

#define ICM_DRAW_IDLE (ICM_USER+52)

#define ICM_GETBUFFERSWANTED (ICM_USER+41)

#define ICM_GETDEFAULTKEYFRAMERATE (ICM_USER+42)

#define ICM_DECOMPRESSEX_BEGIN (ICM_USER+60)
#define ICM_DECOMPRESSEX_QUERY (ICM_USER+61)
#define ICM_DECOMPRESSEX (ICM_USER+62)
#define ICM_DECOMPRESSEX_END (ICM_USER+63)

#define ICM_COMPRESS_FRAMES_INFO (ICM_USER+70)
#define ICM_COMPRESS_FRAMES (ICM_USER+71)
#define ICM_SET_STATUS_PROC (ICM_USER+72)

  typedef struct {
    DWORD dwSize;
    DWORD fccType;
    DWORD fccHandler;
    DWORD dwVersion;
    DWORD dwFlags;
    LRESULT dwError;
    LPVOID pV1Reserved;
    LPVOID pV2Reserved;
    DWORD dnDevNode;
  } ICOPEN;

  typedef struct {
    DWORD dwSize;
    DWORD fccType;
    DWORD fccHandler;
    DWORD dwFlags;
    DWORD dwVersion;
    DWORD dwVersionICM;

    WCHAR szName[16];
    WCHAR szDescription[128];
    WCHAR szDriver[128];
  } ICINFO;

#define VIDCF_QUALITY 0x0001
#define VIDCF_CRUNCH 0x0002
#define VIDCF_TEMPORAL 0x0004
#define VIDCF_COMPRESSFRAMES 0x0008
#define VIDCF_DRAW 0x0010
#define VIDCF_FASTTEMPORALC 0x0020
#define VIDCF_QUALITYTIME   0x0040
#define VIDCF_FASTTEMPORALD 0x0080
#define VIDCF_FASTTEMPORAL	(VIDCF_FASTTEMPORALC|VIDCF_FASTTEMPORALD)

#define ICCOMPRESS_KEYFRAME __MSABI_LONG(0x00000001)

  typedef struct {
    DWORD dwFlags;
    LPBITMAPINFOHEADER lpbiOutput;
    LPVOID lpOutput;

    LPBITMAPINFOHEADER lpbiInput;
    LPVOID lpInput;
    LPDWORD lpckid;
    LPDWORD lpdwFlags;
    LONG lFrameNum;
    DWORD dwFrameSize;
    DWORD dwQuality;
    LPBITMAPINFOHEADER lpbiPrev;
    LPVOID lpPrev;
  } ICCOMPRESS;

#define ICCOMPRESSFRAMES_PADDING 0x00000001

  typedef struct {
    DWORD dwFlags;
    LPBITMAPINFOHEADER lpbiOutput;
    LPARAM lOutput;
    LPBITMAPINFOHEADER lpbiInput;
    LPARAM lInput;
    LONG lStartFrame;
    LONG lFrameCount;
    LONG lQuality;
    LONG lDataRate;
    LONG lKeyRate;
    DWORD dwRate;
    DWORD dwScale;
    DWORD dwOverheadPerFrame;
    DWORD dwReserved2;
    LONG (CALLBACK *GetData)(LPARAM lInput,LONG lFrame,LPVOID lpBits,LONG len);
    LONG (CALLBACK *PutData)(LPARAM lOutput,LONG lFrame,LPVOID lpBits,LONG len);
  } ICCOMPRESSFRAMES;

#define ICSTATUS_START 0
#define ICSTATUS_STATUS 1
#define ICSTATUS_END 2
#define ICSTATUS_ERROR 3
#define ICSTATUS_YIELD 4

  typedef struct {
    DWORD dwFlags;
    LPARAM lParam;
    LONG (CALLBACK *Status)(LPARAM lParam,UINT message,LONG l);
  } ICSETSTATUSPROC;

#define ICDECOMPRESS_HURRYUP __MSABI_LONG(0x80000000)
#define ICDECOMPRESS_UPDATE __MSABI_LONG(0x40000000)
#define ICDECOMPRESS_PREROLL __MSABI_LONG(0x20000000)
#define ICDECOMPRESS_NULLFRAME __MSABI_LONG(0x10000000)
#define ICDECOMPRESS_NOTKEYFRAME __MSABI_LONG(0x08000000)

  typedef struct {
    DWORD dwFlags;
    LPBITMAPINFOHEADER lpbiInput;
    LPVOID lpInput;
    LPBITMAPINFOHEADER lpbiOutput;
    LPVOID lpOutput;
    DWORD ckid;
  } ICDECOMPRESS;

  typedef struct {
    DWORD dwFlags;
    LPBITMAPINFOHEADER lpbiSrc;
    LPVOID lpSrc;
    LPBITMAPINFOHEADER lpbiDst;
    LPVOID lpDst;
    int xDst;
    int yDst;
    int dxDst;
    int dyDst;

    int xSrc;
    int ySrc;
    int dxSrc;
    int dySrc;
  } ICDECOMPRESSEX;

#define ICDRAW_QUERY __MSABI_LONG(0x00000001)
#define ICDRAW_FULLSCREEN __MSABI_LONG(0x00000002)
#define ICDRAW_HDC __MSABI_LONG(0x00000004)
#define ICDRAW_ANIMATE __MSABI_LONG(0x00000008)
#define ICDRAW_CONTINUE __MSABI_LONG(0x00000010)
#define ICDRAW_MEMORYDC __MSABI_LONG(0x00000020)
#define ICDRAW_UPDATING __MSABI_LONG(0x00000040)
#define ICDRAW_RENDER __MSABI_LONG(0x00000080)
#define ICDRAW_BUFFER __MSABI_LONG(0x00000100)

  typedef struct {
    DWORD dwFlags;
    HPALETTE hpal;
    HWND hwnd;
    HDC hdc;
    int xDst;
    int yDst;
    int dxDst;
    int dyDst;
    LPBITMAPINFOHEADER lpbi;
    int xSrc;
    int ySrc;
    int dxSrc;
    int dySrc;
    DWORD dwRate;
    DWORD dwScale;
  } ICDRAWBEGIN;

#define ICDRAW_HURRYUP __MSABI_LONG(0x80000000)
#define ICDRAW_UPDATE __MSABI_LONG(0x40000000)
#define ICDRAW_PREROLL __MSABI_LONG(0x20000000)
#define ICDRAW_NULLFRAME __MSABI_LONG(0x10000000)
#define ICDRAW_NOTKEYFRAME __MSABI_LONG(0x08000000)

  typedef struct {
    DWORD dwFlags;
    LPVOID lpFormat;
    LPVOID lpData;
    DWORD cbData;
    LONG lTime;
  } ICDRAW;

  typedef struct {
    LPBITMAPINFOHEADER lpbiIn;
    LPBITMAPINFOHEADER lpbiSuggest;
    int dxSrc;
    int dySrc;
    int dxDst;
    int dyDst;
    HIC hicDecompressor;
  } ICDRAWSUGGEST;

  typedef struct {
    DWORD dwFlags;
    int iStart;
    int iLen;
    LPPALETTEENTRY lppe;
  } ICPALETTE;

  WINBOOL WINAPI ICInfo(DWORD fccType,DWORD fccHandler,ICINFO *lpicinfo);
  WINBOOL WINAPI ICInstall(DWORD fccType,DWORD fccHandler,LPARAM lParam,LPSTR szDesc,UINT wFlags);
  WINBOOL WINAPI ICRemove(DWORD fccType,DWORD fccHandler,UINT wFlags);
  LRESULT WINAPI ICGetInfo(HIC hic,ICINFO *picinfo,DWORD cb);
  HIC WINAPI ICOpen(DWORD fccType,DWORD fccHandler,UINT wMode);
  HIC WINAPI ICOpenFunction(DWORD fccType,DWORD fccHandler,UINT wMode,FARPROC lpfnHandler);
  LRESULT WINAPI ICClose(HIC hic);
  LRESULT WINAPI ICSendMessage(HIC hic,UINT msg,DWORD_PTR dw1,DWORD_PTR dw2);

#define ICINSTALL_UNICODE 0x8000
#define ICINSTALL_FUNCTION 0x0001
#define ICINSTALL_DRIVER 0x0002
#define ICINSTALL_HDRV 0x0004
#define ICINSTALL_DRIVERW 0x8002

#define ICMF_CONFIGURE_QUERY 0x00000001
#define ICMF_ABOUT_QUERY 0x00000001

#define ICQueryAbout(hic) (ICSendMessage(hic,ICM_ABOUT,(DWORD_PTR) -1,ICMF_ABOUT_QUERY)==ICERR_OK)
#define ICAbout(hic,hwnd) ICSendMessage(hic,ICM_ABOUT,(DWORD_PTR)(UINT_PTR)(hwnd),(DWORD_PTR)0)
#define ICQueryConfigure(hic) (ICSendMessage(hic,ICM_CONFIGURE,(DWORD_PTR) -1,ICMF_CONFIGURE_QUERY)==ICERR_OK)
#define ICConfigure(hic,hwnd) ICSendMessage(hic,ICM_CONFIGURE,(DWORD_PTR)(UINT_PTR)(hwnd),(DWORD_PTR)0)
#define ICGetState(hic,pv,cb) ICSendMessage(hic,ICM_GETSTATE,(DWORD_PTR)(LPVOID)(pv),(DWORD_PTR)(cb))
#define ICSetState(hic,pv,cb) ICSendMessage(hic,ICM_SETSTATE,(DWORD_PTR)(LPVOID)(pv),(DWORD_PTR)(cb))
#define ICGetStateSize(hic) (DWORD) ICGetState(hic,NULL,0)

  static DWORD dwICValue;

#define ICGetDefaultQuality(hic) (ICSendMessage(hic,ICM_GETDEFAULTQUALITY,(DWORD_PTR)(LPVOID)&dwICValue,sizeof(DWORD)),dwICValue)
#define ICGetDefaultKeyFrameRate(hic) (ICSendMessage(hic,ICM_GETDEFAULTKEYFRAMERATE,(DWORD_PTR)(LPVOID)&dwICValue,sizeof(DWORD)),dwICValue)
#define ICDrawWindow(hic,prc) ICSendMessage(hic,ICM_DRAW_WINDOW,(DWORD_PTR)(LPVOID)(prc),sizeof(RECT))

  DWORD WINAPIV ICCompress(HIC hic,DWORD dwFlags,LPBITMAPINFOHEADER lpbiOutput,LPVOID lpData,LPBITMAPINFOHEADER lpbiInput,LPVOID lpBits,LPDWORD lpckid,LPDWORD lpdwFlags,LONG lFrameNum,DWORD dwFrameSize,DWORD dwQuality,LPBITMAPINFOHEADER lpbiPrev,LPVOID lpPrev);

#define ICCompressBegin(hic,lpbiInput,lpbiOutput) ICSendMessage(hic,ICM_COMPRESS_BEGIN,(DWORD_PTR)(LPVOID)(lpbiInput),(DWORD_PTR)(LPVOID)(lpbiOutput))
#define ICCompressQuery(hic,lpbiInput,lpbiOutput) ICSendMessage(hic,ICM_COMPRESS_QUERY,(DWORD_PTR)(LPVOID)(lpbiInput),(DWORD_PTR)(LPVOID)(lpbiOutput))
#define ICCompressGetFormat(hic,lpbiInput,lpbiOutput) ICSendMessage(hic,ICM_COMPRESS_GET_FORMAT,(DWORD_PTR)(LPVOID)(lpbiInput),(DWORD_PTR)(LPVOID)(lpbiOutput))
#define ICCompressGetFormatSize(hic,lpbi) (DWORD) ICCompressGetFormat(hic,lpbi,NULL)
#define ICCompressGetSize(hic,lpbiInput,lpbiOutput) (DWORD) ICSendMessage(hic,ICM_COMPRESS_GET_SIZE,(DWORD_PTR)(LPVOID)(lpbiInput),(DWORD_PTR)(LPVOID)(lpbiOutput))
#define ICCompressEnd(hic) ICSendMessage(hic,ICM_COMPRESS_END,(DWORD_PTR)0,(DWORD_PTR)0)
#define ICDECOMPRESS_HURRYUP __MSABI_LONG(0x80000000)

  DWORD WINAPIV ICDecompress(HIC hic,DWORD dwFlags,LPBITMAPINFOHEADER lpbiFormat,LPVOID lpData,LPBITMAPINFOHEADER lpbi,LPVOID lpBits);

#define ICDecompressBegin(hic,lpbiInput,lpbiOutput) ICSendMessage(hic,ICM_DECOMPRESS_BEGIN,(DWORD_PTR)(LPVOID)(lpbiInput),(DWORD_PTR)(LPVOID)(lpbiOutput))
#define ICDecompressQuery(hic,lpbiInput,lpbiOutput) ICSendMessage(hic,ICM_DECOMPRESS_QUERY,(DWORD_PTR)(LPVOID)(lpbiInput),(DWORD_PTR)(LPVOID)(lpbiOutput))
#define ICDecompressGetFormat(hic,lpbiInput,lpbiOutput) ((LONG) ICSendMessage(hic,ICM_DECOMPRESS_GET_FORMAT,(DWORD_PTR)(LPVOID)(lpbiInput),(DWORD_PTR)(LPVOID)(lpbiOutput)))
#define ICDecompressGetFormatSize(hic,lpbi) ICDecompressGetFormat(hic,lpbi,NULL)
#define ICDecompressGetPalette(hic,lpbiInput,lpbiOutput) ICSendMessage(hic,ICM_DECOMPRESS_GET_PALETTE,(DWORD_PTR)(LPVOID)(lpbiInput),(DWORD_PTR)(LPVOID)(lpbiOutput))
#define ICDecompressSetPalette(hic,lpbiPalette) ICSendMessage(hic,ICM_DECOMPRESS_SET_PALETTE,(DWORD_PTR)(LPVOID)(lpbiPalette),(DWORD_PTR)0)
#define ICDecompressEnd(hic) ICSendMessage(hic,ICM_DECOMPRESS_END,(DWORD_PTR)0,(DWORD_PTR)0)

#ifndef __CRT__NO_INLINE
  __CRT_INLINE LRESULT WINAPI ICDecompressEx(HIC hic,DWORD dwFlags,LPBITMAPINFOHEADER lpbiSrc,LPVOID lpSrc,int xSrc,int ySrc,int dxSrc,int dySrc,LPBITMAPINFOHEADER lpbiDst,LPVOID lpDst,int xDst,int yDst,int dxDst,int dyDst) {
    ICDECOMPRESSEX ic;
    ic.dwFlags = dwFlags;
    ic.lpbiSrc = lpbiSrc;
    ic.lpSrc = lpSrc;
    ic.xSrc = xSrc;
    ic.ySrc = ySrc;
    ic.dxSrc = dxSrc;
    ic.dySrc = dySrc;
    ic.lpbiDst = lpbiDst;
    ic.lpDst = lpDst;
    ic.xDst = xDst;
    ic.yDst = yDst;
    ic.dxDst = dxDst;
    ic.dyDst = dyDst;
    return ICSendMessage(hic,ICM_DECOMPRESSEX,(DWORD_PTR)&ic,sizeof(ic));
  }

  __CRT_INLINE LRESULT WINAPI ICDecompressExBegin(HIC hic,DWORD dwFlags,LPBITMAPINFOHEADER lpbiSrc,LPVOID lpSrc,int xSrc,int ySrc,int dxSrc,int dySrc,LPBITMAPINFOHEADER lpbiDst,LPVOID lpDst,int xDst,int yDst,int dxDst,int dyDst) {
    ICDECOMPRESSEX ic;
    ic.dwFlags = dwFlags;
    ic.lpbiSrc = lpbiSrc;
    ic.lpSrc = lpSrc;
    ic.xSrc = xSrc;
    ic.ySrc = ySrc;
    ic.dxSrc = dxSrc;
    ic.dySrc = dySrc;
    ic.lpbiDst = lpbiDst;
    ic.lpDst = lpDst;
    ic.xDst = xDst;
    ic.yDst = yDst;
    ic.dxDst = dxDst;
    ic.dyDst = dyDst;
    return ICSendMessage(hic,ICM_DECOMPRESSEX_BEGIN,(DWORD_PTR)&ic,sizeof(ic));
  }

  __CRT_INLINE LRESULT WINAPI ICDecompressExQuery(HIC hic,DWORD dwFlags,LPBITMAPINFOHEADER lpbiSrc,LPVOID lpSrc,int xSrc,int ySrc,int dxSrc,int dySrc,LPBITMAPINFOHEADER lpbiDst,LPVOID lpDst,int xDst,int yDst,int dxDst,int dyDst) {
    ICDECOMPRESSEX ic;
    ic.dwFlags = dwFlags;
    ic.lpbiSrc = lpbiSrc;
    ic.lpSrc = lpSrc;
    ic.xSrc = xSrc;
    ic.ySrc = ySrc;
    ic.dxSrc = dxSrc;
    ic.dySrc = dySrc;
    ic.lpbiDst = lpbiDst;
    ic.lpDst = lpDst;
    ic.xDst = xDst;
    ic.yDst = yDst;
    ic.dxDst = dxDst;
    ic.dyDst = dyDst;
    return ICSendMessage(hic,ICM_DECOMPRESSEX_QUERY,(DWORD_PTR)&ic,sizeof(ic));
  }
#endif /* !__CRT__NO_INLINE */

#define ICDecompressExEnd(hic) ICSendMessage(hic,ICM_DECOMPRESSEX_END,(DWORD_PTR)0,(DWORD_PTR)0)

#define ICDRAW_QUERY __MSABI_LONG(0x00000001)
#define ICDRAW_FULLSCREEN __MSABI_LONG(0x00000002)
#define ICDRAW_HDC __MSABI_LONG(0x00000004)

  DWORD WINAPIV ICDrawBegin(HIC hic,DWORD dwFlags,HPALETTE hpal,HWND hwnd,HDC hdc,int xDst,int yDst,int dxDst,int dyDst,LPBITMAPINFOHEADER lpbi,int xSrc,int ySrc,int dxSrc,int dySrc,DWORD dwRate,DWORD dwScale);

#define ICDRAW_HURRYUP __MSABI_LONG(0x80000000)
#define ICDRAW_UPDATE __MSABI_LONG(0x40000000)

  DWORD WINAPIV ICDraw(HIC hic,DWORD dwFlags,LPVOID lpFormat,LPVOID lpData,DWORD cbData,LONG lTime);

#ifndef __CRT__NO_INLINE
  __CRT_INLINE LRESULT WINAPI ICDrawSuggestFormat(HIC hic,LPBITMAPINFOHEADER lpbiIn,LPBITMAPINFOHEADER lpbiOut,int dxSrc,int dySrc,int dxDst,int dyDst,HIC hicDecomp) {
    ICDRAWSUGGEST ic;
    ic.lpbiIn = lpbiIn;
    ic.lpbiSuggest = lpbiOut;
    ic.dxSrc = dxSrc;
    ic.dySrc = dySrc;
    ic.dxDst = dxDst;
    ic.dyDst = dyDst;
    ic.hicDecompressor = hicDecomp;
    return ICSendMessage(hic,ICM_DRAW_SUGGESTFORMAT,(DWORD_PTR)&ic,sizeof(ic));
  }
#endif /* !__CRT__NO_INLINE */

#define ICDrawQuery(hic,lpbiInput) ICSendMessage(hic,ICM_DRAW_QUERY,(DWORD_PTR)(LPVOID)(lpbiInput),(DWORD)0)
#define ICDrawChangePalette(hic,lpbiInput) ICSendMessage(hic,ICM_DRAW_CHANGEPALETTE,(DWORD_PTR)(LPVOID)(lpbiInput),(DWORD)0)
#define ICGetBuffersWanted(hic,lpdwBuffers) ICSendMessage(hic,ICM_GETBUFFERSWANTED,(DWORD_PTR)(LPVOID)(lpdwBuffers),(DWORD_PTR)0)
#define ICDrawEnd(hic) ICSendMessage(hic,ICM_DRAW_END,(DWORD_PTR)0,(DWORD_PTR)0)
#define ICDrawStart(hic) ICSendMessage(hic,ICM_DRAW_START,(DWORD_PTR)0,(DWORD_PTR)0)
#define ICDrawStartPlay(hic,lFrom,lTo) ICSendMessage(hic,ICM_DRAW_START_PLAY,(DWORD_PTR)(lFrom),(DWORD_PTR)(lTo))
#define ICDrawStop(hic) ICSendMessage(hic,ICM_DRAW_STOP,(DWORD_PTR)0,(DWORD_PTR)0)
#define ICDrawStopPlay(hic) ICSendMessage(hic,ICM_DRAW_STOP_PLAY,(DWORD_PTR)0,(DWORD_PTR)0)
#define ICDrawGetTime(hic,lplTime) ICSendMessage(hic,ICM_DRAW_GETTIME,(DWORD_PTR)(LPVOID)(lplTime),(DWORD_PTR)0)
#define ICDrawSetTime(hic,lTime) ICSendMessage(hic,ICM_DRAW_SETTIME,(DWORD_PTR)lTime,(DWORD_PTR)0)
#define ICDrawRealize(hic,hdc,fBackground) ICSendMessage(hic,ICM_DRAW_REALIZE,(DWORD_PTR)(UINT_PTR)(HDC)(hdc),(DWORD_PTR)(WINBOOL)(fBackground))
#define ICDrawFlush(hic) ICSendMessage(hic,ICM_DRAW_FLUSH,(DWORD_PTR)0,(DWORD_PTR)0)
#define ICDrawRenderBuffer(hic) ICSendMessage(hic,ICM_DRAW_RENDERBUFFER,(DWORD_PTR)0,(DWORD_PTR)0)

#ifndef __CRT__NO_INLINE
  __CRT_INLINE LRESULT WINAPI ICSetStatusProc(HIC hic,DWORD dwFlags,LRESULT lParam,LONG (CALLBACK *fpfnStatus)(LPARAM,UINT,LONG)) {
    ICSETSTATUSPROC ic;
    ic.dwFlags = dwFlags;
    ic.lParam = lParam;
    ic.Status = fpfnStatus;
    return ICSendMessage(hic,ICM_SET_STATUS_PROC,(DWORD_PTR)&ic,sizeof(ic));
  }
#endif /* !__CRT__NO_INLINE */

#define ICDecompressOpen(fccType,fccHandler,lpbiIn,lpbiOut) ICLocate(fccType,fccHandler,lpbiIn,lpbiOut,ICMODE_DECOMPRESS)
#define ICDrawOpen(fccType,fccHandler,lpbiIn) ICLocate(fccType,fccHandler,lpbiIn,NULL,ICMODE_DRAW)

  HIC WINAPI ICLocate(DWORD fccType,DWORD fccHandler,LPBITMAPINFOHEADER lpbiIn,LPBITMAPINFOHEADER lpbiOut,WORD wFlags);
  HIC WINAPI ICGetDisplayFormat(HIC hic,LPBITMAPINFOHEADER lpbiIn,LPBITMAPINFOHEADER lpbiOut,int BitDepth,int dx,int dy);
  HANDLE WINAPI ICImageCompress(HIC hic,UINT uiFlags,LPBITMAPINFO lpbiIn,LPVOID lpBits,LPBITMAPINFO lpbiOut,LONG lQuality,LONG *plSize);
  HANDLE WINAPI ICImageDecompress(HIC hic,UINT uiFlags,LPBITMAPINFO lpbiIn,LPVOID lpBits,LPBITMAPINFO lpbiOut);

  typedef struct {
    LONG cbSize;
    DWORD dwFlags;
    HIC hic;
    DWORD fccType;
    DWORD fccHandler;
    LPBITMAPINFO lpbiIn;
    LPBITMAPINFO lpbiOut;
    LPVOID lpBitsOut;
    LPVOID lpBitsPrev;
    LONG lFrame;
    LONG lKey;
    LONG lDataRate;
    LONG lQ;
    LONG lKeyCount;
    LPVOID lpState;
    LONG cbState;
  } COMPVARS,*PCOMPVARS;

#define ICMF_COMPVARS_VALID 0x00000001

  WINBOOL WINAPI ICCompressorChoose(HWND hwnd,UINT uiFlags,LPVOID pvIn,LPVOID lpData,PCOMPVARS pc,LPSTR lpszTitle);

#define ICMF_CHOOSE_KEYFRAME 0x0001
#define ICMF_CHOOSE_DATARATE 0x0002
#define ICMF_CHOOSE_PREVIEW 0x0004
#define ICMF_CHOOSE_ALLCOMPRESSORS 0x0008

  WINBOOL WINAPI ICSeqCompressFrameStart(PCOMPVARS pc,LPBITMAPINFO lpbiIn);
  void WINAPI ICSeqCompressFrameEnd(PCOMPVARS pc);
  LPVOID WINAPI ICSeqCompressFrame(PCOMPVARS pc,UINT uiFlags,LPVOID lpBits,WINBOOL *pfKey,LONG *plSize);
  void WINAPI ICCompressorFree(PCOMPVARS pc);
#endif

#ifndef NODRAWDIB

  typedef HANDLE HDRAWDIB;

#define DDF_0001 0x0001
#define DDF_UPDATE 0x0002
#define DDF_SAME_HDC 0x0004
#define DDF_SAME_DRAW 0x0008
#define DDF_DONTDRAW 0x0010
#define DDF_ANIMATE 0x0020
#define DDF_BUFFER 0x0040
#define DDF_JUSTDRAWIT 0x0080
#define DDF_FULLSCREEN 0x0100
#define DDF_BACKGROUNDPAL 0x0200
#define DDF_NOTKEYFRAME 0x0400
#define DDF_HURRYUP 0x0800
#define DDF_HALFTONE 0x1000
#define DDF_2000 0x2000

#define DDF_PREROLL DDF_DONTDRAW
#define DDF_SAME_DIB DDF_SAME_DRAW
#define DDF_SAME_SIZE DDF_SAME_DRAW

  extern WINBOOL WINAPI DrawDibInit(void);
  extern HDRAWDIB WINAPI DrawDibOpen(void);
  extern WINBOOL WINAPI DrawDibClose(HDRAWDIB hdd);
  extern LPVOID WINAPI DrawDibGetBuffer(HDRAWDIB hdd,LPBITMAPINFOHEADER lpbi,DWORD dwSize,DWORD dwFlags);
  extern UINT WINAPI DrawDibError(HDRAWDIB hdd);
  extern HPALETTE WINAPI DrawDibGetPalette(HDRAWDIB hdd);
  extern WINBOOL WINAPI DrawDibSetPalette(HDRAWDIB hdd,HPALETTE hpal);
  extern WINBOOL WINAPI DrawDibChangePalette(HDRAWDIB hdd,int iStart,int iLen,LPPALETTEENTRY lppe);
  extern UINT WINAPI DrawDibRealize(HDRAWDIB hdd,HDC hdc,WINBOOL fBackground);
  extern WINBOOL WINAPI DrawDibStart(HDRAWDIB hdd,DWORD rate);
  extern WINBOOL WINAPI DrawDibStop(HDRAWDIB hdd);
  extern WINBOOL WINAPI DrawDibBegin(HDRAWDIB hdd,HDC hdc,int dxDst,int dyDst,LPBITMAPINFOHEADER lpbi,int dxSrc,int dySrc,UINT wFlags);
  extern WINBOOL WINAPI DrawDibDraw(HDRAWDIB hdd,HDC hdc,int xDst,int yDst,int dxDst,int dyDst,LPBITMAPINFOHEADER lpbi,LPVOID lpBits,int xSrc,int ySrc,int dxSrc,int dySrc,UINT wFlags);

#define DrawDibUpdate(hdd,hdc,x,y) DrawDibDraw(hdd,hdc,x,y,0,0,NULL,NULL,0,0,0,0,DDF_UPDATE)

  extern WINBOOL WINAPI DrawDibEnd(HDRAWDIB hdd);

  typedef struct {
    LONG timeCount;
    LONG timeDraw;
    LONG timeDecompress;
    LONG timeDither;
    LONG timeStretch;
    LONG timeBlt;
    LONG timeSetDIBits;
  } DRAWDIBTIME,*LPDRAWDIBTIME;

  WINBOOL WINAPI DrawDibTime(HDRAWDIB hdd,LPDRAWDIBTIME lpddtime);

#define PD_CAN_DRAW_DIB 0x0001
#define PD_CAN_STRETCHDIB 0x0002
#define PD_STRETCHDIB_1_1_OK 0x0004
#define PD_STRETCHDIB_1_2_OK 0x0008
#define PD_STRETCHDIB_1_N_OK 0x0010

  LRESULT WINAPI DrawDibProfileDisplay(LPBITMAPINFOHEADER lpbi);

#ifdef DRAWDIB_INCLUDE_STRETCHDIB
  void WINAPI StretchDIB(LPBITMAPINFOHEADER biDst,LPVOID lpDst,int DstX,int DstY,int DstXE,int DstYE,LPBITMAPINFOHEADER biSrc,LPVOID lpSrc,int SrcX,int SrcY,int SrcXE,int SrcYE);
#endif
#endif

#ifndef NOAVIFMT
#ifndef _INC_MMSYSTEM
  typedef DWORD FOURCC;
#endif

/* This part of the file is duplicated in avifmt.h */
#ifndef mmioFOURCC
#define mmioFOURCC(ch0,ch1,ch2,ch3) ((DWORD)(BYTE)(ch0) | ((DWORD)(BYTE)(ch1) << 8) | ((DWORD)(BYTE)(ch2) << 16) | ((DWORD)(BYTE)(ch3) << 24))
#endif

#ifndef aviTWOCC
#define aviTWOCC(ch0,ch1) ((WORD)(BYTE)(ch0) | ((WORD)(BYTE)(ch1) << 8))
#endif

  typedef WORD TWOCC;

#define formtypeAVI mmioFOURCC('A','V','I',' ')
#define listtypeAVIHEADER mmioFOURCC('h','d','r','l')
#define ckidAVIMAINHDR mmioFOURCC('a','v','i','h')
#define listtypeSTREAMHEADER mmioFOURCC('s','t','r','l')
#define ckidSTREAMHEADER mmioFOURCC('s','t','r','h')
#define ckidSTREAMFORMAT mmioFOURCC('s','t','r','f')
#define ckidSTREAMHANDLERDATA mmioFOURCC('s','t','r','d')
#define ckidSTREAMNAME mmioFOURCC('s','t','r','n')

#define listtypeAVIMOVIE mmioFOURCC('m','o','v','i')
#define listtypeAVIRECORD mmioFOURCC('r','e','c',' ')

#define ckidAVINEWINDEX mmioFOURCC('i','d','x','1')

#define streamtypeANY __MSABI_LONG(0U)
#define streamtypeVIDEO mmioFOURCC('v','i','d','s')
#define streamtypeAUDIO mmioFOURCC('a','u','d','s')
#define streamtypeMIDI mmioFOURCC('m','i','d','s')
#define streamtypeTEXT mmioFOURCC('t','x','t','s')

#define cktypeDIBbits aviTWOCC('d','b')
#define cktypeDIBcompressed aviTWOCC('d','c')
#define cktypePALchange aviTWOCC('p','c')
#define cktypeWAVEbytes aviTWOCC('w','b')

#define ckidAVIPADDING mmioFOURCC('J','U','N','K')

#define FromHex(n) (((n) >= 'A') ? ((n) + 10 - 'A') : ((n) - '0'))
#define StreamFromFOURCC(fcc) ((WORD) ((FromHex(LOBYTE(LOWORD(fcc))) << 4) + (FromHex(HIBYTE(LOWORD(fcc))))))

#define TWOCCFromFOURCC(fcc) HIWORD(fcc)

#define ToHex(n) ((BYTE) (((n) > 9) ? ((n) - 10 + 'A') : ((n) + '0')))
#define MAKEAVICKID(tcc,stream) MAKELONG((ToHex((stream) & 0x0f) << 8) | (ToHex(((stream) & 0xf0) >> 4)),tcc)

#define AVIF_HASINDEX 0x00000010
#define AVIF_MUSTUSEINDEX 0x00000020
#define AVIF_ISINTERLEAVED 0x00000100
#define AVIF_TRUSTCKTYPE 0x00000800
#define AVIF_WASCAPTUREFILE 0x00010000
#define AVIF_COPYRIGHTED 0x00020000

#define AVI_HEADERSIZE 2048

  typedef struct {
    DWORD dwMicroSecPerFrame;
    DWORD dwMaxBytesPerSec;
    DWORD dwPaddingGranularity;
    DWORD dwFlags;
    DWORD dwTotalFrames;
    DWORD dwInitialFrames;
    DWORD dwStreams;
    DWORD dwSuggestedBufferSize;
    DWORD dwWidth;
    DWORD dwHeight;
    DWORD dwReserved[4];
  } MainAVIHeader;

#define AVISF_DISABLED 0x00000001
#define AVISF_VIDEO_PALCHANGES 0x00010000

  typedef struct {
    FOURCC fccType;
    FOURCC fccHandler;
    DWORD dwFlags;
    WORD wPriority;
    WORD wLanguage;
    DWORD dwInitialFrames;
    DWORD dwScale;
    DWORD dwRate;
    DWORD dwStart;
    DWORD dwLength;
    DWORD dwSuggestedBufferSize;
    DWORD dwQuality;
    DWORD dwSampleSize;
    RECT rcFrame;
  } AVIStreamHeader;

#define AVIIF_LIST __MSABI_LONG(0x00000001)
#define AVIIF_KEYFRAME __MSABI_LONG(0x00000010)
#define AVIIF_FIRSTPART __MSABI_LONG(0x00000020)
#define AVIIF_LASTPART __MSABI_LONG(0x00000040)
#define AVIIF_MIDPART (AVIIF_LASTPART|AVIIF_FIRSTPART)

#define AVIIF_NOTIME __MSABI_LONG(0x00000100)
#define AVIIF_COMPUSE __MSABI_LONG(0x0FFF0000)

  typedef struct {
    DWORD ckid;
    DWORD dwFlags;
    DWORD dwChunkOffset;
    DWORD dwChunkLength;
  } AVIINDEXENTRY;

  typedef struct {
    BYTE bFirstEntry;
    BYTE bNumEntries;
    WORD wFlags;
    PALETTEENTRY peNew[];
  } AVIPALCHANGE;
#endif
/* End of duplication */

#ifdef __cplusplus
}
#endif

#ifndef RC_INVOKED
#include "pshpack8.h"
#endif

#ifndef NOMMREG
#include <mmreg.h>
#endif

#ifdef __cplusplus
extern "C" {
#endif

#ifndef NOAVIFILE
#ifndef mmioFOURCC
#define mmioFOURCC(ch0,ch1,ch2,ch3) ((DWORD)(BYTE)(ch0) | ((DWORD)(BYTE)(ch1) << 8) | ((DWORD)(BYTE)(ch2) << 16) | ((DWORD)(BYTE)(ch3) << 24))
#endif

#ifndef streamtypeVIDEO
#define streamtypeANY __MSABI_LONG(0U)
#define streamtypeVIDEO mmioFOURCC('v','i','d','s')
#define streamtypeAUDIO mmioFOURCC('a','u','d','s')
#define streamtypeMIDI mmioFOURCC('m','i','d','s')
#define streamtypeTEXT mmioFOURCC('t','x','t','s')
#endif

#ifndef AVIIF_KEYFRAME
#define AVIIF_KEYFRAME __MSABI_LONG(0x00000010)
#endif

#define AVIGETFRAMEF_BESTDISPLAYFMT 1

  typedef struct _AVISTREAMINFOW {
    DWORD fccType;
    DWORD fccHandler;
    DWORD dwFlags;
    DWORD dwCaps;
    WORD wPriority;
    WORD wLanguage;
    DWORD dwScale;
    DWORD dwRate;
    DWORD dwStart;
    DWORD dwLength;
    DWORD dwInitialFrames;
    DWORD dwSuggestedBufferSize;
    DWORD dwQuality;
    DWORD dwSampleSize;
    RECT rcFrame;
    DWORD dwEditCount;
    DWORD dwFormatChangeCount;
    WCHAR szName[64];
  } AVISTREAMINFOW,*LPAVISTREAMINFOW;

  typedef struct _AVISTREAMINFOA {
    DWORD fccType;
    DWORD fccHandler;
    DWORD dwFlags;
    DWORD dwCaps;
    WORD wPriority;
    WORD wLanguage;
    DWORD dwScale;
    DWORD dwRate;
    DWORD dwStart;
    DWORD dwLength;
    DWORD dwInitialFrames;
    DWORD dwSuggestedBufferSize;
    DWORD dwQuality;
    DWORD dwSampleSize;
    RECT rcFrame;
    DWORD dwEditCount;
    DWORD dwFormatChangeCount;
    char szName[64];
  } AVISTREAMINFOA,*LPAVISTREAMINFOA;

#define AVISTREAMINFO __MINGW_NAME_AW(AVISTREAMINFO)
#define LPAVISTREAMINFO __MINGW_NAME_AW(LPAVISTREAMINFO)

#define AVISTREAMINFO_DISABLED 0x00000001
#define AVISTREAMINFO_FORMATCHANGES 0x00010000

  typedef struct _AVIFILEINFOW {
    DWORD dwMaxBytesPerSec;
    DWORD dwFlags;
    DWORD dwCaps;
    DWORD dwStreams;
    DWORD dwSuggestedBufferSize;
    DWORD dwWidth;
    DWORD dwHeight;
    DWORD dwScale;
    DWORD dwRate;
    DWORD dwLength;
    DWORD dwEditCount;
    WCHAR szFileType[64];
  } AVIFILEINFOW,*LPAVIFILEINFOW;

  typedef struct _AVIFILEINFOA {
    DWORD dwMaxBytesPerSec;
    DWORD dwFlags;
    DWORD dwCaps;
    DWORD dwStreams;
    DWORD dwSuggestedBufferSize;
    DWORD dwWidth;
    DWORD dwHeight;
    DWORD dwScale;
    DWORD dwRate;
    DWORD dwLength;
    DWORD dwEditCount;
    char szFileType[64];
  } AVIFILEINFOA,*LPAVIFILEINFOA;

#define AVIFILEINFO __MINGW_NAME_AW(AVIFILEINFO)
#define LPAVIFILEINFO __MINGW_NAME_AW(LPAVIFILEINFO)

#define AVIFILEINFO_HASINDEX 0x00000010
#define AVIFILEINFO_MUSTUSEINDEX 0x00000020
#define AVIFILEINFO_ISINTERLEAVED 0x00000100
#define AVIFILEINFO_TRUSTCKTYPE 0x00000800
#define AVIFILEINFO_WASCAPTUREFILE 0x00010000
#define AVIFILEINFO_COPYRIGHTED 0x00020000

#define AVIFILECAPS_CANREAD 0x00000001
#define AVIFILECAPS_CANWRITE 0x00000002
#define AVIFILECAPS_ALLKEYFRAMES 0x00000010
#define AVIFILECAPS_NOCOMPRESSION 0x00000020

  typedef WINBOOL (WINAPI *AVISAVECALLBACK)(int);

  typedef struct {
    DWORD fccType;
    DWORD fccHandler;
    DWORD dwKeyFrameEvery;
    DWORD dwQuality;
    DWORD dwBytesPerSecond;
    DWORD dwFlags;
    LPVOID lpFormat;
    DWORD cbFormat;
    LPVOID lpParms;
    DWORD cbParms;
    DWORD dwInterleaveEvery;
  } AVICOMPRESSOPTIONS, FAR *LPAVICOMPRESSOPTIONS;

#define AVICOMPRESSF_INTERLEAVE 0x00000001
#define AVICOMPRESSF_DATARATE 0x00000002
#define AVICOMPRESSF_KEYFRAMES 0x00000004
#define AVICOMPRESSF_VALID 0x00000008

#ifdef __cplusplus
}
#endif

#include <ole2.h>

#ifdef __cplusplus
extern "C" {
#endif

#undef INTERFACE
#define INTERFACE IAVIStream
  DECLARE_INTERFACE_(IAVIStream,IUnknown) {
    STDMETHOD(QueryInterface) (THIS_ REFIID riid,LPVOID *ppvObj) PURE;
    STDMETHOD_(ULONG,AddRef) (THIS) PURE;
    STDMETHOD_(ULONG,Release) (THIS) PURE;
    STDMETHOD(Create) (THIS_ LPARAM lParam1,LPARAM lParam2) PURE;
    STDMETHOD(Info) (THIS_ AVISTREAMINFOW *psi,LONG lSize) PURE;
    STDMETHOD_(LONG,FindSample)(THIS_ LONG lPos,LONG lFlags) PURE;
    STDMETHOD(ReadFormat) (THIS_ LONG lPos,LPVOID lpFormat,LONG *lpcbFormat) PURE;
    STDMETHOD(SetFormat) (THIS_ LONG lPos,LPVOID lpFormat,LONG cbFormat) PURE;
    STDMETHOD(Read) (THIS_ LONG lStart,LONG lSamples,LPVOID lpBuffer,LONG cbBuffer,LONG *plBytes,LONG *plSamples) PURE;
    STDMETHOD(Write) (THIS_ LONG lStart,LONG lSamples,LPVOID lpBuffer,LONG cbBuffer,DWORD dwFlags,LONG *plSampWritten,LONG *plBytesWritten) PURE;
    STDMETHOD(Delete) (THIS_ LONG lStart,LONG lSamples) PURE;
    STDMETHOD(ReadData) (THIS_ DWORD fcc,LPVOID lp,LONG *lpcb) PURE;
    STDMETHOD(WriteData) (THIS_ DWORD fcc,LPVOID lp,LONG cb) PURE;
    STDMETHOD(SetInfo) (THIS_ AVISTREAMINFOW *lpInfo,LONG cbInfo) PURE;
  };

  typedef IAVIStream *PAVISTREAM;

#undef INTERFACE
#define INTERFACE IAVIStreaming
  DECLARE_INTERFACE_(IAVIStreaming,IUnknown) {
    STDMETHOD(QueryInterface) (THIS_ REFIID riid,LPVOID *ppvObj) PURE;
    STDMETHOD_(ULONG,AddRef) (THIS) PURE;
    STDMETHOD_(ULONG,Release) (THIS) PURE;
    STDMETHOD(Begin) (THIS_ LONG lStart,LONG lEnd,LONG lRate) PURE;
    STDMETHOD(End) (THIS) PURE;
  };

  typedef IAVIStreaming *PAVISTREAMING;

#undef INTERFACE
#define INTERFACE IAVIEditStream
  DECLARE_INTERFACE_(IAVIEditStream,IUnknown) {
    STDMETHOD(QueryInterface) (THIS_ REFIID riid,LPVOID *ppvObj) PURE;
    STDMETHOD_(ULONG,AddRef) (THIS) PURE;
    STDMETHOD_(ULONG,Release) (THIS) PURE;
    STDMETHOD(Cut) (THIS_ LONG *plStart,LONG *plLength,PAVISTREAM *ppResult) PURE;
    STDMETHOD(Copy) (THIS_ LONG *plStart,LONG *plLength,PAVISTREAM *ppResult) PURE;
    STDMETHOD(Paste) (THIS_ LONG *plPos,LONG *plLength,PAVISTREAM pstream,LONG lStart,LONG lEnd) PURE;
    STDMETHOD(Clone) (THIS_ PAVISTREAM *ppResult) PURE;
    STDMETHOD(SetInfo) (THIS_ AVISTREAMINFOW *lpInfo,LONG cbInfo) PURE;
  };

  typedef IAVIEditStream *PAVIEDITSTREAM;

#undef INTERFACE
#define INTERFACE IAVIPersistFile
  DECLARE_INTERFACE_(IAVIPersistFile,IPersistFile) {
    STDMETHOD(Reserved1)(THIS) PURE;
  };

  typedef IAVIPersistFile *PAVIPERSISTFILE;

#undef INTERFACE
#define INTERFACE IAVIFile
#define PAVIFILE IAVIFile *
  DECLARE_INTERFACE_(IAVIFile,IUnknown) {
    STDMETHOD(QueryInterface) (THIS_ REFIID riid,LPVOID *ppvObj) PURE;
    STDMETHOD_(ULONG,AddRef) (THIS) PURE;
    STDMETHOD_(ULONG,Release) (THIS) PURE;
    STDMETHOD(Info) (THIS_ AVIFILEINFOW *pfi,LONG lSize) PURE;
    STDMETHOD(GetStream) (THIS_ PAVISTREAM *ppStream,DWORD fccType,LONG lParam) PURE;
    STDMETHOD(CreateStream) (THIS_ PAVISTREAM *ppStream,AVISTREAMINFOW *psi) PURE;
    STDMETHOD(WriteData) (THIS_ DWORD ckid,LPVOID lpData,LONG cbData) PURE;
    STDMETHOD(ReadData) (THIS_ DWORD ckid,LPVOID lpData,LONG *lpcbData) PURE;
    STDMETHOD(EndRecord) (THIS) PURE;
    STDMETHOD(DeleteStream) (THIS_ DWORD fccType,LONG lParam) PURE;
  };

#undef PAVIFILE
  typedef IAVIFile *PAVIFILE;

#undef INTERFACE
#define INTERFACE IGetFrame
#define PGETFRAME IGetFrame *
  DECLARE_INTERFACE_(IGetFrame,IUnknown) {
    STDMETHOD(QueryInterface) (THIS_ REFIID riid,LPVOID *ppvObj) PURE;
    STDMETHOD_(ULONG,AddRef) (THIS) PURE;
    STDMETHOD_(ULONG,Release) (THIS) PURE;
    STDMETHOD_(LPVOID,GetFrame) (THIS_ LONG lPos) PURE;
    STDMETHOD(Begin) (THIS_ LONG lStart,LONG lEnd,LONG lRate) PURE;
    STDMETHOD(End) (THIS) PURE;
    STDMETHOD(SetFormat) (THIS_ LPBITMAPINFOHEADER lpbi,LPVOID lpBits,int x,int y,int dx,int dy) PURE;
  };

#undef PGETFRAME
  typedef IGetFrame *PGETFRAME;

#define DEFINE_AVIGUID(name,l,w1,w2) DEFINE_GUID(name,l,w1,w2,0xC0,0,0,0,0,0,0,0x46)

  DEFINE_AVIGUID(IID_IAVIFile,0x00020020,0,0);
  DEFINE_AVIGUID(IID_IAVIStream,0x00020021,0,0);
  DEFINE_AVIGUID(IID_IAVIStreaming,0x00020022,0,0);
  DEFINE_AVIGUID(IID_IGetFrame,0x00020023,0,0);
  DEFINE_AVIGUID(IID_IAVIEditStream,0x00020024,0,0);
  DEFINE_AVIGUID(IID_IAVIPersistFile,0x00020025,0,0);
#if !defined(UNICODE)
  DEFINE_AVIGUID(CLSID_AVISimpleUnMarshal,0x00020009,0,0);
#endif

  DEFINE_AVIGUID(CLSID_AVIFile,0x00020000,0,0);

#define AVIFILEHANDLER_CANREAD 0x0001
#define AVIFILEHANDLER_CANWRITE 0x0002
#define AVIFILEHANDLER_CANACCEPTNONRGB 0x0004

#define AVIFileOpen __MINGW_NAME_AW(AVIFileOpen)
#define AVIFileInfo __MINGW_NAME_AW(AVIFileInfo)
#define AVIFileCreateStream __MINGW_NAME_AW(AVIFileCreateStream)
#define AVIStreamInfo __MINGW_NAME_AW(AVIStreamInfo)
#define AVIStreamOpenFromFile __MINGW_NAME_AW(AVIStreamOpenFromFile)

  STDAPI_(void) AVIFileInit(void);
  STDAPI_(void) AVIFileExit(void);
  STDAPI_(ULONG) AVIFileAddRef (PAVIFILE pfile);
  STDAPI_(ULONG) AVIFileRelease (PAVIFILE pfile);
  STDAPI AVIFileOpenA (PAVIFILE *ppfile,LPCSTR szFile,UINT uMode,LPCLSID lpHandler);
  STDAPI AVIFileOpenW (PAVIFILE *ppfile,LPCWSTR szFile,UINT uMode,LPCLSID lpHandler);
  STDAPI AVIFileInfoW (PAVIFILE pfile,LPAVIFILEINFOW pfi,LONG lSize);
  STDAPI AVIFileInfoA (PAVIFILE pfile,LPAVIFILEINFOA pfi,LONG lSize);
  STDAPI AVIFileGetStream (PAVIFILE pfile,PAVISTREAM *ppavi,DWORD fccType,LONG lParam);
  STDAPI AVIFileCreateStreamW (PAVIFILE pfile,PAVISTREAM *ppavi,AVISTREAMINFOW *psi);
  STDAPI AVIFileCreateStreamA (PAVIFILE pfile,PAVISTREAM *ppavi,AVISTREAMINFOA *psi);
  STDAPI AVIFileWriteData (PAVIFILE pfile,DWORD ckid,LPVOID lpData,LONG cbData);
  STDAPI AVIFileReadData (PAVIFILE pfile,DWORD ckid,LPVOID lpData,LONG *lpcbData);
  STDAPI AVIFileEndRecord (PAVIFILE pfile);
  STDAPI_(ULONG) AVIStreamAddRef (PAVISTREAM pavi);
  STDAPI_(ULONG) AVIStreamRelease (PAVISTREAM pavi);
  STDAPI AVIStreamInfoW (PAVISTREAM pavi,LPAVISTREAMINFOW psi,LONG lSize);
  STDAPI AVIStreamInfoA (PAVISTREAM pavi,LPAVISTREAMINFOA psi,LONG lSize);
  STDAPI_(LONG) AVIStreamFindSample(PAVISTREAM pavi,LONG lPos,LONG lFlags);
  STDAPI AVIStreamReadFormat (PAVISTREAM pavi,LONG lPos,LPVOID lpFormat,LONG *lpcbFormat);
  STDAPI AVIStreamSetFormat (PAVISTREAM pavi,LONG lPos,LPVOID lpFormat,LONG cbFormat);
  STDAPI AVIStreamReadData (PAVISTREAM pavi,DWORD fcc,LPVOID lp,LONG *lpcb);
  STDAPI AVIStreamWriteData (PAVISTREAM pavi,DWORD fcc,LPVOID lp,LONG cb);
  STDAPI AVIStreamRead (PAVISTREAM pavi,LONG lStart,LONG lSamples,LPVOID lpBuffer,LONG cbBuffer,LONG *plBytes,LONG *plSamples);
#define AVISTREAMREAD_CONVENIENT (__MSABI_LONG(-1))
  STDAPI AVIStreamWrite (PAVISTREAM pavi,LONG lStart,LONG lSamples,LPVOID lpBuffer,LONG cbBuffer,DWORD dwFlags,LONG *plSampWritten,LONG *plBytesWritten);
  STDAPI_(LONG) AVIStreamStart (PAVISTREAM pavi);
  STDAPI_(LONG) AVIStreamLength (PAVISTREAM pavi);
  STDAPI_(LONG) AVIStreamTimeToSample (PAVISTREAM pavi,LONG lTime);
  STDAPI_(LONG) AVIStreamSampleToTime (PAVISTREAM pavi,LONG lSample);
  STDAPI AVIStreamBeginStreaming(PAVISTREAM pavi,LONG lStart,LONG lEnd,LONG lRate);
  STDAPI AVIStreamEndStreaming(PAVISTREAM pavi);
  STDAPI_(PGETFRAME) AVIStreamGetFrameOpen(PAVISTREAM pavi,LPBITMAPINFOHEADER lpbiWanted);
  STDAPI_(LPVOID) AVIStreamGetFrame(PGETFRAME pg,LONG lPos);
  STDAPI AVIStreamGetFrameClose(PGETFRAME pg);
  STDAPI AVIStreamOpenFromFileA(PAVISTREAM *ppavi,LPCSTR szFile,DWORD fccType,LONG lParam,UINT mode,CLSID *pclsidHandler);
  STDAPI AVIStreamOpenFromFileW(PAVISTREAM *ppavi,LPCWSTR szFile,DWORD fccType,LONG lParam,UINT mode,CLSID *pclsidHandler);
  STDAPI AVIStreamCreate(PAVISTREAM *ppavi,LONG lParam1,LONG lParam2,CLSID *pclsidHandler);

#define FIND_DIR __MSABI_LONG(0x0000000F)
#define FIND_NEXT __MSABI_LONG(0x00000001)
#define FIND_PREV __MSABI_LONG(0x00000004)
#define FIND_FROM_START __MSABI_LONG(0x00000008)

#define FIND_TYPE __MSABI_LONG(0x000000F0)
#define FIND_KEY __MSABI_LONG(0x00000010)
#define FIND_ANY __MSABI_LONG(0x00000020)
#define FIND_FORMAT __MSABI_LONG(0x00000040)

#define FIND_RET __MSABI_LONG(0x0000F000)
#define FIND_POS __MSABI_LONG(0x00000000)
#define FIND_LENGTH __MSABI_LONG(0x00001000)
#define FIND_OFFSET __MSABI_LONG(0x00002000)
#define FIND_SIZE __MSABI_LONG(0x00003000)
#define FIND_INDEX __MSABI_LONG(0x00004000)

#define AVIStreamFindKeyFrame AVIStreamFindSample
#define FindKeyFrame FindSample

#define AVIStreamClose AVIStreamRelease
#define AVIFileClose AVIFileRelease
#define AVIStreamInit AVIFileInit
#define AVIStreamExit AVIFileExit

#define SEARCH_NEAREST FIND_PREV
#define SEARCH_BACKWARD FIND_PREV
#define SEARCH_FORWARD FIND_NEXT
#define SEARCH_KEY FIND_KEY
#define SEARCH_ANY FIND_ANY

#define AVIStreamSampleToSample(pavi1,pavi2,l) AVIStreamTimeToSample(pavi1,AVIStreamSampleToTime(pavi2,l))
#define AVIStreamNextSample(pavi,l) AVIStreamFindSample(pavi,l+1,FIND_NEXT|FIND_ANY)
#define AVIStreamPrevSample(pavi,l) AVIStreamFindSample(pavi,l-1,FIND_PREV|FIND_ANY)
#define AVIStreamNearestSample(pavi,l) AVIStreamFindSample(pavi,l,FIND_PREV|FIND_ANY)
#define AVIStreamNextKeyFrame(pavi,l) AVIStreamFindSample(pavi,l+1,FIND_NEXT|FIND_KEY)
#define AVIStreamPrevKeyFrame(pavi,l) AVIStreamFindSample(pavi,l-1,FIND_PREV|FIND_KEY)
#define AVIStreamNearestKeyFrame(pavi,l) AVIStreamFindSample(pavi,l,FIND_PREV|FIND_KEY)
#define AVIStreamIsKeyFrame(pavi,l) (AVIStreamNearestKeyFrame(pavi,l)==l)
#define AVIStreamPrevSampleTime(pavi,t) AVIStreamSampleToTime(pavi,AVIStreamPrevSample(pavi,AVIStreamTimeToSample(pavi,t)))
#define AVIStreamNextSampleTime(pavi,t) AVIStreamSampleToTime(pavi,AVIStreamNextSample(pavi,AVIStreamTimeToSample(pavi,t)))
#define AVIStreamNearestSampleTime(pavi,t) AVIStreamSampleToTime(pavi,AVIStreamNearestSample(pavi,AVIStreamTimeToSample(pavi,t)))
#define AVIStreamNextKeyFrameTime(pavi,t) AVIStreamSampleToTime(pavi,AVIStreamNextKeyFrame(pavi,AVIStreamTimeToSample(pavi,t)))
#define AVIStreamPrevKeyFrameTime(pavi,t) AVIStreamSampleToTime(pavi,AVIStreamPrevKeyFrame(pavi,AVIStreamTimeToSample(pavi,t)))
#define AVIStreamNearestKeyFrameTime(pavi,t) AVIStreamSampleToTime(pavi,AVIStreamNearestKeyFrame(pavi,AVIStreamTimeToSample(pavi,t)))
#define AVIStreamStartTime(pavi) AVIStreamSampleToTime(pavi,AVIStreamStart(pavi))
#define AVIStreamLengthTime(pavi) AVIStreamSampleToTime(pavi,AVIStreamLength(pavi))
#define AVIStreamEnd(pavi) (AVIStreamStart(pavi) + AVIStreamLength(pavi))
#define AVIStreamEndTime(pavi) AVIStreamSampleToTime(pavi,AVIStreamEnd(pavi))
#define AVIStreamSampleSize(pavi,lPos,plSize) AVIStreamRead(pavi,lPos,1,NULL,(LONG)0,plSize,NULL)
#define AVIStreamFormatSize(pavi,lPos,plSize) AVIStreamReadFormat(pavi,lPos,NULL,plSize)
#define AVIStreamDataSize(pavi,fcc,plSize) AVIStreamReadData(pavi,fcc,NULL,plSize)

#define AVStreamNextKeyFrame(pavi,pos) AVIStreamFindSample(pavi, pos + 1, FIND_NEXT | FIND_KEY)
#define AVStreamPrevKeyFrame(pavi,pos) AVIStreamFindSample(pavi, pos - 1, FIND_NEXT | FIND_KEY)

#ifndef comptypeDIB
#define comptypeDIB mmioFOURCC('D','I','B',' ')
#endif

#define AVISave __MINGW_NAME_AW(AVISave)
#define AVISaveV __MINGW_NAME_AW(AVISaveV)
#define AVIBuildFilter __MINGW_NAME_AW(AVIBuildFilter)
#define EditStreamSetInfo __MINGW_NAME_AW(EditStreamSetInfo)
#define EditStreamSetName __MINGW_NAME_AW(EditStreamSetName)

  STDAPI AVIMakeCompressedStream(PAVISTREAM *ppsCompressed,PAVISTREAM ppsSource,AVICOMPRESSOPTIONS *lpOptions,CLSID *pclsidHandler);
  EXTERN_C HRESULT CDECL AVISaveA (LPCSTR szFile,CLSID *pclsidHandler,AVISAVECALLBACK lpfnCallback,int nStreams,PAVISTREAM pfile,LPAVICOMPRESSOPTIONS lpOptions,...);
  STDAPI AVISaveVA(LPCSTR szFile,CLSID *pclsidHandler,AVISAVECALLBACK lpfnCallback,int nStreams,PAVISTREAM *ppavi,LPAVICOMPRESSOPTIONS *plpOptions);
  EXTERN_C HRESULT CDECL AVISaveW (LPCWSTR szFile,CLSID *pclsidHandler,AVISAVECALLBACK lpfnCallback,int nStreams,PAVISTREAM pfile,LPAVICOMPRESSOPTIONS lpOptions,...);
  STDAPI AVISaveVW(LPCWSTR szFile,CLSID *pclsidHandler,AVISAVECALLBACK lpfnCallback,int nStreams,PAVISTREAM *ppavi,LPAVICOMPRESSOPTIONS *plpOptions);
  STDAPI_(INT_PTR) AVISaveOptions(HWND hwnd,UINT uiFlags,int nStreams,PAVISTREAM *ppavi,LPAVICOMPRESSOPTIONS *plpOptions);
  STDAPI AVISaveOptionsFree(int nStreams,LPAVICOMPRESSOPTIONS *plpOptions);
  STDAPI AVIBuildFilterW(LPWSTR lpszFilter,LONG cbFilter,WINBOOL fSaving);
  STDAPI AVIBuildFilterA(LPSTR lpszFilter,LONG cbFilter,WINBOOL fSaving);
  STDAPI AVIMakeFileFromStreams(PAVIFILE *ppfile,int nStreams,PAVISTREAM *papStreams);
  STDAPI AVIMakeStreamFromClipboard(UINT cfFormat,HANDLE hGlobal,PAVISTREAM *ppstream);
  STDAPI AVIPutFileOnClipboard(PAVIFILE pf);
  STDAPI AVIGetFromClipboard(PAVIFILE *lppf);
  STDAPI AVIClearClipboard(void);
  STDAPI CreateEditableStream(PAVISTREAM *ppsEditable,PAVISTREAM psSource);
  STDAPI EditStreamCut(PAVISTREAM pavi,LONG *plStart,LONG *plLength,PAVISTREAM *ppResult);
  STDAPI EditStreamCopy(PAVISTREAM pavi,LONG *plStart,LONG *plLength,PAVISTREAM *ppResult);
  STDAPI EditStreamPaste(PAVISTREAM pavi,LONG *plPos,LONG *plLength,PAVISTREAM pstream,LONG lStart,LONG lEnd);
  STDAPI EditStreamClone(PAVISTREAM pavi,PAVISTREAM *ppResult);
  STDAPI EditStreamSetNameA(PAVISTREAM pavi,LPCSTR lpszName);
  STDAPI EditStreamSetNameW(PAVISTREAM pavi,LPCWSTR lpszName);
  STDAPI EditStreamSetInfoW(PAVISTREAM pavi,LPAVISTREAMINFOW lpInfo,LONG cbInfo);
  STDAPI EditStreamSetInfoA(PAVISTREAM pavi,LPAVISTREAMINFOA lpInfo,LONG cbInfo);

#ifndef AVIERR_OK
#define AVIERR_OK __MSABI_LONG(0)

#define MAKE_AVIERR(error) MAKE_SCODE(SEVERITY_ERROR,FACILITY_ITF,0x4000 + error)

#define AVIERR_UNSUPPORTED MAKE_AVIERR(101)
#define AVIERR_BADFORMAT MAKE_AVIERR(102)
#define AVIERR_MEMORY MAKE_AVIERR(103)
#define AVIERR_INTERNAL MAKE_AVIERR(104)
#define AVIERR_BADFLAGS MAKE_AVIERR(105)
#define AVIERR_BADPARAM MAKE_AVIERR(106)
#define AVIERR_BADSIZE MAKE_AVIERR(107)
#define AVIERR_BADHANDLE MAKE_AVIERR(108)
#define AVIERR_FILEREAD MAKE_AVIERR(109)
#define AVIERR_FILEWRITE MAKE_AVIERR(110)
#define AVIERR_FILEOPEN MAKE_AVIERR(111)
#define AVIERR_COMPRESSOR MAKE_AVIERR(112)
#define AVIERR_NOCOMPRESSOR MAKE_AVIERR(113)
#define AVIERR_READONLY MAKE_AVIERR(114)
#define AVIERR_NODATA MAKE_AVIERR(115)
#define AVIERR_BUFFERTOOSMALL MAKE_AVIERR(116)
#define AVIERR_CANTCOMPRESS MAKE_AVIERR(117)
#define AVIERR_USERABORT MAKE_AVIERR(198)
#define AVIERR_ERROR MAKE_AVIERR(199)
#endif
#endif

#ifndef NOMCIWND

#ifdef __cplusplus
#define MCIWndSM ::SendMessage
#else
#define MCIWndSM SendMessage
#endif

#define MCIWND_WINDOW_CLASS TEXT("MCIWndClass")

#define MCIWndCreate __MINGW_NAME_AW(MCIWndCreate)

  HWND WINAPIV MCIWndCreateA(HWND hwndParent,HINSTANCE hInstance,DWORD dwStyle,LPCSTR szFile);
  HWND WINAPIV MCIWndCreateW(HWND hwndParent,HINSTANCE hInstance,DWORD dwStyle,LPCWSTR szFile);
  WINBOOL WINAPIV MCIWndRegisterClass(void);

#define MCIWNDOPENF_NEW 0x0001

#define MCIWNDF_NOAUTOSIZEWINDOW 0x0001
#define MCIWNDF_NOPLAYBAR 0x0002
#define MCIWNDF_NOAUTOSIZEMOVIE 0x0004
#define MCIWNDF_NOMENU 0x0008
#define MCIWNDF_SHOWNAME 0x0010
#define MCIWNDF_SHOWPOS 0x0020
#define MCIWNDF_SHOWMODE 0x0040
#define MCIWNDF_SHOWALL 0x0070

#define MCIWNDF_NOTIFYMODE 0x0100
#define MCIWNDF_NOTIFYPOS 0x0200
#define MCIWNDF_NOTIFYSIZE 0x0400
#define MCIWNDF_NOTIFYERROR 0x1000
#define MCIWNDF_NOTIFYALL 0x1F00

#define MCIWNDF_NOTIFYANSI 0x0080

#define MCIWNDF_NOTIFYMEDIAA 0x0880
#define MCIWNDF_NOTIFYMEDIAW 0x0800

#define MCIWNDF_NOTIFYMEDIA __MINGW_NAME_AW(MCIWNDF_NOTIFYMEDIA)

#define MCIWNDF_RECORD 0x2000
#define MCIWNDF_NOERRORDLG 0x4000
#define MCIWNDF_NOOPEN 0x8000

#define MCIWndCanPlay(hwnd) (WINBOOL)MCIWndSM(hwnd,MCIWNDM_CAN_PLAY,(WPARAM)0,(LPARAM)0)
#define MCIWndCanRecord(hwnd) (WINBOOL)MCIWndSM(hwnd,MCIWNDM_CAN_RECORD,(WPARAM)0,(LPARAM)0)
#define MCIWndCanSave(hwnd) (WINBOOL)MCIWndSM(hwnd,MCIWNDM_CAN_SAVE,(WPARAM)0,(LPARAM)0)
#define MCIWndCanWindow(hwnd) (WINBOOL)MCIWndSM(hwnd,MCIWNDM_CAN_WINDOW,(WPARAM)0,(LPARAM)0)
#define MCIWndCanEject(hwnd) (WINBOOL)MCIWndSM(hwnd,MCIWNDM_CAN_EJECT,(WPARAM)0,(LPARAM)0)
#define MCIWndCanConfig(hwnd) (WINBOOL)MCIWndSM(hwnd,MCIWNDM_CAN_CONFIG,(WPARAM)0,(LPARAM)0)
#define MCIWndPaletteKick(hwnd) (WINBOOL)MCIWndSM(hwnd,MCIWNDM_PALETTEKICK,(WPARAM)0,(LPARAM)0)

#define MCIWndSave(hwnd,szFile) (LONG)MCIWndSM(hwnd,MCI_SAVE,(WPARAM)0,(LPARAM)(LPVOID)(szFile))
#define MCIWndSaveDialog(hwnd) MCIWndSave(hwnd,-1)

#define MCIWndNew(hwnd,lp) (LONG)MCIWndSM(hwnd,MCIWNDM_NEW,(WPARAM)0,(LPARAM)(LPVOID)(lp))

#define MCIWndRecord(hwnd) (LONG)MCIWndSM(hwnd,MCI_RECORD,(WPARAM)0,(LPARAM)0)
#define MCIWndOpen(hwnd,sz,f) (LONG)MCIWndSM(hwnd,MCIWNDM_OPEN,(WPARAM)(UINT)(f),(LPARAM)(LPVOID)(sz))
#define MCIWndOpenDialog(hwnd) MCIWndOpen(hwnd,-1,0)
#define MCIWndClose(hwnd) (LONG)MCIWndSM(hwnd,MCI_CLOSE,(WPARAM)0,(LPARAM)0)
#define MCIWndPlay(hwnd) (LONG)MCIWndSM(hwnd,MCI_PLAY,(WPARAM)0,(LPARAM)0)
#define MCIWndStop(hwnd) (LONG)MCIWndSM(hwnd,MCI_STOP,(WPARAM)0,(LPARAM)0)
#define MCIWndPause(hwnd) (LONG)MCIWndSM(hwnd,MCI_PAUSE,(WPARAM)0,(LPARAM)0)
#define MCIWndResume(hwnd) (LONG)MCIWndSM(hwnd,MCI_RESUME,(WPARAM)0,(LPARAM)0)
#define MCIWndSeek(hwnd,lPos) (LONG)MCIWndSM(hwnd,MCI_SEEK,(WPARAM)0,(LPARAM)(LONG)(lPos))
#define MCIWndEject(hwnd) (LONG)MCIWndSM(hwnd,MCIWNDM_EJECT,(WPARAM)0,(LPARAM)0)

#define MCIWndHome(hwnd) MCIWndSeek(hwnd,MCIWND_START)
#define MCIWndEnd(hwnd) MCIWndSeek(hwnd,MCIWND_END)

#define MCIWndGetSource(hwnd,prc) (LONG)MCIWndSM(hwnd,MCIWNDM_GET_SOURCE,(WPARAM)0,(LPARAM)(LPRECT)(prc))
#define MCIWndPutSource(hwnd,prc) (LONG)MCIWndSM(hwnd,MCIWNDM_PUT_SOURCE,(WPARAM)0,(LPARAM)(LPRECT)(prc))

#define MCIWndGetDest(hwnd,prc) (LONG)MCIWndSM(hwnd,MCIWNDM_GET_DEST,(WPARAM)0,(LPARAM)(LPRECT)(prc))
#define MCIWndPutDest(hwnd,prc) (LONG)MCIWndSM(hwnd,MCIWNDM_PUT_DEST,(WPARAM)0,(LPARAM)(LPRECT)(prc))

#define MCIWndPlayReverse(hwnd) (LONG)MCIWndSM(hwnd,MCIWNDM_PLAYREVERSE,(WPARAM)0,(LPARAM)0)
#define MCIWndPlayFrom(hwnd,lPos) (LONG)MCIWndSM(hwnd,MCIWNDM_PLAYFROM,(WPARAM)0,(LPARAM)(LONG)(lPos))
#define MCIWndPlayTo(hwnd,lPos) (LONG)MCIWndSM(hwnd,MCIWNDM_PLAYTO,(WPARAM)0,(LPARAM)(LONG)(lPos))
#define MCIWndPlayFromTo(hwnd,lStart,lEnd) (MCIWndSeek(hwnd,lStart),MCIWndPlayTo(hwnd,lEnd))

#define MCIWndGetDeviceID(hwnd) (UINT)MCIWndSM(hwnd,MCIWNDM_GETDEVICEID,(WPARAM)0,(LPARAM)0)
#define MCIWndGetAlias(hwnd) (UINT)MCIWndSM(hwnd,MCIWNDM_GETALIAS,(WPARAM)0,(LPARAM)0)
#define MCIWndGetMode(hwnd,lp,len) (LONG)MCIWndSM(hwnd,MCIWNDM_GETMODE,(WPARAM)(UINT)(len),(LPARAM)(LPTSTR)(lp))
#define MCIWndGetPosition(hwnd) (LONG)MCIWndSM(hwnd,MCIWNDM_GETPOSITION,(WPARAM)0,(LPARAM)0)
#define MCIWndGetPositionString(hwnd,lp,len) (LONG)MCIWndSM(hwnd,MCIWNDM_GETPOSITION,(WPARAM)(UINT)(len),(LPARAM)(LPTSTR)(lp))
#define MCIWndGetStart(hwnd) (LONG)MCIWndSM(hwnd,MCIWNDM_GETSTART,(WPARAM)0,(LPARAM)0)
#define MCIWndGetLength(hwnd) (LONG)MCIWndSM(hwnd,MCIWNDM_GETLENGTH,(WPARAM)0,(LPARAM)0)
#define MCIWndGetEnd(hwnd) (LONG)MCIWndSM(hwnd,MCIWNDM_GETEND,(WPARAM)0,(LPARAM)0)

#define MCIWndStep(hwnd,n) (LONG)MCIWndSM(hwnd,MCI_STEP,(WPARAM)0,(LPARAM)(__LONG32)(n))

#define MCIWndDestroy(hwnd) (VOID)MCIWndSM(hwnd,WM_CLOSE,(WPARAM)0,(LPARAM)0)
#define MCIWndSetZoom(hwnd,iZoom) (VOID)MCIWndSM(hwnd,MCIWNDM_SETZOOM,(WPARAM)0,(LPARAM)(UINT)(iZoom))
#define MCIWndGetZoom(hwnd) (UINT)MCIWndSM(hwnd,MCIWNDM_GETZOOM,(WPARAM)0,(LPARAM)0)
#define MCIWndSetVolume(hwnd,iVol) (LONG)MCIWndSM(hwnd,MCIWNDM_SETVOLUME,(WPARAM)0,(LPARAM)(UINT)(iVol))
#define MCIWndGetVolume(hwnd) (LONG)MCIWndSM(hwnd,MCIWNDM_GETVOLUME,(WPARAM)0,(LPARAM)0)
#define MCIWndSetSpeed(hwnd,iSpeed) (LONG)MCIWndSM(hwnd,MCIWNDM_SETSPEED,(WPARAM)0,(LPARAM)(UINT)(iSpeed))
#define MCIWndGetSpeed(hwnd) (LONG)MCIWndSM(hwnd,MCIWNDM_GETSPEED,(WPARAM)0,(LPARAM)0)
#define MCIWndSetTimeFormat(hwnd,lp) (LONG)MCIWndSM(hwnd,MCIWNDM_SETTIMEFORMAT,(WPARAM)0,(LPARAM)(LPTSTR)(lp))
#define MCIWndGetTimeFormat(hwnd,lp,len) (LONG)MCIWndSM(hwnd,MCIWNDM_GETTIMEFORMAT,(WPARAM)(UINT)(len),(LPARAM)(LPTSTR)(lp))
#define MCIWndValidateMedia(hwnd) (VOID)MCIWndSM(hwnd,MCIWNDM_VALIDATEMEDIA,(WPARAM)0,(LPARAM)0)

#define MCIWndSetRepeat(hwnd,f) (void)MCIWndSM(hwnd,MCIWNDM_SETREPEAT,(WPARAM)0,(LPARAM)(WINBOOL)(f))
#define MCIWndGetRepeat(hwnd) (WINBOOL)MCIWndSM(hwnd,MCIWNDM_GETREPEAT,(WPARAM)0,(LPARAM)0)

#define MCIWndUseFrames(hwnd) MCIWndSetTimeFormat(hwnd,TEXT("frames"))
#define MCIWndUseTime(hwnd) MCIWndSetTimeFormat(hwnd,TEXT("ms"))

#define MCIWndSetActiveTimer(hwnd,active) (VOID)MCIWndSM(hwnd,MCIWNDM_SETACTIVETIMER,(WPARAM)(UINT)(active),(LPARAM)0)
#define MCIWndSetInactiveTimer(hwnd,inactive) (VOID)MCIWndSM(hwnd,MCIWNDM_SETINACTIVETIMER,(WPARAM)(UINT)(inactive),(LPARAM)0)
#define MCIWndSetTimers(hwnd,active,inactive) (VOID)MCIWndSM(hwnd,MCIWNDM_SETTIMERS,(WPARAM)(UINT)(active),(LPARAM)(UINT)(inactive))
#define MCIWndGetActiveTimer(hwnd) (UINT)MCIWndSM(hwnd,MCIWNDM_GETACTIVETIMER,(WPARAM)0,(LPARAM)0);
#define MCIWndGetInactiveTimer(hwnd) (UINT)MCIWndSM(hwnd,MCIWNDM_GETINACTIVETIMER,(WPARAM)0,(LPARAM)0);

#define MCIWndRealize(hwnd,fBkgnd) (LONG)MCIWndSM(hwnd,MCIWNDM_REALIZE,(WPARAM)(WINBOOL)(fBkgnd),(LPARAM)0)

#define MCIWndSendString(hwnd,sz) (LONG)MCIWndSM(hwnd,MCIWNDM_SENDSTRING,(WPARAM)0,(LPARAM)(LPTSTR)(sz))
#define MCIWndReturnString(hwnd,lp,len) (LONG)MCIWndSM(hwnd,MCIWNDM_RETURNSTRING,(WPARAM)(UINT)(len),(LPARAM)(LPVOID)(lp))
#define MCIWndGetError(hwnd,lp,len) (LONG)MCIWndSM(hwnd,MCIWNDM_GETERROR,(WPARAM)(UINT)(len),(LPARAM)(LPVOID)(lp))

#define MCIWndGetPalette(hwnd) (HPALETTE)MCIWndSM(hwnd,MCIWNDM_GETPALETTE,(WPARAM)0,(LPARAM)0)
#define MCIWndSetPalette(hwnd,hpal) (LONG)MCIWndSM(hwnd,MCIWNDM_SETPALETTE,(WPARAM)(HPALETTE)(hpal),(LPARAM)0)

#define MCIWndGetFileName(hwnd,lp,len) (LONG)MCIWndSM(hwnd,MCIWNDM_GETFILENAME,(WPARAM)(UINT)(len),(LPARAM)(LPVOID)(lp))
#define MCIWndGetDevice(hwnd,lp,len) (LONG)MCIWndSM(hwnd,MCIWNDM_GETDEVICE,(WPARAM)(UINT)(len),(LPARAM)(LPVOID)(lp))

#define MCIWndGetStyles(hwnd) (UINT)MCIWndSM(hwnd,MCIWNDM_GETSTYLES,(WPARAM)0,(LPARAM)0)
#define MCIWndChangeStyles(hwnd,mask,value) (LONG)MCIWndSM(hwnd,MCIWNDM_CHANGESTYLES,(WPARAM)(UINT)(mask),(LPARAM)(LONG)(value))

#define MCIWndOpenInterface(hwnd,pUnk) (LONG)MCIWndSM(hwnd,MCIWNDM_OPENINTERFACE,(WPARAM)0,(LPARAM)(LPUNKNOWN)(pUnk))

#define MCIWndSetOwner(hwnd,hwndP) (LONG)MCIWndSM(hwnd,MCIWNDM_SETOWNER,(WPARAM)(hwndP),(LPARAM)0)

#define MCIWNDM_GETDEVICEID (WM_USER + 100)
#define MCIWNDM_GETSTART (WM_USER + 103)
#define MCIWNDM_GETLENGTH (WM_USER + 104)
#define MCIWNDM_GETEND (WM_USER + 105)
#define MCIWNDM_EJECT (WM_USER + 107)
#define MCIWNDM_SETZOOM (WM_USER + 108)
#define MCIWNDM_GETZOOM (WM_USER + 109)
#define MCIWNDM_SETVOLUME (WM_USER + 110)
#define MCIWNDM_GETVOLUME (WM_USER + 111)
#define MCIWNDM_SETSPEED (WM_USER + 112)
#define MCIWNDM_GETSPEED (WM_USER + 113)
#define MCIWNDM_SETREPEAT (WM_USER + 114)
#define MCIWNDM_GETREPEAT (WM_USER + 115)
#define MCIWNDM_REALIZE (WM_USER + 118)
#define MCIWNDM_VALIDATEMEDIA (WM_USER + 121)
#define MCIWNDM_PLAYFROM (WM_USER + 122)
#define MCIWNDM_PLAYTO (WM_USER + 123)
#define MCIWNDM_GETPALETTE (WM_USER + 126)
#define MCIWNDM_SETPALETTE (WM_USER + 127)
#define MCIWNDM_SETTIMERS (WM_USER + 129)
#define MCIWNDM_SETACTIVETIMER (WM_USER + 130)
#define MCIWNDM_SETINACTIVETIMER (WM_USER + 131)
#define MCIWNDM_GETACTIVETIMER (WM_USER + 132)
#define MCIWNDM_GETINACTIVETIMER (WM_USER + 133)
#define MCIWNDM_CHANGESTYLES (WM_USER + 135)
#define MCIWNDM_GETSTYLES (WM_USER + 136)
#define MCIWNDM_GETALIAS (WM_USER + 137)
#define MCIWNDM_PLAYREVERSE (WM_USER + 139)
#define MCIWNDM_GET_SOURCE (WM_USER + 140)
#define MCIWNDM_PUT_SOURCE (WM_USER + 141)
#define MCIWNDM_GET_DEST (WM_USER + 142)
#define MCIWNDM_PUT_DEST (WM_USER + 143)
#define MCIWNDM_CAN_PLAY (WM_USER + 144)
#define MCIWNDM_CAN_WINDOW (WM_USER + 145)
#define MCIWNDM_CAN_RECORD (WM_USER + 146)
#define MCIWNDM_CAN_SAVE (WM_USER + 147)
#define MCIWNDM_CAN_EJECT (WM_USER + 148)
#define MCIWNDM_CAN_CONFIG (WM_USER + 149)
#define MCIWNDM_PALETTEKICK (WM_USER + 150)
#define MCIWNDM_OPENINTERFACE (WM_USER + 151)
#define MCIWNDM_SETOWNER (WM_USER + 152)

#define MCIWNDM_SENDSTRINGA (WM_USER + 101)
#define MCIWNDM_GETPOSITIONA (WM_USER + 102)
#define MCIWNDM_GETMODEA (WM_USER + 106)
#define MCIWNDM_SETTIMEFORMATA (WM_USER + 119)
#define MCIWNDM_GETTIMEFORMATA (WM_USER + 120)
#define MCIWNDM_GETFILENAMEA (WM_USER + 124)
#define MCIWNDM_GETDEVICEA (WM_USER + 125)
#define MCIWNDM_GETERRORA (WM_USER + 128)
#define MCIWNDM_NEWA (WM_USER + 134)
#define MCIWNDM_RETURNSTRINGA (WM_USER + 138)
#define MCIWNDM_OPENA (WM_USER + 153)

#define MCIWNDM_SENDSTRINGW (WM_USER + 201)
#define MCIWNDM_GETPOSITIONW (WM_USER + 202)
#define MCIWNDM_GETMODEW (WM_USER + 206)
#define MCIWNDM_SETTIMEFORMATW (WM_USER + 219)
#define MCIWNDM_GETTIMEFORMATW (WM_USER + 220)
#define MCIWNDM_GETFILENAMEW (WM_USER + 224)
#define MCIWNDM_GETDEVICEW (WM_USER + 225)
#define MCIWNDM_GETERRORW (WM_USER + 228)
#define MCIWNDM_NEWW (WM_USER + 234)
#define MCIWNDM_RETURNSTRINGW (WM_USER + 238)
#define MCIWNDM_OPENW (WM_USER + 252)

#define MCIWNDM_SENDSTRING __MINGW_NAME_AW(MCIWNDM_SENDSTRING)
#define MCIWNDM_GETPOSITION __MINGW_NAME_AW(MCIWNDM_GETPOSITION)
#define MCIWNDM_GETMODE __MINGW_NAME_AW(MCIWNDM_GETMODE)
#define MCIWNDM_SETTIMEFORMAT __MINGW_NAME_AW(MCIWNDM_SETTIMEFORMAT)
#define MCIWNDM_GETTIMEFORMAT __MINGW_NAME_AW(MCIWNDM_GETTIMEFORMAT)
#define MCIWNDM_GETFILENAME __MINGW_NAME_AW(MCIWNDM_GETFILENAME)
#define MCIWNDM_GETDEVICE __MINGW_NAME_AW(MCIWNDM_GETDEVICE)
#define MCIWNDM_GETERROR __MINGW_NAME_AW(MCIWNDM_GETERROR)
#define MCIWNDM_NEW __MINGW_NAME_AW(MCIWNDM_NEW)
#define MCIWNDM_RETURNSTRING __MINGW_NAME_AW(MCIWNDM_RETURNSTRING)
#define MCIWNDM_OPEN __MINGW_NAME_AW(MCIWNDM_OPEN)

#define MCIWNDM_NOTIFYMODE (WM_USER + 200)
#define MCIWNDM_NOTIFYPOS (WM_USER + 201)
#define MCIWNDM_NOTIFYSIZE (WM_USER + 202)
#define MCIWNDM_NOTIFYMEDIA (WM_USER + 203)
#define MCIWNDM_NOTIFYERROR (WM_USER + 205)

#define MCIWND_START -1
#define MCIWND_END -2

#ifndef MCI_PLAY
#define MCI_CLOSE 0x0804
#define MCI_PLAY 0x0806
#define MCI_SEEK 0x0807
#define MCI_STOP 0x0808
#define MCI_PAUSE 0x0809
#define MCI_STEP 0x080E
#define MCI_RECORD 0x080F
#define MCI_SAVE 0x0813
#define MCI_CUT 0x0851
#define MCI_COPY 0x0852
#define MCI_PASTE 0x0853
#define MCI_RESUME 0x0855
#define MCI_DELETE 0x0856
#endif

#ifndef MCI_MODE_NOT_READY

#define MCI_MODE_NOT_READY (524)
#define MCI_MODE_STOP (525)
#define MCI_MODE_PLAY (526)
#define MCI_MODE_RECORD (527)
#define MCI_MODE_SEEK (528)
#define MCI_MODE_PAUSE (529)
#define MCI_MODE_OPEN (530)
#endif
#endif

#if !defined(NOAVICAP) || !defined(NOVIDEO)

#ifndef _RCINVOKED

  DECLARE_HANDLE(HVIDEO);
  typedef HVIDEO *LPHVIDEO;
#endif

  DWORD WINAPI VideoForWindowsVersion(void);

#define DV_ERR_OK (0)
#define DV_ERR_BASE (1)
#define DV_ERR_NONSPECIFIC (DV_ERR_BASE)
#define DV_ERR_BADFORMAT (DV_ERR_BASE + 1)

#define DV_ERR_STILLPLAYING (DV_ERR_BASE + 2)

#define DV_ERR_UNPREPARED (DV_ERR_BASE + 3)

#define DV_ERR_SYNC (DV_ERR_BASE + 4)

#define DV_ERR_TOOMANYCHANNELS (DV_ERR_BASE + 5)

#define DV_ERR_NOTDETECTED (DV_ERR_BASE + 6)
#define DV_ERR_BADINSTALL (DV_ERR_BASE + 7)
#define DV_ERR_CREATEPALETTE (DV_ERR_BASE + 8)
#define DV_ERR_SIZEFIELD (DV_ERR_BASE + 9)
#define DV_ERR_PARAM1 (DV_ERR_BASE + 10)
#define DV_ERR_PARAM2 (DV_ERR_BASE + 11)
#define DV_ERR_CONFIG1 (DV_ERR_BASE + 12)
#define DV_ERR_CONFIG2 (DV_ERR_BASE + 13)
#define DV_ERR_FLAGS (DV_ERR_BASE + 14)
#define DV_ERR_13 (DV_ERR_BASE + 15)

#define DV_ERR_NOTSUPPORTED (DV_ERR_BASE + 16)
#define DV_ERR_NOMEM (DV_ERR_BASE + 17)
#define DV_ERR_ALLOCATED (DV_ERR_BASE + 18)
#define DV_ERR_BADDEVICEID (DV_ERR_BASE + 19)
#define DV_ERR_INVALHANDLE (DV_ERR_BASE + 20)
#define DV_ERR_BADERRNUM (DV_ERR_BASE + 21)
#define DV_ERR_NO_BUFFERS (DV_ERR_BASE + 22)

#define DV_ERR_MEM_CONFLICT (DV_ERR_BASE + 23)
#define DV_ERR_IO_CONFLICT (DV_ERR_BASE + 24)
#define DV_ERR_DMA_CONFLICT (DV_ERR_BASE + 25)
#define DV_ERR_INT_CONFLICT (DV_ERR_BASE + 26)
#define DV_ERR_PROTECT_ONLY (DV_ERR_BASE + 27)
#define DV_ERR_LASTERROR (DV_ERR_BASE + 27)

#define DV_ERR_USER_MSG (DV_ERR_BASE + 1000)

#ifndef _RCINVOKED

#ifndef MM_DRVM_OPEN
#define MM_DRVM_OPEN 0x3D0
#define MM_DRVM_CLOSE 0x3D1
#define MM_DRVM_DATA 0x3D2
#define MM_DRVM_ERROR 0x3D3
#endif

#define DV_VM_OPEN MM_DRVM_OPEN
#define DV_VM_CLOSE MM_DRVM_CLOSE
#define DV_VM_DATA MM_DRVM_DATA
#define DV_VM_ERROR MM_DRVM_ERROR

  typedef struct videohdr_tag {
    LPBYTE lpData;
    DWORD dwBufferLength;
    DWORD dwBytesUsed;
    DWORD dwTimeCaptured;
    DWORD_PTR dwUser;
    DWORD dwFlags;
    DWORD_PTR dwReserved[4];
  } VIDEOHDR, NEAR *PVIDEOHDR, FAR * LPVIDEOHDR;

#define VHDR_DONE 0x00000001
#define VHDR_PREPARED 0x00000002
#define VHDR_INQUEUE 0x00000004
#define VHDR_KEYFRAME 0x00000008
#define VHDR_VALID 0x0000000F

  typedef struct channel_caps_tag {
    DWORD dwFlags;
    DWORD dwSrcRectXMod;
    DWORD dwSrcRectYMod;
    DWORD dwSrcRectWidthMod;
    DWORD dwSrcRectHeightMod;
    DWORD dwDstRectXMod;
    DWORD dwDstRectYMod;
    DWORD dwDstRectWidthMod;
    DWORD dwDstRectHeightMod;
  } CHANNEL_CAPS,NEAR *PCHANNEL_CAPS,*LPCHANNEL_CAPS;

#define VCAPS_OVERLAY 0x00000001
#define VCAPS_SRC_CAN_CLIP 0x00000002
#define VCAPS_DST_CAN_CLIP 0x00000004
#define VCAPS_CAN_SCALE 0x00000008

#define VIDEO_EXTERNALIN 0x0001
#define VIDEO_EXTERNALOUT 0x0002
#define VIDEO_IN 0x0004
#define VIDEO_OUT 0x0008

#define VIDEO_DLG_QUERY 0x0010

#define VIDEO_CONFIGURE_QUERY 0x8000

#define VIDEO_CONFIGURE_SET 0x1000

#define VIDEO_CONFIGURE_GET 0x2000
#define VIDEO_CONFIGURE_QUERYSIZE 0x0001

#define VIDEO_CONFIGURE_CURRENT 0x0010
#define VIDEO_CONFIGURE_NOMINAL 0x0020
#define VIDEO_CONFIGURE_MIN 0x0040
#define VIDEO_CONFIGURE_MAX 0x0080

#define DVM_USER 0X4000

#define DVM_CONFIGURE_START 0x1000
#define DVM_CONFIGURE_END 0x1FFF

#define DVM_PALETTE (DVM_CONFIGURE_START + 1)
#define DVM_FORMAT (DVM_CONFIGURE_START + 2)
#define DVM_PALETTERGB555 (DVM_CONFIGURE_START + 3)
#define DVM_SRC_RECT (DVM_CONFIGURE_START + 4)
#define DVM_DST_RECT (DVM_CONFIGURE_START + 5)
#endif
#endif

#ifndef NOAVICAP
#ifdef __cplusplus

#define AVICapSM(hwnd,m,w,l) ((::IsWindow(hwnd)) ? ::SendMessage(hwnd,m,w,l) : 0)
#else

#define AVICapSM(hwnd,m,w,l) ((IsWindow(hwnd)) ? SendMessage(hwnd,m,w,l) : 0)
#endif

#ifndef RC_INVOKED

#define WM_CAP_START WM_USER

#define WM_CAP_UNICODE_START WM_USER+100

#define WM_CAP_GET_CAPSTREAMPTR (WM_CAP_START+ 1)

#define WM_CAP_SET_CALLBACK_ERRORW (WM_CAP_UNICODE_START+ 2)
#define WM_CAP_SET_CALLBACK_STATUSW (WM_CAP_UNICODE_START+ 3)
#define WM_CAP_SET_CALLBACK_ERRORA (WM_CAP_START+ 2)
#define WM_CAP_SET_CALLBACK_STATUSA (WM_CAP_START+ 3)

#define WM_CAP_SET_CALLBACK_ERROR __MINGW_NAME_AW(WM_CAP_SET_CALLBACK_ERROR)
#define WM_CAP_SET_CALLBACK_STATUS __MINGW_NAME_AW(WM_CAP_SET_CALLBACK_STATUS)

#define WM_CAP_SET_CALLBACK_YIELD (WM_CAP_START+ 4)
#define WM_CAP_SET_CALLBACK_FRAME (WM_CAP_START+ 5)
#define WM_CAP_SET_CALLBACK_VIDEOSTREAM (WM_CAP_START+ 6)
#define WM_CAP_SET_CALLBACK_WAVESTREAM (WM_CAP_START+ 7)
#define WM_CAP_GET_USER_DATA (WM_CAP_START+ 8)
#define WM_CAP_SET_USER_DATA (WM_CAP_START+ 9)

#define WM_CAP_DRIVER_CONNECT (WM_CAP_START+ 10)
#define WM_CAP_DRIVER_DISCONNECT (WM_CAP_START+ 11)

#define WM_CAP_DRIVER_GET_NAMEA (WM_CAP_START+ 12)
#define WM_CAP_DRIVER_GET_VERSIONA (WM_CAP_START+ 13)
#define WM_CAP_DRIVER_GET_NAMEW (WM_CAP_UNICODE_START+ 12)
#define WM_CAP_DRIVER_GET_VERSIONW (WM_CAP_UNICODE_START+ 13)

#define WM_CAP_DRIVER_GET_NAME __MINGW_NAME_AW(WM_CAP_DRIVER_GET_NAME)
#define WM_CAP_DRIVER_GET_VERSION __MINGW_NAME_AW(WM_CAP_DRIVER_GET_VERSION)

#define WM_CAP_DRIVER_GET_CAPS (WM_CAP_START+ 14)

#define WM_CAP_FILE_SET_CAPTURE_FILEA (WM_CAP_START+ 20)
#define WM_CAP_FILE_GET_CAPTURE_FILEA (WM_CAP_START+ 21)
#define WM_CAP_FILE_SAVEASA (WM_CAP_START+ 23)
#define WM_CAP_FILE_SAVEDIBA (WM_CAP_START+ 25)
#define WM_CAP_FILE_SET_CAPTURE_FILEW (WM_CAP_UNICODE_START+ 20)
#define WM_CAP_FILE_GET_CAPTURE_FILEW (WM_CAP_UNICODE_START+ 21)
#define WM_CAP_FILE_SAVEASW (WM_CAP_UNICODE_START+ 23)
#define WM_CAP_FILE_SAVEDIBW (WM_CAP_UNICODE_START+ 25)

#define WM_CAP_FILE_SET_CAPTURE_FILE __MINGW_NAME_AW(WM_CAP_FILE_SET_CAPTURE_FILE)
#define WM_CAP_FILE_GET_CAPTURE_FILE __MINGW_NAME_AW(WM_CAP_FILE_GET_CAPTURE_FILE)
#define WM_CAP_FILE_SAVEAS __MINGW_NAME_AW(WM_CAP_FILE_SAVEAS)
#define WM_CAP_FILE_SAVEDIB __MINGW_NAME_AW(WM_CAP_FILE_SAVEDIB)

#define WM_CAP_FILE_ALLOCATE (WM_CAP_START+ 22)
#define WM_CAP_FILE_SET_INFOCHUNK (WM_CAP_START+ 24)

#define WM_CAP_EDIT_COPY (WM_CAP_START+ 30)

#define WM_CAP_SET_AUDIOFORMAT (WM_CAP_START+ 35)
#define WM_CAP_GET_AUDIOFORMAT (WM_CAP_START+ 36)

#define WM_CAP_DLG_VIDEOFORMAT (WM_CAP_START+ 41)
#define WM_CAP_DLG_VIDEOSOURCE (WM_CAP_START+ 42)
#define WM_CAP_DLG_VIDEODISPLAY (WM_CAP_START+ 43)
#define WM_CAP_GET_VIDEOFORMAT (WM_CAP_START+ 44)
#define WM_CAP_SET_VIDEOFORMAT (WM_CAP_START+ 45)
#define WM_CAP_DLG_VIDEOCOMPRESSION (WM_CAP_START+ 46)

#define WM_CAP_SET_PREVIEW (WM_CAP_START+ 50)
#define WM_CAP_SET_OVERLAY (WM_CAP_START+ 51)
#define WM_CAP_SET_PREVIEWRATE (WM_CAP_START+ 52)
#define WM_CAP_SET_SCALE (WM_CAP_START+ 53)
#define WM_CAP_GET_STATUS (WM_CAP_START+ 54)
#define WM_CAP_SET_SCROLL (WM_CAP_START+ 55)

#define WM_CAP_GRAB_FRAME (WM_CAP_START+ 60)
#define WM_CAP_GRAB_FRAME_NOSTOP (WM_CAP_START+ 61)

#define WM_CAP_SEQUENCE (WM_CAP_START+ 62)
#define WM_CAP_SEQUENCE_NOFILE (WM_CAP_START+ 63)
#define WM_CAP_SET_SEQUENCE_SETUP (WM_CAP_START+ 64)
#define WM_CAP_GET_SEQUENCE_SETUP (WM_CAP_START+ 65)

#define WM_CAP_SET_MCI_DEVICEA (WM_CAP_START+ 66)
#define WM_CAP_GET_MCI_DEVICEA (WM_CAP_START+ 67)
#define WM_CAP_SET_MCI_DEVICEW (WM_CAP_UNICODE_START+ 66)
#define WM_CAP_GET_MCI_DEVICEW (WM_CAP_UNICODE_START+ 67)

#define WM_CAP_SET_MCI_DEVICE __MINGW_NAME_AW(WM_CAP_SET_MCI_DEVICE)
#define WM_CAP_GET_MCI_DEVICE __MINGW_NAME_AW(WM_CAP_GET_MCI_DEVICE)

#define WM_CAP_STOP (WM_CAP_START+ 68)
#define WM_CAP_ABORT (WM_CAP_START+ 69)

#define WM_CAP_SINGLE_FRAME_OPEN (WM_CAP_START+ 70)
#define WM_CAP_SINGLE_FRAME_CLOSE (WM_CAP_START+ 71)
#define WM_CAP_SINGLE_FRAME (WM_CAP_START+ 72)

#define WM_CAP_PAL_OPENA (WM_CAP_START+ 80)
#define WM_CAP_PAL_SAVEA (WM_CAP_START+ 81)
#define WM_CAP_PAL_OPENW (WM_CAP_UNICODE_START+ 80)
#define WM_CAP_PAL_SAVEW (WM_CAP_UNICODE_START+ 81)

#define WM_CAP_PAL_OPEN __MINGW_NAME_AW(WM_CAP_PAL_OPEN)
#define WM_CAP_PAL_SAVE __MINGW_NAME_AW(WM_CAP_PAL_SAVE)

#define WM_CAP_PAL_PASTE (WM_CAP_START+ 82)
#define WM_CAP_PAL_AUTOCREATE (WM_CAP_START+ 83)
#define WM_CAP_PAL_MANUALCREATE (WM_CAP_START+ 84)

#define WM_CAP_SET_CALLBACK_CAPCONTROL (WM_CAP_START+ 85)

#define WM_CAP_UNICODE_END WM_CAP_PAL_SAVEW
#define WM_CAP_END WM_CAP_UNICODE_END

#define capSetCallbackOnError(hwnd,fpProc) ((WINBOOL)AVICapSM(hwnd,WM_CAP_SET_CALLBACK_ERROR,(WPARAM)0,(LPARAM)(LPVOID)(fpProc)))
#define capSetCallbackOnStatus(hwnd,fpProc) ((WINBOOL)AVICapSM(hwnd,WM_CAP_SET_CALLBACK_STATUS,(WPARAM)0,(LPARAM)(LPVOID)(fpProc)))
#define capSetCallbackOnYield(hwnd,fpProc) ((WINBOOL)AVICapSM(hwnd,WM_CAP_SET_CALLBACK_YIELD,(WPARAM)0,(LPARAM)(LPVOID)(fpProc)))
#define capSetCallbackOnFrame(hwnd,fpProc) ((WINBOOL)AVICapSM(hwnd,WM_CAP_SET_CALLBACK_FRAME,(WPARAM)0,(LPARAM)(LPVOID)(fpProc)))
#define capSetCallbackOnVideoStream(hwnd,fpProc) ((WINBOOL)AVICapSM(hwnd,WM_CAP_SET_CALLBACK_VIDEOSTREAM,(WPARAM)0,(LPARAM)(LPVOID)(fpProc)))
#define capSetCallbackOnWaveStream(hwnd,fpProc) ((WINBOOL)AVICapSM(hwnd,WM_CAP_SET_CALLBACK_WAVESTREAM,(WPARAM)0,(LPARAM)(LPVOID)(fpProc)))
#define capSetCallbackOnCapControl(hwnd,fpProc) ((WINBOOL)AVICapSM(hwnd,WM_CAP_SET_CALLBACK_CAPCONTROL,(WPARAM)0,(LPARAM)(LPVOID)(fpProc)))

#define capSetUserData(hwnd,lUser) ((WINBOOL)AVICapSM(hwnd,WM_CAP_SET_USER_DATA,(WPARAM)0,(LPARAM)lUser))
#define capGetUserData(hwnd) (AVICapSM(hwnd,WM_CAP_GET_USER_DATA,(WPARAM)0,(LPARAM)0))

#define capDriverConnect(hwnd,i) ((WINBOOL)AVICapSM(hwnd,WM_CAP_DRIVER_CONNECT,(WPARAM)(i),(LPARAM)0))
#define capDriverDisconnect(hwnd) ((WINBOOL)AVICapSM(hwnd,WM_CAP_DRIVER_DISCONNECT,(WPARAM)0,(LPARAM)0))
#define capDriverGetName(hwnd,szName,wSize) ((WINBOOL)AVICapSM(hwnd,WM_CAP_DRIVER_GET_NAME,(WPARAM)(wSize),(LPARAM)(LPVOID)(LPTSTR)(szName)))
#define capDriverGetVersion(hwnd,szVer,wSize) ((WINBOOL)AVICapSM(hwnd,WM_CAP_DRIVER_GET_VERSION,(WPARAM)(wSize),(LPARAM)(LPVOID)(LPTSTR)(szVer)))
#define capDriverGetCaps(hwnd,s,wSize) ((WINBOOL)AVICapSM(hwnd,WM_CAP_DRIVER_GET_CAPS,(WPARAM)(wSize),(LPARAM)(LPVOID)(LPCAPDRIVERCAPS)(s)))

#define capFileSetCaptureFile(hwnd,szName) ((WINBOOL)AVICapSM(hwnd,WM_CAP_FILE_SET_CAPTURE_FILE,(WPARAM)0,(LPARAM)(LPVOID)(LPTSTR)(szName)))
#define capFileGetCaptureFile(hwnd,szName,wSize) ((WINBOOL)AVICapSM(hwnd,WM_CAP_FILE_GET_CAPTURE_FILE,(WPARAM)(wSize),(LPARAM)(LPVOID)(LPTSTR)(szName)))
#define capFileAlloc(hwnd,dwSize) ((WINBOOL)AVICapSM(hwnd,WM_CAP_FILE_ALLOCATE,(WPARAM)0,(LPARAM)(DWORD)(dwSize)))
#define capFileSaveAs(hwnd,szName) ((WINBOOL)AVICapSM(hwnd,WM_CAP_FILE_SAVEAS,(WPARAM)0,(LPARAM)(LPVOID)(LPTSTR)(szName)))
#define capFileSetInfoChunk(hwnd,lpInfoChunk) ((WINBOOL)AVICapSM(hwnd,WM_CAP_FILE_SET_INFOCHUNK,(WPARAM)0,(LPARAM)(LPCAPINFOCHUNK)(lpInfoChunk)))
#define capFileSaveDIB(hwnd,szName) ((WINBOOL)AVICapSM(hwnd,WM_CAP_FILE_SAVEDIB,(WPARAM)0,(LPARAM)(LPVOID)(LPTSTR)(szName)))

#define capEditCopy(hwnd) ((WINBOOL)AVICapSM(hwnd,WM_CAP_EDIT_COPY,(WPARAM)0,(LPARAM)0))

#define capSetAudioFormat(hwnd,s,wSize) ((WINBOOL)AVICapSM(hwnd,WM_CAP_SET_AUDIOFORMAT,(WPARAM)(wSize),(LPARAM)(LPVOID)(LPWAVEFORMATEX)(s)))
#define capGetAudioFormat(hwnd,s,wSize) ((DWORD)AVICapSM(hwnd,WM_CAP_GET_AUDIOFORMAT,(WPARAM)(wSize),(LPARAM)(LPVOID)(LPWAVEFORMATEX)(s)))
#define capGetAudioFormatSize(hwnd) ((DWORD)AVICapSM(hwnd,WM_CAP_GET_AUDIOFORMAT,(WPARAM)0,(LPARAM)0))

#define capDlgVideoFormat(hwnd) ((WINBOOL)AVICapSM(hwnd,WM_CAP_DLG_VIDEOFORMAT,(WPARAM)0,(LPARAM)0))
#define capDlgVideoSource(hwnd) ((WINBOOL)AVICapSM(hwnd,WM_CAP_DLG_VIDEOSOURCE,(WPARAM)0,(LPARAM)0))
#define capDlgVideoDisplay(hwnd) ((WINBOOL)AVICapSM(hwnd,WM_CAP_DLG_VIDEODISPLAY,(WPARAM)0,(LPARAM)0))
#define capDlgVideoCompression(hwnd) ((WINBOOL)AVICapSM(hwnd,WM_CAP_DLG_VIDEOCOMPRESSION,(WPARAM)0,(LPARAM)0))

#define capGetVideoFormat(hwnd,s,wSize) ((DWORD)AVICapSM(hwnd,WM_CAP_GET_VIDEOFORMAT,(WPARAM)(wSize),(LPARAM)(LPVOID)(s)))
#define capGetVideoFormatSize(hwnd) ((DWORD)AVICapSM(hwnd,WM_CAP_GET_VIDEOFORMAT,(WPARAM)0,(LPARAM)0))
#define capSetVideoFormat(hwnd,s,wSize) ((WINBOOL)AVICapSM(hwnd,WM_CAP_SET_VIDEOFORMAT,(WPARAM)(wSize),(LPARAM)(LPVOID)(s)))

#define capPreview(hwnd,f) ((WINBOOL)AVICapSM(hwnd,WM_CAP_SET_PREVIEW,(WPARAM)(WINBOOL)(f),(LPARAM)0))
#define capPreviewRate(hwnd,wMS) ((WINBOOL)AVICapSM(hwnd,WM_CAP_SET_PREVIEWRATE,(WPARAM)(wMS),(LPARAM)0))
#define capOverlay(hwnd,f) ((WINBOOL)AVICapSM(hwnd,WM_CAP_SET_OVERLAY,(WPARAM)(WINBOOL)(f),(LPARAM)0))
#define capPreviewScale(hwnd,f) ((WINBOOL)AVICapSM(hwnd,WM_CAP_SET_SCALE,(WPARAM)(WINBOOL)f,(LPARAM)0))
#define capGetStatus(hwnd,s,wSize) ((WINBOOL)AVICapSM(hwnd,WM_CAP_GET_STATUS,(WPARAM)(wSize),(LPARAM)(LPVOID)(LPCAPSTATUS)(s)))
#define capSetScrollPos(hwnd,lpP) ((WINBOOL)AVICapSM(hwnd,WM_CAP_SET_SCROLL,(WPARAM)0,(LPARAM)(LPPOINT)(lpP)))

#define capGrabFrame(hwnd) ((WINBOOL)AVICapSM(hwnd,WM_CAP_GRAB_FRAME,(WPARAM)0,(LPARAM)0))
#define capGrabFrameNoStop(hwnd) ((WINBOOL)AVICapSM(hwnd,WM_CAP_GRAB_FRAME_NOSTOP,(WPARAM)0,(LPARAM)0))

#define capCaptureSequence(hwnd) ((WINBOOL)AVICapSM(hwnd,WM_CAP_SEQUENCE,(WPARAM)0,(LPARAM)0))
#define capCaptureSequenceNoFile(hwnd) ((WINBOOL)AVICapSM(hwnd,WM_CAP_SEQUENCE_NOFILE,(WPARAM)0,(LPARAM)0))
#define capCaptureStop(hwnd) ((WINBOOL)AVICapSM(hwnd,WM_CAP_STOP,(WPARAM)0,(LPARAM)0))
#define capCaptureAbort(hwnd) ((WINBOOL)AVICapSM(hwnd,WM_CAP_ABORT,(WPARAM)0,(LPARAM)0))

#define capCaptureSingleFrameOpen(hwnd) ((WINBOOL)AVICapSM(hwnd,WM_CAP_SINGLE_FRAME_OPEN,(WPARAM)0,(LPARAM)0))
#define capCaptureSingleFrameClose(hwnd) ((WINBOOL)AVICapSM(hwnd,WM_CAP_SINGLE_FRAME_CLOSE,(WPARAM)0,(LPARAM)0))
#define capCaptureSingleFrame(hwnd) ((WINBOOL)AVICapSM(hwnd,WM_CAP_SINGLE_FRAME,(WPARAM)0,(LPARAM)0))

#define capCaptureGetSetup(hwnd,s,wSize) ((WINBOOL)AVICapSM(hwnd,WM_CAP_GET_SEQUENCE_SETUP,(WPARAM)(wSize),(LPARAM)(LPVOID)(LPCAPTUREPARMS)(s)))
#define capCaptureSetSetup(hwnd,s,wSize) ((WINBOOL)AVICapSM(hwnd,WM_CAP_SET_SEQUENCE_SETUP,(WPARAM)(wSize),(LPARAM)(LPVOID)(LPCAPTUREPARMS)(s)))

#define capSetMCIDeviceName(hwnd,szName) ((WINBOOL)AVICapSM(hwnd,WM_CAP_SET_MCI_DEVICE,(WPARAM)0,(LPARAM)(LPVOID)(LPTSTR)(szName)))
#define capGetMCIDeviceName(hwnd,szName,wSize) ((WINBOOL)AVICapSM(hwnd,WM_CAP_GET_MCI_DEVICE,(WPARAM)(wSize),(LPARAM)(LPVOID)(LPTSTR)(szName)))

#define capPaletteOpen(hwnd,szName) ((WINBOOL)AVICapSM(hwnd,WM_CAP_PAL_OPEN,(WPARAM)0,(LPARAM)(LPVOID)(LPTSTR)(szName)))
#define capPaletteSave(hwnd,szName) ((WINBOOL)AVICapSM(hwnd,WM_CAP_PAL_SAVE,(WPARAM)0,(LPARAM)(LPVOID)(LPTSTR)(szName)))
#define capPalettePaste(hwnd) ((WINBOOL)AVICapSM(hwnd,WM_CAP_PAL_PASTE,(WPARAM) 0,(LPARAM)0))
#define capPaletteAuto(hwnd,iFrames,iColors) ((WINBOOL)AVICapSM(hwnd,WM_CAP_PAL_AUTOCREATE,(WPARAM)(iFrames),(LPARAM)(DWORD)(iColors)))
#define capPaletteManual(hwnd,fGrab,iColors) ((WINBOOL)AVICapSM(hwnd,WM_CAP_PAL_MANUALCREATE,(WPARAM)(fGrab),(LPARAM)(DWORD)(iColors)))

  typedef struct tagCapDriverCaps {
    UINT wDeviceIndex;
    WINBOOL fHasOverlay;
    WINBOOL fHasDlgVideoSource;
    WINBOOL fHasDlgVideoFormat;
    WINBOOL fHasDlgVideoDisplay;
    WINBOOL fCaptureInitialized;
    WINBOOL fDriverSuppliesPalettes;
    HANDLE hVideoIn;
    HANDLE hVideoOut;
    HANDLE hVideoExtIn;
    HANDLE hVideoExtOut;
  } CAPDRIVERCAPS,*PCAPDRIVERCAPS,*LPCAPDRIVERCAPS;

  typedef struct tagCapStatus {
    UINT uiImageWidth;
    UINT uiImageHeight;
    WINBOOL fLiveWindow;
    WINBOOL fOverlayWindow;
    WINBOOL fScale;
    POINT ptScroll;
    WINBOOL fUsingDefaultPalette;
    WINBOOL fAudioHardware;
    WINBOOL fCapFileExists;
    DWORD dwCurrentVideoFrame;
    DWORD dwCurrentVideoFramesDropped;
    DWORD dwCurrentWaveSamples;
    DWORD dwCurrentTimeElapsedMS;
    HPALETTE hPalCurrent;
    WINBOOL fCapturingNow;
    DWORD dwReturn;
    UINT wNumVideoAllocated;
    UINT wNumAudioAllocated;
  } CAPSTATUS,*PCAPSTATUS,*LPCAPSTATUS;

  typedef struct tagCaptureParms {
    DWORD dwRequestMicroSecPerFrame;
    WINBOOL fMakeUserHitOKToCapture;
    UINT wPercentDropForError;
    WINBOOL fYield;
    DWORD dwIndexSize;
    UINT wChunkGranularity;
    WINBOOL fUsingDOSMemory;
    UINT wNumVideoRequested;
    WINBOOL fCaptureAudio;
    UINT wNumAudioRequested;
    UINT vKeyAbort;
    WINBOOL fAbortLeftMouse;
    WINBOOL fAbortRightMouse;
    WINBOOL fLimitEnabled;
    UINT wTimeLimit;
    WINBOOL fMCIControl;
    WINBOOL fStepMCIDevice;
    DWORD dwMCIStartTime;
    DWORD dwMCIStopTime;
    WINBOOL fStepCaptureAt2x;
    UINT wStepCaptureAverageFrames;
    DWORD dwAudioBufferSize;
    WINBOOL fDisableWriteCache;
    UINT AVStreamMaster;
  } CAPTUREPARMS,*PCAPTUREPARMS,*LPCAPTUREPARMS;

#define AVSTREAMMASTER_AUDIO 0
#define AVSTREAMMASTER_NONE 1

  typedef struct tagCapInfoChunk {
    FOURCC fccInfoID;
    LPVOID lpData;
    LONG cbData;
  } CAPINFOCHUNK,*PCAPINFOCHUNK,*LPCAPINFOCHUNK;

  typedef LRESULT (CALLBACK *CAPYIELDCALLBACK)(HWND hWnd);
  typedef LRESULT (CALLBACK *CAPSTATUSCALLBACKW)(HWND hWnd,int nID,LPCWSTR lpsz);
  typedef LRESULT (CALLBACK *CAPERRORCALLBACKW)(HWND hWnd,int nID,LPCWSTR lpsz);
  typedef LRESULT (CALLBACK *CAPSTATUSCALLBACKA)(HWND hWnd,int nID,LPCSTR lpsz);
  typedef LRESULT (CALLBACK *CAPERRORCALLBACKA)(HWND hWnd,int nID,LPCSTR lpsz);

#define CAPSTATUSCALLBACK __MINGW_NAME_AW(CAPSTATUSCALLBACK)
#define CAPERRORCALLBACK __MINGW_NAME_AW(CAPERRORCALLBACK)

  typedef LRESULT (CALLBACK *CAPVIDEOCALLBACK)(HWND hWnd,LPVIDEOHDR lpVHdr);
  typedef LRESULT (CALLBACK *CAPWAVECALLBACK)(HWND hWnd,LPWAVEHDR lpWHdr);
  typedef LRESULT (CALLBACK *CAPCONTROLCALLBACK)(HWND hWnd,int nState);

#define CONTROLCALLBACK_PREROLL 1
#define CONTROLCALLBACK_CAPTURING 2

  HWND WINAPI capCreateCaptureWindowA (LPCSTR lpszWindowName,DWORD dwStyle,int x,int y,int nWidth,int nHeight,HWND hwndParent,int nID);
  WINBOOL WINAPI capGetDriverDescriptionA (UINT wDriverIndex,LPSTR lpszName,int cbName,LPSTR lpszVer,int cbVer);
  HWND WINAPI capCreateCaptureWindowW (LPCWSTR lpszWindowName,DWORD dwStyle,int x,int y,int nWidth,int nHeight,HWND hwndParent,int nID);
  WINBOOL WINAPI capGetDriverDescriptionW (UINT wDriverIndex,LPWSTR lpszName,int cbName,LPWSTR lpszVer,int cbVer);

#define capCreateCaptureWindow __MINGW_NAME_AW(capCreateCaptureWindow)
#define capGetDriverDescription __MINGW_NAME_AW(capGetDriverDescription)
#endif

#define infotypeDIGITIZATION_TIME mmioFOURCC ('I','D','I','T')
#define infotypeSMPTE_TIME mmioFOURCC ('I','S','M','P')

#define IDS_CAP_BEGIN 300
#define IDS_CAP_END 301

#define IDS_CAP_INFO 401
#define IDS_CAP_OUTOFMEM 402
#define IDS_CAP_FILEEXISTS 403
#define IDS_CAP_ERRORPALOPEN 404
#define IDS_CAP_ERRORPALSAVE 405
#define IDS_CAP_ERRORDIBSAVE 406
#define IDS_CAP_DEFAVIEXT 407
#define IDS_CAP_DEFPALEXT 408
#define IDS_CAP_CANTOPEN 409
#define IDS_CAP_SEQ_MSGSTART 410
#define IDS_CAP_SEQ_MSGSTOP 411

#define IDS_CAP_VIDEDITERR 412
#define IDS_CAP_READONLYFILE 413
#define IDS_CAP_WRITEERROR 414
#define IDS_CAP_NODISKSPACE 415
#define IDS_CAP_SETFILESIZE 416
#define IDS_CAP_SAVEASPERCENT 417

#define IDS_CAP_DRIVER_ERROR 418

#define IDS_CAP_WAVE_OPEN_ERROR 419
#define IDS_CAP_WAVE_ALLOC_ERROR 420
#define IDS_CAP_WAVE_PREPARE_ERROR 421
#define IDS_CAP_WAVE_ADD_ERROR 422
#define IDS_CAP_WAVE_SIZE_ERROR 423

#define IDS_CAP_VIDEO_OPEN_ERROR 424
#define IDS_CAP_VIDEO_ALLOC_ERROR 425
#define IDS_CAP_VIDEO_PREPARE_ERROR 426
#define IDS_CAP_VIDEO_ADD_ERROR 427
#define IDS_CAP_VIDEO_SIZE_ERROR 428

#define IDS_CAP_FILE_OPEN_ERROR 429
#define IDS_CAP_FILE_WRITE_ERROR 430
#define IDS_CAP_RECORDING_ERROR 431
#define IDS_CAP_RECORDING_ERROR2 432
#define IDS_CAP_AVI_INIT_ERROR 433
#define IDS_CAP_NO_FRAME_CAP_ERROR 434
#define IDS_CAP_NO_PALETTE_WARN 435
#define IDS_CAP_MCI_CONTROL_ERROR 436
#define IDS_CAP_MCI_CANT_STEP_ERROR 437
#define IDS_CAP_NO_AUDIO_CAP_ERROR 438
#define IDS_CAP_AVI_DRAWDIB_ERROR 439
#define IDS_CAP_COMPRESSOR_ERROR 440
#define IDS_CAP_AUDIO_DROP_ERROR 441
#define IDS_CAP_AUDIO_DROP_COMPERROR 442

#define IDS_CAP_STAT_LIVE_MODE 500
#define IDS_CAP_STAT_OVERLAY_MODE 501
#define IDS_CAP_STAT_CAP_INIT 502
#define IDS_CAP_STAT_CAP_FINI 503
#define IDS_CAP_STAT_PALETTE_BUILD 504
#define IDS_CAP_STAT_OPTPAL_BUILD 505
#define IDS_CAP_STAT_I_FRAMES 506
#define IDS_CAP_STAT_L_FRAMES 507
#define IDS_CAP_STAT_CAP_L_FRAMES 508
#define IDS_CAP_STAT_CAP_AUDIO 509
#define IDS_CAP_STAT_VIDEOCURRENT 510
#define IDS_CAP_STAT_VIDEOAUDIO 511
#define IDS_CAP_STAT_VIDEOONLY 512
#define IDS_CAP_STAT_FRAMESDROPPED 513
#endif

#ifdef __cplusplus
}
#endif

#ifndef NOMSACM
#include <msacm.h>
#endif

#ifdef __cplusplus
extern "C" {
#endif

#ifdef OFN_READONLY
  WINBOOL WINAPI GetOpenFileNamePreviewA(LPOPENFILENAMEA lpofn);
  WINBOOL WINAPI GetSaveFileNamePreviewA(LPOPENFILENAMEA lpofn);
  WINBOOL WINAPI GetOpenFileNamePreviewW(LPOPENFILENAMEW lpofn);
  WINBOOL WINAPI GetSaveFileNamePreviewW(LPOPENFILENAMEW lpofn);

#define GetOpenFileNamePreview __MINGW_NAME_AW(GetOpenFileNamePreview)
#define GetSaveFileNamePreview __MINGW_NAME_AW(GetSaveFileNamePreview)
#endif

#ifndef RC_INVOKED
#include "poppack.h"
#endif

#ifdef __cplusplus
}
#endif
#endif

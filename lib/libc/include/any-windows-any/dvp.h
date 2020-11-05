
/* $Id$
 *
 * COPYRIGHT:            This file is in the public domain.
 * PROJECT:              ReactOS kernel
 * FILE:
 * PURPOSE:              Directx headers
 * PROGRAMMER:           Magnus Olsen (greatlrd)
 *
 */

#ifndef __DVP_INCLUDED__
#define __DVP_INCLUDED__

#if defined( _WIN32 )  && !defined( _NO_COM )
DEFINE_GUID(IID_IDDVideoPortContainer, 0x6C142760,0xA733,0x11CE,0xA5,0x21,0x00,0x20,0xAF,0x0B,0xE5,0x60);
DEFINE_GUID(IID_IDirectDrawVideoPort, 0xB36D93E0,0x2B43,0x11CF,0xA2,0xDE,0x00,0xAA,0x00,0xB9,0x33,0x56);
DEFINE_GUID(IID_IDirectDrawVideoPortNotify, 0xA655FB94,0x0589,0x4E57,0xB3,0x33,0x56,0x7A,0x89,0x46,0x8C,0x88);

DEFINE_GUID(DDVPTYPE_E_HREFH_VREFH, 0x54F39980L,0xDA60,0x11CF,0x9B,0x06,0x00,0xA0,0xC9,0x03,0xA3,0xB8);
DEFINE_GUID(DDVPTYPE_E_HREFH_VREFL, 0x92783220L,0xDA60,0x11CF,0x9B,0x06,0x00,0xA0,0xC9,0x03,0xA3,0xB8);
DEFINE_GUID(DDVPTYPE_E_HREFL_VREFH, 0xA07A02E0L,0xDA60,0x11CF,0x9B,0x06,0x00,0xA0,0xC9,0x03,0xA3,0xB8);
DEFINE_GUID(DDVPTYPE_E_HREFL_VREFL, 0xE09C77E0L,0xDA60,0x11CF,0x9B,0x06,0x00,0xA0,0xC9,0x03,0xA3,0xB8);
DEFINE_GUID(DDVPTYPE_CCIR656, 0xFCA326A0L,0xDA60,0x11CF,0x9B,0x06,0x00,0xA0,0xC9,0x03,0xA3,0xB8);
DEFINE_GUID(DDVPTYPE_BROOKTREE, 0x1352A560L,0xDA61,0x11CF,0x9B,0x06,0x00,0xA0,0xC9,0x03,0xA3,0xB8);
DEFINE_GUID(DDVPTYPE_PHILIPS, 0x332CF160L,0xDA61,0x11CF,0x9B,0x06,0x00,0xA0,0xC9,0x03,0xA3,0xB8);
#endif

#ifndef GUID_DEFS_ONLY

#if defined(_WIN32)  && !defined(_NO_COM)
#define COM_NO_WINDOWS_H
#include <objbase.h>
#else
#define IUnknown void
#endif /* _WIN32 && !_NO_COM */

#ifndef MAXULONG_PTR
#define ULONG_PTR DWORD
#endif

#ifdef __cplusplus
extern "C" {
#endif

typedef struct _DDVIDEOPORTCONNECT
{
  DWORD dwSize;
  DWORD dwPortWidth;
  GUID guidTypeID;
  DWORD dwFlags;
  ULONG_PTR dwReserved1;
} DDVIDEOPORTCONNECT, *LPDDVIDEOPORTCONNECT;

typedef struct _DDVIDEOPORTDESC
{
  DWORD dwSize;
  DWORD dwFieldWidth;
  DWORD dwVBIWidth;
  DWORD dwFieldHeight;
  DWORD dwMicrosecondsPerField;
  DWORD dwMaxPixelsPerSecond;
  DWORD dwVideoPortID;
  DWORD dwReserved1;
  DDVIDEOPORTCONNECT VideoPortType;
  ULONG_PTR dwReserved2;
  ULONG_PTR dwReserved3;
} DDVIDEOPORTDESC, *LPDDVIDEOPORTDESC;

typedef struct _DDVIDEOPORTBANDWIDTH
{
  DWORD dwSize;
  DWORD dwOverlay;
  DWORD dwColorkey;
  DWORD dwYInterpolate;
  DWORD dwYInterpAndColorkey;
  ULONG_PTR dwReserved1;
  ULONG_PTR dwReserved2;
} DDVIDEOPORTBANDWIDTH, *LPDDVIDEOPORTBANDWIDTH;

typedef struct _DDVIDEOPORTCAPS
{
  DWORD dwSize;
  DWORD dwFlags;
  DWORD dwMaxWidth;
  DWORD dwMaxVBIWidth;
  DWORD dwMaxHeight;
  DWORD dwVideoPortID;
  DWORD dwCaps;
  DWORD dwFX;
  DWORD dwNumAutoFlipSurfaces;
  DWORD dwAlignVideoPortBoundary;
  DWORD dwAlignVideoPortPrescaleWidth;
  DWORD dwAlignVideoPortCropBoundary;
  DWORD dwAlignVideoPortCropWidth;
  DWORD dwPreshrinkXStep;
  DWORD dwPreshrinkYStep;
  DWORD dwNumVBIAutoFlipSurfaces;
  DWORD dwNumPreferredAutoflip;
  WORD  wNumFilterTapsX;
  WORD  wNumFilterTapsY;
} DDVIDEOPORTCAPS, *LPDDVIDEOPORTCAPS;

typedef struct _DDVIDEOPORTINFO
{
  DWORD dwSize;
  DWORD dwOriginX;
  DWORD dwOriginY;
  DWORD dwVPFlags;
  RECT rCrop;
  DWORD dwPrescaleWidth;
  DWORD dwPrescaleHeight;
  LPDDPIXELFORMAT lpddpfInputFormat;
  LPDDPIXELFORMAT lpddpfVBIInputFormat;
  LPDDPIXELFORMAT lpddpfVBIOutputFormat;
  DWORD dwVBIHeight;
  ULONG_PTR dwReserved1;
  ULONG_PTR dwReserved2;
} DDVIDEOPORTINFO, *LPDDVIDEOPORTINFO;

typedef struct _DDVIDEOPORTSTATUS
{
  DWORD dwSize;
  WINBOOL bInUse;
  DWORD dwFlags;
  DWORD dwReserved1;
  DDVIDEOPORTCONNECT VideoPortType;
  ULONG_PTR dwReserved2;
  ULONG_PTR dwReserved3;
} DDVIDEOPORTSTATUS, *LPDDVIDEOPORTSTATUS;

typedef struct _DDVIDEOPORTNOTIFY
{
  LARGE_INTEGER ApproximateTimeStamp;
  LONG lField;
  UINT dwSurfaceIndex;
  LONG lDone;
} DDVIDEOPORTNOTIFY, *LPDDVIDEOPORTNOTIFY;


#define DDVPD_WIDTH				0x00000001
#define DDVPD_HEIGHT				0x00000002
#define DDVPD_ID				0x00000004
#define DDVPD_CAPS				0x00000008
#define DDVPD_FX				0x00000010
#define DDVPD_AUTOFLIP				0x00000020
#define DDVPD_ALIGN				0x00000040
#define DDVPD_PREFERREDAUTOFLIP			0x00000080
#define DDVPD_FILTERQUALITY			0x00000100
#define DDVPCONNECT_DOUBLECLOCK			0x00000001
#define DDVPCONNECT_VACT			0x00000002
#define DDVPCONNECT_INVERTPOLARITY		0x00000004
#define DDVPCONNECT_DISCARDSVREFDATA		0x00000008
#define DDVPCONNECT_HALFLINE			0x00000010
#define DDVPCONNECT_INTERLACED			0x00000020
#define DDVPCONNECT_SHAREEVEN			0x00000040
#define DDVPCONNECT_SHAREODD			0x00000080
#define DDVPCAPS_AUTOFLIP			0x00000001
#define DDVPCAPS_INTERLACED			0x00000002
#define DDVPCAPS_NONINTERLACED			0x00000004
#define DDVPCAPS_READBACKFIELD			0x00000008
#define DDVPCAPS_READBACKLINE			0x00000010
#define DDVPCAPS_SHAREABLE			0x00000020
#define DDVPCAPS_SKIPEVENFIELDS			0x00000040
#define DDVPCAPS_SKIPODDFIELDS			0x00000080
#define DDVPCAPS_SYNCMASTER			0x00000100
#define DDVPCAPS_VBISURFACE			0x00000200
#define DDVPCAPS_COLORCONTROL			0x00000400
#define DDVPCAPS_OVERSAMPLEDVBI			0x00000800
#define DDVPCAPS_SYSTEMMEMORY			0x00001000
#define DDVPCAPS_VBIANDVIDEOINDEPENDENT		0x00002000
#define DDVPCAPS_HARDWAREDEINTERLACE		0x00004000
#define DDVPFX_CROPTOPDATA			0x00000001
#define DDVPFX_CROPX				0x00000002
#define DDVPFX_CROPY				0x00000004
#define DDVPFX_INTERLEAVE			0x00000008
#define DDVPFX_MIRRORLEFTRIGHT			0x00000010
#define DDVPFX_MIRRORUPDOWN			0x00000020
#define DDVPFX_PRESHRINKX			0x00000040
#define DDVPFX_PRESHRINKY			0x00000080
#define DDVPFX_PRESHRINKXB			0x00000100
#define DDVPFX_PRESHRINKYB			0x00000200
#define DDVPFX_PRESHRINKXS			0x00000400
#define DDVPFX_PRESHRINKYS			0x00000800
#define DDVPFX_PRESTRETCHX			0x00001000
#define DDVPFX_PRESTRETCHY			0x00002000
#define DDVPFX_PRESTRETCHXN			0x00004000
#define DDVPFX_PRESTRETCHYN			0x00008000
#define DDVPFX_VBICONVERT			0x00010000
#define DDVPFX_VBINOSCALE			0x00020000
#define DDVPFX_IGNOREVBIXCROP			0x00040000
#define DDVPFX_VBINOINTERLEAVE			0x00080000
#define DDVP_AUTOFLIP				0x00000001
#define DDVP_CONVERT				0x00000002
#define DDVP_CROP				0x00000004
#define DDVP_INTERLEAVE				0x00000008
#define DDVP_MIRRORLEFTRIGHT			0x00000010
#define DDVP_MIRRORUPDOWN			0x00000020
#define DDVP_PRESCALE				0x00000040
#define DDVP_SKIPEVENFIELDS			0x00000080
#define DDVP_SKIPODDFIELDS			0x00000100
#define DDVP_SYNCMASTER				0x00000200
#define DDVP_VBICONVERT				0x00000400
#define DDVP_VBINOSCALE				0x00000800
#define DDVP_OVERRIDEBOBWEAVE			0x00001000
#define DDVP_IGNOREVBIXCROP			0x00002000
#define DDVP_VBINOINTERLEAVE			0x00004000
#define DDVP_HARDWAREDEINTERLACE		0x00008000
#define DDVPFORMAT_VIDEO			0x00000001
#define DDVPFORMAT_VBI				0x00000002
#define DDVPTARGET_VIDEO			0x00000001
#define DDVPTARGET_VBI				0x00000002
#define DDVPWAIT_BEGIN				0x00000001
#define DDVPWAIT_END				0x00000002
#define DDVPWAIT_LINE				0x00000003
#define DDVPFLIP_VIDEO				0x00000001
#define DDVPFLIP_VBI				0x00000002
#define DDVPSQ_NOSIGNAL				0x00000001
#define DDVPSQ_SIGNALOK				0x00000002
#define DDVPB_VIDEOPORT				0x00000001
#define DDVPB_OVERLAY				0x00000002
#define DDVPB_TYPE				0x00000004
#define DDVPBCAPS_SOURCE			0x00000001
#define DDVPBCAPS_DESTINATION			0x00000002
#define DDVPCREATE_VBIONLY			0x00000001
#define DDVPCREATE_VIDEOONLY			0x00000002
#define DDVPSTATUS_VBIONLY			0x00000001
#define DDVPSTATUS_VIDEOONLY			0x00000002

struct IDirectDraw;
struct IDirectDrawSurface;
struct IDirectDrawPalette;
struct IDirectDrawClipper;
typedef struct IDirectDrawVideoPort *LPDIRECTDRAWVIDEOPORT;
typedef struct IDDVideoPortContainer *LPDDVIDEOPORTCONTAINER;
typedef struct IDirectDrawVideoPortNotify *LPDIRECTDRAWVIDEOPORTNOTIFY;

typedef struct IDDVideoPortContainerVtbl DDVIDEOPORTCONTAINERCALLBACKS;
typedef struct IDirectDrawVideoPortVtbl DIRECTDRAWVIDEOPORTCALLBACKS;
typedef struct IDirectDrawVideoPortNotifyVtbl DIRECTDRAWVIDEOPORTNOTIFYCALLBACKS;

typedef HRESULT (*LPDDENUMVIDEOCALLBACK)(LPDDVIDEOPORTCAPS, LPVOID);


#if defined( _WIN32 ) && !defined( _NO_COM )
#undef INTERFACE
#define INTERFACE IDDVideoPortContainer
DECLARE_INTERFACE_( IDDVideoPortContainer, IUnknown )
{
    STDMETHOD(QueryInterface) (THIS_ REFIID riid, LPVOID *ppvObj) PURE;
    STDMETHOD_(ULONG,AddRef) (THIS)  PURE;
    STDMETHOD_(ULONG,Release) (THIS) PURE;
    STDMETHOD(CreateVideoPort)(THIS_ DWORD, LPDDVIDEOPORTDESC, LPDIRECTDRAWVIDEOPORT *, IUnknown *) PURE;
    STDMETHOD(EnumVideoPorts)(THIS_ DWORD, LPDDVIDEOPORTCAPS, LPVOID,LPDDENUMVIDEOCALLBACK ) PURE;
    STDMETHOD(GetVideoPortConnectInfo)(THIS_ DWORD, LPDWORD, LPDDVIDEOPORTCONNECT ) PURE;
    STDMETHOD(QueryVideoPortStatus)(THIS_ DWORD, LPDDVIDEOPORTSTATUS ) PURE;
};

#if !defined(__cplusplus) || defined(CINTERFACE)
# define IVideoPortContainer_QueryInterface(p, a, b)		(p)->lpVtbl->QueryInterface(p, a, b)
# define IVideoPortContainer_AddRef(p)				(p)->lpVtbl->AddRef(p)
# define IVideoPortContainer_Release(p)				(p)->lpVtbl->Release(p)
# define IVideoPortContainer_CreateVideoPort(p, a, b, c, d)	(p)->lpVtbl->CreateVideoPort(p, a, b, c, d)
# define IVideoPortContainer_EnumVideoPorts(p, a, b, c, d)	(p)->lpVtbl->EnumVideoPorts(p, a, b, c, d)
# define IVideoPortContainer_GetVideoPortConnectInfo(p, a, b, c) (p)->lpVtbl->GetVideoPortConnectInfo(p, a, b, c)
# define IVideoPortContainer_QueryVideoPortStatus(p, a, b)	(p)->lpVtbl->QueryVideoPortStatus(p, a, b)
#else
# define IVideoPortContainer_QueryInterface(p, a, b)		(p)->QueryInterface(a, b)
# define IVideoPortContainer_AddRef(p)				(p)->AddRef()
# define IVideoPortContainer_Release(p)				(p)->Release()
# define IVideoPortContainer_CreateVideoPort(p, a, b, c, d)	(p)->CreateVideoPort(a, b, c, d)
# define IVideoPortContainer_EnumVideoPorts(p, a, b, c, d)	(p)->EnumVideoPorts(a, b, c, d)
# define IVideoPortContainer_GetVideoPortConnectInfo(p, a, b, c) (p)->GetVideoPortConnectInfo(a, b, c)
# define IVideoPortContainer_QueryVideoPortStatus(p, a, b)	(p)->QueryVideoPortStatus(a, b)
#endif /* !__cplusplus || defined(CINTERFACE) */
#endif /* defined( _WIN32 ) && !defined( _NO_COM ) */

#if defined( _WIN32 ) && !defined( _NO_COM )
#undef INTERFACE
#define INTERFACE IDirectDrawVideoPort
DECLARE_INTERFACE_( IDirectDrawVideoPort, IUnknown )
{
    STDMETHOD(QueryInterface) (THIS_ REFIID riid, LPVOID * ppvObj) PURE;
    STDMETHOD_(ULONG,AddRef) (THIS)  PURE;
    STDMETHOD_(ULONG,Release) (THIS) PURE;
    STDMETHOD(Flip)(THIS_ LPDIRECTDRAWSURFACE, DWORD) PURE;
    STDMETHOD(GetBandwidthInfo)(THIS_ LPDDPIXELFORMAT, DWORD, DWORD, DWORD, LPDDVIDEOPORTBANDWIDTH) PURE;
    STDMETHOD(GetColorControls)(THIS_ LPDDCOLORCONTROL) PURE;
    STDMETHOD(GetInputFormats)(THIS_ LPDWORD, LPDDPIXELFORMAT, DWORD) PURE;
    STDMETHOD(GetOutputFormats)(THIS_ LPDDPIXELFORMAT, LPDWORD, LPDDPIXELFORMAT, DWORD) PURE;
    STDMETHOD(GetFieldPolarity)(THIS_ LPBOOL) PURE;
    STDMETHOD(GetVideoLine)(THIS_ LPDWORD) PURE;
    STDMETHOD(GetVideoSignalStatus)(THIS_ LPDWORD) PURE;
    STDMETHOD(SetColorControls)(THIS_ LPDDCOLORCONTROL) PURE;
    STDMETHOD(SetTargetSurface)(THIS_ LPDIRECTDRAWSURFACE, DWORD) PURE;
    STDMETHOD(StartVideo)(THIS_ LPDDVIDEOPORTINFO) PURE;
    STDMETHOD(StopVideo)(THIS) PURE;
    STDMETHOD(UpdateVideo)(THIS_ LPDDVIDEOPORTINFO) PURE;
    STDMETHOD(WaitForSync)(THIS_ DWORD, DWORD, DWORD) PURE;
};

#if !defined(__cplusplus) || defined(CINTERFACE)
# define IVideoPort_QueryInterface(p,a,b)		(p)->lpVtbl->QueryInterface(p,a,b)
# define IVideoPort_AddRef(p)				(p)->lpVtbl->AddRef(p)
# define IVideoPort_Release(p)				(p)->lpVtbl->Release(p)
# define IVideoPort_SetTargetSurface(p,a,b)		(p)->lpVtbl->SetTargetSurface(p,a,b)
# define IVideoPort_Flip(p,a,b)				(p)->lpVtbl->Flip(p,a,b)
# define IVideoPort_GetBandwidthInfo(p,a,b,c,d,e)	(p)->lpVtbl->GetBandwidthInfo(p,a,b,c,d,e)
# define IVideoPort_GetColorControls(p,a) 		(p)->lpVtbl->GetColorControls(p,a)
# define IVideoPort_GetInputFormats(p,a,b,c)		(p)->lpVtbl->GetInputFormats(p,a,b,c)
# define IVideoPort_GetOutputFormats(p,a,b,c,d)		(p)->lpVtbl->GetOutputFormats(p,a,b,c,d)
# define IVideoPort_GetFieldPolarity(p,a)		(p)->lpVtbl->GetFieldPolarity(p,a)
# define IVideoPort_GetVideoLine(p,a)			(p)->lpVtbl->GetVideoLine(p,a)
# define IVideoPort_GetVideoSignalStatus(p,a)		(p)->lpVtbl->GetVideoSignalStatus(p,a)
# define IVideoPort_SetColorControls(p,a)		(p)->lpVtbl->SetColorControls(p,a)
# define IVideoPort_StartVideo(p,a)			(p)->lpVtbl->StartVideo(p,a)
# define IVideoPort_StopVideo(p)			(p)->lpVtbl->StopVideo(p)
# define IVideoPort_UpdateVideo(p,a)			(p)->lpVtbl->UpdateVideo(p,a)
# define IVideoPort_WaitForSync(p,a,b,c)		(p)->lpVtbl->WaitForSync(p,a,b,c)
#else
# define IVideoPort_QueryInterface(p,a,b)		(p)->QueryInterface(a,b)
# define IVideoPort_AddRef(p)				(p)->AddRef()
# define IVideoPort_Release(p)				(p)->Release()
# define IVideoPort_SetTargetSurface(p,a,b)		(p)->SetTargetSurface(a,b)
# define IVideoPort_Flip(p,a,b)				(p)->Flip(a,b)
# define IVideoPort_GetBandwidthInfo(p,a,b,c,d,e)	(p)->GetBandwidthInfo(a,b,c,d,e)
# define IVideoPort_GetColorControls(p,a) 		(p)->GetColorControls(a)
# define IVideoPort_GetInputFormats(p,a,b,c)		(p)->GetInputFormats(a,b,c)
# define IVideoPort_GetOutputFormats(p,a,b,c,d)		(p)->GetOutputFormats(a,b,c,d)
# define IVideoPort_GetFieldPolarity(p,a)		(p)->GetFieldPolarity(a)
# define IVideoPort_GetVideoLine(p,a)			(p)->GetVideoLine(a)
# define IVideoPort_GetVideoSignalStatus(p,a)		(p)->GetVideoSignalStatus(a)
# define IVideoPort_SetColorControls(p,a)		(p)->SetColorControls(a)
# define IVideoPort_StartVideo(p,a)			(p)->StartVideo(a)
# define IVideoPort_StopVideo(p)			(p)->StopVideo()
# define IVideoPort_UpdateVideo(p,a)			(p)->UpdateVideo(a)
# define IVideoPort_WaitForSync(p,a,b,c)		(p)->WaitForSync(a,b,c)
#endif /* !__cplusplus || defined(CINTERFACE) */
#endif /* defined( _WIN32 ) && !defined( _NO_COM ) */

#if defined( _WIN32 ) && !defined( _NO_COM )
#undef INTERFACE
#define INTERFACE IDirectDrawVideoPortNotify

DECLARE_INTERFACE_( IDirectDrawVideoPortNotify, IUnknown )
{
    STDMETHOD(QueryInterface) (THIS_ REFIID riid, LPVOID * ppvObj) PURE;
    STDMETHOD_(ULONG,AddRef) (THIS)  PURE;
    STDMETHOD_(ULONG,Release) (THIS) PURE;
    STDMETHOD(AcquireNotification)(THIS_ HANDLE *, LPDDVIDEOPORTNOTIFY) PURE;
    STDMETHOD(ReleaseNotification)(THIS_ HANDLE) PURE;
};

#if !defined(__cplusplus) || defined(CINTERFACE)
# define IVideoPortNotify_QueryInterface(p,a,b)		(p)->lpVtbl->QueryInterface(p,a,b)
# define IVideoPortNotify_AddRef(p)			(p)->lpVtbl->AddRef(p)
# define IVideoPortNotify_Release(p)			(p)->lpVtbl->Release(p)
# define IVideoPortNotify_AcquireNotification(p,a,b)	(p)->lpVtbl->AcquireNotification(p,a,b)
# define IVideoPortNotify_ReleaseNotification(p,a)	(p)->lpVtbl->ReleaseNotification(p,a)
#else
# define IVideoPortNotify_QueryInterface(p,a,b)		(p)->QueryInterface(a,b)
# define IVideoPortNotify_AddRef(p)			(p)->AddRef()
# define IVideoPortNotify_Release(p)			(p)->Release()
# define IVideoPortNotify_AcquireNotification(p,a,b)	(p)->lpVtbl->AcquireNotification(a,b)
# define IVideoPortNotify_ReleaseNotification(p,a)	(p)->lpVtbl->ReleaseNotification(a)
#endif /* !__cplusplus || defined(CINTERFACE) */
#endif /* defined( _WIN32 ) && !defined( _NO_COM ) */

#ifdef __cplusplus
}
#endif

#endif /* ! GUID_DEFS_ONLY */

#endif /* __DVP_INCLUDED__ */


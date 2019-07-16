/**
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER within this package.
 */

#ifndef _RICHOLE_
#define _RICHOLE_

#include "richedit.h"

typedef struct _reobject {
  DWORD cbStruct;
  LONG cp;
  CLSID clsid;
  LPOLEOBJECT poleobj;
  LPSTORAGE pstg;
  LPOLECLIENTSITE polesite;
  SIZEL sizel;
  DWORD dvaspect;
  DWORD dwFlags;
  DWORD dwUser;
} REOBJECT;

#define REO_GETOBJ_NO_INTERFACES (__MSABI_LONG(0x00000000))
#define REO_GETOBJ_POLEOBJ (__MSABI_LONG(0x00000001))
#define REO_GETOBJ_PSTG (__MSABI_LONG(0x00000002))
#define REO_GETOBJ_POLESITE (__MSABI_LONG(0x00000004))
#define REO_GETOBJ_ALL_INTERFACES (__MSABI_LONG(0x00000007))

#define REO_CP_SELECTION ((ULONG) -1)

#define REO_IOB_SELECTION ((ULONG) -1)
#define REO_IOB_USE_CP ((ULONG) -2)

#define REO_NULL (__MSABI_LONG(0x00000000))
#define REO_READWRITEMASK (__MSABI_LONG(0x000007ff))
#define REO_CANROTATE (__MSABI_LONG(0x00000080))
#define REO_OWNERDRAWSELECT (__MSABI_LONG(0x00000040))
#define REO_DONTNEEDPALETTE (__MSABI_LONG(0x00000020))
#define REO_BLANK (__MSABI_LONG(0x00000010))
#define REO_DYNAMICSIZE (__MSABI_LONG(0x00000008))
#define REO_INVERTEDSELECT (__MSABI_LONG(0x00000004))
#define REO_BELOWBASELINE (__MSABI_LONG(0x00000002))
#define REO_RESIZABLE (__MSABI_LONG(0x00000001))
#define REO_USEASBACKGROUND (__MSABI_LONG(0x00000400))
#define REO_WRAPTEXTAROUND (__MSABI_LONG(0x00000200))
#define REO_ALIGNTORIGHT (__MSABI_LONG(0x00000100))
#define REO_LINK (__MSABI_LONG(0x80000000))
#define REO_STATIC (__MSABI_LONG(0x40000000))
#define REO_SELECTED (__MSABI_LONG(0x08000000))
#define REO_OPEN (__MSABI_LONG(0x04000000))
#define REO_INPLACEACTIVE (__MSABI_LONG(0x02000000))
#define REO_HILITED (__MSABI_LONG(0x01000000))
#define REO_LINKAVAILABLE (__MSABI_LONG(0x00800000))
#define REO_GETMETAFILE (__MSABI_LONG(0x00400000))

#define RECO_PASTE (__MSABI_LONG(0x00000000))
#define RECO_DROP (__MSABI_LONG(0x00000001))
#define RECO_COPY (__MSABI_LONG(0x00000002))
#define RECO_CUT (__MSABI_LONG(0x00000003))
#define RECO_DRAG (__MSABI_LONG(0x00000004))

#undef INTERFACE
#define INTERFACE IRichEditOle

DECLARE_INTERFACE_ (IRichEditOle, IUnknown) {
#ifndef __cplusplus
  STDMETHOD (QueryInterface) (THIS_ REFIID riid, LPVOID *lplpObj) PURE;
  STDMETHOD_ (ULONG, AddRef) (THIS) PURE;
  STDMETHOD_ (ULONG, Release) (THIS) PURE;
#endif
  STDMETHOD (GetClientSite) (THIS_ LPOLECLIENTSITE *lplpolesite) PURE;
  STDMETHOD_ (LONG, GetObjectCount) (THIS) PURE;
  STDMETHOD_ (LONG, GetLinkCount) (THIS) PURE;
  STDMETHOD (GetObject) (THIS_ LONG iob, REOBJECT *lpreobject, DWORD dwFlags) PURE;
  STDMETHOD (InsertObject) (THIS_ REOBJECT *lpreobject) PURE;
  STDMETHOD (ConvertObject) (THIS_ LONG iob, REFCLSID rclsidNew, LPCSTR lpstrUserTypeNew) PURE;
  STDMETHOD (ActivateAs) (THIS_ REFCLSID rclsid, REFCLSID rclsidAs) PURE;
  STDMETHOD (SetHostNames) (THIS_ LPCSTR lpstrContainerApp, LPCSTR lpstrContainerObj) PURE;
  STDMETHOD (SetLinkAvailable) (THIS_ LONG iob, WINBOOL fAvailable) PURE;
  STDMETHOD (SetDvaspect) (THIS_ LONG iob, DWORD dvaspect) PURE;
  STDMETHOD (HandsOffStorage) (THIS_ LONG iob) PURE;
  STDMETHOD (SaveCompleted) (THIS_ LONG iob, LPSTORAGE lpstg) PURE;
  STDMETHOD (InPlaceDeactivate) (THIS) PURE;
  STDMETHOD (ContextSensitiveHelp) (THIS_ WINBOOL fEnterMode) PURE;
  STDMETHOD (GetClipboardData) (THIS_ CHARRANGE *lpchrg, DWORD reco, LPDATAOBJECT *lplpdataobj) PURE;
  STDMETHOD (ImportDataObject) (THIS_ LPDATAOBJECT lpdataobj, CLIPFORMAT cf, HGLOBAL hMetaPict) PURE;
};
typedef IRichEditOle *LPRICHEDITOLE;

#undef INTERFACE
#define INTERFACE IRichEditOleCallback
DECLARE_INTERFACE_ (IRichEditOleCallback, IUnknown) {
#ifndef __cplusplus
  STDMETHOD (QueryInterface) (THIS_ REFIID riid, LPVOID *lplpObj) PURE;
  STDMETHOD_ (ULONG, AddRef) (THIS) PURE;
  STDMETHOD_ (ULONG, Release) (THIS) PURE;
#endif
  STDMETHOD (GetNewStorage) (THIS_ LPSTORAGE *lplpstg) PURE;
  STDMETHOD (GetInPlaceContext) (THIS_ LPOLEINPLACEFRAME *lplpFrame, LPOLEINPLACEUIWINDOW *lplpDoc, LPOLEINPLACEFRAMEINFO lpFrameInfo) PURE;
  STDMETHOD (ShowContainerUI) (THIS_ WINBOOL fShow) PURE;
  STDMETHOD (QueryInsertObject) (THIS_ LPCLSID lpclsid, LPSTORAGE lpstg, LONG cp) PURE;
  STDMETHOD (DeleteObject) (THIS_ LPOLEOBJECT lpoleobj) PURE;
  STDMETHOD (QueryAcceptData) (THIS_ LPDATAOBJECT lpdataobj, CLIPFORMAT *lpcfFormat, DWORD reco, WINBOOL fReally, HGLOBAL hMetaPict) PURE;
  STDMETHOD (ContextSensitiveHelp) (THIS_ WINBOOL fEnterMode) PURE;
  STDMETHOD (GetClipboardData) (THIS_ CHARRANGE *lpchrg, DWORD reco, LPDATAOBJECT *lplpdataobj) PURE;
  STDMETHOD (GetDragDropEffect) (THIS_ WINBOOL fDrag, DWORD grfKeyState, LPDWORD pdwEffect) PURE;
  STDMETHOD (GetContextMenu) (THIS_ WORD seltype, LPOLEOBJECT lpoleobj, CHARRANGE *lpchrg, HMENU *lphmenu) PURE;
};
typedef IRichEditOleCallback *LPRICHEDITOLECALLBACK;

DEFINE_GUID (IID_IRichEditOle,0x00020D00,0,0,0xC0,0,0,0,0,0,0,0x46);
DEFINE_GUID (IID_IRichEditOleCallback,0x00020D03,0,0,0xC0,0,0,0,0,0,0,0x46);
#endif

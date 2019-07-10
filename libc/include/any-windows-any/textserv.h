/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _TEXTSERV_H
#define _TEXTSERV_H

EXTERN_C const IID IID_ITextServices;
EXTERN_C const IID IID_ITextHost;

#define S_MSG_KEY_IGNORED MAKE_HRESULT(SEVERITY_SUCCESS,FACILITY_ITF,0x201)

enum TXTBACKSTYLE {
  TXTBACK_TRANSPARENT = 0,TXTBACK_OPAQUE
};

enum TXTHITRESULT {
  TXTHITRESULT_NOHIT = 0,TXTHITRESULT_TRANSPARENT = 1,TXTHITRESULT_CLOSE = 2,TXTHITRESULT_HIT = 3
};

enum TXTNATURALSIZE {
  TXTNS_FITTOCONTENT = 1,TXTNS_ROUNDTOLINE = 2
};

enum TXTVIEW {
  TXTVIEW_ACTIVE = 0,TXTVIEW_INACTIVE = -1
};

enum CHANGETYPE {
  CN_GENERIC = 0,CN_TEXTCHANGED = 1,CN_NEWUNDO = 2,CN_NEWREDO = 4
};

struct CHANGENOTIFY {
  DWORD dwChangeType;
  void *pvCookieData;
};

#define TXTBIT_RICHTEXT 1
#define TXTBIT_MULTILINE 2
#define TXTBIT_READONLY 4
#define TXTBIT_SHOWACCELERATOR 8
#define TXTBIT_USEPASSWORD 0x10
#define TXTBIT_HIDESELECTION 0x20
#define TXTBIT_SAVESELECTION 0x40
#define TXTBIT_AUTOWORDSEL 0x80
#define TXTBIT_VERTICAL 0x100
#define TXTBIT_SELBARCHANGE 0x200

#define TXTBIT_WORDWRAP 0x400

#define TXTBIT_ALLOWBEEP 0x800
#define TXTBIT_DISABLEDRAG 0x1000
#define TXTBIT_VIEWINSETCHANGE 0x2000
#define TXTBIT_BACKSTYLECHANGE 0x4000
#define TXTBIT_MAXLENGTHCHANGE 0x8000
#define TXTBIT_SCROLLBARCHANGE 0x10000
#define TXTBIT_CHARFORMATCHANGE 0x20000
#define TXTBIT_PARAFORMATCHANGE 0x40000
#define TXTBIT_EXTENTCHANGE 0x80000
#define TXTBIT_CLIENTRECTCHANGE 0x100000
#define TXTBIT_USECURRENTBKG 0x200000

class ITextServices : public IUnknown {
public:
  virtual HRESULT TxSendMessage(UINT msg,WPARAM wparam,LPARAM lparam,LRESULT *plresult) = 0;
  virtual HRESULT TxDraw(DWORD dwDrawAspect,LONG lindex,void *pvAspect,DVTARGETDEVICE *ptd,HDC hdcDraw,HDC hicTargetDev,LPCRECTL lprcBounds,LPCRECTL lprcWBounds,LPRECT lprcUpdate,WINBOOL (CALLBACK *pfnContinue) (DWORD),DWORD dwContinue,LONG lViewId) = 0;
  virtual HRESULT TxGetHScroll(LONG *plMin,LONG *plMax,LONG *plPos,LONG *plPage,WINBOOL *pfEnabled) = 0;
  virtual HRESULT TxGetVScroll(LONG *plMin,LONG *plMax,LONG *plPos,LONG *plPage,WINBOOL *pfEnabled) = 0;
  virtual HRESULT OnTxSetCursor(DWORD dwDrawAspect,LONG lindex,void *pvAspect,DVTARGETDEVICE *ptd,HDC hdcDraw,HDC hicTargetDev,LPCRECT lprcClient,INT x,INT y) = 0;
  virtual HRESULT TxQueryHitPoint(DWORD dwDrawAspect,LONG lindex,void *pvAspect,DVTARGETDEVICE *ptd,HDC hdcDraw,HDC hicTargetDev,LPCRECT lprcClient,INT x,INT y,DWORD *pHitResult) = 0;
  virtual HRESULT OnTxInPlaceActivate(LPCRECT prcClient) = 0;
  virtual HRESULT OnTxInPlaceDeactivate() = 0;
  virtual HRESULT OnTxUIActivate() = 0;
  virtual HRESULT OnTxUIDeactivate() = 0;
  virtual HRESULT TxGetText(BSTR *pbstrText) = 0;
  virtual HRESULT TxSetText(LPCWSTR pszText) = 0;
  virtual HRESULT TxGetCurTargetX(LONG *) = 0;
  virtual HRESULT TxGetBaseLinePos(LONG *) = 0;
  virtual HRESULT TxGetNaturalSize(DWORD dwAspect,HDC hdcDraw,HDC hicTargetDev,DVTARGETDEVICE *ptd,DWORD dwMode,const SIZEL *psizelExtent,LONG *pwidth,LONG *pheight) = 0;
  virtual HRESULT TxGetDropTarget(IDropTarget **ppDropTarget) = 0;
  virtual HRESULT OnTxPropertyBitsChange(DWORD dwMask,DWORD dwBits) = 0;
  virtual HRESULT TxGetCachedSize(DWORD *pdwWidth,DWORD *pdwHeight)=0;
};

class ITextHost : public IUnknown {
public:
  virtual HDC TxGetDC() = 0;
  virtual INT TxReleaseDC(HDC hdc) = 0;
  virtual WINBOOL TxShowScrollBar(INT fnBar,WINBOOL fShow) = 0;
  virtual WINBOOL TxEnableScrollBar (INT fuSBFlags,INT fuArrowflags) = 0;
  virtual WINBOOL TxSetScrollRange(INT fnBar,LONG nMinPos,INT nMaxPos,WINBOOL fRedraw) = 0;
  virtual WINBOOL TxSetScrollPos (INT fnBar,INT nPos,WINBOOL fRedraw) = 0;
  virtual void TxInvalidateRect(LPCRECT prc,WINBOOL fMode) = 0;
  virtual void TxViewChange(WINBOOL fUpdate) = 0;
  virtual WINBOOL TxCreateCaret(HBITMAP hbmp,INT xWidth,INT yHeight) = 0;
  virtual WINBOOL TxShowCaret(WINBOOL fShow) = 0;
  virtual WINBOOL TxSetCaretPos(INT x,INT y) = 0;
  virtual WINBOOL TxSetTimer(UINT idTimer,UINT uTimeout) = 0;
  virtual void TxKillTimer(UINT idTimer) = 0;
  virtual void TxScrollWindowEx (INT dx,INT dy,LPCRECT lprcScroll,LPCRECT lprcClip,HRGN hrgnUpdate,LPRECT lprcUpdate,UINT fuScroll) = 0;
  virtual void TxSetCapture(WINBOOL fCapture) = 0;
  virtual void TxSetFocus() = 0;
  virtual void TxSetCursor(HCURSOR hcur,WINBOOL fText) = 0;
  virtual WINBOOL TxScreenToClient (LPPOINT lppt) = 0;
  virtual WINBOOL TxClientToScreen (LPPOINT lppt) = 0;
  virtual HRESULT TxActivate(LONG *plOldState) = 0;
  virtual HRESULT TxDeactivate(LONG lNewState) = 0;
  virtual HRESULT TxGetClientRect(LPRECT prc) = 0;
  virtual HRESULT TxGetViewInset(LPRECT prc) = 0;
  virtual HRESULT TxGetCharFormat(const CHARFORMATW **ppCF) = 0;
  virtual HRESULT TxGetParaFormat(const PARAFORMAT **ppPF) = 0;
  virtual COLORREF TxGetSysColor(int nIndex) = 0;
  virtual HRESULT TxGetBackStyle(TXTBACKSTYLE *pstyle) = 0;
  virtual HRESULT TxGetMaxLength(DWORD *plength) = 0;
  virtual HRESULT TxGetScrollBars(DWORD *pdwScrollBar) = 0;
  virtual HRESULT TxGetPasswordChar(TCHAR *pch) = 0;
  virtual HRESULT TxGetAcceleratorPos(LONG *pcp) = 0;
  virtual HRESULT TxGetExtent(LPSIZEL lpExtent) = 0;
  virtual HRESULT OnTxCharFormatChange (const CHARFORMATW *pcf) = 0;
  virtual HRESULT OnTxParaFormatChange (const PARAFORMAT *ppf) = 0;
  virtual HRESULT TxGetPropertyBits(DWORD dwMask,DWORD *pdwBits) = 0;
  virtual HRESULT TxNotify(DWORD iNotify,void *pv) = 0;
  virtual HIMC TxImmGetContext() = 0;
  virtual void TxImmReleaseContext(HIMC himc) = 0;
  virtual HRESULT TxGetSelectionBarWidth (LONG *lSelBarWidth) = 0;
};

STDAPI CreateTextServices(IUnknown *punkOuter,ITextHost *pITextHost,IUnknown **ppUnk);
typedef HRESULT (WINAPI *PCreateTextServices)(IUnknown *punkOuter,ITextHost *pITextHost,IUnknown **ppUnk);
#endif

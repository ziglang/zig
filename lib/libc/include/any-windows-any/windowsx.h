/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _INC_WINDOWSX
#define _INC_WINDOWSX

#ifdef __cplusplus
extern "C" {
#endif

#ifndef SNDMSG
#ifdef __cplusplus
#define SNDMSG ::SendMessage
#else
#define SNDMSG SendMessage
#endif
#endif

#define GetInstanceModule(hInstance) (HMODULE)(hInstance)
#define GlobalPtrHandle(lp) ((HGLOBAL)GlobalHandle(lp))
#define GlobalLockPtr(lp) ((WINBOOL)GlobalLock(GlobalPtrHandle(lp)))
#define GlobalUnlockPtr(lp) GlobalUnlock(GlobalPtrHandle(lp))
#define GlobalAllocPtr(flags,cb) (GlobalLock(GlobalAlloc((flags),(cb))))
#define GlobalReAllocPtr(lp,cbNew,flags) (GlobalUnlockPtr(lp),GlobalLock(GlobalReAlloc(GlobalPtrHandle(lp) ,(cbNew),(flags))))
#define GlobalFreePtr(lp) (GlobalUnlockPtr(lp),(WINBOOL)(ULONG_PTR)GlobalFree(GlobalPtrHandle(lp)))
#define DeletePen(hpen) DeleteObject((HGDIOBJ)(HPEN)(hpen))
#define SelectPen(hdc,hpen) ((HPEN)SelectObject((hdc),(HGDIOBJ)(HPEN)(hpen)))
#define GetStockPen(i) ((HPEN)GetStockObject(i))
#define DeleteBrush(hbr) DeleteObject((HGDIOBJ)(HBRUSH)(hbr))
#define SelectBrush(hdc,hbr) ((HBRUSH)SelectObject((hdc),(HGDIOBJ)(HBRUSH)(hbr)))
#define GetStockBrush(i) ((HBRUSH)GetStockObject(i))
#define DeleteRgn(hrgn) DeleteObject((HGDIOBJ)(HRGN)(hrgn))
#define CopyRgn(hrgnDst,hrgnSrc) CombineRgn(hrgnDst,hrgnSrc,0,RGN_COPY)
#define IntersectRgn(hrgnResult,hrgnA,hrgnB) CombineRgn(hrgnResult,hrgnA,hrgnB,RGN_AND)
#define SubtractRgn(hrgnResult,hrgnA,hrgnB) CombineRgn(hrgnResult,hrgnA,hrgnB,RGN_DIFF)
#define UnionRgn(hrgnResult,hrgnA,hrgnB) CombineRgn(hrgnResult,hrgnA,hrgnB,RGN_OR)
#define XorRgn(hrgnResult,hrgnA,hrgnB) CombineRgn(hrgnResult,hrgnA,hrgnB,RGN_XOR)
#define DeletePalette(hpal) DeleteObject((HGDIOBJ)(HPALETTE)(hpal))
#define DeleteFont(hfont) DeleteObject((HGDIOBJ)(HFONT)(hfont))
#define SelectFont(hdc,hfont) ((HFONT)SelectObject((hdc),(HGDIOBJ)(HFONT)(hfont)))
#define GetStockFont(i) ((HFONT)GetStockObject(i))
#define DeleteBitmap(hbm) DeleteObject((HGDIOBJ)(HBITMAP)(hbm))
#define SelectBitmap(hdc,hbm) ((HBITMAP)SelectObject((hdc),(HGDIOBJ)(HBITMAP)(hbm)))
#define InsetRect(lprc,dx,dy) InflateRect((lprc),-(dx),-(dy))
#define GetWindowInstance(hwnd) ((HMODULE)GetWindowLongPtr(hwnd,GWLP_HINSTANCE))
#define GetWindowStyle(hwnd) ((DWORD)GetWindowLong(hwnd,GWL_STYLE))
#define GetWindowExStyle(hwnd) ((DWORD)GetWindowLong(hwnd,GWL_EXSTYLE))
#define GetWindowOwner(hwnd) GetWindow(hwnd,GW_OWNER)
#define GetFirstChild(hwnd) GetTopWindow(hwnd)
#define GetFirstSibling(hwnd) GetWindow(hwnd,GW_HWNDFIRST)
#define GetLastSibling(hwnd) GetWindow(hwnd,GW_HWNDLAST)
#define GetNextSibling(hwnd) GetWindow(hwnd,GW_HWNDNEXT)
#define GetPrevSibling(hwnd) GetWindow(hwnd,GW_HWNDPREV)
#define GetWindowID(hwnd) GetDlgCtrlID(hwnd)
#define SetWindowRedraw(hwnd,fRedraw) ((void)SNDMSG(hwnd,WM_SETREDRAW,(WPARAM)(WINBOOL)(fRedraw),(LPARAM)0))
#define SubclassWindow(hwnd,lpfn) ((WNDPROC)SetWindowLongPtr((hwnd),GWLP_WNDPROC,(LPARAM)(WNDPROC)(lpfn)))
#define IsMinimized(hwnd) IsIconic(hwnd)
#define IsMaximized(hwnd) IsZoomed(hwnd)
#define IsRestored(hwnd) (!(GetWindowStyle(hwnd) & (WS_MINIMIZE | WS_MAXIMIZE)))
#define SetWindowFont(hwnd,hfont,fRedraw) FORWARD_WM_SETFONT((hwnd),(hfont),(fRedraw),SNDMSG)
#define GetWindowFont(hwnd) FORWARD_WM_GETFONT((hwnd),SNDMSG)
#define MapWindowRect(hwndFrom,hwndTo,lprc) MapWindowPoints((hwndFrom),(hwndTo),(POINT *)(lprc),2)
#define IsLButtonDown() (GetKeyState(VK_LBUTTON) < 0)
#define IsRButtonDown() (GetKeyState(VK_RBUTTON) < 0)
#define IsMButtonDown() (GetKeyState(VK_MBUTTON) < 0)
#define SubclassDialog(hwndDlg,lpfn) (SetWindowLongPtr(hwndDlg,DWLP_DLGPROC,(LPARAM)(lpfn)))
#define SetDlgMsgResult(hwnd,msg,result) (((msg)==WM_CTLCOLORMSGBOX || (msg)==WM_CTLCOLOREDIT || (msg)==WM_CTLCOLORLISTBOX || (msg)==WM_CTLCOLORBTN || (msg)==WM_CTLCOLORDLG || (msg)==WM_CTLCOLORSCROLLBAR || (msg)==WM_CTLCOLORSTATIC || (msg)==WM_COMPAREITEM || (msg)==WM_VKEYTOITEM || (msg)==WM_CHARTOITEM || (msg)==WM_QUERYDRAGICON || (msg)==WM_INITDIALOG) ? (WINBOOL)(result) : (SetWindowLongPtr((hwnd),DWLP_MSGRESULT,(LPARAM)(LRESULT)(result)),TRUE))
#define DefDlgProcEx(hwnd,msg,wParam,lParam,pfRecursion) (*(pfRecursion) = TRUE,DefDlgProc(hwnd,msg,wParam,lParam))
#define CheckDefDlgRecursion(pfRecursion) if (*(pfRecursion)) { *(pfRecursion) = FALSE; return FALSE; }
#define HANDLE_MSG(hwnd,message,fn) case (message): return HANDLE_##message((hwnd),(wParam),(lParam),(fn))
#define HANDLE_WM_COMPACTING(hwnd,wParam,lParam,fn) ((fn)((hwnd),(UINT)(wParam)),(LRESULT)0)
#define FORWARD_WM_COMPACTING(hwnd,compactRatio,fn) (void)(fn)((hwnd),WM_COMPACTING,(WPARAM)(UINT)(compactRatio),(LPARAM)0)
#define HANDLE_WM_WININICHANGE(hwnd,wParam,lParam,fn) ((fn)((hwnd),(LPCTSTR)(lParam)),(LRESULT)0)
#define FORWARD_WM_WININICHANGE(hwnd,lpszSectionName,fn) (void)(fn)((hwnd),WM_WININICHANGE,(WPARAM)0,(LPARAM)(LPCTSTR)(lpszSectionName))
#define HANDLE_WM_SYSCOLORCHANGE(hwnd,wParam,lParam,fn) ((fn)(hwnd),(LRESULT)0)
#define FORWARD_WM_SYSCOLORCHANGE(hwnd,fn) (void)(fn)((hwnd),WM_SYSCOLORCHANGE,(WPARAM)0,(LPARAM)0)
#define HANDLE_WM_QUERYNEWPALETTE(hwnd,wParam,lParam,fn) MAKELRESULT((WINBOOL)(fn)(hwnd),(LRESULT)0)
#define FORWARD_WM_QUERYNEWPALETTE(hwnd,fn) (WINBOOL)(DWORD)(fn)((hwnd),WM_QUERYNEWPALETTE,(WPARAM)0,(LPARAM)0)
#define HANDLE_WM_PALETTEISCHANGING(hwnd,wParam,lParam,fn) ((fn)((hwnd),(HWND)(wParam)),(LRESULT)0)
#define FORWARD_WM_PALETTEISCHANGING(hwnd,hwndPaletteChange,fn) (void)(fn)((hwnd),WM_PALETTEISCHANGING,(WPARAM)(HWND)(hwndPaletteChange),(LPARAM)0)
#define HANDLE_WM_PALETTECHANGED(hwnd,wParam,lParam,fn) ((fn)((hwnd),(HWND)(wParam)),(LRESULT)0)
#define FORWARD_WM_PALETTECHANGED(hwnd,hwndPaletteChange,fn) (void)(fn)((hwnd),WM_PALETTECHANGED,(WPARAM)(HWND)(hwndPaletteChange),(LPARAM)0)
#define HANDLE_WM_FONTCHANGE(hwnd,wParam,lParam,fn) ((fn)(hwnd),(LRESULT)0)
#define FORWARD_WM_FONTCHANGE(hwnd,fn) (void)(fn)((hwnd),WM_FONTCHANGE,(WPARAM)0,(LPARAM)0)
#define HANDLE_WM_SPOOLERSTATUS(hwnd,wParam,lParam,fn) ((fn)((hwnd),(UINT)(wParam),(int)(short)LOWORD(lParam)),(LRESULT)0)
#define FORWARD_WM_SPOOLERSTATUS(hwnd,status,cJobInQueue,fn) (void)(fn)((hwnd),WM_SPOOLERSTATUS,(WPARAM)(status),MAKELPARAM((cJobInQueue),0))
#define HANDLE_WM_DEVMODECHANGE(hwnd,wParam,lParam,fn) ((fn)((hwnd),(LPCTSTR)(lParam)),(LRESULT)0)
#define FORWARD_WM_DEVMODECHANGE(hwnd,lpszDeviceName,fn) (void)(fn)((hwnd),WM_DEVMODECHANGE,(WPARAM)0,(LPARAM)(LPCTSTR)(lpszDeviceName))
#define HANDLE_WM_TIMECHANGE(hwnd,wParam,lParam,fn) ((fn)(hwnd),(LRESULT)0)
#define FORWARD_WM_TIMECHANGE(hwnd,fn) (void)(fn)((hwnd),WM_TIMECHANGE,(WPARAM)0,(LPARAM)0)
#define HANDLE_WM_POWER(hwnd,wParam,lParam,fn) ((fn)((hwnd),(int)(wParam)),(LRESULT)0)
#define FORWARD_WM_POWER(hwnd,code,fn) (void)(fn)((hwnd),WM_POWER,(WPARAM)(int)(code),(LPARAM)0)
#define HANDLE_WM_QUERYENDSESSION(hwnd,wParam,lParam,fn) MAKELRESULT((WINBOOL)(fn)(hwnd),(LRESULT)0)
#define FORWARD_WM_QUERYENDSESSION(hwnd,fn) (WINBOOL)(DWORD)(fn)((hwnd),WM_QUERYENDSESSION,(WPARAM)0,(LPARAM)0)
#define HANDLE_WM_ENDSESSION(hwnd,wParam,lParam,fn) ((fn)((hwnd),(WINBOOL)(wParam)),(LRESULT)0)
#define FORWARD_WM_ENDSESSION(hwnd,fEnding,fn) (void)(fn)((hwnd),WM_ENDSESSION,(WPARAM)(WINBOOL)(fEnding),(LPARAM)0)
#define HANDLE_WM_QUIT(hwnd,wParam,lParam,fn) ((fn)((hwnd),(int)(wParam)),(LRESULT)0)
#define FORWARD_WM_QUIT(hwnd,exitCode,fn) (void)(fn)((hwnd),WM_QUIT,(WPARAM)(exitCode),(LPARAM)0)
#define HANDLE_WM_SYSTEMERROR(hwnd,wParam,lParam,fn) (LRESULT)0
#define FORWARD_WM_SYSTEMERROR(hwnd,errCode,fn) (LRESULT)0

#define HANDLE_WM_CREATE(hwnd,wParam,lParam,fn) (LRESULT)((fn)((hwnd),(LPCREATESTRUCT)(lParam)) ? 0 : -1)
#define FORWARD_WM_CREATE(hwnd,lpCreateStruct,fn) (WINBOOL)(DWORD)(fn)((hwnd),WM_CREATE,(WPARAM)0,(LPARAM)(LPCREATESTRUCT)(lpCreateStruct))

#define HANDLE_WM_NCCREATE(hwnd,wParam,lParam,fn) (LRESULT)(DWORD)(WINBOOL)(fn)((hwnd),(LPCREATESTRUCT)(lParam))
#define FORWARD_WM_NCCREATE(hwnd,lpCreateStruct,fn) (WINBOOL)(DWORD)(fn)((hwnd),WM_NCCREATE,(WPARAM)0,(LPARAM)(LPCREATESTRUCT)(lpCreateStruct))

#define HANDLE_WM_DESTROY(hwnd,wParam,lParam,fn) ((fn)(hwnd),(LRESULT)0)
#define FORWARD_WM_DESTROY(hwnd,fn) (void)(fn)((hwnd),WM_DESTROY,(WPARAM)0,(LPARAM)0)

#define HANDLE_WM_NCDESTROY(hwnd,wParam,lParam,fn) ((fn)(hwnd),(LRESULT)0)
#define FORWARD_WM_NCDESTROY(hwnd,fn) (void)(fn)((hwnd),WM_NCDESTROY,(WPARAM)0,(LPARAM)0)

#define HANDLE_WM_SHOWWINDOW(hwnd,wParam,lParam,fn) ((fn)((hwnd),(WINBOOL)(wParam),(UINT)(lParam)),(LRESULT)0)
#define FORWARD_WM_SHOWWINDOW(hwnd,fShow,status,fn) (void)(fn)((hwnd),WM_SHOWWINDOW,(WPARAM)(WINBOOL)(fShow),(LPARAM)(UINT)(status))

#define HANDLE_WM_SETREDRAW(hwnd,wParam,lParam,fn) ((fn)((hwnd),(WINBOOL)(wParam)),(LRESULT)0)
#define FORWARD_WM_SETREDRAW(hwnd,fRedraw,fn) (void)(fn)((hwnd),WM_SETREDRAW,(WPARAM)(WINBOOL)(fRedraw),(LPARAM)0)

#define HANDLE_WM_ENABLE(hwnd,wParam,lParam,fn) ((fn)((hwnd),(WINBOOL)(wParam)),(LRESULT)0)
#define FORWARD_WM_ENABLE(hwnd,fEnable,fn) (void)(fn)((hwnd),WM_ENABLE,(WPARAM)(WINBOOL)(fEnable),(LPARAM)0)

#define HANDLE_WM_SETTEXT(hwnd,wParam,lParam,fn) ((fn)((hwnd),(LPCTSTR)(lParam)),(LRESULT)0)
#define FORWARD_WM_SETTEXT(hwnd,lpszText,fn) (void)(fn)((hwnd),WM_SETTEXT,(WPARAM)0,(LPARAM)(LPCTSTR)(lpszText))

#define HANDLE_WM_GETTEXT(hwnd,wParam,lParam,fn) (LRESULT)(DWORD)(int)(fn)((hwnd),(int)(wParam),(LPTSTR)(lParam))
#define FORWARD_WM_GETTEXT(hwnd,cchTextMax,lpszText,fn) (int)(DWORD)(fn)((hwnd),WM_GETTEXT,(WPARAM)(int)(cchTextMax),(LPARAM)(LPTSTR)(lpszText))

#define HANDLE_WM_GETTEXTLENGTH(hwnd,wParam,lParam,fn) (LRESULT)(DWORD)(int)(fn)(hwnd)
#define FORWARD_WM_GETTEXTLENGTH(hwnd,fn) (int)(DWORD)(fn)((hwnd),WM_GETTEXTLENGTH,(WPARAM)0,(LPARAM)0)

#define HANDLE_WM_WINDOWPOSCHANGING(hwnd,wParam,lParam,fn) (LRESULT)(DWORD)(WINBOOL)(fn)((hwnd),(LPWINDOWPOS)(lParam))
#define FORWARD_WM_WINDOWPOSCHANGING(hwnd,lpwpos,fn) (WINBOOL)(DWORD)(fn)((hwnd),WM_WINDOWPOSCHANGING,(WPARAM)0,(LPARAM)(LPWINDOWPOS)(lpwpos))

#define HANDLE_WM_WINDOWPOSCHANGED(hwnd,wParam,lParam,fn) ((fn)((hwnd),(const LPWINDOWPOS)(lParam)),(LRESULT)0)
#define FORWARD_WM_WINDOWPOSCHANGED(hwnd,lpwpos,fn) (void)(fn)((hwnd),WM_WINDOWPOSCHANGED,(WPARAM)0,(LPARAM)(const LPWINDOWPOS)(lpwpos))

#define HANDLE_WM_MOVE(hwnd,wParam,lParam,fn) ((fn)((hwnd),(int)(short)LOWORD(lParam),(int)(short)HIWORD(lParam)),(LRESULT)0)
#define FORWARD_WM_MOVE(hwnd,x,y,fn) (void)(fn)((hwnd),WM_MOVE,(WPARAM)0,MAKELPARAM((x),(y)))

#define HANDLE_WM_SIZE(hwnd,wParam,lParam,fn) ((fn)((hwnd),(UINT)(wParam),(int)(short)LOWORD(lParam),(int)(short)HIWORD(lParam)),(LRESULT)0)
#define FORWARD_WM_SIZE(hwnd,state,cx,cy,fn) (void)(fn)((hwnd),WM_SIZE,(WPARAM)(UINT)(state),MAKELPARAM((cx),(cy)))

#define HANDLE_WM_CLOSE(hwnd,wParam,lParam,fn) ((fn)(hwnd),(LRESULT)0)
#define FORWARD_WM_CLOSE(hwnd,fn) (void)(fn)((hwnd),WM_CLOSE,(WPARAM)0,(LPARAM)0)

#define HANDLE_WM_QUERYOPEN(hwnd,wParam,lParam,fn) MAKELRESULT((WINBOOL)(fn)(hwnd),0)
#define FORWARD_WM_QUERYOPEN(hwnd,fn) (WINBOOL)(DWORD)(fn)((hwnd),WM_QUERYOPEN,(WPARAM)0,(LPARAM)0)

#define HANDLE_WM_GETMINMAXINFO(hwnd,wParam,lParam,fn) ((fn)((hwnd),(LPMINMAXINFO)(lParam)),(LRESULT)0)
#define FORWARD_WM_GETMINMAXINFO(hwnd,lpMinMaxInfo,fn) (void)(fn)((hwnd),WM_GETMINMAXINFO,(WPARAM)0,(LPARAM)(LPMINMAXINFO)(lpMinMaxInfo))

#define HANDLE_WM_PAINT(hwnd,wParam,lParam,fn) ((fn)(hwnd),(LRESULT)0)
#define FORWARD_WM_PAINT(hwnd,fn) (void)(fn)((hwnd),WM_PAINT,(WPARAM)0,(LPARAM)0)

#define HANDLE_WM_ERASEBKGND(hwnd,wParam,lParam,fn) (LRESULT)(DWORD)(WINBOOL)(fn)((hwnd),(HDC)(wParam))
#define FORWARD_WM_ERASEBKGND(hwnd,hdc,fn) (WINBOOL)(DWORD)(fn)((hwnd),WM_ERASEBKGND,(WPARAM)(HDC)(hdc),(LPARAM)0)

#define HANDLE_WM_ICONERASEBKGND(hwnd,wParam,lParam,fn) (LRESULT)(DWORD)(WINBOOL)(fn)((hwnd),(HDC)(wParam))
#define FORWARD_WM_ICONERASEBKGND(hwnd,hdc,fn) (WINBOOL)(DWORD)(fn)((hwnd),WM_ICONERASEBKGND,(WPARAM)(HDC)(hdc),(LPARAM)0)

#define HANDLE_WM_NCPAINT(hwnd,wParam,lParam,fn) ((fn)((hwnd),(HRGN)(wParam)),(LRESULT)0)
#define FORWARD_WM_NCPAINT(hwnd,hrgn,fn) (void)(fn)((hwnd),WM_NCPAINT,(WPARAM)(HRGN)(hrgn),(LPARAM)0)

#define HANDLE_WM_NCCALCSIZE(hwnd,wParam,lParam,fn) (LRESULT)(DWORD)(UINT)(fn)((hwnd),(WINBOOL)(wParam),(NCCALCSIZE_PARAMS *)(lParam))
#define FORWARD_WM_NCCALCSIZE(hwnd,fCalcValidRects,lpcsp,fn) (UINT)(DWORD)(fn)((hwnd),WM_NCCALCSIZE,(WPARAM)(fCalcValidRects),(LPARAM)(NCCALCSIZE_PARAMS *)(lpcsp))

#define HANDLE_WM_NCHITTEST(hwnd,wParam,lParam,fn) (LRESULT)(DWORD)(UINT)(fn)((hwnd),(int)(short)LOWORD(lParam),(int)(short)HIWORD(lParam))
#define FORWARD_WM_NCHITTEST(hwnd,x,y,fn) (UINT)(DWORD)(fn)((hwnd),WM_NCHITTEST,(WPARAM)0,MAKELPARAM((x),(y)))

#define HANDLE_WM_QUERYDRAGICON(hwnd,wParam,lParam,fn) (LRESULT)(DWORD)(UINT)(fn)(hwnd)
#define FORWARD_WM_QUERYDRAGICON(hwnd,fn) (HICON)(UINT)(DWORD)(fn)((hwnd),WM_QUERYDRAGICON,(WPARAM)0,(LPARAM)0)

#ifdef _INC_SHELLAPI

#define HANDLE_WM_DROPFILES(hwnd,wParam,lParam,fn) ((fn)((hwnd),(HDROP)(wParam)),(LRESULT)0)
#define FORWARD_WM_DROPFILES(hwnd,hdrop,fn) (void)(fn)((hwnd),WM_DROPFILES,(WPARAM)(HDROP)(hdrop),(LPARAM)0)
#endif

#define HANDLE_WM_ACTIVATE(hwnd,wParam,lParam,fn) ((fn)((hwnd),(UINT)LOWORD(wParam),(HWND)(lParam),(WINBOOL)HIWORD(wParam)),(LRESULT)0)
#define FORWARD_WM_ACTIVATE(hwnd,state,hwndActDeact,fMinimized,fn) (void)(fn)((hwnd),WM_ACTIVATE,MAKEWPARAM((state),(fMinimized)),(LPARAM)(HWND)(hwndActDeact))

#define HANDLE_WM_ACTIVATEAPP(hwnd,wParam,lParam,fn) ((fn)((hwnd),(WINBOOL)(wParam),(DWORD)(lParam)),(LRESULT)0)
#define FORWARD_WM_ACTIVATEAPP(hwnd,fActivate,dwThreadId,fn) (void)(fn)((hwnd),WM_ACTIVATEAPP,(WPARAM)(WINBOOL)(fActivate),(LPARAM)(dwThreadId))

#define HANDLE_WM_NCACTIVATE(hwnd,wParam,lParam,fn) (LRESULT)(DWORD)(WINBOOL)(fn)((hwnd),(WINBOOL)(wParam),(WPARAM)0,(LPARAM)0)
#define FORWARD_WM_NCACTIVATE(hwnd,fActive,hwndActDeact,fMinimized,fn) (WINBOOL)(DWORD)(fn)((hwnd),WM_NCACTIVATE,(WPARAM)(WINBOOL)(fActive),(LPARAM)0)

#define HANDLE_WM_SETFOCUS(hwnd,wParam,lParam,fn) ((fn)((hwnd),(HWND)(wParam)),(LRESULT)0)
#define FORWARD_WM_SETFOCUS(hwnd,hwndOldFocus,fn) (void)(fn)((hwnd),WM_SETFOCUS,(WPARAM)(HWND)(hwndOldFocus),(LPARAM)0)

#define HANDLE_WM_KILLFOCUS(hwnd,wParam,lParam,fn) ((fn)((hwnd),(HWND)(wParam)),(LRESULT)0)
#define FORWARD_WM_KILLFOCUS(hwnd,hwndNewFocus,fn) (void)(fn)((hwnd),WM_KILLFOCUS,(WPARAM)(HWND)(hwndNewFocus),(LPARAM)0)

#define HANDLE_WM_KEYDOWN(hwnd,wParam,lParam,fn) ((fn)((hwnd),(UINT)(wParam),TRUE,(int)(short)LOWORD(lParam),(UINT)HIWORD(lParam)),(LRESULT)0)
#define FORWARD_WM_KEYDOWN(hwnd,vk,cRepeat,flags,fn) (void)(fn)((hwnd),WM_KEYDOWN,(WPARAM)(UINT)(vk),MAKELPARAM((cRepeat),(flags)))

#define HANDLE_WM_KEYUP(hwnd,wParam,lParam,fn) ((fn)((hwnd),(UINT)(wParam),FALSE,(int)(short)LOWORD(lParam),(UINT)HIWORD(lParam)),(LRESULT)0)
#define FORWARD_WM_KEYUP(hwnd,vk,cRepeat,flags,fn) (void)(fn)((hwnd),WM_KEYUP,(WPARAM)(UINT)(vk),MAKELPARAM((cRepeat),(flags)))

#define HANDLE_WM_CHAR(hwnd,wParam,lParam,fn) ((fn)((hwnd),(TCHAR)(wParam),(int)(short)LOWORD(lParam)),(LRESULT)0)
#define FORWARD_WM_CHAR(hwnd,ch,cRepeat,fn) (void)(fn)((hwnd),WM_CHAR,(WPARAM)(TCHAR)(ch),MAKELPARAM((cRepeat),0))

#define HANDLE_WM_DEADCHAR(hwnd,wParam,lParam,fn) ((fn)((hwnd),(TCHAR)(wParam),(int)(short)LOWORD(lParam)),(LRESULT)0)
#define FORWARD_WM_DEADCHAR(hwnd,ch,cRepeat,fn) (void)(fn)((hwnd),WM_DEADCHAR,(WPARAM)(TCHAR)(ch),MAKELPARAM((cRepeat),0))

#define HANDLE_WM_SYSKEYDOWN(hwnd,wParam,lParam,fn) ((fn)((hwnd),(UINT)(wParam),TRUE,(int)(short)LOWORD(lParam),(UINT)HIWORD(lParam)),(LRESULT)0)
#define FORWARD_WM_SYSKEYDOWN(hwnd,vk,cRepeat,flags,fn) (void)(fn)((hwnd),WM_SYSKEYDOWN,(WPARAM)(UINT)(vk),MAKELPARAM((cRepeat),(flags)))

#define HANDLE_WM_SYSKEYUP(hwnd,wParam,lParam,fn) ((fn)((hwnd),(UINT)(wParam),FALSE,(int)(short)LOWORD(lParam),(UINT)HIWORD(lParam)),(LRESULT)0)
#define FORWARD_WM_SYSKEYUP(hwnd,vk,cRepeat,flags,fn) (void)(fn)((hwnd),WM_SYSKEYUP,(WPARAM)(UINT)(vk),MAKELPARAM((cRepeat),(flags)))

#define HANDLE_WM_SYSCHAR(hwnd,wParam,lParam,fn) ((fn)((hwnd),(TCHAR)(wParam),(int)(short)LOWORD(lParam)),(LRESULT)0)
#define FORWARD_WM_SYSCHAR(hwnd,ch,cRepeat,fn) (void)(fn)((hwnd),WM_SYSCHAR,(WPARAM)(TCHAR)(ch),MAKELPARAM((cRepeat),0))

#define HANDLE_WM_SYSDEADCHAR(hwnd,wParam,lParam,fn) ((fn)((hwnd),(TCHAR)(wParam),(int)(short)LOWORD(lParam)),(LRESULT)0)
#define FORWARD_WM_SYSDEADCHAR(hwnd,ch,cRepeat,fn) (void)(fn)((hwnd),WM_SYSDEADCHAR,(WPARAM)(TCHAR)(ch),MAKELPARAM((cRepeat),0))

#define HANDLE_WM_MOUSEMOVE(hwnd,wParam,lParam,fn) ((fn)((hwnd),(int)(short)LOWORD(lParam),(int)(short)HIWORD(lParam),(UINT)(wParam)),(LRESULT)0)
#define FORWARD_WM_MOUSEMOVE(hwnd,x,y,keyFlags,fn) (void)(fn)((hwnd),WM_MOUSEMOVE,(WPARAM)(UINT)(keyFlags),MAKELPARAM((x),(y)))

#define HANDLE_WM_LBUTTONDOWN(hwnd,wParam,lParam,fn) ((fn)((hwnd),FALSE,(int)(short)LOWORD(lParam),(int)(short)HIWORD(lParam),(UINT)(wParam)),(LRESULT)0)
#define FORWARD_WM_LBUTTONDOWN(hwnd,fDoubleClick,x,y,keyFlags,fn) (void)(fn)((hwnd),(fDoubleClick) ? WM_LBUTTONDBLCLK : WM_LBUTTONDOWN,(WPARAM)(UINT)(keyFlags),MAKELPARAM((x),(y)))

#define HANDLE_WM_LBUTTONDBLCLK(hwnd,wParam,lParam,fn) ((fn)((hwnd),TRUE,(int)(short)LOWORD(lParam),(int)(short)HIWORD(lParam),(UINT)(wParam)),(LRESULT)0)

#define HANDLE_WM_LBUTTONUP(hwnd,wParam,lParam,fn) ((fn)((hwnd),(int)(short)LOWORD(lParam),(int)(short)HIWORD(lParam),(UINT)(wParam)),(LRESULT)0)
#define FORWARD_WM_LBUTTONUP(hwnd,x,y,keyFlags,fn) (void)(fn)((hwnd),WM_LBUTTONUP,(WPARAM)(UINT)(keyFlags),MAKELPARAM((x),(y)))

#define HANDLE_WM_RBUTTONDOWN(hwnd,wParam,lParam,fn) ((fn)((hwnd),FALSE,(int)(short)LOWORD(lParam),(int)(short)HIWORD(lParam),(UINT)(wParam)),(LRESULT)0)
#define FORWARD_WM_RBUTTONDOWN(hwnd,fDoubleClick,x,y,keyFlags,fn) (void)(fn)((hwnd),(fDoubleClick) ? WM_RBUTTONDBLCLK : WM_RBUTTONDOWN,(WPARAM)(UINT)(keyFlags),MAKELPARAM((x),(y)))

#define HANDLE_WM_RBUTTONDBLCLK(hwnd,wParam,lParam,fn) ((fn)((hwnd),TRUE,(int)(short)LOWORD(lParam),(int)(short)HIWORD(lParam),(UINT)(wParam)),(LRESULT)0)

#define HANDLE_WM_RBUTTONUP(hwnd,wParam,lParam,fn) ((fn)((hwnd),(int)(short)LOWORD(lParam),(int)(short)HIWORD(lParam),(UINT)(wParam)),(LRESULT)0)
#define FORWARD_WM_RBUTTONUP(hwnd,x,y,keyFlags,fn) (void)(fn)((hwnd),WM_RBUTTONUP,(WPARAM)(UINT)(keyFlags),MAKELPARAM((x),(y)))

#define HANDLE_WM_MBUTTONDOWN(hwnd,wParam,lParam,fn) ((fn)((hwnd),FALSE,(int)(short)LOWORD(lParam),(int)(short)HIWORD(lParam),(UINT)(wParam)),(LRESULT)0)
#define FORWARD_WM_MBUTTONDOWN(hwnd,fDoubleClick,x,y,keyFlags,fn) (void)(fn)((hwnd),(fDoubleClick) ? WM_MBUTTONDBLCLK : WM_MBUTTONDOWN,(WPARAM)(UINT)(keyFlags),MAKELPARAM((x),(y)))

#define HANDLE_WM_MBUTTONDBLCLK(hwnd,wParam,lParam,fn) ((fn)((hwnd),TRUE,(int)(short)LOWORD(lParam),(int)(short)HIWORD(lParam),(UINT)(wParam)),(LRESULT)0)

#define HANDLE_WM_MBUTTONUP(hwnd,wParam,lParam,fn) ((fn)((hwnd),(int)(short)LOWORD(lParam),(int)(short)HIWORD(lParam),(UINT)(wParam)),(LRESULT)0)
#define FORWARD_WM_MBUTTONUP(hwnd,x,y,keyFlags,fn) (void)(fn)((hwnd),WM_MBUTTONUP,(WPARAM)(UINT)(keyFlags),MAKELPARAM((x),(y)))

#define HANDLE_WM_MOUSEWHEEL(hwnd,wParam,lParam,fn) ((fn)((hwnd),(int)(short)LOWORD(lParam),(int)(short)HIWORD(lParam),(int)(short)HIWORD(wParam),(UINT)(short)LOWORD(wParam)),(LRESULT)0)
#define FORWARD_WM_MOUSEWHEEL(hwnd,xPos,yPos,zDelta,fwKeys,fn) (void)(fn)((hwnd),WM_MOUSEWHEEL,MAKEWPARAM((fwKeys),(zDelta)),MAKELPARAM((x),(y)))

#define HANDLE_WM_NCMOUSEMOVE(hwnd,wParam,lParam,fn) ((fn)((hwnd),(int)(short)LOWORD(lParam),(int)(short)HIWORD(lParam),(UINT)(wParam)),(LRESULT)0)
#define FORWARD_WM_NCMOUSEMOVE(hwnd,x,y,codeHitTest,fn) (void)(fn)((hwnd),WM_NCMOUSEMOVE,(WPARAM)(UINT)(codeHitTest),MAKELPARAM((x),(y)))

#define HANDLE_WM_NCLBUTTONDOWN(hwnd,wParam,lParam,fn) ((fn)((hwnd),FALSE,(int)(short)LOWORD(lParam),(int)(short)HIWORD(lParam),(UINT)(wParam)),(LRESULT)0)
#define FORWARD_WM_NCLBUTTONDOWN(hwnd,fDoubleClick,x,y,codeHitTest,fn) (void)(fn)((hwnd),(fDoubleClick) ? WM_NCLBUTTONDBLCLK : WM_NCLBUTTONDOWN,(WPARAM)(UINT)(codeHitTest),MAKELPARAM((x),(y)))

#define HANDLE_WM_NCLBUTTONDBLCLK(hwnd,wParam,lParam,fn) ((fn)((hwnd),TRUE,(int)(short)LOWORD(lParam),(int)(short)HIWORD(lParam),(UINT)(wParam)),(LRESULT)0)

#define HANDLE_WM_NCLBUTTONUP(hwnd,wParam,lParam,fn) ((fn)((hwnd),(int)(short)LOWORD(lParam),(int)(short)HIWORD(lParam),(UINT)(wParam)),(LRESULT)0)
#define FORWARD_WM_NCLBUTTONUP(hwnd,x,y,codeHitTest,fn) (void)(fn)((hwnd),WM_NCLBUTTONUP,(WPARAM)(UINT)(codeHitTest),MAKELPARAM((x),(y)))

#define HANDLE_WM_NCRBUTTONDOWN(hwnd,wParam,lParam,fn) ((fn)((hwnd),FALSE,(int)(short)LOWORD(lParam),(int)(short)HIWORD(lParam),(UINT)(wParam)),(LRESULT)0)
#define FORWARD_WM_NCRBUTTONDOWN(hwnd,fDoubleClick,x,y,codeHitTest,fn) (void)(fn)((hwnd),(fDoubleClick) ? WM_NCRBUTTONDBLCLK : WM_NCRBUTTONDOWN,(WPARAM)(UINT)(codeHitTest),MAKELPARAM((x),(y)))

#define HANDLE_WM_NCRBUTTONDBLCLK(hwnd,wParam,lParam,fn) ((fn)((hwnd),TRUE,(int)(short)LOWORD(lParam),(int)(short)HIWORD(lParam),(UINT)(wParam)),(LRESULT)0)

#define HANDLE_WM_NCRBUTTONUP(hwnd,wParam,lParam,fn) ((fn)((hwnd),(int)(short)LOWORD(lParam),(int)(short)HIWORD(lParam),(UINT)(wParam)),(LRESULT)0)
#define FORWARD_WM_NCRBUTTONUP(hwnd,x,y,codeHitTest,fn) (void)(fn)((hwnd),WM_NCRBUTTONUP,(WPARAM)(UINT)(codeHitTest),MAKELPARAM((x),(y)))

#define HANDLE_WM_NCMBUTTONDOWN(hwnd,wParam,lParam,fn) ((fn)((hwnd),FALSE,(int)(short)LOWORD(lParam),(int)(short)HIWORD(lParam),(UINT)(wParam)),(LRESULT)0)
#define FORWARD_WM_NCMBUTTONDOWN(hwnd,fDoubleClick,x,y,codeHitTest,fn) (void)(fn)((hwnd),(fDoubleClick) ? WM_NCMBUTTONDBLCLK : WM_NCMBUTTONDOWN,(WPARAM)(UINT)(codeHitTest),MAKELPARAM((x),(y)))

#define HANDLE_WM_NCMBUTTONDBLCLK(hwnd,wParam,lParam,fn) ((fn)((hwnd),TRUE,(int)(short)LOWORD(lParam),(int)(short)HIWORD(lParam),(UINT)(wParam)),(LRESULT)0)

#define HANDLE_WM_NCMBUTTONUP(hwnd,wParam,lParam,fn) ((fn)((hwnd),(int)(short)LOWORD(lParam),(int)(short)HIWORD(lParam),(UINT)(wParam)),(LRESULT)0)
#define FORWARD_WM_NCMBUTTONUP(hwnd,x,y,codeHitTest,fn) (void)(fn)((hwnd),WM_NCMBUTTONUP,(WPARAM)(UINT)(codeHitTest),MAKELPARAM((x),(y)))

#define HANDLE_WM_MOUSEACTIVATE(hwnd,wParam,lParam,fn) (LRESULT)(DWORD)(int)(fn)((hwnd),(HWND)(wParam),(UINT)LOWORD(lParam),(UINT)HIWORD(lParam))
#define FORWARD_WM_MOUSEACTIVATE(hwnd,hwndTopLevel,codeHitTest,msg,fn) (int)(DWORD)(fn)((hwnd),WM_MOUSEACTIVATE,(WPARAM)(HWND)(hwndTopLevel),MAKELPARAM((codeHitTest),(msg)))

#define HANDLE_WM_CANCELMODE(hwnd,wParam,lParam,fn) ((fn)(hwnd),(LRESULT)0)
#define FORWARD_WM_CANCELMODE(hwnd,fn) (void)(fn)((hwnd),WM_CANCELMODE,(WPARAM)0,(LPARAM)0)

#define HANDLE_WM_TIMER(hwnd,wParam,lParam,fn) ((fn)((hwnd),(UINT)(wParam)),(LRESULT)0)
#define FORWARD_WM_TIMER(hwnd,id,fn) (void)(fn)((hwnd),WM_TIMER,(WPARAM)(UINT)(id),(LPARAM)0)

#define HANDLE_WM_INITMENU(hwnd,wParam,lParam,fn) ((fn)((hwnd),(HMENU)(wParam)),(LRESULT)0)
#define FORWARD_WM_INITMENU(hwnd,hMenu,fn) (void)(fn)((hwnd),WM_INITMENU,(WPARAM)(HMENU)(hMenu),(LPARAM)0)

#define HANDLE_WM_INITMENUPOPUP(hwnd,wParam,lParam,fn) ((fn)((hwnd),(HMENU)(wParam),(UINT)LOWORD(lParam),(WINBOOL)HIWORD(lParam)),(LRESULT)0)
#define FORWARD_WM_INITMENUPOPUP(hwnd,hMenu,item,fSystemMenu,fn) (void)(fn)((hwnd),WM_INITMENUPOPUP,(WPARAM)(HMENU)(hMenu),MAKELPARAM((item),(fSystemMenu)))

#define HANDLE_WM_MENUSELECT(hwnd,wParam,lParam,fn) ((fn)((hwnd),(HMENU)(lParam),(HIWORD(wParam) & MF_POPUP) ? 0 : (int)(LOWORD(wParam)),(HIWORD(wParam) & MF_POPUP) ? GetSubMenu((HMENU)lParam,LOWORD(wParam)) : (HMENU)0,(UINT)(((short)HIWORD(wParam)==-1) ? 0xFFFFFFFF : HIWORD(wParam))),(LRESULT)0)
#define FORWARD_WM_MENUSELECT(hwnd,hmenu,item,hmenuPopup,flags,fn) (void)(fn)((hwnd),WM_MENUSELECT,MAKEWPARAM((item),(flags)),(LPARAM)(HMENU)((hmenu) ? (hmenu) : (hmenuPopup)))

#define HANDLE_WM_MENUCHAR(hwnd,wParam,lParam,fn) (LRESULT)(DWORD)(fn)((hwnd),(UINT)(LOWORD(wParam)),(UINT)HIWORD(wParam),(HMENU)(lParam))
#define FORWARD_WM_MENUCHAR(hwnd,ch,flags,hmenu,fn) (DWORD)(fn)((hwnd),WM_MENUCHAR,MAKEWPARAM(flags,(WORD)(ch)),(LPARAM)(HMENU)(hmenu))

#define HANDLE_WM_COMMAND(hwnd,wParam,lParam,fn) ((fn)((hwnd),(int)(LOWORD(wParam)),(HWND)(lParam),(UINT)HIWORD(wParam)),(LRESULT)0)
#define FORWARD_WM_COMMAND(hwnd,id,hwndCtl,codeNotify,fn) (void)(fn)((hwnd),WM_COMMAND,MAKEWPARAM((UINT)(id),(UINT)(codeNotify)),(LPARAM)(HWND)(hwndCtl))

#define HANDLE_WM_HSCROLL(hwnd,wParam,lParam,fn) ((fn)((hwnd),(HWND)(lParam),(UINT)(LOWORD(wParam)),(int)(short)HIWORD(wParam)),(LRESULT)0)
#define FORWARD_WM_HSCROLL(hwnd,hwndCtl,code,pos,fn) (void)(fn)((hwnd),WM_HSCROLL,MAKEWPARAM((UINT)(int)(code),(UINT)(int)(pos)),(LPARAM)(HWND)(hwndCtl))

#define HANDLE_WM_VSCROLL(hwnd,wParam,lParam,fn) ((fn)((hwnd),(HWND)(lParam),(UINT)(LOWORD(wParam)),(int)(short)HIWORD(wParam)),(LRESULT)0)
#define FORWARD_WM_VSCROLL(hwnd,hwndCtl,code,pos,fn) (void)(fn)((hwnd),WM_VSCROLL,MAKEWPARAM((UINT)(int)(code),(UINT)(int)(pos)),(LPARAM)(HWND)(hwndCtl))

#define HANDLE_WM_CUT(hwnd,wParam,lParam,fn) ((fn)(hwnd),(LRESULT)0)
#define FORWARD_WM_CUT(hwnd,fn) (void)(fn)((hwnd),WM_CUT,(WPARAM)0,(LPARAM)0)

#define HANDLE_WM_COPY(hwnd,wParam,lParam,fn) ((fn)(hwnd),(LRESULT)0)
#define FORWARD_WM_COPY(hwnd,fn) (void)(fn)((hwnd),WM_COPY,(WPARAM)0,(LPARAM)0)

#define HANDLE_WM_PASTE(hwnd,wParam,lParam,fn) ((fn)(hwnd),(LRESULT)0)
#define FORWARD_WM_PASTE(hwnd,fn) (void)(fn)((hwnd),WM_PASTE,(WPARAM)0,(LPARAM)0)

#define HANDLE_WM_CLEAR(hwnd,wParam,lParam,fn) ((fn)(hwnd),(LRESULT)0)
#define FORWARD_WM_CLEAR(hwnd,fn) (void)(fn)((hwnd),WM_CLEAR,(WPARAM)0,(LPARAM)0)

#define HANDLE_WM_UNDO(hwnd,wParam,lParam,fn) ((fn)(hwnd),(LRESULT)0)
#define FORWARD_WM_UNDO(hwnd,fn) (void)(fn)((hwnd),WM_UNDO,(WPARAM)0,(LPARAM)0)

#define HANDLE_WM_RENDERFORMAT(hwnd,wParam,lParam,fn) (LRESULT)(UINT_PTR)(HANDLE)(fn)((hwnd),(UINT)(wParam))
#define FORWARD_WM_RENDERFORMAT(hwnd,fmt,fn) (HANDLE)(UINT_PTR)(fn)((hwnd),WM_RENDERFORMAT,(WPARAM)(UINT)(fmt),(LPARAM)0)

#define HANDLE_WM_RENDERALLFORMATS(hwnd,wParam,lParam,fn) ((fn)(hwnd),(LRESULT)0)
#define FORWARD_WM_RENDERALLFORMATS(hwnd,fn) (void)(fn)((hwnd),WM_RENDERALLFORMATS,(WPARAM)0,(LPARAM)0)

#define HANDLE_WM_DESTROYCLIPBOARD(hwnd,wParam,lParam,fn) ((fn)(hwnd),(LRESULT)0)
#define FORWARD_WM_DESTROYCLIPBOARD(hwnd,fn) (void)(fn)((hwnd),WM_DESTROYCLIPBOARD,(WPARAM)0,(LPARAM)0)

#define HANDLE_WM_DRAWCLIPBOARD(hwnd,wParam,lParam,fn) ((fn)(hwnd),(LRESULT)0)
#define FORWARD_WM_DRAWCLIPBOARD(hwnd,fn) (void)(fn)((hwnd),WM_DRAWCLIPBOARD,(WPARAM)0,(LPARAM)0)

#define HANDLE_WM_PAINTCLIPBOARD(hwnd,wParam,lParam,fn) ((fn)((hwnd),(HWND)(wParam),(const LPPAINTSTRUCT)GlobalLock((HGLOBAL)(lParam))),GlobalUnlock((HGLOBAL)(lParam)),(LRESULT)0)
#define FORWARD_WM_PAINTCLIPBOARD(hwnd,hwndCBViewer,lpPaintStruct,fn) (void)(fn)((hwnd),WM_PAINTCLIPBOARD,(WPARAM)(HWND)(hwndCBViewer),(LPARAM)(LPPAINTSTRUCT)(lpPaintStruct))

#define HANDLE_WM_SIZECLIPBOARD(hwnd,wParam,lParam,fn) ((fn)((hwnd),(HWND)(wParam),(const LPRECT)GlobalLock((HGLOBAL)(lParam))),GlobalUnlock((HGLOBAL)(lParam)),(LRESULT)0)
#define FORWARD_WM_SIZECLIPBOARD(hwnd,hwndCBViewer,lprc,fn) (void)(fn)((hwnd),WM_SIZECLIPBOARD,(WPARAM)(HWND)(hwndCBViewer),(LPARAM)(LPRECT)(lprc))

#define HANDLE_WM_VSCROLLCLIPBOARD(hwnd,wParam,lParam,fn) ((fn)((hwnd),(HWND)(wParam),(UINT)LOWORD(lParam),(int)(short)HIWORD(lParam)),(LRESULT)0)
#define FORWARD_WM_VSCROLLCLIPBOARD(hwnd,hwndCBViewer,code,pos,fn) (void)(fn)((hwnd),WM_VSCROLLCLIPBOARD,(WPARAM)(HWND)(hwndCBViewer),MAKELPARAM((code),(pos)))

#define HANDLE_WM_HSCROLLCLIPBOARD(hwnd,wParam,lParam,fn) ((fn)((hwnd),(HWND)(wParam),(UINT)LOWORD(lParam),(int)(short)HIWORD(lParam)),(LRESULT)0)
#define FORWARD_WM_HSCROLLCLIPBOARD(hwnd,hwndCBViewer,code,pos,fn) (void)(fn)((hwnd),WM_HSCROLLCLIPBOARD,(WPARAM)(HWND)(hwndCBViewer),MAKELPARAM((code),(pos)))

#define HANDLE_WM_ASKCBFORMATNAME(hwnd,wParam,lParam,fn) ((fn)((hwnd),(int)(wParam),(LPTSTR)(lParam)),(LRESULT)0)
#define FORWARD_WM_ASKCBFORMATNAME(hwnd,cchMax,rgchName,fn) (void)(fn)((hwnd),WM_ASKCBFORMATNAME,(WPARAM)(int)(cchMax),(LPARAM)(rgchName))

#define HANDLE_WM_CHANGECBCHAIN(hwnd,wParam,lParam,fn) ((fn)((hwnd),(HWND)(wParam),(HWND)(lParam)),(LRESULT)0)
#define FORWARD_WM_CHANGECBCHAIN(hwnd,hwndRemove,hwndNext,fn) (void)(fn)((hwnd),WM_CHANGECBCHAIN,(WPARAM)(HWND)(hwndRemove),(LPARAM)(HWND)(hwndNext))

#define HANDLE_WM_SETCURSOR(hwnd,wParam,lParam,fn) (LRESULT)(DWORD)(WINBOOL)(fn)((hwnd),(HWND)(wParam),(UINT)LOWORD(lParam),(UINT)HIWORD(lParam))
#define FORWARD_WM_SETCURSOR(hwnd,hwndCursor,codeHitTest,msg,fn) (WINBOOL)(DWORD)(fn)((hwnd),WM_SETCURSOR,(WPARAM)(HWND)(hwndCursor),MAKELPARAM((codeHitTest),(msg)))

#define HANDLE_WM_SYSCOMMAND(hwnd,wParam,lParam,fn) ((fn)((hwnd),(UINT)(wParam),(int)(short)LOWORD(lParam),(int)(short)HIWORD(lParam)),(LRESULT)0)
#define FORWARD_WM_SYSCOMMAND(hwnd,cmd,x,y,fn) (void)(fn)((hwnd),WM_SYSCOMMAND,(WPARAM)(UINT)(cmd),MAKELPARAM((x),(y)))

#define HANDLE_WM_MDICREATE(hwnd,wParam,lParam,fn) (LRESULT)(DWORD)(UINT)(fn)((hwnd),(LPMDICREATESTRUCT)(lParam))
#define FORWARD_WM_MDICREATE(hwnd,lpmcs,fn) (HWND)(UINT)(DWORD)(fn)((hwnd),WM_MDICREATE,(WPARAM)0,(LPARAM)(LPMDICREATESTRUCT)(lpmcs))

#define HANDLE_WM_MDIDESTROY(hwnd,wParam,lParam,fn) ((fn)((hwnd),(HWND)(wParam)),(LRESULT)0)
#define FORWARD_WM_MDIDESTROY(hwnd,hwndDestroy,fn) (void)(fn)((hwnd),WM_MDIDESTROY,(WPARAM)(hwndDestroy),(LPARAM)0)

#define HANDLE_WM_MDIACTIVATE(hwnd,wParam,lParam,fn) ((fn)((hwnd),(WINBOOL)(lParam==(LPARAM)hwnd),(HWND)(lParam),(HWND)(wParam)),(LRESULT)0)
#define FORWARD_WM_MDIACTIVATE(hwnd,fActive,hwndActivate,hwndDeactivate,fn) (void)(fn)(hwnd,WM_MDIACTIVATE,(WPARAM)(hwndDeactivate),(LPARAM)(hwndActivate))

#define HANDLE_WM_MDIRESTORE(hwnd,wParam,lParam,fn) ((fn)((hwnd),(HWND)(wParam)),(LRESULT)0)
#define FORWARD_WM_MDIRESTORE(hwnd,hwndRestore,fn) (void)(fn)((hwnd),WM_MDIRESTORE,(WPARAM)(hwndRestore),(LPARAM)0)

#define HANDLE_WM_MDINEXT(hwnd,wParam,lParam,fn) (LRESULT)(HWND)(fn)((hwnd),(HWND)(wParam),(WINBOOL)lParam)
#define FORWARD_WM_MDINEXT(hwnd,hwndCur,fPrev,fn) (HWND)(UINT_PTR)(fn)((hwnd),WM_MDINEXT,(WPARAM)(hwndCur),(LPARAM)(fPrev))

#define HANDLE_WM_MDIMAXIMIZE(hwnd,wParam,lParam,fn) ((fn)((hwnd),(HWND)(wParam)),(LRESULT)0)
#define FORWARD_WM_MDIMAXIMIZE(hwnd,hwndMaximize,fn) (void)(fn)((hwnd),WM_MDIMAXIMIZE,(WPARAM)(hwndMaximize),(LPARAM)0)

#define HANDLE_WM_MDITILE(hwnd,wParam,lParam,fn) (LRESULT)(DWORD)(fn)((hwnd),(UINT)(wParam))
#define FORWARD_WM_MDITILE(hwnd,cmd,fn) (WINBOOL)(DWORD)(fn)((hwnd),WM_MDITILE,(WPARAM)(cmd),(LPARAM)0)

#define HANDLE_WM_MDICASCADE(hwnd,wParam,lParam,fn) (LRESULT)(DWORD)(fn)((hwnd),(UINT)(wParam))
#define FORWARD_WM_MDICASCADE(hwnd,cmd,fn) (WINBOOL)(DWORD)(fn)((hwnd),WM_MDICASCADE,(WPARAM)(cmd),(LPARAM)0)

#define HANDLE_WM_MDIICONARRANGE(hwnd,wParam,lParam,fn) ((fn)(hwnd),(LRESULT)0)
#define FORWARD_WM_MDIICONARRANGE(hwnd,fn) (void)(fn)((hwnd),WM_MDIICONARRANGE,(WPARAM)0,(LPARAM)0)

#define HANDLE_WM_MDIGETACTIVE(hwnd,wParam,lParam,fn) (LRESULT)(UINT_PTR)(fn)(hwnd)
#define FORWARD_WM_MDIGETACTIVE(hwnd,fn) (HWND)(UINT_PTR)(fn)((hwnd),WM_MDIGETACTIVE,(WPARAM)0,(LPARAM)0)

#define HANDLE_WM_MDISETMENU(hwnd,wParam,lParam,fn) (LRESULT)(UINT_PTR)(fn)((hwnd),(WINBOOL)(wParam),(HMENU)(wParam),(HMENU)(lParam))
#define FORWARD_WM_MDISETMENU(hwnd,fRefresh,hmenuFrame,hmenuWindow,fn) (HMENU)(UINT_PTR)(fn)((hwnd),WM_MDISETMENU,(WPARAM)((fRefresh) ? (hmenuFrame) : 0),(LPARAM)(hmenuWindow))

#define HANDLE_WM_CHILDACTIVATE(hwnd,wParam,lParam,fn) ((fn)(hwnd),(LRESULT)0)
#define FORWARD_WM_CHILDACTIVATE(hwnd,fn) (void)(fn)((hwnd),WM_CHILDACTIVATE,(WPARAM)0,(LPARAM)0)

#define HANDLE_WM_INITDIALOG(hwnd,wParam,lParam,fn) (LRESULT)(DWORD)(UINT)(WINBOOL)(fn)((hwnd),(HWND)(wParam),lParam)
#define FORWARD_WM_INITDIALOG(hwnd,hwndFocus,lParam,fn) (WINBOOL)(DWORD)(fn)((hwnd),WM_INITDIALOG,(WPARAM)(HWND)(hwndFocus),(lParam))

#define HANDLE_WM_NEXTDLGCTL(hwnd,wParam,lParam,fn) (LRESULT)(UINT_PTR)(HWND)(fn)((hwnd),(HWND)(wParam),(WINBOOL)(lParam))
#define FORWARD_WM_NEXTDLGCTL(hwnd,hwndSetFocus,fNext,fn) (HWND)(UINT_PTR)(fn)((hwnd),WM_NEXTDLGCTL,(WPARAM)(HWND)(hwndSetFocus),(LPARAM)(fNext))

#define HANDLE_WM_PARENTNOTIFY(hwnd,wParam,lParam,fn) ((fn)((hwnd),(UINT)LOWORD(wParam),(HWND)(lParam),(UINT)HIWORD(wParam)),(LRESULT)0)
#define FORWARD_WM_PARENTNOTIFY(hwnd,msg,hwndChild,idChild,fn) (void)(fn)((hwnd),WM_PARENTNOTIFY,MAKEWPARAM(msg,idChild),(LPARAM)(hwndChild))

#define HANDLE_WM_ENTERIDLE(hwnd,wParam,lParam,fn) ((fn)((hwnd),(UINT)(wParam),(HWND)(lParam)),(LRESULT)0)
#define FORWARD_WM_ENTERIDLE(hwnd,source,hwndSource,fn) (void)(fn)((hwnd),WM_ENTERIDLE,(WPARAM)(UINT)(source),(LPARAM)(HWND)(hwndSource))

#define HANDLE_WM_GETDLGCODE(hwnd,wParam,lParam,fn) (LRESULT)(DWORD)(UINT)(fn)(hwnd,(LPMSG)(lParam))
#define FORWARD_WM_GETDLGCODE(hwnd,lpmsg,fn) (UINT)(DWORD)(fn)((hwnd),WM_GETDLGCODE,(lpmsg ? lpmsg->wParam : 0),(LPARAM)(LPMSG)(lpmsg))

#define HANDLE_WM_CTLCOLORMSGBOX(hwnd,wParam,lParam,fn) (LRESULT)(UINT_PTR)(HBRUSH)(fn)((hwnd),(HDC)(wParam),(HWND)(lParam),CTLCOLOR_MSGBOX)
#define FORWARD_WM_CTLCOLORMSGBOX(hwnd,hdc,hwndChild,fn) (HBRUSH)(UINT_PTR)(fn)((hwnd),WM_CTLCOLORMSGBOX,(WPARAM)(HDC)(hdc),(LPARAM)(HWND)(hwndChild))

#define HANDLE_WM_CTLCOLOREDIT(hwnd,wParam,lParam,fn) (LRESULT)(UINT_PTR)(HBRUSH)(fn)((hwnd),(HDC)(wParam),(HWND)(lParam),CTLCOLOR_EDIT)
#define FORWARD_WM_CTLCOLOREDIT(hwnd,hdc,hwndChild,fn) (HBRUSH)(UINT_PTR)(fn)((hwnd),WM_CTLCOLOREDIT,(WPARAM)(HDC)(hdc),(LPARAM)(HWND)(hwndChild))

#define HANDLE_WM_CTLCOLORLISTBOX(hwnd,wParam,lParam,fn) (LRESULT)(UINT_PTR)(HBRUSH)(fn)((hwnd),(HDC)(wParam),(HWND)(lParam),CTLCOLOR_LISTBOX)
#define FORWARD_WM_CTLCOLORLISTBOX(hwnd,hdc,hwndChild,fn) (HBRUSH)(UINT_PTR)(fn)((hwnd),WM_CTLCOLORLISTBOX,(WPARAM)(HDC)(hdc),(LPARAM)(HWND)(hwndChild))

#define HANDLE_WM_CTLCOLORBTN(hwnd,wParam,lParam,fn) (LRESULT)(UINT_PTR)(HBRUSH)(fn)((hwnd),(HDC)(wParam),(HWND)(lParam),CTLCOLOR_BTN)
#define FORWARD_WM_CTLCOLORBTN(hwnd,hdc,hwndChild,fn) (HBRUSH)(UINT_PTR)(fn)((hwnd),WM_CTLCOLORBTN,(WPARAM)(HDC)(hdc),(LPARAM)(HWND)(hwndChild))

#define HANDLE_WM_CTLCOLORDLG(hwnd,wParam,lParam,fn) (LRESULT)(UINT_PTR)(HBRUSH)(fn)((hwnd),(HDC)(wParam),(HWND)(lParam),CTLCOLOR_DLG)
#define FORWARD_WM_CTLCOLORDLG(hwnd,hdc,hwndChild,fn) (HBRUSH)(UINT_PTR)(fn)((hwnd),WM_CTLCOLORDLG,(WPARAM)(HDC)(hdc),(LPARAM)(HWND)(hwndChild))

#define HANDLE_WM_CTLCOLORSCROLLBAR(hwnd,wParam,lParam,fn) (LRESULT)(UINT_PTR)(HBRUSH)(fn)((hwnd),(HDC)(wParam),(HWND)(lParam),CTLCOLOR_SCROLLBAR)
#define FORWARD_WM_CTLCOLORSCROLLBAR(hwnd,hdc,hwndChild,fn) (HBRUSH)(UINT_PTR)(fn)((hwnd),WM_CTLCOLORSCROLLBAR,(WPARAM)(HDC)(hdc),(LPARAM)(HWND)(hwndChild))

#define HANDLE_WM_CTLCOLORSTATIC(hwnd,wParam,lParam,fn) (LRESULT)(UINT_PTR)(HBRUSH)(fn)((hwnd),(HDC)(wParam),(HWND)(lParam),CTLCOLOR_STATIC)
#define FORWARD_WM_CTLCOLORSTATIC(hwnd,hdc,hwndChild,fn) (HBRUSH)(UINT_PTR)(fn)((hwnd),WM_CTLCOLORSTATIC,(WPARAM)(HDC)(hdc),(LPARAM)(HWND)(hwndChild))

#define HANDLE_WM_SETFONT(hwnd,wParam,lParam,fn) ((fn)((hwnd),(HFONT)(wParam),(WINBOOL)(lParam)),(LRESULT)0)
#define FORWARD_WM_SETFONT(hwnd,hfont,fRedraw,fn) (void)(fn)((hwnd),WM_SETFONT,(WPARAM)(HFONT)(hfont),(LPARAM)(WINBOOL)(fRedraw))

#define HANDLE_WM_GETFONT(hwnd,wParam,lParam,fn) (LRESULT)(UINT_PTR)(HFONT)(fn)(hwnd)
#define FORWARD_WM_GETFONT(hwnd,fn) (HFONT)(UINT_PTR)(fn)((hwnd),WM_GETFONT,(WPARAM)0,(LPARAM)0)

#define HANDLE_WM_DRAWITEM(hwnd,wParam,lParam,fn) ((fn)((hwnd),(const DRAWITEMSTRUCT *)(lParam)),(LRESULT)0)
#define FORWARD_WM_DRAWITEM(hwnd,lpDrawItem,fn) (void)(fn)((hwnd),WM_DRAWITEM,(WPARAM)(((const DRAWITEMSTRUCT *)lpDrawItem)->CtlID),(LPARAM)(const DRAWITEMSTRUCT *)(lpDrawItem))

#define HANDLE_WM_MEASUREITEM(hwnd,wParam,lParam,fn) ((fn)((hwnd),(MEASUREITEMSTRUCT *)(lParam)),(LRESULT)0)
#define FORWARD_WM_MEASUREITEM(hwnd,lpMeasureItem,fn) (void)(fn)((hwnd),WM_MEASUREITEM,(WPARAM)(((MEASUREITEMSTRUCT *)lpMeasureItem)->CtlID),(LPARAM)(MEASUREITEMSTRUCT *)(lpMeasureItem))

#define HANDLE_WM_DELETEITEM(hwnd,wParam,lParam,fn) ((fn)((hwnd),(const DELETEITEMSTRUCT *)(lParam)),(LRESULT)0)
#define FORWARD_WM_DELETEITEM(hwnd,lpDeleteItem,fn) (void)(fn)((hwnd),WM_DELETEITEM,(WPARAM)(((const DELETEITEMSTRUCT *)(lpDeleteItem))->CtlID),(LPARAM)(const DELETEITEMSTRUCT *)(lpDeleteItem))

#define HANDLE_WM_COMPAREITEM(hwnd,wParam,lParam,fn) (LRESULT)(DWORD)(int)(fn)((hwnd),(const COMPAREITEMSTRUCT *)(lParam))
#define FORWARD_WM_COMPAREITEM(hwnd,lpCompareItem,fn) (int)(DWORD)(fn)((hwnd),WM_COMPAREITEM,(WPARAM)(((const COMPAREITEMSTRUCT *)(lpCompareItem))->CtlID),(LPARAM)(const COMPAREITEMSTRUCT *)(lpCompareItem))

#define HANDLE_WM_VKEYTOITEM(hwnd,wParam,lParam,fn) (LRESULT)(DWORD)(int)(fn)((hwnd),(UINT)LOWORD(wParam),(HWND)(lParam),(int)(short)HIWORD(wParam))
#define FORWARD_WM_VKEYTOITEM(hwnd,vk,hwndListBox,iCaret,fn) (int)(DWORD)(fn)((hwnd),WM_VKEYTOITEM,MAKEWPARAM((vk),(iCaret)),(LPARAM)(hwndListBox))

#define HANDLE_WM_CHARTOITEM(hwnd,wParam,lParam,fn) (LRESULT)(DWORD)(int)(fn)((hwnd),(UINT)LOWORD(wParam),(HWND)(lParam),(int)(short)HIWORD(wParam))
#define FORWARD_WM_CHARTOITEM(hwnd,ch,hwndListBox,iCaret,fn) (int)(DWORD)(fn)((hwnd),WM_CHARTOITEM,MAKEWPARAM((UINT)(ch),(UINT)(iCaret)),(LPARAM)(hwndListBox))

#define HANDLE_WM_QUEUESYNC(hwnd,wParam,lParam,fn) ((fn)(hwnd),(LRESULT)0)
#define FORWARD_WM_QUEUESYNC(hwnd,fn) (void)(fn)((hwnd),WM_QUEUESYNC,(WPARAM)0,(LPARAM)0)
#define HANDLE_WM_COMMNOTIFY(hwnd,wParam,lParam,fn) ((fn)((hwnd),(int)(wParam),(UINT)LOWORD(lParam)),(LRESULT)0)
#define FORWARD_WM_COMMNOTIFY(hwnd,cid,flags,fn) (void)(fn)((hwnd),WM_COMMNOTIFY,(WPARAM)(cid),MAKELPARAM((flags),0))

#define HANDLE_WM_DISPLAYCHANGE(hwnd,wParam,lParam,fn) ((fn)((hwnd),(UINT)(wParam),(UINT)LOWORD(lParam),(UINT)HIWORD(wParam)),(LRESULT)0)
#define FORWARD_WM_DISPLAYCHANGE(hwnd,bitsPerPixel,cxScreen,cyScreen,fn) (void)(fn)((hwnd),WM_DISPLAYCHANGE,(WPARAM)(UINT)(bitsPerPixel),(LPARAM)MAKELPARAM((UINT)(cxScreen),(UINT)(cyScreen)))

#define HANDLE_WM_DEVICECHANGE(hwnd,wParam,lParam,fn) (LRESULT)(DWORD)(WINBOOL)(fn)((hwnd),(UINT)(wParam),(DWORD)(wParam))
#define FORWARD_WM_DEVICECHANGE(hwnd,uEvent,dwEventData,fn) (WINBOOL)(DWORD)(fn)((hwnd),WM_DEVICECHANGE,(WPARAM)(UINT)(uEvent),(LPARAM)(DWORD)(dwEventData))

#define HANDLE_WM_CONTEXTMENU(hwnd,wParam,lParam,fn) ((fn)((hwnd),(HWND)(wParam),(UINT)LOWORD(lParam),(UINT)HIWORD(lParam)),(LRESULT)0)
#define FORWARD_WM_CONTEXTMENU(hwnd,hwndContext,xPos,yPos,fn) (void)(fn)((hwnd),WM_CONTEXTMENU,(WPARAM)(HWND)(hwndContext),MAKELPARAM((UINT)(xPos),(UINT)(yPos)))

#define HANDLE_WM_COPYDATA(hwnd,wParam,lParam,fn) ((fn)((hwnd),(HWND)(wParam),(PCOPYDATASTRUCT)lParam),(LRESULT)0)
#define FORWARD_WM_COPYDATA(hwnd,hwndFrom,pcds,fn) (WINBOOL)(UINT)(DWORD)(fn)((hwnd),WM_COPYDATA,(WPARAM)(hwndFrom),(LPARAM)(pcds))

#define HANDLE_WM_HOTKEY(hwnd,wParam,lParam,fn) ((fn)((hwnd),(int)(wParam),(UINT)LOWORD(lParam),(UINT)HIWORD(lParam)),(LRESULT)0)
#define FORWARD_WM_HOTKEY(hwnd,idHotKey,fuModifiers,vk,fn) (void)(fn)((hwnd),WM_HOTKEY,(WPARAM)(idHotKey),MAKELPARAM((fuModifiers),(vk)))

#define Static_Enable(hwndCtl,fEnable) EnableWindow((hwndCtl),(fEnable))

#define Static_GetText(hwndCtl,lpch,cchMax) GetWindowText((hwndCtl),(lpch),(cchMax))
#define Static_GetTextLength(hwndCtl) GetWindowTextLength(hwndCtl)
#define Static_SetText(hwndCtl,lpsz) SetWindowText((hwndCtl),(lpsz))

#define Static_SetIcon(hwndCtl,hIcon) ((HICON)(UINT_PTR)SNDMSG((hwndCtl),STM_SETICON,(WPARAM)(HICON)(hIcon),(LPARAM)0))
#define Static_GetIcon(hwndCtl,hIcon) ((HICON)(UINT_PTR)SNDMSG((hwndCtl),STM_GETICON,(WPARAM)0,(LPARAM)0))

#define Button_Enable(hwndCtl,fEnable) EnableWindow((hwndCtl),(fEnable))

#define Button_GetText(hwndCtl,lpch,cchMax) GetWindowText((hwndCtl),(lpch),(cchMax))
#define Button_GetTextLength(hwndCtl) GetWindowTextLength(hwndCtl)
#define Button_SetText(hwndCtl,lpsz) SetWindowText((hwndCtl),(lpsz))

#define Button_GetCheck(hwndCtl) ((int)(DWORD)SNDMSG((hwndCtl),BM_GETCHECK,(WPARAM)0,(LPARAM)0))
#define Button_SetCheck(hwndCtl,check) ((void)SNDMSG((hwndCtl),BM_SETCHECK,(WPARAM)(int)(check),(LPARAM)0))

#define Button_GetState(hwndCtl) ((int)(DWORD)SNDMSG((hwndCtl),BM_GETSTATE,(WPARAM)0,(LPARAM)0))
#define Button_SetState(hwndCtl,state) ((UINT)(DWORD)SNDMSG((hwndCtl),BM_SETSTATE,(WPARAM)(int)(state),(LPARAM)0))
#define Button_SetStyle(hwndCtl,style,fRedraw) ((void)SNDMSG((hwndCtl),BM_SETSTYLE,(WPARAM)LOWORD(style),MAKELPARAM(((fRedraw) ? TRUE : FALSE),0)))

#define Edit_Enable(hwndCtl,fEnable) EnableWindow((hwndCtl),(fEnable))
#define Edit_GetText(hwndCtl,lpch,cchMax) GetWindowText((hwndCtl),(lpch),(cchMax))
#define Edit_GetTextLength(hwndCtl) GetWindowTextLength(hwndCtl)
#define Edit_SetText(hwndCtl,lpsz) SetWindowText((hwndCtl),(lpsz))
#define Edit_LimitText(hwndCtl,cchMax) ((void)SNDMSG((hwndCtl),EM_LIMITTEXT,(WPARAM)(cchMax),(LPARAM)0))
#define Edit_GetLineCount(hwndCtl) ((int)(DWORD)SNDMSG((hwndCtl),EM_GETLINECOUNT,(WPARAM)0,(LPARAM)0))
#define Edit_GetLine(hwndCtl,line,lpch,cchMax) ((*((int *)(lpch)) = (cchMax)),((int)(DWORD)SNDMSG((hwndCtl),EM_GETLINE,(WPARAM)(int)(line),(LPARAM)(LPTSTR)(lpch))))
#define Edit_GetRect(hwndCtl,lprc) ((void)SNDMSG((hwndCtl),EM_GETRECT,(LPARAM)0,(LPARAM)(RECT *)(lprc)))
#define Edit_SetRect(hwndCtl,lprc) ((void)SNDMSG((hwndCtl),EM_SETRECT,(LPARAM)0,(LPARAM)(const RECT *)(lprc)))
#define Edit_SetRectNoPaint(hwndCtl,lprc) ((void)SNDMSG((hwndCtl),EM_SETRECTNP,(LPARAM)0,(LPARAM)(const RECT *)(lprc)))

#define Edit_GetSel(hwndCtl) ((DWORD)SNDMSG((hwndCtl),EM_GETSEL,(WPARAM)0,(LPARAM)0))
#define Edit_SetSel(hwndCtl,ichStart,ichEnd) ((void)SNDMSG((hwndCtl),EM_SETSEL,(ichStart),(ichEnd)))
#define Edit_ReplaceSel(hwndCtl,lpszReplace) ((void)SNDMSG((hwndCtl),EM_REPLACESEL,(LPARAM)0,(LPARAM)(LPCTSTR)(lpszReplace)))

#define Edit_GetModify(hwndCtl) ((WINBOOL)(DWORD)SNDMSG((hwndCtl),EM_GETMODIFY,(WPARAM)0,(LPARAM)0))
#define Edit_SetModify(hwndCtl,fModified) ((void)SNDMSG((hwndCtl),EM_SETMODIFY,(WPARAM)(UINT)(fModified),(LPARAM)0))

#define Edit_ScrollCaret(hwndCtl) ((WINBOOL)(DWORD)SNDMSG((hwndCtl),EM_SCROLLCARET,(WPARAM)0,(LPARAM)0))

#define Edit_LineFromChar(hwndCtl,ich) ((int)(DWORD)SNDMSG((hwndCtl),EM_LINEFROMCHAR,(WPARAM)(int)(ich),(LPARAM)0))
#define Edit_LineIndex(hwndCtl,line) ((int)(DWORD)SNDMSG((hwndCtl),EM_LINEINDEX,(WPARAM)(int)(line),(LPARAM)0))
#define Edit_LineLength(hwndCtl,line) ((int)(DWORD)SNDMSG((hwndCtl),EM_LINELENGTH,(WPARAM)(int)(line),(LPARAM)0))

#define Edit_Scroll(hwndCtl,dv,dh) ((void)SNDMSG((hwndCtl),EM_LINESCROLL,(WPARAM)(dh),(LPARAM)(dv)))

#define Edit_CanUndo(hwndCtl) ((WINBOOL)(DWORD)SNDMSG((hwndCtl),EM_CANUNDO,(WPARAM)0,(LPARAM)0))
#define Edit_Undo(hwndCtl) ((WINBOOL)(DWORD)SNDMSG((hwndCtl),EM_UNDO,(WPARAM)0,(LPARAM)0))
#define Edit_EmptyUndoBuffer(hwndCtl) ((void)SNDMSG((hwndCtl),EM_EMPTYUNDOBUFFER,(WPARAM)0,(LPARAM)0))

#define Edit_SetPasswordChar(hwndCtl,ch) ((void)SNDMSG((hwndCtl),EM_SETPASSWORDCHAR,(WPARAM)(UINT)(ch),(LPARAM)0))

#define Edit_SetTabStops(hwndCtl,cTabs,lpTabs) ((void)SNDMSG((hwndCtl),EM_SETTABSTOPS,(WPARAM)(int)(cTabs),(LPARAM)(const int *)(lpTabs)))

#define Edit_FmtLines(hwndCtl,fAddEOL) ((WINBOOL)(DWORD)SNDMSG((hwndCtl),EM_FMTLINES,(WPARAM)(WINBOOL)(fAddEOL),(LPARAM)0))

#define Edit_GetHandle(hwndCtl) ((HLOCAL)(UINT_PTR)SNDMSG((hwndCtl),EM_GETHANDLE,(WPARAM)0,(LPARAM)0))
#define Edit_SetHandle(hwndCtl,h) ((void)SNDMSG((hwndCtl),EM_SETHANDLE,(WPARAM)(UINT_PTR)(HLOCAL)(h),(LPARAM)0))

#define Edit_GetFirstVisibleLine(hwndCtl) ((int)(DWORD)SNDMSG((hwndCtl),EM_GETFIRSTVISIBLELINE,(WPARAM)0,(LPARAM)0))

#define Edit_SetReadOnly(hwndCtl,fReadOnly) ((WINBOOL)(DWORD)SNDMSG((hwndCtl),EM_SETREADONLY,(WPARAM)(WINBOOL)(fReadOnly),(LPARAM)0))

#define Edit_GetPasswordChar(hwndCtl) ((TCHAR)(DWORD)SNDMSG((hwndCtl),EM_GETPASSWORDCHAR,(WPARAM)0,(LPARAM)0))

#define Edit_SetWordBreakProc(hwndCtl,lpfnWordBreak) ((void)SNDMSG((hwndCtl),EM_SETWORDBREAKPROC,(LPARAM)0,(LPARAM)(EDITWORDBREAKPROC)(lpfnWordBreak)))
#define Edit_GetWordBreakProc(hwndCtl) ((EDITWORDBREAKPROC)SNDMSG((hwndCtl),EM_GETWORDBREAKPROC,(WPARAM)0,(LPARAM)0))

#define ScrollBar_Enable(hwndCtl,flags) EnableScrollBar((hwndCtl),SB_CTL,(flags))

#define ScrollBar_Show(hwndCtl,fShow) ShowWindow((hwndCtl),(fShow) ? SW_SHOWNORMAL : SW_HIDE)

#define ScrollBar_SetPos(hwndCtl,pos,fRedraw) SetScrollPos((hwndCtl),SB_CTL,(pos),(fRedraw))
#define ScrollBar_GetPos(hwndCtl) GetScrollPos((hwndCtl),SB_CTL)

#define ScrollBar_SetRange(hwndCtl,posMin,posMax,fRedraw) SetScrollRange((hwndCtl),SB_CTL,(posMin),(posMax),(fRedraw))
#define ScrollBar_GetRange(hwndCtl,lpposMin,lpposMax) GetScrollRange((hwndCtl),SB_CTL,(lpposMin),(lpposMax))

#define ListBox_Enable(hwndCtl,fEnable) EnableWindow((hwndCtl),(fEnable))

#define ListBox_GetCount(hwndCtl) ((int)(DWORD)SNDMSG((hwndCtl),LB_GETCOUNT,(WPARAM)0,(LPARAM)0))
#define ListBox_ResetContent(hwndCtl) ((WINBOOL)(DWORD)SNDMSG((hwndCtl),LB_RESETCONTENT,(WPARAM)0,(LPARAM)0))

#define ListBox_AddString(hwndCtl,lpsz) ((int)(DWORD)SNDMSG((hwndCtl),LB_ADDSTRING,(LPARAM)0,(LPARAM)(LPCTSTR)(lpsz)))
#define ListBox_InsertString(hwndCtl,index,lpsz) ((int)(DWORD)SNDMSG((hwndCtl),LB_INSERTSTRING,(WPARAM)(int)(index),(LPARAM)(LPCTSTR)(lpsz)))

#define ListBox_AddItemData(hwndCtl,data) ((int)(DWORD)SNDMSG((hwndCtl),LB_ADDSTRING,(LPARAM)0,(LPARAM)(data)))
#define ListBox_InsertItemData(hwndCtl,index,data) ((int)(DWORD)SNDMSG((hwndCtl),LB_INSERTSTRING,(WPARAM)(int)(index),(LPARAM)(data)))

#define ListBox_DeleteString(hwndCtl,index) ((int)(DWORD)SNDMSG((hwndCtl),LB_DELETESTRING,(WPARAM)(int)(index),(LPARAM)0))

#define ListBox_GetTextLen(hwndCtl,index) ((int)(DWORD)SNDMSG((hwndCtl),LB_GETTEXTLEN,(WPARAM)(int)(index),(LPARAM)0))
#define ListBox_GetText(hwndCtl,index,lpszBuffer) ((int)(DWORD)SNDMSG((hwndCtl),LB_GETTEXT,(WPARAM)(int)(index),(LPARAM)(LPCTSTR)(lpszBuffer)))

#define ListBox_GetItemData(hwndCtl,index) ((LRESULT)(ULONG_PTR)SNDMSG((hwndCtl),LB_GETITEMDATA,(WPARAM)(int)(index),(LPARAM)0))
#define ListBox_SetItemData(hwndCtl,index,data) ((int)(DWORD)SNDMSG((hwndCtl),LB_SETITEMDATA,(WPARAM)(int)(index),(LPARAM)(data)))

#define ListBox_FindString(hwndCtl,indexStart,lpszFind) ((int)(DWORD)SNDMSG((hwndCtl),LB_FINDSTRING,(WPARAM)(int)(indexStart),(LPARAM)(LPCTSTR)(lpszFind)))
#define ListBox_FindItemData(hwndCtl,indexStart,data) ((int)(DWORD)SNDMSG((hwndCtl),LB_FINDSTRING,(WPARAM)(int)(indexStart),(LPARAM)(data)))

#define ListBox_SetSel(hwndCtl,fSelect,index) ((int)(DWORD)SNDMSG((hwndCtl),LB_SETSEL,(WPARAM)(WINBOOL)(fSelect),(LPARAM)(index)))
#define ListBox_SelItemRange(hwndCtl,fSelect,first,last) ((int)(DWORD)SNDMSG((hwndCtl),LB_SELITEMRANGE,(WPARAM)(WINBOOL)(fSelect),MAKELPARAM((first),(last))))

#define ListBox_GetCurSel(hwndCtl) ((int)(DWORD)SNDMSG((hwndCtl),LB_GETCURSEL,(WPARAM)0,(LPARAM)0))
#define ListBox_SetCurSel(hwndCtl,index) ((int)(DWORD)SNDMSG((hwndCtl),LB_SETCURSEL,(WPARAM)(int)(index),(LPARAM)0))

#define ListBox_SelectString(hwndCtl,indexStart,lpszFind) ((int)(DWORD)SNDMSG((hwndCtl),LB_SELECTSTRING,(WPARAM)(int)(indexStart),(LPARAM)(LPCTSTR)(lpszFind)))
#define ListBox_SelectItemData(hwndCtl,indexStart,data) ((int)(DWORD)SNDMSG((hwndCtl),LB_SELECTSTRING,(WPARAM)(int)(indexStart),(LPARAM)(data)))

#define ListBox_GetSel(hwndCtl,index) ((int)(DWORD)SNDMSG((hwndCtl),LB_GETSEL,(WPARAM)(int)(index),(LPARAM)0))
#define ListBox_GetSelCount(hwndCtl) ((int)(DWORD)SNDMSG((hwndCtl),LB_GETSELCOUNT,(WPARAM)0,(LPARAM)0))
#define ListBox_GetTopIndex(hwndCtl) ((int)(DWORD)SNDMSG((hwndCtl),LB_GETTOPINDEX,(WPARAM)0,(LPARAM)0))
#define ListBox_GetSelItems(hwndCtl,cItems,lpItems) ((int)(DWORD)SNDMSG((hwndCtl),LB_GETSELITEMS,(WPARAM)(int)(cItems),(LPARAM)(int *)(lpItems)))

#define ListBox_SetTopIndex(hwndCtl,indexTop) ((int)(DWORD)SNDMSG((hwndCtl),LB_SETTOPINDEX,(WPARAM)(int)(indexTop),(LPARAM)0))

#define ListBox_SetColumnWidth(hwndCtl,cxColumn) ((void)SNDMSG((hwndCtl),LB_SETCOLUMNWIDTH,(WPARAM)(int)(cxColumn),(LPARAM)0))
#define ListBox_GetHorizontalExtent(hwndCtl) ((int)(DWORD)SNDMSG((hwndCtl),LB_GETHORIZONTALEXTENT,(WPARAM)0,(LPARAM)0))
#define ListBox_SetHorizontalExtent(hwndCtl,cxExtent) ((void)SNDMSG((hwndCtl),LB_SETHORIZONTALEXTENT,(WPARAM)(int)(cxExtent),(LPARAM)0))

#define ListBox_SetTabStops(hwndCtl,cTabs,lpTabs) ((WINBOOL)(DWORD)SNDMSG((hwndCtl),LB_SETTABSTOPS,(WPARAM)(int)(cTabs),(LPARAM)(int *)(lpTabs)))

#define ListBox_GetItemRect(hwndCtl,index,lprc) ((int)(DWORD)SNDMSG((hwndCtl),LB_GETITEMRECT,(WPARAM)(int)(index),(LPARAM)(RECT *)(lprc)))

#define ListBox_SetCaretIndex(hwndCtl,index) ((int)(DWORD)SNDMSG((hwndCtl),LB_SETCARETINDEX,(WPARAM)(int)(index),(LPARAM)0))
#define ListBox_GetCaretIndex(hwndCtl) ((int)(DWORD)SNDMSG((hwndCtl),LB_GETCARETINDEX,(WPARAM)0,(LPARAM)0))

#define ListBox_FindStringExact(hwndCtl,indexStart,lpszFind) ((int)(DWORD)SNDMSG((hwndCtl),LB_FINDSTRINGEXACT,(WPARAM)(int)(indexStart),(LPARAM)(LPCTSTR)(lpszFind)))

#define ListBox_SetItemHeight(hwndCtl,index,cy) ((int)(DWORD)SNDMSG((hwndCtl),LB_SETITEMHEIGHT,(WPARAM)(int)(index),MAKELPARAM((cy),0)))
#define ListBox_GetItemHeight(hwndCtl,index) ((int)(DWORD)SNDMSG((hwndCtl),LB_GETITEMHEIGHT,(WPARAM)(int)(index),(LPARAM)0))

#define ListBox_Dir(hwndCtl,attrs,lpszFileSpec) ((int)(DWORD)SNDMSG((hwndCtl),LB_DIR,(WPARAM)(UINT)(attrs),(LPARAM)(LPCTSTR)(lpszFileSpec)))

#define ComboBox_Enable(hwndCtl,fEnable) EnableWindow((hwndCtl),(fEnable))

#define ComboBox_GetText(hwndCtl,lpch,cchMax) GetWindowText((hwndCtl),(lpch),(cchMax))
#define ComboBox_GetTextLength(hwndCtl) GetWindowTextLength(hwndCtl)
#define ComboBox_SetText(hwndCtl,lpsz) SetWindowText((hwndCtl),(lpsz))

#define ComboBox_LimitText(hwndCtl,cchLimit) ((int)(DWORD)SNDMSG((hwndCtl),CB_LIMITTEXT,(WPARAM)(int)(cchLimit),(LPARAM)0))

#define ComboBox_GetEditSel(hwndCtl) ((DWORD)SNDMSG((hwndCtl),CB_GETEDITSEL,(WPARAM)0,(LPARAM)0))
#define ComboBox_SetEditSel(hwndCtl,ichStart,ichEnd) ((int)(DWORD)SNDMSG((hwndCtl),CB_SETEDITSEL,(LPARAM)0,MAKELPARAM((ichStart),(ichEnd))))

#define ComboBox_GetCount(hwndCtl) ((int)(DWORD)SNDMSG((hwndCtl),CB_GETCOUNT,(WPARAM)0,(LPARAM)0))
#define ComboBox_ResetContent(hwndCtl) ((int)(DWORD)SNDMSG((hwndCtl),CB_RESETCONTENT,(WPARAM)0,(LPARAM)0))

#define ComboBox_AddString(hwndCtl,lpsz) ((int)(DWORD)SNDMSG((hwndCtl),CB_ADDSTRING,(LPARAM)0,(LPARAM)(LPCTSTR)(lpsz)))
#define ComboBox_InsertString(hwndCtl,index,lpsz) ((int)(DWORD)SNDMSG((hwndCtl),CB_INSERTSTRING,(WPARAM)(int)(index),(LPARAM)(LPCTSTR)(lpsz)))

#define ComboBox_AddItemData(hwndCtl,data) ((int)(DWORD)SNDMSG((hwndCtl),CB_ADDSTRING,(LPARAM)0,(LPARAM)(data)))
#define ComboBox_InsertItemData(hwndCtl,index,data) ((int)(DWORD)SNDMSG((hwndCtl),CB_INSERTSTRING,(WPARAM)(int)(index),(LPARAM)(data)))

#define ComboBox_DeleteString(hwndCtl,index) ((int)(DWORD)SNDMSG((hwndCtl),CB_DELETESTRING,(WPARAM)(int)(index),(LPARAM)0))

#define ComboBox_GetLBTextLen(hwndCtl,index) ((int)(DWORD)SNDMSG((hwndCtl),CB_GETLBTEXTLEN,(WPARAM)(int)(index),(LPARAM)0))
#define ComboBox_GetLBText(hwndCtl,index,lpszBuffer) ((int)(DWORD)SNDMSG((hwndCtl),CB_GETLBTEXT,(WPARAM)(int)(index),(LPARAM)(LPCTSTR)(lpszBuffer)))

#define ComboBox_GetItemData(hwndCtl,index) ((LRESULT)(ULONG_PTR)SNDMSG((hwndCtl),CB_GETITEMDATA,(WPARAM)(int)(index),(LPARAM)0))
#define ComboBox_SetItemData(hwndCtl,index,data) ((int)(DWORD)SNDMSG((hwndCtl),CB_SETITEMDATA,(WPARAM)(int)(index),(LPARAM)(data)))

#define ComboBox_FindString(hwndCtl,indexStart,lpszFind) ((int)(DWORD)SNDMSG((hwndCtl),CB_FINDSTRING,(WPARAM)(int)(indexStart),(LPARAM)(LPCTSTR)(lpszFind)))
#define ComboBox_FindItemData(hwndCtl,indexStart,data) ((int)(DWORD)SNDMSG((hwndCtl),CB_FINDSTRING,(WPARAM)(int)(indexStart),(LPARAM)(data)))

#define ComboBox_GetCurSel(hwndCtl) ((int)(DWORD)SNDMSG((hwndCtl),CB_GETCURSEL,(WPARAM)0,(LPARAM)0))
#define ComboBox_SetCurSel(hwndCtl,index) ((int)(DWORD)SNDMSG((hwndCtl),CB_SETCURSEL,(WPARAM)(int)(index),(LPARAM)0))

#define ComboBox_SelectString(hwndCtl,indexStart,lpszSelect) ((int)(DWORD)SNDMSG((hwndCtl),CB_SELECTSTRING,(WPARAM)(int)(indexStart),(LPARAM)(LPCTSTR)(lpszSelect)))
#define ComboBox_SelectItemData(hwndCtl,indexStart,data) ((int)(DWORD)SNDMSG((hwndCtl),CB_SELECTSTRING,(WPARAM)(int)(indexStart),(LPARAM)(data)))

#define ComboBox_Dir(hwndCtl,attrs,lpszFileSpec) ((int)(DWORD)SNDMSG((hwndCtl),CB_DIR,(WPARAM)(UINT)(attrs),(LPARAM)(LPCTSTR)(lpszFileSpec)))

#define ComboBox_ShowDropdown(hwndCtl,fShow) ((WINBOOL)(DWORD)SNDMSG((hwndCtl),CB_SHOWDROPDOWN,(WPARAM)(WINBOOL)(fShow),(LPARAM)0))

#define ComboBox_FindStringExact(hwndCtl,indexStart,lpszFind) ((int)(DWORD)SNDMSG((hwndCtl),CB_FINDSTRINGEXACT,(WPARAM)(int)(indexStart),(LPARAM)(LPCTSTR)(lpszFind)))

#define ComboBox_GetDroppedState(hwndCtl) ((WINBOOL)(DWORD)SNDMSG((hwndCtl),CB_GETDROPPEDSTATE,(WPARAM)0,(LPARAM)0))
#define ComboBox_GetDroppedControlRect(hwndCtl,lprc) ((void)SNDMSG((hwndCtl),CB_GETDROPPEDCONTROLRECT,(LPARAM)0,(LPARAM)(RECT *)(lprc)))

#define ComboBox_GetItemHeight(hwndCtl) ((int)(DWORD)SNDMSG((hwndCtl),CB_GETITEMHEIGHT,(WPARAM)0,(LPARAM)0))
#define ComboBox_SetItemHeight(hwndCtl,index,cyItem) ((int)(DWORD)SNDMSG((hwndCtl),CB_SETITEMHEIGHT,(WPARAM)(int)(index),(LPARAM)(int)cyItem))

#define ComboBox_GetExtendedUI(hwndCtl) ((UINT)(DWORD)SNDMSG((hwndCtl),CB_GETEXTENDEDUI,(WPARAM)0,(LPARAM)0))
#define ComboBox_SetExtendedUI(hwndCtl,flags) ((int)(DWORD)SNDMSG((hwndCtl),CB_SETEXTENDEDUI,(WPARAM)(UINT)(flags),(LPARAM)0))

#define GET_WPARAM(wp,lp) (wp)
#define GET_LPARAM(wp,lp) (lp)

#define GET_X_LPARAM(lp) ((int)(short)LOWORD(lp))
#define GET_Y_LPARAM(lp) ((int)(short)HIWORD(lp))

#define GET_WM_ACTIVATE_STATE(wp,lp) LOWORD(wp)
#define GET_WM_ACTIVATE_FMINIMIZED(wp,lp) (WINBOOL)HIWORD(wp)
#define GET_WM_ACTIVATE_HWND(wp,lp) (HWND)(lp)
#define GET_WM_ACTIVATE_MPS(s,fmin,hwnd) (WPARAM)MAKELONG((s),(fmin)),(LPARAM)(hwnd)

#define GET_WM_CHARTOITEM_CHAR(wp,lp) (TCHAR)LOWORD(wp)
#define GET_WM_CHARTOITEM_POS(wp,lp) HIWORD(wp)
#define GET_WM_CHARTOITEM_HWND(wp,lp) (HWND)(lp)
#define GET_WM_CHARTOITEM_MPS(ch,pos,hwnd) (WPARAM)MAKELONG((pos),(ch)),(LPARAM)(hwnd)

#define GET_WM_COMMAND_ID(wp,lp) LOWORD(wp)
#define GET_WM_COMMAND_HWND(wp,lp) (HWND)(lp)
#define GET_WM_COMMAND_CMD(wp,lp) HIWORD(wp)
#define GET_WM_COMMAND_MPS(id,hwnd,cmd) (WPARAM)MAKELONG(id,cmd),(LPARAM)(hwnd)

#define WM_CTLCOLOR 0x0019

#define GET_WM_CTLCOLOR_HDC(wp,lp,msg) (HDC)(wp)
#define GET_WM_CTLCOLOR_HWND(wp,lp,msg) (HWND)(lp)
#define GET_WM_CTLCOLOR_TYPE(wp,lp,msg) (WORD)(msg - WM_CTLCOLORMSGBOX)
#define GET_WM_CTLCOLOR_MSG(type) (WORD)(WM_CTLCOLORMSGBOX+(type))
#define GET_WM_CTLCOLOR_MPS(hdc,hwnd,type) (WPARAM)(hdc),(LPARAM)(hwnd)

#define GET_WM_MENUSELECT_CMD(wp,lp) LOWORD(wp)
#define GET_WM_MENUSELECT_FLAGS(wp,lp) (UINT)(int)(short)HIWORD(wp)
#define GET_WM_MENUSELECT_HMENU(wp,lp) (HMENU)(lp)
#define GET_WM_MENUSELECT_MPS(cmd,f,hmenu) (WPARAM)MAKELONG(cmd,f),(LPARAM)(hmenu)

#define GET_WM_MDIACTIVATE_FACTIVATE(hwnd,wp,lp) (lp==(LPARAM)hwnd)
#define GET_WM_MDIACTIVATE_HWNDDEACT(wp,lp) (HWND)(wp)
#define GET_WM_MDIACTIVATE_HWNDACTIVATE(wp,lp) (HWND)(lp)

#define GET_WM_MDIACTIVATE_MPS(f,hwndD,hwndA) (WPARAM)(hwndA),0

#define GET_WM_MDISETMENU_MPS(hmenuF,hmenuW) (WPARAM)hmenuF,(LPARAM)hmenuW

#define GET_WM_MENUCHAR_CHAR(wp,lp) (TCHAR)LOWORD(wp)
#define GET_WM_MENUCHAR_HMENU(wp,lp) (HMENU)(lp)
#define GET_WM_MENUCHAR_FMENU(wp,lp) (WINBOOL)HIWORD(wp)
#define GET_WM_MENUCHAR_MPS(ch,hmenu,f) (WPARAM)MAKELONG(ch,f),(LPARAM)(hmenu)

#define GET_WM_PARENTNOTIFY_MSG(wp,lp) LOWORD(wp)
#define GET_WM_PARENTNOTIFY_ID(wp,lp) HIWORD(wp)
#define GET_WM_PARENTNOTIFY_HWNDCHILD(wp,lp) (HWND)(lp)
#define GET_WM_PARENTNOTIFY_X(wp,lp) (int)(short)LOWORD(lp)
#define GET_WM_PARENTNOTIFY_Y(wp,lp) (int)(short)HIWORD(lp)
#define GET_WM_PARENTNOTIFY_MPS(msg,id,hwnd) (WPARAM)MAKELONG(id,msg),(LPARAM)(hwnd)
#define GET_WM_PARENTNOTIFY2_MPS(msg,x,y) (WPARAM)MAKELONG(0,msg),MAKELONG(x,y)

#define GET_WM_VKEYTOITEM_CODE(wp,lp) (int)(short)LOWORD(wp)
#define GET_WM_VKEYTOITEM_ITEM(wp,lp) HIWORD(wp)
#define GET_WM_VKEYTOITEM_HWND(wp,lp) (HWND)(lp)
#define GET_WM_VKEYTOITEM_MPS(code,item,hwnd) (WPARAM)MAKELONG(item,code),(LPARAM)(hwnd)

#define GET_EM_SETSEL_START(wp,lp) (INT)(wp)
#define GET_EM_SETSEL_END(wp,lp) (lp)
#define GET_EM_SETSEL_MPS(iStart,iEnd) (WPARAM)(iStart),(LPARAM)(iEnd)

#define GET_EM_LINESCROLL_MPS(vert,horz) (WPARAM)horz,(LPARAM)vert

#define GET_WM_CHANGECBCHAIN_HWNDNEXT(wp,lp) (HWND)(lp)

#define GET_WM_HSCROLL_CODE(wp,lp) LOWORD(wp)
#define GET_WM_HSCROLL_POS(wp,lp) HIWORD(wp)
#define GET_WM_HSCROLL_HWND(wp,lp) (HWND)(lp)
#define GET_WM_HSCROLL_MPS(code,pos,hwnd) (WPARAM)MAKELONG(code,pos),(LPARAM)(hwnd)

#define GET_WM_VSCROLL_CODE(wp,lp) LOWORD(wp)
#define GET_WM_VSCROLL_POS(wp,lp) HIWORD(wp)
#define GET_WM_VSCROLL_HWND(wp,lp) (HWND)(lp)
#define GET_WM_VSCROLL_MPS(code,pos,hwnd) (WPARAM)MAKELONG(code,pos),(LPARAM)(hwnd)

#define _ncalloc calloc
#define _nexpand _expand
#define _ffree free
#define _fmalloc malloc
#define _fmemccpy _memccpy
#define _fmemchr memchr
#define _fmemcmp memcmp
#define _fmemcpy memcpy
#define _fmemicmp _memicmp
#define _fmemmove memmove
#define _fmemset memset
#define _fmsize _msize
#define _frealloc realloc
#define _fstrcat strcat
#define _fstrchr strchr
#define _fstrcmp strcmp
#define _fstrcpy strcpy
#define _fstrcspn strcspn
#define _fstrdup _strdup
#define _fstricmp _stricmp
#define _fstrlen strlen
#define _fstrlwr _strlwr
#define _fstrncat strncat
#define _fstrncmp strncmp
#define _fstrncpy strncpy
#define _fstrnicmp _strnicmp
#define _fstrnset _strnset
#define _fstrpbrk strpbrk
#define _fstrrchr strrchr
#define _fstrrev _strrev
#define _fstrset _strset
#define _fstrspn strspn
#define _fstrstr strstr
#define _fstrtok strtok
#define _fstrupr _strupr
#define _nfree free
#define _nmalloc malloc
#define _nmsize _msize
#define _nrealloc realloc
#define _nstrdup _strdup
#define hmemcpy MoveMemory

#ifndef DECLARE_HANDLE32
#define DECLARE_HANDLE32 DECLARE_HANDLE
#endif

#ifdef __cplusplus
}
#endif
#endif

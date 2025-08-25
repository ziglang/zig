/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef __DISPDIB_H__
#define __DISPDIB_H__

#define DISPLAYDIB_NOERROR 0x0000
#define DISPLAYDIB_NOTSUPPORTED 0x0001
#define DISPLAYDIB_INVALIDDIB 0x0002
#define DISPLAYDIB_INVALIDFORMAT 0x0003
#define DISPLAYDIB_INVALIDTASK 0x0004
#define DISPLAYDIB_STOP 0x0005
#define DISPLAYDIB_NOTACTIVE 0x0006
#define DISPLAYDIB_BADSIZE 0x0007

#define DISPLAYDIB_NOPALETTE 0x0010
#define DISPLAYDIB_NOCENTER 0x0020
#define DISPLAYDIB_NOWAIT 0x0040
#define DISPLAYDIB_NOIMAGE 0x0080
#define DISPLAYDIB_ZOOM2 0x0100
#define DISPLAYDIB_DONTLOCKTASK 0x0200
#define DISPLAYDIB_TEST 0x0400
#define DISPLAYDIB_NOFLIP 0x0800
#define DISPLAYDIB_BEGIN 0x8000
#define DISPLAYDIB_END 0x4000

#define DISPLAYDIB_MODE 0x000F
#define DISPLAYDIB_MODE_DEFAULT 0x0000
#define DISPLAYDIB_MODE_320x200x8 0x0001
#define DISPLAYDIB_MODE_320x240x8 0x0005

#define DISPLAYDIB_WINDOW_CLASS "DisplayDibWindow"
#define DISPLAYDIB_DLL "DISPDIB.DLL"

#define DDM_SETFMT WM_USER+0
#define DDM_DRAW WM_USER+1
#define DDM_CLOSE WM_USER+2
#define DDM_BEGIN WM_USER+3
#define DDM_END WM_USER+4

static __inline UINT DisplayDibWindowMessage(HWND hwnd,UINT msg,WPARAM wParam,LPARAM lParam,DWORD cbSize) {
  COPYDATASTRUCT cds;
  cds.dwData = MAKELONG(msg,wParam);
  cds.cbData = lParam ? cbSize : 0;
  cds.lpData = (LPVOID)lParam;
  return (UINT)SendMessage(hwnd,WM_COPYDATA,(WPARAM)(HWND)NULL,(LPARAM)(LPVOID)&cds);
}

static __inline HWND DisplayDibWindowCreateEx(HWND hwndParent,HINSTANCE hInstance,DWORD dwStyle) {
  DWORD show = 2;
  DWORD zero = 0;
  LPVOID params[4] = {NULL,&zero,&show,0};
  if((UINT)LoadModule(DISPLAYDIB_DLL,&params) < (UINT)HINSTANCE_ERROR) return NULL;
  return CreateWindow(DISPLAYDIB_WINDOW_CLASS,"",dwStyle,0,0,GetSystemMetrics(SM_CXSCREEN),GetSystemMetrics(SM_CYSCREEN),hwndParent,NULL,(hInstance ? hInstance : GetWindowInstance(hwndParent)),NULL);
}

#define DisplayDibWindowCreate(hwndP,hInstance) DisplayDibWindowCreateEx(hwndP,hInstance,WS_POPUP)
#define DisplayDibWindowSetFmt(hwnd,lpbi) DisplayDibWindowMessage(hwnd,DDM_SETFMT,0,(LPARAM)(LPVOID)(lpbi),sizeof(BITMAPINFOHEADER) + 256 *sizeof(RGBQUAD))
#define DisplayDibWindowDraw(hwnd,flags,bits,size) DisplayDibWindowMessage(hwnd,DDM_DRAW,(WPARAM)(UINT)(flags),(LPARAM)(LPVOID)(bits),(DWORD)(size))

#ifdef __cplusplus
#define DisplayDibWindowBegin(hwnd) ::ShowWindow(hwnd,SW_SHOWNORMAL)
#define DisplayDibWindowEnd(hwnd) ::ShowWindow(hwnd,SW_HIDE)
#define DisplayDibWindowBeginEx(hwnd,f) ::SendMessage(hwnd,DDM_BEGIN,(WPARAM)(UINT)(f),0)
#define DisplayDibWindowEndEx(hwnd) ::SendMessage(hwnd,DDM_END,0,0)
#define DisplayDibWindowClose(hwnd) ::SendMessage(hwnd,DDM_CLOSE,0,0)
#else
#define DisplayDibWindowBegin(hwnd) ShowWindow(hwnd,SW_SHOWNORMAL)
#define DisplayDibWindowEnd(hwnd) ShowWindow(hwnd,SW_HIDE)
#define DisplayDibWindowBeginEx(hwnd) SendMessage(hwnd,DDM_BEGIN,0,0)
#define DisplayDibWindowEndEx(hwnd) SendMessage(hwnd,DDM_END,0,0)
#define DisplayDibWindowClose(hwnd) SendMessage(hwnd,DDM_CLOSE,0,0)
#endif
#endif

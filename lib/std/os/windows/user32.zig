// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2020 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
usingnamespace @import("bits.zig");

// PM
pub const PM_REMOVE = 0x0001;
pub const PM_NOREMOVE = 0x0000;
pub const PM_NOYIELD = 0x0002;

// WM
pub const WM_NULL = 0x0000;
pub const WM_CREATE = 0x0001;
pub const WM_DESTROY = 0x0002;
pub const WM_MOVE = 0x0003;
pub const WM_SIZE = 0x0005;

pub const WM_ACTIVATE = 0x0006;
pub const WM_PAINT = 0x000F;
pub const WM_CLOSE = 0x0010;
pub const WM_QUIT = 0x0012;
pub const WM_SETFOCUS = 0x0007;

pub const WM_KILLFOCUS = 0x0008;
pub const WM_ENABLE = 0x000A;
pub const WM_SETREDRAW = 0x000B;

pub const WM_SYSCOLORCHANGE = 0x0015;
pub const WM_SHOWWINDOW = 0x0018;

pub const WM_WINDOWPOSCHANGING = 0x0046;
pub const WM_WINDOWPOSCHANGED = 0x0047;
pub const WM_POWER = 0x0048;

pub const WM_CONTEXTMENU = 0x007B;
pub const WM_STYLECHANGING = 0x007C;
pub const WM_STYLECHANGED = 0x007D;
pub const WM_DISPLAYCHANGE = 0x007E;
pub const WM_GETICON = 0x007F;
pub const WM_SETICON = 0x0080;

pub const WM_INPUT_DEVICE_CHANGE = 0x00fe;
pub const WM_INPUT = 0x00FF;
pub const WM_KEYFIRST = 0x0100;
pub const WM_KEYDOWN = 0x0100;
pub const WM_KEYUP = 0x0101;
pub const WM_CHAR = 0x0102;
pub const WM_DEADCHAR = 0x0103;
pub const WM_SYSKEYDOWN = 0x0104;
pub const WM_SYSKEYUP = 0x0105;
pub const WM_SYSCHAR = 0x0106;
pub const WM_SYSDEADCHAR = 0x0107;
pub const WM_UNICHAR = 0x0109;
pub const WM_KEYLAST = 0x0109;

pub const WM_COMMAND = 0x0111;
pub const WM_SYSCOMMAND = 0x0112;
pub const WM_TIMER = 0x0113;

pub const WM_MOUSEFIRST = 0x0200;
pub const WM_MOUSEMOVE = 0x0200;
pub const WM_LBUTTONDOWN = 0x0201;
pub const WM_LBUTTONUP = 0x0202;
pub const WM_LBUTTONDBLCLK = 0x0203;
pub const WM_RBUTTONDOWN = 0x0204;
pub const WM_RBUTTONUP = 0x0205;
pub const WM_RBUTTONDBLCLK = 0x0206;
pub const WM_MBUTTONDOWN = 0x0207;
pub const WM_MBUTTONUP = 0x0208;
pub const WM_MBUTTONDBLCLK = 0x0209;
pub const WM_MOUSEWHEEL = 0x020A;
pub const WM_XBUTTONDOWN = 0x020B;
pub const WM_XBUTTONUP = 0x020C;
pub const WM_XBUTTONDBLCLK = 0x020D;

// WA
pub const WA_INACTIVE = 0;
pub const WA_ACTIVE = 0x0006;

// WS
pub const WS_OVERLAPPED = 0x00000000;
pub const WS_CAPTION = 0x00C00000;
pub const WS_SYSMENU = 0x00080000;
pub const WS_THICKFRAME = 0x00040000;
pub const WS_MINIMIZEBOX = 0x00020000;
pub const WS_MAXIMIZEBOX = 0x00010000;

// PFD
pub const PFD_DRAW_TO_WINDOW = 0x00000004;
pub const PFD_SUPPORT_OPENGL = 0x00000020;
pub const PFD_DOUBLEBUFFER = 0x00000001;
pub const PFD_MAIN_PLANE = 0;
pub const PFD_TYPE_RGBA = 0;

// CS
pub const CS_HREDRAW = 0x0002;
pub const CS_VREDRAW = 0x0001;
pub const CS_OWNDC = 0x0020;

// SW
pub const SW_HIDE = 0;
pub const SW_SHOW = 5;

pub const WNDPROC = fn (HWND, UINT, WPARAM, LPARAM) callconv(WINAPI) LRESULT;

pub const WNDCLASSEXA = extern struct {
    cbSize: UINT = @sizeOf(WNDCLASSEXA),
    style: UINT,
    lpfnWndProc: WNDPROC,
    cbClsExtra: i32,
    cbWndExtra: i32,
    hInstance: HINSTANCE,
    hIcon: ?HICON,
    hCursor: ?HCURSOR,
    hbrBackground: ?HBRUSH,
    lpszMenuName: ?LPCSTR,
    lpszClassName: LPCSTR,
    hIconSm: ?HICON,
};

pub const POINT = extern struct {
    x: c_long, y: c_long
};

pub const MSG = extern struct {
    hWnd: ?HWND,
    message: UINT,
    wParam: WPARAM,
    lParam: LPARAM,
    time: DWORD,
    pt: POINT,
    lPrivate: DWORD,
};

pub extern "user32" fn CreateWindowExA(
    dwExStyle: DWORD,
    lpClassName: LPCSTR,
    lpWindowName: LPCSTR,
    dwStyle: DWORD,
    X: i32,
    Y: i32,
    nWidth: i32,
    nHeight: i32,
    hWindParent: ?HWND,
    hMenu: ?HMENU,
    hInstance: HINSTANCE,
    lpParam: ?LPVOID,
) callconv(WINAPI) ?HWND;

pub extern "user32" fn RegisterClassExA(*const WNDCLASSEXA) callconv(WINAPI) c_ushort;
pub extern "user32" fn DefWindowProcA(HWND, Msg: UINT, WPARAM, LPARAM) callconv(WINAPI) LRESULT;
pub extern "user32" fn ShowWindow(hWnd: ?HWND, nCmdShow: i32) callconv(WINAPI) bool;
pub extern "user32" fn UpdateWindow(hWnd: ?HWND) callconv(WINAPI) bool;
pub extern "user32" fn GetDC(hWnd: ?HWND) callconv(WINAPI) ?HDC;

pub extern "user32" fn PeekMessageA(
    lpMsg: ?*MSG,
    hWnd: ?HWND,
    wMsgFilterMin: UINT,
    wMsgFilterMax: UINT,
    wRemoveMsg: UINT,
) callconv(WINAPI) bool;

pub extern "user32" fn GetMessageA(
    lpMsg: ?*MSG,
    hWnd: ?HWND,
    wMsgFilterMin: UINT,
    wMsgFilterMax: UINT,
) callconv(WINAPI) bool;

pub extern "user32" fn TranslateMessage(lpMsg: *const MSG) callconv(WINAPI) bool;
pub extern "user32" fn DispatchMessageA(lpMsg: *const MSG) callconv(WINAPI) LRESULT;
pub extern "user32" fn PostQuitMessage(nExitCode: i32) callconv(WINAPI) void;

// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
usingnamespace @import("bits.zig");
const std = @import("std");
const builtin = @import("builtin");
const assert = std.debug.assert;
const windows = @import("../windows.zig");
const unexpectedError = windows.unexpectedError;
const GetLastError = windows.kernel32.GetLastError;
const SetLastError = windows.kernel32.SetLastError;

fn selectSymbol(comptime function_static: anytype, function_dynamic: @TypeOf(function_static), comptime os: std.Target.Os.WindowsVersion) @TypeOf(function_static) {
    comptime {
        const sym_ok = builtin.Target.current.os.isAtLeast(.windows, os);
        if (sym_ok == true) return function_static;
        if (sym_ok == null) return function_dynamic;
        if (sym_ok == false) @compileError("Target OS range does not support function, at least " ++ @tagName(os) ++ " is required");
    }
}

// === Messages ===

pub const WNDPROC = fn (hwnd: HWND, uMsg: UINT, wParam: WPARAM, lParam: LPARAM) callconv(WINAPI) LRESULT;

pub const MSG = extern struct {
    hWnd: ?HWND,
    message: UINT,
    wParam: WPARAM,
    lParam: LPARAM,
    time: DWORD,
    pt: POINT,
    lPrivate: DWORD,
};

pub const WM_NULL = 0x0000;
pub const WM_CREATE = 0x0001;
pub const WM_DESTROY = 0x0002;
pub const WM_NCDESTROY = WM_DESTROY;
pub const WM_MOVE = 0x0003;
pub const WM_SIZE = 0x0005;
pub const WM_ACTIVATE = 0x0006;
pub const WM_SETFOCUS = 0x0007;
pub const WM_KILLFOCUS = 0x0008;
pub const WM_ENABLE = 0x000A;
pub const WM_SETREDRAW = 0x000B;
pub const WM_SETTEXT = 0x000C;
pub const WM_GETTEXT = 0x000D;
pub const WM_GETTEXTLENGTH = 0x000E;
pub const WM_PAINT = 0x000F;
pub const WM_CLOSE = 0x0010;
pub const WM_QUIT = 0x0012;
pub const WM_ERASEBKGND = 0x0014;
pub const WM_SHOWWINDOW = 0x0018;
pub const WM_CTLCOLOR = 0x0019;
pub const WM_NEXTDLGCTL = 0x0028;
pub const WM_DRAWITEM = 0x002B;
pub const WM_MEASUREITEM = 0x002C;
pub const WM_DELETEITEM = 0x002D;
pub const WM_VKEYTOITEM = 0x002E;
pub const WM_CHARTOITEM = 0x002F;
pub const WM_SETFONT = 0x0030;
pub const WM_GETFONT = 0x0031;
pub const WM_COMPAREITEM = 0x0039;
pub const WM_WINDOWPOSCHANGED = 0x0047;
pub const WM_NOTIFY = 0x004E;
pub const WM_NCCALCSIZE = 0x0083;
pub const WM_NCHITTEST = 0x0084;
pub const WM_NCPAINT = 0x0085;
pub const WM_GETDLGCODE = 0x0087;
pub const WM_NCMOUSEMOVE = 0x00A0;
pub const WM_NCLBUTTONDOWN = 0x00A1;
pub const WM_NCLBUTTONUP = 0x00A2;
pub const WM_NCLBUTTONDBLCLK = 0x00A3;
pub const WM_NCRBUTTONDOWN = 0x00A4;
pub const WM_NCRBUTTONUP = 0x00A5;
pub const WM_NCRBUTTONDBLCLK = 0x00A6;
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
pub const WM_INITDIALOG = 0x0110;
pub const WM_COMMAND = 0x0111;
pub const WM_SYSCOMMAND = 0x0112;
pub const WM_TIMER = 0x0113;
pub const WM_HSCROLL = 0x0114;
pub const WM_VSCROLL = 0x0115;
pub const WM_ENTERIDLE = 0x0121;
pub const WM_CTLCOLORMSGBOX = 0x0132;
pub const WM_CTLCOLOREDIT = 0x0133;
pub const WM_CTLCOLORLISTBOX = 0x0134;
pub const WM_CTLCOLORBTN = 0x0135;
pub const WM_CTLCOLORDLG = 0x0136;
pub const WM_CTLCOLORSCROLLBAR = 0x0137;
pub const WM_CTLCOLORSTATIC = 0x0138;
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
pub const WM_MOUSELAST = 0x020A;
pub const WM_HOTKEY = 0x0312;
pub const WM_CARET_CREATE = 0x03E0;
pub const WM_CARET_DESTROY = 0x03E1;
pub const WM_CARET_BLINK = 0x03E2;
pub const WM_FDINPUT = 0x03F0;
pub const WM_FDOUTPUT = 0x03F1;
pub const WM_FDEXCEPT = 0x03F2;
pub const WM_USER = 0x0400;

pub extern "user32" fn GetMessageA(lpMsg: *MSG, hWnd: ?HWND, wMsgFilterMin: UINT, wMsgFilterMax: UINT) callconv(WINAPI) BOOL;
pub fn getMessageA(lpMsg: *MSG, hWnd: ?HWND, wMsgFilterMin: u32, wMsgFilterMax: u32) !void {
    const r = GetMessageA(lpMsg, hWnd, wMsgFilterMin, wMsgFilterMax);
    if (r == 0) return error.Quit;
    if (r != -1) return;
    switch (GetLastError()) {
        .INVALID_WINDOW_HANDLE => unreachable,
        .INVALID_PARAMETER => unreachable,
        else => |err| return windows.unexpectedError(err),
    }
}

pub extern "user32" fn GetMessageW(lpMsg: *MSG, hWnd: ?HWND, wMsgFilterMin: UINT, wMsgFilterMax: UINT) callconv(WINAPI) BOOL;
pub var pfnGetMessageW: @TypeOf(GetMessageW) = undefined;
pub fn getMessageW(lpMsg: *MSG, hWnd: ?HWND, wMsgFilterMin: u32, wMsgFilterMax: u32) !void {
    const function = selectSymbol(GetMessageW, pfnGetMessageW, .win2k);

    const r = function(lpMsg, hWnd, wMsgFilterMin, wMsgFilterMax);
    if (r == 0) return error.Quit;
    if (r != -1) return;
    switch (GetLastError()) {
        .INVALID_WINDOW_HANDLE => unreachable,
        .INVALID_PARAMETER => unreachable,
        else => |err| return windows.unexpectedError(err),
    }
}

pub const PM_NOREMOVE = 0x0000;
pub const PM_REMOVE = 0x0001;
pub const PM_NOYIELD = 0x0002;

pub extern "user32" fn PeekMessageA(lpMsg: *MSG, hWnd: ?HWND, wMsgFilterMin: UINT, wMsgFilterMax: UINT, wRemoveMsg: UINT) callconv(WINAPI) BOOL;
pub fn peekMessageA(lpMsg: *MSG, hWnd: ?HWND, wMsgFilterMin: u32, wMsgFilterMax: u32, wRemoveMsg: u32) !bool {
    const r = PeekMessageA(lpMsg, hWnd, wMsgFilterMin, wMsgFilterMax, wRemoveMsg);
    if (r == 0) return false;
    if (r != -1) return true;
    switch (GetLastError()) {
        .INVALID_WINDOW_HANDLE => unreachable,
        .INVALID_PARAMETER => unreachable,
        else => |err| return windows.unexpectedError(err),
    }
}

pub extern "user32" fn PeekMessageW(lpMsg: *MSG, hWnd: ?HWND, wMsgFilterMin: UINT, wMsgFilterMax: UINT, wRemoveMsg: UINT) callconv(WINAPI) BOOL;
pub var pfnPeekMessageW: @TypeOf(PeekMessageW) = undefined;
pub fn peekMessageW(lpMsg: *MSG, hWnd: ?HWND, wMsgFilterMin: u32, wMsgFilterMax: u32, wRemoveMsg: u32) !bool {
    const function = selectSymbol(PeekMessageW, pfnPeekMessageW, .win2k);

    const r = function(lpMsg, hWnd, wMsgFilterMin, wMsgFilterMax, wRemoveMsg);
    if (r == 0) return false;
    if (r != -1) return true;
    switch (GetLastError()) {
        .INVALID_WINDOW_HANDLE => unreachable,
        .INVALID_PARAMETER => unreachable,
        else => |err| return windows.unexpectedError(err),
    }
}

pub extern "user32" fn TranslateMessage(lpMsg: *const MSG) callconv(WINAPI) BOOL;
pub fn translateMessage(lpMsg: *const MSG) bool {
    return if (TranslateMessage(lpMsg) == 0) false else true;
}

pub extern "user32" fn DispatchMessageA(lpMsg: *const MSG) callconv(WINAPI) LRESULT;
pub fn dispatchMessageA(lpMsg: *const MSG) LRESULT {
    return DispatchMessageA(lpMsg);
}

pub extern "user32" fn DispatchMessageW(lpMsg: *const MSG) callconv(WINAPI) LRESULT;
pub var pfnDispatchMessageW: @TypeOf(DispatchMessageW) = undefined;
pub fn dispatchMessageW(lpMsg: *const MSG) LRESULT {
    const function = selectSymbol(DispatchMessageW, pfnDispatchMessageW, .win2k);
    return function(lpMsg);
}

pub extern "user32" fn PostQuitMessage(nExitCode: i32) callconv(WINAPI) void;
pub fn postQuitMessage(nExitCode: i32) void {
    PostQuitMessage(nExitCode);
}

pub extern "user32" fn DefWindowProcA(hWnd: HWND, Msg: UINT, wParam: WPARAM, lParam: LPARAM) callconv(WINAPI) LRESULT;
pub fn defWindowProcA(hWnd: HWND, Msg: UINT, wParam: WPARAM, lParam: LPARAM) LRESULT {
    return DefWindowProcA(hWnd, Msg, wParam, lParam);
}

pub extern "user32" fn DefWindowProcW(hWnd: HWND, Msg: UINT, wParam: WPARAM, lParam: LPARAM) callconv(WINAPI) LRESULT;
pub var pfnDefWindowProcW: @TypeOf(DefWindowProcW) = undefined;
pub fn defWindowProcW(hWnd: HWND, Msg: UINT, wParam: WPARAM, lParam: LPARAM) LRESULT {
    const function = selectSymbol(DefWindowProcW, pfnDefWindowProcW, .win2k);
    return function(hWnd, Msg, wParam, lParam);
}

// === Windows ===

pub const CS_VREDRAW = 0x0001;
pub const CS_HREDRAW = 0x0002;
pub const CS_DBLCLKS = 0x0008;
pub const CS_OWNDC = 0x0020;
pub const CS_CLASSDC = 0x0040;
pub const CS_PARENTDC = 0x0080;
pub const CS_NOCLOSE = 0x0200;
pub const CS_SAVEBITS = 0x0800;
pub const CS_BYTEALIGNCLIENT = 0x1000;
pub const CS_BYTEALIGNWINDOW = 0x2000;
pub const CS_GLOBALCLASS = 0x4000;

pub const WNDCLASSEXA = extern struct {
    cbSize: UINT = @sizeOf(WNDCLASSEXA),
    style: UINT,
    lpfnWndProc: WNDPROC,
    cbClsExtra: i32 = 0,
    cbWndExtra: i32 = 0,
    hInstance: HINSTANCE,
    hIcon: ?HICON,
    hCursor: ?HCURSOR,
    hbrBackground: ?HBRUSH,
    lpszMenuName: ?[*:0]const u8,
    lpszClassName: [*:0]const u8,
    hIconSm: ?HICON,
};

pub const WNDCLASSEXW = extern struct {
    cbSize: UINT = @sizeOf(WNDCLASSEXW),
    style: UINT,
    lpfnWndProc: WNDPROC,
    cbClsExtra: i32 = 0,
    cbWndExtra: i32 = 0,
    hInstance: HINSTANCE,
    hIcon: ?HICON,
    hCursor: ?HCURSOR,
    hbrBackground: ?HBRUSH,
    lpszMenuName: ?[*:0]const u16,
    lpszClassName: [*:0]const u16,
    hIconSm: ?HICON,
};

pub extern "user32" fn RegisterClassExA(*const WNDCLASSEXA) callconv(WINAPI) ATOM;
pub fn registerClassExA(window_class: *const WNDCLASSEXA) !ATOM {
    const atom = RegisterClassExA(window_class);
    if (atom != 0) return atom;
    switch (GetLastError()) {
        .CLASS_ALREADY_EXISTS => return error.AlreadyExists,
        .INVALID_PARAMETER => unreachable,
        else => |err| return windows.unexpectedError(err),
    }
}

pub extern "user32" fn RegisterClassExW(*const WNDCLASSEXW) callconv(WINAPI) ATOM;
pub var pfnRegisterClassExW: @TypeOf(RegisterClassExW) = undefined;
pub fn registerClassExW(window_class: *const WNDCLASSEXW) !ATOM {
    const function = selectSymbol(RegisterClassExW, pfnRegisterClassExW, .win2k);
    const atom = function(window_class);
    if (atom != 0) return atom;
    switch (GetLastError()) {
        .CLASS_ALREADY_EXISTS => return error.AlreadyExists,
        .CALL_NOT_IMPLEMENTED => unreachable,
        .INVALID_PARAMETER => unreachable,
        else => |err| return windows.unexpectedError(err),
    }
}

pub extern "user32" fn UnregisterClassA(lpClassName: [*:0]const u8, hInstance: HINSTANCE) callconv(WINAPI) BOOL;
pub fn unregisterClassA(lpClassName: [*:0]const u8, hInstance: HINSTANCE) !void {
    if (UnregisterClassA(lpClassName, hInstance) == 0) {
        switch (GetLastError()) {
            .CLASS_DOES_NOT_EXIST => return error.ClassDoesNotExist,
            else => |err| return windows.unexpectedError(err),
        }
    }
}

pub extern "user32" fn UnregisterClassW(lpClassName: [*:0]const u16, hInstance: HINSTANCE) callconv(WINAPI) BOOL;
pub var pfnUnregisterClassW: @TypeOf(UnregisterClassW) = undefined;
pub fn unregisterClassW(lpClassName: [*:0]const u16, hInstance: HINSTANCE) !void {
    const function = selectSymbol(UnregisterClassW, pfnUnregisterClassW, .win2k);
    if (function(lpClassName, hInstance) == 0) {
        switch (GetLastError()) {
            .CLASS_DOES_NOT_EXIST => return error.ClassDoesNotExist,
            else => |err| return windows.unexpectedError(err),
        }
    }
}

pub const WS_OVERLAPPED = 0x00000000;
pub const WS_POPUP = 0x80000000;
pub const WS_CHILD = 0x40000000;
pub const WS_MINIMIZE = 0x20000000;
pub const WS_VISIBLE = 0x10000000;
pub const WS_DISABLED = 0x08000000;
pub const WS_CLIPSIBLINGS = 0x04000000;
pub const WS_CLIPCHILDREN = 0x02000000;
pub const WS_MAXIMIZE = 0x01000000;
pub const WS_CAPTION = WS_BORDER | WS_DLGFRAME;
pub const WS_BORDER = 0x00800000;
pub const WS_DLGFRAME = 0x00400000;
pub const WS_VSCROLL = 0x00200000;
pub const WS_HSCROLL = 0x00100000;
pub const WS_SYSMENU = 0x00080000;
pub const WS_THICKFRAME = 0x00040000;
pub const WS_GROUP = 0x00020000;
pub const WS_TABSTOP = 0x00010000;
pub const WS_MINIMIZEBOX = 0x00020000;
pub const WS_MAXIMIZEBOX = 0x00010000;
pub const WS_TILED = WS_OVERLAPPED;
pub const WS_ICONIC = WS_MINIMIZE;
pub const WS_SIZEBOX = WS_THICKFRAME;
pub const WS_TILEDWINDOW = WS_OVERLAPPEDWINDOW;
pub const WS_OVERLAPPEDWINDOW = WS_OVERLAPPED | WS_CAPTION | WS_SYSMENU | WS_THICKFRAME | WS_MINIMIZEBOX | WS_MAXIMIZEBOX;
pub const WS_POPUPWINDOW = WS_POPUP | WS_BORDER | WS_SYSMENU;
pub const WS_CHILDWINDOW = WS_CHILD;

pub const WS_EX_DLGMODALFRAME = 0x00000001;
pub const WS_EX_NOPARENTNOTIFY = 0x00000004;
pub const WS_EX_TOPMOST = 0x00000008;
pub const WS_EX_ACCEPTFILES = 0x00000010;
pub const WS_EX_TRANSPARENT = 0x00000020;
pub const WS_EX_MDICHILD = 0x00000040;
pub const WS_EX_TOOLWINDOW = 0x00000080;
pub const WS_EX_WINDOWEDGE = 0x00000100;
pub const WS_EX_CLIENTEDGE = 0x00000200;
pub const WS_EX_CONTEXTHELP = 0x00000400;
pub const WS_EX_RIGHT = 0x00001000;
pub const WS_EX_LEFT = 0x00000000;
pub const WS_EX_RTLREADING = 0x00002000;
pub const WS_EX_LTRREADING = 0x00000000;
pub const WS_EX_LEFTSCROLLBAR = 0x00004000;
pub const WS_EX_RIGHTSCROLLBAR = 0x00000000;
pub const WS_EX_CONTROLPARENT = 0x00010000;
pub const WS_EX_STATICEDGE = 0x00020000;
pub const WS_EX_APPWINDOW = 0x00040000;
pub const WS_EX_LAYERED = 0x00080000;
pub const WS_EX_OVERLAPPEDWINDOW = WS_EX_WINDOWEDGE | WS_EX_CLIENTEDGE;
pub const WS_EX_PALETTEWINDOW = WS_EX_WINDOWEDGE | WS_EX_TOOLWINDOW | WS_EX_TOPMOST;

pub const CW_USEDEFAULT = @bitCast(i32, @as(u32, 0x80000000));

pub extern "user32" fn CreateWindowExA(dwExStyle: DWORD, lpClassName: [*:0]const u8, lpWindowName: [*:0]const u8, dwStyle: DWORD, X: i32, Y: i32, nWidth: i32, nHeight: i32, hWindParent: ?HWND, hMenu: ?HMENU, hInstance: HINSTANCE, lpParam: ?LPVOID) callconv(WINAPI) ?HWND;
pub fn createWindowExA(dwExStyle: u32, lpClassName: [*:0]const u8, lpWindowName: [*:0]const u8, dwStyle: u32, X: i32, Y: i32, nWidth: i32, nHeight: i32, hWindParent: ?HWND, hMenu: ?HMENU, hInstance: HINSTANCE, lpParam: ?*c_void) !HWND {
    const window = CreateWindowExA(dwExStyle, lpClassName, lpWindowName, dwStyle, X, Y, nWidth, nHeight, hWindParent, hMenu, hInstance, lpParam);
    if (window) |win| return win;

    switch (GetLastError()) {
        .CLASS_DOES_NOT_EXIST => return error.ClassDoesNotExist,
        .INVALID_PARAMETER => unreachable,
        else => |err| return windows.unexpectedError(err),
    }
}

pub extern "user32" fn CreateWindowExW(dwExStyle: DWORD, lpClassName: [*:0]const u16, lpWindowName: [*:0]const u16, dwStyle: DWORD, X: i32, Y: i32, nWidth: i32, nHeight: i32, hWindParent: ?HWND, hMenu: ?HMENU, hInstance: HINSTANCE, lpParam: ?LPVOID) callconv(WINAPI) ?HWND;
pub var pfnCreateWindowExW: @TypeOf(CreateWindowExW) = undefined;
pub fn createWindowExW(dwExStyle: u32, lpClassName: [*:0]const u16, lpWindowName: [*:0]const u16, dwStyle: u32, X: i32, Y: i32, nWidth: i32, nHeight: i32, hWindParent: ?HWND, hMenu: ?HMENU, hInstance: HINSTANCE, lpParam: ?*c_void) !HWND {
    const function = selectSymbol(CreateWindowExW, pfnCreateWindowExW, .win2k);
    const window = function(dwExStyle, lpClassName, lpWindowName, dwStyle, X, Y, nWidth, nHeight, hWindParent, hMenu, hInstance, lpParam);
    if (window) |win| return win;

    switch (GetLastError()) {
        .CLASS_DOES_NOT_EXIST => return error.ClassDoesNotExist,
        .INVALID_PARAMETER => unreachable,
        else => |err| return windows.unexpectedError(err),
    }
}

pub extern "user32" fn DestroyWindow(hWnd: HWND) callconv(WINAPI) BOOL;
pub fn destroyWindow(hWnd: HWND) !void {
    if (DestroyWindow(hWnd) == 0) {
        switch (GetLastError()) {
            .INVALID_WINDOW_HANDLE => unreachable,
            .INVALID_PARAMETER => unreachable,
            else => |err| return windows.unexpectedError(err),
        }
    }
}

pub const SW_HIDE = 0;
pub const SW_SHOWNORMAL = 1;
pub const SW_NORMAL = 1;
pub const SW_SHOWMINIMIZED = 2;
pub const SW_SHOWMAXIMIZED = 3;
pub const SW_MAXIMIZE = 3;
pub const SW_SHOWNOACTIVATE = 4;
pub const SW_SHOW = 5;
pub const SW_MINIMIZE = 6;
pub const SW_SHOWMINNOACTIVE = 7;
pub const SW_SHOWNA = 8;
pub const SW_RESTORE = 9;
pub const SW_SHOWDEFAULT = 10;
pub const SW_FORCEMINIMIZE = 11;
pub const SW_MAX = 11;

pub extern "user32" fn ShowWindow(hWnd: HWND, nCmdShow: i32) callconv(WINAPI) BOOL;
pub fn showWindow(hWnd: HWND, nCmdShow: i32) bool {
    return (ShowWindow(hWnd, nCmdShow) == TRUE);
}

pub extern "user32" fn UpdateWindow(hWnd: HWND) callconv(WINAPI) BOOL;
pub fn updateWindow(hWnd: HWND) !void {
    if (ShowWindow(hWnd, nCmdShow) == 0) {
        switch (GetLastError()) {
            .INVALID_WINDOW_HANDLE => unreachable,
            .INVALID_PARAMETER => unreachable,
            else => |err| return windows.unexpectedError(err),
        }
    }
}

pub extern "user32" fn AdjustWindowRectEx(lpRect: *RECT, dwStyle: DWORD, bMenu: BOOL, dwExStyle: DWORD) callconv(WINAPI) BOOL;
pub fn adjustWindowRectEx(lpRect: *RECT, dwStyle: u32, bMenu: bool, dwExStyle: u32) !void {
    assert(dwStyle & WS_OVERLAPPED == 0);

    if (AdjustWindowRectEx(lpRect, dwStyle, bMenu, dwExStyle) == 0) {
        switch (GetLastError()) {
            .INVALID_PARAMETER => unreachable,
            else => |err| return windows.unexpectedError(err),
        }
    }
}

pub const GWL_WNDPROC = -4;
pub const GWL_HINSTANCE = -6;
pub const GWL_HWNDPARENT = -8;
pub const GWL_STYLE = -16;
pub const GWL_EXSTYLE = -20;
pub const GWL_USERDATA = -21;
pub const GWL_ID = -12;

pub extern "user32" fn GetWindowLongA(hWnd: HWND, nIndex: i32) callconv(WINAPI) LONG;
pub fn getWindowLongA(hWnd: HWND, nIndex: i32) !i32 {
    const value = GetWindowLongA(hWnd, nIndex);
    if (value != 0) return value;

    switch (GetLastError()) {
        .SUCCESS => return 0,
        .INVALID_WINDOW_HANDLE => unreachable,
        .INVALID_PARAMETER => unreachable,
        else => |err| return windows.unexpectedError(err),
    }
}

pub extern "user32" fn GetWindowLongW(hWnd: HWND, nIndex: i32) callconv(WINAPI) LONG;
pub var pfnGetWindowLongW: @TypeOf(GetWindowLongW) = undefined;
pub fn getWindowLongW(hWnd: HWND, nIndex: i32) !i32 {
    const function = selectSymbol(GetWindowLongW, pfnGetWindowLongW, .win2k);

    const value = function(hWnd, nIndex);
    if (value != 0) return value;

    switch (GetLastError()) {
        .SUCCESS => return 0,
        .INVALID_WINDOW_HANDLE => unreachable,
        .INVALID_PARAMETER => unreachable,
        else => |err| return windows.unexpectedError(err),
    }
}

pub extern "user32" fn GetWindowLongPtrA(hWnd: HWND, nIndex: i32) callconv(WINAPI) LONG_PTR;
pub fn getWindowLongPtrA(hWnd: HWND, nIndex: i32) !isize {
    // "When compiling for 32-bit Windows, GetWindowLongPtr is defined as a call to the GetWindowLong function."
    // https://docs.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-getwindowlongptrw
    if (@sizeOf(LONG_PTR) == 4) return getWindowLongA(hWnd, nIndex);

    const value = GetWindowLongPtrA(hWnd, nIndex);
    if (value != 0) return value;

    switch (GetLastError()) {
        .SUCCESS => return 0,
        .INVALID_WINDOW_HANDLE => unreachable,
        .INVALID_PARAMETER => unreachable,
        else => |err| return windows.unexpectedError(err),
    }
}

pub extern "user32" fn GetWindowLongPtrW(hWnd: HWND, nIndex: i32) callconv(WINAPI) LONG_PTR;
pub var pfnGetWindowLongPtrW: @TypeOf(GetWindowLongPtrW) = undefined;
pub fn getWindowLongPtrW(hWnd: HWND, nIndex: i32) !isize {
    if (@sizeOf(LONG_PTR) == 4) return getWindowLongW(hWnd, nIndex);
    const function = selectSymbol(GetWindowLongPtrW, pfnGetWindowLongPtrW, .win2k);

    const value = function(hWnd, nIndex);
    if (value != 0) return value;

    switch (GetLastError()) {
        .SUCCESS => return 0,
        .INVALID_WINDOW_HANDLE => unreachable,
        .INVALID_PARAMETER => unreachable,
        else => |err| return windows.unexpectedError(err),
    }
}

pub extern "user32" fn SetWindowLongA(hWnd: HWND, nIndex: i32, dwNewLong: LONG) callconv(WINAPI) LONG;
pub fn setWindowLongA(hWnd: HWND, nIndex: i32, dwNewLong: i32) !i32 {
    // [...] you should clear the last error information by calling SetLastError with 0 before calling SetWindowLong.
    // https://docs.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-setwindowlonga
    SetLastError(.SUCCESS);

    const value = SetWindowLongA(hWnd, nIndex, dwNewLong);
    if (value != 0) return value;

    switch (GetLastError()) {
        .SUCCESS => return 0,
        .INVALID_WINDOW_HANDLE => unreachable,
        .INVALID_PARAMETER => unreachable,
        else => |err| return windows.unexpectedError(err),
    }
}

pub extern "user32" fn SetWindowLongW(hWnd: HWND, nIndex: i32, dwNewLong: LONG) callconv(WINAPI) LONG;
pub var pfnSetWindowLongW: @TypeOf(SetWindowLongW) = undefined;
pub fn setWindowLongW(hWnd: HWND, nIndex: i32, dwNewLong: i32) !i32 {
    const function = selectSymbol(SetWindowLongW, pfnSetWindowLongW, .win2k);

    SetLastError(.SUCCESS);
    const value = function(hWnd, nIndex, dwNewLong);
    if (value != 0) return value;

    switch (GetLastError()) {
        .SUCCESS => return 0,
        .INVALID_WINDOW_HANDLE => unreachable,
        .INVALID_PARAMETER => unreachable,
        else => |err| return windows.unexpectedError(err),
    }
}

pub extern "user32" fn SetWindowLongPtrA(hWnd: HWND, nIndex: i32, dwNewLong: LONG_PTR) callconv(WINAPI) LONG_PTR;
pub fn setWindowLongPtrA(hWnd: HWND, nIndex: i32, dwNewLong: isize) !isize {
    // "When compiling for 32-bit Windows, GetWindowLongPtr is defined as a call to the GetWindowLong function."
    // https://docs.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-getwindowlongptrw
    if (@sizeOf(LONG_PTR) == 4) return setWindowLongA(hWnd, nIndex, dwNewLong);

    SetLastError(.SUCCESS);
    const value = SetWindowLongPtrA(hWnd, nIndex, dwNewLong);
    if (value != 0) return value;

    switch (GetLastError()) {
        .SUCCESS => return 0,
        .INVALID_WINDOW_HANDLE => unreachable,
        .INVALID_PARAMETER => unreachable,
        else => |err| return windows.unexpectedError(err),
    }
}

pub extern "user32" fn SetWindowLongPtrW(hWnd: HWND, nIndex: i32, dwNewLong: LONG_PTR) callconv(WINAPI) LONG_PTR;
pub var pfnSetWindowLongPtrW: @TypeOf(SetWindowLongPtrW) = undefined;
pub fn setWindowLongPtrW(hWnd: HWND, nIndex: i32, dwNewLong: isize) !isize {
    if (@sizeOf(LONG_PTR) == 4) return setWindowLongW(hWnd, nIndex, dwNewLong);
    const function = selectSymbol(SetWindowLongPtrW, pfnSetWindowLongPtrW, .win2k);

    SetLastError(.SUCCESS);
    const value = function(hWnd, nIndex, dwNewLong);
    if (value != 0) return value;

    switch (GetLastError()) {
        .SUCCESS => return 0,
        .INVALID_WINDOW_HANDLE => unreachable,
        .INVALID_PARAMETER => unreachable,
        else => |err| return windows.unexpectedError(err),
    }
}

pub extern "user32" fn GetDC(hWnd: ?HWND) callconv(WINAPI) ?HDC;
pub fn getDC(hWnd: ?HWND) !HDC {
    const hdc = GetDC(hWnd);
    if (hdc) |h| return h;

    switch (GetLastError()) {
        .INVALID_WINDOW_HANDLE => unreachable,
        .INVALID_PARAMETER => unreachable,
        else => |err| return windows.unexpectedError(err),
    }
}

pub extern "user32" fn ReleaseDC(hWnd: ?HWND, hDC: HDC) callconv(WINAPI) i32;
pub fn releaseDC(hWnd: ?HWND, hDC: HDC) bool {
    return if (ReleaseDC(hWnd, hDC) == 1) true else false;
}

// === Modal dialogue boxes ===

pub const MB_OK = 0x00000000;
pub const MB_OKCANCEL = 0x00000001;
pub const MB_ABORTRETRYIGNORE = 0x00000002;
pub const MB_YESNOCANCEL = 0x00000003;
pub const MB_YESNO = 0x00000004;
pub const MB_RETRYCANCEL = 0x00000005;
pub const MB_CANCELTRYCONTINUE = 0x00000006;
pub const MB_ICONHAND = 0x00000010;
pub const MB_ICONQUESTION = 0x00000020;
pub const MB_ICONEXCLAMATION = 0x00000030;
pub const MB_ICONASTERISK = 0x00000040;
pub const MB_USERICON = 0x00000080;
pub const MB_ICONWARNING = MB_ICONEXCLAMATION;
pub const MB_ICONERROR = MB_ICONHAND;
pub const MB_ICONINFORMATION = MB_ICONASTERISK;
pub const MB_ICONSTOP = MB_ICONHAND;
pub const MB_DEFBUTTON1 = 0x00000000;
pub const MB_DEFBUTTON2 = 0x00000100;
pub const MB_DEFBUTTON3 = 0x00000200;
pub const MB_DEFBUTTON4 = 0x00000300;
pub const MB_APPLMODAL = 0x00000000;
pub const MB_SYSTEMMODAL = 0x00001000;
pub const MB_TASKMODAL = 0x00002000;
pub const MB_HELP = 0x00004000;
pub const MB_NOFOCUS = 0x00008000;
pub const MB_SETFOREGROUND = 0x00010000;
pub const MB_DEFAULT_DESKTOP_ONLY = 0x00020000;
pub const MB_TOPMOST = 0x00040000;
pub const MB_RIGHT = 0x00080000;
pub const MB_RTLREADING = 0x00100000;
pub const MB_TYPEMASK = 0x0000000F;
pub const MB_ICONMASK = 0x000000F0;
pub const MB_DEFMASK = 0x00000F00;
pub const MB_MODEMASK = 0x00003000;
pub const MB_MISCMASK = 0x0000C000;

pub const IDOK = 1;
pub const IDCANCEL = 2;
pub const IDABORT = 3;
pub const IDRETRY = 4;
pub const IDIGNORE = 5;
pub const IDYES = 6;
pub const IDNO = 7;
pub const IDCLOSE = 8;
pub const IDHELP = 9;
pub const IDTRYAGAIN = 10;
pub const IDCONTINUE = 11;

pub extern "user32" fn MessageBoxA(hWnd: ?HWND, lpText: [*:0]const u8, lpCaption: [*:0]const u8, uType: UINT) callconv(WINAPI) i32;
pub fn messageBoxA(hWnd: ?HWND, lpText: [*:0]const u8, lpCaption: [*:0]const u8, uType: u32) !i32 {
    const value = MessageBoxA(hWnd, lpText, lpCaption, uType);
    if (value != 0) return value;
    switch (GetLastError()) {
        .INVALID_WINDOW_HANDLE => unreachable,
        .INVALID_PARAMETER => unreachable,
        else => |err| return windows.unexpectedError(err),
    }
}

pub extern "user32" fn MessageBoxW(hWnd: ?HWND, lpText: [*:0]const u16, lpCaption: ?[*:0]const u16, uType: UINT) callconv(WINAPI) i32;
pub var pfnMessageBoxW: @TypeOf(MessageBoxW) = undefined;
pub fn messageBoxW(hWnd: ?HWND, lpText: [*:0]const u16, lpCaption: [*:0]const u16, uType: u32) !i32 {
    const function = selectSymbol(MessageBoxW, pfnMessageBoxW, .win2k);
    const value = function(hWnd, lpText, lpCaption, uType);
    if (value != 0) return value;
    switch (GetLastError()) {
        .INVALID_WINDOW_HANDLE => unreachable,
        .INVALID_PARAMETER => unreachable,
        else => |err| return windows.unexpectedError(err),
    }
}

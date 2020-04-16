usingnamespace @import("bits.zig");

pub const WM = extern enum {
    NULL = 0x0000,
    CREATE = 0x0001,
    DESTROY = 0x0002,
    MOVE = 0x0003,
    SIZE = 0x0005,

    ACTIVATE = 0x0006,
    PAINT = 0x000F,
    CLOSE = 0x0010,
    QUIT = 0x0012,
    SETFOCUS = 0x0007,

    KILLFOCUS = 0x0008,
    ENABLE = 0x000A,
    SETREDRAW = 0x000B,

    SYSCOLORCHANGE = 0x0015,
    SHOWWINDOW = 0x0018,

    WINDOWPOSCHANGING = 0x0046,
    WINDOWPOSCHANGED = 0x0047,
    POWER = 0x0048,

    CONTEXTMENU = 0x007B,
    STYLECHANGING = 0x007C,
    STYLECHANGED = 0x007D,
    DISPLAYCHANGE = 0x007E,
    GETICON = 0x007F,
    SETICON = 0x0080,

    INPUT_DEVICE_CHANGE = 0x00fe,
    INPUT = 0x00FF,
    KEYDOWN = 0x0100,
    KEYUP = 0x0101,
    CHAR = 0x0102,
    DEADCHAR = 0x0103,
    SYSKEYDOWN = 0x0104,
    SYSKEYUP = 0x0105,
    SYSCHAR = 0x0106,
    SYSDEADCHAR = 0x0107,
    UNICHAR = 0x0109,

    COMMAND = 0x0111,
    SYSCOMMAND = 0x0112,
    TIMER = 0x0113,

    MOUSEMOVE = 0x0200,
    LBUTTONDOWN = 0x0201,
    LBUTTONUP = 0x0202,
    LBUTTONDBLCLK = 0x0203,
    RBUTTONDOWN = 0x0204,
    RBUTTONUP = 0x0205,
    RBUTTONDBLCLK = 0x0206,
    MBUTTONDOWN = 0x0207,
    MBUTTONUP = 0x0208,
    MBUTTONDBLCLK = 0x0209,
    MOUSEWHEEL = 0x020A,
    XBUTTONDOWN = 0x020B,
    XBUTTONUP = 0x020C,
    XBUTTONDBLCLK = 0x020D,

    pub const KEYFIRST = @intToEnum(@This(), 0x0100);
    pub const KEYLAST = @intToEnum(@This(), 0x0109);
    pub const MOUSEFIRST = @intToEnum(@This(), 0x0200);
    pub const MOUSELAST = @intToEnum(@This(), 0x020d);
};

pub const WA = extern enum {
    INACTIVE = 0,
    ACTIVE = 1,
    CLICKACTIVE = 2,
};

pub const SW = extern enum {
    HIDE = 0,
    SHOWNORMAL = 1,
    SHOWMINIMIZED = 2,
    MAXIMIZE = 3,
    SHOWNOACTIVE = 4,
    SHOW = 5,
    MINIMIZE = 6,
    SHOWMINNOACTIVE = 7,
    SHOWNA = 8,
    RESTORE = 9,
    SHOWDEFAULT = 10,
    FORCEMINIMIZE = 11,
};

pub const PM_REMOVE = 0x0001;
pub const PM_NOREMOVE = 0x0000;
pub const PM_NOYIELD = 0x0002;

pub const CS_HREDRAW = 0x0002;
pub const CS_VREDRAW = 0x0001;
pub const CS_OWNDC = 0x0020;
pub const CS_BYTEALIGNCLIENT = 0x1000;
pub const CS_BYTEALIGNWINDOW = 0x2000;
pub const CS_CLASSDC = 0x0040;
pub const CS_DBLCLKS = 0x0008;
pub const CS_DROPSHADOW = 0x00020000;
pub const CS_GLOBALCLASS = 0x4000;
pub const CS_NOCLOSE = 0x0200;
pub const CS_PARENTDC = 0x0080;
pub const CS_SAVEBITS = 0x0800;

pub const WS_OVERLAPPED = 0x00000000;
pub const WS_POPUP = 0x80000000;
pub const WS_CHILD = 0x40000000;
pub const WS_MINIMIZE = 0x20000000;
pub const WS_CAPTION = 0x00C00000;
pub const WS_SYSMENU = 0x00080000;
pub const WS_THICKFRAME = 0x00040000;
pub const WS_MINIMIZEBOX = 0x00020000;
pub const WS_MAXIMIZEBOX = 0x00010000;
pub const WS_VISIBLE = 0x10000000;
pub const WS_DISABLED = 0x08000000;
pub const WS_CLIPSIBLINGS = 0x04000000;
pub const WS_CLIPCHILDREN = 0x02000000;
pub const WS_MAXIMIZE = 0x01000000;
pub const WS_BORDER = 0x00800000;
pub const WS_DLGFRAME = 0x00400000;
pub const WS_VSCROLL = 0x00200000;
pub const WS_HSCROLL = 0x00100000;
pub const WS_GROUP = 0x00020000;
pub const WS_TABSTOP = 0x00010000;

pub const WNDPROC = fn (HWND, UINT, WPARAM, LPARAM) callconv(.Stdcall) LRESULT;

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
) callconv(.Stdcall) ?HWND;

pub extern "user32" fn RegisterClassExA(*const WNDCLASSEXA) callconv(.Stdcall) c_ushort;
pub extern "user32" fn DefWindowProcA(HWND, UINT, WPARAM, LPARAM) callconv(.Stdcall) LRESULT;
pub extern "user32" fn GetModuleHandleA(lpModuleName: ?LPCSTR) callconv(.Stdcall) HMODULE;
pub extern "user32" fn ShowWindow(hWnd: ?HWND, nCmdShow: i32) callconv(.Stdcall) bool;
pub extern "user32" fn UpdateWindow(hWnd: ?HWND) callconv(.Stdcall) bool;
pub extern "user32" fn GetDC(hWnd: ?HWND) callconv(.Stdcall) ?HDC;

pub extern "user32" fn PeekMessageA(
    lpMsg: ?*MSG,
    hWnd: ?HWND,
    wMsgFilterMin: UINT,
    wMsgFilterMax: UINT,
    wRemoveMsg: UINT,
) callconv(.Stdcall) bool;

pub extern "user32" fn GetMessageA(
    lpMsg: ?*MSG,
    hWnd: ?HWND,
    wMsgFilterMin: UINT,
    wMsgFilterMax: UINT,
) callconv(.Stdcall) bool;

pub extern "user32" fn TranslateMessage(lpMsg: *const MSG) callconv(.Stdcall) bool;
pub extern "user32" fn DispatchMessageA(lpMsg: *const MSG) callconv(.Stdcall) LRESULT;
pub extern "user32" fn PostQuitMessage(nExitCode: i32) callconv(.Stdcall) void;

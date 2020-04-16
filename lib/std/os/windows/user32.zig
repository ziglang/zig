usingnamespace @import("bits.zig");

pub const WM = extern enum(UINT) {
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

pub const WA = extern enum(UINT) {
    INACTIVE = 0,
    ACTIVE = 1,
    CLICKACTIVE = 2,
};

pub const SW = extern enum(UINT) {
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

pub const VK = extern enum(UINT) {
    LBUTTON = 0x01,
    RBUTTON = 0x02,
    CANCEL = 0x03,
    MBUTTON = 0x04,
    XBUTTON1 = 0x05,
    XBUTTON2 = 0x06,
    BACK = 0x08,
    TAB = 0x09,
    CLEAR = 0x0C,
    RETURN = 0x0D,
    SHIFT = 0x10,
    CONTROL = 0x11,
    MENU = 0x12,
    PAUSE = 0x13,
    CAPITAL = 0x14,
    KANA = 0x15,
    HANGEUL = 0x15,
    HANGUL = 0x15,
    JUNJA = 0x17,
    FINAL = 0x18,
    HANJA = 0x19,
    KANJI = 0x19,
    ESCAPE = 0x1B,
    CONVERT = 0x1C,
    NONCONVERT = 0x1D,
    ACCEPT = 0x1E,
    MODECHANGE = 0x1F,
    SPACE = 0x20,
    PRIOR = 0x21,
    NEXT = 0x22,
    END = 0x23,
    HOME = 0x24,
    LEFT = 0x25,
    UP = 0x26,
    RIGHT = 0x27,
    DOWN = 0x28,
    SELECT = 0x29,
    PRINT = 0x2A,
    EXECUTE = 0x2B,
    SNAPSHOT = 0x2C,
    INSERT = 0x2D,
    DELETE = 0x2E,
    HELP = 0x2F,
    ZERO = 0x30,
    ONE = 0x31,
    TWO = 0x32,
    THREE = 0x33,
    FOUR = 0x34,
    FIVE = 0x35,
    SIX = 0x36,
    SEVEN = 0x37,
    EIGHT = 0x38,
    NINE = 0x39,
    A = 0x41,
    B = 0x42,
    C = 0x43,
    D = 0x44,
    E = 0x45,
    F = 0x46,
    G = 0x47,
    H = 0x48,
    I = 0x49,
    J = 0x4A,
    K = 0x4B,
    L = 0x4C,
    M = 0x4D,
    N = 0x4E,
    O = 0x4F,
    P = 0x50,
    Q = 0x51,
    R = 0x52,
    S = 0x53,
    T = 0x54,
    U = 0x55,
    V = 0x56,
    W = 0x57,
    X = 0x58,
    Y = 0x59,
    Z = 0x5A,
    LWIN = 0x5B,
    RWIN = 0x5C,
    APPS = 0x5D,
    SLEEP = 0x5F,
    NUMPAD0 = 0x60,
    NUMPAD1 = 0x61,
    NUMPAD2 = 0x62,
    NUMPAD3 = 0x63,
    NUMPAD4 = 0x64,
    NUMPAD5 = 0x65,
    NUMPAD6 = 0x66,
    NUMPAD7 = 0x67,
    NUMPAD8 = 0x68,
    NUMPAD9 = 0x69,
    MULTIPLY = 0x6A,
    ADD = 0x6B,
    SEPARATOR = 0x6C,
    SUBTRACT = 0x6D,
    DECIMAL = 0x6E,
    DIVIDE = 0x6F,
    F1 = 0x70,
    F2 = 0x71,
    F3 = 0x72,
    F4 = 0x73,
    F5 = 0x74,
    F6 = 0x75,
    F7 = 0x76,
    F8 = 0x77,
    F9 = 0x78,
    F10 = 0x79,
    F11 = 0x7A,
    F12 = 0x7B,
    F13 = 0x7C,
    F14 = 0x7D,
    F15 = 0x7E,
    F16 = 0x7F,
    F17 = 0x80,
    F18 = 0x81,
    F19 = 0x82,
    F20 = 0x83,
    F21 = 0x84,
    F22 = 0x85,
    F23 = 0x86,
    F24 = 0x87,
    NUMLOCK = 0x90,
    SCROLL = 0x91,
    OEM_NEC_EQUAL = 0x92,
    OEM_FJ_JISHO = 0x92,
    OEM_FJ_MASSHOU = 0x93,
    OEM_FJ_TOUROKU = 0x94,
    OEM_FJ_LOYA = 0x95,
    OEM_FJ_ROYA = 0x96,
    LSHIFT = 0xA0,
    RSHIFT = 0xA1,
    LCONTROL = 0xA2,
    RCONTROL = 0xA3,
    LMENU = 0xA4,
    RMENU = 0xA5,
    BROWSER_BACK = 0xA6,
    BROWSER_FORWARD = 0xA7,
    BROWSER_REFRESH = 0xA8,
    BROWSER_STOP = 0xA9,
    BROWSER_SEARCH = 0xAA,
    BROWSER_FAVORITES = 0xAB,
    BROWSER_HOME = 0xAC,
    VOLUME_MUTE = 0xAD,
    VOLUME_DOWN = 0xAE,
    VOLUME_UP = 0xAF,
    MEDIA_NEXT_TRACK = 0xB0,
    MEDIA_PREV_TRACK = 0xB1,
    MEDIA_STOP = 0xB2,
    MEDIA_PLAY_PAUSE = 0xB3,
    LAUNCH_MAIL = 0xB4,
    LAUNCH_MEDIA_SELECT = 0xB5,
    LAUNCH_APP1 = 0xB6,
    LAUNCH_APP2 = 0xB7,
    OEM_1 = 0xBA,
    OEM_PLUS = 0xBB,
    OEM_COMMA = 0xBC,
    OEM_MINUS = 0xBD,
    OEM_PERIOD = 0xBE,
    OEM_2 = 0xBF,
    OEM_3 = 0xC0,
    OEM_4 = 0xDB,
    OEM_5 = 0xDC,
    OEM_6 = 0xDD,
    OEM_7 = 0xDE,
    OEM_8 = 0xDF,
    OEM_AX = 0xE1,
    OEM_102 = 0xE2,
    ICO_HELP = 0xE3,
    ICO_00 = 0xE4,
    PROCESSKEY = 0xE5,
    ICO_CLEAR = 0xE6,
    PACKET = 0xE7,
    OEM_RESET = 0xE9,
    OEM_JUMP = 0xEA,
    OEM_PA1 = 0xEB,
    OEM_PA2 = 0xEC,
    OEM_PA3 = 0xED,
    OEM_WSCTRL = 0xEE,
    OEM_CUSEL = 0xEF,
    OEM_ATTN = 0xF0,
    OEM_FINISH = 0xF1,
    OEM_COPY = 0xF2,
    OEM_AUTO = 0xF3,
    OEM_ENLW = 0xF4,
    OEM_BACKTAB = 0xF5,
    ATTN = 0xF6,
    CRSEL = 0xF7,
    EXSEL = 0xF8,
    EREOF = 0xF9,
    PLAY = 0xFA,
    ZOOM = 0xFB,
    NONAME = 0xFC,
    PA1 = 0xFD,
    OEM_CLEAR = 0xFE,
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

pub const WNDPROC = fn (HWND, WM, WPARAM, LPARAM) callconv(.Stdcall) LRESULT;

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
    message: WM,
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
pub extern "user32" fn DefWindowProcA(HWND, WM, WPARAM, LPARAM) callconv(.Stdcall) LRESULT;
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

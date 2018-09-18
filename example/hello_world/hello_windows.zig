use @import("std").os.windows;

extern "user32" stdcallcc fn MessageBoxA(hWnd: ?HANDLE, lpText: ?LPCTSTR, lpCaption: ?LPCTSTR, uType: UINT) c_int;

export fn WinMain(hInstance: HINSTANCE, hPrevInstance: HINSTANCE, lpCmdLine: PWSTR, nCmdShow: INT) INT {
    _ = MessageBoxA(null, c"hello", c"title", 0);
    return 0;
}

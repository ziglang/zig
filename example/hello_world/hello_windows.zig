use @import("std").os.windows;

export fn WinMain(hInstance: HINSTANCE, hPrevInstance: HINSTANCE, lpCmdLine: PWSTR, nCmdShow: INT) INT {
    _ = MessageBoxA(null, c"hello", c"title", 0);
    return 0;
}

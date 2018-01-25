// This file is included in the compilation unit when exporting a library on windows.

const std = @import("std");

comptime {
    @export("_DllMainCRTStartup", _DllMainCRTStartup);
}

stdcallcc fn _DllMainCRTStartup(hinstDLL: std.os.windows.HINSTANCE, fdwReason: std.os.windows.DWORD,
    lpReserved: std.os.windows.LPVOID) std.os.windows.BOOL
{
    return std.os.windows.TRUE;
}

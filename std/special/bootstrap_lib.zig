// This file is included in the compilation unit when exporting a library on windows.

const std = @import("std");
const builtin = @import("builtin");

comptime {
    @export("_DllMainCRTStartup", _DllMainCRTStartup, builtin.GlobalLinkage.Strong);
}

stdcallcc fn _DllMainCRTStartup(
    hinstDLL: std.os.windows.HINSTANCE,
    fdwReason: std.os.windows.DWORD,
    lpReserved: std.os.windows.LPVOID,
) std.os.windows.BOOL {
    return std.os.windows.TRUE;
}

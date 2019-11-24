// This file is included in the compilation unit when exporting a DLL on windows.

const root = @import("root");
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
    if (@hasDecl(root, "DllMain")) {
        return root.DllMain(hinstDLL, fdwReason, lpReserved);
    }

    return std.os.windows.TRUE;
}

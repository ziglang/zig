use @import("index.zig");

pub extern "shlwapi" stdcallcc fn PathFileExistsA(pszPath: ?LPCTSTR) BOOL;


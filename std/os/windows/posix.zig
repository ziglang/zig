// Declarations that are intended to be imported into the POSIX namespace.
const std = @import("../../std.zig");
const maxInt = std.math.maxInt;
use std.os.windows;

pub const fd_t = HANDLE;

/// The standard input device. Initially, this is the console input buffer, CONIN$.
pub const STD_INPUT_HANDLE = maxInt(DWORD) - 10 + 1;

/// The standard output device. Initially, this is the active console screen buffer, CONOUT$.
pub const STD_OUTPUT_HANDLE = maxInt(DWORD) - 11 + 1;

/// The standard error device. Initially, this is the active console screen buffer, CONOUT$.
pub const STD_ERROR_HANDLE = maxInt(DWORD) - 12 + 1;

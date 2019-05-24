// Declarations that are intended to be imported into the POSIX namespace,
// when not linking libc.
const std = @import("../../std.zig");
const builtin = @import("builtin");

pub const fd_t = std.os.windows.HANDLE;

const builtin = @import("builtin");
const separator = if (builtin.os.tag == .windows) '\\' else '/';

// syntax

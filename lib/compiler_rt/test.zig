// Include all tests.
comptime {
    _ = @import("test/exp.zig");
    _ = @import("test/exp2.zig");
    _ = @import("test/log.zig");
    _ = @import("test/log2.zig");
    _ = @import("test/log10.zig");
}

const std = @import("std");
const assert = std.debug.assert;

const build_options = @import("build_options");

test "build options" {
    comptime assert(build_options.bool_true);
    comptime assert(!build_options.bool_false);
    comptime assert(build_options.int == 1234);
    comptime assert(build_options.e == .two);
    comptime assert(std.mem.eql(u8, build_options.string, "hello"));
}

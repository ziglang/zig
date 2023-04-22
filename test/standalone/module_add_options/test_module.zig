const options = @import("test_options");
const std = @import("std");

pub fn hasOption() void {
    std.debug.assert(options.option);
}

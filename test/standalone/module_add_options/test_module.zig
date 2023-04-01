const options = @import("test_options");
const std = @import("std");

pub fn hasOption() void {
    std.debug.print("Option: {}", .{options.option});
    std.debug.assert(options.option);
}

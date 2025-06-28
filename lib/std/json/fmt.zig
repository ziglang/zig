const std = @import("../std.zig");
const assert = std.debug.assert;

const stringify = @import("stringify.zig").stringify;
const StringifyOptions = @import("stringify.zig").StringifyOptions;

/// Returns a formatter that formats the given value using stringify.
pub fn fmt(value: anytype, options: StringifyOptions) Formatter(@TypeOf(value)) {
    return Formatter(@TypeOf(value)){ .value = value, .options = options };
}

/// Formats the given value using stringify.
pub fn Formatter(comptime T: type) type {
    return struct {
        value: T,
        options: StringifyOptions,

        pub fn format(self: @This(), writer: *std.io.Writer, comptime f: []const u8) std.io.Writer.Error!void {
            comptime assert(f.len == 0);
            try stringify(self.value, self.options, writer);
        }
    };
}

test fmt {
    const expectFmt = std.testing.expectFmt;
    try expectFmt("123", "{}", .{fmt(@as(u32, 123), .{})});
    try expectFmt(
        \\{"num":927,"msg":"hello","sub":{"mybool":true}}
    , "{}", .{fmt(struct {
        num: u32,
        msg: []const u8,
        sub: struct {
            mybool: bool,
        },
    }{
        .num = 927,
        .msg = "hello",
        .sub = .{ .mybool = true },
    }, .{})});
}

const std = @import("std");

const Error = error{InvalidCharacter};

const Direction = enum { upside_down };

const Barrrr = union(enum) {
    float: f64,
    direction: Direction,
};

fn fooey(bar: std.meta.Tag(Barrrr), args: []const []const u8) !Barrrr {
    return switch (bar) {
        .float => .{ .float = try std.fmt.parseFloat(f64, args[0]) },
        .direction => if (std.mem.eql(u8, args[0], "upside_down"))
            Barrrr{ .direction = .upside_down }
        else
            error.InvalidDirection,
    };
}

pub fn main() Error!void {
    std.debug.print("{}", .{try fooey(.direction, &[_][]const u8{ "one", "two", "three" })});
}

// error
// backend=llvm
// target=native
//
// :23:29: error: expected type 'error{InvalidCharacter}', found '@typeInfo(@typeInfo(@TypeOf(tmp.fooey)).Fn.return_type.?).ErrorUnion.error_set'
// :23:29: note: 'error.InvalidDirection' not a member of destination error set

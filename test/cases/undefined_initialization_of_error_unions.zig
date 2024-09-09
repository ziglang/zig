const builtin = @import("builtin");

pub fn main() !void {
    if (builtin.mode == .Debug) {
        var foo: ?u32 = undefined;
        if (foo == null) return error.Miscompilation;
        foo = undefined;
    }
    var a: anyerror!u32 = undefined;
    _ = a catch return error.Miscompilation;
    a = undefined;
}

// run
//

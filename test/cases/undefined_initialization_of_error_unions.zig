pub fn main() !void {
    var a: anyerror!u32 = undefined;
    _ = a catch return error.Miscompilation;
    a = undefined;
}

// run
//

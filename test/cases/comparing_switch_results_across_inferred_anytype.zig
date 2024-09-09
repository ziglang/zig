pub fn main() !void {
    const x: u32 = 1;
    var y: u32 = undefined;
    y = x;

    const a = switch (x) {
        1 => 1,
        else => 3,
    };

    const b = anytypeInner(.{switch (y) {
        1 => "1",
        else => "3",
    }});

    if (b[0] - '0' != a) return error.Miscompilation;
}

fn anytypeInner(thing: anytype) []const u8 {
    return thing[0];
}

// run
//

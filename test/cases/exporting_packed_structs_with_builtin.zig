const P = packed struct { x: u32 };
const p = P{ .x = 234 };
comptime {
    @export(&p, .{ .name = "p" });
}

// compile
//

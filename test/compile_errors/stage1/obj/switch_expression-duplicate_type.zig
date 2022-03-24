fn foo(comptime T: type, x: T) u8 {
    _ = x;
    return switch (T) {
        u32 => 0,
        u64 => 1,
        u32 => 2,
        else => 3,
    };
}
export fn entry() usize { return @sizeOf(@TypeOf(foo(u32, 0))); }

// switch expression - duplicate type
//
// tmp.zig:6:9: error: duplicate switch value
// tmp.zig:4:9: note: previous value here

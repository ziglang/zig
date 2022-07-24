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

// error
// backend=stage2
// target=native
//
// :6:9: error: duplicate switch value
// :4:9: note: previous value here

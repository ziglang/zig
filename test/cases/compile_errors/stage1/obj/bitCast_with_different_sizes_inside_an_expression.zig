export fn entry() void {
    var foo = (@bitCast(u8, @as(f32, 1.0)) == 0xf);
    _ = foo;
}

// error
// backend=stage1
// target=native
//
// tmp.zig:2:25: error: destination type 'u8' has size 1 but source type 'f32' has size 4

export fn entry() void {
    @alignCast(4, @as(u32, 3));
}

// @alignCast expects pointer or slice
//
// tmp.zig:2:19: error: expected pointer or slice, found 'u32'

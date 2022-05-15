export fn entry() void {
    var x: u32 = 0;
    @atomicStore(u32, &x, 1, .Acquire);
}

// error
// backend=stage1
// target=native
//
// tmp.zig:3:30: error: @atomicStore atomic ordering must not be Acquire or AcqRel

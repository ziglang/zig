export fn entry() void {
    var x: u32 = 0;
    @atomicStore(u32, &x, 1, .Acquire);
}

// error
// backend=stage2
// target=native
//
// :3:31: error: @atomicStore atomic ordering must not be Acquire or AcqRel

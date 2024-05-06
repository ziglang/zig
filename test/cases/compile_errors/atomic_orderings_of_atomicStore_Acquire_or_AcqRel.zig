export fn entry() void {
    var x: u32 = 0;
    @atomicStore(u32, &x, 1, .acquire);
}

// error
// backend=stage2
// target=native
//
// :3:31: error: @atomicStore atomic ordering must not be acquire or acq_rel

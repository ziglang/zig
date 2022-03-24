export fn entry() void {
    var x: u32 = 0;
    @atomicStore(u32, &x, 1, .Acquire);
}

// atomic orderings of atomicStore Acquire or AcqRel
//
// tmp.zig:3:30: error: @atomicStore atomic ordering must not be Acquire or AcqRel

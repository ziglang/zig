const std = @import("std");

comptime {
    var val: u8 = 15;
    var opt_ptr: ?*const u8 = &val;

    const payload_ptr = &opt_ptr.?;
    opt_ptr = null;
    _ = payload_ptr.*.*; // TODO: this case was regressed by #19630
}
comptime {
    var opt: ?u8 = 15;

    const payload_ptr = &opt.?;
    opt = null;
    _ = payload_ptr.*;
}
comptime {
    const val: u8 = 15;
    var err_union: anyerror!u8 = val;

    const payload_ptr = &(err_union catch unreachable);
    err_union = error.Foo;
    _ = payload_ptr.*;
}

// error
// backend=stage2
// target=native
//
// :16:20: error: attempt to use null value
// :24:20: error: attempt to unwrap error: Foo

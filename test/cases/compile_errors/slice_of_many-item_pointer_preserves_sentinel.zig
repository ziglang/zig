comptime {
    var ptr: [*]const u8 = undefined;
    _ = ptr[0.. :0];
}

comptime {
    var ptrz: [*:0]const u8 = undefined;
    _ = ptrz[0.. :1];
}

// error
//
// :3:18: error: sentinel-terminated slicing is not permitted on many-item pointer without sentinel
// :3:12: note: use @ptrCast to cast pointer sentinel
// :8:19: error: sentinel-terminated slicing of many-item pointer must preserve sentinel; expected sentinel 0, found 1
// :8:13: note: use @ptrCast to cast pointer sentinel

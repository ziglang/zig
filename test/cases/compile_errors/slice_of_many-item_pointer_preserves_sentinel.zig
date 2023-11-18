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
// :3:18: error: cannot perform slice with sentinel '0' on pointer without sentinel
// :3:12: note: use @ptrCast to cast pointer sentinel
// :8:19: error: cannot perform slice with sentinel '1' on pointer with sentinel '0'
// :8:13: note: use @ptrCast to cast pointer sentinel

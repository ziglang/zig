export fn entry() void {
    _ = @import("zon/neg_inf.zon");
}

// error
// imports=zon/neg_inf.zon
//
// neg_inf.zon:1:1: error: negative infinity requires a known result type
// tmp.zig:2:17: note: imported here

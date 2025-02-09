export fn entry() void {
    const f: [5]u8 = @import("zon/hello.zon");
    _ = f;
}

// error
// imports=zon/hello.zon
//
// hello.zon:1:1: error: expected type '[5]u8'
// tmp.zig:2:30: note: imported here

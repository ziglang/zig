export fn entry() void {
    const f: bool = @import("zon/struct.zon");
    _ = f;
}

// error
// imports=zon/struct.zon
//
// struct.zon:1:2: error: expected type 'bool'
// tmp.zig:2:29: note: imported here

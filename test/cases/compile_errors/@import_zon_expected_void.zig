export fn entry() void {
    const U = union(enum) { a: void };
    const f: U = @import("zon/simple_union.zon");
    _ = f;
}

// error
// imports=zon/simple_union.zon
//
// simple_union.zon:1:9: error: expected type 'void'
// tmp.zig:3:26: note: imported here

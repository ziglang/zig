export fn a() void {
    var x: *anyopaque = undefined;
    var y: [*c]anyopaque = x;
    _ = y;
}

// C pointer to anyopaque
//
// tmp.zig:3:16: error: C pointers cannot point to opaque types

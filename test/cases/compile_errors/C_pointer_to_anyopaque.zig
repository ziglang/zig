export fn a() void {
    var x: *anyopaque = undefined;
    var y: [*c]anyopaque = x;
    _ = .{ &x, &y };
}

// error
// backend=stage2
// target=native
//
// :3:16: error: C pointers cannot point to opaque types

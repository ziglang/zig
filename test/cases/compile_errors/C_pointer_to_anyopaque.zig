export fn a() void {
    var x: *anyopaque = undefined;
    var y: [*c]anyopaque = x;
    _ = .{ &x, &y };
}

// error
//
// :3:16: error: C pointers cannot point to opaque types

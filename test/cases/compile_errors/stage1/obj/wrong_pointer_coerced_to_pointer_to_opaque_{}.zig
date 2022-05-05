const Derp = opaque {};
extern fn bar(d: *Derp) void;
export fn foo() void {
    var x = @as(u8, 1);
    bar(@ptrCast(*anyopaque, &x));
}

// error
// backend=stage1
// target=native
//
// tmp.zig:5:9: error: expected type '*Derp', found '*anyopaque'

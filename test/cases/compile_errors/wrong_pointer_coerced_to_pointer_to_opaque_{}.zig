const Derp = opaque {};
extern fn bar(d: *Derp) void;
export fn foo() void {
    var x = @as(u8, 1);
    bar(@as(*anyopaque, @ptrCast(&x)));
}

// error
// backend=stage2
// target=native
//
// :5:9: error: expected type '*tmp.Derp', found '*anyopaque'
// :5:9: note: pointer type child 'anyopaque' cannot cast into pointer type child 'tmp.Derp'
// :1:14: note: opaque declared here
// :2:18: note: parameter type declared here

comptime {
    var a: *align(2) @TypeOf(foo) = undefined;
    _ = a;
}
fn foo() void {}

comptime {
    var a: *align(1) fn () void = undefined;
    _ = a;
}
comptime {
    var a: *align(2) fn () align(2) void = undefined;
    _ = a;
}
comptime {
    var a: *align(2) fn () void = undefined;
    _ = a;
}

// error
// backend=stage2
// target=x86_64-linux
//
// :2:19: error: function pointer alignment disagrees with function alignment
// :16:19: error: function pointer alignment disagrees with function alignment

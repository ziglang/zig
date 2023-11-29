comptime {
    var a: *align(2) @TypeOf(foo) = undefined;
    _ = &a;
}
fn foo() void {}

comptime {
    var a: *align(1) fn () void = undefined;
    _ = &a;
}
comptime {
    var a: *align(2) fn () align(2) void = undefined;
    _ = &a;
}
comptime {
    var a: *align(2) fn () void = undefined;
    _ = &a;
}
comptime {
    var a: *align(1) fn () align(2) void = undefined;
    _ = &a;
}

// error
// backend=stage2
// target=native
//
// :20:19: error: function pointer alignment disagrees with function alignment

fn f(noalias x: i32) void {
    _ = x;
}
export fn entry() void {
    f(1234);
}

fn generic(comptime T: type, noalias _: [*]T, noalias _: [*]const T, _: usize) void {}
comptime {
    _ = &generic;
}

fn slice(noalias _: []u8) void {}
comptime {
    _ = &slice;
}

// error
//
// :1:6: error: non-pointer parameter declared noalias

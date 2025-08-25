fn f(_: i32) void {}
export fn wrong_param_count() void {
    _ = @as(fn () void, f);
}
export fn wrong_param_type() void {
    _ = @as(fn (f32) void, f);
}
export fn wrong_return_type() void {
    _ = @as(fn () i32, f);
}

// error
// backend=stage2,llvm
// target=native
//
// :3:25: error: expected type 'fn () void', found 'fn (i32) void'
// :3:25: note: function with 1 parameters cannot cast into a function with 0 parameters
// :6:28: error: expected type 'fn (f32) void', found 'fn (i32) void'
// :6:28: note: parameter 0 'i32' cannot cast into 'f32'
// :9:24: error: expected type 'fn () i32', found 'fn (i32) void'
// :9:24: note: return type 'void' cannot cast into return type 'i32'

export fn a() void {
    var non_async_fn: fn () void = undefined;
    non_async_fn = func;
}
fn func() void {
    suspend {}
}

// error
// backend=stage1
// target=native
//
// tmp.zig:5:1: error: 'func' cannot be async
// tmp.zig:3:20: note: required to be non-async here
// tmp.zig:6:5: note: suspends here

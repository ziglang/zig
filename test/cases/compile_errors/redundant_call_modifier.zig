fn foo() void {}

export fn entry() void {
    comptime @call(.compile_time, foo, .{});
}

// error
// backend=stage2
// target=native
//
// :4:21: error: '.compile_time' call modifier is redundant in a comptime scope

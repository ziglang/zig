// from #7841 - stage1 couldn't distinguish a and b

pub export fn testing() void {
    var cond = false;
    _ = &cond;
    const theFn = if (cond) a else b;

    theFn() catch |err| switch (err) {
        error.ErrorA => return,
        //error.errorB is not part of this error set
    };
}

fn a() !void {
    return error.ErrorA;
}

fn b() !void {
    return error.ErrorB;
}

// error
// backend=stage2
// target=native
//
// :6:19: error: incompatible types: 'fn() @typeInfo(@typeInfo(@TypeOf(example.a)).Fn.return_type.?).ErrorUnion.error_set!void' and 'fn() @typeInfo(@typeInfo(@TypeOf(example.b)).Fn.return_type.?).ErrorUnion.error_set!void'
// :6:29: note: type 'fn() @typeInfo(@typeInfo(@TypeOf(example.a)).Fn.return_type.?).ErrorUnion.error_set!void' here
// :6:36: note: type 'fn() @typeInfo(@typeInfo(@TypeOf(example.b)).Fn.return_type.?).ErrorUnion.error_set!void' here

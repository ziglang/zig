pub export fn testing() void {
    var cond: bool = undefined;
    cond = false; // must be a var
    const theFn = if (cond) a else b;
    _ = theFn;
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
// :4:19: error: incompatible types: 'fn() @typeInfo(@typeInfo(@TypeOf(example.a)).Fn.return_type.?).ErrorUnion.error_set!void' and 'fn() @typeInfo(@typeInfo(@TypeOf(example.b)).Fn.return_type.?).ErrorUnion.error_set!void'
// :4:29: note: type 'fn() @typeInfo(@typeInfo(@TypeOf(example.a)).Fn.return_type.?).ErrorUnion.error_set!void' here
// :4:36: note: type 'fn() @typeInfo(@typeInfo(@TypeOf(example.b)).Fn.return_type.?).ErrorUnion.error_set!void' here

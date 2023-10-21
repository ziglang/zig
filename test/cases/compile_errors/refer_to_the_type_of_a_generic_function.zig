export fn entry() void {
    const Func = fn (type) void;
    const f: Func = undefined;
    f(i32);
}

// error
// backend=stage2
// target=native
//
// :4:6: error: unable to call 'undefined'

export fn entry() void {
    const Func = fn (type) void;
    const f: Func = undefined;
    f(i32);
}

// error
//
// :4:6: error: use of undefined value here causes illegal behavior

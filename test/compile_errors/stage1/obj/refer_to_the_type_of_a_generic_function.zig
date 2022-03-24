export fn entry() void {
    const Func = fn (type) void;
    const f: Func = undefined;
    f(i32);
}

// refer to the type of a generic function
//
// tmp.zig:4:5: error: use of undefined value here causes undefined behavior

var rt_val: [5]u32 = .{ 1, 2, 3, 4, 5 };

comptime {
    _ = rt_val; // fine
}

comptime {
    const a = rt_val; // error
    _ = a;
}

comptime {
    const l = rt_val.len; // fine
    @compileLog(l);
}

export fn foo() void {
    _ = comptime rt_val; // error
}

export fn bar() void {
    const l = comptime rt_val.len; // fine
    @compileLog(l);
}

export fn baz() void {
    const S = struct {
        fn inner() void {
            _ = comptime rt_val;
        }
    };
    comptime S.inner(); // fine; inner comptime is a nop
    S.inner(); // error
}

export fn qux() void {
    const S = struct {
        fn inner() void {
            const a = rt_val;
            _ = a;
        }
    };
    S.inner(); // fine; everything is runtime
    comptime S.inner(); // error
}

// error
//
// :8:15: error: unable to resolve comptime value
// :7:1: note: 'comptime' keyword forces comptime evaluation
// :18:9: error: unable to resolve comptime value
// :18:9: note: 'comptime' keyword forces comptime evaluation
// :29:17: error: unable to resolve comptime value
// :29:17: note: 'comptime' keyword forces comptime evaluation
// :39:23: error: unable to resolve comptime value
// :44:21: note: called at comptime from here
// :44:5: note: 'comptime' keyword forces comptime evaluation
//
// Compile Log Output:
// @as(usize, 5)
// @as(usize, 5)

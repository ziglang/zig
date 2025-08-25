export fn foo() void {
    comptime var i = 0;
    while (i < 5) : (i += 1) {
        bar();
    }
}

fn bar() void {}
export fn baz() void {
    comptime var idx: u32 = 0;
    while (idx < 1) {
        const not_null: ?u32 = 1;
        _ = not_null orelse return;
        idx += 1;
    }
}

export fn qux() void {
    comptime var i = 0;
    while (i < 3) : (i += 1) {
        const T = switch (i) {
            0 => f32,
            1 => i8,
            2 => bool,
            else => unreachable,
        };
        _ = T;
    }
}

// error
// backend=stage2
// target=native
//
// :3:24: error: cannot store to comptime variable in non-inline loop
// :3:5: note: non-inline loop here
// :14:13: error: cannot store to comptime variable in non-inline loop
// :11:5: note: non-inline loop here
// :20:24: error: cannot store to comptime variable in non-inline loop
// :20:5: note: non-inline loop here

export fn foo() void {
    comptime var i = 0;
    while (i < 5) : (i += 1) {
        bar();
    }
}

fn bar() void { }

// error
// backend=stage1
// target=native
//
// tmp.zig:3:5: error: control flow attempts to use compile-time variable at runtime
// tmp.zig:3:24: note: compile-time variable assigned here

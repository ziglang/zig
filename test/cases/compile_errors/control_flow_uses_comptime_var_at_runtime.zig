export fn foo() void {
    comptime var i = 0;
    while (i < 5) : (i += 1) {
        bar();
    }
}

fn bar() void { }

// error
// backend=stage2
// target=native
//
// :3:24: error: cannot store to comptime variable in non-inline loop
// :3:5: note: non-inline loop here

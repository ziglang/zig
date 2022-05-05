const E = enum(usize) { One, Two };

export fn entry() void {
    foo(1);
}

fn foo(x: usize) void {
    switch (x) {
        E.One => {},
    }
}

// error
// backend=stage1
// target=native
//
// tmp.zig:9:10: error: expected type 'usize', found 'E'

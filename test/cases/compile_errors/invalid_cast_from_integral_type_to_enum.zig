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
// backend=stage2
// target=native
//
// :9:10: error: expected type 'usize', found 'tmp.E'
// :1:11: note: enum declared here

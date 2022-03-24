const E = enum(usize) { One, Two };

export fn entry() void {
    foo(1);
}

fn foo(x: usize) void {
    switch (x) {
        E.One => {},
    }
}

// invalid cast from integral type to enum
//
// tmp.zig:9:10: error: expected type 'usize', found 'E'

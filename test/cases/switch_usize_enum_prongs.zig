const E = enum(usize) { One, Two };

test "aoeou" {
    foo(1);
}

fn foo(x: usize) void {
    switch (x) {
        E.One => {},
    }
}

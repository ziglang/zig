export fn entry() void {
    const err: error{Foo} = error.Foo;

    switch (err) {
        error.Foo => |*foo| {
            foo catch {};
        },
    }
}

// error
// backend=stage2
// target=native
//
// :5:23: error: error set cannot be captured by reference

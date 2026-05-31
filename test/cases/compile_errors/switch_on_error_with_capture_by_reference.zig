comptime {
    const e: error{Foo}!u32 = error.Foo;
    e catch |err| switch (err) {
        error.Foo => |*foo| {
            foo catch {};
        },
    };
}

comptime {
    const e: error{Foo}!u32 = error.Foo;
    if (e) {} else |err| switch (err) {
        error.Foo => |*foo| {
            foo catch {};
        },
    }
}

// error
//
// :4:24: error: error set cannot be captured by reference
// :13:24: error: error set cannot be captured by reference

pub fn main() void {
    foo() catch |err| {
        assert(err == error.Foo);
        assert(err != error.Bar);
        assert(err != error.Baz);
    };
    bar() catch |err| {
        assert(err != error.Foo);
        assert(err == error.Bar);
        assert(err != error.Baz);
    };
}

fn assert(ok: bool) void {
    if (!ok) unreachable;
}

fn foo() anyerror!void {
    return error.Foo;
}

fn bar() anyerror!void {
    return error.Bar;
}

// run
//

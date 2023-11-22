pub fn main() void {
    var e1 = error.Foo;
    var e2 = error.Bar;
    _ = .{ &e1, &e2 };
    assert(e1 != e2);
    assert(e1 == error.Foo);
    assert(e2 == error.Bar);
}

fn assert(b: bool) void {
    if (!b) unreachable;
}

// run
// target=wasm32-wasi
//

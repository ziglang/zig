const Foo = struct {
    y: u8,
};

var foo: Foo = undefined;
const t = &foo;

fn bar(pointer: ?*anyopaque) void {
    _ = pointer;
}

test "fixed" {
    bar(t);
}

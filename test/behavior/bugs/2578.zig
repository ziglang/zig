const Foo = struct {
    y: u8,
};

var foo: Foo = undefined;
const t = &foo;

fn bar(pointer: ?*c_void) void {
    _ = pointer;
}

test "fixed" {
    bar(t);
}

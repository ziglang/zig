const Foo = struct {
    y: u8,
};

var foo: Foo = undefined;
const t = &foo;

fn bar(pointer: ?*c_void) void {}

test "fixed" {
    bar(t);
}

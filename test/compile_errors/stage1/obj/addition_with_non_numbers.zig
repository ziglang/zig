const Foo = struct {
    field: i32,
};
const x = Foo {.field = 1} + Foo {.field = 2};

export fn entry() usize { return @sizeOf(@TypeOf(x)); }

// addition with non numbers
//
// tmp.zig:4:28: error: invalid operands to binary expression: 'Foo' and 'Foo'

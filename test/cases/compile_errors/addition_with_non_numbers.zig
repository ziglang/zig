const Foo = struct {
    field: i32,
};
const x = Foo {.field = 1} + Foo {.field = 2};

export fn entry() usize { return @sizeOf(@TypeOf(x)); }

// error
// backend=stage2
// target=native
//
// :4:28: error: invalid operands to binary expression: 'Struct' and 'Struct'

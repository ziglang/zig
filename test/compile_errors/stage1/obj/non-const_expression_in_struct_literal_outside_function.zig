const Foo = struct {
    x: i32,
};
const a = Foo {.x = get_it()};
extern fn get_it() i32;

export fn entry() usize { return @sizeOf(@TypeOf(a)); }

// error
// backend=stage1
// target=native
//
// tmp.zig:4:21: error: unable to evaluate constant expression

const Foo = struct {
    x: i32,
};
const a = get_it();
fn get_it() Foo {
    global_side_effect = true;
    return Foo {.x = 13};
}
var global_side_effect = false;

export fn entry() usize { return @sizeOf(@TypeOf(a)); }

// non-const expression function call with struct return value outside function
//
// tmp.zig:6:26: error: unable to evaluate constant expression

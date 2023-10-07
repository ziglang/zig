const Foo = struct {
    x: i32,
};
const a = Foo{ .x = get_it() };
extern fn get_it() i32;

export fn entry() usize {
    return @sizeOf(@TypeOf(a));
}

// error
// backend=stage2
// target=native
//
// :4:27: error: comptime call of extern function

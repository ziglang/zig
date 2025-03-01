const Foo = struct {
    x: i32,
};
const a = Foo{ .x = get_it() };
extern fn get_it() i32;

export fn entry() usize {
    return @sizeOf(@TypeOf(a));
}

// error
//
// :4:27: error: comptime call of extern function
// :4:14: note: initializer of container-level variable must be comptime-known

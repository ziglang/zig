const Foo = struct {
    y: [get()]u8,
};
var global_var: usize = 1;
fn get() usize {
    return global_var;
}

export fn entry() usize {
    return @offsetOf(Foo, "y");
}

// error
// backend=stage2
// target=native
//
// :6:12: error: unable to resolve comptime value
// :2:12: note: called at comptime from here
// :1:13: note: struct fields must be comptime-known

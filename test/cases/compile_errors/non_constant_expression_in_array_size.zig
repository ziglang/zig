const Foo = struct {
    y: [get()]u8,
};
var global_var: usize = 1;
fn get() usize { return global_var; }

export fn entry() usize { return @offsetOf(Foo, "y"); }

// error
// backend=stage2
// target=native
//
// :5:25: error: cannot load runtime value in comptime block
// :2:15: note: called from here

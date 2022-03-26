const Foo = struct {
    y: [get()]u8,
};
var global_var: usize = 1;
fn get() usize { return global_var; }

export fn entry() usize { return @sizeOf(@TypeOf(Foo)); }

// non constant expression in array size
//
// tmp.zig:5:25: error: cannot store runtime value in compile time variable
// tmp.zig:2:12: note: called from here

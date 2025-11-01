const Foo = extern struct {
    f: *const fn () void,
};

export fn entry() void {
    _ = (Foo{}).f;
}

// error
//
// :2:8: error: extern structs cannot contain fields of type '*const fn () void'
// :2:8: note: extern function must specify calling convention

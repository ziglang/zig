const Foo = extern struct {
    x: ?*const void,
};
const Bar = extern struct {
    foo: Foo,
    y: i32,
};
export fn entry(bar: *Bar) void {_ = bar;}

// optional pointer to void in extern struct
//
// tmp.zig:2:5: error: extern structs cannot contain fields of type '?*const void'

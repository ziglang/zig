const Foo = enum { M };

export fn entry() void {
    var f = Foo.M;
    switch (f) {}
}

// error
// backend=stage1
// target=native
//
// tmp.zig:5:5: error: enumeration value 'Foo.M' not handled in switch

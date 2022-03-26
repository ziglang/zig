const Foo = enum { M };

export fn entry() void {
    var f = Foo.M;
    switch (f) {}
}

// switch on enum with 1 field with no prongs
//
// tmp.zig:5:5: error: enumeration value 'Foo.M' not handled in switch

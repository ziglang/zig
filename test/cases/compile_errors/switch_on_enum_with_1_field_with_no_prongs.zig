const Foo = enum { M };

export fn entry() void {
    var f = Foo.M;
    switch (f) {}
}

// error
// backend=stage2
// target=native
//
// :5:5: error: switch must handle all possibilities
// :5:5: note: unhandled enumeration value: 'M'
// :1:13: note: enum 'tmp.Foo' declared here

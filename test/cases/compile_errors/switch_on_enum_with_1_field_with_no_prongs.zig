const Foo = enum { M };

export fn entry() void {
    const f = Foo.M;
    switch (f) {}
}

// error
// backend=stage2
// target=native
//
// :5:5: error: switch must handle all possibilities
// :1:20: note: unhandled enumeration value: 'M'
// :1:13: note: enum 'tmp.Foo' declared here

export fn entry1() void {
    var e: error{Foo} = error.Foo;
    const p: *error{ Foo, Bar } = &e;
    p.* = error.Bar;
}
export fn entry2() void {
    var x: error{Foo}!u8 = 5;
    const p: *error{ Foo, Bar }!u8 = &x;
    p.* = error.Bar;
}

// error
// backend=stage2
// target=native
//
//:3:35: error: expected type '*error{Foo,Bar}', found '*error{Foo}'
//:3:35: note: pointer type child 'error{Foo}' cannot cast into pointer type child 'error{Foo,Bar}'
//:3:35: note: 'error.Bar' not a member of source error set
//:8:38: error: expected type '*error{Foo,Bar}!u8', found '*error{Foo}!u8'
//:8:38: note: pointer type child 'error{Foo}!u8' cannot cast into pointer type child 'error{Foo,Bar}!u8'
//:8:38: note: 'error.Bar' not a member of source error set

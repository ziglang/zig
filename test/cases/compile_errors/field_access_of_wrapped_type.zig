const Foo = struct {
    a: i32,
};
export fn f1() void {
    var foo: ?Foo = undefined;
    foo.a += 1;
}
export fn f2() void {
    var foo: anyerror!Foo = undefined;
    foo.a += 1;
}
export fn f3() void {
    var foo: error{ A, B }!Foo = undefined;
    foo.a += 1;
}
export fn f4() void {
    var foo = x4();
    foo.a += 1;
}

fn x4() !Foo {
    return undefined;
}

// error
// backend=stage2
// target=native
//
// :6:8: error: optional type '?tmp.Foo' does not support field access
// :6:8: note: consider using '.?', 'orelse', or 'if'
// :10:8: error: error union type 'anyerror!tmp.Foo' does not support field access
// :10:8: note: consider using 'try', 'catch', or 'if'
// :14:8: error: error union type 'error{A,B}!tmp.Foo' does not support field access
// :14:8: note: consider using 'try', 'catch', or 'if'
// :18:8: error: error union type '!tmp.Foo' does not support field access
// :18:8: note: consider using 'try', 'catch', or 'if'

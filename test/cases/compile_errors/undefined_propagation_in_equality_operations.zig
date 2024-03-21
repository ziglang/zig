test "undefined propagation in equality operators for bool" {
    var foo: bool = undefined;
    _ = &foo;
    _ = foo == undefined;
    if (foo == undefined) {}
}

test "undefined propagation in equality operators for pointer" {
    var foo: *i32 = undefined;
    _ = &foo;
    _ = foo == undefined;
    if (foo == undefined) {}
}

test "undefined propagation in equality operators for optional" {
    var foo: ?*i32 = undefined;
    _ = &foo;
    _ = foo == undefined;
    if (foo == undefined) {}
}

test "undefined propagation in equality operators for error union" {
    var foo: anyerror = undefined;
    _ = &foo;
    _ = foo == @as(anyerror!i32, undefined);
    if (foo == @as(anyerror!i32, undefined)) {}
}

test "undefined propagation in equality operators for integers" {
    var foo: i32 = undefined;
    _ = &foo;
    _ = foo == undefined;
    if (foo == undefined) {}
}

// error
// is_test=true
//
// :5:13: error: use of undefined value here causes undefined behavior
// :12:13: error: use of undefined value here causes undefined behavior
// :19:13: error: use of undefined value here causes undefined behavior
// :26:13: error: use of undefined value here causes undefined behavior
// :33:13: error: use of undefined value here causes undefined behavior

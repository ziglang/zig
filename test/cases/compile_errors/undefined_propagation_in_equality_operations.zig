test "undefined propagation in equality operators for bool" {
    var foo: bool = undefined;
    _ = foo == undefined;
    if (foo == undefined) {}
}

test "undefined propagation in equality operators for pointer" {
    var foo: *i32 = undefined;
    _ = foo == undefined;
    if (foo == undefined) {}
}

test "undefined propagation in equality operators for optional" {
    var foo: ?*i32 = undefined;
    _ = foo == undefined;
    if (foo == undefined) {}
}

test "undefined propagation in equality operators for error union" {
    var foo: anyerror = undefined;
    _ = foo == @as(anyerror!i32, undefined);
    if (foo == @as(anyerror!i32, undefined)) {}
}

test "undefined propagation in equality operators for integers" {
    var foo: i32 = undefined;
    _ = foo == undefined;
    if (foo == undefined) {}
}

// error
// is_test=true
//
// :4:13: error: use of undefined value here causes undefined behavior
// :10:13: error: use of undefined value here causes undefined behavior
// :16:13: error: use of undefined value here causes undefined behavior
// :22:13: error: use of undefined value here causes undefined behavior
// :28:13: error: use of undefined value here causes undefined behavior

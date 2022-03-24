// operator ==
comptime {
    var a: i64 = undefined;
    var x: i32 = 0;
    if (a == a) x += 1;
}
// operator !=
comptime {
    var a: i64 = undefined;
    var x: i32 = 0;
    if (a != a) x += 1;
}
// operator >
comptime {
    var a: i64 = undefined;
    var x: i32 = 0;
    if (a > a) x += 1;
}
// operator <
comptime {
    var a: i64 = undefined;
    var x: i32 = 0;
    if (a < a) x += 1;
}
// operator >=
comptime {
    var a: i64 = undefined;
    var x: i32 = 0;
    if (a >= a) x += 1;
}
// operator <=
comptime {
    var a: i64 = undefined;
    var x: i32 = 0;
    if (a <= a) x += 1;
}

// comparison operators with undefined value
//
// tmp.zig:5:11: error: use of undefined value here causes undefined behavior
// tmp.zig:11:11: error: use of undefined value here causes undefined behavior
// tmp.zig:17:11: error: use of undefined value here causes undefined behavior
// tmp.zig:23:11: error: use of undefined value here causes undefined behavior
// tmp.zig:29:11: error: use of undefined value here causes undefined behavior
// tmp.zig:35:11: error: use of undefined value here causes undefined behavior

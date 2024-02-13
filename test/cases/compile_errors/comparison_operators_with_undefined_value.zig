// operator ==
comptime {
    const a: i64 = undefined;
    var x: i32 = 0;
    if (a == a) x += 1;
}
// operator !=
comptime {
    const a: i64 = undefined;
    var x: i32 = 0;
    if (a != a) x += 1;
}
// operator >
comptime {
    const a: i64 = undefined;
    var x: i32 = 0;
    if (a > a) x += 1;
}
// operator <
comptime {
    const a: i64 = undefined;
    var x: i32 = 0;
    if (a < a) x += 1;
}
// operator >=
comptime {
    const a: i64 = undefined;
    var x: i32 = 0;
    if (a >= a) x += 1;
}
// operator <=
comptime {
    const a: i64 = undefined;
    var x: i32 = 0;
    if (a <= a) x += 1;
}

// error
// backend=stage2
// target=native
//
// :5:11: error: use of undefined value here causes undefined behavior
// :11:11: error: use of undefined value here causes undefined behavior
// :17:11: error: use of undefined value here causes undefined behavior
// :23:11: error: use of undefined value here causes undefined behavior
// :29:11: error: use of undefined value here causes undefined behavior
// :35:11: error: use of undefined value here causes undefined behavior

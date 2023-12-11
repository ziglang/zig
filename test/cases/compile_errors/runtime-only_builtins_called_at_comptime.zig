test "comptime @panic call" {
    comptime @panic("amogus");
}

test "comptime @trap call" {
    comptime @trap();
}

test "comptime @breakpoint call" {
    comptime @breakpoint();
}

// error
// backend=stage2
// target=native
// is_test=true
//
// :2:14: error: encountered @panic at comptime
// :6:14: error: encountered @trap at comptime
// :10:14: error: encountered @breakpoint at comptime

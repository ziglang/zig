test "comptime @workGroupId call" {
    _ = comptime @workGroupId(42);
}

test "comptime @workGroupSize call" {
    _ = comptime @workGroupSize(42);
}

test "comptime @workItemId call" {
    _ = comptime @workItemId(42);
}

test "comptime @panic call" {
    comptime @panic("amogus");
}

test "comptime @trap call" {
    comptime @trap();
}

test "comptime @setAlignStack call" {
    comptime @setAlignStack(1);
}

test "comptime @breakpoint call" {
    comptime @breakpoint();
}

// error
// backend=stage2
// target=native
// is_test=true
//
// :2:18: error: encountered @workGroupId at comptime
// :6:18: error: encountered @workGroupSize at comptime
// :10:18: error: encountered @workItemId at comptime
// :14:14: error: encountered @panic at comptime
// :18:14: error: encountered @trap at comptime
// :22:14: error: encountered @setAlignStack at comptime
// :26:14: error: encountered @breakpoint at comptime

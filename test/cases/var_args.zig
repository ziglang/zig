const assert = @import("std").debug.assert;

fn add(args: ...) -> i32 {
    var sum = i32(0);
    {comptime var i: usize = 0; inline while (i < args.len; i += 1) {
        sum += args[i];
    }}
    return sum;
}

fn testAddArbitraryArgs() {
    @setFnTest(this);

    assert(add(i32(1), i32(2), i32(3), i32(4)) == 10);
    assert(add(i32(1234)) == 1234);
}

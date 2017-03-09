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
    assert(add() == 0);
}

fn readFirstVarArg(args: ...) {
    const value = args[0];
}

fn sendVoidArgToVarArgs() {
    @setFnTest(this);

    readFirstVarArg({});
}

fn testPassArgsDirectly() {
    @setFnTest(this);

    assert(addSomeStuff(i32(1), i32(2), i32(3), i32(4)) == 10);
    assert(addSomeStuff(i32(1234)) == 1234);
    assert(addSomeStuff() == 0);
}

fn addSomeStuff(args: ...) -> i32 {
    return add(args);
}

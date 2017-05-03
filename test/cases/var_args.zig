const assert = @import("std").debug.assert;

fn add(args: ...) -> i32 {
    var sum = i32(0);
    {comptime var i: usize = 0; inline while (i < args.len) : (i += 1) {
        sum += args[i];
    }}
    return sum;
}

test "testAddArbitraryArgs" {
    assert(add(i32(1), i32(2), i32(3), i32(4)) == 10);
    assert(add(i32(1234)) == 1234);
    assert(add() == 0);
}

fn readFirstVarArg(args: ...) {
    const value = args[0];
}

test "sendVoidArgToVarArgs" {
    readFirstVarArg({});
}

test "testPassArgsDirectly" {
    assert(addSomeStuff(i32(1), i32(2), i32(3), i32(4)) == 10);
    assert(addSomeStuff(i32(1234)) == 1234);
    assert(addSomeStuff() == 0);
}

fn addSomeStuff(args: ...) -> i32 {
    return add(args);
}

test "runtime parameter before var args" {
    assert(extraFn(10) == 0);
    assert(extraFn(10, false) == 1);
    assert(extraFn(10, false, true) == 2);

    // TODO issue #313
    //comptime {
    //    assert(extraFn(10) == 0);
    //    assert(extraFn(10, false) == 1);
    //    assert(extraFn(10, false, true) == 2);
    //}
}

fn extraFn(extra: u32, args: ...) -> usize {
    if (args.len >= 1) {
        assert(args[0] == false);
    }
    if (args.len >= 2) {
        assert(args[1] == true);
    }
    return args.len;
}

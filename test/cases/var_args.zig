const assert = @import("std").debug.assert;

fn add(args: ...) i32 {
    var sum = i32(0);
    {
        comptime var i: usize = 0;
        inline while (i < args.len) : (i += 1) {
            sum += args[i];
        }
    }
    return sum;
}

test "add arbitrary args" {
    assert(add(i32(1), i32(2), i32(3), i32(4)) == 10);
    assert(add(i32(1234)) == 1234);
    assert(add() == 0);
}

fn readFirstVarArg(args: ...) void {
    const value = args[0];
}

test "send void arg to var args" {
    readFirstVarArg({});
}

test "pass args directly" {
    assert(addSomeStuff(i32(1), i32(2), i32(3), i32(4)) == 10);
    assert(addSomeStuff(i32(1234)) == 1234);
    assert(addSomeStuff() == 0);
}

fn addSomeStuff(args: ...) i32 {
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

fn extraFn(extra: u32, args: ...) usize {
    if (args.len >= 1) {
        assert(args[0] == false);
    }
    if (args.len >= 2) {
        assert(args[1] == true);
    }
    return args.len;
}

const foos = []fn (...) bool{
    foo1,
    foo2,
};

fn foo1(args: ...) bool {
    return true;
}
fn foo2(args: ...) bool {
    return false;
}

test "array of var args functions" {
    assert(foos[0]());
    assert(!foos[1]());
}

test "pass zero length array to var args param" {
    doNothingWithFirstArg("");
}

fn doNothingWithFirstArg(args: ...) void {
    const a = args[0];
}

const expect = @import("std").testing.expect;

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
    expect(add(i32(1), i32(2), i32(3), i32(4)) == 10);
    expect(add(i32(1234)) == 1234);
    expect(add() == 0);
}

fn readFirstVarArg(args: ...) void {
    const value = args[0];
}

test "send void arg to var args" {
    readFirstVarArg({});
}

test "pass args directly" {
    expect(addSomeStuff(i32(1), i32(2), i32(3), i32(4)) == 10);
    expect(addSomeStuff(i32(1234)) == 1234);
    expect(addSomeStuff() == 0);
}

fn addSomeStuff(args: ...) i32 {
    return add(args);
}

test "runtime parameter before var args" {
    expect(extraFn(10) == 0);
    expect(extraFn(10, false) == 1);
    expect(extraFn(10, false, true) == 2);

    // TODO issue #313
    //comptime {
    //    expect(extraFn(10) == 0);
    //    expect(extraFn(10, false) == 1);
    //    expect(extraFn(10, false, true) == 2);
    //}
}

fn extraFn(extra: u32, args: ...) usize {
    if (args.len >= 1) {
        expect(args[0] == false);
    }
    if (args.len >= 2) {
        expect(args[1] == true);
    }
    return args.len;
}

const foos = [_]fn (...) bool{
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
    expect(foos[0]());
    expect(!foos[1]());
}

test "pass zero length array to var args param" {
    doNothingWithFirstArg("");
}

fn doNothingWithFirstArg(args: ...) void {
    const a = args[0];
}

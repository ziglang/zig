const assertOrPanic = @import("std").debug.assertOrPanic;

test "break and continue inside loop inside defer expression" {
    testBreakContInDefer(10);
    comptime testBreakContInDefer(10);
}

fn testBreakContInDefer(x: usize) void {
    defer {
        var i: usize = 0;
        while (i < x) : (i += 1) {
            if (i < 5) continue;
            if (i == 5) break;
        }
        assertOrPanic(i == 5);
    }
}

test "defer and labeled break" {
    var i = usize(0);

    blk: {
        defer i += 1;
        break :blk;
    }

    assertOrPanic(i == 1);
}

test "errdefer does not apply to fn inside fn" {
    if (testNestedFnErrDefer()) |_| @panic("expected error") else |e| assertOrPanic(e == error.Bad);
}

fn testNestedFnErrDefer() anyerror!void {
    var a: i32 = 0;
    errdefer a += 1;
    const S = struct {
        fn baz() anyerror {
            return error.Bad;
        }
    };
    return S.baz();
}

var result: [3]u8 = undefined;
var index: usize = undefined;

fn runSomeErrorDefers(x: bool) !bool {
    index = 0;
    defer {
        result[index] = 'a';
        index += 1;
    }
    errdefer {
        result[index] = 'b';
        index += 1;
    }
    defer {
        result[index] = 'c';
        index += 1;
    }
    return if (x) x else error.FalseNotAllowed;
}

test "mixing normal and error defers" {
    assertOrPanic(runSomeErrorDefers(true) catch unreachable);
    assertOrPanic(result[0] == 'c');
    assertOrPanic(result[1] == 'a');

    const ok = runSomeErrorDefers(false) catch |err| x: {
        assertOrPanic(err == error.FalseNotAllowed);
        break :x true;
    };
    assertOrPanic(ok);
    assertOrPanic(result[0] == 'c');
    assertOrPanic(result[1] == 'b');
    assertOrPanic(result[2] == 'a');
}

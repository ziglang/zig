const assertOrPanic = @import("std").debug.assertOrPanic;

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

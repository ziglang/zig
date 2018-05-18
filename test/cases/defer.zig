const assert = @import("std").debug.assert;

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
    assert(runSomeErrorDefers(true) catch unreachable);
    assert(result[0] == 'c');
    assert(result[1] == 'a');

    const ok = runSomeErrorDefers(false) catch |err| x: {
        assert(err == error.FalseNotAllowed);
        break :x true;
    };
    assert(ok);
    assert(result[0] == 'c');
    assert(result[1] == 'b');
    assert(result[2] == 'a');
}

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
        assert(i == 5);
    }
}

test "defer and labeled break" {
    var i = usize(0);

    blk: {
        defer i += 1;
        break :blk;
    }

    assert(i == 1);
}

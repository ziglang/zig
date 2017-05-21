const assert = @import("std").debug.assert;

var result: [3]u8 = undefined;
var index: usize = undefined;

error FalseNotAllowed;

fn runSomeErrorDefers(x: bool) -> %bool {
    index = 0;
    defer {result[index] = 'a'; index += 1;};
    %defer {result[index] = 'b'; index += 1;};
    defer {result[index] = 'c'; index += 1;};
    return if (x) x else error.FalseNotAllowed;
}

test "mixing normal and error defers" {
    assert(%%runSomeErrorDefers(true));
    assert(result[0] == 'c');
    assert(result[1] == 'a');

    const ok = runSomeErrorDefers(false) %% |err| {
        assert(err == error.FalseNotAllowed);
        true
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

fn testBreakContInDefer(x: usize) {
    defer {
        var i: usize = 0;
        while (i < x) : (i += 1) {
            if (i < 5) continue;
            if (i == 5) break;
        }
        assert(i == 5);
    };
}

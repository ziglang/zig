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

fn runSomeMaybeDefers(x: bool) -> ?bool {
    index = 0;
    defer {result[index] = 'a'; index += 1;};
    ?defer {result[index] = 'b'; index += 1;};
    defer {result[index] = 'c'; index += 1;};
    return if (x) x else null;
}

test "mixingNormalAndErrorDefers" {
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

test "mixingNormalAndMaybeDefers" {
    assert(??runSomeMaybeDefers(true));
    assert(result[0] == 'c');
    assert(result[1] == 'a');

    const ok = runSomeMaybeDefers(false) ?? true;
    assert(ok);
    assert(result[0] == 'c');
    assert(result[1] == 'b');
    assert(result[2] == 'a');
}

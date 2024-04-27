const expect = @import("std").testing.expect;

test "error union" {
    var foo: anyerror!i32 = undefined;

    // Coerce from child type of an error union:
    foo = 1234;

    // Coerce from an error set:
    foo = error.SomeError;

    // Use compile-time reflection to access the payload type of an error union:
    try comptime expect(@typeInfo(@TypeOf(foo)).ErrorUnion.payload == i32);

    // Use compile-time reflection to access the error set type of an error union:
    try comptime expect(@typeInfo(@TypeOf(foo)).ErrorUnion.error_set == anyerror);
}

// test

const std = @import("std");
const expect = std.testing.expect;

test "null literal outside function" {
    const is_null = here_is_a_null_literal.context == null;
    try expect(is_null);

    const is_non_null = here_is_a_null_literal.context != null;
    try expect(!is_non_null);
}

const SillyStruct = struct {
    context: ?i32,
};

const here_is_a_null_literal = SillyStruct{ .context = null };

const StructWithOptional = struct {
    field: ?i32,
};

var struct_with_optional: StructWithOptional = undefined;

test "unwrap optional which is field of global var" {
    struct_with_optional.field = null;
    if (struct_with_optional.field) |payload| {
        _ = payload;
        unreachable;
    }
    struct_with_optional.field = 1234;
    if (struct_with_optional.field) |payload| {
        try expect(payload == 1234);
    } else {
        unreachable;
    }
}

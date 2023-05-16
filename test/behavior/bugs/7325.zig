const std = @import("std");
const builtin = @import("builtin");
const testing = std.testing;

const string = "hello world";

const TempRef = struct {
    index: usize,
    is_weak: bool,
};

const BuiltinEnum = struct {
    name: []const u8,
};

const ParamType = union(enum) {
    boolean,
    buffer,
    one_of: BuiltinEnum,
};

const CallArg = struct {
    value: Expression,
};

const Expression = union(enum) {
    literal_boolean: bool,
    literal_enum_value: EnumLiteral,
};

const EnumLiteral = struct {
    label: []const u8,
};

const ExpressionResult = union(enum) {
    temp_buffer: TempRef,
    literal_boolean: bool,
    literal_enum_value: []const u8,
};

fn commitCalleeParam(result: ExpressionResult, callee_param_type: ParamType) ExpressionResult {
    switch (callee_param_type) {
        .boolean => {
            return result;
        },
        .buffer => {
            return ExpressionResult{
                .temp_buffer = .{ .index = 0, .is_weak = false },
            };
        },
        .one_of => {
            return result;
        },
    }
}

fn genExpression(expr: Expression) !ExpressionResult {
    switch (expr) {
        .literal_boolean => |value| {
            return ExpressionResult{
                .literal_boolean = value,
            };
        },
        .literal_enum_value => |v| {
            try testing.expectEqualStrings(string, v.label);
            const result: ExpressionResult = .{
                .literal_enum_value = v.label,
            };
            switch (result) {
                .literal_enum_value => |w| {
                    try testing.expectEqualStrings(string, w);
                },
                else => {},
            }
            return result;
        },
    }
}

test {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    var param: ParamType = .{
        .one_of = .{ .name = "name" },
    };
    var arg: CallArg = .{
        .value = .{
            .literal_enum_value = .{
                .label = string,
            },
        },
    };

    const result = try genExpression(arg.value);
    switch (result) {
        .literal_enum_value => |w| {
            try testing.expectEqualStrings(string, w);
        },
        else => {},
    }

    const derp = commitCalleeParam(result, param);
    switch (derp) {
        .literal_enum_value => |w| {
            try testing.expectEqualStrings(string, w);
        },
        else => {},
    }
}

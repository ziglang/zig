const SomeEnum = union(enum) {
    EnumVariant: u8,
};

const SomeStruct = struct {
    struct_field: u8,
};

const OptEnum = struct {
    opt_enum: ?SomeEnum,
};

const ErrEnum = struct {
    err_enum: anyerror!SomeEnum,
};

const OptStruct = struct {
    opt_struct: ?SomeStruct,
};

const ErrStruct = struct {
    err_struct: anyerror!SomeStruct,
};

test {
    if (@import("builtin").zig_backend == .stage1) return error.SkipZigTest;

    _ = OptEnum{
        .opt_enum = .{
            .EnumVariant = 1,
        },
    };

    _ = ErrEnum{
        .err_enum = .{
            .EnumVariant = 1,
        },
    };

    _ = OptStruct{
        .opt_struct = .{
            .struct_field = 1,
        },
    };

    _ = ErrStruct{
        .err_struct = .{
            .struct_field = 1,
        },
    };
}

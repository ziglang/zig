fn isFieldOptional(comptime T: type, field_index: usize) !bool {
    const fields = @typeInfo(T).@"struct".fields;
    return switch (field_index) {
        inline 0...fields.len - 1 => |idx| @typeInfo(fields[idx].type) == .optional,
        else => return error.IndexOutOfBounds,
    };
}

// syntax

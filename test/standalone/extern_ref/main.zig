const std = @import("std");
const eql = std.mem.eql;

// These are defined in `obj.zig`
extern var global_var: usize;
extern const global_const: usize;

const TheStruct = @import("./types.zig").TheStruct;
extern var global_var_struct: TheStruct;
extern const global_const_struct: TheStruct;

const TheUnion = @import("./types.zig").TheUnion;
extern var global_var_union: TheUnion;
extern const global_const_union: TheUnion;

extern var global_var_array: [4]u32;
extern const global_const_array: [4]u32;

// Take the pointers to external entities as constant values
const p_global_var = &global_var;
const p_global_const = &global_const;

test "access the external integers" {
    std.testing.expect(p_global_var.* == 2);
    std.testing.expect(p_global_const.* == 422);
}

const p_global_var_struct = &global_var_struct;
const p_global_const_struct = &global_const_struct;

const p_global_var_struct_val = &global_var_struct.value;
const p_global_const_struct_val = &global_const_struct.value;

const p_global_var_struct_array = &global_var_struct.array;
const p_global_const_struct_array = &global_const_struct.array;

const p_global_var_struct_array2 = global_var_struct.array[1..3];
const p_global_const_struct_array2 = global_const_struct.array[1..3];

const p_global_var_struct_array3 = &global_var_struct.array[1];
const p_global_const_struct_array3 = &global_const_struct.array[1];

test "access the external integers in a struct through comptime ptrs" {
    std.testing.expect(p_global_var_struct.value == 2);
    std.testing.expect(p_global_const_struct.value == 422);

    std.testing.expect(p_global_var_struct_val.* == 2);
    std.testing.expect(p_global_const_struct_val.* == 422);
}

test "access the external arrays in a struct through comptime ptrs" {
    // TODO
    // std.testing.expect(eql(u32, &p_global_var_struct.array, &[_]u32{1, 2, 3, 4}));
    // std.testing.expect(eql(u32, &p_global_const_struct.array, &[_]u32{5, 6, 7, 8}));

    // TODO
    // std.testing.expect(eql(u32, p_global_var_struct_array, &[_]u32{1, 2, 3, 4}));
    // std.testing.expect(eql(u32, p_global_const_struct_array, &[_]u32{5, 6, 7, 8}));

    // TODO
    // std.testing.expect(eql(u32, p_global_var_struct_array2, &[_]u32{2, 3}));
    // std.testing.expect(eql(u32, p_global_const_struct_array2, &[_]u32{6, 7}));

    // TODO
    // std.testing.expect(p_global_var_struct_array3.* == 2);
    // std.testing.expect(p_global_const_struct_array3.* == 6);
}

test "access the external integers with indirection through comptime ptrs" {
    std.testing.expect(p_global_var_struct.p_value.* == 3);
    std.testing.expect(p_global_const_struct.p_value.* == 423);
}

const p_global_var_struct_inner_val = &global_var_struct.inner.value;
const p_global_const_struct_inner_val = &global_const_struct.inner.value;

test "access the external integers in a nested struct through comptime ptrs" {
    // TODO
    // std.testing.expect(p_global_var_struct_inner_val.* == 4);
    // std.testing.expect(p_global_const_struct_inner_val.* == 424);
}

const p_global_var_union = &global_var_union;
const p_global_const_union = &global_const_union;

const p_global_var_union_val = &global_var_union.U32;
const p_global_const_union_val = &global_const_union.U32;

test "access the external integers in a union through comptime ptrs" {
    std.testing.expect(p_global_var_union.U32 == 10);
    std.testing.expect(p_global_const_union.U32 == 20);

    // TODO
    // std.testing.expect(p_global_var_union_val.* == 10);
    // std.testing.expect(p_global_const_union_val.* == 20);
}

const p_global_var_array = &global_var_array;
const p_global_const_array = &global_const_array;

const p_global_var_array2 = global_var_array[1..3];
const p_global_const_array2 = global_const_array[1..3];

const p_global_var_array3 = &global_var_array[1];
const p_global_const_array3 = &global_const_array[1];

test "access the external arrays through comptime ptrs" {
    std.testing.expect(eql(u32, &global_var_array, &[_]u32{1, 2, 3, 4}));
    std.testing.expect(eql(u32, &global_const_array, &[_]u32{5, 6, 7, 8}));

    std.testing.expect(eql(u32, p_global_var_array, &[_]u32{1, 2, 3, 4}));
    std.testing.expect(eql(u32, p_global_const_array, &[_]u32{5, 6, 7, 8}));

    std.testing.expect(eql(u32, p_global_var_array2, &[_]u32{2, 3}));
    std.testing.expect(eql(u32, p_global_const_array2, &[_]u32{6, 7}));

    // TODO
    // std.testing.expect(p_global_var_array3.* == 2);
    // std.testing.expect(p_global_const_array3.* == 6);
}

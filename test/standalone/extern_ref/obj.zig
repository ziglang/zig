export var global_var: usize = 2;
export const global_const: usize = 422;

const TheStruct = @import("./types.zig").TheStruct;
export var global_var_struct = TheStruct{
    .value = 2,
    .array = [_]u32{ 1, 2, 3, 4 },
    .p_value = &@as(u32, 3),
    .inner = .{ .value = 4 },
};
export const global_const_struct = TheStruct{
    .value = 422,
    .array = [_]u32{ 5, 6, 7, 8 },
    .p_value = &@as(u32, 423),
    .inner = .{ .value = 424 },
};

const TheUnion = @import("./types.zig").TheUnion;
export var global_var_union = TheUnion{
    .U32 = 10,
};
export const global_const_union = TheUnion{
    .U32 = 20,
};

export var global_var_array = [4]u32{ 1, 2, 3, 4 };
export const global_const_array = [4]u32{ 5, 6, 7, 8 };

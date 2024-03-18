const std = @import("std");

const BuiltinFn = @This();

pub const Tag = enum {
    add_with_overflow,
    addrspace_cast,
    align_cast,
    align_of,
    as,
    async_call,
    atomic_load,
    atomic_rmw,
    atomic_store,
    bit_cast,
    bit_offset_of,
    int_from_bool,
    bit_size_of,
    breakpoint,
    mul_add,
    byte_swap,
    bit_reverse,
    offset_of,
    call,
    c_define,
    c_import,
    c_include,
    clz,
    cmpxchg_strong,
    cmpxchg_weak,
    compile_error,
    compile_log,
    const_cast,
    ctz,
    c_undef,
    c_va_arg,
    c_va_copy,
    c_va_end,
    c_va_start,
    div_exact,
    div_floor,
    div_trunc,
    embed_file,
    int_from_enum,
    error_name,
    error_return_trace,
    int_from_error,
    error_cast,
    @"export",
    @"extern",
    fence,
    field,
    field_parent_ptr,
    float_cast,
    int_from_float,
    frame,
    Frame,
    frame_address,
    frame_size,
    has_decl,
    has_field,
    import,
    in_comptime,
    int_cast,
    enum_from_int,
    error_from_int,
    float_from_int,
    ptr_from_int,
    max,
    memcpy,
    memset,
    min,
    wasm_memory_size,
    wasm_memory_grow,
    mod,
    mul_with_overflow,
    panic,
    pop_count,
    prefetch,
    ptr_cast,
    int_from_ptr,
    rem,
    return_address,
    select,
    set_align_stack,
    set_cold,
    set_eval_branch_quota,
    set_float_mode,
    set_runtime_safety,
    shl_exact,
    shl_with_overflow,
    shr_exact,
    shuffle,
    size_of,
    splat,
    reduce,
    src,
    sqrt,
    sin,
    cos,
    tan,
    exp,
    exp2,
    log,
    log2,
    log10,
    abs,
    floor,
    ceil,
    trunc,
    round,
    sub_with_overflow,
    tag_name,
    This,
    trap,
    truncate,
    Type,
    type_info,
    type_name,
    TypeOf,
    union_init,
    Vector,
    volatile_cast,
    work_item_id,
    work_group_size,
    work_group_id,
};

pub const MemLocRequirement = enum {
    /// The builtin never needs a memory location.
    never,
    /// The builtin always needs a memory location.
    always,
    /// The builtin forwards the question to argument at index 0.
    forward0,
    /// The builtin forwards the question to argument at index 1.
    forward1,
};

pub const EvalToError = enum {
    /// The builtin cannot possibly evaluate to an error.
    never,
    /// The builtin will always evaluate to an error.
    always,
    /// The builtin may or may not evaluate to an error depending on the parameters.
    maybe,
};

tag: Tag,

/// Info about the builtin call's ability to take advantage of a result location pointer.
needs_mem_loc: MemLocRequirement = .never,
/// Info about the builtin call's possibility of returning an error.
eval_to_error: EvalToError = .never,
/// `true` if the builtin call can be the left-hand side of an expression (assigned to).
allows_lvalue: bool = false,
/// `true` if builtin call is not available outside function scope
illegal_outside_function: bool = false,
/// The number of parameters to this builtin function. `null` means variable number
/// of parameters.
param_count: ?u8,

pub const list = list: {
    @setEvalBranchQuota(3000);
    break :list std.ComptimeStringMap(BuiltinFn, &.{
        .{
            "@addWithOverflow",
            BuiltinFn{
                .tag = .add_with_overflow,
                .param_count = 2,
            },
        },
        .{
            "@addrSpaceCast",
            BuiltinFn{
                .tag = .addrspace_cast,
                .param_count = 1,
            },
        },
        .{
            "@alignCast",
            BuiltinFn{
                .tag = .align_cast,
                .param_count = 1,
            },
        },
        .{
            "@alignOf",
            BuiltinFn{
                .tag = .align_of,
                .param_count = 1,
            },
        },
        .{
            "@as",
            BuiltinFn{
                .tag = .as,
                .needs_mem_loc = .forward1,
                .eval_to_error = .maybe,
                .param_count = 2,
            },
        },
        .{
            "@asyncCall",
            BuiltinFn{
                .tag = .async_call,
                .param_count = 4,
            },
        },
        .{
            "@atomicLoad",
            BuiltinFn{
                .tag = .atomic_load,
                .param_count = 3,
            },
        },
        .{
            "@atomicRmw",
            BuiltinFn{
                .tag = .atomic_rmw,
                .param_count = 5,
            },
        },
        .{
            "@atomicStore",
            BuiltinFn{
                .tag = .atomic_store,
                .param_count = 4,
            },
        },
        .{
            "@bitCast",
            BuiltinFn{
                .tag = .bit_cast,
                .needs_mem_loc = .forward0,
                .param_count = 1,
            },
        },
        .{
            "@bitOffsetOf",
            BuiltinFn{
                .tag = .bit_offset_of,
                .param_count = 2,
            },
        },
        .{
            "@intFromBool",
            BuiltinFn{
                .tag = .int_from_bool,
                .param_count = 1,
            },
        },
        .{
            "@bitSizeOf",
            BuiltinFn{
                .tag = .bit_size_of,
                .param_count = 1,
            },
        },
        .{
            "@breakpoint",
            BuiltinFn{
                .tag = .breakpoint,
                .param_count = 0,
                .illegal_outside_function = true,
            },
        },
        .{
            "@mulAdd",
            BuiltinFn{
                .tag = .mul_add,
                .param_count = 4,
            },
        },
        .{
            "@byteSwap",
            BuiltinFn{
                .tag = .byte_swap,
                .param_count = 1,
            },
        },
        .{
            "@bitReverse",
            BuiltinFn{
                .tag = .bit_reverse,
                .param_count = 1,
            },
        },
        .{
            "@offsetOf",
            BuiltinFn{
                .tag = .offset_of,
                .param_count = 2,
            },
        },
        .{
            "@call",
            BuiltinFn{
                .tag = .call,
                .needs_mem_loc = .always,
                .eval_to_error = .maybe,
                .param_count = 3,
            },
        },
        .{
            "@cDefine",
            BuiltinFn{
                .tag = .c_define,
                .param_count = 2,
            },
        },
        .{
            "@cImport",
            BuiltinFn{
                .tag = .c_import,
                .param_count = 1,
            },
        },
        .{
            "@cInclude",
            BuiltinFn{
                .tag = .c_include,
                .param_count = 1,
            },
        },
        .{
            "@clz",
            BuiltinFn{
                .tag = .clz,
                .param_count = 1,
            },
        },
        .{
            "@cmpxchgStrong",
            BuiltinFn{
                .tag = .cmpxchg_strong,
                .param_count = 6,
            },
        },
        .{
            "@cmpxchgWeak",
            BuiltinFn{
                .tag = .cmpxchg_weak,
                .param_count = 6,
            },
        },
        .{
            "@compileError",
            BuiltinFn{
                .tag = .compile_error,
                .param_count = 1,
            },
        },
        .{
            "@compileLog",
            BuiltinFn{
                .tag = .compile_log,
                .param_count = null,
            },
        },
        .{
            "@constCast",
            BuiltinFn{
                .tag = .const_cast,
                .param_count = 1,
            },
        },
        .{
            "@ctz",
            BuiltinFn{
                .tag = .ctz,
                .param_count = 1,
            },
        },
        .{
            "@cUndef",
            BuiltinFn{
                .tag = .c_undef,
                .param_count = 1,
            },
        },
        .{
            "@cVaArg",
            BuiltinFn{
                .tag = .c_va_arg,
                .param_count = 2,
                .illegal_outside_function = true,
            },
        },
        .{
            "@cVaCopy",
            BuiltinFn{
                .tag = .c_va_copy,
                .param_count = 1,
                .illegal_outside_function = true,
            },
        },
        .{
            "@cVaEnd",
            BuiltinFn{
                .tag = .c_va_end,
                .param_count = 1,
                .illegal_outside_function = true,
            },
        },
        .{
            "@cVaStart",
            BuiltinFn{
                .tag = .c_va_start,
                .param_count = 0,
                .illegal_outside_function = true,
            },
        },
        .{
            "@divExact",
            BuiltinFn{
                .tag = .div_exact,
                .param_count = 2,
            },
        },
        .{
            "@divFloor",
            BuiltinFn{
                .tag = .div_floor,
                .param_count = 2,
            },
        },
        .{
            "@divTrunc",
            BuiltinFn{
                .tag = .div_trunc,
                .param_count = 2,
            },
        },
        .{
            "@embedFile",
            BuiltinFn{
                .tag = .embed_file,
                .param_count = 1,
            },
        },
        .{
            "@intFromEnum",
            BuiltinFn{
                .tag = .int_from_enum,
                .param_count = 1,
            },
        },
        .{
            "@errorName",
            BuiltinFn{
                .tag = .error_name,
                .param_count = 1,
            },
        },
        .{
            "@errorReturnTrace",
            BuiltinFn{
                .tag = .error_return_trace,
                .param_count = 0,
            },
        },
        .{
            "@intFromError",
            BuiltinFn{
                .tag = .int_from_error,
                .param_count = 1,
            },
        },
        .{
            "@errorCast",
            BuiltinFn{
                .tag = .error_cast,
                .eval_to_error = .always,
                .param_count = 1,
            },
        },
        .{
            "@export",
            BuiltinFn{
                .tag = .@"export",
                .param_count = 2,
            },
        },
        .{
            "@extern",
            BuiltinFn{
                .tag = .@"extern",
                .param_count = 2,
            },
        },
        .{
            "@fence",
            BuiltinFn{
                .tag = .fence,
                .param_count = 1,
            },
        },
        .{
            "@field",
            BuiltinFn{
                .tag = .field,
                .needs_mem_loc = .always,
                .eval_to_error = .maybe,
                .param_count = 2,
                .allows_lvalue = true,
            },
        },
        .{
            "@fieldParentPtr",
            BuiltinFn{
                .tag = .field_parent_ptr,
                .param_count = 3,
            },
        },
        .{
            "@floatCast",
            BuiltinFn{
                .tag = .float_cast,
                .param_count = 1,
            },
        },
        .{
            "@intFromFloat",
            BuiltinFn{
                .tag = .int_from_float,
                .param_count = 1,
            },
        },
        .{
            "@frame",
            BuiltinFn{
                .tag = .frame,
                .param_count = 0,
            },
        },
        .{
            "@Frame",
            BuiltinFn{
                .tag = .Frame,
                .param_count = 1,
            },
        },
        .{
            "@frameAddress",
            BuiltinFn{
                .tag = .frame_address,
                .param_count = 0,
                .illegal_outside_function = true,
            },
        },
        .{
            "@frameSize",
            BuiltinFn{
                .tag = .frame_size,
                .param_count = 1,
            },
        },
        .{
            "@hasDecl",
            BuiltinFn{
                .tag = .has_decl,
                .param_count = 2,
            },
        },
        .{
            "@hasField",
            BuiltinFn{
                .tag = .has_field,
                .param_count = 2,
            },
        },
        .{
            "@import",
            BuiltinFn{
                .tag = .import,
                .param_count = 1,
            },
        },
        .{
            "@inComptime",
            BuiltinFn{
                .tag = .in_comptime,
                .param_count = 0,
            },
        },
        .{
            "@intCast",
            BuiltinFn{
                .tag = .int_cast,
                .param_count = 1,
            },
        },
        .{
            "@enumFromInt",
            BuiltinFn{
                .tag = .enum_from_int,
                .param_count = 1,
            },
        },
        .{
            "@errorFromInt",
            BuiltinFn{
                .tag = .error_from_int,
                .eval_to_error = .always,
                .param_count = 1,
            },
        },
        .{
            "@floatFromInt",
            BuiltinFn{
                .tag = .float_from_int,
                .param_count = 1,
            },
        },
        .{
            "@ptrFromInt",
            BuiltinFn{
                .tag = .ptr_from_int,
                .param_count = 1,
            },
        },
        .{
            "@max",
            BuiltinFn{
                .tag = .max,
                .param_count = null,
            },
        },
        .{
            "@memcpy",
            BuiltinFn{
                .tag = .memcpy,
                .param_count = 2,
            },
        },
        .{
            "@memset",
            BuiltinFn{
                .tag = .memset,
                .param_count = 2,
            },
        },
        .{
            "@min",
            BuiltinFn{
                .tag = .min,
                .param_count = null,
            },
        },
        .{
            "@wasmMemorySize",
            BuiltinFn{
                .tag = .wasm_memory_size,
                .param_count = 1,
            },
        },
        .{
            "@wasmMemoryGrow",
            BuiltinFn{
                .tag = .wasm_memory_grow,
                .param_count = 2,
            },
        },
        .{
            "@mod",
            BuiltinFn{
                .tag = .mod,
                .param_count = 2,
            },
        },
        .{
            "@mulWithOverflow",
            BuiltinFn{
                .tag = .mul_with_overflow,
                .param_count = 2,
            },
        },
        .{
            "@panic",
            BuiltinFn{
                .tag = .panic,
                .param_count = 1,
            },
        },
        .{
            "@popCount",
            BuiltinFn{
                .tag = .pop_count,
                .param_count = 1,
            },
        },
        .{
            "@prefetch",
            BuiltinFn{
                .tag = .prefetch,
                .param_count = 2,
            },
        },
        .{
            "@ptrCast",
            BuiltinFn{
                .tag = .ptr_cast,
                .param_count = 1,
            },
        },
        .{
            "@intFromPtr",
            BuiltinFn{
                .tag = .int_from_ptr,
                .param_count = 1,
            },
        },
        .{
            "@rem",
            BuiltinFn{
                .tag = .rem,
                .param_count = 2,
            },
        },
        .{
            "@returnAddress",
            BuiltinFn{
                .tag = .return_address,
                .param_count = 0,
                .illegal_outside_function = true,
            },
        },
        .{
            "@select",
            BuiltinFn{
                .tag = .select,
                .param_count = 4,
            },
        },
        .{
            "@setAlignStack",
            BuiltinFn{
                .tag = .set_align_stack,
                .param_count = 1,
                .illegal_outside_function = true,
            },
        },
        .{
            "@setCold",
            BuiltinFn{
                .tag = .set_cold,
                .param_count = 1,
                .illegal_outside_function = true,
            },
        },
        .{
            "@setEvalBranchQuota",
            BuiltinFn{
                .tag = .set_eval_branch_quota,
                .param_count = 1,
            },
        },
        .{
            "@setFloatMode",
            BuiltinFn{
                .tag = .set_float_mode,
                .param_count = 1,
            },
        },
        .{
            "@setRuntimeSafety",
            BuiltinFn{
                .tag = .set_runtime_safety,
                .param_count = 1,
            },
        },
        .{
            "@shlExact",
            BuiltinFn{
                .tag = .shl_exact,
                .param_count = 2,
            },
        },
        .{
            "@shlWithOverflow",
            BuiltinFn{
                .tag = .shl_with_overflow,
                .param_count = 2,
            },
        },
        .{
            "@shrExact",
            BuiltinFn{
                .tag = .shr_exact,
                .param_count = 2,
            },
        },
        .{
            "@shuffle",
            BuiltinFn{
                .tag = .shuffle,
                .param_count = 4,
            },
        },
        .{
            "@sizeOf",
            BuiltinFn{
                .tag = .size_of,
                .param_count = 1,
            },
        },
        .{
            "@splat",
            BuiltinFn{
                .tag = .splat,
                .param_count = 1,
            },
        },
        .{
            "@reduce",
            BuiltinFn{
                .tag = .reduce,
                .param_count = 2,
            },
        },
        .{
            "@src",
            BuiltinFn{
                .tag = .src,
                .needs_mem_loc = .always,
                .param_count = 0,
                .illegal_outside_function = true,
            },
        },
        .{
            "@sqrt",
            BuiltinFn{
                .tag = .sqrt,
                .param_count = 1,
            },
        },
        .{
            "@sin",
            BuiltinFn{
                .tag = .sin,
                .param_count = 1,
            },
        },
        .{
            "@cos",
            BuiltinFn{
                .tag = .cos,
                .param_count = 1,
            },
        },
        .{
            "@tan",
            BuiltinFn{
                .tag = .tan,
                .param_count = 1,
            },
        },
        .{
            "@exp",
            BuiltinFn{
                .tag = .exp,
                .param_count = 1,
            },
        },
        .{
            "@exp2",
            BuiltinFn{
                .tag = .exp2,
                .param_count = 1,
            },
        },
        .{
            "@log",
            BuiltinFn{
                .tag = .log,
                .param_count = 1,
            },
        },
        .{
            "@log2",
            BuiltinFn{
                .tag = .log2,
                .param_count = 1,
            },
        },
        .{
            "@log10",
            BuiltinFn{
                .tag = .log10,
                .param_count = 1,
            },
        },
        .{
            "@abs",
            BuiltinFn{
                .tag = .abs,
                .param_count = 1,
            },
        },
        .{
            "@floor",
            BuiltinFn{
                .tag = .floor,
                .param_count = 1,
            },
        },
        .{
            "@ceil",
            BuiltinFn{
                .tag = .ceil,
                .param_count = 1,
            },
        },
        .{
            "@trunc",
            BuiltinFn{
                .tag = .trunc,
                .param_count = 1,
            },
        },
        .{
            "@round",
            BuiltinFn{
                .tag = .round,
                .param_count = 1,
            },
        },
        .{
            "@subWithOverflow",
            BuiltinFn{
                .tag = .sub_with_overflow,
                .param_count = 2,
            },
        },
        .{
            "@tagName",
            BuiltinFn{
                .tag = .tag_name,
                .param_count = 1,
            },
        },
        .{
            "@This",
            BuiltinFn{
                .tag = .This,
                .param_count = 0,
            },
        },
        .{
            "@trap",
            BuiltinFn{
                .tag = .trap,
                .param_count = 0,
            },
        },
        .{
            "@truncate",
            BuiltinFn{
                .tag = .truncate,
                .param_count = 1,
            },
        },
        .{
            "@Type",
            BuiltinFn{
                .tag = .Type,
                .param_count = 1,
            },
        },
        .{
            "@typeInfo",
            BuiltinFn{
                .tag = .type_info,
                .param_count = 1,
            },
        },
        .{
            "@typeName",
            BuiltinFn{
                .tag = .type_name,
                .param_count = 1,
            },
        },
        .{
            "@TypeOf",
            BuiltinFn{
                .tag = .TypeOf,
                .param_count = null,
            },
        },
        .{
            "@unionInit",
            BuiltinFn{
                .tag = .union_init,
                .needs_mem_loc = .always,
                .param_count = 3,
            },
        },
        .{
            "@Vector",
            BuiltinFn{
                .tag = .Vector,
                .param_count = 2,
            },
        },
        .{
            "@volatileCast",
            BuiltinFn{
                .tag = .volatile_cast,
                .param_count = 1,
            },
        },
        .{
            "@workItemId",
            BuiltinFn{
                .tag = .work_item_id,
                .param_count = 1,
                .illegal_outside_function = true,
            },
        },
        .{
            "@workGroupSize",
            BuiltinFn{
                .tag = .work_group_size,
                .param_count = 1,
                .illegal_outside_function = true,
            },
        },
        .{
            "@workGroupId",
            BuiltinFn{
                .tag = .work_group_id,
                .param_count = 1,
                .illegal_outside_function = true,
            },
        },
    });
};

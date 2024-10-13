const std = @import("std");

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
    branch_hint,
    breakpoint,
    disable_instrumentation,
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
    break :list std.StaticStringMap(@This()).initComptime(.{
        .{
            "@addWithOverflow",
            .{
                .tag = .add_with_overflow,
                .param_count = 2,
            },
        },
        .{
            "@addrSpaceCast",
            .{
                .tag = .addrspace_cast,
                .param_count = 1,
            },
        },
        .{
            "@alignCast",
            .{
                .tag = .align_cast,
                .param_count = 1,
            },
        },
        .{
            "@alignOf",
            .{
                .tag = .align_of,
                .param_count = 1,
            },
        },
        .{
            "@as",
            .{
                .tag = .as,
                .needs_mem_loc = .forward1,
                .eval_to_error = .maybe,
                .param_count = 2,
            },
        },
        .{
            "@asyncCall",
            .{
                .tag = .async_call,
                .param_count = 4,
            },
        },
        .{
            "@atomicLoad",
            .{
                .tag = .atomic_load,
                .param_count = 3,
            },
        },
        .{
            "@atomicRmw",
            .{
                .tag = .atomic_rmw,
                .param_count = 5,
            },
        },
        .{
            "@atomicStore",
            .{
                .tag = .atomic_store,
                .param_count = 4,
            },
        },
        .{
            "@bitCast",
            .{
                .tag = .bit_cast,
                .needs_mem_loc = .forward0,
                .param_count = 1,
            },
        },
        .{
            "@bitOffsetOf",
            .{
                .tag = .bit_offset_of,
                .param_count = 2,
            },
        },
        .{
            "@intFromBool",
            .{
                .tag = .int_from_bool,
                .param_count = 1,
            },
        },
        .{
            "@bitSizeOf",
            .{
                .tag = .bit_size_of,
                .param_count = 1,
            },
        },
        .{
            "@branchHint",
            .{
                .tag = .branch_hint,
                .param_count = 1,
                .illegal_outside_function = true,
            },
        },
        .{
            "@breakpoint",
            .{
                .tag = .breakpoint,
                .param_count = 0,
                .illegal_outside_function = true,
            },
        },
        .{
            "@disableInstrumentation",
            .{
                .tag = .disable_instrumentation,
                .param_count = 0,
                .illegal_outside_function = true,
            },
        },
        .{
            "@mulAdd",
            .{
                .tag = .mul_add,
                .param_count = 4,
            },
        },
        .{
            "@byteSwap",
            .{
                .tag = .byte_swap,
                .param_count = 1,
            },
        },
        .{
            "@bitReverse",
            .{
                .tag = .bit_reverse,
                .param_count = 1,
            },
        },
        .{
            "@offsetOf",
            .{
                .tag = .offset_of,
                .param_count = 2,
            },
        },
        .{
            "@call",
            .{
                .tag = .call,
                .needs_mem_loc = .always,
                .eval_to_error = .maybe,
                .param_count = 3,
            },
        },
        .{
            "@cDefine",
            .{
                .tag = .c_define,
                .param_count = 2,
            },
        },
        .{
            "@cImport",
            .{
                .tag = .c_import,
                .param_count = 1,
            },
        },
        .{
            "@cInclude",
            .{
                .tag = .c_include,
                .param_count = 1,
            },
        },
        .{
            "@clz",
            .{
                .tag = .clz,
                .param_count = 1,
            },
        },
        .{
            "@cmpxchgStrong",
            .{
                .tag = .cmpxchg_strong,
                .param_count = 6,
            },
        },
        .{
            "@cmpxchgWeak",
            .{
                .tag = .cmpxchg_weak,
                .param_count = 6,
            },
        },
        .{
            "@compileError",
            .{
                .tag = .compile_error,
                .param_count = 1,
            },
        },
        .{
            "@compileLog",
            .{
                .tag = .compile_log,
                .param_count = null,
            },
        },
        .{
            "@constCast",
            .{
                .tag = .const_cast,
                .param_count = 1,
            },
        },
        .{
            "@ctz",
            .{
                .tag = .ctz,
                .param_count = 1,
            },
        },
        .{
            "@cUndef",
            .{
                .tag = .c_undef,
                .param_count = 1,
            },
        },
        .{
            "@cVaArg", .{
                .tag = .c_va_arg,
                .param_count = 2,
                .illegal_outside_function = true,
            },
        },
        .{
            "@cVaCopy", .{
                .tag = .c_va_copy,
                .param_count = 1,
                .illegal_outside_function = true,
            },
        },
        .{
            "@cVaEnd", .{
                .tag = .c_va_end,
                .param_count = 1,
                .illegal_outside_function = true,
            },
        },
        .{
            "@cVaStart", .{
                .tag = .c_va_start,
                .param_count = 0,
                .illegal_outside_function = true,
            },
        },
        .{
            "@divExact",
            .{
                .tag = .div_exact,
                .param_count = 2,
            },
        },
        .{
            "@divFloor",
            .{
                .tag = .div_floor,
                .param_count = 2,
            },
        },
        .{
            "@divTrunc",
            .{
                .tag = .div_trunc,
                .param_count = 2,
            },
        },
        .{
            "@embedFile",
            .{
                .tag = .embed_file,
                .param_count = 1,
            },
        },
        .{
            "@intFromEnum",
            .{
                .tag = .int_from_enum,
                .param_count = 1,
            },
        },
        .{
            "@errorName",
            .{
                .tag = .error_name,
                .param_count = 1,
            },
        },
        .{
            "@errorReturnTrace",
            .{
                .tag = .error_return_trace,
                .param_count = 0,
            },
        },
        .{
            "@intFromError",
            .{
                .tag = .int_from_error,
                .param_count = 1,
            },
        },
        .{
            "@errorCast",
            .{
                .tag = .error_cast,
                .eval_to_error = .maybe,
                .param_count = 1,
            },
        },
        .{
            "@export",
            .{
                .tag = .@"export",
                .param_count = 2,
            },
        },
        .{
            "@extern",
            .{
                .tag = .@"extern",
                .param_count = 2,
            },
        },
        .{
            "@field",
            .{
                .tag = .field,
                .needs_mem_loc = .always,
                .eval_to_error = .maybe,
                .param_count = 2,
                .allows_lvalue = true,
            },
        },
        .{
            "@fieldParentPtr",
            .{
                .tag = .field_parent_ptr,
                .param_count = 2,
            },
        },
        .{
            "@floatCast",
            .{
                .tag = .float_cast,
                .param_count = 1,
            },
        },
        .{
            "@intFromFloat",
            .{
                .tag = .int_from_float,
                .param_count = 1,
            },
        },
        .{
            "@frame",
            .{
                .tag = .frame,
                .param_count = 0,
            },
        },
        .{
            "@Frame",
            .{
                .tag = .Frame,
                .param_count = 1,
            },
        },
        .{
            "@frameAddress",
            .{
                .tag = .frame_address,
                .param_count = 0,
                .illegal_outside_function = true,
            },
        },
        .{
            "@frameSize",
            .{
                .tag = .frame_size,
                .param_count = 1,
            },
        },
        .{
            "@hasDecl",
            .{
                .tag = .has_decl,
                .param_count = 2,
            },
        },
        .{
            "@hasField",
            .{
                .tag = .has_field,
                .param_count = 2,
            },
        },
        .{
            "@import",
            .{
                .tag = .import,
                .param_count = 1,
            },
        },
        .{
            "@inComptime",
            .{
                .tag = .in_comptime,
                .param_count = 0,
            },
        },
        .{
            "@intCast",
            .{
                .tag = .int_cast,
                .param_count = 1,
            },
        },
        .{
            "@enumFromInt",
            .{
                .tag = .enum_from_int,
                .param_count = 1,
            },
        },
        .{
            "@errorFromInt",
            .{
                .tag = .error_from_int,
                .eval_to_error = .always,
                .param_count = 1,
            },
        },
        .{
            "@floatFromInt",
            .{
                .tag = .float_from_int,
                .param_count = 1,
            },
        },
        .{
            "@ptrFromInt",
            .{
                .tag = .ptr_from_int,
                .param_count = 1,
            },
        },
        .{
            "@max",
            .{
                .tag = .max,
                .param_count = null,
            },
        },
        .{
            "@memcpy",
            .{
                .tag = .memcpy,
                .param_count = 2,
            },
        },
        .{
            "@memset",
            .{
                .tag = .memset,
                .param_count = 2,
            },
        },
        .{
            "@min",
            .{
                .tag = .min,
                .param_count = null,
            },
        },
        .{
            "@wasmMemorySize",
            .{
                .tag = .wasm_memory_size,
                .param_count = 1,
            },
        },
        .{
            "@wasmMemoryGrow",
            .{
                .tag = .wasm_memory_grow,
                .param_count = 2,
            },
        },
        .{
            "@mod",
            .{
                .tag = .mod,
                .param_count = 2,
            },
        },
        .{
            "@mulWithOverflow",
            .{
                .tag = .mul_with_overflow,
                .param_count = 2,
            },
        },
        .{
            "@panic",
            .{
                .tag = .panic,
                .param_count = 1,
            },
        },
        .{
            "@popCount",
            .{
                .tag = .pop_count,
                .param_count = 1,
            },
        },
        .{
            "@prefetch",
            .{
                .tag = .prefetch,
                .param_count = 2,
            },
        },
        .{
            "@ptrCast",
            .{
                .tag = .ptr_cast,
                .param_count = 1,
            },
        },
        .{
            "@intFromPtr",
            .{
                .tag = .int_from_ptr,
                .param_count = 1,
            },
        },
        .{
            "@rem",
            .{
                .tag = .rem,
                .param_count = 2,
            },
        },
        .{
            "@returnAddress",
            .{
                .tag = .return_address,
                .param_count = 0,
                .illegal_outside_function = true,
            },
        },
        .{
            "@select",
            .{
                .tag = .select,
                .param_count = 4,
            },
        },
        .{
            "@setAlignStack",
            .{
                .tag = .set_align_stack,
                .param_count = 1,
                .illegal_outside_function = true,
            },
        },
        .{
            "@setEvalBranchQuota",
            .{
                .tag = .set_eval_branch_quota,
                .param_count = 1,
            },
        },
        .{
            "@setFloatMode",
            .{
                .tag = .set_float_mode,
                .param_count = 1,
            },
        },
        .{
            "@setRuntimeSafety",
            .{
                .tag = .set_runtime_safety,
                .param_count = 1,
            },
        },
        .{
            "@shlExact",
            .{
                .tag = .shl_exact,
                .param_count = 2,
            },
        },
        .{
            "@shlWithOverflow",
            .{
                .tag = .shl_with_overflow,
                .param_count = 2,
            },
        },
        .{
            "@shrExact",
            .{
                .tag = .shr_exact,
                .param_count = 2,
            },
        },
        .{
            "@shuffle",
            .{
                .tag = .shuffle,
                .param_count = 4,
            },
        },
        .{
            "@sizeOf",
            .{
                .tag = .size_of,
                .param_count = 1,
            },
        },
        .{
            "@splat",
            .{
                .tag = .splat,
                .param_count = 1,
            },
        },
        .{
            "@reduce",
            .{
                .tag = .reduce,
                .param_count = 2,
            },
        },
        .{
            "@src",
            .{
                .tag = .src,
                .needs_mem_loc = .always,
                .param_count = 0,
                .illegal_outside_function = true,
            },
        },
        .{
            "@sqrt",
            .{
                .tag = .sqrt,
                .param_count = 1,
            },
        },
        .{
            "@sin",
            .{
                .tag = .sin,
                .param_count = 1,
            },
        },
        .{
            "@cos",
            .{
                .tag = .cos,
                .param_count = 1,
            },
        },
        .{
            "@tan",
            .{
                .tag = .tan,
                .param_count = 1,
            },
        },
        .{
            "@exp",
            .{
                .tag = .exp,
                .param_count = 1,
            },
        },
        .{
            "@exp2",
            .{
                .tag = .exp2,
                .param_count = 1,
            },
        },
        .{
            "@log",
            .{
                .tag = .log,
                .param_count = 1,
            },
        },
        .{
            "@log2",
            .{
                .tag = .log2,
                .param_count = 1,
            },
        },
        .{
            "@log10",
            .{
                .tag = .log10,
                .param_count = 1,
            },
        },
        .{
            "@abs",
            .{
                .tag = .abs,
                .param_count = 1,
            },
        },
        .{
            "@floor",
            .{
                .tag = .floor,
                .param_count = 1,
            },
        },
        .{
            "@ceil",
            .{
                .tag = .ceil,
                .param_count = 1,
            },
        },
        .{
            "@trunc",
            .{
                .tag = .trunc,
                .param_count = 1,
            },
        },
        .{
            "@round",
            .{
                .tag = .round,
                .param_count = 1,
            },
        },
        .{
            "@subWithOverflow",
            .{
                .tag = .sub_with_overflow,
                .param_count = 2,
            },
        },
        .{
            "@tagName",
            .{
                .tag = .tag_name,
                .param_count = 1,
            },
        },
        .{
            "@This",
            .{
                .tag = .This,
                .param_count = 0,
            },
        },
        .{
            "@trap",
            .{
                .tag = .trap,
                .param_count = 0,
            },
        },
        .{
            "@truncate",
            .{
                .tag = .truncate,
                .param_count = 1,
            },
        },
        .{
            "@Type",
            .{
                .tag = .Type,
                .param_count = 1,
            },
        },
        .{
            "@typeInfo",
            .{
                .tag = .type_info,
                .param_count = 1,
            },
        },
        .{
            "@typeName",
            .{
                .tag = .type_name,
                .param_count = 1,
            },
        },
        .{
            "@TypeOf",
            .{
                .tag = .TypeOf,
                .param_count = null,
            },
        },
        .{
            "@unionInit",
            .{
                .tag = .union_init,
                .needs_mem_loc = .always,
                .param_count = 3,
            },
        },
        .{
            "@Vector",
            .{
                .tag = .Vector,
                .param_count = 2,
            },
        },
        .{
            "@volatileCast",
            .{
                .tag = .volatile_cast,
                .param_count = 1,
            },
        },
        .{
            "@workItemId", .{
                .tag = .work_item_id,
                .param_count = 1,
                .illegal_outside_function = true,
            },
        },
        .{
            "@workGroupSize",
            .{
                .tag = .work_group_size,
                .param_count = 1,
                .illegal_outside_function = true,
            },
        },
        .{
            "@workGroupId",
            .{
                .tag = .work_group_id,
                .param_count = 1,
                .illegal_outside_function = true,
            },
        },
    });
};

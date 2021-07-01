const std = @import("std");

pub const Tag = enum {
    add_with_overflow,
    align_cast,
    align_of,
    as,
    async_call,
    atomic_load,
    atomic_rmw,
    atomic_store,
    bit_cast,
    bit_offset_of,
    bool_to_int,
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
    ctz,
    c_undef,
    div_exact,
    div_floor,
    div_trunc,
    embed_file,
    enum_to_int,
    error_name,
    error_return_trace,
    error_to_int,
    err_set_cast,
    @"export",
    @"extern",
    fence,
    field,
    field_parent_ptr,
    float_cast,
    float_to_int,
    frame,
    Frame,
    frame_address,
    frame_size,
    has_decl,
    has_field,
    import,
    int_cast,
    int_to_enum,
    int_to_error,
    int_to_float,
    int_to_ptr,
    memcpy,
    memset,
    wasm_memory_size,
    wasm_memory_grow,
    mod,
    mul_with_overflow,
    panic,
    pop_count,
    ptr_cast,
    ptr_to_int,
    rem,
    return_address,
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
    exp,
    exp2,
    log,
    log2,
    log10,
    fabs,
    floor,
    ceil,
    trunc,
    round,
    sub_with_overflow,
    tag_name,
    This,
    truncate,
    Type,
    type_info,
    type_name,
    TypeOf,
    union_init,
    Vector,
};

tag: Tag,

/// `true` if the builtin call can take advantage of a result location pointer.
needs_mem_loc: bool = false,
/// `true` if the builtin call can be the left-hand side of an expression (assigned to).
allows_lvalue: bool = false,
/// The number of parameters to this builtin function. `null` means variable number
/// of parameters.
param_count: ?u8,

pub const list = list: {
    @setEvalBranchQuota(3000);
    break :list std.ComptimeStringMap(@This(), .{
        .{
            "@addWithOverflow",
            .{
                .tag = .add_with_overflow,
                .param_count = 4,
            },
        },
        .{
            "@alignCast",
            .{
                .tag = .align_cast,
                .param_count = 2,
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
                .needs_mem_loc = true,
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
                .needs_mem_loc = true,
                .param_count = 2,
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
            "@boolToInt",
            .{
                .tag = .bool_to_int,
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
            "@breakpoint",
            .{
                .tag = .breakpoint,
                .param_count = 0,
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
                .param_count = 2,
            },
        },
        .{
            "@bitReverse",
            .{
                .tag = .bit_reverse,
                .param_count = 2,
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
                .needs_mem_loc = true,
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
                .param_count = 2,
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
            "@ctz",
            .{
                .tag = .ctz,
                .param_count = 2,
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
            "@enumToInt",
            .{
                .tag = .enum_to_int,
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
            "@errorToInt",
            .{
                .tag = .error_to_int,
                .param_count = 1,
            },
        },
        .{
            "@errSetCast",
            .{
                .tag = .err_set_cast,
                .param_count = 2,
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
            "@fence",
            .{
                .tag = .fence,
                .param_count = 1,
            },
        },
        .{
            "@field",
            .{
                .tag = .field,
                .needs_mem_loc = true,
                .param_count = 2,
                .allows_lvalue = true,
            },
        },
        .{
            "@fieldParentPtr",
            .{
                .tag = .field_parent_ptr,
                .param_count = 3,
            },
        },
        .{
            "@floatCast",
            .{
                .tag = .float_cast,
                .param_count = 2,
            },
        },
        .{
            "@floatToInt",
            .{
                .tag = .float_to_int,
                .param_count = 2,
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
            "@intCast",
            .{
                .tag = .int_cast,
                .param_count = 2,
            },
        },
        .{
            "@intToEnum",
            .{
                .tag = .int_to_enum,
                .param_count = 2,
            },
        },
        .{
            "@intToError",
            .{
                .tag = .int_to_error,
                .param_count = 1,
            },
        },
        .{
            "@intToFloat",
            .{
                .tag = .int_to_float,
                .param_count = 2,
            },
        },
        .{
            "@intToPtr",
            .{
                .tag = .int_to_ptr,
                .param_count = 2,
            },
        },
        .{
            "@memcpy",
            .{
                .tag = .memcpy,
                .param_count = 3,
            },
        },
        .{
            "@memset",
            .{
                .tag = .memset,
                .param_count = 3,
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
                .param_count = 4,
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
                .param_count = 2,
            },
        },
        .{
            "@ptrCast",
            .{
                .tag = .ptr_cast,
                .param_count = 2,
            },
        },
        .{
            "@ptrToInt",
            .{
                .tag = .ptr_to_int,
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
            },
        },
        .{
            "@setAlignStack",
            .{
                .tag = .set_align_stack,
                .param_count = 1,
            },
        },
        .{
            "@setCold",
            .{
                .tag = .set_cold,
                .param_count = 1,
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
                .param_count = 4,
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
                .needs_mem_loc = true,
                .param_count = 2,
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
                .needs_mem_loc = true,
                .param_count = 0,
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
            "@fabs",
            .{
                .tag = .fabs,
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
                .param_count = 4,
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
            "@truncate",
            .{
                .tag = .truncate,
                .param_count = 2,
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
                .needs_mem_loc = true,
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
    });
};

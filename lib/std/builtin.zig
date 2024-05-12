//! Types and values provided by the Zig language.

const builtin = @import("builtin");

/// `explicit_subsystem` is missing when the subsystem is automatically detected,
/// so Zig standard library has the subsystem detection logic here. This should generally be
/// used rather than `explicit_subsystem`.
/// On non-Windows targets, this is `null`.
pub const subsystem: ?std.Target.SubSystem = blk: {
    if (@hasDecl(builtin, "explicit_subsystem")) break :blk builtin.explicit_subsystem;
    switch (builtin.os.tag) {
        .windows => {
            if (builtin.is_test) {
                break :blk std.Target.SubSystem.Console;
            }
            if (@hasDecl(root, "main") or
                @hasDecl(root, "WinMain") or
                @hasDecl(root, "wWinMain") or
                @hasDecl(root, "WinMainCRTStartup") or
                @hasDecl(root, "wWinMainCRTStartup"))
            {
                break :blk std.Target.SubSystem.Windows;
            } else {
                break :blk std.Target.SubSystem.Console;
            }
        },
        else => break :blk null,
    }
};

/// This data structure is used by the Zig language code generation and
/// therefore must be kept in sync with the compiler implementation.
pub const StackTrace = struct {
    index: usize,
    instruction_addresses: []usize,
};

/// This data structure is used by the Zig language code generation and
/// therefore must be kept in sync with the compiler implementation.
pub const GlobalLinkage = enum {
    internal,
    strong,
    weak,
    link_once,
};

/// This data structure is used by the Zig language code generation and
/// therefore must be kept in sync with the compiler implementation.
pub const SymbolVisibility = enum {
    default,
    hidden,
    protected,
};

/// This data structure is used by the Zig language code generation and
/// therefore must be kept in sync with the compiler implementation.
pub const AtomicOrder = enum {
    unordered,
    monotonic,
    acquire,
    release,
    acq_rel,
    seq_cst,
};

/// This data structure is used by the Zig language code generation and
/// therefore must be kept in sync with the compiler implementation.
pub const ReduceOp = enum {
    And,
    Or,
    Xor,
    Min,
    Max,
    Add,
    Mul,
};

/// This data structure is used by the Zig language code generation and
/// therefore must be kept in sync with the compiler implementation.
pub const AtomicRmwOp = enum {
    /// Exchange - store the operand unmodified.
    /// Supports enums, integers, and floats.
    Xchg,
    /// Add operand to existing value.
    /// Supports integers and floats.
    /// For integers, two's complement wraparound applies.
    Add,
    /// Subtract operand from existing value.
    /// Supports integers and floats.
    /// For integers, two's complement wraparound applies.
    Sub,
    /// Perform bitwise AND on existing value with operand.
    /// Supports integers.
    And,
    /// Perform bitwise NAND on existing value with operand.
    /// Supports integers.
    Nand,
    /// Perform bitwise OR on existing value with operand.
    /// Supports integers.
    Or,
    /// Perform bitwise XOR on existing value with operand.
    /// Supports integers.
    Xor,
    /// Store operand if it is larger than the existing value.
    /// Supports integers and floats.
    Max,
    /// Store operand if it is smaller than the existing value.
    /// Supports integers and floats.
    Min,
};

/// The code model puts constraints on the location of symbols and the size of code and data.
/// The selection of a code model is a trade off on speed and restrictions that needs to be selected on a per application basis to meet its requirements.
/// A slightly more detailed explanation can be found in (for example) the [System V Application Binary Interface (x86_64)](https://github.com/hjl-tools/x86-psABI/wiki/x86-64-psABI-1.0.pdf) 3.5.1.
///
/// This data structure is used by the Zig language code generation and
/// therefore must be kept in sync with the compiler implementation.
pub const CodeModel = enum {
    default,
    tiny,
    small,
    kernel,
    medium,
    large,
};

/// This data structure is used by the Zig language code generation and
/// therefore must be kept in sync with the compiler implementation.
pub const OptimizeMode = enum {
    Debug,
    ReleaseSafe,
    ReleaseFast,
    ReleaseSmall,
};

/// Deprecated; use OptimizeMode.
pub const Mode = OptimizeMode;

/// This data structure is used by the Zig language code generation and
/// therefore must be kept in sync with the compiler implementation.
pub const CallingConvention = enum(u8) {
    /// This is the default Zig calling convention used when not using `export` on `fn`
    /// and no other calling convention is specified.
    Unspecified,
    /// Matches the C ABI for the target.
    /// This is the default calling convention when using `export` on `fn`
    /// and no other calling convention is specified.
    C,
    /// This makes a function not have any function prologue or epilogue,
    /// making the function itself uncallable in regular Zig code.
    /// This can be useful when integrating with assembly.
    Naked,
    /// Functions with this calling convention are called asynchronously,
    /// as if called as `async function()`.
    Async,
    /// Functions with this calling convention are inlined at all call sites.
    Inline,
    /// x86-only.
    Interrupt,
    Signal,
    /// x86-only.
    Stdcall,
    /// x86-only.
    Fastcall,
    /// x86-only.
    Vectorcall,
    /// x86-only.
    Thiscall,
    /// ARM Procedure Call Standard (obsolete)
    /// ARM-only.
    APCS,
    /// ARM Architecture Procedure Call Standard (current standard)
    /// ARM-only.
    AAPCS,
    /// ARM Architecture Procedure Call Standard Vector Floating-Point
    /// ARM-only.
    AAPCSVFP,
    /// x86-64-only.
    SysV,
    /// x86-64-only.
    Win64,
    /// AMD GPU, NVPTX, or SPIR-V kernel
    Kernel,
    // Vulkan-only
    Fragment,
    Vertex,
};

/// This data structure is used by the Zig language code generation and
/// therefore must be kept in sync with the compiler implementation.
pub const AddressSpace = enum(u5) {
    // CPU address spaces.
    generic,
    gs,
    fs,
    ss,

    // GPU address spaces.
    global,
    constant,
    param,
    shared,
    local,
    input,
    output,
    uniform,

    // AVR address spaces.
    flash,
    flash1,
    flash2,
    flash3,
    flash4,
    flash5,
};

/// This data structure is used by the Zig language code generation and
/// therefore must be kept in sync with the compiler implementation.
pub const SourceLocation = struct {
    file: [:0]const u8,
    fn_name: [:0]const u8,
    line: u32,
    column: u32,
};

pub const TypeId = std.meta.Tag(Type);

/// This data structure is used by the Zig language code generation and
/// therefore must be kept in sync with the compiler implementation.
pub const Type = union(enum) {
    Type: void,
    Void: void,
    Bool: void,
    NoReturn: void,
    Int: Int,
    Float: Float,
    Pointer: Pointer,
    Array: Array,
    Struct: Struct,
    ComptimeFloat: void,
    ComptimeInt: void,
    Undefined: void,
    Null: void,
    Optional: Optional,
    ErrorUnion: ErrorUnion,
    ErrorSet: ErrorSet,
    Enum: Enum,
    Union: Union,
    Fn: Fn,
    Opaque: Opaque,
    Frame: Frame,
    AnyFrame: AnyFrame,
    Vector: Vector,
    EnumLiteral: void,

    /// This data structure is used by the Zig language code generation and
    /// therefore must be kept in sync with the compiler implementation.
    pub const Int = struct {
        signedness: Signedness,
        bits: u16,
    };

    /// This data structure is used by the Zig language code generation and
    /// therefore must be kept in sync with the compiler implementation.
    pub const Float = struct {
        bits: u16,
    };

    /// This data structure is used by the Zig language code generation and
    /// therefore must be kept in sync with the compiler implementation.
    pub const Pointer = struct {
        size: Size,
        is_const: bool,
        is_volatile: bool,
        /// TODO make this u16 instead of comptime_int
        alignment: comptime_int,
        address_space: AddressSpace,
        child: type,
        is_allowzero: bool,

        /// The type of the sentinel is the element type of the pointer, which is
        /// the value of the `child` field in this struct. However there is no way
        /// to refer to that type here, so we use pointer to `anyopaque`.
        sentinel: ?*const anyopaque,

        /// This data structure is used by the Zig language code generation and
        /// therefore must be kept in sync with the compiler implementation.
        pub const Size = enum(u2) {
            One,
            Many,
            Slice,
            C,
        };
    };

    /// This data structure is used by the Zig language code generation and
    /// therefore must be kept in sync with the compiler implementation.
    pub const Array = struct {
        len: comptime_int,
        child: type,

        /// The type of the sentinel is the element type of the array, which is
        /// the value of the `child` field in this struct. However there is no way
        /// to refer to that type here, so we use pointer to `anyopaque`.
        sentinel: ?*const anyopaque,
    };

    /// This data structure is used by the Zig language code generation and
    /// therefore must be kept in sync with the compiler implementation.
    pub const ContainerLayout = enum(u2) {
        auto,
        @"extern",
        @"packed",
    };

    /// This data structure is used by the Zig language code generation and
    /// therefore must be kept in sync with the compiler implementation.
    pub const StructField = struct {
        name: [:0]const u8,
        type: type,
        default_value: ?*const anyopaque,
        is_comptime: bool,
        alignment: comptime_int,
    };

    /// This data structure is used by the Zig language code generation and
    /// therefore must be kept in sync with the compiler implementation.
    pub const Struct = struct {
        layout: ContainerLayout,
        /// Only valid if layout is .@"packed"
        backing_integer: ?type = null,
        fields: []const StructField,
        decls: []const Declaration,
        is_tuple: bool,
    };

    /// This data structure is used by the Zig language code generation and
    /// therefore must be kept in sync with the compiler implementation.
    pub const Optional = struct {
        child: type,
    };

    /// This data structure is used by the Zig language code generation and
    /// therefore must be kept in sync with the compiler implementation.
    pub const ErrorUnion = struct {
        error_set: type,
        payload: type,
    };

    /// This data structure is used by the Zig language code generation and
    /// therefore must be kept in sync with the compiler implementation.
    pub const Error = struct {
        name: [:0]const u8,
    };

    /// This data structure is used by the Zig language code generation and
    /// therefore must be kept in sync with the compiler implementation.
    pub const ErrorSet = ?[]const Error;

    /// This data structure is used by the Zig language code generation and
    /// therefore must be kept in sync with the compiler implementation.
    pub const EnumField = struct {
        name: [:0]const u8,
        value: comptime_int,
    };

    /// This data structure is used by the Zig language code generation and
    /// therefore must be kept in sync with the compiler implementation.
    pub const Enum = struct {
        tag_type: type,
        fields: []const EnumField,
        decls: []const Declaration,
        is_exhaustive: bool,
    };

    /// This data structure is used by the Zig language code generation and
    /// therefore must be kept in sync with the compiler implementation.
    pub const UnionField = struct {
        name: [:0]const u8,
        type: type,
        alignment: comptime_int,
    };

    /// This data structure is used by the Zig language code generation and
    /// therefore must be kept in sync with the compiler implementation.
    pub const Union = struct {
        layout: ContainerLayout,
        tag_type: ?type,
        fields: []const UnionField,
        decls: []const Declaration,
    };

    /// This data structure is used by the Zig language code generation and
    /// therefore must be kept in sync with the compiler implementation.
    pub const Fn = struct {
        calling_convention: CallingConvention,
        is_generic: bool,
        is_var_args: bool,
        /// TODO change the language spec to make this not optional.
        return_type: ?type,
        params: []const Param,

        /// This data structure is used by the Zig language code generation and
        /// therefore must be kept in sync with the compiler implementation.
        pub const Param = struct {
            is_generic: bool,
            is_noalias: bool,
            type: ?type,
        };
    };

    /// This data structure is used by the Zig language code generation and
    /// therefore must be kept in sync with the compiler implementation.
    pub const Opaque = struct {
        decls: []const Declaration,
    };

    /// This data structure is used by the Zig language code generation and
    /// therefore must be kept in sync with the compiler implementation.
    pub const Frame = struct {
        function: *const anyopaque,
    };

    /// This data structure is used by the Zig language code generation and
    /// therefore must be kept in sync with the compiler implementation.
    pub const AnyFrame = struct {
        child: ?type,
    };

    /// This data structure is used by the Zig language code generation and
    /// therefore must be kept in sync with the compiler implementation.
    pub const Vector = struct {
        len: comptime_int,
        child: type,
    };

    /// This data structure is used by the Zig language code generation and
    /// therefore must be kept in sync with the compiler implementation.
    pub const Declaration = struct {
        name: [:0]const u8,
    };
};

/// This data structure is used by the Zig language code generation and
/// therefore must be kept in sync with the compiler implementation.
pub const FloatMode = enum {
    strict,
    optimized,
};

/// This data structure is used by the Zig language code generation and
/// therefore must be kept in sync with the compiler implementation.
pub const Endian = enum {
    big,
    little,
};

/// This data structure is used by the Zig language code generation and
/// therefore must be kept in sync with the compiler implementation.
pub const Signedness = enum {
    signed,
    unsigned,
};

/// This data structure is used by the Zig language code generation and
/// therefore must be kept in sync with the compiler implementation.
pub const OutputMode = enum {
    Exe,
    Lib,
    Obj,
};

/// This data structure is used by the Zig language code generation and
/// therefore must be kept in sync with the compiler implementation.
pub const LinkMode = enum {
    static,
    dynamic,
};

/// This data structure is used by the Zig language code generation and
/// therefore must be kept in sync with the compiler implementation.
pub const WasiExecModel = enum {
    command,
    reactor,
};

/// This data structure is used by the Zig language code generation and
/// therefore must be kept in sync with the compiler implementation.
pub const CallModifier = enum {
    /// Equivalent to function call syntax.
    auto,

    /// Equivalent to async keyword used with function call syntax.
    async_kw,

    /// Prevents tail call optimization. This guarantees that the return
    /// address will point to the callsite, as opposed to the callsite's
    /// callsite. If the call is otherwise required to be tail-called
    /// or inlined, a compile error is emitted instead.
    never_tail,

    /// Guarantees that the call will not be inlined. If the call is
    /// otherwise required to be inlined, a compile error is emitted instead.
    never_inline,

    /// Asserts that the function call will not suspend. This allows a
    /// non-async function to call an async function.
    no_async,

    /// Guarantees that the call will be generated with tail call optimization.
    /// If this is not possible, a compile error is emitted instead.
    always_tail,

    /// Guarantees that the call will be inlined at the callsite.
    /// If this is not possible, a compile error is emitted instead.
    always_inline,

    /// Evaluates the call at compile-time. If the call cannot be completed at
    /// compile-time, a compile error is emitted instead.
    compile_time,
};

/// This data structure is used by the Zig language code generation and
/// therefore must be kept in sync with the compiler implementation.
pub const VaListAarch64 = extern struct {
    __stack: *anyopaque,
    __gr_top: *anyopaque,
    __vr_top: *anyopaque,
    __gr_offs: c_int,
    __vr_offs: c_int,
};

/// This data structure is used by the Zig language code generation and
/// therefore must be kept in sync with the compiler implementation.
pub const VaListHexagon = extern struct {
    __gpr: c_long,
    __fpr: c_long,
    __overflow_arg_area: *anyopaque,
    __reg_save_area: *anyopaque,
};

/// This data structure is used by the Zig language code generation and
/// therefore must be kept in sync with the compiler implementation.
pub const VaListPowerPc = extern struct {
    gpr: u8,
    fpr: u8,
    reserved: c_ushort,
    overflow_arg_area: *anyopaque,
    reg_save_area: *anyopaque,
};

/// This data structure is used by the Zig language code generation and
/// therefore must be kept in sync with the compiler implementation.
pub const VaListS390x = extern struct {
    __current_saved_reg_area_pointer: *anyopaque,
    __saved_reg_area_end_pointer: *anyopaque,
    __overflow_area_pointer: *anyopaque,
};

/// This data structure is used by the Zig language code generation and
/// therefore must be kept in sync with the compiler implementation.
pub const VaListX86_64 = extern struct {
    gp_offset: c_uint,
    fp_offset: c_uint,
    overflow_arg_area: *anyopaque,
    reg_save_area: *anyopaque,
};

/// This data structure is used by the Zig language code generation and
/// therefore must be kept in sync with the compiler implementation.
pub const VaList = switch (builtin.cpu.arch) {
    .aarch64, .aarch64_be => switch (builtin.os.tag) {
        .windows => *u8,
        .ios, .macos, .tvos, .watchos => *u8,
        else => @compileError("disabled due to miscompilations"), // VaListAarch64,
    },
    .arm => switch (builtin.os.tag) {
        .ios, .macos, .tvos, .watchos => *u8,
        else => *anyopaque,
    },
    .amdgcn => *u8,
    .avr => *anyopaque,
    .bpfel, .bpfeb => *anyopaque,
    .hexagon => if (builtin.target.isMusl()) VaListHexagon else *u8,
    .mips, .mipsel, .mips64, .mips64el => *anyopaque,
    .riscv32, .riscv64 => *anyopaque,
    .powerpc, .powerpcle => switch (builtin.os.tag) {
        .ios, .macos, .tvos, .watchos, .aix => *u8,
        else => VaListPowerPc,
    },
    .powerpc64, .powerpc64le => *u8,
    .sparc, .sparcel, .sparc64 => *anyopaque,
    .spirv32, .spirv64 => *anyopaque,
    .s390x => VaListS390x,
    .wasm32, .wasm64 => *anyopaque,
    .x86 => *u8,
    .x86_64 => switch (builtin.os.tag) {
        .windows => @compileError("disabled due to miscompilations"), // *u8,
        else => VaListX86_64,
    },
    else => @compileError("VaList not supported for this target yet"),
};

/// This data structure is used by the Zig language code generation and
/// therefore must be kept in sync with the compiler implementation.
pub const PrefetchOptions = struct {
    /// Whether the prefetch should prepare for a read or a write.
    rw: Rw = .read,
    /// The data's locality in an inclusive range from 0 to 3.
    ///
    /// 0 means no temporal locality. That is, the data can be immediately
    /// dropped from the cache after it is accessed.
    ///
    /// 3 means high temporal locality. That is, the data should be kept in
    /// the cache as it is likely to be accessed again soon.
    locality: u2 = 3,
    /// The cache that the prefetch should be performed on.
    cache: Cache = .data,

    pub const Rw = enum(u1) {
        read,
        write,
    };

    pub const Cache = enum(u1) {
        instruction,
        data,
    };
};

/// This data structure is used by the Zig language code generation and
/// therefore must be kept in sync with the compiler implementation.
pub const ExportOptions = struct {
    name: []const u8,
    linkage: GlobalLinkage = .strong,
    section: ?[]const u8 = null,
    visibility: SymbolVisibility = .default,
};

/// This data structure is used by the Zig language code generation and
/// therefore must be kept in sync with the compiler implementation.
pub const ExternOptions = struct {
    name: []const u8,
    library_name: ?[]const u8 = null,
    linkage: GlobalLinkage = .strong,
    is_thread_local: bool = false,
};

/// This enum is set by the compiler and communicates which compiler backend is
/// used to produce machine code.
/// Think carefully before deciding to observe this value. Nearly all code should
/// be agnostic to the backend that implements the language. The use case
/// to use this value is to **work around problems with compiler implementations.**
///
/// Avoid failing the compilation if the compiler backend does not match a
/// whitelist of backends; rather one should detect that a known problem would
/// occur in a blacklist of backends.
///
/// The enum is nonexhaustive so that alternate Zig language implementations may
/// choose a number as their tag (please use a random number generator rather
/// than a "cute" number) and codebases can interact with these values even if
/// this upstream enum does not have a name for the number. Of course, upstream
/// is happy to accept pull requests to add Zig implementations to this enum.
///
/// This data structure is part of the Zig language specification.
pub const CompilerBackend = enum(u64) {
    /// It is allowed for a compiler implementation to not reveal its identity,
    /// in which case this value is appropriate. Be cool and make sure your
    /// code supports `other` Zig compilers!
    other = 0,
    /// The original Zig compiler created in 2015 by Andrew Kelley. Implemented
    /// in C++. Used LLVM. Deleted from the ZSF ziglang/zig codebase on
    /// December 6th, 2022.
    stage1 = 1,
    /// The reference implementation self-hosted compiler of Zig, using the
    /// LLVM backend.
    stage2_llvm = 2,
    /// The reference implementation self-hosted compiler of Zig, using the
    /// backend that generates C source code.
    /// Note that one can observe whether the compilation will output C code
    /// directly with `object_format` value rather than the `compiler_backend` value.
    stage2_c = 3,
    /// The reference implementation self-hosted compiler of Zig, using the
    /// WebAssembly backend.
    stage2_wasm = 4,
    /// The reference implementation self-hosted compiler of Zig, using the
    /// arm backend.
    stage2_arm = 5,
    /// The reference implementation self-hosted compiler of Zig, using the
    /// x86_64 backend.
    stage2_x86_64 = 6,
    /// The reference implementation self-hosted compiler of Zig, using the
    /// aarch64 backend.
    stage2_aarch64 = 7,
    /// The reference implementation self-hosted compiler of Zig, using the
    /// x86 backend.
    stage2_x86 = 8,
    /// The reference implementation self-hosted compiler of Zig, using the
    /// riscv64 backend.
    stage2_riscv64 = 9,
    /// The reference implementation self-hosted compiler of Zig, using the
    /// sparc64 backend.
    stage2_sparc64 = 10,
    /// The reference implementation self-hosted compiler of Zig, using the
    /// spirv backend.
    stage2_spirv64 = 11,

    _,
};

/// This function type is used by the Zig language code generation and
/// therefore must be kept in sync with the compiler implementation.
pub const TestFn = struct {
    name: []const u8,
    func: *const fn () anyerror!void,
};

/// This function type is used by the Zig language code generation and
/// therefore must be kept in sync with the compiler implementation.
pub const PanicFn = fn ([]const u8, ?*StackTrace, ?usize) noreturn;

/// This function is used by the Zig language code generation and
/// therefore must be kept in sync with the compiler implementation.
pub const panic: PanicFn = if (@hasDecl(root, "panic"))
    root.panic
else if (@hasDecl(root, "os") and @hasDecl(root.os, "panic"))
    root.os.panic
else
    std.debug.panicImpl;

pub fn checkNonScalarSentinel(expected: anytype, actual: @TypeOf(expected)) void {
    if (!std.meta.eql(expected, actual)) {
        panicSentinelMismatch(expected, actual);
    }
}

pub fn panicSentinelMismatch(expected: anytype, actual: @TypeOf(expected)) noreturn {
    @setCold(true);
    std.debug.panicExtra(null, @returnAddress(), "sentinel mismatch: expected {any}, found {any}", .{ expected, actual });
}

pub fn panicUnwrapError(st: ?*StackTrace, err: anyerror) noreturn {
    @setCold(true);
    std.debug.panicExtra(st, @returnAddress(), "attempt to unwrap error: {s}", .{@errorName(err)});
}

pub fn panicOutOfBounds(index: usize, len: usize) noreturn {
    @setCold(true);
    std.debug.panicExtra(null, @returnAddress(), "index out of bounds: index {d}, len {d}", .{ index, len });
}

pub fn panicStartGreaterThanEnd(start: usize, end: usize) noreturn {
    @setCold(true);
    std.debug.panicExtra(null, @returnAddress(), "start index {d} is larger than end index {d}", .{ start, end });
}

pub fn panicInactiveUnionField(active: anytype, wanted: @TypeOf(active)) noreturn {
    @setCold(true);
    std.debug.panicExtra(null, @returnAddress(), "access of union field '{s}' while field '{s}' is active", .{ @tagName(wanted), @tagName(active) });
}

pub const panic_messages = struct {
    pub const unreach = "reached unreachable code";
    pub const unwrap_null = "attempt to use null value";
    pub const cast_to_null = "cast causes pointer to be null";
    pub const incorrect_alignment = "incorrect alignment";
    pub const invalid_error_code = "invalid error code";
    pub const cast_truncated_data = "integer cast truncated bits";
    pub const negative_to_unsigned = "attempt to cast negative value to unsigned integer";
    pub const integer_overflow = "integer overflow";
    pub const shl_overflow = "left shift overflowed bits";
    pub const shr_overflow = "right shift overflowed bits";
    pub const divide_by_zero = "division by zero";
    pub const exact_division_remainder = "exact division produced remainder";
    pub const inactive_union_field = "access of inactive union field";
    pub const integer_part_out_of_bounds = "integer part of floating point value out of bounds";
    pub const corrupt_switch = "switch on corrupt value";
    pub const shift_rhs_too_big = "shift amount is greater than the type size";
    pub const invalid_enum_value = "invalid enum value";
    pub const sentinel_mismatch = "sentinel mismatch";
    pub const unwrap_error = "attempt to unwrap error";
    pub const index_out_of_bounds = "index out of bounds";
    pub const start_index_greater_than_end = "start index is larger than end index";
    pub const for_len_mismatch = "for loop over objects with non-equal lengths";
    pub const memcpy_len_mismatch = "@memcpy arguments have non-equal lengths";
    pub const memcpy_alias = "@memcpy arguments alias";
    pub const noreturn_returned = "'noreturn' function returned";
};

pub noinline fn returnError(st: *StackTrace) void {
    @setCold(true);
    @setRuntimeSafety(false);
    addErrRetTraceAddr(st, @returnAddress());
}

pub inline fn addErrRetTraceAddr(st: *StackTrace, addr: usize) void {
    if (st.index < st.instruction_addresses.len)
        st.instruction_addresses[st.index] = addr;

    st.index += 1;
}

/// This type is used by the Zig language code generation and
/// therefore must be kept in sync with the compiler implementation.
pub const PanicId = @typeInfo(PanicCause).Union.tag_type.?;

/// This type is used by the Zig language code generation and
/// therefore must be kept in sync with the compiler implementation.
pub const PanicCause = union(enum(u8)) {
    message,
    unwrapped_error,
    returned_noreturn,
    reached_unreachable,
    corrupt_switch,
    accessed_out_of_bounds,
    accessed_out_of_order,
    accessed_out_of_order_extra,
    accessed_inactive_field: type,
    accessed_null_value,
    divided_by_zero,
    memcpy_argument_aliasing,
    mismatched_memcpy_argument_lengths,
    mismatched_for_loop_capture_lengths,
    mismatched_sentinel: type,
    mismatched_null_sentinel,
    shl_overflowed: type,
    shr_overflowed: type,
    shift_amt_overflowed: type,
    div_with_remainder: type,
    mul_overflowed: type,
    add_overflowed: type,
    inc_overflowed: type,
    sub_overflowed: type,
    dec_overflowed: type,
    div_overflowed: type,
    cast_truncated_data: Cast,
    cast_to_enum_from_invalid: type,
    cast_to_error_from_invalid: Cast,
    cast_to_ptr_from_invalid: usize,
    cast_to_int_from_invalid: Cast,
    cast_to_unsigned_from_negative: Cast,

    const ErrorStackTrace = struct {
        st: ?*StackTrace,
        err: anyerror,
    };
    const Bounds = struct {
        index: usize,
        length: usize,
    };
    const OrderedBounds = struct {
        start: usize,
        end: usize,
    };
    const OrderedBoundsExtra = struct {
        start: usize,
        end: usize,
        length: usize,
    };
    const AddressRanges = struct {
        dest_start: usize,
        dest_end: usize,
        src_start: usize,
        src_end: usize,
    };
    const ArgumentLengths = struct {
        dest_len: usize,
        src_len: usize,
    };
    const CaptureLengths = struct {
        loop_len: usize,
        capture_len: usize,
    };
};

/// This type is used by the Zig language code generation and
/// therefore must be kept in sync with the compiler implementation.
pub const Cast = struct {
    to: type,
    from: type,
};

/// This function is used by the Zig language code generation and
/// therefore must be kept in sync with the compiler implementation.
pub fn PanicData(comptime cause: PanicCause) type {
    switch (cause) {
        .message => {
            return []const u8;
        },
        .returned_noreturn,
        .reached_unreachable,
        .accessed_null_value,
        .divided_by_zero,
        .corrupt_switch,
        => {
            return void;
        },
        .unwrapped_error => {
            return PanicCause.ErrorStackTrace;
        },
        .accessed_out_of_bounds => {
            return PanicCause.Bounds;
        },
        .accessed_out_of_order => {
            return PanicCause.OrderedBounds;
        },
        .accessed_out_of_order_extra => {
            return PanicCause.OrderedBoundsExtra;
        },
        .accessed_inactive_field => |tag_type| {
            return struct { expected: tag_type, found: tag_type };
        },
        .memcpy_argument_aliasing => {
            return PanicCause.AddressRanges;
        },
        .mismatched_memcpy_argument_lengths => {
            return PanicCause.ArgumentLengths;
        },
        .mismatched_for_loop_capture_lengths => {
            return PanicCause.CaptureLengths;
        },
        .mismatched_null_sentinel => {
            return u8;
        },
        .mismatched_sentinel => |elem_type| {
            return struct { expected: elem_type, actual: elem_type };
        },
        .mul_overflowed,
        .add_overflowed,
        .sub_overflowed,
        .div_overflowed,
        .div_with_remainder,
        => |val_type| {
            return struct { lhs: val_type, rhs: val_type };
        },
        .shl_overflowed,
        .shr_overflowed,
        => |int_type| {
            switch (@typeInfo(int_type)) {
                .Vector => |info| {
                    return struct { value: int_type, shift_amt: @Vector(info.len, u16) };
                },
                else => {
                    return struct { value: int_type, shift_amt: u16 };
                },
            }
        },
        .shift_amt_overflowed => |int_type| {
            switch (@typeInfo(int_type)) {
                .Vector => |info| {
                    return @Vector(info.len, u16);
                },
                else => {
                    return u16;
                },
            }
        },
        .inc_overflowed,
        .dec_overflowed,
        => |val_type| {
            return val_type;
        },
        .cast_to_ptr_from_invalid => {
            return usize;
        },
        .cast_to_int_from_invalid => |num_types| {
            return num_types.from;
        },
        .cast_truncated_data => |num_types| {
            return num_types.from;
        },
        .cast_to_unsigned_from_negative => |int_types| {
            return int_types.from;
        },
        .cast_to_error_from_invalid => |error_type| {
            return error_type.from;
        },
        .cast_to_enum_from_invalid => |enum_type| {
            return @typeInfo(enum_type).Enum.tag_type;
        },
    }
}

// TODO: Rename to `panic` when the old interface is removed.
pub const panicNew = if (@hasDecl(root, "panicNew")) root.panicNew else panicImpl;

/// The backend/os logic is not here, because this function is a combination
/// of all the special handler functions `panic*`, which also never checked
/// the backend/os before attempting to write error messages.
fn panicImpl(comptime cause: PanicCause, data: anytype) noreturn {
    @setCold(true);
    @setRuntimeSafety(false);
    if (@TypeOf(data) == void) {
        std.debug.panicImpl(@tagName(cause), null, @returnAddress());
    }
    switch (cause) {
        .message => {
            std.debug.panicImpl(data, null, @returnAddress());
        },
        .accessed_null_value => @call(.auto, std.debug.panicImpl, .{
            "attempted to use null value", null, @returnAddress(),
        }),
        .divided_by_zero => @call(.auto, std.debug.panicImpl, .{
            "attempted to divide by zero", null, @returnAddress(),
        }),
        .returned_noreturn => @call(.auto, std.debug.panicImpl, .{
            "returned from function marked 'noreturn'", null, @returnAddress(),
        }),
        .reached_unreachable => @call(.auto, std.debug.panicImpl, .{
            "reached unreachable code", null, @returnAddress(),
        }),
        .corrupt_switch => @call(.auto, std.debug.panicImpl, .{
            "corrupt switch", null, @returnAddress(),
        }),
        .unwrapped_error => @call(.auto, std.debug.panicUnwrappedError, .{
            data.st, data.err, @returnAddress(),
        }),
        .accessed_out_of_bounds => @call(.auto, std.debug.panicAccessedOutOfBounds, .{
            data.index, data.length, @returnAddress(),
        }),
        .accessed_out_of_order => @call(.auto, std.debug.panicAccessedOutOfOrder, .{
            data.start, data.end, @returnAddress(),
        }),
        .accessed_out_of_order_extra => @call(.auto, std.debug.panicAccessedOutOfOrderExtra, .{
            data.start, data.end, data.length, @returnAddress(),
        }),
        .accessed_inactive_field => @call(.auto, std.debug.panicAccessedInactiveField, .{
            @tagName(data.expected), @tagName(data.found), @returnAddress(),
        }),
        .memcpy_argument_aliasing => @call(.auto, std.debug.panicMemcpyArgumentAliasing, .{
            data.dest_start, data.dest_end, data.src_start, data.src_end, @returnAddress(),
        }),
        .mismatched_memcpy_argument_lengths => @call(.auto, std.debug.panicMismatchedMemcpyLengths, .{
            data.dest_len, data.src_len, @returnAddress(),
        }),
        .mismatched_for_loop_capture_lengths => @call(.auto, std.debug.panicMismatchedForLoopCaptureLengths, .{
            data.loop_len, data.capture_len, @returnAddress(),
        }),
        .mismatched_null_sentinel => @call(.auto, std.debug.panicMismatchedNullSentinel, .{
            data, @returnAddress(),
        }),
        .cast_to_enum_from_invalid => |enum_type| @call(.auto, std.debug.panicCastToTagFromInvalid, .{
            std.meta.BestNum(@typeInfo(enum_type).Enum.tag_type), @typeName(enum_type), data, @returnAddress(),
        }),
        .cast_to_error_from_invalid => |error_type| @call(.auto, std.debug.panicCastToErrorFromInvalid, .{
            error_type.from, @typeName(error_type.to), data, @returnAddress(),
        }),
        .mul_overflowed => |int_type| @call(.auto, std.debug.panicArithOverflow(std.meta.BestInt(int_type)).mul, .{
            @typeName(std.meta.Scalar(int_type)), std.meta.bestExtrema(int_type), data.lhs, data.rhs, @returnAddress(),
        }),
        .add_overflowed => |int_type| @call(.auto, std.debug.panicArithOverflow(std.meta.BestInt(int_type)).add, .{
            @typeName(std.meta.Scalar(int_type)), std.meta.bestExtrema(int_type), data.lhs, data.rhs, @returnAddress(),
        }),
        .sub_overflowed => |int_type| @call(.auto, std.debug.panicArithOverflow(std.meta.BestInt(int_type)).sub, .{
            @typeName(std.meta.Scalar(int_type)), std.meta.bestExtrema(int_type), data.lhs, data.rhs, @returnAddress(),
        }),
        .div_overflowed => |int_type| @call(.auto, std.debug.panicArithOverflow(std.meta.BestInt(int_type)).div, .{
            @typeName(std.meta.Scalar(int_type)), std.meta.bestExtrema(int_type), data.lhs, data.rhs, @returnAddress(),
        }),
        .inc_overflowed, .dec_overflowed => {},
        .shl_overflowed => |int_type| @call(.auto, std.debug.panicArithOverflow(std.meta.BestInt(int_type)).shl, .{
            @typeName(std.meta.Scalar(int_type)), data.value, data.shift_amt, ~@abs(@as(std.meta.Scalar(int_type), 0)), @returnAddress(),
        }),
        .shr_overflowed => |int_type| @call(.auto, std.debug.panicArithOverflow(std.meta.BestInt(int_type)).shr, .{
            @typeName(std.meta.Scalar(int_type)), data.value, data.shift_amt, ~@abs(@as(std.meta.Scalar(int_type), 0)), @returnAddress(),
        }),
        .shift_amt_overflowed => |int_type| @call(.auto, std.debug.panicArithOverflow(std.meta.BestInt(@TypeOf(data))).shiftRhs, .{
            @typeName(std.meta.Scalar(int_type)), @bitSizeOf(int_type), data, @returnAddress(),
        }),
        .div_with_remainder => |num_type| @call(.auto, std.debug.panicExactDivisionWithRemainder, .{
            std.meta.BestNum(num_type), data.lhs, data.rhs, @returnAddress(),
        }),
        .mismatched_sentinel => |elem_type| @call(.auto, std.debug.panicMismatchedSentinel, .{
            std.meta.BestNum(elem_type), @typeName(elem_type),
            data.expected,               data.actual,
            @returnAddress(),
        }),
        .cast_to_ptr_from_invalid => |alignment| @call(.auto, std.debug.panicCastToPointerFromInvalid, .{
            data, alignment, @returnAddress(),
        }),
        .cast_to_unsigned_from_negative => |int_types| @call(.auto, std.debug.panicCastToUnsignedFromNegative, .{
            std.meta.BestNum(int_types.to),   @typeName(int_types.to),
            std.meta.BestNum(int_types.from), @typeName(int_types.from),
            data,                             @returnAddress(),
        }),
        .cast_to_int_from_invalid => |num_types| @call(.auto, std.debug.panicCastToIntFromInvalid, .{
            std.meta.BestNum(num_types.to),     @typeName(num_types.to),
            std.meta.BestNum(num_types.from),   @typeName(num_types.from),
            std.meta.bestExtrema(num_types.to), data,
            @returnAddress(),
        }),
        .cast_truncated_data => |num_types| @call(.auto, std.debug.panicCastTruncatedData, .{
            std.meta.BestNum(num_types.to),     @typeName(num_types.to),
            std.meta.BestNum(num_types.from),   @typeName(num_types.from),
            std.meta.bestExtrema(num_types.to), data,
            @returnAddress(),
        }),
    }
}

const std = @import("std.zig");
const root = @import("root");

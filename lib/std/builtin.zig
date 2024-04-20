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

const std = @import("std.zig");
const root = @import("root");

// Safety

/// This type is used by the Zig language code generation and
/// therefore must be kept in sync with the compiler implementation.
pub const PanicId = @typeInfo(PanicCause).Union.tag_type.?;

/// This type is used by the Zig language code generation and
/// therefore must be kept in sync with the compiler implementation.
pub const PanicCause = union(enum(u8)) {
    message = 0,
    unwrapped_error = 1,
    returned_noreturn = 2,
    reached_unreachable = 3,
    corrupt_switch = 4,
    accessed_out_of_bounds = 5,
    accessed_out_of_order = 6,
    accessed_out_of_order_extra = 7,
    accessed_inactive_field: type = 8,
    accessed_null_value = 9,
    divided_by_zero = 10,
    memcpy_argument_aliasing = 11,
    mismatched_memcpy_argument_lengths = 12,
    mismatched_for_loop_capture_lengths = 13,
    mismatched_sentinel: type = 14,
    mismatched_null_sentinel = 15,
    shl_overflowed: type = 16,
    shr_overflowed: type = 17,
    shift_amt_overflowed: type = 18,
    div_with_remainder: type = 19,
    mul_overflowed: type = 20,
    add_overflowed: type = 21,
    inc_overflowed: type = 22,
    sub_overflowed: type = 23,
    dec_overflowed: type = 24,
    div_overflowed: type = 25,
    cast_truncated_data: Cast = 26,
    cast_to_enum_from_invalid: type = 27,
    cast_to_error_from_invalid: Cast = 28,
    cast_to_ptr_from_invalid: usize = 29,
    cast_to_int_from_invalid: Cast = 30,
    cast_to_unsigned_from_negative: Cast = 31,

    /// ATTENTION: These types are not at all necessary for this implementation.
    ///            Their definitions may be inlined if there is any reason at
    ///            all to do so.
    const ErrorStackTrace = struct {
        err: anyerror,
        st: ?*StackTrace,
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
    if (cause == .message) {
        return []const u8;
    }
    if (@field(builtin.runtime_safety, @tagName(cause)) != .extra) {
        return void;
    }
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
        .inc_overflowed,
        .dec_overflowed,
        => |val_type| {
            return val_type;
        },
        .shl_overflowed,
        .shr_overflowed,
        => |int_type| {
            return struct { value: int_type, shift_amt: u16 };
        },
        .shift_amt_overflowed => {
            return u16;
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
        .cast_to_enum_from_invalid => |enum_type| {
            return @typeInfo(enum_type).Enum.tag_type;
        },
        .cast_to_error_from_invalid => |error_type| {
            return error_type.from;
        },
    }
}
pub const RuntimeSafety = packed struct(u64) {
    message: Setting = .extra,
    unwrapped_error: Setting = .extra,
    returned_noreturn: Setting = .extra,
    reached_unreachable: Setting = .extra,
    corrupt_switch: Setting = .extra,
    accessed_out_of_bounds: Setting = .extra,
    accessed_out_of_order: Setting = .extra,
    accessed_out_of_order_extra: Setting = .extra,
    accessed_inactive_field: Setting = .extra,
    accessed_null_value: Setting = .extra,
    divided_by_zero: Setting = .extra,
    memcpy_argument_aliasing: Setting = .extra,
    mismatched_memcpy_argument_lengths: Setting = .extra,
    mismatched_for_loop_capture_lengths: Setting = .extra,
    mismatched_sentinel: Setting = .extra,
    mismatched_null_sentinel: Setting = .extra,
    shl_overflowed: Setting = .extra,
    shr_overflowed: Setting = .extra,
    shift_amt_overflowed: Setting = .extra,
    div_with_remainder: Setting = .extra,
    mul_overflowed: Setting = .extra,
    add_overflowed: Setting = .extra,
    inc_overflowed: Setting = .extra,
    sub_overflowed: Setting = .extra,
    dec_overflowed: Setting = .extra,
    div_overflowed: Setting = .extra,
    cast_truncated_data: Setting = .extra,
    cast_to_enum_from_invalid: Setting = .extra,
    cast_to_error_from_invalid: Setting = .extra,
    cast_to_ptr_from_invalid: Setting = .extra,
    cast_to_int_from_invalid: Setting = .extra,
    cast_to_unsigned_from_negative: Setting = .extra,

    pub const Setting = enum(u2) {
        /// Do not check panic condition.
        none = 0,
        /// Check panic condition.
        check = 1,
        /// Check panic condition, include context data.
        extra = 2,
    };

    // TODO: Remove when `analyzeSlice2` is confirmed.
    pub var analyze_slice2: bool = true;
};

// TODO: Rename to `panic` when the old interface is removed.
pub const panicNew = if (@hasDecl(root, "panicNew")) root.panicNew else panicNew_default;

// TODO: Rename to `panicImpl` when the old interface is removed.
//
//       The backend/os logic is not here, because this function is a combination
//       of all the special handler functions `panic*`, which also never checked
//       the backend/os before attempting to write error messages.
pub fn panicNew_default(comptime cause: PanicCause, data: PanicData(cause)) noreturn {
    @setCold(true);
    @setRuntimeSafety(false);
    if (cause != .message and
        @field(builtin.runtime_safety, @tagName(cause)) == .check)
    {
        std.debug.panicImpl(@tagName(cause), null, @returnAddress());
    }
    switch (cause) {
        .message => {
            std.debug.panicImpl(data, null, @returnAddress());
        },
        .accessed_null_value => {
            std.debug.panicImpl("attempted to use null value", null, @returnAddress());
        },
        .divided_by_zero => {
            std.debug.panicImpl("attempted to divide by zero", null, @returnAddress());
        },
        .returned_noreturn => {
            std.debug.panicImpl("returned from function marked 'noreturn'", null, @returnAddress());
        },
        .reached_unreachable, .corrupt_switch => {
            std.debug.panicImpl("reached unreachable code", null, @returnAddress());
        },
        .unwrapped_error => {
            var buf: [256]u8 = undefined;
            buf[0..28].* = "attempted to discard error: ".*;
            const ptr: [*]u8 = mem.cpyEqu(buf[28..], @errorName(data.err));
            std.debug.panicImpl(buf[0 .. @intFromPtr(ptr) -% @intFromPtr(&buf)], data.st, @returnAddress());
        },
        .accessed_out_of_bounds => {
            var buf: [256]u8 = undefined;
            buf[0..6].* = "index ".*;
            var ptr: [*]u8 = fmt.formatIntDec(buf[6..], data.index);
            ptr[0..9].* = ", length ".*;
            ptr = fmt.formatIntDec(ptr[9..][0..32], data.length);
            std.debug.panicImpl(buf[0 .. @intFromPtr(ptr) -% @intFromPtr(&buf)], null, @returnAddress());
        },
        .accessed_out_of_order => {
            var buf: [256]u8 = undefined;
            var ptr: [*]u8 = &buf;
            ptr[0..12].* = "start index ".*;
            ptr = fmt.formatIntDec(buf[12..], data.start);
            ptr[0..26].* = " is larger than end index ".*;
            ptr = fmt.formatIntDec(ptr[26..][0..32], data.end);
            std.debug.panicImpl(buf[0 .. @intFromPtr(ptr) -% @intFromPtr(&buf)], null, @returnAddress());
        },
        .accessed_out_of_order_extra => {
            var buf: [256]u8 = undefined;
            var ptr: [*]u8 = &buf;
            if (data.start > data.end) {
                ptr[0..12].* = "start index ".*;
                ptr = fmt.formatIntDec(buf[12..], data.start);
                ptr[0..26].* = " is larger than end index ".*;
                ptr = fmt.formatIntDec(ptr[26..][0..32], data.end);
            } else {
                ptr[0..10].* = "end index ".*;
                ptr = fmt.formatIntDec(buf[10..], data.start);
                ptr[0..9].* = ", length ".*;
                ptr = fmt.formatIntDec(ptr[9..][0..32], data.length);
            }
            std.debug.panicImpl(buf[0 .. @intFromPtr(ptr) -% @intFromPtr(&buf)], null, @returnAddress());
        },
        .accessed_inactive_field => {
            var buf: [256]u8 = undefined;
            buf[0..23].* = "access of union field '".*;
            var ptr: [*]u8 = mem.cpyEqu(buf[23..], @tagName(data.found));
            ptr[0..15].* = "' while field '".*;
            ptr = mem.cpyEqu(ptr + 15, @tagName(data.expected));
            ptr = mem.cpyEqu(ptr, "' is active");
            std.debug.panicImpl(buf[0 .. @intFromPtr(ptr) -% @intFromPtr(&buf)], null, @returnAddress());
        },
        .memcpy_argument_aliasing => {
            var buf: [256]u8 = undefined;
            buf[0..32].* = "@memcpy arguments alias between ".*;
            var ptr: [*]u8 = fmt.formatIntHex(buf[32..], @max(data.dest_start, data.src_start));
            ptr[0..5].* = " and ".*;
            ptr = fmt.formatIntHex(ptr[5..][0..32], @min(data.dest_end, data.src_end));
            ptr[0..2].* = " (".*;
            ptr = fmt.formatIntDec(ptr[2..][0..32], data.dest_end -% data.dest_start);
            ptr[0..7].* = " bytes)".*;
            std.debug.panicImpl(buf[0 .. @intFromPtr(ptr + 7) -% @intFromPtr(&buf)], null, @returnAddress());
        },
        .mismatched_memcpy_argument_lengths => {
            var buf: [256]u8 = undefined;
            buf[0..65].* = "@memcpy destination and source with mismatched lengths: expected ".*;
            var ptr: [*]u8 = fmt.formatIntDec(buf[65..], data.dest_len);
            ptr[0..8].* = ", found ".*;
            ptr = fmt.formatIntDec(ptr[8..][0..32], data.src_len);
            std.debug.panicImpl(buf[0 .. @intFromPtr(ptr) -% @intFromPtr(&buf)], null, @returnAddress());
        },
        .mismatched_for_loop_capture_lengths => {
            var buf: [256]u8 = undefined;
            buf[0..58].* = "multi-for loop captures with mismatched lengths: expected ".*;
            var ptr: [*]u8 = fmt.formatIntDec(buf[58..], data.loop_len);
            ptr[0..8].* = ", found ".*;
            ptr = fmt.formatIntDec(ptr[8..][0..32], data.capture_len);
            std.debug.panicImpl(buf[0 .. @intFromPtr(ptr) -% @intFromPtr(&buf)], null, @returnAddress());
        },
        .mismatched_null_sentinel => {
            var buf: [256]u8 = undefined;
            buf[0..28].* = "mismatched null terminator: ".*;
            const ptr: [*]u8 = fmt.formatIntDec(buf[28..], data);
            std.debug.panicImpl(buf[0 .. @intFromPtr(ptr) -% @intFromPtr(&buf)], null, @returnAddress());
        },
        .cast_to_enum_from_invalid => |enum_type| @call(.never_inline, panicCastToTagFromInvalid, .{
            meta.BestNum(@typeInfo(enum_type).Enum.tag_type), @typeName(enum_type), data, @returnAddress(),
        }),
        .cast_to_error_from_invalid => |error_type| @call(.never_inline, panicCastToErrorFromInvalid, .{
            error_type.from, @typeName(error_type.to), data, @returnAddress(),
        }),
        .mul_overflowed,
        .add_overflowed,
        .sub_overflowed,
        .div_overflowed,
        => |int_type| @call(.never_inline, panicArithOverflow(meta.BestInt(int_type)).combined, .{
            cause, @typeName(int_type), comptime math.bestExtrema(int_type), data.lhs, data.rhs, @returnAddress(),
        }),
        .inc_overflowed => |int_type| @call(.never_inline, panicArithOverflow(meta.BestInt(int_type)).inc, .{
            @typeName(int_type), comptime math.bestExtrema(int_type).max, data, @returnAddress(),
        }),
        .dec_overflowed => |int_type| @call(.never_inline, panicArithOverflow(meta.BestInt(int_type)).dec, .{
            @typeName(int_type), comptime math.bestExtrema(int_type).min, data, @returnAddress(),
        }),
        .shl_overflowed => |int_type| @call(.never_inline, panicArithOverflow(meta.BestInt(int_type)).shl, .{
            @typeName(int_type), data.value, data.shift_amt, ~@abs(@as(int_type, 0)), @returnAddress(),
        }),
        .shr_overflowed => |int_type| @call(.never_inline, panicArithOverflow(meta.BestInt(int_type)).shr, .{
            @typeName(int_type), data.value, data.shift_amt, ~@abs(@as(int_type, 0)), @returnAddress(),
        }),
        .shift_amt_overflowed => |int_type| @call(.never_inline, panicArithOverflow(meta.BestInt(int_type)).shiftRhs, .{
            @typeName(int_type), @bitSizeOf(int_type), data, @returnAddress(),
        }),
        .div_with_remainder => |num_type| @call(.never_inline, panicExactDivisionWithRemainder, .{
            meta.BestNum(num_type), data.lhs, data.rhs, @returnAddress(),
        }),
        .mismatched_sentinel => |elem_type| @call(.never_inline, panicMismatchedSentinel, .{
            meta.BestNum(elem_type), @typeName(elem_type),
            data.expected,           data.actual,
            @returnAddress(),
        }),
        .cast_to_ptr_from_invalid => |alignment| @call(.never_inline, panicCastToPointerFromInvalid, .{
            data, alignment, @returnAddress(),
        }),
        .cast_to_unsigned_from_negative => |int_types| @call(.never_inline, panicCastToUnsignedFromNegative, .{
            meta.BestNum(int_types.to),   @typeName(int_types.to),
            meta.BestNum(int_types.from), @typeName(int_types.from),
            data,                         @returnAddress(),
        }),
        .cast_to_int_from_invalid => |num_types| @call(.never_inline, panicCastToIntFromInvalid, .{
            meta.BestNum(num_types.to),              @typeName(num_types.to),
            meta.BestNum(num_types.from),            @typeName(num_types.from),
            comptime math.bestExtrema(num_types.to), data,
            @returnAddress(),
        }),
        .cast_truncated_data => |num_types| @call(.never_inline, panicCastTruncatedData, .{
            meta.BestNum(num_types.to),              @typeName(num_types.to),
            meta.BestNum(num_types.from),            @typeName(num_types.from),
            comptime math.bestExtrema(num_types.to), data,
            @returnAddress(),
        }),
    }
}

/// TODO: Move all of the following functions to `debug` with the same names.
pub fn panicCastToPointerFromInvalid(
    address: usize,
    alignment: usize,
    ret_addr: usize,
) noreturn {
    @setCold(true);
    @setRuntimeSafety(false);
    var buf: [256]u8 = undefined;
    var ptr: [*]u8 = &buf;
    if (address != 0) {
        ptr[0..42].* = "cast to pointer with incorrect alignment (".*;
        ptr = fmt.formatIntDec(ptr[42..][0..32], alignment);
        ptr[0..3].* = "): ".*;
        ptr = fmt.formatIntDec(ptr[3..][0..32], address);
        ptr[0..4].* = " == ".*;
        ptr = fmt.formatIntDec(ptr[4..][0..32], address & ~(alignment -% 1));
        ptr[0] = '+';
        ptr = fmt.formatIntDec(ptr[1..][0..32], address & (alignment -% 1));
    } else {
        ptr[0..40].* = "cast to null pointer without 'allowzero'".*;
        ptr += 40;
    }
    std.debug.panicImpl(buf[0 .. @intFromPtr(ptr) -% @intFromPtr(&buf)], null, ret_addr);
}
pub fn panicCastToTagFromInvalid(
    comptime Integer: type,
    type_name: []const u8,
    value: Integer,
    ret_addr: usize,
) noreturn {
    @setCold(true);
    @setRuntimeSafety(false);
    var buf: [256]u8 = undefined;
    buf[0..9].* = "cast to '".*;
    var ptr: [*]u8 = mem.cpyEqu(buf[9..], type_name);
    ptr[0..21].* = "' from invalid value ".*;
    ptr = fmt.formatIntDec(ptr[21..][0..32], value);
    std.debug.panicImpl(buf[0 .. @intFromPtr(ptr) -% @intFromPtr(&buf)], null, ret_addr);
}
pub fn panicCastToErrorFromInvalid(
    comptime From: type,
    type_name: []const u8,
    value: From,
    ret_addr: usize,
) noreturn {
    @setCold(true);
    @setRuntimeSafety(false);
    var buf: [256]u8 = undefined;
    buf[0..9].* = "cast to '".*;
    var ptr: [*]u8 = mem.cpyEqu(buf[9..], type_name);
    ptr[0..7].* = "' from ".*;
    if (@typeInfo(From) == .Int) {
        ptr[7..32].* = "non-existent error-code (".*;
        ptr = fmt.formatIntDec(ptr[32..][0..32], value);
        ptr[0] = ')';
        ptr += 1;
    } else {
        ptr[7] = '\'';
        ptr = mem.cpyEqu(ptr + 8, @typeName(From));
        ptr[0..2].* = "' ".*;
        ptr = fmt.AnyFormat(.{}, From).write(ptr + 2, value);
    }
    std.debug.panicImpl(buf[0 .. @intFromPtr(ptr) -% @intFromPtr(&buf)], null, ret_addr);
}
pub fn panicCastToIntFromInvalid(
    comptime To: type,
    to_type_name: []const u8,
    comptime From: type,
    from_type_name: []const u8,
    extrema: math.BestExtrema(To),
    value: From,
    ret_addr: usize,
) noreturn {
    @setCold(true);
    @setRuntimeSafety(false);
    var buf: [256]u8 = undefined;
    const yn: bool = value < 0;
    var ptr: [*]u8 = writeCastToFrom(&buf, to_type_name, from_type_name);
    ptr[0..13].* = " overflowed: ".*;
    ptr = writeAboveOrBelowLimit(ptr + 13, To, to_type_name, yn, if (yn) extrema.min else extrema.max);
    std.debug.panicImpl(buf[0 .. @intFromPtr(ptr) -% @intFromPtr(&buf)], null, ret_addr);
}
pub fn panicCastTruncatedData(
    comptime To: type,
    to_type_name: []const u8,
    comptime From: type,
    from_type_name: []const u8,
    extrema: math.BestExtrema(To),
    value: From,
    ret_addr: usize,
) noreturn {
    @setCold(true);
    @setRuntimeSafety(false);
    if (builtin.zig_backend != .stage2_llvm and @bitSizeOf(From) > 64) {
        return std.debug.panicImpl("cast truncated bits", null, ret_addr);
    }
    var buf: [256]u8 = undefined;
    const yn: bool = value < 0;
    var ptr: [*]u8 = writeCastToFrom(&buf, to_type_name, from_type_name);
    ptr[0..17].* = " truncated bits: ".*;
    ptr = fmt.formatIntDec(ptr[17..][0..32], value);
    ptr = writeAboveOrBelowLimit(ptr, To, to_type_name, yn, if (yn) extrema.min else extrema.max);
    std.debug.panicImpl(buf[0 .. @intFromPtr(ptr) -% @intFromPtr(&buf)], null, ret_addr);
}
pub fn panicCastToUnsignedFromNegative(
    comptime _: type,
    to_type_name: []const u8,
    comptime From: type,
    from_type_name: []const u8,
    value: From,
    ret_addr: usize,
) noreturn {
    @setCold(true);
    @setRuntimeSafety(false);
    if (builtin.zig_backend != .stage2_llvm and @bitSizeOf(From) > 64) {
        return std.debug.panicImpl("cast to unsigned from negative", null, ret_addr);
    }
    var buf: [256]u8 = undefined;
    var ptr: [*]u8 = writeCastToFrom(&buf, to_type_name, from_type_name);
    ptr[0..18].* = " lost signedness (".*;
    ptr = fmt.formatIntDec(ptr[18..][0..32], value);
    ptr[0] = ')';
    std.debug.panicImpl(buf[0 .. @intFromPtr(ptr + 1) -% @intFromPtr(&buf)], null, ret_addr);
}
pub fn panicMismatchedSentinel(
    comptime Number: type,
    type_name: []const u8,
    expected: Number,
    found: Number,
    ret_addr: usize,
) noreturn {
    @setCold(true);
    @setRuntimeSafety(false);
    if (builtin.zig_backend != .stage2_llvm and
        (@bitSizeOf(Number) > 64 or @typeInfo(Number) == .Float))
    {
        return std.debug.panicImpl("mismatched sentinel", null, ret_addr);
    }
    var buf: [256]u8 = undefined;
    var ptr: [*]u8 = mem.cpyEqu(&buf, type_name);
    ptr[0..29].* = " sentinel mismatch: expected ".*;
    ptr = fmt.formatAny(ptr[29..][0..32], expected);
    ptr[0..8].* = ", found ".*;
    ptr = fmt.formatAny(ptr[8..][0..32], found);
    std.debug.panicImpl(buf[0 .. @intFromPtr(ptr) -% @intFromPtr(&buf)], null, ret_addr);
}
pub fn panicAccessedInactiveField(
    expected: []const u8,
    found: []const u8,
    ret_addr: usize,
) noreturn {
    @setCold(true);
    @setRuntimeSafety(false);
    var buf: [256]u8 = undefined;
    buf[0..23].* = "access of union field '".*;
    var ptr: [*]u8 = mem.cpyEqu(buf[23..], found);
    ptr[0..15].* = "' while field '".*;
    ptr = mem.cpyEqu(ptr + 15, expected);
    ptr = mem.cpyEqu(ptr, "' is active");
    std.debug.panicImpl(buf[0 .. @intFromPtr(ptr) -% @intFromPtr(&buf)], null, ret_addr);
}
pub fn panicExactDivisionWithRemainder(
    comptime Number: type,
    lhs: Number,
    rhs: Number,
    ret_addr: usize,
) noreturn {
    @setCold(true);
    @setRuntimeSafety(false);
    if (builtin.zig_backend != .stage2_llvm and @bitSizeOf(Number) > 64) {
        return std.debug.panicImpl("exact division with remainder", null, ret_addr);
    }
    var buf: [256]u8 = undefined;
    buf[0..31].* = "exact division with remainder: ".*;
    var ptr: [*]u8 = fmt.formatIntDec(buf[31..], lhs);
    ptr[0] = '/';
    ptr = fmt.formatIntDec(ptr[1..][0..32], rhs);
    ptr[0..4].* = " == ".*;
    ptr = fmt.formatAny(ptr[4..][0..64], @divTrunc(lhs, rhs));
    ptr[0] = 'r';
    ptr = fmt.formatAny(ptr[1..][0..64], @rem(lhs, rhs));
    std.debug.panicImpl(buf[0 .. @intFromPtr(ptr) -% @intFromPtr(&buf)], null, ret_addr);
}
pub fn writeCastToFrom(
    buf: [*]u8,
    to_type_name: []const u8,
    from_type_name: []const u8,
) [*]u8 {
    @setRuntimeSafety(false);
    buf[0..9].* = "cast to '".*;
    const ptr: [*]u8 = mem.cpyEqu(buf + 9, to_type_name);
    ptr[0..8].* = "' from '".*;
    mem.cpyEqu(ptr + 8, from_type_name)[0] = '\'';
    return ptr + 9 + from_type_name.len;
}
pub fn writeAboveOrBelowLimit(
    buf: [*]u8,
    comptime To: type,
    to_type_name: []const u8,
    yn: bool,
    limit: To,
) [*]u8 {
    @setRuntimeSafety(false);
    buf[0..7].* = if (yn) " below ".* else " above ".*;
    var ptr: [*]u8 = mem.cpyEqu(buf + 7, to_type_name);
    ptr[0..10].* = if (yn) " minimum (".* else " maximum (".*;
    ptr = fmt.formatIntDec(ptr[10..][0..32], limit);
    ptr[0] = ')';
    return ptr + 1;
}
pub fn panicArithOverflow(comptime Number: type) type {
    const T = struct {
        const Absolute = @TypeOf(@abs(@as(Number, undefined)));
        const feature_limited: bool = builtin.zig_backend != .stage2_llvm and
            @bitSizeOf(Number) > @bitSizeOf(usize);
        pub fn add(
            type_name: []const u8,
            extrema: math.BestExtrema(Number),
            lhs: Number,
            rhs: Number,
            ret_addr: usize,
        ) noreturn {
            @setCold(true);
            @setRuntimeSafety(false);
            if (feature_limited) {
                return std.debug.panicImpl("add overflowed", null, ret_addr);
            }
            const yn: bool = rhs < 0;
            var buf: [256]u8 = undefined;
            var ptr: [*]u8 = writeOverflowed(&buf, "add overflowed ", type_name, " + ", lhs, rhs, &@addWithOverflow(lhs, rhs));
            ptr = writeAboveOrBelowLimit(ptr, Number, type_name, yn, if (yn) extrema.min else extrema.max);
            std.debug.panicImpl(buf[0 .. @intFromPtr(ptr) -% @intFromPtr(&buf)], null, ret_addr);
        }
        pub fn inc(
            type_name: []const u8,
            max: Number,
            lhs: Number,
            ret_addr: usize,
        ) noreturn {
            @setCold(true);
            @setRuntimeSafety(false);
            if (feature_limited) {
                return std.debug.panicImpl("add overflowed", null, ret_addr);
            }
            var buf: [256]u8 = undefined;
            var ptr: [*]u8 = writeOverflowed(&buf, "add overflowed ", type_name, " + ", lhs, 1, &@addWithOverflow(lhs, 1));
            ptr = writeAboveOrBelowLimit(ptr, Number, type_name, false, max);
            std.debug.panicImpl(buf[0 .. @intFromPtr(ptr) -% @intFromPtr(&buf)], null, ret_addr);
        }
        pub fn sub(
            type_name: []const u8,
            extrema: math.BestExtrema(Number),
            lhs: Number,
            rhs: Number,
            ret_addr: usize,
        ) noreturn {
            @setCold(true);
            @setRuntimeSafety(false);
            if (feature_limited) {
                return std.debug.panicImpl("sub overflowed", null, ret_addr);
            }
            const yn: bool = rhs > 0;
            var buf: [256]u8 = undefined;
            var ptr: [*]u8 = writeOverflowed(&buf, "sub overflowed ", type_name, " - ", lhs, rhs, &@subWithOverflow(lhs, rhs));
            ptr = writeAboveOrBelowLimit(ptr, Number, type_name, yn, if (yn) extrema.min else extrema.max);
            std.debug.panicImpl(buf[0 .. @intFromPtr(ptr) -% @intFromPtr(&buf)], null, ret_addr);
        }
        pub fn dec(
            type_name: []const u8,
            min: Number,
            lhs: Number,
            ret_addr: usize,
        ) noreturn {
            @setCold(true);
            @setRuntimeSafety(false);
            if (feature_limited) {
                return std.debug.panicImpl("sub overflowed", null, ret_addr);
            }
            var buf: [256]u8 = undefined;
            var ptr: [*]u8 = writeOverflowed(&buf, "sub overflowed ", type_name, " - ", lhs, 1, &@subWithOverflow(lhs, 1));
            ptr = writeAboveOrBelowLimit(ptr, Number, type_name, true, min);
            std.debug.panicImpl(buf[0 .. @intFromPtr(ptr) -% @intFromPtr(&buf)], null, ret_addr);
        }
        pub fn mul(
            type_name: []const u8,
            extrema: math.BestExtrema(Number),
            lhs: Number,
            rhs: Number,
            ret_addr: usize,
        ) noreturn {
            @setCold(true);
            @setRuntimeSafety(false);
            if (feature_limited) {
                return std.debug.panicImpl("mul overflowed", null, ret_addr);
            }
            var buf: [256]u8 = undefined;
            var ptr: [*]u8 = writeOverflowed(&buf, "mul overflowed ", type_name, " * ", lhs, rhs, &@mulWithOverflow(lhs, rhs));
            const yn: bool = @bitCast(
                (@intFromBool(rhs < 0) & @intFromBool(lhs > 0)) |
                    (@intFromBool(lhs < 0) & @intFromBool(rhs > 0)),
            );
            ptr = writeAboveOrBelowLimit(ptr, Number, type_name, yn, if (yn) extrema.min else extrema.max);
            std.debug.panicImpl(buf[0 .. @intFromPtr(ptr) -% @intFromPtr(&buf)], null, ret_addr);
        }
        pub fn div(
            type_name: []const u8,
            extrema: math.BestExtrema(Number),
            lhs: Number,
            rhs: Number,
            ret_addr: usize,
        ) noreturn {
            @setCold(true);
            @setRuntimeSafety(false);
            if (feature_limited) {
                return std.debug.panicImpl("div overflowed", null, ret_addr);
            }
            const yn: bool = rhs < 0;
            var buf: [256]u8 = undefined;
            var ptr: [*]u8 = writeOverflowed(&buf, "div overflowed ", type_name, " / ", lhs, rhs, &@addWithOverflow(lhs, rhs));
            ptr = writeAboveOrBelowLimit(ptr, Number, type_name, yn, if (yn) extrema.min else extrema.max);
            std.debug.panicImpl(buf[0 .. @intFromPtr(ptr) -% @intFromPtr(&buf)], null, ret_addr);
        }
        pub fn combined(
            pc: PanicId,
            type_name: []const u8,
            extrema: math.BestExtrema(Number),
            lhs: Number,
            rhs: Number,
            ret_addr: usize,
        ) noreturn {
            @setCold(true);
            @setRuntimeSafety(false);
            if (feature_limited) {
                std.debug.panicImpl(switch (pc) {
                    .add_overflowed => "add overflowed",
                    .sub_overflowed => "sub overflowed",
                    .div_overflowed => "div overflowed",
                    else => "mul overflowed",
                }, null, ret_addr);
            }
            const yn: bool = switch (pc) {
                .add_overflowed => rhs < 0,
                .sub_overflowed => rhs > 0,
                else => @bitCast(
                    (@intFromBool(rhs < 0) & @intFromBool(lhs > 0)) |
                        (@intFromBool(lhs < 0) & @intFromBool(rhs > 0)),
                ),
            };
            var buf: [256]u8 = undefined;
            var ptr: [*]u8 = writeOverflowed(&buf, switch (pc) {
                .add_overflowed => "add overflowed ",
                .sub_overflowed => "sub overflowed ",
                .div_overflowed => "div overflowed ",
                else => "mul overflowed ",
            }, type_name, switch (pc) {
                .add_overflowed => " + ",
                .sub_overflowed => " - ",
                else => " * ",
            }, lhs, rhs, &switch (pc) {
                .add_overflowed => @addWithOverflow(lhs, rhs),
                .sub_overflowed => @subWithOverflow(lhs, rhs),
                else => @mulWithOverflow(lhs, rhs),
            });
            ptr = writeAboveOrBelowLimit(ptr, Number, type_name, yn, if (yn) extrema.min else extrema.max);
            std.debug.panicImpl(buf[0 .. @intFromPtr(ptr) -% @intFromPtr(&buf)], null, ret_addr);
        }
        pub fn shl(
            type_name: []const u8,
            value: Number,
            shift_amt: u16,
            mask: Absolute,
            ret_addr: usize,
        ) noreturn {
            @setCold(true);
            @setRuntimeSafety(false);
            if (feature_limited) {
                return std.debug.panicImpl("shl overflowed", null, ret_addr);
            }
            const absolute: Absolute = @bitCast(value);
            const ov_bits: u16 = @popCount(absolute & mask) -% @popCount((absolute << @intCast(shift_amt)) & mask);
            var buf: [256]u8 = undefined;
            buf[0..22].* = "left shift overflowed ".*;
            var ptr: [*]u8 = mem.cpyEqu(buf[22..], type_name);
            ptr[0..2].* = ": ".*;
            ptr = fmt.formatIntDec(ptr[2..][0..32], value);
            ptr[0..4].* = " << ".*;
            ptr = fmt.formatIntDec(ptr[4..][0..32], shift_amt);
            ptr = writeShiftedOutBits(ptr, ov_bits);
            std.debug.panicImpl(buf[0 .. @intFromPtr(ptr) -% @intFromPtr(&buf)], null, ret_addr);
        }
        pub fn shr(
            type_name: []const u8,
            value: Number,
            shift_amt: u16,
            mask: Absolute,
            ret_addr: usize,
        ) noreturn {
            @setCold(true);
            @setRuntimeSafety(false);
            if (feature_limited) {
                return std.debug.panicImpl("shr overflowed", null, ret_addr);
            }
            const absolute: Absolute = @bitCast(value);
            const ov_bits: u16 = @popCount(absolute & mask) -% @popCount((absolute << @intCast(shift_amt)) & mask);
            var buf: [256]u8 = undefined;
            buf[0..23].* = "right shift overflowed ".*;
            var ptr: [*]u8 = mem.cpyEqu(buf[23..], type_name);
            ptr[0..2].* = ": ".*;
            ptr = fmt.formatIntDec(ptr[2..][0..32], value);
            ptr[0..4].* = " >> ".*;
            ptr = fmt.formatIntDec(ptr[4..][0..32], shift_amt);
            ptr = writeShiftedOutBits(ptr, ov_bits);
            std.debug.panicImpl(buf[0 .. @intFromPtr(ptr) -% @intFromPtr(&buf)], null, ret_addr);
        }
        pub fn shiftRhs(
            type_name: []const u8,
            bit_count: u16,
            shift_amt: u16,
            ret_addr: usize,
        ) noreturn {
            @setCold(true);
            @setRuntimeSafety(false);
            if (feature_limited) {
                return std.debug.panicImpl("shift RHS overflowed", null, ret_addr);
            }
            var buf: [256]u8 = undefined;
            var ptr: [*]u8 = mem.cpyEqu(&buf, type_name);
            ptr[0..23].* = " RHS of shift too big: ".*;
            ptr = fmt.formatIntDec(ptr[23..][0..32], shift_amt);
            ptr[0..3].* = " > ".*;
            ptr = fmt.formatIntDec(ptr[3..][0..32], bit_count);
            std.debug.panicImpl(buf[0 .. @intFromPtr(ptr) -% @intFromPtr(&buf)], null, ret_addr);
        }
        const Overflow = struct { Number, u1 };
        pub fn writeOverflowed(
            buf: [*]u8,
            op_name: *const [15]u8,
            type_name: []const u8,
            op_sym: *const [3]u8,
            lhs: Number,
            rhs: Number,
            res: *const Overflow,
        ) [*]u8 {
            @setCold(true);
            @setRuntimeSafety(false);
            buf[0..15].* = op_name.*;
            var ptr: [*]u8 = mem.cpyEqu(buf[15..], type_name);
            ptr[0..2].* = ": ".*;
            ptr = fmt.formatIntDec(ptr[2..][0..32], lhs);
            ptr[0..3].* = op_sym.*;
            ptr = fmt.formatIntDec(ptr[3..][0..32], rhs);
            if (res[1] == 0) {
                ptr[0..2].* = " (".*;
                ptr = fmt.formatIntDec(ptr[2..][0..32], res[0]);
                ptr[0] = ')';
                ptr += 1;
            }
            return ptr;
        }
        pub fn writeShiftedOutBits(
            buf: [*]u8,
            ov_bits: u16,
        ) [*]u8 {
            @setRuntimeSafety(false);
            buf[0..13].* = " shifted out ".*;
            var ptr: [*]u8 = fmt.formatIntDec(buf[13..][0..32], ov_bits);
            ptr[0..5].* = " bits".*;
            return ptr + 4 + @intFromBool(ov_bits != 1);
        }
    };
    return T;
}

/// ATTENTION: Standard library users/contributors could help with consolidating
///            these namespaces. These are used to extract the generic parts of
///            panic data payloads in order to call the most efficient writer
///            function without sacrificing any information.
///
///            The general idea is that integers and floats larger than `*size`
///            are rare enough to afford specific writer functions. Integers and
///            floats not larger than `*size` are able to use a common function.
///            For these, we just extract the type name and the extrema and
///            allow the values to coerce.
const mem = struct {
    fn cpyEqu(ptr: [*]u8, str: []const u8) [*]u8 {
        @memcpy(ptr, str);
        return ptr + str.len;
    }
};
const meta = struct {
    pub fn BestFloat(comptime Float: type) type {
        if (@bitSizeOf(Float) <= @bitSizeOf(usize)) {
            return @Type(.{ .Float = .{ .bits = @bitSizeOf(usize) } });
        }
        return Float;
    }
    pub fn BestInt(comptime T: type) type {
        switch (@typeInfo(T)) {
            .Vector => |vector_info| {
                return @Vector(vector_info.len, BestInt(vector_info.child));
            },
            .Int => if (@bitSizeOf(T) <= @bitSizeOf(usize)) {
                if (@typeInfo(T).Int.signedness == .signed) {
                    return isize;
                } else {
                    return usize;
                }
            } else {
                return @Type(.{ .Int = .{
                    .bits = @bitSizeOf(T),
                    .signedness = switch (@typeInfo(T)) {
                        .Int => |int_info| int_info.signedness,
                        else => .unsigned,
                    },
                } });
            },
            else => {
                return BestInt(meta.Child(T));
            },
        }
    }
    pub fn BestNum(comptime Number: type) type {
        switch (@typeInfo(Number)) {
            .ComptimeInt, .Int => return BestInt(Number),
            .ComptimeFloat, .Float => return BestFloat(Number),
            else => return Number,
        }
    }
    /// Extracts types like:
    /// Int                     => Int,
    /// Enum(Int)               => Int,
    /// Struct(Int)             => Int,
    /// Union(Enum(Int))        => Int,
    /// Optional(Pointer(Any))  => Any,
    /// Optional(Any)           => Any,
    /// Array(Any)              => Any,
    /// Pointer(Array(Any))     => Any,
    /// Pointer(Any)            => Any,
    pub fn Child(comptime T: type) type {
        switch (@typeInfo(T)) {
            else => {
                @compileError(@typeName(T));
            },
            .Array, .Pointer => {
                return Element(T);
            },
            .Int, .Float => {
                return T;
            },
            .Enum => |enum_info| {
                return enum_info.tag_type;
            },
            .ErrorSet => {
                return u16;
            },
            .Struct => |struct_info| {
                if (struct_info.backing_integer) |backing_integer| {
                    return backing_integer;
                } else {
                    @compileError("'" ++ @typeName(T) ++ "' not a packed struct");
                }
            },
            .Union => |union_info| {
                if (union_info.tag_type) |tag_type| {
                    return Child(tag_type);
                } else {
                    @compileError("'" ++ @typeName(T) ++ "' not a tagged union");
                }
            },
            .Optional => |optional_info| {
                return optional_info.child;
            },
        }
    }
    pub fn Element(comptime T: type) type {
        switch (@typeInfo(T)) {
            else => {
                @compileError(@typeName(T));
            },
            .Array => |array_info| {
                return array_info.child;
            },
            .Pointer => |pointer_info| {
                if (pointer_info.size == .Slice or pointer_info.size == .Many) {
                    return pointer_info.child;
                }
                switch (@typeInfo(pointer_info.child)) {
                    .Array => |array_info| {
                        return array_info.child;
                    },
                    else => {
                        @compileError(@typeName(T));
                    },
                }
            },
        }
    }
};
const math = struct {
    pub fn BestExtrema(comptime Int: type) type {
        if (meta.BestInt(Int) != Int) {
            return BestExtrema(meta.BestInt(Int));
        }
        return struct {
            min: Int,
            max: Int,
        };
    }
    /// Find the maximum and minimum arithmetical values for an integer type.
    pub fn bestExtrema(comptime Int: type) BestExtrema(Int) {
        if (@typeInfo(Int) == .Vector) {
            return .{
                .min = @splat(bestExtrema(@typeInfo(Int).Vector.child).min),
                .max = @splat(bestExtrema(@typeInfo(Int).Vector.child).max),
            };
        }
        switch (Int) {
            u0, i0 => return .{ .min = 0, .max = 0 },
            u1 => return .{ .min = 0, .max = 1 },
            i1 => return .{ .min = -1, .max = 0 },
            else => {
                const U = @Type(.{ .Int = .{
                    .signedness = .unsigned,
                    .bits = @bitSizeOf(Int),
                } });
                const umax: U = ~@as(U, 0);
                if (@typeInfo(Int).Int.signedness == .unsigned) {
                    return .{ .min = 0, .max = umax };
                } else {
                    const imax: U = umax >> 1;
                    return .{
                        .min = @as(Int, @bitCast(~imax)),
                        .max = @as(Int, @bitCast(imax)),
                    };
                }
            },
        }
    }
};
const fmt = struct {
    fn formatAny(buf: []u8, value: anytype) [*]u8 {
        var fbs = std.io.fixedBufferStream(buf);
        std.fmt.format(fbs.writer(), "{any}", .{value}) catch return buf.ptr;
        return buf.ptr + fbs.pos;
    }
    fn formatIntDec(buf: []u8, value: anytype) [*]u8 {
        var fbs = std.io.fixedBufferStream(buf);
        std.fmt.formatInt(value, 10, .lower, .{}, fbs.writer()) catch return buf.ptr;
        return buf.ptr + fbs.pos;
    }
    fn formatIntHex(buf: []u8, value: anytype) [*]u8 {
        var fbs = std.io.fixedBufferStream(buf);
        std.fmt.formatInt(value, 16, .lower, .{}, fbs.writer()) catch return buf.ptr;
        return buf.ptr + fbs.pos;
    }
    fn formatFloatDec(buf: []u8, value: anytype) [*]u8 {
        var fbs = std.io.fixedBufferStream(buf[0..32]);
        std.fmt.formatFloatDecimal(value, .{}, fbs.writer()) catch return buf.ptr;
        return buf.ptr + fbs.pos;
    }
};

pub fn isNamedEnumValue(comptime Enum: type, enum_or_int: anytype) bool {
    @setRuntimeSafety(false);
    if (@typeInfo(@TypeOf(enum_or_int)) == .Int) {
        inline for (@typeInfo(Enum).Enum.fields) |field| {
            if (field.value == enum_or_int) {
                return true;
            }
        }
        return false;
    }
    inline for (@typeInfo(Enum).Enum.fields) |field| {
        if (field.value == @intFromEnum(enum_or_int)) {
            return true;
        }
    }
    return false;
}
pub fn errorSetHasValue(comptime Error: type, error_or_int: anytype) bool {
    @setRuntimeSafety(false);
    if (@typeInfo(@TypeOf(error_or_int)) == .Int) {
        if (@typeInfo(Error).ErrorSet) |error_set| {
            inline for (error_set) |elem| {
                if (@intFromError(@field(Error, elem.name)) == error_or_int) {
                    return true;
                }
            }
        }
        return false;
    }
    if (@typeInfo(Error).ErrorSet) |error_set| {
        inline for (error_set) |elem| {
            if (@intFromError(@field(Error, elem.name)) == @intFromError(error_or_int)) {
                return true;
            }
        }
    }
    return false;
}

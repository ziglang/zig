const std = @import("std");
const Allocator = mem.Allocator;
const assert = std.debug.assert;
const EpochSeconds = std.time.epoch.EpochSeconds;
const mem = std.mem;
const Interner = @import("../backend.zig").Interner;
const Builtins = @import("Builtins.zig");
const Builtin = Builtins.Builtin;
const Diagnostics = @import("Diagnostics.zig");
const LangOpts = @import("LangOpts.zig");
const Source = @import("Source.zig");
const Tokenizer = @import("Tokenizer.zig");
const Token = Tokenizer.Token;
const Type = @import("Type.zig");
const Pragma = @import("Pragma.zig");
const StrInt = @import("StringInterner.zig");
const record_layout = @import("record_layout.zig");
const target_util = @import("target.zig");

pub const Error = error{
    /// A fatal error has ocurred and compilation has stopped.
    FatalError,
} || Allocator.Error;

pub const bit_int_max_bits = std.math.maxInt(u16);
const path_buf_stack_limit = 1024;

/// Environment variables used during compilation / linking.
pub const Environment = struct {
    /// Directory to use for temporary files
    /// TODO: not implemented yet
    tmpdir: ?[]const u8 = null,

    /// PATH environment variable used to search for programs
    path: ?[]const u8 = null,

    /// Directories to try when searching for subprograms.
    /// TODO: not implemented yet
    compiler_path: ?[]const u8 = null,

    /// Directories to try when searching for special linker files, if compiling for the native target
    /// TODO: not implemented yet
    library_path: ?[]const u8 = null,

    /// List of directories to be searched as if specified with -I, but after any paths given with -I options on the command line
    /// Used regardless of the language being compiled
    /// TODO: not implemented yet
    cpath: ?[]const u8 = null,

    /// List of directories to be searched as if specified with -I, but after any paths given with -I options on the command line
    /// Used if the language being compiled is C
    /// TODO: not implemented yet
    c_include_path: ?[]const u8 = null,

    /// UNIX timestamp to be used instead of the current date and time in the __DATE__ and __TIME__ macros
    source_date_epoch: ?[]const u8 = null,

    /// Load all of the environment variables using the std.process API. Do not use if using Aro as a shared library on Linux without libc
    /// See https://github.com/ziglang/zig/issues/4524
    pub fn loadAll(allocator: std.mem.Allocator) !Environment {
        var env: Environment = .{};
        errdefer env.deinit(allocator);

        inline for (@typeInfo(@TypeOf(env)).@"struct".fields) |field| {
            std.debug.assert(@field(env, field.name) == null);

            var env_var_buf: [field.name.len]u8 = undefined;
            const env_var_name = std.ascii.upperString(&env_var_buf, field.name);
            const val: ?[]const u8 = std.process.getEnvVarOwned(allocator, env_var_name) catch |err| switch (err) {
                error.OutOfMemory => |e| return e,
                error.EnvironmentVariableNotFound => null,
                error.InvalidWtf8 => null,
            };
            @field(env, field.name) = val;
        }
        return env;
    }

    /// Use this only if environment slices were allocated with `allocator` (such as via `loadAll`)
    pub fn deinit(self: *Environment, allocator: std.mem.Allocator) void {
        inline for (@typeInfo(@TypeOf(self.*)).@"struct".fields) |field| {
            if (@field(self, field.name)) |slice| {
                allocator.free(slice);
            }
        }
        self.* = undefined;
    }
};

const Compilation = @This();

gpa: Allocator,
diagnostics: Diagnostics,

environment: Environment = .{},
sources: std.StringArrayHashMapUnmanaged(Source) = .empty,
include_dirs: std.ArrayListUnmanaged([]const u8) = .empty,
system_include_dirs: std.ArrayListUnmanaged([]const u8) = .empty,
target: std.Target = @import("builtin").target,
pragma_handlers: std.StringArrayHashMapUnmanaged(*Pragma) = .empty,
langopts: LangOpts = .{},
generated_buf: std.ArrayListUnmanaged(u8) = .empty,
builtins: Builtins = .{},
types: struct {
    wchar: Type = undefined,
    uint_least16_t: Type = undefined,
    uint_least32_t: Type = undefined,
    ptrdiff: Type = undefined,
    size: Type = undefined,
    va_list: Type = undefined,
    pid_t: Type = undefined,
    ns_constant_string: struct {
        ty: Type = undefined,
        record: Type.Record = undefined,
        fields: [4]Type.Record.Field = undefined,
        int_ty: Type = .{ .specifier = .int, .qual = .{ .@"const" = true } },
        char_ty: Type = .{ .specifier = .char, .qual = .{ .@"const" = true } },
    } = .{},
    file: Type = .{ .specifier = .invalid },
    jmp_buf: Type = .{ .specifier = .invalid },
    sigjmp_buf: Type = .{ .specifier = .invalid },
    ucontext_t: Type = .{ .specifier = .invalid },
    intmax: Type = .{ .specifier = .invalid },
    intptr: Type = .{ .specifier = .invalid },
    int16: Type = .{ .specifier = .invalid },
    int64: Type = .{ .specifier = .invalid },
} = .{},
string_interner: StrInt = .{},
interner: Interner = .{},
/// If this is not null, the directory containing the specified Source will be searched for includes
/// Used by MS extensions which allow searching for includes relative to the directory of the main source file.
ms_cwd_source_id: ?Source.Id = null,
cwd: std.fs.Dir,

pub fn init(gpa: Allocator, cwd: std.fs.Dir) Compilation {
    return .{
        .gpa = gpa,
        .diagnostics = Diagnostics.init(gpa),
        .cwd = cwd,
    };
}

/// Initialize Compilation with default environment,
/// pragma handlers and emulation mode set to target.
pub fn initDefault(gpa: Allocator, cwd: std.fs.Dir) !Compilation {
    var comp: Compilation = .{
        .gpa = gpa,
        .environment = try Environment.loadAll(gpa),
        .diagnostics = Diagnostics.init(gpa),
        .cwd = cwd,
    };
    errdefer comp.deinit();
    try comp.addDefaultPragmaHandlers();
    comp.langopts.setEmulatedCompiler(target_util.systemCompiler(comp.target));
    return comp;
}

pub fn deinit(comp: *Compilation) void {
    for (comp.pragma_handlers.values()) |pragma| {
        pragma.deinit(pragma, comp);
    }
    for (comp.sources.values()) |source| {
        comp.gpa.free(source.path);
        comp.gpa.free(source.buf);
        comp.gpa.free(source.splice_locs);
    }
    comp.sources.deinit(comp.gpa);
    comp.diagnostics.deinit();
    comp.include_dirs.deinit(comp.gpa);
    for (comp.system_include_dirs.items) |path| comp.gpa.free(path);
    comp.system_include_dirs.deinit(comp.gpa);
    comp.pragma_handlers.deinit(comp.gpa);
    comp.generated_buf.deinit(comp.gpa);
    comp.builtins.deinit(comp.gpa);
    comp.string_interner.deinit(comp.gpa);
    comp.interner.deinit(comp.gpa);
    comp.environment.deinit(comp.gpa);
}

pub fn getSourceEpoch(self: *const Compilation, max: i64) !?i64 {
    const provided = self.environment.source_date_epoch orelse return null;
    const parsed = std.fmt.parseInt(i64, provided, 10) catch return error.InvalidEpoch;
    if (parsed < 0 or parsed > max) return error.InvalidEpoch;
    return parsed;
}

/// Dec 31 9999 23:59:59
const max_timestamp = 253402300799;

fn getTimestamp(comp: *Compilation) !u47 {
    const provided: ?i64 = comp.getSourceEpoch(max_timestamp) catch blk: {
        try comp.addDiagnostic(.{
            .tag = .invalid_source_epoch,
            .loc = .{ .id = .unused, .byte_offset = 0, .line = 0 },
        }, &.{});
        break :blk null;
    };
    const timestamp = provided orelse std.time.timestamp();
    return @intCast(std.math.clamp(timestamp, 0, max_timestamp));
}

fn generateDateAndTime(w: anytype, timestamp: u47) !void {
    const epoch_seconds = EpochSeconds{ .secs = timestamp };
    const epoch_day = epoch_seconds.getEpochDay();
    const day_seconds = epoch_seconds.getDaySeconds();
    const year_day = epoch_day.calculateYearDay();
    const month_day = year_day.calculateMonthDay();

    const month_names = [_][]const u8{ "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" };
    std.debug.assert(std.time.epoch.Month.jan.numeric() == 1);

    const month_name = month_names[month_day.month.numeric() - 1];
    try w.print("#define __DATE__ \"{s} {d: >2} {d}\"\n", .{
        month_name,
        month_day.day_index + 1,
        year_day.year,
    });
    try w.print("#define __TIME__ \"{d:0>2}:{d:0>2}:{d:0>2}\"\n", .{
        day_seconds.getHoursIntoDay(),
        day_seconds.getMinutesIntoHour(),
        day_seconds.getSecondsIntoMinute(),
    });

    const day_names = [_][]const u8{ "Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun" };
    const day_name = day_names[@intCast((epoch_day.day + 3) % 7)];
    try w.print("#define __TIMESTAMP__ \"{s} {s} {d: >2} {d:0>2}:{d:0>2}:{d:0>2} {d}\"\n", .{
        day_name,
        month_name,
        month_day.day_index + 1,
        day_seconds.getHoursIntoDay(),
        day_seconds.getMinutesIntoHour(),
        day_seconds.getSecondsIntoMinute(),
        year_day.year,
    });
}

/// Which set of system defines to generate via generateBuiltinMacros
pub const SystemDefinesMode = enum {
    /// Only define macros required by the C standard (date/time macros and those beginning with `__STDC`)
    no_system_defines,
    /// Define the standard set of system macros
    include_system_defines,
};

fn generateSystemDefines(comp: *Compilation, w: anytype) !void {
    const ptr_width = comp.target.ptrBitWidth();

    if (comp.langopts.gnuc_version > 0) {
        try w.print("#define __GNUC__ {d}\n", .{comp.langopts.gnuc_version / 10_000});
        try w.print("#define __GNUC_MINOR__ {d}\n", .{comp.langopts.gnuc_version / 100 % 100});
        try w.print("#define __GNUC_PATCHLEVEL__ {d}\n", .{comp.langopts.gnuc_version % 100});
    }

    // os macros
    switch (comp.target.os.tag) {
        .linux => try w.writeAll(
            \\#define linux 1
            \\#define __linux 1
            \\#define __linux__ 1
            \\
        ),
        .windows => if (ptr_width == 32) try w.writeAll(
            \\#define WIN32 1
            \\#define _WIN32 1
            \\#define __WIN32 1
            \\#define __WIN32__ 1
            \\
        ) else try w.writeAll(
            \\#define WIN32 1
            \\#define WIN64 1
            \\#define _WIN32 1
            \\#define _WIN64 1
            \\#define __WIN32 1
            \\#define __WIN64 1
            \\#define __WIN32__ 1
            \\#define __WIN64__ 1
            \\
        ),
        .freebsd => try w.print("#define __FreeBSD__ {d}\n", .{comp.target.os.version_range.semver.min.major}),
        .netbsd => try w.writeAll("#define __NetBSD__ 1\n"),
        .openbsd => try w.writeAll("#define __OpenBSD__ 1\n"),
        .dragonfly => try w.writeAll("#define __DragonFly__ 1\n"),
        .solaris => try w.writeAll(
            \\#define sun 1
            \\#define __sun 1
            \\
        ),
        .macos => try w.writeAll(
            \\#define __APPLE__ 1
            \\#define __MACH__ 1
            \\
        ),
        else => {},
    }

    // unix and other additional os macros
    switch (comp.target.os.tag) {
        .freebsd,
        .netbsd,
        .openbsd,
        .dragonfly,
        .linux,
        => try w.writeAll(
            \\#define unix 1
            \\#define __unix 1
            \\#define __unix__ 1
            \\
        ),
        else => {},
    }
    if (comp.target.isAndroid()) {
        try w.writeAll("#define __ANDROID__ 1\n");
    }

    // architecture macros
    switch (comp.target.cpu.arch) {
        .x86_64 => try w.writeAll(
            \\#define __amd64__ 1
            \\#define __amd64 1
            \\#define __x86_64 1
            \\#define __x86_64__ 1
            \\
        ),
        .x86 => try w.writeAll(
            \\#define i386 1
            \\#define __i386 1
            \\#define __i386__ 1
            \\
        ),
        .mips,
        .mipsel,
        .mips64,
        .mips64el,
        => try w.writeAll(
            \\#define __mips__ 1
            \\#define mips 1
            \\
        ),
        .powerpc,
        .powerpcle,
        => try w.writeAll(
            \\#define __powerpc__ 1
            \\#define __POWERPC__ 1
            \\#define __ppc__ 1
            \\#define __PPC__ 1
            \\#define _ARCH_PPC 1
            \\
        ),
        .powerpc64,
        .powerpc64le,
        => try w.writeAll(
            \\#define __powerpc 1
            \\#define __powerpc__ 1
            \\#define __powerpc64__ 1
            \\#define __POWERPC__ 1
            \\#define __ppc__ 1
            \\#define __ppc64__ 1
            \\#define __PPC__ 1
            \\#define __PPC64__ 1
            \\#define _ARCH_PPC 1
            \\#define _ARCH_PPC64 1
            \\
        ),
        .sparc64 => try w.writeAll(
            \\#define __sparc__ 1
            \\#define __sparc 1
            \\#define __sparc_v9__ 1
            \\
        ),
        .sparc => try w.writeAll(
            \\#define __sparc__ 1
            \\#define __sparc 1
            \\
        ),
        .arm, .armeb => try w.writeAll(
            \\#define __arm__ 1
            \\#define __arm 1
            \\
        ),
        .thumb, .thumbeb => try w.writeAll(
            \\#define __arm__ 1
            \\#define __arm 1
            \\#define __thumb__ 1
            \\
        ),
        .aarch64, .aarch64_be => try w.writeAll("#define __aarch64__ 1\n"),
        .msp430 => try w.writeAll(
            \\#define MSP430 1
            \\#define __MSP430__ 1
            \\
        ),
        else => {},
    }

    if (comp.target.os.tag != .windows) switch (ptr_width) {
        64 => try w.writeAll(
            \\#define _LP64 1
            \\#define __LP64__ 1
            \\
        ),
        32 => try w.writeAll("#define _ILP32 1\n"),
        else => {},
    };

    try w.writeAll(
        \\#define __ORDER_LITTLE_ENDIAN__ 1234
        \\#define __ORDER_BIG_ENDIAN__ 4321
        \\#define __ORDER_PDP_ENDIAN__ 3412
        \\
    );
    if (comp.target.cpu.arch.endian() == .little) try w.writeAll(
        \\#define __BYTE_ORDER__ __ORDER_LITTLE_ENDIAN__
        \\#define __LITTLE_ENDIAN__ 1
        \\
    ) else try w.writeAll(
        \\#define __BYTE_ORDER__ __ORDER_BIG_ENDIAN__
        \\#define __BIG_ENDIAN__ 1
        \\
    );

    // atomics
    try w.writeAll(
        \\#define __ATOMIC_RELAXED 0
        \\#define __ATOMIC_CONSUME 1
        \\#define __ATOMIC_ACQUIRE 2
        \\#define __ATOMIC_RELEASE 3
        \\#define __ATOMIC_ACQ_REL 4
        \\#define __ATOMIC_SEQ_CST 5
        \\
    );

    // TODO: Set these to target-specific constants depending on backend capabilities
    // For now they are just set to the "may be lock-free" value
    try w.writeAll(
        \\#define __ATOMIC_BOOL_LOCK_FREE 1
        \\#define __ATOMIC_CHAR_LOCK_FREE 1
        \\#define __ATOMIC_CHAR16_T_LOCK_FREE 1
        \\#define __ATOMIC_CHAR32_T_LOCK_FREE 1
        \\#define __ATOMIC_WCHAR_T_LOCK_FREE 1
        \\#define __ATOMIC_SHORT_LOCK_FREE 1
        \\#define __ATOMIC_INT_LOCK_FREE 1
        \\#define __ATOMIC_LONG_LOCK_FREE 1
        \\#define __ATOMIC_LLONG_LOCK_FREE 1
        \\#define __ATOMIC_POINTER_LOCK_FREE 1
        \\
    );
    if (comp.langopts.hasChar8_T()) {
        try w.writeAll("#define __ATOMIC_CHAR8_T_LOCK_FREE 1\n");
    }

    // types
    if (comp.getCharSignedness() == .unsigned) try w.writeAll("#define __CHAR_UNSIGNED__ 1\n");
    try w.writeAll("#define __CHAR_BIT__ 8\n");

    // int maxs
    try comp.generateIntWidth(w, "BOOL", .{ .specifier = .bool });
    try comp.generateIntMaxAndWidth(w, "SCHAR", .{ .specifier = .schar });
    try comp.generateIntMaxAndWidth(w, "SHRT", .{ .specifier = .short });
    try comp.generateIntMaxAndWidth(w, "INT", .{ .specifier = .int });
    try comp.generateIntMaxAndWidth(w, "LONG", .{ .specifier = .long });
    try comp.generateIntMaxAndWidth(w, "LONG_LONG", .{ .specifier = .long_long });
    try comp.generateIntMaxAndWidth(w, "WCHAR", comp.types.wchar);
    // try comp.generateIntMax(w, "WINT", comp.types.wchar);
    try comp.generateIntMaxAndWidth(w, "INTMAX", comp.types.intmax);
    try comp.generateIntMaxAndWidth(w, "SIZE", comp.types.size);
    try comp.generateIntMaxAndWidth(w, "UINTMAX", comp.types.intmax.makeIntegerUnsigned());
    try comp.generateIntMaxAndWidth(w, "PTRDIFF", comp.types.ptrdiff);
    try comp.generateIntMaxAndWidth(w, "INTPTR", comp.types.intptr);
    try comp.generateIntMaxAndWidth(w, "UINTPTR", comp.types.intptr.makeIntegerUnsigned());
    try comp.generateIntMaxAndWidth(w, "SIG_ATOMIC", target_util.sigAtomicType(comp.target));

    // int widths
    try w.print("#define __BITINT_MAXWIDTH__ {d}\n", .{bit_int_max_bits});

    // sizeof types
    try comp.generateSizeofType(w, "__SIZEOF_FLOAT__", .{ .specifier = .float });
    try comp.generateSizeofType(w, "__SIZEOF_DOUBLE__", .{ .specifier = .double });
    try comp.generateSizeofType(w, "__SIZEOF_LONG_DOUBLE__", .{ .specifier = .long_double });
    try comp.generateSizeofType(w, "__SIZEOF_SHORT__", .{ .specifier = .short });
    try comp.generateSizeofType(w, "__SIZEOF_INT__", .{ .specifier = .int });
    try comp.generateSizeofType(w, "__SIZEOF_LONG__", .{ .specifier = .long });
    try comp.generateSizeofType(w, "__SIZEOF_LONG_LONG__", .{ .specifier = .long_long });
    try comp.generateSizeofType(w, "__SIZEOF_POINTER__", .{ .specifier = .pointer });
    try comp.generateSizeofType(w, "__SIZEOF_PTRDIFF_T__", comp.types.ptrdiff);
    try comp.generateSizeofType(w, "__SIZEOF_SIZE_T__", comp.types.size);
    try comp.generateSizeofType(w, "__SIZEOF_WCHAR_T__", comp.types.wchar);
    // try comp.generateSizeofType(w, "__SIZEOF_WINT_T__", .{ .specifier = .pointer });

    if (target_util.hasInt128(comp.target)) {
        try comp.generateSizeofType(w, "__SIZEOF_INT128__", .{ .specifier = .int128 });
    }

    // various int types
    const mapper = comp.string_interner.getSlowTypeMapper();
    try generateTypeMacro(w, mapper, "__INTPTR_TYPE__", comp.types.intptr, comp.langopts);
    try generateTypeMacro(w, mapper, "__UINTPTR_TYPE__", comp.types.intptr.makeIntegerUnsigned(), comp.langopts);

    try generateTypeMacro(w, mapper, "__INTMAX_TYPE__", comp.types.intmax, comp.langopts);
    try comp.generateSuffixMacro("__INTMAX", w, comp.types.intptr);

    try generateTypeMacro(w, mapper, "__UINTMAX_TYPE__", comp.types.intmax.makeIntegerUnsigned(), comp.langopts);
    try comp.generateSuffixMacro("__UINTMAX", w, comp.types.intptr.makeIntegerUnsigned());

    try generateTypeMacro(w, mapper, "__PTRDIFF_TYPE__", comp.types.ptrdiff, comp.langopts);
    try generateTypeMacro(w, mapper, "__SIZE_TYPE__", comp.types.size, comp.langopts);
    try generateTypeMacro(w, mapper, "__WCHAR_TYPE__", comp.types.wchar, comp.langopts);
    try generateTypeMacro(w, mapper, "__CHAR16_TYPE__", comp.types.uint_least16_t, comp.langopts);
    try generateTypeMacro(w, mapper, "__CHAR32_TYPE__", comp.types.uint_least32_t, comp.langopts);

    try comp.generateExactWidthTypes(w, mapper);
    try comp.generateFastAndLeastWidthTypes(w, mapper);

    if (target_util.FPSemantics.halfPrecisionType(comp.target)) |half| {
        try generateFloatMacros(w, "FLT16", half, "F16");
    }
    try generateFloatMacros(w, "FLT", target_util.FPSemantics.forType(.float, comp.target), "F");
    try generateFloatMacros(w, "DBL", target_util.FPSemantics.forType(.double, comp.target), "");
    try generateFloatMacros(w, "LDBL", target_util.FPSemantics.forType(.longdouble, comp.target), "L");

    // TODO: clang treats __FLT_EVAL_METHOD__ as a special-cased macro because evaluating it within a scope
    // where `#pragma clang fp eval_method(X)` has been called produces an error diagnostic.
    const flt_eval_method = comp.langopts.fp_eval_method orelse target_util.defaultFpEvalMethod(comp.target);
    try w.print("#define __FLT_EVAL_METHOD__ {d}\n", .{@intFromEnum(flt_eval_method)});

    try w.writeAll(
        \\#define __FLT_RADIX__ 2
        \\#define __DECIMAL_DIG__ __LDBL_DECIMAL_DIG__
        \\
    );
}

/// Generate builtin macros that will be available to each source file.
pub fn generateBuiltinMacros(comp: *Compilation, system_defines_mode: SystemDefinesMode) !Source {
    try comp.generateBuiltinTypes();

    var buf = std.ArrayList(u8).init(comp.gpa);
    defer buf.deinit();

    if (system_defines_mode == .include_system_defines) {
        try buf.appendSlice(
            \\#define __VERSION__ "Aro
        ++ " " ++ @import("../backend.zig").version_str ++ "\"\n" ++
            \\#define __Aro__
            \\
        );
    }

    try buf.appendSlice("#define __STDC__ 1\n");
    try buf.writer().print("#define __STDC_HOSTED__ {d}\n", .{@intFromBool(comp.target.os.tag != .freestanding)});

    // standard macros
    try buf.appendSlice(
        \\#define __STDC_NO_COMPLEX__ 1
        \\#define __STDC_NO_THREADS__ 1
        \\#define __STDC_NO_VLA__ 1
        \\#define __STDC_UTF_16__ 1
        \\#define __STDC_UTF_32__ 1
        \\#define __STDC_EMBED_NOT_FOUND__ 0
        \\#define __STDC_EMBED_FOUND__ 1
        \\#define __STDC_EMBED_EMPTY__ 2
        \\
    );
    if (comp.langopts.standard.StdCVersionMacro()) |stdc_version| {
        try buf.appendSlice("#define __STDC_VERSION__ ");
        try buf.appendSlice(stdc_version);
        try buf.append('\n');
    }

    // timestamps
    const timestamp = try comp.getTimestamp();
    try generateDateAndTime(buf.writer(), timestamp);

    if (system_defines_mode == .include_system_defines) {
        try comp.generateSystemDefines(buf.writer());
    }

    return comp.addSourceFromBuffer("<builtin>", buf.items);
}

fn generateFloatMacros(w: anytype, prefix: []const u8, semantics: target_util.FPSemantics, ext: []const u8) !void {
    const denormMin = semantics.chooseValue(
        []const u8,
        .{
            "5.9604644775390625e-8",
            "1.40129846e-45",
            "4.9406564584124654e-324",
            "3.64519953188247460253e-4951",
            "4.94065645841246544176568792868221e-324",
            "6.47517511943802511092443895822764655e-4966",
        },
    );
    const digits = semantics.chooseValue(i32, .{ 3, 6, 15, 18, 31, 33 });
    const decimalDigits = semantics.chooseValue(i32, .{ 5, 9, 17, 21, 33, 36 });
    const epsilon = semantics.chooseValue(
        []const u8,
        .{
            "9.765625e-4",
            "1.19209290e-7",
            "2.2204460492503131e-16",
            "1.08420217248550443401e-19",
            "4.94065645841246544176568792868221e-324",
            "1.92592994438723585305597794258492732e-34",
        },
    );
    const mantissaDigits = semantics.chooseValue(i32, .{ 11, 24, 53, 64, 106, 113 });

    const min10Exp = semantics.chooseValue(i32, .{ -4, -37, -307, -4931, -291, -4931 });
    const max10Exp = semantics.chooseValue(i32, .{ 4, 38, 308, 4932, 308, 4932 });

    const minExp = semantics.chooseValue(i32, .{ -13, -125, -1021, -16381, -968, -16381 });
    const maxExp = semantics.chooseValue(i32, .{ 16, 128, 1024, 16384, 1024, 16384 });

    const min = semantics.chooseValue(
        []const u8,
        .{
            "6.103515625e-5",
            "1.17549435e-38",
            "2.2250738585072014e-308",
            "3.36210314311209350626e-4932",
            "2.00416836000897277799610805135016e-292",
            "3.36210314311209350626267781732175260e-4932",
        },
    );
    const max = semantics.chooseValue(
        []const u8,
        .{
            "6.5504e+4",
            "3.40282347e+38",
            "1.7976931348623157e+308",
            "1.18973149535723176502e+4932",
            "1.79769313486231580793728971405301e+308",
            "1.18973149535723176508575932662800702e+4932",
        },
    );

    var def_prefix_buf: [32]u8 = undefined;
    const prefix_slice = std.fmt.bufPrint(&def_prefix_buf, "__{s}_", .{prefix}) catch
        return error.OutOfMemory;

    try w.print("#define {s}DENORM_MIN__ {s}{s}\n", .{ prefix_slice, denormMin, ext });
    try w.print("#define {s}HAS_DENORM__\n", .{prefix_slice});
    try w.print("#define {s}DIG__ {d}\n", .{ prefix_slice, digits });
    try w.print("#define {s}DECIMAL_DIG__ {d}\n", .{ prefix_slice, decimalDigits });

    try w.print("#define {s}EPSILON__ {s}{s}\n", .{ prefix_slice, epsilon, ext });
    try w.print("#define {s}HAS_INFINITY__\n", .{prefix_slice});
    try w.print("#define {s}HAS_QUIET_NAN__\n", .{prefix_slice});
    try w.print("#define {s}MANT_DIG__ {d}\n", .{ prefix_slice, mantissaDigits });

    try w.print("#define {s}MAX_10_EXP__ {d}\n", .{ prefix_slice, max10Exp });
    try w.print("#define {s}MAX_EXP__ {d}\n", .{ prefix_slice, maxExp });
    try w.print("#define {s}MAX__ {s}{s}\n", .{ prefix_slice, max, ext });

    try w.print("#define {s}MIN_10_EXP__ ({d})\n", .{ prefix_slice, min10Exp });
    try w.print("#define {s}MIN_EXP__ ({d})\n", .{ prefix_slice, minExp });
    try w.print("#define {s}MIN__ {s}{s}\n", .{ prefix_slice, min, ext });
}

fn generateTypeMacro(w: anytype, mapper: StrInt.TypeMapper, name: []const u8, ty: Type, langopts: LangOpts) !void {
    try w.print("#define {s} ", .{name});
    try ty.print(mapper, langopts, w);
    try w.writeByte('\n');
}

fn generateBuiltinTypes(comp: *Compilation) !void {
    const os = comp.target.os.tag;
    const wchar: Type = switch (comp.target.cpu.arch) {
        .xcore => .{ .specifier = .uchar },
        .ve, .msp430 => .{ .specifier = .uint },
        .arm, .armeb, .thumb, .thumbeb => .{
            .specifier = if (os != .windows and os != .netbsd and os != .openbsd) .uint else .int,
        },
        .aarch64, .aarch64_be => .{
            .specifier = if (!os.isDarwin() and os != .netbsd) .uint else .int,
        },
        .x86_64, .x86 => .{ .specifier = if (os == .windows) .ushort else .int },
        else => .{ .specifier = .int },
    };

    const ptr_width = comp.target.ptrBitWidth();
    const ptrdiff = if (os == .windows and ptr_width == 64)
        Type{ .specifier = .long_long }
    else switch (ptr_width) {
        16 => Type{ .specifier = .int },
        32 => Type{ .specifier = .int },
        64 => Type{ .specifier = .long },
        else => unreachable,
    };

    const size = if (os == .windows and ptr_width == 64)
        Type{ .specifier = .ulong_long }
    else switch (ptr_width) {
        16 => Type{ .specifier = .uint },
        32 => Type{ .specifier = .uint },
        64 => Type{ .specifier = .ulong },
        else => unreachable,
    };

    const va_list = try comp.generateVaListType();

    const pid_t: Type = switch (os) {
        .haiku => .{ .specifier = .long },
        // Todo: pid_t is required to "a signed integer type"; are there any systems
        // on which it is `short int`?
        else => .{ .specifier = .int },
    };

    const intmax = target_util.intMaxType(comp.target);
    const intptr = target_util.intPtrType(comp.target);
    const int16 = target_util.int16Type(comp.target);
    const int64 = target_util.int64Type(comp.target);

    comp.types = .{
        .wchar = wchar,
        .ptrdiff = ptrdiff,
        .size = size,
        .va_list = va_list,
        .pid_t = pid_t,
        .intmax = intmax,
        .intptr = intptr,
        .int16 = int16,
        .int64 = int64,
        .uint_least16_t = comp.intLeastN(16, .unsigned),
        .uint_least32_t = comp.intLeastN(32, .unsigned),
    };

    try comp.generateNsConstantStringType();
}

pub fn float80Type(comp: *const Compilation) ?Type {
    if (comp.langopts.emulate != .gcc) return null;
    return target_util.float80Type(comp.target);
}

/// Smallest integer type with at least N bits
pub fn intLeastN(comp: *const Compilation, bits: usize, signedness: std.builtin.Signedness) Type {
    if (bits == 64 and (comp.target.isDarwin() or comp.target.isWasm())) {
        // WebAssembly and Darwin use `long long` for `int_least64_t` and `int_fast64_t`.
        return .{ .specifier = if (signedness == .signed) .long_long else .ulong_long };
    }
    if (bits == 16 and comp.target.cpu.arch == .avr) {
        // AVR uses int for int_least16_t and int_fast16_t.
        return .{ .specifier = if (signedness == .signed) .int else .uint };
    }
    const candidates = switch (signedness) {
        .signed => &[_]Type.Specifier{ .schar, .short, .int, .long, .long_long },
        .unsigned => &[_]Type.Specifier{ .uchar, .ushort, .uint, .ulong, .ulong_long },
    };
    for (candidates) |specifier| {
        const ty: Type = .{ .specifier = specifier };
        if (ty.sizeof(comp).? * 8 >= bits) return ty;
    } else unreachable;
}

fn intSize(comp: *const Compilation, specifier: Type.Specifier) u64 {
    const ty = Type{ .specifier = specifier };
    return ty.sizeof(comp).?;
}

fn generateFastOrLeastType(
    comp: *Compilation,
    bits: usize,
    kind: enum { least, fast },
    signedness: std.builtin.Signedness,
    w: anytype,
    mapper: StrInt.TypeMapper,
) !void {
    const ty = comp.intLeastN(bits, signedness); // defining the fast types as the least types is permitted

    var buf: [32]u8 = undefined;
    const suffix = "_TYPE__";
    const base_name = switch (signedness) {
        .signed => "__INT_",
        .unsigned => "__UINT_",
    };
    const kind_str = switch (kind) {
        .fast => "FAST",
        .least => "LEAST",
    };

    const full = std.fmt.bufPrint(&buf, "{s}{s}{d}{s}", .{
        base_name, kind_str, bits, suffix,
    }) catch return error.OutOfMemory;

    try generateTypeMacro(w, mapper, full, ty, comp.langopts);

    const prefix = full[2 .. full.len - suffix.len]; // remove "__" and "_TYPE__"

    switch (signedness) {
        .signed => try comp.generateIntMaxAndWidth(w, prefix, ty),
        .unsigned => try comp.generateIntMax(w, prefix, ty),
    }
    try comp.generateFmt(prefix, w, ty);
}

fn generateFastAndLeastWidthTypes(comp: *Compilation, w: anytype, mapper: StrInt.TypeMapper) !void {
    const sizes = [_]usize{ 8, 16, 32, 64 };
    for (sizes) |size| {
        try comp.generateFastOrLeastType(size, .least, .signed, w, mapper);
        try comp.generateFastOrLeastType(size, .least, .unsigned, w, mapper);
        try comp.generateFastOrLeastType(size, .fast, .signed, w, mapper);
        try comp.generateFastOrLeastType(size, .fast, .unsigned, w, mapper);
    }
}

fn generateExactWidthTypes(comp: *const Compilation, w: anytype, mapper: StrInt.TypeMapper) !void {
    try comp.generateExactWidthType(w, mapper, .schar);

    if (comp.intSize(.short) > comp.intSize(.char)) {
        try comp.generateExactWidthType(w, mapper, .short);
    }

    if (comp.intSize(.int) > comp.intSize(.short)) {
        try comp.generateExactWidthType(w, mapper, .int);
    }

    if (comp.intSize(.long) > comp.intSize(.int)) {
        try comp.generateExactWidthType(w, mapper, .long);
    }

    if (comp.intSize(.long_long) > comp.intSize(.long)) {
        try comp.generateExactWidthType(w, mapper, .long_long);
    }

    try comp.generateExactWidthType(w, mapper, .uchar);
    try comp.generateExactWidthIntMax(w, .uchar);
    try comp.generateExactWidthIntMax(w, .schar);

    if (comp.intSize(.short) > comp.intSize(.char)) {
        try comp.generateExactWidthType(w, mapper, .ushort);
        try comp.generateExactWidthIntMax(w, .ushort);
        try comp.generateExactWidthIntMax(w, .short);
    }

    if (comp.intSize(.int) > comp.intSize(.short)) {
        try comp.generateExactWidthType(w, mapper, .uint);
        try comp.generateExactWidthIntMax(w, .uint);
        try comp.generateExactWidthIntMax(w, .int);
    }

    if (comp.intSize(.long) > comp.intSize(.int)) {
        try comp.generateExactWidthType(w, mapper, .ulong);
        try comp.generateExactWidthIntMax(w, .ulong);
        try comp.generateExactWidthIntMax(w, .long);
    }

    if (comp.intSize(.long_long) > comp.intSize(.long)) {
        try comp.generateExactWidthType(w, mapper, .ulong_long);
        try comp.generateExactWidthIntMax(w, .ulong_long);
        try comp.generateExactWidthIntMax(w, .long_long);
    }
}

fn generateFmt(comp: *const Compilation, prefix: []const u8, w: anytype, ty: Type) !void {
    const unsigned = ty.isUnsignedInt(comp);
    const modifier = ty.formatModifier();
    const formats = if (unsigned) "ouxX" else "di";
    for (formats) |c| {
        try w.print("#define {s}_FMT{c}__ \"{s}{c}\"\n", .{ prefix, c, modifier, c });
    }
}

fn generateSuffixMacro(comp: *const Compilation, prefix: []const u8, w: anytype, ty: Type) !void {
    return w.print("#define {s}_C_SUFFIX__ {s}\n", .{ prefix, ty.intValueSuffix(comp) });
}

/// Generate the following for ty:
///     Name macro (e.g. #define __UINT32_TYPE__ unsigned int)
///     Format strings (e.g. #define __UINT32_FMTu__ "u")
///     Suffix macro (e.g. #define __UINT32_C_SUFFIX__ U)
fn generateExactWidthType(comp: *const Compilation, w: anytype, mapper: StrInt.TypeMapper, specifier: Type.Specifier) !void {
    var ty = Type{ .specifier = specifier };
    const width = 8 * ty.sizeof(comp).?;
    const unsigned = ty.isUnsignedInt(comp);

    if (width == 16) {
        ty = if (unsigned) comp.types.int16.makeIntegerUnsigned() else comp.types.int16;
    } else if (width == 64) {
        ty = if (unsigned) comp.types.int64.makeIntegerUnsigned() else comp.types.int64;
    }

    var buffer: [16]u8 = undefined;
    const suffix = "_TYPE__";
    const full = std.fmt.bufPrint(&buffer, "{s}{d}{s}", .{
        if (unsigned) "__UINT" else "__INT", width, suffix,
    }) catch return error.OutOfMemory;

    try generateTypeMacro(w, mapper, full, ty, comp.langopts);

    const prefix = full[0 .. full.len - suffix.len]; // remove "_TYPE__"

    try comp.generateFmt(prefix, w, ty);
    try comp.generateSuffixMacro(prefix, w, ty);
}

pub fn hasFloat128(comp: *const Compilation) bool {
    return target_util.hasFloat128(comp.target);
}

pub fn hasHalfPrecisionFloatABI(comp: *const Compilation) bool {
    return comp.langopts.allow_half_args_and_returns or target_util.hasHalfPrecisionFloatABI(comp.target);
}

fn generateNsConstantStringType(comp: *Compilation) !void {
    comp.types.ns_constant_string.record = .{
        .name = try StrInt.intern(comp, "__NSConstantString_tag"),
        .fields = &comp.types.ns_constant_string.fields,
        .field_attributes = null,
        .type_layout = undefined,
    };
    const const_int_ptr = Type{ .specifier = .pointer, .data = .{ .sub_type = &comp.types.ns_constant_string.int_ty } };
    const const_char_ptr = Type{ .specifier = .pointer, .data = .{ .sub_type = &comp.types.ns_constant_string.char_ty } };

    comp.types.ns_constant_string.fields[0] = .{ .name = try StrInt.intern(comp, "isa"), .ty = const_int_ptr };
    comp.types.ns_constant_string.fields[1] = .{ .name = try StrInt.intern(comp, "flags"), .ty = .{ .specifier = .int } };
    comp.types.ns_constant_string.fields[2] = .{ .name = try StrInt.intern(comp, "str"), .ty = const_char_ptr };
    comp.types.ns_constant_string.fields[3] = .{ .name = try StrInt.intern(comp, "length"), .ty = .{ .specifier = .long } };
    comp.types.ns_constant_string.ty = .{ .specifier = .@"struct", .data = .{ .record = &comp.types.ns_constant_string.record } };
    record_layout.compute(&comp.types.ns_constant_string.record, comp.types.ns_constant_string.ty, comp, null) catch unreachable;
}

fn generateVaListType(comp: *Compilation) !Type {
    const Kind = enum { char_ptr, void_ptr, aarch64_va_list, x86_64_va_list };
    const kind: Kind = switch (comp.target.cpu.arch) {
        .aarch64 => switch (comp.target.os.tag) {
            .windows => @as(Kind, .char_ptr),
            .ios, .macos, .tvos, .watchos => .char_ptr,
            else => .aarch64_va_list,
        },
        .sparc, .wasm32, .wasm64, .bpfel, .bpfeb, .riscv32, .riscv64, .avr, .spirv32, .spirv64 => .void_ptr,
        .powerpc => switch (comp.target.os.tag) {
            .ios, .macos, .tvos, .watchos, .aix => @as(Kind, .char_ptr),
            else => return Type{ .specifier = .void }, // unknown
        },
        .x86, .msp430 => .char_ptr,
        .x86_64 => switch (comp.target.os.tag) {
            .windows => @as(Kind, .char_ptr),
            else => .x86_64_va_list,
        },
        else => return Type{ .specifier = .void }, // unknown
    };

    // TODO this might be bad?
    const arena = comp.diagnostics.arena.allocator();

    var ty: Type = undefined;
    switch (kind) {
        .char_ptr => ty = .{ .specifier = .char },
        .void_ptr => ty = .{ .specifier = .void },
        .aarch64_va_list => {
            const record_ty = try arena.create(Type.Record);
            record_ty.* = .{
                .name = try StrInt.intern(comp, "__va_list_tag"),
                .fields = try arena.alloc(Type.Record.Field, 5),
                .field_attributes = null,
                .type_layout = undefined, // computed below
            };
            const void_ty = try arena.create(Type);
            void_ty.* = .{ .specifier = .void };
            const void_ptr = Type{ .specifier = .pointer, .data = .{ .sub_type = void_ty } };
            record_ty.fields[0] = .{ .name = try StrInt.intern(comp, "__stack"), .ty = void_ptr };
            record_ty.fields[1] = .{ .name = try StrInt.intern(comp, "__gr_top"), .ty = void_ptr };
            record_ty.fields[2] = .{ .name = try StrInt.intern(comp, "__vr_top"), .ty = void_ptr };
            record_ty.fields[3] = .{ .name = try StrInt.intern(comp, "__gr_offs"), .ty = .{ .specifier = .int } };
            record_ty.fields[4] = .{ .name = try StrInt.intern(comp, "__vr_offs"), .ty = .{ .specifier = .int } };
            ty = .{ .specifier = .@"struct", .data = .{ .record = record_ty } };
            record_layout.compute(record_ty, ty, comp, null) catch unreachable;
        },
        .x86_64_va_list => {
            const record_ty = try arena.create(Type.Record);
            record_ty.* = .{
                .name = try StrInt.intern(comp, "__va_list_tag"),
                .fields = try arena.alloc(Type.Record.Field, 4),
                .field_attributes = null,
                .type_layout = undefined, // computed below
            };
            const void_ty = try arena.create(Type);
            void_ty.* = .{ .specifier = .void };
            const void_ptr = Type{ .specifier = .pointer, .data = .{ .sub_type = void_ty } };
            record_ty.fields[0] = .{ .name = try StrInt.intern(comp, "gp_offset"), .ty = .{ .specifier = .uint } };
            record_ty.fields[1] = .{ .name = try StrInt.intern(comp, "fp_offset"), .ty = .{ .specifier = .uint } };
            record_ty.fields[2] = .{ .name = try StrInt.intern(comp, "overflow_arg_area"), .ty = void_ptr };
            record_ty.fields[3] = .{ .name = try StrInt.intern(comp, "reg_save_area"), .ty = void_ptr };
            ty = .{ .specifier = .@"struct", .data = .{ .record = record_ty } };
            record_layout.compute(record_ty, ty, comp, null) catch unreachable;
        },
    }
    if (kind == .char_ptr or kind == .void_ptr) {
        const elem_ty = try arena.create(Type);
        elem_ty.* = ty;
        ty = Type{ .specifier = .pointer, .data = .{ .sub_type = elem_ty } };
    } else {
        const arr_ty = try arena.create(Type.Array);
        arr_ty.* = .{ .len = 1, .elem = ty };
        ty = Type{ .specifier = .array, .data = .{ .array = arr_ty } };
    }

    return ty;
}

fn generateIntMax(comp: *const Compilation, w: anytype, name: []const u8, ty: Type) !void {
    const bit_count: u8 = @intCast(ty.sizeof(comp).? * 8);
    const unsigned = ty.isUnsignedInt(comp);
    const max: u128 = switch (bit_count) {
        8 => if (unsigned) std.math.maxInt(u8) else std.math.maxInt(i8),
        16 => if (unsigned) std.math.maxInt(u16) else std.math.maxInt(i16),
        32 => if (unsigned) std.math.maxInt(u32) else std.math.maxInt(i32),
        64 => if (unsigned) std.math.maxInt(u64) else std.math.maxInt(i64),
        128 => if (unsigned) std.math.maxInt(u128) else std.math.maxInt(i128),
        else => unreachable,
    };
    try w.print("#define __{s}_MAX__ {d}{s}\n", .{ name, max, ty.intValueSuffix(comp) });
}

/// Largest value that can be stored in wchar_t
pub fn wcharMax(comp: *const Compilation) u32 {
    const unsigned = comp.types.wchar.isUnsignedInt(comp);
    return switch (comp.types.wchar.bitSizeof(comp).?) {
        8 => if (unsigned) std.math.maxInt(u8) else std.math.maxInt(i8),
        16 => if (unsigned) std.math.maxInt(u16) else std.math.maxInt(i16),
        32 => if (unsigned) std.math.maxInt(u32) else std.math.maxInt(i32),
        else => unreachable,
    };
}

fn generateExactWidthIntMax(comp: *const Compilation, w: anytype, specifier: Type.Specifier) !void {
    var ty = Type{ .specifier = specifier };
    const bit_count: u8 = @intCast(ty.sizeof(comp).? * 8);
    const unsigned = ty.isUnsignedInt(comp);

    if (bit_count == 64) {
        ty = if (unsigned) comp.types.int64.makeIntegerUnsigned() else comp.types.int64;
    }

    var name_buffer: [6]u8 = undefined;
    const name = std.fmt.bufPrint(&name_buffer, "{s}{d}", .{
        if (unsigned) "UINT" else "INT", bit_count,
    }) catch return error.OutOfMemory;

    return comp.generateIntMax(w, name, ty);
}

fn generateIntWidth(comp: *Compilation, w: anytype, name: []const u8, ty: Type) !void {
    try w.print("#define __{s}_WIDTH__ {d}\n", .{ name, 8 * ty.sizeof(comp).? });
}

fn generateIntMaxAndWidth(comp: *Compilation, w: anytype, name: []const u8, ty: Type) !void {
    try comp.generateIntMax(w, name, ty);
    try comp.generateIntWidth(w, name, ty);
}

fn generateSizeofType(comp: *Compilation, w: anytype, name: []const u8, ty: Type) !void {
    try w.print("#define {s} {d}\n", .{ name, ty.sizeof(comp).? });
}

pub fn nextLargestIntSameSign(comp: *const Compilation, ty: Type) ?Type {
    assert(ty.isInt());
    const specifiers = if (ty.isUnsignedInt(comp))
        [_]Type.Specifier{ .short, .int, .long, .long_long }
    else
        [_]Type.Specifier{ .ushort, .uint, .ulong, .ulong_long };
    const size = ty.sizeof(comp).?;
    for (specifiers) |specifier| {
        const candidate = Type{ .specifier = specifier };
        if (candidate.sizeof(comp).? > size) return candidate;
    }
    return null;
}

/// Maximum size of an array, in bytes
pub fn maxArrayBytes(comp: *const Compilation) u64 {
    const max_bits = @min(61, comp.target.ptrBitWidth());
    return (@as(u64, 1) << @truncate(max_bits)) - 1;
}

/// If `enum E { ... }` syntax has a fixed underlying integer type regardless of the presence of
/// __attribute__((packed)) or the range of values of the corresponding enumerator constants,
/// specify it here.
/// TODO: likely incomplete
pub fn fixedEnumTagSpecifier(comp: *const Compilation) ?Type.Specifier {
    switch (comp.langopts.emulate) {
        .msvc => return .int,
        .clang => if (comp.target.os.tag == .windows) return .int,
        .gcc => {},
    }
    return null;
}

pub fn getCharSignedness(comp: *const Compilation) std.builtin.Signedness {
    return comp.langopts.char_signedness_override orelse comp.target.charSignedness();
}

/// Add built-in aro headers directory to system include paths
pub fn addBuiltinIncludeDir(comp: *Compilation, aro_dir: []const u8) !void {
    var search_path = aro_dir;
    while (std.fs.path.dirname(search_path)) |dirname| : (search_path = dirname) {
        var base_dir = comp.cwd.openDir(dirname, .{}) catch continue;
        defer base_dir.close();

        base_dir.access("include/stddef.h", .{}) catch continue;
        const path = try std.fs.path.join(comp.gpa, &.{ dirname, "include" });
        errdefer comp.gpa.free(path);
        try comp.system_include_dirs.append(comp.gpa, path);
        break;
    } else return error.AroIncludeNotFound;
}

pub fn addSystemIncludeDir(comp: *Compilation, path: []const u8) !void {
    const duped = try comp.gpa.dupe(u8, path);
    errdefer comp.gpa.free(duped);
    try comp.system_include_dirs.append(comp.gpa, duped);
}

pub fn getSource(comp: *const Compilation, id: Source.Id) Source {
    if (id == .generated) return .{
        .path = "<scratch space>",
        .buf = comp.generated_buf.items,
        .id = .generated,
        .splice_locs = &.{},
        .kind = .user,
    };
    return comp.sources.values()[@intFromEnum(id) - 2];
}

/// Creates a Source from the contents of `reader` and adds it to the Compilation
pub fn addSourceFromReader(comp: *Compilation, reader: anytype, path: []const u8, kind: Source.Kind) !Source {
    const contents = try reader.readAllAlloc(comp.gpa, std.math.maxInt(u32));
    errdefer comp.gpa.free(contents);
    return comp.addSourceFromOwnedBuffer(contents, path, kind);
}

/// Creates a Source from `buf` and adds it to the Compilation
/// Performs newline splicing and line-ending normalization to '\n'
/// `buf` will be modified and the allocation will be resized if newline splicing
/// or line-ending changes happen.
/// caller retains ownership of `path`
/// To add the contents of an arbitrary reader as a Source, see addSourceFromReader
/// To add a file's contents given its path, see addSourceFromPath
pub fn addSourceFromOwnedBuffer(comp: *Compilation, buf: []u8, path: []const u8, kind: Source.Kind) !Source {
    try comp.sources.ensureUnusedCapacity(comp.gpa, 1);

    var contents = buf;
    const duped_path = try comp.gpa.dupe(u8, path);
    errdefer comp.gpa.free(duped_path);

    var splice_list = std.ArrayList(u32).init(comp.gpa);
    defer splice_list.deinit();

    const source_id: Source.Id = @enumFromInt(comp.sources.count() + 2);

    var i: u32 = 0;
    var backslash_loc: u32 = undefined;
    var state: enum {
        beginning_of_file,
        bom1,
        bom2,
        start,
        back_slash,
        cr,
        back_slash_cr,
        trailing_ws,
    } = .beginning_of_file;
    var line: u32 = 1;

    for (contents) |byte| {
        contents[i] = byte;

        switch (byte) {
            '\r' => {
                switch (state) {
                    .start, .cr, .beginning_of_file => {
                        state = .start;
                        line += 1;
                        state = .cr;
                        contents[i] = '\n';
                        i += 1;
                    },
                    .back_slash, .trailing_ws, .back_slash_cr => {
                        i = backslash_loc;
                        try splice_list.append(i);
                        if (state == .trailing_ws) {
                            try comp.addDiagnostic(.{
                                .tag = .backslash_newline_escape,
                                .loc = .{ .id = source_id, .byte_offset = i, .line = line },
                            }, &.{});
                        }
                        state = if (state == .back_slash_cr) .cr else .back_slash_cr;
                    },
                    .bom1, .bom2 => break, // invalid utf-8
                }
            },
            '\n' => {
                switch (state) {
                    .start, .beginning_of_file => {
                        state = .start;
                        line += 1;
                        i += 1;
                    },
                    .cr, .back_slash_cr => {},
                    .back_slash, .trailing_ws => {
                        i = backslash_loc;
                        if (state == .back_slash or state == .trailing_ws) {
                            try splice_list.append(i);
                        }
                        if (state == .trailing_ws) {
                            try comp.addDiagnostic(.{
                                .tag = .backslash_newline_escape,
                                .loc = .{ .id = source_id, .byte_offset = i, .line = line },
                            }, &.{});
                        }
                    },
                    .bom1, .bom2 => break,
                }
                state = .start;
            },
            '\\' => {
                backslash_loc = i;
                state = .back_slash;
                i += 1;
            },
            '\t', '\x0B', '\x0C', ' ' => {
                switch (state) {
                    .start, .trailing_ws => {},
                    .beginning_of_file => state = .start,
                    .cr, .back_slash_cr => state = .start,
                    .back_slash => state = .trailing_ws,
                    .bom1, .bom2 => break,
                }
                i += 1;
            },
            '\xEF' => {
                i += 1;
                state = switch (state) {
                    .beginning_of_file => .bom1,
                    else => .start,
                };
            },
            '\xBB' => {
                i += 1;
                state = switch (state) {
                    .bom1 => .bom2,
                    else => .start,
                };
            },
            '\xBF' => {
                switch (state) {
                    .bom2 => i = 0, // rewind and overwrite the BOM
                    else => i += 1,
                }
                state = .start;
            },
            else => {
                i += 1;
                state = .start;
            },
        }
    }

    const splice_locs = try splice_list.toOwnedSlice();
    errdefer comp.gpa.free(splice_locs);

    if (i != contents.len) contents = try comp.gpa.realloc(contents, i);
    errdefer @compileError("errdefers in callers would possibly free the realloced slice using the original len");

    const source = Source{
        .id = source_id,
        .path = duped_path,
        .buf = contents,
        .splice_locs = splice_locs,
        .kind = kind,
    };

    comp.sources.putAssumeCapacityNoClobber(duped_path, source);
    return source;
}

/// Caller retains ownership of `path` and `buf`.
/// Dupes the source buffer; if it is acceptable to modify the source buffer and possibly resize
/// the allocation, please use `addSourceFromOwnedBuffer`
pub fn addSourceFromBuffer(comp: *Compilation, path: []const u8, buf: []const u8) !Source {
    if (comp.sources.get(path)) |some| return some;
    if (@as(u64, buf.len) > std.math.maxInt(u32)) return error.StreamTooLong;

    const contents = try comp.gpa.dupe(u8, buf);
    errdefer comp.gpa.free(contents);

    return comp.addSourceFromOwnedBuffer(contents, path, .user);
}

/// Caller retains ownership of `path`.
pub fn addSourceFromPath(comp: *Compilation, path: []const u8) !Source {
    return comp.addSourceFromPathExtra(path, .user);
}

/// Caller retains ownership of `path`.
fn addSourceFromPathExtra(comp: *Compilation, path: []const u8, kind: Source.Kind) !Source {
    if (comp.sources.get(path)) |some| return some;

    if (mem.indexOfScalar(u8, path, 0) != null) {
        return error.FileNotFound;
    }

    const file = try comp.cwd.openFile(path, .{});
    defer file.close();

    const contents = file.readToEndAlloc(comp.gpa, std.math.maxInt(u32)) catch |err| switch (err) {
        error.FileTooBig => return error.StreamTooLong,
        else => |e| return e,
    };
    errdefer comp.gpa.free(contents);

    return comp.addSourceFromOwnedBuffer(contents, path, kind);
}

pub const IncludeDirIterator = struct {
    comp: *const Compilation,
    cwd_source_id: ?Source.Id,
    include_dirs_idx: usize = 0,
    sys_include_dirs_idx: usize = 0,
    tried_ms_cwd: bool = false,

    const FoundSource = struct {
        path: []const u8,
        kind: Source.Kind,
    };

    fn next(self: *IncludeDirIterator) ?FoundSource {
        if (self.cwd_source_id) |source_id| {
            self.cwd_source_id = null;
            const path = self.comp.getSource(source_id).path;
            return .{ .path = std.fs.path.dirname(path) orelse ".", .kind = .user };
        }
        if (self.include_dirs_idx < self.comp.include_dirs.items.len) {
            defer self.include_dirs_idx += 1;
            return .{ .path = self.comp.include_dirs.items[self.include_dirs_idx], .kind = .user };
        }
        if (self.sys_include_dirs_idx < self.comp.system_include_dirs.items.len) {
            defer self.sys_include_dirs_idx += 1;
            return .{ .path = self.comp.system_include_dirs.items[self.sys_include_dirs_idx], .kind = .system };
        }
        if (self.comp.ms_cwd_source_id) |source_id| {
            if (self.tried_ms_cwd) return null;
            self.tried_ms_cwd = true;
            const path = self.comp.getSource(source_id).path;
            return .{ .path = std.fs.path.dirname(path) orelse ".", .kind = .user };
        }
        return null;
    }

    /// Returned value's path field must be freed by allocator
    fn nextWithFile(self: *IncludeDirIterator, filename: []const u8, allocator: Allocator) !?FoundSource {
        while (self.next()) |found| {
            const path = try std.fs.path.join(allocator, &.{ found.path, filename });
            if (self.comp.langopts.ms_extensions) {
                std.mem.replaceScalar(u8, path, '\\', '/');
            }
            return .{ .path = path, .kind = found.kind };
        }
        return null;
    }

    /// Advance the iterator until it finds an include directory that matches
    /// the directory which contains `source`.
    fn skipUntilDirMatch(self: *IncludeDirIterator, source: Source.Id) void {
        const path = self.comp.getSource(source).path;
        const includer_path = std.fs.path.dirname(path) orelse ".";
        while (self.next()) |found| {
            if (mem.eql(u8, includer_path, found.path)) break;
        }
    }
};

pub fn hasInclude(
    comp: *const Compilation,
    filename: []const u8,
    includer_token_source: Source.Id,
    /// angle bracket vs quotes
    include_type: IncludeType,
    /// __has_include vs __has_include_next
    which: WhichInclude,
) !bool {
    if (mem.indexOfScalar(u8, filename, 0) != null) {
        return false;
    }

    if (std.fs.path.isAbsolute(filename)) {
        if (which == .next) return false;
        return !std.meta.isError(comp.cwd.access(filename, .{}));
    }

    const cwd_source_id = switch (include_type) {
        .quotes => switch (which) {
            .first => includer_token_source,
            .next => null,
        },
        .angle_brackets => null,
    };
    var it = IncludeDirIterator{ .comp = comp, .cwd_source_id = cwd_source_id };
    if (which == .next) {
        it.skipUntilDirMatch(includer_token_source);
    }

    var stack_fallback = std.heap.stackFallback(path_buf_stack_limit, comp.gpa);
    const sf_allocator = stack_fallback.get();

    while (try it.nextWithFile(filename, sf_allocator)) |found| {
        defer sf_allocator.free(found.path);
        if (!std.meta.isError(comp.cwd.access(found.path, .{}))) return true;
    }
    return false;
}

pub const WhichInclude = enum {
    first,
    next,
};

pub const IncludeType = enum {
    quotes,
    angle_brackets,
};

fn getFileContents(comp: *Compilation, path: []const u8, limit: ?u32) ![]const u8 {
    if (mem.indexOfScalar(u8, path, 0) != null) {
        return error.FileNotFound;
    }

    const file = try comp.cwd.openFile(path, .{});
    defer file.close();

    var buf = std.ArrayList(u8).init(comp.gpa);
    defer buf.deinit();

    const max = limit orelse std.math.maxInt(u32);
    file.reader().readAllArrayList(&buf, max) catch |e| switch (e) {
        error.StreamTooLong => if (limit == null) return e,
        else => return e,
    };

    return buf.toOwnedSlice();
}

pub fn findEmbed(
    comp: *Compilation,
    filename: []const u8,
    includer_token_source: Source.Id,
    /// angle bracket vs quotes
    include_type: IncludeType,
    limit: ?u32,
) !?[]const u8 {
    if (std.fs.path.isAbsolute(filename)) {
        return if (comp.getFileContents(filename, limit)) |some|
            some
        else |err| switch (err) {
            error.OutOfMemory => |e| return e,
            else => null,
        };
    }

    const cwd_source_id = switch (include_type) {
        .quotes => includer_token_source,
        .angle_brackets => null,
    };
    var it = IncludeDirIterator{ .comp = comp, .cwd_source_id = cwd_source_id };
    var stack_fallback = std.heap.stackFallback(path_buf_stack_limit, comp.gpa);
    const sf_allocator = stack_fallback.get();

    while (try it.nextWithFile(filename, sf_allocator)) |found| {
        defer sf_allocator.free(found.path);
        if (comp.getFileContents(found.path, limit)) |some|
            return some
        else |err| switch (err) {
            error.OutOfMemory => return error.OutOfMemory,
            else => {},
        }
    }
    return null;
}

pub fn findInclude(
    comp: *Compilation,
    filename: []const u8,
    includer_token: Token,
    /// angle bracket vs quotes
    include_type: IncludeType,
    /// include vs include_next
    which: WhichInclude,
) !?Source {
    if (std.fs.path.isAbsolute(filename)) {
        if (which == .next) return null;
        // TODO: classify absolute file as belonging to system includes or not?
        return if (comp.addSourceFromPath(filename)) |some|
            some
        else |err| switch (err) {
            error.OutOfMemory => |e| return e,
            else => null,
        };
    }
    const cwd_source_id = switch (include_type) {
        .quotes => switch (which) {
            .first => includer_token.source,
            .next => null,
        },
        .angle_brackets => null,
    };
    var it = IncludeDirIterator{ .comp = comp, .cwd_source_id = cwd_source_id };

    if (which == .next) {
        it.skipUntilDirMatch(includer_token.source);
    }

    var stack_fallback = std.heap.stackFallback(path_buf_stack_limit, comp.gpa);
    const sf_allocator = stack_fallback.get();

    while (try it.nextWithFile(filename, sf_allocator)) |found| {
        defer sf_allocator.free(found.path);
        if (comp.addSourceFromPathExtra(found.path, found.kind)) |some| {
            if (it.tried_ms_cwd) {
                try comp.addDiagnostic(.{
                    .tag = .ms_search_rule,
                    .extra = .{ .str = some.path },
                    .loc = .{
                        .id = includer_token.source,
                        .byte_offset = includer_token.start,
                        .line = includer_token.line,
                    },
                }, &.{});
            }
            return some;
        } else |err| switch (err) {
            error.OutOfMemory => return error.OutOfMemory,
            else => {},
        }
    }
    return null;
}

pub fn addPragmaHandler(comp: *Compilation, name: []const u8, handler: *Pragma) Allocator.Error!void {
    try comp.pragma_handlers.putNoClobber(comp.gpa, name, handler);
}

pub fn addDefaultPragmaHandlers(comp: *Compilation) Allocator.Error!void {
    const GCC = @import("pragmas/gcc.zig");
    var gcc = try GCC.init(comp.gpa);
    errdefer gcc.deinit(gcc, comp);

    const Once = @import("pragmas/once.zig");
    var once = try Once.init(comp.gpa);
    errdefer once.deinit(once, comp);

    const Message = @import("pragmas/message.zig");
    var message = try Message.init(comp.gpa);
    errdefer message.deinit(message, comp);

    const Pack = @import("pragmas/pack.zig");
    var pack = try Pack.init(comp.gpa);
    errdefer pack.deinit(pack, comp);

    try comp.addPragmaHandler("GCC", gcc);
    try comp.addPragmaHandler("once", once);
    try comp.addPragmaHandler("message", message);
    try comp.addPragmaHandler("pack", pack);
}

pub fn getPragma(comp: *Compilation, name: []const u8) ?*Pragma {
    return comp.pragma_handlers.get(name);
}

const PragmaEvent = enum {
    before_preprocess,
    before_parse,
    after_parse,
};

pub fn pragmaEvent(comp: *Compilation, event: PragmaEvent) void {
    for (comp.pragma_handlers.values()) |pragma| {
        const maybe_func = switch (event) {
            .before_preprocess => pragma.beforePreprocess,
            .before_parse => pragma.beforeParse,
            .after_parse => pragma.afterParse,
        };
        if (maybe_func) |func| func(pragma, comp);
    }
}

pub fn hasBuiltin(comp: *const Compilation, name: []const u8) bool {
    if (std.mem.eql(u8, name, "__builtin_va_arg") or
        std.mem.eql(u8, name, "__builtin_choose_expr") or
        std.mem.eql(u8, name, "__builtin_bitoffsetof") or
        std.mem.eql(u8, name, "__builtin_offsetof") or
        std.mem.eql(u8, name, "__builtin_types_compatible_p")) return true;

    const builtin = Builtin.fromName(name) orelse return false;
    return comp.hasBuiltinFunction(builtin);
}

pub fn hasBuiltinFunction(comp: *const Compilation, builtin: Builtin) bool {
    if (!target_util.builtinEnabled(comp.target, builtin.properties.target_set)) return false;

    switch (builtin.properties.language) {
        .all_languages => return true,
        .all_ms_languages => return comp.langopts.emulate == .msvc,
        .gnu_lang, .all_gnu_languages => return comp.langopts.standard.isGNU(),
    }
}

pub fn locSlice(comp: *const Compilation, loc: Source.Location) []const u8 {
    var tmp_tokenizer = Tokenizer{
        .buf = comp.getSource(loc.id).buf,
        .langopts = comp.langopts,
        .index = loc.byte_offset,
        .source = .generated,
    };
    const tok = tmp_tokenizer.next();
    return tmp_tokenizer.buf[tok.start..tok.end];
}

pub const CharUnitSize = enum(u32) {
    @"1" = 1,
    @"2" = 2,
    @"4" = 4,

    pub fn Type(comptime self: CharUnitSize) type {
        return switch (self) {
            .@"1" => u8,
            .@"2" => u16,
            .@"4" => u32,
        };
    }
};

pub const addDiagnostic = Diagnostics.add;

test "addSourceFromReader" {
    const Test = struct {
        fn addSourceFromReader(str: []const u8, expected: []const u8, warning_count: u32, splices: []const u32) !void {
            var comp = Compilation.init(std.testing.allocator, std.fs.cwd());
            defer comp.deinit();

            var buf_reader = std.io.fixedBufferStream(str);
            const source = try comp.addSourceFromReader(buf_reader.reader(), "path", .user);

            try std.testing.expectEqualStrings(expected, source.buf);
            try std.testing.expectEqual(warning_count, @as(u32, @intCast(comp.diagnostics.list.items.len)));
            try std.testing.expectEqualSlices(u32, splices, source.splice_locs);
        }

        fn withAllocationFailures(allocator: std.mem.Allocator) !void {
            var comp = Compilation.init(allocator, std.fs.cwd());
            defer comp.deinit();

            _ = try comp.addSourceFromBuffer("path", "spliced\\\nbuffer\n");
            _ = try comp.addSourceFromBuffer("path", "non-spliced buffer\n");
        }
    };
    try Test.addSourceFromReader("ab\\\nc", "abc", 0, &.{2});
    try Test.addSourceFromReader("ab\\\rc", "abc", 0, &.{2});
    try Test.addSourceFromReader("ab\\\r\nc", "abc", 0, &.{2});
    try Test.addSourceFromReader("ab\\ \nc", "abc", 1, &.{2});
    try Test.addSourceFromReader("ab\\\t\nc", "abc", 1, &.{2});
    try Test.addSourceFromReader("ab\\                     \t\nc", "abc", 1, &.{2});
    try Test.addSourceFromReader("ab\\\r \nc", "ab \nc", 0, &.{2});
    try Test.addSourceFromReader("ab\\\\\nc", "ab\\c", 0, &.{3});
    try Test.addSourceFromReader("ab\\   \r\nc", "abc", 1, &.{2});
    try Test.addSourceFromReader("ab\\ \\\nc", "ab\\ c", 0, &.{4});
    try Test.addSourceFromReader("ab\\\r\\\nc", "abc", 0, &.{ 2, 2 });
    try Test.addSourceFromReader("ab\\  \rc", "abc", 1, &.{2});
    try Test.addSourceFromReader("ab\\", "ab\\", 0, &.{});
    try Test.addSourceFromReader("ab\\\\", "ab\\\\", 0, &.{});
    try Test.addSourceFromReader("ab\\ ", "ab\\ ", 0, &.{});
    try Test.addSourceFromReader("ab\\\n", "ab", 0, &.{2});
    try Test.addSourceFromReader("ab\\\r\n", "ab", 0, &.{2});
    try Test.addSourceFromReader("ab\\\r", "ab", 0, &.{2});

    // carriage return normalization
    try Test.addSourceFromReader("ab\r", "ab\n", 0, &.{});
    try Test.addSourceFromReader("ab\r\r", "ab\n\n", 0, &.{});
    try Test.addSourceFromReader("ab\r\r\n", "ab\n\n", 0, &.{});
    try Test.addSourceFromReader("ab\r\r\n\r", "ab\n\n\n", 0, &.{});
    try Test.addSourceFromReader("\r\\", "\n\\", 0, &.{});
    try Test.addSourceFromReader("\\\r\\", "\\", 0, &.{0});

    try std.testing.checkAllAllocationFailures(std.testing.allocator, Test.withAllocationFailures, .{});
}

test "addSourceFromReader - exhaustive check for carriage return elimination" {
    const alphabet = [_]u8{ '\r', '\n', ' ', '\\', 'a' };
    const alen = alphabet.len;
    var buf: [alphabet.len]u8 = [1]u8{alphabet[0]} ** alen;

    var comp = Compilation.init(std.testing.allocator, std.fs.cwd());
    defer comp.deinit();

    var source_count: u32 = 0;

    while (true) {
        const source = try comp.addSourceFromBuffer(&buf, &buf);
        source_count += 1;
        try std.testing.expect(std.mem.indexOfScalar(u8, source.buf, '\r') == null);

        if (std.mem.allEqual(u8, &buf, alphabet[alen - 1])) break;

        var idx = std.mem.indexOfScalar(u8, &alphabet, buf[buf.len - 1]).?;
        buf[buf.len - 1] = alphabet[(idx + 1) % alen];
        var j = buf.len - 1;
        while (j > 0) : (j -= 1) {
            idx = std.mem.indexOfScalar(u8, &alphabet, buf[j - 1]).?;
            if (buf[j] == alphabet[0]) buf[j - 1] = alphabet[(idx + 1) % alen] else break;
        }
    }
    try std.testing.expect(source_count == std.math.powi(usize, alen, alen) catch unreachable);
}

test "ignore BOM at beginning of file" {
    const BOM = "\xEF\xBB\xBF";

    const Test = struct {
        fn run(buf: []const u8) !void {
            var comp = Compilation.init(std.testing.allocator, std.fs.cwd());
            defer comp.deinit();

            var buf_reader = std.io.fixedBufferStream(buf);
            const source = try comp.addSourceFromReader(buf_reader.reader(), "file.c", .user);
            const expected_output = if (mem.startsWith(u8, buf, BOM)) buf[BOM.len..] else buf;
            try std.testing.expectEqualStrings(expected_output, source.buf);
        }
    };

    try Test.run(BOM);
    try Test.run(BOM ++ "x");
    try Test.run("x" ++ BOM);
    try Test.run(BOM ++ " ");
    try Test.run(BOM ++ "\n");
    try Test.run(BOM ++ "\\");

    try Test.run(BOM[0..1] ++ "x");
    try Test.run(BOM[0..2] ++ "x");
    try Test.run(BOM[1..] ++ "x");
    try Test.run(BOM[2..] ++ "x");
}

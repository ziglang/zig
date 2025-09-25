const std = @import("std");
const assert = std.debug.assert;
const EpochSeconds = std.time.epoch.EpochSeconds;
const mem = std.mem;
const Allocator = mem.Allocator;

const backend = @import("../backend.zig");
const Interner = backend.Interner;
const CodeGenOptions = backend.CodeGenOptions;

const Builtins = @import("Builtins.zig");
const Builtin = Builtins.Builtin;
const Diagnostics = @import("Diagnostics.zig");
const DepFile = @import("DepFile.zig");
const LangOpts = @import("LangOpts.zig");
const Pragma = @import("Pragma.zig");
const record_layout = @import("record_layout.zig");
const Source = @import("Source.zig");
const StringInterner = @import("StringInterner.zig");
const target_util = @import("target.zig");
const Tokenizer = @import("Tokenizer.zig");
const Token = Tokenizer.Token;
const TypeStore = @import("TypeStore.zig");
const Type = TypeStore.Type;
const QualType = TypeStore.QualType;

pub const Error = error{
    /// A fatal error has ocurred and compilation has stopped.
    FatalError,
} || Allocator.Error;
pub const AddSourceError = Error || error{FileTooBig};

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

    /// UNIX timestamp to be used instead of the current date and time in the __DATE__ and __TIME__ macros, and instead of the
    /// file modification time in the __TIMESTAMP__ macro
    source_date_epoch: ?[]const u8 = null,

    pub const SourceEpoch = union(enum) {
        /// Represents system time when aro is invoked; used for __DATE__ and __TIME__ macros
        system: u64,
        /// Represents a user-provided time (typically via the SOURCE_DATE_EPOCH environment variable)
        /// used for __DATE__, __TIME__, and __TIMESTAMP__
        provided: u64,

        pub const default: @This() = .{ .provided = 0 };
    };

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

    pub fn sourceEpoch(self: *const Environment) !SourceEpoch {
        const max_timestamp = 253402300799; // Dec 31 9999 23:59:59

        if (self.source_date_epoch) |epoch| {
            const parsed = std.fmt.parseInt(u64, epoch, 10) catch return error.InvalidEpoch;
            if (parsed > max_timestamp) return error.InvalidEpoch;
            return .{ .provided = parsed };
        } else {
            const timestamp = std.math.cast(u64, std.time.timestamp()) orelse return error.InvalidEpoch;
            return .{ .system = std.math.clamp(timestamp, 0, max_timestamp) };
        }
    }
};

const Compilation = @This();

gpa: Allocator,
/// Allocations in this arena live all the way until `Compilation.deinit`.
arena: Allocator,
diagnostics: *Diagnostics,

code_gen_options: CodeGenOptions = .default,
environment: Environment = .{},
sources: std.StringArrayHashMapUnmanaged(Source) = .empty,
/// Allocated into `gpa`, but keys are externally managed.
include_dirs: std.ArrayList([]const u8) = .empty,
/// Allocated into `gpa`, but keys are externally managed.
iquote_include_dirs: std.ArrayList([]const u8) = .empty,
/// Allocated into `gpa`, but keys are externally managed.
system_include_dirs: std.ArrayList([]const u8) = .empty,
/// Allocated into `gpa`, but keys are externally managed.
after_include_dirs: std.ArrayList([]const u8) = .empty,
/// Allocated into `gpa`, but keys are externally managed.
framework_dirs: std.ArrayList([]const u8) = .empty,
/// Allocated into `gpa`, but keys are externally managed.
system_framework_dirs: std.ArrayList([]const u8) = .empty,
/// Allocated into `gpa`, but keys are externally managed.
embed_dirs: std.ArrayList([]const u8) = .empty,
target: std.Target = @import("builtin").target,
cmodel: std.builtin.CodeModel = .default,
pragma_handlers: std.StringArrayHashMapUnmanaged(*Pragma) = .empty,
langopts: LangOpts = .{},
generated_buf: std.ArrayList(u8) = .empty,
builtins: Builtins = .{},
string_interner: StringInterner = .{},
interner: Interner = .{},
type_store: TypeStore = .{},
/// If this is not null, the directory containing the specified Source will be searched for includes
/// Used by MS extensions which allow searching for includes relative to the directory of the main source file.
ms_cwd_source_id: ?Source.Id = null,
cwd: std.fs.Dir,

pub fn init(gpa: Allocator, arena: Allocator, diagnostics: *Diagnostics, cwd: std.fs.Dir) Compilation {
    return .{
        .gpa = gpa,
        .arena = arena,
        .diagnostics = diagnostics,
        .cwd = cwd,
    };
}

/// Initialize Compilation with default environment,
/// pragma handlers and emulation mode set to target.
pub fn initDefault(gpa: Allocator, arena: Allocator, diagnostics: *Diagnostics, cwd: std.fs.Dir) !Compilation {
    var comp: Compilation = .{
        .gpa = gpa,
        .arena = arena,
        .diagnostics = diagnostics,
        .environment = try Environment.loadAll(gpa),
        .cwd = cwd,
    };
    errdefer comp.deinit();
    try comp.addDefaultPragmaHandlers();
    comp.langopts.setEmulatedCompiler(target_util.systemCompiler(comp.target));
    return comp;
}

pub fn deinit(comp: *Compilation) void {
    const gpa = comp.gpa;
    for (comp.pragma_handlers.values()) |pragma| {
        pragma.deinit(pragma, comp);
    }
    for (comp.sources.values()) |source| {
        gpa.free(source.path);
        gpa.free(source.buf);
        gpa.free(source.splice_locs);
    }
    comp.sources.deinit(gpa);
    comp.include_dirs.deinit(gpa);
    comp.iquote_include_dirs.deinit(gpa);
    comp.system_include_dirs.deinit(gpa);
    comp.after_include_dirs.deinit(gpa);
    comp.framework_dirs.deinit(gpa);
    comp.system_framework_dirs.deinit(gpa);
    comp.embed_dirs.deinit(gpa);
    comp.pragma_handlers.deinit(gpa);
    comp.generated_buf.deinit(gpa);
    comp.builtins.deinit(gpa);
    comp.string_interner.deinit(gpa);
    comp.interner.deinit(gpa);
    comp.environment.deinit(gpa);
    comp.type_store.deinit(gpa);
    comp.* = undefined;
}

pub fn internString(comp: *Compilation, str: []const u8) !StringInterner.StringId {
    return comp.string_interner.intern(comp.gpa, str);
}

/// Which set of system defines to generate via generateBuiltinMacros
pub const SystemDefinesMode = enum {
    /// Only define macros required by the C standard (date/time macros and those beginning with `__STDC`)
    no_system_defines,
    /// Define the standard set of system macros
    include_system_defines,
};

fn generateSystemDefines(comp: *Compilation, w: *std.Io.Writer) !void {
    const define = struct {
        fn define(_w: *std.Io.Writer, name: []const u8) !void {
            try _w.print("#define {s} 1\n", .{name});
        }
    }.define;
    const defineStd = struct {
        fn defineStd(_w: *std.Io.Writer, name: []const u8, is_gnu: bool) !void {
            if (is_gnu) {
                try _w.print("#define {s} 1\n", .{name});
            }
            try _w.print(
                \\#define __{s} 1
                \\#define __{s}__ 1
                \\
            , .{ name, name });
        }
    }.defineStd;
    const ptr_width = comp.target.ptrBitWidth();
    const is_gnu = comp.langopts.standard.isGNU();

    const gnuc_version = comp.langopts.gnuc_version orelse comp.langopts.emulate.defaultGccVersion();
    if (gnuc_version > 0) {
        try w.print("#define __GNUC__ {d}\n", .{gnuc_version / 10_000});
        try w.print("#define __GNUC_MINOR__ {d}\n", .{gnuc_version / 100 % 100});
        try w.print("#define __GNUC_PATCHLEVEL__ {d}\n", .{gnuc_version % 100});
    }

    try w.writeAll(
        \\#define __ARO_EMULATE_CLANG__ 1
        \\#define __ARO_EMULATE_GCC__ 2
        \\#define __ARO_EMULATE_MSVC__ 3
        \\
    );
    const emulated = switch (comp.langopts.emulate) {
        .clang => "__ARO_EMULATE_CLANG__",
        .gcc => "__ARO_EMULATE_GCC__",
        .msvc => "__ARO_EMULATE_MSVC__",
    };
    try w.print("#define __ARO_EMULATE__ {s}\n", .{emulated});

    if (comp.code_gen_options.optimization_level.hasAnyOptimizations()) {
        try define(w, "__OPTIMIZE__");
    }
    if (comp.code_gen_options.optimization_level.isSizeOptimized()) {
        try define(w, "__OPTIMIZE_SIZE__");
    }

    // os macros
    switch (comp.target.os.tag) {
        .linux => try defineStd(w, "linux", is_gnu),
        .windows => {
            try define(w, "_WIN32");
            if (ptr_width == 64) {
                try define(w, "_WIN64");
            }

            if (comp.target.abi.isGnu()) {
                try defineStd(w, "WIN32", is_gnu);
                try defineStd(w, "WINNT", is_gnu);
                if (ptr_width == 64) {
                    try defineStd(w, "WIN64", is_gnu);
                    try define(w, "__MINGW64__");
                }
                try define(w, "__MSVCRT__");
                try define(w, "__MINGW32__");
            } else if (comp.target.abi == .cygnus) {
                try define(w, "__CYGWIN__");
                if (ptr_width == 64) {
                    try define(w, "__CYGWIN64__");
                } else {
                    try define(w, "__CYGWIN32__");
                }
            }

            if (comp.target.abi.isGnu() or comp.target.abi == .cygnus) {
                // MinGW and Cygwin define __declspec(a) to __attribute((a)).
                // Like Clang we make the define no op if -fdeclspec is enabled.
                if (comp.langopts.declspec_attrs) {
                    try w.writeAll("#define __declspec __declspec\n");
                } else {
                    try w.writeAll("#define __declspec(a) __attribute__((a))\n");
                }
                if (!comp.langopts.ms_extensions) {
                    // Provide aliases for the calling convention keywords.
                    for ([_][]const u8{ "cdecl", "stdcall", "fastcall", "thiscall" }) |keyword| {
                        try w.print(
                            \\#define _{[0]s} __attribute__((__{[0]s}__))
                            \\#define __{[0]s} __attribute__((__{[0]s}__))
                            \\
                        , .{keyword});
                    }
                }
            }
        },
        .uefi => try define(w, "__UEFI__"),
        .freebsd => {
            const release = comp.target.os.version_range.semver.min.major;
            const cc_version = release * 10_000 + 1;
            try w.print(
                \\#define __FreeBSD__ {d}
                \\#define __FreeBSD_cc_version {d}
                \\
            , .{ release, cc_version });
        },
        .ps4, .ps5 => {
            try w.writeAll(
                \\#define __FreeBSD__ 9
                \\#define __FreeBSD_cc_version 900001
                \\
            );
        },
        .netbsd => try define(w, "__NetBSD__"),
        .openbsd => try define(w, "__OpenBSD__"),
        .dragonfly => try define(w, "__DragonFly__"),
        .solaris => try defineStd(w, "sun", is_gnu),
        .macos,
        .tvos,
        .ios,
        .driverkit,
        .visionos,
        .watchos,
        => try define(w, "__APPLE__"),
        .wasi => try define(w, "__wasi__"),
        .emscripten => try define(w, "__EMSCRIPTEN__"),
        .@"3ds" => try define(w, "__3DS__"),
        .vita => try define(w, "__vita__"),
        else => {},
    }

    // unix and other additional os macros
    switch (comp.target.os.tag) {
        .freebsd,
        .netbsd,
        .openbsd,
        .dragonfly,
        .linux,
        .haiku,
        .hurd,
        .solaris,
        .aix,
        .emscripten,
        .ps4,
        .ps5,
        => try defineStd(w, "unix", is_gnu),
        .windows => if (comp.target.abi.isGnu() or comp.target.abi == .cygnus) {
            try defineStd(w, "unix", is_gnu);
        },
        else => {},
    }
    if (comp.target.abi.isAndroid()) {
        try define(w, "__ANDROID__");
    }

    // architecture macros
    switch (comp.target.cpu.arch) {
        .x86, .x86_64 => {
            try w.print("#define __code_model_{s}__ 1\n", .{switch (comp.cmodel) {
                .default => "small",
                else => @tagName(comp.cmodel),
            }});

            if (comp.target.cpu.arch == .x86_64) {
                try define(w, "__amd64__");
                try define(w, "__amd64");
                try define(w, "__x86_64__");
                try define(w, "__x86_64");

                if (comp.target.os.tag == .windows and comp.target.abi == .msvc) {
                    try w.writeAll(
                        \\#define _M_X64 100
                        \\#define _M_AMD64 100
                        \\
                    );
                }
            } else {
                try defineStd(w, "i386", is_gnu);

                if (comp.target.os.tag == .windows and comp.target.abi == .msvc) {
                    try w.print("#define _M_IX86 {d}\n", .{blk: {
                        if (comp.target.cpu.model == &std.Target.x86.cpu.i386) break :blk 300;
                        if (comp.target.cpu.model == &std.Target.x86.cpu.i486) break :blk 400;
                        if (comp.target.cpu.model == &std.Target.x86.cpu.i586) break :blk 500;
                        break :blk @as(u32, 600);
                    }});
                }
            }
            try define(w, "__SEG_GS");
            try define(w, "__SEG_FS");
            try w.writeAll(
                \\#define __seg_gs __attribute__((address_space(256)))
                \\#define __seg_fs __attribute__((address_space(257)))
                \\
            );

            if (comp.target.cpu.has(.x86, .sahf) or (comp.langopts.emulate == .clang and comp.target.cpu.arch == .x86)) {
                try define(w, "__LAHF_SAHF__");
            }

            const features = comp.target.cpu.features;
            for ([_]struct { std.Target.x86.Feature, []const u8 }{
                .{ .aes, "__AES__" },
                .{ .vaes, "__VAES__" },
                .{ .pclmul, "__PCLMUL__" },
                .{ .vpclmulqdq, "__VPCLMULQDQ__" },
                .{ .lzcnt, "__LZCNT__" },
                .{ .rdrnd, "__RDRND__" },
                .{ .fsgsbase, "__FSGSBASE__" },
                .{ .bmi, "__BMI__" },
                .{ .bmi2, "__BMI2__" },
                .{ .popcnt, "__POPCNT__" },
                .{ .rtm, "__RTM__" },
                .{ .prfchw, "__PRFCHW__" },
                .{ .rdseed, "__RDSEED__" },
                .{ .adx, "__ADX__" },
                .{ .tbm, "__TBM__" },
                .{ .lwp, "__LWP__" },
                .{ .mwaitx, "__MWAITX__" },
                .{ .movbe, "__MOVBE__" },

                .{ .xop, "__XOP__" },
                .{ .fma4, "__FMA4__" },
                .{ .sse4a, "__SSE4A__" },

                .{ .fma, "__FMA__" },
                .{ .f16c, "__F16C__" },
                .{ .gfni, "__GFNI__" },
                .{ .evex512, "__EVEX512__" },

                .{ .avx10_1, "__AVX10_1__" },
                .{ .avx10_1, "__AVX10_1_512__" },

                .{ .avx10_2, "__AVX10_2__" },
                .{ .avx10_2, "__AVX10_2_512__" },

                .{ .avx512cd, "__AVX512CD__" },
                .{ .avx512vpopcntdq, "__AVX512VPOPCNTDQ__" },
                .{ .avx512vnni, "__AVX512VNNI__" },
                .{ .avx512bf16, "__AVX512BF16__" },
                .{ .avx512fp16, "__AVX512FP16__" },
                .{ .avx512dq, "__AVX512DQ__" },
                .{ .avx512bitalg, "__AVX512BITALG__" },
                .{ .avx512bw, "__AVX512BW__" },

                .{ .avx512vl, "__AVX512VL__" },
                .{ .avx512vl, "__EVEX256__" },

                .{ .avx512vbmi, "__AVX512VBMI__" },
                .{ .avx512vbmi2, "__AVX512VBMI2__" },
                .{ .avx512ifma, "__AVX512IFMA__" },
                .{ .avx512vp2intersect, "__AVX512VP2INTERSECT__" },
                .{ .sha, "__SHA__" },
                .{ .sha512, "__SHA512__" },
                .{ .fxsr, "__FXSR__" },
                .{ .xsave, "__XSAVE__" },
                .{ .xsaveopt, "__XSAVEOPT__" },
                .{ .xsavec, "__XSAVEC__" },
                .{ .xsaves, "__XSAVES__" },
                .{ .pku, "__PKU__" },
                .{ .clflushopt, "__CLFLUSHOPT__" },
                .{ .clwb, "__CLWB__" },
                .{ .wbnoinvd, "__WBNOINVD__" },
                .{ .shstk, "__SHSTK__" },
                .{ .sgx, "__SGX__" },
                .{ .sm3, "__SM3__" },
                .{ .sm4, "__SM4__" },
                .{ .prefetchi, "__PREFETCHI__" },
                .{ .clzero, "__CLZERO__" },
                .{ .kl, "__KL__" },
                .{ .widekl, "__WIDEKL__" },
                .{ .rdpid, "__RDPID__" },
                .{ .rdpru, "__RDPRU__" },
                .{ .cldemote, "__CLDEMOTE__" },
                .{ .waitpkg, "__WAITPKG__" },
                .{ .movdiri, "__MOVDIRI__" },
                .{ .movdir64b, "__MOVDIR64B__" },
                .{ .movrs, "__MOVRS__" },
                .{ .pconfig, "__PCONFIG__" },
                .{ .ptwrite, "__PTWRITE__" },
                .{ .invpcid, "__INVPCID__" },
                .{ .enqcmd, "__ENQCMD__" },
                .{ .hreset, "__HRESET__" },
                .{ .amx_tile, "__AMX_TILE__" },
                .{ .amx_int8, "__AMX_INT8__" },
                .{ .amx_bf16, "__AMX_BF16__" },
                .{ .amx_fp16, "__AMX_FP16__" },
                .{ .amx_complex, "__AMX_COMPLEX__" },
                .{ .amx_fp8, "__AMX_FP8__" },
                .{ .amx_movrs, "__AMX_MOVRS__" },
                .{ .amx_transpose, "__AMX_TRANSPOSE__" },
                .{ .amx_avx512, "__AMX_AVX512__" },
                .{ .amx_tf32, "__AMX_TF32__" },
                .{ .cmpccxadd, "__CMPCCXADD__" },
                .{ .raoint, "__RAOINT__" },
                .{ .avxifma, "__AVXIFMA__" },
                .{ .avxneconvert, "__AVXNECONVERT__" },
                .{ .avxvnni, "__AVXVNNI__" },
                .{ .avxvnniint16, "__AVXVNNIINT16__" },
                .{ .avxvnniint8, "__AVXVNNIINT8__" },
                .{ .serialize, "__SERIALIZE__" },
                .{ .tsxldtrk, "__TSXLDTRK__" },
                .{ .uintr, "__UINTR__" },
                .{ .usermsr, "__USERMSR__" },
                .{ .crc32, "__CRC32__" },
                .{ .egpr, "__EGPR__" },
                .{ .push2pop2, "__PUSH2POP2__" },
                .{ .ppx, "__PPX__" },
                .{ .ndd, "__NDD__" },
                .{ .ccmp, "__CCMP__" },
                .{ .nf, "__NF__" },
                .{ .cf, "__CF__" },
                .{ .zu, "__ZU__" },

                .{ .avx512f, "__AVX512F__" },
                .{ .avx2, "__AVX2__" },
                .{ .avx, "__AVX__" },
                .{ .sse4_2, "__SSE4_2__" },
                .{ .sse4_1, "__SSE4_1__" },
                .{ .ssse3, "__SSSE3__" },
                .{ .sse3, "__SSE3__" },
                .{ .sse2, "__SSE2__" },
                .{ .sse, "__SSE__" },
                .{ .sse, "__SSE_MATH__" },

                .{ .mmx, "__MMX__" },
            }) |fs| {
                if (features.isEnabled(@intFromEnum(fs[0]))) {
                    try define(w, fs[1]);
                }
            }

            if (comp.langopts.ms_extensions and comp.target.cpu.arch == .x86) {
                const level = if (comp.target.cpu.has(.x86, .sse2))
                    "2"
                else if (comp.target.cpu.has(.x86, .sse))
                    "1"
                else
                    "0";

                try w.print("#define _M_IX86_FP {s}\n", .{level});
            }

            if (comp.target.cpu.hasAll(.x86, &.{ .egpr, .push2pop2, .ppx, .ndd, .ccmp, .nf, .cf, .zu })) {
                try define(w, "__APX_F__");
            }

            if (comp.target.cpu.hasAll(.x86, &.{ .egpr, .inline_asm_use_gpr32 })) {
                try define(w, "__APX_INLINE_ASM_USE_GPR32__");
            }

            if (comp.target.cpu.has(.x86, .cx8)) {
                try define(w, "__GCC_HAVE_SYNC_COMPARE_AND_SWAP_8");
            }
            if (comp.target.cpu.has(.x86, .cx16) and comp.target.cpu.arch == .x86_64) {
                try define(w, "__GCC_HAVE_SYNC_COMPARE_AND_SWAP_8");
            }

            if (comp.hasFloat128()) {
                try w.writeAll("#define __SIZEOF_FLOAT128__ 16\n");
            }
        },
        .mips,
        .mipsel,
        .mips64,
        .mips64el,
        => {
            try define(w, "__mips__");
            try define(w, "_mips");
        },
        .powerpc,
        .powerpcle,
        => {
            try define(w, "__powerpc__");
            try define(w, "__POWERPC__");
            try define(w, "__ppc__");
            try define(w, "__PPC__");
            try define(w, "_ARCH_PPC");
        },
        .powerpc64,
        .powerpc64le,
        => {
            try define(w, "__powerpc");
            try define(w, "__powerpc__");
            try define(w, "__powerpc64__");
            try define(w, "__POWERPC__");
            try define(w, "__ppc__");
            try define(w, "__ppc64__");
            try define(w, "__PPC__");
            try define(w, "__PPC64__");
            try define(w, "_ARCH_PPC");
            try define(w, "_ARCH_PPC64");
        },
        .sparc64 => {
            try defineStd(w, "sparc", is_gnu);
            try define(w, "__sparc_v9__");
            try define(w, "__arch64__");
            if (comp.target.os.tag != .solaris) {
                try define(w, "__sparc64__");
                try define(w, "__sparc_v9__");
                try define(w, "__sparcv9__");
            }
        },
        .sparc => {
            try defineStd(w, "sparc", is_gnu);
            if (comp.target.os.tag == .solaris) {
                try define(w, "__sparcv8");
            }
        },
        .arm, .armeb, .thumb, .thumbeb => {
            try define(w, "__arm__");
            try define(w, "__arm");
            if (comp.target.cpu.arch.isThumb()) {
                try define(w, "__thumb__");
            }
        },
        .aarch64, .aarch64_be => {
            try define(w, "__aarch64__");
            if (comp.target.os.tag == .macos) {
                try define(w, "__AARCH64_SIMD__");
                if (ptr_width == 32) {
                    try define(w, "__ARM64_ARCH_8_32__");
                } else {
                    try define(w, "__ARM64_ARCH_8__");
                }
                try define(w, "__ARM_NEON__");
                try define(w, "__arm64");
                try define(w, "__arm64__");
            }
            if (comp.target.os.tag == .windows and comp.target.abi == .msvc) {
                try w.writeAll("#define _M_ARM64 1\n");
            }

            {
                const cmodel = switch (comp.cmodel) {
                    .default => "small",
                    else => @tagName(comp.cmodel),
                };
                try w.writeAll("#define __AARCH64_CMODEL_");
                for (cmodel) |c| {
                    try w.writeByte(std.ascii.toUpper(c));
                }
                try w.writeAll("__ 1\n");
            }

            if (comp.target.cpu.has(.aarch64, .fp_armv8)) {
                try w.writeAll("#define __ARM_FP 0xE\n");
            }
            if (comp.target.cpu.has(.aarch64, .neon)) {
                try define(w, "__ARM_NEON");
                try w.writeAll("#define __ARM_NEON_FP 0xE\n");
            }
            if (comp.target.cpu.has(.aarch64, .bf16)) {
                try define(w, "__ARM_FEATURE_BF16");
                try define(w, "__ARM_FEATURE_BF16_VECTOR_ARITHMETIC");
                try define(w, "__ARM_BF16_FORMAT_ALTERNATIVE");
                try define(w, "__ARM_FEATURE_BF16_SCALAR_ARITHMETIC");
                if (comp.target.cpu.has(.aarch64, .sve)) {
                    try define(w, "__ARM_FEATURE_SVE_BF16");
                }
            }
            if (comp.target.cpu.hasAll(.aarch64, &.{ .sve2, .sve_aes })) {
                try define(w, "__ARM_FEATURE_SVE2_AES");
            }
            if (comp.target.cpu.hasAll(.aarch64, &.{ .sve2, .sve_bitperm })) {
                try define(w, "__ARM_FEATURE_SVE2_BITPERM");
            }
            if (comp.target.cpu.has(.aarch64, .sme)) {
                try define(w, "__ARM_FEATURE_SME");
                try define(w, "__ARM_FEATURE_LOCALLY_STREAMING");
            }
            if (comp.target.cpu.has(.aarch64, .fmv)) {
                try define(w, "__HAVE_FUNCTION_MULTI_VERSIONING");
            }
            if (comp.target.cpu.has(.aarch64, .sha3)) {
                try define(w, "__ARM_FEATURE_SHA3");
                try define(w, "__ARM_FEATURE_SHA512");
            }
            if (comp.target.cpu.has(.aarch64, .sm4)) {
                try define(w, "__ARM_FEATURE_SM3");
                try define(w, "__ARM_FEATURE_SM4");
            }
            if (!comp.target.cpu.has(.aarch64, .strict_align)) {
                try define(w, "__ARM_FEATURE_UNALIGNED");
            }
            if (comp.target.cpu.hasAll(.aarch64, &.{ .neon, .fullfp16 })) {
                try define(w, "__ARM_FEATURE_FP16_VECTOR_ARITHMETIC");
            }
            if (comp.target.cpu.has(.aarch64, .rcpc3)) {
                try w.writeAll("#define __ARM_FEATURE_RCPC 3\n");
            } else if (comp.target.cpu.has(.aarch64, .rcpc)) {
                try define(w, "__ARM_FEATURE_RCPC");
            }

            const features = comp.target.cpu.features;
            for ([_]struct { std.Target.aarch64.Feature, []const u8 }{
                .{ .sve, "SVE" },
                .{ .sve2, "SVE2" },
                .{ .sve2p1, "SVE2p1" },
                .{ .sve2_sha3, "SVE2_SHA3" },
                .{ .sve2_sm4, "SVE2_SM4" },
                .{ .sve_b16b16, "SVE_B16B16" },
                .{ .sme2, "SME2" },
                .{ .sme2p1, "SME2p1" },
                .{ .sme_f16f16, "SME_F16F16" },
                .{ .sme_b16b16, "SME_B16B16" },
                .{ .crc, "CRC32" },
                .{ .aes, "AES" },
                .{ .sha2, "SHA2" },
                .{ .pauth, "PAUTH" },
                .{ .pauth_lr, "PAUTH_LR" },
                .{ .bti, "BTI" },
                .{ .fullfp16, "FP16_SCALAR_ARITHMETIC" },
                .{ .dotprod, "DOTPROD" },
                .{ .mte, "MEMORY_TAGGING" },
                .{ .tme, "TME" },
                .{ .i8mm, "MATMUL_INT8" },
                .{ .lse, "ATOMICS" },
                .{ .f64mm, "SVE_MATMUL_FP64" },
                .{ .f32mm, "SVE_MATMUL_FP32" },
                .{ .i8mm, "SVE_MATMUL_INT8" },
                .{ .fp16fml, "FP16_FML" },
                .{ .ls64, "LS64" },
                .{ .rand, "RNG" },
                .{ .mops, "MOPS" },
                .{ .d128, "SYSREG128" },
                .{ .gcs, "GCS" },
            }) |fs| {
                if (features.isEnabled(@intFromEnum(fs[0]))) {
                    try w.print("#define __ARM_FEATURE_{s} 1\n", .{fs[1]});
                }
            }
        },
        .msp430 => {
            try define(w, "MSP430");
            try define(w, "__MSP430__");
        },
        .arc => {
            try define(w, "__arc__");
        },
        .wasm32, .wasm64 => {
            try define(w, "__wasm");
            try define(w, "__wasm__");
            if (comp.target.cpu.arch == .wasm32) {
                try define(w, "__wasm32");
                try define(w, "__wasm32__");
            } else {
                try define(w, "__wasm64");
                try define(w, "__wasm64__");
            }

            for (comp.target.cpu.arch.allFeaturesList()) |feature| {
                if (!comp.target.cpu.features.isEnabled(feature.index)) continue;
                try w.print("#define __wasm_{s}__ 1\n", .{feature.name});
            }
        },
        else => {},
    }

    if (ptr_width == 64 and comp.target.cTypeBitSize(.long) == 32) {
        try define(w, "_LP64");
        try define(w, "__LP64__");
    } else if (ptr_width == 32 and comp.target.cTypeBitSize(.long) == 32 and
        comp.target.cTypeBitSize(.int) == 32)
    {
        try define(w, "_ILP32");
        try define(w, "__ILP32__");
    }

    if (comp.hasFloat128()) {
        try define(w, "__FLOAT128__");
    }

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

    switch (comp.target.ofmt) {
        .elf => try define(w, "__ELF__"),
        .macho => try define(w, "__MACH__"),
        else => {},
    }

    if (comp.target.os.tag.isDarwin()) {
        try w.writeAll(
            \\#define __nonnull _Nonnull
            \\#define __null_unspecified _Null_unspecified
            \\#define __nullable _Nullable
            \\
        );
    }

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
    try comp.generateIntWidth(w, "BOOL", .bool);
    try comp.generateIntMaxAndWidth(w, "SCHAR", .schar);
    try comp.generateIntMaxAndWidth(w, "SHRT", .short);
    try comp.generateIntMaxAndWidth(w, "INT", .int);
    try comp.generateIntMaxAndWidth(w, "LONG", .long);
    try comp.generateIntMaxAndWidth(w, "LONG_LONG", .long_long);
    try comp.generateIntMaxAndWidth(w, "WCHAR", comp.type_store.wchar);
    // try comp.generateIntMax(w, "WINT", comp.type_store.wchar);
    try comp.generateIntMaxAndWidth(w, "INTMAX", comp.type_store.intmax);
    try comp.generateIntMaxAndWidth(w, "SIZE", comp.type_store.size);
    try comp.generateIntMaxAndWidth(w, "UINTMAX", try comp.type_store.intmax.makeIntUnsigned(comp));
    try comp.generateIntMaxAndWidth(w, "PTRDIFF", comp.type_store.ptrdiff);
    try comp.generateIntMaxAndWidth(w, "INTPTR", comp.type_store.intptr);
    try comp.generateIntMaxAndWidth(w, "UINTPTR", try comp.type_store.intptr.makeIntUnsigned(comp));
    try comp.generateIntMaxAndWidth(w, "SIG_ATOMIC", target_util.sigAtomicType(comp.target));

    // int widths
    try w.print("#define __BITINT_MAXWIDTH__ {d}\n", .{bit_int_max_bits});

    // sizeof types
    try comp.generateSizeofType(w, "__SIZEOF_FLOAT__", .float);
    try comp.generateSizeofType(w, "__SIZEOF_DOUBLE__", .double);
    try comp.generateSizeofType(w, "__SIZEOF_LONG_DOUBLE__", .long_double);
    try comp.generateSizeofType(w, "__SIZEOF_SHORT__", .short);
    try comp.generateSizeofType(w, "__SIZEOF_INT__", .int);
    try comp.generateSizeofType(w, "__SIZEOF_LONG__", .long);
    try comp.generateSizeofType(w, "__SIZEOF_LONG_LONG__", .long_long);
    try comp.generateSizeofType(w, "__SIZEOF_POINTER__", .void_pointer);
    try comp.generateSizeofType(w, "__SIZEOF_PTRDIFF_T__", comp.type_store.ptrdiff);
    try comp.generateSizeofType(w, "__SIZEOF_SIZE_T__", comp.type_store.size);
    try comp.generateSizeofType(w, "__SIZEOF_WCHAR_T__", comp.type_store.wchar);
    // try comp.generateSizeofType(w, "__SIZEOF_WINT_T__", .void_pointer);

    if (target_util.hasInt128(comp.target)) {
        try comp.generateSizeofType(w, "__SIZEOF_INT128__", .int128);
    }

    // various int types
    try comp.generateTypeMacro(w, "__INTPTR_TYPE__", comp.type_store.intptr);
    try comp.generateTypeMacro(w, "__UINTPTR_TYPE__", try comp.type_store.intptr.makeIntUnsigned(comp));

    try comp.generateTypeMacro(w, "__INTMAX_TYPE__", comp.type_store.intmax);
    try comp.generateSuffixMacro("__INTMAX", w, comp.type_store.intptr);

    try comp.generateTypeMacro(w, "__UINTMAX_TYPE__", try comp.type_store.intmax.makeIntUnsigned(comp));
    try comp.generateSuffixMacro("__UINTMAX", w, try comp.type_store.intptr.makeIntUnsigned(comp));

    try comp.generateTypeMacro(w, "__PTRDIFF_TYPE__", comp.type_store.ptrdiff);
    try comp.generateTypeMacro(w, "__SIZE_TYPE__", comp.type_store.size);
    try comp.generateTypeMacro(w, "__WCHAR_TYPE__", comp.type_store.wchar);
    try comp.generateTypeMacro(w, "__CHAR16_TYPE__", comp.type_store.uint_least16_t);
    try comp.generateTypeMacro(w, "__CHAR32_TYPE__", comp.type_store.uint_least32_t);

    try comp.generateExactWidthTypes(w);
    try comp.generateFastAndLeastWidthTypes(w);

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

    switch (comp.code_gen_options.pic_level) {
        .none => {},
        .one, .two => {
            try w.print(
                \\#define __pic__ {0d}
                \\#define __PIC__ {0d}
                \\
            , .{@intFromEnum(comp.code_gen_options.pic_level)});
            if (comp.code_gen_options.is_pie) {
                try w.print(
                    \\#define __pie__ {0d}
                    \\#define __PIE__ {0d}
                    \\
                , .{@intFromEnum(comp.code_gen_options.pic_level)});
            }
        },
    }
}

/// Generate builtin macros that will be available to each source file.
pub fn generateBuiltinMacros(comp: *Compilation, system_defines_mode: SystemDefinesMode) AddSourceError!Source {
    try comp.type_store.initNamedTypes(comp);

    var allocating: std.Io.Writer.Allocating = try .initCapacity(comp.gpa, 2 << 13);
    defer allocating.deinit();

    comp.writeBuiltinMacros(system_defines_mode, &allocating.writer) catch |err| switch (err) {
        error.WriteFailed, error.OutOfMemory => return error.OutOfMemory,
    };

    if (allocating.written().len > std.math.maxInt(u32)) return error.FileTooBig;

    const contents = try allocating.toOwnedSlice();
    errdefer comp.gpa.free(contents);
    return comp.addSourceFromOwnedBuffer("<builtin>", contents, .user);
}

fn writeBuiltinMacros(comp: *Compilation, system_defines_mode: SystemDefinesMode, w: *std.Io.Writer) !void {
    if (system_defines_mode == .include_system_defines) {
        try w.writeAll(
            \\#define __VERSION__ "Aro
        ++ " " ++ @import("../backend.zig").version_str ++ "\"\n" ++
            \\#define __Aro__
            \\
        );
    }

    if (comp.langopts.emulate != .msvc) {
        try w.writeAll("#define __STDC__ 1\n");
    }
    try w.print("#define __STDC_HOSTED__ {d}\n", .{@intFromBool(comp.target.os.tag != .freestanding)});

    // standard macros
    try w.writeAll(
        \\#define __STDC_UTF_16__ 1
        \\#define __STDC_UTF_32__ 1
        \\#define __STDC_EMBED_NOT_FOUND__ 0
        \\#define __STDC_EMBED_FOUND__ 1
        \\#define __STDC_EMBED_EMPTY__ 2
        \\
    );
    if (comp.langopts.standard.atLeast(.c11)) switch (comp.target.os.tag) {
        .openbsd, .driverkit, .ios, .macos, .tvos, .visionos, .watchos => {
            try w.writeAll("#define __STDC_NO_THREADS__ 1\n");
        },
        .ps4, .ps5 => {
            try w.writeAll(
                \\#define __STDC_NO_THREADS__ 1
                \\#define __STDC_NO_COMPLEX__ 1
                \\
            );
        },
        .aix => {
            try w.writeAll(
                \\#define __STDC_NO_THREADS__ 1
                \\#define __STDC_NO_ATOMICS__ 1
                \\
            );
        },
        else => {},
    };
    if (comp.langopts.standard.StdCVersionMacro()) |stdc_version| {
        try w.writeAll("#define __STDC_VERSION__ ");
        try w.writeAll(stdc_version);
        try w.writeByte('\n');
    }

    if (system_defines_mode == .include_system_defines) {
        try comp.generateSystemDefines(w);
    }
}

fn generateFloatMacros(w: *std.Io.Writer, prefix: []const u8, semantics: target_util.FPSemantics, ext: []const u8) !void {
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

    try w.print("#define __{s}_DENORM_MIN__ {s}{s}\n", .{ prefix, denormMin, ext });
    try w.print("#define __{s}_HAS_DENORM__\n", .{prefix});
    try w.print("#define __{s}_DIG__ {d}\n", .{ prefix, digits });
    try w.print("#define __{s}_DECIMAL_DIG__ {d}\n", .{ prefix, decimalDigits });

    try w.print("#define __{s}_EPSILON__ {s}{s}\n", .{ prefix, epsilon, ext });
    try w.print("#define __{s}_HAS_INFINITY__\n", .{prefix});
    try w.print("#define __{s}_HAS_QUIET_NAN__\n", .{prefix});
    try w.print("#define __{s}_MANT_DIG__ {d}\n", .{ prefix, mantissaDigits });

    try w.print("#define __{s}_MAX_10_EXP__ {d}\n", .{ prefix, max10Exp });
    try w.print("#define __{s}_MAX_EXP__ {d}\n", .{ prefix, maxExp });
    try w.print("#define __{s}_MAX__ {s}{s}\n", .{ prefix, max, ext });

    try w.print("#define __{s}_MIN_10_EXP__ ({d})\n", .{ prefix, min10Exp });
    try w.print("#define __{s}_MIN_EXP__ ({d})\n", .{ prefix, minExp });
    try w.print("#define __{s}_MIN__ {s}{s}\n", .{ prefix, min, ext });
}

fn generateTypeMacro(comp: *const Compilation, w: *std.Io.Writer, name: []const u8, qt: QualType) !void {
    try w.print("#define {s} ", .{name});
    try qt.print(comp, w);
    try w.writeByte('\n');
}

pub fn float80Type(comp: *const Compilation) ?QualType {
    if (comp.langopts.emulate != .gcc) return null;
    return target_util.float80Type(comp.target);
}

/// Smallest integer type with at least N bits
pub fn intLeastN(comp: *const Compilation, bits: usize, signedness: std.builtin.Signedness) QualType {
    if (bits == 64 and (comp.target.os.tag.isDarwin() or comp.target.cpu.arch.isWasm())) {
        // WebAssembly and Darwin use `long long` for `int_least64_t` and `int_fast64_t`.
        return if (signedness == .signed) .long_long else .ulong_long;
    }
    if (bits == 16 and comp.target.cpu.arch == .avr) {
        // AVR uses int for int_least16_t and int_fast16_t.
        return if (signedness == .signed) .int else .uint;
    }
    const candidates: [5]QualType = switch (signedness) {
        .signed => .{ .schar, .short, .int, .long, .long_long },
        .unsigned => .{ .uchar, .ushort, .uint, .ulong, .ulong_long },
    };
    for (candidates) |qt| {
        if (qt.bitSizeof(comp) >= bits) return qt;
    } else unreachable;
}

fn generateFastOrLeastType(
    comp: *Compilation,
    bits: usize,
    kind: enum { least, fast },
    signedness: std.builtin.Signedness,
    w: *std.Io.Writer,
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
    }) catch unreachable;

    try comp.generateTypeMacro(w, full, ty);

    const prefix = full[2 .. full.len - suffix.len]; // remove "__" and "_TYPE__"

    switch (signedness) {
        .signed => try comp.generateIntMaxAndWidth(w, prefix, ty),
        .unsigned => try comp.generateIntMax(w, prefix, ty),
    }
    try comp.generateFmt(prefix, w, ty);
}

fn generateFastAndLeastWidthTypes(comp: *Compilation, w: *std.Io.Writer) !void {
    const sizes = [_]usize{ 8, 16, 32, 64 };
    for (sizes) |size| {
        try comp.generateFastOrLeastType(size, .least, .signed, w);
        try comp.generateFastOrLeastType(size, .least, .unsigned, w);
        try comp.generateFastOrLeastType(size, .fast, .signed, w);
        try comp.generateFastOrLeastType(size, .fast, .unsigned, w);
    }
}

fn generateExactWidthTypes(comp: *Compilation, w: *std.Io.Writer) !void {
    try comp.generateExactWidthType(w, .schar);

    if (QualType.short.sizeof(comp) > QualType.char.sizeof(comp)) {
        try comp.generateExactWidthType(w, .short);
    }

    if (QualType.int.sizeof(comp) > QualType.short.sizeof(comp)) {
        try comp.generateExactWidthType(w, .int);
    }

    if (QualType.long.sizeof(comp) > QualType.int.sizeof(comp)) {
        try comp.generateExactWidthType(w, .long);
    }

    if (QualType.long_long.sizeof(comp) > QualType.long.sizeof(comp)) {
        try comp.generateExactWidthType(w, .long_long);
    }

    try comp.generateExactWidthType(w, .uchar);
    try comp.generateExactWidthIntMax(w, .uchar);
    try comp.generateExactWidthIntMax(w, .schar);

    if (QualType.short.sizeof(comp) > QualType.char.sizeof(comp)) {
        try comp.generateExactWidthType(w, .ushort);
        try comp.generateExactWidthIntMax(w, .ushort);
        try comp.generateExactWidthIntMax(w, .short);
    }

    if (QualType.int.sizeof(comp) > QualType.short.sizeof(comp)) {
        try comp.generateExactWidthType(w, .uint);
        try comp.generateExactWidthIntMax(w, .uint);
        try comp.generateExactWidthIntMax(w, .int);
    }

    if (QualType.long.sizeof(comp) > QualType.int.sizeof(comp)) {
        try comp.generateExactWidthType(w, .ulong);
        try comp.generateExactWidthIntMax(w, .ulong);
        try comp.generateExactWidthIntMax(w, .long);
    }

    if (QualType.long_long.sizeof(comp) > QualType.long.sizeof(comp)) {
        try comp.generateExactWidthType(w, .ulong_long);
        try comp.generateExactWidthIntMax(w, .ulong_long);
        try comp.generateExactWidthIntMax(w, .long_long);
    }
}

fn generateFmt(comp: *const Compilation, prefix: []const u8, w: *std.Io.Writer, qt: QualType) !void {
    const unsigned = qt.signedness(comp) == .unsigned;
    const modifier = qt.formatModifier(comp);
    const formats = if (unsigned) "ouxX" else "di";
    for (formats) |c| {
        try w.print("#define {s}_FMT{c}__ \"{s}{c}\"\n", .{ prefix, c, modifier, c });
    }
}

fn generateSuffixMacro(comp: *const Compilation, prefix: []const u8, w: *std.Io.Writer, qt: QualType) !void {
    return w.print("#define {s}_C_SUFFIX__ {s}\n", .{ prefix, qt.intValueSuffix(comp) });
}

/// Generate the following for a type:
///     Name macro (e.g. #define __UINT32_TYPE__ unsigned int)
///     Format strings (e.g. #define __UINT32_FMTu__ "u")
///     Suffix macro (e.g. #define __UINT32_C_SUFFIX__ U)
fn generateExactWidthType(comp: *Compilation, w: *std.Io.Writer, original_qt: QualType) !void {
    var qt = original_qt;
    const width = qt.sizeof(comp) * 8;
    const unsigned = qt.signedness(comp) == .unsigned;

    if (width == 16) {
        qt = if (unsigned) try comp.type_store.int16.makeIntUnsigned(comp) else comp.type_store.int16;
    } else if (width == 64) {
        qt = if (unsigned) try comp.type_store.int64.makeIntUnsigned(comp) else comp.type_store.int64;
    }

    var buffer: [16]u8 = undefined;
    const suffix = "_TYPE__";
    const full = std.fmt.bufPrint(&buffer, "{s}{d}{s}", .{
        if (unsigned) "__UINT" else "__INT", width, suffix,
    }) catch unreachable;

    try comp.generateTypeMacro(w, full, qt);

    const prefix = full[0 .. full.len - suffix.len]; // remove "_TYPE__"

    try comp.generateFmt(prefix, w, qt);
    try comp.generateSuffixMacro(prefix, w, qt);
}

pub fn hasFloat128(comp: *const Compilation) bool {
    return target_util.hasFloat128(comp.target);
}

pub fn hasHalfPrecisionFloatABI(comp: *const Compilation) bool {
    return comp.langopts.allow_half_args_and_returns or target_util.hasHalfPrecisionFloatABI(comp.target);
}

fn generateIntMax(comp: *const Compilation, w: *std.Io.Writer, name: []const u8, qt: QualType) !void {
    const unsigned = qt.signedness(comp) == .unsigned;
    const max: u128 = switch (qt.bitSizeof(comp)) {
        8 => if (unsigned) std.math.maxInt(u8) else std.math.maxInt(i8),
        16 => if (unsigned) std.math.maxInt(u16) else std.math.maxInt(i16),
        32 => if (unsigned) std.math.maxInt(u32) else std.math.maxInt(i32),
        64 => if (unsigned) std.math.maxInt(u64) else std.math.maxInt(i64),
        128 => if (unsigned) std.math.maxInt(u128) else std.math.maxInt(i128),
        else => unreachable,
    };
    try w.print("#define __{s}_MAX__ {d}{s}\n", .{ name, max, qt.intValueSuffix(comp) });
}

/// Largest value that can be stored in wchar_t
pub fn wcharMax(comp: *const Compilation) u32 {
    const unsigned = comp.type_store.wchar.signedness(comp) == .unsigned;
    return switch (comp.type_store.wchar.bitSizeof(comp)) {
        8 => if (unsigned) std.math.maxInt(u8) else std.math.maxInt(i8),
        16 => if (unsigned) std.math.maxInt(u16) else std.math.maxInt(i16),
        32 => if (unsigned) std.math.maxInt(u32) else std.math.maxInt(i32),
        else => unreachable,
    };
}

fn generateExactWidthIntMax(comp: *Compilation, w: *std.Io.Writer, original_qt: QualType) !void {
    var qt = original_qt;
    const bit_count: u8 = @intCast(qt.sizeof(comp) * 8);
    const unsigned = qt.signedness(comp) == .unsigned;

    if (bit_count == 64) {
        qt = if (unsigned) try comp.type_store.int64.makeIntUnsigned(comp) else comp.type_store.int64;
    }

    var name_buffer: [6]u8 = undefined;
    const name = std.fmt.bufPrint(&name_buffer, "{s}{d}", .{
        if (unsigned) "UINT" else "INT", bit_count,
    }) catch unreachable;

    return comp.generateIntMax(w, name, qt);
}

fn generateIntWidth(comp: *Compilation, w: *std.Io.Writer, name: []const u8, qt: QualType) !void {
    try w.print("#define __{s}_WIDTH__ {d}\n", .{ name, qt.sizeof(comp) * 8 });
}

fn generateIntMaxAndWidth(comp: *Compilation, w: *std.Io.Writer, name: []const u8, qt: QualType) !void {
    try comp.generateIntMax(w, name, qt);
    try comp.generateIntWidth(w, name, qt);
}

fn generateSizeofType(comp: *Compilation, w: *std.Io.Writer, name: []const u8, qt: QualType) !void {
    try w.print("#define {s} {d}\n", .{ name, qt.sizeof(comp) });
}

pub fn nextLargestIntSameSign(comp: *const Compilation, qt: QualType) ?QualType {
    assert(qt.isInt(comp));
    const candidates: [4]QualType = if (qt.signedness(comp) == .signed)
        .{ .short, .int, .long, .long_long }
    else
        .{ .ushort, .uint, .ulong, .ulong_long };

    const size = qt.sizeof(comp);
    for (candidates) |candidate| {
        if (candidate.sizeof(comp) > size) return candidate;
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
pub fn fixedEnumTagType(comp: *const Compilation) ?QualType {
    switch (comp.langopts.emulate) {
        .msvc => return .int,
        .clang => if (comp.target.os.tag == .windows) return .int,
        .gcc => {},
    }
    return null;
}

pub fn getCharSignedness(comp: *const Compilation) std.builtin.Signedness {
    return comp.langopts.char_signedness_override orelse comp.target.cCharSignedness();
}

/// Add built-in aro headers directory to system include paths
pub fn addBuiltinIncludeDir(comp: *Compilation, aro_dir: []const u8, override_resource_dir: ?[]const u8) !void {
    const gpa = comp.gpa;
    const arena = comp.arena;
    try comp.system_include_dirs.ensureUnusedCapacity(gpa, 1);
    if (override_resource_dir) |resource_dir| {
        comp.system_include_dirs.appendAssumeCapacity(try std.fs.path.join(arena, &.{ resource_dir, "include" }));
        return;
    }
    var search_path = aro_dir;
    while (std.fs.path.dirname(search_path)) |dirname| : (search_path = dirname) {
        var base_dir = comp.cwd.openDir(dirname, .{}) catch continue;
        defer base_dir.close();

        base_dir.access("include/stddef.h", .{}) catch continue;
        comp.system_include_dirs.appendAssumeCapacity(try std.fs.path.join(arena, &.{ dirname, "include" }));
        break;
    } else return error.AroIncludeNotFound;
}

pub fn addSystemIncludeDir(comp: *Compilation, path: []const u8) !void {
    try comp.system_include_dirs.append(comp.gpa, try comp.arena.dupe(u8, path));
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

/// Creates a Source from `buf` and adds it to the Compilation
/// Performs newline splicing and line-ending normalization to '\n'
/// `buf` will be modified and the allocation will be resized if newline splicing
/// or line-ending changes happen.
/// caller retains ownership of `path`
/// To add a file's contents given its path, see addSourceFromPath
pub fn addSourceFromOwnedBuffer(comp: *Compilation, path: []const u8, buf: []u8, kind: Source.Kind) !Source {
    assert(buf.len <= std.math.maxInt(u32));
    try comp.sources.ensureUnusedCapacity(comp.gpa, 1);

    var contents = buf;
    const duped_path = try comp.gpa.dupe(u8, path);
    errdefer comp.gpa.free(duped_path);

    var splice_list: std.ArrayList(u32) = .empty;
    defer splice_list.deinit(comp.gpa);

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
                        try splice_list.append(comp.gpa, i);
                        if (state == .trailing_ws) {
                            try comp.addNewlineEscapeError(path, buf, splice_list.items, i, line, kind);
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
                            try splice_list.append(comp.gpa, i);
                        }
                        if (state == .trailing_ws) {
                            try comp.addNewlineEscapeError(path, buf, splice_list.items, i, line, kind);
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

    const splice_locs = try splice_list.toOwnedSlice(comp.gpa);
    errdefer comp.gpa.free(splice_locs);

    if (i != contents.len) {
        var list: std.ArrayList(u8) = .{
            .items = contents[0..i],
            .capacity = contents.len,
        };
        contents = try list.toOwnedSlice(comp.gpa);
    }
    errdefer @compileError("errdefers in callers would possibly free the realloced slice using the original len");

    const source: Source = .{
        .id = source_id,
        .path = duped_path,
        .buf = contents,
        .splice_locs = splice_locs,
        .kind = kind,
    };

    comp.sources.putAssumeCapacityNoClobber(duped_path, source);
    return source;
}

fn addNewlineEscapeError(
    comp: *Compilation,
    path: []const u8,
    buf: []const u8,
    splice_locs: []const u32,
    byte_offset: u32,
    line: u32,
    kind: Source.Kind,
) !void {
    // Temporary source for getting the location for errors.
    var tmp_source: Source = .{
        .path = path,
        .buf = buf,
        .id = undefined,
        .kind = kind,
        .splice_locs = splice_locs,
    };

    const diagnostic: Diagnostic = .backslash_newline_escape;
    var loc = tmp_source.lineCol(.{ .id = undefined, .byte_offset = byte_offset, .line = line });
    loc.line = loc.line[0 .. loc.line.len - 1];
    loc.width += 1;
    loc.col += 1;

    try comp.diagnostics.add(.{
        .text = diagnostic.fmt,
        .kind = diagnostic.kind,
        .opt = diagnostic.opt,
        .location = loc,
    });
}

/// Caller retains ownership of `path` and `buf`.
/// Dupes the source buffer; if it is acceptable to modify the source buffer and possibly resize
/// the allocation, please use `addSourceFromOwnedBuffer`
pub fn addSourceFromBuffer(comp: *Compilation, path: []const u8, buf: []const u8) AddSourceError!Source {
    if (comp.sources.get(path)) |some| return some;
    if (buf.len > std.math.maxInt(u32)) return error.FileTooBig;

    const contents = try comp.gpa.dupe(u8, buf);
    errdefer comp.gpa.free(contents);

    return comp.addSourceFromOwnedBuffer(path, contents, .user);
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
    return comp.addSourceFromFile(file, path, kind);
}

pub fn addSourceFromFile(comp: *Compilation, file: std.fs.File, path: []const u8, kind: Source.Kind) !Source {
    const contents = try comp.getFileContents(file, .unlimited);
    errdefer comp.gpa.free(contents);
    return comp.addSourceFromOwnedBuffer(path, contents, kind);
}

pub fn hasInclude(
    comp: *Compilation,
    filename: []const u8,
    includer_token_source: Source.Id,
    /// angle bracket vs quotes
    include_type: IncludeType,
    /// __has_include vs __has_include_next
    which: WhichInclude,
    opt_dep_file: ?*DepFile,
) Compilation.Error!bool {
    if (try FindInclude.run(comp, filename, include_type, switch (which) {
        .next => .{ .only_search_after_dir = comp.getSource(includer_token_source).path },
        .first => switch (include_type) {
            .quotes => .{ .allow_same_dir = comp.getSource(includer_token_source).path },
            .angle_brackets => .only_search,
        },
    })) |found| {
        if (opt_dep_file) |dep_file| {
            const source = comp.getSource(found.source);
            try dep_file.addDependency(comp.gpa, source.path);
        }
        return true;
    } else {
        return false;
    }
}

const FindInclude = struct {
    comp: *Compilation,
    include_path: []const u8,
    /// We won't actually consider any include directories until after this directory.
    wait_for: ?[]const u8,

    const Result = struct {
        source: Source.Id,
        kind: Source.Kind,
        used_ms_search_rule: bool,
    };

    fn run(
        comp: *Compilation,
        include_path: []const u8,
        include_type: IncludeType,
        search_strat: union(enum) {
            allow_same_dir: []const u8,
            only_search,
            only_search_after_dir: []const u8,
        },
    ) Allocator.Error!?Result {
        var find: FindInclude = .{
            .comp = comp,
            .include_path = include_path,
            .wait_for = null,
        };

        if (std.fs.path.isAbsolute(include_path)) {
            switch (search_strat) {
                .allow_same_dir, .only_search => {},
                .only_search_after_dir => return null,
            }
            return find.check("{s}", .{include_path}, .user, false);
        }

        switch (search_strat) {
            .allow_same_dir => |other_file| {
                const dir = std.fs.path.dirname(other_file) orelse ".";
                if (try find.checkIncludeDir(dir, .user)) |res| return res;
            },
            .only_search => {},
            .only_search_after_dir => |other_file| {
                // TODO: this is not the correct interpretation of `#include_next` and friends,
                // because a file might not be directly inside of an include directory. To implement
                // this correctly, we will need to track which include directory a file has been
                // included from.
                find.wait_for = std.fs.path.dirname(other_file);
            },
        }
        switch (include_type) {
            .quotes => for (comp.iquote_include_dirs.items) |dir| {
                if (try find.checkIncludeDir(dir, .user)) |res| return res;
            },
            .angle_brackets => {},
        }
        for (comp.include_dirs.items) |dir| {
            if (try find.checkIncludeDir(dir, .user)) |res| return res;
        }
        for (comp.framework_dirs.items) |dir| {
            if (try find.checkFrameworkDir(dir, .user)) |res| return res;
        }
        for (comp.system_include_dirs.items) |dir| {
            if (try find.checkIncludeDir(dir, .system)) |res| return res;
        }
        for (comp.system_framework_dirs.items) |dir| {
            if (try find.checkFrameworkDir(dir, .system)) |res| return res;
        }
        for (comp.after_include_dirs.items) |dir| {
            if (try find.checkIncludeDir(dir, .system)) |res| return res;
        }
        if (comp.ms_cwd_source_id) |source_id| {
            if (try find.checkMsCwdIncludeDir(source_id)) |res| return res;
        }
        return null;
    }
    fn checkIncludeDir(find: *FindInclude, include_dir: []const u8, kind: Source.Kind) Allocator.Error!?Result {
        if (find.wait_for) |wait_for| {
            if (std.mem.eql(u8, include_dir, wait_for)) find.wait_for = null;
            return null;
        }
        return find.check("{s}{c}{s}", .{
            include_dir,
            std.fs.path.sep,
            find.include_path,
        }, kind, false);
    }
    fn checkMsCwdIncludeDir(find: *FindInclude, source_id: Source.Id) Allocator.Error!?Result {
        const path = find.comp.getSource(source_id).path;
        const dir = std.fs.path.dirname(path) orelse ".";
        if (find.wait_for) |wait_for| {
            if (std.mem.eql(u8, dir, wait_for)) find.wait_for = null;
            return null;
        }
        return find.check("{s}{c}{s}", .{
            dir,
            std.fs.path.sep,
            find.include_path,
        }, .user, true);
    }
    fn checkFrameworkDir(find: *FindInclude, framework_dir: []const u8, kind: Source.Kind) Allocator.Error!?Result {
        if (find.wait_for) |wait_for| {
            match: {
                // If this is a match, then `wait_for` looks like '.../Foo.framework/Headers'.
                const wait_framework = std.fs.path.dirname(wait_for) orelse break :match;
                const wait_framework_dir = std.fs.path.dirname(wait_framework) orelse break :match;
                if (!std.mem.eql(u8, framework_dir, wait_framework_dir)) break :match;
                find.wait_for = null;
            }
            return null;
        }
        // For an include like 'Foo/Bar.h', search in '<framework_dir>/Foo.framework/Headers/Bar.h'.
        const framework_name: []const u8, const header_sub_path: []const u8 = f: {
            const i = std.mem.indexOfScalar(u8, find.include_path, '/') orelse return null;
            break :f .{ find.include_path[0..i], find.include_path[i + 1 ..] };
        };
        return find.check("{s}{c}{s}.framework{c}Headers{c}{s}", .{
            framework_dir,
            std.fs.path.sep,
            framework_name,
            std.fs.path.sep,
            std.fs.path.sep,
            header_sub_path,
        }, kind, false);
    }
    fn check(
        find: *FindInclude,
        comptime format: []const u8,
        args: anytype,
        kind: Source.Kind,
        used_ms_search_rule: bool,
    ) Allocator.Error!?Result {
        const comp = find.comp;

        var stack_fallback = std.heap.stackFallback(path_buf_stack_limit, comp.gpa);
        const sfa = stack_fallback.get();
        const header_path = try std.fmt.allocPrint(sfa, format, args);
        defer sfa.free(header_path);

        if (find.comp.langopts.ms_extensions) {
            std.mem.replaceScalar(u8, header_path, '\\', '/');
        }
        const source = comp.addSourceFromPathExtra(header_path, kind) catch |err| switch (err) {
            error.OutOfMemory => |e| return e,
            else => return null,
        };
        return .{
            .source = source.id,
            .kind = kind,
            .used_ms_search_rule = used_ms_search_rule,
        };
    }
};

pub const WhichInclude = enum {
    first,
    next,
};

pub const IncludeType = enum {
    quotes,
    angle_brackets,
};

fn getPathContents(comp: *Compilation, path: []const u8, limit: std.Io.Limit) ![]u8 {
    if (mem.indexOfScalar(u8, path, 0) != null) {
        return error.FileNotFound;
    }

    const file = try comp.cwd.openFile(path, .{});
    defer file.close();
    return comp.getFileContents(file, limit);
}

fn getFileContents(comp: *Compilation, file: std.fs.File, limit: std.Io.Limit) ![]u8 {
    var file_buf: [4096]u8 = undefined;
    var file_reader = file.reader(&file_buf);

    var allocating: std.Io.Writer.Allocating = .init(comp.gpa);
    defer allocating.deinit();
    if (file_reader.getSize()) |size| {
        const limited_size = limit.minInt64(size);
        if (limited_size > std.math.maxInt(u32)) return error.FileTooBig;
        try allocating.ensureUnusedCapacity(limited_size);
    } else |_| {}

    var remaining = limit.min(.limited(std.math.maxInt(u32)));
    while (remaining.nonzero()) {
        const n = file_reader.interface.stream(&allocating.writer, remaining) catch |err| switch (err) {
            error.EndOfStream => return allocating.toOwnedSlice(),
            error.WriteFailed => return error.OutOfMemory,
            error.ReadFailed => return file_reader.err.?,
        };
        remaining = remaining.subtract(n).?;
    }
    if (limit == .unlimited) return error.FileTooBig;
    return allocating.toOwnedSlice();
}

pub fn findEmbed(
    comp: *Compilation,
    filename: []const u8,
    includer_token_source: Source.Id,
    /// angle bracket vs quotes
    include_type: IncludeType,
    limit: std.Io.Limit,
    opt_dep_file: ?*DepFile,
) !?[]u8 {
    if (std.fs.path.isAbsolute(filename)) {
        if (comp.getPathContents(filename, limit)) |some| {
            errdefer comp.gpa.free(some);
            if (opt_dep_file) |dep_file| try dep_file.addDependencyDupe(comp.gpa, comp.arena, filename);
            return some;
        } else |err| switch (err) {
            error.OutOfMemory => |e| return e,
            else => return null,
        }
    }

    var stack_fallback = std.heap.stackFallback(path_buf_stack_limit, comp.gpa);
    const sf_allocator = stack_fallback.get();

    switch (include_type) {
        .quotes => {
            const dir = std.fs.path.dirname(comp.getSource(includer_token_source).path) orelse ".";
            const path = try std.fs.path.join(sf_allocator, &.{ dir, filename });
            defer sf_allocator.free(path);
            if (comp.langopts.ms_extensions) {
                std.mem.replaceScalar(u8, path, '\\', '/');
            }
            if (comp.getPathContents(path, limit)) |some| {
                errdefer comp.gpa.free(some);
                if (opt_dep_file) |dep_file| try dep_file.addDependencyDupe(comp.gpa, comp.arena, filename);
                return some;
            } else |err| switch (err) {
                error.OutOfMemory => return error.OutOfMemory,
                else => {},
            }
        },
        .angle_brackets => {},
    }
    for (comp.embed_dirs.items) |embed_dir| {
        const path = try std.fs.path.join(sf_allocator, &.{ embed_dir, filename });
        defer sf_allocator.free(path);
        if (comp.langopts.ms_extensions) {
            std.mem.replaceScalar(u8, path, '\\', '/');
        }
        if (comp.getPathContents(path, limit)) |some| {
            errdefer comp.gpa.free(some);
            if (opt_dep_file) |dep_file| try dep_file.addDependencyDupe(comp.gpa, comp.arena, filename);
            return some;
        } else |err| switch (err) {
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
) Compilation.Error!?Source {
    const found = try FindInclude.run(comp, filename, include_type, switch (which) {
        .next => .{ .only_search_after_dir = comp.getSource(includer_token.source).path },
        .first => switch (include_type) {
            .quotes => .{ .allow_same_dir = comp.getSource(includer_token.source).path },
            .angle_brackets => .only_search,
        },
    }) orelse return null;
    if (found.used_ms_search_rule) {
        const diagnostic: Diagnostic = .ms_search_rule;
        try comp.diagnostics.add(.{
            .text = diagnostic.fmt,
            .kind = diagnostic.kind,
            .opt = diagnostic.opt,
            .extension = diagnostic.extension,
            .location = (Source.Location{
                .id = includer_token.source,
                .byte_offset = includer_token.start,
                .line = includer_token.line,
            }).expand(comp),
        });
    }
    return comp.getSource(found.source);
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

pub fn getSourceMTimeUncached(comp: *const Compilation, source_id: Source.Id) ?u64 {
    const source = comp.getSource(source_id);
    if (comp.cwd.statFile(source.path)) |stat| {
        const mtime = @divTrunc(stat.mtime, std.time.ns_per_s);
        return std.math.cast(u64, mtime);
    } else |_| {
        return null;
    }
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

pub const Diagnostic = struct {
    fmt: []const u8,
    kind: Diagnostics.Message.Kind,
    opt: ?Diagnostics.Option = null,
    extension: bool = false,

    pub const backslash_newline_escape: Diagnostic = .{
        .fmt = "backslash and newline separated by space",
        .kind = .warning,
        .opt = .@"backslash-newline-escape",
    };

    pub const ms_search_rule: Diagnostic = .{
        .fmt = "#include resolved using non-portable Microsoft search rules as: {s}",
        .kind = .warning,
        .opt = .@"microsoft-include",
        .extension = true,
    };

    pub const ctrl_z_eof: Diagnostic = .{
        .fmt = "treating Ctrl-Z as end-of-file is a Microsoft extension",
        .kind = .off,
        .opt = .@"microsoft-end-of-file",
        .extension = true,
    };
};

test "addSourceFromBuffer" {
    const Test = struct {
        fn addSourceFromBuffer(str: []const u8, expected: []const u8, warning_count: u32, splices: []const u32) !void {
            var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
            defer arena.deinit();
            var diagnostics: Diagnostics = .{ .output = .ignore };
            var comp = Compilation.init(std.testing.allocator, arena.allocator(), &diagnostics, std.fs.cwd());
            defer comp.deinit();

            const source = try comp.addSourceFromBuffer("path", str);

            try std.testing.expectEqualStrings(expected, source.buf);
            try std.testing.expectEqual(warning_count, @as(u32, @intCast(diagnostics.warnings)));
            try std.testing.expectEqualSlices(u32, splices, source.splice_locs);
        }

        fn withAllocationFailures(allocator: std.mem.Allocator) !void {
            var arena: std.heap.ArenaAllocator = .init(allocator);
            defer arena.deinit();
            var diagnostics: Diagnostics = .{ .output = .ignore };
            var comp = Compilation.init(allocator, arena.allocator(), &diagnostics, std.fs.cwd());
            defer comp.deinit();

            _ = try comp.addSourceFromBuffer("path", "spliced\\\nbuffer\n");
            _ = try comp.addSourceFromBuffer("path", "non-spliced buffer\n");
        }
    };
    try Test.addSourceFromBuffer("ab\\\nc", "abc", 0, &.{2});
    try Test.addSourceFromBuffer("ab\\\rc", "abc", 0, &.{2});
    try Test.addSourceFromBuffer("ab\\\r\nc", "abc", 0, &.{2});
    try Test.addSourceFromBuffer("ab\\ \nc", "abc", 1, &.{2});
    try Test.addSourceFromBuffer("ab\\\t\nc", "abc", 1, &.{2});
    try Test.addSourceFromBuffer("ab\\                     \t\nc", "abc", 1, &.{2});
    try Test.addSourceFromBuffer("ab\\\r \nc", "ab \nc", 0, &.{2});
    try Test.addSourceFromBuffer("ab\\\\\nc", "ab\\c", 0, &.{3});
    try Test.addSourceFromBuffer("ab\\   \r\nc", "abc", 1, &.{2});
    try Test.addSourceFromBuffer("ab\\ \\\nc", "ab\\ c", 0, &.{4});
    try Test.addSourceFromBuffer("ab\\\r\\\nc", "abc", 0, &.{ 2, 2 });
    try Test.addSourceFromBuffer("ab\\  \rc", "abc", 1, &.{2});
    try Test.addSourceFromBuffer("ab\\", "ab\\", 0, &.{});
    try Test.addSourceFromBuffer("ab\\\\", "ab\\\\", 0, &.{});
    try Test.addSourceFromBuffer("ab\\ ", "ab\\ ", 0, &.{});
    try Test.addSourceFromBuffer("ab\\\n", "ab", 0, &.{2});
    try Test.addSourceFromBuffer("ab\\\r\n", "ab", 0, &.{2});
    try Test.addSourceFromBuffer("ab\\\r", "ab", 0, &.{2});

    // carriage return normalization
    try Test.addSourceFromBuffer("ab\r", "ab\n", 0, &.{});
    try Test.addSourceFromBuffer("ab\r\r", "ab\n\n", 0, &.{});
    try Test.addSourceFromBuffer("ab\r\r\n", "ab\n\n", 0, &.{});
    try Test.addSourceFromBuffer("ab\r\r\n\r", "ab\n\n\n", 0, &.{});
    try Test.addSourceFromBuffer("\r\\", "\n\\", 0, &.{});
    try Test.addSourceFromBuffer("\\\r\\", "\\", 0, &.{0});

    try std.testing.checkAllAllocationFailures(std.testing.allocator, Test.withAllocationFailures, .{});
}

test "addSourceFromBuffer - exhaustive check for carriage return elimination" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();

    const alphabet = [_]u8{ '\r', '\n', ' ', '\\', 'a' };
    const alen = alphabet.len;
    var buf: [alphabet.len]u8 = [1]u8{alphabet[0]} ** alen;

    var diagnostics: Diagnostics = .{ .output = .ignore };
    var comp = Compilation.init(std.testing.allocator, arena.allocator(), &diagnostics, std.fs.cwd());
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
        fn run(arena: Allocator, buf: []const u8) !void {
            var diagnostics: Diagnostics = .{ .output = .ignore };
            var comp = Compilation.init(std.testing.allocator, arena, &diagnostics, std.fs.cwd());
            defer comp.deinit();

            const source = try comp.addSourceFromBuffer("file.c", buf);
            const expected_output = if (mem.startsWith(u8, buf, BOM)) buf[BOM.len..] else buf;
            try std.testing.expectEqualStrings(expected_output, source.buf);
        }
    };

    var arena_state: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();

    try Test.run(arena, BOM);
    try Test.run(arena, BOM ++ "x");
    try Test.run(arena, "x" ++ BOM);
    try Test.run(arena, BOM ++ " ");
    try Test.run(arena, BOM ++ "\n");
    try Test.run(arena, BOM ++ "\\");

    try Test.run(arena, BOM[0..1] ++ "x");
    try Test.run(arena, BOM[0..2] ++ "x");
    try Test.run(arena, BOM[1..] ++ "x");
    try Test.run(arena, BOM[2..] ++ "x");
}

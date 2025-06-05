//! Corresponds to something that Zig source code can `@import`.

/// The root directory of the module. Only files inside this directory can be imported.
root: Compilation.Path,
/// Path to the root source file of this module. Relative to `root`. May contain path separators.
root_src_path: []const u8,
/// Name used in compile errors. Looks like "root.foo.bar".
fully_qualified_name: []const u8,
/// The dependency table of this module. The shared dependencies 'std' and
/// 'root' are not specified in every module dependency table, but are stored
/// separately in `Zcu`. 'builtin' is also not stored here, although it is
/// not necessarily the same between all modules. Handling of `@import` in
/// the rest of the compiler must detect these special names and use the
/// correct module instead of consulting `deps`.
deps: Deps = .{},

resolved_target: ResolvedTarget,
optimize_mode: std.builtin.OptimizeMode,
code_model: std.builtin.CodeModel,
single_threaded: bool,
error_tracing: bool,
valgrind: bool,
pic: bool,
strip: bool,
omit_frame_pointer: bool,
stack_check: bool,
stack_protector: u32,
red_zone: bool,
sanitize_c: std.zig.SanitizeC,
sanitize_thread: bool,
sanitize_address: bool,
fuzz: bool,
unwind_tables: std.builtin.UnwindTables,
cc_argv: []const []const u8,
/// (SPIR-V) whether to generate a structured control flow graph or not
structured_cfg: bool,
no_builtin: bool,

pub const Deps = std.StringArrayHashMapUnmanaged(*Module);

pub const Tree = struct {
    /// Each `Package` exposes a `Module` with build.zig as its root source file.
    build_module_table: std.AutoArrayHashMapUnmanaged(MultiHashHexDigest, *Module),
};

pub const CreateOptions = struct {
    paths: Paths,
    fully_qualified_name: []const u8,

    cc_argv: []const []const u8,
    inherited: Inherited,
    global: Compilation.Config,
    /// If this is null then `resolved_target` must be non-null.
    parent: ?*Package.Module,

    pub const Paths = struct {
        root: Compilation.Path,
        /// Relative to `root`. May contain path separators.
        root_src_path: []const u8,
    };

    pub const Inherited = struct {
        /// If this is null then `parent` must be non-null.
        resolved_target: ?ResolvedTarget = null,
        optimize_mode: ?std.builtin.OptimizeMode = null,
        code_model: ?std.builtin.CodeModel = null,
        single_threaded: ?bool = null,
        error_tracing: ?bool = null,
        valgrind: ?bool = null,
        pic: ?bool = null,
        strip: ?bool = null,
        omit_frame_pointer: ?bool = null,
        stack_check: ?bool = null,
        /// null means default.
        /// 0 means no stack protector.
        /// other number means stack protection with that buffer size.
        stack_protector: ?u32 = null,
        red_zone: ?bool = null,
        unwind_tables: ?std.builtin.UnwindTables = null,
        sanitize_c: ?std.zig.SanitizeC = null,
        sanitize_thread: ?bool = null,
        sanitize_address: ?bool = null,
        fuzz: ?bool = null,
        structured_cfg: ?bool = null,
        no_builtin: ?bool = null,
    };
};

pub const ResolvedTarget = struct {
    result: std.Target,
    is_native_os: bool,
    is_native_abi: bool,
    is_explicit_dynamic_linker: bool,
    llvm_cpu_features: ?[*:0]const u8 = null,
};

/// At least one of `parent` and `resolved_target` must be non-null.
pub fn create(arena: Allocator, options: CreateOptions) !*Package.Module {
    if (options.inherited.sanitize_thread == true) assert(options.global.any_sanitize_thread);
    if (options.inherited.sanitize_address == true) assert(options.global.any_sanitize_address);
    if (options.inherited.fuzz == true) assert(options.global.any_fuzz);
    if (options.inherited.single_threaded == false) assert(options.global.any_non_single_threaded);
    if (options.inherited.unwind_tables) |uwt| if (uwt != .none) assert(options.global.any_unwind_tables);
    if (options.inherited.sanitize_c) |sc| if (sc != .off) assert(options.global.any_sanitize_c != .off);
    if (options.inherited.error_tracing == true) assert(options.global.any_error_tracing);

    const resolved_target = options.inherited.resolved_target orelse options.parent.?.resolved_target;
    const target = resolved_target.result;

    const optimize_mode = options.inherited.optimize_mode orelse
        if (options.parent) |p| p.optimize_mode else options.global.root_optimize_mode;

    const strip = b: {
        if (options.inherited.strip) |x| break :b x;
        if (options.parent) |p| break :b p.strip;
        break :b options.global.root_strip;
    };

    const zig_backend = target_util.zigBackend(target, options.global.use_llvm);

    const valgrind = b: {
        if (!target_util.hasValgrindSupport(target, zig_backend)) {
            if (options.inherited.valgrind == true)
                return error.ValgrindUnsupportedOnTarget;
            break :b false;
        }
        if (options.inherited.valgrind) |x| break :b x;
        if (options.parent) |p| break :b p.valgrind;
        if (strip) break :b false;
        break :b optimize_mode == .Debug;
    };

    const single_threaded = b: {
        if (target_util.alwaysSingleThreaded(target)) {
            if (options.inherited.single_threaded == false)
                return error.TargetRequiresSingleThreaded;
            break :b true;
        }

        if (options.global.have_zcu) {
            if (!target_util.supportsThreads(target, zig_backend)) {
                if (options.inherited.single_threaded == false)
                    return error.BackendRequiresSingleThreaded;
                break :b true;
            }
        }

        if (options.inherited.single_threaded) |x| break :b x;
        if (options.parent) |p| break :b p.single_threaded;
        break :b target_util.defaultSingleThreaded(target);
    };

    const error_tracing = b: {
        if (options.inherited.error_tracing) |x| break :b x;
        if (options.parent) |p| break :b p.error_tracing;
        break :b options.global.root_error_tracing;
    };

    const pic = b: {
        if (target_util.requiresPIC(target, options.global.link_libc)) {
            if (options.inherited.pic == false)
                return error.TargetRequiresPic;
            break :b true;
        }
        if (options.global.pie) {
            if (options.inherited.pic == false)
                return error.PieRequiresPic;
            break :b true;
        }
        if (options.global.link_mode == .dynamic) {
            if (options.inherited.pic == false)
                return error.DynamicLinkingRequiresPic;
            break :b true;
        }
        if (options.inherited.pic) |x| break :b x;
        if (options.parent) |p| break :b p.pic;
        break :b false;
    };

    const red_zone = b: {
        if (!target_util.hasRedZone(target)) {
            if (options.inherited.red_zone == true)
                return error.TargetHasNoRedZone;
            break :b false;
        }
        if (options.inherited.red_zone) |x| break :b x;
        if (options.parent) |p| break :b p.red_zone;
        break :b true;
    };

    const omit_frame_pointer = b: {
        if (options.inherited.omit_frame_pointer) |x| break :b x;
        if (options.parent) |p| break :b p.omit_frame_pointer;
        if (optimize_mode == .ReleaseSmall) {
            // On x86, in most cases, keeping the frame pointer usually results in smaller binary size.
            // This has to do with how instructions for memory access via the stack base pointer register (when keeping the frame pointer)
            // are smaller than instructions for memory access via the stack pointer register (when omitting the frame pointer).
            break :b !target.cpu.arch.isX86();
        }
        break :b false;
    };

    const sanitize_thread = b: {
        if (options.inherited.sanitize_thread) |x| break :b x;
        if (options.parent) |p| break :b p.sanitize_thread;
        break :b false;
    };

    const sanitize_address = b: {
        if (options.inherited.sanitize_address) |x| break :b x;
        if (options.parent) |p| break :b p.sanitize_address;
        break :b false;
    };

    const unwind_tables = b: {
        if (options.inherited.unwind_tables) |x| break :b x;
        if (options.parent) |p| break :b p.unwind_tables;

        break :b target_util.defaultUnwindTables(
            target,
            options.global.link_libunwind,
            sanitize_thread or options.global.any_sanitize_thread,
            sanitize_address or options.global.any_sanitize_address,
        );
    };

    const fuzz = b: {
        if (options.inherited.fuzz) |x| break :b x;
        if (options.parent) |p| break :b p.fuzz;
        break :b false;
    };

    const code_model: std.builtin.CodeModel = b: {
        if (options.inherited.code_model) |x| break :b x;
        if (options.parent) |p| break :b p.code_model;
        break :b switch (target.cpu.arch) {
            // Temporary workaround until LLVM 21: https://github.com/llvm/llvm-project/pull/132173
            .loongarch64 => .medium,
            else => .default,
        };
    };

    const is_safe_mode = switch (optimize_mode) {
        .Debug, .ReleaseSafe => true,
        .ReleaseFast, .ReleaseSmall => false,
    };

    const sanitize_c: std.zig.SanitizeC = b: {
        if (options.inherited.sanitize_c) |x| break :b x;
        if (options.parent) |p| break :b p.sanitize_c;
        break :b switch (optimize_mode) {
            .Debug => .full,
            // It's recommended to use the minimal runtime in production
            // environments due to the security implications of the full runtime.
            // The minimal runtime doesn't provide much benefit over simply
            // trapping, however, so we do that instead.
            .ReleaseSafe => .trap,
            .ReleaseFast, .ReleaseSmall => .off,
        };
    };

    const stack_check = b: {
        if (!target_util.supportsStackProbing(target)) {
            if (options.inherited.stack_check == true)
                return error.StackCheckUnsupportedByTarget;
            break :b false;
        }
        if (options.inherited.stack_check) |x| break :b x;
        if (options.parent) |p| break :b p.stack_check;
        break :b is_safe_mode;
    };

    const stack_protector: u32 = sp: {
        const use_zig_backend = options.global.have_zcu or
            (options.global.any_c_source_files and options.global.c_frontend == .aro);
        if (use_zig_backend and !target_util.supportsStackProtector(target, zig_backend)) {
            if (options.inherited.stack_protector) |x| {
                if (x > 0) return error.StackProtectorUnsupportedByTarget;
            }
            break :sp 0;
        }

        if (options.global.any_c_source_files and options.global.c_frontend == .clang and
            !target_util.clangSupportsStackProtector(target))
        {
            if (options.inherited.stack_protector) |x| {
                if (x > 0) return error.StackProtectorUnsupportedByTarget;
            }
            break :sp 0;
        }

        // This logic is checking for linking libc because otherwise our start code
        // which is trying to set up TLS (i.e. the fs/gs registers) but the stack
        // protection code depends on fs/gs registers being already set up.
        // If we were able to annotate start code, or perhaps the entire std lib,
        // as being exempt from stack protection checks, we could change this logic
        // to supporting stack protection even when not linking libc.
        // TODO file issue about this
        if (!options.global.link_libc) {
            if (options.inherited.stack_protector) |x| {
                if (x > 0) return error.StackProtectorUnavailableWithoutLibC;
            }
            break :sp 0;
        }

        if (options.inherited.stack_protector) |x| break :sp x;
        if (options.parent) |p| break :sp p.stack_protector;
        if (!is_safe_mode) break :sp 0;

        break :sp target_util.default_stack_protector_buffer_size;
    };

    const structured_cfg = b: {
        if (options.inherited.structured_cfg) |x| break :b x;
        if (options.parent) |p| break :b p.structured_cfg;
        // We always want a structured control flow in shaders. This option is
        // only relevant for OpenCL kernels.
        break :b switch (target.os.tag) {
            .opencl => false,
            else => true,
        };
    };

    const no_builtin = b: {
        if (options.inherited.no_builtin) |x| break :b x;
        if (options.parent) |p| break :b p.no_builtin;

        break :b target.cpu.arch.isBpf();
    };

    const llvm_cpu_features: ?[*:0]const u8 = b: {
        if (resolved_target.llvm_cpu_features) |x| break :b x;
        if (!options.global.use_llvm) break :b null;

        var buf = std.ArrayList(u8).init(arena);
        var disabled_features = std.ArrayList(u8).init(arena);
        defer disabled_features.deinit();

        // Append disabled features after enabled ones, so that their effects aren't overwritten.
        for (target.cpu.arch.allFeaturesList()) |feature| {
            if (feature.llvm_name) |llvm_name| {
                // Ignore these until we figure out how to handle the concept of omitting features.
                // See https://github.com/ziglang/zig/issues/23539
                if (target_util.isDynamicAMDGCNFeature(target, feature)) continue;

                const is_enabled = target.cpu.features.isEnabled(feature.index);

                if (is_enabled) {
                    try buf.ensureUnusedCapacity(2 + llvm_name.len);
                    buf.appendAssumeCapacity('+');
                    buf.appendSliceAssumeCapacity(llvm_name);
                    buf.appendAssumeCapacity(',');
                } else {
                    try disabled_features.ensureUnusedCapacity(2 + llvm_name.len);
                    disabled_features.appendAssumeCapacity('-');
                    disabled_features.appendSliceAssumeCapacity(llvm_name);
                    disabled_features.appendAssumeCapacity(',');
                }
            }
        }

        try buf.appendSlice(disabled_features.items);
        if (buf.items.len == 0) break :b "";
        assert(std.mem.endsWith(u8, buf.items, ","));
        buf.items[buf.items.len - 1] = 0;
        buf.shrinkAndFree(buf.items.len);
        break :b buf.items[0 .. buf.items.len - 1 :0].ptr;
    };

    const mod = try arena.create(Module);
    mod.* = .{
        .root = options.paths.root,
        .root_src_path = options.paths.root_src_path,
        .fully_qualified_name = options.fully_qualified_name,
        .resolved_target = .{
            .result = target,
            .is_native_os = resolved_target.is_native_os,
            .is_native_abi = resolved_target.is_native_abi,
            .is_explicit_dynamic_linker = resolved_target.is_explicit_dynamic_linker,
            .llvm_cpu_features = llvm_cpu_features,
        },
        .optimize_mode = optimize_mode,
        .single_threaded = single_threaded,
        .error_tracing = error_tracing,
        .valgrind = valgrind,
        .pic = pic,
        .strip = strip,
        .omit_frame_pointer = omit_frame_pointer,
        .stack_check = stack_check,
        .stack_protector = stack_protector,
        .code_model = code_model,
        .red_zone = red_zone,
        .sanitize_c = sanitize_c,
        .sanitize_thread = sanitize_thread,
        .sanitize_address = sanitize_address,
        .fuzz = fuzz,
        .unwind_tables = unwind_tables,
        .cc_argv = options.cc_argv,
        .structured_cfg = structured_cfg,
        .no_builtin = no_builtin,
    };
    return mod;
}

/// All fields correspond to `CreateOptions`.
pub const LimitedOptions = struct {
    root: Compilation.Path,
    root_src_path: []const u8,
    fully_qualified_name: []const u8,
};

/// This one can only be used if the Module will only be used for AstGen and earlier in
/// the pipeline. Illegal behavior occurs if a limited module touches Sema.
pub fn createLimited(gpa: Allocator, options: LimitedOptions) Allocator.Error!*Package.Module {
    const mod = try gpa.create(Module);
    mod.* = .{
        .root = options.root,
        .root_src_path = options.root_src_path,
        .fully_qualified_name = options.fully_qualified_name,

        .resolved_target = undefined,
        .optimize_mode = undefined,
        .code_model = undefined,
        .single_threaded = undefined,
        .error_tracing = undefined,
        .valgrind = undefined,
        .pic = undefined,
        .strip = undefined,
        .omit_frame_pointer = undefined,
        .stack_check = undefined,
        .stack_protector = undefined,
        .red_zone = undefined,
        .sanitize_c = undefined,
        .sanitize_thread = undefined,
        .sanitize_address = undefined,
        .fuzz = undefined,
        .unwind_tables = undefined,
        .cc_argv = undefined,
        .structured_cfg = undefined,
        .no_builtin = undefined,
    };
    return mod;
}

/// Does not ensure that the module's root directory exists on-disk; see `Builtin.updateFileOnDisk` for that task.
pub fn createBuiltin(arena: Allocator, opts: Builtin, dirs: Compilation.Directories) Allocator.Error!*Module {
    const sub_path = "b" ++ std.fs.path.sep_str ++ Cache.binToHex(opts.hash());
    const new = try arena.create(Module);
    new.* = .{
        .root = try .fromRoot(arena, dirs, .global_cache, sub_path),
        .root_src_path = "builtin.zig",
        .fully_qualified_name = "builtin",
        .resolved_target = .{
            .result = opts.target,
            // These values are not in `opts`, but do not matter because `builtin.zig` contains no runtime code.
            .is_native_os = false,
            .is_native_abi = false,
            .is_explicit_dynamic_linker = false,
            .llvm_cpu_features = null,
        },
        .optimize_mode = opts.optimize_mode,
        .single_threaded = opts.single_threaded,
        .error_tracing = opts.error_tracing,
        .valgrind = opts.valgrind,
        .pic = opts.pic,
        .strip = opts.strip,
        .omit_frame_pointer = opts.omit_frame_pointer,
        .code_model = opts.code_model,
        .sanitize_thread = opts.sanitize_thread,
        .sanitize_address = opts.sanitize_address,
        .fuzz = opts.fuzz,
        .unwind_tables = opts.unwind_tables,
        .cc_argv = &.{},
        // These values are not in `opts`, but do not matter because `builtin.zig` contains no runtime code.
        .stack_check = false,
        .stack_protector = 0,
        .red_zone = false,
        .sanitize_c = .off,
        .structured_cfg = false,
        .no_builtin = false,
    };
    return new;
}

/// Returns the `Builtin` which forms the contents of `@import("builtin")` for this module.
pub fn getBuiltinOptions(m: Module, global: Compilation.Config) Builtin {
    assert(global.have_zcu);
    return .{
        .target = m.resolved_target.result,
        .zig_backend = target_util.zigBackend(m.resolved_target.result, global.use_llvm),
        .output_mode = global.output_mode,
        .link_mode = global.link_mode,
        .unwind_tables = m.unwind_tables,
        .is_test = global.is_test,
        .single_threaded = m.single_threaded,
        .link_libc = global.link_libc,
        .link_libcpp = global.link_libcpp,
        .optimize_mode = m.optimize_mode,
        .error_tracing = m.error_tracing,
        .valgrind = m.valgrind,
        .sanitize_thread = m.sanitize_thread,
        .sanitize_address = m.sanitize_address,
        .fuzz = m.fuzz,
        .pic = m.pic,
        .pie = global.pie,
        .strip = m.strip,
        .code_model = m.code_model,
        .omit_frame_pointer = m.omit_frame_pointer,
        .wasi_exec_model = global.wasi_exec_model,
    };
}

const Module = @This();
const Package = @import("../Package.zig");
const std = @import("std");
const Allocator = std.mem.Allocator;
const MultiHashHexDigest = Package.Manifest.MultiHashHexDigest;
const target_util = @import("../target.zig");
const Cache = std.Build.Cache;
const Builtin = @import("../Builtin.zig");
const assert = std.debug.assert;
const Compilation = @import("../Compilation.zig");
const File = @import("../Zcu.zig").File;

//! Corresponds to something that Zig source code can `@import`.

/// Only files inside this directory can be imported.
root: Cache.Path,
/// Relative to `root`. May contain path separators.
root_src_path: []const u8,
/// Name used in compile errors. Looks like "root.foo.bar".
fully_qualified_name: []const u8,
/// The dependency table of this module. Shared dependencies such as 'std',
/// 'builtin', and 'root' are not specified in every dependency table, but
/// instead only in the table of `main_mod`. `Module.importFile` is
/// responsible for detecting these names and using the correct package.
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
sanitize_c: bool,
sanitize_thread: bool,
fuzz: bool,
unwind_tables: bool,
cc_argv: []const []const u8,
/// (SPIR-V) whether to generate a structured control flow graph or not
structured_cfg: bool,

/// If the module is an `@import("builtin")` module, this is the `File` that
/// is preallocated for it. Otherwise this field is null.
builtin_file: ?*File,

pub const Deps = std.StringArrayHashMapUnmanaged(*Module);

pub fn isBuiltin(m: Module) bool {
    return m.builtin_file != null;
}

pub const Tree = struct {
    /// Each `Package` exposes a `Module` with build.zig as its root source file.
    build_module_table: std.AutoArrayHashMapUnmanaged(MultiHashHexDigest, *Module),
};

pub const CreateOptions = struct {
    /// Where to store builtin.zig. The global cache directory is used because
    /// it is a pure function based on CLI flags.
    global_cache_directory: Cache.Directory,
    paths: Paths,
    fully_qualified_name: []const u8,

    cc_argv: []const []const u8,
    inherited: Inherited,
    global: Compilation.Config,
    /// If this is null then `resolved_target` must be non-null.
    parent: ?*Package.Module,

    builtin_mod: ?*Package.Module,

    /// Allocated into the given `arena`. Should be shared across all module creations in a Compilation.
    /// Ignored if `builtin_mod` is passed or if `!have_zcu`.
    /// Otherwise, may be `null` only if this Compilation consists of a single module.
    builtin_modules: ?*std.StringHashMapUnmanaged(*Module),

    pub const Paths = struct {
        root: Cache.Path,
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
        unwind_tables: ?bool = null,
        sanitize_c: ?bool = null,
        sanitize_thread: ?bool = null,
        fuzz: ?bool = null,
        structured_cfg: ?bool = null,
    };
};

pub const ResolvedTarget = struct {
    result: std.Target,
    is_native_os: bool,
    is_native_abi: bool,
    llvm_cpu_features: ?[*:0]const u8 = null,
};

/// At least one of `parent` and `resolved_target` must be non-null.
pub fn create(arena: Allocator, options: CreateOptions) !*Package.Module {
    if (options.inherited.sanitize_thread == true) assert(options.global.any_sanitize_thread);
    if (options.inherited.fuzz == true) assert(options.global.any_fuzz);
    if (options.inherited.single_threaded == false) assert(options.global.any_non_single_threaded);
    if (options.inherited.unwind_tables == true) assert(options.global.any_unwind_tables);
    if (options.inherited.error_tracing == true) assert(options.global.any_error_tracing);

    const resolved_target = options.inherited.resolved_target orelse options.parent.?.resolved_target;
    const target = resolved_target.result;

    const optimize_mode = options.inherited.optimize_mode orelse
        if (options.parent) |p| p.optimize_mode else .Debug;

    const unwind_tables = options.inherited.unwind_tables orelse
        if (options.parent) |p| p.unwind_tables else options.global.any_unwind_tables;

    const strip = b: {
        if (options.inherited.strip) |x| break :b x;
        if (options.parent) |p| break :b p.strip;
        break :b options.global.root_strip;
    };

    const valgrind = b: {
        if (!target_util.hasValgrindSupport(target)) {
            if (options.inherited.valgrind == true)
                return error.ValgrindUnsupportedOnTarget;
            break :b false;
        }
        if (options.inherited.valgrind) |x| break :b x;
        if (options.parent) |p| break :b p.valgrind;
        if (strip) break :b false;
        break :b optimize_mode == .Debug;
    };

    const zig_backend = target_util.zigBackend(target, options.global.use_llvm);

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
        if (optimize_mode == .Debug) break :b false;
        break :b true;
    };

    const sanitize_thread = b: {
        if (options.inherited.sanitize_thread) |x| break :b x;
        if (options.parent) |p| break :b p.sanitize_thread;
        break :b false;
    };

    const fuzz = b: {
        if (options.inherited.fuzz) |x| break :b x;
        if (options.parent) |p| break :b p.fuzz;
        break :b false;
    };

    const code_model = b: {
        if (options.inherited.code_model) |x| break :b x;
        if (options.parent) |p| break :b p.code_model;
        break :b .default;
    };

    const is_safe_mode = switch (optimize_mode) {
        .Debug, .ReleaseSafe => true,
        .ReleaseFast, .ReleaseSmall => false,
    };

    const sanitize_c = b: {
        if (options.inherited.sanitize_c) |x| break :b x;
        if (options.parent) |p| break :b p.sanitize_c;
        break :b is_safe_mode;
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

    const llvm_cpu_features: ?[*:0]const u8 = b: {
        if (resolved_target.llvm_cpu_features) |x| break :b x;
        if (!options.global.use_llvm) break :b null;

        var buf = std.ArrayList(u8).init(arena);
        for (target.cpu.arch.allFeaturesList(), 0..) |feature, index_usize| {
            const index = @as(std.Target.Cpu.Feature.Set.Index, @intCast(index_usize));
            const is_enabled = target.cpu.features.isEnabled(index);

            if (feature.llvm_name) |llvm_name| {
                const plus_or_minus = "-+"[@intFromBool(is_enabled)];
                try buf.ensureUnusedCapacity(2 + llvm_name.len);
                buf.appendAssumeCapacity(plus_or_minus);
                buf.appendSliceAssumeCapacity(llvm_name);
                buf.appendSliceAssumeCapacity(",");
            }
        }
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
        .fuzz = fuzz,
        .unwind_tables = unwind_tables,
        .cc_argv = options.cc_argv,
        .structured_cfg = structured_cfg,
        .builtin_file = null,
    };

    const opt_builtin_mod = options.builtin_mod orelse b: {
        if (!options.global.have_zcu) break :b null;

        const generated_builtin_source = try Builtin.generate(.{
            .target = target,
            .zig_backend = zig_backend,
            .output_mode = options.global.output_mode,
            .link_mode = options.global.link_mode,
            .is_test = options.global.is_test,
            .single_threaded = single_threaded,
            .link_libc = options.global.link_libc,
            .link_libcpp = options.global.link_libcpp,
            .optimize_mode = optimize_mode,
            .error_tracing = error_tracing,
            .valgrind = valgrind,
            .sanitize_thread = sanitize_thread,
            .fuzz = fuzz,
            .pic = pic,
            .pie = options.global.pie,
            .strip = strip,
            .code_model = code_model,
            .omit_frame_pointer = omit_frame_pointer,
            .wasi_exec_model = options.global.wasi_exec_model,
        }, arena);

        const new = if (options.builtin_modules) |builtins| new: {
            const gop = try builtins.getOrPut(arena, generated_builtin_source);
            if (gop.found_existing) break :b gop.value_ptr.*;
            errdefer builtins.removeByPtr(gop.key_ptr);
            const new = try arena.create(Module);
            gop.value_ptr.* = new;
            break :new new;
        } else try arena.create(Module);
        errdefer if (options.builtin_modules) |builtins| assert(builtins.remove(generated_builtin_source));

        const new_file = try arena.create(File);

        const hex_digest = digest: {
            var hasher: Cache.Hasher = Cache.hasher_init;
            hasher.update(generated_builtin_source);

            var bin_digest: Cache.BinDigest = undefined;
            hasher.final(&bin_digest);

            var hex_digest: Cache.HexDigest = undefined;
            _ = std.fmt.bufPrint(
                &hex_digest,
                "{s}",
                .{std.fmt.fmtSliceHexLower(&bin_digest)},
            ) catch unreachable;

            break :digest hex_digest;
        };

        const builtin_sub_path = try arena.dupe(u8, "b" ++ std.fs.path.sep_str ++ hex_digest);

        new.* = .{
            .root = .{
                .root_dir = options.global_cache_directory,
                .sub_path = builtin_sub_path,
            },
            .root_src_path = "builtin.zig",
            .fully_qualified_name = if (options.parent == null)
                "builtin"
            else
                try std.fmt.allocPrint(arena, "{s}.builtin", .{options.fully_qualified_name}),
            .resolved_target = .{
                .result = target,
                .is_native_os = resolved_target.is_native_os,
                .is_native_abi = resolved_target.is_native_abi,
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
            .fuzz = fuzz,
            .unwind_tables = unwind_tables,
            .cc_argv = &.{},
            .structured_cfg = structured_cfg,
            .builtin_file = new_file,
        };
        new_file.* = .{
            .sub_file_path = "builtin.zig",
            .source = generated_builtin_source,
            .source_loaded = true,
            .tree_loaded = false,
            .zir_loaded = false,
            .stat = undefined,
            .tree = undefined,
            .zir = undefined,
            .status = .never_loaded,
            .mod = new,
        };
        break :b new;
    };

    if (opt_builtin_mod) |builtin_mod| {
        try mod.deps.ensureUnusedCapacity(arena, 1);
        mod.deps.putAssumeCapacityNoClobber("builtin", builtin_mod);
    }

    return mod;
}

/// All fields correspond to `CreateOptions`.
pub const LimitedOptions = struct {
    root: Cache.Path,
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
        .fuzz = undefined,
        .unwind_tables = undefined,
        .cc_argv = undefined,
        .structured_cfg = undefined,
        .builtin_file = null,
    };
    return mod;
}

/// Asserts that the module has a builtin module, which is not true for non-zig
/// modules such as ones only used for `@embedFile`, or the root module when
/// there is no Zig Compilation Unit.
pub fn getBuiltinDependency(m: Module) *Module {
    const result = m.deps.values()[0];
    assert(result.isBuiltin());
    return result;
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

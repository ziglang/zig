const builtin = @import("builtin");
const std = @import("std");
const mem = std.mem;
const fs = std.fs;
const assert = std.debug.assert;
const panic = std.debug.panic;
const ArrayList = std.ArrayList;
const StringHashMap = std.StringHashMap;
const Sha256 = std.crypto.hash.sha2.Sha256;
const Allocator = mem.Allocator;
const Step = std.Build.Step;
const CrossTarget = std.zig.CrossTarget;
const NativeTargetInfo = std.zig.system.NativeTargetInfo;
const LazyPath = std.Build.LazyPath;
const PkgConfigPkg = std.Build.PkgConfigPkg;
const PkgConfigError = std.Build.PkgConfigError;
const ExecError = std.Build.ExecError;
const Module = std.Build.Module;
const VcpkgRoot = std.Build.VcpkgRoot;
const InstallDir = std.Build.InstallDir;
const GeneratedFile = std.Build.GeneratedFile;
const Compile = @This();

pub const base_id: Step.Id = .compile;

step: Step,
name: []const u8,
target: CrossTarget,
target_info: NativeTargetInfo,
optimize: std.builtin.Mode,
linker_script: ?LazyPath = null,
version_script: ?[]const u8 = null,
out_filename: []const u8,
linkage: ?Linkage = null,
version: ?std.SemanticVersion,
kind: Kind,
major_only_filename: ?[]const u8,
name_only_filename: ?[]const u8,
strip: ?bool,
unwind_tables: ?bool,
// keep in sync with src/link.zig:CompressDebugSections
compress_debug_sections: enum { none, zlib } = .none,
lib_paths: ArrayList(LazyPath),
rpaths: ArrayList(LazyPath),
framework_dirs: ArrayList(LazyPath),
frameworks: StringHashMap(FrameworkLinkInfo),
verbose_link: bool,
verbose_cc: bool,
bundle_compiler_rt: ?bool = null,
single_threaded: ?bool,
stack_protector: ?bool = null,
disable_stack_probing: bool,
disable_sanitize_c: bool,
sanitize_thread: bool,
rdynamic: bool,
dwarf_format: ?std.dwarf.Format = null,
import_memory: bool = false,
export_memory: bool = false,
/// For WebAssembly targets, this will allow for undefined symbols to
/// be imported from the host environment.
import_symbols: bool = false,
import_table: bool = false,
export_table: bool = false,
initial_memory: ?u64 = null,
max_memory: ?u64 = null,
shared_memory: bool = false,
global_base: ?u64 = null,
c_std: std.Build.CStd,
/// Set via options; intended to be read-only after that.
zig_lib_dir: ?LazyPath,
/// Set via options; intended to be read-only after that.
main_pkg_path: ?LazyPath,
exec_cmd_args: ?[]const ?[]const u8,
filter: ?[]const u8,
test_evented_io: bool = false,
test_runner: ?[]const u8,
code_model: std.builtin.CodeModel = .default,
wasi_exec_model: ?std.builtin.WasiExecModel = null,
/// Symbols to be exported when compiling to wasm
export_symbol_names: []const []const u8 = &.{},

root_src: ?LazyPath,
out_lib_filename: []const u8,
modules: std.StringArrayHashMap(*Module),

link_objects: ArrayList(LinkObject),
include_dirs: ArrayList(IncludeDir),
c_macros: ArrayList([]const u8),
installed_headers: ArrayList(*Step),
is_linking_libc: bool,
is_linking_libcpp: bool,
vcpkg_bin_path: ?[]const u8 = null,

installed_path: ?[]const u8,

/// Base address for an executable image.
image_base: ?u64 = null,

libc_file: ?LazyPath = null,

valgrind_support: ?bool = null,
each_lib_rpath: ?bool = null,
/// On ELF targets, this will emit a link section called ".note.gnu.build-id"
/// which can be used to coordinate a stripped binary with its debug symbols.
/// As an example, the bloaty project refuses to work unless its inputs have
/// build ids, in order to prevent accidental mismatches.
/// The default is to not include this section because it slows down linking.
build_id: ?BuildId = null,

/// Create a .eh_frame_hdr section and a PT_GNU_EH_FRAME segment in the ELF
/// file.
link_eh_frame_hdr: bool = false,
link_emit_relocs: bool = false,

/// Place every function in its own section so that unused ones may be
/// safely garbage-collected during the linking phase.
link_function_sections: bool = false,

/// Remove functions and data that are unreachable by the entry point or
/// exported symbols.
link_gc_sections: ?bool = null,

/// (Windows) Whether or not to enable ASLR. Maps to the /DYNAMICBASE[:NO] linker argument.
linker_dynamicbase: bool = true,

linker_allow_shlib_undefined: ?bool = null,

/// Permit read-only relocations in read-only segments. Disallowed by default.
link_z_notext: bool = false,

/// Force all relocations to be read-only after processing.
link_z_relro: bool = true,

/// Allow relocations to be lazily processed after load.
link_z_lazy: bool = false,

/// Common page size
link_z_common_page_size: ?u64 = null,

/// Maximum page size
link_z_max_page_size: ?u64 = null,

/// (Darwin) Install name for the dylib
install_name: ?[]const u8 = null,

/// (Darwin) Path to entitlements file
entitlements: ?[]const u8 = null,

/// (Darwin) Size of the pagezero segment.
pagezero_size: ?u64 = null,

/// (Darwin) Set size of the padding between the end of load commands
/// and start of `__TEXT,__text` section.
headerpad_size: ?u32 = null,

/// (Darwin) Automatically Set size of the padding between the end of load commands
/// and start of `__TEXT,__text` section to a value fitting all paths expanded to MAXPATHLEN.
headerpad_max_install_names: bool = false,

/// (Darwin) Remove dylibs that are unreachable by the entry point or exported symbols.
dead_strip_dylibs: bool = false,

/// Position Independent Code
force_pic: ?bool = null,

/// Position Independent Executable
pie: ?bool = null,

red_zone: ?bool = null,

omit_frame_pointer: ?bool = null,
dll_export_fns: ?bool = null,

subsystem: ?std.Target.SubSystem = null,

entry_symbol_name: ?[]const u8 = null,

/// List of symbols forced as undefined in the symbol table
/// thus forcing their resolution by the linker.
/// Corresponds to `-u <symbol>` for ELF/MachO and `/include:<symbol>` for COFF/PE.
force_undefined_symbols: std.StringHashMap(void),

/// Overrides the default stack size
stack_size: ?u64 = null,

want_lto: ?bool = null,
use_llvm: ?bool,
use_lld: ?bool,

/// This is an advanced setting that can change the intent of this Compile step.
/// If this slice has nonzero length, it means that this Compile step exists to
/// check for compile errors and return *success* if they match, and failure
/// otherwise.
expect_errors: []const []const u8 = &.{},

emit_directory: ?*GeneratedFile,

generated_docs: ?*GeneratedFile,
generated_asm: ?*GeneratedFile,
generated_bin: ?*GeneratedFile,
generated_pdb: ?*GeneratedFile,
generated_implib: ?*GeneratedFile,
generated_llvm_bc: ?*GeneratedFile,
generated_llvm_ir: ?*GeneratedFile,
generated_h: ?*GeneratedFile,

pub const CSourceFiles = struct {
    /// Relative to the build root.
    files: []const []const u8,
    flags: []const []const u8,
};

pub const CSourceFile = struct {
    file: LazyPath,
    flags: []const []const u8,

    pub fn dupe(self: CSourceFile, b: *std.Build) CSourceFile {
        return .{
            .file = self.file.dupe(b),
            .flags = b.dupeStrings(self.flags),
        };
    }
};

pub const LinkObject = union(enum) {
    static_path: LazyPath,
    other_step: *Compile,
    system_lib: SystemLib,
    assembly_file: LazyPath,
    c_source_file: *CSourceFile,
    c_source_files: *CSourceFiles,
};

pub const SystemLib = struct {
    name: []const u8,
    needed: bool,
    weak: bool,
    use_pkg_config: UsePkgConfig,
    preferred_link_mode: std.builtin.LinkMode,
    search_strategy: SystemLib.SearchStrategy,

    pub const UsePkgConfig = enum {
        /// Don't use pkg-config, just pass -lfoo where foo is name.
        no,
        /// Try to get information on how to link the library from pkg-config.
        /// If that fails, fall back to passing -lfoo where foo is name.
        yes,
        /// Try to get information on how to link the library from pkg-config.
        /// If that fails, error out.
        force,
    };

    pub const SearchStrategy = enum { paths_first, mode_first, no_fallback };
};

const FrameworkLinkInfo = struct {
    needed: bool = false,
    weak: bool = false,
};

pub const IncludeDir = union(enum) {
    path: LazyPath,
    path_system: LazyPath,
    other_step: *Compile,
    config_header_step: *Step.ConfigHeader,
};

pub const Options = struct {
    name: []const u8,
    root_source_file: ?LazyPath = null,
    target: CrossTarget,
    optimize: std.builtin.Mode,
    kind: Kind,
    linkage: ?Linkage = null,
    version: ?std.SemanticVersion = null,
    max_rss: usize = 0,
    filter: ?[]const u8 = null,
    test_runner: ?[]const u8 = null,
    link_libc: ?bool = null,
    single_threaded: ?bool = null,
    use_llvm: ?bool = null,
    use_lld: ?bool = null,
    zig_lib_dir: ?LazyPath = null,
    main_pkg_path: ?LazyPath = null,
};

pub const BuildId = union(enum) {
    none,
    fast,
    uuid,
    sha1,
    md5,
    hexstring: HexString,

    pub fn eql(a: BuildId, b: BuildId) bool {
        const a_tag = std.meta.activeTag(a);
        const b_tag = std.meta.activeTag(b);
        if (a_tag != b_tag) return false;
        return switch (a) {
            .none, .fast, .uuid, .sha1, .md5 => true,
            .hexstring => |a_hexstring| mem.eql(u8, a_hexstring.toSlice(), b.hexstring.toSlice()),
        };
    }

    pub const HexString = struct {
        bytes: [32]u8,
        len: u8,

        /// Result is byte values, *not* hex-encoded.
        pub fn toSlice(hs: *const HexString) []const u8 {
            return hs.bytes[0..hs.len];
        }
    };

    /// Input is byte values, *not* hex-encoded.
    /// Asserts `bytes` fits inside `HexString`
    pub fn initHexString(bytes: []const u8) BuildId {
        var result: BuildId = .{ .hexstring = .{
            .bytes = undefined,
            .len = @as(u8, @intCast(bytes.len)),
        } };
        @memcpy(result.hexstring.bytes[0..bytes.len], bytes);
        return result;
    }

    /// Converts UTF-8 text to a `BuildId`.
    pub fn parse(text: []const u8) !BuildId {
        if (mem.eql(u8, text, "none")) {
            return .none;
        } else if (mem.eql(u8, text, "fast")) {
            return .fast;
        } else if (mem.eql(u8, text, "uuid")) {
            return .uuid;
        } else if (mem.eql(u8, text, "sha1") or mem.eql(u8, text, "tree")) {
            return .sha1;
        } else if (mem.eql(u8, text, "md5")) {
            return .md5;
        } else if (mem.startsWith(u8, text, "0x")) {
            var result: BuildId = .{ .hexstring = undefined };
            const slice = try std.fmt.hexToBytes(&result.hexstring.bytes, text[2..]);
            result.hexstring.len = @as(u8, @intCast(slice.len));
            return result;
        }
        return error.InvalidBuildIdStyle;
    }

    test parse {
        try std.testing.expectEqual(BuildId.md5, try parse("md5"));
        try std.testing.expectEqual(BuildId.none, try parse("none"));
        try std.testing.expectEqual(BuildId.fast, try parse("fast"));
        try std.testing.expectEqual(BuildId.uuid, try parse("uuid"));
        try std.testing.expectEqual(BuildId.sha1, try parse("sha1"));
        try std.testing.expectEqual(BuildId.sha1, try parse("tree"));

        try std.testing.expect(BuildId.initHexString("").eql(try parse("0x")));
        try std.testing.expect(BuildId.initHexString("\x12\x34\x56").eql(try parse("0x123456")));
        try std.testing.expectError(error.InvalidLength, parse("0x12-34"));
        try std.testing.expectError(error.InvalidCharacter, parse("0xfoobbb"));
        try std.testing.expectError(error.InvalidBuildIdStyle, parse("yaddaxxx"));
    }
};

pub const Kind = enum {
    exe,
    lib,
    obj,
    @"test",
};

pub const Linkage = enum { dynamic, static };

pub fn create(owner: *std.Build, options: Options) *Compile {
    const name = owner.dupe(options.name);
    const root_src: ?LazyPath = if (options.root_source_file) |rsrc| rsrc.dupe(owner) else null;
    if (mem.indexOf(u8, name, "/") != null or mem.indexOf(u8, name, "\\") != null) {
        panic("invalid name: '{s}'. It looks like a file path, but it is supposed to be the library or application name.", .{name});
    }

    // Avoid the common case of the step name looking like "zig test test".
    const name_adjusted = if (options.kind == .@"test" and mem.eql(u8, name, "test"))
        ""
    else
        owner.fmt("{s} ", .{name});

    const step_name = owner.fmt("{s} {s}{s} {s}", .{
        switch (options.kind) {
            .exe => "zig build-exe",
            .lib => "zig build-lib",
            .obj => "zig build-obj",
            .@"test" => "zig test",
        },
        name_adjusted,
        @tagName(options.optimize),
        options.target.zigTriple(owner.allocator) catch @panic("OOM"),
    });

    const target_info = NativeTargetInfo.detect(options.target) catch @panic("unhandled error");

    const out_filename = std.zig.binNameAlloc(owner.allocator, .{
        .root_name = name,
        .target = target_info.target,
        .output_mode = switch (options.kind) {
            .lib => .Lib,
            .obj => .Obj,
            .exe, .@"test" => .Exe,
        },
        .link_mode = if (options.linkage) |some| @as(std.builtin.LinkMode, switch (some) {
            .dynamic => .Dynamic,
            .static => .Static,
        }) else null,
        .version = options.version,
    }) catch @panic("OOM");

    const self = owner.allocator.create(Compile) catch @panic("OOM");
    self.* = .{
        .strip = null,
        .unwind_tables = null,
        .verbose_link = false,
        .verbose_cc = false,
        .optimize = options.optimize,
        .target = options.target,
        .linkage = options.linkage,
        .kind = options.kind,
        .root_src = root_src,
        .name = name,
        .frameworks = StringHashMap(FrameworkLinkInfo).init(owner.allocator),
        .step = Step.init(.{
            .id = base_id,
            .name = step_name,
            .owner = owner,
            .makeFn = make,
            .max_rss = options.max_rss,
        }),
        .version = options.version,
        .out_filename = out_filename,
        .out_lib_filename = undefined,
        .major_only_filename = null,
        .name_only_filename = null,
        .modules = std.StringArrayHashMap(*Module).init(owner.allocator),
        .include_dirs = ArrayList(IncludeDir).init(owner.allocator),
        .link_objects = ArrayList(LinkObject).init(owner.allocator),
        .c_macros = ArrayList([]const u8).init(owner.allocator),
        .lib_paths = ArrayList(LazyPath).init(owner.allocator),
        .rpaths = ArrayList(LazyPath).init(owner.allocator),
        .framework_dirs = ArrayList(LazyPath).init(owner.allocator),
        .installed_headers = ArrayList(*Step).init(owner.allocator),
        .c_std = std.Build.CStd.C99,
        .zig_lib_dir = null,
        .main_pkg_path = null,
        .exec_cmd_args = null,
        .filter = options.filter,
        .test_runner = options.test_runner,
        .disable_stack_probing = false,
        .disable_sanitize_c = false,
        .sanitize_thread = false,
        .rdynamic = false,
        .installed_path = null,
        .force_undefined_symbols = StringHashMap(void).init(owner.allocator),

        .emit_directory = null,
        .generated_docs = null,
        .generated_asm = null,
        .generated_bin = null,
        .generated_pdb = null,
        .generated_implib = null,
        .generated_llvm_bc = null,
        .generated_llvm_ir = null,
        .generated_h = null,

        .target_info = target_info,

        .is_linking_libc = options.link_libc orelse false,
        .is_linking_libcpp = false,
        .single_threaded = options.single_threaded,
        .use_llvm = options.use_llvm,
        .use_lld = options.use_lld,
    };

    if (options.zig_lib_dir) |lp| {
        self.zig_lib_dir = lp.dupe(self.step.owner);
        lp.addStepDependencies(&self.step);
    }

    if (options.main_pkg_path) |lp| {
        self.main_pkg_path = lp.dupe(self.step.owner);
        lp.addStepDependencies(&self.step);
    }

    if (self.kind == .lib) {
        if (self.linkage != null and self.linkage.? == .static) {
            self.out_lib_filename = self.out_filename;
        } else if (self.version) |version| {
            if (target_info.target.isDarwin()) {
                self.major_only_filename = owner.fmt("lib{s}.{d}.dylib", .{
                    self.name,
                    version.major,
                });
                self.name_only_filename = owner.fmt("lib{s}.dylib", .{self.name});
                self.out_lib_filename = self.out_filename;
            } else if (target_info.target.os.tag == .windows) {
                self.out_lib_filename = owner.fmt("{s}.lib", .{self.name});
            } else {
                self.major_only_filename = owner.fmt("lib{s}.so.{d}", .{ self.name, version.major });
                self.name_only_filename = owner.fmt("lib{s}.so", .{self.name});
                self.out_lib_filename = self.out_filename;
            }
        } else {
            if (target_info.target.isDarwin()) {
                self.out_lib_filename = self.out_filename;
            } else if (target_info.target.os.tag == .windows) {
                self.out_lib_filename = owner.fmt("{s}.lib", .{self.name});
            } else {
                self.out_lib_filename = self.out_filename;
            }
        }
    }

    if (root_src) |rs| rs.addStepDependencies(&self.step);

    return self;
}

pub fn installHeader(cs: *Compile, src_path: []const u8, dest_rel_path: []const u8) void {
    const b = cs.step.owner;
    const install_file = b.addInstallHeaderFile(src_path, dest_rel_path);
    b.getInstallStep().dependOn(&install_file.step);
    cs.installed_headers.append(&install_file.step) catch @panic("OOM");
}

pub const InstallConfigHeaderOptions = struct {
    install_dir: InstallDir = .header,
    dest_rel_path: ?[]const u8 = null,
};

pub fn installConfigHeader(
    cs: *Compile,
    config_header: *Step.ConfigHeader,
    options: InstallConfigHeaderOptions,
) void {
    const dest_rel_path = options.dest_rel_path orelse config_header.include_path;
    const b = cs.step.owner;
    const install_file = b.addInstallFileWithDir(
        .{ .generated = &config_header.output_file },
        options.install_dir,
        dest_rel_path,
    );
    install_file.step.dependOn(&config_header.step);
    b.getInstallStep().dependOn(&install_file.step);
    cs.installed_headers.append(&install_file.step) catch @panic("OOM");
}

pub fn installHeadersDirectory(
    a: *Compile,
    src_dir_path: []const u8,
    dest_rel_path: []const u8,
) void {
    return installHeadersDirectoryOptions(a, .{
        .source_dir = .{ .path = src_dir_path },
        .install_dir = .header,
        .install_subdir = dest_rel_path,
    });
}

pub fn installHeadersDirectoryOptions(
    cs: *Compile,
    options: std.Build.Step.InstallDir.Options,
) void {
    const b = cs.step.owner;
    const install_dir = b.addInstallDirectory(options);
    b.getInstallStep().dependOn(&install_dir.step);
    cs.installed_headers.append(&install_dir.step) catch @panic("OOM");
}

pub fn installLibraryHeaders(cs: *Compile, l: *Compile) void {
    assert(l.kind == .lib);
    const b = cs.step.owner;
    const install_step = b.getInstallStep();
    // Copy each element from installed_headers, modifying the builder
    // to be the new parent's builder.
    for (l.installed_headers.items) |step| {
        const step_copy = switch (step.id) {
            inline .install_file, .install_dir => |id| blk: {
                const T = id.Type();
                const ptr = b.allocator.create(T) catch @panic("OOM");
                ptr.* = step.cast(T).?.*;
                ptr.dest_builder = b;
                break :blk &ptr.step;
            },
            else => unreachable,
        };
        cs.installed_headers.append(step_copy) catch @panic("OOM");
        install_step.dependOn(step_copy);
    }
    cs.installed_headers.appendSlice(l.installed_headers.items) catch @panic("OOM");
}

pub fn addObjCopy(cs: *Compile, options: Step.ObjCopy.Options) *Step.ObjCopy {
    const b = cs.step.owner;
    var copy = options;
    if (copy.basename == null) {
        if (options.format) |f| {
            copy.basename = b.fmt("{s}.{s}", .{ cs.name, @tagName(f) });
        } else {
            copy.basename = cs.name;
        }
    }
    return b.addObjCopy(cs.getEmittedBin(), copy);
}

/// This function would run in the context of the package that created the executable,
/// which is undesirable when running an executable provided by a dependency package.
pub const run = @compileError("deprecated; use std.Build.addRunArtifact");

/// This function would install in the context of the package that created the artifact,
/// which is undesirable when installing an artifact provided by a dependency package.
pub const install = @compileError("deprecated; use std.Build.installArtifact");

pub fn checkObject(self: *Compile) *Step.CheckObject {
    return Step.CheckObject.create(self.step.owner, self.getEmittedBin(), self.target_info.target.ofmt);
}

/// deprecated: use `setLinkerScript`
pub const setLinkerScriptPath = setLinkerScript;

pub fn setLinkerScript(self: *Compile, source: LazyPath) void {
    const b = self.step.owner;
    self.linker_script = source.dupe(b);
    source.addStepDependencies(&self.step);
}

pub fn forceUndefinedSymbol(self: *Compile, symbol_name: []const u8) void {
    const b = self.step.owner;
    self.force_undefined_symbols.put(b.dupe(symbol_name), {}) catch @panic("OOM");
}

pub fn linkFramework(self: *Compile, framework_name: []const u8) void {
    const b = self.step.owner;
    self.frameworks.put(b.dupe(framework_name), .{}) catch @panic("OOM");
}

pub fn linkFrameworkNeeded(self: *Compile, framework_name: []const u8) void {
    const b = self.step.owner;
    self.frameworks.put(b.dupe(framework_name), .{
        .needed = true,
    }) catch @panic("OOM");
}

pub fn linkFrameworkWeak(self: *Compile, framework_name: []const u8) void {
    const b = self.step.owner;
    self.frameworks.put(b.dupe(framework_name), .{
        .weak = true,
    }) catch @panic("OOM");
}

/// Returns whether the library, executable, or object depends on a particular system library.
pub fn dependsOnSystemLibrary(self: Compile, name: []const u8) bool {
    if (isLibCLibrary(name)) {
        return self.is_linking_libc;
    }
    if (isLibCppLibrary(name)) {
        return self.is_linking_libcpp;
    }
    for (self.link_objects.items) |link_object| {
        switch (link_object) {
            .system_lib => |lib| if (mem.eql(u8, lib.name, name)) return true,
            else => continue,
        }
    }
    return false;
}

pub fn linkLibrary(self: *Compile, lib: *Compile) void {
    assert(lib.kind == .lib);
    self.linkLibraryOrObject(lib);
}

pub fn isDynamicLibrary(self: *Compile) bool {
    return self.kind == .lib and self.linkage == Linkage.dynamic;
}

pub fn isStaticLibrary(self: *Compile) bool {
    return self.kind == .lib and self.linkage != Linkage.dynamic;
}

pub fn producesPdbFile(self: *Compile) bool {
    // TODO: Is this right? Isn't PDB for *any* PE/COFF file?
    // TODO: just share this logic with the compiler, silly!
    if (!self.target.isWindows() and !self.target.isUefi()) return false;
    if (self.target.getObjectFormat() == .c) return false;
    if (self.strip == true or (self.strip == null and self.optimize == .ReleaseSmall)) return false;
    return self.isDynamicLibrary() or self.kind == .exe or self.kind == .@"test";
}

pub fn producesImplib(self: *Compile) bool {
    return self.isDynamicLibrary() and self.target.isWindows();
}

pub fn linkLibC(self: *Compile) void {
    self.is_linking_libc = true;
}

pub fn linkLibCpp(self: *Compile) void {
    self.is_linking_libcpp = true;
}

/// If the value is omitted, it is set to 1.
/// `name` and `value` need not live longer than the function call.
pub fn defineCMacro(self: *Compile, name: []const u8, value: ?[]const u8) void {
    const b = self.step.owner;
    const macro = std.Build.constructCMacro(b.allocator, name, value);
    self.c_macros.append(macro) catch @panic("OOM");
}

/// name_and_value looks like [name]=[value]. If the value is omitted, it is set to 1.
pub fn defineCMacroRaw(self: *Compile, name_and_value: []const u8) void {
    const b = self.step.owner;
    self.c_macros.append(b.dupe(name_and_value)) catch @panic("OOM");
}

/// deprecated: use linkSystemLibrary2
pub fn linkSystemLibraryName(self: *Compile, name: []const u8) void {
    return linkSystemLibrary2(self, name, .{ .use_pkg_config = .no });
}

/// deprecated: use linkSystemLibrary2
pub fn linkSystemLibraryNeededName(self: *Compile, name: []const u8) void {
    return linkSystemLibrary2(self, name, .{ .needed = true, .use_pkg_config = .no });
}

/// deprecated: use linkSystemLibrary2
pub fn linkSystemLibraryWeakName(self: *Compile, name: []const u8) void {
    return linkSystemLibrary2(self, name, .{ .weak = true, .use_pkg_config = .no });
}

/// deprecated: use linkSystemLibrary2
pub fn linkSystemLibraryPkgConfigOnly(self: *Compile, lib_name: []const u8) void {
    return linkSystemLibrary2(self, lib_name, .{ .use_pkg_config = .force });
}

/// deprecated: use linkSystemLibrary2
pub fn linkSystemLibraryNeededPkgConfigOnly(self: *Compile, lib_name: []const u8) void {
    return linkSystemLibrary2(self, lib_name, .{ .needed = true, .use_pkg_config = .force });
}

/// Run pkg-config for the given library name and parse the output, returning the arguments
/// that should be passed to zig to link the given library.
fn runPkgConfig(self: *Compile, lib_name: []const u8) ![]const []const u8 {
    const b = self.step.owner;
    const pkg_name = match: {
        // First we have to map the library name to pkg config name. Unfortunately,
        // there are several examples where this is not straightforward:
        // -lSDL2 -> pkg-config sdl2
        // -lgdk-3 -> pkg-config gdk-3.0
        // -latk-1.0 -> pkg-config atk
        const pkgs = try getPkgConfigList(b);

        // Exact match means instant winner.
        for (pkgs) |pkg| {
            if (mem.eql(u8, pkg.name, lib_name)) {
                break :match pkg.name;
            }
        }

        // Next we'll try ignoring case.
        for (pkgs) |pkg| {
            if (std.ascii.eqlIgnoreCase(pkg.name, lib_name)) {
                break :match pkg.name;
            }
        }

        // Now try appending ".0".
        for (pkgs) |pkg| {
            if (std.ascii.indexOfIgnoreCase(pkg.name, lib_name)) |pos| {
                if (pos != 0) continue;
                if (mem.eql(u8, pkg.name[lib_name.len..], ".0")) {
                    break :match pkg.name;
                }
            }
        }

        // Trimming "-1.0".
        if (mem.endsWith(u8, lib_name, "-1.0")) {
            const trimmed_lib_name = lib_name[0 .. lib_name.len - "-1.0".len];
            for (pkgs) |pkg| {
                if (std.ascii.eqlIgnoreCase(pkg.name, trimmed_lib_name)) {
                    break :match pkg.name;
                }
            }
        }

        return error.PackageNotFound;
    };

    var code: u8 = undefined;
    const stdout = if (b.execAllowFail(&[_][]const u8{
        "pkg-config",
        pkg_name,
        "--cflags",
        "--libs",
    }, &code, .Ignore)) |stdout| stdout else |err| switch (err) {
        error.ProcessTerminated => return error.PkgConfigCrashed,
        error.ExecNotSupported => return error.PkgConfigFailed,
        error.ExitCodeFailure => return error.PkgConfigFailed,
        error.FileNotFound => return error.PkgConfigNotInstalled,
        else => return err,
    };

    var zig_args = ArrayList([]const u8).init(b.allocator);
    defer zig_args.deinit();

    var it = mem.tokenizeAny(u8, stdout, " \r\n\t");
    while (it.next()) |tok| {
        if (mem.eql(u8, tok, "-I")) {
            const dir = it.next() orelse return error.PkgConfigInvalidOutput;
            try zig_args.appendSlice(&[_][]const u8{ "-I", dir });
        } else if (mem.startsWith(u8, tok, "-I")) {
            try zig_args.append(tok);
        } else if (mem.eql(u8, tok, "-L")) {
            const dir = it.next() orelse return error.PkgConfigInvalidOutput;
            try zig_args.appendSlice(&[_][]const u8{ "-L", dir });
        } else if (mem.startsWith(u8, tok, "-L")) {
            try zig_args.append(tok);
        } else if (mem.eql(u8, tok, "-l")) {
            const lib = it.next() orelse return error.PkgConfigInvalidOutput;
            try zig_args.appendSlice(&[_][]const u8{ "-l", lib });
        } else if (mem.startsWith(u8, tok, "-l")) {
            try zig_args.append(tok);
        } else if (mem.eql(u8, tok, "-D")) {
            const macro = it.next() orelse return error.PkgConfigInvalidOutput;
            try zig_args.appendSlice(&[_][]const u8{ "-D", macro });
        } else if (mem.startsWith(u8, tok, "-D")) {
            try zig_args.append(tok);
        } else if (b.debug_pkg_config) {
            return self.step.fail("unknown pkg-config flag '{s}'", .{tok});
        }
    }

    return zig_args.toOwnedSlice();
}

pub fn linkSystemLibrary(self: *Compile, name: []const u8) void {
    self.linkSystemLibrary2(name, .{});
}

/// deprecated: use linkSystemLibrary2
pub fn linkSystemLibraryNeeded(self: *Compile, name: []const u8) void {
    return linkSystemLibrary2(self, name, .{ .needed = true });
}

/// deprecated: use linkSystemLibrary2
pub fn linkSystemLibraryWeak(self: *Compile, name: []const u8) void {
    return linkSystemLibrary2(self, name, .{ .weak = true });
}

pub const LinkSystemLibraryOptions = struct {
    needed: bool = false,
    weak: bool = false,
    use_pkg_config: SystemLib.UsePkgConfig = .yes,
    preferred_link_mode: std.builtin.LinkMode = .Dynamic,
    search_strategy: SystemLib.SearchStrategy = .paths_first,
};

pub fn linkSystemLibrary2(
    self: *Compile,
    name: []const u8,
    options: LinkSystemLibraryOptions,
) void {
    const b = self.step.owner;
    if (isLibCLibrary(name)) {
        self.linkLibC();
        return;
    }
    if (isLibCppLibrary(name)) {
        self.linkLibCpp();
        return;
    }

    self.link_objects.append(.{
        .system_lib = .{
            .name = b.dupe(name),
            .needed = options.needed,
            .weak = options.weak,
            .use_pkg_config = options.use_pkg_config,
            .preferred_link_mode = options.preferred_link_mode,
            .search_strategy = options.search_strategy,
        },
    }) catch @panic("OOM");
}

/// Handy when you have many C/C++ source files and want them all to have the same flags.
pub fn addCSourceFiles(self: *Compile, files: []const []const u8, flags: []const []const u8) void {
    const b = self.step.owner;
    const c_source_files = b.allocator.create(CSourceFiles) catch @panic("OOM");

    const files_copy = b.dupeStrings(files);
    const flags_copy = b.dupeStrings(flags);

    c_source_files.* = .{
        .files = files_copy,
        .flags = flags_copy,
    };
    self.link_objects.append(.{ .c_source_files = c_source_files }) catch @panic("OOM");
}

pub fn addCSourceFile(self: *Compile, source: CSourceFile) void {
    const b = self.step.owner;
    const c_source_file = b.allocator.create(CSourceFile) catch @panic("OOM");
    c_source_file.* = source.dupe(b);
    self.link_objects.append(.{ .c_source_file = c_source_file }) catch @panic("OOM");
    source.file.addStepDependencies(&self.step);
}

pub fn setVerboseLink(self: *Compile, value: bool) void {
    self.verbose_link = value;
}

pub fn setVerboseCC(self: *Compile, value: bool) void {
    self.verbose_cc = value;
}

pub fn setLibCFile(self: *Compile, libc_file: ?LazyPath) void {
    const b = self.step.owner;
    self.libc_file = if (libc_file) |f| f.dupe(b) else null;
}

fn getEmittedFileGeneric(self: *Compile, output_file: *?*GeneratedFile) LazyPath {
    if (output_file.*) |g| {
        return .{ .generated = g };
    }
    const arena = self.step.owner.allocator;
    const generated_file = arena.create(GeneratedFile) catch @panic("OOM");
    generated_file.* = .{ .step = &self.step };
    output_file.* = generated_file;
    return .{ .generated = generated_file };
}

/// deprecated: use `getEmittedBinDirectory`
pub const getOutputDirectorySource = getEmittedBinDirectory;

/// Returns the path to the directory that contains the emitted binary file.
pub fn getEmittedBinDirectory(self: *Compile) LazyPath {
    _ = self.getEmittedBin();
    return self.getEmittedFileGeneric(&self.emit_directory);
}

/// deprecated: use `getEmittedBin`
pub const getOutputSource = getEmittedBin;

/// Returns the path to the generated executable, library or object file.
/// To run an executable built with zig build, use `run`, or create an install step and invoke it.
pub fn getEmittedBin(self: *Compile) LazyPath {
    return self.getEmittedFileGeneric(&self.generated_bin);
}

/// deprecated: use `getEmittedImplib`
pub const getOutputLibSource = getEmittedImplib;

/// Returns the path to the generated import library.
/// This function can only be called for libraries.
pub fn getEmittedImplib(self: *Compile) LazyPath {
    assert(self.kind == .lib);
    return self.getEmittedFileGeneric(&self.generated_implib);
}

/// deprecated: use `getEmittedH`
pub const getOutputHSource = getEmittedH;

/// Returns the path to the generated header file.
/// This function can only be called for libraries or objects.
pub fn getEmittedH(self: *Compile) LazyPath {
    assert(self.kind != .exe and self.kind != .@"test");
    return self.getEmittedFileGeneric(&self.generated_h);
}

/// deprecated: use `getEmittedPdb`.
pub const getOutputPdbSource = getEmittedPdb;

/// Returns the generated PDB file.
/// If the compilation does not produce a PDB file, this causes a FileNotFound error
/// at build time.
pub fn getEmittedPdb(self: *Compile) LazyPath {
    _ = self.getEmittedBin();
    return self.getEmittedFileGeneric(&self.generated_pdb);
}

/// Returns the path to the generated documentation directory.
pub fn getEmittedDocs(self: *Compile) LazyPath {
    return self.getEmittedFileGeneric(&self.generated_docs);
}

/// Returns the path to the generated assembly code.
pub fn getEmittedAsm(self: *Compile) LazyPath {
    return self.getEmittedFileGeneric(&self.generated_asm);
}

/// Returns the path to the generated LLVM IR.
pub fn getEmittedLlvmIr(self: *Compile) LazyPath {
    return self.getEmittedFileGeneric(&self.generated_llvm_ir);
}

/// Returns the path to the generated LLVM BC.
pub fn getEmittedLlvmBc(self: *Compile) LazyPath {
    return self.getEmittedFileGeneric(&self.generated_llvm_bc);
}

pub fn addAssemblyFile(self: *Compile, source: LazyPath) void {
    const b = self.step.owner;
    const source_duped = source.dupe(b);
    self.link_objects.append(.{ .assembly_file = source_duped }) catch @panic("OOM");
    source_duped.addStepDependencies(&self.step);
}

pub fn addObjectFile(self: *Compile, source: LazyPath) void {
    const b = self.step.owner;
    self.link_objects.append(.{ .static_path = source.dupe(b) }) catch @panic("OOM");
    source.addStepDependencies(&self.step);
}

pub fn addObject(self: *Compile, obj: *Compile) void {
    assert(obj.kind == .obj);
    self.linkLibraryOrObject(obj);
}

pub fn addSystemIncludePath(self: *Compile, path: LazyPath) void {
    const b = self.step.owner;
    self.include_dirs.append(IncludeDir{ .path_system = path.dupe(b) }) catch @panic("OOM");
    path.addStepDependencies(&self.step);
}

pub fn addIncludePath(self: *Compile, path: LazyPath) void {
    const b = self.step.owner;
    self.include_dirs.append(IncludeDir{ .path = path.dupe(b) }) catch @panic("OOM");
    path.addStepDependencies(&self.step);
}

pub fn addConfigHeader(self: *Compile, config_header: *Step.ConfigHeader) void {
    self.step.dependOn(&config_header.step);
    self.include_dirs.append(.{ .config_header_step = config_header }) catch @panic("OOM");
}

pub fn addLibraryPath(self: *Compile, directory_source: LazyPath) void {
    const b = self.step.owner;
    self.lib_paths.append(directory_source.dupe(b)) catch @panic("OOM");
    directory_source.addStepDependencies(&self.step);
}

pub fn addRPath(self: *Compile, directory_source: LazyPath) void {
    const b = self.step.owner;
    self.rpaths.append(directory_source.dupe(b)) catch @panic("OOM");
    directory_source.addStepDependencies(&self.step);
}

pub fn addFrameworkPath(self: *Compile, directory_source: LazyPath) void {
    const b = self.step.owner;
    self.framework_dirs.append(directory_source.dupe(b)) catch @panic("OOM");
    directory_source.addStepDependencies(&self.step);
}

/// Adds a module to be used with `@import` and exposing it in the current
/// package's module table using `name`.
pub fn addModule(cs: *Compile, name: []const u8, module: *Module) void {
    const b = cs.step.owner;
    cs.modules.put(b.dupe(name), module) catch @panic("OOM");

    var done = std.AutoHashMap(*Module, void).init(b.allocator);
    defer done.deinit();
    cs.addRecursiveBuildDeps(module, &done) catch @panic("OOM");
}

/// Adds a module to be used with `@import` without exposing it in the current
/// package's module table.
pub fn addAnonymousModule(cs: *Compile, name: []const u8, options: std.Build.CreateModuleOptions) void {
    const b = cs.step.owner;
    const module = b.createModule(options);
    return addModule(cs, name, module);
}

pub fn addOptions(cs: *Compile, module_name: []const u8, options: *Step.Options) void {
    addModule(cs, module_name, options.createModule());
}

fn addRecursiveBuildDeps(cs: *Compile, module: *Module, done: *std.AutoHashMap(*Module, void)) !void {
    if (done.contains(module)) return;
    try done.put(module, {});
    module.source_file.addStepDependencies(&cs.step);
    for (module.dependencies.values()) |dep| {
        try cs.addRecursiveBuildDeps(dep, done);
    }
}

/// If Vcpkg was found on the system, it will be added to include and lib
/// paths for the specified target.
pub fn addVcpkgPaths(self: *Compile, linkage: Compile.Linkage) !void {
    const b = self.step.owner;
    // Ideally in the Unattempted case we would call the function recursively
    // after findVcpkgRoot and have only one switch statement, but the compiler
    // cannot resolve the error set.
    switch (b.vcpkg_root) {
        .unattempted => {
            b.vcpkg_root = if (try findVcpkgRoot(b.allocator)) |root|
                VcpkgRoot{ .found = root }
            else
                .not_found;
        },
        .not_found => return error.VcpkgNotFound,
        .found => {},
    }

    switch (b.vcpkg_root) {
        .unattempted => unreachable,
        .not_found => return error.VcpkgNotFound,
        .found => |root| {
            const allocator = b.allocator;
            const triplet = try self.target.vcpkgTriplet(allocator, if (linkage == .static) .Static else .Dynamic);
            defer b.allocator.free(triplet);

            const include_path = b.pathJoin(&.{ root, "installed", triplet, "include" });
            errdefer allocator.free(include_path);
            try self.include_dirs.append(IncludeDir{ .path = .{ .path = include_path } });

            const lib_path = b.pathJoin(&.{ root, "installed", triplet, "lib" });
            try self.lib_paths.append(.{ .path = lib_path });

            self.vcpkg_bin_path = b.pathJoin(&.{ root, "installed", triplet, "bin" });
        },
    }
}

pub fn setExecCmd(self: *Compile, args: []const ?[]const u8) void {
    const b = self.step.owner;
    assert(self.kind == .@"test");
    const duped_args = b.allocator.alloc(?[]u8, args.len) catch @panic("OOM");
    for (args, 0..) |arg, i| {
        duped_args[i] = if (arg) |a| b.dupe(a) else null;
    }
    self.exec_cmd_args = duped_args;
}

fn linkLibraryOrObject(self: *Compile, other: *Compile) void {
    other.getEmittedBin().addStepDependencies(&self.step);
    if (other.target.isWindows() and other.isDynamicLibrary()) {
        other.getEmittedImplib().addStepDependencies(&self.step);
    }

    self.link_objects.append(.{ .other_step = other }) catch @panic("OOM");
    self.include_dirs.append(.{ .other_step = other }) catch @panic("OOM");

    for (other.installed_headers.items) |install_step| {
        self.step.dependOn(install_step);
    }
}

fn appendModuleArgs(
    cs: *Compile,
    zig_args: *ArrayList([]const u8),
) error{OutOfMemory}!void {
    const b = cs.step.owner;
    // First, traverse the whole dependency graph and give every module a unique name, ideally one
    // named after what it's called somewhere in the graph. It will help here to have both a mapping
    // from module to name and a set of all the currently-used names.
    var mod_names = std.AutoHashMap(*Module, []const u8).init(b.allocator);
    var names = std.StringHashMap(void).init(b.allocator);

    var to_name = std.ArrayList(struct {
        name: []const u8,
        mod: *Module,
    }).init(b.allocator);
    {
        var it = cs.modules.iterator();
        while (it.next()) |kv| {
            // While we're traversing the root dependencies, let's make sure that no module names
            // have colons in them, since the CLI forbids it. We handle this for transitive
            // dependencies further down.
            if (std.mem.indexOfScalar(u8, kv.key_ptr.*, ':') != null) {
                @panic("Module names cannot contain colons");
            }
            try to_name.append(.{
                .name = kv.key_ptr.*,
                .mod = kv.value_ptr.*,
            });
        }
    }

    while (to_name.popOrNull()) |dep| {
        if (mod_names.contains(dep.mod)) continue;

        // We'll use this buffer to store the name we decide on
        var buf = try b.allocator.alloc(u8, dep.name.len + 32);
        // First, try just the exposed dependency name
        @memcpy(buf[0..dep.name.len], dep.name);
        var name = buf[0..dep.name.len];
        var n: usize = 0;
        while (names.contains(name)) {
            // If that failed, append an incrementing number to the end
            name = std.fmt.bufPrint(buf, "{s}{}", .{ dep.name, n }) catch unreachable;
            n += 1;
        }

        try mod_names.put(dep.mod, name);
        try names.put(name, {});

        var it = dep.mod.dependencies.iterator();
        while (it.next()) |kv| {
            // Same colon-in-name check as above, but for transitive dependencies.
            if (std.mem.indexOfScalar(u8, kv.key_ptr.*, ':') != null) {
                @panic("Module names cannot contain colons");
            }
            try to_name.append(.{
                .name = kv.key_ptr.*,
                .mod = kv.value_ptr.*,
            });
        }
    }

    // Since the module names given to the CLI are based off of the exposed names, we already know
    // that none of the CLI names have colons in them, so there's no need to check that explicitly.

    // Every module in the graph is now named; output their definitions
    {
        var it = mod_names.iterator();
        while (it.next()) |kv| {
            const mod = kv.key_ptr.*;
            const name = kv.value_ptr.*;

            const deps_str = try constructDepString(b.allocator, mod_names, mod.dependencies);
            const src = mod.builder.pathFromRoot(mod.source_file.getPath(mod.builder));
            try zig_args.append("--mod");
            try zig_args.append(try std.fmt.allocPrint(b.allocator, "{s}:{s}:{s}", .{ name, deps_str, src }));
        }
    }

    // Lastly, output the root dependencies
    const deps_str = try constructDepString(b.allocator, mod_names, cs.modules);
    if (deps_str.len > 0) {
        try zig_args.append("--deps");
        try zig_args.append(deps_str);
    }
}

fn constructDepString(
    allocator: std.mem.Allocator,
    mod_names: std.AutoHashMap(*Module, []const u8),
    deps: std.StringArrayHashMap(*Module),
) ![]const u8 {
    var deps_str = std.ArrayList(u8).init(allocator);
    var it = deps.iterator();
    while (it.next()) |kv| {
        const expose = kv.key_ptr.*;
        const name = mod_names.get(kv.value_ptr.*).?;
        if (std.mem.eql(u8, expose, name)) {
            try deps_str.writer().print("{s},", .{name});
        } else {
            try deps_str.writer().print("{s}={s},", .{ expose, name });
        }
    }
    if (deps_str.items.len > 0) {
        return deps_str.items[0 .. deps_str.items.len - 1]; // omit trailing comma
    } else {
        return "";
    }
}

fn getGeneratedFilePath(self: *Compile, comptime tag_name: []const u8, asking_step: ?*Step) []const u8 {
    const maybe_path: ?*GeneratedFile = @field(self, tag_name);

    const generated_file = maybe_path orelse {
        std.debug.getStderrMutex().lock();
        const stderr = std.io.getStdErr();

        std.Build.dumpBadGetPathHelp(&self.step, stderr, self.step.owner, asking_step) catch {};

        @panic("missing emit option for " ++ tag_name);
    };

    const path = generated_file.path orelse {
        std.debug.getStderrMutex().lock();
        const stderr = std.io.getStdErr();

        std.Build.dumpBadGetPathHelp(&self.step, stderr, self.step.owner, asking_step) catch {};

        @panic(tag_name ++ " is null. Is there a missing step dependency?");
    };

    return path;
}

fn make(step: *Step, prog_node: *std.Progress.Node) !void {
    const b = step.owner;
    const self = @fieldParentPtr(Compile, "step", step);

    if (self.root_src == null and self.link_objects.items.len == 0) {
        return step.fail("the linker needs one or more objects to link", .{});
    }

    var zig_args = ArrayList([]const u8).init(b.allocator);
    defer zig_args.deinit();

    try zig_args.append(b.zig_exe);

    const cmd = switch (self.kind) {
        .lib => "build-lib",
        .exe => "build-exe",
        .obj => "build-obj",
        .@"test" => "test",
    };
    try zig_args.append(cmd);

    if (b.reference_trace) |some| {
        try zig_args.append(try std.fmt.allocPrint(b.allocator, "-freference-trace={d}", .{some}));
    }

    try addFlag(&zig_args, "llvm", self.use_llvm);
    try addFlag(&zig_args, "lld", self.use_lld);

    if (self.target.ofmt) |ofmt| {
        try zig_args.append(try std.fmt.allocPrint(b.allocator, "-ofmt={s}", .{@tagName(ofmt)}));
    }

    if (self.entry_symbol_name) |entry| {
        try zig_args.append("--entry");
        try zig_args.append(entry);
    }

    {
        var it = self.force_undefined_symbols.keyIterator();
        while (it.next()) |symbol_name| {
            try zig_args.append("--force_undefined");
            try zig_args.append(symbol_name.*);
        }
    }

    if (self.stack_size) |stack_size| {
        try zig_args.append("--stack");
        try zig_args.append(try std.fmt.allocPrint(b.allocator, "{}", .{stack_size}));
    }

    if (self.root_src) |root_src| try zig_args.append(root_src.getPath(b));

    // We will add link objects from transitive dependencies, but we want to keep
    // all link objects in the same order provided.
    // This array is used to keep self.link_objects immutable.
    var transitive_deps: TransitiveDeps = .{
        .link_objects = ArrayList(LinkObject).init(b.allocator),
        .seen_system_libs = StringHashMap(void).init(b.allocator),
        .seen_steps = std.AutoHashMap(*const Step, void).init(b.allocator),
        .is_linking_libcpp = self.is_linking_libcpp,
        .is_linking_libc = self.is_linking_libc,
        .frameworks = &self.frameworks,
    };

    try transitive_deps.seen_steps.put(&self.step, {});
    try transitive_deps.add(self.link_objects.items);

    var prev_has_cflags = false;
    var prev_search_strategy: SystemLib.SearchStrategy = .paths_first;
    var prev_preferred_link_mode: std.builtin.LinkMode = .Dynamic;

    for (transitive_deps.link_objects.items) |link_object| {
        switch (link_object) {
            .static_path => |static_path| try zig_args.append(static_path.getPath(b)),

            .other_step => |other| switch (other.kind) {
                .exe => @panic("Cannot link with an executable build artifact"),
                .@"test" => @panic("Cannot link with a test"),
                .obj => {
                    try zig_args.append(other.getEmittedBin().getPath(b));
                },
                .lib => l: {
                    if (self.isStaticLibrary() and other.isStaticLibrary()) {
                        // Avoid putting a static library inside a static library.
                        break :l;
                    }

                    // For DLLs, we gotta link against the implib. For
                    // everything else, we directly link against the library file.
                    const full_path_lib = if (other.producesImplib())
                        other.getGeneratedFilePath("generated_implib", &self.step)
                    else
                        other.getGeneratedFilePath("generated_bin", &self.step);
                    try zig_args.append(full_path_lib);

                    if (other.linkage == Linkage.dynamic and !self.target.isWindows()) {
                        if (fs.path.dirname(full_path_lib)) |dirname| {
                            try zig_args.append("-rpath");
                            try zig_args.append(dirname);
                        }
                    }
                },
            },

            .system_lib => |system_lib| {
                if ((system_lib.search_strategy != prev_search_strategy or
                    system_lib.preferred_link_mode != prev_preferred_link_mode) and
                    self.linkage != .static)
                {
                    switch (system_lib.search_strategy) {
                        .no_fallback => switch (system_lib.preferred_link_mode) {
                            .Dynamic => try zig_args.append("-search_dylibs_only"),
                            .Static => try zig_args.append("-search_static_only"),
                        },
                        .paths_first => switch (system_lib.preferred_link_mode) {
                            .Dynamic => try zig_args.append("-search_paths_first"),
                            .Static => try zig_args.append("-search_paths_first_static"),
                        },
                        .mode_first => switch (system_lib.preferred_link_mode) {
                            .Dynamic => try zig_args.append("-search_dylibs_first"),
                            .Static => try zig_args.append("-search_static_first"),
                        },
                    }
                    prev_search_strategy = system_lib.search_strategy;
                    prev_preferred_link_mode = system_lib.preferred_link_mode;
                }

                const prefix: []const u8 = prefix: {
                    if (system_lib.needed) break :prefix "-needed-l";
                    if (system_lib.weak) break :prefix "-weak-l";
                    break :prefix "-l";
                };
                switch (system_lib.use_pkg_config) {
                    .no => try zig_args.append(b.fmt("{s}{s}", .{ prefix, system_lib.name })),
                    .yes, .force => {
                        if (self.runPkgConfig(system_lib.name)) |args| {
                            try zig_args.appendSlice(args);
                        } else |err| switch (err) {
                            error.PkgConfigInvalidOutput,
                            error.PkgConfigCrashed,
                            error.PkgConfigFailed,
                            error.PkgConfigNotInstalled,
                            error.PackageNotFound,
                            => switch (system_lib.use_pkg_config) {
                                .yes => {
                                    // pkg-config failed, so fall back to linking the library
                                    // by name directly.
                                    try zig_args.append(b.fmt("{s}{s}", .{
                                        prefix,
                                        system_lib.name,
                                    }));
                                },
                                .force => {
                                    panic("pkg-config failed for library {s}", .{system_lib.name});
                                },
                                .no => unreachable,
                            },

                            else => |e| return e,
                        }
                    },
                }
            },

            .assembly_file => |asm_file| {
                if (prev_has_cflags) {
                    try zig_args.append("-cflags");
                    try zig_args.append("--");
                    prev_has_cflags = false;
                }
                try zig_args.append(asm_file.getPath(b));
            },

            .c_source_file => |c_source_file| {
                if (c_source_file.flags.len == 0) {
                    if (prev_has_cflags) {
                        try zig_args.append("-cflags");
                        try zig_args.append("--");
                        prev_has_cflags = false;
                    }
                } else {
                    try zig_args.append("-cflags");
                    for (c_source_file.flags) |arg| {
                        try zig_args.append(arg);
                    }
                    try zig_args.append("--");
                    prev_has_cflags = true;
                }
                try zig_args.append(c_source_file.file.getPath(b));
            },

            .c_source_files => |c_source_files| {
                if (c_source_files.flags.len == 0) {
                    if (prev_has_cflags) {
                        try zig_args.append("-cflags");
                        try zig_args.append("--");
                        prev_has_cflags = false;
                    }
                } else {
                    try zig_args.append("-cflags");
                    for (c_source_files.flags) |flag| {
                        try zig_args.append(flag);
                    }
                    try zig_args.append("--");
                    prev_has_cflags = true;
                }
                for (c_source_files.files) |file| {
                    try zig_args.append(b.pathFromRoot(file));
                }
            },
        }
    }

    if (transitive_deps.is_linking_libcpp) {
        try zig_args.append("-lc++");
    }

    if (transitive_deps.is_linking_libc) {
        try zig_args.append("-lc");
    }

    if (self.image_base) |image_base| {
        try zig_args.append("--image-base");
        try zig_args.append(b.fmt("0x{x}", .{image_base}));
    }

    if (self.filter) |filter| {
        try zig_args.append("--test-filter");
        try zig_args.append(filter);
    }

    if (self.test_evented_io) {
        try zig_args.append("--test-evented-io");
    }

    if (self.test_runner) |test_runner| {
        try zig_args.append("--test-runner");
        try zig_args.append(b.pathFromRoot(test_runner));
    }

    for (b.debug_log_scopes) |log_scope| {
        try zig_args.append("--debug-log");
        try zig_args.append(log_scope);
    }

    if (b.debug_compile_errors) {
        try zig_args.append("--debug-compile-errors");
    }

    if (b.verbose_cimport) try zig_args.append("--verbose-cimport");
    if (b.verbose_air) try zig_args.append("--verbose-air");
    if (b.verbose_llvm_ir) |path| try zig_args.append(b.fmt("--verbose-llvm-ir={s}", .{path}));
    if (b.verbose_llvm_bc) |path| try zig_args.append(b.fmt("--verbose-llvm-bc={s}", .{path}));
    if (b.verbose_link or self.verbose_link) try zig_args.append("--verbose-link");
    if (b.verbose_cc or self.verbose_cc) try zig_args.append("--verbose-cc");
    if (b.verbose_llvm_cpu_features) try zig_args.append("--verbose-llvm-cpu-features");

    if (self.generated_asm != null) try zig_args.append("-femit-asm");
    if (self.generated_bin == null) try zig_args.append("-fno-emit-bin");
    if (self.generated_docs != null) try zig_args.append("-femit-docs");
    if (self.generated_implib != null) try zig_args.append("-femit-implib");
    if (self.generated_llvm_bc != null) try zig_args.append("-femit-llvm-bc");
    if (self.generated_llvm_ir != null) try zig_args.append("-femit-llvm-ir");
    if (self.generated_h != null) try zig_args.append("-femit-h");

    try addFlag(&zig_args, "strip", self.strip);
    try addFlag(&zig_args, "unwind-tables", self.unwind_tables);

    if (self.dwarf_format) |dwarf_format| {
        try zig_args.append(switch (dwarf_format) {
            .@"32" => "-gdwarf32",
            .@"64" => "-gdwarf64",
        });
    }

    switch (self.compress_debug_sections) {
        .none => {},
        .zlib => try zig_args.append("--compress-debug-sections=zlib"),
    }

    if (self.link_eh_frame_hdr) {
        try zig_args.append("--eh-frame-hdr");
    }
    if (self.link_emit_relocs) {
        try zig_args.append("--emit-relocs");
    }
    if (self.link_function_sections) {
        try zig_args.append("-ffunction-sections");
    }
    if (self.link_gc_sections) |x| {
        try zig_args.append(if (x) "--gc-sections" else "--no-gc-sections");
    }
    if (!self.linker_dynamicbase) {
        try zig_args.append("--no-dynamicbase");
    }
    if (self.linker_allow_shlib_undefined) |x| {
        try zig_args.append(if (x) "-fallow-shlib-undefined" else "-fno-allow-shlib-undefined");
    }
    if (self.link_z_notext) {
        try zig_args.append("-z");
        try zig_args.append("notext");
    }
    if (!self.link_z_relro) {
        try zig_args.append("-z");
        try zig_args.append("norelro");
    }
    if (self.link_z_lazy) {
        try zig_args.append("-z");
        try zig_args.append("lazy");
    }
    if (self.link_z_common_page_size) |size| {
        try zig_args.append("-z");
        try zig_args.append(b.fmt("common-page-size={d}", .{size}));
    }
    if (self.link_z_max_page_size) |size| {
        try zig_args.append("-z");
        try zig_args.append(b.fmt("max-page-size={d}", .{size}));
    }

    if (self.libc_file) |libc_file| {
        try zig_args.append("--libc");
        try zig_args.append(libc_file.getPath(b));
    } else if (b.libc_file) |libc_file| {
        try zig_args.append("--libc");
        try zig_args.append(libc_file);
    }

    switch (self.optimize) {
        .Debug => {}, // Skip since it's the default.
        else => try zig_args.append(b.fmt("-O{s}", .{@tagName(self.optimize)})),
    }

    try zig_args.append("--cache-dir");
    try zig_args.append(b.cache_root.path orelse ".");

    try zig_args.append("--global-cache-dir");
    try zig_args.append(b.global_cache_root.path orelse ".");

    try zig_args.append("--name");
    try zig_args.append(self.name);

    if (self.linkage) |some| switch (some) {
        .dynamic => try zig_args.append("-dynamic"),
        .static => try zig_args.append("-static"),
    };
    if (self.kind == .lib and self.linkage != null and self.linkage.? == .dynamic) {
        if (self.version) |version| {
            try zig_args.append("--version");
            try zig_args.append(b.fmt("{}", .{version}));
        }

        if (self.target.isDarwin()) {
            const install_name = self.install_name orelse b.fmt("@rpath/{s}{s}{s}", .{
                self.target.libPrefix(),
                self.name,
                self.target.dynamicLibSuffix(),
            });
            try zig_args.append("-install_name");
            try zig_args.append(install_name);
        }
    }

    if (self.entitlements) |entitlements| {
        try zig_args.appendSlice(&[_][]const u8{ "--entitlements", entitlements });
    }
    if (self.pagezero_size) |pagezero_size| {
        const size = try std.fmt.allocPrint(b.allocator, "{x}", .{pagezero_size});
        try zig_args.appendSlice(&[_][]const u8{ "-pagezero_size", size });
    }
    if (self.headerpad_size) |headerpad_size| {
        const size = try std.fmt.allocPrint(b.allocator, "{x}", .{headerpad_size});
        try zig_args.appendSlice(&[_][]const u8{ "-headerpad", size });
    }
    if (self.headerpad_max_install_names) {
        try zig_args.append("-headerpad_max_install_names");
    }
    if (self.dead_strip_dylibs) {
        try zig_args.append("-dead_strip_dylibs");
    }

    try addFlag(&zig_args, "compiler-rt", self.bundle_compiler_rt);
    try addFlag(&zig_args, "single-threaded", self.single_threaded);
    if (self.disable_stack_probing) {
        try zig_args.append("-fno-stack-check");
    }
    try addFlag(&zig_args, "stack-protector", self.stack_protector);
    if (self.red_zone) |red_zone| {
        if (red_zone) {
            try zig_args.append("-mred-zone");
        } else {
            try zig_args.append("-mno-red-zone");
        }
    }
    try addFlag(&zig_args, "omit-frame-pointer", self.omit_frame_pointer);
    try addFlag(&zig_args, "dll-export-fns", self.dll_export_fns);

    if (self.disable_sanitize_c) {
        try zig_args.append("-fno-sanitize-c");
    }
    if (self.sanitize_thread) {
        try zig_args.append("-fsanitize-thread");
    }
    if (self.rdynamic) {
        try zig_args.append("-rdynamic");
    }
    if (self.import_memory) {
        try zig_args.append("--import-memory");
    }
    if (self.export_memory) {
        try zig_args.append("--export-memory");
    }
    if (self.import_symbols) {
        try zig_args.append("--import-symbols");
    }
    if (self.import_table) {
        try zig_args.append("--import-table");
    }
    if (self.export_table) {
        try zig_args.append("--export-table");
    }
    if (self.initial_memory) |initial_memory| {
        try zig_args.append(b.fmt("--initial-memory={d}", .{initial_memory}));
    }
    if (self.max_memory) |max_memory| {
        try zig_args.append(b.fmt("--max-memory={d}", .{max_memory}));
    }
    if (self.shared_memory) {
        try zig_args.append("--shared-memory");
    }
    if (self.global_base) |global_base| {
        try zig_args.append(b.fmt("--global-base={d}", .{global_base}));
    }

    if (self.code_model != .default) {
        try zig_args.append("-mcmodel");
        try zig_args.append(@tagName(self.code_model));
    }
    if (self.wasi_exec_model) |model| {
        try zig_args.append(b.fmt("-mexec-model={s}", .{@tagName(model)}));
    }
    for (self.export_symbol_names) |symbol_name| {
        try zig_args.append(b.fmt("--export={s}", .{symbol_name}));
    }

    if (!self.target.isNative()) {
        try zig_args.appendSlice(&.{
            "-target", try self.target.zigTriple(b.allocator),
            "-mcpu",   try std.Build.serializeCpu(b.allocator, self.target.getCpu()),
        });

        if (self.target.dynamic_linker.get()) |dynamic_linker| {
            try zig_args.append("--dynamic-linker");
            try zig_args.append(dynamic_linker);
        }
    }

    if (self.linker_script) |linker_script| {
        try zig_args.append("--script");
        try zig_args.append(linker_script.getPath(b));
    }

    if (self.version_script) |version_script| {
        try zig_args.append("--version-script");
        try zig_args.append(b.pathFromRoot(version_script));
    }

    if (self.kind == .@"test") {
        if (self.exec_cmd_args) |exec_cmd_args| {
            for (exec_cmd_args) |cmd_arg| {
                if (cmd_arg) |arg| {
                    try zig_args.append("--test-cmd");
                    try zig_args.append(arg);
                } else {
                    try zig_args.append("--test-cmd-bin");
                }
            }
        }
    }

    try self.appendModuleArgs(&zig_args);

    for (self.include_dirs.items) |include_dir| {
        switch (include_dir) {
            .path => |include_path| {
                try zig_args.append("-I");
                try zig_args.append(include_path.getPath(b));
            },
            .path_system => |include_path| {
                if (b.sysroot != null) {
                    try zig_args.append("-iwithsysroot");
                } else {
                    try zig_args.append("-isystem");
                }

                const resolved_include_path = include_path.getPath(b);

                const common_include_path = if (builtin.os.tag == .windows and b.sysroot != null and fs.path.isAbsolute(resolved_include_path)) blk: {
                    // We need to check for disk designator and strip it out from dir path so
                    // that zig/clang can concat resolved_include_path with sysroot.
                    const disk_designator = fs.path.diskDesignatorWindows(resolved_include_path);

                    if (mem.indexOf(u8, resolved_include_path, disk_designator)) |where| {
                        break :blk resolved_include_path[where + disk_designator.len ..];
                    }

                    break :blk resolved_include_path;
                } else resolved_include_path;

                try zig_args.append(common_include_path);
            },
            .other_step => |other| {
                if (other.generated_h) |header| {
                    try zig_args.append("-isystem");
                    try zig_args.append(fs.path.dirname(header.path.?).?);
                }
                if (other.installed_headers.items.len > 0) {
                    try zig_args.append("-I");
                    try zig_args.append(b.pathJoin(&.{
                        other.step.owner.install_prefix, "include",
                    }));
                }
            },
            .config_header_step => |config_header| {
                const full_file_path = config_header.output_file.path.?;
                const header_dir_path = full_file_path[0 .. full_file_path.len - config_header.include_path.len];
                try zig_args.appendSlice(&.{ "-I", header_dir_path });
            },
        }
    }

    for (self.c_macros.items) |c_macro| {
        try zig_args.append("-D");
        try zig_args.append(c_macro);
    }

    try zig_args.ensureUnusedCapacity(2 * self.lib_paths.items.len);
    for (self.lib_paths.items) |lib_path| {
        zig_args.appendAssumeCapacity("-L");
        zig_args.appendAssumeCapacity(lib_path.getPath2(b, step));
    }

    try zig_args.ensureUnusedCapacity(2 * self.rpaths.items.len);
    for (self.rpaths.items) |rpath| {
        zig_args.appendAssumeCapacity("-rpath");

        if (self.target_info.target.isDarwin()) switch (rpath) {
            .path, .cwd_relative => |path| {
                // On Darwin, we should not try to expand special runtime paths such as
                // * @executable_path
                // * @loader_path
                if (mem.startsWith(u8, path, "@executable_path") or
                    mem.startsWith(u8, path, "@loader_path"))
                {
                    zig_args.appendAssumeCapacity(path);
                    continue;
                }
            },
            .generated => {},
        };

        zig_args.appendAssumeCapacity(rpath.getPath2(b, step));
    }

    for (self.framework_dirs.items) |directory_source| {
        if (b.sysroot != null) {
            try zig_args.append("-iframeworkwithsysroot");
        } else {
            try zig_args.append("-iframework");
        }
        try zig_args.append(directory_source.getPath2(b, step));
        try zig_args.append("-F");
        try zig_args.append(directory_source.getPath2(b, step));
    }

    {
        var it = self.frameworks.iterator();
        while (it.next()) |entry| {
            const name = entry.key_ptr.*;
            const info = entry.value_ptr.*;
            if (info.needed) {
                try zig_args.append("-needed_framework");
            } else if (info.weak) {
                try zig_args.append("-weak_framework");
            } else {
                try zig_args.append("-framework");
            }
            try zig_args.append(name);
        }
    }

    if (b.sysroot) |sysroot| {
        try zig_args.appendSlice(&[_][]const u8{ "--sysroot", sysroot });
    }

    for (b.search_prefixes.items) |search_prefix| {
        var prefix_dir = fs.cwd().openDir(search_prefix, .{}) catch |err| {
            return step.fail("unable to open prefix directory '{s}': {s}", .{
                search_prefix, @errorName(err),
            });
        };
        defer prefix_dir.close();

        // Avoid passing -L and -I flags for nonexistent directories.
        // This prevents a warning, that should probably be upgraded to an error in Zig's
        // CLI parsing code, when the linker sees an -L directory that does not exist.

        if (prefix_dir.accessZ("lib", .{})) |_| {
            try zig_args.appendSlice(&.{
                "-L", try fs.path.join(b.allocator, &.{ search_prefix, "lib" }),
            });
        } else |err| switch (err) {
            error.FileNotFound => {},
            else => |e| return step.fail("unable to access '{s}/lib' directory: {s}", .{
                search_prefix, @errorName(e),
            }),
        }

        if (prefix_dir.accessZ("include", .{})) |_| {
            try zig_args.appendSlice(&.{
                "-I", try fs.path.join(b.allocator, &.{ search_prefix, "include" }),
            });
        } else |err| switch (err) {
            error.FileNotFound => {},
            else => |e| return step.fail("unable to access '{s}/include' directory: {s}", .{
                search_prefix, @errorName(e),
            }),
        }
    }

    try addFlag(&zig_args, "valgrind", self.valgrind_support);
    try addFlag(&zig_args, "each-lib-rpath", self.each_lib_rpath);

    if (self.build_id) |build_id| {
        try zig_args.append(switch (build_id) {
            .hexstring => |hs| b.fmt("--build-id=0x{s}", .{
                std.fmt.fmtSliceHexLower(hs.toSlice()),
            }),
            .none, .fast, .uuid, .sha1, .md5 => b.fmt("--build-id={s}", .{@tagName(build_id)}),
        });
    }

    if (self.zig_lib_dir) |dir| {
        try zig_args.append("--zig-lib-dir");
        try zig_args.append(dir.getPath(b));
    }

    if (self.main_pkg_path) |dir| {
        try zig_args.append("--main-pkg-path");
        try zig_args.append(dir.getPath(b));
    }

    try addFlag(&zig_args, "PIC", self.force_pic);
    try addFlag(&zig_args, "PIE", self.pie);
    try addFlag(&zig_args, "lto", self.want_lto);

    if (self.subsystem) |subsystem| {
        try zig_args.append("--subsystem");
        try zig_args.append(switch (subsystem) {
            .Console => "console",
            .Windows => "windows",
            .Posix => "posix",
            .Native => "native",
            .EfiApplication => "efi_application",
            .EfiBootServiceDriver => "efi_boot_service_driver",
            .EfiRom => "efi_rom",
            .EfiRuntimeDriver => "efi_runtime_driver",
        });
    }

    try zig_args.append("--listen=-");

    // Windows has an argument length limit of 32,766 characters, macOS 262,144 and Linux
    // 2,097,152. If our args exceed 30 KiB, we instead write them to a "response file" and
    // pass that to zig, e.g. via 'zig build-lib @args.rsp'
    // See @file syntax here: https://gcc.gnu.org/onlinedocs/gcc/Overall-Options.html
    var args_length: usize = 0;
    for (zig_args.items) |arg| {
        args_length += arg.len + 1; // +1 to account for null terminator
    }
    if (args_length >= 30 * 1024) {
        try b.cache_root.handle.makePath("args");

        const args_to_escape = zig_args.items[2..];
        var escaped_args = try ArrayList([]const u8).initCapacity(b.allocator, args_to_escape.len);
        arg_blk: for (args_to_escape) |arg| {
            for (arg, 0..) |c, arg_idx| {
                if (c == '\\' or c == '"') {
                    // Slow path for arguments that need to be escaped. We'll need to allocate and copy
                    var escaped = try ArrayList(u8).initCapacity(b.allocator, arg.len + 1);
                    const writer = escaped.writer();
                    try writer.writeAll(arg[0..arg_idx]);
                    for (arg[arg_idx..]) |to_escape| {
                        if (to_escape == '\\' or to_escape == '"') try writer.writeByte('\\');
                        try writer.writeByte(to_escape);
                    }
                    escaped_args.appendAssumeCapacity(escaped.items);
                    continue :arg_blk;
                }
            }
            escaped_args.appendAssumeCapacity(arg); // no escaping needed so just use original argument
        }

        // Write the args to zig-cache/args/<SHA256 hash of args> to avoid conflicts with
        // other zig build commands running in parallel.
        const partially_quoted = try std.mem.join(b.allocator, "\" \"", escaped_args.items);
        const args = try std.mem.concat(b.allocator, u8, &[_][]const u8{ "\"", partially_quoted, "\"" });

        var args_hash: [Sha256.digest_length]u8 = undefined;
        Sha256.hash(args, &args_hash, .{});
        var args_hex_hash: [Sha256.digest_length * 2]u8 = undefined;
        _ = try std.fmt.bufPrint(
            &args_hex_hash,
            "{s}",
            .{std.fmt.fmtSliceHexLower(&args_hash)},
        );

        const args_file = "args" ++ fs.path.sep_str ++ args_hex_hash;
        try b.cache_root.handle.writeFile(args_file, args);

        const resolved_args_file = try mem.concat(b.allocator, u8, &.{
            "@",
            try b.cache_root.join(b.allocator, &.{args_file}),
        });

        zig_args.shrinkRetainingCapacity(2);
        try zig_args.append(resolved_args_file);
    }

    const maybe_output_bin_path = step.evalZigProcess(zig_args.items, prog_node) catch |err| switch (err) {
        error.NeedCompileErrorCheck => {
            assert(self.expect_errors.len != 0);
            try checkCompileErrors(self);
            return;
        },
        else => |e| return e,
    };

    // Update generated files
    if (maybe_output_bin_path) |output_bin_path| {
        const output_dir = fs.path.dirname(output_bin_path).?;

        if (self.emit_directory) |lp| {
            lp.path = output_dir;
        }

        // -femit-bin[=path]         (default) Output machine code
        if (self.generated_bin) |bin| {
            bin.path = b.pathJoin(&.{ output_dir, self.out_filename });
        }

        const sep = std.fs.path.sep;

        // output PDB if someone requested it
        if (self.generated_pdb) |pdb| {
            pdb.path = b.fmt("{s}{c}{s}.pdb", .{ output_dir, sep, self.name });
        }

        // -femit-implib[=path]      (default) Produce an import .lib when building a Windows DLL
        if (self.generated_implib) |implib| {
            implib.path = b.fmt("{s}{c}{s}.lib", .{ output_dir, sep, self.name });
        }

        // -femit-h[=path]           Generate a C header file (.h)
        if (self.generated_h) |lp| {
            lp.path = b.fmt("{s}{c}{s}.h", .{ output_dir, sep, self.name });
        }

        // -femit-docs[=path]        Create a docs/ dir with html documentation
        if (self.generated_docs) |generated_docs| {
            generated_docs.path = b.pathJoin(&.{ output_dir, "docs" });
        }

        // -femit-asm[=path]         Output .s (assembly code)
        if (self.generated_asm) |lp| {
            lp.path = b.fmt("{s}{c}{s}.s", .{ output_dir, sep, self.name });
        }

        // -femit-llvm-ir[=path]     Produce a .ll file with optimized LLVM IR (requires LLVM extensions)
        if (self.generated_llvm_ir) |lp| {
            lp.path = b.fmt("{s}{c}{s}.ll", .{ output_dir, sep, self.name });
        }

        // -femit-llvm-bc[=path]     Produce an optimized LLVM module as a .bc file (requires LLVM extensions)
        if (self.generated_llvm_bc) |lp| {
            lp.path = b.fmt("{s}{c}{s}.bc", .{ output_dir, sep, self.name });
        }
    }

    if (self.kind == .lib and self.linkage != null and self.linkage.? == .dynamic and
        self.version != null and self.target.wantSharedLibSymLinks())
    {
        try doAtomicSymLinks(
            step,
            self.getEmittedBin().getPath(b),
            self.major_only_filename.?,
            self.name_only_filename.?,
        );
    }
}

fn isLibCLibrary(name: []const u8) bool {
    const libc_libraries = [_][]const u8{ "c", "m", "dl", "rt", "pthread" };
    for (libc_libraries) |libc_lib_name| {
        if (mem.eql(u8, name, libc_lib_name))
            return true;
    }
    return false;
}

fn isLibCppLibrary(name: []const u8) bool {
    const libcpp_libraries = [_][]const u8{ "c++", "stdc++" };
    for (libcpp_libraries) |libcpp_lib_name| {
        if (mem.eql(u8, name, libcpp_lib_name))
            return true;
    }
    return false;
}

/// Returned slice must be freed by the caller.
fn findVcpkgRoot(allocator: Allocator) !?[]const u8 {
    const appdata_path = try fs.getAppDataDir(allocator, "vcpkg");
    defer allocator.free(appdata_path);

    const path_file = try fs.path.join(allocator, &[_][]const u8{ appdata_path, "vcpkg.path.txt" });
    defer allocator.free(path_file);

    const file = fs.cwd().openFile(path_file, .{}) catch return null;
    defer file.close();

    const size = @as(usize, @intCast(try file.getEndPos()));
    const vcpkg_path = try allocator.alloc(u8, size);
    const size_read = try file.read(vcpkg_path);
    std.debug.assert(size == size_read);

    return vcpkg_path;
}

pub fn doAtomicSymLinks(
    step: *Step,
    output_path: []const u8,
    filename_major_only: []const u8,
    filename_name_only: []const u8,
) !void {
    const arena = step.owner.allocator;
    const out_dir = fs.path.dirname(output_path) orelse ".";
    const out_basename = fs.path.basename(output_path);
    // sym link for libfoo.so.1 to libfoo.so.1.2.3
    const major_only_path = try fs.path.join(arena, &.{ out_dir, filename_major_only });
    fs.atomicSymLink(arena, out_basename, major_only_path) catch |err| {
        return step.fail("unable to symlink {s} -> {s}: {s}", .{
            major_only_path, out_basename, @errorName(err),
        });
    };
    // sym link for libfoo.so to libfoo.so.1
    const name_only_path = try fs.path.join(arena, &.{ out_dir, filename_name_only });
    fs.atomicSymLink(arena, filename_major_only, name_only_path) catch |err| {
        return step.fail("Unable to symlink {s} -> {s}: {s}", .{
            name_only_path, filename_major_only, @errorName(err),
        });
    };
}

fn execPkgConfigList(self: *std.Build, out_code: *u8) (PkgConfigError || ExecError)![]const PkgConfigPkg {
    const stdout = try self.execAllowFail(&[_][]const u8{ "pkg-config", "--list-all" }, out_code, .Ignore);
    var list = ArrayList(PkgConfigPkg).init(self.allocator);
    errdefer list.deinit();
    var line_it = mem.tokenizeAny(u8, stdout, "\r\n");
    while (line_it.next()) |line| {
        if (mem.trim(u8, line, " \t").len == 0) continue;
        var tok_it = mem.tokenizeAny(u8, line, " \t");
        try list.append(PkgConfigPkg{
            .name = tok_it.next() orelse return error.PkgConfigInvalidOutput,
            .desc = tok_it.rest(),
        });
    }
    return list.toOwnedSlice();
}

fn getPkgConfigList(self: *std.Build) ![]const PkgConfigPkg {
    if (self.pkg_config_pkg_list) |res| {
        return res;
    }
    var code: u8 = undefined;
    if (execPkgConfigList(self, &code)) |list| {
        self.pkg_config_pkg_list = list;
        return list;
    } else |err| {
        const result = switch (err) {
            error.ProcessTerminated => error.PkgConfigCrashed,
            error.ExecNotSupported => error.PkgConfigFailed,
            error.ExitCodeFailure => error.PkgConfigFailed,
            error.FileNotFound => error.PkgConfigNotInstalled,
            error.InvalidName => error.PkgConfigNotInstalled,
            error.PkgConfigInvalidOutput => error.PkgConfigInvalidOutput,
            else => return err,
        };
        self.pkg_config_pkg_list = result;
        return result;
    }
}

fn addFlag(args: *ArrayList([]const u8), comptime name: []const u8, opt: ?bool) !void {
    const cond = opt orelse return;
    try args.ensureUnusedCapacity(1);
    if (cond) {
        args.appendAssumeCapacity("-f" ++ name);
    } else {
        args.appendAssumeCapacity("-fno-" ++ name);
    }
}

const TransitiveDeps = struct {
    link_objects: ArrayList(LinkObject),
    seen_system_libs: StringHashMap(void),
    seen_steps: std.AutoHashMap(*const Step, void),
    is_linking_libcpp: bool,
    is_linking_libc: bool,
    frameworks: *StringHashMap(FrameworkLinkInfo),

    fn add(td: *TransitiveDeps, link_objects: []const LinkObject) !void {
        try td.link_objects.ensureUnusedCapacity(link_objects.len);

        for (link_objects) |link_object| {
            try td.link_objects.append(link_object);
            switch (link_object) {
                .other_step => |other| try addInner(td, other, other.isDynamicLibrary()),
                else => {},
            }
        }
    }

    fn addInner(td: *TransitiveDeps, other: *Compile, dyn: bool) !void {
        // Inherit dependency on libc and libc++
        td.is_linking_libcpp = td.is_linking_libcpp or other.is_linking_libcpp;
        td.is_linking_libc = td.is_linking_libc or other.is_linking_libc;

        // Inherit dependencies on darwin frameworks
        if (!dyn) {
            var it = other.frameworks.iterator();
            while (it.next()) |framework| {
                try td.frameworks.put(framework.key_ptr.*, framework.value_ptr.*);
            }
        }

        // Inherit dependencies on system libraries and static libraries.
        for (other.link_objects.items) |other_link_object| {
            switch (other_link_object) {
                .system_lib => |system_lib| {
                    if ((try td.seen_system_libs.fetchPut(system_lib.name, {})) != null)
                        continue;

                    if (dyn)
                        continue;

                    try td.link_objects.append(other_link_object);
                },
                .other_step => |inner_other| {
                    if ((try td.seen_steps.fetchPut(&inner_other.step, {})) != null)
                        continue;

                    const included_in_lib = (other.kind == .lib and inner_other.kind == .obj);
                    if (!dyn and !included_in_lib)
                        try td.link_objects.append(other_link_object);

                    try addInner(td, inner_other, dyn or inner_other.isDynamicLibrary());
                },
                else => continue,
            }
        }
    }
};

fn checkCompileErrors(self: *Compile) !void {
    // Clear this field so that it does not get printed by the build runner.
    const actual_eb = self.step.result_error_bundle;
    self.step.result_error_bundle = std.zig.ErrorBundle.empty;

    const arena = self.step.owner.allocator;

    var actual_stderr_list = std.ArrayList(u8).init(arena);
    try actual_eb.renderToWriter(.{
        .ttyconf = .no_color,
        .include_reference_trace = false,
        .include_source_line = false,
    }, actual_stderr_list.writer());
    const actual_stderr = try actual_stderr_list.toOwnedSlice();

    // Render the expected lines into a string that we can compare verbatim.
    var expected_generated = std.ArrayList(u8).init(arena);

    var actual_line_it = mem.splitScalar(u8, actual_stderr, '\n');
    for (self.expect_errors) |expect_line| {
        const actual_line = actual_line_it.next() orelse {
            try expected_generated.appendSlice(expect_line);
            try expected_generated.append('\n');
            continue;
        };
        if (mem.endsWith(u8, actual_line, expect_line)) {
            try expected_generated.appendSlice(actual_line);
            try expected_generated.append('\n');
            continue;
        }
        if (mem.startsWith(u8, expect_line, ":?:?: ")) {
            if (mem.endsWith(u8, actual_line, expect_line[":?:?: ".len..])) {
                try expected_generated.appendSlice(actual_line);
                try expected_generated.append('\n');
                continue;
            }
        }
        try expected_generated.appendSlice(expect_line);
        try expected_generated.append('\n');
    }

    if (mem.eql(u8, expected_generated.items, actual_stderr)) return;

    // TODO merge this with the testing.expectEqualStrings logic, and also CheckFile
    return self.step.fail(
        \\
        \\========= expected: =====================
        \\{s}
        \\========= but found: ====================
        \\{s}
        \\=========================================
    , .{ expected_generated.items, actual_stderr });
}

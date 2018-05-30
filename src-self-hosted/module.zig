const std = @import("std");
const os = std.os;
const io = std.io;
const mem = std.mem;
const Buffer = std.Buffer;
const llvm = @import("llvm.zig");
const c = @import("c.zig");
const builtin = @import("builtin");
const Target = @import("target.zig").Target;
const warn = std.debug.warn;
const Token = std.zig.Token;
const ArrayList = std.ArrayList;
const errmsg = @import("errmsg.zig");

pub const Module = struct {
    allocator: &mem.Allocator,
    name: Buffer,
    root_src_path: ?[]const u8,
    module: llvm.ModuleRef,
    context: llvm.ContextRef,
    builder: llvm.BuilderRef,
    target: Target,
    build_mode: builtin.Mode,
    zig_lib_dir: []const u8,

    version_major: u32,
    version_minor: u32,
    version_patch: u32,

    linker_script: ?[]const u8,
    cache_dir: []const u8,
    libc_lib_dir: ?[]const u8,
    libc_static_lib_dir: ?[]const u8,
    libc_include_dir: ?[]const u8,
    msvc_lib_dir: ?[]const u8,
    kernel32_lib_dir: ?[]const u8,
    dynamic_linker: ?[]const u8,
    out_h_path: ?[]const u8,

    is_test: bool,
    each_lib_rpath: bool,
    strip: bool,
    is_static: bool,
    linker_rdynamic: bool,

    clang_argv: []const []const u8,
    llvm_argv: []const []const u8,
    lib_dirs: []const []const u8,
    rpath_list: []const []const u8,
    assembly_files: []const []const u8,
    link_objects: []const []const u8,

    windows_subsystem_windows: bool,
    windows_subsystem_console: bool,

    link_libs_list: ArrayList(&LinkLib),
    libc_link_lib: ?&LinkLib,

    err_color: errmsg.Color,

    verbose_tokenize: bool,
    verbose_ast_tree: bool,
    verbose_ast_fmt: bool,
    verbose_cimport: bool,
    verbose_ir: bool,
    verbose_llvm_ir: bool,
    verbose_link: bool,

    darwin_frameworks: []const []const u8,
    darwin_version_min: DarwinVersionMin,

    test_filters: []const []const u8,
    test_name_prefix: ?[]const u8,

    emit_file_type: Emit,

    kind: Kind,

    pub const DarwinVersionMin = union(enum) {
        None,
        MacOS: []const u8,
        Ios: []const u8,
    };

    pub const Kind = enum {
        Exe,
        Lib,
        Obj,
    };

    pub const LinkLib = struct {
        name: []const u8,
        path: ?[]const u8,

        /// the list of symbols we depend on from this lib
        symbols: ArrayList([]u8),
        provided_explicitly: bool,
    };

    pub const Emit = enum {
        Binary,
        Assembly,
        LlvmIr,
    };

    pub const CliPkg = struct {
        name: []const u8,
        path: []const u8,
        children: ArrayList(&CliPkg),
        parent: ?&CliPkg,

        pub fn init(allocator: &mem.Allocator, name: []const u8, path: []const u8, parent: ?&CliPkg) !&CliPkg {
            var pkg = try allocator.create(CliPkg);
            pkg.name = name;
            pkg.path = path;
            pkg.children = ArrayList(&CliPkg).init(allocator);
            pkg.parent = parent;
            return pkg;
        }

        pub fn deinit(self: &CliPkg) void {
            for (self.children.toSliceConst()) |child| {
                child.deinit();
            }
            self.children.deinit();
        }
    };

    pub fn create(allocator: &mem.Allocator, name: []const u8, root_src_path: ?[]const u8, target: &const Target, kind: Kind, build_mode: builtin.Mode, zig_lib_dir: []const u8, cache_dir: []const u8) !&Module {
        var name_buffer = try Buffer.init(allocator, name);
        errdefer name_buffer.deinit();

        const context = c.LLVMContextCreate() ?? return error.OutOfMemory;
        errdefer c.LLVMContextDispose(context);

        const module = c.LLVMModuleCreateWithNameInContext(name_buffer.ptr(), context) ?? return error.OutOfMemory;
        errdefer c.LLVMDisposeModule(module);

        const builder = c.LLVMCreateBuilderInContext(context) ?? return error.OutOfMemory;
        errdefer c.LLVMDisposeBuilder(builder);

        const module_ptr = try allocator.create(Module);
        errdefer allocator.destroy(module_ptr);

        module_ptr.* = Module{
            .allocator = allocator,
            .name = name_buffer,
            .root_src_path = root_src_path,
            .module = module,
            .context = context,
            .builder = builder,
            .target = target.*,
            .kind = kind,
            .build_mode = build_mode,
            .zig_lib_dir = zig_lib_dir,
            .cache_dir = cache_dir,

            .version_major = 0,
            .version_minor = 0,
            .version_patch = 0,

            .verbose_tokenize = false,
            .verbose_ast_tree = false,
            .verbose_ast_fmt = false,
            .verbose_cimport = false,
            .verbose_ir = false,
            .verbose_llvm_ir = false,
            .verbose_link = false,

            .linker_script = null,
            .libc_lib_dir = null,
            .libc_static_lib_dir = null,
            .libc_include_dir = null,
            .msvc_lib_dir = null,
            .kernel32_lib_dir = null,
            .dynamic_linker = null,
            .out_h_path = null,
            .is_test = false,
            .each_lib_rpath = false,
            .strip = false,
            .is_static = false,
            .linker_rdynamic = false,
            .clang_argv = [][]const u8{},
            .llvm_argv = [][]const u8{},
            .lib_dirs = [][]const u8{},
            .rpath_list = [][]const u8{},
            .assembly_files = [][]const u8{},
            .link_objects = [][]const u8{},
            .windows_subsystem_windows = false,
            .windows_subsystem_console = false,
            .link_libs_list = ArrayList(&LinkLib).init(allocator),
            .libc_link_lib = null,
            .err_color = errmsg.Color.Auto,
            .darwin_frameworks = [][]const u8{},
            .darwin_version_min = DarwinVersionMin.None,
            .test_filters = [][]const u8{},
            .test_name_prefix = null,
            .emit_file_type = Emit.Binary,
        };
        return module_ptr;
    }

    fn dump(self: &Module) void {
        c.LLVMDumpModule(self.module);
    }

    pub fn destroy(self: &Module) void {
        c.LLVMDisposeBuilder(self.builder);
        c.LLVMDisposeModule(self.module);
        c.LLVMContextDispose(self.context);
        self.name.deinit();

        self.allocator.destroy(self);
    }

    pub fn build(self: &Module) !void {
        if (self.llvm_argv.len != 0) {
            var c_compatible_args = try std.cstr.NullTerminated2DArray.fromSlices(self.allocator, [][]const []const u8{
                [][]const u8{"zig (LLVM option parsing)"},
                self.llvm_argv,
            });
            defer c_compatible_args.deinit();
            c.ZigLLVMParseCommandLineOptions(self.llvm_argv.len + 1, c_compatible_args.ptr);
        }

        const root_src_path = self.root_src_path ?? @panic("TODO handle null root src path");
        const root_src_real_path = os.path.real(self.allocator, root_src_path) catch |err| {
            try printError("unable to get real path '{}': {}", root_src_path, err);
            return err;
        };
        errdefer self.allocator.free(root_src_real_path);

        const source_code = io.readFileAlloc(self.allocator, root_src_real_path) catch |err| {
            try printError("unable to open '{}': {}", root_src_real_path, err);
            return err;
        };
        errdefer self.allocator.free(source_code);

        warn("====input:====\n");

        warn("{}", source_code);

        warn("====parse:====\n");

        var tree = try std.zig.parse(self.allocator, source_code);
        defer tree.deinit();

        var stderr_file = try std.io.getStdErr();
        var stderr_file_out_stream = std.io.FileOutStream.init(&stderr_file);
        const out_stream = &stderr_file_out_stream.stream;

        warn("====fmt:====\n");
        _ = try std.zig.render(self.allocator, out_stream, &tree);

        warn("====ir:====\n");
        warn("TODO\n\n");

        warn("====llvm ir:====\n");
        self.dump();
    }

    pub fn link(self: &Module, out_file: ?[]const u8) !void {
        warn("TODO link");
        return error.Todo;
    }

    pub fn addLinkLib(self: &Module, name: []const u8, provided_explicitly: bool) !&LinkLib {
        const is_libc = mem.eql(u8, name, "c");

        if (is_libc) {
            if (self.libc_link_lib) |libc_link_lib| {
                return libc_link_lib;
            }
        }

        for (self.link_libs_list.toSliceConst()) |existing_lib| {
            if (mem.eql(u8, name, existing_lib.name)) {
                return existing_lib;
            }
        }

        const link_lib = try self.allocator.create(LinkLib);
        link_lib.* = LinkLib{
            .name = name,
            .path = null,
            .provided_explicitly = provided_explicitly,
            .symbols = ArrayList([]u8).init(self.allocator),
        };
        try self.link_libs_list.append(link_lib);
        if (is_libc) {
            self.libc_link_lib = link_lib;
        }
        return link_lib;
    }
};

fn printError(comptime format: []const u8, args: ...) !void {
    var stderr_file = try std.io.getStdErr();
    var stderr_file_out_stream = std.io.FileOutStream.init(&stderr_file);
    const out_stream = &stderr_file_out_stream.stream;
    try out_stream.print(format, args);
}

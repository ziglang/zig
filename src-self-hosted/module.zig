const std = @import("std");
const os = std.os;
const io = std.io;
const mem = std.mem;
const Allocator = mem.Allocator;
const Buffer = std.Buffer;
const llvm = @import("llvm.zig");
const c = @import("c.zig");
const builtin = @import("builtin");
const Target = @import("target.zig").Target;
const warn = std.debug.warn;
const Token = std.zig.Token;
const ArrayList = std.ArrayList;
const errmsg = @import("errmsg.zig");
const ast = std.zig.ast;
const event = std.event;
const assert = std.debug.assert;

pub const Module = struct {
    loop: *event.Loop,
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

    link_libs_list: ArrayList(*LinkLib),
    libc_link_lib: ?*LinkLib,

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

    link_out_file: ?[]const u8,
    events: *event.Channel(Event),

    exported_symbol_names: event.Locked(Decl.Table),

    /// Before code generation starts, must wait on this group to make sure
    /// the build is complete.
    build_group: event.Group(BuildError!void),

    compile_errors: event.Locked(CompileErrList),

    const CompileErrList = std.ArrayList(*errmsg.Msg);

    // TODO handle some of these earlier and report them in a way other than error codes
    pub const BuildError = error{
        OutOfMemory,
        EndOfStream,
        BadFd,
        Io,
        IsDir,
        Unexpected,
        SystemResources,
        SharingViolation,
        PathAlreadyExists,
        FileNotFound,
        AccessDenied,
        PipeBusy,
        FileTooBig,
        SymLinkLoop,
        ProcessFdQuotaExceeded,
        NameTooLong,
        SystemFdQuotaExceeded,
        NoDevice,
        PathNotFound,
        NoSpaceLeft,
        NotDir,
        FileSystem,
        OperationAborted,
        IoPending,
        BrokenPipe,
        WouldBlock,
        FileClosed,
        DestinationAddressRequired,
        DiskQuota,
        InputOutput,
        NoStdHandles,
        Overflow,
        NotSupported,
        BufferTooSmall,
    };

    pub const Event = union(enum) {
        Ok,
        Fail: []*errmsg.Msg,
        Error: BuildError,
    };

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

    pub fn create(
        loop: *event.Loop,
        name: []const u8,
        root_src_path: ?[]const u8,
        target: *const Target,
        kind: Kind,
        build_mode: builtin.Mode,
        zig_lib_dir: []const u8,
        cache_dir: []const u8,
    ) !*Module {
        var name_buffer = try Buffer.init(loop.allocator, name);
        errdefer name_buffer.deinit();

        const context = c.LLVMContextCreate() orelse return error.OutOfMemory;
        errdefer c.LLVMContextDispose(context);

        const module = c.LLVMModuleCreateWithNameInContext(name_buffer.ptr(), context) orelse return error.OutOfMemory;
        errdefer c.LLVMDisposeModule(module);

        const builder = c.LLVMCreateBuilderInContext(context) orelse return error.OutOfMemory;
        errdefer c.LLVMDisposeBuilder(builder);

        const events = try event.Channel(Event).create(loop, 0);
        errdefer events.destroy();

        return loop.allocator.create(Module{
            .loop = loop,
            .events = events,
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
            .link_libs_list = ArrayList(*LinkLib).init(loop.allocator),
            .libc_link_lib = null,
            .err_color = errmsg.Color.Auto,
            .darwin_frameworks = [][]const u8{},
            .darwin_version_min = DarwinVersionMin.None,
            .test_filters = [][]const u8{},
            .test_name_prefix = null,
            .emit_file_type = Emit.Binary,
            .link_out_file = null,
            .exported_symbol_names = event.Locked(Decl.Table).init(loop, Decl.Table.init(loop.allocator)),
            .build_group = event.Group(BuildError!void).init(loop),
            .compile_errors = event.Locked(CompileErrList).init(loop, CompileErrList.init(loop.allocator)),
        });
    }

    fn dump(self: *Module) void {
        c.LLVMDumpModule(self.module);
    }

    pub fn destroy(self: *Module) void {
        self.events.destroy();
        c.LLVMDisposeBuilder(self.builder);
        c.LLVMDisposeModule(self.module);
        c.LLVMContextDispose(self.context);
        self.name.deinit();

        self.a().destroy(self);
    }

    pub fn build(self: *Module) !void {
        if (self.llvm_argv.len != 0) {
            var c_compatible_args = try std.cstr.NullTerminated2DArray.fromSlices(self.a(), [][]const []const u8{
                [][]const u8{"zig (LLVM option parsing)"},
                self.llvm_argv,
            });
            defer c_compatible_args.deinit();
            // TODO this sets global state
            c.ZigLLVMParseCommandLineOptions(self.llvm_argv.len + 1, c_compatible_args.ptr);
        }

        _ = try async<self.a()> self.buildAsync();
    }

    async fn buildAsync(self: *Module) void {
        while (true) {
            // TODO directly awaiting async should guarantee memory allocation elision
            // TODO also async before suspending should guarantee memory allocation elision
            (await (async self.addRootSrc() catch unreachable)) catch |err| {
                await (async self.events.put(Event{ .Error = err }) catch unreachable);
                return;
            };
            const compile_errors = blk: {
                const held = await (async self.compile_errors.acquire() catch unreachable);
                defer held.release();
                break :blk held.value.toOwnedSlice();
            };

            if (compile_errors.len == 0) {
                await (async self.events.put(Event.Ok) catch unreachable);
            } else {
                await (async self.events.put(Event{ .Fail = compile_errors }) catch unreachable);
            }
            // for now we stop after 1
            return;
        }
    }

    async fn addRootSrc(self: *Module) !void {
        const root_src_path = self.root_src_path orelse @panic("TODO handle null root src path");
        // TODO async/await os.path.real
        const root_src_real_path = os.path.real(self.a(), root_src_path) catch |err| {
            try printError("unable to get real path '{}': {}", root_src_path, err);
            return err;
        };
        errdefer self.a().free(root_src_real_path);

        // TODO async/await readFileAlloc()
        const source_code = io.readFileAlloc(self.a(), root_src_real_path) catch |err| {
            try printError("unable to open '{}': {}", root_src_real_path, err);
            return err;
        };
        errdefer self.a().free(source_code);

        const parsed_file = try self.a().create(ParsedFile{
            .tree = undefined,
            .realpath = root_src_real_path,
        });
        errdefer self.a().destroy(parsed_file);

        parsed_file.tree = try std.zig.parse(self.a(), source_code);
        errdefer parsed_file.tree.deinit();

        const tree = &parsed_file.tree;

        // create empty struct for it
        const decls = try Scope.Decls.create(self.a(), null);
        errdefer decls.destroy();

        var decl_group = event.Group(BuildError!void).init(self.loop);
        errdefer decl_group.cancelAll();

        var it = tree.root_node.decls.iterator(0);
        while (it.next()) |decl_ptr| {
            const decl = decl_ptr.*;
            switch (decl.id) {
                ast.Node.Id.Comptime => @panic("TODO"),
                ast.Node.Id.VarDecl => @panic("TODO"),
                ast.Node.Id.FnProto => {
                    const fn_proto = @fieldParentPtr(ast.Node.FnProto, "base", decl);

                    const name = if (fn_proto.name_token) |name_token| tree.tokenSlice(name_token) else {
                        try self.addCompileError(parsed_file, errmsg.Span{
                            .first = fn_proto.fn_token,
                            .last = fn_proto.fn_token + 1,
                        }, "missing function name");
                        continue;
                    };

                    const fn_decl = try self.a().create(Decl.Fn{
                        .base = Decl{
                            .id = Decl.Id.Fn,
                            .name = name,
                            .visib = parseVisibToken(tree, fn_proto.visib_token),
                            .resolution = Decl.Resolution.Unresolved,
                        },
                        .value = Decl.Fn.Val{ .Unresolved = {} },
                        .fn_proto = fn_proto,
                    });
                    errdefer self.a().destroy(fn_decl);

                    try decl_group.call(addTopLevelDecl, self, parsed_file, &fn_decl.base);
                },
                ast.Node.Id.TestDecl => @panic("TODO"),
                else => unreachable,
            }
        }
        try await (async decl_group.wait() catch unreachable);
        try await (async self.build_group.wait() catch unreachable);
    }

    async fn addTopLevelDecl(self: *Module, parsed_file: *ParsedFile, decl: *Decl) !void {
        const is_export = decl.isExported(&parsed_file.tree);

        if (is_export) {
            try self.build_group.call(verifyUniqueSymbol, self, parsed_file, decl);
            try self.build_group.call(generateDecl, self, parsed_file, decl);
        }
    }

    fn addCompileError(self: *Module, parsed_file: *ParsedFile, span: errmsg.Span, comptime fmt: []const u8, args: ...) !void {
        const text = try std.fmt.allocPrint(self.loop.allocator, fmt, args);
        errdefer self.loop.allocator.free(text);

        try self.build_group.call(addCompileErrorAsync, self, parsed_file, span.first, span.last, text);
    }

    async fn addCompileErrorAsync(
        self: *Module,
        parsed_file: *ParsedFile,
        first_token: ast.TokenIndex,
        last_token: ast.TokenIndex,
        text: []u8,
    ) !void {
        const msg = try self.loop.allocator.create(errmsg.Msg{
            .path = parsed_file.realpath,
            .text = text,
            .span = errmsg.Span{
                .first = first_token,
                .last = last_token,
            },
            .tree = &parsed_file.tree,
        });
        errdefer self.loop.allocator.destroy(msg);

        const compile_errors = await (async self.compile_errors.acquire() catch unreachable);
        defer compile_errors.release();

        try compile_errors.value.append(msg);
    }

    async fn verifyUniqueSymbol(self: *Module, parsed_file: *ParsedFile, decl: *Decl) !void {
        const exported_symbol_names = await (async self.exported_symbol_names.acquire() catch unreachable);
        defer exported_symbol_names.release();

        if (try exported_symbol_names.value.put(decl.name, decl)) |other_decl| {
            try self.addCompileError(
                parsed_file,
                decl.getSpan(),
                "exported symbol collision: '{}'",
                decl.name,
            );
        }
    }

    /// This declaration has been blessed as going into the final code generation.
    async fn generateDecl(self: *Module, parsed_file: *ParsedFile, decl: *Decl) void {
        switch (decl.id) {
            Decl.Id.Var => @panic("TODO"),
            Decl.Id.Fn => {
                const fn_decl = @fieldParentPtr(Decl.Fn, "base", decl);
                return await (async self.generateDeclFn(parsed_file, fn_decl) catch unreachable);
            },
            Decl.Id.CompTime => @panic("TODO"),
        }
    }

    async fn generateDeclFn(self: *Module, parsed_file: *ParsedFile, fn_decl: *Decl.Fn) void {
        fn_decl.value = Decl.Fn.Val{ .Ok = Value.Fn{} };
    }

    pub fn link(self: *Module, out_file: ?[]const u8) !void {
        warn("TODO link");
        return error.Todo;
    }

    pub fn addLinkLib(self: *Module, name: []const u8, provided_explicitly: bool) !*LinkLib {
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

        const link_lib = try self.a().create(LinkLib{
            .name = name,
            .path = null,
            .provided_explicitly = provided_explicitly,
            .symbols = ArrayList([]u8).init(self.a()),
        });
        try self.link_libs_list.append(link_lib);
        if (is_libc) {
            self.libc_link_lib = link_lib;
        }
        return link_lib;
    }

    fn a(self: Module) *mem.Allocator {
        return self.loop.allocator;
    }
};

fn printError(comptime format: []const u8, args: ...) !void {
    var stderr_file = try std.io.getStdErr();
    var stderr_file_out_stream = std.io.FileOutStream.init(&stderr_file);
    const out_stream = &stderr_file_out_stream.stream;
    try out_stream.print(format, args);
}

fn parseVisibToken(tree: *ast.Tree, optional_token_index: ?ast.TokenIndex) Visib {
    if (optional_token_index) |token_index| {
        const token = tree.tokens.at(token_index);
        assert(token.id == Token.Id.Keyword_pub);
        return Visib.Pub;
    } else {
        return Visib.Private;
    }
}

pub const Scope = struct {
    id: Id,
    parent: ?*Scope,

    pub const Id = enum {
        Decls,
        Block,
    };

    pub const Decls = struct {
        base: Scope,
        table: Decl.Table,

        pub fn create(a: *Allocator, parent: ?*Scope) !*Decls {
            const self = try a.create(Decls{
                .base = Scope{
                    .id = Id.Decls,
                    .parent = parent,
                },
                .table = undefined,
            });
            errdefer a.destroy(self);

            self.table = Decl.Table.init(a);
            errdefer self.table.deinit();

            return self;
        }

        pub fn destroy(self: *Decls) void {
            self.table.deinit();
            self.table.allocator.destroy(self);
            self.* = undefined;
        }
    };

    pub const Block = struct {
        base: Scope,
    };
};

pub const Visib = enum {
    Private,
    Pub,
};

pub const Decl = struct {
    id: Id,
    name: []const u8,
    visib: Visib,
    resolution: Resolution,

    pub const Table = std.HashMap([]const u8, *Decl, mem.hash_slice_u8, mem.eql_slice_u8);

    pub fn isExported(base: *const Decl, tree: *ast.Tree) bool {
        switch (base.id) {
            Id.Fn => {
                const fn_decl = @fieldParentPtr(Fn, "base", base);
                return fn_decl.isExported(tree);
            },
            else => return false,
        }
    }

    pub fn getSpan(base: *const Decl) errmsg.Span {
        switch (base.id) {
            Id.Fn => {
                const fn_decl = @fieldParentPtr(Fn, "base", base);
                const fn_proto = fn_decl.fn_proto;
                const start = fn_proto.fn_token;
                const end = fn_proto.name_token orelse start;
                return errmsg.Span{
                    .first = start,
                    .last = end + 1,
                };
            },
            else => @panic("TODO"),
        }
    }

    pub const Resolution = enum {
        Unresolved,
        InProgress,
        Invalid,
        Ok,
    };

    pub const Id = enum {
        Var,
        Fn,
        CompTime,
    };

    pub const Var = struct {
        base: Decl,
    };

    pub const Fn = struct {
        base: Decl,
        value: Val,
        fn_proto: *const ast.Node.FnProto,

        // TODO https://github.com/ziglang/zig/issues/683 and then make this anonymous
        pub const Val = union {
            Unresolved: void,
            Ok: Value.Fn,
        };

        pub fn externLibName(self: Fn, tree: *ast.Tree) ?[]const u8 {
            return if (self.fn_proto.extern_export_inline_token) |tok_index| x: {
                const token = tree.tokens.at(tok_index);
                break :x switch (token.id) {
                    Token.Id.Extern => tree.tokenSlicePtr(token),
                    else => null,
                };
            } else null;
        }

        pub fn isExported(self: Fn, tree: *ast.Tree) bool {
            if (self.fn_proto.extern_export_inline_token) |tok_index| {
                const token = tree.tokens.at(tok_index);
                return token.id == Token.Id.Keyword_export;
            } else {
                return false;
            }
        }
    };

    pub const CompTime = struct {
        base: Decl,
    };
};

pub const Value = struct {
    pub const Fn = struct {};
};

pub const Type = struct {
    id: Id,

    pub const Id = enum {
        Type,
        Void,
        Bool,
        NoReturn,
        Int,
        Float,
        Pointer,
        Array,
        Struct,
        ComptimeFloat,
        ComptimeInt,
        Undefined,
        Null,
        Optional,
        ErrorUnion,
        ErrorSet,
        Enum,
        Union,
        Fn,
        Opaque,
        Promise,
    };

    pub const Struct = struct {
        base: Type,
        decls: *Scope.Decls,
    };
};

pub const ParsedFile = struct {
    tree: ast.Tree,
    realpath: []const u8,
};

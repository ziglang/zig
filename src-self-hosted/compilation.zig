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
const AtomicRmwOp = builtin.AtomicRmwOp;
const AtomicOrder = builtin.AtomicOrder;
const Scope = @import("scope.zig").Scope;
const Decl = @import("decl.zig").Decl;
const ir = @import("ir.zig");
const Visib = @import("visib.zig").Visib;
const ParsedFile = @import("parsed_file.zig").ParsedFile;
const Value = @import("value.zig").Value;
const Type = Value.Type;
const Span = errmsg.Span;
const codegen = @import("codegen.zig");
const Package = @import("package.zig").Package;

/// Data that is local to the event loop.
pub const EventLoopLocal = struct {
    loop: *event.Loop,
    llvm_handle_pool: std.atomic.Stack(llvm.ContextRef),

    /// TODO pool these so that it doesn't have to lock
    prng: event.Locked(std.rand.DefaultPrng),

    var lazy_init_targets = std.lazyInit(void);

    fn init(loop: *event.Loop) !EventLoopLocal {
        lazy_init_targets.get() orelse {
            Target.initializeAll();
            lazy_init_targets.resolve();
        };

        var seed_bytes: [@sizeOf(u64)]u8 = undefined;
        try std.os.getRandomBytes(seed_bytes[0..]);
        const seed = std.mem.readInt(seed_bytes, u64, builtin.Endian.Big);
        return EventLoopLocal{
            .loop = loop,
            .llvm_handle_pool = std.atomic.Stack(llvm.ContextRef).init(),
            .prng = event.Locked(std.rand.DefaultPrng).init(loop, std.rand.DefaultPrng.init(seed)),
        };
    }

    fn deinit(self: *EventLoopLocal) void {
        while (self.llvm_handle_pool.pop()) |node| {
            c.LLVMContextDispose(node.data);
            self.loop.allocator.destroy(node);
        }
    }

    /// Gets an exclusive handle on any LlvmContext.
    /// Caller must release the handle when done.
    pub fn getAnyLlvmContext(self: *EventLoopLocal) !LlvmHandle {
        if (self.llvm_handle_pool.pop()) |node| return LlvmHandle{ .node = node };

        const context_ref = c.LLVMContextCreate() orelse return error.OutOfMemory;
        errdefer c.LLVMContextDispose(context_ref);

        const node = try self.loop.allocator.create(std.atomic.Stack(llvm.ContextRef).Node{
            .next = undefined,
            .data = context_ref,
        });
        errdefer self.loop.allocator.destroy(node);

        return LlvmHandle{ .node = node };
    }
};

pub const LlvmHandle = struct {
    node: *std.atomic.Stack(llvm.ContextRef).Node,

    pub fn release(self: LlvmHandle, event_loop_local: *EventLoopLocal) void {
        event_loop_local.llvm_handle_pool.push(self.node);
    }
};

pub const Compilation = struct {
    event_loop_local: *EventLoopLocal,
    loop: *event.Loop,
    name: Buffer,
    llvm_triple: Buffer,
    root_src_path: ?[]const u8,
    target: Target,
    llvm_target: llvm.TargetRef,
    build_mode: builtin.Mode,
    zig_lib_dir: []const u8,
    zig_std_dir: []const u8,

    /// lazily created when we need it
    tmp_dir: event.Future(BuildError![]u8),

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

    /// paths that are explicitly provided by the user to link against
    link_objects: []const []const u8,

    /// functions that have their own objects that we need to link
    /// it uses an optional pointer so that tombstone removals are possible
    fn_link_set: event.Locked(FnLinkSet),

    pub const FnLinkSet = std.LinkedList(?*Value.Fn);

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
    prelink_group: event.Group(BuildError!void),

    compile_errors: event.Locked(CompileErrList),

    meta_type: *Type.MetaType,
    void_type: *Type.Void,
    bool_type: *Type.Bool,
    noreturn_type: *Type.NoReturn,

    void_value: *Value.Void,
    true_value: *Value.Bool,
    false_value: *Value.Bool,
    noreturn_value: *Value.NoReturn,

    target_machine: llvm.TargetMachineRef,
    target_data_ref: llvm.TargetDataRef,
    target_layout_str: [*]u8,

    /// for allocating things which have the same lifetime as this Compilation
    arena_allocator: std.heap.ArenaAllocator,

    root_package: *Package,
    std_package: *Package,

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
        Unimplemented, // TODO remove this one
        SemanticAnalysisFailed, // TODO remove this one
        ReadOnlyFileSystem,
        LinkQuotaExceeded,
        EnvironmentVariableNotFound,
    };

    pub const Event = union(enum) {
        Ok,
        Error: BuildError,
        Fail: []*errmsg.Msg,
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
        event_loop_local: *EventLoopLocal,
        name: []const u8,
        root_src_path: ?[]const u8,
        target: Target,
        kind: Kind,
        build_mode: builtin.Mode,
        is_static: bool,
        zig_lib_dir: []const u8,
        cache_dir: []const u8,
    ) !*Compilation {
        const loop = event_loop_local.loop;
        const comp = try event_loop_local.loop.allocator.create(Compilation{
            .loop = loop,
            .arena_allocator = std.heap.ArenaAllocator.init(loop.allocator),
            .event_loop_local = event_loop_local,
            .events = undefined,
            .root_src_path = root_src_path,
            .target = target,
            .llvm_target = undefined,
            .kind = kind,
            .build_mode = build_mode,
            .zig_lib_dir = zig_lib_dir,
            .zig_std_dir = undefined,
            .cache_dir = cache_dir,
            .tmp_dir = event.Future(BuildError![]u8).init(loop),

            .name = undefined,
            .llvm_triple = undefined,

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
            .is_static = is_static,
            .linker_rdynamic = false,
            .clang_argv = [][]const u8{},
            .llvm_argv = [][]const u8{},
            .lib_dirs = [][]const u8{},
            .rpath_list = [][]const u8{},
            .assembly_files = [][]const u8{},
            .link_objects = [][]const u8{},
            .fn_link_set = event.Locked(FnLinkSet).init(loop, FnLinkSet.init()),
            .windows_subsystem_windows = false,
            .windows_subsystem_console = false,
            .link_libs_list = undefined,
            .libc_link_lib = null,
            .err_color = errmsg.Color.Auto,
            .darwin_frameworks = [][]const u8{},
            .darwin_version_min = DarwinVersionMin.None,
            .test_filters = [][]const u8{},
            .test_name_prefix = null,
            .emit_file_type = Emit.Binary,
            .link_out_file = null,
            .exported_symbol_names = event.Locked(Decl.Table).init(loop, Decl.Table.init(loop.allocator)),
            .prelink_group = event.Group(BuildError!void).init(loop),
            .compile_errors = event.Locked(CompileErrList).init(loop, CompileErrList.init(loop.allocator)),

            .meta_type = undefined,
            .void_type = undefined,
            .void_value = undefined,
            .bool_type = undefined,
            .true_value = undefined,
            .false_value = undefined,
            .noreturn_type = undefined,
            .noreturn_value = undefined,

            .target_machine = undefined,
            .target_data_ref = undefined,
            .target_layout_str = undefined,

            .root_package = undefined,
            .std_package = undefined,
        });
        errdefer {
            comp.arena_allocator.deinit();
            comp.loop.allocator.destroy(comp);
        }

        comp.name = try Buffer.init(comp.arena(), name);
        comp.llvm_triple = try target.getTriple(comp.arena());
        comp.llvm_target = try Target.llvmTargetFromTriple(comp.llvm_triple);
        comp.link_libs_list = ArrayList(*LinkLib).init(comp.arena());
        comp.zig_std_dir = try std.os.path.join(comp.arena(), zig_lib_dir, "std");

        const opt_level = switch (build_mode) {
            builtin.Mode.Debug => llvm.CodeGenLevelNone,
            else => llvm.CodeGenLevelAggressive,
        };

        const reloc_mode = if (is_static) llvm.RelocStatic else llvm.RelocPIC;

        // LLVM creates invalid binaries on Windows sometimes.
        // See https://github.com/ziglang/zig/issues/508
        // As a workaround we do not use target native features on Windows.
        var target_specific_cpu_args: ?[*]u8 = null;
        var target_specific_cpu_features: ?[*]u8 = null;
        errdefer llvm.DisposeMessage(target_specific_cpu_args);
        errdefer llvm.DisposeMessage(target_specific_cpu_features);
        if (target == Target.Native and !target.isWindows()) {
            target_specific_cpu_args = llvm.GetHostCPUName() orelse return error.OutOfMemory;
            target_specific_cpu_features = llvm.GetNativeFeatures() orelse return error.OutOfMemory;
        }

        comp.target_machine = llvm.CreateTargetMachine(
            comp.llvm_target,
            comp.llvm_triple.ptr(),
            target_specific_cpu_args orelse c"",
            target_specific_cpu_features orelse c"",
            opt_level,
            reloc_mode,
            llvm.CodeModelDefault,
        ) orelse return error.OutOfMemory;
        errdefer llvm.DisposeTargetMachine(comp.target_machine);

        comp.target_data_ref = llvm.CreateTargetDataLayout(comp.target_machine) orelse return error.OutOfMemory;
        errdefer llvm.DisposeTargetData(comp.target_data_ref);

        comp.target_layout_str = llvm.CopyStringRepOfTargetData(comp.target_data_ref) orelse return error.OutOfMemory;
        errdefer llvm.DisposeMessage(comp.target_layout_str);

        comp.events = try event.Channel(Event).create(comp.loop, 0);
        errdefer comp.events.destroy();

        if (root_src_path) |root_src| {
            const dirname = std.os.path.dirname(root_src) orelse ".";
            const basename = std.os.path.basename(root_src);

            comp.root_package = try Package.create(comp.arena(), dirname, basename);
            comp.std_package = try Package.create(comp.arena(), comp.zig_std_dir, "index.zig");
            try comp.root_package.add("std", comp.std_package);
        } else {
            comp.root_package = try Package.create(comp.arena(), ".", "");
        }

        try comp.initTypes();

        return comp;
    }

    fn initTypes(comp: *Compilation) !void {
        comp.meta_type = try comp.gpa().create(Type.MetaType{
            .base = Type{
                .base = Value{
                    .id = Value.Id.Type,
                    .typeof = undefined,
                    .ref_count = std.atomic.Int(usize).init(3), // 3 because it references itself twice
                },
                .id = builtin.TypeId.Type,
            },
            .value = undefined,
        });
        comp.meta_type.value = &comp.meta_type.base;
        comp.meta_type.base.base.typeof = &comp.meta_type.base;
        errdefer comp.gpa().destroy(comp.meta_type);

        comp.void_type = try comp.gpa().create(Type.Void{
            .base = Type{
                .base = Value{
                    .id = Value.Id.Type,
                    .typeof = &Type.MetaType.get(comp).base,
                    .ref_count = std.atomic.Int(usize).init(1),
                },
                .id = builtin.TypeId.Void,
            },
        });
        errdefer comp.gpa().destroy(comp.void_type);

        comp.noreturn_type = try comp.gpa().create(Type.NoReturn{
            .base = Type{
                .base = Value{
                    .id = Value.Id.Type,
                    .typeof = &Type.MetaType.get(comp).base,
                    .ref_count = std.atomic.Int(usize).init(1),
                },
                .id = builtin.TypeId.NoReturn,
            },
        });
        errdefer comp.gpa().destroy(comp.noreturn_type);

        comp.bool_type = try comp.gpa().create(Type.Bool{
            .base = Type{
                .base = Value{
                    .id = Value.Id.Type,
                    .typeof = &Type.MetaType.get(comp).base,
                    .ref_count = std.atomic.Int(usize).init(1),
                },
                .id = builtin.TypeId.Bool,
            },
        });
        errdefer comp.gpa().destroy(comp.bool_type);

        comp.void_value = try comp.gpa().create(Value.Void{
            .base = Value{
                .id = Value.Id.Void,
                .typeof = &Type.Void.get(comp).base,
                .ref_count = std.atomic.Int(usize).init(1),
            },
        });
        errdefer comp.gpa().destroy(comp.void_value);

        comp.true_value = try comp.gpa().create(Value.Bool{
            .base = Value{
                .id = Value.Id.Bool,
                .typeof = &Type.Bool.get(comp).base,
                .ref_count = std.atomic.Int(usize).init(1),
            },
            .x = true,
        });
        errdefer comp.gpa().destroy(comp.true_value);

        comp.false_value = try comp.gpa().create(Value.Bool{
            .base = Value{
                .id = Value.Id.Bool,
                .typeof = &Type.Bool.get(comp).base,
                .ref_count = std.atomic.Int(usize).init(1),
            },
            .x = false,
        });
        errdefer comp.gpa().destroy(comp.false_value);

        comp.noreturn_value = try comp.gpa().create(Value.NoReturn{
            .base = Value{
                .id = Value.Id.NoReturn,
                .typeof = &Type.NoReturn.get(comp).base,
                .ref_count = std.atomic.Int(usize).init(1),
            },
        });
        errdefer comp.gpa().destroy(comp.noreturn_value);
    }

    pub fn destroy(self: *Compilation) void {
        if (self.tmp_dir.getOrNull()) |tmp_dir_result| if (tmp_dir_result.*) |tmp_dir| {
            os.deleteTree(self.arena(), tmp_dir) catch {};
        } else |_| {};

        self.noreturn_value.base.deref(self);
        self.void_value.base.deref(self);
        self.false_value.base.deref(self);
        self.true_value.base.deref(self);
        self.noreturn_type.base.base.deref(self);
        self.void_type.base.base.deref(self);
        self.meta_type.base.base.deref(self);

        self.events.destroy();

        llvm.DisposeMessage(self.target_layout_str);
        llvm.DisposeTargetData(self.target_data_ref);
        llvm.DisposeTargetMachine(self.target_machine);

        self.arena_allocator.deinit();
        self.gpa().destroy(self);
    }

    pub fn build(self: *Compilation) !void {
        if (self.llvm_argv.len != 0) {
            var c_compatible_args = try std.cstr.NullTerminated2DArray.fromSlices(self.arena(), [][]const []const u8{
                [][]const u8{"zig (LLVM option parsing)"},
                self.llvm_argv,
            });
            defer c_compatible_args.deinit();
            // TODO this sets global state
            c.ZigLLVMParseCommandLineOptions(self.llvm_argv.len + 1, c_compatible_args.ptr);
        }

        _ = try async<self.gpa()> self.buildAsync();
    }

    async fn buildAsync(self: *Compilation) void {
        while (true) {
            // TODO directly awaiting async should guarantee memory allocation elision
            // TODO also async before suspending should guarantee memory allocation elision
            const build_result = await (async self.addRootSrc() catch unreachable);

            // this makes a handy error return trace and stack trace in debug mode
            if (std.debug.runtime_safety) {
                build_result catch unreachable;
            }

            const compile_errors = blk: {
                const held = await (async self.compile_errors.acquire() catch unreachable);
                defer held.release();
                break :blk held.value.toOwnedSlice();
            };

            if (build_result) |_| {
                if (compile_errors.len == 0) {
                    await (async self.events.put(Event.Ok) catch unreachable);
                } else {
                    await (async self.events.put(Event{ .Fail = compile_errors }) catch unreachable);
                }
            } else |err| {
                // if there's an error then the compile errors have dangling references
                self.gpa().free(compile_errors);

                await (async self.events.put(Event{ .Error = err }) catch unreachable);
            }

            // for now we stop after 1
            return;
        }
    }

    async fn addRootSrc(self: *Compilation) !void {
        const root_src_path = self.root_src_path orelse @panic("TODO handle null root src path");
        // TODO async/await os.path.real
        const root_src_real_path = os.path.real(self.gpa(), root_src_path) catch |err| {
            try printError("unable to get real path '{}': {}", root_src_path, err);
            return err;
        };
        errdefer self.gpa().free(root_src_real_path);

        // TODO async/await readFileAlloc()
        const source_code = io.readFileAlloc(self.gpa(), root_src_real_path) catch |err| {
            try printError("unable to open '{}': {}", root_src_real_path, err);
            return err;
        };
        errdefer self.gpa().free(source_code);

        const parsed_file = try self.gpa().create(ParsedFile{
            .tree = undefined,
            .realpath = root_src_real_path,
        });
        errdefer self.gpa().destroy(parsed_file);

        parsed_file.tree = try std.zig.parse(self.gpa(), source_code);
        errdefer parsed_file.tree.deinit();

        const tree = &parsed_file.tree;

        // create empty struct for it
        const decls = try Scope.Decls.create(self, null);
        defer decls.base.deref(self);

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
                        try self.addCompileError(parsed_file, Span{
                            .first = fn_proto.fn_token,
                            .last = fn_proto.fn_token + 1,
                        }, "missing function name");
                        continue;
                    };

                    const fn_decl = try self.gpa().create(Decl.Fn{
                        .base = Decl{
                            .id = Decl.Id.Fn,
                            .name = name,
                            .visib = parseVisibToken(tree, fn_proto.visib_token),
                            .resolution = event.Future(BuildError!void).init(self.loop),
                            .resolution_in_progress = 0,
                            .parsed_file = parsed_file,
                            .parent_scope = &decls.base,
                        },
                        .value = Decl.Fn.Val{ .Unresolved = {} },
                        .fn_proto = fn_proto,
                    });
                    errdefer self.gpa().destroy(fn_decl);

                    try decl_group.call(addTopLevelDecl, self, &fn_decl.base);
                },
                ast.Node.Id.TestDecl => @panic("TODO"),
                else => unreachable,
            }
        }
        try await (async decl_group.wait() catch unreachable);
        try await (async self.prelink_group.wait() catch unreachable);
    }

    async fn addTopLevelDecl(self: *Compilation, decl: *Decl) !void {
        const is_export = decl.isExported(&decl.parsed_file.tree);

        if (is_export) {
            try self.prelink_group.call(verifyUniqueSymbol, self, decl);
            try self.prelink_group.call(resolveDecl, self, decl);
        }
    }

    fn addCompileError(self: *Compilation, parsed_file: *ParsedFile, span: Span, comptime fmt: []const u8, args: ...) !void {
        const text = try std.fmt.allocPrint(self.loop.allocator, fmt, args);
        errdefer self.loop.allocator.free(text);

        try self.prelink_group.call(addCompileErrorAsync, self, parsed_file, span, text);
    }

    async fn addCompileErrorAsync(
        self: *Compilation,
        parsed_file: *ParsedFile,
        span: Span,
        text: []u8,
    ) !void {
        const msg = try self.loop.allocator.create(errmsg.Msg{
            .path = parsed_file.realpath,
            .text = text,
            .span = span,
            .tree = &parsed_file.tree,
        });
        errdefer self.loop.allocator.destroy(msg);

        const compile_errors = await (async self.compile_errors.acquire() catch unreachable);
        defer compile_errors.release();

        try compile_errors.value.append(msg);
    }

    async fn verifyUniqueSymbol(self: *Compilation, decl: *Decl) !void {
        const exported_symbol_names = await (async self.exported_symbol_names.acquire() catch unreachable);
        defer exported_symbol_names.release();

        if (try exported_symbol_names.value.put(decl.name, decl)) |other_decl| {
            try self.addCompileError(
                decl.parsed_file,
                decl.getSpan(),
                "exported symbol collision: '{}'",
                decl.name,
            );
            // TODO add error note showing location of other symbol
        }
    }

    pub fn link(self: *Compilation, out_file: ?[]const u8) !void {
        warn("TODO link");
        return error.Todo;
    }

    pub fn haveLibC(self: *Compilation) bool {
        return self.libc_link_lib != null;
    }

    pub fn addLinkLib(self: *Compilation, name: []const u8, provided_explicitly: bool) !*LinkLib {
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

        const link_lib = try self.gpa().create(LinkLib{
            .name = name,
            .path = null,
            .provided_explicitly = provided_explicitly,
            .symbols = ArrayList([]u8).init(self.gpa()),
        });
        try self.link_libs_list.append(link_lib);
        if (is_libc) {
            self.libc_link_lib = link_lib;
        }
        return link_lib;
    }

    /// General Purpose Allocator. Must free when done.
    fn gpa(self: Compilation) *mem.Allocator {
        return self.loop.allocator;
    }

    /// Arena Allocator. Automatically freed when the Compilation is destroyed.
    fn arena(self: *Compilation) *mem.Allocator {
        return &self.arena_allocator.allocator;
    }

    /// If the temporary directory for this compilation has not been created, it creates it.
    /// Then it creates a random file name in that dir and returns it.
    pub async fn createRandomOutputPath(self: *Compilation, suffix: []const u8) !Buffer {
        const tmp_dir = try await (async self.getTmpDir() catch unreachable);
        const file_prefix = await (async self.getRandomFileName() catch unreachable);

        const file_name = try std.fmt.allocPrint(self.gpa(), "{}{}", file_prefix[0..], suffix);
        defer self.gpa().free(file_name);

        const full_path = try os.path.join(self.gpa(), tmp_dir, file_name[0..]);
        errdefer self.gpa().free(full_path);

        return Buffer.fromOwnedSlice(self.gpa(), full_path);
    }

    /// If the temporary directory for this Compilation has not been created, creates it.
    /// Then returns it. The directory is unique to this Compilation and cleaned up when
    /// the Compilation deinitializes.
    async fn getTmpDir(self: *Compilation) ![]const u8 {
        if (await (async self.tmp_dir.start() catch unreachable)) |ptr| return ptr.*;
        self.tmp_dir.data = await (async self.getTmpDirImpl() catch unreachable);
        self.tmp_dir.resolve();
        return self.tmp_dir.data;
    }

    async fn getTmpDirImpl(self: *Compilation) ![]u8 {
        const comp_dir_name = await (async self.getRandomFileName() catch unreachable);
        const zig_dir_path = try getZigDir(self.gpa());
        defer self.gpa().free(zig_dir_path);

        const tmp_dir = try os.path.join(self.arena(), zig_dir_path, comp_dir_name[0..]);
        try os.makePath(self.gpa(), tmp_dir);
        return tmp_dir;
    }

    async fn getRandomFileName(self: *Compilation) [12]u8 {
        // here we replace the standard +/ with -_ so that it can be used in a file name
        const b64_fs_encoder = std.base64.Base64Encoder.init(
            "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_",
            std.base64.standard_pad_char,
        );

        var rand_bytes: [9]u8 = undefined;

        {
            const held = await (async self.event_loop_local.prng.acquire() catch unreachable);
            defer held.release();

            held.value.random.bytes(rand_bytes[0..]);
        }

        var result: [12]u8 = undefined;
        b64_fs_encoder.encode(result[0..], rand_bytes);
        return result;
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

/// This declaration has been blessed as going into the final code generation.
pub async fn resolveDecl(comp: *Compilation, decl: *Decl) !void {
    if (await (async decl.resolution.start() catch unreachable)) |ptr| return ptr.*;

    decl.resolution.data = await (async generateDecl(comp, decl) catch unreachable);
    decl.resolution.resolve();
    return decl.resolution.data;
}

/// The function that actually does the generation.
async fn generateDecl(comp: *Compilation, decl: *Decl) !void {
    switch (decl.id) {
        Decl.Id.Var => @panic("TODO"),
        Decl.Id.Fn => {
            const fn_decl = @fieldParentPtr(Decl.Fn, "base", decl);
            return await (async generateDeclFn(comp, fn_decl) catch unreachable);
        },
        Decl.Id.CompTime => @panic("TODO"),
    }
}

async fn generateDeclFn(comp: *Compilation, fn_decl: *Decl.Fn) !void {
    const body_node = fn_decl.fn_proto.body_node orelse @panic("TODO extern fn proto decl");

    const fndef_scope = try Scope.FnDef.create(comp, fn_decl.base.parent_scope);
    defer fndef_scope.base.deref(comp);

    // TODO actually look at the return type of the AST
    const return_type = &Type.Void.get(comp).base;
    defer return_type.base.deref(comp);

    const is_var_args = false;
    const params = ([*]Type.Fn.Param)(undefined)[0..0];
    const fn_type = try Type.Fn.create(comp, return_type, params, is_var_args);
    defer fn_type.base.base.deref(comp);

    var symbol_name = try std.Buffer.init(comp.gpa(), fn_decl.base.name);
    errdefer symbol_name.deinit();

    const fn_val = try Value.Fn.create(comp, fn_type, fndef_scope, symbol_name);
    defer fn_val.base.deref(comp);

    fn_decl.value = Decl.Fn.Val{ .Ok = fn_val };

    const unanalyzed_code = (await (async ir.gen(
        comp,
        body_node,
        &fndef_scope.base,
        Span.token(body_node.lastToken()),
        fn_decl.base.parsed_file,
    ) catch unreachable)) catch |err| switch (err) {
        // This poison value should not cause the errdefers to run. It simply means
        // that self.compile_errors is populated.
        // TODO https://github.com/ziglang/zig/issues/769
        error.SemanticAnalysisFailed => return {},
        else => return err,
    };
    defer unanalyzed_code.destroy(comp.gpa());

    if (comp.verbose_ir) {
        std.debug.warn("unanalyzed:\n");
        unanalyzed_code.dump();
    }

    const analyzed_code = (await (async ir.analyze(
        comp,
        fn_decl.base.parsed_file,
        unanalyzed_code,
        null,
    ) catch unreachable)) catch |err| switch (err) {
        // This poison value should not cause the errdefers to run. It simply means
        // that self.compile_errors is populated.
        // TODO https://github.com/ziglang/zig/issues/769
        error.SemanticAnalysisFailed => return {},
        else => return err,
    };
    errdefer analyzed_code.destroy(comp.gpa());

    if (comp.verbose_ir) {
        std.debug.warn("analyzed:\n");
        analyzed_code.dump();
    }

    // Kick off rendering to LLVM module, but it doesn't block the fn decl
    // analysis from being complete.
    try comp.prelink_group.call(codegen.renderToLlvm, comp, fn_val, analyzed_code);
    try comp.prelink_group.call(addFnToLinkSet, comp, fn_val);
}

async fn addFnToLinkSet(comp: *Compilation, fn_val: *Value.Fn) void {
    fn_val.base.ref();
    defer fn_val.base.deref(comp);

    fn_val.link_set_node.data = fn_val;

    const held = await (async comp.fn_link_set.acquire() catch unreachable);
    defer held.release();

    held.value.append(fn_val.link_set_node);
}

fn getZigDir(allocator: *mem.Allocator) ![]u8 {
    const home_dir = try getHomeDir(allocator);
    defer allocator.free(home_dir);

    return os.path.join(allocator, home_dir, ".zig");
}

/// TODO move to zig std lib, and make it work for other OSes
fn getHomeDir(allocator: *mem.Allocator) ![]u8 {
    return os.getEnvVarOwned(allocator, "HOME");
}

const std = @import("std");
const io = std.io;
const mem = std.mem;
const Allocator = mem.Allocator;
const Buffer = std.Buffer;
const llvm = @import("llvm.zig");
const c = @import("c.zig");
const builtin = std.builtin;
const Target = std.Target;
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
const Value = @import("value.zig").Value;
const Type = Value.Type;
const Span = errmsg.Span;
const Msg = errmsg.Msg;
const codegen = @import("codegen.zig");
const Package = @import("package.zig").Package;
const link = @import("link.zig").link;
const LibCInstallation = @import("libc_installation.zig").LibCInstallation;
const CInt = @import("c_int.zig").CInt;
const fs = std.fs;
const util = @import("util.zig");

const max_src_size = 2 * 1024 * 1024 * 1024; // 2 GiB

/// Data that is local to the event loop.
pub const ZigCompiler = struct {
    llvm_handle_pool: std.atomic.Stack(*llvm.Context),
    lld_lock: event.Lock,
    allocator: *Allocator,

    /// TODO pool these so that it doesn't have to lock
    prng: event.Locked(std.rand.DefaultPrng),

    native_libc: event.Future(LibCInstallation),

    var lazy_init_targets = std.lazyInit(void);

    pub fn init(allocator: *Allocator) !ZigCompiler {
        lazy_init_targets.get() orelse {
            util.initializeAllTargets();
            lazy_init_targets.resolve();
        };

        var seed_bytes: [@sizeOf(u64)]u8 = undefined;
        try std.crypto.randomBytes(seed_bytes[0..]);
        const seed = mem.readIntNative(u64, &seed_bytes);

        return ZigCompiler{
            .allocator = allocator,
            .lld_lock = event.Lock.init(),
            .llvm_handle_pool = std.atomic.Stack(*llvm.Context).init(),
            .prng = event.Locked(std.rand.DefaultPrng).init(std.rand.DefaultPrng.init(seed)),
            .native_libc = event.Future(LibCInstallation).init(),
        };
    }

    /// Must be called only after EventLoop.run completes.
    fn deinit(self: *ZigCompiler) void {
        self.lld_lock.deinit();
        while (self.llvm_handle_pool.pop()) |node| {
            llvm.ContextDispose(node.data);
            self.allocator.destroy(node);
        }
    }

    /// Gets an exclusive handle on any LlvmContext.
    /// Caller must release the handle when done.
    pub fn getAnyLlvmContext(self: *ZigCompiler) !LlvmHandle {
        if (self.llvm_handle_pool.pop()) |node| return LlvmHandle{ .node = node };

        const context_ref = llvm.ContextCreate() orelse return error.OutOfMemory;
        errdefer llvm.ContextDispose(context_ref);

        const node = try self.allocator.create(std.atomic.Stack(*llvm.Context).Node);
        node.* = std.atomic.Stack(*llvm.Context).Node{
            .next = undefined,
            .data = context_ref,
        };
        errdefer self.allocator.destroy(node);

        return LlvmHandle{ .node = node };
    }

    pub fn getNativeLibC(self: *ZigCompiler) !*LibCInstallation {
        if (self.native_libc.start()) |ptr| return ptr;
        try self.native_libc.data.findNative(self.allocator);
        self.native_libc.resolve();
        return &self.native_libc.data;
    }

    /// Must be called only once, ever. Sets global state.
    pub fn setLlvmArgv(allocator: *Allocator, llvm_argv: []const []const u8) !void {
        if (llvm_argv.len != 0) {
            var c_compatible_args = try std.cstr.NullTerminated2DArray.fromSlices(allocator, &[_][]const []const u8{
                &[_][]const u8{"zig (LLVM option parsing)"},
                llvm_argv,
            });
            defer c_compatible_args.deinit();
            c.ZigLLVMParseCommandLineOptions(llvm_argv.len + 1, c_compatible_args.ptr);
        }
    }
};

pub const LlvmHandle = struct {
    node: *std.atomic.Stack(*llvm.Context).Node,

    pub fn release(self: LlvmHandle, zig_compiler: *ZigCompiler) void {
        zig_compiler.llvm_handle_pool.push(self.node);
    }
};

pub const Compilation = struct {
    zig_compiler: *ZigCompiler,
    name: Buffer,
    llvm_triple: Buffer,
    root_src_path: ?[]const u8,
    target: Target,
    llvm_target: *llvm.Target,
    build_mode: builtin.Mode,
    zig_lib_dir: []const u8,
    zig_std_dir: []const u8,

    /// lazily created when we need it
    tmp_dir: event.Future(BuildError![]u8) = event.Future(BuildError![]u8).init(),

    version: builtin.Version = builtin.Version{ .major = 0, .minor = 0, .patch = 0 },

    linker_script: ?[]const u8 = null,
    out_h_path: ?[]const u8 = null,

    is_test: bool = false,
    strip: bool = false,
    is_static: bool,
    linker_rdynamic: bool = false,

    clang_argv: []const []const u8 = &[_][]const u8{},
    assembly_files: []const []const u8 = &[_][]const u8{},

    /// paths that are explicitly provided by the user to link against
    link_objects: []const []const u8 = &[_][]const u8{},

    /// functions that have their own objects that we need to link
    /// it uses an optional pointer so that tombstone removals are possible
    fn_link_set: event.Locked(FnLinkSet) = event.Locked(FnLinkSet).init(FnLinkSet.init()),

    pub const FnLinkSet = std.TailQueue(?*Value.Fn);

    link_libs_list: ArrayList(*LinkLib),
    libc_link_lib: ?*LinkLib = null,

    err_color: errmsg.Color = .Auto,

    verbose_tokenize: bool = false,
    verbose_ast_tree: bool = false,
    verbose_ast_fmt: bool = false,
    verbose_cimport: bool = false,
    verbose_ir: bool = false,
    verbose_llvm_ir: bool = false,
    verbose_link: bool = false,

    link_eh_frame_hdr: bool = false,

    darwin_version_min: DarwinVersionMin = .None,

    test_filters: []const []const u8 = &[_][]const u8{},
    test_name_prefix: ?[]const u8 = null,

    emit_bin: bool = true,
    emit_asm: bool = false,
    emit_llvm_ir: bool = false,
    emit_h: bool = false,

    kind: Kind,

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
    comptime_int_type: *Type.ComptimeInt,
    u8_type: *Type.Int,

    void_value: *Value.Void,
    true_value: *Value.Bool,
    false_value: *Value.Bool,
    noreturn_value: *Value.NoReturn,

    target_machine: *llvm.TargetMachine,
    target_data_ref: *llvm.TargetData,
    target_layout_str: [*:0]u8,
    target_ptr_bits: u32,

    /// for allocating things which have the same lifetime as this Compilation
    arena_allocator: std.heap.ArenaAllocator,

    root_package: *Package,
    std_package: *Package,

    override_libc: ?*LibCInstallation = null,

    /// need to wait on this group before deinitializing
    deinit_group: event.Group(void),

    destroy_frame: *@Frame(createAsync),
    main_loop_frame: *@Frame(Compilation.mainLoop),
    main_loop_future: event.Future(void) = event.Future(void).init(),

    have_err_ret_tracing: bool = false,

    /// not locked because it is read-only
    primitive_type_table: TypeTable,

    int_type_table: event.Locked(IntTypeTable),
    array_type_table: event.Locked(ArrayTypeTable),
    ptr_type_table: event.Locked(PtrTypeTable),
    fn_type_table: event.Locked(FnTypeTable),

    c_int_types: [CInt.list.len]*Type.Int,

    fs_watch: *fs.Watch(*Scope.Root),

    cancelled: bool = false,

    const IntTypeTable = std.HashMap(*const Type.Int.Key, *Type.Int, Type.Int.Key.hash, Type.Int.Key.eql);
    const ArrayTypeTable = std.HashMap(*const Type.Array.Key, *Type.Array, Type.Array.Key.hash, Type.Array.Key.eql);
    const PtrTypeTable = std.HashMap(*const Type.Pointer.Key, *Type.Pointer, Type.Pointer.Key.hash, Type.Pointer.Key.eql);
    const FnTypeTable = std.HashMap(*const Type.Fn.Key, *Type.Fn, Type.Fn.Key.hash, Type.Fn.Key.eql);
    const TypeTable = std.StringHashMap(*Type);

    const CompileErrList = std.ArrayList(*Msg);

    // TODO handle some of these earlier and report them in a way other than error codes
    pub const BuildError = error{
        OutOfMemory,
        EndOfStream,
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
        AppDataDirUnavailable,
        LinkFailed,
        LibCRequiredButNotProvidedOrFound,
        LibCMissingDynamicLinker,
        InvalidDarwinVersionString,
        UnsupportedLinkArchitecture,
        UserResourceLimitReached,
        InvalidUtf8,
        BadPathName,
        DeviceBusy,
        CurrentWorkingDirectoryUnlinked,
    };

    pub const Event = union(enum) {
        Ok,
        Error: BuildError,
        Fail: []*Msg,
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
        zig_compiler: *ZigCompiler,
        name: []const u8,
        root_src_path: ?[]const u8,
        target: Target,
        kind: Kind,
        build_mode: builtin.Mode,
        is_static: bool,
        zig_lib_dir: []const u8,
    ) !*Compilation {
        var optional_comp: ?*Compilation = null;
        var frame = try zig_compiler.allocator.create(@Frame(createAsync));
        errdefer zig_compiler.allocator.destroy(frame);
        frame.* = async createAsync(
            &optional_comp,
            zig_compiler,
            name,
            root_src_path,
            target,
            kind,
            build_mode,
            is_static,
            zig_lib_dir,
        );
        // TODO causes segfault
        // return optional_comp orelse if (await frame) |_| unreachable else |err| err;
        if (optional_comp) |comp| {
            return comp;
        } else if (await frame) |_| unreachable else |err| return err;
    }

    async fn createAsync(
        out_comp: *?*Compilation,
        zig_compiler: *ZigCompiler,
        name: []const u8,
        root_src_path: ?[]const u8,
        target: Target,
        kind: Kind,
        build_mode: builtin.Mode,
        is_static: bool,
        zig_lib_dir: []const u8,
    ) !void {
        const allocator = zig_compiler.allocator;
        var comp = Compilation{
            .arena_allocator = std.heap.ArenaAllocator.init(allocator),
            .zig_compiler = zig_compiler,
            .events = undefined,
            .root_src_path = root_src_path,
            .target = target,
            .llvm_target = undefined,
            .kind = kind,
            .build_mode = build_mode,
            .zig_lib_dir = zig_lib_dir,
            .zig_std_dir = undefined,
            .destroy_frame = @frame(),
            .main_loop_frame = undefined,

            .name = undefined,
            .llvm_triple = undefined,
            .is_static = is_static,
            .link_libs_list = undefined,
            .exported_symbol_names = event.Locked(Decl.Table).init(Decl.Table.init(allocator)),
            .prelink_group = event.Group(BuildError!void).init(allocator),
            .deinit_group = event.Group(void).init(allocator),
            .compile_errors = event.Locked(CompileErrList).init(CompileErrList.init(allocator)),
            .int_type_table = event.Locked(IntTypeTable).init(IntTypeTable.init(allocator)),
            .array_type_table = event.Locked(ArrayTypeTable).init(ArrayTypeTable.init(allocator)),
            .ptr_type_table = event.Locked(PtrTypeTable).init(PtrTypeTable.init(allocator)),
            .fn_type_table = event.Locked(FnTypeTable).init(FnTypeTable.init(allocator)),
            .c_int_types = undefined,

            .meta_type = undefined,
            .void_type = undefined,
            .void_value = undefined,
            .bool_type = undefined,
            .true_value = undefined,
            .false_value = undefined,
            .noreturn_type = undefined,
            .noreturn_value = undefined,
            .comptime_int_type = undefined,
            .u8_type = undefined,

            .target_machine = undefined,
            .target_data_ref = undefined,
            .target_layout_str = undefined,
            .target_ptr_bits = target.getArchPtrBitWidth(),

            .root_package = undefined,
            .std_package = undefined,

            .primitive_type_table = undefined,

            .fs_watch = undefined,
        };
        comp.link_libs_list = ArrayList(*LinkLib).init(comp.arena());
        comp.primitive_type_table = TypeTable.init(comp.arena());

        defer {
            comp.int_type_table.private_data.deinit();
            comp.array_type_table.private_data.deinit();
            comp.ptr_type_table.private_data.deinit();
            comp.fn_type_table.private_data.deinit();
            comp.arena_allocator.deinit();
        }

        comp.name = try Buffer.init(comp.arena(), name);
        comp.llvm_triple = try util.getTriple(comp.arena(), target);
        comp.llvm_target = try util.llvmTargetFromTriple(comp.llvm_triple);
        comp.zig_std_dir = try fs.path.join(comp.arena(), &[_][]const u8{ zig_lib_dir, "std" });

        const opt_level = switch (build_mode) {
            .Debug => llvm.CodeGenLevelNone,
            else => llvm.CodeGenLevelAggressive,
        };

        const reloc_mode = if (is_static) llvm.RelocStatic else llvm.RelocPIC;

        // LLVM creates invalid binaries on Windows sometimes.
        // See https://github.com/ziglang/zig/issues/508
        // As a workaround we do not use target native features on Windows.
        var target_specific_cpu_args: ?[*:0]u8 = null;
        var target_specific_cpu_features: ?[*:0]u8 = null;
        defer llvm.DisposeMessage(target_specific_cpu_args);
        defer llvm.DisposeMessage(target_specific_cpu_features);
        if (target == Target.Native and !target.isWindows()) {
            target_specific_cpu_args = llvm.GetHostCPUName() orelse return error.OutOfMemory;
            target_specific_cpu_features = llvm.GetNativeFeatures() orelse return error.OutOfMemory;
        }

        comp.target_machine = llvm.CreateTargetMachine(
            comp.llvm_target,
            comp.llvm_triple.toSliceConst(),
            target_specific_cpu_args orelse "",
            target_specific_cpu_features orelse "",
            opt_level,
            reloc_mode,
            llvm.CodeModelDefault,
            false, // TODO: add -ffunction-sections option
        ) orelse return error.OutOfMemory;
        defer llvm.DisposeTargetMachine(comp.target_machine);

        comp.target_data_ref = llvm.CreateTargetDataLayout(comp.target_machine) orelse return error.OutOfMemory;
        defer llvm.DisposeTargetData(comp.target_data_ref);

        comp.target_layout_str = llvm.CopyStringRepOfTargetData(comp.target_data_ref) orelse return error.OutOfMemory;
        defer llvm.DisposeMessage(comp.target_layout_str);

        comp.events = try allocator.create(event.Channel(Event));
        defer allocator.destroy(comp.events);

        comp.events.init(&[0]Event{});
        defer comp.events.deinit();

        if (root_src_path) |root_src| {
            const dirname = fs.path.dirname(root_src) orelse ".";
            const basename = fs.path.basename(root_src);

            comp.root_package = try Package.create(comp.arena(), dirname, basename);
            comp.std_package = try Package.create(comp.arena(), comp.zig_std_dir, "std.zig");
            try comp.root_package.add("std", comp.std_package);
        } else {
            comp.root_package = try Package.create(comp.arena(), ".", "");
        }

        comp.fs_watch = try fs.Watch(*Scope.Root).init(allocator, 16);
        defer comp.fs_watch.deinit();

        try comp.initTypes();
        defer comp.primitive_type_table.deinit();

        comp.main_loop_frame = try allocator.create(@Frame(mainLoop));
        defer allocator.destroy(comp.main_loop_frame);

        comp.main_loop_frame.* = async comp.mainLoop();
        // Set this to indicate that initialization completed successfully.
        // from here on out we must not return an error.
        // This must occur before the first suspend/await.
        out_comp.* = &comp;
        // This suspend is resumed by destroy()
        suspend;
        // From here on is cleanup.

        comp.deinit_group.wait();

        if (comp.tmp_dir.getOrNull()) |tmp_dir_result|
            if (tmp_dir_result.*) |tmp_dir| {
                // TODO evented I/O?
                fs.deleteTree(tmp_dir) catch {};
            } else |_| {};
    }

    /// it does ref the result because it could be an arbitrary integer size
    pub fn getPrimitiveType(comp: *Compilation, name: []const u8) !?*Type {
        if (name.len >= 2) {
            switch (name[0]) {
                'i', 'u' => blk: {
                    for (name[1..]) |byte|
                        switch (byte) {
                            '0'...'9' => {},
                            else => break :blk,
                        };
                    const is_signed = name[0] == 'i';
                    const bit_count = std.fmt.parseUnsigned(u32, name[1..], 10) catch |err| switch (err) {
                        error.Overflow => return error.Overflow,
                        error.InvalidCharacter => unreachable, // we just checked the characters above
                    };
                    const int_type = try Type.Int.get(comp, Type.Int.Key{
                        .bit_count = bit_count,
                        .is_signed = is_signed,
                    });
                    errdefer int_type.base.base.deref();
                    return &int_type.base;
                },
                else => {},
            }
        }

        if (comp.primitive_type_table.get(name)) |entry| {
            entry.value.base.ref();
            return entry.value;
        }

        return null;
    }

    fn initTypes(comp: *Compilation) !void {
        comp.meta_type = try comp.arena().create(Type.MetaType);
        comp.meta_type.* = Type.MetaType{
            .base = Type{
                .name = "type",
                .base = Value{
                    .id = .Type,
                    .typ = undefined,
                    .ref_count = std.atomic.Int(usize).init(3), // 3 because it references itself twice
                },
                .id = .Type,
                .abi_alignment = Type.AbiAlignment.init(),
            },
            .value = undefined,
        };
        comp.meta_type.value = &comp.meta_type.base;
        comp.meta_type.base.base.typ = &comp.meta_type.base;
        assert((try comp.primitive_type_table.put(comp.meta_type.base.name, &comp.meta_type.base)) == null);

        comp.void_type = try comp.arena().create(Type.Void);
        comp.void_type.* = Type.Void{
            .base = Type{
                .name = "void",
                .base = Value{
                    .id = .Type,
                    .typ = &Type.MetaType.get(comp).base,
                    .ref_count = std.atomic.Int(usize).init(1),
                },
                .id = .Void,
                .abi_alignment = Type.AbiAlignment.init(),
            },
        };
        assert((try comp.primitive_type_table.put(comp.void_type.base.name, &comp.void_type.base)) == null);

        comp.noreturn_type = try comp.arena().create(Type.NoReturn);
        comp.noreturn_type.* = Type.NoReturn{
            .base = Type{
                .name = "noreturn",
                .base = Value{
                    .id = .Type,
                    .typ = &Type.MetaType.get(comp).base,
                    .ref_count = std.atomic.Int(usize).init(1),
                },
                .id = .NoReturn,
                .abi_alignment = Type.AbiAlignment.init(),
            },
        };
        assert((try comp.primitive_type_table.put(comp.noreturn_type.base.name, &comp.noreturn_type.base)) == null);

        comp.comptime_int_type = try comp.arena().create(Type.ComptimeInt);
        comp.comptime_int_type.* = Type.ComptimeInt{
            .base = Type{
                .name = "comptime_int",
                .base = Value{
                    .id = .Type,
                    .typ = &Type.MetaType.get(comp).base,
                    .ref_count = std.atomic.Int(usize).init(1),
                },
                .id = .ComptimeInt,
                .abi_alignment = Type.AbiAlignment.init(),
            },
        };
        assert((try comp.primitive_type_table.put(comp.comptime_int_type.base.name, &comp.comptime_int_type.base)) == null);

        comp.bool_type = try comp.arena().create(Type.Bool);
        comp.bool_type.* = Type.Bool{
            .base = Type{
                .name = "bool",
                .base = Value{
                    .id = .Type,
                    .typ = &Type.MetaType.get(comp).base,
                    .ref_count = std.atomic.Int(usize).init(1),
                },
                .id = .Bool,
                .abi_alignment = Type.AbiAlignment.init(),
            },
        };
        assert((try comp.primitive_type_table.put(comp.bool_type.base.name, &comp.bool_type.base)) == null);

        comp.void_value = try comp.arena().create(Value.Void);
        comp.void_value.* = Value.Void{
            .base = Value{
                .id = .Void,
                .typ = &Type.Void.get(comp).base,
                .ref_count = std.atomic.Int(usize).init(1),
            },
        };

        comp.true_value = try comp.arena().create(Value.Bool);
        comp.true_value.* = Value.Bool{
            .base = Value{
                .id = .Bool,
                .typ = &Type.Bool.get(comp).base,
                .ref_count = std.atomic.Int(usize).init(1),
            },
            .x = true,
        };

        comp.false_value = try comp.arena().create(Value.Bool);
        comp.false_value.* = Value.Bool{
            .base = Value{
                .id = .Bool,
                .typ = &Type.Bool.get(comp).base,
                .ref_count = std.atomic.Int(usize).init(1),
            },
            .x = false,
        };

        comp.noreturn_value = try comp.arena().create(Value.NoReturn);
        comp.noreturn_value.* = Value.NoReturn{
            .base = Value{
                .id = .NoReturn,
                .typ = &Type.NoReturn.get(comp).base,
                .ref_count = std.atomic.Int(usize).init(1),
            },
        };

        for (CInt.list) |cint, i| {
            const c_int_type = try comp.arena().create(Type.Int);
            c_int_type.* = Type.Int{
                .base = Type{
                    .name = cint.zig_name,
                    .base = Value{
                        .id = .Type,
                        .typ = &Type.MetaType.get(comp).base,
                        .ref_count = std.atomic.Int(usize).init(1),
                    },
                    .id = .Int,
                    .abi_alignment = Type.AbiAlignment.init(),
                },
                .key = Type.Int.Key{
                    .is_signed = cint.is_signed,
                    .bit_count = cint.sizeInBits(comp.target),
                },
                .garbage_node = undefined,
            };
            comp.c_int_types[i] = c_int_type;
            assert((try comp.primitive_type_table.put(cint.zig_name, &c_int_type.base)) == null);
        }
        comp.u8_type = try comp.arena().create(Type.Int);
        comp.u8_type.* = Type.Int{
            .base = Type{
                .name = "u8",
                .base = Value{
                    .id = .Type,
                    .typ = &Type.MetaType.get(comp).base,
                    .ref_count = std.atomic.Int(usize).init(1),
                },
                .id = .Int,
                .abi_alignment = Type.AbiAlignment.init(),
            },
            .key = Type.Int.Key{
                .is_signed = false,
                .bit_count = 8,
            },
            .garbage_node = undefined,
        };
        assert((try comp.primitive_type_table.put(comp.u8_type.base.name, &comp.u8_type.base)) == null);
    }

    pub fn destroy(self: *Compilation) void {
        const allocator = self.gpa();
        self.cancelled = true;
        await self.main_loop_frame;
        resume self.destroy_frame;
        allocator.destroy(self.destroy_frame);
    }

    fn start(self: *Compilation) void {
        self.main_loop_future.resolve();
    }

    async fn mainLoop(self: *Compilation) void {
        // wait until start() is called
        _ = self.main_loop_future.get();

        var build_result = self.initialCompile();

        while (!self.cancelled) {
            const link_result = if (build_result) blk: {
                break :blk self.maybeLink();
            } else |err| err;
            // this makes a handy error return trace and stack trace in debug mode
            if (std.debug.runtime_safety) {
                link_result catch unreachable;
            }

            const compile_errors = blk: {
                const held = self.compile_errors.acquire();
                defer held.release();
                break :blk held.value.toOwnedSlice();
            };

            if (link_result) |_| {
                if (compile_errors.len == 0) {
                    self.events.put(Event.Ok);
                } else {
                    self.events.put(Event{ .Fail = compile_errors });
                }
            } else |err| {
                // if there's an error then the compile errors have dangling references
                self.gpa().free(compile_errors);

                self.events.put(Event{ .Error = err });
            }

            // First, get an item from the watch channel, waiting on the channel.
            var group = event.Group(BuildError!void).init(self.gpa());
            {
                const ev = (self.fs_watch.channel.get()) catch |err| {
                    build_result = err;
                    continue;
                };
                const root_scope = ev.data;
                group.call(rebuildFile, .{ self, root_scope }) catch |err| {
                    build_result = err;
                    continue;
                };
            }
            // Next, get all the items from the channel that are buffered up.
            while (self.fs_watch.channel.getOrNull()) |ev_or_err| {
                if (ev_or_err) |ev| {
                    const root_scope = ev.data;
                    group.call(rebuildFile, .{ self, root_scope }) catch |err| {
                        build_result = err;
                        continue;
                    };
                } else |err| {
                    build_result = err;
                    continue;
                }
            }
            build_result = group.wait();
        }
    }

    async fn rebuildFile(self: *Compilation, root_scope: *Scope.Root) BuildError!void {
        const tree_scope = blk: {
            const source_code = fs.cwd().readFileAlloc(
                self.gpa(),
                root_scope.realpath,
                max_src_size,
            ) catch |err| {
                try self.addCompileErrorCli(root_scope.realpath, "unable to open: {}", .{@errorName(err)});
                return;
            };
            errdefer self.gpa().free(source_code);

            const tree = try std.zig.parse(self.gpa(), source_code);
            errdefer {
                tree.deinit();
            }

            break :blk try Scope.AstTree.create(self, tree, root_scope);
        };
        defer tree_scope.base.deref(self);

        var error_it = tree_scope.tree.errors.iterator(0);
        while (error_it.next()) |parse_error| {
            const msg = try Msg.createFromParseErrorAndScope(self, tree_scope, parse_error);
            errdefer msg.destroy();

            try self.addCompileErrorAsync(msg);
        }
        if (tree_scope.tree.errors.len != 0) {
            return;
        }

        const locked_table = root_scope.decls.table.acquireWrite();
        defer locked_table.release();

        var decl_group = event.Group(BuildError!void).init(self.gpa());

        try self.rebuildChangedDecls(
            &decl_group,
            locked_table.value,
            root_scope.decls,
            &tree_scope.tree.root_node.decls,
            tree_scope,
        );

        try decl_group.wait();
    }

    fn rebuildChangedDecls(
        self: *Compilation,
        group: *event.Group(BuildError!void),
        locked_table: *Decl.Table,
        decl_scope: *Scope.Decls,
        ast_decls: *ast.Node.Root.DeclList,
        tree_scope: *Scope.AstTree,
    ) !void {
        var existing_decls = try locked_table.clone();
        defer existing_decls.deinit();

        var ast_it = ast_decls.iterator(0);
        while (ast_it.next()) |decl_ptr| {
            const decl = decl_ptr.*;
            switch (decl.id) {
                .Comptime => {
                    const comptime_node = @fieldParentPtr(ast.Node.Comptime, "base", decl);

                    // TODO connect existing comptime decls to updated source files

                    try self.prelink_group.call(addCompTimeBlock, .{ self, tree_scope, &decl_scope.base, comptime_node });
                },
                .VarDecl => @panic("TODO"),
                .FnProto => {
                    const fn_proto = @fieldParentPtr(ast.Node.FnProto, "base", decl);

                    const name = if (fn_proto.name_token) |name_token| tree_scope.tree.tokenSlice(name_token) else {
                        try self.addCompileError(tree_scope, Span{
                            .first = fn_proto.fn_token,
                            .last = fn_proto.fn_token + 1,
                        }, "missing function name", .{});
                        continue;
                    };

                    if (existing_decls.remove(name)) |entry| {
                        // compare new code to existing
                        if (entry.value.cast(Decl.Fn)) |existing_fn_decl| {
                            // Just compare the old bytes to the new bytes of the top level decl.
                            // Even if the AST is technically the same, we want error messages to display
                            // from the most recent source.
                            const old_decl_src = existing_fn_decl.base.tree_scope.tree.getNodeSource(
                                &existing_fn_decl.fn_proto.base,
                            );
                            const new_decl_src = tree_scope.tree.getNodeSource(&fn_proto.base);
                            if (mem.eql(u8, old_decl_src, new_decl_src)) {
                                // it's the same, we can skip this decl
                                continue;
                            } else {
                                @panic("TODO decl changed implementation");
                                // Add the new thing before dereferencing the old thing. This way we don't end
                                // up pointlessly re-creating things we end up using in the new thing.
                            }
                        } else {
                            @panic("TODO decl changed kind");
                        }
                    } else {
                        // add new decl
                        const fn_decl = try self.gpa().create(Decl.Fn);
                        fn_decl.* = Decl.Fn{
                            .base = Decl{
                                .id = Decl.Id.Fn,
                                .name = name,
                                .visib = parseVisibToken(tree_scope.tree, fn_proto.visib_token),
                                .resolution = event.Future(BuildError!void).init(),
                                .parent_scope = &decl_scope.base,
                                .tree_scope = tree_scope,
                            },
                            .value = .Unresolved,
                            .fn_proto = fn_proto,
                        };
                        tree_scope.base.ref();
                        errdefer self.gpa().destroy(fn_decl);

                        try group.call(addTopLevelDecl, .{ self, &fn_decl.base, locked_table });
                    }
                },
                .TestDecl => @panic("TODO"),
                else => unreachable,
            }
        }

        var existing_decl_it = existing_decls.iterator();
        while (existing_decl_it.next()) |entry| {
            // this decl was deleted
            const existing_decl = entry.value;
            @panic("TODO handle decl deletion");
        }
    }

    fn initialCompile(self: *Compilation) !void {
        if (self.root_src_path) |root_src_path| {
            const root_scope = blk: {
                // TODO async/await fs.realpath
                const root_src_real_path = fs.realpathAlloc(self.gpa(), root_src_path) catch |err| {
                    try self.addCompileErrorCli(root_src_path, "unable to open: {}", .{@errorName(err)});
                    return;
                };
                errdefer self.gpa().free(root_src_real_path);

                break :blk try Scope.Root.create(self, root_src_real_path);
            };
            defer root_scope.base.deref(self);

            // assert((try self.fs_watch.addFile(root_scope.realpath, root_scope)) == null);
            try self.rebuildFile(root_scope);
        }
    }

    fn maybeLink(self: *Compilation) !void {
        (self.prelink_group.wait()) catch |err| switch (err) {
            error.SemanticAnalysisFailed => {},
            else => return err,
        };

        const any_prelink_errors = blk: {
            const compile_errors = self.compile_errors.acquire();
            defer compile_errors.release();

            break :blk compile_errors.value.len != 0;
        };

        if (!any_prelink_errors) {
            try link(self);
        }
    }

    /// caller takes ownership of resulting Code
    async fn genAndAnalyzeCode(
        comp: *Compilation,
        tree_scope: *Scope.AstTree,
        scope: *Scope,
        node: *ast.Node,
        expected_type: ?*Type,
    ) !*ir.Code {
        const unanalyzed_code = try ir.gen(
            comp,
            node,
            tree_scope,
            scope,
        );
        defer unanalyzed_code.destroy(comp.gpa());

        if (comp.verbose_ir) {
            std.debug.warn("unanalyzed:\n", .{});
            unanalyzed_code.dump();
        }

        const analyzed_code = try ir.analyze(
            comp,
            unanalyzed_code,
            expected_type,
        );
        errdefer analyzed_code.destroy(comp.gpa());

        if (comp.verbose_ir) {
            std.debug.warn("analyzed:\n", .{});
            analyzed_code.dump();
        }

        return analyzed_code;
    }

    async fn addCompTimeBlock(
        comp: *Compilation,
        tree_scope: *Scope.AstTree,
        scope: *Scope,
        comptime_node: *ast.Node.Comptime,
    ) BuildError!void {
        const void_type = Type.Void.get(comp);
        defer void_type.base.base.deref(comp);

        const analyzed_code = genAndAnalyzeCode(
            comp,
            tree_scope,
            scope,
            comptime_node.expr,
            &void_type.base,
        ) catch |err| switch (err) {
            // This poison value should not cause the errdefers to run. It simply means
            // that comp.compile_errors is populated.
            error.SemanticAnalysisFailed => return {},
            else => return err,
        };
        analyzed_code.destroy(comp.gpa());
    }

    async fn addTopLevelDecl(
        self: *Compilation,
        decl: *Decl,
        locked_table: *Decl.Table,
    ) BuildError!void {
        const is_export = decl.isExported(decl.tree_scope.tree);

        if (is_export) {
            try self.prelink_group.call(verifyUniqueSymbol, .{ self, decl });
            try self.prelink_group.call(resolveDecl, .{ self, decl });
        }

        const gop = try locked_table.getOrPut(decl.name);
        if (gop.found_existing) {
            try self.addCompileError(decl.tree_scope, decl.getSpan(), "redefinition of '{}'", .{decl.name});
            // TODO note: other definition here
        } else {
            gop.kv.value = decl;
        }
    }

    fn addCompileError(self: *Compilation, tree_scope: *Scope.AstTree, span: Span, comptime fmt: []const u8, args: var) !void {
        const text = try std.fmt.allocPrint(self.gpa(), fmt, args);
        errdefer self.gpa().free(text);

        const msg = try Msg.createFromScope(self, tree_scope, span, text);
        errdefer msg.destroy();

        try self.prelink_group.call(addCompileErrorAsync, .{ self, msg });
    }

    fn addCompileErrorCli(self: *Compilation, realpath: []const u8, comptime fmt: []const u8, args: var) !void {
        const text = try std.fmt.allocPrint(self.gpa(), fmt, args);
        errdefer self.gpa().free(text);

        const msg = try Msg.createFromCli(self, realpath, text);
        errdefer msg.destroy();

        try self.prelink_group.call(addCompileErrorAsync, .{ self, msg });
    }

    async fn addCompileErrorAsync(
        self: *Compilation,
        msg: *Msg,
    ) BuildError!void {
        errdefer msg.destroy();

        const compile_errors = self.compile_errors.acquire();
        defer compile_errors.release();

        try compile_errors.value.append(msg);
    }

    async fn verifyUniqueSymbol(self: *Compilation, decl: *Decl) BuildError!void {
        const exported_symbol_names = self.exported_symbol_names.acquire();
        defer exported_symbol_names.release();

        if (try exported_symbol_names.value.put(decl.name, decl)) |other_decl| {
            try self.addCompileError(decl.tree_scope, decl.getSpan(), "exported symbol collision: '{}'", .{
                decl.name,
            });
            // TODO add error note showing location of other symbol
        }
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

        const link_lib = try self.gpa().create(LinkLib);
        link_lib.* = LinkLib{
            .name = name,
            .path = null,
            .provided_explicitly = provided_explicitly,
            .symbols = ArrayList([]u8).init(self.gpa()),
        };
        try self.link_libs_list.append(link_lib);
        if (is_libc) {
            self.libc_link_lib = link_lib;

            // get a head start on looking for the native libc
            if (self.target == Target.Native and self.override_libc == null) {
                try self.deinit_group.call(startFindingNativeLibC, .{self});
            }
        }
        return link_lib;
    }

    async fn startFindingNativeLibC(self: *Compilation) void {
        event.Loop.startCpuBoundOperation();
        // we don't care if it fails, we're just trying to kick off the future resolution
        _ = self.zig_compiler.getNativeLibC() catch return;
    }

    /// General Purpose Allocator. Must free when done.
    fn gpa(self: Compilation) *mem.Allocator {
        return self.zig_compiler.allocator;
    }

    /// Arena Allocator. Automatically freed when the Compilation is destroyed.
    fn arena(self: *Compilation) *mem.Allocator {
        return &self.arena_allocator.allocator;
    }

    /// If the temporary directory for this compilation has not been created, it creates it.
    /// Then it creates a random file name in that dir and returns it.
    pub fn createRandomOutputPath(self: *Compilation, suffix: []const u8) !Buffer {
        const tmp_dir = try self.getTmpDir();
        const file_prefix = self.getRandomFileName();

        const file_name = try std.fmt.allocPrint(self.gpa(), "{}{}", .{ file_prefix[0..], suffix });
        defer self.gpa().free(file_name);

        const full_path = try fs.path.join(self.gpa(), &[_][]const u8{ tmp_dir, file_name[0..] });
        errdefer self.gpa().free(full_path);

        return Buffer.fromOwnedSlice(self.gpa(), full_path);
    }

    /// If the temporary directory for this Compilation has not been created, creates it.
    /// Then returns it. The directory is unique to this Compilation and cleaned up when
    /// the Compilation deinitializes.
    fn getTmpDir(self: *Compilation) ![]const u8 {
        if (self.tmp_dir.start()) |ptr| return ptr.*;
        self.tmp_dir.data = self.getTmpDirImpl();
        self.tmp_dir.resolve();
        return self.tmp_dir.data;
    }

    fn getTmpDirImpl(self: *Compilation) ![]u8 {
        const comp_dir_name = self.getRandomFileName();
        const zig_dir_path = try getZigDir(self.gpa());
        defer self.gpa().free(zig_dir_path);

        const tmp_dir = try fs.path.join(self.arena(), &[_][]const u8{ zig_dir_path, comp_dir_name[0..] });
        try fs.cwd().makePath(tmp_dir);
        return tmp_dir;
    }

    fn getRandomFileName(self: *Compilation) [12]u8 {
        // here we replace the standard +/ with -_ so that it can be used in a file name
        const b64_fs_encoder = std.base64.Base64Encoder.init(
            "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_",
            std.base64.standard_pad_char,
        );

        var rand_bytes: [9]u8 = undefined;

        {
            const held = self.zig_compiler.prng.acquire();
            defer held.release();

            held.value.random.bytes(rand_bytes[0..]);
        }

        var result: [12]u8 = undefined;
        b64_fs_encoder.encode(result[0..], &rand_bytes);
        return result;
    }

    fn registerGarbage(comp: *Compilation, comptime T: type, node: *std.atomic.Stack(*T).Node) void {
        // TODO put the garbage somewhere
    }

    /// Returns a value which has been ref()'d once
    fn analyzeConstValue(
        comp: *Compilation,
        tree_scope: *Scope.AstTree,
        scope: *Scope,
        node: *ast.Node,
        expected_type: *Type,
    ) !*Value {
        var frame = try comp.gpa().create(@Frame(genAndAnalyzeCode));
        defer comp.gpa().destroy(frame);
        frame.* = async comp.genAndAnalyzeCode(tree_scope, scope, node, expected_type);
        const analyzed_code = try await frame;
        defer analyzed_code.destroy(comp.gpa());

        return analyzed_code.getCompTimeResult(comp);
    }

    fn analyzeTypeExpr(comp: *Compilation, tree_scope: *Scope.AstTree, scope: *Scope, node: *ast.Node) !*Type {
        const meta_type = &Type.MetaType.get(comp).base;
        defer meta_type.base.deref(comp);

        const result_val = try comp.analyzeConstValue(tree_scope, scope, node, meta_type);
        errdefer result_val.base.deref(comp);

        return result_val.cast(Type).?;
    }

    /// This declaration has been blessed as going into the final code generation.
    pub async fn resolveDecl(comp: *Compilation, decl: *Decl) BuildError!void {
        if (decl.resolution.start()) |ptr| return ptr.*;

        decl.resolution.data = try generateDecl(comp, decl);
        decl.resolution.resolve();
        return decl.resolution.data;
    }
};

fn parseVisibToken(tree: *ast.Tree, optional_token_index: ?ast.TokenIndex) Visib {
    if (optional_token_index) |token_index| {
        const token = tree.tokens.at(token_index);
        assert(token.id == Token.Id.Keyword_pub);
        return Visib.Pub;
    } else {
        return Visib.Private;
    }
}

/// The function that actually does the generation.
fn generateDecl(comp: *Compilation, decl: *Decl) !void {
    switch (decl.id) {
        .Var => @panic("TODO"),
        .Fn => {
            const fn_decl = @fieldParentPtr(Decl.Fn, "base", decl);
            return generateDeclFn(comp, fn_decl);
        },
        .CompTime => @panic("TODO"),
    }
}

fn generateDeclFn(comp: *Compilation, fn_decl: *Decl.Fn) !void {
    const tree_scope = fn_decl.base.tree_scope;

    const body_node = fn_decl.fn_proto.body_node orelse return generateDeclFnProto(comp, fn_decl);

    const fndef_scope = try Scope.FnDef.create(comp, fn_decl.base.parent_scope);
    defer fndef_scope.base.deref(comp);

    const fn_type = try analyzeFnType(comp, tree_scope, fn_decl.base.parent_scope, fn_decl.fn_proto);
    defer fn_type.base.base.deref(comp);

    var symbol_name = try std.Buffer.init(comp.gpa(), fn_decl.base.name);
    var symbol_name_consumed = false;
    errdefer if (!symbol_name_consumed) symbol_name.deinit();

    // The Decl.Fn owns the initial 1 reference count
    const fn_val = try Value.Fn.create(comp, fn_type, fndef_scope, symbol_name);
    fn_decl.value = .{ .Fn = fn_val };
    symbol_name_consumed = true;

    // Define local parameter variables
    for (fn_type.key.data.Normal.params) |param, i| {
        //AstNode *param_decl_node = get_param_decl_node(fn_table_entry, i);
        const param_decl = @fieldParentPtr(ast.Node.ParamDecl, "base", fn_decl.fn_proto.params.at(i).*);
        const name_token = param_decl.name_token orelse {
            try comp.addCompileError(tree_scope, Span{
                .first = param_decl.firstToken(),
                .last = param_decl.type_node.firstToken(),
            }, "missing parameter name", .{});
            return error.SemanticAnalysisFailed;
        };
        const param_name = tree_scope.tree.tokenSlice(name_token);

        // if (is_noalias && get_codegen_ptr_type(param_type) == nullptr) {
        //     add_node_error(g, param_decl_node, buf_sprintf("noalias on non-pointer parameter"));
        // }

        // TODO check for shadowing

        const var_scope = try Scope.Var.createParam(
            comp,
            fn_val.child_scope,
            param_name,
            &param_decl.base,
            i,
            param.typ,
        );
        fn_val.child_scope = &var_scope.base;

        try fn_type.non_key.Normal.variable_list.append(var_scope);
    }

    var frame = try comp.gpa().create(@Frame(Compilation.genAndAnalyzeCode));
    defer comp.gpa().destroy(frame);
    frame.* = async comp.genAndAnalyzeCode(
        tree_scope,
        fn_val.child_scope,
        body_node,
        fn_type.key.data.Normal.return_type,
    );
    const analyzed_code = try await frame;
    errdefer analyzed_code.destroy(comp.gpa());

    assert(fn_val.block_scope != null);

    // Kick off rendering to LLVM module, but it doesn't block the fn decl
    // analysis from being complete.
    try comp.prelink_group.call(codegen.renderToLlvm, .{ comp, fn_val, analyzed_code });
    try comp.prelink_group.call(addFnToLinkSet, .{ comp, fn_val });
}

async fn addFnToLinkSet(comp: *Compilation, fn_val: *Value.Fn) Compilation.BuildError!void {
    fn_val.base.ref();
    defer fn_val.base.deref(comp);

    fn_val.link_set_node.data = fn_val;

    const held = comp.fn_link_set.acquire();
    defer held.release();

    held.value.append(fn_val.link_set_node);
}

fn getZigDir(allocator: *mem.Allocator) ![]u8 {
    return fs.getAppDataDir(allocator, "zig");
}

fn analyzeFnType(
    comp: *Compilation,
    tree_scope: *Scope.AstTree,
    scope: *Scope,
    fn_proto: *ast.Node.FnProto,
) !*Type.Fn {
    const return_type_node = switch (fn_proto.return_type) {
        .Explicit => |n| n,
        .InferErrorSet => |n| n,
    };
    const return_type = try comp.analyzeTypeExpr(tree_scope, scope, return_type_node);
    return_type.base.deref(comp);

    var params = ArrayList(Type.Fn.Param).init(comp.gpa());
    var params_consumed = false;
    defer if (!params_consumed) {
        for (params.toSliceConst()) |param| {
            param.typ.base.deref(comp);
        }
        params.deinit();
    };

    {
        var it = fn_proto.params.iterator(0);
        while (it.next()) |param_node_ptr| {
            const param_node = param_node_ptr.*.cast(ast.Node.ParamDecl).?;
            const param_type = try comp.analyzeTypeExpr(tree_scope, scope, param_node.type_node);
            errdefer param_type.base.deref(comp);
            try params.append(Type.Fn.Param{
                .typ = param_type,
                .is_noalias = param_node.noalias_token != null,
            });
        }
    }

    const key = Type.Fn.Key{
        .alignment = null,
        .data = Type.Fn.Key.Data{
            .Normal = Type.Fn.Key.Normal{
                .return_type = return_type,
                .params = params.toOwnedSlice(),
                .is_var_args = false, // TODO
                .cc = .Unspecified, // TODO
            },
        },
    };
    params_consumed = true;
    var key_consumed = false;
    defer if (!key_consumed) {
        for (key.data.Normal.params) |param| {
            param.typ.base.deref(comp);
        }
        comp.gpa().free(key.data.Normal.params);
    };

    const fn_type = try Type.Fn.get(comp, key);
    key_consumed = true;
    errdefer fn_type.base.base.deref(comp);

    return fn_type;
}

fn generateDeclFnProto(comp: *Compilation, fn_decl: *Decl.Fn) !void {
    const fn_type = try analyzeFnType(
        comp,
        fn_decl.base.tree_scope,
        fn_decl.base.parent_scope,
        fn_decl.fn_proto,
    );
    defer fn_type.base.base.deref(comp);

    var symbol_name = try std.Buffer.init(comp.gpa(), fn_decl.base.name);
    var symbol_name_consumed = false;
    defer if (!symbol_name_consumed) symbol_name.deinit();

    // The Decl.Fn owns the initial 1 reference count
    const fn_proto_val = try Value.FnProto.create(comp, fn_type, symbol_name);
    fn_decl.value = .{ .FnProto = fn_proto_val };
    symbol_name_consumed = true;
}

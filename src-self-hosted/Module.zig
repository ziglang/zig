const std = @import("std");
const mem = std.mem;
const Allocator = std.mem.Allocator;
const ArrayListUnmanaged = std.ArrayListUnmanaged;
const Value = @import("value.zig").Value;
const Type = @import("type.zig").Type;
const TypedValue = @import("TypedValue.zig");
const assert = std.debug.assert;
const BigIntConst = std.math.big.int.Const;
const BigIntMutable = std.math.big.int.Mutable;
const Target = std.Target;
const Package = @import("Package.zig");
const link = @import("link.zig");
const ir = @import("ir.zig");
const zir = @import("zir.zig");
const Module = @This();
const Inst = ir.Inst;

/// General-purpose allocator.
allocator: *Allocator,
/// Pointer to externally managed resource.
root_pkg: *Package,
/// Module owns this resource.
root_scope: *Scope.ZIRModule,
bin_file: link.ElfFile,
bin_file_dir: std.fs.Dir,
bin_file_path: []const u8,
/// It's rare for a decl to be exported, so we save memory by having a sparse map of
/// Decl pointers to details about them being exported.
/// The Export memory is owned by the `export_owners` table; the slice itself is owned by this table.
decl_exports: std.AutoHashMap(*Decl, []*Export),
/// This models the Decls that perform exports, so that `decl_exports` can be updated when a Decl
/// is modified. Note that the key of this table is not the Decl being exported, but the Decl that
/// is performing the export of another Decl.
/// This table owns the Export memory.
export_owners: std.AutoHashMap(*Decl, []*Export),
/// Maps fully qualified namespaced names to the Decl struct for them.
decl_table: std.AutoHashMap(Decl.Hash, *Decl),

optimize_mode: std.builtin.Mode,
link_error_flags: link.ElfFile.ErrorFlags = link.ElfFile.ErrorFlags{},

work_queue: std.fifo.LinearFifo(WorkItem, .Dynamic),

/// We optimize memory usage for a compilation with no compile errors by storing the
/// error messages and mapping outside of `Decl`.
/// The ErrorMsg memory is owned by the decl, using Module's allocator.
/// Note that a Decl can succeed but the Fn it represents can fail. In this case,
/// a Decl can have a failed_decls entry but have analysis status of success.
failed_decls: std.AutoHashMap(*Decl, *ErrorMsg),
/// Using a map here for consistency with the other fields here.
/// The ErrorMsg memory is owned by the `Scope.ZIRModule`, using Module's allocator.
failed_files: std.AutoHashMap(*Scope.ZIRModule, *ErrorMsg),
/// Using a map here for consistency with the other fields here.
/// The ErrorMsg memory is owned by the `Export`, using Module's allocator.
failed_exports: std.AutoHashMap(*Export, *ErrorMsg),

/// Incrementing integer used to compare against the corresponding Decl
/// field to determine whether a Decl's status applies to an ongoing update, or a
/// previous analysis.
generation: u32 = 0,

/// Candidates for deletion. After a semantic analysis update completes, this list
/// contains Decls that need to be deleted if they end up having no references to them.
deletion_set: std.ArrayListUnmanaged(*Decl) = std.ArrayListUnmanaged(*Decl){},

pub const WorkItem = union(enum) {
    /// Write the machine code for a Decl to the output file.
    codegen_decl: *Decl,
    /// Decl has been determined to be outdated; perform semantic analysis again.
    re_analyze_decl: *Decl,
};

pub const Export = struct {
    options: std.builtin.ExportOptions,
    /// Byte offset into the file that contains the export directive.
    src: usize,
    /// Represents the position of the export, if any, in the output file.
    link: link.ElfFile.Export,
    /// The Decl that performs the export. Note that this is *not* the Decl being exported.
    owner_decl: *Decl,
    /// The Decl being exported. Note this is *not* the Decl performing the export.
    exported_decl: *Decl,
    status: enum {
        in_progress,
        failed,
        /// Indicates that the failure was due to a temporary issue, such as an I/O error
        /// when writing to the output file. Retrying the export may succeed.
        failed_retryable,
        complete,
    },
};

pub const Decl = struct {
    /// This name is relative to the containing namespace of the decl. It uses a null-termination
    /// to save bytes, since there can be a lot of decls in a compilation. The null byte is not allowed
    /// in symbol names, because executable file formats use null-terminated strings for symbol names.
    /// All Decls have names, even values that are not bound to a zig namespace. This is necessary for
    /// mapping them to an address in the output file.
    /// Memory owned by this decl, using Module's allocator.
    name: [*:0]const u8,
    /// The direct parent container of the Decl. This field will need to get more fleshed out when
    /// self-hosted supports proper struct types and Zig AST => ZIR.
    /// Reference to externally owned memory.
    scope: *Scope.ZIRModule,
    /// Byte offset into the source file that contains this declaration.
    /// This is the base offset that src offsets within this Decl are relative to.
    src: usize,
    /// The most recent value of the Decl after a successful semantic analysis.
    typed_value: union(enum) {
        never_succeeded: void,
        most_recent: TypedValue.Managed,
    },
    /// Represents the "shallow" analysis status. For example, for decls that are functions,
    /// the function type is analyzed with this set to `in_progress`, however, the semantic
    /// analysis of the function body is performed with this value set to `success`. Functions
    /// have their own analysis status field.
    analysis: enum {
        /// Semantic analysis for this Decl is running right now. This state detects dependency loops.
        in_progress,
        /// This Decl might be OK but it depends on another one which did not successfully complete
        /// semantic analysis.
        dependency_failure,
        /// Semantic analysis failure.
        /// There will be a corresponding ErrorMsg in Module.failed_decls.
        sema_failure,
        /// There will be a corresponding ErrorMsg in Module.failed_decls.
        codegen_failure,
        /// There will be a corresponding ErrorMsg in Module.failed_decls.
        /// This indicates the failure was something like running out of disk space,
        /// and attempting codegen again may succeed.
        codegen_failure_retryable,
        /// Everything is done. During an update, this Decl may be out of date, depending
        /// on its dependencies. The `generation` field can be used to determine if this
        /// completion status occurred before or after a given update.
        complete,
        /// A Module update is in progress, and this Decl has been flagged as being known
        /// to require re-analysis.
        outdated,
    },
    /// This flag is set when this Decl is added to a check_for_deletion set, and cleared
    /// when removed.
    deletion_flag: bool,
    /// An integer that can be checked against the corresponding incrementing
    /// generation field of Module. This is used to determine whether `complete` status
    /// represents pre- or post- re-analysis.
    generation: u32,

    /// Represents the position of the code in the output file.
    /// This is populated regardless of semantic analysis and code generation.
    link: link.ElfFile.TextBlock = link.ElfFile.TextBlock.empty,

    contents_hash: Hash,

    /// The shallow set of other decls whose typed_value could possibly change if this Decl's
    /// typed_value is modified.
    dependants: ArrayListUnmanaged(*Decl) = ArrayListUnmanaged(*Decl){},
    /// The shallow set of other decls whose typed_value changing indicates that this Decl's
    /// typed_value may need to be regenerated.
    dependencies: ArrayListUnmanaged(*Decl) = ArrayListUnmanaged(*Decl){},

    pub fn destroy(self: *Decl, allocator: *Allocator) void {
        allocator.free(mem.spanZ(self.name));
        if (self.typedValueManaged()) |tvm| {
            tvm.deinit(allocator);
        }
        self.dependants.deinit(allocator);
        self.dependencies.deinit(allocator);
        allocator.destroy(self);
    }

    pub const Hash = [16]u8;

    /// If the name is small enough, it is used directly as the hash.
    /// If it is long, blake3 hash is computed.
    pub fn hashSimpleName(name: []const u8) Hash {
        var out: Hash = undefined;
        if (name.len <= Hash.len) {
            mem.copy(u8, &out, name);
            mem.set(u8, out[name.len..], 0);
        } else {
            std.crypto.Blake3.hash(name, &out);
        }
        return out;
    }

    /// Must generate unique bytes with no collisions with other decls.
    /// The point of hashing here is only to limit the number of bytes of
    /// the unique identifier to a fixed size (16 bytes).
    pub fn fullyQualifiedNameHash(self: Decl) Hash {
        // Right now we only have ZIRModule as the source. So this is simply the
        // relative name of the decl.
        return hashSimpleName(mem.spanZ(self.name));
    }

    pub fn typedValue(self: *Decl) error{AnalysisFail}!TypedValue {
        const tvm = self.typedValueManaged() orelse return error.AnalysisFail;
        return tvm.typed_value;
    }

    pub fn value(self: *Decl) error{AnalysisFail}!Value {
        return (try self.typedValue()).val;
    }

    pub fn dump(self: *Decl) void {
        const loc = std.zig.findLineColumn(self.scope.source.bytes, self.src);
        std.debug.warn("{}:{}:{} name={} status={}", .{
            self.scope.sub_file_path,
            loc.line + 1,
            loc.column + 1,
            mem.spanZ(self.name),
            @tagName(self.analysis),
        });
        if (self.typedValueManaged()) |tvm| {
            std.debug.warn(" ty={} val={}", .{ tvm.typed_value.ty, tvm.typed_value.val });
        }
        std.debug.warn("\n", .{});
    }

    fn typedValueManaged(self: *Decl) ?*TypedValue.Managed {
        switch (self.typed_value) {
            .most_recent => |*x| return x,
            .never_succeeded => return null,
        }
    }

    fn removeDependant(self: *Decl, other: *Decl) void {
        for (self.dependants.items) |item, i| {
            if (item == other) {
                _ = self.dependants.swapRemove(i);
                return;
            }
        }
        unreachable;
    }

    fn removeDependency(self: *Decl, other: *Decl) void {
        for (self.dependencies.items) |item, i| {
            if (item == other) {
                _ = self.dependencies.swapRemove(i);
                return;
            }
        }
        unreachable;
    }
};

/// Fn struct memory is owned by the Decl's TypedValue.Managed arena allocator.
pub const Fn = struct {
    /// This memory owned by the Decl's TypedValue.Managed arena allocator.
    fn_type: Type,
    analysis: union(enum) {
        /// The value is the source instruction.
        queued: *zir.Inst.Fn,
        in_progress: *Analysis,
        /// There will be a corresponding ErrorMsg in Module.failed_decls
        sema_failure,
        /// This Fn might be OK but it depends on another Decl which did not successfully complete
        /// semantic analysis.
        dependency_failure,
        success: Body,
    },
    owner_decl: *Decl,

    /// This memory is temporary and points to stack memory for the duration
    /// of Fn analysis.
    pub const Analysis = struct {
        inner_block: Scope.Block,
        /// TODO Performance optimization idea: instead of this inst_table,
        /// use a field in the zir.Inst instead to track corresponding instructions
        inst_table: std.AutoHashMap(*zir.Inst, *Inst),
        needed_inst_capacity: usize,
    };
};

pub const Scope = struct {
    tag: Tag,

    pub fn cast(base: *Scope, comptime T: type) ?*T {
        if (base.tag != T.base_tag)
            return null;

        return @fieldParentPtr(T, "base", base);
    }

    /// Asserts the scope has a parent which is a DeclAnalysis and
    /// returns the arena Allocator.
    pub fn arena(self: *Scope) *Allocator {
        switch (self.tag) {
            .block => return self.cast(Block).?.arena,
            .decl => return &self.cast(DeclAnalysis).?.arena.allocator,
            .zir_module => return &self.cast(ZIRModule).?.contents.module.arena.allocator,
        }
    }

    /// Asserts the scope has a parent which is a DeclAnalysis and
    /// returns the Decl.
    pub fn decl(self: *Scope) ?*Decl {
        return switch (self.tag) {
            .block => self.cast(Block).?.decl,
            .decl => self.cast(DeclAnalysis).?.decl,
            .zir_module => null,
        };
    }

    /// Asserts the scope has a parent which is a ZIRModule and
    /// returns it.
    pub fn namespace(self: *Scope) *ZIRModule {
        switch (self.tag) {
            .block => return self.cast(Block).?.decl.scope,
            .decl => return self.cast(DeclAnalysis).?.decl.scope,
            .zir_module => return self.cast(ZIRModule).?,
        }
    }

    pub fn dumpInst(self: *Scope, inst: *Inst) void {
        const zir_module = self.namespace();
        const loc = std.zig.findLineColumn(zir_module.source.bytes, inst.src);
        std.debug.warn("{}:{}:{}: {}: ty={}\n", .{
            zir_module.sub_file_path,
            loc.line + 1,
            loc.column + 1,
            @tagName(inst.tag),
            inst.ty,
        });
    }

    pub const Tag = enum {
        zir_module,
        block,
        decl,
    };

    pub const ZIRModule = struct {
        pub const base_tag: Tag = .zir_module;
        base: Scope = Scope{ .tag = base_tag },
        /// Relative to the owning package's root_src_dir.
        /// Reference to external memory, not owned by ZIRModule.
        sub_file_path: []const u8,
        source: union(enum) {
            unloaded: void,
            bytes: [:0]const u8,
        },
        contents: union {
            not_available: void,
            module: *zir.Module,
        },
        status: enum {
            never_loaded,
            unloaded_success,
            unloaded_parse_failure,
            unloaded_sema_failure,

            loaded_sema_failure,
            loaded_success,
        },

        pub fn unload(self: *ZIRModule, allocator: *Allocator) void {
            switch (self.status) {
                .never_loaded,
                .unloaded_parse_failure,
                .unloaded_sema_failure,
                .unloaded_success,
                => {},

                .loaded_success => {
                    self.contents.module.deinit(allocator);
                    allocator.destroy(self.contents.module);
                    self.status = .unloaded_success;
                },
                .loaded_sema_failure => {
                    self.contents.module.deinit(allocator);
                    allocator.destroy(self.contents.module);
                    self.status = .unloaded_sema_failure;
                },
            }
            switch (self.source) {
                .bytes => |bytes| {
                    allocator.free(bytes);
                    self.source = .{ .unloaded = {} };
                },
                .unloaded => {},
            }
        }

        pub fn deinit(self: *ZIRModule, allocator: *Allocator) void {
            self.unload(allocator);
            self.* = undefined;
        }

        pub fn dumpSrc(self: *ZIRModule, src: usize) void {
            const loc = std.zig.findLineColumn(self.source.bytes, src);
            std.debug.warn("{}:{}:{}\n", .{ self.sub_file_path, loc.line + 1, loc.column + 1 });
        }
    };

    /// This is a temporary structure, references to it are valid only
    /// during semantic analysis of the block.
    pub const Block = struct {
        pub const base_tag: Tag = .block;
        base: Scope = Scope{ .tag = base_tag },
        func: *Fn,
        decl: *Decl,
        instructions: ArrayListUnmanaged(*Inst),
        /// Points to the arena allocator of DeclAnalysis
        arena: *Allocator,
    };

    /// This is a temporary structure, references to it are valid only
    /// during semantic analysis of the decl.
    pub const DeclAnalysis = struct {
        pub const base_tag: Tag = .decl;
        base: Scope = Scope{ .tag = base_tag },
        decl: *Decl,
        arena: std.heap.ArenaAllocator,
    };
};

pub const Body = struct {
    instructions: []*Inst,
};

pub const AllErrors = struct {
    arena: std.heap.ArenaAllocator.State,
    list: []const Message,

    pub const Message = struct {
        src_path: []const u8,
        line: usize,
        column: usize,
        byte_offset: usize,
        msg: []const u8,
    };

    pub fn deinit(self: *AllErrors, allocator: *Allocator) void {
        self.arena.promote(allocator).deinit();
    }

    fn add(
        arena: *std.heap.ArenaAllocator,
        errors: *std.ArrayList(Message),
        sub_file_path: []const u8,
        source: []const u8,
        simple_err_msg: ErrorMsg,
    ) !void {
        const loc = std.zig.findLineColumn(source, simple_err_msg.byte_offset);
        try errors.append(.{
            .src_path = try arena.allocator.dupe(u8, sub_file_path),
            .msg = try arena.allocator.dupe(u8, simple_err_msg.msg),
            .byte_offset = simple_err_msg.byte_offset,
            .line = loc.line,
            .column = loc.column,
        });
    }
};

pub const InitOptions = struct {
    target: std.Target,
    root_pkg: *Package,
    output_mode: std.builtin.OutputMode,
    bin_file_dir: ?std.fs.Dir = null,
    bin_file_path: []const u8,
    link_mode: ?std.builtin.LinkMode = null,
    object_format: ?std.builtin.ObjectFormat = null,
    optimize_mode: std.builtin.Mode = .Debug,
};

pub fn init(gpa: *Allocator, options: InitOptions) !Module {
    const root_scope = try gpa.create(Scope.ZIRModule);
    errdefer gpa.destroy(root_scope);

    root_scope.* = .{
        .sub_file_path = options.root_pkg.root_src_path,
        .source = .{ .unloaded = {} },
        .contents = .{ .not_available = {} },
        .status = .never_loaded,
    };

    const bin_file_dir = options.bin_file_dir orelse std.fs.cwd();
    var bin_file = try link.openBinFilePath(gpa, bin_file_dir, options.bin_file_path, .{
        .target = options.target,
        .output_mode = options.output_mode,
        .link_mode = options.link_mode orelse .Static,
        .object_format = options.object_format orelse options.target.getObjectFormat(),
    });
    errdefer bin_file.deinit();

    return Module{
        .allocator = gpa,
        .root_pkg = options.root_pkg,
        .root_scope = root_scope,
        .bin_file_dir = bin_file_dir,
        .bin_file_path = options.bin_file_path,
        .bin_file = bin_file,
        .optimize_mode = options.optimize_mode,
        .decl_table = std.AutoHashMap(Decl.Hash, *Decl).init(gpa),
        .decl_exports = std.AutoHashMap(*Decl, []*Export).init(gpa),
        .export_owners = std.AutoHashMap(*Decl, []*Export).init(gpa),
        .failed_decls = std.AutoHashMap(*Decl, *ErrorMsg).init(gpa),
        .failed_files = std.AutoHashMap(*Scope.ZIRModule, *ErrorMsg).init(gpa),
        .failed_exports = std.AutoHashMap(*Export, *ErrorMsg).init(gpa),
        .work_queue = std.fifo.LinearFifo(WorkItem, .Dynamic).init(gpa),
    };
}

pub fn deinit(self: *Module) void {
    self.bin_file.deinit();
    const allocator = self.allocator;
    self.deletion_set.deinit(allocator);
    self.work_queue.deinit();
    {
        var it = self.decl_table.iterator();
        while (it.next()) |kv| {
            kv.value.destroy(allocator);
        }
        self.decl_table.deinit();
    }
    {
        var it = self.failed_decls.iterator();
        while (it.next()) |kv| {
            kv.value.destroy(allocator);
        }
        self.failed_decls.deinit();
    }
    {
        var it = self.failed_files.iterator();
        while (it.next()) |kv| {
            kv.value.destroy(allocator);
        }
        self.failed_files.deinit();
    }
    {
        var it = self.failed_exports.iterator();
        while (it.next()) |kv| {
            kv.value.destroy(allocator);
        }
        self.failed_exports.deinit();
    }
    {
        var it = self.decl_exports.iterator();
        while (it.next()) |kv| {
            const export_list = kv.value;
            allocator.free(export_list);
        }
        self.decl_exports.deinit();
    }
    {
        var it = self.export_owners.iterator();
        while (it.next()) |kv| {
            freeExportList(allocator, kv.value);
        }
        self.export_owners.deinit();
    }
    {
        self.root_scope.deinit(allocator);
        allocator.destroy(self.root_scope);
    }
    self.* = undefined;
}

fn freeExportList(allocator: *Allocator, export_list: []*Export) void {
    for (export_list) |exp| {
        allocator.destroy(exp);
    }
    allocator.free(export_list);
}

pub fn target(self: Module) std.Target {
    return self.bin_file.options.target;
}

/// Detect changes to source files, perform semantic analysis, and update the output files.
pub fn update(self: *Module) !void {
    self.generation += 1;

    // TODO Use the cache hash file system to detect which source files changed.
    // Here we simulate a full cache miss.
    // Analyze the root source file now.
    // Source files could have been loaded for any reason; to force a refresh we unload now.
    self.root_scope.unload(self.allocator);
    self.analyzeRoot(self.root_scope) catch |err| switch (err) {
        error.AnalysisFail => {
            assert(self.totalErrorCount() != 0);
        },
        else => |e| return e,
    };

    try self.performAllTheWork();

    // Process the deletion set.
    while (self.deletion_set.popOrNull()) |decl| {
        if (decl.dependants.items.len != 0) {
            decl.deletion_flag = false;
            continue;
        }
        try self.deleteDecl(decl);
    }

    // If there are any errors, we anticipate the source files being loaded
    // to report error messages. Otherwise we unload all source files to save memory.
    if (self.totalErrorCount() == 0) {
        self.root_scope.unload(self.allocator);
    }

    try self.bin_file.flush();
    self.link_error_flags = self.bin_file.error_flags;
}

/// Having the file open for writing is problematic as far as executing the
/// binary is concerned. This will remove the write flag, or close the file,
/// or whatever is needed so that it can be executed.
/// After this, one must call` makeFileWritable` before calling `update`.
pub fn makeBinFileExecutable(self: *Module) !void {
    return self.bin_file.makeExecutable();
}

pub fn makeBinFileWritable(self: *Module) !void {
    return self.bin_file.makeWritable(self.bin_file_dir, self.bin_file_path);
}

pub fn totalErrorCount(self: *Module) usize {
    return self.failed_decls.size +
        self.failed_files.size +
        self.failed_exports.size +
        @boolToInt(self.link_error_flags.no_entry_point_found);
}

pub fn getAllErrorsAlloc(self: *Module) !AllErrors {
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    errdefer arena.deinit();

    var errors = std.ArrayList(AllErrors.Message).init(self.allocator);
    defer errors.deinit();

    {
        var it = self.failed_files.iterator();
        while (it.next()) |kv| {
            const scope = kv.key;
            const err_msg = kv.value;
            const source = try self.getSource(scope);
            try AllErrors.add(&arena, &errors, scope.sub_file_path, source, err_msg.*);
        }
    }
    {
        var it = self.failed_decls.iterator();
        while (it.next()) |kv| {
            const decl = kv.key;
            const err_msg = kv.value;
            const source = try self.getSource(decl.scope);
            try AllErrors.add(&arena, &errors, decl.scope.sub_file_path, source, err_msg.*);
        }
    }
    {
        var it = self.failed_exports.iterator();
        while (it.next()) |kv| {
            const decl = kv.key.owner_decl;
            const err_msg = kv.value;
            const source = try self.getSource(decl.scope);
            try AllErrors.add(&arena, &errors, decl.scope.sub_file_path, source, err_msg.*);
        }
    }

    if (self.link_error_flags.no_entry_point_found) {
        try errors.append(.{
            .src_path = self.root_pkg.root_src_path,
            .line = 0,
            .column = 0,
            .byte_offset = 0,
            .msg = try std.fmt.allocPrint(&arena.allocator, "no entry point found", .{}),
        });
    }

    assert(errors.items.len == self.totalErrorCount());

    return AllErrors{
        .list = try arena.allocator.dupe(AllErrors.Message, errors.items),
        .arena = arena.state,
    };
}

const InnerError = error{ OutOfMemory, AnalysisFail };

pub fn performAllTheWork(self: *Module) error{OutOfMemory}!void {
    while (self.work_queue.readItem()) |work_item| switch (work_item) {
        .codegen_decl => |decl| switch (decl.analysis) {
            .in_progress => unreachable,
            .outdated => unreachable,

            .sema_failure,
            .codegen_failure,
            .dependency_failure,
            => continue,

            .complete, .codegen_failure_retryable => {
                if (decl.typed_value.most_recent.typed_value.val.cast(Value.Payload.Function)) |payload| {
                    switch (payload.func.analysis) {
                        .queued => self.analyzeFnBody(decl, payload.func) catch |err| switch (err) {
                            error.AnalysisFail => {
                                if (payload.func.analysis == .queued) {
                                    payload.func.analysis = .dependency_failure;
                                }
                                continue;
                            },
                            else => |e| return e,
                        },
                        .in_progress => unreachable,
                        .sema_failure, .dependency_failure => continue,
                        .success => {},
                    }
                }

                assert(decl.typed_value.most_recent.typed_value.ty.hasCodeGenBits());

                self.bin_file.updateDecl(self, decl) catch |err| switch (err) {
                    error.OutOfMemory => return error.OutOfMemory,
                    error.AnalysisFail => {
                        decl.analysis = .dependency_failure;
                    },
                    else => {
                        try self.failed_decls.ensureCapacity(self.failed_decls.size + 1);
                        self.failed_decls.putAssumeCapacityNoClobber(decl, try ErrorMsg.create(
                            self.allocator,
                            decl.src,
                            "unable to codegen: {}",
                            .{@errorName(err)},
                        ));
                        decl.analysis = .codegen_failure_retryable;
                    },
                };
            },
        },
        .re_analyze_decl => |decl| switch (decl.analysis) {
            .in_progress => unreachable,

            .sema_failure,
            .codegen_failure,
            .dependency_failure,
            .complete,
            .codegen_failure_retryable,
            => continue,

            .outdated => {
                const zir_module = self.getSrcModule(decl.scope) catch |err| switch (err) {
                    error.OutOfMemory => return error.OutOfMemory,
                    else => {
                        try self.failed_decls.ensureCapacity(self.failed_decls.size + 1);
                        self.failed_decls.putAssumeCapacityNoClobber(decl, try ErrorMsg.create(
                            self.allocator,
                            decl.src,
                            "unable to load source file '{}': {}",
                            .{ decl.scope.sub_file_path, @errorName(err) },
                        ));
                        decl.analysis = .codegen_failure_retryable;
                        continue;
                    },
                };
                const decl_name = mem.spanZ(decl.name);
                // We already detected deletions, so we know this will be found.
                const src_decl = zir_module.findDecl(decl_name).?;
                self.reAnalyzeDecl(decl, src_decl) catch |err| switch (err) {
                    error.OutOfMemory => return error.OutOfMemory,
                    error.AnalysisFail => continue,
                };
            },
        },
    };
}

fn declareDeclDependency(self: *Module, depender: *Decl, dependee: *Decl) !void {
    try depender.dependencies.ensureCapacity(self.allocator, depender.dependencies.items.len + 1);
    try dependee.dependants.ensureCapacity(self.allocator, dependee.dependants.items.len + 1);

    for (depender.dependencies.items) |item| {
        if (item == dependee) break; // Already in the set.
    } else {
        depender.dependencies.appendAssumeCapacity(dependee);
    }

    for (dependee.dependants.items) |item| {
        if (item == depender) break; // Already in the set.
    } else {
        dependee.dependants.appendAssumeCapacity(depender);
    }
}

fn getSource(self: *Module, root_scope: *Scope.ZIRModule) ![:0]const u8 {
    switch (root_scope.source) {
        .unloaded => {
            const source = try self.root_pkg.root_src_dir.readFileAllocOptions(
                self.allocator,
                root_scope.sub_file_path,
                std.math.maxInt(u32),
                1,
                0,
            );
            root_scope.source = .{ .bytes = source };
            return source;
        },
        .bytes => |bytes| return bytes,
    }
}

fn getSrcModule(self: *Module, root_scope: *Scope.ZIRModule) !*zir.Module {
    switch (root_scope.status) {
        .never_loaded, .unloaded_success => {
            try self.failed_files.ensureCapacity(self.failed_files.size + 1);

            const source = try self.getSource(root_scope);

            var keep_zir_module = false;
            const zir_module = try self.allocator.create(zir.Module);
            defer if (!keep_zir_module) self.allocator.destroy(zir_module);

            zir_module.* = try zir.parse(self.allocator, source);
            defer if (!keep_zir_module) zir_module.deinit(self.allocator);

            if (zir_module.error_msg) |src_err_msg| {
                self.failed_files.putAssumeCapacityNoClobber(
                    root_scope,
                    try ErrorMsg.create(self.allocator, src_err_msg.byte_offset, "{}", .{src_err_msg.msg}),
                );
                root_scope.status = .unloaded_parse_failure;
                return error.AnalysisFail;
            }

            root_scope.status = .loaded_success;
            root_scope.contents = .{ .module = zir_module };
            keep_zir_module = true;

            return zir_module;
        },

        .unloaded_parse_failure,
        .unloaded_sema_failure,
        => return error.AnalysisFail,

        .loaded_success, .loaded_sema_failure => return root_scope.contents.module,
    }
}

fn analyzeRoot(self: *Module, root_scope: *Scope.ZIRModule) !void {
    switch (root_scope.status) {
        .never_loaded => {
            const src_module = try self.getSrcModule(root_scope);

            // Here we ensure enough queue capacity to store all the decls, so that later we can use
            // appendAssumeCapacity.
            try self.work_queue.ensureUnusedCapacity(src_module.decls.len);

            for (src_module.decls) |decl| {
                if (decl.cast(zir.Inst.Export)) |export_inst| {
                    _ = try self.resolveDecl(&root_scope.base, &export_inst.base);
                }
            }
        },

        .unloaded_parse_failure,
        .unloaded_sema_failure,
        .unloaded_success,
        .loaded_sema_failure,
        .loaded_success,
        => {
            const src_module = try self.getSrcModule(root_scope);

            var exports_to_resolve = std.ArrayList(*zir.Inst).init(self.allocator);
            defer exports_to_resolve.deinit();

            // Keep track of the decls that we expect to see in this file so that
            // we know which ones have been deleted.
            var deleted_decls = std.AutoHashMap(*Decl, void).init(self.allocator);
            defer deleted_decls.deinit();
            try deleted_decls.ensureCapacity(self.decl_table.size);
            {
                var it = self.decl_table.iterator();
                while (it.next()) |kv| {
                    deleted_decls.putAssumeCapacityNoClobber(kv.value, {});
                }
            }

            for (src_module.decls) |src_decl| {
                const name_hash = Decl.hashSimpleName(src_decl.name);
                if (self.decl_table.get(name_hash)) |kv| {
                    const decl = kv.value;
                    deleted_decls.removeAssertDiscard(decl);
                    const new_contents_hash = Decl.hashSimpleName(src_decl.contents);
                    //std.debug.warn("'{}' contents: '{}'\n", .{ src_decl.name, src_decl.contents });
                    if (!mem.eql(u8, &new_contents_hash, &decl.contents_hash)) {
                        //std.debug.warn("'{}' {x} => {x}\n", .{ src_decl.name, decl.contents_hash, new_contents_hash });
                        try self.markOutdatedDecl(decl);
                        decl.contents_hash = new_contents_hash;
                    }
                } else if (src_decl.cast(zir.Inst.Export)) |export_inst| {
                    try exports_to_resolve.append(&export_inst.base);
                }
            }
            {
                // Handle explicitly deleted decls from the source code. Not to be confused
                // with when we delete decls because they are no longer referenced.
                var it = deleted_decls.iterator();
                while (it.next()) |kv| {
                    //std.debug.warn("noticed '{}' deleted from source\n", .{kv.key.name});
                    try self.deleteDecl(kv.key);
                }
            }
            for (exports_to_resolve.items) |export_inst| {
                _ = try self.resolveDecl(&root_scope.base, export_inst);
            }
        },
    }
}

fn deleteDecl(self: *Module, decl: *Decl) !void {
    try self.deletion_set.ensureCapacity(self.allocator, self.deletion_set.items.len + decl.dependencies.items.len);

    //std.debug.warn("deleting decl '{}'\n", .{decl.name});
    const name_hash = decl.fullyQualifiedNameHash();
    self.decl_table.removeAssertDiscard(name_hash);
    // Remove itself from its dependencies, because we are about to destroy the decl pointer.
    for (decl.dependencies.items) |dep| {
        dep.removeDependant(decl);
        if (dep.dependants.items.len == 0) {
            // We don't recursively perform a deletion here, because during the update,
            // another reference to it may turn up.
            assert(!dep.deletion_flag);
            dep.deletion_flag = true;
            self.deletion_set.appendAssumeCapacity(dep);
        }
    }
    // Anything that depends on this deleted decl certainly needs to be re-analyzed.
    for (decl.dependants.items) |dep| {
        dep.removeDependency(decl);
        if (dep.analysis != .outdated) {
            // TODO Move this failure possibility to the top of the function.
            try self.markOutdatedDecl(dep);
        }
    }
    if (self.failed_decls.remove(decl)) |entry| {
        entry.value.destroy(self.allocator);
    }
    self.deleteDeclExports(decl);
    self.bin_file.freeDecl(decl);
    decl.destroy(self.allocator);
}

/// Delete all the Export objects that are caused by this Decl. Re-analysis of
/// this Decl will cause them to be re-created (or not).
fn deleteDeclExports(self: *Module, decl: *Decl) void {
    const kv = self.export_owners.remove(decl) orelse return;

    for (kv.value) |exp| {
        if (self.decl_exports.get(exp.exported_decl)) |decl_exports_kv| {
            // Remove exports with owner_decl matching the regenerating decl.
            const list = decl_exports_kv.value;
            var i: usize = 0;
            var new_len = list.len;
            while (i < new_len) {
                if (list[i].owner_decl == decl) {
                    mem.copyBackwards(*Export, list[i..], list[i + 1 .. new_len]);
                    new_len -= 1;
                } else {
                    i += 1;
                }
            }
            decl_exports_kv.value = self.allocator.shrink(list, new_len);
            if (new_len == 0) {
                self.decl_exports.removeAssertDiscard(exp.exported_decl);
            }
        }

        self.bin_file.deleteExport(exp.link);
        self.allocator.destroy(exp);
    }
    self.allocator.free(kv.value);
}

fn analyzeFnBody(self: *Module, decl: *Decl, func: *Fn) !void {
    // Use the Decl's arena for function memory.
    var arena = decl.typed_value.most_recent.arena.?.promote(self.allocator);
    defer decl.typed_value.most_recent.arena.?.* = arena.state;
    var analysis: Fn.Analysis = .{
        .inner_block = .{
            .func = func,
            .decl = decl,
            .instructions = .{},
            .arena = &arena.allocator,
        },
        .needed_inst_capacity = 0,
        .inst_table = std.AutoHashMap(*zir.Inst, *Inst).init(self.allocator),
    };
    defer analysis.inner_block.instructions.deinit(self.allocator);
    defer analysis.inst_table.deinit();

    const fn_inst = func.analysis.queued;
    func.analysis = .{ .in_progress = &analysis };

    try self.analyzeBody(&analysis.inner_block.base, fn_inst.positionals.body);

    func.analysis = .{
        .success = .{
            .instructions = try arena.allocator.dupe(*Inst, analysis.inner_block.instructions.items),
        },
    };
}

fn reAnalyzeDecl(self: *Module, decl: *Decl, old_inst: *zir.Inst) InnerError!void {
    switch (decl.analysis) {
        .in_progress => unreachable,
        .dependency_failure,
        .sema_failure,
        .codegen_failure,
        .codegen_failure_retryable,
        .complete,
        => return,

        .outdated => {}, // Decl re-analysis
    }
    //std.debug.warn("re-analyzing {}\n", .{decl.name});
    decl.src = old_inst.src;

    // The exports this Decl performs will be re-discovered, so we remove them here
    // prior to re-analysis.
    self.deleteDeclExports(decl);
    // Dependencies will be re-discovered, so we remove them here prior to re-analysis.
    for (decl.dependencies.items) |dep| {
        dep.removeDependant(decl);
        if (dep.dependants.items.len == 0) {
            // We don't perform a deletion here, because this Decl or another one
            // may end up referencing it before the update is complete.
            assert(!dep.deletion_flag);
            dep.deletion_flag = true;
            try self.deletion_set.append(self.allocator, dep);
        }
    }
    decl.dependencies.shrink(self.allocator, 0);
    var decl_scope: Scope.DeclAnalysis = .{
        .decl = decl,
        .arena = std.heap.ArenaAllocator.init(self.allocator),
    };
    errdefer decl_scope.arena.deinit();

    const typed_value = self.analyzeInstConst(&decl_scope.base, old_inst) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        error.AnalysisFail => {
            switch (decl.analysis) {
                .in_progress => decl.analysis = .dependency_failure,
                else => {},
            }
            decl.generation = self.generation;
            return error.AnalysisFail;
        },
    };
    const arena_state = try decl_scope.arena.allocator.create(std.heap.ArenaAllocator.State);
    arena_state.* = decl_scope.arena.state;

    var prev_type_has_bits = false;
    var type_changed = true;

    if (decl.typedValueManaged()) |tvm| {
        prev_type_has_bits = tvm.typed_value.ty.hasCodeGenBits();
        type_changed = !tvm.typed_value.ty.eql(typed_value.ty);

        tvm.deinit(self.allocator);
    }
    decl.typed_value = .{
        .most_recent = .{
            .typed_value = typed_value,
            .arena = arena_state,
        },
    };
    decl.analysis = .complete;
    decl.generation = self.generation;
    if (typed_value.ty.hasCodeGenBits()) {
        // We don't fully codegen the decl until later, but we do need to reserve a global
        // offset table index for it. This allows us to codegen decls out of dependency order,
        // increasing how many computations can be done in parallel.
        try self.bin_file.allocateDeclIndexes(decl);
        try self.work_queue.writeItem(.{ .codegen_decl = decl });
    } else if (prev_type_has_bits) {
        self.bin_file.freeDecl(decl);
    }

    // If the decl is a function, and the type is the same, we do not need
    // to chase the dependants.
    if (type_changed or typed_value.val.tag() != .function) {
        for (decl.dependants.items) |dep| {
            switch (dep.analysis) {
                .in_progress => unreachable,
                .outdated => continue, // already queued for update

                .dependency_failure,
                .sema_failure,
                .codegen_failure,
                .codegen_failure_retryable,
                .complete,
                => if (dep.generation != self.generation) {
                    try self.markOutdatedDecl(dep);
                },
            }
        }
    }
}

fn markOutdatedDecl(self: *Module, decl: *Decl) !void {
    //std.debug.warn("mark {} outdated\n", .{decl.name});
    try self.work_queue.writeItem(.{ .re_analyze_decl = decl });
    if (self.failed_decls.remove(decl)) |entry| {
        entry.value.destroy(self.allocator);
    }
    decl.analysis = .outdated;
}

fn resolveDecl(self: *Module, scope: *Scope, old_inst: *zir.Inst) InnerError!*Decl {
    const hash = Decl.hashSimpleName(old_inst.name);
    if (self.decl_table.get(hash)) |kv| {
        const decl = kv.value;
        try self.reAnalyzeDecl(decl, old_inst);
        return decl;
    } else if (old_inst.cast(zir.Inst.DeclVal)) |decl_val| {
        // This is just a named reference to another decl.
        return self.analyzeDeclVal(scope, decl_val);
    } else {
        const new_decl = blk: {
            try self.decl_table.ensureCapacity(self.decl_table.size + 1);
            const new_decl = try self.allocator.create(Decl);
            errdefer self.allocator.destroy(new_decl);
            const name = try mem.dupeZ(self.allocator, u8, old_inst.name);
            errdefer self.allocator.free(name);
            new_decl.* = .{
                .name = name,
                .scope = scope.namespace(),
                .src = old_inst.src,
                .typed_value = .{ .never_succeeded = {} },
                .analysis = .in_progress,
                .deletion_flag = false,
                .contents_hash = Decl.hashSimpleName(old_inst.contents),
                .link = link.ElfFile.TextBlock.empty,
                .generation = 0,
            };
            self.decl_table.putAssumeCapacityNoClobber(hash, new_decl);
            break :blk new_decl;
        };

        var decl_scope: Scope.DeclAnalysis = .{
            .decl = new_decl,
            .arena = std.heap.ArenaAllocator.init(self.allocator),
        };
        errdefer decl_scope.arena.deinit();

        const typed_value = self.analyzeInstConst(&decl_scope.base, old_inst) catch |err| switch (err) {
            error.OutOfMemory => return error.OutOfMemory,
            error.AnalysisFail => {
                switch (new_decl.analysis) {
                    .in_progress => new_decl.analysis = .dependency_failure,
                    else => {},
                }
                new_decl.generation = self.generation;
                return error.AnalysisFail;
            },
        };
        const arena_state = try decl_scope.arena.allocator.create(std.heap.ArenaAllocator.State);

        arena_state.* = decl_scope.arena.state;

        new_decl.typed_value = .{
            .most_recent = .{
                .typed_value = typed_value,
                .arena = arena_state,
            },
        };
        new_decl.analysis = .complete;
        new_decl.generation = self.generation;
        if (typed_value.ty.hasCodeGenBits()) {
            // We don't fully codegen the decl until later, but we do need to reserve a global
            // offset table index for it. This allows us to codegen decls out of dependency order,
            // increasing how many computations can be done in parallel.
            try self.bin_file.allocateDeclIndexes(new_decl);
            try self.work_queue.writeItem(.{ .codegen_decl = new_decl });
        }
        return new_decl;
    }
}

/// Declares a dependency on the decl.
fn resolveCompleteDecl(self: *Module, scope: *Scope, old_inst: *zir.Inst) InnerError!*Decl {
    const decl = try self.resolveDecl(scope, old_inst);
    switch (decl.analysis) {
        .in_progress => unreachable,
        .outdated => unreachable,

        .dependency_failure,
        .sema_failure,
        .codegen_failure,
        .codegen_failure_retryable,
        => return error.AnalysisFail,

        .complete => {},
    }
    if (scope.decl()) |scope_decl| {
        try self.declareDeclDependency(scope_decl, decl);
    }
    return decl;
}

fn resolveInst(self: *Module, scope: *Scope, old_inst: *zir.Inst) InnerError!*Inst {
    if (scope.cast(Scope.Block)) |block| {
        if (block.func.analysis.in_progress.inst_table.get(old_inst)) |kv| {
            return kv.value;
        }
    }

    const decl = try self.resolveCompleteDecl(scope, old_inst);
    const decl_ref = try self.analyzeDeclRef(scope, old_inst.src, decl);
    return self.analyzeDeref(scope, old_inst.src, decl_ref, old_inst.src);
}

fn requireRuntimeBlock(self: *Module, scope: *Scope, src: usize) !*Scope.Block {
    return scope.cast(Scope.Block) orelse
        return self.fail(scope, src, "instruction illegal outside function body", .{});
}

fn resolveInstConst(self: *Module, scope: *Scope, old_inst: *zir.Inst) InnerError!TypedValue {
    const new_inst = try self.resolveInst(scope, old_inst);
    const val = try self.resolveConstValue(scope, new_inst);
    return TypedValue{
        .ty = new_inst.ty,
        .val = val,
    };
}

fn resolveConstValue(self: *Module, scope: *Scope, base: *Inst) !Value {
    return (try self.resolveDefinedValue(scope, base)) orelse
        return self.fail(scope, base.src, "unable to resolve comptime value", .{});
}

fn resolveDefinedValue(self: *Module, scope: *Scope, base: *Inst) !?Value {
    if (base.value()) |val| {
        if (val.isUndef()) {
            return self.fail(scope, base.src, "use of undefined value here causes undefined behavior", .{});
        }
        return val;
    }
    return null;
}

fn resolveConstString(self: *Module, scope: *Scope, old_inst: *zir.Inst) ![]u8 {
    const new_inst = try self.resolveInst(scope, old_inst);
    const wanted_type = Type.initTag(.const_slice_u8);
    const coerced_inst = try self.coerce(scope, wanted_type, new_inst);
    const val = try self.resolveConstValue(scope, coerced_inst);
    return val.toAllocatedBytes(scope.arena());
}

fn resolveType(self: *Module, scope: *Scope, old_inst: *zir.Inst) !Type {
    const new_inst = try self.resolveInst(scope, old_inst);
    const wanted_type = Type.initTag(.@"type");
    const coerced_inst = try self.coerce(scope, wanted_type, new_inst);
    const val = try self.resolveConstValue(scope, coerced_inst);
    return val.toType();
}

fn analyzeExport(self: *Module, scope: *Scope, export_inst: *zir.Inst.Export) InnerError!void {
    try self.decl_exports.ensureCapacity(self.decl_exports.size + 1);
    try self.export_owners.ensureCapacity(self.export_owners.size + 1);
    const symbol_name = try self.resolveConstString(scope, export_inst.positionals.symbol_name);
    const exported_decl = try self.resolveCompleteDecl(scope, export_inst.positionals.value);
    const typed_value = exported_decl.typed_value.most_recent.typed_value;
    switch (typed_value.ty.zigTypeTag()) {
        .Fn => {},
        else => return self.fail(
            scope,
            export_inst.positionals.value.src,
            "unable to export type '{}'",
            .{typed_value.ty},
        ),
    }
    const new_export = try self.allocator.create(Export);
    errdefer self.allocator.destroy(new_export);

    const owner_decl = scope.decl().?;

    new_export.* = .{
        .options = .{ .name = symbol_name },
        .src = export_inst.base.src,
        .link = .{},
        .owner_decl = owner_decl,
        .exported_decl = exported_decl,
        .status = .in_progress,
    };

    // Add to export_owners table.
    const eo_gop = self.export_owners.getOrPut(owner_decl) catch unreachable;
    if (!eo_gop.found_existing) {
        eo_gop.kv.value = &[0]*Export{};
    }
    eo_gop.kv.value = try self.allocator.realloc(eo_gop.kv.value, eo_gop.kv.value.len + 1);
    eo_gop.kv.value[eo_gop.kv.value.len - 1] = new_export;
    errdefer eo_gop.kv.value = self.allocator.shrink(eo_gop.kv.value, eo_gop.kv.value.len - 1);

    // Add to exported_decl table.
    const de_gop = self.decl_exports.getOrPut(exported_decl) catch unreachable;
    if (!de_gop.found_existing) {
        de_gop.kv.value = &[0]*Export{};
    }
    de_gop.kv.value = try self.allocator.realloc(de_gop.kv.value, de_gop.kv.value.len + 1);
    de_gop.kv.value[de_gop.kv.value.len - 1] = new_export;
    errdefer de_gop.kv.value = self.allocator.shrink(de_gop.kv.value, de_gop.kv.value.len - 1);

    self.bin_file.updateDeclExports(self, exported_decl, de_gop.kv.value) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        else => {
            try self.failed_exports.ensureCapacity(self.failed_exports.size + 1);
            self.failed_exports.putAssumeCapacityNoClobber(new_export, try ErrorMsg.create(
                self.allocator,
                export_inst.base.src,
                "unable to export: {}",
                .{@errorName(err)},
            ));
            new_export.status = .failed_retryable;
        },
    };
}

/// TODO should not need the cast on the last parameter at the callsites
fn addNewInstArgs(
    self: *Module,
    block: *Scope.Block,
    src: usize,
    ty: Type,
    comptime T: type,
    args: Inst.Args(T),
) !*Inst {
    const inst = try self.addNewInst(block, src, ty, T);
    inst.args = args;
    return &inst.base;
}

fn addNewInst(self: *Module, block: *Scope.Block, src: usize, ty: Type, comptime T: type) !*T {
    const inst = try block.arena.create(T);
    inst.* = .{
        .base = .{
            .tag = T.base_tag,
            .ty = ty,
            .src = src,
        },
        .args = undefined,
    };
    try block.instructions.append(self.allocator, &inst.base);
    return inst;
}

fn constInst(self: *Module, scope: *Scope, src: usize, typed_value: TypedValue) !*Inst {
    const const_inst = try scope.arena().create(Inst.Constant);
    const_inst.* = .{
        .base = .{
            .tag = Inst.Constant.base_tag,
            .ty = typed_value.ty,
            .src = src,
        },
        .val = typed_value.val,
    };
    return &const_inst.base;
}

fn constStr(self: *Module, scope: *Scope, src: usize, str: []const u8) !*Inst {
    const ty_payload = try scope.arena().create(Type.Payload.Array_u8_Sentinel0);
    ty_payload.* = .{ .len = str.len };

    const bytes_payload = try scope.arena().create(Value.Payload.Bytes);
    bytes_payload.* = .{ .data = str };

    return self.constInst(scope, src, .{
        .ty = Type.initPayload(&ty_payload.base),
        .val = Value.initPayload(&bytes_payload.base),
    });
}

fn constType(self: *Module, scope: *Scope, src: usize, ty: Type) !*Inst {
    return self.constInst(scope, src, .{
        .ty = Type.initTag(.type),
        .val = try ty.toValue(scope.arena()),
    });
}

fn constVoid(self: *Module, scope: *Scope, src: usize) !*Inst {
    return self.constInst(scope, src, .{
        .ty = Type.initTag(.void),
        .val = Value.initTag(.the_one_possible_value),
    });
}

fn constUndef(self: *Module, scope: *Scope, src: usize, ty: Type) !*Inst {
    return self.constInst(scope, src, .{
        .ty = ty,
        .val = Value.initTag(.undef),
    });
}

fn constBool(self: *Module, scope: *Scope, src: usize, v: bool) !*Inst {
    return self.constInst(scope, src, .{
        .ty = Type.initTag(.bool),
        .val = ([2]Value{ Value.initTag(.bool_false), Value.initTag(.bool_true) })[@boolToInt(v)],
    });
}

fn constIntUnsigned(self: *Module, scope: *Scope, src: usize, ty: Type, int: u64) !*Inst {
    const int_payload = try scope.arena().create(Value.Payload.Int_u64);
    int_payload.* = .{ .int = int };

    return self.constInst(scope, src, .{
        .ty = ty,
        .val = Value.initPayload(&int_payload.base),
    });
}

fn constIntSigned(self: *Module, scope: *Scope, src: usize, ty: Type, int: i64) !*Inst {
    const int_payload = try scope.arena().create(Value.Payload.Int_i64);
    int_payload.* = .{ .int = int };

    return self.constInst(scope, src, .{
        .ty = ty,
        .val = Value.initPayload(&int_payload.base),
    });
}

fn constIntBig(self: *Module, scope: *Scope, src: usize, ty: Type, big_int: BigIntConst) !*Inst {
    const val_payload = if (big_int.positive) blk: {
        if (big_int.to(u64)) |x| {
            return self.constIntUnsigned(scope, src, ty, x);
        } else |err| switch (err) {
            error.NegativeIntoUnsigned => unreachable,
            error.TargetTooSmall => {}, // handled below
        }
        const big_int_payload = try scope.arena().create(Value.Payload.IntBigPositive);
        big_int_payload.* = .{ .limbs = big_int.limbs };
        break :blk &big_int_payload.base;
    } else blk: {
        if (big_int.to(i64)) |x| {
            return self.constIntSigned(scope, src, ty, x);
        } else |err| switch (err) {
            error.NegativeIntoUnsigned => unreachable,
            error.TargetTooSmall => {}, // handled below
        }
        const big_int_payload = try scope.arena().create(Value.Payload.IntBigNegative);
        big_int_payload.* = .{ .limbs = big_int.limbs };
        break :blk &big_int_payload.base;
    };

    return self.constInst(scope, src, .{
        .ty = ty,
        .val = Value.initPayload(val_payload),
    });
}

fn analyzeInstConst(self: *Module, scope: *Scope, old_inst: *zir.Inst) InnerError!TypedValue {
    const new_inst = try self.analyzeInst(scope, old_inst);
    return TypedValue{
        .ty = new_inst.ty,
        .val = try self.resolveConstValue(scope, new_inst),
    };
}

fn analyzeInst(self: *Module, scope: *Scope, old_inst: *zir.Inst) InnerError!*Inst {
    switch (old_inst.tag) {
        .breakpoint => return self.analyzeInstBreakpoint(scope, old_inst.cast(zir.Inst.Breakpoint).?),
        .call => return self.analyzeInstCall(scope, old_inst.cast(zir.Inst.Call).?),
        .compileerror => return self.analyzeInstCompileError(scope, old_inst.cast(zir.Inst.CompileError).?),
        .declref => return self.analyzeInstDeclRef(scope, old_inst.cast(zir.Inst.DeclRef).?),
        .declval => return self.analyzeInstDeclVal(scope, old_inst.cast(zir.Inst.DeclVal).?),
        .str => {
            const bytes = old_inst.cast(zir.Inst.Str).?.positionals.bytes;
            // The bytes references memory inside the ZIR module, which can get deallocated
            // after semantic analysis is complete. We need the memory to be in the Decl's arena.
            const arena_bytes = try scope.arena().dupe(u8, bytes);
            return self.constStr(scope, old_inst.src, arena_bytes);
        },
        .int => {
            const big_int = old_inst.cast(zir.Inst.Int).?.positionals.int;
            return self.constIntBig(scope, old_inst.src, Type.initTag(.comptime_int), big_int);
        },
        .ptrtoint => return self.analyzeInstPtrToInt(scope, old_inst.cast(zir.Inst.PtrToInt).?),
        .fieldptr => return self.analyzeInstFieldPtr(scope, old_inst.cast(zir.Inst.FieldPtr).?),
        .deref => return self.analyzeInstDeref(scope, old_inst.cast(zir.Inst.Deref).?),
        .as => return self.analyzeInstAs(scope, old_inst.cast(zir.Inst.As).?),
        .@"asm" => return self.analyzeInstAsm(scope, old_inst.cast(zir.Inst.Asm).?),
        .@"unreachable" => return self.analyzeInstUnreachable(scope, old_inst.cast(zir.Inst.Unreachable).?),
        .@"return" => return self.analyzeInstRet(scope, old_inst.cast(zir.Inst.Return).?),
        .@"fn" => return self.analyzeInstFn(scope, old_inst.cast(zir.Inst.Fn).?),
        .@"export" => {
            try self.analyzeExport(scope, old_inst.cast(zir.Inst.Export).?);
            return self.constVoid(scope, old_inst.src);
        },
        .primitive => return self.analyzeInstPrimitive(scope, old_inst.cast(zir.Inst.Primitive).?),
        .ref => return self.analyzeInstRef(scope, old_inst.cast(zir.Inst.Ref).?),
        .fntype => return self.analyzeInstFnType(scope, old_inst.cast(zir.Inst.FnType).?),
        .intcast => return self.analyzeInstIntCast(scope, old_inst.cast(zir.Inst.IntCast).?),
        .bitcast => return self.analyzeInstBitCast(scope, old_inst.cast(zir.Inst.BitCast).?),
        .elemptr => return self.analyzeInstElemPtr(scope, old_inst.cast(zir.Inst.ElemPtr).?),
        .add => return self.analyzeInstAdd(scope, old_inst.cast(zir.Inst.Add).?),
        .cmp => return self.analyzeInstCmp(scope, old_inst.cast(zir.Inst.Cmp).?),
        .condbr => return self.analyzeInstCondBr(scope, old_inst.cast(zir.Inst.CondBr).?),
        .isnull => return self.analyzeInstIsNull(scope, old_inst.cast(zir.Inst.IsNull).?),
        .isnonnull => return self.analyzeInstIsNonNull(scope, old_inst.cast(zir.Inst.IsNonNull).?),
    }
}

fn analyzeInstCompileError(self: *Module, scope: *Scope, inst: *zir.Inst.CompileError) InnerError!*Inst {
    return self.fail(scope, inst.base.src, "{}", .{inst.positionals.msg});
}

fn analyzeInstBreakpoint(self: *Module, scope: *Scope, inst: *zir.Inst.Breakpoint) InnerError!*Inst {
    const b = try self.requireRuntimeBlock(scope, inst.base.src);
    return self.addNewInstArgs(b, inst.base.src, Type.initTag(.void), Inst.Breakpoint, Inst.Args(Inst.Breakpoint){});
}

fn analyzeInstRef(self: *Module, scope: *Scope, inst: *zir.Inst.Ref) InnerError!*Inst {
    const decl = try self.resolveCompleteDecl(scope, inst.positionals.operand);
    return self.analyzeDeclRef(scope, inst.base.src, decl);
}

fn analyzeInstDeclRef(self: *Module, scope: *Scope, inst: *zir.Inst.DeclRef) InnerError!*Inst {
    const decl_name = try self.resolveConstString(scope, inst.positionals.name);
    // This will need to get more fleshed out when there are proper structs & namespaces.
    const zir_module = scope.namespace();
    const src_decl = zir_module.contents.module.findDecl(decl_name) orelse
        return self.fail(scope, inst.positionals.name.src, "use of undeclared identifier '{}'", .{decl_name});

    const decl = try self.resolveCompleteDecl(scope, src_decl);
    return self.analyzeDeclRef(scope, inst.base.src, decl);
}

fn analyzeDeclVal(self: *Module, scope: *Scope, inst: *zir.Inst.DeclVal) InnerError!*Decl {
    const decl_name = inst.positionals.name;
    // This will need to get more fleshed out when there are proper structs & namespaces.
    const zir_module = scope.namespace();
    const src_decl = zir_module.contents.module.findDecl(decl_name) orelse
        return self.fail(scope, inst.base.src, "use of undeclared identifier '{}'", .{decl_name});

    const decl = try self.resolveCompleteDecl(scope, src_decl);

    return decl;
}

fn analyzeInstDeclVal(self: *Module, scope: *Scope, inst: *zir.Inst.DeclVal) InnerError!*Inst {
    const decl = try self.analyzeDeclVal(scope, inst);
    const ptr = try self.analyzeDeclRef(scope, inst.base.src, decl);
    return self.analyzeDeref(scope, inst.base.src, ptr, inst.base.src);
}

fn analyzeDeclRef(self: *Module, scope: *Scope, src: usize, decl: *Decl) InnerError!*Inst {
    const decl_tv = try decl.typedValue();
    const ty_payload = try scope.arena().create(Type.Payload.SingleConstPointer);
    ty_payload.* = .{ .pointee_type = decl_tv.ty };
    const val_payload = try scope.arena().create(Value.Payload.DeclRef);
    val_payload.* = .{ .decl = decl };
    return self.constInst(scope, src, .{
        .ty = Type.initPayload(&ty_payload.base),
        .val = Value.initPayload(&val_payload.base),
    });
}

fn analyzeInstCall(self: *Module, scope: *Scope, inst: *zir.Inst.Call) InnerError!*Inst {
    const func = try self.resolveInst(scope, inst.positionals.func);
    if (func.ty.zigTypeTag() != .Fn)
        return self.fail(scope, inst.positionals.func.src, "type '{}' not a function", .{func.ty});

    const cc = func.ty.fnCallingConvention();
    if (cc == .Naked) {
        // TODO add error note: declared here
        return self.fail(
            scope,
            inst.positionals.func.src,
            "unable to call function with naked calling convention",
            .{},
        );
    }
    const call_params_len = inst.positionals.args.len;
    const fn_params_len = func.ty.fnParamLen();
    if (func.ty.fnIsVarArgs()) {
        if (call_params_len < fn_params_len) {
            // TODO add error note: declared here
            return self.fail(
                scope,
                inst.positionals.func.src,
                "expected at least {} arguments, found {}",
                .{ fn_params_len, call_params_len },
            );
        }
        return self.fail(scope, inst.base.src, "TODO implement support for calling var args functions", .{});
    } else if (fn_params_len != call_params_len) {
        // TODO add error note: declared here
        return self.fail(
            scope,
            inst.positionals.func.src,
            "expected {} arguments, found {}",
            .{ fn_params_len, call_params_len },
        );
    }

    if (inst.kw_args.modifier == .compile_time) {
        return self.fail(scope, inst.base.src, "TODO implement comptime function calls", .{});
    }
    if (inst.kw_args.modifier != .auto) {
        return self.fail(scope, inst.base.src, "TODO implement call with modifier {}", .{inst.kw_args.modifier});
    }

    // TODO handle function calls of generic functions

    const fn_param_types = try self.allocator.alloc(Type, fn_params_len);
    defer self.allocator.free(fn_param_types);
    func.ty.fnParamTypes(fn_param_types);

    const casted_args = try scope.arena().alloc(*Inst, fn_params_len);
    for (inst.positionals.args) |src_arg, i| {
        const uncasted_arg = try self.resolveInst(scope, src_arg);
        casted_args[i] = try self.coerce(scope, fn_param_types[i], uncasted_arg);
    }

    const b = try self.requireRuntimeBlock(scope, inst.base.src);
    return self.addNewInstArgs(b, inst.base.src, Type.initTag(.void), Inst.Call, Inst.Args(Inst.Call){
        .func = func,
        .args = casted_args,
    });
}

fn analyzeInstFn(self: *Module, scope: *Scope, fn_inst: *zir.Inst.Fn) InnerError!*Inst {
    const fn_type = try self.resolveType(scope, fn_inst.positionals.fn_type);
    const new_func = try scope.arena().create(Fn);
    new_func.* = .{
        .fn_type = fn_type,
        .analysis = .{ .queued = fn_inst },
        .owner_decl = scope.decl().?,
    };
    const fn_payload = try scope.arena().create(Value.Payload.Function);
    fn_payload.* = .{ .func = new_func };
    return self.constInst(scope, fn_inst.base.src, .{
        .ty = fn_type,
        .val = Value.initPayload(&fn_payload.base),
    });
}

fn analyzeInstFnType(self: *Module, scope: *Scope, fntype: *zir.Inst.FnType) InnerError!*Inst {
    const return_type = try self.resolveType(scope, fntype.positionals.return_type);

    if (return_type.zigTypeTag() == .NoReturn and
        fntype.positionals.param_types.len == 0 and
        fntype.kw_args.cc == .Unspecified)
    {
        return self.constType(scope, fntype.base.src, Type.initTag(.fn_noreturn_no_args));
    }

    if (return_type.zigTypeTag() == .NoReturn and
        fntype.positionals.param_types.len == 0 and
        fntype.kw_args.cc == .Naked)
    {
        return self.constType(scope, fntype.base.src, Type.initTag(.fn_naked_noreturn_no_args));
    }

    if (return_type.zigTypeTag() == .Void and
        fntype.positionals.param_types.len == 0 and
        fntype.kw_args.cc == .C)
    {
        return self.constType(scope, fntype.base.src, Type.initTag(.fn_ccc_void_no_args));
    }

    return self.fail(scope, fntype.base.src, "TODO implement fntype instruction more", .{});
}

fn analyzeInstPrimitive(self: *Module, scope: *Scope, primitive: *zir.Inst.Primitive) InnerError!*Inst {
    return self.constInst(scope, primitive.base.src, primitive.positionals.tag.toTypedValue());
}

fn analyzeInstAs(self: *Module, scope: *Scope, as: *zir.Inst.As) InnerError!*Inst {
    const dest_type = try self.resolveType(scope, as.positionals.dest_type);
    const new_inst = try self.resolveInst(scope, as.positionals.value);
    return self.coerce(scope, dest_type, new_inst);
}

fn analyzeInstPtrToInt(self: *Module, scope: *Scope, ptrtoint: *zir.Inst.PtrToInt) InnerError!*Inst {
    const ptr = try self.resolveInst(scope, ptrtoint.positionals.ptr);
    if (ptr.ty.zigTypeTag() != .Pointer) {
        return self.fail(scope, ptrtoint.positionals.ptr.src, "expected pointer, found '{}'", .{ptr.ty});
    }
    // TODO handle known-pointer-address
    const b = try self.requireRuntimeBlock(scope, ptrtoint.base.src);
    const ty = Type.initTag(.usize);
    return self.addNewInstArgs(b, ptrtoint.base.src, ty, Inst.PtrToInt, Inst.Args(Inst.PtrToInt){ .ptr = ptr });
}

fn analyzeInstFieldPtr(self: *Module, scope: *Scope, fieldptr: *zir.Inst.FieldPtr) InnerError!*Inst {
    const object_ptr = try self.resolveInst(scope, fieldptr.positionals.object_ptr);
    const field_name = try self.resolveConstString(scope, fieldptr.positionals.field_name);

    const elem_ty = switch (object_ptr.ty.zigTypeTag()) {
        .Pointer => object_ptr.ty.elemType(),
        else => return self.fail(scope, fieldptr.positionals.object_ptr.src, "expected pointer, found '{}'", .{object_ptr.ty}),
    };
    switch (elem_ty.zigTypeTag()) {
        .Array => {
            if (mem.eql(u8, field_name, "len")) {
                const len_payload = try scope.arena().create(Value.Payload.Int_u64);
                len_payload.* = .{ .int = elem_ty.arrayLen() };

                const ref_payload = try scope.arena().create(Value.Payload.RefVal);
                ref_payload.* = .{ .val = Value.initPayload(&len_payload.base) };

                return self.constInst(scope, fieldptr.base.src, .{
                    .ty = Type.initTag(.single_const_pointer_to_comptime_int),
                    .val = Value.initPayload(&ref_payload.base),
                });
            } else {
                return self.fail(
                    scope,
                    fieldptr.positionals.field_name.src,
                    "no member named '{}' in '{}'",
                    .{ field_name, elem_ty },
                );
            }
        },
        else => return self.fail(scope, fieldptr.base.src, "type '{}' does not support field access", .{elem_ty}),
    }
}

fn analyzeInstIntCast(self: *Module, scope: *Scope, intcast: *zir.Inst.IntCast) InnerError!*Inst {
    const dest_type = try self.resolveType(scope, intcast.positionals.dest_type);
    const new_inst = try self.resolveInst(scope, intcast.positionals.value);

    const dest_is_comptime_int = switch (dest_type.zigTypeTag()) {
        .ComptimeInt => true,
        .Int => false,
        else => return self.fail(
            scope,
            intcast.positionals.dest_type.src,
            "expected integer type, found '{}'",
            .{
                dest_type,
            },
        ),
    };

    switch (new_inst.ty.zigTypeTag()) {
        .ComptimeInt, .Int => {},
        else => return self.fail(
            scope,
            intcast.positionals.value.src,
            "expected integer type, found '{}'",
            .{new_inst.ty},
        ),
    }

    if (dest_is_comptime_int or new_inst.value() != null) {
        return self.coerce(scope, dest_type, new_inst);
    }

    return self.fail(scope, intcast.base.src, "TODO implement analyze widen or shorten int", .{});
}

fn analyzeInstBitCast(self: *Module, scope: *Scope, inst: *zir.Inst.BitCast) InnerError!*Inst {
    const dest_type = try self.resolveType(scope, inst.positionals.dest_type);
    const operand = try self.resolveInst(scope, inst.positionals.operand);
    return self.bitcast(scope, dest_type, operand);
}

fn analyzeInstElemPtr(self: *Module, scope: *Scope, inst: *zir.Inst.ElemPtr) InnerError!*Inst {
    const array_ptr = try self.resolveInst(scope, inst.positionals.array_ptr);
    const uncasted_index = try self.resolveInst(scope, inst.positionals.index);
    const elem_index = try self.coerce(scope, Type.initTag(.usize), uncasted_index);

    if (array_ptr.ty.isSinglePointer() and array_ptr.ty.elemType().zigTypeTag() == .Array) {
        if (array_ptr.value()) |array_ptr_val| {
            if (elem_index.value()) |index_val| {
                // Both array pointer and index are compile-time known.
                const index_u64 = index_val.toUnsignedInt();
                // @intCast here because it would have been impossible to construct a value that
                // required a larger index.
                const elem_ptr = try array_ptr_val.elemPtr(scope.arena(), @intCast(usize, index_u64));

                const type_payload = try scope.arena().create(Type.Payload.SingleConstPointer);
                type_payload.* = .{ .pointee_type = array_ptr.ty.elemType().elemType() };

                return self.constInst(scope, inst.base.src, .{
                    .ty = Type.initPayload(&type_payload.base),
                    .val = elem_ptr,
                });
            }
        }
    }

    return self.fail(scope, inst.base.src, "TODO implement more analyze elemptr", .{});
}

fn analyzeInstAdd(self: *Module, scope: *Scope, inst: *zir.Inst.Add) InnerError!*Inst {
    const lhs = try self.resolveInst(scope, inst.positionals.lhs);
    const rhs = try self.resolveInst(scope, inst.positionals.rhs);

    if (lhs.ty.zigTypeTag() == .Int and rhs.ty.zigTypeTag() == .Int) {
        if (lhs.value()) |lhs_val| {
            if (rhs.value()) |rhs_val| {
                // TODO is this a performance issue? maybe we should try the operation without
                // resorting to BigInt first.
                var lhs_space: Value.BigIntSpace = undefined;
                var rhs_space: Value.BigIntSpace = undefined;
                const lhs_bigint = lhs_val.toBigInt(&lhs_space);
                const rhs_bigint = rhs_val.toBigInt(&rhs_space);
                const limbs = try scope.arena().alloc(
                    std.math.big.Limb,
                    std.math.max(lhs_bigint.limbs.len, rhs_bigint.limbs.len) + 1,
                );
                var result_bigint = BigIntMutable{ .limbs = limbs, .positive = undefined, .len = undefined };
                result_bigint.add(lhs_bigint, rhs_bigint);
                const result_limbs = result_bigint.limbs[0..result_bigint.len];

                if (!lhs.ty.eql(rhs.ty)) {
                    return self.fail(scope, inst.base.src, "TODO implement peer type resolution", .{});
                }

                const val_payload = if (result_bigint.positive) blk: {
                    const val_payload = try scope.arena().create(Value.Payload.IntBigPositive);
                    val_payload.* = .{ .limbs = result_limbs };
                    break :blk &val_payload.base;
                } else blk: {
                    const val_payload = try scope.arena().create(Value.Payload.IntBigNegative);
                    val_payload.* = .{ .limbs = result_limbs };
                    break :blk &val_payload.base;
                };

                return self.constInst(scope, inst.base.src, .{
                    .ty = lhs.ty,
                    .val = Value.initPayload(val_payload),
                });
            }
        }
    }

    return self.fail(scope, inst.base.src, "TODO implement more analyze add", .{});
}

fn analyzeInstDeref(self: *Module, scope: *Scope, deref: *zir.Inst.Deref) InnerError!*Inst {
    const ptr = try self.resolveInst(scope, deref.positionals.ptr);
    return self.analyzeDeref(scope, deref.base.src, ptr, deref.positionals.ptr.src);
}

fn analyzeDeref(self: *Module, scope: *Scope, src: usize, ptr: *Inst, ptr_src: usize) InnerError!*Inst {
    const elem_ty = switch (ptr.ty.zigTypeTag()) {
        .Pointer => ptr.ty.elemType(),
        else => return self.fail(scope, ptr_src, "expected pointer, found '{}'", .{ptr.ty}),
    };
    if (ptr.value()) |val| {
        return self.constInst(scope, src, .{
            .ty = elem_ty,
            .val = try val.pointerDeref(scope.arena()),
        });
    }

    return self.fail(scope, src, "TODO implement runtime deref", .{});
}

fn analyzeInstAsm(self: *Module, scope: *Scope, assembly: *zir.Inst.Asm) InnerError!*Inst {
    const return_type = try self.resolveType(scope, assembly.positionals.return_type);
    const asm_source = try self.resolveConstString(scope, assembly.positionals.asm_source);
    const output = if (assembly.kw_args.output) |o| try self.resolveConstString(scope, o) else null;

    const inputs = try scope.arena().alloc([]const u8, assembly.kw_args.inputs.len);
    const clobbers = try scope.arena().alloc([]const u8, assembly.kw_args.clobbers.len);
    const args = try scope.arena().alloc(*Inst, assembly.kw_args.args.len);

    for (inputs) |*elem, i| {
        elem.* = try self.resolveConstString(scope, assembly.kw_args.inputs[i]);
    }
    for (clobbers) |*elem, i| {
        elem.* = try self.resolveConstString(scope, assembly.kw_args.clobbers[i]);
    }
    for (args) |*elem, i| {
        const arg = try self.resolveInst(scope, assembly.kw_args.args[i]);
        elem.* = try self.coerce(scope, Type.initTag(.usize), arg);
    }

    const b = try self.requireRuntimeBlock(scope, assembly.base.src);
    return self.addNewInstArgs(b, assembly.base.src, return_type, Inst.Assembly, Inst.Args(Inst.Assembly){
        .asm_source = asm_source,
        .is_volatile = assembly.kw_args.@"volatile",
        .output = output,
        .inputs = inputs,
        .clobbers = clobbers,
        .args = args,
    });
}

fn analyzeInstCmp(self: *Module, scope: *Scope, inst: *zir.Inst.Cmp) InnerError!*Inst {
    const lhs = try self.resolveInst(scope, inst.positionals.lhs);
    const rhs = try self.resolveInst(scope, inst.positionals.rhs);
    const op = inst.positionals.op;

    const is_equality_cmp = switch (op) {
        .eq, .neq => true,
        else => false,
    };
    const lhs_ty_tag = lhs.ty.zigTypeTag();
    const rhs_ty_tag = rhs.ty.zigTypeTag();
    if (is_equality_cmp and lhs_ty_tag == .Null and rhs_ty_tag == .Null) {
        // null == null, null != null
        return self.constBool(scope, inst.base.src, op == .eq);
    } else if (is_equality_cmp and
        ((lhs_ty_tag == .Null and rhs_ty_tag == .Optional) or
        rhs_ty_tag == .Null and lhs_ty_tag == .Optional))
    {
        // comparing null with optionals
        const opt_operand = if (lhs_ty_tag == .Optional) lhs else rhs;
        if (opt_operand.value()) |opt_val| {
            const is_null = opt_val.isNull();
            return self.constBool(scope, inst.base.src, if (op == .eq) is_null else !is_null);
        }
        const b = try self.requireRuntimeBlock(scope, inst.base.src);
        switch (op) {
            .eq => return self.addNewInstArgs(
                b,
                inst.base.src,
                Type.initTag(.bool),
                Inst.IsNull,
                Inst.Args(Inst.IsNull){ .operand = opt_operand },
            ),
            .neq => return self.addNewInstArgs(
                b,
                inst.base.src,
                Type.initTag(.bool),
                Inst.IsNonNull,
                Inst.Args(Inst.IsNonNull){ .operand = opt_operand },
            ),
            else => unreachable,
        }
    } else if (is_equality_cmp and
        ((lhs_ty_tag == .Null and rhs.ty.isCPtr()) or (rhs_ty_tag == .Null and lhs.ty.isCPtr())))
    {
        return self.fail(scope, inst.base.src, "TODO implement C pointer cmp", .{});
    } else if (lhs_ty_tag == .Null or rhs_ty_tag == .Null) {
        const non_null_type = if (lhs_ty_tag == .Null) rhs.ty else lhs.ty;
        return self.fail(scope, inst.base.src, "comparison of '{}' with null", .{non_null_type});
    } else if (is_equality_cmp and
        ((lhs_ty_tag == .EnumLiteral and rhs_ty_tag == .Union) or
        (rhs_ty_tag == .EnumLiteral and lhs_ty_tag == .Union)))
    {
        return self.fail(scope, inst.base.src, "TODO implement equality comparison between a union's tag value and an enum literal", .{});
    } else if (lhs_ty_tag == .ErrorSet and rhs_ty_tag == .ErrorSet) {
        if (!is_equality_cmp) {
            return self.fail(scope, inst.base.src, "{} operator not allowed for errors", .{@tagName(op)});
        }
        return self.fail(scope, inst.base.src, "TODO implement equality comparison between errors", .{});
    } else if (lhs.ty.isNumeric() and rhs.ty.isNumeric()) {
        // This operation allows any combination of integer and float types, regardless of the
        // signed-ness, comptime-ness, and bit-width. So peer type resolution is incorrect for
        // numeric types.
        return self.cmpNumeric(scope, inst.base.src, lhs, rhs, op);
    }
    return self.fail(scope, inst.base.src, "TODO implement more cmp analysis", .{});
}

fn analyzeInstIsNull(self: *Module, scope: *Scope, inst: *zir.Inst.IsNull) InnerError!*Inst {
    const operand = try self.resolveInst(scope, inst.positionals.operand);
    return self.analyzeIsNull(scope, inst.base.src, operand, true);
}

fn analyzeInstIsNonNull(self: *Module, scope: *Scope, inst: *zir.Inst.IsNonNull) InnerError!*Inst {
    const operand = try self.resolveInst(scope, inst.positionals.operand);
    return self.analyzeIsNull(scope, inst.base.src, operand, false);
}

fn analyzeInstCondBr(self: *Module, scope: *Scope, inst: *zir.Inst.CondBr) InnerError!*Inst {
    const uncasted_cond = try self.resolveInst(scope, inst.positionals.condition);
    const cond = try self.coerce(scope, Type.initTag(.bool), uncasted_cond);

    if (try self.resolveDefinedValue(scope, cond)) |cond_val| {
        const body = if (cond_val.toBool()) &inst.positionals.true_body else &inst.positionals.false_body;
        try self.analyzeBody(scope, body.*);
        return self.constVoid(scope, inst.base.src);
    }

    const parent_block = try self.requireRuntimeBlock(scope, inst.base.src);

    var true_block: Scope.Block = .{
        .func = parent_block.func,
        .decl = parent_block.decl,
        .instructions = .{},
        .arena = parent_block.arena,
    };
    defer true_block.instructions.deinit(self.allocator);
    try self.analyzeBody(&true_block.base, inst.positionals.true_body);

    var false_block: Scope.Block = .{
        .func = parent_block.func,
        .decl = parent_block.decl,
        .instructions = .{},
        .arena = parent_block.arena,
    };
    defer false_block.instructions.deinit(self.allocator);
    try self.analyzeBody(&false_block.base, inst.positionals.false_body);

    return self.addNewInstArgs(parent_block, inst.base.src, Type.initTag(.void), Inst.CondBr, Inst.Args(Inst.CondBr){
        .condition = cond,
        .true_body = .{ .instructions = try scope.arena().dupe(*Inst, true_block.instructions.items) },
        .false_body = .{ .instructions = try scope.arena().dupe(*Inst, false_block.instructions.items) },
    });
}

fn wantSafety(self: *Module, scope: *Scope) bool {
    return switch (self.optimize_mode) {
        .Debug => true,
        .ReleaseSafe => true,
        .ReleaseFast => false,
        .ReleaseSmall => false,
    };
}

fn analyzeInstUnreachable(self: *Module, scope: *Scope, unreach: *zir.Inst.Unreachable) InnerError!*Inst {
    const b = try self.requireRuntimeBlock(scope, unreach.base.src);
    if (self.wantSafety(scope)) {
        // TODO Once we have a panic function to call, call it here instead of this.
        _ = try self.addNewInstArgs(b, unreach.base.src, Type.initTag(.void), Inst.Breakpoint, {});
    }
    return self.addNewInstArgs(b, unreach.base.src, Type.initTag(.noreturn), Inst.Unreach, {});
}

fn analyzeInstRet(self: *Module, scope: *Scope, inst: *zir.Inst.Return) InnerError!*Inst {
    const b = try self.requireRuntimeBlock(scope, inst.base.src);
    return self.addNewInstArgs(b, inst.base.src, Type.initTag(.noreturn), Inst.Ret, {});
}

fn analyzeBody(self: *Module, scope: *Scope, body: zir.Module.Body) !void {
    if (scope.cast(Scope.Block)) |b| {
        const analysis = b.func.analysis.in_progress;
        analysis.needed_inst_capacity += body.instructions.len;
        try analysis.inst_table.ensureCapacity(analysis.needed_inst_capacity);
        for (body.instructions) |src_inst| {
            const new_inst = try self.analyzeInst(scope, src_inst);
            analysis.inst_table.putAssumeCapacityNoClobber(src_inst, new_inst);
        }
    } else {
        for (body.instructions) |src_inst| {
            _ = try self.analyzeInst(scope, src_inst);
        }
    }
}

fn analyzeIsNull(
    self: *Module,
    scope: *Scope,
    src: usize,
    operand: *Inst,
    invert_logic: bool,
) InnerError!*Inst {
    return self.fail(scope, src, "TODO implement analysis of isnull and isnotnull", .{});
}

/// Asserts that lhs and rhs types are both numeric.
fn cmpNumeric(
    self: *Module,
    scope: *Scope,
    src: usize,
    lhs: *Inst,
    rhs: *Inst,
    op: std.math.CompareOperator,
) !*Inst {
    assert(lhs.ty.isNumeric());
    assert(rhs.ty.isNumeric());

    const lhs_ty_tag = lhs.ty.zigTypeTag();
    const rhs_ty_tag = rhs.ty.zigTypeTag();

    if (lhs_ty_tag == .Vector and rhs_ty_tag == .Vector) {
        if (lhs.ty.arrayLen() != rhs.ty.arrayLen()) {
            return self.fail(scope, src, "vector length mismatch: {} and {}", .{
                lhs.ty.arrayLen(),
                rhs.ty.arrayLen(),
            });
        }
        return self.fail(scope, src, "TODO implement support for vectors in cmpNumeric", .{});
    } else if (lhs_ty_tag == .Vector or rhs_ty_tag == .Vector) {
        return self.fail(scope, src, "mixed scalar and vector operands to comparison operator: '{}' and '{}'", .{
            lhs.ty,
            rhs.ty,
        });
    }

    if (lhs.value()) |lhs_val| {
        if (rhs.value()) |rhs_val| {
            return self.constBool(scope, src, Value.compare(lhs_val, op, rhs_val));
        }
    }

    // TODO handle comparisons against lazy zero values
    // Some values can be compared against zero without being runtime known or without forcing
    // a full resolution of their value, for example `@sizeOf(@Frame(function))` is known to
    // always be nonzero, and we benefit from not forcing the full evaluation and stack frame layout
    // of this function if we don't need to.

    // It must be a runtime comparison.
    const b = try self.requireRuntimeBlock(scope, src);
    // For floats, emit a float comparison instruction.
    const lhs_is_float = switch (lhs_ty_tag) {
        .Float, .ComptimeFloat => true,
        else => false,
    };
    const rhs_is_float = switch (rhs_ty_tag) {
        .Float, .ComptimeFloat => true,
        else => false,
    };
    if (lhs_is_float and rhs_is_float) {
        // Implicit cast the smaller one to the larger one.
        const dest_type = x: {
            if (lhs_ty_tag == .ComptimeFloat) {
                break :x rhs.ty;
            } else if (rhs_ty_tag == .ComptimeFloat) {
                break :x lhs.ty;
            }
            if (lhs.ty.floatBits(self.target()) >= rhs.ty.floatBits(self.target())) {
                break :x lhs.ty;
            } else {
                break :x rhs.ty;
            }
        };
        const casted_lhs = try self.coerce(scope, dest_type, lhs);
        const casted_rhs = try self.coerce(scope, dest_type, rhs);
        return self.addNewInstArgs(b, src, dest_type, Inst.Cmp, Inst.Args(Inst.Cmp){
            .lhs = casted_lhs,
            .rhs = casted_rhs,
            .op = op,
        });
    }
    // For mixed unsigned integer sizes, implicit cast both operands to the larger integer.
    // For mixed signed and unsigned integers, implicit cast both operands to a signed
    // integer with + 1 bit.
    // For mixed floats and integers, extract the integer part from the float, cast that to
    // a signed integer with mantissa bits + 1, and if there was any non-integral part of the float,
    // add/subtract 1.
    const lhs_is_signed = if (lhs.value()) |lhs_val|
        lhs_val.compareWithZero(.lt)
    else
        (lhs.ty.isFloat() or lhs.ty.isSignedInt());
    const rhs_is_signed = if (rhs.value()) |rhs_val|
        rhs_val.compareWithZero(.lt)
    else
        (rhs.ty.isFloat() or rhs.ty.isSignedInt());
    const dest_int_is_signed = lhs_is_signed or rhs_is_signed;

    var dest_float_type: ?Type = null;

    var lhs_bits: usize = undefined;
    if (lhs.value()) |lhs_val| {
        if (lhs_val.isUndef())
            return self.constUndef(scope, src, Type.initTag(.bool));
        const is_unsigned = if (lhs_is_float) x: {
            var bigint_space: Value.BigIntSpace = undefined;
            var bigint = try lhs_val.toBigInt(&bigint_space).toManaged(self.allocator);
            defer bigint.deinit();
            const zcmp = lhs_val.orderAgainstZero();
            if (lhs_val.floatHasFraction()) {
                switch (op) {
                    .eq => return self.constBool(scope, src, false),
                    .neq => return self.constBool(scope, src, true),
                    else => {},
                }
                if (zcmp == .lt) {
                    try bigint.addScalar(bigint.toConst(), -1);
                } else {
                    try bigint.addScalar(bigint.toConst(), 1);
                }
            }
            lhs_bits = bigint.toConst().bitCountTwosComp();
            break :x (zcmp != .lt);
        } else x: {
            lhs_bits = lhs_val.intBitCountTwosComp();
            break :x (lhs_val.orderAgainstZero() != .lt);
        };
        lhs_bits += @boolToInt(is_unsigned and dest_int_is_signed);
    } else if (lhs_is_float) {
        dest_float_type = lhs.ty;
    } else {
        const int_info = lhs.ty.intInfo(self.target());
        lhs_bits = int_info.bits + @boolToInt(!int_info.signed and dest_int_is_signed);
    }

    var rhs_bits: usize = undefined;
    if (rhs.value()) |rhs_val| {
        if (rhs_val.isUndef())
            return self.constUndef(scope, src, Type.initTag(.bool));
        const is_unsigned = if (rhs_is_float) x: {
            var bigint_space: Value.BigIntSpace = undefined;
            var bigint = try rhs_val.toBigInt(&bigint_space).toManaged(self.allocator);
            defer bigint.deinit();
            const zcmp = rhs_val.orderAgainstZero();
            if (rhs_val.floatHasFraction()) {
                switch (op) {
                    .eq => return self.constBool(scope, src, false),
                    .neq => return self.constBool(scope, src, true),
                    else => {},
                }
                if (zcmp == .lt) {
                    try bigint.addScalar(bigint.toConst(), -1);
                } else {
                    try bigint.addScalar(bigint.toConst(), 1);
                }
            }
            rhs_bits = bigint.toConst().bitCountTwosComp();
            break :x (zcmp != .lt);
        } else x: {
            rhs_bits = rhs_val.intBitCountTwosComp();
            break :x (rhs_val.orderAgainstZero() != .lt);
        };
        rhs_bits += @boolToInt(is_unsigned and dest_int_is_signed);
    } else if (rhs_is_float) {
        dest_float_type = rhs.ty;
    } else {
        const int_info = rhs.ty.intInfo(self.target());
        rhs_bits = int_info.bits + @boolToInt(!int_info.signed and dest_int_is_signed);
    }

    const dest_type = if (dest_float_type) |ft| ft else blk: {
        const max_bits = std.math.max(lhs_bits, rhs_bits);
        const casted_bits = std.math.cast(u16, max_bits) catch |err| switch (err) {
            error.Overflow => return self.fail(scope, src, "{} exceeds maximum integer bit count", .{max_bits}),
        };
        break :blk try self.makeIntType(scope, dest_int_is_signed, casted_bits);
    };
    const casted_lhs = try self.coerce(scope, dest_type, lhs);
    const casted_rhs = try self.coerce(scope, dest_type, lhs);

    return self.addNewInstArgs(b, src, dest_type, Inst.Cmp, Inst.Args(Inst.Cmp){
        .lhs = casted_lhs,
        .rhs = casted_rhs,
        .op = op,
    });
}

fn makeIntType(self: *Module, scope: *Scope, signed: bool, bits: u16) !Type {
    if (signed) {
        const int_payload = try scope.arena().create(Type.Payload.IntSigned);
        int_payload.* = .{ .bits = bits };
        return Type.initPayload(&int_payload.base);
    } else {
        const int_payload = try scope.arena().create(Type.Payload.IntUnsigned);
        int_payload.* = .{ .bits = bits };
        return Type.initPayload(&int_payload.base);
    }
}

fn coerce(self: *Module, scope: *Scope, dest_type: Type, inst: *Inst) !*Inst {
    // If the types are the same, we can return the operand.
    if (dest_type.eql(inst.ty))
        return inst;

    const in_memory_result = coerceInMemoryAllowed(dest_type, inst.ty);
    if (in_memory_result == .ok) {
        return self.bitcast(scope, dest_type, inst);
    }

    // *[N]T to []T
    if (inst.ty.isSinglePointer() and dest_type.isSlice() and
        (!inst.ty.pointerIsConst() or dest_type.pointerIsConst()))
    {
        const array_type = inst.ty.elemType();
        const dst_elem_type = dest_type.elemType();
        if (array_type.zigTypeTag() == .Array and
            coerceInMemoryAllowed(dst_elem_type, array_type.elemType()) == .ok)
        {
            return self.coerceArrayPtrToSlice(scope, dest_type, inst);
        }
    }

    // comptime_int to fixed-width integer
    if (inst.ty.zigTypeTag() == .ComptimeInt and dest_type.zigTypeTag() == .Int) {
        // The representation is already correct; we only need to make sure it fits in the destination type.
        const val = inst.value().?; // comptime_int always has comptime known value
        if (!val.intFitsInType(dest_type, self.target())) {
            return self.fail(scope, inst.src, "type {} cannot represent integer value {}", .{ inst.ty, val });
        }
        return self.constInst(scope, inst.src, .{ .ty = dest_type, .val = val });
    }

    // integer widening
    if (inst.ty.zigTypeTag() == .Int and dest_type.zigTypeTag() == .Int) {
        const src_info = inst.ty.intInfo(self.target());
        const dst_info = dest_type.intInfo(self.target());
        if (src_info.signed == dst_info.signed and dst_info.bits >= src_info.bits) {
            if (inst.value()) |val| {
                return self.constInst(scope, inst.src, .{ .ty = dest_type, .val = val });
            } else {
                return self.fail(scope, inst.src, "TODO implement runtime integer widening", .{});
            }
        } else {
            return self.fail(scope, inst.src, "TODO implement more int widening {} to {}", .{ inst.ty, dest_type });
        }
    }

    return self.fail(scope, inst.src, "TODO implement type coercion from {} to {}", .{ inst.ty, dest_type });
}

fn bitcast(self: *Module, scope: *Scope, dest_type: Type, inst: *Inst) !*Inst {
    if (inst.value()) |val| {
        // Keep the comptime Value representation; take the new type.
        return self.constInst(scope, inst.src, .{ .ty = dest_type, .val = val });
    }
    // TODO validate the type size and other compile errors
    const b = try self.requireRuntimeBlock(scope, inst.src);
    return self.addNewInstArgs(b, inst.src, dest_type, Inst.BitCast, Inst.Args(Inst.BitCast){ .operand = inst });
}

fn coerceArrayPtrToSlice(self: *Module, scope: *Scope, dest_type: Type, inst: *Inst) !*Inst {
    if (inst.value()) |val| {
        // The comptime Value representation is compatible with both types.
        return self.constInst(scope, inst.src, .{ .ty = dest_type, .val = val });
    }
    return self.fail(scope, inst.src, "TODO implement coerceArrayPtrToSlice runtime instruction", .{});
}

fn fail(self: *Module, scope: *Scope, src: usize, comptime format: []const u8, args: var) InnerError {
    @setCold(true);
    const err_msg = try ErrorMsg.create(self.allocator, src, format, args);
    return self.failWithOwnedErrorMsg(scope, src, err_msg);
}

fn failWithOwnedErrorMsg(self: *Module, scope: *Scope, src: usize, err_msg: *ErrorMsg) InnerError {
    {
        errdefer err_msg.destroy(self.allocator);
        try self.failed_decls.ensureCapacity(self.failed_decls.size + 1);
        try self.failed_files.ensureCapacity(self.failed_files.size + 1);
    }
    switch (scope.tag) {
        .decl => {
            const decl = scope.cast(Scope.DeclAnalysis).?.decl;
            decl.analysis = .sema_failure;
            self.failed_decls.putAssumeCapacityNoClobber(decl, err_msg);
        },
        .block => {
            const block = scope.cast(Scope.Block).?;
            block.func.analysis = .sema_failure;
            self.failed_decls.putAssumeCapacityNoClobber(block.decl, err_msg);
        },
        .zir_module => {
            const zir_module = scope.cast(Scope.ZIRModule).?;
            zir_module.status = .loaded_sema_failure;
            self.failed_files.putAssumeCapacityNoClobber(zir_module, err_msg);
        },
    }
    return error.AnalysisFail;
}

const InMemoryCoercionResult = enum {
    ok,
    no_match,
};

fn coerceInMemoryAllowed(dest_type: Type, src_type: Type) InMemoryCoercionResult {
    if (dest_type.eql(src_type))
        return .ok;

    // TODO: implement more of this function

    return .no_match;
}

pub const ErrorMsg = struct {
    byte_offset: usize,
    msg: []const u8,

    pub fn create(allocator: *Allocator, byte_offset: usize, comptime format: []const u8, args: var) !*ErrorMsg {
        const self = try allocator.create(ErrorMsg);
        errdefer allocator.destroy(self);
        self.* = try init(allocator, byte_offset, format, args);
        return self;
    }

    /// Assumes the ErrorMsg struct and msg were both allocated with allocator.
    pub fn destroy(self: *ErrorMsg, allocator: *Allocator) void {
        self.deinit(allocator);
        allocator.destroy(self);
    }

    pub fn init(allocator: *Allocator, byte_offset: usize, comptime format: []const u8, args: var) !ErrorMsg {
        return ErrorMsg{
            .byte_offset = byte_offset,
            .msg = try std.fmt.allocPrint(allocator, format, args),
        };
    }

    pub fn deinit(self: *ErrorMsg, allocator: *Allocator) void {
        allocator.free(self.msg);
        self.* = undefined;
    }
};

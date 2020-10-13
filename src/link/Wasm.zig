const Wasm = @This();

const std = @import("std");
const mem = std.mem;
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const fs = std.fs;
const leb = std.debug.leb;
const log = std.log.scoped(.link);

const Module = @import("../Module.zig");
const Compilation = @import("../Compilation.zig");
const codegen = @import("../codegen/wasm.zig");
const link = @import("../link.zig");
const trace = @import("../tracy.zig").trace;
const build_options = @import("build_options");
const Cache = @import("../Cache.zig");

/// Various magic numbers defined by the wasm spec
const spec = struct {
    const magic = [_]u8{ 0x00, 0x61, 0x73, 0x6D }; // \0asm
    const version = [_]u8{ 0x01, 0x00, 0x00, 0x00 }; // version 1

    const custom_id = 0;
    const types_id = 1;
    const imports_id = 2;
    const funcs_id = 3;
    const tables_id = 4;
    const memories_id = 5;
    const globals_id = 6;
    const exports_id = 7;
    const start_id = 8;
    const elements_id = 9;
    const code_id = 10;
    const data_id = 11;
};

pub const base_tag = link.File.Tag.wasm;

pub const FnData = struct {
    /// Generated code for the type of the function
    functype: std.ArrayListUnmanaged(u8) = .{},
    /// Generated code for the body of the function
    code: std.ArrayListUnmanaged(u8) = .{},
    /// Locations in the generated code where function indexes must be filled in.
    /// This must be kept ordered by offset.
    idx_refs: std.ArrayListUnmanaged(struct { offset: u32, decl: *Module.Decl }) = .{},
};

base: link.File,

/// List of all function Decls to be written to the output file. The index of
/// each Decl in this list at the time of writing the binary is used as the
/// function index.
/// TODO: can/should we access some data structure in Module directly?
funcs: std.ArrayListUnmanaged(*Module.Decl) = .{},

pub fn openPath(allocator: *Allocator, sub_path: []const u8, options: link.Options) !*Wasm {
    assert(options.object_format == .wasm);

    if (options.use_llvm) return error.LLVM_BackendIsTODO_ForWasm; // TODO
    if (options.use_lld) return error.LLD_LinkingIsTODO_ForWasm; // TODO

    // TODO: read the file and keep vaild parts instead of truncating
    const file = try options.emit.?.directory.handle.createFile(sub_path, .{ .truncate = true, .read = true });
    errdefer file.close();

    const wasm = try createEmpty(allocator, options);
    errdefer wasm.base.destroy();

    wasm.base.file = file;

    try file.writeAll(&(spec.magic ++ spec.version));

    return wasm;
}

pub fn createEmpty(gpa: *Allocator, options: link.Options) !*Wasm {
    const wasm = try gpa.create(Wasm);
    wasm.* = .{
        .base = .{
            .tag = .wasm,
            .options = options,
            .file = null,
            .allocator = gpa,
        },
    };
    return wasm;
}

pub fn deinit(self: *Wasm) void {
    for (self.funcs.items) |decl| {
        decl.fn_link.wasm.?.functype.deinit(self.base.allocator);
        decl.fn_link.wasm.?.code.deinit(self.base.allocator);
        decl.fn_link.wasm.?.idx_refs.deinit(self.base.allocator);
    }
    self.funcs.deinit(self.base.allocator);
}

// Generate code for the Decl, storing it in memory to be later written to
// the file on flush().
pub fn updateDecl(self: *Wasm, module: *Module, decl: *Module.Decl) !void {
    if (decl.typed_value.most_recent.typed_value.ty.zigTypeTag() != .Fn)
        return error.TODOImplementNonFnDeclsForWasm;

    if (decl.fn_link.wasm) |*fn_data| {
        fn_data.functype.items.len = 0;
        fn_data.code.items.len = 0;
        fn_data.idx_refs.items.len = 0;
    } else {
        decl.fn_link.wasm = .{};
        try self.funcs.append(self.base.allocator, decl);
    }
    const fn_data = &decl.fn_link.wasm.?;

    var managed_functype = fn_data.functype.toManaged(self.base.allocator);
    var managed_code = fn_data.code.toManaged(self.base.allocator);
    try codegen.genFunctype(&managed_functype, decl);
    try codegen.genCode(&managed_code, decl);
    fn_data.functype = managed_functype.toUnmanaged();
    fn_data.code = managed_code.toUnmanaged();
}

pub fn updateDeclExports(
    self: *Wasm,
    module: *Module,
    decl: *const Module.Decl,
    exports: []const *Module.Export,
) !void {}

pub fn freeDecl(self: *Wasm, decl: *Module.Decl) void {
    // TODO: remove this assert when non-function Decls are implemented
    assert(decl.typed_value.most_recent.typed_value.ty.zigTypeTag() == .Fn);
    _ = self.funcs.swapRemove(self.getFuncidx(decl).?);
    decl.fn_link.wasm.?.functype.deinit(self.base.allocator);
    decl.fn_link.wasm.?.code.deinit(self.base.allocator);
    decl.fn_link.wasm.?.idx_refs.deinit(self.base.allocator);
    decl.fn_link.wasm = null;
}

pub fn flush(self: *Wasm, comp: *Compilation) !void {
    if (build_options.have_llvm and self.base.options.use_lld) {
        return self.linkWithLLD(comp);
    } else {
        return self.flushModule(comp);
    }
}

pub fn flushModule(self: *Wasm, comp: *Compilation) !void {
    const tracy = trace(@src());
    defer tracy.end();

    const file = self.base.file.?;
    const header_size = 5 + 1;

    // No need to rewrite the magic/version header
    try file.setEndPos(@sizeOf(@TypeOf(spec.magic ++ spec.version)));
    try file.seekTo(@sizeOf(@TypeOf(spec.magic ++ spec.version)));

    // Type section
    {
        const header_offset = try reserveVecSectionHeader(file);
        for (self.funcs.items) |decl| {
            try file.writeAll(decl.fn_link.wasm.?.functype.items);
        }
        try writeVecSectionHeader(
            file,
            header_offset,
            spec.types_id,
            @intCast(u32, (try file.getPos()) - header_offset - header_size),
            @intCast(u32, self.funcs.items.len),
        );
    }

    // Function section
    {
        const header_offset = try reserveVecSectionHeader(file);
        const writer = file.writer();
        for (self.funcs.items) |_, typeidx| try leb.writeULEB128(writer, @intCast(u32, typeidx));
        try writeVecSectionHeader(
            file,
            header_offset,
            spec.funcs_id,
            @intCast(u32, (try file.getPos()) - header_offset - header_size),
            @intCast(u32, self.funcs.items.len),
        );
    }

    // Export section
    if (self.base.options.module) |module| {
        const header_offset = try reserveVecSectionHeader(file);
        const writer = file.writer();
        var count: u32 = 0;
        for (module.decl_exports.entries.items) |entry| {
            for (entry.value) |exprt| {
                // Export name length + name
                try leb.writeULEB128(writer, @intCast(u32, exprt.options.name.len));
                try writer.writeAll(exprt.options.name);

                switch (exprt.exported_decl.typed_value.most_recent.typed_value.ty.zigTypeTag()) {
                    .Fn => {
                        // Type of the export
                        try writer.writeByte(0x00);
                        // Exported function index
                        try leb.writeULEB128(writer, self.getFuncidx(exprt.exported_decl).?);
                    },
                    else => return error.TODOImplementNonFnDeclsForWasm,
                }

                count += 1;
            }
        }
        try writeVecSectionHeader(
            file,
            header_offset,
            spec.exports_id,
            @intCast(u32, (try file.getPos()) - header_offset - header_size),
            count,
        );
    }

    // Code section
    {
        const header_offset = try reserveVecSectionHeader(file);
        const writer = file.writer();
        for (self.funcs.items) |decl| {
            const fn_data = &decl.fn_link.wasm.?;

            // Write the already generated code to the file, inserting
            // function indexes where required.
            var current: u32 = 0;
            for (fn_data.idx_refs.items) |idx_ref| {
                try writer.writeAll(fn_data.code.items[current..idx_ref.offset]);
                current = idx_ref.offset;
                // Use a fixed width here to make calculating the code size
                // in codegen.wasm.genCode() simpler.
                var buf: [5]u8 = undefined;
                leb.writeUnsignedFixed(5, &buf, self.getFuncidx(idx_ref.decl).?);
                try writer.writeAll(&buf);
            }

            try writer.writeAll(fn_data.code.items[current..]);
        }
        try writeVecSectionHeader(
            file,
            header_offset,
            spec.code_id,
            @intCast(u32, (try file.getPos()) - header_offset - header_size),
            @intCast(u32, self.funcs.items.len),
        );
    }
}

fn linkWithLLD(self: *Wasm, comp: *Compilation) !void {
    const tracy = trace(@src());
    defer tracy.end();

    var arena_allocator = std.heap.ArenaAllocator.init(self.base.allocator);
    defer arena_allocator.deinit();
    const arena = &arena_allocator.allocator;

    const directory = self.base.options.emit.?.directory; // Just an alias to make it shorter to type.

    // If there is no Zig code to compile, then we should skip flushing the output file because it
    // will not be part of the linker line anyway.
    const module_obj_path: ?[]const u8 = if (self.base.options.module) |module| blk: {
        const use_stage1 = build_options.is_stage1 and self.base.options.use_llvm;
        if (use_stage1) {
            const obj_basename = try std.zig.binNameAlloc(arena, .{
                .root_name = self.base.options.root_name,
                .target = self.base.options.target,
                .output_mode = .Obj,
            });
            const o_directory = self.base.options.module.?.zig_cache_artifact_directory;
            const full_obj_path = try o_directory.join(arena, &[_][]const u8{obj_basename});
            break :blk full_obj_path;
        }

        try self.flushModule(comp);
        const obj_basename = self.base.intermediary_basename.?;
        const full_obj_path = try directory.join(arena, &[_][]const u8{obj_basename});
        break :blk full_obj_path;
    } else null;

    const target = self.base.options.target;

    const id_symlink_basename = "lld.id";

    var man: Cache.Manifest = undefined;
    defer if (!self.base.options.disable_lld_caching) man.deinit();

    var digest: [Cache.hex_digest_len]u8 = undefined;

    if (!self.base.options.disable_lld_caching) {
        man = comp.cache_parent.obtain();

        // We are about to obtain this lock, so here we give other processes a chance first.
        self.base.releaseLock();

        try man.addListOfFiles(self.base.options.objects);
        for (comp.c_object_table.items()) |entry| {
            _ = try man.addFile(entry.key.status.success.object_path, null);
        }
        try man.addOptionalFile(module_obj_path);
        man.hash.addOptional(self.base.options.stack_size_override);
        man.hash.addListOfBytes(self.base.options.extra_lld_args);

        // We don't actually care whether it's a cache hit or miss; we just need the digest and the lock.
        _ = try man.hit();
        digest = man.final();

        var prev_digest_buf: [digest.len]u8 = undefined;
        const prev_digest: []u8 = Cache.readSmallFile(
            directory.handle,
            id_symlink_basename,
            &prev_digest_buf,
        ) catch |err| blk: {
            log.debug("WASM LLD new_digest={} error: {}", .{ digest, @errorName(err) });
            // Handle this as a cache miss.
            break :blk prev_digest_buf[0..0];
        };
        if (mem.eql(u8, prev_digest, &digest)) {
            log.debug("WASM LLD digest={} match - skipping invocation", .{digest});
            // Hot diggity dog! The output binary is already there.
            self.base.lock = man.toOwnedLock();
            return;
        }
        log.debug("WASM LLD prev_digest={} new_digest={}", .{ prev_digest, digest });

        // We are about to change the output file to be different, so we invalidate the build hash now.
        directory.handle.deleteFile(id_symlink_basename) catch |err| switch (err) {
            error.FileNotFound => {},
            else => |e| return e,
        };
    }

    const is_obj = self.base.options.output_mode == .Obj;

    // Create an LLD command line and invoke it.
    var argv = std.ArrayList([]const u8).init(self.base.allocator);
    defer argv.deinit();
    // Even though we're calling LLD as a library it thinks the first argument is its own exe name.
    try argv.append("lld");
    if (is_obj) {
        try argv.append("-r");
    }

    try argv.append("-error-limit=0");

    if (self.base.options.output_mode == .Exe) {
        // Increase the default stack size to a more reasonable value of 1MB instead of
        // the default of 1 Wasm page being 64KB, unless overriden by the user.
        try argv.append("-z");
        const stack_size = self.base.options.stack_size_override orelse 1048576;
        const arg = try std.fmt.allocPrint(arena, "stack-size={d}", .{stack_size});
        try argv.append(arg);

        // Put stack before globals so that stack overflow results in segfault immediately
        // before corrupting globals. See https://github.com/ziglang/zig/issues/4496
        try argv.append("--stack-first");
    } else {
        try argv.append("--no-entry"); // So lld doesn't look for _start.
        try argv.append("--export-all");
    }
    try argv.appendSlice(&[_][]const u8{
        "--allow-undefined",
        "-o",
        try directory.join(arena, &[_][]const u8{self.base.options.emit.?.sub_path}),
    });

    // Positional arguments to the linker such as object files.
    try argv.appendSlice(self.base.options.objects);

    for (comp.c_object_table.items()) |entry| {
        try argv.append(entry.key.status.success.object_path);
    }
    if (module_obj_path) |p| {
        try argv.append(p);
    }

    if (self.base.options.output_mode != .Obj and !self.base.options.is_compiler_rt_or_libc) {
        if (!self.base.options.link_libc) {
            try argv.append(comp.libc_static_lib.?.full_object_path);
        }
        try argv.append(comp.compiler_rt_static_lib.?.full_object_path);
    }

    if (self.base.options.verbose_link) {
        Compilation.dump_argv(argv.items);
    }

    const new_argv = try arena.allocSentinel(?[*:0]const u8, argv.items.len, null);
    for (argv.items) |arg, i| {
        new_argv[i] = try arena.dupeZ(u8, arg);
    }

    var stderr_context: LLDContext = .{
        .wasm = self,
        .data = std.ArrayList(u8).init(self.base.allocator),
    };
    defer stderr_context.data.deinit();
    var stdout_context: LLDContext = .{
        .wasm = self,
        .data = std.ArrayList(u8).init(self.base.allocator),
    };
    defer stdout_context.data.deinit();
    const llvm = @import("../llvm.zig");
    const ok = llvm.Link(
        .Wasm,
        new_argv.ptr,
        new_argv.len,
        append_diagnostic,
        @ptrToInt(&stdout_context),
        @ptrToInt(&stderr_context),
    );
    if (stderr_context.oom or stdout_context.oom) return error.OutOfMemory;
    if (stdout_context.data.items.len != 0) {
        std.log.warn("unexpected LLD stdout: {}", .{stdout_context.data.items});
    }
    if (!ok) {
        // TODO parse this output and surface with the Compilation API rather than
        // directly outputting to stderr here.
        std.debug.print("{}", .{stderr_context.data.items});
        return error.LLDReportedFailure;
    }
    if (stderr_context.data.items.len != 0) {
        std.log.warn("unexpected LLD stderr: {}", .{stderr_context.data.items});
    }

    if (!self.base.options.disable_lld_caching) {
        // Update the file with the digest. If it fails we can continue; it only
        // means that the next invocation will have an unnecessary cache miss.
        Cache.writeSmallFile(directory.handle, id_symlink_basename, &digest) catch |err| {
            std.log.warn("failed to save linking hash digest symlink: {}", .{@errorName(err)});
        };
        // Again failure here only means an unnecessary cache miss.
        man.writeManifest() catch |err| {
            std.log.warn("failed to write cache manifest when linking: {}", .{@errorName(err)});
        };
        // We hang on to this lock so that the output file path can be used without
        // other processes clobbering it.
        self.base.lock = man.toOwnedLock();
    }
}

const LLDContext = struct {
    data: std.ArrayList(u8),
    wasm: *Wasm,
    oom: bool = false,
};

fn append_diagnostic(context: usize, ptr: [*]const u8, len: usize) callconv(.C) void {
    const lld_context = @intToPtr(*LLDContext, context);
    const msg = ptr[0..len];
    lld_context.data.appendSlice(msg) catch |err| switch (err) {
        error.OutOfMemory => lld_context.oom = true,
    };
}

/// Get the current index of a given Decl in the function list
/// TODO: we could maintain a hash map to potentially make this
fn getFuncidx(self: Wasm, decl: *Module.Decl) ?u32 {
    return for (self.funcs.items) |func, idx| {
        if (func == decl) break @intCast(u32, idx);
    } else null;
}

fn reserveVecSectionHeader(file: fs.File) !u64 {
    // section id + fixed leb contents size + fixed leb vector length
    const header_size = 1 + 5 + 5;
    // TODO: this should be a single lseek(2) call, but fs.File does not
    // currently provide a way to do this.
    try file.seekBy(header_size);
    return (try file.getPos()) - header_size;
}

fn writeVecSectionHeader(file: fs.File, offset: u64, section: u8, size: u32, items: u32) !void {
    var buf: [1 + 5 + 5]u8 = undefined;
    buf[0] = section;
    leb.writeUnsignedFixed(5, buf[1..6], size);
    leb.writeUnsignedFixed(5, buf[6..], items);
    try file.pwriteAll(&buf, offset);
}

const MachO = @This();

const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const fs = std.fs;
const log = std.log.scoped(.link);
const macho = std.macho;
const codegen = @import("../codegen.zig");
const math = std.math;
const mem = std.mem;

const trace = @import("../tracy.zig").trace;
const Type = @import("../type.zig").Type;
const build_options = @import("build_options");
const Module = @import("../Module.zig");
const Compilation = @import("../Compilation.zig");
const link = @import("../link.zig");
const File = link.File;
const Cache = @import("../Cache.zig");
const target_util = @import("../target.zig");

pub const base_tag: File.Tag = File.Tag.macho;

const LoadCommand = union(enum) {
    Segment: macho.segment_command_64,
    LinkeditData: macho.linkedit_data_command,
    Symtab: macho.symtab_command,
    Dysymtab: macho.dysymtab_command,

    pub fn cmdsize(self: LoadCommand) u32 {
        return switch (self) {
            .Segment => |x| x.cmdsize,
            .LinkeditData => |x| x.cmdsize,
            .Symtab => |x| x.cmdsize,
            .Dysymtab => |x| x.cmdsize,
        };
    }

    pub fn write(self: LoadCommand, file: *fs.File, offset: u64) !void {
        return switch (self) {
            .Segment => |cmd| writeGeneric(cmd, file, offset),
            .LinkeditData => |cmd| writeGeneric(cmd, file, offset),
            .Symtab => |cmd| writeGeneric(cmd, file, offset),
            .Dysymtab => |cmd| writeGeneric(cmd, file, offset),
        };
    }

    fn writeGeneric(cmd: anytype, file: *fs.File, offset: u64) !void {
        const slice = [1]@TypeOf(cmd){cmd};
        return file.pwriteAll(mem.sliceAsBytes(slice[0..1]), offset);
    }
};

base: File,

/// Table of all load commands
load_commands: std.ArrayListUnmanaged(LoadCommand) = .{},
segment_cmd_index: ?u16 = null,
symtab_cmd_index: ?u16 = null,
dysymtab_cmd_index: ?u16 = null,
data_in_code_cmd_index: ?u16 = null,

/// Table of all sections
sections: std.ArrayListUnmanaged(macho.section_64) = .{},

/// __TEXT segment sections
text_section_index: ?u16 = null,
cstring_section_index: ?u16 = null,
const_text_section_index: ?u16 = null,
stubs_section_index: ?u16 = null,
stub_helper_section_index: ?u16 = null,

/// __DATA segment sections
got_section_index: ?u16 = null,
const_data_section_index: ?u16 = null,

entry_addr: ?u64 = null,

/// Table of all symbols used.
/// Internally references string table for names (which are optional).
symbol_table: std.ArrayListUnmanaged(macho.nlist_64) = .{},

/// Table of symbol names aka the string table.
string_table: std.ArrayListUnmanaged(u8) = .{},

/// Table of symbol vaddr values. The values is the absolute vaddr value.
/// If the vaddr of the executable __TEXT segment vaddr changes, the entire offset
/// table needs to be rewritten.
offset_table: std.ArrayListUnmanaged(u64) = .{},

error_flags: File.ErrorFlags = File.ErrorFlags{},

cmd_table_dirty: bool = false,

/// Pointer to the last allocated text block
last_text_block: ?*TextBlock = null,

/// `alloc_num / alloc_den` is the factor of padding when allocating.
const alloc_num = 4;
const alloc_den = 3;

/// Default path to dyld
/// TODO instead of hardcoding it, we should probably look through some env vars and search paths
/// instead but this will do for now.
const DEFAULT_DYLD_PATH: [*:0]const u8 = "/usr/lib/dyld";

/// Default lib search path
/// TODO instead of hardcoding it, we should probably look through some env vars and search paths
/// instead but this will do for now.
const DEFAULT_LIB_SEARCH_PATH: []const u8 = "/usr/lib";

const LIB_SYSTEM_NAME: [*:0]const u8 = "System";
/// TODO we should search for libSystem and fail if it doesn't exist, instead of hardcoding it
const LIB_SYSTEM_PATH: [*:0]const u8 = DEFAULT_LIB_SEARCH_PATH ++ "/libSystem.B.dylib";

pub const TextBlock = struct {
    /// Index into the symbol table
    symbol_table_index: ?u32,
    /// Index into offset table
    offset_table_index: ?u32,
    /// Size of this text block
    size: u64,
    /// Points to the previous and next neighbours
    prev: ?*TextBlock,
    next: ?*TextBlock,

    pub const empty = TextBlock{
        .symbol_table_index = null,
        .offset_table_index = null,
        .size = 0,
        .prev = null,
        .next = null,
    };
};

pub const SrcFn = struct {
    pub const empty = SrcFn{};
};

pub fn openPath(allocator: *Allocator, sub_path: []const u8, options: link.Options) !*MachO {
    assert(options.object_format == .macho);

    if (options.use_llvm) return error.LLVM_BackendIsTODO_ForMachO; // TODO
    if (options.use_lld) return error.LLD_LinkingIsTODO_ForMachO; // TODO

    const file = try options.emit.?.directory.handle.createFile(sub_path, .{
        .truncate = false,
        .read = true,
        .mode = link.determineMode(options),
    });
    errdefer file.close();

    const self = try createEmpty(allocator, options);
    errdefer self.base.destroy();

    self.base.file = file;

    switch (options.output_mode) {
        .Exe => {},
        .Obj => {},
        .Lib => return error.TODOImplementWritingLibFiles,
    }

    try self.populateMissingMetadata();

    return self;
}

pub fn createEmpty(gpa: *Allocator, options: link.Options) !*MachO {
    const self = try gpa.create(MachO);
    self.* = .{
        .base = .{
            .tag = .macho,
            .options = options,
            .allocator = gpa,
            .file = null,
        },
    };
    return self;
}

pub fn flush(self: *MachO, comp: *Compilation) !void {
    if (build_options.have_llvm and self.base.options.use_lld) {
        return self.linkWithLLD(comp);
    } else {
        switch (self.base.options.effectiveOutputMode()) {
            .Exe, .Obj => {},
            .Lib => return error.TODOImplementWritingLibFiles,
        }
        return self.flushModule(comp);
    }
}

pub fn flushModule(self: *MachO, comp: *Compilation) !void {
    const tracy = trace(@src());
    defer tracy.end();

    switch (self.base.options.output_mode) {
        .Exe => {
            var last_cmd_offset: usize = @sizeOf(macho.mach_header_64);
            {
                // Specify path to dynamic linker dyld
                const cmdsize = commandSize(@sizeOf(macho.dylinker_command) + mem.lenZ(DEFAULT_DYLD_PATH));
                const load_dylinker = [1]macho.dylinker_command{
                    .{
                        .cmd = macho.LC_LOAD_DYLINKER,
                        .cmdsize = cmdsize,
                        .name = @sizeOf(macho.dylinker_command),
                    },
                };

                try self.base.file.?.pwriteAll(mem.sliceAsBytes(load_dylinker[0..1]), last_cmd_offset);

                const file_offset = last_cmd_offset + @sizeOf(macho.dylinker_command);
                try self.addPadding(cmdsize - @sizeOf(macho.dylinker_command), file_offset);

                try self.base.file.?.pwriteAll(mem.spanZ(DEFAULT_DYLD_PATH), file_offset);
                last_cmd_offset += cmdsize;
            }

            {
                // Link against libSystem
                const cmdsize = commandSize(@sizeOf(macho.dylib_command) + mem.lenZ(LIB_SYSTEM_PATH));
                // TODO Find a way to work out runtime version from the OS version triple stored in std.Target.
                // In the meantime, we're gonna hardcode to the minimum compatibility version of 1.0.0.
                const min_version = 0x10000;
                const dylib = .{
                    .name = @sizeOf(macho.dylib_command),
                    .timestamp = 2, // not sure why not simply 0; this is reverse engineered from Mach-O files
                    .current_version = min_version,
                    .compatibility_version = min_version,
                };
                const load_dylib = [1]macho.dylib_command{
                    .{
                        .cmd = macho.LC_LOAD_DYLIB,
                        .cmdsize = cmdsize,
                        .dylib = dylib,
                    },
                };

                try self.base.file.?.pwriteAll(mem.sliceAsBytes(load_dylib[0..1]), last_cmd_offset);

                const file_offset = last_cmd_offset + @sizeOf(macho.dylib_command);
                try self.addPadding(cmdsize - @sizeOf(macho.dylib_command), file_offset);

                try self.base.file.?.pwriteAll(mem.spanZ(LIB_SYSTEM_PATH), file_offset);
                last_cmd_offset += cmdsize;
            }
        },
        .Obj => {
            {
                const symtab = &self.load_commands.items[self.symtab_cmd_index.?].Symtab;
                symtab.nsyms = @intCast(u32, self.symbol_table.items.len);
                const allocated_size = self.allocatedSize(symtab.stroff);
                const needed_size = self.string_table.items.len;
                log.debug("allocated_size = 0x{x}, needed_size = 0x{x}\n", .{ allocated_size, needed_size });

                if (needed_size > allocated_size) {
                    symtab.strsize = 0;
                    symtab.stroff = @intCast(u32, self.findFreeSpace(needed_size, 1));
                }
                symtab.strsize = @intCast(u32, needed_size);

                log.debug("writing string table from 0x{x} to 0x{x}\n", .{ symtab.stroff, symtab.stroff + symtab.strsize });

                try self.base.file.?.pwriteAll(self.string_table.items, symtab.stroff);
            }

            var last_cmd_offset: usize = @sizeOf(macho.mach_header_64);
            for (self.load_commands.items) |cmd| {
                try cmd.write(&self.base.file.?, last_cmd_offset);
                last_cmd_offset += cmd.cmdsize();
            }
            const off = @sizeOf(macho.mach_header_64) + @sizeOf(macho.segment_command_64);
            try self.base.file.?.pwriteAll(mem.sliceAsBytes(self.sections.items), off);
        },
        .Lib => return error.TODOImplementWritingLibFiles,
    }

    if (self.entry_addr == null and self.base.options.output_mode == .Exe) {
        log.debug("flushing. no_entry_point_found = true\n", .{});
        self.error_flags.no_entry_point_found = true;
    } else {
        log.debug("flushing. no_entry_point_found = false\n", .{});
        self.error_flags.no_entry_point_found = false;
        try self.writeMachOHeader();
    }
}

fn linkWithLLD(self: *MachO, comp: *Compilation) !void {
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

    const is_lib = self.base.options.output_mode == .Lib;
    const is_dyn_lib = self.base.options.link_mode == .Dynamic and is_lib;
    const is_exe_or_dyn_lib = is_dyn_lib or self.base.options.output_mode == .Exe;
    const target = self.base.options.target;
    const stack_size = self.base.options.stack_size_override orelse 16777216;
    const allow_shlib_undefined = self.base.options.allow_shlib_undefined orelse !self.base.options.is_native_os;

    const id_symlink_basename = "lld.id";

    var man: Cache.Manifest = undefined;
    defer if (!self.base.options.disable_lld_caching) man.deinit();

    var digest: [Cache.hex_digest_len]u8 = undefined;

    if (!self.base.options.disable_lld_caching) {
        man = comp.cache_parent.obtain();

        // We are about to obtain this lock, so here we give other processes a chance first.
        self.base.releaseLock();

        try man.addOptionalFile(self.base.options.linker_script);
        try man.addOptionalFile(self.base.options.version_script);
        try man.addListOfFiles(self.base.options.objects);
        for (comp.c_object_table.items()) |entry| {
            _ = try man.addFile(entry.key.status.success.object_path, null);
        }
        try man.addOptionalFile(module_obj_path);
        // We can skip hashing libc and libc++ components that we are in charge of building from Zig
        // installation sources because they are always a product of the compiler version + target information.
        man.hash.add(stack_size);
        man.hash.add(self.base.options.rdynamic);
        man.hash.addListOfBytes(self.base.options.extra_lld_args);
        man.hash.addListOfBytes(self.base.options.lib_dirs);
        man.hash.addListOfBytes(self.base.options.framework_dirs);
        man.hash.addListOfBytes(self.base.options.frameworks);
        man.hash.addListOfBytes(self.base.options.rpath_list);
        man.hash.add(self.base.options.is_compiler_rt_or_libc);
        man.hash.add(self.base.options.z_nodelete);
        man.hash.add(self.base.options.z_defs);
        if (is_dyn_lib) {
            man.hash.addOptional(self.base.options.version);
        }
        man.hash.addStringSet(self.base.options.system_libs);
        man.hash.add(allow_shlib_undefined);
        man.hash.add(self.base.options.bind_global_refs_locally);

        // We don't actually care whether it's a cache hit or miss; we just need the digest and the lock.
        _ = try man.hit();
        digest = man.final();

        var prev_digest_buf: [digest.len]u8 = undefined;
        const prev_digest: []u8 = directory.handle.readLink(id_symlink_basename, &prev_digest_buf) catch |err| blk: {
            log.debug("MachO LLD new_digest={} readlink error: {}", .{ digest, @errorName(err) });
            // Handle this as a cache miss.
            break :blk prev_digest_buf[0..0];
        };
        if (mem.eql(u8, prev_digest, &digest)) {
            log.debug("MachO LLD digest={} match - skipping invocation", .{digest});
            // Hot diggity dog! The output binary is already there.
            self.base.lock = man.toOwnedLock();
            return;
        }
        log.debug("MachO LLD prev_digest={} new_digest={}", .{ prev_digest, digest });

        // We are about to change the output file to be different, so we invalidate the build hash now.
        directory.handle.deleteFile(id_symlink_basename) catch |err| switch (err) {
            error.FileNotFound => {},
            else => |e| return e,
        };
    }

    const full_out_path = try directory.join(arena, &[_][]const u8{self.base.options.emit.?.sub_path});

    if (self.base.options.output_mode == .Obj) {
        // LLD's MachO driver does not support the equvialent of `-r` so we do a simple file copy
        // here. TODO: think carefully about how we can avoid this redundant operation when doing
        // build-obj. See also the corresponding TODO in linkAsArchive.
        const the_object_path = blk: {
            if (self.base.options.objects.len != 0)
                break :blk self.base.options.objects[0];

            if (comp.c_object_table.count() != 0)
                break :blk comp.c_object_table.items()[0].key.status.success.object_path;

            if (module_obj_path) |p|
                break :blk p;

            // TODO I think this is unreachable. Audit this situation when solving the above TODO
            // regarding eliding redundant object -> object transformations.
            return error.NoObjectsToLink;
        };
        // This can happen when using --enable-cache and using the stage1 backend. In this case
        // we can skip the file copy.
        if (!mem.eql(u8, the_object_path, full_out_path)) {
            try fs.cwd().copyFile(the_object_path, fs.cwd(), full_out_path, .{});
        }
    } else {
        // Create an LLD command line and invoke it.
        var argv = std.ArrayList([]const u8).init(self.base.allocator);
        defer argv.deinit();
        // Even though we're calling LLD as a library it thinks the first argument is its own exe name.
        try argv.append("lld");

        try argv.append("-error-limit");
        try argv.append("0");

        try argv.append("-demangle");

        if (self.base.options.rdynamic) {
            try argv.append("--export-dynamic");
        }

        try argv.appendSlice(self.base.options.extra_lld_args);

        if (self.base.options.z_nodelete) {
            try argv.append("-z");
            try argv.append("nodelete");
        }
        if (self.base.options.z_defs) {
            try argv.append("-z");
            try argv.append("defs");
        }

        if (is_dyn_lib) {
            try argv.append("-static");
        } else {
            try argv.append("-dynamic");
        }

        if (is_dyn_lib) {
            try argv.append("-dylib");

            if (self.base.options.version) |ver| {
                const compat_vers = try std.fmt.allocPrint(arena, "{d}.0.0", .{ver.major});
                try argv.append("-compatibility_version");
                try argv.append(compat_vers);

                const cur_vers = try std.fmt.allocPrint(arena, "{d}.{d}.{d}", .{ ver.major, ver.minor, ver.patch });
                try argv.append("-current_version");
                try argv.append(cur_vers);
            }

            // TODO getting an error when running an executable when doing this rpath thing
            //Buf *dylib_install_name = buf_sprintf("@rpath/lib%s.%" ZIG_PRI_usize ".dylib",
            //    buf_ptr(g->root_out_name), g->version_major);
            //try argv.append("-install_name");
            //try argv.append(buf_ptr(dylib_install_name));
        }

        try argv.append("-arch");
        try argv.append(darwinArchString(target.cpu.arch));

        switch (target.os.tag) {
            .macosx => {
                try argv.append("-macosx_version_min");
            },
            .ios, .tvos, .watchos => switch (target.cpu.arch) {
                .i386, .x86_64 => {
                    try argv.append("-ios_simulator_version_min");
                },
                else => {
                    try argv.append("-iphoneos_version_min");
                },
            },
            else => unreachable,
        }
        const ver = target.os.version_range.semver.min;
        const version_string = try std.fmt.allocPrint(arena, "{d}.{d}.{d}", .{ ver.major, ver.minor, ver.patch });
        try argv.append(version_string);

        try argv.append("-sdk_version");
        try argv.append(version_string);

        if (target_util.requiresPIE(target) and self.base.options.output_mode == .Exe) {
            try argv.append("-pie");
        }

        try argv.append("-o");
        try argv.append(full_out_path);

        // rpaths
        var rpath_table = std.StringHashMap(void).init(self.base.allocator);
        defer rpath_table.deinit();
        for (self.base.options.rpath_list) |rpath| {
            if ((try rpath_table.fetchPut(rpath, {})) == null) {
                try argv.append("-rpath");
                try argv.append(rpath);
            }
        }
        if (is_dyn_lib) {
            if ((try rpath_table.fetchPut(full_out_path, {})) == null) {
                try argv.append("-rpath");
                try argv.append(full_out_path);
            }
        }

        for (self.base.options.lib_dirs) |lib_dir| {
            try argv.append("-L");
            try argv.append(lib_dir);
        }

        // Positional arguments to the linker such as object files.
        try argv.appendSlice(self.base.options.objects);

        for (comp.c_object_table.items()) |entry| {
            try argv.append(entry.key.status.success.object_path);
        }
        if (module_obj_path) |p| {
            try argv.append(p);
        }

        // compiler_rt on darwin is missing some stuff, so we still build it and rely on LinkOnce
        if (is_exe_or_dyn_lib and !self.base.options.is_compiler_rt_or_libc) {
            try argv.append(comp.compiler_rt_static_lib.?.full_object_path);
        }

        // Shared libraries.
        const system_libs = self.base.options.system_libs.items();
        try argv.ensureCapacity(argv.items.len + system_libs.len);
        for (system_libs) |entry| {
            const link_lib = entry.key;
            // By this time, we depend on these libs being dynamically linked libraries and not static libraries
            // (the check for that needs to be earlier), but they could be full paths to .dylib files, in which
            // case we want to avoid prepending "-l".
            const ext = Compilation.classifyFileExt(link_lib);
            const arg = if (ext == .shared_library) link_lib else try std.fmt.allocPrint(arena, "-l{}", .{link_lib});
            argv.appendAssumeCapacity(arg);
        }

        // libc++ dep
        if (self.base.options.link_libcpp) {
            try argv.append(comp.libcxxabi_static_lib.?.full_object_path);
            try argv.append(comp.libcxx_static_lib.?.full_object_path);
        }

        // On Darwin, libSystem has libc in it, but also you have to use it
        // to make syscalls because the syscall numbers are not documented
        // and change between versions. So we always link against libSystem.
        // LLD craps out if you do -lSystem cross compiling, so until that
        // codebase gets some love from the new maintainers we're left with
        // this dirty hack.
        if (self.base.options.is_native_os) {
            try argv.append("-lSystem");
        }

        for (self.base.options.framework_dirs) |framework_dir| {
            try argv.append("-F");
            try argv.append(framework_dir);
        }
        for (self.base.options.frameworks) |framework| {
            try argv.append("-framework");
            try argv.append(framework);
        }

        if (allow_shlib_undefined) {
            try argv.append("-undefined");
            try argv.append("dynamic_lookup");
        }
        if (self.base.options.bind_global_refs_locally) {
            try argv.append("-Bsymbolic");
        }

        if (self.base.options.verbose_link) {
            Compilation.dump_argv(argv.items);
        }

        const new_argv = try arena.allocSentinel(?[*:0]const u8, argv.items.len, null);
        for (argv.items) |arg, i| {
            new_argv[i] = try arena.dupeZ(u8, arg);
        }

        var stderr_context: LLDContext = .{
            .macho = self,
            .data = std.ArrayList(u8).init(self.base.allocator),
        };
        defer stderr_context.data.deinit();
        var stdout_context: LLDContext = .{
            .macho = self,
            .data = std.ArrayList(u8).init(self.base.allocator),
        };
        defer stdout_context.data.deinit();
        const llvm = @import("../llvm.zig");
        const ok = llvm.Link(
            .MachO,
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
    }

    if (!self.base.options.disable_lld_caching) {
        // Update the dangling symlink with the digest. If it fails we can continue; it only
        // means that the next invocation will have an unnecessary cache miss.
        directory.handle.symLink(&digest, id_symlink_basename, .{}) catch |err| {
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
    macho: *MachO,
    oom: bool = false,
};

fn append_diagnostic(context: usize, ptr: [*]const u8, len: usize) callconv(.C) void {
    const lld_context = @intToPtr(*LLDContext, context);
    const msg = ptr[0..len];
    lld_context.data.appendSlice(msg) catch |err| switch (err) {
        error.OutOfMemory => lld_context.oom = true,
    };
}

fn darwinArchString(arch: std.Target.Cpu.Arch) []const u8 {
    return switch (arch) {
        .aarch64, .aarch64_be, .aarch64_32 => "arm64",
        .thumb, .arm => "arm",
        .thumbeb, .armeb => "armeb",
        .powerpc => "ppc",
        .powerpc64 => "ppc64",
        .powerpc64le => "ppc64le",
        else => @tagName(arch),
    };
}

pub fn deinit(self: *MachO) void {
    self.offset_table.deinit(self.base.allocator);
    self.string_table.deinit(self.base.allocator);
    self.symbol_table.deinit(self.base.allocator);
    self.sections.deinit(self.base.allocator);
    self.load_commands.deinit(self.base.allocator);
}

pub fn allocateDeclIndexes(self: *MachO, decl: *Module.Decl) !void {
    if (decl.link.macho.symbol_table_index) |_| return;

    try self.symbol_table.ensureCapacity(self.base.allocator, self.symbol_table.items.len + 1);
    try self.offset_table.ensureCapacity(self.base.allocator, self.offset_table.items.len + 1);

    log.debug("allocating symbol index {} for {}\n", .{ self.symbol_table.items.len, decl.name });
    decl.link.macho.symbol_table_index = @intCast(u32, self.symbol_table.items.len);
    _ = self.symbol_table.addOneAssumeCapacity();

    decl.link.macho.offset_table_index = @intCast(u32, self.offset_table.items.len);
    _ = self.offset_table.addOneAssumeCapacity();

    self.symbol_table.items[decl.link.macho.symbol_table_index.?] = .{
        .n_strx = 0,
        .n_type = 0,
        .n_sect = 0,
        .n_desc = 0,
        .n_value = 0,
    };
    self.offset_table.items[decl.link.macho.offset_table_index.?] = 0;
}

pub fn updateDecl(self: *MachO, module: *Module, decl: *Module.Decl) !void {
    const tracy = trace(@src());
    defer tracy.end();

    var code_buffer = std.ArrayList(u8).init(self.base.allocator);
    defer code_buffer.deinit();

    const typed_value = decl.typed_value.most_recent.typed_value;
    const res = try codegen.generateSymbol(&self.base, decl.src(), typed_value, &code_buffer, .none);

    const code = switch (res) {
        .externally_managed => |x| x,
        .appended => code_buffer.items,
        .fail => |em| {
            decl.analysis = .codegen_failure;
            try module.failed_decls.put(module.gpa, decl, em);
            return;
        },
    };
    log.debug("generated code {}\n", .{code});

    const required_alignment = typed_value.ty.abiAlignment(self.base.options.target);
    const symbol = &self.symbol_table.items[decl.link.macho.symbol_table_index.?];

    const decl_name = mem.spanZ(decl.name);
    const name_str_index = try self.makeString(decl_name);
    const addr = try self.allocateTextBlock(&decl.link.macho, code.len, required_alignment);
    log.debug("allocated text block for {} at 0x{x}\n", .{ decl_name, addr });
    log.debug("updated text section {}\n", .{self.sections.items[self.text_section_index.?]});

    symbol.* = .{
        .n_strx = name_str_index,
        .n_type = macho.N_SECT,
        .n_sect = @intCast(u8, self.text_section_index.?) + 1,
        .n_desc = 0,
        .n_value = addr,
    };

    // Since we updated the vaddr and the size, each corresponding export symbol also needs to be updated.
    const decl_exports = module.decl_exports.get(decl) orelse &[0]*Module.Export{};
    try self.updateDeclExports(module, decl, decl_exports);
    try self.writeSymbol(decl.link.macho.symbol_table_index.?);

    const text_section = self.sections.items[self.text_section_index.?];
    const section_offset = symbol.n_value - text_section.addr;
    const file_offset = text_section.offset + section_offset;
    log.debug("file_offset 0x{x}\n", .{file_offset});

    try self.base.file.?.pwriteAll(code, file_offset);
}

pub fn updateDeclLineNumber(self: *MachO, module: *Module, decl: *const Module.Decl) !void {}

pub fn updateDeclExports(
    self: *MachO,
    module: *Module,
    decl: *const Module.Decl,
    exports: []const *Module.Export,
) !void {
    const tracy = trace(@src());
    defer tracy.end();

    if (decl.link.macho.symbol_table_index == null) return;

    const decl_sym = &self.symbol_table.items[decl.link.macho.symbol_table_index.?];
    // TODO implement
    if (exports.len == 0) return;

    const exp = exports[0];
    self.entry_addr = decl_sym.n_value;
    decl_sym.n_type |= macho.N_EXT;
    exp.link.sym_index = 0;
}

pub fn freeDecl(self: *MachO, decl: *Module.Decl) void {}

pub fn getDeclVAddr(self: *MachO, decl: *const Module.Decl) u64 {
    return self.symbol_table.items[decl.link.macho.symbol_table_index.?].n_value;
}

pub fn populateMissingMetadata(self: *MachO) !void {
    if (self.segment_cmd_index == null) {
        self.segment_cmd_index = @intCast(u16, self.load_commands.items.len);
        try self.load_commands.append(self.base.allocator, .{
            .Segment = .{
                .cmd = macho.LC_SEGMENT_64,
                .cmdsize = @sizeOf(macho.segment_command_64),
                .segname = makeStaticString(""),
                .vmaddr = 0,
                .vmsize = 0,
                .fileoff = 0,
                .filesize = 0,
                .maxprot = 0,
                .initprot = 0,
                .nsects = 0,
                .flags = 0,
            },
        });
        self.cmd_table_dirty = true;
    }
    if (self.symtab_cmd_index == null) {
        self.symtab_cmd_index = @intCast(u16, self.load_commands.items.len);
        try self.load_commands.append(self.base.allocator, .{
            .Symtab = .{
                .cmd = macho.LC_SYMTAB,
                .cmdsize = @sizeOf(macho.symtab_command),
                .symoff = 0,
                .nsyms = 0,
                .stroff = 0,
                .strsize = 0,
            },
        });
        self.cmd_table_dirty = true;
    }
    if (self.text_section_index == null) {
        self.text_section_index = @intCast(u16, self.sections.items.len);
        const segment = &self.load_commands.items[self.segment_cmd_index.?].Segment;
        segment.cmdsize += @sizeOf(macho.section_64);
        segment.nsects += 1;

        const file_size = self.base.options.program_code_size_hint;
        const off = @intCast(u32, self.findFreeSpace(file_size, 1));
        const flags = macho.S_REGULAR | macho.S_ATTR_PURE_INSTRUCTIONS | macho.S_ATTR_SOME_INSTRUCTIONS;

        log.debug("found __text section free space 0x{x} to 0x{x}\n", .{ off, off + file_size });

        try self.sections.append(self.base.allocator, .{
            .sectname = makeStaticString("__text"),
            .segname = makeStaticString("__TEXT"),
            .addr = 0,
            .size = file_size,
            .offset = off,
            .@"align" = 0x1000,
            .reloff = 0,
            .nreloc = 0,
            .flags = flags,
            .reserved1 = 0,
            .reserved2 = 0,
            .reserved3 = 0,
        });

        segment.vmsize += file_size;
        segment.filesize += file_size;
        segment.fileoff = off;

        log.debug("initial text section {}\n", .{self.sections.items[self.text_section_index.?]});
    }
    {
        const symtab = &self.load_commands.items[self.symtab_cmd_index.?].Symtab;
        if (symtab.symoff == 0) {
            const p_align = @sizeOf(macho.nlist_64);
            const nsyms = self.base.options.symbol_count_hint;
            const file_size = p_align * nsyms;
            const off = @intCast(u32, self.findFreeSpace(file_size, p_align));
            log.debug("found symbol table free space 0x{x} to 0x{x}\n", .{ off, off + file_size });
            symtab.symoff = off;
            symtab.nsyms = @intCast(u32, nsyms);
        }
        if (symtab.stroff == 0) {
            try self.string_table.append(self.base.allocator, 0);
            const file_size = @intCast(u32, self.string_table.items.len);
            const off = @intCast(u32, self.findFreeSpace(file_size, 1));
            log.debug("found string table free space 0x{x} to 0x{x}\n", .{ off, off + file_size });
            symtab.stroff = off;
            symtab.strsize = file_size;
        }
    }
}

fn allocateTextBlock(self: *MachO, text_block: *TextBlock, new_block_size: u64, alignment: u64) !u64 {
    const segment = &self.load_commands.items[self.segment_cmd_index.?].Segment;
    const text_section = &self.sections.items[self.text_section_index.?];
    const new_block_ideal_capacity = new_block_size * alloc_num / alloc_den;

    var block_placement: ?*TextBlock = null;
    const addr = blk: {
        if (self.last_text_block) |last| {
            const last_symbol = self.symbol_table.items[last.symbol_table_index.?];
            const end_addr = last_symbol.n_value + last.size;
            const new_start_addr = mem.alignForwardGeneric(u64, end_addr, alignment);
            block_placement = last;
            break :blk new_start_addr;
        } else {
            break :blk text_section.addr;
        }
    };
    log.debug("computed symbol address 0x{x}\n", .{addr});

    const expand_text_section = block_placement == null or block_placement.?.next == null;
    if (expand_text_section) {
        const text_capacity = self.allocatedSize(text_section.offset);
        const needed_size = (addr + new_block_size) - text_section.addr;
        log.debug("text capacity 0x{x}, needed size 0x{x}\n", .{ text_capacity, needed_size });
        assert(needed_size <= text_capacity); // TODO handle growth

        self.last_text_block = text_block;
        text_section.size = needed_size;
        segment.vmsize = needed_size;
        segment.filesize = needed_size;
        if (alignment < text_section.@"align") {
            text_section.@"align" = @intCast(u32, alignment);
        }
    }
    text_block.size = new_block_size;

    if (text_block.prev) |prev| {
        prev.next = text_block.next;
    }
    if (text_block.next) |next| {
        next.prev = text_block.prev;
    }

    if (block_placement) |big_block| {
        text_block.prev = big_block;
        text_block.next = big_block.next;
        big_block.next = text_block;
    } else {
        text_block.prev = null;
        text_block.next = null;
    }

    return addr;
}

fn makeStaticString(comptime bytes: []const u8) [16]u8 {
    var buf = [_]u8{0} ** 16;
    if (bytes.len > buf.len) @compileError("string too long; max 16 bytes");
    mem.copy(u8, buf[0..], bytes);
    return buf;
}

fn makeString(self: *MachO, bytes: []const u8) !u32 {
    try self.string_table.ensureCapacity(self.base.allocator, self.string_table.items.len + bytes.len + 1);
    const result = self.string_table.items.len;
    self.string_table.appendSliceAssumeCapacity(bytes);
    self.string_table.appendAssumeCapacity(0);
    return @intCast(u32, result);
}

fn alignSize(comptime Int: type, min_size: anytype, alignment: Int) Int {
    const size = @intCast(Int, min_size);
    if (size % alignment == 0) return size;

    const div = size / alignment;
    return (div + 1) * alignment;
}

fn commandSize(min_size: anytype) u32 {
    return alignSize(u32, min_size, @sizeOf(u64));
}

fn addPadding(self: *MachO, size: u64, file_offset: u64) !void {
    if (size == 0) return;

    const buf = try self.base.allocator.alloc(u8, size);
    defer self.base.allocator.free(buf);

    mem.set(u8, buf[0..], 0);

    try self.base.file.?.pwriteAll(buf, file_offset);
}

fn detectAllocCollision(self: *MachO, start: u64, size: u64) ?u64 {
    const hdr_size: u64 = @sizeOf(macho.mach_header_64);
    if (start < hdr_size)
        return hdr_size;

    const end = start + satMul(size, alloc_num) / alloc_den;

    {
        const off = @sizeOf(macho.mach_header_64);
        var tight_size: u64 = 0;
        for (self.load_commands.items) |cmd| {
            tight_size += cmd.cmdsize();
        }
        const increased_size = satMul(tight_size, alloc_num) / alloc_den;
        const test_end = off + increased_size;
        if (end > off and start < test_end) {
            return test_end;
        }
    }

    for (self.sections.items) |section| {
        const increased_size = satMul(section.size, alloc_num) / alloc_den;
        const test_end = section.offset + increased_size;
        if (end > section.offset and start < test_end) {
            return test_end;
        }
    }

    if (self.symtab_cmd_index) |symtab_index| {
        const symtab = self.load_commands.items[symtab_index].Symtab;
        {
            const tight_size = @sizeOf(macho.nlist_64) * symtab.nsyms;
            const increased_size = satMul(tight_size, alloc_num) / alloc_den;
            const test_end = symtab.symoff + increased_size;
            if (end > symtab.symoff and start < test_end) {
                return test_end;
            }
        }
        {
            const increased_size = satMul(symtab.strsize, alloc_num) / alloc_den;
            const test_end = symtab.stroff + increased_size;
            if (end > symtab.stroff and start < test_end) {
                return test_end;
            }
        }
    }

    return null;
}

fn allocatedSize(self: *MachO, start: u64) u64 {
    if (start == 0)
        return 0;
    var min_pos: u64 = std.math.maxInt(u64);
    {
        const off = @sizeOf(macho.mach_header_64);
        if (off > start and off < min_pos) min_pos = off;
    }
    for (self.sections.items) |section| {
        if (section.offset <= start) continue;
        if (section.offset < min_pos) min_pos = section.offset;
    }
    if (self.symtab_cmd_index) |symtab_index| {
        const symtab = self.load_commands.items[symtab_index].Symtab;
        if (symtab.symoff > start and symtab.symoff < min_pos) min_pos = symtab.symoff;
        if (symtab.stroff > start and symtab.stroff < min_pos) min_pos = symtab.stroff;
    }
    return min_pos - start;
}

fn findFreeSpace(self: *MachO, object_size: u64, min_alignment: u16) u64 {
    var start: u64 = 0;
    while (self.detectAllocCollision(start, object_size)) |item_end| {
        start = mem.alignForwardGeneric(u64, item_end, min_alignment);
    }
    return start;
}

fn writeSymbol(self: *MachO, index: usize) !void {
    const tracy = trace(@src());
    defer tracy.end();

    const symtab = &self.load_commands.items[self.symtab_cmd_index.?].Symtab;
    const sym = [1]macho.nlist_64{self.symbol_table.items[index]};
    const off = symtab.symoff + @sizeOf(macho.nlist_64) * index;
    log.debug("writing symbol {} at 0x{x}\n", .{ sym[0], off });
    try self.base.file.?.pwriteAll(mem.sliceAsBytes(sym[0..1]), off);
}

/// Writes Mach-O file header.
/// Should be invoked last as it needs up-to-date values of ncmds and sizeof_cmds bookkeeping
/// variables.
fn writeMachOHeader(self: *MachO) !void {
    var hdr: macho.mach_header_64 = undefined;
    hdr.magic = macho.MH_MAGIC_64;

    const CpuInfo = struct {
        cpu_type: macho.cpu_type_t,
        cpu_subtype: macho.cpu_subtype_t,
    };

    const cpu_info: CpuInfo = switch (self.base.options.target.cpu.arch) {
        .aarch64 => .{
            .cpu_type = macho.CPU_TYPE_ARM64,
            .cpu_subtype = macho.CPU_SUBTYPE_ARM_ALL,
        },
        .x86_64 => .{
            .cpu_type = macho.CPU_TYPE_X86_64,
            .cpu_subtype = macho.CPU_SUBTYPE_X86_64_ALL,
        },
        else => return error.UnsupportedMachOArchitecture,
    };
    hdr.cputype = cpu_info.cpu_type;
    hdr.cpusubtype = cpu_info.cpu_subtype;

    const filetype: u32 = switch (self.base.options.output_mode) {
        .Exe => macho.MH_EXECUTE,
        .Obj => macho.MH_OBJECT,
        .Lib => switch (self.base.options.link_mode) {
            .Static => return error.TODOStaticLibMachOType,
            .Dynamic => macho.MH_DYLIB,
        },
    };
    hdr.filetype = filetype;
    hdr.ncmds = @intCast(u32, self.load_commands.items.len);

    var sizeofcmds: u32 = 0;
    for (self.load_commands.items) |cmd| {
        sizeofcmds += cmd.cmdsize();
    }

    hdr.sizeofcmds = sizeofcmds;

    // TODO should these be set to something else?
    hdr.flags = 0;
    hdr.reserved = 0;

    log.debug("writing Mach-O header {}\n", .{hdr});

    try self.base.file.?.pwriteAll(@ptrCast([*]const u8, &hdr)[0..@sizeOf(macho.mach_header_64)], 0);
}

/// Saturating multiplication
fn satMul(a: anytype, b: anytype) @TypeOf(a, b) {
    const T = @TypeOf(a, b);
    return std.math.mul(T, a, b) catch std.math.maxInt(T);
}

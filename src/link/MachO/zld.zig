const std = @import("std");
const build_options = @import("build_options");
const assert = std.debug.assert;
const dwarf = std.dwarf;
const fs = std.fs;
const log = std.log.scoped(.link);
const macho = std.macho;
const math = std.math;
const mem = std.mem;

const aarch64 = @import("../../arch/aarch64/bits.zig");
const bind = @import("bind.zig");
const link = @import("../../link.zig");
const trace = @import("../../tracy.zig").trace;

const Atom = MachO.Atom;
const Cache = @import("../../Cache.zig");
const CodeSignature = @import("CodeSignature.zig");
const Compilation = @import("../../Compilation.zig");
const Dylib = @import("Dylib.zig");
const MachO = @import("../MachO.zig");
const Object = @import("Object.zig");
const SymbolWithLoc = MachO.SymbolWithLoc;
const Trie = @import("Trie.zig");

const dead_strip = @import("dead_strip.zig");

pub fn linkWithZld(macho_file: *MachO, comp: *Compilation, prog_node: *std.Progress.Node) !void {
    const tracy = trace(@src());
    defer tracy.end();

    const gpa = macho_file.base.allocator;
    var arena_allocator = std.heap.ArenaAllocator.init(gpa);
    defer arena_allocator.deinit();
    const arena = arena_allocator.allocator();

    const directory = macho_file.base.options.emit.?.directory; // Just an alias to make it shorter to type.
    const full_out_path = try directory.join(arena, &[_][]const u8{macho_file.base.options.emit.?.sub_path});

    // If there is no Zig code to compile, then we should skip flushing the output file because it
    // will not be part of the linker line anyway.
    const module_obj_path: ?[]const u8 = if (macho_file.base.options.module) |module| blk: {
        if (macho_file.base.options.use_stage1) {
            const obj_basename = try std.zig.binNameAlloc(arena, .{
                .root_name = macho_file.base.options.root_name,
                .target = macho_file.base.options.target,
                .output_mode = .Obj,
            });
            switch (macho_file.base.options.cache_mode) {
                .incremental => break :blk try module.zig_cache_artifact_directory.join(
                    arena,
                    &[_][]const u8{obj_basename},
                ),
                .whole => break :blk try fs.path.join(arena, &.{
                    fs.path.dirname(full_out_path).?, obj_basename,
                }),
            }
        }

        try macho_file.flushModule(comp, prog_node);

        if (fs.path.dirname(full_out_path)) |dirname| {
            break :blk try fs.path.join(arena, &.{ dirname, macho_file.base.intermediary_basename.? });
        } else {
            break :blk macho_file.base.intermediary_basename.?;
        }
    } else null;

    var sub_prog_node = prog_node.start("MachO Flush", 0);
    sub_prog_node.activate();
    sub_prog_node.context.refresh();
    defer sub_prog_node.end();

    const cpu_arch = macho_file.base.options.target.cpu.arch;
    const os_tag = macho_file.base.options.target.os.tag;
    const abi = macho_file.base.options.target.abi;
    const is_lib = macho_file.base.options.output_mode == .Lib;
    const is_dyn_lib = macho_file.base.options.link_mode == .Dynamic and is_lib;
    const is_exe_or_dyn_lib = is_dyn_lib or macho_file.base.options.output_mode == .Exe;
    const stack_size = macho_file.base.options.stack_size_override orelse 0;
    const is_debug_build = macho_file.base.options.optimize_mode == .Debug;
    const gc_sections = macho_file.base.options.gc_sections orelse !is_debug_build;

    const id_symlink_basename = "zld.id";

    var man: Cache.Manifest = undefined;
    defer if (!macho_file.base.options.disable_lld_caching) man.deinit();

    var digest: [Cache.hex_digest_len]u8 = undefined;

    if (!macho_file.base.options.disable_lld_caching) {
        man = comp.cache_parent.obtain();

        // We are about to obtain this lock, so here we give other processes a chance first.
        macho_file.base.releaseLock();

        comptime assert(Compilation.link_hash_implementation_version == 7);

        for (macho_file.base.options.objects) |obj| {
            _ = try man.addFile(obj.path, null);
            man.hash.add(obj.must_link);
        }
        for (comp.c_object_table.keys()) |key| {
            _ = try man.addFile(key.status.success.object_path, null);
        }
        try man.addOptionalFile(module_obj_path);
        // We can skip hashing libc and libc++ components that we are in charge of building from Zig
        // installation sources because they are always a product of the compiler version + target information.
        man.hash.add(stack_size);
        man.hash.addOptional(macho_file.base.options.pagezero_size);
        man.hash.addOptional(macho_file.base.options.search_strategy);
        man.hash.addOptional(macho_file.base.options.headerpad_size);
        man.hash.add(macho_file.base.options.headerpad_max_install_names);
        man.hash.add(gc_sections);
        man.hash.add(macho_file.base.options.dead_strip_dylibs);
        man.hash.add(macho_file.base.options.strip);
        man.hash.addListOfBytes(macho_file.base.options.lib_dirs);
        man.hash.addListOfBytes(macho_file.base.options.framework_dirs);
        link.hashAddSystemLibs(&man.hash, macho_file.base.options.frameworks);
        man.hash.addListOfBytes(macho_file.base.options.rpath_list);
        if (is_dyn_lib) {
            man.hash.addOptionalBytes(macho_file.base.options.install_name);
            man.hash.addOptional(macho_file.base.options.version);
        }
        link.hashAddSystemLibs(&man.hash, macho_file.base.options.system_libs);
        man.hash.addOptionalBytes(macho_file.base.options.sysroot);
        try man.addOptionalFile(macho_file.base.options.entitlements);

        // We don't actually care whether it's a cache hit or miss; we just need the digest and the lock.
        _ = try man.hit();
        digest = man.final();

        var prev_digest_buf: [digest.len]u8 = undefined;
        const prev_digest: []u8 = Cache.readSmallFile(
            directory.handle,
            id_symlink_basename,
            &prev_digest_buf,
        ) catch |err| blk: {
            log.debug("MachO Zld new_digest={s} error: {s}", .{
                std.fmt.fmtSliceHexLower(&digest),
                @errorName(err),
            });
            // Handle this as a cache miss.
            break :blk prev_digest_buf[0..0];
        };
        if (mem.eql(u8, prev_digest, &digest)) {
            // Hot diggity dog! The output binary is already there.
            log.debug("MachO Zld digest={s} match - skipping invocation", .{
                std.fmt.fmtSliceHexLower(&digest),
            });
            macho_file.base.lock = man.toOwnedLock();
            return;
        }
        log.debug("MachO Zld prev_digest={s} new_digest={s}", .{
            std.fmt.fmtSliceHexLower(prev_digest),
            std.fmt.fmtSliceHexLower(&digest),
        });

        // We are about to change the output file to be different, so we invalidate the build hash now.
        directory.handle.deleteFile(id_symlink_basename) catch |err| switch (err) {
            error.FileNotFound => {},
            else => |e| return e,
        };
    }

    if (macho_file.base.options.output_mode == .Obj) {
        // LLD's MachO driver does not support the equivalent of `-r` so we do a simple file copy
        // here. TODO: think carefully about how we can avoid this redundant operation when doing
        // build-obj. See also the corresponding TODO in linkAsArchive.
        const the_object_path = blk: {
            if (macho_file.base.options.objects.len != 0) {
                break :blk macho_file.base.options.objects[0].path;
            }

            if (comp.c_object_table.count() != 0)
                break :blk comp.c_object_table.keys()[0].status.success.object_path;

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
        const sub_path = macho_file.base.options.emit.?.sub_path;
        if (macho_file.base.file == null) {
            macho_file.base.file = try directory.handle.createFile(sub_path, .{
                .truncate = true,
                .read = true,
                .mode = link.determineMode(macho_file.base.options),
            });
        }
        // Index 0 is always a null symbol.
        try macho_file.locals.append(gpa, .{
            .n_strx = 0,
            .n_type = 0,
            .n_sect = 0,
            .n_desc = 0,
            .n_value = 0,
        });
        try macho_file.strtab.buffer.append(gpa, 0);
        try initSections(macho_file);

        var lib_not_found = false;
        var framework_not_found = false;

        // Positional arguments to the linker such as object files and static archives.
        var positionals = std.ArrayList([]const u8).init(arena);
        try positionals.ensureUnusedCapacity(macho_file.base.options.objects.len);

        var must_link_archives = std.StringArrayHashMap(void).init(arena);
        try must_link_archives.ensureUnusedCapacity(macho_file.base.options.objects.len);

        for (macho_file.base.options.objects) |obj| {
            if (must_link_archives.contains(obj.path)) continue;
            if (obj.must_link) {
                _ = must_link_archives.getOrPutAssumeCapacity(obj.path);
            } else {
                _ = positionals.appendAssumeCapacity(obj.path);
            }
        }

        for (comp.c_object_table.keys()) |key| {
            try positionals.append(key.status.success.object_path);
        }

        if (module_obj_path) |p| {
            try positionals.append(p);
        }

        if (comp.compiler_rt_lib) |lib| {
            try positionals.append(lib.full_object_path);
        }

        // libc++ dep
        if (macho_file.base.options.link_libcpp) {
            try positionals.append(comp.libcxxabi_static_lib.?.full_object_path);
            try positionals.append(comp.libcxx_static_lib.?.full_object_path);
        }

        // Shared and static libraries passed via `-l` flag.
        var candidate_libs = std.StringArrayHashMap(link.SystemLib).init(arena);

        const system_lib_names = macho_file.base.options.system_libs.keys();
        for (system_lib_names) |system_lib_name| {
            // By this time, we depend on these libs being dynamically linked libraries and not static libraries
            // (the check for that needs to be earlier), but they could be full paths to .dylib files, in which
            // case we want to avoid prepending "-l".
            if (Compilation.classifyFileExt(system_lib_name) == .shared_library) {
                try positionals.append(system_lib_name);
                continue;
            }

            const system_lib_info = macho_file.base.options.system_libs.get(system_lib_name).?;
            try candidate_libs.put(system_lib_name, .{
                .needed = system_lib_info.needed,
                .weak = system_lib_info.weak,
            });
        }

        var lib_dirs = std.ArrayList([]const u8).init(arena);
        for (macho_file.base.options.lib_dirs) |dir| {
            if (try MachO.resolveSearchDir(arena, dir, macho_file.base.options.sysroot)) |search_dir| {
                try lib_dirs.append(search_dir);
            } else {
                log.warn("directory not found for '-L{s}'", .{dir});
            }
        }

        var libs = std.StringArrayHashMap(link.SystemLib).init(arena);

        // Assume ld64 default -search_paths_first if no strategy specified.
        const search_strategy = macho_file.base.options.search_strategy orelse .paths_first;
        outer: for (candidate_libs.keys()) |lib_name| {
            switch (search_strategy) {
                .paths_first => {
                    // Look in each directory for a dylib (stub first), and then for archive
                    for (lib_dirs.items) |dir| {
                        for (&[_][]const u8{ ".tbd", ".dylib", ".a" }) |ext| {
                            if (try MachO.resolveLib(arena, dir, lib_name, ext)) |full_path| {
                                try libs.put(full_path, candidate_libs.get(lib_name).?);
                                continue :outer;
                            }
                        }
                    } else {
                        log.warn("library not found for '-l{s}'", .{lib_name});
                        lib_not_found = true;
                    }
                },
                .dylibs_first => {
                    // First, look for a dylib in each search dir
                    for (lib_dirs.items) |dir| {
                        for (&[_][]const u8{ ".tbd", ".dylib" }) |ext| {
                            if (try MachO.resolveLib(arena, dir, lib_name, ext)) |full_path| {
                                try libs.put(full_path, candidate_libs.get(lib_name).?);
                                continue :outer;
                            }
                        }
                    } else for (lib_dirs.items) |dir| {
                        if (try MachO.resolveLib(arena, dir, lib_name, ".a")) |full_path| {
                            try libs.put(full_path, candidate_libs.get(lib_name).?);
                        } else {
                            log.warn("library not found for '-l{s}'", .{lib_name});
                            lib_not_found = true;
                        }
                    }
                },
            }
        }

        if (lib_not_found) {
            log.warn("Library search paths:", .{});
            for (lib_dirs.items) |dir| {
                log.warn("  {s}", .{dir});
            }
        }

        try macho_file.resolveLibSystem(arena, comp, lib_dirs.items, &libs);

        // frameworks
        var framework_dirs = std.ArrayList([]const u8).init(arena);
        for (macho_file.base.options.framework_dirs) |dir| {
            if (try MachO.resolveSearchDir(arena, dir, macho_file.base.options.sysroot)) |search_dir| {
                try framework_dirs.append(search_dir);
            } else {
                log.warn("directory not found for '-F{s}'", .{dir});
            }
        }

        outer: for (macho_file.base.options.frameworks.keys()) |f_name| {
            for (framework_dirs.items) |dir| {
                for (&[_][]const u8{ ".tbd", ".dylib", "" }) |ext| {
                    if (try MachO.resolveFramework(arena, dir, f_name, ext)) |full_path| {
                        const info = macho_file.base.options.frameworks.get(f_name).?;
                        try libs.put(full_path, .{
                            .needed = info.needed,
                            .weak = info.weak,
                        });
                        continue :outer;
                    }
                }
            } else {
                log.warn("framework not found for '-framework {s}'", .{f_name});
                framework_not_found = true;
            }
        }

        if (framework_not_found) {
            log.warn("Framework search paths:", .{});
            for (framework_dirs.items) |dir| {
                log.warn("  {s}", .{dir});
            }
        }

        if (macho_file.base.options.verbose_link) {
            var argv = std.ArrayList([]const u8).init(arena);

            try argv.append("zig");
            try argv.append("ld");

            if (is_exe_or_dyn_lib) {
                try argv.append("-dynamic");
            }

            if (is_dyn_lib) {
                try argv.append("-dylib");

                if (macho_file.base.options.install_name) |install_name| {
                    try argv.append("-install_name");
                    try argv.append(install_name);
                }
            }

            if (macho_file.base.options.sysroot) |syslibroot| {
                try argv.append("-syslibroot");
                try argv.append(syslibroot);
            }

            for (macho_file.base.options.rpath_list) |rpath| {
                try argv.append("-rpath");
                try argv.append(rpath);
            }

            if (macho_file.base.options.pagezero_size) |pagezero_size| {
                try argv.append("-pagezero_size");
                try argv.append(try std.fmt.allocPrint(arena, "0x{x}", .{pagezero_size}));
            }

            if (macho_file.base.options.search_strategy) |strat| switch (strat) {
                .paths_first => try argv.append("-search_paths_first"),
                .dylibs_first => try argv.append("-search_dylibs_first"),
            };

            if (macho_file.base.options.headerpad_size) |headerpad_size| {
                try argv.append("-headerpad_size");
                try argv.append(try std.fmt.allocPrint(arena, "0x{x}", .{headerpad_size}));
            }

            if (macho_file.base.options.headerpad_max_install_names) {
                try argv.append("-headerpad_max_install_names");
            }

            if (gc_sections) {
                try argv.append("-dead_strip");
            }

            if (macho_file.base.options.dead_strip_dylibs) {
                try argv.append("-dead_strip_dylibs");
            }

            if (macho_file.base.options.entry) |entry| {
                try argv.append("-e");
                try argv.append(entry);
            }

            for (macho_file.base.options.objects) |obj| {
                try argv.append(obj.path);
            }

            for (comp.c_object_table.keys()) |key| {
                try argv.append(key.status.success.object_path);
            }

            if (module_obj_path) |p| {
                try argv.append(p);
            }

            if (comp.compiler_rt_lib) |lib| {
                try argv.append(lib.full_object_path);
            }

            if (macho_file.base.options.link_libcpp) {
                try argv.append(comp.libcxxabi_static_lib.?.full_object_path);
                try argv.append(comp.libcxx_static_lib.?.full_object_path);
            }

            try argv.append("-o");
            try argv.append(full_out_path);

            try argv.append("-lSystem");
            try argv.append("-lc");

            for (macho_file.base.options.system_libs.keys()) |l_name| {
                const info = macho_file.base.options.system_libs.get(l_name).?;
                const arg = if (info.needed)
                    try std.fmt.allocPrint(arena, "-needed-l{s}", .{l_name})
                else if (info.weak)
                    try std.fmt.allocPrint(arena, "-weak-l{s}", .{l_name})
                else
                    try std.fmt.allocPrint(arena, "-l{s}", .{l_name});
                try argv.append(arg);
            }

            for (macho_file.base.options.lib_dirs) |lib_dir| {
                try argv.append(try std.fmt.allocPrint(arena, "-L{s}", .{lib_dir}));
            }

            for (macho_file.base.options.frameworks.keys()) |framework| {
                const info = macho_file.base.options.frameworks.get(framework).?;
                const arg = if (info.needed)
                    try std.fmt.allocPrint(arena, "-needed_framework {s}", .{framework})
                else if (info.weak)
                    try std.fmt.allocPrint(arena, "-weak_framework {s}", .{framework})
                else
                    try std.fmt.allocPrint(arena, "-framework {s}", .{framework});
                try argv.append(arg);
            }

            for (macho_file.base.options.framework_dirs) |framework_dir| {
                try argv.append(try std.fmt.allocPrint(arena, "-F{s}", .{framework_dir}));
            }

            if (is_dyn_lib and (macho_file.base.options.allow_shlib_undefined orelse false)) {
                try argv.append("-undefined");
                try argv.append("dynamic_lookup");
            }

            for (must_link_archives.keys()) |lib| {
                try argv.append(try std.fmt.allocPrint(arena, "-force_load {s}", .{lib}));
            }

            Compilation.dump_argv(argv.items);
        }

        var dependent_libs = std.fifo.LinearFifo(struct {
            id: Dylib.Id,
            parent: u16,
        }, .Dynamic).init(arena);

        try macho_file.parseInputFiles(positionals.items, macho_file.base.options.sysroot, &dependent_libs);
        try macho_file.parseAndForceLoadStaticArchives(must_link_archives.keys());
        try macho_file.parseLibs(libs.keys(), libs.values(), macho_file.base.options.sysroot, &dependent_libs);
        try macho_file.parseDependentLibs(macho_file.base.options.sysroot, &dependent_libs);

        for (macho_file.objects.items) |_, object_id| {
            try macho_file.resolveSymbolsInObject(@intCast(u16, object_id));
        }

        try macho_file.resolveSymbolsInArchives();
        try macho_file.resolveDyldStubBinder();
        try macho_file.resolveSymbolsInDylibs();
        try macho_file.createMhExecuteHeaderSymbol();
        try macho_file.createDsoHandleSymbol();
        try macho_file.resolveSymbolsAtLoading();

        if (macho_file.unresolved.count() > 0) {
            return error.UndefinedSymbolReference;
        }
        if (lib_not_found) {
            return error.LibraryNotFound;
        }
        if (framework_not_found) {
            return error.FrameworkNotFound;
        }

        for (macho_file.objects.items) |*object| {
            try object.scanInputSections(macho_file);
        }

        try macho_file.createDyldPrivateAtom();
        try macho_file.createTentativeDefAtoms();
        try macho_file.createStubHelperPreambleAtom();

        for (macho_file.objects.items) |*object, object_id| {
            try object.splitIntoAtoms(macho_file, @intCast(u32, object_id));
        }

        if (gc_sections) {
            try dead_strip.gcAtoms(macho_file);
        }

        try allocateSegments(macho_file);
        try allocateSymbols(macho_file);

        try macho_file.allocateSpecialSymbols();

        if (build_options.enable_logging or true) {
            macho_file.logSymtab();
            macho_file.logSections();
            macho_file.logAtoms();
        }

        try writeAtoms(macho_file);

        var lc_buffer = std.ArrayList(u8).init(arena);
        const lc_writer = lc_buffer.writer();
        var ncmds: u32 = 0;

        try writeLinkeditSegmentData(macho_file, &ncmds, lc_writer);

        // If the last section of __DATA segment is zerofill section, we need to ensure
        // that the free space between the end of the last non-zerofill section of __DATA
        // segment and the beginning of __LINKEDIT segment is zerofilled as the loader will
        // copy-paste this space into memory for quicker zerofill operation.
        if (macho_file.data_segment_cmd_index) |data_seg_id| blk: {
            var physical_zerofill_start: u64 = 0;
            const section_indexes = macho_file.getSectionIndexes(data_seg_id);
            for (macho_file.sections.items(.header)[section_indexes.start..section_indexes.end]) |header| {
                if (header.isZerofill() and header.size > 0) break;
                physical_zerofill_start = header.offset + header.size;
            } else break :blk;
            const linkedit = macho_file.segments.items[macho_file.linkedit_segment_cmd_index.?];
            const physical_zerofill_size = math.cast(usize, linkedit.fileoff - physical_zerofill_start) orelse
                return error.Overflow;
            if (physical_zerofill_size > 0) {
                var padding = try macho_file.base.allocator.alloc(u8, physical_zerofill_size);
                defer macho_file.base.allocator.free(padding);
                mem.set(u8, padding, 0);
                try macho_file.base.file.?.pwriteAll(padding, physical_zerofill_start);
            }
        }

        try MachO.writeDylinkerLC(&ncmds, lc_writer);
        try macho_file.writeMainLC(&ncmds, lc_writer);
        try macho_file.writeDylibIdLC(&ncmds, lc_writer);
        try macho_file.writeRpathLCs(&ncmds, lc_writer);

        {
            try lc_writer.writeStruct(macho.source_version_command{
                .cmdsize = @sizeOf(macho.source_version_command),
                .version = 0x0,
            });
            ncmds += 1;
        }

        try macho_file.writeBuildVersionLC(&ncmds, lc_writer);

        {
            var uuid_lc = macho.uuid_command{
                .cmdsize = @sizeOf(macho.uuid_command),
                .uuid = undefined,
            };
            std.crypto.random.bytes(&uuid_lc.uuid);
            try lc_writer.writeStruct(uuid_lc);
            ncmds += 1;
        }

        try macho_file.writeLoadDylibLCs(&ncmds, lc_writer);

        const requires_codesig = blk: {
            if (macho_file.base.options.entitlements) |_| break :blk true;
            if (cpu_arch == .aarch64 and (os_tag == .macos or abi == .simulator)) break :blk true;
            break :blk false;
        };
        var codesig_offset: ?u32 = null;
        var codesig: ?CodeSignature = if (requires_codesig) blk: {
            // Preallocate space for the code signature.
            // We need to do this at this stage so that we have the load commands with proper values
            // written out to the file.
            // The most important here is to have the correct vm and filesize of the __LINKEDIT segment
            // where the code signature goes into.
            var codesig = CodeSignature.init(macho_file.page_size);
            codesig.code_directory.ident = macho_file.base.options.emit.?.sub_path;
            if (macho_file.base.options.entitlements) |path| {
                try codesig.addEntitlements(arena, path);
            }
            codesig_offset = try writeCodeSignaturePadding(macho_file, &codesig, &ncmds, lc_writer);
            break :blk codesig;
        } else null;

        var headers_buf = std.ArrayList(u8).init(arena);
        try writeSegmentHeaders(macho_file, &ncmds, headers_buf.writer());

        try macho_file.base.file.?.pwriteAll(headers_buf.items, @sizeOf(macho.mach_header_64));
        try macho_file.base.file.?.pwriteAll(lc_buffer.items, @sizeOf(macho.mach_header_64) + headers_buf.items.len);

        try writeHeader(macho_file, ncmds, @intCast(u32, lc_buffer.items.len + headers_buf.items.len));

        if (codesig) |*csig| {
            try writeCodeSignature(macho_file, csig, codesig_offset.?); // code signing always comes last
        }
    }

    if (!macho_file.base.options.disable_lld_caching) {
        // Update the file with the digest. If it fails we can continue; it only
        // means that the next invocation will have an unnecessary cache miss.
        Cache.writeSmallFile(directory.handle, id_symlink_basename, &digest) catch |err| {
            log.debug("failed to save linking hash digest file: {s}", .{@errorName(err)});
        };
        // Again failure here only means an unnecessary cache miss.
        man.writeManifest() catch |err| {
            log.debug("failed to write cache manifest when linking: {s}", .{@errorName(err)});
        };
        // We hang on to this lock so that the output file path can be used without
        // other processes clobbering it.
        macho_file.base.lock = man.toOwnedLock();
    }
}

fn initSections(macho_file: *MachO) !void {
    const gpa = macho_file.base.allocator;
    const cpu_arch = macho_file.base.options.target.cpu.arch;
    const pagezero_vmsize = macho_file.calcPagezeroSize();

    if (macho_file.pagezero_segment_cmd_index == null) {
        if (pagezero_vmsize > 0) {
            macho_file.pagezero_segment_cmd_index = @intCast(u8, macho_file.segments.items.len);
            try macho_file.segments.append(gpa, .{
                .segname = MachO.makeStaticString("__PAGEZERO"),
                .vmsize = pagezero_vmsize,
                .cmdsize = @sizeOf(macho.segment_command_64),
            });
        }
    }

    if (macho_file.text_segment_cmd_index == null) {
        macho_file.text_segment_cmd_index = @intCast(u8, macho_file.segments.items.len);
        try macho_file.segments.append(gpa, .{
            .segname = MachO.makeStaticString("__TEXT"),
            .vmaddr = pagezero_vmsize,
            .vmsize = 0,
            .filesize = 0,
            .maxprot = macho.PROT.READ | macho.PROT.EXEC,
            .initprot = macho.PROT.READ | macho.PROT.EXEC,
            .cmdsize = @sizeOf(macho.segment_command_64),
        });
    }

    if (macho_file.text_section_index == null) {
        macho_file.text_section_index = try macho_file.initSection("__TEXT", "__text", .{
            .flags = macho.S_REGULAR | macho.S_ATTR_PURE_INSTRUCTIONS | macho.S_ATTR_SOME_INSTRUCTIONS,
        });
    }

    if (macho_file.stubs_section_index == null) {
        const stub_size: u4 = switch (cpu_arch) {
            .x86_64 => 6,
            .aarch64 => 3 * @sizeOf(u32),
            else => unreachable, // unhandled architecture type
        };
        macho_file.stubs_section_index = try macho_file.initSection("__TEXT", "__stubs", .{
            .flags = macho.S_SYMBOL_STUBS | macho.S_ATTR_PURE_INSTRUCTIONS | macho.S_ATTR_SOME_INSTRUCTIONS,
            .reserved2 = stub_size,
        });
    }

    if (macho_file.stub_helper_section_index == null) {
        macho_file.stub_helper_section_index = try macho_file.initSection("__TEXT", "__stub_helper", .{
            .flags = macho.S_REGULAR | macho.S_ATTR_PURE_INSTRUCTIONS | macho.S_ATTR_SOME_INSTRUCTIONS,
        });
    }

    if (macho_file.data_const_segment_cmd_index == null) {
        macho_file.data_const_segment_cmd_index = @intCast(u8, macho_file.segments.items.len);
        try macho_file.segments.append(gpa, .{
            .segname = MachO.makeStaticString("__DATA_CONST"),
            .vmaddr = 0,
            .vmsize = 0,
            .fileoff = 0,
            .filesize = 0,
            .maxprot = macho.PROT.READ | macho.PROT.WRITE,
            .initprot = macho.PROT.READ | macho.PROT.WRITE,
            .cmdsize = @sizeOf(macho.segment_command_64),
        });
    }

    if (macho_file.got_section_index == null) {
        macho_file.got_section_index = try macho_file.initSection("__DATA_CONST", "__got", .{
            .flags = macho.S_NON_LAZY_SYMBOL_POINTERS,
        });
    }

    if (macho_file.data_segment_cmd_index == null) {
        macho_file.data_segment_cmd_index = @intCast(u8, macho_file.segments.items.len);
        try macho_file.segments.append(gpa, .{
            .segname = MachO.makeStaticString("__DATA"),
            .vmaddr = 0,
            .vmsize = 0,
            .fileoff = 0,
            .filesize = 0,
            .maxprot = macho.PROT.READ | macho.PROT.WRITE,
            .initprot = macho.PROT.READ | macho.PROT.WRITE,
            .cmdsize = @sizeOf(macho.segment_command_64),
        });
    }

    if (macho_file.la_symbol_ptr_section_index == null) {
        macho_file.la_symbol_ptr_section_index = try macho_file.initSection("__DATA", "__la_symbol_ptr", .{
            .flags = macho.S_LAZY_SYMBOL_POINTERS,
        });
    }

    if (macho_file.data_section_index == null) {
        macho_file.data_section_index = try macho_file.initSection("__DATA", "__data", .{});
    }

    if (macho_file.linkedit_segment_cmd_index == null) {
        macho_file.linkedit_segment_cmd_index = @intCast(u8, macho_file.segments.items.len);
        try macho_file.segments.append(gpa, .{
            .segname = MachO.makeStaticString("__LINKEDIT"),
            .vmaddr = 0,
            .fileoff = 0,
            .maxprot = macho.PROT.READ,
            .initprot = macho.PROT.READ,
            .cmdsize = @sizeOf(macho.segment_command_64),
        });
    }
}

fn writeAtoms(macho_file: *MachO) !void {
    assert(macho_file.mode == .one_shot);

    const gpa = macho_file.base.allocator;
    const slice = macho_file.sections.slice();

    for (slice.items(.last_atom)) |last_atom, sect_id| {
        const header = slice.items(.header)[sect_id];
        if (header.size == 0) continue;
        var atom = last_atom.?;

        if (header.isZerofill()) continue;

        var buffer = std.ArrayList(u8).init(gpa);
        defer buffer.deinit();
        try buffer.ensureTotalCapacity(math.cast(usize, header.size) orelse return error.Overflow);

        log.debug("writing atoms in {s},{s}", .{ header.segName(), header.sectName() });

        while (atom.prev) |prev| {
            atom = prev;
        }

        while (true) {
            const this_sym = atom.getSymbol(macho_file);
            const padding_size: usize = if (atom.next) |next| blk: {
                const next_sym = next.getSymbol(macho_file);
                const size = next_sym.n_value - (this_sym.n_value + atom.size);
                break :blk math.cast(usize, size) orelse return error.Overflow;
            } else 0;

            log.debug("  (adding ATOM(%{d}, '{s}') from object({?d}) to buffer)", .{
                atom.sym_index,
                atom.getName(macho_file),
                atom.file,
            });
            if (padding_size > 0) {
                log.debug("    (with padding {x})", .{padding_size});
            }

            try atom.resolveRelocs(macho_file);
            buffer.appendSliceAssumeCapacity(atom.code.items);

            var i: usize = 0;
            while (i < padding_size) : (i += 1) {
                // TODO with NOPs
                buffer.appendAssumeCapacity(0);
            }

            if (atom.next) |next| {
                atom = next;
            } else {
                assert(buffer.items.len == header.size);
                log.debug("  (writing at file offset 0x{x})", .{header.offset});
                try macho_file.base.file.?.pwriteAll(buffer.items, header.offset);
                break;
            }
        }
    }
}

fn allocateSegments(macho_file: *MachO) !void {
    try allocateSegment(macho_file, macho_file.text_segment_cmd_index, &.{
        macho_file.pagezero_segment_cmd_index,
    }, try macho_file.calcMinHeaderPad());

    if (macho_file.text_segment_cmd_index) |index| blk: {
        const indexes = macho_file.getSectionIndexes(index);
        if (indexes.start == indexes.end) break :blk;
        const seg = macho_file.segments.items[index];

        // Shift all sections to the back to minimize jump size between __TEXT and __DATA segments.
        var min_alignment: u32 = 0;
        for (macho_file.sections.items(.header)[indexes.start..indexes.end]) |header| {
            const alignment = try math.powi(u32, 2, header.@"align");
            min_alignment = math.max(min_alignment, alignment);
        }

        assert(min_alignment > 0);
        const last_header = macho_file.sections.items(.header)[indexes.end - 1];
        const shift: u32 = shift: {
            const diff = seg.filesize - last_header.offset - last_header.size;
            const factor = @divTrunc(diff, min_alignment);
            break :shift @intCast(u32, factor * min_alignment);
        };

        if (shift > 0) {
            for (macho_file.sections.items(.header)[indexes.start..indexes.end]) |*header| {
                header.offset += shift;
                header.addr += shift;
            }
        }
    }

    try allocateSegment(macho_file, macho_file.data_const_segment_cmd_index, &.{
        macho_file.text_segment_cmd_index,
        macho_file.pagezero_segment_cmd_index,
    }, 0);

    try allocateSegment(macho_file, macho_file.data_segment_cmd_index, &.{
        macho_file.data_const_segment_cmd_index,
        macho_file.text_segment_cmd_index,
        macho_file.pagezero_segment_cmd_index,
    }, 0);

    try allocateSegment(macho_file, macho_file.linkedit_segment_cmd_index, &.{
        macho_file.data_segment_cmd_index,
        macho_file.data_const_segment_cmd_index,
        macho_file.text_segment_cmd_index,
        macho_file.pagezero_segment_cmd_index,
    }, 0);
}

fn getSegmentAllocBase(macho_file: *MachO, indices: []const ?u8) struct { vmaddr: u64, fileoff: u64 } {
    for (indices) |maybe_prev_id| {
        const prev_id = maybe_prev_id orelse continue;
        const prev = macho_file.segments.items[prev_id];
        return .{
            .vmaddr = prev.vmaddr + prev.vmsize,
            .fileoff = prev.fileoff + prev.filesize,
        };
    }
    return .{ .vmaddr = 0, .fileoff = 0 };
}

fn allocateSegment(macho_file: *MachO, maybe_index: ?u8, indices: []const ?u8, init_size: u64) !void {
    const index = maybe_index orelse return;
    const seg = &macho_file.segments.items[index];

    const base = getSegmentAllocBase(macho_file, indices);
    seg.vmaddr = base.vmaddr;
    seg.fileoff = base.fileoff;
    seg.filesize = init_size;
    seg.vmsize = init_size;

    // Allocate the sections according to their alignment at the beginning of the segment.
    const indexes = macho_file.getSectionIndexes(index);
    var start = init_size;
    const slice = macho_file.sections.slice();
    for (slice.items(.header)[indexes.start..indexes.end]) |*header| {
        const alignment = try math.powi(u32, 2, header.@"align");
        const start_aligned = mem.alignForwardGeneric(u64, start, alignment);

        header.offset = if (header.isZerofill())
            0
        else
            @intCast(u32, seg.fileoff + start_aligned);
        header.addr = seg.vmaddr + start_aligned;

        start = start_aligned + header.size;

        if (!header.isZerofill()) {
            seg.filesize = start;
        }
        seg.vmsize = start;
    }

    seg.filesize = mem.alignForwardGeneric(u64, seg.filesize, macho_file.page_size);
    seg.vmsize = mem.alignForwardGeneric(u64, seg.vmsize, macho_file.page_size);
}

fn allocateSymbols(macho_file: *MachO) !void {
    const slice = macho_file.sections.slice();
    for (slice.items(.last_atom)) |last_atom, sect_id| {
        const header = slice.items(.header)[sect_id];
        var atom = last_atom orelse continue;

        while (atom.prev) |prev| {
            atom = prev;
        }

        const n_sect = @intCast(u8, sect_id + 1);
        var base_vaddr = header.addr;

        log.debug("allocating local symbols in sect({d}, '{s},{s}')", .{
            n_sect,
            header.segName(),
            header.sectName(),
        });

        while (true) {
            const alignment = try math.powi(u32, 2, atom.alignment);
            base_vaddr = mem.alignForwardGeneric(u64, base_vaddr, alignment);

            const sym = atom.getSymbolPtr(macho_file);
            sym.n_value = base_vaddr;
            sym.n_sect = n_sect;

            log.debug("  ATOM(%{d}, '{s}') @{x}", .{ atom.sym_index, atom.getName(macho_file), base_vaddr });

            // Update each symbol contained within the atom
            for (atom.contained.items) |sym_at_off| {
                const contained_sym = macho_file.getSymbolPtr(.{
                    .sym_index = sym_at_off.sym_index,
                    .file = atom.file,
                });
                contained_sym.n_value = base_vaddr + sym_at_off.offset;
                contained_sym.n_sect = n_sect;
            }

            base_vaddr += atom.size;

            if (atom.next) |next| {
                atom = next;
            } else break;
        }
    }
}

fn writeLinkeditSegmentData(macho_file: *MachO, ncmds: *u32, lc_writer: anytype) !void {
    const seg = &macho_file.segments.items[macho_file.linkedit_segment_cmd_index.?];
    seg.filesize = 0;
    seg.vmsize = 0;

    try writeDyldInfoData(macho_file, ncmds, lc_writer);
    try writeFunctionStarts(macho_file, ncmds, lc_writer);
    try writeDataInCode(macho_file, ncmds, lc_writer);
    try writeSymtabs(macho_file, ncmds, lc_writer);

    seg.vmsize = mem.alignForwardGeneric(u64, seg.filesize, macho_file.page_size);
}

fn writeDyldInfoData(macho_file: *MachO, ncmds: *u32, lc_writer: anytype) !void {
    const tracy = trace(@src());
    defer tracy.end();

    const gpa = macho_file.base.allocator;

    var rebase_pointers = std.ArrayList(bind.Pointer).init(gpa);
    defer rebase_pointers.deinit();
    var bind_pointers = std.ArrayList(bind.Pointer).init(gpa);
    defer bind_pointers.deinit();
    var lazy_bind_pointers = std.ArrayList(bind.Pointer).init(gpa);
    defer lazy_bind_pointers.deinit();

    const slice = macho_file.sections.slice();
    for (slice.items(.last_atom)) |last_atom, sect_id| {
        var atom = last_atom orelse continue;
        const segment_index = slice.items(.segment_index)[sect_id];
        const header = slice.items(.header)[sect_id];

        if (mem.eql(u8, header.segName(), "__TEXT")) continue; // __TEXT is non-writable

        log.debug("dyld info for {s},{s}", .{ header.segName(), header.sectName() });

        const seg = macho_file.segments.items[segment_index];

        while (true) {
            log.debug("  ATOM(%{d}, '{s}')", .{ atom.sym_index, atom.getName(macho_file) });
            const sym = atom.getSymbol(macho_file);
            const base_offset = sym.n_value - seg.vmaddr;

            for (atom.rebases.items) |offset| {
                log.debug("    | rebase at {x}", .{base_offset + offset});
                try rebase_pointers.append(.{
                    .offset = base_offset + offset,
                    .segment_id = segment_index,
                });
            }

            for (atom.bindings.items) |binding| {
                const bind_sym = macho_file.getSymbol(binding.target);
                const bind_sym_name = macho_file.getSymbolName(binding.target);
                const dylib_ordinal = @divTrunc(
                    @bitCast(i16, bind_sym.n_desc),
                    macho.N_SYMBOL_RESOLVER,
                );
                var flags: u4 = 0;
                log.debug("    | bind at {x}, import('{s}') in dylib({d})", .{
                    binding.offset + base_offset,
                    bind_sym_name,
                    dylib_ordinal,
                });
                if (bind_sym.weakRef()) {
                    log.debug("    | marking as weak ref ", .{});
                    flags |= @truncate(u4, macho.BIND_SYMBOL_FLAGS_WEAK_IMPORT);
                }
                try bind_pointers.append(.{
                    .offset = binding.offset + base_offset,
                    .segment_id = segment_index,
                    .dylib_ordinal = dylib_ordinal,
                    .name = bind_sym_name,
                    .bind_flags = flags,
                });
            }

            for (atom.lazy_bindings.items) |binding| {
                const bind_sym = macho_file.getSymbol(binding.target);
                const bind_sym_name = macho_file.getSymbolName(binding.target);
                const dylib_ordinal = @divTrunc(
                    @bitCast(i16, bind_sym.n_desc),
                    macho.N_SYMBOL_RESOLVER,
                );
                var flags: u4 = 0;
                log.debug("    | lazy bind at {x} import('{s}') ord({d})", .{
                    binding.offset + base_offset,
                    bind_sym_name,
                    dylib_ordinal,
                });
                if (bind_sym.weakRef()) {
                    log.debug("    | marking as weak ref ", .{});
                    flags |= @truncate(u4, macho.BIND_SYMBOL_FLAGS_WEAK_IMPORT);
                }
                try lazy_bind_pointers.append(.{
                    .offset = binding.offset + base_offset,
                    .segment_id = segment_index,
                    .dylib_ordinal = dylib_ordinal,
                    .name = bind_sym_name,
                    .bind_flags = flags,
                });
            }

            if (atom.prev) |prev| {
                atom = prev;
            } else break;
        }
    }

    var trie: Trie = .{};
    defer trie.deinit(gpa);

    {
        // TODO handle macho.EXPORT_SYMBOL_FLAGS_REEXPORT and macho.EXPORT_SYMBOL_FLAGS_STUB_AND_RESOLVER.
        log.debug("generating export trie", .{});

        const text_segment = macho_file.segments.items[macho_file.text_segment_cmd_index.?];
        const base_address = text_segment.vmaddr;

        if (macho_file.base.options.output_mode == .Exe) {
            for (&[_]SymbolWithLoc{
                try macho_file.getEntryPoint(),
                macho_file.getGlobal("__mh_execute_header").?,
            }) |global| {
                const sym = macho_file.getSymbol(global);
                const sym_name = macho_file.getSymbolName(global);
                log.debug("  (putting '{s}' defined at 0x{x})", .{ sym_name, sym.n_value });
                try trie.put(gpa, .{
                    .name = sym_name,
                    .vmaddr_offset = sym.n_value - base_address,
                    .export_flags = macho.EXPORT_SYMBOL_FLAGS_KIND_REGULAR,
                });
            }
        } else {
            assert(macho_file.base.options.output_mode == .Lib);
            for (macho_file.globals.items) |global| {
                const sym = macho_file.getSymbol(global);

                if (sym.undf()) continue;
                if (!sym.ext()) continue;
                if (sym.n_desc == MachO.N_DESC_GCED) continue;

                const sym_name = macho_file.getSymbolName(global);
                log.debug("  (putting '{s}' defined at 0x{x})", .{ sym_name, sym.n_value });
                try trie.put(gpa, .{
                    .name = sym_name,
                    .vmaddr_offset = sym.n_value - base_address,
                    .export_flags = macho.EXPORT_SYMBOL_FLAGS_KIND_REGULAR,
                });
            }
        }

        try trie.finalize(gpa);
    }

    const link_seg = &macho_file.segments.items[macho_file.linkedit_segment_cmd_index.?];
    const rebase_off = mem.alignForwardGeneric(u64, link_seg.fileoff, @alignOf(u64));
    assert(rebase_off == link_seg.fileoff);
    const rebase_size = try bind.rebaseInfoSize(rebase_pointers.items);
    log.debug("writing rebase info from 0x{x} to 0x{x}", .{ rebase_off, rebase_off + rebase_size });

    const bind_off = mem.alignForwardGeneric(u64, rebase_off + rebase_size, @alignOf(u64));
    const bind_size = try bind.bindInfoSize(bind_pointers.items);
    log.debug("writing bind info from 0x{x} to 0x{x}", .{ bind_off, bind_off + bind_size });

    const lazy_bind_off = mem.alignForwardGeneric(u64, bind_off + bind_size, @alignOf(u64));
    const lazy_bind_size = try bind.lazyBindInfoSize(lazy_bind_pointers.items);
    log.debug("writing lazy bind info from 0x{x} to 0x{x}", .{ lazy_bind_off, lazy_bind_off + lazy_bind_size });

    const export_off = mem.alignForwardGeneric(u64, lazy_bind_off + lazy_bind_size, @alignOf(u64));
    const export_size = trie.size;
    log.debug("writing export trie from 0x{x} to 0x{x}", .{ export_off, export_off + export_size });

    const needed_size = export_off + export_size - rebase_off;
    link_seg.filesize = needed_size;

    var buffer = try gpa.alloc(u8, math.cast(usize, needed_size) orelse return error.Overflow);
    defer gpa.free(buffer);
    mem.set(u8, buffer, 0);

    var stream = std.io.fixedBufferStream(buffer);
    const writer = stream.writer();

    try bind.writeRebaseInfo(rebase_pointers.items, writer);
    try stream.seekTo(bind_off - rebase_off);

    try bind.writeBindInfo(bind_pointers.items, writer);
    try stream.seekTo(lazy_bind_off - rebase_off);

    try bind.writeLazyBindInfo(lazy_bind_pointers.items, writer);
    try stream.seekTo(export_off - rebase_off);

    _ = try trie.write(writer);

    log.debug("writing dyld info from 0x{x} to 0x{x}", .{
        rebase_off,
        rebase_off + needed_size,
    });

    try macho_file.base.file.?.pwriteAll(buffer, rebase_off);
    const start = math.cast(usize, lazy_bind_off - rebase_off) orelse return error.Overflow;
    const end = start + (math.cast(usize, lazy_bind_size) orelse return error.Overflow);
    try populateLazyBindOffsetsInStubHelper(macho_file, buffer[start..end]);

    try lc_writer.writeStruct(macho.dyld_info_command{
        .cmd = .DYLD_INFO_ONLY,
        .cmdsize = @sizeOf(macho.dyld_info_command),
        .rebase_off = @intCast(u32, rebase_off),
        .rebase_size = @intCast(u32, rebase_size),
        .bind_off = @intCast(u32, bind_off),
        .bind_size = @intCast(u32, bind_size),
        .weak_bind_off = 0,
        .weak_bind_size = 0,
        .lazy_bind_off = @intCast(u32, lazy_bind_off),
        .lazy_bind_size = @intCast(u32, lazy_bind_size),
        .export_off = @intCast(u32, export_off),
        .export_size = @intCast(u32, export_size),
    });
    ncmds.* += 1;
}

fn populateLazyBindOffsetsInStubHelper(macho_file: *MachO, buffer: []const u8) !void {
    const gpa = macho_file.base.allocator;

    const stub_helper_section_index = macho_file.stub_helper_section_index orelse return;
    if (macho_file.stub_helper_preamble_atom == null) return;

    const section = macho_file.sections.get(stub_helper_section_index);
    const last_atom = section.last_atom orelse return;
    if (last_atom == macho_file.stub_helper_preamble_atom.?) return; // TODO is this a redundant check?

    var table = std.AutoHashMap(i64, *Atom).init(gpa);
    defer table.deinit();

    {
        var stub_atom = last_atom;
        var laptr_atom = macho_file.sections.items(.last_atom)[macho_file.la_symbol_ptr_section_index.?].?;
        const base_addr = blk: {
            const seg = macho_file.segments.items[macho_file.data_segment_cmd_index.?];
            break :blk seg.vmaddr;
        };

        while (true) {
            const laptr_off = blk: {
                const sym = laptr_atom.getSymbol(macho_file);
                break :blk @intCast(i64, sym.n_value - base_addr);
            };
            try table.putNoClobber(laptr_off, stub_atom);
            if (laptr_atom.prev) |prev| {
                laptr_atom = prev;
                stub_atom = stub_atom.prev.?;
            } else break;
        }
    }

    var stream = std.io.fixedBufferStream(buffer);
    var reader = stream.reader();
    var offsets = std.ArrayList(struct { sym_offset: i64, offset: u32 }).init(gpa);
    try offsets.append(.{ .sym_offset = undefined, .offset = 0 });
    defer offsets.deinit();
    var valid_block = false;

    while (true) {
        const inst = reader.readByte() catch |err| switch (err) {
            error.EndOfStream => break,
        };
        const opcode: u8 = inst & macho.BIND_OPCODE_MASK;

        switch (opcode) {
            macho.BIND_OPCODE_DO_BIND => {
                valid_block = true;
            },
            macho.BIND_OPCODE_DONE => {
                if (valid_block) {
                    const offset = try stream.getPos();
                    try offsets.append(.{ .sym_offset = undefined, .offset = @intCast(u32, offset) });
                }
                valid_block = false;
            },
            macho.BIND_OPCODE_SET_SYMBOL_TRAILING_FLAGS_IMM => {
                var next = try reader.readByte();
                while (next != @as(u8, 0)) {
                    next = try reader.readByte();
                }
            },
            macho.BIND_OPCODE_SET_SEGMENT_AND_OFFSET_ULEB => {
                var inserted = offsets.pop();
                inserted.sym_offset = try std.leb.readILEB128(i64, reader);
                try offsets.append(inserted);
            },
            macho.BIND_OPCODE_SET_DYLIB_ORDINAL_ULEB => {
                _ = try std.leb.readULEB128(u64, reader);
            },
            macho.BIND_OPCODE_SET_ADDEND_SLEB => {
                _ = try std.leb.readILEB128(i64, reader);
            },
            else => {},
        }
    }

    const header = macho_file.sections.items(.header)[stub_helper_section_index];
    const stub_offset: u4 = switch (macho_file.base.options.target.cpu.arch) {
        .x86_64 => 1,
        .aarch64 => 2 * @sizeOf(u32),
        else => unreachable,
    };
    var buf: [@sizeOf(u32)]u8 = undefined;
    _ = offsets.pop();

    while (offsets.popOrNull()) |bind_offset| {
        const atom = table.get(bind_offset.sym_offset).?;
        const sym = atom.getSymbol(macho_file);
        const file_offset = header.offset + sym.n_value - header.addr + stub_offset;
        mem.writeIntLittle(u32, &buf, bind_offset.offset);
        log.debug("writing lazy bind offset in stub helper of 0x{x} for symbol {s} at offset 0x{x}", .{
            bind_offset.offset,
            atom.getName(macho_file),
            file_offset,
        });
        try macho_file.base.file.?.pwriteAll(&buf, file_offset);
    }
}

const asc_u64 = std.sort.asc(u64);

fn writeFunctionStarts(macho_file: *MachO, ncmds: *u32, lc_writer: anytype) !void {
    const tracy = trace(@src());
    defer tracy.end();

    const text_seg_index = macho_file.text_segment_cmd_index orelse return;
    const text_sect_index = macho_file.text_section_index orelse return;
    const text_seg = macho_file.segments.items[text_seg_index];

    const gpa = macho_file.base.allocator;

    // We need to sort by address first
    var addresses = std.ArrayList(u64).init(gpa);
    defer addresses.deinit();
    try addresses.ensureTotalCapacityPrecise(macho_file.globals.items.len);

    for (macho_file.globals.items) |global| {
        const sym = macho_file.getSymbol(global);
        if (sym.undf()) continue;
        if (sym.n_desc == MachO.N_DESC_GCED) continue;
        const sect_id = sym.n_sect - 1;
        if (sect_id != text_sect_index) continue;

        addresses.appendAssumeCapacity(sym.n_value);
    }

    std.sort.sort(u64, addresses.items, {}, asc_u64);

    var offsets = std.ArrayList(u32).init(gpa);
    defer offsets.deinit();
    try offsets.ensureTotalCapacityPrecise(addresses.items.len);

    var last_off: u32 = 0;
    for (addresses.items) |addr| {
        const offset = @intCast(u32, addr - text_seg.vmaddr);
        const diff = offset - last_off;

        if (diff == 0) continue;

        offsets.appendAssumeCapacity(diff);
        last_off = offset;
    }

    var buffer = std.ArrayList(u8).init(gpa);
    defer buffer.deinit();

    const max_size = @intCast(usize, offsets.items.len * @sizeOf(u64));
    try buffer.ensureTotalCapacity(max_size);

    for (offsets.items) |offset| {
        try std.leb.writeULEB128(buffer.writer(), offset);
    }

    const link_seg = &macho_file.segments.items[macho_file.linkedit_segment_cmd_index.?];
    const offset = mem.alignForwardGeneric(u64, link_seg.fileoff + link_seg.filesize, @alignOf(u64));
    const needed_size = buffer.items.len;
    link_seg.filesize = offset + needed_size - link_seg.fileoff;

    log.debug("writing function starts info from 0x{x} to 0x{x}", .{ offset, offset + needed_size });

    try macho_file.base.file.?.pwriteAll(buffer.items, offset);

    try lc_writer.writeStruct(macho.linkedit_data_command{
        .cmd = .FUNCTION_STARTS,
        .cmdsize = @sizeOf(macho.linkedit_data_command),
        .dataoff = @intCast(u32, offset),
        .datasize = @intCast(u32, needed_size),
    });
    ncmds.* += 1;
}

fn filterDataInCode(
    dices: []align(1) const macho.data_in_code_entry,
    start_addr: u64,
    end_addr: u64,
) []align(1) const macho.data_in_code_entry {
    const Predicate = struct {
        addr: u64,

        pub fn predicate(macho_file: @This(), dice: macho.data_in_code_entry) bool {
            return dice.offset >= macho_file.addr;
        }
    };

    const start = MachO.findFirst(macho.data_in_code_entry, dices, 0, Predicate{ .addr = start_addr });
    const end = MachO.findFirst(macho.data_in_code_entry, dices, start, Predicate{ .addr = end_addr });

    return dices[start..end];
}

fn writeDataInCode(macho_file: *MachO, ncmds: *u32, lc_writer: anytype) !void {
    const tracy = trace(@src());
    defer tracy.end();

    var out_dice = std.ArrayList(macho.data_in_code_entry).init(macho_file.base.allocator);
    defer out_dice.deinit();

    const text_sect_id = macho_file.text_section_index orelse return;
    const text_sect_header = macho_file.sections.items(.header)[text_sect_id];

    for (macho_file.objects.items) |object| {
        const dice = object.parseDataInCode() orelse continue;
        try out_dice.ensureUnusedCapacity(dice.len);

        for (object.managed_atoms.items) |atom| {
            const sym = atom.getSymbol(macho_file);
            if (sym.n_desc == MachO.N_DESC_GCED) continue;

            const sect_id = sym.n_sect - 1;
            if (sect_id != macho_file.text_section_index.?) {
                continue;
            }

            const source_sym = object.getSourceSymbol(atom.sym_index) orelse continue;
            const source_addr = math.cast(u32, source_sym.n_value) orelse return error.Overflow;
            const filtered_dice = filterDataInCode(dice, source_addr, source_addr + atom.size);
            const base = math.cast(u32, sym.n_value - text_sect_header.addr + text_sect_header.offset) orelse
                return error.Overflow;

            for (filtered_dice) |single| {
                const offset = single.offset - source_addr + base;
                out_dice.appendAssumeCapacity(.{
                    .offset = offset,
                    .length = single.length,
                    .kind = single.kind,
                });
            }
        }
    }

    const seg = &macho_file.segments.items[macho_file.linkedit_segment_cmd_index.?];
    const offset = mem.alignForwardGeneric(u64, seg.fileoff + seg.filesize, @alignOf(u64));
    const needed_size = out_dice.items.len * @sizeOf(macho.data_in_code_entry);
    seg.filesize = offset + needed_size - seg.fileoff;

    log.debug("writing data-in-code from 0x{x} to 0x{x}", .{ offset, offset + needed_size });

    try macho_file.base.file.?.pwriteAll(mem.sliceAsBytes(out_dice.items), offset);
    try lc_writer.writeStruct(macho.linkedit_data_command{
        .cmd = .DATA_IN_CODE,
        .cmdsize = @sizeOf(macho.linkedit_data_command),
        .dataoff = @intCast(u32, offset),
        .datasize = @intCast(u32, needed_size),
    });
    ncmds.* += 1;
}

fn writeSymtabs(macho_file: *MachO, ncmds: *u32, lc_writer: anytype) !void {
    var symtab_cmd = macho.symtab_command{
        .cmdsize = @sizeOf(macho.symtab_command),
        .symoff = 0,
        .nsyms = 0,
        .stroff = 0,
        .strsize = 0,
    };
    var dysymtab_cmd = macho.dysymtab_command{
        .cmdsize = @sizeOf(macho.dysymtab_command),
        .ilocalsym = 0,
        .nlocalsym = 0,
        .iextdefsym = 0,
        .nextdefsym = 0,
        .iundefsym = 0,
        .nundefsym = 0,
        .tocoff = 0,
        .ntoc = 0,
        .modtaboff = 0,
        .nmodtab = 0,
        .extrefsymoff = 0,
        .nextrefsyms = 0,
        .indirectsymoff = 0,
        .nindirectsyms = 0,
        .extreloff = 0,
        .nextrel = 0,
        .locreloff = 0,
        .nlocrel = 0,
    };
    var ctx = try writeSymtab(macho_file, &symtab_cmd);
    defer ctx.imports_table.deinit();
    try writeDysymtab(macho_file, ctx, &dysymtab_cmd);
    try writeStrtab(macho_file, &symtab_cmd);
    try lc_writer.writeStruct(symtab_cmd);
    try lc_writer.writeStruct(dysymtab_cmd);
    ncmds.* += 2;
}

fn writeSymtab(macho_file: *MachO, lc: *macho.symtab_command) !SymtabCtx {
    const gpa = macho_file.base.allocator;

    var locals = std.ArrayList(macho.nlist_64).init(gpa);
    defer locals.deinit();

    for (macho_file.locals.items) |sym, sym_id| {
        if (sym.n_strx == 0) continue; // no name, skip
        if (sym.n_desc == MachO.N_DESC_GCED) continue; // GCed, skip
        const sym_loc = SymbolWithLoc{ .sym_index = @intCast(u32, sym_id), .file = null };
        if (macho_file.symbolIsTemp(sym_loc)) continue; // local temp symbol, skip
        if (macho_file.getGlobal(macho_file.getSymbolName(sym_loc)) != null) continue; // global symbol is either an export or import, skip
        try locals.append(sym);
    }

    for (macho_file.objects.items) |object, object_id| {
        for (object.symtab.items) |sym, sym_id| {
            if (sym.n_strx == 0) continue; // no name, skip
            if (sym.n_desc == MachO.N_DESC_GCED) continue; // GCed, skip
            const sym_loc = SymbolWithLoc{ .sym_index = @intCast(u32, sym_id), .file = @intCast(u32, object_id) };
            if (macho_file.symbolIsTemp(sym_loc)) continue; // local temp symbol, skip
            if (macho_file.getGlobal(macho_file.getSymbolName(sym_loc)) != null) continue; // global symbol is either an export or import, skip
            var out_sym = sym;
            out_sym.n_strx = try macho_file.strtab.insert(gpa, macho_file.getSymbolName(sym_loc));
            try locals.append(out_sym);
        }

        if (!macho_file.base.options.strip) {
            try generateSymbolStabs(macho_file, object, &locals);
        }
    }

    var exports = std.ArrayList(macho.nlist_64).init(gpa);
    defer exports.deinit();

    for (macho_file.globals.items) |global| {
        const sym = macho_file.getSymbol(global);
        if (sym.undf()) continue; // import, skip
        if (sym.n_desc == MachO.N_DESC_GCED) continue; // GCed, skip
        var out_sym = sym;
        out_sym.n_strx = try macho_file.strtab.insert(gpa, macho_file.getSymbolName(global));
        try exports.append(out_sym);
    }

    var imports = std.ArrayList(macho.nlist_64).init(gpa);
    defer imports.deinit();

    var imports_table = std.AutoHashMap(SymbolWithLoc, u32).init(gpa);

    for (macho_file.globals.items) |global| {
        const sym = macho_file.getSymbol(global);
        if (sym.n_strx == 0) continue; // no name, skip
        if (!sym.undf()) continue; // not an import, skip
        const new_index = @intCast(u32, imports.items.len);
        var out_sym = sym;
        out_sym.n_strx = try macho_file.strtab.insert(gpa, macho_file.getSymbolName(global));
        try imports.append(out_sym);
        try imports_table.putNoClobber(global, new_index);
    }

    const nlocals = @intCast(u32, locals.items.len);
    const nexports = @intCast(u32, exports.items.len);
    const nimports = @intCast(u32, imports.items.len);
    const nsyms = nlocals + nexports + nimports;

    const seg = &macho_file.segments.items[macho_file.linkedit_segment_cmd_index.?];
    const offset = mem.alignForwardGeneric(
        u64,
        seg.fileoff + seg.filesize,
        @alignOf(macho.nlist_64),
    );
    const needed_size = nsyms * @sizeOf(macho.nlist_64);
    seg.filesize = offset + needed_size - seg.fileoff;

    var buffer = std.ArrayList(u8).init(gpa);
    defer buffer.deinit();
    try buffer.ensureTotalCapacityPrecise(needed_size);
    buffer.appendSliceAssumeCapacity(mem.sliceAsBytes(locals.items));
    buffer.appendSliceAssumeCapacity(mem.sliceAsBytes(exports.items));
    buffer.appendSliceAssumeCapacity(mem.sliceAsBytes(imports.items));

    log.debug("writing symtab from 0x{x} to 0x{x}", .{ offset, offset + needed_size });
    try macho_file.base.file.?.pwriteAll(buffer.items, offset);

    lc.symoff = @intCast(u32, offset);
    lc.nsyms = nsyms;

    return SymtabCtx{
        .nlocalsym = nlocals,
        .nextdefsym = nexports,
        .nundefsym = nimports,
        .imports_table = imports_table,
    };
}

fn writeStrtab(macho_file: *MachO, lc: *macho.symtab_command) !void {
    const seg = &macho_file.segments.items[macho_file.linkedit_segment_cmd_index.?];
    const offset = mem.alignForwardGeneric(u64, seg.fileoff + seg.filesize, @alignOf(u64));
    const needed_size = macho_file.strtab.buffer.items.len;
    seg.filesize = offset + needed_size - seg.fileoff;

    log.debug("writing string table from 0x{x} to 0x{x}", .{ offset, offset + needed_size });

    try macho_file.base.file.?.pwriteAll(macho_file.strtab.buffer.items, offset);

    lc.stroff = @intCast(u32, offset);
    lc.strsize = @intCast(u32, needed_size);
}

pub fn generateSymbolStabs(
    macho_file: *MachO,
    object: Object,
    locals: *std.ArrayList(macho.nlist_64),
) !void {
    assert(!macho_file.base.options.strip);

    log.debug("parsing debug info in '{s}'", .{object.name});

    const gpa = macho_file.base.allocator;
    var debug_info = try object.parseDwarfInfo();
    defer debug_info.deinit(gpa);
    try dwarf.openDwarfDebugInfo(&debug_info, gpa);

    // We assume there is only one CU.
    const compile_unit = debug_info.findCompileUnit(0x0) catch |err| switch (err) {
        error.MissingDebugInfo => {
            // TODO audit cases with missing debug info and audit our dwarf.zig module.
            log.debug("invalid or missing debug info in {s}; skipping", .{object.name});
            return;
        },
        else => |e| return e,
    };

    const tu_name = try compile_unit.die.getAttrString(&debug_info, dwarf.AT.name, debug_info.debug_str, compile_unit.*);
    const tu_comp_dir = try compile_unit.die.getAttrString(&debug_info, dwarf.AT.comp_dir, debug_info.debug_str, compile_unit.*);

    // Open scope
    try locals.ensureUnusedCapacity(3);
    locals.appendAssumeCapacity(.{
        .n_strx = try macho_file.strtab.insert(gpa, tu_comp_dir),
        .n_type = macho.N_SO,
        .n_sect = 0,
        .n_desc = 0,
        .n_value = 0,
    });
    locals.appendAssumeCapacity(.{
        .n_strx = try macho_file.strtab.insert(gpa, tu_name),
        .n_type = macho.N_SO,
        .n_sect = 0,
        .n_desc = 0,
        .n_value = 0,
    });
    locals.appendAssumeCapacity(.{
        .n_strx = try macho_file.strtab.insert(gpa, object.name),
        .n_type = macho.N_OSO,
        .n_sect = 0,
        .n_desc = 1,
        .n_value = object.mtime,
    });

    var stabs_buf: [4]macho.nlist_64 = undefined;

    for (object.managed_atoms.items) |atom| {
        const stabs = try generateSymbolStabsForSymbol(
            macho_file,
            atom.getSymbolWithLoc(),
            debug_info,
            &stabs_buf,
        );
        try locals.appendSlice(stabs);

        for (atom.contained.items) |sym_at_off| {
            const sym_loc = SymbolWithLoc{
                .sym_index = sym_at_off.sym_index,
                .file = atom.file,
            };
            const contained_stabs = try generateSymbolStabsForSymbol(
                macho_file,
                sym_loc,
                debug_info,
                &stabs_buf,
            );
            try locals.appendSlice(contained_stabs);
        }
    }

    // Close scope
    try locals.append(.{
        .n_strx = 0,
        .n_type = macho.N_SO,
        .n_sect = 0,
        .n_desc = 0,
        .n_value = 0,
    });
}

fn generateSymbolStabsForSymbol(
    macho_file: *MachO,
    sym_loc: SymbolWithLoc,
    debug_info: dwarf.DwarfInfo,
    buf: *[4]macho.nlist_64,
) ![]const macho.nlist_64 {
    const gpa = macho_file.base.allocator;
    const object = macho_file.objects.items[sym_loc.file.?];
    const sym = macho_file.getSymbol(sym_loc);
    const sym_name = macho_file.getSymbolName(sym_loc);

    if (sym.n_strx == 0) return buf[0..0];
    if (sym.n_desc == MachO.N_DESC_GCED) return buf[0..0];
    if (macho_file.symbolIsTemp(sym_loc)) return buf[0..0];

    const source_sym = object.getSourceSymbol(sym_loc.sym_index) orelse return buf[0..0];
    const size: ?u64 = size: {
        if (source_sym.tentative()) break :size null;
        for (debug_info.func_list.items) |func| {
            if (func.pc_range) |range| {
                if (source_sym.n_value >= range.start and source_sym.n_value < range.end) {
                    break :size range.end - range.start;
                }
            }
        }
        break :size null;
    };

    if (size) |ss| {
        buf[0] = .{
            .n_strx = 0,
            .n_type = macho.N_BNSYM,
            .n_sect = sym.n_sect,
            .n_desc = 0,
            .n_value = sym.n_value,
        };
        buf[1] = .{
            .n_strx = try macho_file.strtab.insert(gpa, sym_name),
            .n_type = macho.N_FUN,
            .n_sect = sym.n_sect,
            .n_desc = 0,
            .n_value = sym.n_value,
        };
        buf[2] = .{
            .n_strx = 0,
            .n_type = macho.N_FUN,
            .n_sect = 0,
            .n_desc = 0,
            .n_value = ss,
        };
        buf[3] = .{
            .n_strx = 0,
            .n_type = macho.N_ENSYM,
            .n_sect = sym.n_sect,
            .n_desc = 0,
            .n_value = ss,
        };
        return buf;
    } else {
        buf[0] = .{
            .n_strx = try macho_file.strtab.insert(gpa, sym_name),
            .n_type = macho.N_STSYM,
            .n_sect = sym.n_sect,
            .n_desc = 0,
            .n_value = sym.n_value,
        };
        return buf[0..1];
    }
}

const SymtabCtx = struct {
    nlocalsym: u32,
    nextdefsym: u32,
    nundefsym: u32,
    imports_table: std.AutoHashMap(SymbolWithLoc, u32),
};

fn writeDysymtab(macho_file: *MachO, ctx: SymtabCtx, lc: *macho.dysymtab_command) !void {
    const gpa = macho_file.base.allocator;
    const nstubs = @intCast(u32, macho_file.stubs_table.count());
    const ngot_entries = @intCast(u32, macho_file.got_entries_table.count());
    const nindirectsyms = nstubs * 2 + ngot_entries;
    const iextdefsym = ctx.nlocalsym;
    const iundefsym = iextdefsym + ctx.nextdefsym;

    const seg = &macho_file.segments.items[macho_file.linkedit_segment_cmd_index.?];
    const offset = mem.alignForwardGeneric(u64, seg.fileoff + seg.filesize, @alignOf(u64));
    const needed_size = nindirectsyms * @sizeOf(u32);
    seg.filesize = offset + needed_size - seg.fileoff;

    log.debug("writing indirect symbol table from 0x{x} to 0x{x}", .{ offset, offset + needed_size });

    var buf = std.ArrayList(u8).init(gpa);
    defer buf.deinit();
    try buf.ensureTotalCapacity(needed_size);
    const writer = buf.writer();

    if (macho_file.stubs_section_index) |sect_id| {
        const stubs = &macho_file.sections.items(.header)[sect_id];
        stubs.reserved1 = 0;
        for (macho_file.stubs.items) |entry| {
            if (entry.sym_index == 0) continue;
            const atom_sym = entry.getSymbol(macho_file);
            if (atom_sym.n_desc == MachO.N_DESC_GCED) continue;
            const target_sym = macho_file.getSymbol(entry.target);
            assert(target_sym.undf());
            try writer.writeIntLittle(u32, iundefsym + ctx.imports_table.get(entry.target).?);
        }
    }

    if (macho_file.got_section_index) |sect_id| {
        const got = &macho_file.sections.items(.header)[sect_id];
        got.reserved1 = nstubs;
        for (macho_file.got_entries.items) |entry| {
            if (entry.sym_index == 0) continue;
            const atom_sym = entry.getSymbol(macho_file);
            if (atom_sym.n_desc == MachO.N_DESC_GCED) continue;
            const target_sym = macho_file.getSymbol(entry.target);
            if (target_sym.undf()) {
                try writer.writeIntLittle(u32, iundefsym + ctx.imports_table.get(entry.target).?);
            } else {
                try writer.writeIntLittle(u32, macho.INDIRECT_SYMBOL_LOCAL);
            }
        }
    }

    if (macho_file.la_symbol_ptr_section_index) |sect_id| {
        const la_symbol_ptr = &macho_file.sections.items(.header)[sect_id];
        la_symbol_ptr.reserved1 = nstubs + ngot_entries;
        for (macho_file.stubs.items) |entry| {
            if (entry.sym_index == 0) continue;
            const atom_sym = entry.getSymbol(macho_file);
            if (atom_sym.n_desc == MachO.N_DESC_GCED) continue;
            const target_sym = macho_file.getSymbol(entry.target);
            assert(target_sym.undf());
            try writer.writeIntLittle(u32, iundefsym + ctx.imports_table.get(entry.target).?);
        }
    }

    assert(buf.items.len == needed_size);
    try macho_file.base.file.?.pwriteAll(buf.items, offset);

    lc.nlocalsym = ctx.nlocalsym;
    lc.iextdefsym = iextdefsym;
    lc.nextdefsym = ctx.nextdefsym;
    lc.iundefsym = iundefsym;
    lc.nundefsym = ctx.nundefsym;
    lc.indirectsymoff = @intCast(u32, offset);
    lc.nindirectsyms = nindirectsyms;
}

fn writeCodeSignaturePadding(
    macho_file: *MachO,
    code_sig: *CodeSignature,
    ncmds: *u32,
    lc_writer: anytype,
) !u32 {
    const seg = &macho_file.segments.items[macho_file.linkedit_segment_cmd_index.?];
    // Code signature data has to be 16-bytes aligned for Apple tools to recognize the file
    // https://github.com/opensource-apple/cctools/blob/fdb4825f303fd5c0751be524babd32958181b3ed/libstuff/checkout.c#L271
    const offset = mem.alignForwardGeneric(u64, seg.fileoff + seg.filesize, 16);
    const needed_size = code_sig.estimateSize(offset);
    seg.filesize = offset + needed_size - seg.fileoff;
    seg.vmsize = mem.alignForwardGeneric(u64, seg.filesize, macho_file.page_size);
    log.debug("writing code signature padding from 0x{x} to 0x{x}", .{ offset, offset + needed_size });
    // Pad out the space. We need to do this to calculate valid hashes for everything in the file
    // except for code signature data.
    try macho_file.base.file.?.pwriteAll(&[_]u8{0}, offset + needed_size - 1);

    try lc_writer.writeStruct(macho.linkedit_data_command{
        .cmd = .CODE_SIGNATURE,
        .cmdsize = @sizeOf(macho.linkedit_data_command),
        .dataoff = @intCast(u32, offset),
        .datasize = @intCast(u32, needed_size),
    });
    ncmds.* += 1;

    return @intCast(u32, offset);
}

fn writeCodeSignature(macho_file: *MachO, code_sig: *CodeSignature, offset: u32) !void {
    const seg = macho_file.segments.items[macho_file.text_segment_cmd_index.?];

    var buffer = std.ArrayList(u8).init(macho_file.base.allocator);
    defer buffer.deinit();
    try buffer.ensureTotalCapacityPrecise(code_sig.size());
    try code_sig.writeAdhocSignature(macho_file.base.allocator, .{
        .file = macho_file.base.file.?,
        .exec_seg_base = seg.fileoff,
        .exec_seg_limit = seg.filesize,
        .file_size = offset,
        .output_mode = macho_file.base.options.output_mode,
    }, buffer.writer());
    assert(buffer.items.len == code_sig.size());

    log.debug("writing code signature from 0x{x} to 0x{x}", .{
        offset,
        offset + buffer.items.len,
    });

    try macho_file.base.file.?.pwriteAll(buffer.items, offset);
}

fn writeSegmentHeaders(macho_file: *MachO, ncmds: *u32, writer: anytype) !void {
    for (macho_file.segments.items) |seg, i| {
        const indexes = macho_file.getSectionIndexes(@intCast(u8, i));
        var out_seg = seg;
        out_seg.cmdsize = @sizeOf(macho.segment_command_64);
        out_seg.nsects = 0;

        // Update section headers count; any section with size of 0 is excluded
        // since it doesn't have any data in the final binary file.
        for (macho_file.sections.items(.header)[indexes.start..indexes.end]) |header| {
            if (header.size == 0) continue;
            out_seg.cmdsize += @sizeOf(macho.section_64);
            out_seg.nsects += 1;
        }

        if (out_seg.nsects == 0 and
            (mem.eql(u8, out_seg.segName(), "__DATA_CONST") or
            mem.eql(u8, out_seg.segName(), "__DATA"))) continue;

        try writer.writeStruct(out_seg);
        for (macho_file.sections.items(.header)[indexes.start..indexes.end]) |header| {
            if (header.size == 0) continue;
            try writer.writeStruct(header);
        }

        ncmds.* += 1;
    }
}

/// Writes Mach-O file header.
fn writeHeader(macho_file: *MachO, ncmds: u32, sizeofcmds: u32) !void {
    var header: macho.mach_header_64 = .{};
    header.flags = macho.MH_NOUNDEFS | macho.MH_DYLDLINK | macho.MH_PIE | macho.MH_TWOLEVEL;

    switch (macho_file.base.options.target.cpu.arch) {
        .aarch64 => {
            header.cputype = macho.CPU_TYPE_ARM64;
            header.cpusubtype = macho.CPU_SUBTYPE_ARM_ALL;
        },
        .x86_64 => {
            header.cputype = macho.CPU_TYPE_X86_64;
            header.cpusubtype = macho.CPU_SUBTYPE_X86_64_ALL;
        },
        else => return error.UnsupportedCpuArchitecture,
    }

    switch (macho_file.base.options.output_mode) {
        .Exe => {
            header.filetype = macho.MH_EXECUTE;
        },
        .Lib => {
            // By this point, it can only be a dylib.
            header.filetype = macho.MH_DYLIB;
            header.flags |= macho.MH_NO_REEXPORTED_DYLIBS;
        },
        else => unreachable,
    }

    if (macho_file.getSectionByName("__DATA", "__thread_vars")) |sect_id| {
        if (macho_file.sections.items(.header)[sect_id].size > 0) {
            header.flags |= macho.MH_HAS_TLV_DESCRIPTORS;
        }
    }

    header.ncmds = ncmds;
    header.sizeofcmds = sizeofcmds;

    log.debug("writing Mach-O header {}", .{header});

    try macho_file.base.file.?.pwriteAll(mem.asBytes(&header), 0);
}

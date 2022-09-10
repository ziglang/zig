const std = @import("std");
const build_options = @import("build_options");
const assert = std.debug.assert;
const fs = std.fs;
const log = std.log.scoped(.link);
const macho = std.macho;
const math = std.math;
const mem = std.mem;

const link = @import("../../link.zig");
const trace = @import("../../tracy.zig").trace;

const Cache = @import("../../Cache.zig");
const CodeSignature = @import("CodeSignature.zig");
const Compilation = @import("../../Compilation.zig");
const Dylib = @import("Dylib.zig");
const MachO = @import("../MachO.zig");

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
        try macho_file.populateMissingMetadata();

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

        try macho_file.writeLinkeditSegmentData(&ncmds, lc_writer);

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
            codesig_offset = try macho_file.writeCodeSignaturePadding(&codesig, &ncmds, lc_writer);
            break :blk codesig;
        } else null;

        var headers_buf = std.ArrayList(u8).init(arena);
        try macho_file.writeSegmentHeaders(&ncmds, headers_buf.writer());

        try macho_file.base.file.?.pwriteAll(headers_buf.items, @sizeOf(macho.mach_header_64));
        try macho_file.base.file.?.pwriteAll(lc_buffer.items, @sizeOf(macho.mach_header_64) + headers_buf.items.len);

        try macho_file.writeHeader(ncmds, @intCast(u32, lc_buffer.items.len + headers_buf.items.len));

        if (codesig) |*csig| {
            try macho_file.writeCodeSignature(csig, codesig_offset.?); // code signing always comes last
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

fn allocateSegment(macho_file: *MachO, maybe_index: ?u8, indices: []const ?u8, init_size: u64) !void {
    const index = maybe_index orelse return;
    const seg = &macho_file.segments.items[index];

    const base = macho_file.getSegmentAllocBase(indices);
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

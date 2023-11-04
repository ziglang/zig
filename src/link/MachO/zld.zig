pub fn linkWithZld(
    macho_file: *MachO,
    comp: *Compilation,
    prog_node: *std.Progress.Node,
) link.File.FlushError!void {
    const tracy = trace(@src());
    defer tracy.end();

    const gpa = macho_file.base.allocator;
    const options = &macho_file.base.options;
    const target = options.target;

    var arena_allocator = std.heap.ArenaAllocator.init(gpa);
    defer arena_allocator.deinit();
    const arena = arena_allocator.allocator();

    const directory = options.emit.?.directory; // Just an alias to make it shorter to type.
    const full_out_path = try directory.join(arena, &[_][]const u8{options.emit.?.sub_path});

    // If there is no Zig code to compile, then we should skip flushing the output file because it
    // will not be part of the linker line anyway.
    const module_obj_path: ?[]const u8 = if (options.module != null) blk: {
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

    const cpu_arch = target.cpu.arch;
    const is_lib = options.output_mode == .Lib;
    const is_dyn_lib = options.link_mode == .Dynamic and is_lib;
    const is_exe_or_dyn_lib = is_dyn_lib or options.output_mode == .Exe;
    const stack_size = options.stack_size_override orelse 0;
    const is_debug_build = options.optimize_mode == .Debug;
    const gc_sections = options.gc_sections orelse !is_debug_build;

    const id_symlink_basename = "zld.id";

    var man: Cache.Manifest = undefined;
    defer if (!options.disable_lld_caching) man.deinit();

    var digest: [Cache.hex_digest_len]u8 = undefined;

    if (!options.disable_lld_caching) {
        man = comp.cache_parent.obtain();

        // We are about to obtain this lock, so here we give other processes a chance first.
        macho_file.base.releaseLock();

        comptime assert(Compilation.link_hash_implementation_version == 10);

        for (options.objects) |obj| {
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
        man.hash.addOptional(options.pagezero_size);
        man.hash.addOptional(options.headerpad_size);
        man.hash.add(options.headerpad_max_install_names);
        man.hash.add(gc_sections);
        man.hash.add(options.dead_strip_dylibs);
        man.hash.add(options.strip);
        man.hash.addListOfBytes(options.lib_dirs);
        man.hash.addListOfBytes(options.framework_dirs);
        try link.hashAddFrameworks(&man, options.frameworks);
        man.hash.addListOfBytes(options.rpath_list);
        if (is_dyn_lib) {
            man.hash.addOptionalBytes(options.install_name);
            man.hash.addOptional(options.version);
        }
        try link.hashAddSystemLibs(&man, options.system_libs);
        man.hash.addOptionalBytes(options.sysroot);
        man.hash.addListOfBytes(options.force_undefined_symbols.keys());
        try man.addOptionalFile(options.entitlements);

        // We don't actually care whether it's a cache hit or miss; we just
        // need the digest and the lock.
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

    if (options.output_mode == .Obj) {
        // LLD's MachO driver does not support the equivalent of `-r` so we do a simple file copy
        // here. TODO: think carefully about how we can avoid this redundant operation when doing
        // build-obj. See also the corresponding TODO in linkAsArchive.
        const the_object_path = blk: {
            if (options.objects.len != 0) {
                break :blk options.objects[0].path;
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
        const sub_path = options.emit.?.sub_path;

        const old_file = macho_file.base.file; // TODO is this needed at all?
        defer macho_file.base.file = old_file;

        const file = try directory.handle.createFile(sub_path, .{
            .truncate = true,
            .read = true,
            .mode = link.determineMode(options.*),
        });
        defer file.close();
        macho_file.base.file = file;

        // Index 0 is always a null symbol.
        try macho_file.locals.append(gpa, .{
            .n_strx = 0,
            .n_type = 0,
            .n_sect = 0,
            .n_desc = 0,
            .n_value = 0,
        });
        try macho_file.strtab.buffer.append(gpa, 0);

        // Positional arguments to the linker such as object files and static archives.
        var positionals = std.ArrayList(Compilation.LinkObject).init(arena);
        try positionals.ensureUnusedCapacity(options.objects.len);
        positionals.appendSliceAssumeCapacity(options.objects);

        for (comp.c_object_table.keys()) |key| {
            try positionals.append(.{ .path = key.status.success.object_path });
        }

        if (module_obj_path) |p| {
            try positionals.append(.{ .path = p });
        }

        if (comp.compiler_rt_lib) |lib| try positionals.append(.{ .path = lib.full_object_path });
        if (comp.compiler_rt_obj) |obj| try positionals.append(.{ .path = obj.full_object_path });

        // libc++ dep
        if (options.link_libcpp) {
            try positionals.ensureUnusedCapacity(2);
            positionals.appendAssumeCapacity(.{ .path = comp.libcxxabi_static_lib.?.full_object_path });
            positionals.appendAssumeCapacity(.{ .path = comp.libcxx_static_lib.?.full_object_path });
        }

        var libs = std.StringArrayHashMap(link.SystemLib).init(arena);

        {
            const vals = options.system_libs.values();
            try libs.ensureUnusedCapacity(vals.len);
            for (vals) |v| libs.putAssumeCapacity(v.path.?, v);
        }

        {
            try libs.ensureUnusedCapacity(options.frameworks.len);
            for (options.frameworks) |v| libs.putAssumeCapacity(v.path, .{
                .needed = v.needed,
                .weak = v.weak,
                .path = v.path,
            });
        }

        try macho_file.resolveLibSystem(arena, comp, options.lib_dirs, &libs);

        if (options.verbose_link) {
            var argv = std.ArrayList([]const u8).init(arena);

            try argv.append("zig");
            try argv.append("ld");

            if (is_exe_or_dyn_lib) {
                try argv.append("-dynamic");
            }

            if (is_dyn_lib) {
                try argv.append("-dylib");

                if (options.install_name) |install_name| {
                    try argv.append("-install_name");
                    try argv.append(install_name);
                }
            }

            {
                const platform = Platform.fromTarget(options.target);
                try argv.append("-platform_version");
                try argv.append(@tagName(platform.os_tag));
                try argv.append(try std.fmt.allocPrint(arena, "{}", .{platform.version}));

                const sdk_version: ?std.SemanticVersion = load_commands.inferSdkVersion(arena, comp);
                if (sdk_version) |ver| {
                    try argv.append(try std.fmt.allocPrint(arena, "{d}.{d}", .{ ver.major, ver.minor }));
                } else {
                    try argv.append(try std.fmt.allocPrint(arena, "{}", .{platform.version}));
                }
            }

            if (options.sysroot) |syslibroot| {
                try argv.append("-syslibroot");
                try argv.append(syslibroot);
            }

            for (options.rpath_list) |rpath| {
                try argv.append("-rpath");
                try argv.append(rpath);
            }

            if (options.pagezero_size) |pagezero_size| {
                try argv.append("-pagezero_size");
                try argv.append(try std.fmt.allocPrint(arena, "0x{x}", .{pagezero_size}));
            }

            if (options.headerpad_size) |headerpad_size| {
                try argv.append("-headerpad_size");
                try argv.append(try std.fmt.allocPrint(arena, "0x{x}", .{headerpad_size}));
            }

            if (options.headerpad_max_install_names) {
                try argv.append("-headerpad_max_install_names");
            }

            if (gc_sections) {
                try argv.append("-dead_strip");
            }

            if (options.dead_strip_dylibs) {
                try argv.append("-dead_strip_dylibs");
            }

            if (options.entry) |entry| {
                try argv.append("-e");
                try argv.append(entry);
            }

            for (options.objects) |obj| {
                if (obj.must_link) {
                    try argv.append("-force_load");
                }
                try argv.append(obj.path);
            }

            for (comp.c_object_table.keys()) |key| {
                try argv.append(key.status.success.object_path);
            }

            if (module_obj_path) |p| {
                try argv.append(p);
            }

            if (comp.compiler_rt_lib) |lib| try argv.append(lib.full_object_path);
            if (comp.compiler_rt_obj) |obj| try argv.append(obj.full_object_path);

            if (options.link_libcpp) {
                try argv.append(comp.libcxxabi_static_lib.?.full_object_path);
                try argv.append(comp.libcxx_static_lib.?.full_object_path);
            }

            try argv.append("-o");
            try argv.append(full_out_path);

            try argv.append("-lSystem");

            for (options.system_libs.keys()) |l_name| {
                const info = options.system_libs.get(l_name).?;
                const arg = if (info.needed)
                    try std.fmt.allocPrint(arena, "-needed-l{s}", .{l_name})
                else if (info.weak)
                    try std.fmt.allocPrint(arena, "-weak-l{s}", .{l_name})
                else
                    try std.fmt.allocPrint(arena, "-l{s}", .{l_name});
                try argv.append(arg);
            }

            for (options.lib_dirs) |lib_dir| {
                try argv.append(try std.fmt.allocPrint(arena, "-L{s}", .{lib_dir}));
            }

            for (options.frameworks) |framework| {
                const name = std.fs.path.stem(framework.path);
                const arg = if (framework.needed)
                    try std.fmt.allocPrint(arena, "-needed_framework {s}", .{name})
                else if (framework.weak)
                    try std.fmt.allocPrint(arena, "-weak_framework {s}", .{name})
                else
                    try std.fmt.allocPrint(arena, "-framework {s}", .{name});
                try argv.append(arg);
            }

            for (options.framework_dirs) |framework_dir| {
                try argv.append(try std.fmt.allocPrint(arena, "-F{s}", .{framework_dir}));
            }

            if (is_dyn_lib and (options.allow_shlib_undefined orelse false)) {
                try argv.append("-undefined");
                try argv.append("dynamic_lookup");
            }

            Compilation.dump_argv(argv.items);
        }

        var dependent_libs = std.fifo.LinearFifo(MachO.DylibReExportInfo, .Dynamic).init(arena);

        for (positionals.items) |obj| {
            const in_file = try std.fs.cwd().openFile(obj.path, .{});
            defer in_file.close();

            var parse_ctx = MachO.ParseErrorCtx.init(gpa);
            defer parse_ctx.deinit();

            macho_file.parsePositional(
                in_file,
                obj.path,
                obj.must_link,
                &dependent_libs,
                &parse_ctx,
            ) catch |err| try macho_file.handleAndReportParseError(obj.path, err, &parse_ctx);
        }

        for (libs.keys(), libs.values()) |path, lib| {
            const in_file = try std.fs.cwd().openFile(path, .{});
            defer in_file.close();

            var parse_ctx = MachO.ParseErrorCtx.init(gpa);
            defer parse_ctx.deinit();

            macho_file.parseLibrary(
                in_file,
                path,
                lib,
                false,
                false,
                null,
                &dependent_libs,
                &parse_ctx,
            ) catch |err| try macho_file.handleAndReportParseError(path, err, &parse_ctx);
        }

        try macho_file.parseDependentLibs(&dependent_libs);

        try macho_file.resolveSymbols();
        if (macho_file.unresolved.count() > 0) {
            try macho_file.reportUndefined();
            return error.FlushFailure;
        }

        for (macho_file.objects.items, 0..) |*object, object_id| {
            object.splitIntoAtoms(macho_file, @as(u32, @intCast(object_id))) catch |err| switch (err) {
                error.MissingEhFrameSection => try macho_file.reportParseError(
                    object.name,
                    "missing section: '__TEXT,__eh_frame' is required but could not be found",
                    .{},
                ),
                error.BadDwarfCfi => try macho_file.reportParseError(
                    object.name,
                    "invalid DWARF: failed to parse '__TEXT,__eh_frame' section",
                    .{},
                ),
                else => |e| return e,
            };
        }

        if (gc_sections) {
            try dead_strip.gcAtoms(macho_file);
        }

        try macho_file.createDyldPrivateAtom();
        try macho_file.createTentativeDefAtoms();

        if (macho_file.base.options.output_mode == .Exe) {
            const global = macho_file.getEntryPoint().?;
            if (macho_file.getSymbol(global).undf()) {
                // We do one additional check here in case the entry point was found in one of the dylibs.
                // (I actually have no idea what this would imply but it is a possible outcome and so we
                // support it.)
                try macho_file.addStubEntry(global);
            }
        }

        for (macho_file.objects.items) |object| {
            for (object.atoms.items) |atom_index| {
                const atom = macho_file.getAtom(atom_index);
                const sym = macho_file.getSymbol(atom.getSymbolWithLoc());
                const header = macho_file.sections.items(.header)[sym.n_sect - 1];
                if (header.isZerofill()) continue;

                const relocs = Atom.getAtomRelocs(macho_file, atom_index);
                try Atom.scanAtomRelocs(macho_file, atom_index, relocs);
            }
        }

        try eh_frame.scanRelocs(macho_file);
        try UnwindInfo.scanRelocs(macho_file);

        if (macho_file.dyld_stub_binder_index) |index|
            try macho_file.addGotEntry(macho_file.globals.items[index]);

        try calcSectionSizes(macho_file);

        var unwind_info = UnwindInfo{ .gpa = gpa };
        defer unwind_info.deinit();
        try unwind_info.collect(macho_file);

        try eh_frame.calcSectionSize(macho_file, &unwind_info);
        unwind_info.calcSectionSize(macho_file);

        try pruneAndSortSections(macho_file);
        try createSegments(macho_file);
        try allocateSegments(macho_file);

        try macho_file.allocateSpecialSymbols();

        if (build_options.enable_logging) {
            macho_file.logSymtab();
            macho_file.logSegments();
            macho_file.logSections();
            macho_file.logAtoms();
        }

        try writeAtoms(macho_file);
        if (macho_file.base.options.target.cpu.arch == .aarch64) try writeThunks(macho_file);
        try writeDyldPrivateAtom(macho_file);

        if (macho_file.stubs_section_index) |_| {
            try writeStubs(macho_file);
            try writeStubHelpers(macho_file);
            try writeLaSymbolPtrs(macho_file);
        }
        if (macho_file.got_section_index) |sect_id|
            try writePointerEntries(macho_file, sect_id, &macho_file.got_table);
        if (macho_file.tlv_ptr_section_index) |sect_id|
            try writePointerEntries(macho_file, sect_id, &macho_file.tlv_ptr_table);

        try eh_frame.write(macho_file, &unwind_info);
        try unwind_info.write(macho_file);
        try macho_file.writeLinkeditSegmentData();

        // If the last section of __DATA segment is zerofill section, we need to ensure
        // that the free space between the end of the last non-zerofill section of __DATA
        // segment and the beginning of __LINKEDIT segment is zerofilled as the loader will
        // copy-paste this space into memory for quicker zerofill operation.
        if (macho_file.data_segment_cmd_index) |data_seg_id| blk: {
            var physical_zerofill_start: ?u64 = null;
            const section_indexes = macho_file.getSectionIndexes(data_seg_id);
            for (macho_file.sections.items(.header)[section_indexes.start..section_indexes.end]) |header| {
                if (header.isZerofill() and header.size > 0) break;
                physical_zerofill_start = header.offset + header.size;
            } else break :blk;
            const start = physical_zerofill_start orelse break :blk;
            const linkedit = macho_file.getLinkeditSegmentPtr();
            const size = math.cast(usize, linkedit.fileoff - start) orelse return error.Overflow;
            if (size > 0) {
                log.debug("zeroing out zerofill area of length {x} at {x}", .{ size, start });
                var padding = try gpa.alloc(u8, size);
                defer gpa.free(padding);
                @memset(padding, 0);
                try macho_file.base.file.?.pwriteAll(padding, start);
            }
        }

        // Write code signature padding if required
        var codesig: ?CodeSignature = if (MachO.requiresCodeSignature(&macho_file.base.options)) blk: {
            // Preallocate space for the code signature.
            // We need to do this at this stage so that we have the load commands with proper values
            // written out to the file.
            // The most important here is to have the correct vm and filesize of the __LINKEDIT segment
            // where the code signature goes into.
            var codesig = CodeSignature.init(MachO.getPageSize(cpu_arch));
            codesig.code_directory.ident = fs.path.basename(full_out_path);
            if (options.entitlements) |path| {
                try codesig.addEntitlements(gpa, path);
            }
            try macho_file.writeCodeSignaturePadding(&codesig);
            break :blk codesig;
        } else null;
        defer if (codesig) |*csig| csig.deinit(gpa);

        // Write load commands
        var lc_buffer = std.ArrayList(u8).init(arena);
        const lc_writer = lc_buffer.writer();

        try macho_file.writeSegmentHeaders(lc_writer);
        try lc_writer.writeStruct(macho_file.dyld_info_cmd);
        try lc_writer.writeStruct(macho_file.function_starts_cmd);
        try lc_writer.writeStruct(macho_file.data_in_code_cmd);
        try lc_writer.writeStruct(macho_file.symtab_cmd);
        try lc_writer.writeStruct(macho_file.dysymtab_cmd);
        try load_commands.writeDylinkerLC(lc_writer);

        switch (macho_file.base.options.output_mode) {
            .Exe => blk: {
                const seg_id = macho_file.header_segment_cmd_index.?;
                const seg = macho_file.segments.items[seg_id];
                const global = macho_file.getEntryPoint() orelse break :blk;
                const sym = macho_file.getSymbol(global);

                const addr: u64 = if (sym.undf())
                    // In this case, the symbol has been resolved in one of dylibs and so we point
                    // to the stub as its vmaddr value.
                    macho_file.getStubsEntryAddress(global).?
                else
                    sym.n_value;

                try lc_writer.writeStruct(macho.entry_point_command{
                    .entryoff = @as(u32, @intCast(addr - seg.vmaddr)),
                    .stacksize = macho_file.base.options.stack_size_override orelse 0,
                });
            },
            .Lib => if (macho_file.base.options.link_mode == .Dynamic) {
                try load_commands.writeDylibIdLC(gpa, &macho_file.base.options, lc_writer);
            },
            else => {},
        }

        try load_commands.writeRpathLCs(gpa, &macho_file.base.options, lc_writer);
        try lc_writer.writeStruct(macho.source_version_command{
            .version = 0,
        });
        {
            const platform = Platform.fromTarget(macho_file.base.options.target);
            const sdk_version: ?std.SemanticVersion = load_commands.inferSdkVersion(arena, comp);
            if (platform.isBuildVersionCompatible()) {
                try load_commands.writeBuildVersionLC(platform, sdk_version, lc_writer);
            } else {
                try load_commands.writeVersionMinLC(platform, sdk_version, lc_writer);
            }
        }

        const uuid_cmd_offset = @sizeOf(macho.mach_header_64) + @as(u32, @intCast(lc_buffer.items.len));
        try lc_writer.writeStruct(macho_file.uuid_cmd);

        try load_commands.writeLoadDylibLCs(
            macho_file.dylibs.items,
            macho_file.referenced_dylibs.keys(),
            lc_writer,
        );

        if (codesig != null) {
            try lc_writer.writeStruct(macho_file.codesig_cmd);
        }

        const ncmds = load_commands.calcNumOfLCs(lc_buffer.items);
        try macho_file.base.file.?.pwriteAll(lc_buffer.items, @sizeOf(macho.mach_header_64));
        try macho_file.writeHeader(ncmds, @as(u32, @intCast(lc_buffer.items.len)));
        try macho_file.writeUuid(comp, uuid_cmd_offset, codesig != null);

        if (codesig) |*csig| {
            try macho_file.writeCodeSignature(comp, csig); // code signing always comes last
            try MachO.invalidateKernelCache(directory.handle, macho_file.base.options.emit.?.sub_path);
        }
    }

    if (!options.disable_lld_caching) {
        // Update the file with the digest. If it fails we can continue; it only
        // means that the next invocation will have an unnecessary cache miss.
        Cache.writeSmallFile(directory.handle, id_symlink_basename, &digest) catch |err| {
            log.debug("failed to save linking hash digest file: {s}", .{@errorName(err)});
        };
        // Again failure here only means an unnecessary cache miss.
        if (man.have_exclusive_lock) {
            man.writeManifest() catch |err| {
                log.debug("failed to write cache manifest when linking: {s}", .{@errorName(err)});
            };
        }
        // We hang on to this lock so that the output file path can be used without
        // other processes clobbering it.
        macho_file.base.lock = man.toOwnedLock();
    }
}

fn createSegments(macho_file: *MachO) !void {
    const gpa = macho_file.base.allocator;
    const pagezero_vmsize = macho_file.base.options.pagezero_size orelse MachO.default_pagezero_vmsize;
    const page_size = MachO.getPageSize(macho_file.base.options.target.cpu.arch);
    const aligned_pagezero_vmsize = mem.alignBackward(u64, pagezero_vmsize, page_size);
    if (macho_file.base.options.output_mode != .Lib and aligned_pagezero_vmsize > 0) {
        if (aligned_pagezero_vmsize != pagezero_vmsize) {
            log.warn("requested __PAGEZERO size (0x{x}) is not page aligned", .{pagezero_vmsize});
            log.warn("  rounding down to 0x{x}", .{aligned_pagezero_vmsize});
        }
        macho_file.pagezero_segment_cmd_index = @intCast(macho_file.segments.items.len);
        try macho_file.segments.append(gpa, .{
            .cmdsize = @sizeOf(macho.segment_command_64),
            .segname = MachO.makeStaticString("__PAGEZERO"),
            .vmsize = aligned_pagezero_vmsize,
        });
    }

    // __TEXT segment is non-optional
    {
        const protection = MachO.getSegmentMemoryProtection("__TEXT");
        macho_file.text_segment_cmd_index = @intCast(macho_file.segments.items.len);
        macho_file.header_segment_cmd_index = macho_file.text_segment_cmd_index.?;
        try macho_file.segments.append(gpa, .{
            .cmdsize = @sizeOf(macho.segment_command_64),
            .segname = MachO.makeStaticString("__TEXT"),
            .maxprot = protection,
            .initprot = protection,
        });
    }

    for (macho_file.sections.items(.header), 0..) |header, sect_id| {
        if (header.size == 0) continue; // empty section

        const segname = header.segName();
        const segment_id = macho_file.getSegmentByName(segname) orelse blk: {
            log.debug("creating segment '{s}'", .{segname});
            const segment_id = @as(u8, @intCast(macho_file.segments.items.len));
            const protection = MachO.getSegmentMemoryProtection(segname);
            try macho_file.segments.append(gpa, .{
                .cmdsize = @sizeOf(macho.segment_command_64),
                .segname = MachO.makeStaticString(segname),
                .maxprot = protection,
                .initprot = protection,
            });
            break :blk segment_id;
        };
        const segment = &macho_file.segments.items[segment_id];
        segment.cmdsize += @sizeOf(macho.section_64);
        segment.nsects += 1;
        macho_file.sections.items(.segment_index)[sect_id] = segment_id;
    }

    if (macho_file.getSegmentByName("__DATA_CONST")) |index| {
        macho_file.data_const_segment_cmd_index = index;
    }

    if (macho_file.getSegmentByName("__DATA")) |index| {
        macho_file.data_segment_cmd_index = index;
    }

    // __LINKEDIT always comes last
    {
        const protection = MachO.getSegmentMemoryProtection("__LINKEDIT");
        macho_file.linkedit_segment_cmd_index = @intCast(macho_file.segments.items.len);
        try macho_file.segments.append(gpa, .{
            .cmdsize = @sizeOf(macho.segment_command_64),
            .segname = MachO.makeStaticString("__LINKEDIT"),
            .maxprot = protection,
            .initprot = protection,
        });
    }
}

fn writeAtoms(macho_file: *MachO) !void {
    const gpa = macho_file.base.allocator;
    const slice = macho_file.sections.slice();

    for (slice.items(.first_atom_index), 0..) |first_atom_index, sect_id| {
        const header = slice.items(.header)[sect_id];
        if (header.isZerofill()) continue;

        var atom_index = first_atom_index orelse continue;

        var buffer = try gpa.alloc(u8, math.cast(usize, header.size) orelse return error.Overflow);
        defer gpa.free(buffer);
        @memset(buffer, 0); // TODO with NOPs

        log.debug("writing atoms in {s},{s}", .{ header.segName(), header.sectName() });

        while (true) {
            const atom = macho_file.getAtom(atom_index);
            if (atom.getFile()) |file| {
                const this_sym = macho_file.getSymbol(atom.getSymbolWithLoc());
                const padding_size: usize = if (atom.next_index) |next_index| blk: {
                    const next_sym = macho_file.getSymbol(macho_file.getAtom(next_index).getSymbolWithLoc());
                    const size = next_sym.n_value - (this_sym.n_value + atom.size);
                    break :blk math.cast(usize, size) orelse return error.Overflow;
                } else 0;

                log.debug("  (adding ATOM(%{d}, '{s}') from object({d}) to buffer)", .{
                    atom.sym_index,
                    macho_file.getSymbolName(atom.getSymbolWithLoc()),
                    file,
                });
                if (padding_size > 0) {
                    log.debug("    (with padding {x})", .{padding_size});
                }

                const offset = math.cast(usize, this_sym.n_value - header.addr) orelse
                    return error.Overflow;
                log.debug("  (at offset 0x{x})", .{offset});

                const code = Atom.getAtomCode(macho_file, atom_index);
                const relocs = Atom.getAtomRelocs(macho_file, atom_index);
                const size = math.cast(usize, atom.size) orelse return error.Overflow;
                @memcpy(buffer[offset .. offset + size], code);
                try Atom.resolveRelocs(
                    macho_file,
                    atom_index,
                    buffer[offset..][0..size],
                    relocs,
                );
            }

            if (atom.next_index) |next_index| {
                atom_index = next_index;
            } else break;
        }

        log.debug("  (writing at file offset 0x{x})", .{header.offset});
        try macho_file.base.file.?.pwriteAll(buffer, header.offset);
    }
}

fn writeDyldPrivateAtom(macho_file: *MachO) !void {
    const atom_index = macho_file.dyld_private_atom_index orelse return;
    const atom = macho_file.getAtom(atom_index);
    const sym = macho_file.getSymbol(atom.getSymbolWithLoc());
    const sect_id = macho_file.data_section_index.?;
    const header = macho_file.sections.items(.header)[sect_id];
    const offset = sym.n_value - header.addr + header.offset;
    log.debug("writing __dyld_private at offset 0x{x}", .{offset});
    const buffer: [@sizeOf(u64)]u8 = [_]u8{0} ** @sizeOf(u64);
    try macho_file.base.file.?.pwriteAll(&buffer, offset);
}

fn writeThunks(macho_file: *MachO) !void {
    assert(macho_file.base.options.target.cpu.arch == .aarch64);
    const gpa = macho_file.base.allocator;

    const sect_id = macho_file.text_section_index orelse return;
    const header = macho_file.sections.items(.header)[sect_id];

    for (macho_file.thunks.items, 0..) |*thunk, i| {
        if (thunk.getSize() == 0) continue;
        const thunk_size = math.cast(usize, thunk.getSize()) orelse return error.Overflow;
        var buffer = try std.ArrayList(u8).initCapacity(gpa, thunk_size);
        defer buffer.deinit();
        try thunks.writeThunkCode(macho_file, thunk, buffer.writer());
        const thunk_atom = macho_file.getAtom(thunk.getStartAtomIndex());
        const thunk_sym = macho_file.getSymbol(thunk_atom.getSymbolWithLoc());
        const offset = thunk_sym.n_value - header.addr + header.offset;
        log.debug("writing thunk({d}) at offset 0x{x}", .{ i, offset });
        try macho_file.base.file.?.pwriteAll(buffer.items, offset);
    }
}

fn writePointerEntries(macho_file: *MachO, sect_id: u8, table: anytype) !void {
    const gpa = macho_file.base.allocator;
    const header = macho_file.sections.items(.header)[sect_id];
    const capacity = math.cast(usize, header.size) orelse return error.Overflow;
    var buffer = try std.ArrayList(u8).initCapacity(gpa, capacity);
    defer buffer.deinit();
    for (table.entries.items) |entry| {
        const sym = macho_file.getSymbol(entry);
        buffer.writer().writeInt(u64, sym.n_value, .little) catch unreachable;
    }
    log.debug("writing __DATA_CONST,__got contents at file offset 0x{x}", .{header.offset});
    try macho_file.base.file.?.pwriteAll(buffer.items, header.offset);
}

fn writeStubs(macho_file: *MachO) !void {
    const gpa = macho_file.base.allocator;
    const cpu_arch = macho_file.base.options.target.cpu.arch;
    const stubs_header = macho_file.sections.items(.header)[macho_file.stubs_section_index.?];
    const la_symbol_ptr_header = macho_file.sections.items(.header)[macho_file.la_symbol_ptr_section_index.?];

    const capacity = math.cast(usize, stubs_header.size) orelse return error.Overflow;
    var buffer = try std.ArrayList(u8).initCapacity(gpa, capacity);
    defer buffer.deinit();

    for (0..macho_file.stub_table.count()) |index| {
        try stubs.writeStubCode(.{
            .cpu_arch = cpu_arch,
            .source_addr = stubs_header.addr + stubs.stubSize(cpu_arch) * index,
            .target_addr = la_symbol_ptr_header.addr + index * @sizeOf(u64),
        }, buffer.writer());
    }

    log.debug("writing __TEXT,__stubs contents at file offset 0x{x}", .{stubs_header.offset});
    try macho_file.base.file.?.pwriteAll(buffer.items, stubs_header.offset);
}

fn writeStubHelpers(macho_file: *MachO) !void {
    const gpa = macho_file.base.allocator;
    const cpu_arch = macho_file.base.options.target.cpu.arch;
    const stub_helper_header = macho_file.sections.items(.header)[macho_file.stub_helper_section_index.?];

    const capacity = math.cast(usize, stub_helper_header.size) orelse return error.Overflow;
    var buffer = try std.ArrayList(u8).initCapacity(gpa, capacity);
    defer buffer.deinit();

    {
        const dyld_private_addr = blk: {
            const atom = macho_file.getAtom(macho_file.dyld_private_atom_index.?);
            const sym = macho_file.getSymbol(atom.getSymbolWithLoc());
            break :blk sym.n_value;
        };
        const dyld_stub_binder_got_addr = blk: {
            const sym_loc = macho_file.globals.items[macho_file.dyld_stub_binder_index.?];
            break :blk macho_file.getGotEntryAddress(sym_loc).?;
        };
        try stubs.writeStubHelperPreambleCode(.{
            .cpu_arch = cpu_arch,
            .source_addr = stub_helper_header.addr,
            .dyld_private_addr = dyld_private_addr,
            .dyld_stub_binder_got_addr = dyld_stub_binder_got_addr,
        }, buffer.writer());
    }

    for (0..macho_file.stub_table.count()) |index| {
        const source_addr = stub_helper_header.addr + stubs.stubHelperPreambleSize(cpu_arch) +
            stubs.stubHelperSize(cpu_arch) * index;
        try stubs.writeStubHelperCode(.{
            .cpu_arch = cpu_arch,
            .source_addr = source_addr,
            .target_addr = stub_helper_header.addr,
        }, buffer.writer());
    }

    log.debug("writing __TEXT,__stub_helper contents at file offset 0x{x}", .{
        stub_helper_header.offset,
    });
    try macho_file.base.file.?.pwriteAll(buffer.items, stub_helper_header.offset);
}

fn writeLaSymbolPtrs(macho_file: *MachO) !void {
    const gpa = macho_file.base.allocator;
    const cpu_arch = macho_file.base.options.target.cpu.arch;
    const la_symbol_ptr_header = macho_file.sections.items(.header)[macho_file.la_symbol_ptr_section_index.?];
    const stub_helper_header = macho_file.sections.items(.header)[macho_file.stub_helper_section_index.?];

    const capacity = math.cast(usize, la_symbol_ptr_header.size) orelse return error.Overflow;
    var buffer = try std.ArrayList(u8).initCapacity(gpa, capacity);
    defer buffer.deinit();

    for (0..macho_file.stub_table.count()) |index| {
        const target_addr = stub_helper_header.addr + stubs.stubHelperPreambleSize(cpu_arch) +
            stubs.stubHelperSize(cpu_arch) * index;
        buffer.writer().writeInt(u64, target_addr, .little) catch unreachable;
    }

    log.debug("writing __DATA,__la_symbol_ptr contents at file offset 0x{x}", .{
        la_symbol_ptr_header.offset,
    });
    try macho_file.base.file.?.pwriteAll(buffer.items, la_symbol_ptr_header.offset);
}

fn pruneAndSortSections(macho_file: *MachO) !void {
    const Entry = struct {
        index: u8,

        pub fn lessThan(ctx: *MachO, lhs: @This(), rhs: @This()) bool {
            const lhs_header = ctx.sections.items(.header)[lhs.index];
            const rhs_header = ctx.sections.items(.header)[rhs.index];
            return MachO.getSectionPrecedence(lhs_header) < MachO.getSectionPrecedence(rhs_header);
        }
    };

    const gpa = macho_file.base.allocator;

    var entries = try std.ArrayList(Entry).initCapacity(gpa, macho_file.sections.slice().len);
    defer entries.deinit();

    for (0..macho_file.sections.slice().len) |index| {
        const section = macho_file.sections.get(index);
        if (section.header.size == 0) {
            log.debug("pruning section {s},{s} {?d}", .{
                section.header.segName(),
                section.header.sectName(),
                section.first_atom_index,
            });
            for (&[_]*?u8{
                &macho_file.text_section_index,
                &macho_file.data_const_section_index,
                &macho_file.data_section_index,
                &macho_file.bss_section_index,
                &macho_file.thread_vars_section_index,
                &macho_file.thread_data_section_index,
                &macho_file.thread_bss_section_index,
                &macho_file.eh_frame_section_index,
                &macho_file.unwind_info_section_index,
                &macho_file.got_section_index,
                &macho_file.tlv_ptr_section_index,
                &macho_file.stubs_section_index,
                &macho_file.stub_helper_section_index,
                &macho_file.la_symbol_ptr_section_index,
            }) |maybe_index| {
                if (maybe_index.* != null and maybe_index.*.? == index) {
                    maybe_index.* = null;
                }
            }
            continue;
        }
        entries.appendAssumeCapacity(.{ .index = @intCast(index) });
    }

    mem.sort(Entry, entries.items, macho_file, Entry.lessThan);

    var slice = macho_file.sections.toOwnedSlice();
    defer slice.deinit(gpa);

    const backlinks = try gpa.alloc(u8, slice.len);
    defer gpa.free(backlinks);
    for (entries.items, 0..) |entry, i| {
        backlinks[entry.index] = @as(u8, @intCast(i));
    }

    try macho_file.sections.ensureTotalCapacity(gpa, entries.items.len);
    for (entries.items) |entry| {
        macho_file.sections.appendAssumeCapacity(slice.get(entry.index));
    }

    for (&[_]*?u8{
        &macho_file.text_section_index,
        &macho_file.data_const_section_index,
        &macho_file.data_section_index,
        &macho_file.bss_section_index,
        &macho_file.thread_vars_section_index,
        &macho_file.thread_data_section_index,
        &macho_file.thread_bss_section_index,
        &macho_file.eh_frame_section_index,
        &macho_file.unwind_info_section_index,
        &macho_file.got_section_index,
        &macho_file.tlv_ptr_section_index,
        &macho_file.stubs_section_index,
        &macho_file.stub_helper_section_index,
        &macho_file.la_symbol_ptr_section_index,
    }) |maybe_index| {
        if (maybe_index.*) |*index| {
            index.* = backlinks[index.*];
        }
    }
}

fn calcSectionSizes(macho_file: *MachO) !void {
    const slice = macho_file.sections.slice();
    for (slice.items(.header), 0..) |*header, sect_id| {
        if (header.size == 0) continue;
        if (macho_file.text_section_index) |txt| {
            if (txt == sect_id and macho_file.base.options.target.cpu.arch == .aarch64) continue;
        }

        var atom_index = slice.items(.first_atom_index)[sect_id] orelse continue;

        header.size = 0;
        header.@"align" = 0;

        while (true) {
            const atom = macho_file.getAtom(atom_index);
            const atom_offset = atom.alignment.forward(header.size);
            const padding = atom_offset - header.size;

            const sym = macho_file.getSymbolPtr(atom.getSymbolWithLoc());
            sym.n_value = atom_offset;

            header.size += padding + atom.size;
            header.@"align" = @max(header.@"align", atom.alignment.toLog2Units());

            atom_index = atom.next_index orelse break;
        }
    }

    if (macho_file.text_section_index != null and macho_file.base.options.target.cpu.arch == .aarch64) {
        // Create jump/branch range extenders if needed.
        try thunks.createThunks(macho_file, macho_file.text_section_index.?);
    }

    // Update offsets of all symbols contained within each Atom.
    // We need to do this since our unwind info synthesiser relies on
    // traversing the symbols when synthesising unwind info and DWARF CFI records.
    for (slice.items(.first_atom_index)) |first_atom_index| {
        var atom_index = first_atom_index orelse continue;

        while (true) {
            const atom = macho_file.getAtom(atom_index);
            const sym = macho_file.getSymbol(atom.getSymbolWithLoc());

            if (atom.getFile() != null) {
                // Update each symbol contained within the atom
                var it = Atom.getInnerSymbolsIterator(macho_file, atom_index);
                while (it.next()) |sym_loc| {
                    const inner_sym = macho_file.getSymbolPtr(sym_loc);
                    inner_sym.n_value = sym.n_value + Atom.calcInnerSymbolOffset(
                        macho_file,
                        atom_index,
                        sym_loc.sym_index,
                    );
                }

                // If there is a section alias, update it now too
                if (Atom.getSectionAlias(macho_file, atom_index)) |sym_loc| {
                    const alias = macho_file.getSymbolPtr(sym_loc);
                    alias.n_value = sym.n_value;
                }
            }

            if (atom.next_index) |next_index| {
                atom_index = next_index;
            } else break;
        }
    }

    if (macho_file.got_section_index) |sect_id| {
        const header = &macho_file.sections.items(.header)[sect_id];
        header.size = macho_file.got_table.count() * @sizeOf(u64);
        header.@"align" = 3;
    }

    if (macho_file.tlv_ptr_section_index) |sect_id| {
        const header = &macho_file.sections.items(.header)[sect_id];
        header.size = macho_file.tlv_ptr_table.count() * @sizeOf(u64);
        header.@"align" = 3;
    }

    const cpu_arch = macho_file.base.options.target.cpu.arch;

    if (macho_file.stubs_section_index) |sect_id| {
        const header = &macho_file.sections.items(.header)[sect_id];
        header.size = macho_file.stub_table.count() * stubs.stubSize(cpu_arch);
        header.@"align" = math.log2(stubs.stubAlignment(cpu_arch));
    }

    if (macho_file.stub_helper_section_index) |sect_id| {
        const header = &macho_file.sections.items(.header)[sect_id];
        header.size = macho_file.stub_table.count() * stubs.stubHelperSize(cpu_arch) +
            stubs.stubHelperPreambleSize(cpu_arch);
        header.@"align" = math.log2(stubs.stubAlignment(cpu_arch));
    }

    if (macho_file.la_symbol_ptr_section_index) |sect_id| {
        const header = &macho_file.sections.items(.header)[sect_id];
        header.size = macho_file.stub_table.count() * @sizeOf(u64);
        header.@"align" = 3;
    }
}

fn allocateSegments(macho_file: *MachO) !void {
    const gpa = macho_file.base.allocator;
    for (macho_file.segments.items, 0..) |*segment, segment_index| {
        const is_text_segment = mem.eql(u8, segment.segName(), "__TEXT");
        const base_size = if (is_text_segment)
            try load_commands.calcMinHeaderPad(gpa, &macho_file.base.options, .{
                .segments = macho_file.segments.items,
                .dylibs = macho_file.dylibs.items,
                .referenced_dylibs = macho_file.referenced_dylibs.keys(),
            })
        else
            0;
        try allocateSegment(macho_file, @as(u8, @intCast(segment_index)), base_size);
    }
}

fn getSegmentAllocBase(macho_file: *MachO, segment_index: u8) struct { vmaddr: u64, fileoff: u64 } {
    if (segment_index > 0) {
        const prev_segment = macho_file.segments.items[segment_index - 1];
        return .{
            .vmaddr = prev_segment.vmaddr + prev_segment.vmsize,
            .fileoff = prev_segment.fileoff + prev_segment.filesize,
        };
    }
    return .{ .vmaddr = 0, .fileoff = 0 };
}

fn allocateSegment(macho_file: *MachO, segment_index: u8, init_size: u64) !void {
    const segment = &macho_file.segments.items[segment_index];

    if (mem.eql(u8, segment.segName(), "__PAGEZERO")) return; // allocated upon creation

    const base = getSegmentAllocBase(macho_file, segment_index);
    segment.vmaddr = base.vmaddr;
    segment.fileoff = base.fileoff;
    segment.filesize = init_size;
    segment.vmsize = init_size;

    // Allocate the sections according to their alignment at the beginning of the segment.
    const indexes = macho_file.getSectionIndexes(segment_index);
    var start = init_size;

    const slice = macho_file.sections.slice();
    for (slice.items(.header)[indexes.start..indexes.end], 0..) |*header, sect_id| {
        const alignment = try math.powi(u32, 2, header.@"align");
        const start_aligned = mem.alignForward(u64, start, alignment);
        const n_sect = @as(u8, @intCast(indexes.start + sect_id + 1));

        header.offset = if (header.isZerofill())
            0
        else
            @as(u32, @intCast(segment.fileoff + start_aligned));
        header.addr = segment.vmaddr + start_aligned;

        if (slice.items(.first_atom_index)[indexes.start + sect_id]) |first_atom_index| {
            var atom_index = first_atom_index;

            log.debug("allocating local symbols in sect({d}, '{s},{s}')", .{
                n_sect,
                header.segName(),
                header.sectName(),
            });

            while (true) {
                const atom = macho_file.getAtom(atom_index);
                const sym = macho_file.getSymbolPtr(atom.getSymbolWithLoc());
                sym.n_value += header.addr;
                sym.n_sect = n_sect;

                log.debug("  ATOM(%{d}, '{s}') @{x}", .{
                    atom.sym_index,
                    macho_file.getSymbolName(atom.getSymbolWithLoc()),
                    sym.n_value,
                });

                if (atom.getFile() != null) {
                    // Update each symbol contained within the atom
                    var it = Atom.getInnerSymbolsIterator(macho_file, atom_index);
                    while (it.next()) |sym_loc| {
                        const inner_sym = macho_file.getSymbolPtr(sym_loc);
                        inner_sym.n_value = sym.n_value + Atom.calcInnerSymbolOffset(
                            macho_file,
                            atom_index,
                            sym_loc.sym_index,
                        );
                        inner_sym.n_sect = n_sect;
                    }

                    // If there is a section alias, update it now too
                    if (Atom.getSectionAlias(macho_file, atom_index)) |sym_loc| {
                        const alias = macho_file.getSymbolPtr(sym_loc);
                        alias.n_value = sym.n_value;
                        alias.n_sect = n_sect;
                    }
                }

                if (atom.next_index) |next_index| {
                    atom_index = next_index;
                } else break;
            }
        }

        start = start_aligned + header.size;

        if (!header.isZerofill()) {
            segment.filesize = start;
        }
        segment.vmsize = start;
    }

    const page_size = MachO.getPageSize(macho_file.base.options.target.cpu.arch);
    segment.filesize = mem.alignForward(u64, segment.filesize, page_size);
    segment.vmsize = mem.alignForward(u64, segment.vmsize, page_size);
}

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
const calcUuid = @import("uuid.zig").calcUuid;
const dead_strip = @import("dead_strip.zig");
const eh_frame = @import("eh_frame.zig");
const fat = @import("fat.zig");
const link = @import("../../link.zig");
const load_commands = @import("load_commands.zig");
const stubs = @import("stubs.zig");
const thunks = @import("thunks.zig");
const trace = @import("../../tracy.zig").trace;

const Allocator = mem.Allocator;
const Archive = @import("Archive.zig");
const Atom = @import("Atom.zig");
const Cache = std.Build.Cache;
const CodeSignature = @import("CodeSignature.zig");
const Compilation = @import("../../Compilation.zig");
const Dylib = @import("Dylib.zig");
const MachO = @import("../MachO.zig");
const Md5 = std.crypto.hash.Md5;
const LibStub = @import("../tapi.zig").LibStub;
const Object = @import("Object.zig");
const Platform = load_commands.Platform;
const Section = MachO.Section;
const SymbolWithLoc = MachO.SymbolWithLoc;
const TableSection = @import("../table_section.zig").TableSection;
const Trie = @import("Trie.zig");
const UnwindInfo = @import("UnwindInfo.zig");

const std = @import("std");
const build_options = @import("build_options");
const allocPrint = std.fmt.allocPrint;
const assert = std.debug.assert;
const fs = std.fs;
const log = std.log.scoped(.link);
const mem = std.mem;
const Cache = std.Build.Cache;

const mingw = @import("../../mingw.zig");
const link = @import("../../link.zig");
const lldMain = @import("../../main.zig").lldMain;
const trace = @import("../../tracy.zig").trace;

const Allocator = mem.Allocator;

const Coff = @import("../Coff.zig");
const Compilation = @import("../../Compilation.zig");

pub fn linkWithLLD(self: *Coff, comp: *Compilation, prog_node: *std.Progress.Node) !void {
    const tracy = trace(@src());
    defer tracy.end();

    var arena_allocator = std.heap.ArenaAllocator.init(self.base.allocator);
    defer arena_allocator.deinit();
    const arena = arena_allocator.allocator();

    const directory = self.base.options.emit.?.directory; // Just an alias to make it shorter to type.
    const full_out_path = try directory.join(arena, &[_][]const u8{self.base.options.emit.?.sub_path});

    // If there is no Zig code to compile, then we should skip flushing the output file because it
    // will not be part of the linker line anyway.
    const module_obj_path: ?[]const u8 = if (self.base.options.module != null) blk: {
        try self.flushModule(comp, prog_node);

        if (fs.path.dirname(full_out_path)) |dirname| {
            break :blk try fs.path.join(arena, &.{ dirname, self.base.intermediary_basename.? });
        } else {
            break :blk self.base.intermediary_basename.?;
        }
    } else null;

    var sub_prog_node = prog_node.start("LLD Link", 0);
    sub_prog_node.activate();
    sub_prog_node.context.refresh();
    defer sub_prog_node.end();

    const is_lib = self.base.options.output_mode == .Lib;
    const is_dyn_lib = self.base.options.link_mode == .Dynamic and is_lib;
    const is_exe_or_dyn_lib = is_dyn_lib or self.base.options.output_mode == .Exe;
    const link_in_crt = self.base.options.link_libc and is_exe_or_dyn_lib;
    const target = self.base.options.target;

    // See link/Elf.zig for comments on how this mechanism works.
    const id_symlink_basename = "lld.id";

    var man: Cache.Manifest = undefined;
    defer if (!self.base.options.disable_lld_caching) man.deinit();

    var digest: [Cache.hex_digest_len]u8 = undefined;

    if (!self.base.options.disable_lld_caching) {
        man = comp.cache_parent.obtain();
        self.base.releaseLock();

        comptime assert(Compilation.link_hash_implementation_version == 9);

        for (self.base.options.objects) |obj| {
            _ = try man.addFile(obj.path, null);
            man.hash.add(obj.must_link);
        }
        for (comp.c_object_table.keys()) |key| {
            _ = try man.addFile(key.status.success.object_path, null);
        }
        try man.addOptionalFile(module_obj_path);
        man.hash.addOptionalBytes(self.base.options.entry);
        man.hash.addOptional(self.base.options.stack_size_override);
        man.hash.addOptional(self.base.options.image_base_override);
        man.hash.addListOfBytes(self.base.options.lib_dirs);
        man.hash.add(self.base.options.skip_linker_dependencies);
        if (self.base.options.link_libc) {
            man.hash.add(self.base.options.libc_installation != null);
            if (self.base.options.libc_installation) |libc_installation| {
                man.hash.addBytes(libc_installation.crt_dir.?);
                if (target.abi == .msvc) {
                    man.hash.addBytes(libc_installation.msvc_lib_dir.?);
                    man.hash.addBytes(libc_installation.kernel32_lib_dir.?);
                }
            }
        }
        try link.hashAddSystemLibs(&man, self.base.options.system_libs);
        man.hash.addListOfBytes(self.base.options.force_undefined_symbols.keys());
        man.hash.addOptional(self.base.options.subsystem);
        man.hash.add(self.base.options.is_test);
        man.hash.add(self.base.options.tsaware);
        man.hash.add(self.base.options.nxcompat);
        man.hash.add(self.base.options.dynamicbase);
        man.hash.addOptional(self.base.options.allow_shlib_undefined);
        // strip does not need to go into the linker hash because it is part of the hash namespace
        man.hash.addOptional(self.base.options.major_subsystem_version);
        man.hash.addOptional(self.base.options.minor_subsystem_version);
        man.hash.addOptional(self.base.options.version);
        try man.addOptionalFile(self.base.options.module_definition_file);

        // We don't actually care whether it's a cache hit or miss; we just need the digest and the lock.
        _ = try man.hit();
        digest = man.final();
        var prev_digest_buf: [digest.len]u8 = undefined;
        const prev_digest: []u8 = Cache.readSmallFile(
            directory.handle,
            id_symlink_basename,
            &prev_digest_buf,
        ) catch |err| blk: {
            log.debug("COFF LLD new_digest={s} error: {s}", .{ std.fmt.fmtSliceHexLower(&digest), @errorName(err) });
            // Handle this as a cache miss.
            break :blk prev_digest_buf[0..0];
        };
        if (mem.eql(u8, prev_digest, &digest)) {
            log.debug("COFF LLD digest={s} match - skipping invocation", .{std.fmt.fmtSliceHexLower(&digest)});
            // Hot diggity dog! The output binary is already there.
            self.base.lock = man.toOwnedLock();
            return;
        }
        log.debug("COFF LLD prev_digest={s} new_digest={s}", .{ std.fmt.fmtSliceHexLower(prev_digest), std.fmt.fmtSliceHexLower(&digest) });

        // We are about to change the output file to be different, so we invalidate the build hash now.
        directory.handle.deleteFile(id_symlink_basename) catch |err| switch (err) {
            error.FileNotFound => {},
            else => |e| return e,
        };
    }

    if (self.base.options.output_mode == .Obj) {
        // LLD's COFF driver does not support the equivalent of `-r` so we do a simple file copy
        // here. TODO: think carefully about how we can avoid this redundant operation when doing
        // build-obj. See also the corresponding TODO in linkAsArchive.
        const the_object_path = blk: {
            if (self.base.options.objects.len != 0)
                break :blk self.base.options.objects[0].path;

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
        // Create an LLD command line and invoke it.
        var argv = std.ArrayList([]const u8).init(self.base.allocator);
        defer argv.deinit();
        // We will invoke ourselves as a child process to gain access to LLD.
        // This is necessary because LLD does not behave properly as a library -
        // it calls exit() and does not reset all global data between invocations.
        const linker_command = "lld-link";
        try argv.appendSlice(&[_][]const u8{ comp.self_exe_path.?, linker_command });

        try argv.append("-ERRORLIMIT:0");
        try argv.append("-NOLOGO");
        if (!self.base.options.strip) {
            try argv.append("-DEBUG");

            const out_ext = std.fs.path.extension(full_out_path);
            const out_pdb = self.base.options.pdb_out_path orelse try allocPrint(arena, "{s}.pdb", .{
                full_out_path[0 .. full_out_path.len - out_ext.len],
            });

            try argv.append(try allocPrint(arena, "-PDB:{s}", .{out_pdb}));
            try argv.append(try allocPrint(arena, "-PDBALTPATH:{s}", .{out_pdb}));
        }
        if (self.base.options.version) |version| {
            try argv.append(try allocPrint(arena, "-VERSION:{}.{}", .{ version.major, version.minor }));
        }
        if (self.base.options.lto) {
            switch (self.base.options.optimize_mode) {
                .Debug => {},
                .ReleaseSmall => try argv.append("-OPT:lldlto=2"),
                .ReleaseFast, .ReleaseSafe => try argv.append("-OPT:lldlto=3"),
            }
        }
        if (self.base.options.output_mode == .Exe) {
            const stack_size = self.base.options.stack_size_override orelse 16777216;
            try argv.append(try allocPrint(arena, "-STACK:{d}", .{stack_size}));
        }
        if (self.base.options.image_base_override) |image_base| {
            try argv.append(try std.fmt.allocPrint(arena, "-BASE:{d}", .{image_base}));
        }

        if (target.cpu.arch == .x86) {
            try argv.append("-MACHINE:X86");
        } else if (target.cpu.arch == .x86_64) {
            try argv.append("-MACHINE:X64");
        } else if (target.cpu.arch.isARM()) {
            if (target.ptrBitWidth() == 32) {
                try argv.append("-MACHINE:ARM");
            } else {
                try argv.append("-MACHINE:ARM64");
            }
        }

        for (self.base.options.force_undefined_symbols.keys()) |symbol| {
            try argv.append(try allocPrint(arena, "-INCLUDE:{s}", .{symbol}));
        }

        if (is_dyn_lib) {
            try argv.append("-DLL");
        }

        if (self.base.options.entry) |entry| {
            try argv.append(try allocPrint(arena, "-ENTRY:{s}", .{entry}));
        }

        if (self.base.options.tsaware) {
            try argv.append("-tsaware");
        }
        if (self.base.options.nxcompat) {
            try argv.append("-nxcompat");
        }
        if (!self.base.options.dynamicbase) {
            try argv.append("-dynamicbase:NO");
        }
        if (self.base.options.allow_shlib_undefined) |allow_shlib_undefined| {
            if (allow_shlib_undefined) {
                try argv.append("-FORCE:UNRESOLVED");
            }
        }

        try argv.append(try allocPrint(arena, "-OUT:{s}", .{full_out_path}));

        if (self.base.options.implib_emit) |emit| {
            const implib_out_path = try emit.directory.join(arena, &[_][]const u8{emit.sub_path});
            try argv.append(try allocPrint(arena, "-IMPLIB:{s}", .{implib_out_path}));
        }

        if (self.base.options.link_libc) {
            if (self.base.options.libc_installation) |libc_installation| {
                try argv.append(try allocPrint(arena, "-LIBPATH:{s}", .{libc_installation.crt_dir.?}));

                if (target.abi == .msvc) {
                    try argv.append(try allocPrint(arena, "-LIBPATH:{s}", .{libc_installation.msvc_lib_dir.?}));
                    try argv.append(try allocPrint(arena, "-LIBPATH:{s}", .{libc_installation.kernel32_lib_dir.?}));
                }
            }
        }

        for (self.base.options.lib_dirs) |lib_dir| {
            try argv.append(try allocPrint(arena, "-LIBPATH:{s}", .{lib_dir}));
        }

        try argv.ensureUnusedCapacity(self.base.options.objects.len);
        for (self.base.options.objects) |obj| {
            if (obj.must_link) {
                argv.appendAssumeCapacity(try allocPrint(arena, "-WHOLEARCHIVE:{s}", .{obj.path}));
            } else {
                argv.appendAssumeCapacity(obj.path);
            }
        }

        for (comp.c_object_table.keys()) |key| {
            try argv.append(key.status.success.object_path);
        }

        if (module_obj_path) |p| {
            try argv.append(p);
        }

        if (self.base.options.module_definition_file) |def| {
            try argv.append(try allocPrint(arena, "-DEF:{s}", .{def}));
        }

        const resolved_subsystem: ?std.Target.SubSystem = blk: {
            if (self.base.options.subsystem) |explicit| break :blk explicit;
            switch (target.os.tag) {
                .windows => {
                    if (self.base.options.module) |module| {
                        if (module.stage1_flags.have_dllmain_crt_startup or is_dyn_lib)
                            break :blk null;
                        if (module.stage1_flags.have_c_main or self.base.options.is_test or
                            module.stage1_flags.have_winmain_crt_startup or
                            module.stage1_flags.have_wwinmain_crt_startup)
                        {
                            break :blk .Console;
                        }
                        if (module.stage1_flags.have_winmain or module.stage1_flags.have_wwinmain)
                            break :blk .Windows;
                    }
                },
                .uefi => break :blk .EfiApplication,
                else => {},
            }
            break :blk null;
        };

        const Mode = enum { uefi, win32 };
        const mode: Mode = mode: {
            if (resolved_subsystem) |subsystem| {
                const subsystem_suffix = ss: {
                    if (self.base.options.major_subsystem_version) |major| {
                        if (self.base.options.minor_subsystem_version) |minor| {
                            break :ss try allocPrint(arena, ",{d}.{d}", .{ major, minor });
                        } else {
                            break :ss try allocPrint(arena, ",{d}", .{major});
                        }
                    }
                    break :ss "";
                };

                switch (subsystem) {
                    .Console => {
                        try argv.append(try allocPrint(arena, "-SUBSYSTEM:console{s}", .{
                            subsystem_suffix,
                        }));
                        break :mode .win32;
                    },
                    .EfiApplication => {
                        try argv.append(try allocPrint(arena, "-SUBSYSTEM:efi_application{s}", .{
                            subsystem_suffix,
                        }));
                        break :mode .uefi;
                    },
                    .EfiBootServiceDriver => {
                        try argv.append(try allocPrint(arena, "-SUBSYSTEM:efi_boot_service_driver{s}", .{
                            subsystem_suffix,
                        }));
                        break :mode .uefi;
                    },
                    .EfiRom => {
                        try argv.append(try allocPrint(arena, "-SUBSYSTEM:efi_rom{s}", .{
                            subsystem_suffix,
                        }));
                        break :mode .uefi;
                    },
                    .EfiRuntimeDriver => {
                        try argv.append(try allocPrint(arena, "-SUBSYSTEM:efi_runtime_driver{s}", .{
                            subsystem_suffix,
                        }));
                        break :mode .uefi;
                    },
                    .Native => {
                        try argv.append(try allocPrint(arena, "-SUBSYSTEM:native{s}", .{
                            subsystem_suffix,
                        }));
                        break :mode .win32;
                    },
                    .Posix => {
                        try argv.append(try allocPrint(arena, "-SUBSYSTEM:posix{s}", .{
                            subsystem_suffix,
                        }));
                        break :mode .win32;
                    },
                    .Windows => {
                        try argv.append(try allocPrint(arena, "-SUBSYSTEM:windows{s}", .{
                            subsystem_suffix,
                        }));
                        break :mode .win32;
                    },
                }
            } else if (target.os.tag == .uefi) {
                break :mode .uefi;
            } else {
                break :mode .win32;
            }
        };

        switch (mode) {
            .uefi => try argv.appendSlice(&[_][]const u8{
                "-BASE:0",
                "-ENTRY:EfiMain",
                "-OPT:REF",
                "-SAFESEH:NO",
                "-MERGE:.rdata=.data",
                "-NODEFAULTLIB",
                "-SECTION:.xdata,D",
            }),
            .win32 => {
                if (link_in_crt) {
                    if (target.abi.isGnu()) {
                        try argv.append("-lldmingw");

                        if (target.cpu.arch == .x86) {
                            try argv.append("-ALTERNATENAME:__image_base__=___ImageBase");
                        } else {
                            try argv.append("-ALTERNATENAME:__image_base__=__ImageBase");
                        }

                        if (is_dyn_lib) {
                            try argv.append(try comp.get_libc_crt_file(arena, "dllcrt2.obj"));
                            if (target.cpu.arch == .x86) {
                                try argv.append("-ALTERNATENAME:__DllMainCRTStartup@12=_DllMainCRTStartup@12");
                            } else {
                                try argv.append("-ALTERNATENAME:_DllMainCRTStartup=DllMainCRTStartup");
                            }
                        } else {
                            try argv.append(try comp.get_libc_crt_file(arena, "crt2.obj"));
                        }

                        try argv.append(try comp.get_libc_crt_file(arena, "mingw32.lib"));
                        try argv.append(try comp.get_libc_crt_file(arena, "mingwex.lib"));
                        try argv.append(try comp.get_libc_crt_file(arena, "msvcrt-os.lib"));
                        try argv.append(try comp.get_libc_crt_file(arena, "uuid.lib"));

                        for (mingw.always_link_libs) |name| {
                            if (!self.base.options.system_libs.contains(name)) {
                                const lib_basename = try allocPrint(arena, "{s}.lib", .{name});
                                try argv.append(try comp.get_libc_crt_file(arena, lib_basename));
                            }
                        }
                    } else {
                        const lib_str = switch (self.base.options.link_mode) {
                            .Dynamic => "",
                            .Static => "lib",
                        };
                        const d_str = switch (self.base.options.optimize_mode) {
                            .Debug => "d",
                            else => "",
                        };
                        switch (self.base.options.link_mode) {
                            .Static => try argv.append(try allocPrint(arena, "libcmt{s}.lib", .{d_str})),
                            .Dynamic => try argv.append(try allocPrint(arena, "msvcrt{s}.lib", .{d_str})),
                        }

                        try argv.append(try allocPrint(arena, "{s}vcruntime{s}.lib", .{ lib_str, d_str }));
                        try argv.append(try allocPrint(arena, "{s}ucrt{s}.lib", .{ lib_str, d_str }));

                        //Visual C++ 2015 Conformance Changes
                        //https://msdn.microsoft.com/en-us/library/bb531344.aspx
                        try argv.append("legacy_stdio_definitions.lib");

                        // msvcrt depends on kernel32 and ntdll
                        try argv.append("kernel32.lib");
                        try argv.append("ntdll.lib");
                    }
                } else {
                    try argv.append("-NODEFAULTLIB");
                    if (!is_lib and self.base.options.entry == null) {
                        if (self.base.options.module) |module| {
                            if (module.stage1_flags.have_winmain_crt_startup) {
                                try argv.append("-ENTRY:WinMainCRTStartup");
                            } else {
                                try argv.append("-ENTRY:wWinMainCRTStartup");
                            }
                        } else {
                            try argv.append("-ENTRY:wWinMainCRTStartup");
                        }
                    }
                }
            },
        }

        // libc++ dep
        if (self.base.options.link_libcpp) {
            try argv.append(comp.libcxxabi_static_lib.?.full_object_path);
            try argv.append(comp.libcxx_static_lib.?.full_object_path);
        }

        // libunwind dep
        if (self.base.options.link_libunwind) {
            try argv.append(comp.libunwind_static_lib.?.full_object_path);
        }

        if (is_exe_or_dyn_lib and !self.base.options.skip_linker_dependencies) {
            if (!self.base.options.link_libc) {
                if (comp.libc_static_lib) |lib| {
                    try argv.append(lib.full_object_path);
                }
            }
            // MinGW doesn't provide libssp symbols
            if (target.abi.isGnu()) {
                if (comp.libssp_static_lib) |lib| {
                    try argv.append(lib.full_object_path);
                }
            }
            // MSVC compiler_rt is missing some stuff, so we build it unconditionally but
            // and rely on weak linkage to allow MSVC compiler_rt functions to override ours.
            if (comp.compiler_rt_lib) |lib| {
                try argv.append(lib.full_object_path);
            }
        }

        try argv.ensureUnusedCapacity(self.base.options.system_libs.count());
        for (self.base.options.system_libs.keys()) |key| {
            const lib_basename = try allocPrint(arena, "{s}.lib", .{key});
            if (comp.crt_files.get(lib_basename)) |crt_file| {
                argv.appendAssumeCapacity(crt_file.full_object_path);
                continue;
            }
            if (try findLib(arena, lib_basename, self.base.options.lib_dirs)) |full_path| {
                argv.appendAssumeCapacity(full_path);
                continue;
            }
            if (target.abi.isGnu()) {
                const fallback_name = try allocPrint(arena, "lib{s}.dll.a", .{key});
                if (try findLib(arena, fallback_name, self.base.options.lib_dirs)) |full_path| {
                    argv.appendAssumeCapacity(full_path);
                    continue;
                }
            }
            if (target.abi == .msvc) {
                argv.appendAssumeCapacity(lib_basename);
                continue;
            }

            log.err("DLL import library for -l{s} not found", .{key});
            return error.DllImportLibraryNotFound;
        }

        if (self.base.options.verbose_link) {
            // Skip over our own name so that the LLD linker name is the first argv item.
            Compilation.dump_argv(argv.items[1..]);
        }

        if (std.process.can_spawn) {
            // If possible, we run LLD as a child process because it does not always
            // behave properly as a library, unfortunately.
            // https://github.com/ziglang/zig/issues/3825
            var child = std.ChildProcess.init(argv.items, arena);
            if (comp.clang_passthrough_mode) {
                child.stdin_behavior = .Inherit;
                child.stdout_behavior = .Inherit;
                child.stderr_behavior = .Inherit;

                const term = child.spawnAndWait() catch |err| {
                    log.err("unable to spawn {s}: {s}", .{ argv.items[0], @errorName(err) });
                    return error.UnableToSpawnSelf;
                };
                switch (term) {
                    .Exited => |code| {
                        if (code != 0) {
                            std.process.exit(code);
                        }
                    },
                    else => std.process.abort(),
                }
            } else {
                child.stdin_behavior = .Ignore;
                child.stdout_behavior = .Ignore;
                child.stderr_behavior = .Pipe;

                try child.spawn();

                const stderr = try child.stderr.?.reader().readAllAlloc(arena, std.math.maxInt(usize));

                const term = child.wait() catch |err| {
                    log.err("unable to spawn {s}: {s}", .{ argv.items[0], @errorName(err) });
                    return error.UnableToSpawnSelf;
                };

                switch (term) {
                    .Exited => |code| {
                        if (code != 0) {
                            comp.lockAndParseLldStderr(linker_command, stderr);
                            return error.LLDReportedFailure;
                        }
                    },
                    else => {
                        log.err("{s} terminated with stderr:\n{s}", .{ argv.items[0], stderr });
                        return error.LLDCrashed;
                    },
                }

                if (stderr.len != 0) {
                    log.warn("unexpected LLD stderr:\n{s}", .{stderr});
                }
            }
        } else {
            const exit_code = try lldMain(arena, argv.items, false);
            if (exit_code != 0) {
                if (comp.clang_passthrough_mode) {
                    std.process.exit(exit_code);
                } else {
                    return error.LLDReportedFailure;
                }
            }
        }
    }

    if (!self.base.options.disable_lld_caching) {
        // Update the file with the digest. If it fails we can continue; it only
        // means that the next invocation will have an unnecessary cache miss.
        Cache.writeSmallFile(directory.handle, id_symlink_basename, &digest) catch |err| {
            log.warn("failed to save linking hash digest file: {s}", .{@errorName(err)});
        };
        // Again failure here only means an unnecessary cache miss.
        man.writeManifest() catch |err| {
            log.warn("failed to write cache manifest when linking: {s}", .{@errorName(err)});
        };
        // We hang on to this lock so that the output file path can be used without
        // other processes clobbering it.
        self.base.lock = man.toOwnedLock();
    }
}

fn findLib(arena: Allocator, name: []const u8, lib_dirs: []const []const u8) !?[]const u8 {
    for (lib_dirs) |lib_dir| {
        const full_path = try fs.path.join(arena, &.{ lib_dir, name });
        fs.cwd().access(full_path, .{}) catch |err| switch (err) {
            error.FileNotFound => continue,
            else => |e| return e,
        };
        return full_path;
    }
    return null;
}

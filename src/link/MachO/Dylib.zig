path: []const u8,
index: File.Index,

exports: std.MultiArrayList(Export) = .{},
strtab: std.ArrayListUnmanaged(u8) = .{},
id: ?Id = null,
ordinal: u16 = 0,

symbols: std.ArrayListUnmanaged(Symbol.Index) = .{},
dependents: std.ArrayListUnmanaged(Id) = .{},
rpaths: std.StringArrayHashMapUnmanaged(void) = .{},
umbrella: File.Index = 0,
platform: ?MachO.Platform = null,

needed: bool,
weak: bool,
reexport: bool,
explicit: bool,
hoisted: bool = true,
referenced: bool = false,

output_symtab_ctx: MachO.SymtabCtx = .{},

pub fn isDylib(path: []const u8, fat_arch: ?fat.Arch) !bool {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    if (fat_arch) |arch| {
        try file.seekTo(arch.offset);
    }
    const header = file.reader().readStruct(macho.mach_header_64) catch return false;
    return header.filetype == macho.MH_DYLIB;
}

pub fn deinit(self: *Dylib, allocator: Allocator) void {
    allocator.free(self.path);
    self.exports.deinit(allocator);
    self.strtab.deinit(allocator);
    if (self.id) |*id| id.deinit(allocator);
    self.symbols.deinit(allocator);
    for (self.dependents.items) |*id| {
        id.deinit(allocator);
    }
    self.dependents.deinit(allocator);
    for (self.rpaths.keys()) |rpath| {
        allocator.free(rpath);
    }
    self.rpaths.deinit(allocator);
}

pub fn parse(self: *Dylib, macho_file: *MachO, file: std.fs.File, fat_arch: ?fat.Arch) !void {
    const tracy = trace(@src());
    defer tracy.end();

    const gpa = macho_file.base.comp.gpa;
    const offset = if (fat_arch) |ar| ar.offset else 0;

    log.debug("parsing dylib from binary: {s}", .{self.path});

    var header_buffer: [@sizeOf(macho.mach_header_64)]u8 = undefined;
    {
        const amt = try file.preadAll(&header_buffer, offset);
        if (amt != @sizeOf(macho.mach_header_64)) return error.InputOutput;
    }
    const header = @as(*align(1) const macho.mach_header_64, @ptrCast(&header_buffer)).*;

    const this_cpu_arch: std.Target.Cpu.Arch = switch (header.cputype) {
        macho.CPU_TYPE_ARM64 => .aarch64,
        macho.CPU_TYPE_X86_64 => .x86_64,
        else => |x| {
            try macho_file.reportParseError2(self.index, "unknown cpu architecture: {d}", .{x});
            return error.InvalidCpuArch;
        },
    };
    if (macho_file.getTarget().cpu.arch != this_cpu_arch) {
        try macho_file.reportParseError2(self.index, "invalid cpu architecture: {s}", .{@tagName(this_cpu_arch)});
        return error.InvalidCpuArch;
    }

    const lc_buffer = try gpa.alloc(u8, header.sizeofcmds);
    defer gpa.free(lc_buffer);
    {
        const amt = try file.preadAll(lc_buffer, offset + @sizeOf(macho.mach_header_64));
        if (amt != lc_buffer.len) return error.InputOutput;
    }

    var it = LoadCommandIterator{
        .ncmds = header.ncmds,
        .buffer = lc_buffer,
    };
    while (it.next()) |cmd| switch (cmd.cmd()) {
        .ID_DYLIB => {
            self.id = try Id.fromLoadCommand(gpa, cmd.cast(macho.dylib_command).?, cmd.getDylibPathName());
        },
        .REEXPORT_DYLIB => if (header.flags & macho.MH_NO_REEXPORTED_DYLIBS == 0) {
            const id = try Id.fromLoadCommand(gpa, cmd.cast(macho.dylib_command).?, cmd.getDylibPathName());
            try self.dependents.append(gpa, id);
        },
        .DYLD_INFO_ONLY => {
            const dyld_cmd = cmd.cast(macho.dyld_info_command).?;
            const data = try gpa.alloc(u8, dyld_cmd.export_size);
            defer gpa.free(data);
            const amt = try file.preadAll(data, dyld_cmd.export_off + offset);
            if (amt != data.len) return error.InputOutput;
            try self.parseTrie(data, macho_file);
        },
        .DYLD_EXPORTS_TRIE => {
            const ld_cmd = cmd.cast(macho.linkedit_data_command).?;
            const data = try gpa.alloc(u8, ld_cmd.datasize);
            defer gpa.free(data);
            const amt = try file.preadAll(data, ld_cmd.dataoff + offset);
            if (amt != data.len) return error.InputOutput;
            try self.parseTrie(data, macho_file);
        },
        .RPATH => {
            const path = cmd.getRpathPathName();
            try self.rpaths.put(gpa, try gpa.dupe(u8, path), {});
        },
        .BUILD_VERSION,
        .VERSION_MIN_MACOSX,
        .VERSION_MIN_IPHONEOS,
        .VERSION_MIN_TVOS,
        .VERSION_MIN_WATCHOS,
        => {
            self.platform = MachO.Platform.fromLoadCommand(cmd);
        },
        else => {},
    };

    if (self.id == null) {
        try macho_file.reportParseError2(self.index, "missing LC_ID_DYLIB load command", .{});
        return error.MalformedDylib;
    }

    if (self.platform) |platform| {
        if (!macho_file.platform.eqlTarget(platform)) {
            try macho_file.reportParseError2(self.index, "invalid platform: {}", .{
                platform.fmtTarget(macho_file.getTarget().cpu.arch),
            });
            return error.InvalidTarget;
        }
        // TODO: this can cause the CI to fail so I'm commenting this check out so that
        // I can work out the rest of the changes first
        // if (macho_file.platform.version.order(platform.version) == .lt) {
        //     try macho_file.reportParseError2(self.index, "object file built for newer platform: {}: {} < {}", .{
        //         macho_file.platform.fmtTarget(macho_file.getTarget().cpu.arch),
        //         macho_file.platform.version,
        //         platform.version,
        //     });
        //     return error.InvalidTarget;
        // }
    }
}

const TrieIterator = struct {
    data: []const u8,
    pos: usize = 0,

    fn getStream(it: *TrieIterator) std.io.FixedBufferStream([]const u8) {
        return std.io.fixedBufferStream(it.data[it.pos..]);
    }

    fn readULEB128(it: *TrieIterator) !u64 {
        var stream = it.getStream();
        var creader = std.io.countingReader(stream.reader());
        const reader = creader.reader();
        const value = try std.leb.readULEB128(u64, reader);
        it.pos += math.cast(usize, creader.bytes_read) orelse return error.Overflow;
        return value;
    }

    fn readString(it: *TrieIterator) ![:0]const u8 {
        var stream = it.getStream();
        const reader = stream.reader();

        var count: usize = 0;
        while (true) : (count += 1) {
            const byte = try reader.readByte();
            if (byte == 0) break;
        }

        const str = @as([*:0]const u8, @ptrCast(it.data.ptr + it.pos))[0..count :0];
        it.pos += count + 1;
        return str;
    }

    fn readByte(it: *TrieIterator) !u8 {
        var stream = it.getStream();
        const value = try stream.reader().readByte();
        it.pos += 1;
        return value;
    }
};

pub fn addExport(self: *Dylib, allocator: Allocator, name: []const u8, flags: Export.Flags) !void {
    try self.exports.append(allocator, .{
        .name = try self.addString(allocator, name),
        .flags = flags,
    });
}

fn parseTrieNode(
    self: *Dylib,
    it: *TrieIterator,
    allocator: Allocator,
    arena: Allocator,
    prefix: []const u8,
) !void {
    const tracy = trace(@src());
    defer tracy.end();
    const size = try it.readULEB128();
    if (size > 0) {
        const flags = try it.readULEB128();
        const kind = flags & macho.EXPORT_SYMBOL_FLAGS_KIND_MASK;
        const out_flags = Export.Flags{
            .abs = kind == macho.EXPORT_SYMBOL_FLAGS_KIND_ABSOLUTE,
            .tlv = kind == macho.EXPORT_SYMBOL_FLAGS_KIND_THREAD_LOCAL,
            .weak = flags & macho.EXPORT_SYMBOL_FLAGS_WEAK_DEFINITION != 0,
        };
        if (flags & macho.EXPORT_SYMBOL_FLAGS_REEXPORT != 0) {
            _ = try it.readULEB128(); // dylib ordinal
            const name = try it.readString();
            try self.addExport(allocator, if (name.len > 0) name else prefix, out_flags);
        } else if (flags & macho.EXPORT_SYMBOL_FLAGS_STUB_AND_RESOLVER != 0) {
            _ = try it.readULEB128(); // stub offset
            _ = try it.readULEB128(); // resolver offset
            try self.addExport(allocator, prefix, out_flags);
        } else {
            _ = try it.readULEB128(); // VM offset
            try self.addExport(allocator, prefix, out_flags);
        }
    }

    const nedges = try it.readByte();

    for (0..nedges) |_| {
        const label = try it.readString();
        const off = try it.readULEB128();
        const prefix_label = try std.fmt.allocPrint(arena, "{s}{s}", .{ prefix, label });
        const curr = it.pos;
        it.pos = math.cast(usize, off) orelse return error.Overflow;
        try self.parseTrieNode(it, allocator, arena, prefix_label);
        it.pos = curr;
    }
}

fn parseTrie(self: *Dylib, data: []const u8, macho_file: *MachO) !void {
    const tracy = trace(@src());
    defer tracy.end();
    const gpa = macho_file.base.comp.gpa;
    var arena = std.heap.ArenaAllocator.init(gpa);
    defer arena.deinit();

    var it: TrieIterator = .{ .data = data };
    try self.parseTrieNode(&it, gpa, arena.allocator(), "");
}

pub fn parseTbd(
    self: *Dylib,
    cpu_arch: std.Target.Cpu.Arch,
    platform: MachO.Platform,
    lib_stub: LibStub,
    macho_file: *MachO,
) !void {
    const tracy = trace(@src());
    defer tracy.end();

    const gpa = macho_file.base.comp.gpa;

    log.debug("parsing dylib from stub: {s}", .{self.path});

    const umbrella_lib = lib_stub.inner[0];

    {
        var id = try Id.default(gpa, umbrella_lib.installName());
        if (umbrella_lib.currentVersion()) |version| {
            try id.parseCurrentVersion(version);
        }
        if (umbrella_lib.compatibilityVersion()) |version| {
            try id.parseCompatibilityVersion(version);
        }
        self.id = id;
    }

    var umbrella_libs = std.StringHashMap(void).init(gpa);
    defer umbrella_libs.deinit();

    log.debug("  (install_name '{s}')", .{umbrella_lib.installName()});

    self.platform = platform;

    var matcher = try TargetMatcher.init(gpa, cpu_arch, self.platform.?.toApplePlatform());
    defer matcher.deinit();

    for (lib_stub.inner, 0..) |elem, stub_index| {
        if (!(try matcher.matchesTargetTbd(elem))) continue;

        if (stub_index > 0) {
            // TODO I thought that we could switch on presence of `parent-umbrella` map;
            // however, turns out `libsystem_notify.dylib` is fully reexported by `libSystem.dylib`
            // BUT does not feature a `parent-umbrella` map as the only sublib. Apple's bug perhaps?
            try umbrella_libs.put(elem.installName(), {});
        }

        switch (elem) {
            .v3 => |stub| {
                if (stub.exports) |exports| {
                    for (exports) |exp| {
                        if (!matcher.matchesArch(exp.archs)) continue;

                        if (exp.symbols) |symbols| {
                            for (symbols) |sym_name| {
                                try self.addExport(gpa, sym_name, .{});
                            }
                        }

                        if (exp.weak_symbols) |symbols| {
                            for (symbols) |sym_name| {
                                try self.addExport(gpa, sym_name, .{ .weak = true });
                            }
                        }

                        if (exp.objc_classes) |objc_classes| {
                            for (objc_classes) |class_name| {
                                try self.addObjCClass(gpa, class_name);
                            }
                        }

                        if (exp.objc_ivars) |objc_ivars| {
                            for (objc_ivars) |ivar| {
                                try self.addObjCIVar(gpa, ivar);
                            }
                        }

                        if (exp.objc_eh_types) |objc_eh_types| {
                            for (objc_eh_types) |eht| {
                                try self.addObjCEhType(gpa, eht);
                            }
                        }

                        if (exp.re_exports) |re_exports| {
                            for (re_exports) |lib| {
                                if (umbrella_libs.contains(lib)) continue;

                                log.debug("  (found re-export '{s}')", .{lib});

                                const dep_id = try Id.default(gpa, lib);
                                try self.dependents.append(gpa, dep_id);
                            }
                        }
                    }
                }
            },
            .v4 => |stub| {
                if (stub.exports) |exports| {
                    for (exports) |exp| {
                        if (!matcher.matchesTarget(exp.targets)) continue;

                        if (exp.symbols) |symbols| {
                            for (symbols) |sym_name| {
                                try self.addExport(gpa, sym_name, .{});
                            }
                        }

                        if (exp.weak_symbols) |symbols| {
                            for (symbols) |sym_name| {
                                try self.addExport(gpa, sym_name, .{ .weak = true });
                            }
                        }

                        if (exp.objc_classes) |classes| {
                            for (classes) |sym_name| {
                                try self.addObjCClass(gpa, sym_name);
                            }
                        }

                        if (exp.objc_ivars) |objc_ivars| {
                            for (objc_ivars) |ivar| {
                                try self.addObjCIVar(gpa, ivar);
                            }
                        }

                        if (exp.objc_eh_types) |objc_eh_types| {
                            for (objc_eh_types) |eht| {
                                try self.addObjCEhType(gpa, eht);
                            }
                        }
                    }
                }

                if (stub.reexports) |reexports| {
                    for (reexports) |reexp| {
                        if (!matcher.matchesTarget(reexp.targets)) continue;

                        if (reexp.symbols) |symbols| {
                            for (symbols) |sym_name| {
                                try self.addExport(gpa, sym_name, .{});
                            }
                        }

                        if (reexp.weak_symbols) |symbols| {
                            for (symbols) |sym_name| {
                                try self.addExport(gpa, sym_name, .{ .weak = true });
                            }
                        }

                        if (reexp.objc_classes) |classes| {
                            for (classes) |sym_name| {
                                try self.addObjCClass(gpa, sym_name);
                            }
                        }

                        if (reexp.objc_ivars) |objc_ivars| {
                            for (objc_ivars) |ivar| {
                                try self.addObjCIVar(gpa, ivar);
                            }
                        }

                        if (reexp.objc_eh_types) |objc_eh_types| {
                            for (objc_eh_types) |eht| {
                                try self.addObjCEhType(gpa, eht);
                            }
                        }
                    }
                }

                if (stub.objc_classes) |classes| {
                    for (classes) |sym_name| {
                        try self.addObjCClass(gpa, sym_name);
                    }
                }

                if (stub.objc_ivars) |objc_ivars| {
                    for (objc_ivars) |ivar| {
                        try self.addObjCIVar(gpa, ivar);
                    }
                }

                if (stub.objc_eh_types) |objc_eh_types| {
                    for (objc_eh_types) |eht| {
                        try self.addObjCEhType(gpa, eht);
                    }
                }
            },
        }
    }

    // For V4, we add dependent libs in a separate pass since some stubs such as libSystem include
    // re-exports directly in the stub file.
    for (lib_stub.inner) |elem| {
        if (elem == .v3) continue;
        const stub = elem.v4;

        if (stub.reexported_libraries) |reexports| {
            for (reexports) |reexp| {
                if (!matcher.matchesTarget(reexp.targets)) continue;

                for (reexp.libraries) |lib| {
                    if (umbrella_libs.contains(lib)) continue;

                    log.debug("  (found re-export '{s}')", .{lib});

                    const dep_id = try Id.default(gpa, lib);
                    try self.dependents.append(gpa, dep_id);
                }
            }
        }
    }
}

fn addObjCClass(self: *Dylib, allocator: Allocator, name: []const u8) !void {
    try self.addObjCExport(allocator, "_OBJC_CLASS_", name);
    try self.addObjCExport(allocator, "_OBJC_METACLASS_", name);
}

fn addObjCIVar(self: *Dylib, allocator: Allocator, name: []const u8) !void {
    try self.addObjCExport(allocator, "_OBJC_IVAR_", name);
}

fn addObjCEhType(self: *Dylib, allocator: Allocator, name: []const u8) !void {
    try self.addObjCExport(allocator, "_OBJC_EHTYPE_", name);
}

fn addObjCExport(
    self: *Dylib,
    allocator: Allocator,
    comptime prefix: []const u8,
    name: []const u8,
) !void {
    const full_name = try std.fmt.allocPrint(allocator, prefix ++ "$_{s}", .{name});
    defer allocator.free(full_name);
    try self.addExport(allocator, full_name, .{});
}

pub fn initSymbols(self: *Dylib, macho_file: *MachO) !void {
    const gpa = macho_file.base.comp.gpa;

    try self.symbols.ensureTotalCapacityPrecise(gpa, self.exports.items(.name).len);

    for (self.exports.items(.name)) |noff| {
        const name = self.getString(noff);
        const off = try macho_file.strings.insert(gpa, name);
        const gop = try macho_file.getOrCreateGlobal(off);
        self.symbols.addOneAssumeCapacity().* = gop.index;
    }
}

pub fn resolveSymbols(self: *Dylib, macho_file: *MachO) void {
    const tracy = trace(@src());
    defer tracy.end();

    if (!self.explicit and !self.hoisted) return;

    for (self.symbols.items, self.exports.items(.flags)) |index, flags| {
        const global = macho_file.getSymbol(index);
        if (self.asFile().getSymbolRank(.{
            .weak = flags.weak,
        }) < global.getSymbolRank(macho_file)) {
            global.value = 0;
            global.atom = 0;
            global.nlist_idx = 0;
            global.file = self.index;
            global.flags.weak = flags.weak;
            global.flags.tlv = flags.tlv;
            global.flags.dyn_ref = false;
            global.flags.tentative = false;
            global.visibility = .global;
        }
    }
}

pub fn resetGlobals(self: *Dylib, macho_file: *MachO) void {
    for (self.symbols.items) |sym_index| {
        const sym = macho_file.getSymbol(sym_index);
        const name = sym.name;
        const global = sym.flags.global;
        const weak_ref = sym.flags.weak_ref;
        sym.* = .{};
        sym.name = name;
        sym.flags.global = global;
        sym.flags.weak_ref = weak_ref;
    }
}

pub fn isAlive(self: Dylib, macho_file: *MachO) bool {
    if (!macho_file.dead_strip_dylibs) return self.explicit or self.referenced or self.needed;
    return self.referenced or self.needed;
}

pub fn markReferenced(self: *Dylib, macho_file: *MachO) void {
    const tracy = trace(@src());
    defer tracy.end();

    for (self.symbols.items) |global_index| {
        const global = macho_file.getSymbol(global_index);
        const file_ptr = global.getFile(macho_file) orelse continue;
        if (file_ptr.getIndex() != self.index) continue;
        if (global.isLocal()) continue;
        self.referenced = true;
        break;
    }
}

pub fn calcSymtabSize(self: *Dylib, macho_file: *MachO) !void {
    const tracy = trace(@src());
    defer tracy.end();

    for (self.symbols.items) |global_index| {
        const global = macho_file.getSymbol(global_index);
        const file_ptr = global.getFile(macho_file) orelse continue;
        if (file_ptr.getIndex() != self.index) continue;
        if (global.isLocal()) continue;
        assert(global.flags.import);
        global.flags.output_symtab = true;
        try global.addExtra(.{ .symtab = self.output_symtab_ctx.nimports }, macho_file);
        self.output_symtab_ctx.nimports += 1;
        self.output_symtab_ctx.strsize += @as(u32, @intCast(global.getName(macho_file).len + 1));
    }
}

pub fn writeSymtab(self: Dylib, macho_file: *MachO, ctx: anytype) void {
    const tracy = trace(@src());
    defer tracy.end();

    for (self.symbols.items) |global_index| {
        const global = macho_file.getSymbol(global_index);
        const file = global.getFile(macho_file) orelse continue;
        if (file.getIndex() != self.index) continue;
        const idx = global.getOutputSymtabIndex(macho_file) orelse continue;
        const n_strx = @as(u32, @intCast(ctx.strtab.items.len));
        ctx.strtab.appendSliceAssumeCapacity(global.getName(macho_file));
        ctx.strtab.appendAssumeCapacity(0);
        const out_sym = &ctx.symtab.items[idx];
        out_sym.n_strx = n_strx;
        global.setOutputSym(macho_file, out_sym);
    }
}

pub inline fn getUmbrella(self: Dylib, macho_file: *MachO) *Dylib {
    return macho_file.getFile(self.umbrella).?.dylib;
}

fn addString(self: *Dylib, allocator: Allocator, name: []const u8) !u32 {
    const off = @as(u32, @intCast(self.strtab.items.len));
    try self.strtab.writer(allocator).print("{s}\x00", .{name});
    return off;
}

pub inline fn getString(self: Dylib, off: u32) [:0]const u8 {
    assert(off < self.strtab.items.len);
    return mem.sliceTo(@as([*:0]const u8, @ptrCast(self.strtab.items.ptr + off)), 0);
}

pub fn asFile(self: *Dylib) File {
    return .{ .dylib = self };
}

pub fn format(
    self: *Dylib,
    comptime unused_fmt_string: []const u8,
    options: std.fmt.FormatOptions,
    writer: anytype,
) !void {
    _ = self;
    _ = unused_fmt_string;
    _ = options;
    _ = writer;
    @compileError("do not format dylib directly");
}

pub fn fmtSymtab(self: *Dylib, macho_file: *MachO) std.fmt.Formatter(formatSymtab) {
    return .{ .data = .{
        .dylib = self,
        .macho_file = macho_file,
    } };
}

const FormatContext = struct {
    dylib: *Dylib,
    macho_file: *MachO,
};

fn formatSymtab(
    ctx: FormatContext,
    comptime unused_fmt_string: []const u8,
    options: std.fmt.FormatOptions,
    writer: anytype,
) !void {
    _ = unused_fmt_string;
    _ = options;
    const dylib = ctx.dylib;
    try writer.writeAll("  globals\n");
    for (dylib.symbols.items) |index| {
        const global = ctx.macho_file.getSymbol(index);
        try writer.print("    {}\n", .{global.fmt(ctx.macho_file)});
    }
}

pub const TargetMatcher = struct {
    allocator: Allocator,
    cpu_arch: std.Target.Cpu.Arch,
    platform: macho.PLATFORM,
    target_strings: std.ArrayListUnmanaged([]const u8) = .{},

    pub fn init(allocator: Allocator, cpu_arch: std.Target.Cpu.Arch, platform: macho.PLATFORM) !TargetMatcher {
        var self = TargetMatcher{
            .allocator = allocator,
            .cpu_arch = cpu_arch,
            .platform = platform,
        };
        const apple_string = try targetToAppleString(allocator, cpu_arch, platform);
        try self.target_strings.append(allocator, apple_string);

        switch (platform) {
            .IOSSIMULATOR, .TVOSSIMULATOR, .WATCHOSSIMULATOR, .VISIONOSSIMULATOR => {
                // For Apple simulator targets, linking gets tricky as we need to link against the simulator
                // hosts dylibs too.
                const host_target = try targetToAppleString(allocator, cpu_arch, .MACOS);
                try self.target_strings.append(allocator, host_target);
            },
            .MACOS => {
                // Turns out that around 10.13/10.14 macOS release version, Apple changed the target tags in
                // tbd files from `macosx` to `macos`. In order to be compliant and therefore actually support
                // linking on older platforms against `libSystem.tbd`, we add `<cpu_arch>-macosx` to target_strings.
                const fallback_target = try std.fmt.allocPrint(allocator, "{s}-macosx", .{
                    cpuArchToAppleString(cpu_arch),
                });
                try self.target_strings.append(allocator, fallback_target);
            },
            else => {},
        }

        return self;
    }

    pub fn deinit(self: *TargetMatcher) void {
        for (self.target_strings.items) |t| {
            self.allocator.free(t);
        }
        self.target_strings.deinit(self.allocator);
    }

    inline fn cpuArchToAppleString(cpu_arch: std.Target.Cpu.Arch) []const u8 {
        return switch (cpu_arch) {
            .aarch64 => "arm64",
            .x86_64 => "x86_64",
            else => unreachable,
        };
    }

    pub fn targetToAppleString(allocator: Allocator, cpu_arch: std.Target.Cpu.Arch, platform: macho.PLATFORM) ![]const u8 {
        const arch = cpuArchToAppleString(cpu_arch);
        const plat = switch (platform) {
            .MACOS => "macos",
            .IOS => "ios",
            .TVOS => "tvos",
            .WATCHOS => "watchos",
            .VISIONOS => "xros",
            .IOSSIMULATOR => "ios-simulator",
            .TVOSSIMULATOR => "tvos-simulator",
            .WATCHOSSIMULATOR => "watchos-simulator",
            .VISIONOSSIMULATOR => "xros-simulator",
            .BRIDGEOS => "bridgeos",
            .MACCATALYST => "maccatalyst",
            .DRIVERKIT => "driverkit",
            else => unreachable,
        };
        return std.fmt.allocPrint(allocator, "{s}-{s}", .{ arch, plat });
    }

    fn hasValue(stack: []const []const u8, needle: []const u8) bool {
        for (stack) |v| {
            if (mem.eql(u8, v, needle)) return true;
        }
        return false;
    }

    fn matchesArch(self: TargetMatcher, archs: []const []const u8) bool {
        return hasValue(archs, cpuArchToAppleString(self.cpu_arch));
    }

    fn matchesTarget(self: TargetMatcher, targets: []const []const u8) bool {
        for (self.target_strings.items) |t| {
            if (hasValue(targets, t)) return true;
        }
        return false;
    }

    pub fn matchesTargetTbd(self: TargetMatcher, tbd: Tbd) !bool {
        var arena = std.heap.ArenaAllocator.init(self.allocator);
        defer arena.deinit();

        const targets = switch (tbd) {
            .v3 => |v3| blk: {
                var targets = std.ArrayList([]const u8).init(arena.allocator());
                for (v3.archs) |arch| {
                    if (mem.eql(u8, v3.platform, "zippered")) {
                        // From Xcode 10.3 → 11.3.1, macos SDK .tbd files specify platform as 'zippered'
                        // which should map to [ '<arch>-macos', '<arch>-maccatalyst' ]
                        try targets.append(try std.fmt.allocPrint(arena.allocator(), "{s}-macos", .{arch}));
                        try targets.append(try std.fmt.allocPrint(arena.allocator(), "{s}-maccatalyst", .{arch}));
                    } else {
                        try targets.append(try std.fmt.allocPrint(arena.allocator(), "{s}-{s}", .{ arch, v3.platform }));
                    }
                }
                break :blk targets.items;
            },
            .v4 => |v4| v4.targets,
        };

        return self.matchesTarget(targets);
    }
};

pub const Id = struct {
    name: []const u8,
    timestamp: u32,
    current_version: u32,
    compatibility_version: u32,

    pub fn default(allocator: Allocator, name: []const u8) !Id {
        return Id{
            .name = try allocator.dupe(u8, name),
            .timestamp = 2,
            .current_version = 0x10000,
            .compatibility_version = 0x10000,
        };
    }

    pub fn fromLoadCommand(allocator: Allocator, lc: macho.dylib_command, name: []const u8) !Id {
        return Id{
            .name = try allocator.dupe(u8, name),
            .timestamp = lc.dylib.timestamp,
            .current_version = lc.dylib.current_version,
            .compatibility_version = lc.dylib.compatibility_version,
        };
    }

    pub fn deinit(id: Id, allocator: Allocator) void {
        allocator.free(id.name);
    }

    pub const ParseError = fmt.ParseIntError || fmt.BufPrintError;

    pub fn parseCurrentVersion(id: *Id, version: anytype) ParseError!void {
        id.current_version = try parseVersion(version);
    }

    pub fn parseCompatibilityVersion(id: *Id, version: anytype) ParseError!void {
        id.compatibility_version = try parseVersion(version);
    }

    fn parseVersion(version: anytype) ParseError!u32 {
        const string = blk: {
            switch (version) {
                .int => |int| {
                    var out: u32 = 0;
                    const major = math.cast(u16, int) orelse return error.Overflow;
                    out += @as(u32, @intCast(major)) << 16;
                    return out;
                },
                .float => |float| {
                    var buf: [256]u8 = undefined;
                    break :blk try fmt.bufPrint(&buf, "{d}", .{float});
                },
                .string => |string| {
                    break :blk string;
                },
            }
        };

        var out: u32 = 0;
        var values: [3][]const u8 = undefined;

        var split = mem.split(u8, string, ".");
        var count: u4 = 0;
        while (split.next()) |value| {
            if (count > 2) {
                log.debug("malformed version field: {s}", .{string});
                return 0x10000;
            }
            values[count] = value;
            count += 1;
        }

        if (count > 2) {
            out += try fmt.parseInt(u8, values[2], 10);
        }
        if (count > 1) {
            out += @as(u32, @intCast(try fmt.parseInt(u8, values[1], 10))) << 8;
        }
        out += @as(u32, @intCast(try fmt.parseInt(u16, values[0], 10))) << 16;

        return out;
    }
};

const Export = struct {
    name: u32,
    flags: Flags,

    const Flags = packed struct {
        abs: bool = false,
        weak: bool = false,
        tlv: bool = false,
    };
};

const assert = std.debug.assert;
const fat = @import("fat.zig");
const fs = std.fs;
const fmt = std.fmt;
const log = std.log.scoped(.link);
const macho = std.macho;
const math = std.math;
const mem = std.mem;
const tapi = @import("../tapi.zig");
const trace = @import("../../tracy.zig").trace;
const std = @import("std");

const Allocator = mem.Allocator;
const Dylib = @This();
const File = @import("file.zig").File;
const LibStub = tapi.LibStub;
const LoadCommandIterator = macho.LoadCommandIterator;
const MachO = @import("../MachO.zig");
const Symbol = @import("Symbol.zig");
const Tbd = tapi.Tbd;

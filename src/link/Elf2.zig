base: link.File,
mf: MappedFile,
nodes: std.MultiArrayList(Node),
symtab: std.ArrayList(Symbol),
shstrtab: StringTable,
strtab: StringTable,
globals: std.AutoArrayHashMapUnmanaged(u32, Symbol.Index),
navs: std.AutoArrayHashMapUnmanaged(InternPool.Nav.Index, Symbol.Index),
uavs: std.AutoArrayHashMapUnmanaged(InternPool.Index, Symbol.Index),
lazy: std.EnumArray(link.File.LazySymbol.Kind, struct {
    map: std.AutoArrayHashMapUnmanaged(InternPool.Index, Symbol.Index),
    pending_index: u32,
}),
pending_uavs: std.AutoArrayHashMapUnmanaged(InternPool.Index, struct {
    alignment: InternPool.Alignment,
    src_loc: Zcu.LazySrcLoc,
}),
relocs: std.ArrayList(Reloc),
/// This is hiding actual bugs with global symbols! Reconsider once they are implemented correctly.
entry_hack: Symbol.Index,

pub const Node = union(enum) {
    file,
    ehdr,
    shdr,
    segment: u32,
    section: Symbol.Index,
    nav: InternPool.Nav.Index,
    uav: InternPool.Index,
    lazy_code: InternPool.Index,
    lazy_const_data: InternPool.Index,

    pub const Tag = @typeInfo(Node).@"union".tag_type.?;

    const known_count = @typeInfo(@TypeOf(known)).@"struct".fields.len;
    const known = known: {
        const Known = enum {
            file,
            seg_rodata,
            ehdr,
            phdr,
            shdr,
            seg_text,
            seg_data,
        };
        var mut_known: std.enums.EnumFieldStruct(
            Known,
            MappedFile.Node.Index,
            null,
        ) = undefined;
        for (@typeInfo(Known).@"enum".fields) |field|
            @field(mut_known, field.name) = @enumFromInt(field.value);
        break :known mut_known;
    };

    comptime {
        if (!std.debug.runtime_safety) std.debug.assert(@sizeOf(Node) == 8);
    }
};

pub const StringTable = struct {
    map: std.HashMapUnmanaged(u32, void, StringTable.Context, std.hash_map.default_max_load_percentage),
    size: u32,

    const Context = struct {
        slice: []const u8,

        pub fn eql(_: Context, lhs_key: u32, rhs_key: u32) bool {
            return lhs_key == rhs_key;
        }

        pub fn hash(ctx: Context, key: u32) u64 {
            return std.hash_map.hashString(std.mem.sliceTo(ctx.slice[key..], 0));
        }
    };

    const Adapter = struct {
        slice: []const u8,

        pub fn eql(adapter: Adapter, lhs_key: []const u8, rhs_key: u32) bool {
            return std.mem.startsWith(u8, adapter.slice[rhs_key..], lhs_key) and
                adapter.slice[rhs_key + lhs_key.len] == 0;
        }

        pub fn hash(_: Adapter, key: []const u8) u64 {
            assert(std.mem.indexOfScalar(u8, key, 0) == null);
            return std.hash_map.hashString(key);
        }
    };

    pub fn get(
        st: *StringTable,
        gpa: std.mem.Allocator,
        mf: *MappedFile,
        ni: MappedFile.Node.Index,
        key: []const u8,
    ) !u32 {
        const slice_const = ni.sliceConst(mf);
        const gop = try st.map.getOrPutContextAdapted(
            gpa,
            key,
            StringTable.Adapter{ .slice = slice_const },
            .{ .slice = slice_const },
        );
        if (gop.found_existing) return gop.key_ptr.*;
        const old_size = st.size;
        const new_size: u32 = @intCast(old_size + key.len + 1);
        st.size = new_size;
        try ni.resize(mf, gpa, new_size);
        const slice = ni.slice(mf)[old_size..];
        @memcpy(slice[0..key.len], key);
        slice[key.len] = 0;
        gop.key_ptr.* = old_size;
        return old_size;
    }
};

pub const Symbol = struct {
    ni: MappedFile.Node.Index,
    /// Relocations contained within this symbol
    loc_relocs: Reloc.Index,
    /// Relocations targeting this symbol
    target_relocs: Reloc.Index,
    unused: u32 = 0,

    pub const Index = enum(u32) {
        null,
        symtab,
        shstrtab,
        strtab,
        rodata,
        text,
        data,
        tdata,
        _,

        pub fn get(si: Symbol.Index, elf: *Elf) *Symbol {
            return &elf.symtab.items[@intFromEnum(si)];
        }

        pub fn node(si: Symbol.Index, elf: *Elf) MappedFile.Node.Index {
            const ni = si.get(elf).ni;
            assert(ni != .none);
            return ni;
        }

        pub const InitOptions = struct {
            name: []const u8 = "",
            size: std.elf.Word = 0,
            type: std.elf.STT,
            bind: std.elf.STB = .LOCAL,
            visibility: std.elf.STV = .DEFAULT,
            shndx: std.elf.Section = std.elf.SHN_UNDEF,
        };
        pub fn init(si: Symbol.Index, elf: *Elf, opts: InitOptions) !void {
            const name_entry = try elf.string(.strtab, opts.name);
            try Symbol.Index.symtab.node(elf).resize(
                &elf.mf,
                elf.base.comp.gpa,
                @as(usize, switch (elf.identClass()) {
                    .NONE, _ => unreachable,
                    .@"32" => @sizeOf(std.elf.Elf32.Sym),
                    .@"64" => @sizeOf(std.elf.Elf64.Sym),
                }) * elf.symtab.items.len,
            );
            switch (elf.symPtr(si)) {
                inline else => |sym| sym.* = .{
                    .name = name_entry,
                    .value = 0,
                    .size = opts.size,
                    .info = .{
                        .type = opts.type,
                        .bind = opts.bind,
                    },
                    .other = .{
                        .visibility = opts.visibility,
                    },
                    .shndx = opts.shndx,
                },
            }
        }

        pub fn applyLocationRelocs(si: Symbol.Index, elf: *Elf) void {
            for (elf.relocs.items[@intFromEnum(si.get(elf).loc_relocs)..]) |*reloc| {
                if (reloc.loc != si) break;
                reloc.apply(elf);
            }
        }

        pub fn applyTargetRelocs(si: Symbol.Index, elf: *Elf) void {
            var ri = si.get(elf).target_relocs;
            while (ri != .none) {
                const reloc = ri.get(elf);
                assert(reloc.target == si);
                reloc.apply(elf);
                ri = reloc.next;
            }
        }

        pub fn deleteLocationRelocs(si: Symbol.Index, elf: *Elf) void {
            const sym = si.get(elf);
            for (elf.relocs.items[@intFromEnum(sym.loc_relocs)..]) |*reloc| {
                if (reloc.loc != si) break;
                reloc.delete(elf);
            }
            sym.loc_relocs = .none;
        }
    };

    comptime {
        if (!std.debug.runtime_safety) std.debug.assert(@sizeOf(Symbol) == 16);
    }
};

pub const Reloc = extern struct {
    type: Reloc.Type,
    prev: Reloc.Index,
    next: Reloc.Index,
    loc: Symbol.Index,
    target: Symbol.Index,
    unused: u32,
    offset: u64,
    addend: i64,

    pub const Type = extern union {
        x86_64: std.elf.R_X86_64,
        aarch64: std.elf.R_AARCH64,
        riscv: std.elf.R_RISCV,
        ppc64: std.elf.R_PPC64,
    };

    pub const Index = enum(u32) {
        none = std.math.maxInt(u32),
        _,

        pub fn get(si: Reloc.Index, elf: *Elf) *Reloc {
            return &elf.relocs.items[@intFromEnum(si)];
        }
    };

    pub fn apply(reloc: *const Reloc, elf: *Elf) void {
        const target_endian = elf.endian();
        switch (reloc.loc.get(elf).ni) {
            .none => return,
            else => |ni| if (ni.hasMoved(&elf.mf)) return,
        }
        switch (reloc.target.get(elf).ni) {
            .none => return,
            else => |ni| if (ni.hasMoved(&elf.mf)) return,
        }
        switch (elf.shdrSlice()) {
            inline else => |shdr, class| {
                const sym = @field(elf.symSlice(), @tagName(class));
                const loc_sym = &sym[@intFromEnum(reloc.loc)];
                const loc_shndx =
                    std.mem.toNative(@TypeOf(loc_sym.shndx), loc_sym.shndx, target_endian);
                assert(loc_shndx != std.elf.SHN_UNDEF);
                const loc_sh = &shdr[loc_shndx];
                const loc_value = std.mem.toNative(
                    @TypeOf(loc_sym.value),
                    loc_sym.value,
                    target_endian,
                ) + reloc.offset;
                const loc_sh_addr =
                    std.mem.toNative(@TypeOf(loc_sh.addr), loc_sh.addr, target_endian);
                const loc_sh_offset =
                    std.mem.toNative(@TypeOf(loc_sh.offset), loc_sh.offset, target_endian);
                const loc_file_offset: usize = @intCast(loc_value - loc_sh_addr + loc_sh_offset);
                const target_sym = &sym[@intFromEnum(reloc.target)];
                const target_value = std.mem.toNative(
                    @TypeOf(target_sym.value),
                    target_sym.value,
                    target_endian,
                ) +% @as(u64, @bitCast(reloc.addend));
                switch (elf.ehdrField(.machine)) {
                    else => |machine| @panic(@tagName(machine)),
                    .X86_64 => switch (reloc.type.x86_64) {
                        else => |kind| @panic(@tagName(kind)),
                        .@"64" => std.mem.writeInt(
                            u64,
                            elf.mf.contents[loc_file_offset..][0..8],
                            target_value,
                            target_endian,
                        ),
                        .PC32 => std.mem.writeInt(
                            i32,
                            elf.mf.contents[loc_file_offset..][0..4],
                            @intCast(@as(i64, @bitCast(target_value -% loc_value))),
                            target_endian,
                        ),
                        .@"32" => std.mem.writeInt(
                            u32,
                            elf.mf.contents[loc_file_offset..][0..4],
                            @intCast(target_value),
                            target_endian,
                        ),
                        .TPOFF32 => {
                            const phdr = @field(elf.phdrSlice(), @tagName(class));
                            const ph = &phdr[4];
                            assert(std.mem.toNative(
                                @TypeOf(ph.type),
                                ph.type,
                                target_endian,
                            ) == std.elf.PT_TLS);
                            std.mem.writeInt(
                                i32,
                                elf.mf.contents[loc_file_offset..][0..4],
                                @intCast(@as(i64, @bitCast(target_value -% std.mem.toNative(
                                    @TypeOf(ph.memsz),
                                    ph.memsz,
                                    target_endian,
                                )))),
                                target_endian,
                            );
                        },
                    },
                }
            },
        }
    }

    pub fn delete(reloc: *Reloc, elf: *Elf) void {
        switch (reloc.prev) {
            .none => {
                const target = reloc.target.get(elf);
                assert(target.target_relocs.get(elf) == reloc);
                target.target_relocs = reloc.next;
            },
            else => |prev| prev.get(elf).next = reloc.next,
        }
        switch (reloc.next) {
            .none => {},
            else => |next| next.get(elf).prev = reloc.prev,
        }
        reloc.* = undefined;
    }

    comptime {
        if (!std.debug.runtime_safety) std.debug.assert(@sizeOf(Reloc) == 40);
    }
};

pub fn open(
    arena: std.mem.Allocator,
    comp: *Compilation,
    path: std.Build.Cache.Path,
    options: link.File.OpenOptions,
) !*Elf {
    return create(arena, comp, path, options);
}
pub fn createEmpty(
    arena: std.mem.Allocator,
    comp: *Compilation,
    path: std.Build.Cache.Path,
    options: link.File.OpenOptions,
) !*Elf {
    return create(arena, comp, path, options);
}
fn create(
    arena: std.mem.Allocator,
    comp: *Compilation,
    path: std.Build.Cache.Path,
    options: link.File.OpenOptions,
) !*Elf {
    _ = options;
    const target = &comp.root_mod.resolved_target.result;
    assert(target.ofmt == .elf);
    const class: std.elf.CLASS = switch (target.ptrBitWidth()) {
        0...32 => .@"32",
        33...64 => .@"64",
        else => return error.UnsupportedELFArchitecture,
    };
    const data: std.elf.DATA = switch (target.cpu.arch.endian()) {
        .little => .@"2LSB",
        .big => .@"2MSB",
    };
    const osabi: std.elf.OSABI = switch (target.os.tag) {
        else => .NONE,
        .freestanding, .other => .STANDALONE,
        .netbsd => .NETBSD,
        .solaris => .SOLARIS,
        .aix => .AIX,
        .freebsd => .FREEBSD,
        .cuda => .CUDA,
        .amdhsa => .AMDGPU_HSA,
        .amdpal => .AMDGPU_PAL,
        .mesa3d => .AMDGPU_MESA3D,
    };
    const @"type": std.elf.ET = switch (comp.config.output_mode) {
        .Exe => if (comp.config.pie or target.os.tag == .haiku) .DYN else .EXEC,
        .Lib => switch (comp.config.link_mode) {
            .static => .REL,
            .dynamic => .DYN,
        },
        .Obj => .REL,
    };
    const machine: std.elf.EM = switch (target.cpu.arch) {
        .spirv32, .spirv64, .wasm32, .wasm64 => .NONE,
        .sparc => .SPARC,
        .x86 => .@"386",
        .m68k => .@"68K",
        .mips, .mipsel, .mips64, .mips64el => .MIPS,
        .powerpc, .powerpcle => .PPC,
        .powerpc64, .powerpc64le => .PPC64,
        .s390x => .S390,
        .arm, .armeb, .thumb, .thumbeb => .ARM,
        .hexagon => .SH,
        .sparc64 => .SPARCV9,
        .arc => .ARC,
        .x86_64 => .X86_64,
        .or1k => .OR1K,
        .xtensa => .XTENSA,
        .msp430 => .MSP430,
        .avr => .AVR,
        .nvptx, .nvptx64 => .CUDA,
        .kalimba => .CSR_KALIMBA,
        .aarch64, .aarch64_be => .AARCH64,
        .xcore => .XCORE,
        .amdgcn => .AMDGPU,
        .riscv32, .riscv32be, .riscv64, .riscv64be => .RISCV,
        .lanai => .LANAI,
        .bpfel, .bpfeb => .BPF,
        .ve => .VE,
        .csky => .CSKY,
        .loongarch32, .loongarch64 => .LOONGARCH,
        .propeller => if (target.cpu.has(.propeller, .p2)) .PROPELLER2 else .PROPELLER,
    };
    const maybe_interp = switch (comp.config.output_mode) {
        .Exe, .Lib => switch (comp.config.link_mode) {
            .static => null,
            .dynamic => target.dynamic_linker.get(),
        },
        .Obj => null,
    };

    const elf = try arena.create(Elf);
    const file = try path.root_dir.handle.createFile(path.sub_path, .{
        .read = true,
        .mode = link.File.determineMode(comp.config.output_mode, comp.config.link_mode),
    });
    errdefer file.close();
    elf.* = .{
        .base = .{
            .tag = .elf2,

            .comp = comp,
            .emit = path,

            .file = file,
            .gc_sections = false,
            .print_gc_sections = false,
            .build_id = .none,
            .allow_shlib_undefined = false,
            .stack_size = 0,
        },
        .mf = try .init(file, comp.gpa),
        .nodes = .empty,
        .symtab = .empty,
        .shstrtab = .{
            .map = .empty,
            .size = 1,
        },
        .strtab = .{
            .map = .empty,
            .size = 1,
        },
        .globals = .empty,
        .navs = .empty,
        .uavs = .empty,
        .lazy = .initFill(.{
            .map = .empty,
            .pending_index = 0,
        }),
        .pending_uavs = .empty,
        .relocs = .empty,
        .entry_hack = .null,
    };
    errdefer elf.deinit();

    switch (class) {
        .NONE, _ => unreachable,
        inline .@"32", .@"64" => |ct_class| try elf.initHeaders(
            ct_class,
            data,
            osabi,
            @"type",
            machine,
            maybe_interp,
        ),
    }

    return elf;
}

pub fn deinit(elf: *Elf) void {
    const gpa = elf.base.comp.gpa;
    elf.mf.deinit(gpa);
    elf.nodes.deinit(gpa);
    elf.symtab.deinit(gpa);
    elf.shstrtab.map.deinit(gpa);
    elf.strtab.map.deinit(gpa);
    elf.globals.deinit(gpa);
    elf.navs.deinit(gpa);
    elf.uavs.deinit(gpa);
    for (&elf.lazy.values) |*lazy| lazy.map.deinit(gpa);
    elf.pending_uavs.deinit(gpa);
    elf.relocs.deinit(gpa);
    elf.* = undefined;
}

fn initHeaders(
    elf: *Elf,
    comptime class: std.elf.CLASS,
    data: std.elf.DATA,
    osabi: std.elf.OSABI,
    @"type": std.elf.ET,
    machine: std.elf.EM,
    maybe_interp: ?[]const u8,
) !void {
    const comp = elf.base.comp;
    const gpa = comp.gpa;
    const ElfN = switch (class) {
        .NONE, _ => comptime unreachable,
        .@"32" => std.elf.Elf32,
        .@"64" => std.elf.Elf64,
    };
    const addr_align: std.mem.Alignment = comptime .fromByteUnits(@sizeOf(ElfN.Addr));
    const target_endian: std.builtin.Endian = switch (data) {
        .NONE, _ => unreachable,
        .@"2LSB" => .little,
        .@"2MSB" => .big,
    };

    var phnum: u32 = 0;
    const phdr_phndx = phnum;
    phnum += 1;
    const interp_phndx = if (maybe_interp) |_| phndx: {
        defer phnum += 1;
        break :phndx phnum;
    } else undefined;
    const rodata_phndx = phnum;
    phnum += 1;
    const text_phndx = phnum;
    phnum += 1;
    const data_phndx = phnum;
    phnum += 1;
    const tls_phndx = if (comp.config.any_non_single_threaded) phndx: {
        defer phnum += 1;
        break :phndx phnum;
    } else undefined;

    try elf.nodes.ensureTotalCapacity(gpa, Node.known_count);
    elf.nodes.appendAssumeCapacity(.file);

    const seg_rodata_ni = Node.known.seg_rodata;
    assert(seg_rodata_ni == try elf.mf.addOnlyChildNode(gpa, .root, .{
        .alignment = elf.mf.flags.block_size,
        .fixed = true,
        .moved = true,
    }));
    elf.nodes.appendAssumeCapacity(.{ .segment = rodata_phndx });

    const ehdr_ni = Node.known.ehdr;
    assert(ehdr_ni == try elf.mf.addOnlyChildNode(gpa, seg_rodata_ni, .{
        .size = @sizeOf(ElfN.Ehdr),
        .alignment = addr_align,
        .fixed = true,
    }));
    elf.nodes.appendAssumeCapacity(.ehdr);

    const ehdr: *ElfN.Ehdr = @ptrCast(@alignCast(ehdr_ni.slice(&elf.mf)));
    const EI = std.elf.EI;
    @memcpy(ehdr.ident[0..std.elf.MAGIC.len], std.elf.MAGIC);
    ehdr.ident[EI.CLASS] = @intFromEnum(class);
    ehdr.ident[EI.DATA] = @intFromEnum(data);
    ehdr.ident[EI.VERSION] = 1;
    ehdr.ident[EI.OSABI] = @intFromEnum(osabi);
    ehdr.ident[EI.ABIVERSION] = 0;
    @memset(ehdr.ident[EI.PAD..], 0);
    ehdr.type = @"type";
    ehdr.machine = machine;
    ehdr.version = 1;
    ehdr.entry = 0;
    ehdr.phoff = 0;
    ehdr.shoff = 0;
    ehdr.flags = 0;
    ehdr.ehsize = @sizeOf(ElfN.Ehdr);
    ehdr.phentsize = @sizeOf(ElfN.Phdr);
    ehdr.phnum = @min(phnum, std.elf.PN_XNUM);
    ehdr.shentsize = @sizeOf(ElfN.Shdr);
    ehdr.shnum = 1;
    ehdr.shstrndx = 0;
    if (target_endian != native_endian) std.mem.byteSwapAllFields(ElfN.Ehdr, ehdr);

    const phdr_ni = Node.known.phdr;
    assert(phdr_ni == try elf.mf.addLastChildNode(gpa, seg_rodata_ni, .{
        .size = @sizeOf(ElfN.Phdr) * phnum,
        .alignment = addr_align,
        .moved = true,
        .resized = true,
    }));
    elf.nodes.appendAssumeCapacity(.{ .segment = phdr_phndx });

    const shdr_ni = Node.known.shdr;
    assert(shdr_ni == try elf.mf.addLastChildNode(gpa, seg_rodata_ni, .{
        .size = @sizeOf(ElfN.Shdr),
        .alignment = addr_align,
    }));
    elf.nodes.appendAssumeCapacity(.shdr);

    const seg_text_ni = Node.known.seg_text;
    assert(seg_text_ni == try elf.mf.addLastChildNode(gpa, .root, .{
        .alignment = elf.mf.flags.block_size,
        .moved = true,
    }));
    elf.nodes.appendAssumeCapacity(.{ .segment = text_phndx });

    const seg_data_ni = Node.known.seg_data;
    assert(seg_data_ni == try elf.mf.addLastChildNode(gpa, .root, .{
        .alignment = elf.mf.flags.block_size,
        .moved = true,
    }));
    elf.nodes.appendAssumeCapacity(.{ .segment = data_phndx });

    assert(elf.nodes.len == Node.known_count);

    {
        const phdr: []ElfN.Phdr = @ptrCast(@alignCast(phdr_ni.slice(&elf.mf)));
        const ph_phdr = &phdr[phdr_phndx];
        ph_phdr.* = .{
            .type = std.elf.PT_PHDR,
            .offset = 0,
            .vaddr = 0,
            .paddr = 0,
            .filesz = 0,
            .memsz = 0,
            .flags = .{ .R = true },
            .@"align" = @intCast(phdr_ni.alignment(&elf.mf).toByteUnits()),
        };
        if (target_endian != native_endian) std.mem.byteSwapAllFields(ElfN.Phdr, ph_phdr);

        if (maybe_interp) |_| {
            const ph_interp = &phdr[interp_phndx];
            ph_interp.* = .{
                .type = std.elf.PT_INTERP,
                .offset = 0,
                .vaddr = 0,
                .paddr = 0,
                .filesz = 0,
                .memsz = 0,
                .flags = .{ .R = true },
                .@"align" = 1,
            };
            if (target_endian != native_endian) std.mem.byteSwapAllFields(ElfN.Phdr, ph_interp);
        }

        const ph_rodata = &phdr[rodata_phndx];
        ph_rodata.* = .{
            .type = std.elf.PT_NULL,
            .offset = 0,
            .vaddr = 0,
            .paddr = 0,
            .filesz = 0,
            .memsz = 0,
            .flags = .{ .R = true },
            .@"align" = @intCast(seg_rodata_ni.alignment(&elf.mf).toByteUnits()),
        };
        if (target_endian != native_endian) std.mem.byteSwapAllFields(ElfN.Phdr, ph_rodata);

        const ph_text = &phdr[text_phndx];
        ph_text.* = .{
            .type = std.elf.PT_NULL,
            .offset = 0,
            .vaddr = 0,
            .paddr = 0,
            .filesz = 0,
            .memsz = 0,
            .flags = .{ .R = true, .X = true },
            .@"align" = @intCast(seg_text_ni.alignment(&elf.mf).toByteUnits()),
        };
        if (target_endian != native_endian) std.mem.byteSwapAllFields(ElfN.Phdr, ph_text);

        const ph_data = &phdr[data_phndx];
        ph_data.* = .{
            .type = std.elf.PT_NULL,
            .offset = 0,
            .vaddr = 0,
            .paddr = 0,
            .filesz = 0,
            .memsz = 0,
            .flags = .{ .R = true, .W = true },
            .@"align" = @intCast(seg_data_ni.alignment(&elf.mf).toByteUnits()),
        };
        if (target_endian != native_endian) std.mem.byteSwapAllFields(ElfN.Phdr, ph_data);

        if (comp.config.any_non_single_threaded) {
            const ph_tls = &phdr[tls_phndx];
            ph_tls.* = .{
                .type = std.elf.PT_TLS,
                .offset = 0,
                .vaddr = 0,
                .paddr = 0,
                .filesz = 0,
                .memsz = 0,
                .flags = .{ .R = true },
                .@"align" = @intCast(elf.mf.flags.block_size.toByteUnits()),
            };
            if (target_endian != native_endian) std.mem.byteSwapAllFields(ElfN.Phdr, ph_tls);
        }

        const sh_null: *ElfN.Shdr = @ptrCast(@alignCast(shdr_ni.slice(&elf.mf)));
        sh_null.* = .{
            .name = try elf.string(.shstrtab, ""),
            .type = std.elf.SHT_NULL,
            .flags = .{ .shf = .{} },
            .addr = 0,
            .offset = 0,
            .size = 0,
            .link = 0,
            .info = if (phnum >= std.elf.PN_XNUM) phnum else 0,
            .addralign = 0,
            .entsize = 0,
        };
        if (target_endian != native_endian) std.mem.byteSwapAllFields(ElfN.Shdr, sh_null);
    }

    try elf.symtab.ensureTotalCapacity(gpa, 1);
    elf.symtab.addOneAssumeCapacity().* = .{
        .ni = .none,
        .loc_relocs = .none,
        .target_relocs = .none,
        .unused = 0,
    };
    assert(try elf.addSection(seg_rodata_ni, .{
        .type = std.elf.SHT_SYMTAB,
        .addralign = addr_align,
        .entsize = @sizeOf(ElfN.Sym),
    }) == .symtab);
    const symtab: *ElfN.Sym = @ptrCast(@alignCast(Symbol.Index.symtab.node(elf).slice(&elf.mf)));
    symtab.* = .{
        .name = try elf.string(.strtab, ""),
        .value = 0,
        .size = 0,
        .info = .{
            .type = .NOTYPE,
            .bind = .LOCAL,
        },
        .other = .{
            .visibility = .DEFAULT,
        },
        .shndx = std.elf.SHN_UNDEF,
    };
    ehdr.shstrndx = ehdr.shnum;
    assert(try elf.addSection(seg_rodata_ni, .{
        .type = std.elf.SHT_STRTAB,
        .addralign = elf.mf.flags.block_size,
        .entsize = 1,
    }) == .shstrtab);
    assert(try elf.addSection(seg_rodata_ni, .{
        .type = std.elf.SHT_STRTAB,
        .addralign = elf.mf.flags.block_size,
        .entsize = 1,
    }) == .strtab);
    try elf.renameSection(.symtab, ".symtab");
    try elf.renameSection(.shstrtab, ".shstrtab");
    try elf.renameSection(.strtab, ".strtab");
    try elf.linkSections(.symtab, .strtab);
    Symbol.Index.shstrtab.node(elf).slice(&elf.mf)[0] = 0;
    Symbol.Index.strtab.node(elf).slice(&elf.mf)[0] = 0;

    assert(try elf.addSection(seg_rodata_ni, .{
        .name = ".rodata",
        .flags = .{ .ALLOC = true },
        .addralign = elf.mf.flags.block_size,
    }) == .rodata);
    assert(try elf.addSection(seg_text_ni, .{
        .name = ".text",
        .flags = .{ .ALLOC = true, .EXECINSTR = true },
        .addralign = elf.mf.flags.block_size,
    }) == .text);
    assert(try elf.addSection(seg_data_ni, .{
        .name = ".data",
        .flags = .{ .WRITE = true, .ALLOC = true },
        .addralign = elf.mf.flags.block_size,
    }) == .data);
    if (comp.config.any_non_single_threaded) {
        try elf.nodes.ensureUnusedCapacity(gpa, 1);
        const seg_tls_ni = try elf.mf.addLastChildNode(gpa, seg_data_ni, .{
            .alignment = elf.mf.flags.block_size,
            .moved = true,
        });
        elf.nodes.appendAssumeCapacity(.{ .segment = tls_phndx });

        assert(try elf.addSection(seg_tls_ni, .{
            .name = ".tdata",
            .flags = .{ .WRITE = true, .ALLOC = true, .TLS = true },
            .addralign = elf.mf.flags.block_size,
        }) == .tdata);
    }
    if (maybe_interp) |interp| {
        try elf.nodes.ensureUnusedCapacity(gpa, 1);
        const seg_interp_ni = try elf.mf.addLastChildNode(gpa, seg_rodata_ni, .{
            .size = interp.len + 1,
            .moved = true,
            .resized = true,
        });
        elf.nodes.appendAssumeCapacity(.{ .segment = interp_phndx });

        const sec_interp_si = try elf.addSection(seg_interp_ni, .{
            .name = ".interp",
            .size = @intCast(interp.len + 1),
            .flags = .{ .ALLOC = true },
        });
        const sec_interp = sec_interp_si.node(elf).slice(&elf.mf);
        @memcpy(sec_interp[0..interp.len], interp);
        sec_interp[interp.len] = 0;
    }
}

fn getNode(elf: *Elf, ni: MappedFile.Node.Index) Node {
    return elf.nodes.get(@intFromEnum(ni));
}

pub const EhdrPtr = union(std.elf.CLASS) {
    NONE: noreturn,
    @"32": *std.elf.Elf32.Ehdr,
    @"64": *std.elf.Elf64.Ehdr,
};
pub fn ehdrPtr(elf: *Elf) EhdrPtr {
    const slice = Node.known.ehdr.slice(&elf.mf);
    return switch (elf.identClass()) {
        .NONE, _ => unreachable,
        inline .@"32", .@"64" => |class| @unionInit(
            EhdrPtr,
            @tagName(class),
            @ptrCast(@alignCast(slice)),
        ),
    };
}
pub fn ehdrField(
    elf: *Elf,
    comptime field: enum { type, machine },
) @FieldType(std.elf.Elf32.Ehdr, @tagName(field)) {
    const Field = @FieldType(std.elf.Elf32.Ehdr, @tagName(field));
    comptime assert(@FieldType(std.elf.Elf64.Ehdr, @tagName(field)) == Field);
    return @enumFromInt(std.mem.toNative(
        @typeInfo(Field).@"enum".tag_type,
        @intFromEnum(switch (elf.ehdrPtr()) {
            inline else => |ehdr| @field(ehdr, @tagName(field)),
        }),
        elf.endian(),
    ));
}

pub fn identClass(elf: *Elf) std.elf.CLASS {
    return @enumFromInt(elf.mf.contents[std.elf.EI.CLASS]);
}

pub fn identData(elf: *Elf) std.elf.DATA {
    return @enumFromInt(elf.mf.contents[std.elf.EI.DATA]);
}
fn endianForData(data: std.elf.DATA) std.builtin.Endian {
    return switch (data) {
        .NONE, _ => unreachable,
        .@"2LSB" => .little,
        .@"2MSB" => .big,
    };
}
pub fn endian(elf: *Elf) std.builtin.Endian {
    return endianForData(elf.identData());
}

fn baseAddrForType(@"type": std.elf.ET) u64 {
    return switch (@"type") {
        else => 0,
        .EXEC => 0x1000000,
    };
}
pub fn baseAddr(elf: *Elf) u64 {
    return baseAddrForType(elf.ehdrField(.type));
}

pub const PhdrSlice = union(std.elf.CLASS) {
    NONE: noreturn,
    @"32": []std.elf.Elf32.Phdr,
    @"64": []std.elf.Elf64.Phdr,
};
pub fn phdrSlice(elf: *Elf) PhdrSlice {
    const slice = Node.known.phdr.slice(&elf.mf);
    return switch (elf.identClass()) {
        .NONE, _ => unreachable,
        inline .@"32", .@"64" => |class| @unionInit(
            PhdrSlice,
            @tagName(class),
            @ptrCast(@alignCast(slice)),
        ),
    };
}

pub const ShdrSlice = union(std.elf.CLASS) {
    NONE: noreturn,
    @"32": []std.elf.Elf32.Shdr,
    @"64": []std.elf.Elf64.Shdr,
};
pub fn shdrSlice(elf: *Elf) ShdrSlice {
    const slice = Node.known.shdr.slice(&elf.mf);
    return switch (elf.identClass()) {
        .NONE, _ => unreachable,
        inline .@"32", .@"64" => |class| @unionInit(
            ShdrSlice,
            @tagName(class),
            @ptrCast(@alignCast(slice)),
        ),
    };
}

pub const SymSlice = union(std.elf.CLASS) {
    NONE: noreturn,
    @"32": []std.elf.Elf32.Sym,
    @"64": []std.elf.Elf64.Sym,
};
pub fn symSlice(elf: *Elf) SymSlice {
    const slice = Symbol.Index.symtab.node(elf).slice(&elf.mf);
    return switch (elf.identClass()) {
        .NONE, _ => unreachable,
        inline .@"32", .@"64" => |class| @unionInit(
            SymSlice,
            @tagName(class),
            @ptrCast(@alignCast(slice)),
        ),
    };
}

pub const SymPtr = union(std.elf.CLASS) {
    NONE: noreturn,
    @"32": *std.elf.Elf32.Sym,
    @"64": *std.elf.Elf64.Sym,
};
pub fn symPtr(elf: *Elf, si: Symbol.Index) SymPtr {
    return switch (elf.symSlice()) {
        inline else => |sym, class| @unionInit(SymPtr, @tagName(class), &sym[@intFromEnum(si)]),
    };
}

fn addSymbolAssumeCapacity(elf: *Elf) !Symbol.Index {
    defer elf.symtab.addOneAssumeCapacity().* = .{
        .ni = .none,
        .loc_relocs = .none,
        .target_relocs = .none,
        .unused = 0,
    };
    return @enumFromInt(elf.symtab.items.len);
}

fn initSymbolAssumeCapacity(elf: *Elf, opts: Symbol.Index.InitOptions) !Symbol.Index {
    const si = try elf.addSymbolAssumeCapacity();
    try si.init(elf, opts);
    return si;
}

pub fn globalSymbol(
    elf: *Elf,
    opts: struct {
        name: []const u8,
        type: std.elf.STT,
        bind: std.elf.STB = .GLOBAL,
        visibility: std.elf.STV = .DEFAULT,
    },
) !Symbol.Index {
    const gpa = elf.base.comp.gpa;
    try elf.symtab.ensureUnusedCapacity(gpa, 1);
    const sym_gop = try elf.globals.getOrPut(gpa, try elf.string(.strtab, opts.name));
    if (!sym_gop.found_existing) sym_gop.value_ptr.* = try elf.initSymbolAssumeCapacity(.{
        .name = opts.name,
        .type = opts.type,
        .bind = opts.bind,
        .visibility = opts.visibility,
    });
    return sym_gop.value_ptr.*;
}

fn navType(
    ip: *const InternPool,
    nav_status: @FieldType(InternPool.Nav, "status"),
    any_non_single_threaded: bool,
) std.elf.STT {
    return switch (nav_status) {
        .unresolved => unreachable,
        .type_resolved => |tr| if (any_non_single_threaded and tr.is_threadlocal)
            .TLS
        else if (ip.isFunctionType(tr.type))
            .FUNC
        else
            .OBJECT,
        .fully_resolved => |fr| switch (ip.indexToKey(fr.val)) {
            else => .OBJECT,
            .variable => |variable| if (any_non_single_threaded and variable.is_threadlocal)
                .TLS
            else
                .OBJECT,
            .@"extern" => |@"extern"| if (any_non_single_threaded and @"extern".is_threadlocal)
                .TLS
            else if (ip.isFunctionType(@"extern".ty))
                .FUNC
            else
                .OBJECT,
            .func => .FUNC,
        },
    };
}
pub fn navSymbol(elf: *Elf, zcu: *Zcu, nav_index: InternPool.Nav.Index) !Symbol.Index {
    const gpa = zcu.gpa;
    const ip = &zcu.intern_pool;
    const nav = ip.getNav(nav_index);
    if (nav.getExtern(ip)) |@"extern"| return elf.globalSymbol(.{
        .name = @"extern".name.toSlice(ip),
        .type = navType(ip, nav.status, elf.base.comp.config.any_non_single_threaded),
        .bind = switch (@"extern".linkage) {
            .internal => .LOCAL,
            .strong => .GLOBAL,
            .weak => .WEAK,
            .link_once => return error.LinkOnceUnsupported,
        },
        .visibility = switch (@"extern".visibility) {
            .default => .DEFAULT,
            .hidden => .HIDDEN,
            .protected => .PROTECTED,
        },
    });
    try elf.symtab.ensureUnusedCapacity(gpa, 1);
    const sym_gop = try elf.navs.getOrPut(gpa, nav_index);
    if (!sym_gop.found_existing) {
        sym_gop.value_ptr.* = try elf.initSymbolAssumeCapacity(.{
            .name = nav.fqn.toSlice(ip),
            .type = navType(ip, nav.status, elf.base.comp.config.any_non_single_threaded),
        });
    }
    return sym_gop.value_ptr.*;
}

pub fn uavSymbol(elf: *Elf, uav_val: InternPool.Index) !Symbol.Index {
    const gpa = elf.base.comp.gpa;
    try elf.symtab.ensureUnusedCapacity(gpa, 1);
    const sym_gop = try elf.uavs.getOrPut(gpa, uav_val);
    if (!sym_gop.found_existing)
        sym_gop.value_ptr.* = try elf.initSymbolAssumeCapacity(.{ .type = .OBJECT });
    return sym_gop.value_ptr.*;
}

pub fn lazySymbol(elf: *Elf, lazy: link.File.LazySymbol) !Symbol.Index {
    const gpa = elf.base.comp.gpa;
    try elf.symtab.ensureUnusedCapacity(gpa, 1);
    const sym_gop = try elf.lazy.getPtr(lazy.kind).map.getOrPut(gpa, lazy.ty);
    if (!sym_gop.found_existing) {
        sym_gop.value_ptr.* = try elf.initSymbolAssumeCapacity(.{
            .type = switch (lazy.kind) {
                .code => .FUNC,
                .const_data => .OBJECT,
            },
        });
        elf.base.comp.link_lazy_prog_node.increaseEstimatedTotalItems(1);
    }
    return sym_gop.value_ptr.*;
}

pub fn getNavVAddr(
    elf: *Elf,
    pt: Zcu.PerThread,
    nav: InternPool.Nav.Index,
    reloc_info: link.File.RelocInfo,
) !u64 {
    return elf.getVAddr(reloc_info, try elf.navSymbol(pt.zcu, nav));
}

pub fn getUavVAddr(
    elf: *Elf,
    uav: InternPool.Index,
    reloc_info: link.File.RelocInfo,
) !u64 {
    return elf.getVAddr(reloc_info, try elf.uavSymbol(uav));
}

pub fn getVAddr(elf: *Elf, reloc_info: link.File.RelocInfo, target_si: Symbol.Index) !u64 {
    try elf.addReloc(
        @enumFromInt(reloc_info.parent.atom_index),
        reloc_info.offset,
        target_si,
        reloc_info.addend,
        switch (elf.ehdrField(.machine)) {
            else => unreachable,
            .X86_64 => .{ .x86_64 = switch (elf.identClass()) {
                .NONE, _ => unreachable,
                .@"32" => .@"32",
                .@"64" => .@"64",
            } },
        },
    );
    return 0;
}

fn addSection(elf: *Elf, segment_ni: MappedFile.Node.Index, opts: struct {
    name: []const u8 = "",
    type: std.elf.Word = std.elf.SHT_NULL,
    size: std.elf.Word = 0,
    flags: std.elf.SHF = .{},
    addralign: std.mem.Alignment = .@"1",
    entsize: std.elf.Word = 0,
}) !Symbol.Index {
    const gpa = elf.base.comp.gpa;
    const target_endian = elf.endian();
    try elf.nodes.ensureUnusedCapacity(gpa, 1);
    try elf.symtab.ensureUnusedCapacity(gpa, 1);

    const shstrtab_entry = try elf.string(.shstrtab, opts.name);
    const shndx, const shdr_size = shndx: switch (elf.ehdrPtr()) {
        inline else => |ehdr| {
            const shentsize = std.mem.toNative(@TypeOf(ehdr.shentsize), ehdr.shentsize, target_endian);
            const shndx = std.mem.toNative(@TypeOf(ehdr.shnum), ehdr.shnum, target_endian);
            const shnum = shndx + 1;
            ehdr.shnum = std.mem.nativeTo(@TypeOf(ehdr.shnum), shnum, target_endian);
            break :shndx .{ shndx, shentsize * shnum };
        },
    };
    try Node.known.shdr.resize(&elf.mf, gpa, shdr_size);
    const ni = try elf.mf.addLastChildNode(gpa, segment_ni, .{
        .alignment = opts.addralign,
        .size = opts.size,
        .moved = true,
    });
    const si = try elf.addSymbolAssumeCapacity();
    elf.nodes.appendAssumeCapacity(.{ .section = si });
    si.get(elf).ni = ni;
    try si.init(elf, .{
        .name = opts.name,
        .size = opts.size,
        .type = .SECTION,
        .shndx = shndx,
    });
    switch (elf.shdrSlice()) {
        inline else => |shdr| {
            const sh = &shdr[shndx];
            sh.* = .{
                .name = shstrtab_entry,
                .type = opts.type,
                .flags = .{ .shf = opts.flags },
                .addr = 0,
                .offset = 0,
                .size = opts.size,
                .link = 0,
                .info = 0,
                .addralign = @intCast(opts.addralign.toByteUnits()),
                .entsize = opts.entsize,
            };
            if (target_endian != native_endian) std.mem.byteSwapAllFields(@TypeOf(sh.*), sh);
        },
    }
    return si;
}

fn renameSection(elf: *Elf, si: Symbol.Index, name: []const u8) !void {
    const strtab_entry = try elf.string(.strtab, name);
    const shstrtab_entry = try elf.string(.shstrtab, name);
    const target_endian = elf.endian();
    switch (elf.shdrSlice()) {
        inline else => |shdr, class| {
            const sym = @field(elf.symPtr(si), @tagName(class));
            sym.name = std.mem.nativeTo(@TypeOf(sym.name), strtab_entry, target_endian);
            const shndx = std.mem.toNative(@TypeOf(sym.shndx), sym.shndx, target_endian);
            const sh = &shdr[shndx];
            sh.name = std.mem.nativeTo(@TypeOf(sh.name), shstrtab_entry, target_endian);
        },
    }
}

fn linkSections(elf: *Elf, si: Symbol.Index, link_si: Symbol.Index) !void {
    const target_endian = elf.endian();
    switch (elf.shdrSlice()) {
        inline else => |shdr, class| {
            const sym = @field(elf.symPtr(si), @tagName(class));
            const shndx = std.mem.toNative(@TypeOf(sym.shndx), sym.shndx, target_endian);
            shdr[shndx].link = @field(elf.symPtr(link_si), @tagName(class)).shndx;
        },
    }
}

fn sectionName(elf: *Elf, si: Symbol.Index) [:0]const u8 {
    const target_endian = elf.endian();
    const name = Symbol.Index.shstrtab.node(elf).slice(&elf.mf)[name: switch (elf.shdrSlice()) {
        inline else => |shndx, class| {
            const sym = @field(elf.symPtr(si), @tagName(class));
            const sh = &shndx[std.mem.toNative(@TypeOf(sym.shndx), sym.shndx, target_endian)];
            break :name std.mem.toNative(@TypeOf(sh.name), sh.name, target_endian);
        },
    }..];
    return name[0..std.mem.indexOfScalar(u8, name, 0).? :0];
}

fn string(elf: *Elf, comptime section: enum { shstrtab, strtab }, key: []const u8) !u32 {
    if (key.len == 0) return 0;
    return @field(elf, @tagName(section)).get(
        elf.base.comp.gpa,
        &elf.mf,
        @field(Symbol.Index, @tagName(section)).node(elf),
        key,
    );
}

pub fn addReloc(
    elf: *Elf,
    loc_si: Symbol.Index,
    offset: u64,
    target_si: Symbol.Index,
    addend: i64,
    @"type": Reloc.Type,
) !void {
    const gpa = elf.base.comp.gpa;
    const target = target_si.get(elf);
    const ri: link.File.Elf2.Reloc.Index = @enumFromInt(elf.relocs.items.len);
    (try elf.relocs.addOne(gpa)).* = .{
        .type = @"type",
        .prev = .none,
        .next = target.target_relocs,
        .loc = loc_si,
        .target = target_si,
        .unused = 0,
        .offset = offset,
        .addend = addend,
    };
    switch (target.target_relocs) {
        .none => {},
        else => |target_ri| target_ri.get(elf).prev = ri,
    }
    target.target_relocs = ri;
}

pub fn prelink(elf: *Elf, prog_node: std.Progress.Node) void {
    _ = elf;
    _ = prog_node;
}

pub fn updateNav(elf: *Elf, pt: Zcu.PerThread, nav_index: InternPool.Nav.Index) !void {
    elf.updateNavInner(pt, nav_index) catch |err| switch (err) {
        error.OutOfMemory,
        error.Overflow,
        error.RelocationNotByteAligned,
        => |e| return e,
        else => |e| return elf.base.cgFail(nav_index, "linker failed to update variable: {t}", .{e}),
    };
}
fn updateNavInner(elf: *Elf, pt: Zcu.PerThread, nav_index: InternPool.Nav.Index) !void {
    const comp = elf.base.comp;
    const zcu = pt.zcu;
    const gpa = zcu.gpa;
    const ip = &zcu.intern_pool;

    const nav = ip.getNav(nav_index);
    const nav_val = nav.status.fully_resolved.val;
    const nav_init, const is_threadlocal = switch (ip.indexToKey(nav_val)) {
        else => .{ nav_val, false },
        .variable => |variable| .{ variable.init, variable.is_threadlocal },
        .@"extern" => return,
        .func => .{ .none, false },
    };
    if (nav_init == .none or !Type.fromInterned(ip.typeOf(nav_init)).hasRuntimeBits(zcu)) return;

    const si = try elf.navSymbol(zcu, nav_index);
    const ni = ni: {
        const sym = si.get(elf);
        switch (sym.ni) {
            .none => {
                try elf.nodes.ensureUnusedCapacity(gpa, 1);
                const sec_si: Symbol.Index =
                    if (is_threadlocal and comp.config.any_non_single_threaded) .tdata else .data;
                const ni = try elf.mf.addLastChildNode(gpa, sec_si.node(elf), .{
                    .alignment = pt.navAlignment(nav_index).toStdMem(),
                    .moved = true,
                });
                elf.nodes.appendAssumeCapacity(.{ .nav = nav_index });
                sym.ni = ni;
                switch (elf.symPtr(si)) {
                    inline else => |sym_ptr, class| sym_ptr.shndx =
                        @field(elf.symPtr(sec_si), @tagName(class)).shndx,
                }
            },
            else => si.deleteLocationRelocs(elf),
        }
        assert(sym.loc_relocs == .none);
        sym.loc_relocs = @enumFromInt(elf.relocs.items.len);
        break :ni sym.ni;
    };

    const size = size: {
        var nw: MappedFile.Node.Writer = undefined;
        ni.writer(&elf.mf, gpa, &nw);
        defer nw.deinit();
        codegen.generateSymbol(
            &elf.base,
            pt,
            zcu.navSrcLoc(nav_index),
            .fromInterned(nav_init),
            &nw.interface,
            .{ .atom_index = @intFromEnum(si) },
        ) catch |err| switch (err) {
            error.WriteFailed => return error.OutOfMemory,
            else => |e| return e,
        };
        break :size nw.interface.end;
    };

    const target_endian = elf.endian();
    switch (elf.symPtr(si)) {
        inline else => |sym| sym.size =
            std.mem.nativeTo(@TypeOf(sym.size), @intCast(size), target_endian),
    }
    si.applyLocationRelocs(elf);
}

pub fn lowerUav(
    elf: *Elf,
    pt: Zcu.PerThread,
    uav_val: InternPool.Index,
    uav_align: InternPool.Alignment,
    src_loc: Zcu.LazySrcLoc,
) !codegen.SymbolResult {
    const zcu = pt.zcu;
    const gpa = zcu.gpa;

    try elf.pending_uavs.ensureUnusedCapacity(gpa, 1);
    const si = elf.uavSymbol(uav_val) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        else => |e| return .{ .fail = try Zcu.ErrorMsg.create(
            gpa,
            src_loc,
            "linker failed to update constant: {s}",
            .{@errorName(e)},
        ) },
    };
    if (switch (si.get(elf).ni) {
        .none => true,
        else => |ni| uav_align.toStdMem().order(ni.alignment(&elf.mf)).compare(.gt),
    }) {
        const gop = elf.pending_uavs.getOrPutAssumeCapacity(uav_val);
        if (gop.found_existing) {
            gop.value_ptr.alignment = gop.value_ptr.alignment.max(uav_align);
        } else {
            gop.value_ptr.* = .{
                .alignment = uav_align,
                .src_loc = src_loc,
            };
            elf.base.comp.link_uav_prog_node.increaseEstimatedTotalItems(1);
        }
    }
    return .{ .sym_index = @intFromEnum(si) };
}

pub fn updateFunc(
    elf: *Elf,
    pt: Zcu.PerThread,
    func_index: InternPool.Index,
    mir: *const codegen.AnyMir,
) !void {
    elf.updateFuncInner(pt, func_index, mir) catch |err| switch (err) {
        error.OutOfMemory,
        error.Overflow,
        error.RelocationNotByteAligned,
        error.CodegenFail,
        => |e| return e,
        else => |e| return elf.base.cgFail(
            pt.zcu.funcInfo(func_index).owner_nav,
            "linker failed to update function: {s}",
            .{@errorName(e)},
        ),
    };
}
fn updateFuncInner(
    elf: *Elf,
    pt: Zcu.PerThread,
    func_index: InternPool.Index,
    mir: *const codegen.AnyMir,
) !void {
    const zcu = pt.zcu;
    const gpa = zcu.gpa;
    const ip = &zcu.intern_pool;
    const func = zcu.funcInfo(func_index);
    const nav = ip.getNav(func.owner_nav);

    const si = try elf.navSymbol(zcu, func.owner_nav);
    log.debug("updateFunc({f}) = {d}", .{ nav.fqn.fmt(ip), si });
    const ni = ni: {
        const sym = si.get(elf);
        switch (sym.ni) {
            .none => {
                try elf.nodes.ensureUnusedCapacity(gpa, 1);
                const mod = zcu.navFileScope(func.owner_nav).mod.?;
                const target = &mod.resolved_target.result;
                const ni = try elf.mf.addLastChildNode(gpa, Symbol.Index.text.node(elf), .{
                    .alignment = switch (nav.status.fully_resolved.alignment) {
                        .none => switch (mod.optimize_mode) {
                            .Debug,
                            .ReleaseSafe,
                            .ReleaseFast,
                            => target_util.defaultFunctionAlignment(target),
                            .ReleaseSmall => target_util.minFunctionAlignment(target),
                        },
                        else => |a| a.maxStrict(target_util.minFunctionAlignment(target)),
                    }.toStdMem(),
                    .moved = true,
                });
                elf.nodes.appendAssumeCapacity(.{ .nav = func.owner_nav });
                sym.ni = ni;
                switch (elf.symPtr(si)) {
                    inline else => |sym_ptr, class| sym_ptr.shndx =
                        @field(elf.symPtr(.text), @tagName(class)).shndx,
                }
            },
            else => si.deleteLocationRelocs(elf),
        }
        assert(sym.loc_relocs == .none);
        sym.loc_relocs = @enumFromInt(elf.relocs.items.len);
        break :ni sym.ni;
    };

    const size = size: {
        var nw: MappedFile.Node.Writer = undefined;
        ni.writer(&elf.mf, gpa, &nw);
        defer nw.deinit();
        codegen.emitFunction(
            &elf.base,
            pt,
            zcu.navSrcLoc(func.owner_nav),
            func_index,
            @intFromEnum(si),
            mir,
            &nw.interface,
            .none,
        ) catch |err| switch (err) {
            error.WriteFailed => return nw.err.?,
            else => |e| return e,
        };
        break :size nw.interface.end;
    };

    const target_endian = elf.endian();
    switch (elf.symPtr(si)) {
        inline else => |sym| sym.size =
            std.mem.nativeTo(@TypeOf(sym.size), @intCast(size), target_endian),
    }
    si.applyLocationRelocs(elf);
}

pub fn updateErrorData(elf: *Elf, pt: Zcu.PerThread) !void {
    const si = elf.lazy.getPtr(.const_data).map.get(.anyerror_type) orelse return;
    elf.flushLazy(pt, .{ .kind = .const_data, .ty = .anyerror_type }, si) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        error.CodegenFail => return error.LinkFailure,
        else => |e| return elf.base.comp.link_diags.fail("updateErrorData failed {t}", .{e}),
    };
}

pub fn flush(
    elf: *Elf,
    arena: std.mem.Allocator,
    tid: Zcu.PerThread.Id,
    prog_node: std.Progress.Node,
) !void {
    _ = arena;
    _ = prog_node;
    while (try elf.idle(tid)) {}
}

pub fn idle(elf: *Elf, tid: Zcu.PerThread.Id) !bool {
    const comp = elf.base.comp;
    task: {
        while (elf.pending_uavs.pop()) |pending_uav| {
            const sub_prog_node =
                elf.idleProgNode(
                    tid,
                    comp.link_uav_prog_node,
                    .{ .uav = pending_uav.key },
                );
            defer sub_prog_node.end();
            break :task elf.flushUav(
                .{ .zcu = elf.base.comp.zcu.?, .tid = tid },
                pending_uav.key,
                pending_uav.value.alignment,
                pending_uav.value.src_loc,
            ) catch |err| switch (err) {
                error.OutOfMemory => return error.OutOfMemory,
                else => |e| return elf.base.comp.link_diags.fail(
                    "linker failed to lower constant: {t}",
                    .{e},
                ),
            };
        }
        var lazy_it = elf.lazy.iterator();
        while (lazy_it.next()) |lazy| for (
            lazy.value.map.keys()[lazy.value.pending_index..],
            lazy.value.map.values()[lazy.value.pending_index..],
        ) |ty, si| {
            lazy.value.pending_index += 1;
            const pt: Zcu.PerThread = .{ .zcu = elf.base.comp.zcu.?, .tid = tid };
            const kind = switch (lazy.key) {
                .code => "code",
                .const_data => "data",
            };
            var name: [std.Progress.Node.max_name_len]u8 = undefined;
            const sub_prog_node = comp.link_lazy_prog_node.start(
                std.fmt.bufPrint(&name, "lazy {s} for {f}", .{
                    kind,
                    Type.fromInterned(ty).fmt(pt),
                }) catch &name,
                0,
            );
            defer sub_prog_node.end();
            break :task elf.flushLazy(pt, .{
                .kind = lazy.key,
                .ty = ty,
            }, si) catch |err| switch (err) {
                error.OutOfMemory => return error.OutOfMemory,
                else => |e| return elf.base.comp.link_diags.fail(
                    "linker failed to lower lazy {s}: {t}",
                    .{ kind, e },
                ),
            };
        };
        while (elf.mf.updates.pop()) |ni| {
            const clean_moved = ni.cleanMoved(&elf.mf);
            const clean_resized = ni.cleanResized(&elf.mf);
            if (clean_moved or clean_resized) {
                const sub_prog_node = elf.idleProgNode(tid, elf.mf.update_prog_node, elf.getNode(ni));
                defer sub_prog_node.end();
                if (clean_moved) try elf.flushMoved(ni);
                if (clean_resized) try elf.flushResized(ni);
                break :task;
            } else elf.mf.update_prog_node.completeOne();
        }
    }
    if (elf.pending_uavs.count() > 0) return true;
    for (&elf.lazy.values) |lazy| if (lazy.map.count() > lazy.pending_index) return true;
    if (elf.mf.updates.items.len > 0) return true;
    return false;
}

fn idleProgNode(
    elf: *Elf,
    tid: Zcu.PerThread.Id,
    prog_node: std.Progress.Node,
    node: Node,
) std.Progress.Node {
    var name: [std.Progress.Node.max_name_len]u8 = undefined;
    return prog_node.start(name: switch (node) {
        else => |tag| @tagName(tag),
        .section => |si| elf.sectionName(si),
        .nav => |nav| {
            const ip = &elf.base.comp.zcu.?.intern_pool;
            break :name ip.getNav(nav).fqn.toSlice(ip);
        },
        .uav => |uav| std.fmt.bufPrint(&name, "{f}", .{
            Value.fromInterned(uav).fmtValue(.{ .zcu = elf.base.comp.zcu.?, .tid = tid }),
        }) catch &name,
    }, 0);
}

fn flushUav(
    elf: *Elf,
    pt: Zcu.PerThread,
    uav_val: InternPool.Index,
    uav_align: InternPool.Alignment,
    src_loc: Zcu.LazySrcLoc,
) !void {
    const zcu = pt.zcu;
    const gpa = zcu.gpa;

    const si = try elf.uavSymbol(uav_val);
    const ni = ni: {
        const sym = si.get(elf);
        switch (sym.ni) {
            .none => {
                try elf.nodes.ensureUnusedCapacity(gpa, 1);
                const ni = try elf.mf.addLastChildNode(gpa, Symbol.Index.data.node(elf), .{
                    .alignment = uav_align.toStdMem(),
                    .moved = true,
                });
                elf.nodes.appendAssumeCapacity(.{ .uav = uav_val });
                sym.ni = ni;
                switch (elf.symPtr(si)) {
                    inline else => |sym_ptr, class| sym_ptr.shndx =
                        @field(elf.symPtr(.data), @tagName(class)).shndx,
                }
            },
            else => {
                if (sym.ni.alignment(&elf.mf).order(uav_align.toStdMem()).compare(.gte)) return;
                si.deleteLocationRelocs(elf);
            },
        }
        assert(sym.loc_relocs == .none);
        sym.loc_relocs = @enumFromInt(elf.relocs.items.len);
        break :ni sym.ni;
    };

    const size = size: {
        var nw: MappedFile.Node.Writer = undefined;
        ni.writer(&elf.mf, gpa, &nw);
        defer nw.deinit();
        codegen.generateSymbol(
            &elf.base,
            pt,
            src_loc,
            .fromInterned(uav_val),
            &nw.interface,
            .{ .atom_index = @intFromEnum(si) },
        ) catch |err| switch (err) {
            error.WriteFailed => return error.OutOfMemory,
            else => |e| return e,
        };
        break :size nw.interface.end;
    };

    const target_endian = elf.endian();
    switch (elf.symPtr(si)) {
        inline else => |sym| sym.size =
            std.mem.nativeTo(@TypeOf(sym.size), @intCast(size), target_endian),
    }
    si.applyLocationRelocs(elf);
}

fn flushLazy(elf: *Elf, pt: Zcu.PerThread, lazy: link.File.LazySymbol, si: Symbol.Index) !void {
    const zcu = pt.zcu;
    const gpa = zcu.gpa;

    const ni = ni: {
        const sym = si.get(elf);
        switch (sym.ni) {
            .none => {
                try elf.nodes.ensureUnusedCapacity(gpa, 1);
                const sec_si: Symbol.Index = switch (lazy.kind) {
                    .code => .text,
                    .const_data => .rodata,
                };
                const ni = try elf.mf.addLastChildNode(gpa, sec_si.node(elf), .{ .moved = true });
                elf.nodes.appendAssumeCapacity(switch (lazy.kind) {
                    .code => .{ .lazy_code = lazy.ty },
                    .const_data => .{ .lazy_const_data = lazy.ty },
                });
                sym.ni = ni;
                switch (elf.symPtr(si)) {
                    inline else => |sym_ptr, class| sym_ptr.shndx =
                        @field(elf.symPtr(sec_si), @tagName(class)).shndx,
                }
            },
            else => si.deleteLocationRelocs(elf),
        }
        assert(sym.loc_relocs == .none);
        sym.loc_relocs = @enumFromInt(elf.relocs.items.len);
        break :ni sym.ni;
    };

    const size = size: {
        var required_alignment: InternPool.Alignment = .none;
        var nw: MappedFile.Node.Writer = undefined;
        ni.writer(&elf.mf, gpa, &nw);
        defer nw.deinit();
        try codegen.generateLazySymbol(
            &elf.base,
            pt,
            Type.fromInterned(lazy.ty).srcLocOrNull(pt.zcu) orelse .unneeded,
            lazy,
            &required_alignment,
            &nw.interface,
            .none,
            .{ .atom_index = @intFromEnum(si) },
        );
        break :size nw.interface.end;
    };

    const target_endian = elf.endian();
    switch (elf.symPtr(si)) {
        inline else => |sym| sym.size =
            std.mem.nativeTo(@TypeOf(sym.size), @intCast(size), target_endian),
    }
    si.applyLocationRelocs(elf);
}

fn flushMoved(elf: *Elf, ni: MappedFile.Node.Index) !void {
    const target_endian = elf.endian();
    const file_offset = ni.fileLocation(&elf.mf, false).offset;
    const node = elf.getNode(ni);
    switch (node) {
        else => |tag| @panic(@tagName(tag)),
        .ehdr => assert(file_offset == 0),
        .shdr => switch (elf.ehdrPtr()) {
            inline else => |ehdr| ehdr.shoff =
                std.mem.nativeTo(@TypeOf(ehdr.shoff), @intCast(file_offset), target_endian),
        },
        .segment => |phndx| switch (elf.phdrSlice()) {
            inline else => |phdr, class| {
                const ph = &phdr[phndx];
                switch (std.mem.toNative(@TypeOf(ph.type), ph.type, target_endian)) {
                    else => unreachable,
                    std.elf.PT_NULL, std.elf.PT_LOAD, std.elf.PT_DYNAMIC, std.elf.PT_INTERP => {},
                    std.elf.PT_PHDR => {
                        const ehdr = @field(elf.ehdrPtr(), @tagName(class));
                        ehdr.phoff =
                            std.mem.nativeTo(@TypeOf(ehdr.phoff), @intCast(file_offset), target_endian);
                    },
                    std.elf.PT_TLS => {},
                }
                ph.offset = std.mem.nativeTo(@TypeOf(ph.offset), @intCast(file_offset), target_endian);
                ph.vaddr = std.mem.nativeTo(
                    @TypeOf(ph.vaddr),
                    @intCast(elf.baseAddr() + file_offset),
                    target_endian,
                );
                ph.paddr = ph.vaddr;
            },
        },
        .section => |si| switch (elf.shdrSlice()) {
            inline else => |shdr, class| {
                const sym = @field(elf.symPtr(si), @tagName(class));
                const shndx = std.mem.toNative(@TypeOf(sym.shndx), sym.shndx, target_endian);
                const sh = &shdr[shndx];
                const flags: @TypeOf(sh.flags) = @bitCast(std.mem.toNative(
                    @typeInfo(@TypeOf(sh.flags)).@"struct".backing_integer.?,
                    @bitCast(sh.flags),
                    target_endian,
                ));
                if (flags.shf.ALLOC) {
                    sym.value = std.mem.nativeTo(
                        @TypeOf(sym.value),
                        @intCast(elf.baseAddr() + file_offset),
                        target_endian,
                    );
                    sh.addr = sym.value;
                }
                sh.offset = std.mem.nativeTo(@TypeOf(sh.offset), @intCast(file_offset), target_endian);
            },
        },
        .nav, .uav, .lazy_code, .lazy_const_data => {
            const si = switch (node) {
                else => unreachable,
                .nav => |nav| elf.navs.get(nav),
                .uav => |uav| elf.uavs.get(uav),
                .lazy_code => |ty| elf.lazy.getPtr(.code).map.get(ty),
                .lazy_const_data => |ty| elf.lazy.getPtr(.const_data).map.get(ty),
            }.?;
            switch (elf.shdrSlice()) {
                inline else => |shdr, class| {
                    const sym = @field(elf.symPtr(si), @tagName(class));
                    const sh = &shdr[std.mem.toNative(@TypeOf(sym.shndx), sym.shndx, target_endian)];
                    const flags: @TypeOf(sh.flags) = @bitCast(std.mem.toNative(
                        @typeInfo(@TypeOf(sh.flags)).@"struct".backing_integer.?,
                        @bitCast(sh.flags),
                        target_endian,
                    ));
                    const sh_addr = if (flags.shf.TLS)
                        0
                    else
                        std.mem.toNative(@TypeOf(sh.addr), sh.addr, target_endian);
                    const sh_offset = std.mem.toNative(@TypeOf(sh.offset), sh.offset, target_endian);
                    sym.value = std.mem.nativeTo(
                        @TypeOf(sym.value),
                        @intCast(file_offset - sh_offset + sh_addr),
                        target_endian,
                    );
                    if (si == elf.entry_hack) @field(elf.ehdrPtr(), @tagName(class)).entry = sym.value;
                },
            }
            si.applyLocationRelocs(elf);
            si.applyTargetRelocs(elf);
        },
    }
    try ni.childrenMoved(elf.base.comp.gpa, &elf.mf);
}

fn flushResized(elf: *Elf, ni: MappedFile.Node.Index) !void {
    const target_endian = elf.endian();
    _, const size = ni.location(&elf.mf).resolve(&elf.mf);
    const node = elf.getNode(ni);
    switch (node) {
        else => |tag| @panic(@tagName(tag)),
        .file, .shdr => {},
        .segment => |phndx| switch (elf.phdrSlice()) {
            inline else => |phdr| {
                const ph = &phdr[phndx];
                ph.filesz = std.mem.nativeTo(@TypeOf(ph.filesz), @intCast(size), target_endian);
                ph.memsz = ph.filesz;
                switch (std.mem.toNative(@TypeOf(ph.type), ph.type, target_endian)) {
                    else => unreachable,
                    std.elf.PT_NULL => {
                        if (size > 0) ph.type = std.mem.nativeTo(
                            @TypeOf(ph.type),
                            std.elf.PT_LOAD,
                            target_endian,
                        );
                    },
                    std.elf.PT_LOAD => {
                        if (size == 0) ph.type = std.mem.nativeTo(
                            @TypeOf(ph.type),
                            std.elf.PT_NULL,
                            target_endian,
                        );
                    },
                    std.elf.PT_DYNAMIC, std.elf.PT_INTERP, std.elf.PT_PHDR => {},
                    std.elf.PT_TLS => try ni.childrenMoved(elf.base.comp.gpa, &elf.mf),
                }
            },
        },
        .section => |si| switch (elf.shdrSlice()) {
            inline else => |shdr, class| {
                const sym = @field(elf.symPtr(si), @tagName(class));
                const shndx = std.mem.toNative(@TypeOf(sym.shndx), sym.shndx, target_endian);
                const sh = &shdr[shndx];
                switch (std.mem.toNative(@TypeOf(sh.type), sh.type, target_endian)) {
                    else => unreachable,
                    std.elf.SHT_NULL => {
                        if (size > 0) sh.type = std.mem.nativeTo(
                            @TypeOf(sh.type),
                            std.elf.SHT_PROGBITS,
                            target_endian,
                        );
                    },
                    std.elf.SHT_PROGBITS => {
                        if (size == 0) sh.type = std.mem.nativeTo(
                            @TypeOf(sh.type),
                            std.elf.SHT_NULL,
                            target_endian,
                        );
                    },
                    std.elf.SHT_SYMTAB => sh.info = std.mem.nativeTo(
                        @TypeOf(sh.info),
                        @intCast(@divExact(
                            size,
                            std.mem.toNative(@TypeOf(sh.entsize), sh.entsize, target_endian),
                        )),
                        target_endian,
                    ),
                    std.elf.SHT_STRTAB => {},
                }
                sh.size = std.mem.nativeTo(@TypeOf(sh.size), @intCast(size), target_endian);
            },
        },
        .nav, .uav, .lazy_code, .lazy_const_data => {},
    }
}

pub fn updateExports(
    elf: *Elf,
    pt: Zcu.PerThread,
    exported: Zcu.Exported,
    export_indices: []const Zcu.Export.Index,
) !void {
    return elf.updateExportsInner(pt, exported, export_indices) catch |err| switch (err) {
        error.OutOfMemory => error.OutOfMemory,
        error.LinkFailure => error.AnalysisFail,
        else => |e| switch (elf.base.comp.link_diags.fail(
            "linker failed to update exports: {t}",
            .{e},
        )) {
            error.LinkFailure => return error.AnalysisFail,
        },
    };
}
fn updateExportsInner(
    elf: *Elf,
    pt: Zcu.PerThread,
    exported: Zcu.Exported,
    export_indices: []const Zcu.Export.Index,
) !void {
    const zcu = pt.zcu;
    const gpa = zcu.gpa;
    const ip = &zcu.intern_pool;

    switch (exported) {
        .nav => |nav| log.debug("updateExports({f})", .{ip.getNav(nav).fqn.fmt(ip)}),
        .uav => |uav| log.debug("updateExports(@as({f}, {f}))", .{
            Type.fromInterned(ip.typeOf(uav)).fmt(pt),
            Value.fromInterned(uav).fmtValue(pt),
        }),
    }
    try elf.symtab.ensureUnusedCapacity(gpa, export_indices.len);
    const exported_si: Symbol.Index, const @"type": std.elf.STT = switch (exported) {
        .nav => |nav| .{
            try elf.navSymbol(zcu, nav),
            navType(ip, ip.getNav(nav).status, elf.base.comp.config.any_non_single_threaded),
        },
        .uav => |uav| .{ @enumFromInt(switch (try elf.lowerUav(
            pt,
            uav,
            Type.fromInterned(ip.typeOf(uav)).abiAlignment(zcu),
            export_indices[0].ptr(zcu).src,
        )) {
            .sym_index => |si| si,
            .fail => |em| {
                defer em.destroy(gpa);
                return elf.base.comp.link_diags.fail("{s}", .{em.msg});
            },
        }), .OBJECT },
    };
    while (try elf.idle(pt.tid)) {}
    const exported_ni = exported_si.node(elf);
    const value, const size, const shndx = switch (elf.symPtr(exported_si)) {
        inline else => |exported_sym| .{ exported_sym.value, exported_sym.size, exported_sym.shndx },
    };
    for (export_indices) |export_index| {
        const @"export" = export_index.ptr(zcu);
        const name = @"export".opts.name.toSlice(ip);
        const export_si = try elf.globalSymbol(.{
            .name = name,
            .type = @"type",
            .bind = switch (@"export".opts.linkage) {
                .internal => .LOCAL,
                .strong => .GLOBAL,
                .weak => .WEAK,
                .link_once => return error.LinkOnceUnsupported,
            },
            .visibility = switch (@"export".opts.visibility) {
                .default => .DEFAULT,
                .hidden => .HIDDEN,
                .protected => .PROTECTED,
            },
        });
        export_si.get(elf).ni = exported_ni;
        switch (elf.symPtr(export_si)) {
            inline else => |export_sym| {
                export_sym.value = @intCast(value);
                export_sym.size = @intCast(size);
                export_sym.shndx = shndx;
            },
        }
        export_si.applyTargetRelocs(elf);
        if (std.mem.eql(u8, name, "_start")) {
            elf.entry_hack = exported_si;
            switch (elf.ehdrPtr()) {
                inline else => |ehdr| ehdr.entry = @intCast(value),
            }
        }
    }
}

pub fn deleteExport(elf: *Elf, exported: Zcu.Exported, name: InternPool.NullTerminatedString) void {
    _ = elf;
    _ = exported;
    _ = name;
}

pub fn dump(elf: *Elf, tid: Zcu.PerThread.Id) void {
    const w = std.debug.lockStderrWriter(&.{});
    defer std.debug.unlockStderrWriter();
    elf.printNode(tid, w, .root, 0) catch {};
}

pub fn printNode(
    elf: *Elf,
    tid: Zcu.PerThread.Id,
    w: *std.Io.Writer,
    ni: MappedFile.Node.Index,
    indent: usize,
) !void {
    const node = elf.getNode(ni);
    const mf_node = &elf.mf.nodes.items[@intFromEnum(ni)];
    const off, const size = mf_node.location().resolve(&elf.mf);
    try w.splatByteAll(' ', indent);
    try w.writeAll(@tagName(node));
    switch (node) {
        else => {},
        .section => |si| try w.print("({s})", .{elf.sectionName(si)}),
        .nav => |nav_index| {
            const zcu = elf.base.comp.zcu.?;
            const ip = &zcu.intern_pool;
            const nav = ip.getNav(nav_index);
            try w.print("({f}, {f})", .{
                Type.fromInterned(nav.typeOf(ip)).fmt(.{ .zcu = zcu, .tid = tid }),
                nav.fqn.fmt(ip),
            });
        },
        .uav => |uav| {
            const zcu = elf.base.comp.zcu.?;
            const val: Value = .fromInterned(uav);
            try w.print("({f}, {f})", .{
                val.typeOf(zcu).fmt(.{ .zcu = zcu, .tid = tid }),
                val.fmtValue(.{ .zcu = zcu, .tid = tid }),
            });
        },
    }
    try w.print(" index={d} offset=0x{x} size=0x{x} align=0x{x}{s}{s}{s}{s}\n", .{
        @intFromEnum(ni),
        off,
        size,
        mf_node.flags.alignment.toByteUnits(),
        if (mf_node.flags.fixed) " fixed" else "",
        if (mf_node.flags.moved) " moved" else "",
        if (mf_node.flags.resized) " resized" else "",
        if (mf_node.flags.has_content) " has_content" else "",
    });
    var child_ni = mf_node.first;
    switch (child_ni) {
        .none => {
            const file_loc = ni.fileLocation(&elf.mf, false);
            if (file_loc.size == 0) return;
            var address = file_loc.offset;
            const line_len = 0x10;
            var line_it = std.mem.window(
                u8,
                elf.mf.contents[@intCast(file_loc.offset)..][0..@intCast(file_loc.size)],
                line_len,
                line_len,
            );
            while (line_it.next()) |line_bytes| : (address += line_len) {
                try w.splatByteAll(' ', indent + 1);
                try w.print("{x:0>8}", .{address});
                for (line_bytes) |byte| try w.print(" {x:0>2}", .{byte});
                try w.writeByte('\n');
            }
        },
        else => while (child_ni != .none) {
            try elf.printNode(tid, w, child_ni, indent + 1);
            child_ni = elf.mf.nodes.items[@intFromEnum(child_ni)].next;
        },
    }
}

const assert = std.debug.assert;
const builtin = @import("builtin");
const codegen = @import("../codegen.zig");
const Compilation = @import("../Compilation.zig");
const Elf = @This();
const InternPool = @import("../InternPool.zig");
const link = @import("../link.zig");
const log = std.log.scoped(.link);
const MappedFile = @import("MappedFile.zig");
const native_endian = builtin.cpu.arch.endian();
const std = @import("std");
const target_util = @import("../target.zig");
const Type = @import("../Type.zig");
const Value = @import("../Value.zig");
const Zcu = @import("../Zcu.zig");

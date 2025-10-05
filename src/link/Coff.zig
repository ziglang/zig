base: link.File,
mf: MappedFile,
nodes: std.MultiArrayList(Node),
import_table: ImportTable,
strings: std.HashMapUnmanaged(
    u32,
    void,
    std.hash_map.StringIndexContext,
    std.hash_map.default_max_load_percentage,
),
string_bytes: std.ArrayList(u8),
section_table: std.ArrayList(Symbol.Index),
symbol_table: std.ArrayList(Symbol),
globals: std.AutoArrayHashMapUnmanaged(GlobalName, Symbol.Index),
global_pending_index: u32,
navs: std.AutoArrayHashMapUnmanaged(InternPool.Nav.Index, Symbol.Index),
uavs: std.AutoArrayHashMapUnmanaged(InternPool.Index, Symbol.Index),
lazy: std.EnumArray(link.File.LazySymbol.Kind, struct {
    map: std.AutoArrayHashMapUnmanaged(InternPool.Index, Symbol.Index),
    pending_index: u32,
}),
pending_uavs: std.AutoArrayHashMapUnmanaged(Node.UavMapIndex, struct {
    alignment: InternPool.Alignment,
    src_loc: Zcu.LazySrcLoc,
}),
relocs: std.ArrayList(Reloc),
/// This is hiding actual bugs with global symbols! Reconsider once they are implemented correctly.
entry_hack: Symbol.Index,

pub const default_file_alignment: u16 = 0x200;
pub const default_size_of_stack_reserve: u32 = 0x1000000;
pub const default_size_of_stack_commit: u32 = 0x1000;
pub const default_size_of_heap_reserve: u32 = 0x100000;
pub const default_size_of_heap_commit: u32 = 0x1000;

/// This is the start of a Portable Executable (PE) file.
/// It starts with a MS-DOS header followed by a MS-DOS stub program.
/// This data does not change so we include it as follows in all binaries.
///
/// In this context,
/// A "paragraph" is 16 bytes.
/// A "page" is 512 bytes.
/// A "long" is 4 bytes.
/// A "word" is 2 bytes.
pub const msdos_stub: [120]u8 = .{
    'M', 'Z', // Magic number. Stands for Mark Zbikowski (designer of the MS-DOS executable format).
    0x78, 0x00, // Number of bytes in the last page. This matches the size of this entire MS-DOS stub.
    0x01, 0x00, // Number of pages.
    0x00, 0x00, // Number of entries in the relocation table.
    0x04, 0x00, // The number of paragraphs taken up by the header. 4 * 16 = 64, which matches the header size (all bytes before the MS-DOS stub program).
    0x00, 0x00, // The number of paragraphs required by the program.
    0x00, 0x00, // The number of paragraphs requested by the program.
    0x00, 0x00, // Initial value for SS (relocatable segment address).
    0x00, 0x00, // Initial value for SP.
    0x00, 0x00, // Checksum.
    0x00, 0x00, // Initial value for IP.
    0x00, 0x00, // Initial value for CS (relocatable segment address).
    0x40, 0x00, // Absolute offset to relocation table. 64 matches the header size (all bytes before the MS-DOS stub program).
    0x00, 0x00, // Overlay number. Zero means this is the main executable.
}
    // Reserved words.
    ++ .{ 0x00, 0x00 } ** 4
        // OEM-related fields.
    ++ .{
        0x00, 0x00, // OEM identifier.
        0x00, 0x00, // OEM information.
    }
    // Reserved words.
    ++ .{ 0x00, 0x00 } ** 10
        // Address of the PE header (a long). This matches the size of this entire MS-DOS stub, so that's the address of what's after this MS-DOS stub.
    ++ .{ 0x78, 0x00, 0x00, 0x00 }
    // What follows is a 16-bit x86 MS-DOS program of 7 instructions that prints the bytes after these instructions and then exits.
    ++ .{
        // Set the value of the data segment to the same value as the code segment.
        0x0e, // push cs
        0x1f, // pop ds
        // Set the DX register to the address of the message.
        // If you count all bytes of these 7 instructions you get 14, so that's the address of what's after these instructions.
        0xba, 14, 0x00, // mov dx, 14
        // Set AH to the system call code for printing a message.
        0xb4, 0x09, // mov ah, 0x09
        // Perform the system call to print the message.
        0xcd, 0x21, // int 0x21
        // Set AH to 0x4c which is the system call code for exiting, and set AL to 0x01 which is the exit code.
        0xb8, 0x01, 0x4c, // mov ax, 0x4c01
        // Peform the system call to exit the program with exit code 1.
        0xcd, 0x21, // int 0x21
    }
    // Message to print.
    ++ "This program cannot be run in DOS mode.".*
    // Message terminators.
    ++ .{
        '$', // We do not pass a length to the print system call; the string is terminated by this character.
        0x00, 0x00, // Terminating zero bytes.
    };

pub const Node = union(enum) {
    file,
    header,
    signature,
    coff_header,
    optional_header,
    data_directories,
    section_table,
    section: Symbol.Index,
    import_directory_table,
    import_lookup_table: ImportTable.Index,
    import_address_table: ImportTable.Index,
    import_hint_name_table: ImportTable.Index,
    global: GlobalMapIndex,
    nav: NavMapIndex,
    uav: UavMapIndex,
    lazy_code: LazyMapRef.Index(.code),
    lazy_const_data: LazyMapRef.Index(.const_data),

    pub const GlobalMapIndex = enum(u32) {
        _,

        pub fn globalName(gmi: GlobalMapIndex, coff: *const Coff) GlobalName {
            return coff.globals.keys()[@intFromEnum(gmi)];
        }

        pub fn symbol(gmi: GlobalMapIndex, coff: *const Coff) Symbol.Index {
            return coff.globals.values()[@intFromEnum(gmi)];
        }
    };

    pub const NavMapIndex = enum(u32) {
        _,

        pub fn navIndex(nmi: NavMapIndex, coff: *const Coff) InternPool.Nav.Index {
            return coff.navs.keys()[@intFromEnum(nmi)];
        }

        pub fn symbol(nmi: NavMapIndex, coff: *const Coff) Symbol.Index {
            return coff.navs.values()[@intFromEnum(nmi)];
        }
    };

    pub const UavMapIndex = enum(u32) {
        _,

        pub fn uavValue(umi: UavMapIndex, coff: *const Coff) InternPool.Index {
            return coff.uavs.keys()[@intFromEnum(umi)];
        }

        pub fn symbol(umi: UavMapIndex, coff: *const Coff) Symbol.Index {
            return coff.uavs.values()[@intFromEnum(umi)];
        }
    };

    pub const LazyMapRef = struct {
        kind: link.File.LazySymbol.Kind,
        index: u32,

        pub fn Index(comptime kind: link.File.LazySymbol.Kind) type {
            return enum(u32) {
                _,

                pub fn ref(lmi: @This()) LazyMapRef {
                    return .{ .kind = kind, .index = @intFromEnum(lmi) };
                }

                pub fn lazySymbol(lmi: @This(), coff: *const Coff) link.File.LazySymbol {
                    return lmi.ref().lazySymbol(coff);
                }

                pub fn symbol(lmi: @This(), coff: *const Coff) Symbol.Index {
                    return lmi.ref().symbol(coff);
                }
            };
        }

        pub fn lazySymbol(lmr: LazyMapRef, coff: *const Coff) link.File.LazySymbol {
            return .{ .kind = lmr.kind, .ty = coff.lazy.getPtrConst(lmr.kind).map.keys()[lmr.index] };
        }

        pub fn symbol(lmr: LazyMapRef, coff: *const Coff) Symbol.Index {
            return coff.lazy.getPtrConst(lmr.kind).map.values()[lmr.index];
        }
    };

    pub const Tag = @typeInfo(Node).@"union".tag_type.?;

    const known_count = @typeInfo(@TypeOf(known)).@"struct".fields.len;
    const known = known: {
        const Known = enum {
            file,
            header,
            signature,
            coff_header,
            optional_header,
            data_directories,
            section_table,
        };
        var mut_known: std.enums.EnumFieldStruct(Known, MappedFile.Node.Index, null) = undefined;
        for (@typeInfo(Known).@"enum".fields) |field|
            @field(mut_known, field.name) = @enumFromInt(field.value);
        break :known mut_known;
    };

    comptime {
        if (!std.debug.runtime_safety) std.debug.assert(@sizeOf(Node) == 8);
    }
};

pub const DataDirectory = enum {
    export_table,
    import_table,
    resorce_table,
    exception_table,
    certificate_table,
    base_relocation_table,
    debug,
    architecture,
    global_ptr,
    tls_table,
    load_config_table,
    bound_import,
    import_address_table,
    delay_import_descriptor,
    clr_runtime_header,
    reserved,

    pub const len = @typeInfo(DataDirectory).@"enum".fields.len;
};

pub const ImportTable = struct {
    ni: MappedFile.Node.Index,
    entries: std.AutoArrayHashMapUnmanaged(void, Entry),

    pub const Entry = struct {
        import_lookup_table_ni: MappedFile.Node.Index,
        import_address_table_si: Symbol.Index,
        import_hint_name_table_ni: MappedFile.Node.Index,
        len: u32,
        hint_name_len: u32,
    };

    const Adapter = struct {
        coff: *Coff,

        pub fn eql(adapter: Adapter, lhs_key: []const u8, _: void, rhs_index: usize) bool {
            const coff = adapter.coff;
            const dll_name = coff.import_table.entries.values()[rhs_index]
                .import_hint_name_table_ni.sliceConst(&coff.mf);
            return std.mem.startsWith(u8, dll_name, lhs_key) and
                std.mem.startsWith(u8, dll_name[lhs_key.len..], ".dll\x00");
        }

        pub fn hash(_: Adapter, key: []const u8) u32 {
            assert(std.mem.indexOfScalar(u8, key, 0) == null);
            return std.array_hash_map.hashString(key);
        }
    };

    pub const Index = enum(u32) {
        _,

        pub fn get(import_index: ImportTable.Index, coff: *Coff) *Entry {
            return &coff.import_table.entries.values()[@intFromEnum(import_index)];
        }
    };
};

pub const String = enum(u32) {
    _,

    pub const Optional = enum(u32) {
        none = std.math.maxInt(u32),
        _,

        pub fn unwrap(os: String.Optional) ?String {
            return switch (os) {
                else => |s| @enumFromInt(@intFromEnum(s)),
                .none => null,
            };
        }

        pub fn toSlice(os: String.Optional, coff: *Coff) ?[:0]const u8 {
            return (os.unwrap() orelse return null).toSlice(coff);
        }
    };

    pub fn toSlice(s: String, coff: *Coff) [:0]const u8 {
        const slice = coff.string_bytes.items[@intFromEnum(s)..];
        return slice[0..std.mem.indexOfScalar(u8, slice, 0).? :0];
    }

    pub fn toOptional(s: String) String.Optional {
        return @enumFromInt(@intFromEnum(s));
    }
};

pub const GlobalName = struct { name: String, lib_name: String.Optional };

pub const Symbol = struct {
    ni: MappedFile.Node.Index,
    rva: u32,
    size: u32,
    /// Relocations contained within this symbol
    loc_relocs: Reloc.Index,
    /// Relocations targeting this symbol
    target_relocs: Reloc.Index,
    section_number: SectionNumber,
    unused0: u32 = 0,
    unused1: u32 = 0,
    unused2: u16 = 0,

    pub const SectionNumber = enum(i16) {
        UNDEFINED = 0,
        ABSOLUTE = -1,
        DEBUG = -2,
        _,

        fn toIndex(sn: SectionNumber) u15 {
            return @intCast(@intFromEnum(sn) - 1);
        }

        pub fn symbol(sn: SectionNumber, coff: *const Coff) Symbol.Index {
            return coff.section_table.items[sn.toIndex()];
        }

        pub fn header(sn: SectionNumber, coff: *Coff) *std.coff.SectionHeader {
            return &coff.sectionTableSlice()[sn.toIndex()];
        }
    };

    pub const Index = enum(u32) {
        null,
        data,
        idata,
        rdata,
        text,
        _,

        const known_count = @typeInfo(Index).@"enum".fields.len;

        pub fn get(si: Symbol.Index, coff: *Coff) *Symbol {
            return &coff.symbol_table.items[@intFromEnum(si)];
        }

        pub fn node(si: Symbol.Index, coff: *Coff) MappedFile.Node.Index {
            const ni = si.get(coff).ni;
            assert(ni != .none);
            return ni;
        }

        pub fn flushMoved(si: Symbol.Index, coff: *Coff) void {
            const sym = si.get(coff);
            sym.rva = coff.computeNodeRva(sym.ni);
            if (si == coff.entry_hack) {
                @branchHint(.unlikely);
                coff.targetStore(&coff.optionalHeaderStandardPtr().address_of_entry_point, sym.rva);
            }
            si.applyLocationRelocs(coff);
            si.applyTargetRelocs(coff);
        }

        pub fn applyLocationRelocs(si: Symbol.Index, coff: *Coff) void {
            for (coff.relocs.items[@intFromEnum(si.get(coff).loc_relocs)..]) |*reloc| {
                if (reloc.loc != si) break;
                reloc.apply(coff);
            }
        }

        pub fn applyTargetRelocs(si: Symbol.Index, coff: *Coff) void {
            var ri = si.get(coff).target_relocs;
            while (ri != .none) {
                const reloc = ri.get(coff);
                assert(reloc.target == si);
                reloc.apply(coff);
                ri = reloc.next;
            }
        }

        pub fn deleteLocationRelocs(si: Symbol.Index, coff: *Coff) void {
            const sym = si.get(coff);
            for (coff.relocs.items[@intFromEnum(sym.loc_relocs)..]) |*reloc| {
                if (reloc.loc != si) break;
                reloc.delete(coff);
            }
            sym.loc_relocs = .none;
        }
    };

    comptime {
        if (!std.debug.runtime_safety) std.debug.assert(@sizeOf(Symbol) == 32);
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
        AMD64: std.coff.IMAGE.REL.AMD64,
        ARM: std.coff.IMAGE.REL.ARM,
        ARM64: std.coff.IMAGE.REL.ARM64,
        SH: std.coff.IMAGE.REL.SH,
        PPC: std.coff.IMAGE.REL.PPC,
        I386: std.coff.IMAGE.REL.I386,
        IA64: std.coff.IMAGE.REL.IA64,
        MIPS: std.coff.IMAGE.REL.MIPS,
        M32R: std.coff.IMAGE.REL.M32R,
    };

    pub const Index = enum(u32) {
        none = std.math.maxInt(u32),
        _,

        pub fn get(si: Reloc.Index, coff: *Coff) *Reloc {
            return &coff.relocs.items[@intFromEnum(si)];
        }
    };

    pub fn apply(reloc: *const Reloc, coff: *Coff) void {
        const loc_sym = reloc.loc.get(coff);
        switch (loc_sym.ni) {
            .none => return,
            else => |ni| if (ni.hasMoved(&coff.mf)) return,
        }
        const target_sym = reloc.target.get(coff);
        switch (target_sym.ni) {
            .none => return,
            else => |ni| if (ni.hasMoved(&coff.mf)) return,
        }
        const loc_slice = loc_sym.ni.slice(&coff.mf)[@intCast(reloc.offset)..];
        const target_rva = target_sym.rva +% @as(u64, @bitCast(reloc.addend));
        const target_endian = coff.targetEndian();
        switch (coff.targetLoad(&coff.headerPtr().machine)) {
            else => |machine| @panic(@tagName(machine)),
            .AMD64 => switch (reloc.type.AMD64) {
                else => |kind| @panic(@tagName(kind)),
                .ABSOLUTE => {},
                .ADDR64 => std.mem.writeInt(
                    u64,
                    loc_slice[0..8],
                    coff.optionalHeaderField(.image_base) + target_rva,
                    target_endian,
                ),
                .ADDR32 => std.mem.writeInt(
                    u32,
                    loc_slice[0..4],
                    @intCast(coff.optionalHeaderField(.image_base) + target_rva),
                    target_endian,
                ),
                .ADDR32NB => std.mem.writeInt(
                    u32,
                    loc_slice[0..4],
                    @intCast(target_rva),
                    target_endian,
                ),
                .REL32 => std.mem.writeInt(
                    i32,
                    loc_slice[0..4],
                    @intCast(@as(i64, @bitCast(target_rva -% (loc_sym.rva + reloc.offset + 4)))),
                    target_endian,
                ),
                .REL32_1 => std.mem.writeInt(
                    i32,
                    loc_slice[0..4],
                    @intCast(@as(i64, @bitCast(target_rva -% (loc_sym.rva + reloc.offset + 5)))),
                    target_endian,
                ),
                .REL32_2 => std.mem.writeInt(
                    i32,
                    loc_slice[0..4],
                    @intCast(@as(i64, @bitCast(target_rva -% (loc_sym.rva + reloc.offset + 6)))),
                    target_endian,
                ),
                .REL32_3 => std.mem.writeInt(
                    i32,
                    loc_slice[0..4],
                    @intCast(@as(i64, @bitCast(target_rva -% (loc_sym.rva + reloc.offset + 7)))),
                    target_endian,
                ),
                .REL32_4 => std.mem.writeInt(
                    i32,
                    loc_slice[0..4],
                    @intCast(@as(i64, @bitCast(target_rva -% (loc_sym.rva + reloc.offset + 8)))),
                    target_endian,
                ),
                .REL32_5 => std.mem.writeInt(
                    i32,
                    loc_slice[0..4],
                    @intCast(@as(i64, @bitCast(target_rva -% (loc_sym.rva + reloc.offset + 9)))),
                    target_endian,
                ),
            },
            .I386 => switch (reloc.type.I386) {
                else => |kind| @panic(@tagName(kind)),
                .ABSOLUTE => {},
                .DIR16 => std.mem.writeInt(
                    u16,
                    loc_slice[0..2],
                    @intCast(coff.optionalHeaderField(.image_base) + target_rva),
                    target_endian,
                ),
                .REL16 => std.mem.writeInt(
                    i16,
                    loc_slice[0..2],
                    @intCast(@as(i64, @bitCast(target_rva -% (loc_sym.rva + reloc.offset + 2)))),
                    target_endian,
                ),
                .DIR32 => std.mem.writeInt(
                    u32,
                    loc_slice[0..4],
                    @intCast(coff.optionalHeaderField(.image_base) + target_rva),
                    target_endian,
                ),
                .DIR32NB => std.mem.writeInt(
                    u32,
                    loc_slice[0..4],
                    @intCast(target_rva),
                    target_endian,
                ),
                .REL32 => std.mem.writeInt(
                    i32,
                    loc_slice[0..4],
                    @intCast(@as(i64, @bitCast(target_rva -% (loc_sym.rva + reloc.offset + 4)))),
                    target_endian,
                ),
            },
        }
    }

    pub fn delete(reloc: *Reloc, coff: *Coff) void {
        switch (reloc.prev) {
            .none => {
                const target = reloc.target.get(coff);
                assert(target.target_relocs.get(coff) == reloc);
                target.target_relocs = reloc.next;
            },
            else => |prev| prev.get(coff).next = reloc.next,
        }
        switch (reloc.next) {
            .none => {},
            else => |next| next.get(coff).prev = reloc.prev,
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
) !*Coff {
    return create(arena, comp, path, options);
}
pub fn createEmpty(
    arena: std.mem.Allocator,
    comp: *Compilation,
    path: std.Build.Cache.Path,
    options: link.File.OpenOptions,
) !*Coff {
    return create(arena, comp, path, options);
}
fn create(
    arena: std.mem.Allocator,
    comp: *Compilation,
    path: std.Build.Cache.Path,
    options: link.File.OpenOptions,
) !*Coff {
    const target = &comp.root_mod.resolved_target.result;
    assert(target.ofmt == .coff);
    if (target.cpu.arch.endian() != comptime targetEndian(undefined))
        return error.UnsupportedCOFFArchitecture;
    const is_image = switch (comp.config.output_mode) {
        .Exe => true,
        .Lib => switch (comp.config.link_mode) {
            .static => false,
            .dynamic => true,
        },
        .Obj => false,
    };
    const machine = target.toCoffMachine();
    const timestamp: u32 = if (options.repro) 0 else @truncate(@as(u64, @bitCast(std.time.timestamp())));
    const major_subsystem_version = options.major_subsystem_version orelse 6;
    const minor_subsystem_version = options.minor_subsystem_version orelse 0;
    const magic: std.coff.OptionalHeader.Magic = switch (target.ptrBitWidth()) {
        0...32 => .PE32,
        33...64 => .@"PE32+",
        else => return error.UnsupportedCOFFArchitecture,
    };
    const section_align: std.mem.Alignment = switch (machine) {
        .AMD64, .I386 => @enumFromInt(12),
        .SH3, .SH3DSP, .SH4, .SH5 => @enumFromInt(12),
        .MIPS16, .MIPSFPU, .MIPSFPU16, .WCEMIPSV2 => @enumFromInt(12),
        .POWERPC, .POWERPCFP => @enumFromInt(12),
        .ALPHA, .ALPHA64 => @enumFromInt(13),
        .IA64 => @enumFromInt(13),
        .ARM => @enumFromInt(12),
        else => return error.UnsupportedCOFFArchitecture,
    };

    const coff = try arena.create(Coff);
    const file = try path.root_dir.handle.createFile(path.sub_path, .{
        .read = true,
        .mode = link.File.determineMode(comp.config.output_mode, comp.config.link_mode),
    });
    errdefer file.close();
    coff.* = .{
        .base = .{
            .tag = .coff2,

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
        .import_table = .{
            .ni = .none,
            .entries = .empty,
        },
        .strings = .empty,
        .string_bytes = .empty,
        .section_table = .empty,
        .symbol_table = .empty,
        .globals = .empty,
        .global_pending_index = 0,
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
    errdefer coff.deinit();

    try coff.initHeaders(
        is_image,
        machine,
        timestamp,
        major_subsystem_version,
        minor_subsystem_version,
        magic,
        section_align,
    );
    return coff;
}

pub fn deinit(coff: *Coff) void {
    const gpa = coff.base.comp.gpa;
    coff.mf.deinit(gpa);
    coff.nodes.deinit(gpa);
    coff.import_table.entries.deinit(gpa);
    coff.strings.deinit(gpa);
    coff.string_bytes.deinit(gpa);
    coff.section_table.deinit(gpa);
    coff.symbol_table.deinit(gpa);
    coff.globals.deinit(gpa);
    coff.navs.deinit(gpa);
    coff.uavs.deinit(gpa);
    for (&coff.lazy.values) |*lazy| lazy.map.deinit(gpa);
    coff.pending_uavs.deinit(gpa);
    coff.relocs.deinit(gpa);
    coff.* = undefined;
}

fn initHeaders(
    coff: *Coff,
    is_image: bool,
    machine: std.coff.IMAGE.FILE.MACHINE,
    timestamp: u32,
    major_subsystem_version: u16,
    minor_subsystem_version: u16,
    magic: std.coff.OptionalHeader.Magic,
    section_align: std.mem.Alignment,
) !void {
    const comp = coff.base.comp;
    const gpa = comp.gpa;
    const file_align: std.mem.Alignment = comptime .fromByteUnits(default_file_alignment);
    const target_endian = coff.targetEndian();

    const optional_header_size: u16 = if (is_image) switch (magic) {
        _ => unreachable,
        inline else => |ct_magic| @sizeOf(@field(std.coff.OptionalHeader, @tagName(ct_magic))),
    } else 0;
    const data_directories_size: u16 = if (is_image)
        @sizeOf(std.coff.ImageDataDirectory) * DataDirectory.len
    else
        0;

    try coff.nodes.ensureTotalCapacity(gpa, Node.known_count);
    coff.nodes.appendAssumeCapacity(.file);

    const header_ni = Node.known.header;
    assert(header_ni == try coff.mf.addOnlyChildNode(gpa, .root, .{
        .alignment = coff.mf.flags.block_size,
        .fixed = true,
    }));
    coff.nodes.appendAssumeCapacity(.header);

    const signature_ni = Node.known.signature;
    assert(signature_ni == try coff.mf.addOnlyChildNode(gpa, header_ni, .{
        .size = (if (is_image) msdos_stub.len else 0) + "PE\x00\x00".len,
        .alignment = .@"4",
        .fixed = true,
    }));
    coff.nodes.appendAssumeCapacity(.signature);
    {
        const signature_slice = signature_ni.slice(&coff.mf);
        if (is_image) @memcpy(signature_slice[0..msdos_stub.len], &msdos_stub);
        @memcpy(signature_slice[signature_slice.len - 4 ..], "PE\x00\x00");
    }

    const coff_header_ni = Node.known.coff_header;
    assert(coff_header_ni == try coff.mf.addLastChildNode(gpa, header_ni, .{
        .size = @sizeOf(std.coff.Header),
        .alignment = .@"4",
        .fixed = true,
    }));
    coff.nodes.appendAssumeCapacity(.coff_header);
    {
        const coff_header = coff.headerPtr();
        coff_header.* = .{
            .machine = machine,
            .number_of_sections = 0,
            .time_date_stamp = timestamp,
            .pointer_to_symbol_table = 0,
            .number_of_symbols = 0,
            .size_of_optional_header = optional_header_size + data_directories_size,
            .flags = .{
                .RELOCS_STRIPPED = is_image,
                .EXECUTABLE_IMAGE = is_image,
                .DEBUG_STRIPPED = true,
                .@"32BIT_MACHINE" = magic == .PE32,
                .LARGE_ADDRESS_AWARE = magic == .@"PE32+",
                .DLL = comp.config.output_mode == .Lib and comp.config.link_mode == .dynamic,
            },
        };
        if (target_endian != native_endian) std.mem.byteSwapAllFields(std.coff.Header, coff_header);
    }

    const optional_header_ni = Node.known.optional_header;
    assert(optional_header_ni == try coff.mf.addLastChildNode(gpa, header_ni, .{
        .size = optional_header_size,
        .alignment = .@"4",
        .fixed = true,
    }));
    coff.nodes.appendAssumeCapacity(.optional_header);
    coff.targetStore(&coff.optionalHeaderStandardPtr().magic, magic);
    if (is_image) switch (coff.optionalHeaderPtr()) {
        .PE32 => |optional_header| {
            optional_header.* = .{
                .standard = .{
                    .magic = .PE32,
                    .major_linker_version = 0,
                    .minor_linker_version = 0,
                    .size_of_code = 0,
                    .size_of_initialized_data = 0,
                    .size_of_uninitialized_data = 0,
                    .address_of_entry_point = 0,
                    .base_of_code = 0,
                },
                .base_of_data = 0,
                .image_base = switch (coff.base.comp.config.output_mode) {
                    .Exe => 0x400000,
                    .Lib => switch (coff.base.comp.config.link_mode) {
                        .static => 0,
                        .dynamic => 0x10000000,
                    },
                    .Obj => 0,
                },
                .section_alignment = @intCast(section_align.toByteUnits()),
                .file_alignment = @intCast(file_align.toByteUnits()),
                .major_operating_system_version = 6,
                .minor_operating_system_version = 0,
                .major_image_version = 0,
                .minor_image_version = 0,
                .major_subsystem_version = major_subsystem_version,
                .minor_subsystem_version = minor_subsystem_version,
                .win32_version_value = 0,
                .size_of_image = 0,
                .size_of_headers = 0,
                .checksum = 0,
                .subsystem = .WINDOWS_CUI,
                .dll_flags = .{
                    .HIGH_ENTROPY_VA = true,
                    .DYNAMIC_BASE = true,
                    .TERMINAL_SERVER_AWARE = true,
                    .NX_COMPAT = true,
                },
                .size_of_stack_reserve = default_size_of_stack_reserve,
                .size_of_stack_commit = default_size_of_stack_commit,
                .size_of_heap_reserve = default_size_of_heap_reserve,
                .size_of_heap_commit = default_size_of_heap_commit,
                .loader_flags = 0,
                .number_of_rva_and_sizes = DataDirectory.len,
            };
            if (target_endian != native_endian)
                std.mem.byteSwapAllFields(std.coff.OptionalHeader.PE32, optional_header);
        },
        .@"PE32+" => |optional_header| {
            optional_header.* = .{
                .standard = .{
                    .magic = .@"PE32+",
                    .major_linker_version = 0,
                    .minor_linker_version = 0,
                    .size_of_code = 0,
                    .size_of_initialized_data = 0,
                    .size_of_uninitialized_data = 0,
                    .address_of_entry_point = 0,
                    .base_of_code = 0,
                },
                .image_base = switch (coff.base.comp.config.output_mode) {
                    .Exe => 0x140000000,
                    .Lib => switch (coff.base.comp.config.link_mode) {
                        .static => 0,
                        .dynamic => 0x180000000,
                    },
                    .Obj => 0,
                },
                .section_alignment = @intCast(section_align.toByteUnits()),
                .file_alignment = @intCast(file_align.toByteUnits()),
                .major_operating_system_version = 6,
                .minor_operating_system_version = 0,
                .major_image_version = 0,
                .minor_image_version = 0,
                .major_subsystem_version = major_subsystem_version,
                .minor_subsystem_version = minor_subsystem_version,
                .win32_version_value = 0,
                .size_of_image = 0,
                .size_of_headers = 0,
                .checksum = 0,
                .subsystem = .WINDOWS_CUI,
                .dll_flags = .{
                    .HIGH_ENTROPY_VA = true,
                    .DYNAMIC_BASE = true,
                    .TERMINAL_SERVER_AWARE = true,
                    .NX_COMPAT = true,
                },
                .size_of_stack_reserve = default_size_of_stack_reserve,
                .size_of_stack_commit = default_size_of_stack_commit,
                .size_of_heap_reserve = default_size_of_heap_reserve,
                .size_of_heap_commit = default_size_of_heap_commit,
                .loader_flags = 0,
                .number_of_rva_and_sizes = DataDirectory.len,
            };
            if (target_endian != native_endian)
                std.mem.byteSwapAllFields(std.coff.OptionalHeader.@"PE32+", optional_header);
        },
    };

    const data_directories_ni = Node.known.data_directories;
    assert(data_directories_ni == try coff.mf.addLastChildNode(gpa, header_ni, .{
        .size = data_directories_size,
        .alignment = .@"4",
        .fixed = true,
    }));
    coff.nodes.appendAssumeCapacity(.data_directories);
    {
        const data_directories = coff.dataDirectorySlice();
        @memset(data_directories, .{ .virtual_address = 0, .size = 0 });
        if (target_endian != native_endian)
            std.mem.byteSwapAllFields([DataDirectory.len]std.coff.ImageDataDirectory, data_directories);
    }

    const section_table_ni = Node.known.section_table;
    assert(section_table_ni == try coff.mf.addLastChildNode(gpa, header_ni, .{
        .alignment = .@"4",
        .fixed = true,
    }));
    coff.nodes.appendAssumeCapacity(.section_table);

    assert(coff.nodes.len == Node.known_count);

    try coff.symbol_table.ensureTotalCapacity(gpa, Symbol.Index.known_count);
    coff.symbol_table.addOneAssumeCapacity().* = .{
        .ni = .none,
        .rva = 0,
        .size = 0,
        .loc_relocs = .none,
        .target_relocs = .none,
        .section_number = .UNDEFINED,
    };
    assert(try coff.addSection(".data", .{
        .CNT_INITIALIZED_DATA = true,
        .MEM_READ = true,
        .MEM_WRITE = true,
    }) == .data);
    assert(try coff.addSection(".idata", .{
        .CNT_INITIALIZED_DATA = true,
        .MEM_READ = true,
    }) == .idata);
    assert(try coff.addSection(".rdata", .{
        .CNT_INITIALIZED_DATA = true,
        .MEM_READ = true,
    }) == .rdata);
    assert(try coff.addSection(".text", .{
        .CNT_CODE = true,
        .MEM_EXECUTE = true,
        .MEM_READ = true,
    }) == .text);
    coff.import_table.ni = try coff.mf.addLastChildNode(
        gpa,
        Symbol.Index.idata.node(coff),
        .{ .alignment = .@"4" },
    );
    coff.nodes.appendAssumeCapacity(.import_directory_table);
    assert(coff.symbol_table.items.len == Symbol.Index.known_count);
}

fn getNode(coff: *const Coff, ni: MappedFile.Node.Index) Node {
    return coff.nodes.get(@intFromEnum(ni));
}
fn computeNodeRva(coff: *Coff, ni: MappedFile.Node.Index) u32 {
    const parent_rva = parent_rva: {
        const parent_si = switch (coff.getNode(ni.parent(&coff.mf))) {
            .file,
            .header,
            .signature,
            .coff_header,
            .optional_header,
            .data_directories,
            .section_table,
            => unreachable,
            .section => |si| si,
            .import_directory_table => unreachable,
            .import_lookup_table => |import_index| break :parent_rva coff.targetLoad(
                &coff.importDirectoryEntryPtr(import_index).import_lookup_table_rva,
            ),
            .import_address_table => |import_index| break :parent_rva coff.targetLoad(
                &coff.importDirectoryEntryPtr(import_index).import_address_table_rva,
            ),
            .import_hint_name_table => |import_index| break :parent_rva coff.targetLoad(
                &coff.importDirectoryEntryPtr(import_index).name_rva,
            ),
            inline .global, .nav, .uav, .lazy_code, .lazy_const_data => |mi| mi.symbol(coff),
        };
        break :parent_rva parent_si.get(coff).rva;
    };
    const offset, _ = ni.location(&coff.mf).resolve(&coff.mf);
    return @intCast(parent_rva + offset);
}

pub inline fn targetEndian(_: *const Coff) std.builtin.Endian {
    return .little;
}
fn targetLoad(coff: *const Coff, ptr: anytype) @typeInfo(@TypeOf(ptr)).pointer.child {
    const Child = @typeInfo(@TypeOf(ptr)).pointer.child;
    return switch (@typeInfo(Child)) {
        else => @compileError(@typeName(Child)),
        .int => std.mem.toNative(Child, ptr.*, coff.targetEndian()),
        .@"enum" => |@"enum"| @enumFromInt(coff.targetLoad(@as(*@"enum".tag_type, @ptrCast(ptr)))),
        .@"struct" => |@"struct"| @bitCast(
            coff.targetLoad(@as(*@"struct".backing_integer.?, @ptrCast(ptr))),
        ),
    };
}
fn targetStore(coff: *const Coff, ptr: anytype, val: @typeInfo(@TypeOf(ptr)).pointer.child) void {
    const Child = @typeInfo(@TypeOf(ptr)).pointer.child;
    return switch (@typeInfo(Child)) {
        else => @compileError(@typeName(Child)),
        .int => ptr.* = std.mem.nativeTo(Child, val, coff.targetEndian()),
        .@"enum" => |@"enum"| coff.targetStore(
            @as(*@"enum".tag_type, @ptrCast(ptr)),
            @intFromEnum(val),
        ),
        .@"struct" => |@"struct"| coff.targetStore(
            @as(*@"struct".backing_integer.?, @ptrCast(ptr)),
            @bitCast(val),
        ),
    };
}

pub fn headerPtr(coff: *Coff) *std.coff.Header {
    return @ptrCast(@alignCast(Node.known.coff_header.slice(&coff.mf)));
}

pub fn optionalHeaderStandardPtr(coff: *Coff) *std.coff.OptionalHeader {
    return @ptrCast(@alignCast(
        Node.known.optional_header.slice(&coff.mf)[0..@sizeOf(std.coff.OptionalHeader)],
    ));
}

pub const OptionalHeaderPtr = union(std.coff.OptionalHeader.Magic) {
    PE32: *std.coff.OptionalHeader.PE32,
    @"PE32+": *std.coff.OptionalHeader.@"PE32+",
};
pub fn optionalHeaderPtr(coff: *Coff) OptionalHeaderPtr {
    const slice = Node.known.optional_header.slice(&coff.mf);
    return switch (coff.targetLoad(&coff.optionalHeaderStandardPtr().magic)) {
        _ => unreachable,
        inline else => |magic| @unionInit(
            OptionalHeaderPtr,
            @tagName(magic),
            @ptrCast(@alignCast(slice)),
        ),
    };
}
pub fn optionalHeaderField(
    coff: *Coff,
    comptime field: std.meta.FieldEnum(std.coff.OptionalHeader.@"PE32+"),
) @FieldType(std.coff.OptionalHeader.@"PE32+", @tagName(field)) {
    return switch (coff.optionalHeaderPtr()) {
        inline else => |optional_header| coff.targetLoad(&@field(optional_header, @tagName(field))),
    };
}

pub fn dataDirectorySlice(coff: *Coff) *[DataDirectory.len]std.coff.ImageDataDirectory {
    return @ptrCast(@alignCast(Node.known.data_directories.slice(&coff.mf)));
}
pub fn dataDirectoryPtr(coff: *Coff, data_directory: DataDirectory) *std.coff.ImageDataDirectory {
    return &coff.dataDirectorySlice()[@intFromEnum(data_directory)];
}

pub fn sectionTableSlice(coff: *Coff) []std.coff.SectionHeader {
    return @ptrCast(@alignCast(Node.known.section_table.slice(&coff.mf)));
}

pub fn importDirectoryTableSlice(coff: *Coff) []std.coff.ImportDirectoryEntry {
    return @ptrCast(@alignCast(coff.import_table.ni.slice(&coff.mf)));
}
pub fn importDirectoryEntryPtr(
    coff: *Coff,
    import_index: ImportTable.Index,
) *std.coff.ImportDirectoryEntry {
    return &coff.importDirectoryTableSlice()[@intFromEnum(import_index)];
}

fn addSymbolAssumeCapacity(coff: *Coff) Symbol.Index {
    defer coff.symbol_table.addOneAssumeCapacity().* = .{
        .ni = .none,
        .rva = 0,
        .size = 0,
        .loc_relocs = .none,
        .target_relocs = .none,
        .section_number = .UNDEFINED,
    };
    return @enumFromInt(coff.symbol_table.items.len);
}

fn initSymbolAssumeCapacity(coff: *Coff) !Symbol.Index {
    const si = coff.addSymbolAssumeCapacity();
    return si;
}

fn getOrPutString(coff: *Coff, string: []const u8) !String {
    const gpa = coff.base.comp.gpa;
    try coff.string_bytes.ensureUnusedCapacity(gpa, string.len + 1);
    const gop = try coff.strings.getOrPutContextAdapted(
        gpa,
        string,
        std.hash_map.StringIndexAdapter{ .bytes = &coff.string_bytes },
        .{ .bytes = &coff.string_bytes },
    );
    if (!gop.found_existing) {
        gop.key_ptr.* = @intCast(coff.string_bytes.items.len);
        gop.value_ptr.* = {};
        coff.string_bytes.appendSliceAssumeCapacity(string);
        coff.string_bytes.appendAssumeCapacity(0);
    }
    return @enumFromInt(gop.key_ptr.*);
}

fn getOrPutOptionalString(coff: *Coff, string: ?[]const u8) !String.Optional {
    return (try coff.getOrPutString(string orelse return .none)).toOptional();
}

pub fn globalSymbol(coff: *Coff, name: []const u8, lib_name: ?[]const u8) !Symbol.Index {
    const gpa = coff.base.comp.gpa;
    try coff.symbol_table.ensureUnusedCapacity(gpa, 1);
    const sym_gop = try coff.globals.getOrPut(gpa, .{
        .name = try coff.getOrPutString(name),
        .lib_name = try coff.getOrPutOptionalString(lib_name),
    });
    if (!sym_gop.found_existing) {
        sym_gop.value_ptr.* = coff.addSymbolAssumeCapacity();
        coff.base.comp.link_synth_prog_node.increaseEstimatedTotalItems(1);
    }
    return sym_gop.value_ptr.*;
}

fn navMapIndex(coff: *Coff, zcu: *Zcu, nav_index: InternPool.Nav.Index) !Node.NavMapIndex {
    const gpa = zcu.gpa;
    try coff.symbol_table.ensureUnusedCapacity(gpa, 1);
    const sym_gop = try coff.navs.getOrPut(gpa, nav_index);
    if (!sym_gop.found_existing) sym_gop.value_ptr.* = coff.addSymbolAssumeCapacity();
    return @enumFromInt(sym_gop.index);
}
pub fn navSymbol(coff: *Coff, zcu: *Zcu, nav_index: InternPool.Nav.Index) !Symbol.Index {
    const ip = &zcu.intern_pool;
    const nav = ip.getNav(nav_index);
    if (nav.getExtern(ip)) |@"extern"| return coff.globalSymbol(
        @"extern".name.toSlice(ip),
        @"extern".lib_name.toSlice(ip),
    );
    const nmi = try coff.navMapIndex(zcu, nav_index);
    return nmi.symbol(coff);
}

fn uavMapIndex(coff: *Coff, uav_val: InternPool.Index) !Node.UavMapIndex {
    const gpa = coff.base.comp.gpa;
    try coff.symbol_table.ensureUnusedCapacity(gpa, 1);
    const sym_gop = try coff.uavs.getOrPut(gpa, uav_val);
    if (!sym_gop.found_existing) sym_gop.value_ptr.* = coff.addSymbolAssumeCapacity();
    return @enumFromInt(sym_gop.index);
}
pub fn uavSymbol(coff: *Coff, uav_val: InternPool.Index) !Symbol.Index {
    const umi = try coff.uavMapIndex(uav_val);
    return umi.symbol(coff);
}

pub fn lazySymbol(coff: *Coff, lazy: link.File.LazySymbol) !Symbol.Index {
    const gpa = coff.base.comp.gpa;
    try coff.symbol_table.ensureUnusedCapacity(gpa, 1);
    const sym_gop = try coff.lazy.getPtr(lazy.kind).map.getOrPut(gpa, lazy.ty);
    if (!sym_gop.found_existing) {
        sym_gop.value_ptr.* = try coff.initSymbolAssumeCapacity();
        coff.base.comp.link_synth_prog_node.increaseEstimatedTotalItems(1);
    }
    return sym_gop.value_ptr.*;
}

pub fn getNavVAddr(
    coff: *Coff,
    pt: Zcu.PerThread,
    nav: InternPool.Nav.Index,
    reloc_info: link.File.RelocInfo,
) !u64 {
    return coff.getVAddr(reloc_info, try coff.navSymbol(pt.zcu, nav));
}

pub fn getUavVAddr(
    coff: *Coff,
    uav: InternPool.Index,
    reloc_info: link.File.RelocInfo,
) !u64 {
    return coff.getVAddr(reloc_info, try coff.uavSymbol(uav));
}

pub fn getVAddr(coff: *Coff, reloc_info: link.File.RelocInfo, target_si: Symbol.Index) !u64 {
    try coff.addReloc(
        @enumFromInt(reloc_info.parent.atom_index),
        reloc_info.offset,
        target_si,
        reloc_info.addend,
        switch (coff.targetLoad(&coff.headerPtr().machine)) {
            else => unreachable,
            .AMD64 => .{ .AMD64 = .ADDR64 },
            .I386 => .{ .I386 = .DIR32 },
        },
    );
    return coff.optionalHeaderField(.image_base) + target_si.get(coff).rva;
}

fn addSection(coff: *Coff, name: []const u8, flags: std.coff.SectionHeader.Flags) !Symbol.Index {
    const gpa = coff.base.comp.gpa;
    try coff.nodes.ensureUnusedCapacity(gpa, 1);
    try coff.section_table.ensureUnusedCapacity(gpa, 1);
    try coff.symbol_table.ensureUnusedCapacity(gpa, 1);

    const coff_header = coff.headerPtr();
    const section_index = coff.targetLoad(&coff_header.number_of_sections);
    const section_table_len = section_index + 1;
    coff.targetStore(&coff_header.number_of_sections, section_table_len);
    try Node.known.section_table.resize(
        &coff.mf,
        gpa,
        @sizeOf(std.coff.SectionHeader) * section_table_len,
    );
    const ni = try coff.mf.addLastChildNode(gpa, .root, .{
        .alignment = coff.mf.flags.block_size,
        .moved = true,
        .bubbles_moved = false,
    });
    const si = coff.addSymbolAssumeCapacity();
    coff.section_table.appendAssumeCapacity(si);
    coff.nodes.appendAssumeCapacity(.{ .section = si });
    const section_table = coff.sectionTableSlice();
    const virtual_size = coff.optionalHeaderField(.section_alignment);
    const rva: u32 = switch (section_index) {
        0 => @intCast(Node.known.header.location(&coff.mf).resolve(&coff.mf)[1]),
        else => coff.section_table.items[section_index - 1].get(coff).rva +
            coff.targetLoad(&section_table[section_index - 1].virtual_size),
    };
    {
        const sym = si.get(coff);
        sym.ni = ni;
        sym.rva = rva;
        sym.section_number = @enumFromInt(section_table_len);
    }
    const section = &section_table[section_index];
    section.* = .{
        .name = undefined,
        .virtual_size = virtual_size,
        .virtual_address = rva,
        .size_of_raw_data = 0,
        .pointer_to_raw_data = 0,
        .pointer_to_relocations = 0,
        .pointer_to_linenumbers = 0,
        .number_of_relocations = 0,
        .number_of_linenumbers = 0,
        .flags = flags,
    };
    @memcpy(section.name[0..name.len], name);
    @memset(section.name[name.len..], 0);
    if (coff.targetEndian() != native_endian)
        std.mem.byteSwapAllFields(std.coff.SectionHeader, section);
    switch (coff.optionalHeaderPtr()) {
        inline else => |optional_header| coff.targetStore(
            &optional_header.size_of_image,
            @intCast(rva + virtual_size),
        ),
    }
    return si;
}

pub fn addReloc(
    coff: *Coff,
    loc_si: Symbol.Index,
    offset: u64,
    target_si: Symbol.Index,
    addend: i64,
    @"type": Reloc.Type,
) !void {
    const gpa = coff.base.comp.gpa;
    const target = target_si.get(coff);
    const ri: Reloc.Index = @enumFromInt(coff.relocs.items.len);
    (try coff.relocs.addOne(gpa)).* = .{
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
        else => |target_ri| target_ri.get(coff).prev = ri,
    }
    target.target_relocs = ri;
}

pub fn prelink(coff: *Coff, prog_node: std.Progress.Node) void {
    _ = coff;
    _ = prog_node;
}

pub fn updateNav(coff: *Coff, pt: Zcu.PerThread, nav_index: InternPool.Nav.Index) !void {
    coff.updateNavInner(pt, nav_index) catch |err| switch (err) {
        error.OutOfMemory,
        error.Overflow,
        error.RelocationNotByteAligned,
        => |e| return e,
        else => |e| return coff.base.cgFail(nav_index, "linker failed to update variable: {t}", .{e}),
    };
}
fn updateNavInner(coff: *Coff, pt: Zcu.PerThread, nav_index: InternPool.Nav.Index) !void {
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

    const nmi = try coff.navMapIndex(zcu, nav_index);
    const si = nmi.symbol(coff);
    const ni = ni: {
        const sym = si.get(coff);
        switch (sym.ni) {
            .none => {
                try coff.nodes.ensureUnusedCapacity(gpa, 1);
                _ = is_threadlocal;
                const ni = try coff.mf.addLastChildNode(gpa, Symbol.Index.data.node(coff), .{
                    .alignment = pt.navAlignment(nav_index).toStdMem(),
                    .moved = true,
                });
                coff.nodes.appendAssumeCapacity(.{ .nav = nmi });
                sym.ni = ni;
                sym.section_number = Symbol.Index.data.get(coff).section_number;
            },
            else => si.deleteLocationRelocs(coff),
        }
        assert(sym.loc_relocs == .none);
        sym.loc_relocs = @enumFromInt(coff.relocs.items.len);
        break :ni sym.ni;
    };

    var nw: MappedFile.Node.Writer = undefined;
    ni.writer(&coff.mf, gpa, &nw);
    defer nw.deinit();
    codegen.generateSymbol(
        &coff.base,
        pt,
        zcu.navSrcLoc(nav_index),
        .fromInterned(nav_init),
        &nw.interface,
        .{ .atom_index = @intFromEnum(si) },
    ) catch |err| switch (err) {
        error.WriteFailed => return error.OutOfMemory,
        else => |e| return e,
    };
    si.get(coff).size = @intCast(nw.interface.end);
    si.applyLocationRelocs(coff);
}

pub fn lowerUav(
    coff: *Coff,
    pt: Zcu.PerThread,
    uav_val: InternPool.Index,
    uav_align: InternPool.Alignment,
    src_loc: Zcu.LazySrcLoc,
) !codegen.SymbolResult {
    const zcu = pt.zcu;
    const gpa = zcu.gpa;

    try coff.pending_uavs.ensureUnusedCapacity(gpa, 1);
    const umi = try coff.uavMapIndex(uav_val);
    const si = umi.symbol(coff);
    if (switch (si.get(coff).ni) {
        .none => true,
        else => |ni| uav_align.toStdMem().order(ni.alignment(&coff.mf)).compare(.gt),
    }) {
        const gop = coff.pending_uavs.getOrPutAssumeCapacity(umi);
        if (gop.found_existing) {
            gop.value_ptr.alignment = gop.value_ptr.alignment.max(uav_align);
        } else {
            gop.value_ptr.* = .{
                .alignment = uav_align,
                .src_loc = src_loc,
            };
            coff.base.comp.link_const_prog_node.increaseEstimatedTotalItems(1);
        }
    }
    return .{ .sym_index = @intFromEnum(si) };
}

pub fn updateFunc(
    coff: *Coff,
    pt: Zcu.PerThread,
    func_index: InternPool.Index,
    mir: *const codegen.AnyMir,
) !void {
    coff.updateFuncInner(pt, func_index, mir) catch |err| switch (err) {
        error.OutOfMemory,
        error.Overflow,
        error.RelocationNotByteAligned,
        error.CodegenFail,
        => |e| return e,
        else => |e| return coff.base.cgFail(
            pt.zcu.funcInfo(func_index).owner_nav,
            "linker failed to update function: {s}",
            .{@errorName(e)},
        ),
    };
}
fn updateFuncInner(
    coff: *Coff,
    pt: Zcu.PerThread,
    func_index: InternPool.Index,
    mir: *const codegen.AnyMir,
) !void {
    const zcu = pt.zcu;
    const gpa = zcu.gpa;
    const ip = &zcu.intern_pool;
    const func = zcu.funcInfo(func_index);
    const nav = ip.getNav(func.owner_nav);

    const nmi = try coff.navMapIndex(zcu, func.owner_nav);
    const si = nmi.symbol(coff);
    log.debug("updateFunc({f}) = {d}", .{ nav.fqn.fmt(ip), si });
    const ni = ni: {
        const sym = si.get(coff);
        switch (sym.ni) {
            .none => {
                try coff.nodes.ensureUnusedCapacity(gpa, 1);
                const mod = zcu.navFileScope(func.owner_nav).mod.?;
                const target = &mod.resolved_target.result;
                const ni = try coff.mf.addLastChildNode(gpa, Symbol.Index.text.node(coff), .{
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
                coff.nodes.appendAssumeCapacity(.{ .nav = nmi });
                sym.ni = ni;
                sym.section_number = Symbol.Index.text.get(coff).section_number;
            },
            else => si.deleteLocationRelocs(coff),
        }
        assert(sym.loc_relocs == .none);
        sym.loc_relocs = @enumFromInt(coff.relocs.items.len);
        break :ni sym.ni;
    };

    var nw: MappedFile.Node.Writer = undefined;
    ni.writer(&coff.mf, gpa, &nw);
    defer nw.deinit();
    codegen.emitFunction(
        &coff.base,
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
    si.get(coff).size = @intCast(nw.interface.end);
    si.applyLocationRelocs(coff);
}

pub fn updateErrorData(coff: *Coff, pt: Zcu.PerThread) !void {
    coff.flushLazy(pt, .{
        .kind = .const_data,
        .index = @intCast(coff.lazy.getPtr(.const_data).map.getIndex(.anyerror_type) orelse return),
    }) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        error.CodegenFail => return error.LinkFailure,
        else => |e| return coff.base.comp.link_diags.fail("updateErrorData failed {t}", .{e}),
    };
}

pub fn flush(
    coff: *Coff,
    arena: std.mem.Allocator,
    tid: Zcu.PerThread.Id,
    prog_node: std.Progress.Node,
) !void {
    _ = arena;
    _ = prog_node;
    while (try coff.idle(tid)) {}

    // hack for stage2_x86_64 + coff
    const comp = coff.base.comp;
    if (comp.compiler_rt_dyn_lib) |crt_file| {
        const gpa = comp.gpa;
        const compiler_rt_sub_path = try std.fs.path.join(gpa, &.{
            std.fs.path.dirname(coff.base.emit.sub_path) orelse "",
            std.fs.path.basename(crt_file.full_object_path.sub_path),
        });
        defer gpa.free(compiler_rt_sub_path);
        crt_file.full_object_path.root_dir.handle.copyFile(
            crt_file.full_object_path.sub_path,
            coff.base.emit.root_dir.handle,
            compiler_rt_sub_path,
            .{},
        ) catch |err| switch (err) {
            else => |e| return comp.link_diags.fail("Copy '{s}' failed: {s}", .{
                compiler_rt_sub_path,
                @errorName(e),
            }),
        };
    }
}

pub fn idle(coff: *Coff, tid: Zcu.PerThread.Id) !bool {
    const comp = coff.base.comp;
    task: {
        while (coff.pending_uavs.pop()) |pending_uav| {
            const sub_prog_node = coff.idleProgNode(
                tid,
                comp.link_const_prog_node,
                .{ .uav = pending_uav.key },
            );
            defer sub_prog_node.end();
            coff.flushUav(
                .{ .zcu = coff.base.comp.zcu.?, .tid = tid },
                pending_uav.key,
                pending_uav.value.alignment,
                pending_uav.value.src_loc,
            ) catch |err| switch (err) {
                error.OutOfMemory => return error.OutOfMemory,
                else => |e| return coff.base.comp.link_diags.fail(
                    "linker failed to lower constant: {t}",
                    .{e},
                ),
            };
            break :task;
        }
        if (coff.global_pending_index < coff.globals.count()) {
            const pt: Zcu.PerThread = .{ .zcu = coff.base.comp.zcu.?, .tid = tid };
            const gmi: Node.GlobalMapIndex = @enumFromInt(coff.global_pending_index);
            coff.global_pending_index += 1;
            const sub_prog_node = comp.link_synth_prog_node.start(
                gmi.globalName(coff).name.toSlice(coff),
                0,
            );
            defer sub_prog_node.end();
            coff.flushGlobal(pt, gmi) catch |err| switch (err) {
                error.OutOfMemory => return error.OutOfMemory,
                else => |e| return coff.base.comp.link_diags.fail(
                    "linker failed to lower constant: {t}",
                    .{e},
                ),
            };
            break :task;
        }
        var lazy_it = coff.lazy.iterator();
        while (lazy_it.next()) |lazy| if (lazy.value.pending_index < lazy.value.map.count()) {
            const pt: Zcu.PerThread = .{ .zcu = coff.base.comp.zcu.?, .tid = tid };
            const lmr: Node.LazyMapRef = .{ .kind = lazy.key, .index = lazy.value.pending_index };
            lazy.value.pending_index += 1;
            const kind = switch (lmr.kind) {
                .code => "code",
                .const_data => "data",
            };
            var name: [std.Progress.Node.max_name_len]u8 = undefined;
            const sub_prog_node = comp.link_synth_prog_node.start(
                std.fmt.bufPrint(&name, "lazy {s} for {f}", .{
                    kind,
                    Type.fromInterned(lmr.lazySymbol(coff).ty).fmt(pt),
                }) catch &name,
                0,
            );
            defer sub_prog_node.end();
            coff.flushLazy(pt, lmr) catch |err| switch (err) {
                error.OutOfMemory => return error.OutOfMemory,
                else => |e| return coff.base.comp.link_diags.fail(
                    "linker failed to lower lazy {s}: {t}",
                    .{ kind, e },
                ),
            };
            break :task;
        };
        while (coff.mf.updates.pop()) |ni| {
            const clean_moved = ni.cleanMoved(&coff.mf);
            const clean_resized = ni.cleanResized(&coff.mf);
            if (clean_moved or clean_resized) {
                const sub_prog_node = coff.idleProgNode(tid, coff.mf.update_prog_node, coff.getNode(ni));
                defer sub_prog_node.end();
                if (clean_moved) try coff.flushMoved(ni);
                if (clean_resized) try coff.flushResized(ni);
                break :task;
            } else coff.mf.update_prog_node.completeOne();
        }
    }
    if (coff.pending_uavs.count() > 0) return true;
    for (&coff.lazy.values) |lazy| if (lazy.map.count() > lazy.pending_index) return true;
    if (coff.mf.updates.items.len > 0) return true;
    return false;
}

fn idleProgNode(
    coff: *Coff,
    tid: Zcu.PerThread.Id,
    prog_node: std.Progress.Node,
    node: Node,
) std.Progress.Node {
    var name: [std.Progress.Node.max_name_len]u8 = undefined;
    return prog_node.start(name: switch (node) {
        else => |tag| @tagName(tag),
        .section => |si| std.mem.sliceTo(&si.get(coff).section_number.header(coff).name, 0),
        .nav => |nmi| {
            const ip = &coff.base.comp.zcu.?.intern_pool;
            break :name ip.getNav(nmi.navIndex(coff)).fqn.toSlice(ip);
        },
        .uav => |umi| std.fmt.bufPrint(&name, "{f}", .{
            Value.fromInterned(umi.uavValue(coff)).fmtValue(.{
                .zcu = coff.base.comp.zcu.?,
                .tid = tid,
            }),
        }) catch &name,
    }, 0);
}

fn flushUav(
    coff: *Coff,
    pt: Zcu.PerThread,
    umi: Node.UavMapIndex,
    uav_align: InternPool.Alignment,
    src_loc: Zcu.LazySrcLoc,
) !void {
    const zcu = pt.zcu;
    const gpa = zcu.gpa;

    const uav_val = umi.uavValue(coff);
    const si = umi.symbol(coff);
    const ni = ni: {
        const sym = si.get(coff);
        switch (sym.ni) {
            .none => {
                try coff.nodes.ensureUnusedCapacity(gpa, 1);
                const ni = try coff.mf.addLastChildNode(gpa, Symbol.Index.data.node(coff), .{
                    .alignment = uav_align.toStdMem(),
                    .moved = true,
                });
                coff.nodes.appendAssumeCapacity(.{ .uav = umi });
                sym.ni = ni;
                sym.section_number = Symbol.Index.data.get(coff).section_number;
            },
            else => {
                if (sym.ni.alignment(&coff.mf).order(uav_align.toStdMem()).compare(.gte)) return;
                si.deleteLocationRelocs(coff);
            },
        }
        assert(sym.loc_relocs == .none);
        sym.loc_relocs = @enumFromInt(coff.relocs.items.len);
        break :ni sym.ni;
    };

    var nw: MappedFile.Node.Writer = undefined;
    ni.writer(&coff.mf, gpa, &nw);
    defer nw.deinit();
    codegen.generateSymbol(
        &coff.base,
        pt,
        src_loc,
        .fromInterned(uav_val),
        &nw.interface,
        .{ .atom_index = @intFromEnum(si) },
    ) catch |err| switch (err) {
        error.WriteFailed => return error.OutOfMemory,
        else => |e| return e,
    };
    si.get(coff).size = @intCast(nw.interface.end);
    si.applyLocationRelocs(coff);
}

fn flushGlobal(coff: *Coff, pt: Zcu.PerThread, gmi: Node.GlobalMapIndex) !void {
    const zcu = pt.zcu;
    const comp = zcu.comp;
    const gpa = zcu.gpa;
    const gn = gmi.globalName(coff);
    if (gn.lib_name.toSlice(coff)) |lib_name| {
        const name = gn.name.toSlice(coff);
        try coff.nodes.ensureUnusedCapacity(gpa, 4);
        try coff.symbol_table.ensureUnusedCapacity(gpa, 1);

        const target_endian = coff.targetEndian();
        const magic = coff.targetLoad(&coff.optionalHeaderStandardPtr().magic);
        const addr_size: u64, const addr_align: std.mem.Alignment = switch (magic) {
            _ => unreachable,
            .PE32 => .{ 4, .@"4" },
            .@"PE32+" => .{ 8, .@"8" },
        };

        const gop = try coff.import_table.entries.getOrPutAdapted(
            gpa,
            lib_name,
            ImportTable.Adapter{ .coff = coff },
        );
        const import_hint_name_align: std.mem.Alignment = .@"2";
        if (!gop.found_existing) {
            errdefer _ = coff.import_table.entries.pop();
            try coff.import_table.ni.resize(
                &coff.mf,
                gpa,
                @sizeOf(std.coff.ImportDirectoryEntry) * (gop.index + 2),
            );
            const import_hint_name_table_len =
                import_hint_name_align.forward(lib_name.len + ".dll".len + 1);
            const idata_section_ni = Symbol.Index.idata.node(coff);
            const import_lookup_table_ni = try coff.mf.addLastChildNode(gpa, idata_section_ni, .{
                .size = addr_size * 2,
                .alignment = addr_align,
                .moved = true,
            });
            const import_address_table_ni = try coff.mf.addLastChildNode(gpa, idata_section_ni, .{
                .size = addr_size * 2,
                .alignment = addr_align,
                .moved = true,
            });
            const import_address_table_si = coff.addSymbolAssumeCapacity();
            {
                const import_address_table_sym = import_address_table_si.get(coff);
                import_address_table_sym.ni = import_address_table_ni;
                assert(import_address_table_sym.loc_relocs == .none);
                import_address_table_sym.loc_relocs = @enumFromInt(coff.relocs.items.len);
                import_address_table_sym.section_number = Symbol.Index.idata.get(coff).section_number;
            }
            const import_hint_name_table_ni = try coff.mf.addLastChildNode(gpa, idata_section_ni, .{
                .size = import_hint_name_table_len,
                .alignment = import_hint_name_align,
                .moved = true,
            });
            gop.value_ptr.* = .{
                .import_lookup_table_ni = import_lookup_table_ni,
                .import_address_table_si = import_address_table_si,
                .import_hint_name_table_ni = import_hint_name_table_ni,
                .len = 0,
                .hint_name_len = @intCast(import_hint_name_table_len),
            };
            const import_hint_name_slice = import_hint_name_table_ni.slice(&coff.mf);
            @memcpy(import_hint_name_slice[0..lib_name.len], lib_name);
            @memcpy(import_hint_name_slice[lib_name.len..][0..".dll".len], ".dll");
            @memset(import_hint_name_slice[lib_name.len + ".dll".len ..], 0);
            coff.nodes.appendAssumeCapacity(.{ .import_lookup_table = @enumFromInt(gop.index) });
            coff.nodes.appendAssumeCapacity(.{ .import_address_table = @enumFromInt(gop.index) });
            coff.nodes.appendAssumeCapacity(.{ .import_hint_name_table = @enumFromInt(gop.index) });

            const import_directory_entries = coff.importDirectoryTableSlice()[gop.index..][0..2];
            import_directory_entries.* = .{ .{
                .import_lookup_table_rva = coff.computeNodeRva(import_lookup_table_ni),
                .time_date_stamp = 0,
                .forwarder_chain = 0,
                .name_rva = coff.computeNodeRva(import_hint_name_table_ni),
                .import_address_table_rva = coff.computeNodeRva(import_address_table_ni),
            }, .{
                .import_lookup_table_rva = 0,
                .time_date_stamp = 0,
                .forwarder_chain = 0,
                .name_rva = 0,
                .import_address_table_rva = 0,
            } };
            if (target_endian != native_endian)
                std.mem.byteSwapAllFields([2]std.coff.ImportDirectoryEntry, import_directory_entries);
        }
        const import_symbol_index = gop.value_ptr.len;
        gop.value_ptr.len = import_symbol_index + 1;
        const new_symbol_table_size = addr_size * (import_symbol_index + 2);
        const import_hint_name_index = gop.value_ptr.hint_name_len;
        gop.value_ptr.hint_name_len = @intCast(
            import_hint_name_align.forward(import_hint_name_index + 2 + name.len + 1),
        );
        try gop.value_ptr.import_lookup_table_ni.resize(&coff.mf, gpa, new_symbol_table_size);
        const import_address_table_ni = gop.value_ptr.import_address_table_si.node(coff);
        try import_address_table_ni.resize(&coff.mf, gpa, new_symbol_table_size);
        try gop.value_ptr.import_hint_name_table_ni.resize(&coff.mf, gpa, gop.value_ptr.hint_name_len);
        const import_lookup_slice = gop.value_ptr.import_lookup_table_ni.slice(&coff.mf);
        const import_address_slice = import_address_table_ni.slice(&coff.mf);
        const import_hint_name_slice = gop.value_ptr.import_hint_name_table_ni.slice(&coff.mf);
        @memset(import_hint_name_slice[import_hint_name_index..][0..2], 0);
        @memcpy(import_hint_name_slice[import_hint_name_index + 2 ..][0..name.len], name);
        @memset(import_hint_name_slice[import_hint_name_index + 2 + name.len ..], 0);
        const import_hint_name_rva =
            coff.computeNodeRva(gop.value_ptr.import_hint_name_table_ni) + import_hint_name_index;
        switch (magic) {
            _ => unreachable,
            inline .PE32, .@"PE32+" => |ct_magic| {
                const Addr = switch (ct_magic) {
                    _ => comptime unreachable,
                    .PE32 => u32,
                    .@"PE32+" => u64,
                };
                const import_lookup_table: []Addr = @ptrCast(@alignCast(import_lookup_slice));
                const import_address_table: []Addr = @ptrCast(@alignCast(import_address_slice));
                const import_hint_name_rvas: [2]Addr = .{
                    std.mem.nativeTo(Addr, @intCast(import_hint_name_rva), target_endian),
                    std.mem.nativeTo(Addr, 0, target_endian),
                };
                import_lookup_table[import_symbol_index..][0..2].* = import_hint_name_rvas;
                import_address_table[import_symbol_index..][0..2].* = import_hint_name_rvas;
            },
        }
        const si = gmi.symbol(coff);
        const sym = si.get(coff);
        sym.section_number = Symbol.Index.text.get(coff).section_number;
        assert(sym.loc_relocs == .none);
        sym.loc_relocs = @enumFromInt(coff.relocs.items.len);
        switch (coff.targetLoad(&coff.headerPtr().machine)) {
            else => |tag| @panic(@tagName(tag)),
            .AMD64 => {
                const init = [_]u8{ 0xff, 0x25, 0x00, 0x00, 0x00, 0x00 };
                const target = &comp.root_mod.resolved_target.result;
                const ni = try coff.mf.addLastChildNode(gpa, Symbol.Index.text.node(coff), .{
                    .alignment = switch (comp.root_mod.optimize_mode) {
                        .Debug,
                        .ReleaseSafe,
                        .ReleaseFast,
                        => target_util.defaultFunctionAlignment(target),
                        .ReleaseSmall => target_util.minFunctionAlignment(target),
                    }.toStdMem(),
                    .size = init.len,
                });
                @memcpy(ni.slice(&coff.mf)[0..init.len], &init);
                sym.ni = ni;
                sym.size = init.len;
                try coff.addReloc(
                    si,
                    init.len - 4,
                    gop.value_ptr.import_address_table_si,
                    @intCast(addr_size * import_symbol_index),
                    .{ .AMD64 = .REL32 },
                );
            },
        }
        coff.nodes.appendAssumeCapacity(.{ .global = gmi });
        sym.rva = coff.computeNodeRva(sym.ni);
        si.applyLocationRelocs(coff);
    }
}

fn flushLazy(coff: *Coff, pt: Zcu.PerThread, lmr: Node.LazyMapRef) !void {
    const zcu = pt.zcu;
    const gpa = zcu.gpa;

    const lazy = lmr.lazySymbol(coff);
    const si = lmr.symbol(coff);
    const ni = ni: {
        const sym = si.get(coff);
        switch (sym.ni) {
            .none => {
                try coff.nodes.ensureUnusedCapacity(gpa, 1);
                const sec_si: Symbol.Index = switch (lazy.kind) {
                    .code => .text,
                    .const_data => .rdata,
                };
                const ni = try coff.mf.addLastChildNode(gpa, sec_si.node(coff), .{ .moved = true });
                coff.nodes.appendAssumeCapacity(switch (lazy.kind) {
                    .code => .{ .lazy_code = @enumFromInt(lmr.index) },
                    .const_data => .{ .lazy_const_data = @enumFromInt(lmr.index) },
                });
                sym.ni = ni;
                sym.section_number = sec_si.get(coff).section_number;
            },
            else => si.deleteLocationRelocs(coff),
        }
        assert(sym.loc_relocs == .none);
        sym.loc_relocs = @enumFromInt(coff.relocs.items.len);
        break :ni sym.ni;
    };

    var required_alignment: InternPool.Alignment = .none;
    var nw: MappedFile.Node.Writer = undefined;
    ni.writer(&coff.mf, gpa, &nw);
    defer nw.deinit();
    try codegen.generateLazySymbol(
        &coff.base,
        pt,
        Type.fromInterned(lazy.ty).srcLocOrNull(pt.zcu) orelse .unneeded,
        lazy,
        &required_alignment,
        &nw.interface,
        .none,
        .{ .atom_index = @intFromEnum(si) },
    );
    si.get(coff).size = @intCast(nw.interface.end);
    si.applyLocationRelocs(coff);
}

fn flushMoved(coff: *Coff, ni: MappedFile.Node.Index) !void {
    switch (coff.getNode(ni)) {
        .file,
        .header,
        .signature,
        .coff_header,
        .optional_header,
        .data_directories,
        .section_table,
        => unreachable,
        .section => |si| return coff.targetStore(
            &si.get(coff).section_number.header(coff).pointer_to_raw_data,
            @intCast(ni.fileLocation(&coff.mf, false).offset),
        ),
        .import_directory_table => coff.targetStore(
            &coff.dataDirectoryPtr(.import_table).virtual_address,
            coff.computeNodeRva(ni),
        ),
        .import_lookup_table => |import_index| coff.targetStore(
            &coff.importDirectoryEntryPtr(import_index).import_lookup_table_rva,
            coff.computeNodeRva(ni),
        ),
        .import_address_table => |import_index| {
            const import_address_table_si = import_index.get(coff).import_address_table_si;
            import_address_table_si.flushMoved(coff);
            coff.targetStore(
                &coff.importDirectoryEntryPtr(import_index).import_address_table_rva,
                import_address_table_si.get(coff).rva,
            );
        },
        .import_hint_name_table => |import_index| {
            const target_endian = coff.targetEndian();
            const magic = coff.targetLoad(&coff.optionalHeaderStandardPtr().magic);
            const import_hint_name_rva = coff.computeNodeRva(ni);
            coff.targetStore(
                &coff.importDirectoryEntryPtr(import_index).name_rva,
                import_hint_name_rva,
            );
            const import_entry = import_index.get(coff);
            const import_lookup_slice = import_entry.import_lookup_table_ni.slice(&coff.mf);
            const import_address_slice =
                import_entry.import_address_table_si.node(coff).slice(&coff.mf);
            const import_hint_name_slice = ni.slice(&coff.mf);
            const import_hint_name_align = ni.alignment(&coff.mf);
            var import_hint_name_index: u32 = 0;
            for (0..import_entry.len) |import_symbol_index| {
                import_hint_name_index = @intCast(import_hint_name_align.forward(
                    std.mem.indexOfScalarPos(
                        u8,
                        import_hint_name_slice,
                        import_hint_name_index,
                        0,
                    ).? + 1,
                ));
                switch (magic) {
                    _ => unreachable,
                    inline .PE32, .@"PE32+" => |ct_magic| {
                        const Addr = switch (ct_magic) {
                            _ => comptime unreachable,
                            .PE32 => u32,
                            .@"PE32+" => u64,
                        };
                        const import_lookup_table: []Addr = @ptrCast(@alignCast(import_lookup_slice));
                        const import_address_table: []Addr = @ptrCast(@alignCast(import_address_slice));
                        const rva = std.mem.nativeTo(
                            Addr,
                            import_hint_name_rva + import_hint_name_index,
                            target_endian,
                        );
                        import_lookup_table[import_symbol_index] = rva;
                        import_address_table[import_symbol_index] = rva;
                    },
                }
                import_hint_name_index += 2;
            }
        },
        inline .global,
        .nav,
        .uav,
        .lazy_code,
        .lazy_const_data,
        => |mi| mi.symbol(coff).flushMoved(coff),
    }
    try ni.childrenMoved(coff.base.comp.gpa, &coff.mf);
}

fn flushResized(coff: *Coff, ni: MappedFile.Node.Index) !void {
    _, const size = ni.location(&coff.mf).resolve(&coff.mf);
    switch (coff.getNode(ni)) {
        .file => {},
        .header => {
            switch (coff.optionalHeaderPtr()) {
                inline else => |optional_header| coff.targetStore(
                    &optional_header.size_of_headers,
                    @intCast(size),
                ),
            }
            if (size > coff.section_table.items[0].get(coff).rva) try coff.virtualSlide(
                0,
                std.mem.alignForward(
                    u32,
                    @intCast(size * 4),
                    coff.optionalHeaderField(.section_alignment),
                ),
            );
        },
        .signature, .coff_header, .optional_header, .data_directories => unreachable,
        .section_table => {},
        .section => |si| {
            const sym = si.get(coff);
            const section_index = sym.section_number.toIndex();
            const section = &coff.sectionTableSlice()[section_index];
            coff.targetStore(&section.size_of_raw_data, @intCast(size));
            if (size > coff.targetLoad(&section.virtual_size)) {
                const virtual_size = std.mem.alignForward(
                    u32,
                    @intCast(size * 4),
                    coff.optionalHeaderField(.section_alignment),
                );
                coff.targetStore(&section.virtual_size, virtual_size);
                try coff.virtualSlide(section_index + 1, sym.rva + virtual_size);
            }
        },
        .import_directory_table => coff.targetStore(
            &coff.dataDirectoryPtr(.import_table).size,
            @intCast(size),
        ),
        .import_lookup_table,
        .import_address_table,
        .import_hint_name_table,
        .global,
        .nav,
        .uav,
        .lazy_code,
        .lazy_const_data,
        => {},
    }
}
fn virtualSlide(coff: *Coff, start_section_index: usize, start_rva: u32) !void {
    var rva = start_rva;
    for (
        coff.section_table.items[start_section_index..],
        coff.sectionTableSlice()[start_section_index..],
    ) |section_si, *section| {
        const section_sym = section_si.get(coff);
        section_sym.rva = rva;
        coff.targetStore(&section.virtual_address, rva);
        try section_sym.ni.childrenMoved(coff.base.comp.gpa, &coff.mf);
        rva += coff.targetLoad(&section.virtual_size);
    }
    switch (coff.optionalHeaderPtr()) {
        inline else => |optional_header| coff.targetStore(
            &optional_header.size_of_image,
            @intCast(rva),
        ),
    }
}

pub fn updateExports(
    coff: *Coff,
    pt: Zcu.PerThread,
    exported: Zcu.Exported,
    export_indices: []const Zcu.Export.Index,
) !void {
    return coff.updateExportsInner(pt, exported, export_indices) catch |err| switch (err) {
        error.OutOfMemory => error.OutOfMemory,
        error.LinkFailure => error.AnalysisFail,
    };
}
fn updateExportsInner(
    coff: *Coff,
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
    try coff.symbol_table.ensureUnusedCapacity(gpa, export_indices.len);
    const exported_si: Symbol.Index = switch (exported) {
        .nav => |nav| try coff.navSymbol(zcu, nav),
        .uav => |uav| @enumFromInt(switch (try coff.lowerUav(
            pt,
            uav,
            Type.fromInterned(ip.typeOf(uav)).abiAlignment(zcu),
            export_indices[0].ptr(zcu).src,
        )) {
            .sym_index => |si| si,
            .fail => |em| {
                defer em.destroy(gpa);
                return coff.base.comp.link_diags.fail("{s}", .{em.msg});
            },
        }),
    };
    while (try coff.idle(pt.tid)) {}
    const exported_ni = exported_si.node(coff);
    const exported_sym = exported_si.get(coff);
    for (export_indices) |export_index| {
        const @"export" = export_index.ptr(zcu);
        const export_si = try coff.globalSymbol(@"export".opts.name.toSlice(ip), null);
        const export_sym = export_si.get(coff);
        export_sym.ni = exported_ni;
        export_sym.rva = exported_sym.rva;
        export_sym.size = exported_sym.size;
        export_sym.section_number = exported_sym.section_number;
        export_si.applyTargetRelocs(coff);
        if (@"export".opts.name.eqlSlice("wWinMainCRTStartup", ip)) {
            coff.entry_hack = exported_si;
            coff.optionalHeaderStandardPtr().address_of_entry_point = exported_sym.rva;
        }
    }
}

pub fn deleteExport(coff: *Coff, exported: Zcu.Exported, name: InternPool.NullTerminatedString) void {
    _ = coff;
    _ = exported;
    _ = name;
}

pub fn dump(coff: *Coff, tid: Zcu.PerThread.Id) void {
    const w = std.debug.lockStderrWriter(&.{});
    defer std.debug.unlockStderrWriter();
    coff.printNode(tid, w, .root, 0) catch {};
}

pub fn printNode(
    coff: *Coff,
    tid: Zcu.PerThread.Id,
    w: *std.Io.Writer,
    ni: MappedFile.Node.Index,
    indent: usize,
) !void {
    const node = coff.getNode(ni);
    try w.splatByteAll(' ', indent);
    try w.writeAll(@tagName(node));
    switch (node) {
        else => {},
        .section => |si| try w.print("({s})", .{
            std.mem.sliceTo(&si.get(coff).section_number.header(coff).name, 0),
        }),
        .import_lookup_table,
        .import_address_table,
        .import_hint_name_table,
        => |import_index| try w.print("({s})", .{
            std.mem.sliceTo(import_index.get(coff).import_hint_name_table_ni.sliceConst(&coff.mf), 0),
        }),
        .global => |gmi| {
            const gn = gmi.globalName(coff);
            try w.writeByte('(');
            if (gn.lib_name.toSlice(coff)) |lib_name| try w.print("{s}.dll, ", .{lib_name});
            try w.print("{s})", .{gn.name.toSlice(coff)});
        },
        .nav => |nmi| {
            const zcu = coff.base.comp.zcu.?;
            const ip = &zcu.intern_pool;
            const nav = ip.getNav(nmi.navIndex(coff));
            try w.print("({f}, {f})", .{
                Type.fromInterned(nav.typeOf(ip)).fmt(.{ .zcu = zcu, .tid = tid }),
                nav.fqn.fmt(ip),
            });
        },
        .uav => |umi| {
            const zcu = coff.base.comp.zcu.?;
            const val: Value = .fromInterned(umi.uavValue(coff));
            try w.print("({f}, {f})", .{
                val.typeOf(zcu).fmt(.{ .zcu = zcu, .tid = tid }),
                val.fmtValue(.{ .zcu = zcu, .tid = tid }),
            });
        },
        inline .lazy_code, .lazy_const_data => |lmi| try w.print("({f})", .{
            Type.fromInterned(lmi.lazySymbol(coff).ty).fmt(.{
                .zcu = coff.base.comp.zcu.?,
                .tid = tid,
            }),
        }),
    }
    {
        const mf_node = &coff.mf.nodes.items[@intFromEnum(ni)];
        const off, const size = mf_node.location().resolve(&coff.mf);
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
    }
    var leaf = true;
    var child_it = ni.children(&coff.mf);
    while (child_it.next()) |child_ni| {
        leaf = false;
        try coff.printNode(tid, w, child_ni, indent + 1);
    }
    if (leaf) {
        const file_loc = ni.fileLocation(&coff.mf, false);
        if (file_loc.size == 0) return;
        var address = file_loc.offset;
        const line_len = 0x10;
        var line_it = std.mem.window(
            u8,
            coff.mf.contents[@intCast(file_loc.offset)..][0..@intCast(file_loc.size)],
            line_len,
            line_len,
        );
        while (line_it.next()) |line_bytes| : (address += line_len) {
            try w.splatByteAll(' ', indent + 1);
            try w.print("{x:0>8}  ", .{address});
            for (line_bytes) |byte| try w.print("{x:0>2} ", .{byte});
            try w.splatByteAll(' ', 3 * (line_len - line_bytes.len) + 1);
            for (line_bytes) |byte| try w.writeByte(if (std.ascii.isPrint(byte)) byte else '.');
            try w.writeByte('\n');
        }
    }
}

const assert = std.debug.assert;
const builtin = @import("builtin");
const codegen = @import("../codegen.zig");
const Compilation = @import("../Compilation.zig");
const Coff = @This();
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

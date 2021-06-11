// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const builtin = std.builtin;
const std = @import("std.zig");
const io = std.io;
const math = std.math;
const mem = std.mem;
const os = std.os;
const warn = std.debug.warn;
const coff = std.coff;
const fs = std.fs;
const File = std.fs.File;
const debug = std.debug;

const ArrayList = std.ArrayList;

// Note: most of this is based on information gathered from LLVM source code,
// documentation and/or contributors.

// https://llvm.org/docs/PDB/DbiStream.html#stream-header
pub const DbiStreamHeader = packed struct {
    VersionSignature: i32,
    VersionHeader: u32,
    Age: u32,
    GlobalStreamIndex: u16,
    BuildNumber: u16,
    PublicStreamIndex: u16,
    PdbDllVersion: u16,
    SymRecordStream: u16,
    PdbDllRbld: u16,
    ModInfoSize: u32,
    SectionContributionSize: u32,
    SectionMapSize: u32,
    SourceInfoSize: i32,
    TypeServerSize: i32,
    MFCTypeServerIndex: u32,
    OptionalDbgHeaderSize: i32,
    ECSubstreamSize: i32,
    Flags: u16,
    Machine: u16,
    Padding: u32,
};

pub const SectionContribEntry = packed struct {
    /// COFF Section index, 1-based
    Section: u16,
    Padding1: [2]u8,
    Offset: u32,
    Size: u32,
    Characteristics: u32,
    ModuleIndex: u16,
    Padding2: [2]u8,
    DataCrc: u32,
    RelocCrc: u32,
};

pub const ModInfo = packed struct {
    Unused1: u32,
    SectionContr: SectionContribEntry,
    Flags: u16,
    ModuleSymStream: u16,
    SymByteSize: u32,
    C11ByteSize: u32,
    C13ByteSize: u32,
    SourceFileCount: u16,
    Padding: [2]u8,
    Unused2: u32,
    SourceFileNameIndex: u32,
    PdbFilePathNameIndex: u32,
    // These fields are variable length
    //ModuleName: char[],
    //ObjFileName: char[],
};

pub const SectionMapHeader = packed struct {
    /// Number of segment descriptors
    Count: u16,

    /// Number of logical segment descriptors
    LogCount: u16,
};

pub const SectionMapEntry = packed struct {
    /// See the SectionMapEntryFlags enum below.
    Flags: u16,

    /// Logical overlay number
    Ovl: u16,

    /// Group index into descriptor array.
    Group: u16,
    Frame: u16,

    /// Byte index of segment / group name in string table, or 0xFFFF.
    SectionName: u16,

    /// Byte index of class in string table, or 0xFFFF.
    ClassName: u16,

    /// Byte offset of the logical segment within physical segment.  If group is set in flags, this is the offset of the group.
    Offset: u32,

    /// Byte count of the segment or group.
    SectionLength: u32,
};

pub const StreamType = enum(u16) {
    Pdb = 1,
    Tpi = 2,
    Dbi = 3,
    Ipi = 4,
};

/// Duplicate copy of SymbolRecordKind, but using the official CV names. Useful
/// for reference purposes and when dealing with unknown record types.
pub const SymbolKind = enum(u16) {
    S_COMPILE = 1,
    S_REGISTER_16t = 2,
    S_CONSTANT_16t = 3,
    S_UDT_16t = 4,
    S_SSEARCH = 5,
    S_SKIP = 7,
    S_CVRESERVE = 8,
    S_OBJNAME_ST = 9,
    S_ENDARG = 10,
    S_COBOLUDT_16t = 11,
    S_MANYREG_16t = 12,
    S_RETURN = 13,
    S_ENTRYTHIS = 14,
    S_BPREL16 = 256,
    S_LDATA16 = 257,
    S_GDATA16 = 258,
    S_PUB16 = 259,
    S_LPROC16 = 260,
    S_GPROC16 = 261,
    S_THUNK16 = 262,
    S_BLOCK16 = 263,
    S_WITH16 = 264,
    S_LABEL16 = 265,
    S_CEXMODEL16 = 266,
    S_VFTABLE16 = 267,
    S_REGREL16 = 268,
    S_BPREL32_16t = 512,
    S_LDATA32_16t = 513,
    S_GDATA32_16t = 514,
    S_PUB32_16t = 515,
    S_LPROC32_16t = 516,
    S_GPROC32_16t = 517,
    S_THUNK32_ST = 518,
    S_BLOCK32_ST = 519,
    S_WITH32_ST = 520,
    S_LABEL32_ST = 521,
    S_CEXMODEL32 = 522,
    S_VFTABLE32_16t = 523,
    S_REGREL32_16t = 524,
    S_LTHREAD32_16t = 525,
    S_GTHREAD32_16t = 526,
    S_SLINK32 = 527,
    S_LPROCMIPS_16t = 768,
    S_GPROCMIPS_16t = 769,
    S_PROCREF_ST = 1024,
    S_DATAREF_ST = 1025,
    S_ALIGN = 1026,
    S_LPROCREF_ST = 1027,
    S_OEM = 1028,
    S_TI16_MAX = 4096,
    S_REGISTER_ST = 4097,
    S_CONSTANT_ST = 4098,
    S_UDT_ST = 4099,
    S_COBOLUDT_ST = 4100,
    S_MANYREG_ST = 4101,
    S_BPREL32_ST = 4102,
    S_LDATA32_ST = 4103,
    S_GDATA32_ST = 4104,
    S_PUB32_ST = 4105,
    S_LPROC32_ST = 4106,
    S_GPROC32_ST = 4107,
    S_VFTABLE32 = 4108,
    S_REGREL32_ST = 4109,
    S_LTHREAD32_ST = 4110,
    S_GTHREAD32_ST = 4111,
    S_LPROCMIPS_ST = 4112,
    S_GPROCMIPS_ST = 4113,
    S_COMPILE2_ST = 4115,
    S_MANYREG2_ST = 4116,
    S_LPROCIA64_ST = 4117,
    S_GPROCIA64_ST = 4118,
    S_LOCALSLOT_ST = 4119,
    S_PARAMSLOT_ST = 4120,
    S_ANNOTATION = 4121,
    S_GMANPROC_ST = 4122,
    S_LMANPROC_ST = 4123,
    S_RESERVED1 = 4124,
    S_RESERVED2 = 4125,
    S_RESERVED3 = 4126,
    S_RESERVED4 = 4127,
    S_LMANDATA_ST = 4128,
    S_GMANDATA_ST = 4129,
    S_MANFRAMEREL_ST = 4130,
    S_MANREGISTER_ST = 4131,
    S_MANSLOT_ST = 4132,
    S_MANMANYREG_ST = 4133,
    S_MANREGREL_ST = 4134,
    S_MANMANYREG2_ST = 4135,
    S_MANTYPREF = 4136,
    S_UNAMESPACE_ST = 4137,
    S_ST_MAX = 4352,
    S_WITH32 = 4356,
    S_MANYREG = 4362,
    S_LPROCMIPS = 4372,
    S_GPROCMIPS = 4373,
    S_MANYREG2 = 4375,
    S_LPROCIA64 = 4376,
    S_GPROCIA64 = 4377,
    S_LOCALSLOT = 4378,
    S_PARAMSLOT = 4379,
    S_MANFRAMEREL = 4382,
    S_MANREGISTER = 4383,
    S_MANSLOT = 4384,
    S_MANMANYREG = 4385,
    S_MANREGREL = 4386,
    S_MANMANYREG2 = 4387,
    S_UNAMESPACE = 4388,
    S_DATAREF = 4390,
    S_ANNOTATIONREF = 4392,
    S_TOKENREF = 4393,
    S_GMANPROC = 4394,
    S_LMANPROC = 4395,
    S_ATTR_FRAMEREL = 4398,
    S_ATTR_REGISTER = 4399,
    S_ATTR_REGREL = 4400,
    S_ATTR_MANYREG = 4401,
    S_SEPCODE = 4402,
    S_LOCAL_2005 = 4403,
    S_DEFRANGE_2005 = 4404,
    S_DEFRANGE2_2005 = 4405,
    S_DISCARDED = 4411,
    S_LPROCMIPS_ID = 4424,
    S_GPROCMIPS_ID = 4425,
    S_LPROCIA64_ID = 4426,
    S_GPROCIA64_ID = 4427,
    S_DEFRANGE_HLSL = 4432,
    S_GDATA_HLSL = 4433,
    S_LDATA_HLSL = 4434,
    S_LOCAL_DPC_GROUPSHARED = 4436,
    S_DEFRANGE_DPC_PTR_TAG = 4439,
    S_DPC_SYM_TAG_MAP = 4440,
    S_ARMSWITCHTABLE = 4441,
    S_POGODATA = 4444,
    S_INLINESITE2 = 4445,
    S_MOD_TYPEREF = 4447,
    S_REF_MINIPDB = 4448,
    S_PDBMAP = 4449,
    S_GDATA_HLSL32 = 4450,
    S_LDATA_HLSL32 = 4451,
    S_GDATA_HLSL32_EX = 4452,
    S_LDATA_HLSL32_EX = 4453,
    S_FASTLINK = 4455,
    S_INLINEES = 4456,
    S_END = 6,
    S_INLINESITE_END = 4430,
    S_PROC_ID_END = 4431,
    S_THUNK32 = 4354,
    S_TRAMPOLINE = 4396,
    S_SECTION = 4406,
    S_COFFGROUP = 4407,
    S_EXPORT = 4408,
    S_LPROC32 = 4367,
    S_GPROC32 = 4368,
    S_LPROC32_ID = 4422,
    S_GPROC32_ID = 4423,
    S_LPROC32_DPC = 4437,
    S_LPROC32_DPC_ID = 4438,
    S_REGISTER = 4358,
    S_PUB32 = 4366,
    S_PROCREF = 4389,
    S_LPROCREF = 4391,
    S_ENVBLOCK = 4413,
    S_INLINESITE = 4429,
    S_LOCAL = 4414,
    S_DEFRANGE = 4415,
    S_DEFRANGE_SUBFIELD = 4416,
    S_DEFRANGE_REGISTER = 4417,
    S_DEFRANGE_FRAMEPOINTER_REL = 4418,
    S_DEFRANGE_SUBFIELD_REGISTER = 4419,
    S_DEFRANGE_FRAMEPOINTER_REL_FULL_SCOPE = 4420,
    S_DEFRANGE_REGISTER_REL = 4421,
    S_BLOCK32 = 4355,
    S_LABEL32 = 4357,
    S_OBJNAME = 4353,
    S_COMPILE2 = 4374,
    S_COMPILE3 = 4412,
    S_FRAMEPROC = 4114,
    S_CALLSITEINFO = 4409,
    S_FILESTATIC = 4435,
    S_HEAPALLOCSITE = 4446,
    S_FRAMECOOKIE = 4410,
    S_CALLEES = 4442,
    S_CALLERS = 4443,
    S_UDT = 4360,
    S_COBOLUDT = 4361,
    S_BUILDINFO = 4428,
    S_BPREL32 = 4363,
    S_REGREL32 = 4369,
    S_CONSTANT = 4359,
    S_MANCONSTANT = 4397,
    S_LDATA32 = 4364,
    S_GDATA32 = 4365,
    S_LMANDATA = 4380,
    S_GMANDATA = 4381,
    S_LTHREAD32 = 4370,
    S_GTHREAD32 = 4371,
};

pub const TypeIndex = u32;

pub const ProcSym = packed struct {
    Parent: u32,
    End: u32,
    Next: u32,
    CodeSize: u32,
    DbgStart: u32,
    DbgEnd: u32,
    FunctionType: TypeIndex,
    CodeOffset: u32,
    Segment: u16,
    Flags: ProcSymFlags,
    // following is a null terminated string
    // Name: [*]u8,
};

pub const ProcSymFlags = packed struct {
    HasFP: bool,
    HasIRET: bool,
    HasFRET: bool,
    IsNoReturn: bool,
    IsUnreachable: bool,
    HasCustomCallingConv: bool,
    IsNoInline: bool,
    HasOptimizedDebugInfo: bool,
};

pub const SectionContrSubstreamVersion = enum(u32) {
    Ver60 = 0xeffe0000 + 19970605,
    V2 = 0xeffe0000 + 20140516,
    _,
};

pub const RecordPrefix = packed struct {
    /// Record length, starting from &RecordKind.
    RecordLen: u16,

    /// Record kind enum (SymRecordKind or TypeRecordKind)
    RecordKind: SymbolKind,
};

/// The following variable length array appears immediately after the header.
/// The structure definition follows.
/// LineBlockFragmentHeader Blocks[]
/// Each `LineBlockFragmentHeader` as specified below.
pub const LineFragmentHeader = packed struct {
    /// Code offset of line contribution.
    RelocOffset: u32,

    /// Code segment of line contribution.
    RelocSegment: u16,
    Flags: LineFlags,

    /// Code size of this line contribution.
    CodeSize: u32,
};

pub const LineFlags = packed struct {
    /// CV_LINES_HAVE_COLUMNS
    LF_HaveColumns: bool,
    unused: u15,
};

/// The following two variable length arrays appear immediately after the
/// header.  The structure definitions follow.
/// LineNumberEntry   Lines[NumLines];
/// ColumnNumberEntry Columns[NumLines];
pub const LineBlockFragmentHeader = packed struct {
    /// Offset of FileChecksum entry in File
    /// checksums buffer.  The checksum entry then
    /// contains another offset into the string
    /// table of the actual name.
    NameIndex: u32,
    NumLines: u32,

    /// code size of block, in bytes
    BlockSize: u32,
};

pub const LineNumberEntry = packed struct {
    /// Offset to start of code bytes for line number
    Offset: u32,
    Flags: u32,

    /// TODO runtime crash when I make the actual type of Flags this
    pub const Flags = packed struct {
        /// Start line number
        Start: u24,
        /// Delta of lines to the end of the expression. Still unclear.
        // TODO figure out the point of this field.
        End: u7,
        IsStatement: bool,
    };
};

pub const ColumnNumberEntry = packed struct {
    StartColumn: u16,
    EndColumn: u16,
};

/// Checksum bytes follow.
pub const FileChecksumEntryHeader = packed struct {
    /// Byte offset of filename in global string table.
    FileNameOffset: u32,

    /// Number of bytes of checksum.
    ChecksumSize: u8,

    /// FileChecksumKind
    ChecksumKind: u8,
};

pub const DebugSubsectionKind = enum(u32) {
    None = 0,
    Symbols = 0xf1,
    Lines = 0xf2,
    StringTable = 0xf3,
    FileChecksums = 0xf4,
    FrameData = 0xf5,
    InlineeLines = 0xf6,
    CrossScopeImports = 0xf7,
    CrossScopeExports = 0xf8,

    // These appear to relate to .Net assembly info.
    ILLines = 0xf9,
    FuncMDTokenMap = 0xfa,
    TypeMDTokenMap = 0xfb,
    MergedAssemblyInput = 0xfc,

    CoffSymbolRVA = 0xfd,
};

pub const DebugSubsectionHeader = packed struct {
    /// codeview::DebugSubsectionKind enum
    Kind: DebugSubsectionKind,

    /// number of bytes occupied by this record.
    Length: u32,
};

pub const PDBStringTableHeader = packed struct {
    /// PDBStringTableSignature
    Signature: u32,

    /// 1 or 2
    HashVersion: u32,

    /// Number of bytes of names buffer.
    ByteSize: u32,
};

fn readSparseBitVector(stream: anytype, allocator: *mem.Allocator) ![]u32 {
    const num_words = try stream.readIntLittle(u32);
    var list = ArrayList(u32).init(allocator);
    errdefer list.deinit();
    var word_i: u32 = 0;
    while (word_i != num_words) : (word_i += 1) {
        const word = try stream.readIntLittle(u32);
        var bit_i: u5 = 0;
        while (true) : (bit_i += 1) {
            if (word & (@as(u32, 1) << bit_i) != 0) {
                try list.append(word_i * 32 + bit_i);
            }
            if (bit_i == std.math.maxInt(u5)) break;
        }
    }
    return list.toOwnedSlice();
}

pub const Pdb = struct {
    in_file: File,
    msf: Msf,
    allocator: *mem.Allocator,
    string_table: ?*MsfStream,
    dbi: ?*MsfStream,
    modules: []Module,
    sect_contribs: []SectionContribEntry,
    guid: [16]u8,
    age: u32,

    pub const Module = struct {
        mod_info: ModInfo,
        module_name: []u8,
        obj_file_name: []u8,
        // The fields below are filled on demand.
        populated: bool,
        symbols: []u8,
        subsect_info: []u8,
        checksum_offset: ?usize,
    };

    pub fn init(allocator: *mem.Allocator, path: []const u8) !Pdb {
        const file = try fs.cwd().openFile(path, .{ .intended_io_mode = .blocking });
        errdefer file.close();

        return Pdb{
            .in_file = file,
            .allocator = allocator,
            .string_table = null,
            .dbi = null,
            .msf = try Msf.init(allocator, file),
            .modules = &[_]Module{},
            .sect_contribs = &[_]SectionContribEntry{},
            .guid = undefined,
            .age = undefined,
        };
    }

    pub fn deinit(self: *Pdb) void {
        self.in_file.close();
        self.allocator.free(self.modules);
        self.allocator.free(self.sect_contribs);
    }

    pub fn parseDbiStream(self: *Pdb) !void {
        var stream = self.getStream(StreamType.Dbi) orelse
            return error.InvalidDebugInfo;
        const reader = stream.reader();

        const header = try reader.readStruct(DbiStreamHeader);
        if (header.VersionHeader != 19990903) // V70, only value observed by LLVM team
            return error.UnknownPDBVersion;
        // if (header.Age != age)
        //     return error.UnmatchingPDB;

        const mod_info_size = header.ModInfoSize;
        const section_contrib_size = header.SectionContributionSize;

        var modules = ArrayList(Module).init(self.allocator);
        errdefer modules.deinit();

        // Module Info Substream
        var mod_info_offset: usize = 0;
        while (mod_info_offset != mod_info_size) {
            const mod_info = try reader.readStruct(ModInfo);
            var this_record_len: usize = @sizeOf(ModInfo);

            const module_name = try reader.readUntilDelimiterAlloc(self.allocator, 0, 1024);
            errdefer self.allocator.free(module_name);
            this_record_len += module_name.len + 1;

            const obj_file_name = try reader.readUntilDelimiterAlloc(self.allocator, 0, 1024);
            errdefer self.allocator.free(obj_file_name);
            this_record_len += obj_file_name.len + 1;

            if (this_record_len % 4 != 0) {
                const round_to_next_4 = (this_record_len | 0x3) + 1;
                const march_forward_bytes = round_to_next_4 - this_record_len;
                try stream.seekBy(@intCast(isize, march_forward_bytes));
                this_record_len += march_forward_bytes;
            }

            try modules.append(Module{
                .mod_info = mod_info,
                .module_name = module_name,
                .obj_file_name = obj_file_name,

                .populated = false,
                .symbols = undefined,
                .subsect_info = undefined,
                .checksum_offset = null,
            });

            mod_info_offset += this_record_len;
            if (mod_info_offset > mod_info_size)
                return error.InvalidDebugInfo;
        }

        // Section Contribution Substream
        var sect_contribs = ArrayList(SectionContribEntry).init(self.allocator);
        errdefer sect_contribs.deinit();

        var sect_cont_offset: usize = 0;
        if (section_contrib_size != 0) {
            const version = reader.readEnum(SectionContrSubstreamVersion, .Little) catch |err| switch (err) {
                error.InvalidValue => return error.InvalidDebugInfo,
                else => |e| return e,
            };
            sect_cont_offset += @sizeOf(u32);
        }
        while (sect_cont_offset != section_contrib_size) {
            const entry = try sect_contribs.addOne();
            entry.* = try reader.readStruct(SectionContribEntry);
            sect_cont_offset += @sizeOf(SectionContribEntry);

            if (sect_cont_offset > section_contrib_size)
                return error.InvalidDebugInfo;
        }

        self.modules = modules.toOwnedSlice();
        self.sect_contribs = sect_contribs.toOwnedSlice();
    }

    pub fn parseInfoStream(self: *Pdb) !void {
        var stream = self.getStream(StreamType.Pdb) orelse
            return error.InvalidDebugInfo;
        const reader = stream.reader();

        // Parse the InfoStreamHeader.
        const version = try reader.readIntLittle(u32);
        const signature = try reader.readIntLittle(u32);
        const age = try reader.readIntLittle(u32);
        const guid = try reader.readBytesNoEof(16);

        if (version != 20000404) // VC70, only value observed by LLVM team
            return error.UnknownPDBVersion;

        self.guid = guid;
        self.age = age;

        // Find the string table.
        const string_table_index = str_tab_index: {
            const name_bytes_len = try reader.readIntLittle(u32);
            const name_bytes = try self.allocator.alloc(u8, name_bytes_len);
            defer self.allocator.free(name_bytes);
            try reader.readNoEof(name_bytes);

            const HashTableHeader = extern struct {
                Size: u32,
                Capacity: u32,

                fn maxLoad(cap: u32) u32 {
                    return cap * 2 / 3 + 1;
                }
            };
            const hash_tbl_hdr = try reader.readStruct(HashTableHeader);
            if (hash_tbl_hdr.Capacity == 0)
                return error.InvalidDebugInfo;

            if (hash_tbl_hdr.Size > HashTableHeader.maxLoad(hash_tbl_hdr.Capacity))
                return error.InvalidDebugInfo;

            const present = try readSparseBitVector(&reader, self.allocator);
            defer self.allocator.free(present);
            if (present.len != hash_tbl_hdr.Size)
                return error.InvalidDebugInfo;
            const deleted = try readSparseBitVector(&reader, self.allocator);
            defer self.allocator.free(deleted);

            for (present) |_| {
                const name_offset = try reader.readIntLittle(u32);
                const name_index = try reader.readIntLittle(u32);
                if (name_offset > name_bytes.len)
                    return error.InvalidDebugInfo;
                const name = mem.spanZ(std.meta.assumeSentinel(name_bytes.ptr + name_offset, 0));
                if (mem.eql(u8, name, "/names")) {
                    break :str_tab_index name_index;
                }
            }
            return error.MissingDebugInfo;
        };

        self.string_table = self.getStreamById(string_table_index) orelse
            return error.MissingDebugInfo;
    }

    pub fn getSymbolName(self: *Pdb, module: *Module, address: u64) ?[]const u8 {
        std.debug.assert(module.populated);

        var symbol_i: usize = 0;
        while (symbol_i != module.symbols.len) {
            const prefix = @ptrCast(*RecordPrefix, &module.symbols[symbol_i]);
            if (prefix.RecordLen < 2)
                return null;
            switch (prefix.RecordKind) {
                .S_LPROC32, .S_GPROC32 => {
                    const proc_sym = @ptrCast(*ProcSym, &module.symbols[symbol_i + @sizeOf(RecordPrefix)]);
                    if (address >= proc_sym.CodeOffset and address < proc_sym.CodeOffset + proc_sym.CodeSize) {
                        return mem.spanZ(@ptrCast([*:0]u8, proc_sym) + @sizeOf(ProcSym));
                    }
                },
                else => {},
            }
            symbol_i += prefix.RecordLen + @sizeOf(u16);
        }

        return null;
    }

    pub fn getLineNumberInfo(self: *Pdb, module: *Module, address: u64) !debug.LineInfo {
        std.debug.assert(module.populated);
        const subsect_info = module.subsect_info;

        var sect_offset: usize = 0;
        var skip_len: usize = undefined;
        const checksum_offset = module.checksum_offset orelse return error.MissingDebugInfo;
        while (sect_offset != subsect_info.len) : (sect_offset += skip_len) {
            const subsect_hdr = @ptrCast(*DebugSubsectionHeader, &subsect_info[sect_offset]);
            skip_len = subsect_hdr.Length;
            sect_offset += @sizeOf(DebugSubsectionHeader);

            switch (subsect_hdr.Kind) {
                .Lines => {
                    var line_index = sect_offset;

                    const line_hdr = @ptrCast(*LineFragmentHeader, &subsect_info[line_index]);
                    if (line_hdr.RelocSegment == 0)
                        return error.MissingDebugInfo;
                    line_index += @sizeOf(LineFragmentHeader);
                    const frag_vaddr_start = line_hdr.RelocOffset;
                    const frag_vaddr_end = frag_vaddr_start + line_hdr.CodeSize;

                    if (address >= frag_vaddr_start and address < frag_vaddr_end) {
                        // There is an unknown number of LineBlockFragmentHeaders (and their accompanying line and column records)
                        // from now on. We will iterate through them, and eventually find a LineInfo that we're interested in,
                        // breaking out to :subsections. If not, we will make sure to not read anything outside of this subsection.
                        const subsection_end_index = sect_offset + subsect_hdr.Length;

                        while (line_index < subsection_end_index) {
                            const block_hdr = @ptrCast(*LineBlockFragmentHeader, &subsect_info[line_index]);
                            line_index += @sizeOf(LineBlockFragmentHeader);
                            const start_line_index = line_index;

                            const has_column = line_hdr.Flags.LF_HaveColumns;

                            // All line entries are stored inside their line block by ascending start address.
                            // Heuristic: we want to find the last line entry
                            // that has a vaddr_start <= address.
                            // This is done with a simple linear search.
                            var line_i: u32 = 0;
                            while (line_i < block_hdr.NumLines) : (line_i += 1) {
                                const line_num_entry = @ptrCast(*LineNumberEntry, &subsect_info[line_index]);
                                line_index += @sizeOf(LineNumberEntry);

                                const vaddr_start = frag_vaddr_start + line_num_entry.Offset;
                                if (address < vaddr_start) {
                                    break;
                                }
                            }

                            // line_i == 0 would mean that no matching LineNumberEntry was found.
                            if (line_i > 0) {
                                const subsect_index = checksum_offset + block_hdr.NameIndex;
                                const chksum_hdr = @ptrCast(*FileChecksumEntryHeader, &module.subsect_info[subsect_index]);
                                const strtab_offset = @sizeOf(PDBStringTableHeader) + chksum_hdr.FileNameOffset;
                                try self.string_table.?.seekTo(strtab_offset);
                                const source_file_name = try self.string_table.?.reader().readUntilDelimiterAlloc(self.allocator, 0, 1024);

                                const line_entry_idx = line_i - 1;

                                const column = if (has_column) blk: {
                                    const start_col_index = start_line_index + @sizeOf(LineNumberEntry) * block_hdr.NumLines;
                                    const col_index = start_col_index + @sizeOf(ColumnNumberEntry) * line_entry_idx;
                                    const col_num_entry = @ptrCast(*ColumnNumberEntry, &subsect_info[col_index]);
                                    break :blk col_num_entry.StartColumn;
                                } else 0;

                                const found_line_index = start_line_index + line_entry_idx * @sizeOf(LineNumberEntry);
                                const line_num_entry = @ptrCast(*LineNumberEntry, &subsect_info[found_line_index]);
                                const flags = @ptrCast(*LineNumberEntry.Flags, &line_num_entry.Flags);

                                return debug.LineInfo{
                                    .allocator = self.allocator,
                                    .file_name = source_file_name,
                                    .line = flags.Start,
                                    .column = column,
                                };
                            }
                        }

                        // Checking that we are not reading garbage after the (possibly) multiple block fragments.
                        if (line_index != subsection_end_index) {
                            return error.InvalidDebugInfo;
                        }
                    }
                },
                else => {},
            }

            if (sect_offset > subsect_info.len)
                return error.InvalidDebugInfo;
        }

        return error.MissingDebugInfo;
    }

    pub fn getModule(self: *Pdb, index: usize) !?*Module {
        if (index >= self.modules.len)
            return null;

        const mod = &self.modules[index];
        if (mod.populated)
            return mod;

        // At most one can be non-zero.
        if (mod.mod_info.C11ByteSize != 0 and mod.mod_info.C13ByteSize != 0)
            return error.InvalidDebugInfo;
        if (mod.mod_info.C13ByteSize == 0)
            return error.InvalidDebugInfo;

        const stream = self.getStreamById(mod.mod_info.ModuleSymStream) orelse
            return error.MissingDebugInfo;
        const reader = stream.reader();

        const signature = try reader.readIntLittle(u32);
        if (signature != 4)
            return error.InvalidDebugInfo;

        mod.symbols = try self.allocator.alloc(u8, mod.mod_info.SymByteSize - 4);
        errdefer self.allocator.free(mod.symbols);
        try reader.readNoEof(mod.symbols);

        mod.subsect_info = try self.allocator.alloc(u8, mod.mod_info.C13ByteSize);
        errdefer self.allocator.free(mod.subsect_info);
        try reader.readNoEof(mod.subsect_info);

        var sect_offset: usize = 0;
        var skip_len: usize = undefined;
        while (sect_offset != mod.subsect_info.len) : (sect_offset += skip_len) {
            const subsect_hdr = @ptrCast(*DebugSubsectionHeader, &mod.subsect_info[sect_offset]);
            skip_len = subsect_hdr.Length;
            sect_offset += @sizeOf(DebugSubsectionHeader);

            switch (subsect_hdr.Kind) {
                .FileChecksums => {
                    mod.checksum_offset = sect_offset;
                    break;
                },
                else => {},
            }

            if (sect_offset > mod.subsect_info.len)
                return error.InvalidDebugInfo;
        }

        mod.populated = true;
        return mod;
    }

    pub fn getStreamById(self: *Pdb, id: u32) ?*MsfStream {
        if (id >= self.msf.streams.len)
            return null;
        return &self.msf.streams[id];
    }

    pub fn getStream(self: *Pdb, stream: StreamType) ?*MsfStream {
        const id = @enumToInt(stream);
        return self.getStreamById(id);
    }
};

// see https://llvm.org/docs/PDB/MsfFile.html
const Msf = struct {
    directory: MsfStream,
    streams: []MsfStream,

    fn init(allocator: *mem.Allocator, file: File) !Msf {
        const in = file.reader();

        const superblock = try in.readStruct(SuperBlock);

        // Sanity checks
        if (!mem.eql(u8, &superblock.FileMagic, SuperBlock.file_magic))
            return error.InvalidDebugInfo;
        if (superblock.FreeBlockMapBlock != 1 and superblock.FreeBlockMapBlock != 2)
            return error.InvalidDebugInfo;
        if (superblock.NumBlocks * superblock.BlockSize != try file.getEndPos())
            return error.InvalidDebugInfo;
        switch (superblock.BlockSize) {
            // llvm only supports 4096 but we can handle any of these values
            512, 1024, 2048, 4096 => {},
            else => return error.InvalidDebugInfo,
        }

        const dir_block_count = blockCountFromSize(superblock.NumDirectoryBytes, superblock.BlockSize);
        if (dir_block_count > superblock.BlockSize / @sizeOf(u32))
            return error.UnhandledBigDirectoryStream; // cf. BlockMapAddr comment.

        try file.seekTo(superblock.BlockSize * superblock.BlockMapAddr);
        var dir_blocks = try allocator.alloc(u32, dir_block_count);
        for (dir_blocks) |*b| {
            b.* = try in.readIntLittle(u32);
        }
        var directory = MsfStream.init(
            superblock.BlockSize,
            file,
            dir_blocks,
        );

        const begin = directory.pos;
        const stream_count = try directory.reader().readIntLittle(u32);
        const stream_sizes = try allocator.alloc(u32, stream_count);
        defer allocator.free(stream_sizes);

        // Microsoft's implementation uses @as(u32, -1) for inexistant streams.
        // These streams are not used, but still participate in the file
        // and must be taken into account when resolving stream indices.
        const Nil = 0xFFFFFFFF;
        for (stream_sizes) |*s, i| {
            const size = try directory.reader().readIntLittle(u32);
            s.* = if (size == Nil) 0 else blockCountFromSize(size, superblock.BlockSize);
        }

        const streams = try allocator.alloc(MsfStream, stream_count);
        for (streams) |*stream, i| {
            const size = stream_sizes[i];
            if (size == 0) {
                stream.* = MsfStream{
                    .blocks = &[_]u32{},
                };
            } else {
                var blocks = try allocator.alloc(u32, size);
                var j: u32 = 0;
                while (j < size) : (j += 1) {
                    const block_id = try directory.reader().readIntLittle(u32);
                    const n = (block_id % superblock.BlockSize);
                    // 0 is for SuperBlock, 1 and 2 for FPMs.
                    if (block_id == 0 or n == 1 or n == 2 or block_id * superblock.BlockSize > try file.getEndPos())
                        return error.InvalidBlockIndex;
                    blocks[j] = block_id;
                }

                stream.* = MsfStream.init(
                    superblock.BlockSize,
                    file,
                    blocks,
                );
            }
        }

        const end = directory.pos;
        if (end - begin != superblock.NumDirectoryBytes)
            return error.InvalidStreamDirectory;

        return Msf{
            .directory = directory,
            .streams = streams,
        };
    }
};

fn blockCountFromSize(size: u32, block_size: u32) u32 {
    return (size + block_size - 1) / block_size;
}

// https://llvm.org/docs/PDB/MsfFile.html#the-superblock
const SuperBlock = packed struct {
    /// The LLVM docs list a space between C / C++ but empirically this is not the case.
    const file_magic = "Microsoft C/C++ MSF 7.00\r\n\x1a\x44\x53\x00\x00\x00";

    FileMagic: [file_magic.len]u8,

    /// The block size of the internal file system. Valid values are 512, 1024,
    /// 2048, and 4096 bytes. Certain aspects of the MSF file layout vary depending
    /// on the block sizes. For the purposes of LLVM, we handle only block sizes of
    /// 4KiB, and all further discussion assumes a block size of 4KiB.
    BlockSize: u32,

    /// The index of a block within the file, at which begins a bitfield representing
    /// the set of all blocks within the file which are “free” (i.e. the data within
    /// that block is not used). See The Free Block Map for more information. Important:
    /// FreeBlockMapBlock can only be 1 or 2!
    FreeBlockMapBlock: u32,

    /// The total number of blocks in the file. NumBlocks * BlockSize should equal the
    /// size of the file on disk.
    NumBlocks: u32,

    /// The size of the stream directory, in bytes. The stream directory contains
    /// information about each stream’s size and the set of blocks that it occupies.
    /// It will be described in more detail later.
    NumDirectoryBytes: u32,

    Unknown: u32,
    /// The index of a block within the MSF file. At this block is an array of
    /// ulittle32_t’s listing the blocks that the stream directory resides on.
    /// For large MSF files, the stream directory (which describes the block
    /// layout of each stream) may not fit entirely on a single block. As a
    /// result, this extra layer of indirection is introduced, whereby this
    /// block contains the list of blocks that the stream directory occupies,
    /// and the stream directory itself can be stitched together accordingly.
    /// The number of ulittle32_t’s in this array is given by
    /// ceil(NumDirectoryBytes / BlockSize).
    // Note: microsoft-pdb code actually suggests this is a variable-length
    // array. If the indices of blocks occupied by the Stream Directory didn't
    // fit in one page, there would be other u32 following it.
    // This would mean the Stream Directory is bigger than BlockSize / sizeof(u32)
    // blocks. We're not even close to this with a 1GB pdb file, and LLVM didn't
    // implement it so we're kind of safe making this assumption for now.
    BlockMapAddr: u32,
};

const MsfStream = struct {
    in_file: File = undefined,
    pos: u64 = undefined,
    blocks: []u32 = undefined,
    block_size: u32 = undefined,

    pub const Error = @typeInfo(@typeInfo(@TypeOf(read)).Fn.return_type.?).ErrorUnion.error_set;

    fn init(block_size: u32, file: File, blocks: []u32) MsfStream {
        const stream = MsfStream{
            .in_file = file,
            .pos = 0,
            .blocks = blocks,
            .block_size = block_size,
        };

        return stream;
    }

    fn read(self: *MsfStream, buffer: []u8) !usize {
        var block_id = @intCast(usize, self.pos / self.block_size);
        if (block_id >= self.blocks.len) return 0; // End of Stream
        var block = self.blocks[block_id];
        var offset = self.pos % self.block_size;

        try self.in_file.seekTo(block * self.block_size + offset);
        const in = self.in_file.reader();

        var size: usize = 0;
        var rem_buffer = buffer;
        while (size < buffer.len) {
            const size_to_read = math.min(self.block_size - offset, rem_buffer.len);
            size += try in.read(rem_buffer[0..size_to_read]);
            rem_buffer = buffer[size..];
            offset += size_to_read;

            // If we're at the end of a block, go to the next one.
            if (offset == self.block_size) {
                offset = 0;
                block_id += 1;
                if (block_id >= self.blocks.len) break; // End of Stream
                block = self.blocks[block_id];
                try self.in_file.seekTo(block * self.block_size);
            }
        }

        self.pos += buffer.len;
        return buffer.len;
    }

    pub fn seekBy(self: *MsfStream, len: i64) !void {
        self.pos = @intCast(u64, @intCast(i64, self.pos) + len);
        if (self.pos >= self.blocks.len * self.block_size)
            return error.EOF;
    }

    pub fn seekTo(self: *MsfStream, len: u64) !void {
        self.pos = len;
        if (self.pos >= self.blocks.len * self.block_size)
            return error.EOF;
    }

    fn getSize(self: *const MsfStream) u64 {
        return self.blocks.len * self.block_size;
    }

    fn getFilePos(self: MsfStream) u64 {
        const block_id = self.pos / self.block_size;
        const block = self.blocks[block_id];
        const offset = self.pos % self.block_size;

        return block * self.block_size + offset;
    }

    pub fn reader(self: *MsfStream) std.io.Reader(*MsfStream, Error, read) {
        return .{ .context = self };
    }
};

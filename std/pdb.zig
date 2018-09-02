const builtin = @import("builtin");
const std = @import("index.zig");
const io = std.io;
const math = std.math;
const mem = std.mem;
const os = std.os;
const warn = std.debug.warn;
const coff = std.coff;

const ArrayList = std.ArrayList;

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
  Count: u16,    /// Number of segment descriptors
  LogCount: u16, /// Number of logical segment descriptors
};

pub const SectionMapEntry = packed struct {
  Flags: u16 ,         /// See the SectionMapEntryFlags enum below.
  Ovl: u16 ,           /// Logical overlay number
  Group: u16 ,         /// Group index into descriptor array.
  Frame: u16 ,
  SectionName: u16 ,   /// Byte index of segment / group name in string table, or 0xFFFF.
  ClassName: u16 ,     /// Byte index of class in string table, or 0xFFFF.
  Offset: u32 ,        /// Byte offset of the logical segment within physical segment.  If group is set in flags, this is the offset of the group.
  SectionLength: u32 , /// Byte count of the segment or group.
};

pub const StreamType = enum(u16) {
    Pdb = 1,
    Tpi = 2,
    Dbi = 3,
    Ipi = 4,
};

/// Duplicate copy of SymbolRecordKind, but using the official CV names. Useful
/// for reference purposes and when dealing with unknown record types.
pub const SymbolKind = packed enum(u16) {
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
    Parent: u32 ,
    End: u32 ,
    Next: u32 ,
    CodeSize: u32 ,
    DbgStart: u32 ,
    DbgEnd: u32 ,
    FunctionType: TypeIndex ,
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

pub const SectionContrSubstreamVersion  = enum(u32) {
  Ver60 = 0xeffe0000 + 19970605,
  V2 = 0xeffe0000 + 20140516
};

pub const RecordPrefix = packed struct {
    RecordLen: u16, /// Record length, starting from &RecordKind.
    RecordKind: SymbolKind, /// Record kind enum (SymRecordKind or TypeRecordKind)
};

pub const LineFragmentHeader = packed struct {
    RelocOffset: u32, /// Code offset of line contribution.
    RelocSegment: u16, /// Code segment of line contribution.
    Flags: LineFlags,
    CodeSize: u32, /// Code size of this line contribution.
};

pub const LineFlags = packed struct {
    LF_HaveColumns: bool, /// CV_LINES_HAVE_COLUMNS
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
    BlockSize: u32, /// code size of block, in bytes
};


pub const LineNumberEntry = packed struct {
    Offset: u32, /// Offset to start of code bytes for line number
    Flags: u32,

    /// TODO runtime crash when I make the actual type of Flags this
    const Flags = packed struct {
        Start: u24,
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
    FileNameOffset: u32, /// Byte offset of filename in global string table.
    ChecksumSize: u8, /// Number of bytes of checksum.
    ChecksumKind: u8, /// FileChecksumKind
};

pub const DebugSubsectionKind = packed enum(u32) {
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
    Kind: DebugSubsectionKind, /// codeview::DebugSubsectionKind enum
    Length: u32, /// number of bytes occupied by this record.
};


pub const PDBStringTableHeader = packed struct {
    Signature: u32, /// PDBStringTableSignature
    HashVersion: u32, /// 1 or 2
    ByteSize: u32, /// Number of bytes of names buffer.
};

pub const Pdb = struct {
    in_file: os.File,
    allocator: *mem.Allocator,
    coff: *coff.Coff,
    string_table: *MsfStream,
    dbi: *MsfStream,

    msf: Msf,

    pub fn openFile(self: *Pdb, coff_ptr: *coff.Coff, file_name: []u8) !void {
        self.in_file = try os.File.openRead(file_name);
        self.allocator = coff_ptr.allocator;
        self.coff = coff_ptr;

        try self.msf.openFile(self.allocator, self.in_file);
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

    fn openFile(self: *Msf, allocator: *mem.Allocator, file: os.File) !void {
        var file_stream = io.FileInStream.init(file);
        const in = &file_stream.stream;

        var superblock: SuperBlock = undefined;
        try in.readStruct(SuperBlock, &superblock);

        if (!mem.eql(u8, superblock.FileMagic, SuperBlock.file_magic))
            return error.InvalidDebugInfo;

        switch (superblock.BlockSize) {
            // llvm only supports 4096 but we can handle any of these values
            512, 1024, 2048, 4096 => {},
            else => return error.InvalidDebugInfo
        }

        if (superblock.NumBlocks * superblock.BlockSize != try file.getEndPos())
            return error.InvalidDebugInfo;

        self.directory = try MsfStream.init(
            superblock.BlockSize,
            blockCountFromSize(superblock.NumDirectoryBytes, superblock.BlockSize),
            superblock.BlockSize * superblock.BlockMapAddr,
            file,
            allocator,
        );

        const stream_count = try self.directory.stream.readIntLe(u32);

        const stream_sizes = try allocator.alloc(u32, stream_count);
        for (stream_sizes) |*s| {
            const size = try self.directory.stream.readIntLe(u32);
            s.* = blockCountFromSize(size, superblock.BlockSize);
        }

        self.streams = try allocator.alloc(MsfStream, stream_count);
        for (self.streams) |*stream, i| {
            stream.* = try MsfStream.init(
                superblock.BlockSize,
                stream_sizes[i],
                // MsfStream.init expects the file to be at the part where it reads [N]u32
                try file.getPos(),
                file,
                allocator,
            );
        }
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
    BlockMapAddr: u32,

};

const MsfStream = struct {
    in_file: os.File,
    pos: usize,
    blocks: []u32,
    block_size: u32,

    /// Implementation of InStream trait for Pdb.MsfStream
    stream: Stream,

    pub const Error = @typeOf(read).ReturnType.ErrorSet;
    pub const Stream = io.InStream(Error);

    fn init(block_size: u32, block_count: u32, pos: usize, file: os.File, allocator: *mem.Allocator) !MsfStream {
        var stream = MsfStream {
            .in_file = file,
            .pos = 0,
            .blocks = try allocator.alloc(u32, block_count),
            .block_size = block_size,
            .stream = Stream {
                .readFn = readFn,
            },
        };

        var file_stream = io.FileInStream.init(file);
        const in = &file_stream.stream;
        try file.seekTo(pos);

        var i: u32 = 0;
        while (i < block_count) : (i += 1) {
            stream.blocks[i] = try in.readIntLe(u32);
        }

        return stream;
    }

    fn readNullTermString(self: *MsfStream, allocator: *mem.Allocator) ![]u8 {
        var list = ArrayList(u8).init(allocator);
        defer list.deinit();
        while (true) {
            const byte = try self.stream.readByte();
            if (byte == 0) {
                return list.toSlice();
            }
            try list.append(byte);
        }
    }

    fn read(self: *MsfStream, buffer: []u8) !usize {
        var block_id = self.pos / self.block_size;
        var block = self.blocks[block_id];
        var offset = self.pos % self.block_size;

        try self.in_file.seekTo(block * self.block_size + offset);
        var file_stream = io.FileInStream.init(self.in_file);
        const in = &file_stream.stream;

        var size: usize = 0;
        for (buffer) |*byte| {
            byte.* = try in.readByte();           

            offset += 1;
            size += 1;

            // If we're at the end of a block, go to the next one.
            if (offset == self.block_size) {
                offset = 0;
                block_id += 1;
                block = self.blocks[block_id];
                try self.in_file.seekTo(block * self.block_size);
            }
        }

        self.pos += size;
        return size;
    }

    fn seekForward(self: *MsfStream, len: usize) !void {
        self.pos += len;
        if (self.pos >= self.blocks.len * self.block_size)
            return error.EOF;
    }

    fn seekTo(self: *MsfStream, len: usize) !void {
        self.pos = len;
        if (self.pos >= self.blocks.len * self.block_size)
            return error.EOF;
    }

    fn getSize(self: *const MsfStream) usize {
        return self.blocks.len * self.block_size;
    }

    fn getFilePos(self: MsfStream) usize {
        const block_id = self.pos / self.block_size;
        const block = self.blocks[block_id];
        const offset = self.pos % self.block_size;

        return block * self.block_size + offset;
    }

    fn readFn(in_stream: *Stream, buffer: []u8) Error!usize {
        const self = @fieldParentPtr(MsfStream, "stream", in_stream);
        return self.read(buffer);
    }
};

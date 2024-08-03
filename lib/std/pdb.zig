//! Program Data Base debugging information format.
//!
//! This namespace contains unopinionated types and data definitions only. For
//! an implementation of parsing and caching PDB information, see
//! `std.debug.Pdb`.
//!
//! Most of this is based on information gathered from LLVM source code,
//! documentation and/or contributors.

const std = @import("std.zig");
const io = std.io;
const math = std.math;
const mem = std.mem;
const coff = std.coff;
const fs = std.fs;
const File = std.fs.File;
const debug = std.debug;

const ArrayList = std.ArrayList;

/// https://llvm.org/docs/PDB/DbiStream.html#stream-header
pub const DbiStreamHeader = extern struct {
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

pub const SectionContribEntry = extern struct {
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

pub const ModInfo = extern struct {
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

pub const SectionMapHeader = extern struct {
    /// Number of segment descriptors
    Count: u16,

    /// Number of logical segment descriptors
    LogCount: u16,
};

pub const SectionMapEntry = extern struct {
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

// TODO According to this header:
// https://github.com/microsoft/microsoft-pdb/blob/082c5290e5aff028ae84e43affa8be717aa7af73/include/cvinfo.h#L3722
// we should define RecordPrefix as part of the ProcSym structure.
// This might be important when we start generating PDB in self-hosted with our own PE linker.
pub const ProcSym = extern struct {
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
    Name: [1]u8, // null-terminated
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

pub const RecordPrefix = extern struct {
    /// Record length, starting from &RecordKind.
    RecordLen: u16,

    /// Record kind enum (SymRecordKind or TypeRecordKind)
    RecordKind: SymbolKind,
};

/// The following variable length array appears immediately after the header.
/// The structure definition follows.
/// LineBlockFragmentHeader Blocks[]
/// Each `LineBlockFragmentHeader` as specified below.
pub const LineFragmentHeader = extern struct {
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
pub const LineBlockFragmentHeader = extern struct {
    /// Offset of FileChecksum entry in File
    /// checksums buffer.  The checksum entry then
    /// contains another offset into the string
    /// table of the actual name.
    NameIndex: u32,
    NumLines: u32,

    /// code size of block, in bytes
    BlockSize: u32,
};

pub const LineNumberEntry = extern struct {
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

pub const ColumnNumberEntry = extern struct {
    StartColumn: u16,
    EndColumn: u16,
};

/// Checksum bytes follow.
pub const FileChecksumEntryHeader = extern struct {
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

pub const DebugSubsectionHeader = extern struct {
    /// codeview::DebugSubsectionKind enum
    Kind: DebugSubsectionKind,

    /// number of bytes occupied by this record.
    Length: u32,
};

pub const StringTableHeader = extern struct {
    /// PDBStringTableSignature
    Signature: u32,
    /// 1 or 2
    HashVersion: u32,
    /// Number of bytes of names buffer.
    ByteSize: u32,
};

// https://llvm.org/docs/PDB/MsfFile.html#the-superblock
pub const SuperBlock = extern struct {
    /// The LLVM docs list a space between C / C++ but empirically this is not the case.
    pub const file_magic = "Microsoft C/C++ MSF 7.00\r\n\x1a\x44\x53\x00\x00\x00";

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

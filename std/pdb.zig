const builtin = @import("builtin");
const std = @import("index.zig");
const io = std.io;
const math = std.math;
const mem = std.mem;
const os = std.os;
const warn = std.debug.warn;

const ArrayList = std.ArrayList;

// https://llvm.org/docs/PDB/DbiStream.html#stream-header
const DbiStreamHeader = packed struct {
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
    SectionContributionSize: i32,
    SectionMapSize: i32,
    SourceInfoSize: i32,
    TypeServerSize: i32,
    MFCTypeServerIndex: u32,
    OptionalDbgHeaderSize: i32,
    ECSubstreamSize: i32,
    Flags: u16,
    Machine: u16,
    Padding: u32,
};

const SectionContribEntry = packed struct {
    Section: u16,
    Padding1: [2]u8,
    Offset: i32,
    Size: i32,
    Characteristics: u32,
    ModuleIndex: u16,
    Padding2: [2]u8,
    DataCrc: u32,
    RelocCrc: u32,
};

const ModInfo = packed struct {
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

pub const StreamType = enum(u16) {
    Pdb = 1,
    Tpi = 2,
    Dbi = 3,
    Ipi = 4,
};

pub const Pdb = struct {
    in_file: os.File,
    allocator: *mem.Allocator,

    msf: Msf,

    pub fn openFile(self: *Pdb, allocator: *mem.Allocator, file_name: []u8) !void {
        self.in_file = try os.File.openRead(file_name);
        self.allocator = allocator;

        try self.msf.openFile(allocator, self.in_file);
    }

    pub fn getStream(self: *Pdb, stream: StreamType) ?*MsfStream {
        const id = @enumToInt(stream);
        if (id < self.msf.streams.len)
            return &self.msf.streams[id];
        return null;
    }

    pub fn getSourceLine(self: *Pdb, address: usize) !void {
        const dbi = self.getStream(StreamType.Dbi) orelse return error.InvalidDebugInfo;

        // Dbi Header
        var header: DbiStreamHeader = undefined;
        try dbi.stream.readStruct(DbiStreamHeader, &header);
        std.debug.warn("{}\n", header);
        warn("after header dbi stream at {} (file offset)\n", dbi.getFilePos());

        // Module Info Substream
        var mod_info_offset: usize = 0;
        while (mod_info_offset < header.ModInfoSize) {
            const march_forward_bytes = dbi.getFilePos() % 4;
            if (march_forward_bytes != 0) {
                try dbi.seekForward(march_forward_bytes);
                mod_info_offset += march_forward_bytes;
            }
            var mod_info: ModInfo = undefined;
            try dbi.stream.readStruct(ModInfo, &mod_info);
            std.debug.warn("{}\n", mod_info);
            mod_info_offset += @sizeOf(ModInfo);

            const module_name = try dbi.readNullTermString(self.allocator);
            std.debug.warn("module_name '{}'\n", module_name);
            mod_info_offset += module_name.len + 1;

            //if (mem.eql(u8, module_name, "piler_rt.obj")) {
            //    std.debug.warn("detected bad thing\n");
            //    try dbi.seekTo(dbi.pos -
            //        "c:\\msys64\\home\\andy\\zig\\build-llvm6-msvc-release\\.\\zig-cache\\compiler_rt.obj\x00".len -
            //        @sizeOf(ModInfo));
            //    mod_info_offset -= module_name.len + 1;
            //    continue;
            //}

            const obj_file_name = try dbi.readNullTermString(self.allocator);
            std.debug.warn("obj_file_name '{}'\n", obj_file_name);
            mod_info_offset += obj_file_name.len + 1;
        }
        std.debug.warn("end modules\n");


        // TODO: locate corresponding source line information
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
        warn("stream count {}\n", stream_count);

        const stream_sizes = try allocator.alloc(u32, stream_count);
        for (stream_sizes) |*s| {
            const size = try self.directory.stream.readIntLe(u32);
            s.* = blockCountFromSize(size, superblock.BlockSize);
            warn("stream {}B {} blocks\n", size, s.*);
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

        warn("stream with blocks");
        var i: u32 = 0;
        while (i < block_count) : (i += 1) {
            stream.blocks[i] = try in.readIntLe(u32);
            warn(" {}", stream.blocks[i]);
        }
        warn("\n");

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

        //std.debug.warn("seek {} read {}B: block_id={} block={} offset={}\n",
        //    block * self.block_size + offset,
        //    buffer.len, block_id, block, offset);

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

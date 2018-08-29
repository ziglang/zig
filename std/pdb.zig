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
        self.in_file = try os.File.openRead(file_name[0..]);
        self.allocator = allocator;

        try self.msf.openFile(allocator, self.in_file);
    }

    pub fn getStream(self: *Pdb, stream: StreamType) ?*MsfStream {
        const id = @enumToInt(stream);
        if (id < self.msf.streams.len)
            return &self.msf.streams.items[id];
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
            var mod_info: ModInfo = undefined;
            try dbi.stream.readStruct(ModInfo, &mod_info);
            std.debug.warn("{}\n", mod_info);
            mod_info_offset += @sizeOf(ModInfo);

            const module_name = try dbi.readNullTermString(self.allocator);
            std.debug.warn("module_name {}\n", module_name);
            mod_info_offset += module_name.len + 1;

            const obj_file_name = try dbi.readNullTermString(self.allocator);
            std.debug.warn("obj_file_name {}\n", obj_file_name);
            mod_info_offset += obj_file_name.len + 1;
        }
        std.debug.warn("end modules\n");


        // TODO: locate corresponding source line information
    }
};

// see https://llvm.org/docs/PDB/MsfFile.html
const Msf = struct {
    superblock: SuperBlock,
    directory: MsfStream,
    streams: ArrayList(MsfStream),

    fn openFile(self: *Msf, allocator: *mem.Allocator, file: os.File) !void {
        var file_stream = io.FileInStream.init(file);
        const in = &file_stream.stream;

        var magic: SuperBlock.FileMagicBuffer = undefined;
        try in.readNoEof(magic[0..]);
        warn("magic: '{}'\n", magic);
        
        if (!mem.eql(u8, magic, SuperBlock.FileMagic))
            return error.InvalidDebugInfo;

        self.superblock = SuperBlock {
            .block_size = try in.readIntLe(u32),
            .free_block_map_block = try in.readIntLe(u32),
            .num_blocks = try in.readIntLe(u32),
            .num_directory_bytes = try in.readIntLe(u32),
            .unknown = try in.readIntLe(u32),
            .block_map_addr = try in.readIntLe(u32),
        };

        switch (self.superblock.block_size) {
            512, 1024, 2048, 4096 => {}, // llvm only uses 4096
            else => return error.InvalidDebugInfo
        }

        if (self.superblock.fileSize() != try file.getEndPos())
            return error.InvalidDebugInfo; // Should always stand.

        self.directory = try MsfStream.init(
            self.superblock.block_size,
            self.superblock.blocksOccupiedByDirectoryStream(),
            self.superblock.blockMapAddr(),
            file,
            allocator
        );

        const stream_count = try self.directory.stream.readIntLe(u32);
        warn("stream count {}\n", stream_count);

        var stream_sizes = ArrayList(u32).init(allocator);
        try stream_sizes.resize(stream_count);
        for (stream_sizes.toSlice()) |*s| {
            const size = try self.directory.stream.readIntLe(u32);
            s.* = blockCountFromSize(size, self.superblock.block_size);
            warn("stream {}B {} blocks\n", size, s.*);
        }

        self.streams = ArrayList(MsfStream).init(allocator);
        try self.streams.resize(stream_count);
        for (self.streams.toSlice()) |*ss, i| {
            ss.* = try MsfStream.init(
                self.superblock.block_size,
                stream_sizes.items[i],
                try file.getPos(), // We're reading the jagged array of block indices when creating streams so the file is always at the right position.
                file,
                allocator
            );
        }
    }
};

fn blockCountFromSize(size: u32, block_size: u32) u32 {
    return (size + block_size - 1) / block_size;
}

const SuperBlock = struct {
    const FileMagic = "Microsoft C/C++ MSF 7.00\r\n" ++ []u8 { 0x1A, 'D', 'S', 0, 0, 0};
    const FileMagicBuffer = @typeOf(FileMagic);

    block_size: u32,
    free_block_map_block: u32,
    num_blocks: u32,
    num_directory_bytes: u32,
    unknown: u32,
    block_map_addr: u32,

    fn fileSize(self: *const SuperBlock) usize {
        return self.num_blocks * self.block_size;
    }

    fn blockMapAddr(self: *const SuperBlock) usize {
        return self.block_size * self.block_map_addr;
    }

    fn blocksOccupiedByDirectoryStream(self: *const SuperBlock) u32 {
        return blockCountFromSize(self.num_directory_bytes, self.block_size);
    }
};

const MsfStream = struct {
    in_file: os.File,
    pos: usize,
    blocks: ArrayList(u32),
    block_size: u32,

    /// Implementation of InStream trait for Pdb.MsfStream
    stream: Stream,

    pub const Error = @typeOf(read).ReturnType.ErrorSet;
    pub const Stream = io.InStream(Error);

    fn init(block_size: u32, block_count: u32, pos: usize, file: os.File, allocator: *mem.Allocator) !MsfStream {
        var stream = MsfStream {
            .in_file = file,
            .pos = 0,
            .blocks = ArrayList(u32).init(allocator),
            .block_size = block_size,
            .stream = Stream {
                .readFn = readFn,
            },
        };

        try stream.blocks.resize(block_count);

        var file_stream = io.FileInStream.init(file);
        const in = &file_stream.stream;
        try file.seekTo(pos);

        warn("stream with blocks");
        var i: u32 = 0;
        while (i < block_count) : (i += 1) {
            stream.blocks.items[i] = try in.readIntLe(u32);
            warn(" {}", stream.blocks.items[i]);
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
        var block = self.blocks.items[block_id];
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
            if (offset == self.block_size)
            {
                offset = 0;
                block_id += 1;
                block = self.blocks.items[block_id];
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

    fn getFilePos(self: *const MsfStream) usize {
        const block_id = self.pos / self.block_size;
        const block = self.blocks.items[block_id];
        const offset = self.pos % self.block_size;

        return block * self.block_size + offset;
    }

    fn readFn(in_stream: *Stream, buffer: []u8) Error!usize {
        const self = @fieldParentPtr(MsfStream, "stream", in_stream);
        return self.read(buffer);
    }
};

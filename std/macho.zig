const builtin = @import("builtin");
const std = @import("index.zig");
const io = std.io;
const mem = std.mem;

const MH_MAGIC_64 = 0xFEEDFACF;
const MH_PIE = 0x200000;
const LC_SYMTAB = 2;

const MachHeader64 = packed struct {
    magic: u32,
    cputype: u32,
    cpusubtype: u32,
    filetype: u32,
    ncmds: u32,
    sizeofcmds: u32,
    flags: u32,
    reserved: u32,
};

const LoadCommand = packed struct {
    cmd: u32,
    cmdsize: u32,
};

const SymtabCommand = packed struct {
    symoff: u32,
    nsyms: u32,
    stroff: u32,
    strsize: u32,
};

const Nlist64 = packed struct {
    n_strx: u32,
    n_type: u8,
    n_sect: u8,
    n_desc: u16,
    n_value: u64,
};

pub const Symbol = struct {
    name: []const u8,
    address: u64,

    fn addressLessThan(lhs: *const Symbol, rhs: *const Symbol) bool {
        return lhs.address < rhs.address;
    }
};

pub const SymbolTable = struct {
    allocator: *mem.Allocator,
    symbols: []const Symbol,
    strings: []const u8,

    // Doubles as an eyecatcher to calculate the PIE slide, see loadSymbols().
    // Ideally we'd use _mh_execute_header because it's always at 0x100000000
    // in the image but as it's located in a different section than executable
    // code, its displacement is different.
    pub fn deinit(self: *SymbolTable) void {
        self.allocator.free(self.symbols);
        self.symbols = []const Symbol{};

        self.allocator.free(self.strings);
        self.strings = []const u8{};
    }

    pub fn search(self: *const SymbolTable, address: usize) ?*const Symbol {
        var min: usize = 0;
        var max: usize = self.symbols.len - 1; // Exclude sentinel.
        while (min < max) {
            const mid = min + (max - min) / 2;
            const curr = &self.symbols[mid];
            const next = &self.symbols[mid + 1];
            if (address >= next.address) {
                min = mid + 1;
            } else if (address < curr.address) {
                max = mid;
            } else {
                return curr;
            }
        }
        return null;
    }
};

pub fn loadSymbols(allocator: *mem.Allocator, in: *io.FileInStream) !SymbolTable {
    var file = in.file;
    try file.seekTo(0);

    var hdr: MachHeader64 = undefined;
    try readOneNoEof(in, MachHeader64, &hdr);
    if (hdr.magic != MH_MAGIC_64) return error.MissingDebugInfo;
    const is_pie = MH_PIE == (hdr.flags & MH_PIE);

    var pos: usize = @sizeOf(@typeOf(hdr));
    var ncmd: u32 = hdr.ncmds;
    while (ncmd != 0) : (ncmd -= 1) {
        try file.seekTo(pos);
        var lc: LoadCommand = undefined;
        try readOneNoEof(in, LoadCommand, &lc);
        if (lc.cmd == LC_SYMTAB) break;
        pos += lc.cmdsize;
    } else {
        return error.MissingDebugInfo;
    }

    var cmd: SymtabCommand = undefined;
    try readOneNoEof(in, SymtabCommand, &cmd);

    try file.seekTo(cmd.symoff);
    var syms = try allocator.alloc(Nlist64, cmd.nsyms);
    defer allocator.free(syms);
    try readNoEof(in, Nlist64, syms);

    try file.seekTo(cmd.stroff);
    var strings = try allocator.alloc(u8, cmd.strsize);
    errdefer allocator.free(strings);
    try in.stream.readNoEof(strings);

    var nsyms: usize = 0;
    for (syms) |sym|
        if (isSymbol(sym)) nsyms += 1;
    if (nsyms == 0) return error.MissingDebugInfo;

    var symbols = try allocator.alloc(Symbol, nsyms + 1); // Room for sentinel.
    errdefer allocator.free(symbols);

    var pie_slide: usize = 0;
    var nsym: usize = 0;
    for (syms) |sym| {
        if (!isSymbol(sym)) continue;
        const start = sym.n_strx;
        const end = mem.indexOfScalarPos(u8, strings, start, 0).?;
        const name = strings[start..end];
        const address = sym.n_value;
        symbols[nsym] = Symbol{ .name = name, .address = address };
        nsym += 1;
        if (is_pie and mem.eql(u8, name, "_SymbolTable_deinit")) {
            pie_slide = @ptrToInt(SymbolTable.deinit) - address;
        }
    }

    // Effectively a no-op, lld emits symbols in ascending order.
    std.sort.insertionSort(Symbol, symbols[0..nsyms], Symbol.addressLessThan);

    // Insert the sentinel.  Since we don't know where the last function ends,
    // we arbitrarily limit it to the start address + 4 KB.
    const top = symbols[nsyms - 1].address + 4096;
    symbols[nsyms] = Symbol{ .name = "", .address = top };

    if (pie_slide != 0) {
        for (symbols) |*symbol|
            symbol.address += pie_slide;
    }

    return SymbolTable{
        .allocator = allocator,
        .symbols = symbols,
        .strings = strings,
    };
}

fn readNoEof(in: *io.FileInStream, comptime T: type, result: []T) !void {
    return in.stream.readNoEof(@sliceToBytes(result));
}
fn readOneNoEof(in: *io.FileInStream, comptime T: type, result: *T) !void {
    return readNoEof(in, T, (*[1]T)(result)[0..]);
}

fn isSymbol(sym: *const Nlist64) bool {
    return sym.n_value != 0 and sym.n_desc == 0;
}

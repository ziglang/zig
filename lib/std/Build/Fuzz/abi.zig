//! This file is shared among Zig code running in wildly different contexts:
//! libfuzzer, compiled alongside unit tests, the build runner, running on the
//! host computer, and the fuzzing web interface webassembly code running in
//! the browser. All of these components interface to some degree via an ABI.

/// libfuzzer uses this and its usize is the one that counts. To match the ABI,
/// make the ints be the size of the target used with libfuzzer.
///
/// Trailing:
/// * 1 bit per pc_addr, usize elements
/// * pc_addr: usize for each pcs_len
pub const SeenPcsHeader = extern struct {
    n_runs: usize,
    unique_runs: usize,
    pcs_len: usize,

    /// Used for comptime assertions. Provides a mechanism for strategically
    /// causing compile errors.
    pub const trailing = .{
        .pc_bits_usize,
        .pc_addr,
    };

    pub fn headerEnd(header: *const SeenPcsHeader) []const usize {
        const ptr: [*]align(@alignOf(usize)) const u8 = @ptrCast(header);
        const header_end_ptr: [*]const usize = @ptrCast(ptr + @sizeOf(SeenPcsHeader));
        const pcs_len = header.pcs_len;
        return header_end_ptr[0 .. pcs_len + seenElemsLen(pcs_len)];
    }

    pub fn seenBits(header: *const SeenPcsHeader) []const usize {
        return header.headerEnd()[0..seenElemsLen(header.pcs_len)];
    }

    pub fn seenElemsLen(pcs_len: usize) usize {
        return (pcs_len + @bitSizeOf(usize) - 1) / @bitSizeOf(usize);
    }

    pub fn pcAddrs(header: *const SeenPcsHeader) []const usize {
        const pcs_len = header.pcs_len;
        return header.headerEnd()[seenElemsLen(pcs_len)..][0..pcs_len];
    }
};

pub const ToClientTag = enum(u8) {
    current_time,
    source_index,
    coverage_update,
    entry_points,
    _,
};

pub const CurrentTime = extern struct {
    tag: ToClientTag = .current_time,
    /// Number of nanoseconds that all other timestamps are in reference to.
    base: i64 align(1),
};

/// Sent to the fuzzer web client on first connection to the websocket URL.
///
/// Trailing:
/// * std.debug.Coverage.String for each directories_len
/// * std.debug.Coverage.File for each files_len
/// * std.debug.Coverage.SourceLocation for each source_locations_len
/// * u8 for each string_bytes_len
pub const SourceIndexHeader = extern struct {
    flags: Flags,
    directories_len: u32,
    files_len: u32,
    source_locations_len: u32,
    string_bytes_len: u32,
    /// When, according to the server, fuzzing started.
    start_timestamp: i64 align(4),

    pub const Flags = packed struct(u32) {
        tag: ToClientTag = .source_index,
        _: u24 = 0,
    };
};

/// Sent to the fuzzer web client whenever the set of covered source locations
/// changes.
///
/// Trailing:
/// * one bit per source_locations_len, contained in u64 elements
pub const CoverageUpdateHeader = extern struct {
    flags: Flags = .{},
    n_runs: u64,
    unique_runs: u64,

    pub const Flags = packed struct(u64) {
        tag: ToClientTag = .coverage_update,
        _: u56 = 0,
    };

    pub const trailing = .{
        .pc_bits_usize,
    };
};

/// Sent to the fuzzer web client when the set of entry points is updated.
///
/// Trailing:
/// * one u32 index of source_locations per locs_len
pub const EntryPointHeader = extern struct {
    flags: Flags,

    pub const Flags = packed struct(u32) {
        tag: ToClientTag = .entry_points,
        locs_len: u24,
    };
};

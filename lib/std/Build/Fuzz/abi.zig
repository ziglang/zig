//! This file is shared among Zig code running in wildly different contexts:
//! libfuzzer, compiled alongside unit tests, the build runner, running on the
//! host computer, and the fuzzing web interface webassembly code running in
//! the browser. All of these components interface to some degree via an ABI.

/// libfuzzer uses this and its usize is the one that counts. To match the ABI,
/// make the ints be the size of the target used with libfuzzer.
///
/// Trailing:
/// * pc_addr: usize for each pcs_len
/// * 1 bit per pc_addr, u8 elements
pub const SeenPcsHeader = extern struct {
    n_runs: usize,
    unique_runs: usize,
    pcs_len: usize,
    lowest_stack: usize,

    /// Used for comptime assertions. Provides a mechanism for strategically
    /// causing compile errors.
    pub const trailing = .{
        .pc_addr,
        .{ .pc_bits, u8 },
    };
};

pub const ToClientTag = enum(u8) {
    source_index,
    coverage_update,
    entry_points,
    _,
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

    pub const Flags = packed struct(u32) {
        tag: ToClientTag = .source_index,
        _: u24 = 0,
    };
};

/// Sent to the fuzzer web client whenever the set of covered source locations
/// changes.
///
/// Trailing:
/// * one bit per source_locations_len, contained in u8 elements
pub const CoverageUpdateHeader = extern struct {
    tag: ToClientTag = .coverage_update,
    n_runs: u64 align(1),
    unique_runs: u64 align(1),
    lowest_stack: u64 align(1),
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

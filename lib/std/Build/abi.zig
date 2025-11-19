//! This file is shared among Zig code running in wildly different contexts:
//! * The build runner, running on the host computer
//! * The build system web interface Wasm code, running in the browser
//! * `libfuzzer`, compiled alongside unit tests
//!
//! All of these components interface to some degree via an ABI:
//! * The build runner communicates with the web interface over a WebSocket connection
//! * The build runner communicates with `libfuzzer` over a shared memory-mapped file

// Check that no WebSocket message type has implicit padding bits. This ensures we never send any
// undefined bits over the wire, and also helps validate that the layout doesn't differ between, for
// instance, the web server in `std.Build` and the Wasm client.
comptime {
    const check = struct {
        fn check(comptime T: type) void {
            const std = @import("std");
            std.debug.assert(@typeInfo(T) == .@"struct");
            std.debug.assert(@typeInfo(T).@"struct".layout == .@"extern");
            std.debug.assert(std.meta.hasUniqueRepresentation(T));
        }
    }.check;

    // server->client
    check(Hello);
    check(StatusUpdate);
    check(StepUpdate);
    check(fuzz.SourceIndexHeader);
    check(fuzz.CoverageUpdateHeader);
    check(fuzz.EntryPointHeader);
    check(time_report.GenericResult);
    check(time_report.CompileResult);

    // client->server
    check(Rebuild);
}

/// All WebSocket messages sent by the server to the client begin with a `ToClientTag` byte. This
/// enum is non-exhaustive only to avoid Illegal Behavior when malformed messages are sent over the
/// socket; unnamed tags are an error condition and should terminate the connection.
///
/// Every tag has a curresponding `extern struct` representing the full message (or a header of the
/// message if it is variable-length). For instance, `.hello` corresponds to `Hello`.
///
/// When introducing a tag, make sure to add a corresponding `extern struct` whose first field is
/// this enum, and `check` its layout in the `comptime` block above.
pub const ToClientTag = enum(u8) {
    hello,
    status_update,
    step_update,

    // `--fuzz`
    fuzz_source_index,
    fuzz_coverage_update,
    fuzz_entry_points,

    // `--time-report`
    time_report_generic_result,
    time_report_compile_result,
    time_report_run_test_result,

    _,
};

/// Like `ToClientTag`, but for messages sent by the client to the server.
pub const ToServerTag = enum(u8) {
    rebuild,

    _,
};

/// The current overall status of the build runner.
/// Keep in sync with indices in web UI `main.js:updateBuildStatus`.
pub const BuildStatus = enum(u8) {
    idle,
    watching,
    running,
    fuzz_init,
};

/// WebSocket server->client.
///
/// Sent by the server as the first message after a WebSocket connection opens to provide basic
/// information about the server, the build graph, etc.
///
/// Trailing:
/// * `step_name_len: u32` for each `steps_len`
/// * `step_name: [step_name_len]u8` for each `step_name_len`
/// * `step_status: u8` for every 4 `steps_len`; every 2 bits is a `StepUpdate.Status`, LSBs first
pub const Hello = extern struct {
    tag: ToClientTag = .hello,

    status: BuildStatus,
    flags: Flags,

    /// Any message containing a timestamp represents it as a number of nanoseconds relative to when
    /// the build began. This field is the current timestamp, represented in that form.
    timestamp: i64 align(4),

    /// The number of steps in the build graph which are reachable from the top-level step[s] being
    /// run; in other words, the number of steps which will be executed by this build. The name of
    /// each step trails this message.
    steps_len: u32 align(1),

    pub const Flags = packed struct(u16) {
        /// Whether time reporting is enabled.
        time_report: bool,
        _: u15 = 0,
    };
};
/// WebSocket server->client.
///
/// Indicates that the build status has changed.
pub const StatusUpdate = extern struct {
    tag: ToClientTag = .status_update,
    new: BuildStatus,
};
/// WebSocket server->client.
///
/// Indicates a change in a step's status.
pub const StepUpdate = extern struct {
    tag: ToClientTag = .step_update,
    step_idx: u32 align(1),
    bits: packed struct(u8) {
        status: Status,
        _: u6 = 0,
    },
    /// Keep in sync with indices in web UI `main.js:updateStepStatus`.
    pub const Status = enum(u2) {
        pending,
        wip,
        success,
        failure,
    };
};

pub const Rebuild = extern struct {
    tag: ToServerTag = .rebuild,
};

/// ABI bits specifically relating to the fuzzer interface.
pub const fuzz = struct {
    pub const TestOne = *const fn (Slice) callconv(.c) void;
    pub extern fn fuzzer_init(cache_dir_path: Slice) void;
    pub extern fn fuzzer_coverage() Coverage;
    pub extern fn fuzzer_init_test(test_one: TestOne, unit_test_name: Slice) void;
    pub extern fn fuzzer_new_input(bytes: Slice) void;
    pub extern fn fuzzer_main(limit_kind: LimitKind, amount: u64) void;
    pub extern fn fuzzer_unslide_address(addr: usize) usize;

    pub const Slice = extern struct {
        ptr: [*]const u8,
        len: usize,

        pub fn toSlice(s: Slice) []const u8 {
            return s.ptr[0..s.len];
        }

        pub fn fromSlice(s: []const u8) Slice {
            return .{ .ptr = s.ptr, .len = s.len };
        }
    };

    pub const LimitKind = enum(u8) { forever, iterations };

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

    /// WebSocket server->client.
    ///
    /// Sent once, when fuzzing starts, to indicate the available coverage data.
    ///
    /// Trailing:
    /// * std.debug.Coverage.String for each directories_len
    /// * std.debug.Coverage.File for each files_len
    /// * std.debug.Coverage.SourceLocation for each source_locations_len
    /// * u8 for each string_bytes_len
    pub const SourceIndexHeader = extern struct {
        tag: ToClientTag = .fuzz_source_index,
        _: [3]u8 = @splat(0),
        directories_len: u32,
        files_len: u32,
        source_locations_len: u32,
        string_bytes_len: u32,
        /// When, according to the server, fuzzing started.
        start_timestamp: i64 align(4),
    };

    /// WebSocket server->client.
    ///
    /// Sent whenever the set of covered source locations is updated.
    ///
    /// Trailing:
    /// * one bit per source_locations_len, contained in u64 elements
    pub const CoverageUpdateHeader = extern struct {
        tag: ToClientTag = .fuzz_coverage_update,
        _: [7]u8 = @splat(0),
        n_runs: u64,
        unique_runs: u64,

        pub const trailing = .{
            .pc_bits_usize,
        };
    };

    /// WebSocket server->client.
    ///
    /// Sent whenever the set of entry points is updated.
    ///
    /// Trailing:
    /// * one u32 index of source_locations per locsLen()
    pub const EntryPointHeader = extern struct {
        tag: ToClientTag = .fuzz_entry_points,
        locs_len_raw: [3]u8,

        pub fn locsLen(hdr: EntryPointHeader) u24 {
            return @bitCast(hdr.locs_len_raw);
        }
        pub fn init(locs_len: u24) EntryPointHeader {
            return .{ .locs_len_raw = @bitCast(locs_len) };
        }
    };

    /// Sent by lib/fuzzer to test_runner to obtain information about the
    /// active memory mapped input file and cumulative stats about previous
    /// fuzzing runs.
    pub const Coverage = extern struct {
        id: u64,
        runs: u64,
        unique: u64,
        seen: u64,
    };
};

/// ABI bits specifically relating to the time report interface.
pub const time_report = struct {
    /// WebSocket server->client.
    ///
    /// Sent after a `Step` finishes, providing the time taken to execute the step.
    pub const GenericResult = extern struct {
        tag: ToClientTag = .time_report_generic_result,
        step_idx: u32 align(1),
        ns_total: u64 align(1),
    };

    /// WebSocket server->client.
    ///
    /// Sent after a `Step.Compile` finishes, providing the step's time report.
    ///
    /// Trailing:
    /// * `llvm_pass_timings: [llvm_pass_timings_len]u8` (ASCII-encoded)
    /// * for each `files_len`:
    ///   * `name` (null-terminated UTF-8 string)
    /// * for each `decls_len`:
    ///   * `name` (null-terminated UTF-8 string)
    ///   * `file: u32` (index of file this decl is in)
    ///   * `sema_ns: u64` (nanoseconds spent semantically analyzing this decl)
    ///   * `codegen_ns: u64` (nanoseconds spent semantically analyzing this decl)
    ///   * `link_ns: u64` (nanoseconds spent semantically analyzing this decl)
    pub const CompileResult = extern struct {
        tag: ToClientTag = .time_report_compile_result,

        step_idx: u32 align(1),

        flags: Flags,
        stats: Stats align(1),
        ns_total: u64 align(1),

        llvm_pass_timings_len: u32 align(1),
        files_len: u32 align(1),
        decls_len: u32 align(1),

        pub const Flags = packed struct(u8) {
            use_llvm: bool,
            _: u7 = 0,
        };

        pub const Stats = extern struct {
            n_reachable_files: u32,
            n_imported_files: u32,
            n_generic_instances: u32,
            n_inline_calls: u32,

            cpu_ns_parse: u64,
            cpu_ns_astgen: u64,
            cpu_ns_sema: u64,
            cpu_ns_codegen: u64,
            cpu_ns_link: u64,

            real_ns_files: u64,
            real_ns_decls: u64,
            real_ns_llvm_emit: u64,
            real_ns_link_flush: u64,

            pub const init: Stats = .{
                .n_reachable_files = 0,
                .n_imported_files = 0,
                .n_generic_instances = 0,
                .n_inline_calls = 0,
                .cpu_ns_parse = 0,
                .cpu_ns_astgen = 0,
                .cpu_ns_sema = 0,
                .cpu_ns_codegen = 0,
                .cpu_ns_link = 0,
                .real_ns_files = 0,
                .real_ns_decls = 0,
                .real_ns_llvm_emit = 0,
                .real_ns_link_flush = 0,
            };
        };
    };

    /// WebSocket server->client.
    ///
    /// Sent after a `Step.Run` for a Zig test executable finishes, providing the test's time report.
    ///
    /// Trailing:
    /// * for each `tests_len`:
    ///   * `test_ns: u64` (nanoseconds spent running this test)
    /// * for each `tests_len`:
    ///   * `name` (null-terminated UTF-8 string)
    pub const RunTestResult = extern struct {
        tag: ToClientTag = .time_report_run_test_result,
        step_idx: u32 align(1),
        tests_len: u32 align(1),
    };
};

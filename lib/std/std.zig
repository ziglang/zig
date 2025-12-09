pub const ArrayHashMap = array_hash_map.ArrayHashMap;
pub const ArrayHashMapUnmanaged = array_hash_map.ArrayHashMapUnmanaged;
pub const AutoArrayHashMap = array_hash_map.AutoArrayHashMap;
pub const AutoArrayHashMapUnmanaged = array_hash_map.AutoArrayHashMapUnmanaged;
pub const AutoHashMap = hash_map.AutoHashMap;
pub const AutoHashMapUnmanaged = hash_map.AutoHashMapUnmanaged;
pub const BitStack = @import("BitStack.zig");
pub const Build = @import("Build.zig");
pub const BufMap = @import("buf_map.zig").BufMap;
pub const BufSet = @import("buf_set.zig").BufSet;
pub const StaticStringMap = static_string_map.StaticStringMap;
pub const StaticStringMapWithEql = static_string_map.StaticStringMapWithEql;
pub const Deque = @import("deque.zig").Deque;
pub const DoublyLinkedList = @import("DoublyLinkedList.zig");
pub const DynLib = @import("dynamic_library.zig").DynLib;
pub const DynamicBitSet = bit_set.DynamicBitSet;
pub const DynamicBitSetUnmanaged = bit_set.DynamicBitSetUnmanaged;
pub const EnumArray = enums.EnumArray;
pub const EnumMap = enums.EnumMap;
pub const EnumSet = enums.EnumSet;
pub const HashMap = hash_map.HashMap;
pub const HashMapUnmanaged = hash_map.HashMapUnmanaged;
pub const Io = @import("Io.zig");
pub const MultiArrayList = @import("multi_array_list.zig").MultiArrayList;
pub const PriorityQueue = @import("priority_queue.zig").PriorityQueue;
pub const PriorityDequeue = @import("priority_dequeue.zig").PriorityDequeue;
pub const Progress = @import("Progress.zig");
pub const Random = @import("Random.zig");
pub const SemanticVersion = @import("SemanticVersion.zig");
pub const SinglyLinkedList = @import("SinglyLinkedList.zig");
pub const StaticBitSet = bit_set.StaticBitSet;
pub const StringHashMap = hash_map.StringHashMap;
pub const StringHashMapUnmanaged = hash_map.StringHashMapUnmanaged;
pub const StringArrayHashMap = array_hash_map.StringArrayHashMap;
pub const StringArrayHashMapUnmanaged = array_hash_map.StringArrayHashMapUnmanaged;
pub const Target = @import("Target.zig");
pub const Thread = @import("Thread.zig");
pub const Treap = @import("treap.zig").Treap;
pub const Tz = tz.Tz;
pub const Uri = @import("Uri.zig");

/// A contiguous, growable list of items in memory. This is a wrapper around a
/// slice of `T` values.
///
/// The same allocator must be used throughout its entire lifetime. Initialize
/// directly with `empty` or `initCapacity`, and deinitialize with `deinit` or
/// `toOwnedSlice`.
pub fn ArrayList(comptime T: type) type {
    return array_list.Aligned(T, null);
}
pub const array_list = @import("array_list.zig");

/// Deprecated; use `array_list.Aligned`.
pub const ArrayListAligned = array_list.Aligned;
/// Deprecated; use `array_list.Aligned`.
pub const ArrayListAlignedUnmanaged = array_list.Aligned;
/// Deprecated; use `ArrayList`.
pub const ArrayListUnmanaged = ArrayList;

pub const array_hash_map = @import("array_hash_map.zig");
pub const atomic = @import("atomic.zig");
pub const base64 = @import("base64.zig");
pub const bit_set = @import("bit_set.zig");
pub const builtin = @import("builtin.zig");
pub const c = @import("c.zig");
pub const coff = @import("coff.zig");
pub const compress = @import("compress.zig");
pub const static_string_map = @import("static_string_map.zig");
pub const crypto = @import("crypto.zig");
pub const debug = @import("debug.zig");
pub const dwarf = @import("dwarf.zig");
pub const elf = @import("elf.zig");
pub const enums = @import("enums.zig");
pub const fmt = @import("fmt.zig");
pub const fs = @import("fs.zig");
pub const gpu = @import("gpu.zig");
pub const hash = @import("hash.zig");
pub const hash_map = @import("hash_map.zig");
pub const heap = @import("heap.zig");
pub const http = @import("http.zig");
pub const json = @import("json.zig");
pub const leb = @import("leb128.zig");
pub const log = @import("log.zig");
pub const macho = @import("macho.zig");
pub const math = @import("math.zig");
pub const mem = @import("mem.zig");
pub const meta = @import("meta.zig");
pub const os = @import("os.zig");
pub const once = @import("once.zig").once;
pub const pdb = @import("pdb.zig");
pub const pie = @import("pie.zig");
pub const posix = @import("posix.zig");
pub const process = @import("process.zig");
pub const sort = @import("sort.zig");
pub const simd = @import("simd.zig");
pub const ascii = @import("ascii.zig");
pub const tar = @import("tar.zig");
pub const testing = @import("testing.zig");
pub const time = @import("time.zig");
pub const tz = @import("tz.zig");
pub const unicode = @import("unicode.zig");
pub const valgrind = @import("valgrind.zig");
pub const wasm = @import("wasm.zig");
pub const zig = @import("zig.zig");
pub const zip = @import("zip.zig");
pub const zon = @import("zon.zig");
pub const start = @import("start.zig");

const root = @import("root");

/// Stdlib-wide options that can be overridden by the root file.
pub const options: Options = if (@hasDecl(root, "std_options")) root.std_options else .{};

pub const Options = struct {
    enable_segfault_handler: bool = debug.default_enable_segfault_handler,

    /// Function used to implement `std.fs.cwd` for WASI.
    wasiCwd: fn () os.wasi.fd_t = fs.defaultWasiCwd,

    /// The current log level.
    log_level: log.Level = log.default_level,

    log_scope_levels: []const log.ScopeLevel = &.{},

    logFn: fn (
        comptime message_level: log.Level,
        comptime scope: @EnumLiteral(),
        comptime format: []const u8,
        args: anytype,
    ) void = log.defaultLog,

    /// Overrides `std.heap.page_size_min`.
    page_size_min: ?usize = null,
    /// Overrides `std.heap.page_size_max`.
    page_size_max: ?usize = null,
    /// Overrides default implementation for determining OS page size at runtime.
    queryPageSize: fn () usize = heap.defaultQueryPageSize,

    fmt_max_depth: usize = fmt.default_max_depth,

    cryptoRandomSeed: fn (buffer: []u8) void = @import("crypto/tlcsprng.zig").defaultRandomSeed,

    crypto_always_getrandom: bool = false,

    crypto_fork_safety: bool = true,

    /// By default, std.http.Client will support HTTPS connections.  Set this option to `true` to
    /// disable TLS support.
    ///
    /// This will likely reduce the size of the binary, but it will also make it impossible to
    /// make a HTTPS connection.
    http_disable_tls: bool = false,

    /// This enables `std.http.Client` to log ssl secrets to the file specified by the SSLKEYLOGFILE
    /// env var.  Creating such a log file allows other programs with access to that file to decrypt
    /// all `std.http.Client` traffic made by this program.
    http_enable_ssl_key_log_file: bool = @import("builtin").mode == .Debug,

    side_channels_mitigations: crypto.SideChannelsMitigations = crypto.default_side_channels_mitigations,

    /// Whether to allow capturing and writing stack traces. This affects the following functions:
    /// * `debug.captureCurrentStackTrace`
    /// * `debug.writeCurrentStackTrace`
    /// * `debug.dumpCurrentStackTrace`
    /// * `debug.writeStackTrace`
    /// * `debug.dumpStackTrace`
    ///
    /// Stack traces can generally be collected and printed when debug info is stripped, but are
    /// often less useful since they usually cannot be mapped to source locations and/or have bad
    /// source locations. The stack tracing logic can also be quite large, which may be undesirable,
    /// particularly in ReleaseSmall.
    ///
    /// If this is `false`, then captured stack traces will always be empty, and attempts to write
    /// stack traces will just print an error to the relevant `Io.Writer` and return.
    allow_stack_tracing: bool = !@import("builtin").strip_debug_info,
};

// This forces the start.zig file to be imported, and the comptime logic inside that
// file decides whether to export any appropriate start symbols, and call main.
comptime {
    _ = start;
}

test {
    testing.refAllDecls(@This());
}

comptime {
    debug.assert(@import("std") == @This()); // std lib tests require --zig-lib-dir
}

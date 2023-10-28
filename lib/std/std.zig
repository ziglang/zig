pub const ArrayHashMap = array_hash_map.ArrayHashMap;
pub const ArrayHashMapUnmanaged = array_hash_map.ArrayHashMapUnmanaged;
pub const ArrayList = @import("array_list.zig").ArrayList;
pub const ArrayListAligned = @import("array_list.zig").ArrayListAligned;
pub const ArrayListAlignedUnmanaged = @import("array_list.zig").ArrayListAlignedUnmanaged;
pub const ArrayListUnmanaged = @import("array_list.zig").ArrayListUnmanaged;
pub const AutoArrayHashMap = array_hash_map.AutoArrayHashMap;
pub const AutoArrayHashMapUnmanaged = array_hash_map.AutoArrayHashMapUnmanaged;
pub const AutoHashMap = hash_map.AutoHashMap;
pub const AutoHashMapUnmanaged = hash_map.AutoHashMapUnmanaged;
pub const BitStack = @import("BitStack.zig");
pub const BoundedArray = @import("bounded_array.zig").BoundedArray;
pub const BoundedArrayAligned = @import("bounded_array.zig").BoundedArrayAligned;
pub const Build = @import("Build.zig");
pub const BufMap = @import("buf_map.zig").BufMap;
pub const BufSet = @import("buf_set.zig").BufSet;
/// Deprecated: use `process.Child`.
pub const ChildProcess = @import("child_process.zig").ChildProcess;
pub const ComptimeStringMap = comptime_string_map.ComptimeStringMap;
pub const ComptimeStringMapWithEql = comptime_string_map.ComptimeStringMapWithEql;
pub const DoublyLinkedList = @import("linked_list.zig").DoublyLinkedList;
pub const DynLib = @import("dynamic_library.zig").DynLib;
pub const DynamicBitSet = bit_set.DynamicBitSet;
pub const DynamicBitSetUnmanaged = bit_set.DynamicBitSetUnmanaged;
pub const EnumArray = enums.EnumArray;
pub const EnumMap = enums.EnumMap;
pub const EnumSet = enums.EnumSet;
pub const HashMap = hash_map.HashMap;
pub const HashMapUnmanaged = hash_map.HashMapUnmanaged;
pub const Ini = @import("Ini.zig");
pub const MultiArrayList = @import("multi_array_list.zig").MultiArrayList;
pub const PackedIntArray = @import("packed_int_array.zig").PackedIntArray;
pub const PackedIntArrayEndian = @import("packed_int_array.zig").PackedIntArrayEndian;
pub const PackedIntSlice = @import("packed_int_array.zig").PackedIntSlice;
pub const PackedIntSliceEndian = @import("packed_int_array.zig").PackedIntSliceEndian;
pub const PriorityQueue = @import("priority_queue.zig").PriorityQueue;
pub const PriorityDequeue = @import("priority_dequeue.zig").PriorityDequeue;
pub const Progress = @import("Progress.zig");
pub const RingBuffer = @import("RingBuffer.zig");
pub const SegmentedList = @import("segmented_list.zig").SegmentedList;
pub const SemanticVersion = @import("SemanticVersion.zig");
pub const SinglyLinkedList = @import("linked_list.zig").SinglyLinkedList;
pub const StaticBitSet = bit_set.StaticBitSet;
pub const StringHashMap = hash_map.StringHashMap;
pub const StringHashMapUnmanaged = hash_map.StringHashMapUnmanaged;
pub const StringArrayHashMap = array_hash_map.StringArrayHashMap;
pub const StringArrayHashMapUnmanaged = array_hash_map.StringArrayHashMapUnmanaged;
/// deprecated: use `DoublyLinkedList`.
pub const TailQueue = DoublyLinkedList;
pub const Target = @import("target.zig").Target;
pub const Thread = @import("Thread.zig");
pub const Treap = @import("treap.zig").Treap;
pub const Tz = tz.Tz;
pub const Uri = @import("Uri.zig");

pub const array_hash_map = @import("array_hash_map.zig");

/// Memory ordering, atomic data structures, and operations.
pub const atomic = @import("atomic.zig");

/// Base64 encoding/decoding.
pub const base64 = @import("base64.zig");

/// Bit manipulation data structures.
pub const bit_set = @import("bit_set.zig");

/// Comptime-available information about the build environment, such as the target and optimize mode.
pub const builtin = @import("builtin.zig");

pub const c = @import("c.zig");

/// COFF format.
pub const coff = @import("coff.zig");

/// Compression algorithms such as zlib, zstd, etc.
pub const compress = @import("compress.zig");

pub const comptime_string_map = @import("comptime_string_map.zig");

/// Cryptography.
pub const crypto = @import("crypto.zig");

/// Debug printing, allocation and other debug helpers.
pub const debug = @import("debug.zig");

/// DWARF debugging data format.
pub const dwarf = @import("dwarf.zig");

/// ELF format.
pub const elf = @import("elf.zig");

/// Enum-related metaprogramming helpers.
pub const enums = @import("enums.zig");

/// Evented I/O data structures.
pub const event = @import("event.zig");

/// First in, first out data structures.
pub const fifo = @import("fifo.zig");

/// String formatting and parsing (e.g. parsing numbers out of strings).
pub const fmt = @import("fmt.zig");

/// File system-related functionality.
pub const fs = @import("fs.zig");

/// Fast hashing functions (i.e. not cryptographically secure).
pub const hash = @import("hash.zig");
pub const hash_map = @import("hash_map.zig");

/// Allocator implementations.
pub const heap = @import("heap.zig");

/// HTTP client and server.
pub const http = @import("http.zig");

/// I/O streams, reader/writer interfaces and common helpers.
pub const io = @import("io.zig");

/// JSON parsing and serialization.
pub const json = @import("json.zig");

/// LEB128 encoding.
pub const leb = @import("leb128.zig");

/// A standardized interface for logging.
pub const log = @import("log.zig");

/// Mach-O format.
pub const macho = @import("macho.zig");

/// Mathematical constants and operations.
pub const math = @import("math.zig");

/// Functions for comparing, searching, and manipulating memory.
pub const mem = @import("mem.zig");

/// Metaprogramming helpers.
pub const meta = @import("meta.zig");

/// Networking.
pub const net = @import("net.zig");

/// Wrappers around OS-specific APIs.
pub const os = @import("os.zig");

pub const once = @import("once.zig").once;

/// A set of array and slice types that bit-pack integer elements.
pub const packed_int_array = @import("packed_int_array.zig");

/// PDB file format.
pub const pdb = @import("pdb.zig");

/// Accessors for process-related info (e.g. command line arguments)
/// and spawning of child processes.
pub const process = @import("process.zig");

/// Fast pseudo-random number generators (i.e. not cryptographically secure).
pub const rand = @import("rand.zig");

/// Sorting.
pub const sort = @import("sort.zig");

/// Single Instruction Multiple Data (SIMD) helpers.
pub const simd = @import("simd.zig");

/// ASCII text processing.
pub const ascii = @import("ascii.zig");

/// Tar archive format compression/decompression.
pub const tar = @import("tar.zig");

/// Testing allocator, testing assertions, and other helpers for testing code.
pub const testing = @import("testing.zig");

/// Sleep, obtaining the current time, conversion constants, and more.
pub const time = @import("time.zig");

/// Time zones.
pub const tz = @import("tz.zig");

/// UTF-8 and UTF-16LE encoding/decoding.
pub const unicode = @import("unicode.zig");

/// Helpers for integrating with Valgrind.
pub const valgrind = @import("valgrind.zig");

/// Constants and types representing the Wasm binary format.
pub const wasm = @import("wasm.zig");

/// Tokenizing and parsing of Zig code and other Zig-specific language tooling.
pub const zig = @import("zig.zig");

pub const start = @import("start.zig");

/// deprecated: use `Build`.
pub const build = Build;

const root = @import("root");
const options_override = if (@hasDecl(root, "std_options")) root.std_options else struct {};

/// Stdlib-wide options that can be overridden by the root file.
pub const options = struct {
    pub const enable_segfault_handler: bool = if (@hasDecl(options_override, "enable_segfault_handler"))
        options_override.enable_segfault_handler
    else
        debug.default_enable_segfault_handler;

    /// Function used to implement `std.fs.cwd` for WASI.
    pub const wasiCwd: fn () fs.Dir = if (@hasDecl(options_override, "wasiCwd"))
        options_override.wasiCwd
    else
        fs.defaultWasiCwd;

    /// The application's chosen I/O mode.
    pub const io_mode: io.Mode = if (@hasDecl(options_override, "io_mode"))
        options_override.io_mode
    else if (@hasDecl(options_override, "event_loop"))
        .evented
    else
        .blocking;

    pub const event_loop: event.Loop.Instance = if (@hasDecl(options_override, "event_loop"))
        options_override.event_loop
    else
        event.Loop.default_instance;

    pub const event_loop_mode: event.Loop.Mode = if (@hasDecl(options_override, "event_loop_mode"))
        options_override.event_loop_mode
    else
        event.Loop.default_mode;

    /// The current log level.
    pub const log_level: log.Level = if (@hasDecl(options_override, "log_level"))
        options_override.log_level
    else
        log.default_level;

    pub const log_scope_levels: []const log.ScopeLevel = if (@hasDecl(options_override, "log_scope_levels"))
        options_override.log_scope_levels
    else
        &.{};

    pub const logFn: fn (
        comptime message_level: log.Level,
        comptime scope: @TypeOf(.enum_literal),
        comptime format: []const u8,
        args: anytype,
    ) void = if (@hasDecl(options_override, "logFn"))
        options_override.logFn
    else
        log.defaultLog;

    pub const fmt_max_depth = if (@hasDecl(options_override, "fmt_max_depth"))
        options_override.fmt_max_depth
    else
        fmt.default_max_depth;

    pub const cryptoRandomSeed: fn (buffer: []u8) void = if (@hasDecl(options_override, "cryptoRandomSeed"))
        options_override.cryptoRandomSeed
    else
        @import("crypto/tlcsprng.zig").defaultRandomSeed;

    pub const crypto_always_getrandom: bool = if (@hasDecl(options_override, "crypto_always_getrandom"))
        options_override.crypto_always_getrandom
    else
        false;

    /// By default Zig disables SIGPIPE by setting a "no-op" handler for it.  Set this option
    /// to `true` to prevent that.
    ///
    /// Note that we use a "no-op" handler instead of SIG_IGN because it will not be inherited by
    /// any child process.
    ///
    /// SIGPIPE is triggered when a process attempts to write to a broken pipe. By default, SIGPIPE
    /// will terminate the process instead of exiting.  It doesn't trigger the panic handler so in many
    /// cases it's unclear why the process was terminated.  By capturing SIGPIPE instead, functions that
    /// write to broken pipes will return the EPIPE error (error.BrokenPipe) and the program can handle
    /// it like any other error.
    pub const keep_sigpipe: bool = if (@hasDecl(options_override, "keep_sigpipe"))
        options_override.keep_sigpipe
    else
        false;

    /// By default, std.http.Client will support HTTPS connections.  Set this option to `true` to
    /// disable TLS support.
    ///
    /// This will likely reduce the size of the binary, but it will also make it impossible to
    /// make a HTTPS connection.
    pub const http_disable_tls = if (@hasDecl(options_override, "http_disable_tls"))
        options_override.http_disable_tls
    else
        false;

    pub const side_channels_mitigations: crypto.SideChannelsMitigations = if (@hasDecl(options_override, "side_channels_mitigations"))
        options_override.side_channels_mitigations
    else
        crypto.default_side_channels_mitigations;
};

// This forces the start.zig file to be imported, and the comptime logic inside that
// file decides whether to export any appropriate start symbols, and call main.
comptime {
    _ = start;

    for (@typeInfo(options_override).Struct.decls) |decl| {
        if (!@hasDecl(options, decl.name)) @compileError("no option named " ++ decl.name);
    }
}

test {
    testing.refAllDecls(@This());
}

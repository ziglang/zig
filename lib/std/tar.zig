pub const Error = error{
    Overflow,
    InvalidCharacter,
    UnexpectedEndOfStream,
    Header,
    TarUnexpectedFileType,
    TarComponentsOutsideStrippedPrefix,
};

pub const FileType = enum(u8) {
    normal = '0',
    normal2 = 0,
    hard_link = '1',
    symbolic_link = '2',
    character_special = '3',
    block_special = '4',
    directory = '5',
    fifo = '6',
    contiguous = '7',
    global_extended_header = 'g',
    extended_header = 'x',
    gnu_sparse = 'S',
    gnu_long_name = 'L',
    gnu_long_link = 'K',
    _,

    pub const sentinel = @enumFromInt(FileType, 0xff);

    pub const NamedTypesBitset = std.StaticBitSet(128);

    pub const named_types_bitset = blk: {
        var result = NamedTypesBitset.initEmpty();
        for ([_]FileType{
            .directory,     .normal,            .normal2,       .hard_link,
            .symbolic_link, .character_special, .block_special, .fifo,
            .contiguous,
        }) |ft|
            result.set(@intFromEnum(ft));
        break :blk result;
    };

    pub fn isNamedType(ft: FileType) bool {
        return
        // verify not beyond NamedTypesBitset.bit_length to avoid assertion
        // failure in std.bit_set
        @intFromEnum(ft) < NamedTypesBitset.bit_length and
            named_types_bitset.isSet(@intFromEnum(ft));
    }

    pub fn tagName(ft: FileType) ?[]const u8 {
        return inline for (std.meta.fields(FileType)) |f| {
            if (@intFromEnum(ft) == f.value) break f.name;
        } else null;
    }
};

fn parseOctal(raw: []const u8) !i64 {
    // don't need to trim '0's as parseInt() accepts them
    const trimmed = mem.trim(u8, raw, " \x00");
    if (trimmed.len == 0) return 0;
    return fmt.parseInt(i64, mem.sliceTo(trimmed, 0), 8);
}

/// Parses the input as being encoded in either base-256 or octal.
/// This function may return negative numbers.
/// Returns errors if parsing fails or an integer overflow occurs.
fn parseNumeric(b: []const u8) !i64 {
    // Check for base-256 (binary) format first.
    // If the first bit is set, then all following bits constitute a two's
    // complement encoded number in big-endian byte order.
    if (b.len > 0 and b[0] & 0x80 != 0) {
        // Handling negative numbers relies on the following identity:
        //  -a-1 == ^a
        //
        // If the number is negative, we use an inversion mask to invert the
        // data bytes and treat the value as an unsigned number.

        // inv = 0xff if negative else 0
        const inv = @as(u8, @intFromBool(b[0] & 0x40 != 0)) * 0xff;

        var x: u64 = 0;
        for (0..b.len) |i| {
            // ignore the signal bit in first byte
            const mask = @as(u8, 0xff) >> @intFromBool(i == 0);
            const c = b[i] ^ inv & mask;
            if (x > 0x00ff_ffff_ffff_ffff) return error.Overflow;
            x = x << 8 | c;
        }
        if (x >= 0x8000_0000_0000_0000) return error.Overflow;

        return if (inv == 0)
            @bitCast(i64, x)
        else
            ~@bitCast(i64, x);
    }

    return try parseOctal(b);
}

test parseNumeric {
    const TestCase = struct {
        []const u8,
        Error!i128,
    };

    const cases = [_]TestCase{
        .{ "", 0 },
        .{ "\x80", 0 },
        .{ "\x80\x00", 0 },
        .{ "\x80\x00\x00", 0 },
        .{ "\xbf", (1 << 6) - 1 },
        .{ "\xbf\xff", (1 << 14) - 1 },
        .{ "\xbf\xff\xff", (1 << 22) - 1 },
        .{ "\xff", -1 },
        .{ "\xff\xff", -1 },
        .{ "\xff\xff\xff", -1 },
        .{ "\xc0", -1 * (1 << 6) },
        .{ "\xc0\x00", -1 * (1 << 14) },
        .{ "\xc0\x00\x00", -1 * (1 << 22) },
        .{ "\x87\x76\xa2\x22\xeb\x8a\x72\x61", 537795476381659745 },
        .{ "\x80\x00\x00\x00\x07\x76\xa2\x22\xeb\x8a\x72\x61", 537795476381659745 },
        .{ "\xf7\x76\xa2\x22\xeb\x8a\x72\x61", -615126028225187231 },
        .{ "\xff\xff\xff\xff\xf7\x76\xa2\x22\xeb\x8a\x72\x61", -615126028225187231 },
        .{ "\x80\x7f\xff\xff\xff\xff\xff\xff\xff", math.maxInt(i64) },
        .{ "\x80\x80\x00\x00\x00\x00\x00\x00\x00", error.Overflow },
        .{ "\xff\x80\x00\x00\x00\x00\x00\x00\x00", math.minInt(i64) },
        .{ "\xff\x7f\xff\xff\xff\xff\xff\xff\xff", error.Overflow },
        .{ "\xf5\xec\xd1\xc7\x7e\x5f\x26\x48\x81\x9f\x8f\x9b", error.Overflow },

        // Test base-8 (octal) encoded values.
        .{ "0000000\x00", 0 },
        .{ " \x0000000\x00", 0 },
        .{ " \x0000003\x00", 3 },
        .{ "00000000227\x00", 0o227 },
        .{ "032033\x00 ", 0o32033 },
        .{ "320330\x00 ", 0o320330 },
        .{ "0000660\x00 ", 0o660 },
        .{ "\x00 0000660\x00 ", 0o660 },
        .{ "0123456789abcdef", error.InvalidCharacter },
        .{ "0123456789\x00abcdef", error.InvalidCharacter },
        .{ "01234567\x0089abcdef", 342391 },
        .{ "0123\x7e\x5f\x264123", error.InvalidCharacter },
    };

    for (cases) |case| {
        const input = case[0];
        const expected_or_err = case[1];
        const err_or_void = if (expected_or_err) |expected|
            if (parseNumeric(input)) |actual|
                std.testing.expectEqual(expected, actual)
            else |err|
                err
        else |err|
            std.testing.expectError(err, parseNumeric(input));

        err_or_void catch |e| {
            log.err("parseNumeric failed on {s}:{any}. expected {!} got {!}", .{ input, input, expected_or_err, e });
            return e;
        };
    }
}

// Takes a string of the form %d.%d as described in the PAX
// specification. Note that this implementation allows for negative timestamps,
// which is allowed for by the PAX specification, but not always portable.
fn parsePaxTime(s: []const u8) !i128 {
    // split into seconds and sub-seconds parts
    const parts: [2][]const u8 = if (mem.indexOfScalar(u8, s, '.')) |pos|
        .{ s[0..pos], s[pos + 1 ..] }
    else
        .{ s, "" };
    const ss = parts[0];
    const secs = try fmt.parseInt(i64, ss, 10);

    const sn = parts[1];
    if (sn.len == 0) return try unixTime(secs, 0);

    const all_digits = for (sn) |c| {
        if (!std.ascii.isDigit(c)) break false;
    } else true;
    if (!all_digits) return error.InvalidCharacter;

    const max_digits = 9;
    // add trailing zeroes
    var buf = [1]u8{'0'} ** max_digits;
    const len = @min(sn.len, max_digits);
    mem.copy(u8, &buf, sn[0..len]);
    const nsecs = try fmt.parseInt(i64, &buf, 10);

    log.debug("parsePaxTime secs={} nsecs={} sn.len={}", .{ secs, nsecs, sn.len });
    return if (ss.len > 0 and ss[0] == '-')
        try unixTime(secs, -nsecs)
    else
        try unixTime(secs, nsecs);
}

test parsePaxTime {
    const TestCase = struct {
        []const u8,
        Error!i128,
    };

    const cases = [_]TestCase{
        .{ "1350244992.023960108", try unixTime(1350244992, 23960108) },
        .{ "1350244992.02396010", try unixTime(1350244992, 23960100) },
        .{ "1350244992.0239601089", try unixTime(1350244992, 23960108) },
        .{ "1350244992.3", try unixTime(1350244992, 300000000) },
        .{ "1350244992", try unixTime(1350244992, 0) },
        .{ "-1.000000001", try unixTime(-1, -1e0 + 0e0) },
        .{ "-1.000001", try unixTime(-1, -1e3 + 0e0) },
        .{ "-1.001000", try unixTime(-1, -1e6 + 0e0) },
        .{ "-1", try unixTime(-1, -0e0 + 0e0) },
        .{ "-1.999000", try unixTime(-1, -1e9 + 1e6) },
        .{ "-1.999999", try unixTime(-1, -1e9 + 1e3) },
        .{ "-1.999999999", try unixTime(-1, -1e9 + 1e0) },
        .{ "0.000000001", try unixTime(0, 1e0 + 0e0) },
        .{ "0.000001", try unixTime(0, 1e3 + 0e0) },
        .{ "0.001000", try unixTime(0, 1e6 + 0e0) },
        .{ "0", try unixTime(0, 0e0) },
        .{ "0.999000", try unixTime(0, 1e9 - 1e6) },
        .{ "0.999999", try unixTime(0, 1e9 - 1e3) },
        .{ "0.999999999", try unixTime(0, 1e9 - 1e0) },
        .{ "1.000000001", try unixTime(1, 1e0 - 0e0) },
        .{ "1.000001", try unixTime(1, 1e3 - 0e0) },
        .{ "1.001000", try unixTime(1, 1e6 - 0e0) },
        .{ "1", try unixTime(1, 0e0 - 0e0) },
        .{ "1.999000", try unixTime(1, 1e9 - 1e6) },
        .{ "1.999999", try unixTime(1, 1e9 - 1e3) },
        .{ "1.999999999", try unixTime(1, 1e9 - 1e0) },
        .{ "-1350244992.023960108", try unixTime(-1350244992, -23960108) },
        .{ "-1350244992.02396010", try unixTime(-1350244992, -23960100) },
        .{ "-1350244992.0239601089", try unixTime(-1350244992, -23960108) },
        .{ "-1350244992.3", try unixTime(-1350244992, -300000000) },
        .{ "-1350244992", try unixTime(-1350244992, 0) },
        .{ "", error.InvalidCharacter },
        .{ "0", try unixTime(0, 0) },
        .{ "1.", try unixTime(1, 0) },
        .{ "0.0", try unixTime(0, 0) },
        .{ ".5", error.InvalidCharacter },
        .{ "-1.3", try unixTime(-1, -3e8) },
        .{ "-1.0", try unixTime(-1, -0e0) },
        .{ "-0.0", try unixTime(-0, -0e0) },
        .{ "-0.1", try unixTime(-0, -1e8) },
        .{ "-0.01", try unixTime(-0, -1e7) },
        .{ "-0.99", try unixTime(-0, -99e7) },
        .{ "-0.98", try unixTime(-0, -98e7) },
        .{ "-1.1", try unixTime(-1, -1e8) },
        .{ "-1.01", try unixTime(-1, -1e7) },
        .{ "-2.99", try unixTime(-2, -99e7) },
        .{ "-5.98", try unixTime(-5, -98e7) },
        .{ "-", error.InvalidCharacter },
        .{ "+", error.InvalidCharacter },
        .{ "-1.-1", error.InvalidCharacter },
        .{ "99999999999999999999999999999999999999999999999", error.Overflow },
        .{ "0.123456789abcdef", error.InvalidCharacter },
        .{ "foo", error.InvalidCharacter },
        .{ "\x00", error.InvalidCharacter },
        .{ "𝟵𝟴𝟳𝟲𝟱.𝟰𝟯𝟮𝟭𝟬", error.InvalidCharacter }, // Unicode numbers (U+1D7EC to U+1D7}
        .{ "98765﹒43210", error.InvalidCharacter }, // Unicode period (U+FE}
    };

    for (cases) |case| {
        const input = case[0];
        const expected_or_err = case[1];
        const err_or_void = if (expected_or_err) |expected|
            if (parsePaxTime(input)) |actual|
                std.testing.expectEqual(expected, actual)
            else |err|
                err
        else |err|
            std.testing.expectError(err, parsePaxTime(input));

        err_or_void catch |e| {
            log.err("parsePaxTime failed on {s}. expected {!} got {!}", .{ input, expected_or_err, e });
            return e;
        };
    }
}

/// merges key-value pair `kv` into hdr if its a valid PAX field.
/// TODO merge PAX schilly xattrs
pub fn mergePax(kv: [2][]const u8, hdr: *Header) !void {
    const k = kv[0];
    const v = kv[1];
    log.debug("mergePax k={s} v={s}", .{ k, v });
    if (v.len == 0) return;

    const map = std.ComptimeStringMap(std.meta.FieldEnum(Header), .{
        .{ Pax.path, .name },
        .{ Pax.linkpath, .linkname },
        .{ Pax.uname, .uname },
        .{ Pax.gname, .gname },
        .{ Pax.uid, .uid },
        .{ Pax.gid, .gid },
        .{ Pax.atime, .atime },
        .{ Pax.mtime, .mtime },
        .{ Pax.ctime, .ctime },
        .{ Pax.size, .size },
    });

    if (map.get(k)) |field_enum| switch (field_enum) {
        .name => hdr.name = v,
        .linkname => hdr.linkname = v,
        .uname => hdr.uname = v,
        .gname => hdr.gname = v,
        .uid => hdr.uid = @truncate(i32, try fmt.parseInt(i64, v, 10)),
        .gid => hdr.gid = @truncate(i32, try fmt.parseInt(i64, v, 10)),
        .atime => hdr.atime = try parsePaxTime(v),
        .ctime => hdr.ctime = try parsePaxTime(v),
        .mtime => hdr.mtime = try parsePaxTime(v),
        .size => hdr.size = try fmt.parseInt(i64, v, 10),
        else => unreachable,
    } else {
        // TODO merge PAX schilly xattrs
        // log.debug("TODO handle pax header key={s}", .{k});
    }
}

// Constants to identify various tar formats.
pub const Format = enum {
    unknown,

    // The format of the original Unix V7 tar tool prior to standardization.
    v7,

    // ustar represents the USTAR header format defined in POSIX.1-1988.
    //
    // While this format is compatible with most tar readers,
    // the format has several limitations making it unsuitable for some usages.
    // Most notably, it cannot support sparse files, files larger than 8GiB,
    // filenames larger than 256 characters, and non-ASCII filenames.
    //
    // Reference:
    //  http://pubs.opengroup.org/onlinepubs/9699919799/utilities/pax.html#tag_20_92_13_06
    ustar,

    // pax represents the PAX header format defined in POSIX.1-2001.
    //
    // PAX extends USTAR by writing a special file with Typeflag TypeXHeader
    // preceding the original header. This file contains a set of key-value
    // records, which are used to overcome USTAR's shortcomings, in addition to
    // providing the ability to have sub-second resolution for timestamps.
    //
    // Some newer formats add their own extensions to PAX by defining their
    // own keys and assigning certain semantic meaning to the associated values.
    // For example, sparse file support in PAX is implemented using keys
    // defined by the GNU manual (e.g., "GNU.sparse.map").
    //
    // Reference:
    //  http://pubs.opengroup.org/onlinepubs/009695399/utilities/pax.html
    pax,

    // gnu represents the GNU header format.
    //
    // The GNU header format is older than the USTAR and PAX standards and
    // is not compatible with them. The GNU format supports
    // arbitrary file sizes, filenames of arbitrary encoding and length,
    // sparse files, and other features.
    //
    // It is recommended that PAX be chosen over GNU unless the target
    // application can only parse GNU formatted archives.
    //
    // Reference:
    //  https://www.gnu.org/software/tar/manual/html_node/Standard.html
    gnu,

    // Schily's tar format, which is incompatible with USTAR.
    // This does not cover STAR extensions to the PAX format; these fall under
    // the PAX format.
    star,
};

pub const FormatSet = std.enums.EnumSet(Format);
const fmt_unknown = FormatSet.initOne(.unknown);
const fmt_v7 = FormatSet.initOne(.v7);
const fmt_ustar = FormatSet.initOne(.ustar);
const fmt_pax = FormatSet.initOne(.pax);
const fmt_gnu = FormatSet.initOne(.gnu);
const fmt_star = FormatSet.initOne(.star);
const fmt_ustar_pax = FormatSet.initMany(&.{ .ustar, .pax });
const fmt_ustar_pax_gnu = FormatSet.initMany(&.{ .ustar, .pax, .gnu });

pub const Header = struct {
    /// The type of header
    type: FileType = FileType.sentinel,

    /// Name of file
    name: []const u8 = "",
    /// Target name of link (valid for hard_link or symbolic_link)
    linkname: []const u8 = "",

    /// Logical file size in bytes
    size: i64 = -1,
    /// Permission and mode bits
    mode: i64 = -1,
    /// User ID of owner
    uid: i32 = -1,
    /// Group ID of owner
    gid: i32 = -1,
    /// User name of owner
    uname: []const u8 = "",
    /// Group name of owner
    gname: []const u8 = "",

    /// To use atime or ctime, specify the format as PAX or GNU.
    /// To use sub-second resolution, specify the format as PAX.
    /// Modification time
    mtime: i128 = -1,
    /// Access time (requires either PAX or GNU support)
    atime: i128 = -1,
    /// Change time (requires either PAX or GNU support)
    ctime: i128 = -1,

    /// Major device number (valid for character_special or block_special)
    dev_major: i64 = -1,
    /// Minor device number (valid for character_special or block_special)
    dev_minor: i64 = -1,

    /// pax_recs is a sequence of key, value PAX extended header records.
    /// only used in tests.
    pax_recs: if (builtin.is_test) []const []const u8 else void =
        if (builtin.is_test) &.{} else {},

    // fmt specifies the format of the tar header.
    //
    // This is a best-effort guess at the format.
    // Due to liberally reading some non-compliant files,
    // it is possible for this to be unknown.
    fmt: FormatSet = FormatSet.initEmpty(),

    // TODO remove when unused
    fn debugFormatSet(format_set: FormatSet, writer: anytype) !void {
        try writer.print(" format_set=", .{});
        var iter = format_set.iterator();
        var i: u8 = 0;
        while (iter.next()) |f| : (i += 1) {
            if (i != 0) try writer.writeByte('|');
            try writer.print("{s}", .{@tagName(f)});
        }
    }

    // TODO remove when unused
    pub fn format(h: Header, comptime _: []const u8, _: fmt.FormatOptions, writer: anytype) !void {
        const tagname = inline for (std.meta.fields(FileType)) |field| {
            if (@intFromEnum(h.type) == field.value) break field.name;
        } else "null";
        try writer.print("type={s} size={} name={s} mtime={} mode=0o{o}", .{ tagname, h.size, h.name, h.mtime, h.mode });
        try debugFormatSet(h.fmt, writer);
    }

    fn structField(comptime field_enum: std.meta.FieldEnum(Header)) std.builtin.Type.StructField {
        return @typeInfo(Header).Struct.fields[@intFromEnum(field_enum)];
    }

    fn fieldDefault(comptime field: std.builtin.Type.StructField) field.type {
        return @ptrCast(
            *const field.type,
            @alignCast(@alignOf(field.type), field.default_value),
        ).*;
    }

    /// copy all fields from `new_hdr` to `hdr`, but skipping any fields that
    /// have default values (as defined in Header).
    fn merge(hdr: *Header, new_hdr: Header) void {
        // only assign a `hdr` field value if its not equal to the field's default
        // value.  includes comptime checks that field default values match expectations
        inline for (std.meta.fields(Header)) |f| {
            switch (f.type) {
                FileType => {
                    const default = comptime fieldDefault(f);
                    comptime assert(default == FileType.sentinel);
                    if (@field(new_hdr, f.name) != default) {
                        @field(hdr, f.name) = @field(new_hdr, f.name);
                    }
                },
                i64, i32, i128 => {
                    // verify all integer field defaults == -1
                    const default = comptime fieldDefault(f);
                    comptime assert(default == -1);
                    if (@field(new_hdr, f.name) != default)
                        @field(hdr, f.name) = @field(new_hdr, f.name);
                },
                []const u8 => {
                    // verify all []const u8 field defaults == ""
                    const default = comptime fieldDefault(f);
                    comptime assert(default.len == 0);
                    if (@field(new_hdr, f.name).len != 0)
                        @field(hdr, f.name) = @field(new_hdr, f.name);
                },
                // skip pax_recs which is only used for testing.
                // NOTE: don't try to get fieldDefault() of this field which
                // is void in non-testing modes. it will error with
                // 'error: alignment must be >= 1'.
                []const []const u8, void => assert(mem.eql(u8, f.name, "pax_recs")),
                FormatSet => {
                    const default = comptime fieldDefault(f);
                    comptime assert(default.eql(FormatSet.initEmpty()));
                    if (!@field(new_hdr, f.name).eql(default))
                        @field(hdr, f.name) = @field(new_hdr, f.name);
                },
                else => @compileLog(comptime fmt.comptimePrint("todo {s}", .{@typeName(f.type)})),
            }
        }
    }
};

pub fn unixTime(tv_sec: i64, tv_nsec: i64) !i128 {
    const result = @bitCast(i128, [_]i64{
        try math.mul(i64, tv_sec, time.ns_per_s),
        tv_nsec,
    });
    return result;
}

pub const block_len = 512;
pub const Block = *[block_len]u8;

const V7Header = extern struct {
    file_name: [100]u8, // 0..100
    mode: [8]u8, // 100..108
    uid: [8]u8, // 108..116
    gid: [8]u8, // 116..124
    size: [12]u8, // 124..136
    mod_time: [12]u8, // 136..148
    checksum: [8]u8, // 148..156
    type: FileType, // 156..157
    linked_file_name: [100]u8, // 157..257
    __padding: [255]u8,

    comptime {
        assert(@sizeOf(V7Header) == block_len);
    }

    /// Returns an (unsigned, signed) pair of checksums for the header block.
    /// POSIX specifies a sum of the unsigned byte values, but the Sun tar used
    /// signed byte values.
    /// We compute and return both.
    fn computeChecksum(h: *const V7Header) [2]i64 {
        var unsigned: i64 = 0;
        var signed: i64 = 0;
        const bytes_ = h.bytes();
        for (bytes_, 0..) |_, i| {
            const c = if (148 <= i and i < 156)
                ' ' // Treat the checksum field itself as all spaces.
            else
                bytes_[i];
            unsigned += c;
            signed += @bitCast(i8, c);
        }
        return .{ unsigned, signed };
    }

    inline fn ustar(h: *const V7Header) *const UstarHeader {
        return @ptrCast(*const UstarHeader, h);
    }
    inline fn star(h: *const V7Header) *const StarHeader {
        return @ptrCast(*const StarHeader, h);
    }
    inline fn gnu(h: *const V7Header) *const GnuHeader {
        return @ptrCast(*const GnuHeader, h);
    }
    inline fn bytes(h: *const V7Header) *const [block_len]u8 {
        return @ptrCast(*const [block_len]u8, h);
    }

    // Magics used to identify various formats.
    const magic_gnu = "ustar ";
    const version_gnu = " \x00";
    const magic_version_gnu = mem.readIntBig(u64, magic_gnu ++ version_gnu);
    const magic_ustar = @truncate(u48, mem.readIntBig(u64, "ustar\x00\x00\x00") >> 16);
    const version_ustar = "00"; // unused. left only for documentation
    const trailer_star = mem.readIntBig(u32, "tar\x00");

    fn getFormat(h: *const V7Header) !FormatSet {
        const value = try parseOctal(&h.checksum);
        const checksums = h.computeChecksum();
        if (value != checksums[0] and value != checksums[1])
            return fmt_unknown;

        const magic_version = h.ustar().magicVersion();
        const magic = @truncate(u48, magic_version >> 16);

        return if (magic == magic_ustar and
            mem.readIntBig(u32, &h.star().trailer) == trailer_star)
            fmt_star
        else if (magic == magic_ustar)
            // either ustar or pax is enough info. don't need to check version
            fmt_ustar_pax
        else if (magic_version == magic_version_gnu)
            fmt_gnu
        else
            fmt_v7;
    }
};

const V7HeaderDummy = [257]u8;

const UstarHeader = extern struct {
    v7_header: V7HeaderDummy,
    magic: [6]u8, // 257..263
    version: [2]u8, // 263..265
    user_name: [32]u8, // 265..297
    group_name: [32]u8, // 297..329
    dev_major: [8]u8, // 329..337
    dev_minor: [8]u8, // 337..345
    filename_prefix: [155]u8, // 345..500
    __padding: [12]u8,

    pub fn magicVersion(ustar: *const UstarHeader) u64 {
        return mem.readIntBig(u64, @ptrCast([*]const u8, &ustar.magic)[0..8]);
    }

    comptime {
        assert(@sizeOf(UstarHeader) == block_len);
    }
};

const StarHeader = extern struct {
    v7_header: V7HeaderDummy,
    magic: [6]u8, // 257..263
    version: [2]u8, // 263..265
    user_name: [32]u8, // 265..297
    group_name: [32]u8, // 297..329
    dev_major: [8]u8, // 329..337
    dev_minor: [8]u8, // 337..345
    filename_prefix: [131]u8, // 345..476
    access_time: [12]u8, // 476..488
    change_time: [12]u8, // 488..500
    __padding: [8]u8,
    trailer: [4]u8, // 508..512

    comptime {
        assert(@sizeOf(StarHeader) == block_len);
    }
};

const GnuHeader = extern struct {
    v7_header: V7HeaderDummy,
    magic: [6]u8, // 257..263
    version: [2]u8, // 263..265
    user_name: [32]u8, // 265..297
    group_name: [32]u8, // 297..329
    dev_major: [8]u8, // 329..337
    dev_minor: [8]u8, // 337..345
    access_time: [12]u8, // 345..357
    change_time: [12]u8, // 357..369
    __padding: [17]u8,
    sparse: [24 * 4 + 1]u8, // 386..483
    real_size: [12]u8, // 483..495
    __padding2: [17]u8,

    comptime {
        assert(@sizeOf(GnuHeader) == block_len);
    }
};

pub fn headerIterator(
    reader: anytype,
    buf: Block,
    allocator: mem.Allocator,
) HeaderIterator(@TypeOf(reader)) {
    return HeaderIterator(@TypeOf(reader)){
        .reader = reader,
        .buf = buf,
        .allocator = allocator,
    };
}

pub fn HeaderIterator(comptime Reader: type) type {
    return struct {
        reader: Reader,
        buf: Block,
        pax_buf: std.ArrayListUnmanaged(u8) = .{},
        name_buf: std.ArrayListUnmanaged(u8) = .{},
        linkname_buf: std.ArrayListUnmanaged(u8) = .{},
        allocator: mem.Allocator,

        const Self = @This();

        pub fn deinit(self: *Self) void {
            self.pax_buf.deinit(self.allocator);
            self.name_buf.deinit(self.allocator);
            self.linkname_buf.deinit(self.allocator);
        }

        /// iterates through the tar archive as if it is a series of
        /// files. Internally, the tar format often uses fake "files" to add meta
        /// data that describes the next file. These meta data "files" should not
        /// normally be visible to the outside. As such, this iterates through
        /// one or more "header files" until it finds a "normal file".
        pub fn next(self: *Self) !?Header {
            var gnu_long_name: []const u8 = "";
            var gnu_long_link: []const u8 = "";
            var format = fmt_ustar_pax_gnu;
            var hdr = Header{};
            var pax_hdr = Header{};

            while (true) {
                const v7 = try self.nextV7Header() orelse return null;
                hdr = try self.header(v7) orelse return null;

                format.setIntersection(hdr.fmt);
                log.debug("hdr={}", .{hdr});
                switch (hdr.type) {
                    .extended_header, .global_extended_header => {
                        format.setIntersection(fmt_pax);
                        var paxiter = self.paxIterator();
                        pax_hdr = .{};
                        while (try paxiter.next()) |kv|
                            try mergePax(kv, &pax_hdr);

                        if (hdr.type == .global_extended_header) {
                            var res = Header{
                                .name = hdr.name,
                                .type = hdr.type,
                                .fmt = format,
                            };
                            res.merge(pax_hdr);
                            return res;
                        }
                    },
                    .gnu_long_name => {
                        format.setIntersection(fmt_gnu);
                        gnu_long_name = mem.sliceTo(try self.readBlocks(
                            @intCast(usize, hdr.size),
                            &self.name_buf,
                        ), 0);
                    },
                    .gnu_long_link => {
                        format.setIntersection(fmt_gnu);
                        gnu_long_link = mem.sliceTo(try self.readBlocks(
                            @intCast(usize, hdr.size),
                            &self.linkname_buf,
                        ), 0);
                    },

                    else => {
                        hdr.merge(pax_hdr);
                        if (gnu_long_name.len > 0) hdr.name = gnu_long_name;
                        if (gnu_long_link.len > 0) hdr.linkname = gnu_long_link;
                        if (hdr.type == .normal2) {
                            hdr.type = if (mem.endsWith(u8, hdr.name, "/"))
                                .directory
                            else
                                .normal;
                        }

                        // Set the final guess at the format.
                        if (format.contains(.ustar) and format.contains(.pax))
                            format.setIntersection(fmt_ustar);

                        hdr.fmt = format;
                        return hdr;
                    },
                }
            }
            unreachable;
        }

        /// resets `outbuf` and then reads from `self.reader` into `outbuf`
        /// `size` (aligned forward to 512) bytes.  returns
        /// UnexpectedEndOfStream if less than 512 bytes are read during a read.
        // else returns `outbuf.items[0..size]`.
        fn readBlocks(
            self: *Self,
            size: usize,
            outbuf: *std.ArrayListUnmanaged(u8),
        ) ![]u8 {
            var want = mem.alignForward(usize, size, block_len);
            outbuf.items.len = 0;
            var w = outbuf.writer(self.allocator);
            var buf: [block_len]u8 = undefined;
            while (want > 0) {
                switch (try self.reader.read(&buf)) {
                    0 => break,
                    block_len => try w.writeAll(&buf),
                    else => return error.UnexpectedEndOfStream,
                }
                want -= block_len;
            }
            if (want != 0) return error.UnexpectedEndOfStream;
            return outbuf.items[0..@intCast(usize, size)];
        }

        inline fn v7Header(self: Self) *const V7Header {
            return @ptrCast(*const V7Header, self.buf);
        }

        /// Reads n bytes from reader. Returns the following depending on n:
        ///   0:    null
        ///   512:  V7Header. also, if v7.fileType() is an extended header,
        ///         reads contents into pax_buf
        ///   else: error.UnexpectedEndOfStream
        pub fn nextV7Header(self: *Self) !?*const V7Header {
            const amt = try self.reader.read(self.buf);
            return switch (amt) {
                0 => null,
                block_len => blk: {
                    const v7 = self.v7Header();
                    switch (v7.type) {
                        .global_extended_header, .extended_header => {
                            const size = math.cast(usize, try parseOctal(&v7.size)) orelse
                                return error.Header;
                            self.pax_buf.items = try self.readBlocks(size, &self.pax_buf);
                        },
                        else => {},
                    }
                    break :blk v7;
                },
                else => error.UnexpectedEndOfStream,
            };
        }

        pub fn paxIterator(self: *Self) PaxIterator {
            return .{ .bytes = self.pax_buf.items };
        }

        /// provides a forward only iterator over pax records. pax records have
        /// the format: 'len key=value'.  calling next() yields single
        /// (key, value) entry.
        pub const PaxIterator = struct {
            bytes: []const u8,

            pub fn next(self: *PaxIterator) !?[2][]const u8 {
                if (self.bytes.len == 0) return null;

                const nl = mem.indexOfScalar(u8, self.bytes, '\n') orelse
                    return null;
                const pax_record = self.bytes[0..nl];
                self.bytes = self.bytes[nl + 1 ..];
                if (pax_record.len == 0) return error.Header;
                const sp = mem.indexOfScalar(u8, pax_record, ' ') orelse
                    return error.Header;
                const len = try fmt.parseUnsigned(u32, pax_record[0..sp], 10);
                if (len > pax_record.len + 1 or sp + 2 > len) return error.Header;
                const rec = pax_record[sp + 1 .. len - 1];
                const eqidx = mem.indexOfScalar(u8, rec, '=') orelse
                    return error.Header;
                const key = rec[0..eqidx];
                const val = rec[eqidx + 1 ..];
                const kv = .{ key, val };
                if (!isValidPax(kv)) return error.Header;
                return kv;
            }

            fn hasNul(s: []const u8) bool {
                return mem.indexOfScalar(u8, s, 0) != null;
            }

            // reports whether the key-value pair is valid where each
            // record is formatted as:
            //  "%d %s=%s\n" % (size, key, value)
            //
            // Keys and values should be UTF-8, but the number of bad writers out there
            // forces us to be a more liberal.
            // Thus, we only reject string keys with NUL, and only reject NULs in values
            // for the PAX version of the USTAR string fields.
            // The key must not contain an '=' character.
            fn isValidPax(kv: [2][]const u8) bool {
                const map = std.ComptimeStringMap(void, .{
                    .{ Pax.path, {} },
                    .{ Pax.linkpath, {} },
                    .{ Pax.uname, {} },
                    .{ Pax.gname, {} },
                });

                const k = kv[0];
                const v = kv[1];
                return if (k.len == 0 or mem.indexOfScalar(u8, k, '=') != null)
                    false
                else if (map.get(k) != null)
                    !hasNul(v)
                else
                    !hasNul(k);
            }
        };

        fn allZeroes(self: Self) bool {
            return mem.allEqual(u8, self.buf, 0);
        }

        /// Populates and returns a validated header record
        /// Returns null when one of the following occurs:
        ///  * Exactly 0 bytes are read and EOF is hit.
        ///  * Exactly 1 block of zeros is read and EOF is hit.
        ///  * At least 2 blocks of zeros are read.
        pub fn header(
            self: *Self,
            v7: *const V7Header,
        ) !?Header {
            if (self.allZeroes()) {
                _ = try self.nextV7Header() orelse return null;
                if (self.allZeroes()) return null;
                return error.Header;
            }
            // Verify the header matches a known format.
            const format = try v7.getFormat();

            if (format.eql(fmt_unknown)) return error.Header;

            var hdr = Header{
                .type = v7.type,
                .name = mem.sliceTo(&v7.file_name, 0),
                .linkname = mem.sliceTo(&v7.linked_file_name, 0),
                .size = try parseNumeric(&v7.size),
                .mode = try parseNumeric(&v7.mode),
                .uid = math.cast(i32, try parseNumeric(&v7.uid)) orelse
                    return error.Header,
                .gid = math.cast(i32, try parseNumeric(&v7.gid)) orelse
                    return error.Header,
                .mtime = try unixTime(try parseNumeric(&v7.mod_time), 0),
            };

            var prefix: []const u8 = "";

            // Unpack format specific fields.
            if (format.bits.mask > fmt_v7.bits.mask) {
                const ustar = v7.ustar();
                hdr.uname = mem.sliceTo(&ustar.user_name, 0);
                hdr.gname = mem.sliceTo(&ustar.group_name, 0);
                hdr.dev_major = try parseNumeric(&ustar.dev_major);
                hdr.dev_minor = try parseNumeric(&ustar.dev_minor);

                if (format.intersectWith(fmt_ustar_pax).bits.mask != 0) {
                    hdr.fmt = format;

                    prefix = mem.sliceTo(&ustar.filename_prefix, 0);

                    // set format = unknown if self.buf has any non-ascii chars
                    for (self.buf) |c| {
                        if (!std.ascii.isASCII(c)) {
                            hdr.fmt = fmt_unknown;
                            break;
                        }
                    }

                    // Numeric fields must end in NUL
                    // set format = unknown if any numeric field isn't 0 terminated
                    const hasNull = struct {
                        fn func(s: []const u8) bool {
                            return s[s.len - 1] == 0;
                        }
                    }.func;
                    if (!(hasNull(&v7.size) and hasNull(&v7.mode) and
                        hasNull(&v7.uid) and hasNull(&v7.gid) and
                        hasNull(&v7.mod_time) and hasNull(&ustar.dev_major) and
                        hasNull(&ustar.dev_minor)))
                    {
                        hdr.fmt = fmt_unknown;
                    }
                } else if (format.contains(.star)) {
                    const star = v7.star();
                    prefix = mem.sliceTo(&star.filename_prefix, 0);
                    hdr.atime = try unixTime(try parseNumeric(&star.access_time), 0);
                    hdr.ctime = try unixTime(try parseNumeric(&star.change_time), 0);
                } else if (format.contains(.gnu)) {
                    hdr.fmt = format;
                    const gnu = v7.gnu();

                    if (gnu.access_time[0] != 0)
                        hdr.atime = try unixTime(try parseNumeric(&gnu.access_time), 0);

                    if (gnu.change_time[0] != 0)
                        hdr.ctime = try unixTime(try parseNumeric(&gnu.change_time), 0);
                }
                if (prefix.len > 0) {
                    self.name_buf.items.len = 0;
                    const w = self.name_buf.writer(self.allocator);
                    _ = try w.write(prefix);
                    try w.writeByte(fs.path.sep);
                    _ = try w.write(hdr.name);
                    // add null terminator after end
                    const len = self.name_buf.items.len;
                    try w.writeByte(0);
                    hdr.name = self.name_buf.items[0..len];
                }
            }
            return hdr;
        }
    };
}

const Pax = struct {
    const path = "path";
    const linkpath = "linkpath";
    const size = "size";
    const uid = "uid";
    const gid = "gid";
    const uname = "uname";
    const gname = "gname";
    const mtime = "mtime";
    const atime = "atime";
    const ctime = "ctime";

    const schily_xattr = "SCHILY.xattr.";

    // Keywords for GNU sparse files in a PAX extended header.
    const Gnu = struct {
        const sparse = "GNU.sparse.";
        const sparse_num_blocks = "GNU.sparse.numblocks";
        const sparse_offset = "GNU.sparse.offset";
        const sparse_num_bytes = "GNU.sparse.numbytes";
        const sparse_map = "GNU.sparse.map";
        const sparse_name = "GNU.sparse.name";
        const sparse_major = "GNU.sparse.major";
        const sparse_minor = "GNU.sparse.minor";
        const sparse_size = "GNU.sparse.size";
        const sparse_real_size = "GNU.sparse.realsize";
    };
};

/// return the most significant, 'top' half of the time as an i64
fn truncateTime(t: i128) i64 {
    return @truncate(i64, t >> 64);
}

const is_windows = builtin.os.tag == .windows;

fn setFileProperties(file: fs.File, header: Header, options: Options) !void {
    comptime assert(Header.fieldDefault(Header.structField(.atime)) == -1);
    comptime assert(Header.fieldDefault(Header.structField(.ctime)) == -1);
    // TODO not sure 'now' is correct if time is set to its default value. and
    // also, maybe this logic should be moved elsewhere. maybe 'fn header()'
    const atime = if (header.atime == -1) time.nanoTimestamp() else header.atime;
    const mtime = if (header.mtime == -1) time.nanoTimestamp() else header.mtime;
    if (is_windows)
        // workaround for 'panic: integer cast truncated bits' from
        // file.updateTimes()
        try file.updateTimes(truncateTime(atime), truncateTime(mtime))
    else
        try file.updateTimes(atime, mtime);

    if (options.mode_mode == .executable_bit_only) {
        if (std.fs.has_executable_bit) {
            // TODO - not sure using file.mode() is correct but it seems to
            //        match gnu tar behavior on linux while using
            //        header.mode does not
            const mode = try file.mode(); // header.mode
            var modebits = std.StaticBitSet(32){ .mask = @intCast(u32, mode) };
            // copy the user exe bit to the group and other exe bits
            // these bit indices count from the right:
            //   u   g   o
            //   rwx rwx rwx
            //   876_543_210
            // 0b000_000_000
            const has_owner_exe_bit = modebits.isSet(6);
            modebits.setValue(3, has_owner_exe_bit);
            modebits.setValue(0, has_owner_exe_bit);
            log.debug("mode old={o} new={o}", .{ mode, modebits.mask });
            try file.chmod(modebits.mask);
        }
    }
}

fn setDirProperties(dir: fs.Dir, header: Header, options: Options) !void {
    // FIXME: creating a File from a Dir.fs is incorrect on non-posix systems.
    // this is an attempt to re-use setFileProperties() that doesn't work on windows:
    //   return setFileProperties(fs.File{ .handle = dir.fd }, header, options);

    // TODO implement once https://github.com/ziglang/zig/issues/12377 is solved
    // see https://github.com/ziglang/zig/pull/15382#issuecomment-1519136452
    _ = options;
    _ = header;
    _ = dir;
}

fn makeOpenPath(dir: fs.Dir, sub_path: []const u8, header: Header, options: Options) !fs.Dir {
    var subdir = try dir.makeOpenPath(sub_path, .{});
    try setDirProperties(subdir, header, options);
    return subdir;
}

fn makeSymLink(dir: fs.Dir, target_path: []const u8, symlink_path: []const u8) !void {
    // handle dangling symlinks (where target_path doesn't yet exist) by setting
    // is_directory = false;
    const is_directory = blk: {
        const file = dir.openFile(target_path, .{}) catch |e| switch (e) {
            error.FileNotFound => break :blk false,
            else => return e,
        };
        defer file.close();
        const stat = try file.stat();
        break :blk stat.kind == .directory;
    };
    try dir.symLink(target_path, symlink_path, .{ .is_directory = is_directory });
}

pub const Options = struct {
    /// Number of directory levels to skip when extracting files.
    strip_components: u32 = 0,
    /// How to handle the "mode" property of files from within the tar file.
    mode_mode: ModeMode = .executable_bit_only,

    const ModeMode = enum {
        /// The mode from the tar file is completely ignored. Files are created
        /// with the default mode when creating files.
        ignore,
        /// The mode from the tar file is inspected for the owner executable bit
        /// only. This bit is copied to the group and other executable bits.
        /// Other bits of the mode are left as the default when creating files.
        executable_bit_only,
    };
};

/// reads tar file contents from `reader` and writes files to `dir`. `allocator`
/// used for potentially long file names when:
///   1. gnu_long_name or gnu_long_link are present
///   2. a prefixed filename is used
pub fn pipeToFileSystem(
    allocator: mem.Allocator,
    dir: fs.Dir,
    reader: anytype,
    options: Options,
) !void {
    var format = FormatSet.initMany(&.{ .ustar, .pax, .gnu });
    var buf: [block_len]u8 = undefined;
    var iter = headerIterator(reader, &buf, allocator);
    defer iter.deinit();

    while (try iter.next()) |header| {
        const file_name = try stripComponents(header.name, options.strip_components);
        log.info("pipeToFileSystem() header.type={?s} stripped file_name={s}", .{ header.type.tagName(), file_name });

        const must_validate_path = header.type.isNamedType();
        if (must_validate_path and file_name.len == 0)
            continue;
        // verify that the path doesn't contain NUL characters
        // TODO check for other other types of invalid paths
        //   see https://github.com/ziglang/zig/pull/15382#issuecomment-1532255834
        //   and https://github.com/ziglang/zig/pull/14533#issuecomment-1416888193
        if (must_validate_path and mem.indexOfScalar(u8, file_name, 0) != null)
            return error.InvalidCharacter;

        switch (header.type) {
            .directory => {
                var subdir = try makeOpenPath(dir, file_name, header, options);
                subdir.close();
            },
            .normal, .normal2 => {
                var file = try if (fs.path.dirname(file_name)) |sub_path| blk: {
                    var subdir = try makeOpenPath(dir, sub_path, header, options);
                    defer subdir.close();
                    const basename = file_name[sub_path.len + 1 ..];
                    break :blk subdir.createFile(basename, .{});
                } else dir.createFile(file_name, .{});
                defer file.close();
                const size = math.cast(usize, header.size) orelse
                    return error.Header;
                const want = mem.alignForward(usize, size, block_len);
                var lim_reader = std.io.limitedReader(reader, want);
                var bytes_left = size;
                while (true) {
                    const amt = try lim_reader.read(iter.buf);
                    switch (amt) {
                        0 => break,
                        block_len => {},
                        else => return error.UnexpectedEndOfStream,
                    }
                    _ = try file.write(iter.buf[0..@min(bytes_left, block_len)]);
                    bytes_left -|= block_len;
                }

                try setFileProperties(file, header, options);
            },
            .symbolic_link => {
                if (fs.path.dirname(file_name)) |sub_path| {
                    const basename = file_name[sub_path.len + 1 ..];
                    var subdir = try makeOpenPath(dir, sub_path, header, options);
                    defer subdir.close();
                    log.debug("sub_path={s} basename={s}", .{ sub_path, basename });
                    if (is_windows or builtin.os.tag == .wasi) {
                        // TODO - symlinks on windows / wasi. windows will fail unless run as admin
                    } else {
                        try makeSymLink(subdir, header.linkname, basename);
                    }
                } else {
                    if (is_windows or builtin.os.tag == .wasi) {
                        // TODO - symlinks on windows / wasi. windows will fail unless run as admin
                    } else {
                        try makeSymLink(dir, header.linkname, file_name);
                    }
                }
            },
            .hard_link => {
                if (fs.path.dirname(file_name)) |sub_path| {
                    const basename = file_name[sub_path.len + 1 ..];
                    var subdir = try makeOpenPath(dir, sub_path, header, options);
                    defer subdir.close();
                    try subdir.copyFile(header.linkname, subdir, basename, .{});
                } else {
                    try dir.copyFile(header.linkname, dir, file_name, .{});
                }
            },
            .global_extended_header, .extended_header => {
                format.setIntersection(fmt_pax);
            },
            else => {
                log.err("unsupported type '{?s}':{}", .{ header.type.tagName(), @intFromEnum(header.type) });
                return error.TarUnexpectedFileType;
            },
        }
    }
}

fn stripComponents(path: []const u8, count: u32) ![]const u8 {
    var i: usize = 0;
    var c = count;
    while (c > 0) : (c -= 1) {
        if (mem.indexOfScalarPos(u8, path, i, '/')) |pos| {
            i = pos + 1;
        } else {
            log.err("stripComponents() invalid path={s} with count={}\n", .{ path, count });
            return error.TarComponentsOutsideStrippedPrefix;
        }
    }
    return path[i..];
}

test stripComponents {
    const expectEqualStrings = std.testing.expectEqualStrings;
    try expectEqualStrings("a/b/c", try stripComponents("a/b/c", 0));
    try expectEqualStrings("b/c", try stripComponents("a/b/c", 1));
    try expectEqualStrings("c", try stripComponents("a/b/c", 2));
}

const std = @import("std");
const assert = std.debug.assert;
const mem = std.mem;
const fs = std.fs;
const fmt = std.fmt;
const log = std.log;
const time = std.time;
const math = std.math;
const builtin = @import("builtin");

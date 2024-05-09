const std = @import("std");
const rc = @import("rc.zig");
const Resource = rc.Resource;
const CommonResourceAttributes = rc.CommonResourceAttributes;
const Allocator = std.mem.Allocator;
const windows1252 = @import("windows1252.zig");
const CodePage = @import("code_pages.zig").CodePage;
const literals = @import("literals.zig");
const SourceBytes = literals.SourceBytes;
const Codepoint = @import("code_pages.zig").Codepoint;
const lang = @import("lang.zig");
const isNonAsciiDigit = @import("utils.zig").isNonAsciiDigit;

/// https://learn.microsoft.com/en-us/windows/win32/menurc/resource-types
pub const RT = enum(u8) {
    ACCELERATOR = 9,
    ANICURSOR = 21,
    ANIICON = 22,
    BITMAP = 2,
    CURSOR = 1,
    DIALOG = 5,
    DLGINCLUDE = 17,
    DLGINIT = 240,
    FONT = 8,
    FONTDIR = 7,
    GROUP_CURSOR = 1 + 11, // CURSOR + 11
    GROUP_ICON = 3 + 11, // ICON + 11
    HTML = 23,
    ICON = 3,
    MANIFEST = 24,
    MENU = 4,
    MESSAGETABLE = 11,
    PLUGPLAY = 19,
    RCDATA = 10,
    STRING = 6,
    TOOLBAR = 241,
    VERSION = 16,
    VXD = 20,
    _,

    /// Returns null if the resource type is user-defined
    /// Asserts that the resource is not `stringtable`
    pub fn fromResource(resource: Resource) ?RT {
        return switch (resource) {
            .accelerators => .ACCELERATOR,
            .bitmap => .BITMAP,
            .cursor => .GROUP_CURSOR,
            .dialog => .DIALOG,
            .dialogex => .DIALOG,
            .dlginclude => .DLGINCLUDE,
            .dlginit => .DLGINIT,
            .font => .FONT,
            .html => .HTML,
            .icon => .GROUP_ICON,
            .menu => .MENU,
            .menuex => .MENU,
            .messagetable => .MESSAGETABLE,
            .plugplay => .PLUGPLAY,
            .rcdata => .RCDATA,
            .stringtable => unreachable,
            .toolbar => .TOOLBAR,
            .user_defined => null,
            .versioninfo => .VERSION,
            .vxd => .VXD,

            .cursor_num => .CURSOR,
            .icon_num => .ICON,
            .string_num => .STRING,
            .anicursor_num => .ANICURSOR,
            .aniicon_num => .ANIICON,
            .fontdir_num => .FONTDIR,
            .manifest_num => .MANIFEST,
        };
    }
};

/// https://learn.microsoft.com/en-us/windows/win32/menurc/common-resource-attributes
/// https://learn.microsoft.com/en-us/windows/win32/menurc/resourceheader
pub const MemoryFlags = packed struct(u16) {
    value: u16,

    pub const MOVEABLE: u16 = 0x10;
    // TODO: SHARED and PURE seem to be the same thing? Testing seems to confirm this but
    //       would like to find mention of it somewhere.
    pub const SHARED: u16 = 0x20;
    pub const PURE: u16 = 0x20;
    pub const PRELOAD: u16 = 0x40;
    pub const DISCARDABLE: u16 = 0x1000;

    /// Note: The defaults can have combinations that are not possible to specify within
    ///       an .rc file, as the .rc attributes imply other values (i.e. specifying
    ///       DISCARDABLE always implies MOVEABLE and PURE/SHARED, and yet RT_ICON
    ///       has a default of only MOVEABLE | DISCARDABLE).
    pub fn defaults(predefined_resource_type: ?RT) MemoryFlags {
        if (predefined_resource_type == null) {
            return MemoryFlags{ .value = MOVEABLE | SHARED };
        } else {
            return switch (predefined_resource_type.?) {
                // zig fmt: off
                .RCDATA, .BITMAP, .HTML, .MANIFEST,
                .ACCELERATOR, .VERSION, .MESSAGETABLE,
                .DLGINIT, .TOOLBAR, .PLUGPLAY,
                .VXD, => MemoryFlags{ .value = MOVEABLE | SHARED },

                .GROUP_ICON, .GROUP_CURSOR,
                .STRING, .FONT, .DIALOG, .MENU,
                .DLGINCLUDE, => MemoryFlags{ .value = MOVEABLE | SHARED | DISCARDABLE },

                .ICON, .CURSOR, .ANIICON, .ANICURSOR => MemoryFlags{ .value = MOVEABLE | DISCARDABLE },
                .FONTDIR => MemoryFlags{ .value = MOVEABLE | PRELOAD },
                // zig fmt: on
                // Same as predefined_resource_type == null
                _ => return MemoryFlags{ .value = MOVEABLE | SHARED },
            };
        }
    }

    pub fn set(self: *MemoryFlags, attribute: CommonResourceAttributes) void {
        switch (attribute) {
            .preload => self.value |= PRELOAD,
            .loadoncall => self.value &= ~PRELOAD,
            .moveable => self.value |= MOVEABLE,
            .fixed => self.value &= ~(MOVEABLE | DISCARDABLE),
            .shared => self.value |= SHARED,
            .nonshared => self.value &= ~(SHARED | DISCARDABLE),
            .pure => self.value |= PURE,
            .impure => self.value &= ~(PURE | DISCARDABLE),
            .discardable => self.value |= DISCARDABLE | MOVEABLE | PURE,
        }
    }

    pub fn setGroup(self: *MemoryFlags, attribute: CommonResourceAttributes, implied_shared_or_pure: bool) void {
        switch (attribute) {
            .preload => {
                self.value |= PRELOAD;
                if (implied_shared_or_pure) self.value &= ~SHARED;
            },
            .loadoncall => {
                self.value &= ~PRELOAD;
                if (implied_shared_or_pure) self.value |= SHARED;
            },
            else => self.set(attribute),
        }
    }
};

/// https://learn.microsoft.com/en-us/windows/win32/intl/language-identifiers
pub const Language = packed struct(u16) {
    // Note: This is the default no matter what locale the current system is set to,
    //       e.g. even if the system's locale is en-GB, en-US will still be the
    //       default language for resources in the Win32 rc compiler.
    primary_language_id: u10 = lang.LANG_ENGLISH,
    sublanguage_id: u6 = lang.SUBLANG_ENGLISH_US,

    /// Default language ID as a u16
    pub const default: u16 = (Language{}).asInt();

    pub fn fromInt(int: u16) Language {
        return @bitCast(int);
    }

    pub fn asInt(self: Language) u16 {
        return @bitCast(self);
    }
};

/// https://learn.microsoft.com/en-us/windows/win32/api/winuser/ns-winuser-dlgitemtemplate#remarks
pub const ControlClass = enum(u16) {
    button = 0x80,
    edit = 0x81,
    static = 0x82,
    listbox = 0x83,
    scrollbar = 0x84,
    combobox = 0x85,

    pub fn fromControl(control: rc.Control) ?ControlClass {
        return switch (control) {
            // zig fmt: off
            .auto3state, .autocheckbox, .autoradiobutton,
            .checkbox, .defpushbutton, .groupbox, .pushbox,
            .pushbutton, .radiobutton, .state3, .userbutton => .button,
            // zig fmt: on
            .combobox => .combobox,
            .control => null,
            .ctext, .icon, .ltext, .rtext => .static,
            .edittext, .hedit, .iedit => .edit,
            .listbox => .listbox,
            .scrollbar => .scrollbar,
        };
    }

    pub fn getImpliedStyle(control: rc.Control) u32 {
        var style = WS.CHILD | WS.VISIBLE;
        switch (control) {
            .auto3state => style |= BS.AUTO3STATE | WS.TABSTOP,
            .autocheckbox => style |= BS.AUTOCHECKBOX | WS.TABSTOP,
            .autoradiobutton => style |= BS.AUTORADIOBUTTON,
            .checkbox => style |= BS.CHECKBOX | WS.TABSTOP,
            .combobox => {},
            .control => {},
            .ctext => style |= SS.CENTER | WS.GROUP,
            .defpushbutton => style |= BS.DEFPUSHBUTTON | WS.TABSTOP,
            .edittext, .hedit, .iedit => style |= WS.TABSTOP | WS.BORDER,
            .groupbox => style |= BS.GROUPBOX,
            .icon => style |= SS.ICON,
            .listbox => style |= LBS.NOTIFY | WS.BORDER,
            .ltext => style |= WS.GROUP,
            .pushbox => style |= BS.PUSHBOX | WS.TABSTOP,
            .pushbutton => style |= WS.TABSTOP,
            .radiobutton => style |= BS.RADIOBUTTON,
            .rtext => style |= SS.RIGHT | WS.GROUP,
            .scrollbar => {},
            .state3 => style |= BS.@"3STATE" | WS.TABSTOP,
            .userbutton => style |= BS.USERBUTTON | WS.TABSTOP,
        }
        return style;
    }
};

pub const NameOrOrdinal = union(enum) {
    // UTF-16 LE
    name: [:0]const u16,
    ordinal: u16,

    pub fn deinit(self: NameOrOrdinal, allocator: Allocator) void {
        switch (self) {
            .name => |name| {
                allocator.free(name);
            },
            .ordinal => {},
        }
    }

    /// Returns the full length of the amount of bytes that would be written by `write`
    /// (e.g. for an ordinal it will return the length including the 0xFFFF indicator)
    pub fn byteLen(self: NameOrOrdinal) usize {
        switch (self) {
            .name => |name| {
                // + 1 for 0-terminated
                return (name.len + 1) * @sizeOf(u16);
            },
            .ordinal => return 4,
        }
    }

    pub fn write(self: NameOrOrdinal, writer: anytype) !void {
        switch (self) {
            .name => |name| {
                try writer.writeAll(std.mem.sliceAsBytes(name[0 .. name.len + 1]));
            },
            .ordinal => |ordinal| {
                try writer.writeInt(u16, 0xffff, .little);
                try writer.writeInt(u16, ordinal, .little);
            },
        }
    }

    pub fn writeEmpty(writer: anytype) !void {
        try writer.writeInt(u16, 0, .little);
    }

    pub fn fromString(allocator: Allocator, bytes: SourceBytes) !NameOrOrdinal {
        if (maybeOrdinalFromString(bytes)) |ordinal| {
            return ordinal;
        }
        return nameFromString(allocator, bytes);
    }

    pub fn nameFromString(allocator: Allocator, bytes: SourceBytes) !NameOrOrdinal {
        // Names have a limit of 256 UTF-16 code units + null terminator
        var buf = try std.ArrayList(u16).initCapacity(allocator, @min(257, bytes.slice.len));
        errdefer buf.deinit();

        var i: usize = 0;
        while (bytes.code_page.codepointAt(i, bytes.slice)) |codepoint| : (i += codepoint.byte_len) {
            if (buf.items.len == 256) break;

            const c = codepoint.value;
            if (c == Codepoint.invalid) {
                try buf.append(std.mem.nativeToLittle(u16, '�'));
            } else if (c < 0x7F) {
                // ASCII chars in names are always converted to uppercase
                try buf.append(std.mem.nativeToLittle(u16, std.ascii.toUpper(@intCast(c))));
            } else if (c < 0x10000) {
                const short: u16 = @intCast(c);
                try buf.append(std.mem.nativeToLittle(u16, short));
            } else {
                const high = @as(u16, @intCast((c - 0x10000) >> 10)) + 0xD800;
                try buf.append(std.mem.nativeToLittle(u16, high));

                // Note: This can cut-off in the middle of a UTF-16 surrogate pair,
                //       i.e. it can make the string end with an unpaired high surrogate
                if (buf.items.len == 256) break;

                const low = @as(u16, @intCast(c & 0x3FF)) + 0xDC00;
                try buf.append(std.mem.nativeToLittle(u16, low));
            }
        }

        return NameOrOrdinal{ .name = try buf.toOwnedSliceSentinel(0) };
    }

    /// Returns `null` if the bytes do not form a valid number.
    /// Does not allow non-ASCII digits (which the Win32 RC compiler does allow
    /// in base 10 numbers, see `maybeNonAsciiOrdinalFromString`).
    pub fn maybeOrdinalFromString(bytes: SourceBytes) ?NameOrOrdinal {
        var buf = bytes.slice;
        var radix: u8 = 10;
        if (buf.len > 2 and buf[0] == '0') {
            switch (buf[1]) {
                '0'...'9' => {},
                'x', 'X' => {
                    radix = 16;
                    buf = buf[2..];
                    // only the first 4 hex digits matter, anything else is ignored
                    // i.e. 0x12345 is treated as if it were 0x1234
                    buf.len = @min(buf.len, 4);
                },
                else => return null,
            }
        }

        var i: usize = 0;
        var result: u16 = 0;
        while (bytes.code_page.codepointAt(i, buf)) |codepoint| : (i += codepoint.byte_len) {
            const c = codepoint.value;
            const digit: u8 = switch (c) {
                0x00...0x7F => std.fmt.charToDigit(@intCast(c), radix) catch switch (radix) {
                    10 => return null,
                    // non-hex-digits are treated as a terminator rather than invalidating
                    // the number (note: if there are no valid hex digits then the result
                    // will be zero which is not treated as a valid number)
                    16 => break,
                    else => unreachable,
                },
                else => if (radix == 10) return null else break,
            };

            if (result != 0) {
                result *%= radix;
            }
            result +%= digit;
        }

        // Anything that resolves to zero is not interpretted as a number
        if (result == 0) return null;
        return NameOrOrdinal{ .ordinal = result };
    }

    /// The Win32 RC compiler uses `iswdigit` for digit detection for base 10
    /// numbers, which means that non-ASCII digits are 'accepted' but handled
    /// in a totally unintuitive manner, leading to arbitrary results.
    ///
    /// This function will return the value that such an ordinal 'would' have
    /// if it was run through the Win32 RC compiler. This allows us to disallow
    /// non-ASCII digits in number literals but still detect when the Win32
    /// RC compiler would have allowed them, so that a proper warning/error
    /// can be emitted.
    pub fn maybeNonAsciiOrdinalFromString(bytes: SourceBytes) ?NameOrOrdinal {
        const buf = bytes.slice;
        const radix = 10;
        if (buf.len > 2 and buf[0] == '0') {
            switch (buf[1]) {
                // We only care about base 10 numbers here
                'x', 'X' => return null,
                else => {},
            }
        }

        var i: usize = 0;
        var result: u16 = 0;
        while (bytes.code_page.codepointAt(i, buf)) |codepoint| : (i += codepoint.byte_len) {
            const c = codepoint.value;
            const digit: u16 = digit: {
                const is_digit = (c >= '0' and c <= '9') or isNonAsciiDigit(c);
                if (!is_digit) return null;
                break :digit @intCast(c - '0');
            };

            if (result != 0) {
                result *%= radix;
            }
            result +%= digit;
        }

        // Anything that resolves to zero is not interpretted as a number
        if (result == 0) return null;
        return NameOrOrdinal{ .ordinal = result };
    }

    pub fn predefinedResourceType(self: NameOrOrdinal) ?RT {
        switch (self) {
            .ordinal => |ordinal| {
                if (ordinal >= 256) return null;
                switch (@as(RT, @enumFromInt(ordinal))) {
                    .ACCELERATOR,
                    .ANICURSOR,
                    .ANIICON,
                    .BITMAP,
                    .CURSOR,
                    .DIALOG,
                    .DLGINCLUDE,
                    .DLGINIT,
                    .FONT,
                    .FONTDIR,
                    .GROUP_CURSOR,
                    .GROUP_ICON,
                    .HTML,
                    .ICON,
                    .MANIFEST,
                    .MENU,
                    .MESSAGETABLE,
                    .PLUGPLAY,
                    .RCDATA,
                    .STRING,
                    .TOOLBAR,
                    .VERSION,
                    .VXD,
                    => |rt| return rt,
                    _ => return null,
                }
            },
            .name => return null,
        }
    }
};

fn expectNameOrOrdinal(expected: NameOrOrdinal, actual: NameOrOrdinal) !void {
    switch (expected) {
        .name => {
            if (actual != .name) return error.TestExpectedEqual;
            try std.testing.expectEqualSlices(u16, expected.name, actual.name);
        },
        .ordinal => {
            if (actual != .ordinal) return error.TestExpectedEqual;
            try std.testing.expectEqual(expected.ordinal, actual.ordinal);
        },
    }
}

test "NameOrOrdinal" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    // zero is treated as a string
    try expectNameOrOrdinal(
        NameOrOrdinal{ .name = std.unicode.utf8ToUtf16LeStringLiteral("0") },
        try NameOrOrdinal.fromString(allocator, .{ .slice = "0", .code_page = .windows1252 }),
    );
    // any non-digit byte invalidates the number
    try expectNameOrOrdinal(
        NameOrOrdinal{ .name = std.unicode.utf8ToUtf16LeStringLiteral("1A") },
        try NameOrOrdinal.fromString(allocator, .{ .slice = "1a", .code_page = .windows1252 }),
    );
    try expectNameOrOrdinal(
        NameOrOrdinal{ .name = std.unicode.utf8ToUtf16LeStringLiteral("1ÿ") },
        try NameOrOrdinal.fromString(allocator, .{ .slice = "1\xff", .code_page = .windows1252 }),
    );
    try expectNameOrOrdinal(
        NameOrOrdinal{ .name = std.unicode.utf8ToUtf16LeStringLiteral("1€") },
        try NameOrOrdinal.fromString(allocator, .{ .slice = "1€", .code_page = .utf8 }),
    );
    try expectNameOrOrdinal(
        NameOrOrdinal{ .name = std.unicode.utf8ToUtf16LeStringLiteral("1�") },
        try NameOrOrdinal.fromString(allocator, .{ .slice = "1\x80", .code_page = .utf8 }),
    );
    // same with overflow that resolves to 0
    try expectNameOrOrdinal(
        NameOrOrdinal{ .name = std.unicode.utf8ToUtf16LeStringLiteral("65536") },
        try NameOrOrdinal.fromString(allocator, .{ .slice = "65536", .code_page = .windows1252 }),
    );
    // hex zero is also treated as a string
    try expectNameOrOrdinal(
        NameOrOrdinal{ .name = std.unicode.utf8ToUtf16LeStringLiteral("0X0") },
        try NameOrOrdinal.fromString(allocator, .{ .slice = "0x0", .code_page = .windows1252 }),
    );
    // hex numbers work
    try expectNameOrOrdinal(
        NameOrOrdinal{ .ordinal = 0x100 },
        try NameOrOrdinal.fromString(allocator, .{ .slice = "0x100", .code_page = .windows1252 }),
    );
    // only the first 4 hex digits matter
    try expectNameOrOrdinal(
        NameOrOrdinal{ .ordinal = 0x1234 },
        try NameOrOrdinal.fromString(allocator, .{ .slice = "0X12345", .code_page = .windows1252 }),
    );
    // octal is not supported so it gets treated as a string
    try expectNameOrOrdinal(
        NameOrOrdinal{ .name = std.unicode.utf8ToUtf16LeStringLiteral("0O1234") },
        try NameOrOrdinal.fromString(allocator, .{ .slice = "0o1234", .code_page = .windows1252 }),
    );
    // overflow wraps
    try expectNameOrOrdinal(
        NameOrOrdinal{ .ordinal = @truncate(65635) },
        try NameOrOrdinal.fromString(allocator, .{ .slice = "65635", .code_page = .windows1252 }),
    );
    // non-hex-digits in a hex literal are treated as a terminator
    try expectNameOrOrdinal(
        NameOrOrdinal{ .ordinal = 0x4 },
        try NameOrOrdinal.fromString(allocator, .{ .slice = "0x4n", .code_page = .windows1252 }),
    );
    try expectNameOrOrdinal(
        NameOrOrdinal{ .ordinal = 0xFA },
        try NameOrOrdinal.fromString(allocator, .{ .slice = "0xFAZ92348", .code_page = .windows1252 }),
    );
    // 0 at the start is allowed
    try expectNameOrOrdinal(
        NameOrOrdinal{ .ordinal = 50 },
        try NameOrOrdinal.fromString(allocator, .{ .slice = "050", .code_page = .windows1252 }),
    );
    // limit of 256 UTF-16 code units, can cut off between a surrogate pair
    {
        var expected = blk: {
            // the input before the 𐐷 character, but uppercased
            const expected_u8_bytes = "00614982008907933748980730280674788429543776231864944218790698304852300002973622122844631429099469274282385299397783838528QFFL7SHNSIETG0QKLR1UYPBTUV1PMFQRRA0VJDG354GQEDJMUPGPP1W1EXVNTZVEIZ6K3IPQM1AWGEYALMEODYVEZGOD3MFMGEY8FNR4JUETTB1PZDEWSNDRGZUA8SNXP3NGO";
            var buf: [256:0]u16 = undefined;
            for (expected_u8_bytes, 0..) |byte, i| {
                buf[i] = std.mem.nativeToLittle(u16, byte);
            }
            // surrogate pair that is now orphaned
            buf[255] = std.mem.nativeToLittle(u16, 0xD801);
            break :blk buf;
        };
        try expectNameOrOrdinal(
            NameOrOrdinal{ .name = &expected },
            try NameOrOrdinal.fromString(allocator, .{
                .slice = "00614982008907933748980730280674788429543776231864944218790698304852300002973622122844631429099469274282385299397783838528qffL7ShnSIETg0qkLr1UYpbtuv1PMFQRRa0VjDG354GQedJmUPgpp1w1ExVnTzVEiz6K3iPqM1AWGeYALmeODyvEZGOD3MfmGey8fnR4jUeTtB1PzdeWsNDrGzuA8Snxp3NGO𐐷",
                .code_page = .utf8,
            }),
        );
    }
}

test "NameOrOrdinal code page awareness" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    try expectNameOrOrdinal(
        NameOrOrdinal{ .name = std.unicode.utf8ToUtf16LeStringLiteral("��𐐷") },
        try NameOrOrdinal.fromString(allocator, .{
            .slice = "\xF0\x80\x80𐐷",
            .code_page = .utf8,
        }),
    );
    try expectNameOrOrdinal(
        // The UTF-8 representation of 𐐷 is 0xF0 0x90 0x90 0xB7. In order to provide valid
        // UTF-8 to utf8ToUtf16LeStringLiteral, it uses the UTF-8 representation of the codepoint
        // <U+0x90> which is 0xC2 0x90. The code units in the expected UTF-16 string are:
        // { 0x00F0, 0x20AC, 0x20AC, 0x00F0, 0x0090, 0x0090, 0x00B7 }
        NameOrOrdinal{ .name = std.unicode.utf8ToUtf16LeStringLiteral("ð€€ð\xC2\x90\xC2\x90·") },
        try NameOrOrdinal.fromString(allocator, .{
            .slice = "\xF0\x80\x80𐐷",
            .code_page = .windows1252,
        }),
    );
}

/// https://learn.microsoft.com/en-us/windows/win32/api/winuser/ns-winuser-accel#members
/// https://devblogs.microsoft.com/oldnewthing/20070316-00/?p=27593
pub const AcceleratorModifiers = struct {
    value: u8 = 0,
    explicit_ascii_or_virtkey: bool = false,

    pub const ASCII = 0;
    pub const VIRTKEY = 1;
    pub const NOINVERT = 1 << 1;
    pub const SHIFT = 1 << 2;
    pub const CONTROL = 1 << 3;
    pub const ALT = 1 << 4;
    /// Marker for the last accelerator in an accelerator table
    pub const last_accelerator_in_table = 1 << 7;

    pub fn apply(self: *AcceleratorModifiers, modifier: rc.AcceleratorTypeAndOptions) void {
        if (modifier == .ascii or modifier == .virtkey) self.explicit_ascii_or_virtkey = true;
        self.value |= modifierValue(modifier);
    }

    pub fn isSet(self: AcceleratorModifiers, modifier: rc.AcceleratorTypeAndOptions) bool {
        // ASCII is set whenever VIRTKEY is not
        if (modifier == .ascii) return self.value & modifierValue(.virtkey) == 0;
        return self.value & modifierValue(modifier) != 0;
    }

    fn modifierValue(modifier: rc.AcceleratorTypeAndOptions) u8 {
        return switch (modifier) {
            .ascii => ASCII,
            .virtkey => VIRTKEY,
            .noinvert => NOINVERT,
            .shift => SHIFT,
            .control => CONTROL,
            .alt => ALT,
        };
    }

    pub fn markLast(self: *AcceleratorModifiers) void {
        self.value |= last_accelerator_in_table;
    }
};

const AcceleratorKeyCodepointTranslator = struct {
    string_type: literals.StringType,

    pub fn translate(self: @This(), maybe_parsed: ?literals.IterativeStringParser.ParsedCodepoint) ?u21 {
        const parsed = maybe_parsed orelse return null;
        if (parsed.codepoint == Codepoint.invalid) return 0xFFFD;
        if (parsed.from_escaped_integer and self.string_type == .ascii) {
            return windows1252.toCodepoint(@truncate(parsed.codepoint));
        }
        return parsed.codepoint;
    }
};

pub const ParseAcceleratorKeyStringError = error{ EmptyAccelerator, AcceleratorTooLong, InvalidControlCharacter, ControlCharacterOutOfRange };

/// Expects bytes to be the full bytes of a string literal token (e.g. including the "" or L"").
pub fn parseAcceleratorKeyString(bytes: SourceBytes, is_virt: bool, options: literals.StringParseOptions) (ParseAcceleratorKeyStringError || Allocator.Error)!u16 {
    if (bytes.slice.len == 0) {
        return error.EmptyAccelerator;
    }

    var parser = literals.IterativeStringParser.init(bytes, options);
    var translator = AcceleratorKeyCodepointTranslator{ .string_type = parser.declared_string_type };

    const first_codepoint = translator.translate(try parser.next()) orelse return error.EmptyAccelerator;
    // 0 is treated as a terminator, so this is equivalent to an empty string
    if (first_codepoint == 0) return error.EmptyAccelerator;

    if (first_codepoint == '^') {
        // Note: Emitting this warning unconditonally whenever ^ is the first character
        //       matches the Win32 RC behavior, but it's questionable whether or not
        //       the warning should be emitted for ^^ since that results in the ASCII
        //       character ^ being written to the .res.
        if (is_virt and options.diagnostics != null) {
            try options.diagnostics.?.diagnostics.append(.{
                .err = .ascii_character_not_equivalent_to_virtual_key_code,
                .type = .warning,
                .token = options.diagnostics.?.token,
            });
        }

        const c = translator.translate(try parser.next()) orelse return error.InvalidControlCharacter;
        switch (c) {
            '^' => return '^', // special case
            'a'...'z', 'A'...'Z' => return std.ascii.toUpper(@intCast(c)) - 0x40,
            // Note: The Windows RC compiler allows more than just A-Z, but what it allows
            //       seems to be tied to some sort of Unicode-aware 'is character' function or something.
            //       The full list of codepoints that trigger an out-of-range error can be found here:
            //       https://gist.github.com/squeek502/2e9d0a4728a83eed074ad9785a209fd0
            //       For codepoints >= 0x80 that don't trigger the error, the Windows RC compiler takes the
            //       codepoint and does the `- 0x40` transformation as if it were A-Z which couldn't lead
            //       to anything useable, so there's no point in emulating that behavior--erroring for
            //       all non-[a-zA-Z] makes much more sense and is what was probably intended by the
            //       Windows RC compiler.
            else => return error.ControlCharacterOutOfRange,
        }
        @compileError("this should be unreachable");
    }

    const second_codepoint = translator.translate(try parser.next());

    var result: u32 = initial_value: {
        if (first_codepoint >= 0x10000) {
            if (second_codepoint != null and second_codepoint.? != 0) return error.AcceleratorTooLong;
            // No idea why it works this way, but this seems to match the Windows RC
            // behavior for codepoints >= 0x10000
            const low = @as(u16, @intCast(first_codepoint & 0x3FF)) + 0xDC00;
            const extra = (first_codepoint - 0x10000) / 0x400;
            break :initial_value low + extra * 0x100;
        }
        break :initial_value first_codepoint;
    };

    // 0 is treated as a terminator
    if (second_codepoint != null and second_codepoint.? == 0) return @truncate(result);

    const third_codepoint = translator.translate(try parser.next());
    // 0 is treated as a terminator, so a 0 in the third position is fine but
    // anything else is too many codepoints for an accelerator
    if (third_codepoint != null and third_codepoint.? != 0) return error.AcceleratorTooLong;

    if (second_codepoint) |c| {
        if (c >= 0x10000) return error.AcceleratorTooLong;
        result <<= 8;
        result += c;
    } else if (is_virt) {
        switch (result) {
            'a'...'z' => result -= 0x20, // toUpper
            else => {},
        }
    }
    return @truncate(result);
}

test "accelerator keys" {
    try std.testing.expectEqual(@as(u16, 1), try parseAcceleratorKeyString(
        .{ .slice = "\"^a\"", .code_page = .windows1252 },
        false,
        .{},
    ));
    try std.testing.expectEqual(@as(u16, 1), try parseAcceleratorKeyString(
        .{ .slice = "\"^A\"", .code_page = .windows1252 },
        false,
        .{},
    ));
    try std.testing.expectEqual(@as(u16, 26), try parseAcceleratorKeyString(
        .{ .slice = "\"^Z\"", .code_page = .windows1252 },
        false,
        .{},
    ));
    try std.testing.expectEqual(@as(u16, '^'), try parseAcceleratorKeyString(
        .{ .slice = "\"^^\"", .code_page = .windows1252 },
        false,
        .{},
    ));

    try std.testing.expectEqual(@as(u16, 'a'), try parseAcceleratorKeyString(
        .{ .slice = "\"a\"", .code_page = .windows1252 },
        false,
        .{},
    ));
    try std.testing.expectEqual(@as(u16, 0x6162), try parseAcceleratorKeyString(
        .{ .slice = "\"ab\"", .code_page = .windows1252 },
        false,
        .{},
    ));

    try std.testing.expectEqual(@as(u16, 'C'), try parseAcceleratorKeyString(
        .{ .slice = "\"c\"", .code_page = .windows1252 },
        true,
        .{},
    ));
    try std.testing.expectEqual(@as(u16, 0x6363), try parseAcceleratorKeyString(
        .{ .slice = "\"cc\"", .code_page = .windows1252 },
        true,
        .{},
    ));

    // \x00 or any escape that evaluates to zero acts as a terminator, everything past it
    // is ignored
    try std.testing.expectEqual(@as(u16, 'a'), try parseAcceleratorKeyString(
        .{ .slice = "\"a\\0bcdef\"", .code_page = .windows1252 },
        false,
        .{},
    ));

    // \x80 is € in Windows-1252, which is Unicode codepoint 20AC
    try std.testing.expectEqual(@as(u16, 0x20AC), try parseAcceleratorKeyString(
        .{ .slice = "\"\x80\"", .code_page = .windows1252 },
        false,
        .{},
    ));
    // This depends on the code page, though, with codepage 65001, \x80
    // on its own is invalid UTF-8 so it gets converted to the replacement character
    try std.testing.expectEqual(@as(u16, 0xFFFD), try parseAcceleratorKeyString(
        .{ .slice = "\"\x80\"", .code_page = .utf8 },
        false,
        .{},
    ));
    try std.testing.expectEqual(@as(u16, 0xCCAC), try parseAcceleratorKeyString(
        .{ .slice = "\"\x80\x80\"", .code_page = .windows1252 },
        false,
        .{},
    ));
    // This also behaves the same with escaped characters
    try std.testing.expectEqual(@as(u16, 0x20AC), try parseAcceleratorKeyString(
        .{ .slice = "\"\\x80\"", .code_page = .windows1252 },
        false,
        .{},
    ));
    // Even with utf8 code page
    try std.testing.expectEqual(@as(u16, 0x20AC), try parseAcceleratorKeyString(
        .{ .slice = "\"\\x80\"", .code_page = .utf8 },
        false,
        .{},
    ));
    try std.testing.expectEqual(@as(u16, 0xCCAC), try parseAcceleratorKeyString(
        .{ .slice = "\"\\x80\\x80\"", .code_page = .windows1252 },
        false,
        .{},
    ));
    // Wide string with the actual characters behaves like the ASCII string version
    try std.testing.expectEqual(@as(u16, 0xCCAC), try parseAcceleratorKeyString(
        .{ .slice = "L\"\x80\x80\"", .code_page = .windows1252 },
        false,
        .{},
    ));
    // But wide string with escapes behaves differently
    try std.testing.expectEqual(@as(u16, 0x8080), try parseAcceleratorKeyString(
        .{ .slice = "L\"\\x80\\x80\"", .code_page = .windows1252 },
        false,
        .{},
    ));
    // and invalid escapes within wide strings get skipped
    try std.testing.expectEqual(@as(u16, 'z'), try parseAcceleratorKeyString(
        .{ .slice = "L\"\\Hz\"", .code_page = .windows1252 },
        false,
        .{},
    ));

    // any non-A-Z codepoints are illegal
    try std.testing.expectError(error.ControlCharacterOutOfRange, parseAcceleratorKeyString(
        .{ .slice = "\"^\x83\"", .code_page = .windows1252 },
        false,
        .{},
    ));
    try std.testing.expectError(error.ControlCharacterOutOfRange, parseAcceleratorKeyString(
        .{ .slice = "\"^1\"", .code_page = .windows1252 },
        false,
        .{},
    ));
    try std.testing.expectError(error.InvalidControlCharacter, parseAcceleratorKeyString(
        .{ .slice = "\"^\"", .code_page = .windows1252 },
        false,
        .{},
    ));
    try std.testing.expectError(error.EmptyAccelerator, parseAcceleratorKeyString(
        .{ .slice = "\"\"", .code_page = .windows1252 },
        false,
        .{},
    ));
    try std.testing.expectError(error.AcceleratorTooLong, parseAcceleratorKeyString(
        .{ .slice = "\"hello\"", .code_page = .windows1252 },
        false,
        .{},
    ));
    try std.testing.expectError(error.ControlCharacterOutOfRange, parseAcceleratorKeyString(
        .{ .slice = "\"^\x80\"", .code_page = .windows1252 },
        false,
        .{},
    ));

    // Invalid UTF-8 gets converted to 0xFFFD, multiple invalids get shifted and added together
    // The behavior is the same for ascii and wide strings
    try std.testing.expectEqual(@as(u16, 0xFCFD), try parseAcceleratorKeyString(
        .{ .slice = "\"\x80\x80\"", .code_page = .utf8 },
        false,
        .{},
    ));
    try std.testing.expectEqual(@as(u16, 0xFCFD), try parseAcceleratorKeyString(
        .{ .slice = "L\"\x80\x80\"", .code_page = .utf8 },
        false,
        .{},
    ));

    // Codepoints >= 0x10000
    try std.testing.expectEqual(@as(u16, 0xDD00), try parseAcceleratorKeyString(
        .{ .slice = "\"\xF0\x90\x84\x80\"", .code_page = .utf8 },
        false,
        .{},
    ));
    try std.testing.expectEqual(@as(u16, 0xDD00), try parseAcceleratorKeyString(
        .{ .slice = "L\"\xF0\x90\x84\x80\"", .code_page = .utf8 },
        false,
        .{},
    ));
    try std.testing.expectEqual(@as(u16, 0x9C01), try parseAcceleratorKeyString(
        .{ .slice = "\"\xF4\x80\x80\x81\"", .code_page = .utf8 },
        false,
        .{},
    ));
    // anything before or after a codepoint >= 0x10000 causes an error
    try std.testing.expectError(error.AcceleratorTooLong, parseAcceleratorKeyString(
        .{ .slice = "\"a\xF0\x90\x80\x80\"", .code_page = .utf8 },
        false,
        .{},
    ));
    try std.testing.expectError(error.AcceleratorTooLong, parseAcceleratorKeyString(
        .{ .slice = "\"\xF0\x90\x80\x80a\"", .code_page = .utf8 },
        false,
        .{},
    ));
}

pub const ForcedOrdinal = struct {
    pub fn fromBytes(bytes: SourceBytes) u16 {
        var i: usize = 0;
        var result: u21 = 0;
        while (bytes.code_page.codepointAt(i, bytes.slice)) |codepoint| : (i += codepoint.byte_len) {
            const c = switch (codepoint.value) {
                // Codepoints that would need a surrogate pair in UTF-16 are
                // broken up into their UTF-16 code units and each code unit
                // is interpreted as a digit.
                0x10000...0x10FFFF => {
                    const high = @as(u16, @intCast((codepoint.value - 0x10000) >> 10)) + 0xD800;
                    if (result != 0) result *%= 10;
                    result +%= high -% '0';

                    const low = @as(u16, @intCast(codepoint.value & 0x3FF)) + 0xDC00;
                    if (result != 0) result *%= 10;
                    result +%= low -% '0';
                    continue;
                },
                Codepoint.invalid => 0xFFFD,
                else => codepoint.value,
            };
            if (result != 0) result *%= 10;
            result +%= c -% '0';
        }
        return @truncate(result);
    }

    pub fn fromUtf16Le(utf16: [:0]const u16) u16 {
        var result: u16 = 0;
        for (utf16) |code_unit| {
            if (result != 0) result *%= 10;
            result +%= std.mem.littleToNative(u16, code_unit) -% '0';
        }
        return result;
    }
};

test "forced ordinal" {
    try std.testing.expectEqual(@as(u16, 3200), ForcedOrdinal.fromBytes(.{ .slice = "3200", .code_page = .windows1252 }));
    try std.testing.expectEqual(@as(u16, 0x33), ForcedOrdinal.fromBytes(.{ .slice = "1+1", .code_page = .windows1252 }));
    try std.testing.expectEqual(@as(u16, 65531), ForcedOrdinal.fromBytes(.{ .slice = "1!", .code_page = .windows1252 }));

    try std.testing.expectEqual(@as(u16, 0x122), ForcedOrdinal.fromBytes(.{ .slice = "0\x8C", .code_page = .windows1252 }));
    try std.testing.expectEqual(@as(u16, 0x122), ForcedOrdinal.fromBytes(.{ .slice = "0Œ", .code_page = .utf8 }));

    // invalid UTF-8 gets converted to 0xFFFD (replacement char) and then interpreted as a digit
    try std.testing.expectEqual(@as(u16, 0xFFCD), ForcedOrdinal.fromBytes(.{ .slice = "0\x81", .code_page = .utf8 }));
    // codepoints >= 0x10000
    try std.testing.expectEqual(@as(u16, 0x49F2), ForcedOrdinal.fromBytes(.{ .slice = "0\u{10002}", .code_page = .utf8 }));
    try std.testing.expectEqual(@as(u16, 0x4AF0), ForcedOrdinal.fromBytes(.{ .slice = "0\u{10100}", .code_page = .utf8 }));

    // From UTF-16
    try std.testing.expectEqual(@as(u16, 0x122), ForcedOrdinal.fromUtf16Le(&[_:0]u16{ std.mem.nativeToLittle(u16, '0'), std.mem.nativeToLittle(u16, 'Œ') }));
    try std.testing.expectEqual(@as(u16, 0x4AF0), ForcedOrdinal.fromUtf16Le(std.unicode.utf8ToUtf16LeStringLiteral("0\u{10100}")));
}

/// https://learn.microsoft.com/en-us/windows/win32/api/verrsrc/ns-verrsrc-vs_fixedfileinfo
pub const FixedFileInfo = struct {
    file_version: Version = .{},
    product_version: Version = .{},
    file_flags_mask: u32 = 0,
    file_flags: u32 = 0,
    file_os: u32 = 0,
    file_type: u32 = 0,
    file_subtype: u32 = 0,
    file_date: Version = .{}, // TODO: I think this is always all zeroes?

    pub const signature = 0xFEEF04BD;
    // Note: This corresponds to a version of 1.0
    pub const version = 0x00010000;

    pub const byte_len = 0x34;
    pub const key = std.unicode.utf8ToUtf16LeStringLiteral("VS_VERSION_INFO");

    pub const Version = struct {
        parts: [4]u16 = [_]u16{0} ** 4,

        pub fn mostSignificantCombinedParts(self: Version) u32 {
            return (@as(u32, self.parts[0]) << 16) + self.parts[1];
        }

        pub fn leastSignificantCombinedParts(self: Version) u32 {
            return (@as(u32, self.parts[2]) << 16) + self.parts[3];
        }
    };

    pub fn write(self: FixedFileInfo, writer: anytype) !void {
        try writer.writeInt(u32, signature, .little);
        try writer.writeInt(u32, version, .little);
        try writer.writeInt(u32, self.file_version.mostSignificantCombinedParts(), .little);
        try writer.writeInt(u32, self.file_version.leastSignificantCombinedParts(), .little);
        try writer.writeInt(u32, self.product_version.mostSignificantCombinedParts(), .little);
        try writer.writeInt(u32, self.product_version.leastSignificantCombinedParts(), .little);
        try writer.writeInt(u32, self.file_flags_mask, .little);
        try writer.writeInt(u32, self.file_flags, .little);
        try writer.writeInt(u32, self.file_os, .little);
        try writer.writeInt(u32, self.file_type, .little);
        try writer.writeInt(u32, self.file_subtype, .little);
        try writer.writeInt(u32, self.file_date.mostSignificantCombinedParts(), .little);
        try writer.writeInt(u32, self.file_date.leastSignificantCombinedParts(), .little);
    }
};

test "FixedFileInfo.Version" {
    const version = FixedFileInfo.Version{
        .parts = .{ 1, 2, 3, 4 },
    };
    try std.testing.expectEqual(@as(u32, 0x00010002), version.mostSignificantCombinedParts());
    try std.testing.expectEqual(@as(u32, 0x00030004), version.leastSignificantCombinedParts());
}

pub const VersionNode = struct {
    pub const type_string: u16 = 1;
    pub const type_binary: u16 = 0;
};

pub const MenuItemFlags = struct {
    value: u16 = 0,

    pub fn apply(self: *MenuItemFlags, option: rc.MenuItem.Option) void {
        self.value |= optionValue(option);
    }

    pub fn isSet(self: MenuItemFlags, option: rc.MenuItem.Option) bool {
        return self.value & optionValue(option) != 0;
    }

    fn optionValue(option: rc.MenuItem.Option) u16 {
        return @intCast(switch (option) {
            .checked => MF.CHECKED,
            .grayed => MF.GRAYED,
            .help => MF.HELP,
            .inactive => MF.DISABLED,
            .menubarbreak => MF.MENUBARBREAK,
            .menubreak => MF.MENUBREAK,
        });
    }

    pub fn markLast(self: *MenuItemFlags) void {
        self.value |= @intCast(MF.END);
    }
};

/// Menu Flags from WinUser.h
/// This is not complete, it only contains what is needed
pub const MF = struct {
    pub const GRAYED: u32 = 0x00000001;
    pub const DISABLED: u32 = 0x00000002;
    pub const CHECKED: u32 = 0x00000008;
    pub const POPUP: u32 = 0x00000010;
    pub const MENUBARBREAK: u32 = 0x00000020;
    pub const MENUBREAK: u32 = 0x00000040;
    pub const HELP: u32 = 0x00004000;
    pub const END: u32 = 0x00000080;
};

/// Window Styles from WinUser.h
pub const WS = struct {
    pub const OVERLAPPED: u32 = 0x00000000;
    pub const POPUP: u32 = 0x80000000;
    pub const CHILD: u32 = 0x40000000;
    pub const MINIMIZE: u32 = 0x20000000;
    pub const VISIBLE: u32 = 0x10000000;
    pub const DISABLED: u32 = 0x08000000;
    pub const CLIPSIBLINGS: u32 = 0x04000000;
    pub const CLIPCHILDREN: u32 = 0x02000000;
    pub const MAXIMIZE: u32 = 0x01000000;
    pub const CAPTION: u32 = BORDER | DLGFRAME;
    pub const BORDER: u32 = 0x00800000;
    pub const DLGFRAME: u32 = 0x00400000;
    pub const VSCROLL: u32 = 0x00200000;
    pub const HSCROLL: u32 = 0x00100000;
    pub const SYSMENU: u32 = 0x00080000;
    pub const THICKFRAME: u32 = 0x00040000;
    pub const GROUP: u32 = 0x00020000;
    pub const TABSTOP: u32 = 0x00010000;

    pub const MINIMIZEBOX: u32 = 0x00020000;
    pub const MAXIMIZEBOX: u32 = 0x00010000;

    pub const TILED: u32 = OVERLAPPED;
    pub const ICONIC: u32 = MINIMIZE;
    pub const SIZEBOX: u32 = THICKFRAME;
    pub const TILEDWINDOW: u32 = OVERLAPPEDWINDOW;

    // Common Window Styles
    pub const OVERLAPPEDWINDOW: u32 = OVERLAPPED | CAPTION | SYSMENU | THICKFRAME | MINIMIZEBOX | MAXIMIZEBOX;
    pub const POPUPWINDOW: u32 = POPUP | BORDER | SYSMENU;
    pub const CHILDWINDOW: u32 = CHILD;
};

/// Dialog Box Template Styles from WinUser.h
pub const DS = struct {
    pub const SETFONT: u32 = 0x40;
};

/// Button Control Styles from WinUser.h
/// This is not complete, it only contains what is needed
pub const BS = struct {
    pub const PUSHBUTTON: u32 = 0x00000000;
    pub const DEFPUSHBUTTON: u32 = 0x00000001;
    pub const CHECKBOX: u32 = 0x00000002;
    pub const AUTOCHECKBOX: u32 = 0x00000003;
    pub const RADIOBUTTON: u32 = 0x00000004;
    pub const @"3STATE": u32 = 0x00000005;
    pub const AUTO3STATE: u32 = 0x00000006;
    pub const GROUPBOX: u32 = 0x00000007;
    pub const USERBUTTON: u32 = 0x00000008;
    pub const AUTORADIOBUTTON: u32 = 0x00000009;
    pub const PUSHBOX: u32 = 0x0000000A;
    pub const OWNERDRAW: u32 = 0x0000000B;
    pub const TYPEMASK: u32 = 0x0000000F;
    pub const LEFTTEXT: u32 = 0x00000020;
};

/// Static Control Constants from WinUser.h
/// This is not complete, it only contains what is needed
pub const SS = struct {
    pub const LEFT: u32 = 0x00000000;
    pub const CENTER: u32 = 0x00000001;
    pub const RIGHT: u32 = 0x00000002;
    pub const ICON: u32 = 0x00000003;
};

/// Listbox Styles from WinUser.h
/// This is not complete, it only contains what is needed
pub const LBS = struct {
    pub const NOTIFY: u32 = 0x0001;
};

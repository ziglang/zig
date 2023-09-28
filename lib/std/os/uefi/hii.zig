const uefi = @import("std").os.uefi;
const Guid = uefi.Guid;

pub const Handle = *opaque {};

/// The header found at the start of each package.
pub const PackageHeader = packed struct(u32) {
    length: u24,
    type: u8,

    pub const type_all: u8 = 0x0;
    pub const type_guid: u8 = 0x1;
    pub const forms: u8 = 0x2;
    pub const strings: u8 = 0x4;
    pub const fonts: u8 = 0x5;
    pub const images: u8 = 0x6;
    pub const simple_fonsts: u8 = 0x7;
    pub const device_path: u8 = 0x8;
    pub const keyboard_layout: u8 = 0x9;
    pub const animations: u8 = 0xa;
    pub const end: u8 = 0xdf;
    pub const type_system_begin: u8 = 0xe0;
    pub const type_system_end: u8 = 0xff;
};

/// The header found at the start of each package list.
pub const PackageList = extern struct {
    package_list_guid: Guid,

    /// The size of the package list (in bytes), including the header.
    package_list_length: u32,

    // TODO implement iterator
};

pub const SimplifiedFontPackage = extern struct {
    header: PackageHeader,
    number_of_narrow_glyphs: u16,
    number_of_wide_glyphs: u16,

    pub fn getNarrowGlyphs(self: *SimplifiedFontPackage) []NarrowGlyph {
        return @as([*]NarrowGlyph, @ptrCast(@alignCast(@as([*]u8, @ptrCast(self)) + @sizeOf(SimplifiedFontPackage))))[0..self.number_of_narrow_glyphs];
    }
};

pub const NarrowGlyphAttributes = packed struct(u8) {
    non_spacing: bool,
    wide: bool,
    _pad: u6 = 0,
};

pub const NarrowGlyph = extern struct {
    unicode_weight: u16,
    attributes: NarrowGlyphAttributes,
    glyph_col_1: [19]u8,
};

pub const WideGlyphAttributes = packed struct(u8) {
    non_spacing: bool,
    wide: bool,
    _pad: u6 = 0,
};

pub const WideGlyph = extern struct {
    unicode_weight: u16,
    attributes: WideGlyphAttributes,
    glyph_col_1: [19]u8,
    glyph_col_2: [19]u8,
    _pad: [3]u8 = [_]u8{0} ** 3,
};

pub const StringPackage = extern struct {
    header: PackageHeader,
    hdr_size: u32,
    string_info_offset: u32,
    language_window: [16]u16,
    language_name: u16,
    language: [3]u8,
};

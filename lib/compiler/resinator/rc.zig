const std = @import("std");
const utils = @import("utils.zig");
const res = @import("res.zig");
const SourceBytes = @import("literals.zig").SourceBytes;

// https://learn.microsoft.com/en-us/windows/win32/menurc/about-resource-files

pub const Resource = enum {
    accelerators,
    bitmap,
    cursor,
    dialog,
    dialogex,
    /// As far as I can tell, this is undocumented; the most I could find was this:
    /// https://www.betaarchive.com/wiki/index.php/Microsoft_KB_Archive/91697
    dlginclude,
    /// Undocumented, basically works exactly like RCDATA
    dlginit,
    font,
    html,
    icon,
    menu,
    menuex,
    messagetable,
    plugplay, // Obsolete
    rcdata,
    stringtable,
    /// Undocumented
    toolbar,
    user_defined,
    versioninfo,
    vxd, // Obsolete

    // Types that are treated as a user-defined type when encountered, but have
    // special meaning without the Visual Studio GUI. We match the Win32 RC compiler
    // behavior by acting as if these keyword don't exist when compiling the .rc
    // (thereby treating them as user-defined).
    //textinclude, // A special resource that is interpreted by Visual C++.
    //typelib, // A special resource that is used with the /TLBID and /TLBOUT linker options

    // Types that can only be specified by numbers, they don't have keywords
    cursor_num,
    icon_num,
    string_num,
    anicursor_num,
    aniicon_num,
    fontdir_num,
    manifest_num,

    const map = std.StaticStringMapWithEql(
        Resource,
        std.static_string_map.eqlAsciiIgnoreCase,
    ).initComptime(.{
        .{ "ACCELERATORS", .accelerators },
        .{ "BITMAP", .bitmap },
        .{ "CURSOR", .cursor },
        .{ "DIALOG", .dialog },
        .{ "DIALOGEX", .dialogex },
        .{ "DLGINCLUDE", .dlginclude },
        .{ "DLGINIT", .dlginit },
        .{ "FONT", .font },
        .{ "HTML", .html },
        .{ "ICON", .icon },
        .{ "MENU", .menu },
        .{ "MENUEX", .menuex },
        .{ "MESSAGETABLE", .messagetable },
        .{ "PLUGPLAY", .plugplay },
        .{ "RCDATA", .rcdata },
        .{ "STRINGTABLE", .stringtable },
        .{ "TOOLBAR", .toolbar },
        .{ "VERSIONINFO", .versioninfo },
        .{ "VXD", .vxd },
    });

    pub fn fromString(bytes: SourceBytes) Resource {
        const maybe_ordinal = res.NameOrOrdinal.maybeOrdinalFromString(bytes);
        if (maybe_ordinal) |ordinal| {
            if (ordinal.ordinal >= 256) return .user_defined;
            return fromRT(@enumFromInt(ordinal.ordinal));
        }
        return map.get(bytes.slice) orelse .user_defined;
    }

    // TODO: Some comptime validation that RT <-> Resource conversion is synced?
    pub fn fromRT(rt: res.RT) Resource {
        return switch (rt) {
            .ACCELERATOR => .accelerators,
            .ANICURSOR => .anicursor_num,
            .ANIICON => .aniicon_num,
            .BITMAP => .bitmap,
            .CURSOR => .cursor_num,
            .DIALOG => .dialog,
            .DLGINCLUDE => .dlginclude,
            .DLGINIT => .dlginit,
            .FONT => .font,
            .FONTDIR => .fontdir_num,
            .GROUP_CURSOR => .cursor,
            .GROUP_ICON => .icon,
            .HTML => .html,
            .ICON => .icon_num,
            .MANIFEST => .manifest_num,
            .MENU => .menu,
            .MESSAGETABLE => .messagetable,
            .PLUGPLAY => .plugplay,
            .RCDATA => .rcdata,
            .STRING => .string_num,
            .TOOLBAR => .toolbar,
            .VERSION => .versioninfo,
            .VXD => .vxd,
            _ => .user_defined,
        };
    }

    pub fn canUseRawData(resource: Resource) bool {
        return switch (resource) {
            .user_defined,
            .html,
            .plugplay, // Obsolete
            .rcdata,
            .vxd, // Obsolete
            .manifest_num,
            .dlginit,
            => true,
            else => false,
        };
    }

    pub fn nameForErrorDisplay(resource: Resource) []const u8 {
        return switch (resource) {
            // zig fmt: off
            .accelerators, .bitmap, .cursor, .dialog, .dialogex, .dlginclude, .dlginit, .font,
            .html, .icon, .menu, .menuex, .messagetable, .plugplay, .rcdata, .stringtable,
            .toolbar, .versioninfo, .vxd => @tagName(resource),
            // zig fmt: on
            .user_defined => "user-defined",
            .cursor_num => std.fmt.comptimePrint("{d} (cursor)", .{@intFromEnum(res.RT.CURSOR)}),
            .icon_num => std.fmt.comptimePrint("{d} (icon)", .{@intFromEnum(res.RT.ICON)}),
            .string_num => std.fmt.comptimePrint("{d} (string)", .{@intFromEnum(res.RT.STRING)}),
            .anicursor_num => std.fmt.comptimePrint("{d} (anicursor)", .{@intFromEnum(res.RT.ANICURSOR)}),
            .aniicon_num => std.fmt.comptimePrint("{d} (aniicon)", .{@intFromEnum(res.RT.ANIICON)}),
            .fontdir_num => std.fmt.comptimePrint("{d} (fontdir)", .{@intFromEnum(res.RT.FONTDIR)}),
            .manifest_num => std.fmt.comptimePrint("{d} (manifest)", .{@intFromEnum(res.RT.MANIFEST)}),
        };
    }
};

/// https://learn.microsoft.com/en-us/windows/win32/menurc/stringtable-resource#parameters
/// https://learn.microsoft.com/en-us/windows/win32/menurc/dialog-resource#parameters
/// https://learn.microsoft.com/en-us/windows/win32/menurc/dialogex-resource#parameters
pub const OptionalStatements = enum {
    characteristics,
    language,
    version,

    // DIALOG
    caption,
    class,
    exstyle,
    font,
    menu,
    style,

    pub const map = std.StaticStringMapWithEql(
        OptionalStatements,
        std.static_string_map.eqlAsciiIgnoreCase,
    ).initComptime(.{
        .{ "CHARACTERISTICS", .characteristics },
        .{ "LANGUAGE", .language },
        .{ "VERSION", .version },
    });

    pub const dialog_map = std.StaticStringMapWithEql(
        OptionalStatements,
        std.static_string_map.eqlAsciiIgnoreCase,
    ).initComptime(.{
        .{ "CAPTION", .caption },
        .{ "CLASS", .class },
        .{ "EXSTYLE", .exstyle },
        .{ "FONT", .font },
        .{ "MENU", .menu },
        .{ "STYLE", .style },
    });
};

pub const Control = enum {
    auto3state,
    autocheckbox,
    autoradiobutton,
    checkbox,
    combobox,
    control,
    ctext,
    defpushbutton,
    edittext,
    hedit,
    iedit,
    groupbox,
    icon,
    listbox,
    ltext,
    pushbox,
    pushbutton,
    radiobutton,
    rtext,
    scrollbar,
    state3,
    userbutton,

    pub const map = std.StaticStringMapWithEql(
        Control,
        std.static_string_map.eqlAsciiIgnoreCase,
    ).initComptime(.{
        .{ "AUTO3STATE", .auto3state },
        .{ "AUTOCHECKBOX", .autocheckbox },
        .{ "AUTORADIOBUTTON", .autoradiobutton },
        .{ "CHECKBOX", .checkbox },
        .{ "COMBOBOX", .combobox },
        .{ "CONTROL", .control },
        .{ "CTEXT", .ctext },
        .{ "DEFPUSHBUTTON", .defpushbutton },
        .{ "EDITTEXT", .edittext },
        .{ "HEDIT", .hedit },
        .{ "IEDIT", .iedit },
        .{ "GROUPBOX", .groupbox },
        .{ "ICON", .icon },
        .{ "LISTBOX", .listbox },
        .{ "LTEXT", .ltext },
        .{ "PUSHBOX", .pushbox },
        .{ "PUSHBUTTON", .pushbutton },
        .{ "RADIOBUTTON", .radiobutton },
        .{ "RTEXT", .rtext },
        .{ "SCROLLBAR", .scrollbar },
        .{ "STATE3", .state3 },
        .{ "USERBUTTON", .userbutton },
    });

    pub fn hasTextParam(control: Control) bool {
        switch (control) {
            .scrollbar, .listbox, .iedit, .hedit, .edittext, .combobox => return false,
            else => return true,
        }
    }
};

pub const ControlClass = struct {
    pub const map = std.StaticStringMapWithEql(
        res.ControlClass,
        std.static_string_map.eqlAsciiIgnoreCase,
    ).initComptime(.{
        .{ "BUTTON", .button },
        .{ "EDIT", .edit },
        .{ "STATIC", .static },
        .{ "LISTBOX", .listbox },
        .{ "SCROLLBAR", .scrollbar },
        .{ "COMBOBOX", .combobox },
    });

    /// Like `map.get` but works on WTF16 strings, for use with parsed
    /// string literals ("BUTTON", or even "\x42UTTON")
    pub fn fromWideString(str: []const u16) ?res.ControlClass {
        const utf16Literal = std.unicode.utf8ToUtf16LeStringLiteral;
        return if (ascii.eqlIgnoreCaseW(str, utf16Literal("BUTTON")))
            .button
        else if (ascii.eqlIgnoreCaseW(str, utf16Literal("EDIT")))
            .edit
        else if (ascii.eqlIgnoreCaseW(str, utf16Literal("STATIC")))
            .static
        else if (ascii.eqlIgnoreCaseW(str, utf16Literal("LISTBOX")))
            .listbox
        else if (ascii.eqlIgnoreCaseW(str, utf16Literal("SCROLLBAR")))
            .scrollbar
        else if (ascii.eqlIgnoreCaseW(str, utf16Literal("COMBOBOX")))
            .combobox
        else
            null;
    }
};

const ascii = struct {
    /// Compares ASCII values case-insensitively, non-ASCII values are compared directly
    pub fn eqlIgnoreCaseW(a: []const u16, b: []const u16) bool {
        if (a.len != b.len) return false;
        for (a, b) |a_c, b_c| {
            if (a_c < 128) {
                if (std.ascii.toLower(@intCast(a_c)) != std.ascii.toLower(@intCast(b_c))) return false;
            } else {
                if (a_c != b_c) return false;
            }
        }
        return true;
    }
};

pub const MenuItem = enum {
    menuitem,
    popup,

    pub const map = std.StaticStringMapWithEql(
        MenuItem,
        std.static_string_map.eqlAsciiIgnoreCase,
    ).initComptime(.{
        .{ "MENUITEM", .menuitem },
        .{ "POPUP", .popup },
    });

    pub fn isSeparator(bytes: []const u8) bool {
        return std.ascii.eqlIgnoreCase(bytes, "SEPARATOR");
    }

    pub const Option = enum {
        checked,
        grayed,
        help,
        inactive,
        menubarbreak,
        menubreak,

        pub const map = std.StaticStringMapWithEql(
            Option,
            std.static_string_map.eqlAsciiIgnoreCase,
        ).initComptime(.{
            .{ "CHECKED", .checked },
            .{ "GRAYED", .grayed },
            .{ "HELP", .help },
            .{ "INACTIVE", .inactive },
            .{ "MENUBARBREAK", .menubarbreak },
            .{ "MENUBREAK", .menubreak },
        });
    };
};

pub const ToolbarButton = enum {
    button,
    separator,

    pub const map = std.StaticStringMapWithEql(
        ToolbarButton,
        std.static_string_map.eqlAsciiIgnoreCase,
    ).initComptime(.{
        .{ "BUTTON", .button },
        .{ "SEPARATOR", .separator },
    });
};

pub const VersionInfo = enum {
    file_version,
    product_version,
    file_flags_mask,
    file_flags,
    file_os,
    file_type,
    file_subtype,

    pub const map = std.StaticStringMapWithEql(
        VersionInfo,
        std.static_string_map.eqlAsciiIgnoreCase,
    ).initComptime(.{
        .{ "FILEVERSION", .file_version },
        .{ "PRODUCTVERSION", .product_version },
        .{ "FILEFLAGSMASK", .file_flags_mask },
        .{ "FILEFLAGS", .file_flags },
        .{ "FILEOS", .file_os },
        .{ "FILETYPE", .file_type },
        .{ "FILESUBTYPE", .file_subtype },
    });
};

pub const VersionBlock = enum {
    block,
    value,

    pub const map = std.StaticStringMapWithEql(
        VersionBlock,
        std.static_string_map.eqlAsciiIgnoreCase,
    ).initComptime(.{
        .{ "BLOCK", .block },
        .{ "VALUE", .value },
    });
};

/// Keywords that are be the first token in a statement and (if so) dictate how the rest
/// of the statement is parsed.
pub const TopLevelKeywords = enum {
    language,
    version,
    characteristics,
    stringtable,

    pub const map = std.StaticStringMapWithEql(
        TopLevelKeywords,
        std.static_string_map.eqlAsciiIgnoreCase,
    ).initComptime(.{
        .{ "LANGUAGE", .language },
        .{ "VERSION", .version },
        .{ "CHARACTERISTICS", .characteristics },
        .{ "STRINGTABLE", .stringtable },
    });
};

pub const CommonResourceAttributes = enum {
    preload,
    loadoncall,
    fixed,
    moveable,
    discardable,
    pure,
    impure,
    shared,
    nonshared,

    pub const map = std.StaticStringMapWithEql(
        CommonResourceAttributes,
        std.static_string_map.eqlAsciiIgnoreCase,
    ).initComptime(.{
        .{ "PRELOAD", .preload },
        .{ "LOADONCALL", .loadoncall },
        .{ "FIXED", .fixed },
        .{ "MOVEABLE", .moveable },
        .{ "DISCARDABLE", .discardable },
        .{ "PURE", .pure },
        .{ "IMPURE", .impure },
        .{ "SHARED", .shared },
        .{ "NONSHARED", .nonshared },
    });
};

pub const AcceleratorTypeAndOptions = enum {
    virtkey,
    ascii,
    noinvert,
    alt,
    shift,
    control,

    pub const map = std.StaticStringMapWithEql(
        AcceleratorTypeAndOptions,
        std.static_string_map.eqlAsciiIgnoreCase,
    ).initComptime(.{
        .{ "VIRTKEY", .virtkey },
        .{ "ASCII", .ascii },
        .{ "NOINVERT", .noinvert },
        .{ "ALT", .alt },
        .{ "SHIFT", .shift },
        .{ "CONTROL", .control },
    });
};

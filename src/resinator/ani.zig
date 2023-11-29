//! https://en.wikipedia.org/wiki/Resource_Interchange_File_Format
//! https://www.moon-soft.com/program/format/windows/ani.htm
//! https://www.gdgsoft.com/anituner/help/aniformat.htm
//! https://www.lomont.org/software/aniexploit/ExploitANI.pdf
//!
//! RIFF( 'ACON'
//!   [LIST( 'INFO' <info_data> )]
//!   [<DISP_ck>]
//!   anih( <ani_header> )
//!   [rate( <rate_info> )]
//!   ['seq '( <sequence_info> )]
//!   LIST( 'fram' icon( <icon_file> ) ... )
//! )

const std = @import("std");

const AF_ICON: u32 = 1;

pub fn isAnimatedIcon(reader: anytype) bool {
    const flags = getAniheaderFlags(reader) catch return false;
    return flags & AF_ICON == AF_ICON;
}

fn getAniheaderFlags(reader: anytype) !u32 {
    const riff_header = try reader.readBytesNoEof(4);
    if (!std.mem.eql(u8, &riff_header, "RIFF")) return error.InvalidFormat;

    _ = try reader.readInt(u32, .little); // size of RIFF chunk

    const form_type = try reader.readBytesNoEof(4);
    if (!std.mem.eql(u8, &form_type, "ACON")) return error.InvalidFormat;

    while (true) {
        const chunk_id = try reader.readBytesNoEof(4);
        const chunk_len = try reader.readInt(u32, .little);
        if (!std.mem.eql(u8, &chunk_id, "anih")) {
            // TODO: Move file cursor instead of skipBytes
            try reader.skipBytes(chunk_len, .{});
            continue;
        }

        const aniheader = try reader.readStruct(ANIHEADER);
        return std.mem.nativeToLittle(u32, aniheader.flags);
    }
}

/// From Microsoft Multimedia Data Standards Update April 15, 1994
const ANIHEADER = extern struct {
    cbSizeof: u32,
    cFrames: u32,
    cSteps: u32,
    cx: u32,
    cy: u32,
    cBitCount: u32,
    cPlanes: u32,
    jifRate: u32,
    flags: u32,
};

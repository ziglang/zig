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

pub fn isAnimatedIcon(reader: *std.Io.Reader) bool {
    const flags = getAniheaderFlags(reader) catch return false;
    return flags & AF_ICON == AF_ICON;
}

fn getAniheaderFlags(reader: *std.Io.Reader) !u32 {
    const riff_header = try reader.takeArray(4);
    if (!std.mem.eql(u8, riff_header, "RIFF")) return error.InvalidFormat;

    _ = try reader.takeInt(u32, .little); // size of RIFF chunk

    const form_type = try reader.takeArray(4);
    if (!std.mem.eql(u8, form_type, "ACON")) return error.InvalidFormat;

    while (true) {
        const chunk_id = try reader.takeArray(4);
        const chunk_len = try reader.takeInt(u32, .little);
        if (!std.mem.eql(u8, chunk_id, "anih")) {
            // TODO: Move file cursor instead of skipBytes
            try reader.discardAll(chunk_len);
            continue;
        }

        const aniheader = try reader.takeStruct(ANIHEADER, .little);
        return aniheader.flags;
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

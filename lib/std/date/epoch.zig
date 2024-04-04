//! Days since 1970-01-01 for various calendar systems.
//!
//! 1970-01-01 is Zig's chosen epoch for timestamp functions.

// To build this list yourself using `date`:
// $ echo $(( $(date -d "YYYY-mm-dd UTC" +%s) / (60*60*24) ))

/// 1970-01-01
pub const posix = 0;
/// 1980-01-01
pub const dos = 3_652;
/// 2001-01-01
pub const ios = 11_323;
/// 1858-11-17
pub const openvms = -40_587;
/// 1900-01-01
pub const zos = -25_567;
/// 1601-01-01
pub const windows = -134_774;
/// 1978-01-01
pub const amiga = 2_922;
/// 1967-12-31
pub const pickos = -732;
/// 1980-01-06
pub const gps = 3_657;
/// 0001-01-01
pub const clr = -719_164;

pub const unix = posix;
pub const android = posix;
pub const os2 = dos;
pub const bios = dos;
pub const vfat = dos;
pub const ntfs = windows;
pub const ntp = zos;
pub const jbase = pickos;
pub const aros = amiga;
pub const morphos = amiga;
pub const brew = gps;
pub const atsc = gps;
pub const go = clr;

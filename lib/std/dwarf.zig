//! DWARF debugging data format.
//!
//! This namespace contains unopinionated types and data definitions only. For
//! an implementation of parsing and caching DWARF information, see
//! `std.debug.Dwarf`.

pub const TAG = @import("dwarf/TAG.zig");
pub const AT = @import("dwarf/AT.zig");
pub const OP = @import("dwarf/OP.zig");
pub const LANG = @import("dwarf/LANG.zig");
pub const FORM = @import("dwarf/FORM.zig");
pub const ATE = @import("dwarf/ATE.zig");
pub const EH = @import("dwarf/EH.zig");
pub const Format = enum { @"32", @"64" };

pub const LLE = struct {
    pub const end_of_list = 0x00;
    pub const base_addressx = 0x01;
    pub const startx_endx = 0x02;
    pub const startx_length = 0x03;
    pub const offset_pair = 0x04;
    pub const default_location = 0x05;
    pub const base_address = 0x06;
    pub const start_end = 0x07;
    pub const start_length = 0x08;
};

pub const CFA = struct {
    pub const advance_loc = 0x40;
    pub const offset = 0x80;
    pub const restore = 0xc0;
    pub const nop = 0x00;
    pub const set_loc = 0x01;
    pub const advance_loc1 = 0x02;
    pub const advance_loc2 = 0x03;
    pub const advance_loc4 = 0x04;
    pub const offset_extended = 0x05;
    pub const restore_extended = 0x06;
    pub const @"undefined" = 0x07;
    pub const same_value = 0x08;
    pub const register = 0x09;
    pub const remember_state = 0x0a;
    pub const restore_state = 0x0b;
    pub const def_cfa = 0x0c;
    pub const def_cfa_register = 0x0d;
    pub const def_cfa_offset = 0x0e;

    // DWARF 3.
    pub const def_cfa_expression = 0x0f;
    pub const expression = 0x10;
    pub const offset_extended_sf = 0x11;
    pub const def_cfa_sf = 0x12;
    pub const def_cfa_offset_sf = 0x13;
    pub const val_offset = 0x14;
    pub const val_offset_sf = 0x15;
    pub const val_expression = 0x16;

    pub const lo_user = 0x1c;
    pub const hi_user = 0x3f;

    // SGI/MIPS specific.
    pub const MIPS_advance_loc8 = 0x1d;

    // GNU extensions.
    pub const GNU_window_save = 0x2d;
    pub const GNU_args_size = 0x2e;
    pub const GNU_negative_offset_extended = 0x2f;
};

pub const CHILDREN = struct {
    pub const no = 0x00;
    pub const yes = 0x01;
};

pub const LNS = struct {
    pub const extended_op = 0x00;
    pub const copy = 0x01;
    pub const advance_pc = 0x02;
    pub const advance_line = 0x03;
    pub const set_file = 0x04;
    pub const set_column = 0x05;
    pub const negate_stmt = 0x06;
    pub const set_basic_block = 0x07;
    pub const const_add_pc = 0x08;
    pub const fixed_advance_pc = 0x09;
    pub const set_prologue_end = 0x0a;
    pub const set_epilogue_begin = 0x0b;
    pub const set_isa = 0x0c;
};

pub const LNE = struct {
    pub const padding = 0x00;
    pub const end_sequence = 0x01;
    pub const set_address = 0x02;
    pub const define_file = 0x03;
    pub const set_discriminator = 0x04;
    pub const lo_user = 0x80;
    pub const hi_user = 0xff;

    // Zig extensions
    pub const ZIG_set_decl = 0xec;
};

pub const UT = struct {
    pub const compile = 0x01;
    pub const @"type" = 0x02;
    pub const partial = 0x03;
    pub const skeleton = 0x04;
    pub const split_compile = 0x05;
    pub const split_type = 0x06;

    pub const lo_user = 0x80;
    pub const hi_user = 0xff;
};

pub const LNCT = struct {
    pub const path = 0x1;
    pub const directory_index = 0x2;
    pub const timestamp = 0x3;
    pub const size = 0x4;
    pub const MD5 = 0x5;

    pub const lo_user = 0x2000;
    pub const hi_user = 0x3fff;

    pub const LLVM_source = 0x2001;
};

pub const RLE = struct {
    pub const end_of_list = 0x00;
    pub const base_addressx = 0x01;
    pub const startx_endx = 0x02;
    pub const startx_length = 0x03;
    pub const offset_pair = 0x04;
    pub const base_address = 0x05;
    pub const start_end = 0x06;
    pub const start_length = 0x07;
};

pub const CC = enum(u8) {
    normal = 0x1,
    program = 0x2,
    nocall = 0x3,

    pass_by_reference = 0x4,
    pass_by_value = 0x5,

    GNU_renesas_sh = 0x40,
    GNU_borland_fastcall_i386 = 0x41,

    BORLAND_safecall = 0xb0,
    BORLAND_stdcall = 0xb1,
    BORLAND_pascal = 0xb2,
    BORLAND_msfastcall = 0xb3,
    BORLAND_msreturn = 0xb4,
    BORLAND_thiscall = 0xb5,
    BORLAND_fastcall = 0xb6,

    LLVM_vectorcall = 0xc0,
    LLVM_Win64 = 0xc1,
    LLVM_X86_64SysV = 0xc2,
    LLVM_AAPCS = 0xc3,
    LLVM_AAPCS_VFP = 0xc4,
    LLVM_IntelOclBicc = 0xc5,
    LLVM_SpirFunction = 0xc6,
    LLVM_OpenCLKernel = 0xc7,
    LLVM_Swift = 0xc8,
    LLVM_PreserveMost = 0xc9,
    LLVM_PreserveAll = 0xca,
    LLVM_X86RegCall = 0xcb,
    LLVM_M68kRTD = 0xcc,
    LLVM_PreserveNone = 0xcd,
    LLVM_RISCVVectorCall = 0xce,
    LLVM_SwiftTail = 0xcf,

    pub const lo_user = 0x40;
    pub const hi_user = 0xff;
};

pub const ACCESS = struct {
    pub const public = 0x01;
    pub const protected = 0x02;
    pub const private = 0x03;
};

//! DWARF debugging data format.
//!
//! This namespace contains unopinionated types and data definitions only. For
//! an implementation of parsing and caching DWARF information, see
//! `std.debug.Dwarf`.

pub const TAG = @import("dwarf/TAG.zig");
pub const AT = @import("dwarf/AT.zig");
pub const OP = enum(u8) {
    addr = 0x03,
    deref = 0x06,
    const1u = 0x08,
    const1s = 0x09,
    const2u = 0x0a,
    const2s = 0x0b,
    const4u = 0x0c,
    const4s = 0x0d,
    const8u = 0x0e,
    const8s = 0x0f,
    constu = 0x10,
    consts = 0x11,
    dup = 0x12,
    drop = 0x13,
    over = 0x14,
    pick = 0x15,
    swap = 0x16,
    rot = 0x17,
    xderef = 0x18,
    abs = 0x19,
    @"and" = 0x1a,
    div = 0x1b,
    minus = 0x1c,
    mod = 0x1d,
    mul = 0x1e,
    neg = 0x1f,
    not = 0x20,
    @"or" = 0x21,
    plus = 0x22,
    plus_uconst = 0x23,
    shl = 0x24,
    shr = 0x25,
    shra = 0x26,
    xor = 0x27,
    bra = 0x28,
    eq = 0x29,
    ge = 0x2a,
    gt = 0x2b,
    le = 0x2c,
    lt = 0x2d,
    ne = 0x2e,
    skip = 0x2f,
    lit0 = 0x30,
    lit1 = 0x31,
    lit2 = 0x32,
    lit3 = 0x33,
    lit4 = 0x34,
    lit5 = 0x35,
    lit6 = 0x36,
    lit7 = 0x37,
    lit8 = 0x38,
    lit9 = 0x39,
    lit10 = 0x3a,
    lit11 = 0x3b,
    lit12 = 0x3c,
    lit13 = 0x3d,
    lit14 = 0x3e,
    lit15 = 0x3f,
    lit16 = 0x40,
    lit17 = 0x41,
    lit18 = 0x42,
    lit19 = 0x43,
    lit20 = 0x44,
    lit21 = 0x45,
    lit22 = 0x46,
    lit23 = 0x47,
    lit24 = 0x48,
    lit25 = 0x49,
    lit26 = 0x4a,
    lit27 = 0x4b,
    lit28 = 0x4c,
    lit29 = 0x4d,
    lit30 = 0x4e,
    lit31 = 0x4f,
    reg0 = 0x50,
    reg1 = 0x51,
    reg2 = 0x52,
    reg3 = 0x53,
    reg4 = 0x54,
    reg5 = 0x55,
    reg6 = 0x56,
    reg7 = 0x57,
    reg8 = 0x58,
    reg9 = 0x59,
    reg10 = 0x5a,
    reg11 = 0x5b,
    reg12 = 0x5c,
    reg13 = 0x5d,
    reg14 = 0x5e,
    reg15 = 0x5f,
    reg16 = 0x60,
    reg17 = 0x61,
    reg18 = 0x62,
    reg19 = 0x63,
    reg20 = 0x64,
    reg21 = 0x65,
    reg22 = 0x66,
    reg23 = 0x67,
    reg24 = 0x68,
    reg25 = 0x69,
    reg26 = 0x6a,
    reg27 = 0x6b,
    reg28 = 0x6c,
    reg29 = 0x6d,
    reg30 = 0x6e,
    reg31 = 0x6f,
    breg0 = 0x70,
    breg1 = 0x71,
    breg2 = 0x72,
    breg3 = 0x73,
    breg4 = 0x74,
    breg5 = 0x75,
    breg6 = 0x76,
    breg7 = 0x77,
    breg8 = 0x78,
    breg9 = 0x79,
    breg10 = 0x7a,
    breg11 = 0x7b,
    breg12 = 0x7c,
    breg13 = 0x7d,
    breg14 = 0x7e,
    breg15 = 0x7f,
    breg16 = 0x80,
    breg17 = 0x81,
    breg18 = 0x82,
    breg19 = 0x83,
    breg20 = 0x84,
    breg21 = 0x85,
    breg22 = 0x86,
    breg23 = 0x87,
    breg24 = 0x88,
    breg25 = 0x89,
    breg26 = 0x8a,
    breg27 = 0x8b,
    breg28 = 0x8c,
    breg29 = 0x8d,
    breg30 = 0x8e,
    breg31 = 0x8f,
    regx = 0x90,
    fbreg = 0x91,
    bregx = 0x92,
    piece = 0x93,
    deref_size = 0x94,
    xderef_size = 0x95,
    nop = 0x96,

    // DWARF 3 extensions.
    push_object_address = 0x97,
    call2 = 0x98,
    call4 = 0x99,
    call_ref = 0x9a,
    form_tls_address = 0x9b,
    call_frame_cfa = 0x9c,
    bit_piece = 0x9d,

    // DWARF 4 extensions.
    implicit_value = 0x9e,
    stack_value = 0x9f,

    // DWARF 5 extensions.
    implicit_pointer = 0xa0,
    addrx = 0xa1,
    constx = 0xa2,
    entry_value = 0xa3,
    const_type = 0xa4,
    regval_type = 0xa5,
    deref_type = 0xa6,
    xderef_type = 0xa7,
    convert = 0xa8,
    reinterpret = 0xa9,

    // GNU extensions.
    GNU_push_tls_address = 0xe0,
    /// The following is for marking variables that are uninitialized.
    GNU_uninit = 0xf0,
    GNU_encoded_addr = 0xf1,
    /// The GNU implicit pointer extension.
    /// See http://www.dwarfstd.org/ShowIssue.php?issue=100831.1&type=open .
    GNU_implicit_pointer = 0xf2,
    /// The GNU entry value extension.
    /// See http://www.dwarfstd.org/ShowIssue.php?issue=100909.1&type=open .
    GNU_entry_value = 0xf3,
    /// The GNU typed stack extension.
    /// See http://www.dwarfstd.org/doc/040408.1.html .
    GNU_const_type = 0xf4,
    GNU_regval_type = 0xf5,
    GNU_deref_type = 0xf6,
    GNU_convert = 0xf7,
    GNU_reinterpret = 0xf9,
    /// The GNU parameter ref extension.
    GNU_parameter_ref = 0xfa,
    /// Extension for Fission.  See http://gcc.gnu.org/wiki/DebugFission.
    GNU_addr_index = 0xfb,
    GNU_const_index = 0xfc,
    // HP extensions.
    HP_is_value = 0xe1,
    HP_fltconst4 = 0xe2,
    HP_fltconst8 = 0xe3,
    HP_mod_range = 0xe4,
    HP_unmod_range = 0xe5,
    HP_tls = 0xe6,
    // PGI (STMicroelectronics) extensions.
    PGI_omp_thread_num = 0xf8,
    // Wasm extensions.
    WASM_location = 0xed,
    WASM_local = 0x00,
    WASM_global = 0x01,
    WASM_operand_stack = 0x02,

    _,

    /// Implementation-defined range start.
    pub const lo_user: OP = @enumFromInt(0xe0);
    /// Implementation-defined range end.
    pub const hi_user: OP = @enumFromInt(0xff);

    pub const HP_unknown: OP = @enumFromInt(0xe0);
    pub const WASM_global_u32: OP = @enumFromInt(0x03);
};
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

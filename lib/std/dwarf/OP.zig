pub const addr = 0x03;
pub const deref = 0x06;
pub const const1u = 0x08;
pub const const1s = 0x09;
pub const const2u = 0x0a;
pub const const2s = 0x0b;
pub const const4u = 0x0c;
pub const const4s = 0x0d;
pub const const8u = 0x0e;
pub const const8s = 0x0f;
pub const constu = 0x10;
pub const consts = 0x11;
pub const dup = 0x12;
pub const drop = 0x13;
pub const over = 0x14;
pub const pick = 0x15;
pub const swap = 0x16;
pub const rot = 0x17;
pub const xderef = 0x18;
pub const abs = 0x19;
pub const @"and" = 0x1a;
pub const div = 0x1b;
pub const minus = 0x1c;
pub const mod = 0x1d;
pub const mul = 0x1e;
pub const neg = 0x1f;
pub const not = 0x20;
pub const @"or" = 0x21;
pub const plus = 0x22;
pub const plus_uconst = 0x23;
pub const shl = 0x24;
pub const shr = 0x25;
pub const shra = 0x26;
pub const xor = 0x27;
pub const bra = 0x28;
pub const eq = 0x29;
pub const ge = 0x2a;
pub const gt = 0x2b;
pub const le = 0x2c;
pub const lt = 0x2d;
pub const ne = 0x2e;
pub const skip = 0x2f;
pub const lit0 = 0x30;
pub const lit1 = 0x31;
pub const lit2 = 0x32;
pub const lit3 = 0x33;
pub const lit4 = 0x34;
pub const lit5 = 0x35;
pub const lit6 = 0x36;
pub const lit7 = 0x37;
pub const lit8 = 0x38;
pub const lit9 = 0x39;
pub const lit10 = 0x3a;
pub const lit11 = 0x3b;
pub const lit12 = 0x3c;
pub const lit13 = 0x3d;
pub const lit14 = 0x3e;
pub const lit15 = 0x3f;
pub const lit16 = 0x40;
pub const lit17 = 0x41;
pub const lit18 = 0x42;
pub const lit19 = 0x43;
pub const lit20 = 0x44;
pub const lit21 = 0x45;
pub const lit22 = 0x46;
pub const lit23 = 0x47;
pub const lit24 = 0x48;
pub const lit25 = 0x49;
pub const lit26 = 0x4a;
pub const lit27 = 0x4b;
pub const lit28 = 0x4c;
pub const lit29 = 0x4d;
pub const lit30 = 0x4e;
pub const lit31 = 0x4f;
pub const reg0 = 0x50;
pub const reg1 = 0x51;
pub const reg2 = 0x52;
pub const reg3 = 0x53;
pub const reg4 = 0x54;
pub const reg5 = 0x55;
pub const reg6 = 0x56;
pub const reg7 = 0x57;
pub const reg8 = 0x58;
pub const reg9 = 0x59;
pub const reg10 = 0x5a;
pub const reg11 = 0x5b;
pub const reg12 = 0x5c;
pub const reg13 = 0x5d;
pub const reg14 = 0x5e;
pub const reg15 = 0x5f;
pub const reg16 = 0x60;
pub const reg17 = 0x61;
pub const reg18 = 0x62;
pub const reg19 = 0x63;
pub const reg20 = 0x64;
pub const reg21 = 0x65;
pub const reg22 = 0x66;
pub const reg23 = 0x67;
pub const reg24 = 0x68;
pub const reg25 = 0x69;
pub const reg26 = 0x6a;
pub const reg27 = 0x6b;
pub const reg28 = 0x6c;
pub const reg29 = 0x6d;
pub const reg30 = 0x6e;
pub const reg31 = 0x6f;
pub const breg0 = 0x70;
pub const breg1 = 0x71;
pub const breg2 = 0x72;
pub const breg3 = 0x73;
pub const breg4 = 0x74;
pub const breg5 = 0x75;
pub const breg6 = 0x76;
pub const breg7 = 0x77;
pub const breg8 = 0x78;
pub const breg9 = 0x79;
pub const breg10 = 0x7a;
pub const breg11 = 0x7b;
pub const breg12 = 0x7c;
pub const breg13 = 0x7d;
pub const breg14 = 0x7e;
pub const breg15 = 0x7f;
pub const breg16 = 0x80;
pub const breg17 = 0x81;
pub const breg18 = 0x82;
pub const breg19 = 0x83;
pub const breg20 = 0x84;
pub const breg21 = 0x85;
pub const breg22 = 0x86;
pub const breg23 = 0x87;
pub const breg24 = 0x88;
pub const breg25 = 0x89;
pub const breg26 = 0x8a;
pub const breg27 = 0x8b;
pub const breg28 = 0x8c;
pub const breg29 = 0x8d;
pub const breg30 = 0x8e;
pub const breg31 = 0x8f;
pub const regx = 0x90;
pub const fbreg = 0x91;
pub const bregx = 0x92;
pub const piece = 0x93;
pub const deref_size = 0x94;
pub const xderef_size = 0x95;
pub const nop = 0x96;

// DWARF 3 extensions.
pub const push_object_address = 0x97;
pub const call2 = 0x98;
pub const call4 = 0x99;
pub const call_ref = 0x9a;
pub const form_tls_address = 0x9b;
pub const call_frame_cfa = 0x9c;
pub const bit_piece = 0x9d;

// DWARF 4 extensions.
pub const implicit_value = 0x9e;
pub const stack_value = 0x9f;

// DWARF 5 extensions.
pub const implicit_pointer = 0xa0;
pub const addrx = 0xa1;
pub const constx = 0xa2;
pub const entry_value = 0xa3;
pub const const_type = 0xa4;
pub const regval_type = 0xa5;
pub const deref_type = 0xa6;
pub const xderef_type = 0xa7;
pub const convert = 0xa8;
pub const reinterpret = 0xa9;

pub const lo_user = 0xe0; // Implementation-defined range start.
pub const hi_user = 0xff; // Implementation-defined range end.

// GNU extensions.
pub const GNU_push_tls_address = 0xe0;
// The following is for marking variables that are uninitialized.
pub const GNU_uninit = 0xf0;
pub const GNU_encoded_addr = 0xf1;
// The GNU implicit pointer extension.
// See http://www.dwarfstd.org/ShowIssue.php?issue=100831.1&type=open .
pub const GNU_implicit_pointer = 0xf2;
// The GNU entry value extension.
// See http://www.dwarfstd.org/ShowIssue.php?issue=100909.1&type=open .
pub const GNU_entry_value = 0xf3;
// The GNU typed stack extension.
// See http://www.dwarfstd.org/doc/040408.1.html .
pub const GNU_const_type = 0xf4;
pub const GNU_regval_type = 0xf5;
pub const GNU_deref_type = 0xf6;
pub const GNU_convert = 0xf7;
pub const GNU_reinterpret = 0xf9;
// The GNU parameter ref extension.
pub const GNU_parameter_ref = 0xfa;
// Extension for Fission.  See http://gcc.gnu.org/wiki/DebugFission.
pub const GNU_addr_index = 0xfb;
pub const GNU_const_index = 0xfc;
// HP extensions.
pub const HP_unknown = 0xe0; // Ouch, the same as GNU_push_tls_address.
pub const HP_is_value = 0xe1;
pub const HP_fltconst4 = 0xe2;
pub const HP_fltconst8 = 0xe3;
pub const HP_mod_range = 0xe4;
pub const HP_unmod_range = 0xe5;
pub const HP_tls = 0xe6;
// PGI (STMicroelectronics) extensions.
pub const PGI_omp_thread_num = 0xf8;
// Wasm extensions.
pub const WASM_location = 0xed;
pub const WASM_local = 0x00;
pub const WASM_global = 0x01;
pub const WASM_global_u32 = 0x03;
pub const WASM_operand_stack = 0x02;

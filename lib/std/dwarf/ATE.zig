pub const @"void" = 0x0;
pub const address = 0x1;
pub const boolean = 0x2;
pub const complex_float = 0x3;
pub const float = 0x4;
pub const signed = 0x5;
pub const signed_char = 0x6;
pub const unsigned = 0x7;
pub const unsigned_char = 0x8;

// DWARF 3.
pub const imaginary_float = 0x9;
pub const packed_decimal = 0xa;
pub const numeric_string = 0xb;
pub const edited = 0xc;
pub const signed_fixed = 0xd;
pub const unsigned_fixed = 0xe;
pub const decimal_float = 0xf;

// DWARF 4.
pub const UTF = 0x10;

// DWARF 5.
pub const UCS = 0x11;
pub const ASCII = 0x12;

pub const lo_user = 0x80;
pub const hi_user = 0xff;

// HP extensions.
pub const HP_float80 = 0x80; // Floating-point (80 bit).
pub const HP_complex_float80 = 0x81; // Complex floating-point (80 bit).
pub const HP_float128 = 0x82; // Floating-point (128 bit).
pub const HP_complex_float128 = 0x83; // Complex fp (128 bit).
pub const HP_floathpintel = 0x84; // Floating-point (82 bit IA64).
pub const HP_imaginary_float80 = 0x85;
pub const HP_imaginary_float128 = 0x86;
pub const HP_VAX_float = 0x88; // F or G floating.
pub const HP_VAX_float_d = 0x89; // D floating.
pub const HP_packed_decimal = 0x8a; // Cobol.
pub const HP_zoned_decimal = 0x8b; // Cobol.
pub const HP_edited = 0x8c; // Cobol.
pub const HP_signed_fixed = 0x8d; // Cobol.
pub const HP_unsigned_fixed = 0x8e; // Cobol.
pub const HP_VAX_complex_float = 0x8f; // F or G floating complex.
pub const HP_VAX_complex_float_d = 0x90; // D floating complex.

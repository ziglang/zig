pub const padding = 0x00;
pub const array_type = 0x01;
pub const class_type = 0x02;
pub const entry_point = 0x03;
pub const enumeration_type = 0x04;
pub const formal_parameter = 0x05;
pub const imported_declaration = 0x08;
pub const label = 0x0a;
pub const lexical_block = 0x0b;
pub const member = 0x0d;
pub const pointer_type = 0x0f;
pub const reference_type = 0x10;
pub const compile_unit = 0x11;
pub const string_type = 0x12;
pub const structure_type = 0x13;
pub const subroutine = 0x14;
pub const subroutine_type = 0x15;
pub const typedef = 0x16;
pub const union_type = 0x17;
pub const unspecified_parameters = 0x18;
pub const variant = 0x19;
pub const common_block = 0x1a;
pub const common_inclusion = 0x1b;
pub const inheritance = 0x1c;
pub const inlined_subroutine = 0x1d;
pub const module = 0x1e;
pub const ptr_to_member_type = 0x1f;
pub const set_type = 0x20;
pub const subrange_type = 0x21;
pub const with_stmt = 0x22;
pub const access_declaration = 0x23;
pub const base_type = 0x24;
pub const catch_block = 0x25;
pub const const_type = 0x26;
pub const constant = 0x27;
pub const enumerator = 0x28;
pub const file_type = 0x29;
pub const friend = 0x2a;
pub const namelist = 0x2b;
pub const namelist_item = 0x2c;
pub const packed_type = 0x2d;
pub const subprogram = 0x2e;
pub const template_type_param = 0x2f;
pub const template_value_param = 0x30;
pub const thrown_type = 0x31;
pub const try_block = 0x32;
pub const variant_part = 0x33;
pub const variable = 0x34;
pub const volatile_type = 0x35;

// DWARF 3
pub const dwarf_procedure = 0x36;
pub const restrict_type = 0x37;
pub const interface_type = 0x38;
pub const namespace = 0x39;
pub const imported_module = 0x3a;
pub const unspecified_type = 0x3b;
pub const partial_unit = 0x3c;
pub const imported_unit = 0x3d;
pub const condition = 0x3f;
pub const shared_type = 0x40;

// DWARF 4
pub const type_unit = 0x41;
pub const rvalue_reference_type = 0x42;
pub const template_alias = 0x43;

// DWARF 5
pub const coarray_type = 0x44;
pub const generic_subrange = 0x45;
pub const dynamic_type = 0x46;
pub const atomic_type = 0x47;
pub const call_site = 0x48;
pub const call_site_parameter = 0x49;
pub const skeleton_unit = 0x4a;
pub const immutable_type = 0x4b;

pub const lo_user = 0x4080;
pub const hi_user = 0xffff;

// SGI/MIPS Extensions.
pub const MIPS_loop = 0x4081;

// HP extensions.  See: ftp://ftp.hp.com/pub/lang/tools/WDB/wdb-4.0.tar.gz .
pub const HP_array_descriptor = 0x4090;
pub const HP_Bliss_field = 0x4091;
pub const HP_Bliss_field_set = 0x4092;

// GNU extensions.
pub const format_label = 0x4101; // For FORTRAN 77 and Fortran 90.
pub const function_template = 0x4102; // For C++.
pub const class_template = 0x4103; //For C++.
pub const GNU_BINCL = 0x4104;
pub const GNU_EINCL = 0x4105;

// Template template parameter.
// See http://gcc.gnu.org/wiki/TemplateParmsDwarf .
pub const GNU_template_template_param = 0x4106;

// Template parameter pack extension = specified at
// http://wiki.dwarfstd.org/index.php?title=C%2B%2B0x:_Variadic_templates
// The values of these two TAGS are in the DW_TAG_GNU_* space until the tags
// are properly part of DWARF 5.
pub const GNU_template_parameter_pack = 0x4107;
pub const GNU_formal_parameter_pack = 0x4108;
// The GNU call site extension = specified at
// http://www.dwarfstd.org/ShowIssue.php?issue=100909.2&type=open .
// The values of these two TAGS are in the DW_TAG_GNU_* space until the tags
// are properly part of DWARF 5.
pub const GNU_call_site = 0x4109;
pub const GNU_call_site_parameter = 0x410a;
// Extensions for UPC.  See: http://dwarfstd.org/doc/DWARF4.pdf.
pub const upc_shared_type = 0x8765;
pub const upc_strict_type = 0x8766;
pub const upc_relaxed_type = 0x8767;
// PGI (STMicroelectronics; extensions.  No documentation available.
pub const PGI_kanji_type = 0xA000;
pub const PGI_interface_block = 0xA020;

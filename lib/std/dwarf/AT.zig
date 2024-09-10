pub const sibling = 0x01;
pub const location = 0x02;
pub const name = 0x03;
pub const ordering = 0x09;
pub const subscr_data = 0x0a;
pub const byte_size = 0x0b;
pub const bit_offset = 0x0c;
pub const bit_size = 0x0d;
pub const element_list = 0x0f;
pub const stmt_list = 0x10;
pub const low_pc = 0x11;
pub const high_pc = 0x12;
pub const language = 0x13;
pub const member = 0x14;
pub const discr = 0x15;
pub const discr_value = 0x16;
pub const visibility = 0x17;
pub const import = 0x18;
pub const string_length = 0x19;
pub const common_reference = 0x1a;
pub const comp_dir = 0x1b;
pub const const_value = 0x1c;
pub const containing_type = 0x1d;
pub const default_value = 0x1e;
pub const @"inline" = 0x20;
pub const is_optional = 0x21;
pub const lower_bound = 0x22;
pub const producer = 0x25;
pub const prototyped = 0x27;
pub const return_addr = 0x2a;
pub const start_scope = 0x2c;
pub const bit_stride = 0x2e;
pub const upper_bound = 0x2f;
pub const abstract_origin = 0x31;
pub const accessibility = 0x32;
pub const address_class = 0x33;
pub const artificial = 0x34;
pub const base_types = 0x35;
pub const calling_convention = 0x36;
pub const count = 0x37;
pub const data_member_location = 0x38;
pub const decl_column = 0x39;
pub const decl_file = 0x3a;
pub const decl_line = 0x3b;
pub const declaration = 0x3c;
pub const discr_list = 0x3d;
pub const encoding = 0x3e;
pub const external = 0x3f;
pub const frame_base = 0x40;
pub const friend = 0x41;
pub const identifier_case = 0x42;
pub const macro_info = 0x43;
pub const namelist_items = 0x44;
pub const priority = 0x45;
pub const segment = 0x46;
pub const specification = 0x47;
pub const static_link = 0x48;
pub const @"type" = 0x49;
pub const use_location = 0x4a;
pub const variable_parameter = 0x4b;
pub const virtuality = 0x4c;
pub const vtable_elem_location = 0x4d;

// DWARF 3 values.
pub const allocated = 0x4e;
pub const associated = 0x4f;
pub const data_location = 0x50;
pub const byte_stride = 0x51;
pub const entry_pc = 0x52;
pub const use_UTF8 = 0x53;
pub const extension = 0x54;
pub const ranges = 0x55;
pub const trampoline = 0x56;
pub const call_column = 0x57;
pub const call_file = 0x58;
pub const call_line = 0x59;
pub const description = 0x5a;
pub const binary_scale = 0x5b;
pub const decimal_scale = 0x5c;
pub const small = 0x5d;
pub const decimal_sign = 0x5e;
pub const digit_count = 0x5f;
pub const picture_string = 0x60;
pub const mutable = 0x61;
pub const threads_scaled = 0x62;
pub const explicit = 0x63;
pub const object_pointer = 0x64;
pub const endianity = 0x65;
pub const elemental = 0x66;
pub const pure = 0x67;
pub const recursive = 0x68;

// DWARF 4.
pub const signature = 0x69;
pub const main_subprogram = 0x6a;
pub const data_bit_offset = 0x6b;
pub const const_expr = 0x6c;
pub const enum_class = 0x6d;
pub const linkage_name = 0x6e;

// DWARF 5
pub const string_length_bit_size = 0x6f;
pub const string_length_byte_size = 0x70;
pub const rank = 0x71;
pub const str_offsets_base = 0x72;
pub const addr_base = 0x73;
pub const rnglists_base = 0x74;
pub const dwo_name = 0x76;
pub const reference = 0x77;
pub const rvalue_reference = 0x78;
pub const macros = 0x79;
pub const call_all_calls = 0x7a;
pub const call_all_source_calls = 0x7b;
pub const call_all_tail_calls = 0x7c;
pub const call_return_pc = 0x7d;
pub const call_value = 0x7e;
pub const call_origin = 0x7f;
pub const call_parameter = 0x80;
pub const call_pc = 0x81;
pub const call_tail_call = 0x82;
pub const call_target = 0x83;
pub const call_target_clobbered = 0x84;
pub const call_data_location = 0x85;
pub const call_data_value = 0x86;
pub const @"noreturn" = 0x87;
pub const alignment = 0x88;
pub const export_symbols = 0x89;
pub const deleted = 0x8a;
pub const defaulted = 0x8b;
pub const loclists_base = 0x8c;

pub const lo_user = 0x2000; // Implementation-defined range start.
pub const hi_user = 0x3fff; // Implementation-defined range end.

// SGI/MIPS extensions.
pub const MIPS_fde = 0x2001;
pub const MIPS_loop_begin = 0x2002;
pub const MIPS_tail_loop_begin = 0x2003;
pub const MIPS_epilog_begin = 0x2004;
pub const MIPS_loop_unroll_factor = 0x2005;
pub const MIPS_software_pipeline_depth = 0x2006;
pub const MIPS_linkage_name = 0x2007;
pub const MIPS_stride = 0x2008;
pub const MIPS_abstract_name = 0x2009;
pub const MIPS_clone_origin = 0x200a;
pub const MIPS_has_inlines = 0x200b;

// HP extensions.
pub const HP_block_index = 0x2000;
pub const HP_unmodifiable = 0x2001; // Same as AT.MIPS_fde.
pub const HP_prologue = 0x2005; // Same as AT.MIPS_loop_unroll.
pub const HP_epilogue = 0x2008; // Same as AT.MIPS_stride.
pub const HP_actuals_stmt_list = 0x2010;
pub const HP_proc_per_section = 0x2011;
pub const HP_raw_data_ptr = 0x2012;
pub const HP_pass_by_reference = 0x2013;
pub const HP_opt_level = 0x2014;
pub const HP_prof_version_id = 0x2015;
pub const HP_opt_flags = 0x2016;
pub const HP_cold_region_low_pc = 0x2017;
pub const HP_cold_region_high_pc = 0x2018;
pub const HP_all_variables_modifiable = 0x2019;
pub const HP_linkage_name = 0x201a;
pub const HP_prof_flags = 0x201b; // In comp unit of procs_info for -g.
pub const HP_unit_name = 0x201f;
pub const HP_unit_size = 0x2020;
pub const HP_widened_byte_size = 0x2021;
pub const HP_definition_points = 0x2022;
pub const HP_default_location = 0x2023;
pub const HP_is_result_param = 0x2029;

// GNU extensions.
pub const sf_names = 0x2101;
pub const src_info = 0x2102;
pub const mac_info = 0x2103;
pub const src_coords = 0x2104;
pub const body_begin = 0x2105;
pub const body_end = 0x2106;
pub const GNU_vector = 0x2107;
// Thread-safety annotations.
// See http://gcc.gnu.org/wiki/ThreadSafetyAnnotation .
pub const GNU_guarded_by = 0x2108;
pub const GNU_pt_guarded_by = 0x2109;
pub const GNU_guarded = 0x210a;
pub const GNU_pt_guarded = 0x210b;
pub const GNU_locks_excluded = 0x210c;
pub const GNU_exclusive_locks_required = 0x210d;
pub const GNU_shared_locks_required = 0x210e;
// One-definition rule violation detection.
// See http://gcc.gnu.org/wiki/DwarfSeparateTypeInfo .
pub const GNU_odr_signature = 0x210f;
// Template template argument name.
// See http://gcc.gnu.org/wiki/TemplateParmsDwarf .
pub const GNU_template_name = 0x2110;
// The GNU call site extension.
// See http://www.dwarfstd.org/ShowIssue.php?issue=100909.2&type=open .
pub const GNU_call_site_value = 0x2111;
pub const GNU_call_site_data_value = 0x2112;
pub const GNU_call_site_target = 0x2113;
pub const GNU_call_site_target_clobbered = 0x2114;
pub const GNU_tail_call = 0x2115;
pub const GNU_all_tail_call_sites = 0x2116;
pub const GNU_all_call_sites = 0x2117;
pub const GNU_all_source_call_sites = 0x2118;
// Section offset into .debug_macro section.
pub const GNU_macros = 0x2119;
// Extensions for Fission.  See http://gcc.gnu.org/wiki/DebugFission.
pub const GNU_dwo_name = 0x2130;
pub const GNU_dwo_id = 0x2131;
pub const GNU_ranges_base = 0x2132;
pub const GNU_addr_base = 0x2133;
pub const GNU_pubnames = 0x2134;
pub const GNU_pubtypes = 0x2135;
// VMS extensions.
pub const VMS_rtnbeg_pd_address = 0x2201;
// GNAT extensions.
// GNAT descriptive type.
// See http://gcc.gnu.org/wiki/DW_AT_GNAT_descriptive_type .
pub const use_GNAT_descriptive_type = 0x2301;
pub const GNAT_descriptive_type = 0x2302;

// Zig extensions.
pub const ZIG_parent = 0x2ccd;
pub const ZIG_padding = 0x2cce;
pub const ZIG_relative_decl = 0x2cd0;
pub const ZIG_decl_line_relative = 0x2cd1;
pub const ZIG_sentinel = 0x2ce2;

// UPC extension.
pub const upc_threads_scaled = 0x3210;
// PGI (STMicroelectronics) extensions.
pub const PGI_lbase = 0x3a00;
pub const PGI_soffset = 0x3a01;
pub const PGI_lstride = 0x3a02;

pub const TAG_padding = 0x00;
pub const TAG_array_type = 0x01;
pub const TAG_class_type = 0x02;
pub const TAG_entry_point = 0x03;
pub const TAG_enumeration_type = 0x04;
pub const TAG_formal_parameter = 0x05;
pub const TAG_imported_declaration = 0x08;
pub const TAG_label = 0x0a;
pub const TAG_lexical_block = 0x0b;
pub const TAG_member = 0x0d;
pub const TAG_pointer_type = 0x0f;
pub const TAG_reference_type = 0x10;
pub const TAG_compile_unit = 0x11;
pub const TAG_string_type = 0x12;
pub const TAG_structure_type = 0x13;
pub const TAG_subroutine = 0x14;
pub const TAG_subroutine_type = 0x15;
pub const TAG_typedef = 0x16;
pub const TAG_union_type = 0x17;
pub const TAG_unspecified_parameters = 0x18;
pub const TAG_variant = 0x19;
pub const TAG_common_block = 0x1a;
pub const TAG_common_inclusion = 0x1b;
pub const TAG_inheritance = 0x1c;
pub const TAG_inlined_subroutine = 0x1d;
pub const TAG_module = 0x1e;
pub const TAG_ptr_to_member_type = 0x1f;
pub const TAG_set_type = 0x20;
pub const TAG_subrange_type = 0x21;
pub const TAG_with_stmt = 0x22;
pub const TAG_access_declaration = 0x23;
pub const TAG_base_type = 0x24;
pub const TAG_catch_block = 0x25;
pub const TAG_const_type = 0x26;
pub const TAG_constant = 0x27;
pub const TAG_enumerator = 0x28;
pub const TAG_file_type = 0x29;
pub const TAG_friend = 0x2a;
pub const TAG_namelist = 0x2b;
pub const TAG_namelist_item = 0x2c;
pub const TAG_packed_type = 0x2d;
pub const TAG_subprogram = 0x2e;
pub const TAG_template_type_param = 0x2f;
pub const TAG_template_value_param = 0x30;
pub const TAG_thrown_type = 0x31;
pub const TAG_try_block = 0x32;
pub const TAG_variant_part = 0x33;
pub const TAG_variable = 0x34;
pub const TAG_volatile_type = 0x35;

// DWARF 3
pub const TAG_dwarf_procedure = 0x36;
pub const TAG_restrict_type = 0x37;
pub const TAG_interface_type = 0x38;
pub const TAG_namespace = 0x39;
pub const TAG_imported_module = 0x3a;
pub const TAG_unspecified_type = 0x3b;
pub const TAG_partial_unit = 0x3c;
pub const TAG_imported_unit = 0x3d;
pub const TAG_condition = 0x3f;
pub const TAG_shared_type = 0x40;

// DWARF 4
pub const TAG_type_unit = 0x41;
pub const TAG_rvalue_reference_type = 0x42;
pub const TAG_template_alias = 0x43;

pub const TAG_lo_user = 0x4080;
pub const TAG_hi_user = 0xffff;

// SGI/MIPS Extensions.
pub const DW_TAG_MIPS_loop = 0x4081;

// HP extensions.  See: ftp://ftp.hp.com/pub/lang/tools/WDB/wdb-4.0.tar.gz .
pub const TAG_HP_array_descriptor = 0x4090;
pub const TAG_HP_Bliss_field = 0x4091;
pub const TAG_HP_Bliss_field_set = 0x4092;

// GNU extensions.
pub const TAG_format_label = 0x4101; // For FORTRAN 77 and Fortran 90.
pub const TAG_function_template = 0x4102; // For C++.
pub const TAG_class_template = 0x4103; //For C++.
pub const TAG_GNU_BINCL = 0x4104;
pub const TAG_GNU_EINCL = 0x4105;

// Template template parameter.
// See http://gcc.gnu.org/wiki/TemplateParmsDwarf .
pub const TAG_GNU_template_template_param = 0x4106;

// Template parameter pack extension = specified at
// http://wiki.dwarfstd.org/index.php?title=C%2B%2B0x:_Variadic_templates
// The values of these two TAGS are in the DW_TAG_GNU_* space until the tags
// are properly part of DWARF 5.
pub const TAG_GNU_template_parameter_pack = 0x4107;
pub const TAG_GNU_formal_parameter_pack = 0x4108;
// The GNU call site extension = specified at
// http://www.dwarfstd.org/ShowIssue.php?issue=100909.2&type=open .
// The values of these two TAGS are in the DW_TAG_GNU_* space until the tags
// are properly part of DWARF 5.
pub const TAG_GNU_call_site = 0x4109;
pub const TAG_GNU_call_site_parameter = 0x410a;
// Extensions for UPC.  See: http://dwarfstd.org/doc/DWARF4.pdf.
pub const TAG_upc_shared_type = 0x8765;
pub const TAG_upc_strict_type = 0x8766;
pub const TAG_upc_relaxed_type = 0x8767;
// PGI (STMicroelectronics; extensions.  No documentation available.
pub const TAG_PGI_kanji_type = 0xA000;
pub const TAG_PGI_interface_block = 0xA020;

pub const FORM_addr = 0x01;
pub const FORM_block2 = 0x03;
pub const FORM_block4 = 0x04;
pub const FORM_data2 = 0x05;
pub const FORM_data4 = 0x06;
pub const FORM_data8 = 0x07;
pub const FORM_string = 0x08;
pub const FORM_block = 0x09;
pub const FORM_block1 = 0x0a;
pub const FORM_data1 = 0x0b;
pub const FORM_flag = 0x0c;
pub const FORM_sdata = 0x0d;
pub const FORM_strp = 0x0e;
pub const FORM_udata = 0x0f;
pub const FORM_ref_addr = 0x10;
pub const FORM_ref1 = 0x11;
pub const FORM_ref2 = 0x12;
pub const FORM_ref4 = 0x13;
pub const FORM_ref8 = 0x14;
pub const FORM_ref_udata = 0x15;
pub const FORM_indirect = 0x16;
pub const FORM_sec_offset = 0x17;
pub const FORM_exprloc = 0x18;
pub const FORM_flag_present = 0x19;
pub const FORM_ref_sig8 = 0x20;

// Extensions for Fission.  See http://gcc.gnu.org/wiki/DebugFission.
pub const FORM_GNU_addr_index = 0x1f01;
pub const FORM_GNU_str_index = 0x1f02;

// Extensions for DWZ multifile.
// See http://www.dwarfstd.org/ShowIssue.php?issue=120604.1&type=open .
pub const FORM_GNU_ref_alt = 0x1f20;
pub const FORM_GNU_strp_alt = 0x1f21;

pub const AT_sibling = 0x01;
pub const AT_location = 0x02;
pub const AT_name = 0x03;
pub const AT_ordering = 0x09;
pub const AT_subscr_data = 0x0a;
pub const AT_byte_size = 0x0b;
pub const AT_bit_offset = 0x0c;
pub const AT_bit_size = 0x0d;
pub const AT_element_list = 0x0f;
pub const AT_stmt_list = 0x10;
pub const AT_low_pc = 0x11;
pub const AT_high_pc = 0x12;
pub const AT_language = 0x13;
pub const AT_member = 0x14;
pub const AT_discr = 0x15;
pub const AT_discr_value = 0x16;
pub const AT_visibility = 0x17;
pub const AT_import = 0x18;
pub const AT_string_length = 0x19;
pub const AT_common_reference = 0x1a;
pub const AT_comp_dir = 0x1b;
pub const AT_const_value = 0x1c;
pub const AT_containing_type = 0x1d;
pub const AT_default_value = 0x1e;
pub const AT_inline = 0x20;
pub const AT_is_optional = 0x21;
pub const AT_lower_bound = 0x22;
pub const AT_producer = 0x25;
pub const AT_prototyped = 0x27;
pub const AT_return_addr = 0x2a;
pub const AT_start_scope = 0x2c;
pub const AT_bit_stride = 0x2e;
pub const AT_upper_bound = 0x2f;
pub const AT_abstract_origin = 0x31;
pub const AT_accessibility = 0x32;
pub const AT_address_class = 0x33;
pub const AT_artificial = 0x34;
pub const AT_base_types = 0x35;
pub const AT_calling_convention = 0x36;
pub const AT_count = 0x37;
pub const AT_data_member_location = 0x38;
pub const AT_decl_column = 0x39;
pub const AT_decl_file = 0x3a;
pub const AT_decl_line = 0x3b;
pub const AT_declaration = 0x3c;
pub const AT_discr_list = 0x3d;
pub const AT_encoding = 0x3e;
pub const AT_external = 0x3f;
pub const AT_frame_base = 0x40;
pub const AT_friend = 0x41;
pub const AT_identifier_case = 0x42;
pub const AT_macro_info = 0x43;
pub const AT_namelist_items = 0x44;
pub const AT_priority = 0x45;
pub const AT_segment = 0x46;
pub const AT_specification = 0x47;
pub const AT_static_link = 0x48;
pub const AT_type = 0x49;
pub const AT_use_location = 0x4a;
pub const AT_variable_parameter = 0x4b;
pub const AT_virtuality = 0x4c;
pub const AT_vtable_elem_location = 0x4d;

// DWARF 3 values.
pub const AT_allocated = 0x4e;
pub const AT_associated = 0x4f;
pub const AT_data_location = 0x50;
pub const AT_byte_stride = 0x51;
pub const AT_entry_pc = 0x52;
pub const AT_use_UTF8 = 0x53;
pub const AT_extension = 0x54;
pub const AT_ranges = 0x55;
pub const AT_trampoline = 0x56;
pub const AT_call_column = 0x57;
pub const AT_call_file = 0x58;
pub const AT_call_line = 0x59;
pub const AT_description = 0x5a;
pub const AT_binary_scale = 0x5b;
pub const AT_decimal_scale = 0x5c;
pub const AT_small = 0x5d;
pub const AT_decimal_sign = 0x5e;
pub const AT_digit_count = 0x5f;
pub const AT_picture_string = 0x60;
pub const AT_mutable = 0x61;
pub const AT_threads_scaled = 0x62;
pub const AT_explicit = 0x63;
pub const AT_object_pointer = 0x64;
pub const AT_endianity = 0x65;
pub const AT_elemental = 0x66;
pub const AT_pure = 0x67;
pub const AT_recursive = 0x68;

// DWARF 4.
pub const AT_signature = 0x69;
pub const AT_main_subprogram = 0x6a;
pub const AT_data_bit_offset = 0x6b;
pub const AT_const_expr = 0x6c;
pub const AT_enum_class = 0x6d;
pub const AT_linkage_name = 0x6e;

// DWARF 5
pub const AT_alignment = 0x88;

pub const AT_lo_user = 0x2000; // Implementation-defined range start.
pub const AT_hi_user = 0x3fff; // Implementation-defined range end.

// SGI/MIPS extensions.
pub const AT_MIPS_fde = 0x2001;
pub const AT_MIPS_loop_begin = 0x2002;
pub const AT_MIPS_tail_loop_begin = 0x2003;
pub const AT_MIPS_epilog_begin = 0x2004;
pub const AT_MIPS_loop_unroll_factor = 0x2005;
pub const AT_MIPS_software_pipeline_depth = 0x2006;
pub const AT_MIPS_linkage_name = 0x2007;
pub const AT_MIPS_stride = 0x2008;
pub const AT_MIPS_abstract_name = 0x2009;
pub const AT_MIPS_clone_origin = 0x200a;
pub const AT_MIPS_has_inlines = 0x200b;

// HP extensions.
pub const AT_HP_block_index = 0x2000;
pub const AT_HP_unmodifiable = 0x2001; // Same as DW_AT_MIPS_fde.
pub const AT_HP_prologue = 0x2005; // Same as DW_AT_MIPS_loop_unroll.
pub const AT_HP_epilogue = 0x2008; // Same as DW_AT_MIPS_stride.
pub const AT_HP_actuals_stmt_list = 0x2010;
pub const AT_HP_proc_per_section = 0x2011;
pub const AT_HP_raw_data_ptr = 0x2012;
pub const AT_HP_pass_by_reference = 0x2013;
pub const AT_HP_opt_level = 0x2014;
pub const AT_HP_prof_version_id = 0x2015;
pub const AT_HP_opt_flags = 0x2016;
pub const AT_HP_cold_region_low_pc = 0x2017;
pub const AT_HP_cold_region_high_pc = 0x2018;
pub const AT_HP_all_variables_modifiable = 0x2019;
pub const AT_HP_linkage_name = 0x201a;
pub const AT_HP_prof_flags = 0x201b; // In comp unit of procs_info for -g.
pub const AT_HP_unit_name = 0x201f;
pub const AT_HP_unit_size = 0x2020;
pub const AT_HP_widened_byte_size = 0x2021;
pub const AT_HP_definition_points = 0x2022;
pub const AT_HP_default_location = 0x2023;
pub const AT_HP_is_result_param = 0x2029;

// GNU extensions.
pub const AT_sf_names = 0x2101;
pub const AT_src_info = 0x2102;
pub const AT_mac_info = 0x2103;
pub const AT_src_coords = 0x2104;
pub const AT_body_begin = 0x2105;
pub const AT_body_end = 0x2106;
pub const AT_GNU_vector = 0x2107;
// Thread-safety annotations.
// See http://gcc.gnu.org/wiki/ThreadSafetyAnnotation .
pub const AT_GNU_guarded_by = 0x2108;
pub const AT_GNU_pt_guarded_by = 0x2109;
pub const AT_GNU_guarded = 0x210a;
pub const AT_GNU_pt_guarded = 0x210b;
pub const AT_GNU_locks_excluded = 0x210c;
pub const AT_GNU_exclusive_locks_required = 0x210d;
pub const AT_GNU_shared_locks_required = 0x210e;
// One-definition rule violation detection.
// See http://gcc.gnu.org/wiki/DwarfSeparateTypeInfo .
pub const AT_GNU_odr_signature = 0x210f;
// Template template argument name.
// See http://gcc.gnu.org/wiki/TemplateParmsDwarf .
pub const AT_GNU_template_name = 0x2110;
// The GNU call site extension.
// See http://www.dwarfstd.org/ShowIssue.php?issue=100909.2&type=open .
pub const AT_GNU_call_site_value = 0x2111;
pub const AT_GNU_call_site_data_value = 0x2112;
pub const AT_GNU_call_site_target = 0x2113;
pub const AT_GNU_call_site_target_clobbered = 0x2114;
pub const AT_GNU_tail_call = 0x2115;
pub const AT_GNU_all_tail_call_sites = 0x2116;
pub const AT_GNU_all_call_sites = 0x2117;
pub const AT_GNU_all_source_call_sites = 0x2118;
// Section offset into .debug_macro section.
pub const AT_GNU_macros = 0x2119;
// Extensions for Fission.  See http://gcc.gnu.org/wiki/DebugFission.
pub const AT_GNU_dwo_name = 0x2130;
pub const AT_GNU_dwo_id = 0x2131;
pub const AT_GNU_ranges_base = 0x2132;
pub const AT_GNU_addr_base = 0x2133;
pub const AT_GNU_pubnames = 0x2134;
pub const AT_GNU_pubtypes = 0x2135;
// VMS extensions.
pub const AT_VMS_rtnbeg_pd_address = 0x2201;
// GNAT extensions.
// GNAT descriptive type.
// See http://gcc.gnu.org/wiki/DW_AT_GNAT_descriptive_type .
pub const AT_use_GNAT_descriptive_type = 0x2301;
pub const AT_GNAT_descriptive_type = 0x2302;
// UPC extension.
pub const AT_upc_threads_scaled = 0x3210;
// PGI (STMicroelectronics) extensions.
pub const AT_PGI_lbase = 0x3a00;
pub const AT_PGI_soffset = 0x3a01;
pub const AT_PGI_lstride = 0x3a02;

pub const OP_addr = 0x03;
pub const OP_deref = 0x06;
pub const OP_const1u = 0x08;
pub const OP_const1s = 0x09;
pub const OP_const2u = 0x0a;
pub const OP_const2s = 0x0b;
pub const OP_const4u = 0x0c;
pub const OP_const4s = 0x0d;
pub const OP_const8u = 0x0e;
pub const OP_const8s = 0x0f;
pub const OP_constu = 0x10;
pub const OP_consts = 0x11;
pub const OP_dup = 0x12;
pub const OP_drop = 0x13;
pub const OP_over = 0x14;
pub const OP_pick = 0x15;
pub const OP_swap = 0x16;
pub const OP_rot = 0x17;
pub const OP_xderef = 0x18;
pub const OP_abs = 0x19;
pub const OP_and = 0x1a;
pub const OP_div = 0x1b;
pub const OP_minus = 0x1c;
pub const OP_mod = 0x1d;
pub const OP_mul = 0x1e;
pub const OP_neg = 0x1f;
pub const OP_not = 0x20;
pub const OP_or = 0x21;
pub const OP_plus = 0x22;
pub const OP_plus_uconst = 0x23;
pub const OP_shl = 0x24;
pub const OP_shr = 0x25;
pub const OP_shra = 0x26;
pub const OP_xor = 0x27;
pub const OP_bra = 0x28;
pub const OP_eq = 0x29;
pub const OP_ge = 0x2a;
pub const OP_gt = 0x2b;
pub const OP_le = 0x2c;
pub const OP_lt = 0x2d;
pub const OP_ne = 0x2e;
pub const OP_skip = 0x2f;
pub const OP_lit0 = 0x30;
pub const OP_lit1 = 0x31;
pub const OP_lit2 = 0x32;
pub const OP_lit3 = 0x33;
pub const OP_lit4 = 0x34;
pub const OP_lit5 = 0x35;
pub const OP_lit6 = 0x36;
pub const OP_lit7 = 0x37;
pub const OP_lit8 = 0x38;
pub const OP_lit9 = 0x39;
pub const OP_lit10 = 0x3a;
pub const OP_lit11 = 0x3b;
pub const OP_lit12 = 0x3c;
pub const OP_lit13 = 0x3d;
pub const OP_lit14 = 0x3e;
pub const OP_lit15 = 0x3f;
pub const OP_lit16 = 0x40;
pub const OP_lit17 = 0x41;
pub const OP_lit18 = 0x42;
pub const OP_lit19 = 0x43;
pub const OP_lit20 = 0x44;
pub const OP_lit21 = 0x45;
pub const OP_lit22 = 0x46;
pub const OP_lit23 = 0x47;
pub const OP_lit24 = 0x48;
pub const OP_lit25 = 0x49;
pub const OP_lit26 = 0x4a;
pub const OP_lit27 = 0x4b;
pub const OP_lit28 = 0x4c;
pub const OP_lit29 = 0x4d;
pub const OP_lit30 = 0x4e;
pub const OP_lit31 = 0x4f;
pub const OP_reg0 = 0x50;
pub const OP_reg1 = 0x51;
pub const OP_reg2 = 0x52;
pub const OP_reg3 = 0x53;
pub const OP_reg4 = 0x54;
pub const OP_reg5 = 0x55;
pub const OP_reg6 = 0x56;
pub const OP_reg7 = 0x57;
pub const OP_reg8 = 0x58;
pub const OP_reg9 = 0x59;
pub const OP_reg10 = 0x5a;
pub const OP_reg11 = 0x5b;
pub const OP_reg12 = 0x5c;
pub const OP_reg13 = 0x5d;
pub const OP_reg14 = 0x5e;
pub const OP_reg15 = 0x5f;
pub const OP_reg16 = 0x60;
pub const OP_reg17 = 0x61;
pub const OP_reg18 = 0x62;
pub const OP_reg19 = 0x63;
pub const OP_reg20 = 0x64;
pub const OP_reg21 = 0x65;
pub const OP_reg22 = 0x66;
pub const OP_reg23 = 0x67;
pub const OP_reg24 = 0x68;
pub const OP_reg25 = 0x69;
pub const OP_reg26 = 0x6a;
pub const OP_reg27 = 0x6b;
pub const OP_reg28 = 0x6c;
pub const OP_reg29 = 0x6d;
pub const OP_reg30 = 0x6e;
pub const OP_reg31 = 0x6f;
pub const OP_breg0 = 0x70;
pub const OP_breg1 = 0x71;
pub const OP_breg2 = 0x72;
pub const OP_breg3 = 0x73;
pub const OP_breg4 = 0x74;
pub const OP_breg5 = 0x75;
pub const OP_breg6 = 0x76;
pub const OP_breg7 = 0x77;
pub const OP_breg8 = 0x78;
pub const OP_breg9 = 0x79;
pub const OP_breg10 = 0x7a;
pub const OP_breg11 = 0x7b;
pub const OP_breg12 = 0x7c;
pub const OP_breg13 = 0x7d;
pub const OP_breg14 = 0x7e;
pub const OP_breg15 = 0x7f;
pub const OP_breg16 = 0x80;
pub const OP_breg17 = 0x81;
pub const OP_breg18 = 0x82;
pub const OP_breg19 = 0x83;
pub const OP_breg20 = 0x84;
pub const OP_breg21 = 0x85;
pub const OP_breg22 = 0x86;
pub const OP_breg23 = 0x87;
pub const OP_breg24 = 0x88;
pub const OP_breg25 = 0x89;
pub const OP_breg26 = 0x8a;
pub const OP_breg27 = 0x8b;
pub const OP_breg28 = 0x8c;
pub const OP_breg29 = 0x8d;
pub const OP_breg30 = 0x8e;
pub const OP_breg31 = 0x8f;
pub const OP_regx = 0x90;
pub const OP_fbreg = 0x91;
pub const OP_bregx = 0x92;
pub const OP_piece = 0x93;
pub const OP_deref_size = 0x94;
pub const OP_xderef_size = 0x95;
pub const OP_nop = 0x96;

// DWARF 3 extensions.
pub const OP_push_object_address = 0x97;
pub const OP_call2 = 0x98;
pub const OP_call4 = 0x99;
pub const OP_call_ref = 0x9a;
pub const OP_form_tls_address = 0x9b;
pub const OP_call_frame_cfa = 0x9c;
pub const OP_bit_piece = 0x9d;

// DWARF 4 extensions.
pub const OP_implicit_value = 0x9e;
pub const OP_stack_value = 0x9f;

pub const OP_lo_user = 0xe0; // Implementation-defined range start.
pub const OP_hi_user = 0xff; // Implementation-defined range end.

// GNU extensions.
pub const OP_GNU_push_tls_address = 0xe0;
// The following is for marking variables that are uninitialized.
pub const OP_GNU_uninit = 0xf0;
pub const OP_GNU_encoded_addr = 0xf1;
// The GNU implicit pointer extension.
// See http://www.dwarfstd.org/ShowIssue.php?issue=100831.1&type=open .
pub const OP_GNU_implicit_pointer = 0xf2;
// The GNU entry value extension.
// See http://www.dwarfstd.org/ShowIssue.php?issue=100909.1&type=open .
pub const OP_GNU_entry_value = 0xf3;
// The GNU typed stack extension.
// See http://www.dwarfstd.org/doc/040408.1.html .
pub const OP_GNU_const_type = 0xf4;
pub const OP_GNU_regval_type = 0xf5;
pub const OP_GNU_deref_type = 0xf6;
pub const OP_GNU_convert = 0xf7;
pub const OP_GNU_reinterpret = 0xf9;
// The GNU parameter ref extension.
pub const OP_GNU_parameter_ref = 0xfa;
// Extension for Fission.  See http://gcc.gnu.org/wiki/DebugFission.
pub const OP_GNU_addr_index = 0xfb;
pub const OP_GNU_const_index = 0xfc;
// HP extensions.
pub const OP_HP_unknown = 0xe0; // Ouch, the same as GNU_push_tls_address.
pub const OP_HP_is_value = 0xe1;
pub const OP_HP_fltconst4 = 0xe2;
pub const OP_HP_fltconst8 = 0xe3;
pub const OP_HP_mod_range = 0xe4;
pub const OP_HP_unmod_range = 0xe5;
pub const OP_HP_tls = 0xe6;
// PGI (STMicroelectronics) extensions.
pub const OP_PGI_omp_thread_num = 0xf8;

pub const ATE_void = 0x0;
pub const ATE_address = 0x1;
pub const ATE_boolean = 0x2;
pub const ATE_complex_float = 0x3;
pub const ATE_float = 0x4;
pub const ATE_signed = 0x5;
pub const ATE_signed_char = 0x6;
pub const ATE_unsigned = 0x7;
pub const ATE_unsigned_char = 0x8;

// DWARF 3.
pub const ATE_imaginary_float = 0x9;
pub const ATE_packed_decimal = 0xa;
pub const ATE_numeric_string = 0xb;
pub const ATE_edited = 0xc;
pub const ATE_signed_fixed = 0xd;
pub const ATE_unsigned_fixed = 0xe;
pub const ATE_decimal_float = 0xf;

// DWARF 4.
pub const ATE_UTF = 0x10;

pub const ATE_lo_user = 0x80;
pub const ATE_hi_user = 0xff;

// HP extensions.
pub const ATE_HP_float80 = 0x80; // Floating-point (80 bit).
pub const ATE_HP_complex_float80 = 0x81; // Complex floating-point (80 bit).
pub const ATE_HP_float128 = 0x82; // Floating-point (128 bit).
pub const ATE_HP_complex_float128 = 0x83; // Complex fp (128 bit).
pub const ATE_HP_floathpintel = 0x84; // Floating-point (82 bit IA64).
pub const ATE_HP_imaginary_float80 = 0x85;
pub const ATE_HP_imaginary_float128 = 0x86;
pub const ATE_HP_VAX_float = 0x88; // F or G floating.
pub const ATE_HP_VAX_float_d = 0x89; // D floating.
pub const ATE_HP_packed_decimal = 0x8a; // Cobol.
pub const ATE_HP_zoned_decimal = 0x8b; // Cobol.
pub const ATE_HP_edited = 0x8c; // Cobol.
pub const ATE_HP_signed_fixed = 0x8d; // Cobol.
pub const ATE_HP_unsigned_fixed = 0x8e; // Cobol.
pub const ATE_HP_VAX_complex_float = 0x8f; // F or G floating complex.
pub const ATE_HP_VAX_complex_float_d = 0x90; // D floating complex.

pub const CFA_advance_loc = 0x40;
pub const CFA_offset = 0x80;
pub const CFA_restore = 0xc0;
pub const CFA_nop = 0x00;
pub const CFA_set_loc = 0x01;
pub const CFA_advance_loc1 = 0x02;
pub const CFA_advance_loc2 = 0x03;
pub const CFA_advance_loc4 = 0x04;
pub const CFA_offset_extended = 0x05;
pub const CFA_restore_extended = 0x06;
pub const CFA_undefined = 0x07;
pub const CFA_same_value = 0x08;
pub const CFA_register = 0x09;
pub const CFA_remember_state = 0x0a;
pub const CFA_restore_state = 0x0b;
pub const CFA_def_cfa = 0x0c;
pub const CFA_def_cfa_register = 0x0d;
pub const CFA_def_cfa_offset = 0x0e;

// DWARF 3.
pub const CFA_def_cfa_expression = 0x0f;
pub const CFA_expression = 0x10;
pub const CFA_offset_extended_sf = 0x11;
pub const CFA_def_cfa_sf = 0x12;
pub const CFA_def_cfa_offset_sf = 0x13;
pub const CFA_val_offset = 0x14;
pub const CFA_val_offset_sf = 0x15;
pub const CFA_val_expression = 0x16;

pub const CFA_lo_user = 0x1c;
pub const CFA_hi_user = 0x3f;

// SGI/MIPS specific.
pub const CFA_MIPS_advance_loc8 = 0x1d;

// GNU extensions.
pub const CFA_GNU_window_save = 0x2d;
pub const CFA_GNU_args_size = 0x2e;
pub const CFA_GNU_negative_offset_extended = 0x2f;

pub const CHILDREN_no = 0x00;
pub const CHILDREN_yes = 0x01;

pub const LNS_extended_op = 0x00;
pub const LNS_copy = 0x01;
pub const LNS_advance_pc = 0x02;
pub const LNS_advance_line = 0x03;
pub const LNS_set_file = 0x04;
pub const LNS_set_column = 0x05;
pub const LNS_negate_stmt = 0x06;
pub const LNS_set_basic_block = 0x07;
pub const LNS_const_add_pc = 0x08;
pub const LNS_fixed_advance_pc = 0x09;
pub const LNS_set_prologue_end = 0x0a;
pub const LNS_set_epilogue_begin = 0x0b;
pub const LNS_set_isa = 0x0c;

pub const LNE_end_sequence = 0x01;
pub const LNE_set_address = 0x02;
pub const LNE_define_file = 0x03;
pub const LNE_set_discriminator = 0x04;
pub const LNE_lo_user = 0x80;
pub const LNE_hi_user = 0xff;

pub const LANG_C89 = 0x0001;
pub const LANG_C = 0x0002;
pub const LANG_Ada83 = 0x0003;
pub const LANG_C_plus_plus = 0x0004;
pub const LANG_Cobol74 = 0x0005;
pub const LANG_Cobol85 = 0x0006;
pub const LANG_Fortran77 = 0x0007;
pub const LANG_Fortran90 = 0x0008;
pub const LANG_Pascal83 = 0x0009;
pub const LANG_Modula2 = 0x000a;
pub const LANG_Java = 0x000b;
pub const LANG_C99 = 0x000c;
pub const LANG_Ada95 = 0x000d;
pub const LANG_Fortran95 = 0x000e;
pub const LANG_PLI = 0x000f;
pub const LANG_ObjC = 0x0010;
pub const LANG_ObjC_plus_plus = 0x0011;
pub const LANG_UPC = 0x0012;
pub const LANG_D = 0x0013;
pub const LANG_Python = 0x0014;
pub const LANG_Go = 0x0016;
pub const LANG_C_plus_plus_11 = 0x001a;
pub const LANG_Rust = 0x001c;
pub const LANG_C11 = 0x001d;
pub const LANG_C_plus_plus_14 = 0x0021;
pub const LANG_Fortran03 = 0x0022;
pub const LANG_Fortran08 = 0x0023;
pub const LANG_lo_user = 0x8000;
pub const LANG_hi_user = 0xffff;
pub const LANG_Mips_Assembler = 0x8001;
pub const LANG_Upc = 0x8765;
pub const LANG_HP_Bliss = 0x8003;
pub const LANG_HP_Basic91 = 0x8004;
pub const LANG_HP_Pascal91 = 0x8005;
pub const LANG_HP_IMacro = 0x8006;
pub const LANG_HP_Assembler = 0x8007;

pub const UT_compile = 0x01;
pub const UT_type = 0x02;
pub const UT_partial = 0x03;
pub const UT_skeleton = 0x04;
pub const UT_split_compile = 0x05;
pub const UT_split_type = 0x06;
pub const UT_lo_user = 0x80;
pub const UT_hi_user = 0xff;

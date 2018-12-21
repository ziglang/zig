#!/bin/bash
#zig test ./meta/trait.zig --test-filter "std.meta.trait.multiTrait" &&
#zig test ./meta/trait.zig --test-filter "std.meta.trait.hasDef" &&
#zig test ./meta/trait.zig --test-filter "std.meta.trait.hasFn" &&
#zig test ./meta/trait.zig --test-filter "std.meta.trait.hasField" &&
#zig test ./meta/trait.zig --test-filter "std.meta.trait.is" &&
#zig test ./meta/trait.zig --test-filter "std.meta.trait.isPtrTo" &&
#zig test ./meta/trait.zig --test-filter "std.meta.trait.isExtern" &&
#zig test ./meta/trait.zig --test-filter "std.meta.trait.isPacked" &&
#zig test ./meta/trait.zig --test-filter "std.meta.trait.isSingleItemPtr" &&
#zig test ./meta/trait.zig --test-filter "std.meta.trait.isManyItemPtr" &&
#zig test ./meta/trait.zig --test-filter "std.meta.trait.isSlice" &&
#zig test ./meta/trait.zig --test-filter "std.meta.trait.isIndexable" &&
#zig test ./meta/trait.zig --test-filter "std.meta.trait.isNumber" &&
#zig test ./meta/trait.zig --test-filter "std.meta.trait.isConstPtr" &&
#zig test ./meta/trait.zig --test-filter "std.meta.trait.isContainer" &&
#zig test ./meta/index.zig --test-filter "std.meta.tagName" &&
#zig test ./meta/index.zig --test-filter "std.meta.stringToEnum" &&
#zig test ./meta/index.zig --test-filter "std.meta.bitCount" &&
#zig test ./meta/index.zig --test-filter "std.meta.alignment" &&
#zig test ./meta/index.zig --test-filter "std.meta.Child" &&
#zig test ./meta/index.zig --test-filter "std.meta.containerLayout" &&
#zig test ./meta/index.zig --test-filter "std.meta.definitions" &&
#zig test ./meta/index.zig --test-filter "std.meta.definitionInfo" &&
#zig test ./meta/index.zig --test-filter "std.meta.fields" &&
#zig test ./meta/index.zig --test-filter "std.meta.fieldInfo" &&
#zig test ./meta/index.zig --test-filter "std.meta.TagType" &&
#zig test ./meta/index.zig --test-filter "std.meta.activeTag" &&
#zig test ./meta/index.zig --test-filter "std.meta.eql" &&
#zig test ./meta/index.zig --test-filter "intToEnum with error return" &&
#zig test ./io.zig --test-filter "io.SliceOutStream" &&
#zig test ./io.zig --test-filter "io.NullOutStream" &&
#zig test ./io.zig --test-filter "io.CountingOutStream" &&
#zig test ./io.zig --test-filter "import io tests" &&
#zig test ./io.zig --test-filter "io.readLineFrom" &&
#zig test ./io.zig --test-filter "io.readLineSliceFrom" &&
#zig test ./special/init-lib/src/main.zig --test-filter "basic add functionality" &&
#zig test ./special/compiler_rt/fixdfti.zig --test-filter "import fixdfti" &&
#zig test ./special/compiler_rt/floatuntidf.zig --test-filter "import floatuntidf" &&
#zig test ./special/compiler_rt/fixunstfti.zig --test-filter "import fixunstfti" &&
#zig test ./special/compiler_rt/fixunssfsi.zig --test-filter "import fixunssfsi" &&
#zig test ./special/compiler_rt/floatunsitf_test.zig --test-filter "floatunsitf" &&
#zig test ./special/compiler_rt/fixtfti.zig --test-filter "import fixtfti" &&
#zig test ./special/compiler_rt/fixunsdfti_test.zig --test-filter "fixunsdfti" &&
#zig test ./special/compiler_rt/fixunssfdi.zig --test-filter "import fixunssfdi" &&
#zig test ./special/compiler_rt/fixsfsi_test.zig --test-filter "fixsfsi" &&
#zig test ./special/compiler_rt/udivmoddi4_test.zig --test-filter "udivmoddi4" &&
#zig test ./special/compiler_rt/fixdfsi_test.zig --test-filter "fixdfsi" &&
#zig test ./special/compiler_rt/extendXfYf2_test.zig --test-filter "extenddftf2" &&
#zig test ./special/compiler_rt/extendXfYf2_test.zig --test-filter "extendhfsf2" &&
#zig test ./special/compiler_rt/extendXfYf2_test.zig --test-filter "extendsftf2" &&
#zig test ./special/compiler_rt/fixunstfsi.zig --test-filter "import fixunstfsi" &&
#zig test ./special/compiler_rt/fixunsdfdi_test.zig --test-filter "fixunsdfdi" &&
#zig test ./special/compiler_rt/muloti4.zig --test-filter "import muloti4" &&
#zig test ./special/compiler_rt/fixsfdi.zig --test-filter "import fixsfdi" &&
#zig test ./special/compiler_rt/fixunstfti_test.zig --test-filter "fixunstfti" &&
#zig test ./special/compiler_rt/fixint.zig --test-filter "import fixint" &&
#zig test ./special/compiler_rt/multi3_test.zig --test-filter "multi3" &&
#zig test ./special/compiler_rt/floatunsitf.zig --test-filter "import floatunsitf" &&
#zig test ./special/compiler_rt/fixunsdfsi_test.zig --test-filter "fixunsdfsi" &&
#zig test ./special/compiler_rt/udivmodti4.zig --test-filter "import udivmodti4" &&
#zig test ./special/compiler_rt/fixunsdfti.zig --test-filter "import fixunsdfti" &&
#zig test ./special/compiler_rt/fixdfti_test.zig --test-filter "fixdfti" &&
#zig test ./special/compiler_rt/fixtfsi.zig --test-filter "import fixtfsi" &&
#zig test ./special/compiler_rt/floatuntisf.zig --test-filter "import floatuntisf" &&
#zig test ./special/compiler_rt/fixunstfsi_test.zig --test-filter "fixunstfsi" &&
#zig test ./special/compiler_rt/fixunstfdi_test.zig --test-filter "fixunstfdi" &&
#zig test ./special/compiler_rt/fixunsdfdi.zig --test-filter "import fixunsdfdi" &&
#zig test ./special/compiler_rt/divti3.zig --test-filter "import divti3" &&
#zig test ./special/compiler_rt/fixsfsi.zig --test-filter "import fixsfsi" &&
#zig test ./special/compiler_rt/fixint_test.zig --test-filter "fixint.i1" &&
#zig test ./special/compiler_rt/fixint_test.zig --test-filter "fixint.i2" &&
#zig test ./special/compiler_rt/fixint_test.zig --test-filter "fixint.i3" &&
#zig test ./special/compiler_rt/fixint_test.zig --test-filter "fixint.i32" &&
#zig test ./special/compiler_rt/fixint_test.zig --test-filter "fixint.i64" &&
#zig test ./special/compiler_rt/fixint_test.zig --test-filter "fixint.i128" &&
#zig test ./special/compiler_rt/floattitf.zig --test-filter "import floattitf" &&
#zig test ./special/compiler_rt/floatuntitf.zig --test-filter "import floatuntitf" &&
#zig test ./special/compiler_rt/multi3.zig --test-filter "import multi3" &&
#zig test ./special/compiler_rt/floatuntidf_test.zig --test-filter "floatuntidf" &&
#zig test ./special/compiler_rt/floatunditf.zig --test-filter "import floatunditf" &&
#zig test ./special/compiler_rt/floattisf_test.zig --test-filter "floattisf" &&
#zig test ./special/compiler_rt/floattidf.zig --test-filter "import floattidf" &&
#zig test ./special/compiler_rt/floatunditf_test.zig --test-filter "floatunditf" &&
#zig test ./special/compiler_rt/fixsfti_test.zig --test-filter "fixsfti" &&
#zig test ./special/compiler_rt/udivmoddi4.zig --test-filter "import udivmoddi4" &&
#zig test ./special/compiler_rt/floattitf_test.zig --test-filter "floattitf" &&
#zig test ./special/compiler_rt/fixunssfdi_test.zig --test-filter "fixunssfdi" &&
#zig test ./special/compiler_rt/muloti4_test.zig --test-filter "muloti4" &&
#zig test ./special/compiler_rt/divti3_test.zig --test-filter "divti3" &&
#zig test ./special/compiler_rt/floattisf.zig --test-filter "import floattisf" &&
#zig test ./special/compiler_rt/udivmodti4_test.zig --test-filter "udivmodti4" &&
#zig test ./special/compiler_rt/truncXfYf2_test.zig --test-filter "truncsfhf2" &&
#zig test ./special/compiler_rt/truncXfYf2_test.zig --test-filter "trunctfsf2" &&
#zig test ./special/compiler_rt/truncXfYf2_test.zig --test-filter "trunctfdf2" &&
#zig test ./special/compiler_rt/fixunsdfsi.zig --test-filter "import fixunsdfsi" &&
#zig test ./special/compiler_rt/fixunssfti_test.zig --test-filter "fixunssfti" &&
#zig test ./special/compiler_rt/floattidf_test.zig --test-filter "floattidf" &&

#ERROR: Unable to inline. Works on CI...
#zig test ./special/compiler_rt/index.zig --test-filter "test_umoddi3" &&
#zig test ./special/compiler_rt/index.zig --test-filter "test_udivsi3" &&

#zig test ./special/compiler_rt/fixunstfdi.zig --test-filter "import fixunstfdi" &&
#zig test ./special/compiler_rt/fixdfdi_test.zig --test-filter "fixdfdi" &&
#zig test ./special/compiler_rt/fixtfdi_test.zig --test-filter "fixtfdi" &&
#zig test ./special/compiler_rt/fixsfdi_test.zig --test-filter "fixsfdi" &&
#zig test ./special/compiler_rt/fixdfdi.zig --test-filter "import fixdfdi" &&
#zig test ./special/compiler_rt/fixunssfsi_test.zig --test-filter "fixunssfsi" &&
#zig test ./special/compiler_rt/fixtfsi_test.zig --test-filter "fixtfsi" &&
#zig test ./special/compiler_rt/floatuntitf_test.zig --test-filter "floatuntitf" &&
#zig test ./special/compiler_rt/fixtfti_test.zig --test-filter "fixtfti" &&
#zig test ./special/compiler_rt/fixunssfti.zig --test-filter "import fixunssfti" &&
#zig test ./special/compiler_rt/truncXfYf2.zig --test-filter "import truncXfYf2" &&
#zig test ./special/compiler_rt/fixdfsi.zig --test-filter "import fixdfsi" &&
#zig test ./special/compiler_rt/floatuntisf_test.zig --test-filter "floatuntisf" &&
#zig test ./special/compiler_rt/fixtfdi.zig --test-filter "import fixtfdi" &&
#zig test ./special/compiler_rt/extendXfYf2.zig --test-filter "import extendXfYf2" &&
#zig test ./special/compiler_rt/fixsfti.zig --test-filter "import fixsfti" &&

#zig test ./event/loop.zig --test-filter "std.event.Loop - basic" &&

#COMPILER ERROR, ir.cpp ir_analyze_container_field_ptr, async<>?
#passing now:
zig test ./event/loop.zig --test-filter "std.event.Loop - call" &&
zig test ./event/group.zig --test-filter "std.event.Group" &&
zig test ./event/rwlock.zig --test-filter "std.event.RwLock" &&
zig test ./event/channel.zig --test-filter "std.event.Channel" &&
zig test ./event/future.zig --test-filter "std.event.Future" &&
zig test ./event/net.zig --test-filter "listen on a port, send bytes, receive bytes" &&
zig test ./event/lock.zig --test-filter "std.event.Lock" &&

#SKIPPED infinite loop?
#zig test ./event/fs.zig --test-filter "write a file, watch it, write it again" &&

#zig test ./json_test.zig --test-filter "json.test.y_trailing_comma_after_empty" &&
#zig test ./json_test.zig --test-filter "json.test.y_array_arraysWithSpaces" &&
#zig test ./json_test.zig --test-filter "json.test.y_array_empty" &&
#zig test ./json_test.zig --test-filter "json.test.y_array_empty-string" &&
#zig test ./json_test.zig --test-filter "json.test.y_array_ending_with_newline" &&
#zig test ./json_test.zig --test-filter "json.test.y_array_false" &&
#zig test ./json_test.zig --test-filter "json.test.y_array_heterogeneous" &&
#zig test ./json_test.zig --test-filter "json.test.y_array_null" &&
#zig test ./json_test.zig --test-filter "json.test.y_array_with_1_and_newline" &&
#zig test ./json_test.zig --test-filter "json.test.y_array_with_leading_space" &&
#zig test ./json_test.zig --test-filter "json.test.y_array_with_several_null" &&
#zig test ./json_test.zig --test-filter "json.test.y_array_with_trailing_space" &&
#zig test ./json_test.zig --test-filter "json.test.y_number_0e+1" &&
#zig test ./json_test.zig --test-filter "json.test.y_number_0e1" &&
#zig test ./json_test.zig --test-filter "json.test.y_number_after_space" &&
#zig test ./json_test.zig --test-filter "json.test.y_number_double_close_to_zero" &&
#zig test ./json_test.zig --test-filter "json.test.y_number_int_with_exp" &&
#zig test ./json_test.zig --test-filter "json.test.y_number" &&
#zig test ./json_test.zig --test-filter "json.test.y_number_minus_zero" &&
#zig test ./json_test.zig --test-filter "json.test.y_number_negative_int" &&
#zig test ./json_test.zig --test-filter "json.test.y_number_negative_one" &&
#zig test ./json_test.zig --test-filter "json.test.y_number_negative_zero" &&
#zig test ./json_test.zig --test-filter "json.test.y_number_real_capital_e" &&
#zig test ./json_test.zig --test-filter "json.test.y_number_real_capital_e_neg_exp" &&
#zig test ./json_test.zig --test-filter "json.test.y_number_real_capital_e_pos_exp" &&
#zig test ./json_test.zig --test-filter "json.test.y_number_real_exponent" &&
#zig test ./json_test.zig --test-filter "json.test.y_number_real_fraction_exponent" &&
#zig test ./json_test.zig --test-filter "json.test.y_number_real_neg_exp" &&
#zig test ./json_test.zig --test-filter "json.test.y_number_real_pos_exponent" &&
#zig test ./json_test.zig --test-filter "json.test.y_number_simple_int" &&
#zig test ./json_test.zig --test-filter "json.test.y_number_simple_real" &&
#zig test ./json_test.zig --test-filter "json.test.y_object_basic" &&
#zig test ./json_test.zig --test-filter "json.test.y_object_duplicated_key_and_value" &&
#zig test ./json_test.zig --test-filter "json.test.y_object_duplicated_key" &&
#zig test ./json_test.zig --test-filter "json.test.y_object_empty" &&
#zig test ./json_test.zig --test-filter "json.test.y_object_empty_key" &&
#zig test ./json_test.zig --test-filter "json.test.y_object_escaped_null_in_key" &&
#zig test ./json_test.zig --test-filter "json.test.y_object_extreme_numbers" &&
#zig test ./json_test.zig --test-filter "json.test.y_object" &&
#zig test ./json_test.zig --test-filter "json.test.y_object_long_strings" &&
#zig test ./json_test.zig --test-filter "json.test.y_object_simple" &&
#zig test ./json_test.zig --test-filter "json.test.y_object_string_unicode" &&
#zig test ./json_test.zig --test-filter "json.test.y_object_with_newlines" &&
#zig test ./json_test.zig --test-filter "json.test.y_string_1_2_3_bytes_UTF-8_sequences" &&
#zig test ./json_test.zig --test-filter "json.test.y_string_accepted_surrogate_pair" &&
#zig test ./json_test.zig --test-filter "json.test.y_string_accepted_surrogate_pairs" &&
#zig test ./json_test.zig --test-filter "json.test.y_string_allowed_escapes" &&
#zig test ./json_test.zig --test-filter "json.test.y_string_backslash_and_u_escaped_zero" &&
#zig test ./json_test.zig --test-filter "json.test.y_string_backslash_doublequotes" &&
#zig test ./json_test.zig --test-filter "json.test.y_string_comments" &&
#zig test ./json_test.zig --test-filter "json.test.y_string_double_escape_a" &&
#zig test ./json_test.zig --test-filter "json.test.y_string_double_escape_n" &&
#zig test ./json_test.zig --test-filter "json.test.y_string_escaped_control_character" &&
#zig test ./json_test.zig --test-filter "json.test.y_string_escaped_noncharacter" &&
#zig test ./json_test.zig --test-filter "json.test.y_string_in_array" &&
#zig test ./json_test.zig --test-filter "json.test.y_string_in_array_with_leading_space" &&
#zig test ./json_test.zig --test-filter "json.test.y_string_last_surrogates_1_and_2" &&
#zig test ./json_test.zig --test-filter "json.test.y_string_nbsp_uescaped" &&
#zig test ./json_test.zig --test-filter "json.test.y_string_nonCharacterInUTF-8_U+10FFFF" &&
#zig test ./json_test.zig --test-filter "json.test.y_string_nonCharacterInUTF-8_U+FFFF" &&
#zig test ./json_test.zig --test-filter "json.test.y_string_null_escape" &&
#zig test ./json_test.zig --test-filter "json.test.y_string_one-byte-utf-8" &&
#zig test ./json_test.zig --test-filter "json.test.y_string_pi" &&
#zig test ./json_test.zig --test-filter "json.test.y_string_reservedCharacterInUTF-8_U+1BFFF" &&
#zig test ./json_test.zig --test-filter "json.test.y_string_simple_ascii" &&
#zig test ./json_test.zig --test-filter "json.test.y_string_space" &&
#zig test ./json_test.zig --test-filter "json.test.y_string_surrogates_U+1D11E_MUSICAL_SYMBOL_G_CLEF" &&
#zig test ./json_test.zig --test-filter "json.test.y_string_three-byte-utf-8" &&
#zig test ./json_test.zig --test-filter "json.test.y_string_two-byte-utf-8" &&
#zig test ./json_test.zig --test-filter "json.test.y_string_u+2028_line_sep" &&
#zig test ./json_test.zig --test-filter "json.test.y_string_u+2029_par_sep" &&
#zig test ./json_test.zig --test-filter "json.test.y_string_uescaped_newline" &&
#zig test ./json_test.zig --test-filter "json.test.y_string_uEscape" &&
#zig test ./json_test.zig --test-filter "json.test.y_string_unescaped_char_delete" &&
#zig test ./json_test.zig --test-filter "json.test.y_string_unicode_2" &&
#zig test ./json_test.zig --test-filter "json.test.y_string_unicodeEscapedBackslash" &&
#zig test ./json_test.zig --test-filter "json.test.y_string_unicode_escaped_double_quote" &&
#zig test ./json_test.zig --test-filter "json.test.y_string_unicode" &&
#zig test ./json_test.zig --test-filter "json.test.y_string_unicode_U+10FFFE_nonchar" &&
#zig test ./json_test.zig --test-filter "json.test.y_string_unicode_U+1FFFE_nonchar" &&
#zig test ./json_test.zig --test-filter "json.test.y_string_unicode_U+200B_ZERO_WIDTH_SPACE" &&
#zig test ./json_test.zig --test-filter "json.test.y_string_unicode_U+2064_invisible_plus" &&
#zig test ./json_test.zig --test-filter "json.test.y_string_unicode_U+FDD0_nonchar" &&
#zig test ./json_test.zig --test-filter "json.test.y_string_unicode_U+FFFE_nonchar" &&
#zig test ./json_test.zig --test-filter "json.test.y_string_utf8" &&
#zig test ./json_test.zig --test-filter "json.test.y_string_with_del_character" &&
#zig test ./json_test.zig --test-filter "json.test.y_structure_lonely_false" &&
#zig test ./json_test.zig --test-filter "json.test.y_structure_lonely_int" &&
#zig test ./json_test.zig --test-filter "json.test.y_structure_lonely_negative_real" &&
#zig test ./json_test.zig --test-filter "json.test.y_structure_lonely_null" &&
#zig test ./json_test.zig --test-filter "json.test.y_structure_lonely_string" &&
#zig test ./json_test.zig --test-filter "json.test.y_structure_lonely_true" &&
#zig test ./json_test.zig --test-filter "json.test.y_structure_string_empty" &&
#zig test ./json_test.zig --test-filter "json.test.y_structure_trailing_newline" &&
#zig test ./json_test.zig --test-filter "json.test.y_structure_true_in_array" &&
#zig test ./json_test.zig --test-filter "json.test.y_structure_whitespace_array" &&
#zig test ./json_test.zig --test-filter "json.test.n_array_1_true_without_comma" &&
#zig test ./json_test.zig --test-filter "json.test.n_array_a_invalid_utf8" &&
#zig test ./json_test.zig --test-filter "json.test.n_array_colon_instead_of_comma" &&
#zig test ./json_test.zig --test-filter "json.test.n_array_comma_after_close" &&
#zig test ./json_test.zig --test-filter "json.test.n_array_comma_and_number" &&
#zig test ./json_test.zig --test-filter "json.test.n_array_double_comma" &&
#zig test ./json_test.zig --test-filter "json.test.n_array_double_extra_comma" &&
#zig test ./json_test.zig --test-filter "json.test.n_array_extra_close" &&
#zig test ./json_test.zig --test-filter "json.test.n_array_extra_comma" &&
#zig test ./json_test.zig --test-filter "json.test.n_array_incomplete_invalid_value" &&
#zig test ./json_test.zig --test-filter "json.test.n_array_incomplete" &&
#zig test ./json_test.zig --test-filter "json.test.n_array_inner_array_no_comma" &&
#zig test ./json_test.zig --test-filter "json.test.n_array_invalid_utf8" &&
#zig test ./json_test.zig --test-filter "json.test.n_array_items_separated_by_semicolon" &&
#zig test ./json_test.zig --test-filter "json.test.n_array_just_comma" &&
#zig test ./json_test.zig --test-filter "json.test.n_array_just_minus" &&
#zig test ./json_test.zig --test-filter "json.test.n_array_missing_value" &&
#zig test ./json_test.zig --test-filter "json.test.n_array_newlines_unclosed" &&
#zig test ./json_test.zig --test-filter "json.test.n_array_number_and_comma" &&
#zig test ./json_test.zig --test-filter "json.test.n_array_number_and_several_commas" &&
#zig test ./json_test.zig --test-filter "json.test.n_array_spaces_vertical_tab_formfeed" &&
#zig test ./json_test.zig --test-filter "json.test.n_array_star_inside" &&
#zig test ./json_test.zig --test-filter "json.test.n_array_unclosed" &&
#zig test ./json_test.zig --test-filter "json.test.n_array_unclosed_trailing_comma" &&
#zig test ./json_test.zig --test-filter "json.test.n_array_unclosed_with_new_lines" &&
#zig test ./json_test.zig --test-filter "json.test.n_array_unclosed_with_object_inside" &&
#zig test ./json_test.zig --test-filter "json.test.n_incomplete_false" &&
#zig test ./json_test.zig --test-filter "json.test.n_incomplete_null" &&
#zig test ./json_test.zig --test-filter "json.test.n_incomplete_true" &&
#zig test ./json_test.zig --test-filter "json.test.n_multidigit_number_then_00" &&
#zig test ./json_test.zig --test-filter "json.test.n_number_0.1.2" &&
#zig test ./json_test.zig --test-filter "json.test.n_number_-01" &&
#zig test ./json_test.zig --test-filter "json.test.n_number_0.3e" &&
#zig test ./json_test.zig --test-filter "json.test.n_number_0.3e+" &&
#zig test ./json_test.zig --test-filter "json.test.n_number_0_capital_E" &&
#zig test ./json_test.zig --test-filter "json.test.n_number_0_capital_E+" &&
#zig test ./json_test.zig --test-filter "json.test.n_number_0.e1" &&
#zig test ./json_test.zig --test-filter "json.test.n_number_0e" &&
#zig test ./json_test.zig --test-filter "json.test.n_number_0e+" &&
#zig test ./json_test.zig --test-filter "json.test.n_number_1_000" &&
#zig test ./json_test.zig --test-filter "json.test.n_number_1.0e-" &&
#zig test ./json_test.zig --test-filter "json.test.n_number_1.0e" &&
#zig test ./json_test.zig --test-filter "json.test.n_number_1.0e+" &&
#zig test ./json_test.zig --test-filter "json.test.n_number_-1.0." &&
#zig test ./json_test.zig --test-filter "json.test.n_number_1eE2" &&
#zig test ./json_test.zig --test-filter "json.test.n_number_.-1" &&
#zig test ./json_test.zig --test-filter "json.test.n_number_+1" &&
#zig test ./json_test.zig --test-filter "json.test.n_number_.2e-3" &&
#zig test ./json_test.zig --test-filter "json.test.n_number_2.e-3" &&
#zig test ./json_test.zig --test-filter "json.test.n_number_2.e+3" &&
#zig test ./json_test.zig --test-filter "json.test.n_number_2.e3" &&
#zig test ./json_test.zig --test-filter "json.test.n_number_-2." &&
#zig test ./json_test.zig --test-filter "json.test.n_number_9.e+" &&
#zig test ./json_test.zig --test-filter "json.test.n_number_expression" &&
#zig test ./json_test.zig --test-filter "json.test.n_number_hex_1_digit" &&
#zig test ./json_test.zig --test-filter "json.test.n_number_hex_2_digits" &&
#zig test ./json_test.zig --test-filter "json.test.n_number_infinity" &&
#zig test ./json_test.zig --test-filter "json.test.n_number_+Inf" &&
#zig test ./json_test.zig --test-filter "json.test.n_number_Inf" &&
#zig test ./json_test.zig --test-filter "json.test.n_number_invalid+-" &&
#zig test ./json_test.zig --test-filter "json.test.n_number_invalid-negative-real" &&
#zig test ./json_test.zig --test-filter "json.test.n_number_invalid-utf-8-in-bigger-int" &&
#zig test ./json_test.zig --test-filter "json.test.n_number_invalid-utf-8-in-exponent" &&
#zig test ./json_test.zig --test-filter "json.test.n_number_invalid-utf-8-in-int" &&
#zig test ./json_test.zig --test-filter "json.test.n_number_++" &&
#zig test ./json_test.zig --test-filter "json.test.n_number_minus_infinity" &&
#zig test ./json_test.zig --test-filter "json.test.n_number_minus_sign_with_trailing_garbage" &&
#zig test ./json_test.zig --test-filter "json.test.n_number_minus_space_1" &&
#zig test ./json_test.zig --test-filter "json.test.n_number_-NaN" &&
#zig test ./json_test.zig --test-filter "json.test.n_number_NaN" &&
#zig test ./json_test.zig --test-filter "json.test.n_number_neg_int_starting_with_zero" &&
#zig test ./json_test.zig --test-filter "json.test.n_number_neg_real_without_int_part" &&
#zig test ./json_test.zig --test-filter "json.test.n_number_neg_with_garbage_at_end" &&
#zig test ./json_test.zig --test-filter "json.test.n_number_real_garbage_after_e" &&
#zig test ./json_test.zig --test-filter "json.test.n_number_real_with_invalid_utf8_after_e" &&
#zig test ./json_test.zig --test-filter "json.test.n_number_real_without_fractional_part" &&
#zig test ./json_test.zig --test-filter "json.test.n_number_starting_with_dot" &&
#zig test ./json_test.zig --test-filter "json.test.n_number_U+FF11_fullwidth_digit_one" &&
#zig test ./json_test.zig --test-filter "json.test.n_number_with_alpha_char" &&
#zig test ./json_test.zig --test-filter "json.test.n_number_with_alpha" &&
#zig test ./json_test.zig --test-filter "json.test.n_number_with_leading_zero" &&
#zig test ./json_test.zig --test-filter "json.test.n_object_bad_value" &&
#zig test ./json_test.zig --test-filter "json.test.n_object_bracket_key" &&
#zig test ./json_test.zig --test-filter "json.test.n_object_comma_instead_of_colon" &&
#zig test ./json_test.zig --test-filter "json.test.n_object_double_colon" &&
#zig test ./json_test.zig --test-filter "json.test.n_object_emoji" &&
#zig test ./json_test.zig --test-filter "json.test.n_object_garbage_at_end" &&
#zig test ./json_test.zig --test-filter "json.test.n_object_key_with_single_quotes" &&
#zig test ./json_test.zig --test-filter "json.test.n_object_lone_continuation_byte_in_key_and_trailing_comma" &&
#zig test ./json_test.zig --test-filter "json.test.n_object_missing_colon" &&
#zig test ./json_test.zig --test-filter "json.test.n_object_missing_key" &&
#zig test ./json_test.zig --test-filter "json.test.n_object_missing_semicolon" &&
#zig test ./json_test.zig --test-filter "json.test.n_object_missing_value" &&
#zig test ./json_test.zig --test-filter "json.test.n_object_no-colon" &&
#zig test ./json_test.zig --test-filter "json.test.n_object_non_string_key_but_huge_number_instead" &&
#zig test ./json_test.zig --test-filter "json.test.n_object_non_string_key" &&
#zig test ./json_test.zig --test-filter "json.test.n_object_repeated_null_null" &&
#zig test ./json_test.zig --test-filter "json.test.n_object_several_trailing_commas" &&
#zig test ./json_test.zig --test-filter "json.test.n_object_single_quote" &&
#zig test ./json_test.zig --test-filter "json.test.n_object_trailing_comma" &&
#zig test ./json_test.zig --test-filter "json.test.n_object_trailing_comment" &&
#zig test ./json_test.zig --test-filter "json.test.n_object_trailing_comment_open" &&
#zig test ./json_test.zig --test-filter "json.test.n_object_trailing_comment_slash_open_incomplete" &&
#zig test ./json_test.zig --test-filter "json.test.n_object_trailing_comment_slash_open" &&
#zig test ./json_test.zig --test-filter "json.test.n_object_two_commas_in_a_row" &&
#zig test ./json_test.zig --test-filter "json.test.n_object_unquoted_key" &&
#zig test ./json_test.zig --test-filter "json.test.n_object_unterminated-value" &&
#zig test ./json_test.zig --test-filter "json.test.n_object_with_single_string" &&
#zig test ./json_test.zig --test-filter "json.test.n_object_with_trailing_garbage" &&
#zig test ./json_test.zig --test-filter "json.test.n_single_space" &&
#zig test ./json_test.zig --test-filter "json.test.n_string_1_surrogate_then_escape" &&
#zig test ./json_test.zig --test-filter "json.test.n_string_1_surrogate_then_escape_u1" &&
#zig test ./json_test.zig --test-filter "json.test.n_string_1_surrogate_then_escape_u1x" &&
#zig test ./json_test.zig --test-filter "json.test.n_string_1_surrogate_then_escape_u" &&
#zig test ./json_test.zig --test-filter "json.test.n_string_accentuated_char_no_quotes" &&
#zig test ./json_test.zig --test-filter "json.test.n_string_backslash_00" &&
#zig test ./json_test.zig --test-filter "json.test.n_string_escaped_backslash_bad" &&
#zig test ./json_test.zig --test-filter "json.test.n_string_escaped_ctrl_char_tab" &&
#zig test ./json_test.zig --test-filter "json.test.n_string_escaped_emoji" &&
#zig test ./json_test.zig --test-filter "json.test.n_string_escape_x" &&
#zig test ./json_test.zig --test-filter "json.test.n_string_incomplete_escaped_character" &&
#zig test ./json_test.zig --test-filter "json.test.n_string_incomplete_escape" &&
#zig test ./json_test.zig --test-filter "json.test.n_string_incomplete_surrogate_escape_invalid" &&
#zig test ./json_test.zig --test-filter "json.test.n_string_incomplete_surrogate" &&
#zig test ./json_test.zig --test-filter "json.test.n_string_invalid_backslash_esc" &&
#zig test ./json_test.zig --test-filter "json.test.n_string_invalid_unicode_escape" &&
#zig test ./json_test.zig --test-filter "json.test.n_string_invalid_utf8_after_escape" &&
#zig test ./json_test.zig --test-filter "json.test.n_string_invalid-utf-8-in-escape" &&
#zig test ./json_test.zig --test-filter "json.test.n_string_leading_uescaped_thinspace" &&
#zig test ./json_test.zig --test-filter "json.test.n_string_no_quotes_with_bad_escape" &&
#zig test ./json_test.zig --test-filter "json.test.n_string_single_doublequote" &&
#zig test ./json_test.zig --test-filter "json.test.n_string_single_quote" &&
#zig test ./json_test.zig --test-filter "json.test.n_string_single_string_no_double_quotes" &&
#zig test ./json_test.zig --test-filter "json.test.n_string_start_escape_unclosed" &&
#zig test ./json_test.zig --test-filter "json.test.n_string_unescaped_crtl_char" &&
#zig test ./json_test.zig --test-filter "json.test.n_string_unescaped_newline" &&
#zig test ./json_test.zig --test-filter "json.test.n_string_unescaped_tab" &&
#zig test ./json_test.zig --test-filter "json.test.n_string_unicode_CapitalU" &&
#zig test ./json_test.zig --test-filter "json.test.n_string_with_trailing_garbage" &&
#zig test ./json_test.zig --test-filter "json.test.n_structure_100000_opening_arrays" &&
#zig test ./json_test.zig --test-filter "json.test.n_structure_angle_bracket_." &&
#zig test ./json_test.zig --test-filter "json.test.n_structure_angle_bracket_null" &&
#zig test ./json_test.zig --test-filter "json.test.n_structure_array_trailing_garbage" &&
#zig test ./json_test.zig --test-filter "json.test.n_structure_array_with_extra_array_close" &&
#zig test ./json_test.zig --test-filter "json.test.n_structure_array_with_unclosed_string" &&
#zig test ./json_test.zig --test-filter "json.test.n_structure_ascii-unicode-identifier" &&
#zig test ./json_test.zig --test-filter "json.test.n_structure_capitalized_True" &&
#zig test ./json_test.zig --test-filter "json.test.n_structure_close_unopened_array" &&
#zig test ./json_test.zig --test-filter "json.test.n_structure_comma_instead_of_closing_brace" &&
#zig test ./json_test.zig --test-filter "json.test.n_structure_double_array" &&
#zig test ./json_test.zig --test-filter "json.test.n_structure_end_array" &&
#zig test ./json_test.zig --test-filter "json.test.n_structure_incomplete_UTF8_BOM" &&
#zig test ./json_test.zig --test-filter "json.test.n_structure_lone-invalid-utf-8" &&
#zig test ./json_test.zig --test-filter "json.test.n_structure_lone-open-bracket" &&
#zig test ./json_test.zig --test-filter "json.test.n_structure_no_data" &&
#zig test ./json_test.zig --test-filter "json.test.n_structure_null-byte-outside-string" &&
#zig test ./json_test.zig --test-filter "json.test.n_structure_number_with_trailing_garbage" &&
#zig test ./json_test.zig --test-filter "json.test.n_structure_object_followed_by_closing_object" &&
#zig test ./json_test.zig --test-filter "json.test.n_structure_object_unclosed_no_value" &&
#zig test ./json_test.zig --test-filter "json.test.n_structure_object_with_comment" &&
#zig test ./json_test.zig --test-filter "json.test.n_structure_object_with_trailing_garbage" &&
#zig test ./json_test.zig --test-filter "json.test.n_structure_open_array_apostrophe" &&
#zig test ./json_test.zig --test-filter "json.test.n_structure_open_array_comma" &&
#zig test ./json_test.zig --test-filter "json.test.n_structure_open_array_object" &&
#zig test ./json_test.zig --test-filter "json.test.n_structure_open_array_open_object" &&
#zig test ./json_test.zig --test-filter "json.test.n_structure_open_array_open_string" &&
#zig test ./json_test.zig --test-filter "json.test.n_structure_open_array_string" &&
#zig test ./json_test.zig --test-filter "json.test.n_structure_open_object_close_array" &&
#zig test ./json_test.zig --test-filter "json.test.n_structure_open_object_comma" &&
#zig test ./json_test.zig --test-filter "json.test.n_structure_open_object" &&
#zig test ./json_test.zig --test-filter "json.test.n_structure_open_object_open_array" &&
#zig test ./json_test.zig --test-filter "json.test.n_structure_open_object_open_string" &&
#zig test ./json_test.zig --test-filter "json.test.n_structure_open_object_string_with_apostrophes" &&
#zig test ./json_test.zig --test-filter "json.test.n_structure_open_open" &&
#zig test ./json_test.zig --test-filter "json.test.n_structure_single_eacute" &&
#zig test ./json_test.zig --test-filter "json.test.n_structure_single_star" &&
#zig test ./json_test.zig --test-filter "json.test.n_structure_trailing_#" &&
#zig test ./json_test.zig --test-filter "json.test.n_structure_U+2060_word_joined" &&
#zig test ./json_test.zig --test-filter "json.test.n_structure_uescaped_LF_before_string" &&
#zig test ./json_test.zig --test-filter "json.test.n_structure_unclosed_array" &&
#zig test ./json_test.zig --test-filter "json.test.n_structure_unclosed_array_partial_null" &&
#zig test ./json_test.zig --test-filter "json.test.n_structure_unclosed_array_unfinished_false" &&
#zig test ./json_test.zig --test-filter "json.test.n_structure_unclosed_array_unfinished_true" &&
#zig test ./json_test.zig --test-filter "json.test.n_structure_unclosed_object" &&
#zig test ./json_test.zig --test-filter "json.test.n_structure_unicode-identifier" &&
#zig test ./json_test.zig --test-filter "json.test.n_structure_UTF8_BOM_no_data" &&
#zig test ./json_test.zig --test-filter "json.test.n_structure_whitespace_formfeed" &&
#zig test ./json_test.zig --test-filter "json.test.n_structure_whitespace_U+2060_word_joiner" &&
#zig test ./json_test.zig --test-filter "json.test.i_number_double_huge_neg_exp" &&
#zig test ./json_test.zig --test-filter "json.test.i_number_huge_exp" &&
#zig test ./json_test.zig --test-filter "json.test.i_number_neg_int_huge_exp" &&
#zig test ./json_test.zig --test-filter "json.test.i_number_pos_double_huge_exp" &&
#zig test ./json_test.zig --test-filter "json.test.i_number_real_neg_overflow" &&
#zig test ./json_test.zig --test-filter "json.test.i_number_real_pos_overflow" &&
#zig test ./json_test.zig --test-filter "json.test.i_number_real_underflow" &&
#zig test ./json_test.zig --test-filter "json.test.i_number_too_big_neg_int" &&
#zig test ./json_test.zig --test-filter "json.test.i_number_too_big_pos_int" &&
#zig test ./json_test.zig --test-filter "json.test.i_number_very_big_negative_int" &&
#zig test ./json_test.zig --test-filter "json.test.i_object_key_lone_2nd_surrogate" &&
#zig test ./json_test.zig --test-filter "json.test.i_string_1st_surrogate_but_2nd_missing" &&
#zig test ./json_test.zig --test-filter "json.test.i_string_1st_valid_surrogate_2nd_invalid" &&
#zig test ./json_test.zig --test-filter "json.test.i_string_incomplete_surrogate_and_escape_valid" &&
#zig test ./json_test.zig --test-filter "json.test.i_string_incomplete_surrogate_pair" &&
#zig test ./json_test.zig --test-filter "json.test.i_string_incomplete_surrogates_escape_valid" &&
#zig test ./json_test.zig --test-filter "json.test.i_string_invalid_lonely_surrogate" &&
#zig test ./json_test.zig --test-filter "json.test.i_string_invalid_surrogate" &&
#zig test ./json_test.zig --test-filter "json.test.i_string_invalid_utf-8" &&
#zig test ./json_test.zig --test-filter "json.test.i_string_inverted_surrogates_U+1D11E" &&
#zig test ./json_test.zig --test-filter "json.test.i_string_iso_latin_1" &&
#zig test ./json_test.zig --test-filter "json.test.i_string_lone_second_surrogate" &&
#zig test ./json_test.zig --test-filter "json.test.i_string_lone_utf8_continuation_byte" &&
#zig test ./json_test.zig --test-filter "json.test.i_string_not_in_unicode_range" &&
#zig test ./json_test.zig --test-filter "json.test.i_string_overlong_sequence_2_bytes" &&
#zig test ./json_test.zig --test-filter "json.test.i_string_overlong_sequence_6_bytes" &&
#zig test ./json_test.zig --test-filter "json.test.i_string_overlong_sequence_6_bytes_null" &&
#zig test ./json_test.zig --test-filter "json.test.i_string_truncated-utf-8" &&
#zig test ./json_test.zig --test-filter "json.test.i_string_utf16BE_no_BOM" &&
#zig test ./json_test.zig --test-filter "json.test.i_string_utf16LE_no_BOM" &&
#zig test ./json_test.zig --test-filter "json.test.i_string_UTF-16LE_with_BOM" &&
#zig test ./json_test.zig --test-filter "json.test.i_string_UTF-8_invalid_sequence" &&
#zig test ./json_test.zig --test-filter "json.test.i_string_UTF8_surrogate_U+D800" &&
#zig test ./json_test.zig --test-filter "json.test.i_structure_500_nested_arrays" &&
#zig test ./json_test.zig --test-filter "json.test.i_structure_UTF-8_BOM_empty_object" &&
#zig test ./os/path.zig --test-filter "os.path.join" &&
#zig test ./os/path.zig --test-filter "os.path.isAbsoluteWindows" &&
#zig test ./os/path.zig --test-filter "os.path.isAbsolutePosix" &&
#zig test ./os/path.zig --test-filter "os.path.windowsParsePath" &&
#zig test ./os/path.zig --test-filter "os.path.resolve" &&
#zig test ./os/path.zig --test-filter "os.path.resolveWindows" &&
#zig test ./os/path.zig --test-filter "os.path.resolvePosix" &&
#zig test ./os/path.zig --test-filter "os.path.dirnamePosix" &&
#zig test ./os/path.zig --test-filter "os.path.dirnameWindows" &&
#zig test ./os/path.zig --test-filter "os.path.basename" &&
#zig test ./os/path.zig --test-filter "os.path.relative" &&
#zig test ./os/path.zig --test-filter "os.path.real" &&
#zig test ./os/test.zig --test-filter "makePath, put some files in it, deleteTree" &&
#zig test ./os/test.zig --test-filter "access file" &&
#zig test ./os/test.zig --test-filter "std.os.Thread.getCurrentId" &&
#zig test ./os/test.zig --test-filter "spawn threads" &&
#zig test ./os/test.zig --test-filter "cpu count" &&
#zig test ./os/test.zig --test-filter "AtomicFile" &&
#zig test ./os/get_app_data_dir.zig --test-filter "std.os.getAppDataDir" &&
#zig test ./os/time.zig --test-filter "os.time.sleep" &&
#zig test ./os/time.zig --test-filter "os.time.timestamp" &&
#zig test ./os/time.zig --test-filter "os.time.Timer" &&
#zig test ./os/index.zig --test-filter "std.os" &&
#zig test ./os/index.zig --test-filter "os.getRandomBytes" &&
#zig test ./os/index.zig --test-filter "os.getEnvMap" &&
#zig test ./os/index.zig --test-filter "os.getEnvVarOwned" &&
#zig test ./os/index.zig --test-filter "os.getCwd" &&
#zig test ./os/index.zig --test-filter "windows arg parsing" &&
#zig test ./os/index.zig --test-filter "openSelfExe" &&
#zig test ./os/linux/test.zig --test-filter "getpid" &&
#zig test ./os/linux/test.zig --test-filter "timer" &&
#zig test ./os/linux/index.zig --test-filter "import" &&
#zig test ./os/windows/index.zig --test-filter "import" &&
#zig test ./rand/ziggurat.zig --test-filter "ziggurant normal dist sanity" &&
#zig test ./rand/ziggurat.zig --test-filter "ziggurant exp dist sanity" &&
#zig test ./rand/ziggurat.zig --test-filter "ziggurat table gen" &&
#zig test ./rand/index.zig --test-filter "Random int" &&
#zig test ./rand/index.zig --test-filter "Random boolean" &&
#zig test ./rand/index.zig --test-filter "Random intLessThan" &&
#zig test ./rand/index.zig --test-filter "Random intAtMost" &&
#zig test ./rand/index.zig --test-filter "Random Biased" &&
#zig test ./rand/index.zig --test-filter "splitmix64 sequence" &&
#zig test ./rand/index.zig --test-filter "pcg sequence" &&
#zig test ./rand/index.zig --test-filter "xoroshiro sequence" &&
#zig test ./rand/index.zig --test-filter "isaac64 sequence" &&
#zig test ./rand/index.zig --test-filter "Random float" &&
#zig test ./rand/index.zig --test-filter "Random shuffle" &&
#zig test ./rand/index.zig --test-filter "Random range" &&
#zig test ./linked_list.zig --test-filter "basic linked list test" &&
#zig test ./linked_list.zig --test-filter "linked list concatenation" &&
#zig test ./math/copysign.zig --test-filter "math.copysign" &&
#zig test ./math/copysign.zig --test-filter "math.copysign16" &&
#zig test ./math/copysign.zig --test-filter "math.copysign32" &&
#zig test ./math/copysign.zig --test-filter "math.copysign64" &&
#zig test ./math/expm1.zig --test-filter "math.exp1m" &&
#zig test ./math/expm1.zig --test-filter "math.expm1_32" &&
#zig test ./math/expm1.zig --test-filter "math.expm1_64" &&
#zig test ./math/expm1.zig --test-filter "math.expm1_32.special" &&
#zig test ./math/expm1.zig --test-filter "math.expm1_64.special" &&
#zig test ./math/trunc.zig --test-filter "math.trunc" &&
#zig test ./math/trunc.zig --test-filter "math.trunc32" &&
#zig test ./math/trunc.zig --test-filter "math.trunc64" &&
#zig test ./math/trunc.zig --test-filter "math.trunc32.special" &&
#zig test ./math/trunc.zig --test-filter "math.trunc64.special" &&
#zig test ./math/asinh.zig --test-filter "math.asinh" &&
#zig test ./math/asinh.zig --test-filter "math.asinh32" &&
#zig test ./math/asinh.zig --test-filter "math.asinh64" &&
#zig test ./math/asinh.zig --test-filter "math.asinh32.special" &&
#zig test ./math/asinh.zig --test-filter "math.asinh64.special" &&
#zig test ./math/log2.zig --test-filter "math.log2" &&
#zig test ./math/log2.zig --test-filter "math.log2_32" &&
#zig test ./math/log2.zig --test-filter "math.log2_64" &&
#zig test ./math/log2.zig --test-filter "math.log2_32.special" &&
#zig test ./math/log2.zig --test-filter "math.log2_64.special" &&
#zig test ./math/frexp.zig --test-filter "math.frexp" &&
#zig test ./math/frexp.zig --test-filter "math.frexp32" &&
#zig test ./math/frexp.zig --test-filter "math.frexp64" &&
#zig test ./math/frexp.zig --test-filter "math.frexp32.special" &&
#zig test ./math/frexp.zig --test-filter "math.frexp64.special" &&
#zig test ./math/log1p.zig --test-filter "math.log1p" &&
#zig test ./math/log1p.zig --test-filter "math.log1p_32" &&
#zig test ./math/log1p.zig --test-filter "math.log1p_64" &&
#zig test ./math/log1p.zig --test-filter "math.log1p_32.special" &&
#zig test ./math/log1p.zig --test-filter "math.log1p_64.special" &&
#zig test ./math/complex/asinh.zig --test-filter "complex.casinh" &&
#zig test ./math/complex/tanh.zig --test-filter "complex.ctanh32" &&
#zig test ./math/complex/tanh.zig --test-filter "complex.ctanh64" &&
#zig test ./math/complex/atanh.zig --test-filter "complex.catanh" &&
#zig test ./math/complex/cos.zig --test-filter "complex.ccos" &&
#zig test ./math/complex/conj.zig --test-filter "complex.conj" &&
#zig test ./math/complex/abs.zig --test-filter "complex.cabs" &&
#zig test ./math/complex/sqrt.zig --test-filter "complex.csqrt32" &&
#zig test ./math/complex/sqrt.zig --test-filter "complex.csqrt64" &&
#zig test ./math/complex/log.zig --test-filter "complex.clog" &&
#zig test ./math/complex/cosh.zig --test-filter "complex.ccosh32" &&
#zig test ./math/complex/cosh.zig --test-filter "complex.ccosh64" &&
#zig test ./math/complex/proj.zig --test-filter "complex.cproj" &&
#zig test ./math/complex/acosh.zig --test-filter "complex.cacosh" &&
#zig test ./math/complex/arg.zig --test-filter "complex.carg" &&
#zig test ./math/complex/sinh.zig --test-filter "complex.csinh32" &&
#zig test ./math/complex/sinh.zig --test-filter "complex.csinh64" &&
#zig test ./math/complex/atan.zig --test-filter "complex.catan32" &&
#zig test ./math/complex/atan.zig --test-filter "complex.catan64" &&
#zig test ./math/complex/tan.zig --test-filter "complex.ctan" &&
#zig test ./math/complex/index.zig --test-filter "complex.add" &&
#zig test ./math/complex/index.zig --test-filter "complex.sub" &&
#zig test ./math/complex/index.zig --test-filter "complex.mul" &&
#zig test ./math/complex/index.zig --test-filter "complex.div" &&
#zig test ./math/complex/index.zig --test-filter "complex.conjugate" &&
#zig test ./math/complex/index.zig --test-filter "complex.reciprocal" &&
#zig test ./math/complex/index.zig --test-filter "complex.magnitude" &&
#zig test ./math/complex/index.zig --test-filter "complex.cmath" &&
#zig test ./math/complex/sin.zig --test-filter "complex.csin" &&
#zig test ./math/complex/asin.zig --test-filter "complex.casin" &&
#zig test ./math/complex/exp.zig --test-filter "complex.cexp32" &&
#zig test ./math/complex/exp.zig --test-filter "complex.cexp64" &&
#zig test ./math/complex/acos.zig --test-filter "complex.cacos" &&
#zig test ./math/complex/pow.zig --test-filter "complex.cpow" &&
#zig test ./math/scalbn.zig --test-filter "math.scalbn" &&
#zig test ./math/scalbn.zig --test-filter "math.scalbn32" &&
#zig test ./math/scalbn.zig --test-filter "math.scalbn64" &&
#zig test ./math/tanh.zig --test-filter "math.tanh" &&
#zig test ./math/tanh.zig --test-filter "math.tanh32" &&
#zig test ./math/tanh.zig --test-filter "math.tanh64" &&
#zig test ./math/tanh.zig --test-filter "math.tanh32.special" &&
#zig test ./math/tanh.zig --test-filter "math.tanh64.special" &&
#zig test ./math/atanh.zig --test-filter "math.atanh" &&
#zig test ./math/atanh.zig --test-filter "math.atanh_32" &&
#zig test ./math/atanh.zig --test-filter "math.atanh_64" &&
#zig test ./math/atanh.zig --test-filter "math.atanh32.special" &&
#zig test ./math/atanh.zig --test-filter "math.atanh64.special" &&
#zig test ./math/cos.zig --test-filter "math.cos" &&
#zig test ./math/cos.zig --test-filter "math.cos32" &&
#zig test ./math/cos.zig --test-filter "math.cos64" &&
#zig test ./math/cos.zig --test-filter "math.cos32.special" &&
#zig test ./math/cos.zig --test-filter "math.cos64.special" &&
#zig test ./math/atan2.zig --test-filter "math.atan2" &&
#zig test ./math/atan2.zig --test-filter "math.atan2_32" &&
#zig test ./math/atan2.zig --test-filter "math.atan2_64" &&
#zig test ./math/atan2.zig --test-filter "math.atan2_32.special" &&
#zig test ./math/atan2.zig --test-filter "math.atan2_64.special" &&
#zig test ./math/isfinite.zig --test-filter "math.isFinite" &&
#zig test ./math/powi.zig --test-filter "math.powi" &&
#zig test ./math/powi.zig --test-filter "math.powi.special" &&
#zig test ./math/floor.zig --test-filter "math.floor" &&
#zig test ./math/floor.zig --test-filter "math.floor16" &&
#zig test ./math/floor.zig --test-filter "math.floor32" &&
#zig test ./math/floor.zig --test-filter "math.floor64" &&
#zig test ./math/floor.zig --test-filter "math.floor16.special" &&
#zig test ./math/floor.zig --test-filter "math.floor32.special" &&
#zig test ./math/floor.zig --test-filter "math.floor64.special" &&
#zig test ./math/cbrt.zig --test-filter "math.cbrt" &&
#zig test ./math/cbrt.zig --test-filter "math.cbrt32" &&
#zig test ./math/cbrt.zig --test-filter "math.cbrt64" &&
#zig test ./math/cbrt.zig --test-filter "math.cbrt.special" &&
#zig test ./math/cbrt.zig --test-filter "math.cbrt64.special" &&
#zig test ./math/log10.zig --test-filter "math.log10" &&
#zig test ./math/log10.zig --test-filter "math.log10_32" &&
#zig test ./math/log10.zig --test-filter "math.log10_64" &&
#zig test ./math/log10.zig --test-filter "math.log10_32.special" &&
#zig test ./math/log10.zig --test-filter "math.log10_64.special" &&
#zig test ./math/round.zig --test-filter "math.round" &&
#zig test ./math/round.zig --test-filter "math.round32" &&
#zig test ./math/round.zig --test-filter "math.round64" &&
#zig test ./math/round.zig --test-filter "math.round32.special" &&
#zig test ./math/round.zig --test-filter "math.round64.special" &&
#zig test ./math/isnan.zig --test-filter "math.isNan" &&
#zig test ./math/sqrt.zig --test-filter "math.sqrt" &&
#zig test ./math/sqrt.zig --test-filter "math.sqrt16" &&
#zig test ./math/sqrt.zig --test-filter "math.sqrt32" &&
#zig test ./math/sqrt.zig --test-filter "math.sqrt64" &&
#zig test ./math/sqrt.zig --test-filter "math.sqrt16.special" &&
#zig test ./math/sqrt.zig --test-filter "math.sqrt32.special" &&
#zig test ./math/sqrt.zig --test-filter "math.sqrt64.special" &&
#zig test ./math/sqrt.zig --test-filter "math.sqrt_int" &&
#zig test ./math/fabs.zig --test-filter "math.fabs" &&
#zig test ./math/fabs.zig --test-filter "math.fabs16" &&
#zig test ./math/fabs.zig --test-filter "math.fabs32" &&
#zig test ./math/fabs.zig --test-filter "math.fabs64" &&
#zig test ./math/fabs.zig --test-filter "math.fabs16.special" &&
#zig test ./math/fabs.zig --test-filter "math.fabs32.special" &&
#zig test ./math/fabs.zig --test-filter "math.fabs64.special" &&
#zig test ./math/log.zig --test-filter "math.log integer" &&
#zig test ./math/log.zig --test-filter "math.log float" &&
#zig test ./math/log.zig --test-filter "math.log float_special" &&
#zig test ./math/cosh.zig --test-filter "math.cosh" &&
#zig test ./math/cosh.zig --test-filter "math.cosh32" &&
#zig test ./math/cosh.zig --test-filter "math.cosh64" &&
#zig test ./math/cosh.zig --test-filter "math.cosh32.special" &&
#zig test ./math/cosh.zig --test-filter "math.cosh64.special" &&
#zig test ./math/acosh.zig --test-filter "math.acosh" &&
#zig test ./math/acosh.zig --test-filter "math.acosh32" &&
#zig test ./math/acosh.zig --test-filter "math.acosh64" &&
#zig test ./math/acosh.zig --test-filter "math.acosh32.special" &&
#zig test ./math/acosh.zig --test-filter "math.acosh64.special" &&
#zig test ./math/big/int.zig --test-filter "big.int comptime_int set" &&
#zig test ./math/big/int.zig --test-filter "big.int comptime_int set negative" &&
#zig test ./math/big/int.zig --test-filter "big.int int set unaligned small" &&
#zig test ./math/big/int.zig --test-filter "big.int comptime_int to" &&
#zig test ./math/big/int.zig --test-filter "big.int sub-limb to" &&
#zig test ./math/big/int.zig --test-filter "big.int to target too small error" &&
#zig test ./math/big/int.zig --test-filter "big.int norm1" &&
#zig test ./math/big/int.zig --test-filter "big.int normN" &&
#zig test ./math/big/int.zig --test-filter "big.int parity" &&
#zig test ./math/big/int.zig --test-filter "big.int bitcount + sizeInBase" &&
#zig test ./math/big/int.zig --test-filter "big.int bitcount/to" &&
#zig test ./math/big/int.zig --test-filter "big.int fits" &&
#zig test ./math/big/int.zig --test-filter "big.int string set" &&
#zig test ./math/big/int.zig --test-filter "big.int string negative" &&
#zig test ./math/big/int.zig --test-filter "big.int string set bad char error" &&
#zig test ./math/big/int.zig --test-filter "big.int string set bad base error" &&
#zig test ./math/big/int.zig --test-filter "big.int string to" &&
#zig test ./math/big/int.zig --test-filter "big.int string to base base error" &&
#zig test ./math/big/int.zig --test-filter "big.int string to base 2" &&
#zig test ./math/big/int.zig --test-filter "big.int string to base 16" &&
#zig test ./math/big/int.zig --test-filter "big.int neg string to" &&
#zig test ./math/big/int.zig --test-filter "big.int zero string to" &&
#zig test ./math/big/int.zig --test-filter "big.int clone" &&
#zig test ./math/big/int.zig --test-filter "big.int swap" &&
#zig test ./math/big/int.zig --test-filter "big.int to negative" &&
#zig test ./math/big/int.zig --test-filter "big.int compare" &&
#zig test ./math/big/int.zig --test-filter "big.int compare similar" &&
#zig test ./math/big/int.zig --test-filter "big.int compare different limb size" &&
#zig test ./math/big/int.zig --test-filter "big.int compare multi-limb" &&
#zig test ./math/big/int.zig --test-filter "big.int equality" &&
#zig test ./math/big/int.zig --test-filter "big.int abs" &&
#zig test ./math/big/int.zig --test-filter "big.int negate" &&
#zig test ./math/big/int.zig --test-filter "big.int add single-single" &&
#zig test ./math/big/int.zig --test-filter "big.int add multi-single" &&
#zig test ./math/big/int.zig --test-filter "big.int add multi-multi" &&
#zig test ./math/big/int.zig --test-filter "big.int add zero-zero" &&
#zig test ./math/big/int.zig --test-filter "big.int add alias multi-limb nonzero-zero" &&
#zig test ./math/big/int.zig --test-filter "big.int add sign" &&
#zig test ./math/big/int.zig --test-filter "big.int sub single-single" &&
#zig test ./math/big/int.zig --test-filter "big.int sub multi-single" &&
#zig test ./math/big/int.zig --test-filter "big.int sub multi-multi" &&
#zig test ./math/big/int.zig --test-filter "big.int sub equal" &&
#zig test ./math/big/int.zig --test-filter "big.int sub sign" &&
#zig test ./math/big/int.zig --test-filter "big.int mul single-single" &&
#zig test ./math/big/int.zig --test-filter "big.int mul multi-single" &&
#zig test ./math/big/int.zig --test-filter "big.int mul multi-multi" &&
#zig test ./math/big/int.zig --test-filter "big.int mul alias r with a" &&
#zig test ./math/big/int.zig --test-filter "big.int mul alias r with b" &&
#zig test ./math/big/int.zig --test-filter "big.int mul alias r with a and b" &&
#zig test ./math/big/int.zig --test-filter "big.int mul a*0" &&
#zig test ./math/big/int.zig --test-filter "big.int mul 0*0" &&
#zig test ./math/big/int.zig --test-filter "big.int div single-single no rem" &&
#zig test ./math/big/int.zig --test-filter "big.int div single-single with rem" &&
#zig test ./math/big/int.zig --test-filter "big.int div multi-single no rem" &&
#zig test ./math/big/int.zig --test-filter "big.int div multi-single with rem" &&
#zig test ./math/big/int.zig --test-filter "big.int div multi>2-single" &&
#zig test ./math/big/int.zig --test-filter "big.int div single-single q < r" &&
#zig test ./math/big/int.zig --test-filter "big.int div single-single q == r" &&
#zig test ./math/big/int.zig --test-filter "big.int div q=0 alias" &&
#zig test ./math/big/int.zig --test-filter "big.int div multi-multi q < r" &&
#zig test ./math/big/int.zig --test-filter "big.int div trunc single-single +/+" &&
#zig test ./math/big/int.zig --test-filter "big.int div trunc single-single -/+" &&
#zig test ./math/big/int.zig --test-filter "big.int div trunc single-single +/-" &&
#zig test ./math/big/int.zig --test-filter "big.int div trunc single-single -/-" &&
#zig test ./math/big/int.zig --test-filter "big.int div floor single-single +/+" &&
#zig test ./math/big/int.zig --test-filter "big.int div floor single-single -/+" &&
#zig test ./math/big/int.zig --test-filter "big.int div floor single-single +/-" &&
#zig test ./math/big/int.zig --test-filter "big.int div floor single-single -/-" &&
#zig test ./math/big/int.zig --test-filter "big.int div multi-multi with rem" &&
#zig test ./math/big/int.zig --test-filter "big.int div multi-multi no rem" &&
#zig test ./math/big/int.zig --test-filter "big.int div multi-multi (2 branch)" &&
#zig test ./math/big/int.zig --test-filter "big.int div multi-multi (3.1/3.3 branch)" &&
#zig test ./math/big/int.zig --test-filter "big.int shift-right single" &&
#zig test ./math/big/int.zig --test-filter "big.int shift-right multi" &&
#zig test ./math/big/int.zig --test-filter "big.int shift-left single" &&
#zig test ./math/big/int.zig --test-filter "big.int shift-left multi" &&
#zig test ./math/big/int.zig --test-filter "big.int shift-right negative" &&
#zig test ./math/big/int.zig --test-filter "big.int shift-left negative" &&
#zig test ./math/big/int.zig --test-filter "big.int bitwise and simple" &&
#zig test ./math/big/int.zig --test-filter "big.int bitwise and multi-limb" &&
#zig test ./math/big/int.zig --test-filter "big.int bitwise xor simple" &&
#zig test ./math/big/int.zig --test-filter "big.int bitwise xor multi-limb" &&
#zig test ./math/big/int.zig --test-filter "big.int bitwise or simple" &&
#zig test ./math/big/int.zig --test-filter "big.int bitwise or multi-limb" &&
#zig test ./math/big/int.zig --test-filter "big.int var args" &&
#zig test ./math/big/index.zig --test-filter "math.big" &&
#zig test ./math/fma.zig --test-filter "math.fma" &&
#zig test ./math/fma.zig --test-filter "math.fma32" &&
#zig test ./math/fma.zig --test-filter "math.fma64" &&
#zig test ./math/ilogb.zig --test-filter "math.ilogb" &&
#zig test ./math/ilogb.zig --test-filter "math.ilogb32" &&
#zig test ./math/ilogb.zig --test-filter "math.ilogb64" &&
#zig test ./math/ilogb.zig --test-filter "math.ilogb32.special" &&
#zig test ./math/ilogb.zig --test-filter "math.ilogb64.special" &&
#zig test ./math/sinh.zig --test-filter "math.sinh" &&
#zig test ./math/sinh.zig --test-filter "math.sinh32" &&
#zig test ./math/sinh.zig --test-filter "math.sinh64" &&
#zig test ./math/sinh.zig --test-filter "math.sinh32.special" &&
#zig test ./math/sinh.zig --test-filter "math.sinh64.special" &&
#zig test ./math/atan.zig --test-filter "math.atan" &&
#zig test ./math/atan.zig --test-filter "math.atan32" &&
#zig test ./math/atan.zig --test-filter "math.atan64" &&
#zig test ./math/atan.zig --test-filter "math.atan32.special" &&
#zig test ./math/atan.zig --test-filter "math.atan64.special" &&
#zig test ./math/tan.zig --test-filter "math.tan" &&
#zig test ./math/tan.zig --test-filter "math.tan32" &&
#zig test ./math/tan.zig --test-filter "math.tan64" &&
#zig test ./math/tan.zig --test-filter "math.tan32.special" &&
#zig test ./math/tan.zig --test-filter "math.tan64.special" &&
#zig test ./math/index.zig --test-filter "math" &&
#zig test ./math/index.zig --test-filter "math.min" &&
#zig test ./math/index.zig --test-filter "math.max" &&
#zig test ./math/index.zig --test-filter "math.shl" &&
#zig test ./math/index.zig --test-filter "math.shr" &&
#zig test ./math/index.zig --test-filter "math.rotr" &&
#zig test ./math/index.zig --test-filter "math.rotl" &&
#zig test ./math/index.zig --test-filter "math.IntFittingRange" &&
#zig test ./math/index.zig --test-filter "math overflow functions" &&
#zig test ./math/index.zig --test-filter "math.absInt" &&
#zig test ./math/index.zig --test-filter "math.divTrunc" &&
#zig test ./math/index.zig --test-filter "math.divFloor" &&
#zig test ./math/index.zig --test-filter "math.divExact" &&
#zig test ./math/index.zig --test-filter "math.mod" &&
#zig test ./math/index.zig --test-filter "math.rem" &&
#zig test ./math/index.zig --test-filter "math.absCast" &&
#zig test ./math/index.zig --test-filter "math.negateCast" &&
#zig test ./math/index.zig --test-filter "math.cast" &&
#zig test ./math/index.zig --test-filter "math.floorPowerOfTwo" &&
#zig test ./math/index.zig --test-filter "std.math.log2_int_ceil" &&
#zig test ./math/index.zig --test-filter "math.f64_min" &&
#zig test ./math/index.zig --test-filter "minInt and maxInt" &&
#zig test ./math/index.zig --test-filter "max value type" &&
#zig test ./math/signbit.zig --test-filter "math.signbit" &&
#zig test ./math/signbit.zig --test-filter "math.signbit16" &&
#zig test ./math/signbit.zig --test-filter "math.signbit32" &&
#zig test ./math/signbit.zig --test-filter "math.signbit64" &&
#zig test ./math/ln.zig --test-filter "math.ln" &&
#zig test ./math/ln.zig --test-filter "math.ln32" &&
#zig test ./math/ln.zig --test-filter "math.ln64" &&
#zig test ./math/ln.zig --test-filter "math.ln32.special" &&
#zig test ./math/ln.zig --test-filter "math.ln64.special" &&
#zig test ./math/sin.zig --test-filter "math.sin" &&
#zig test ./math/sin.zig --test-filter "math.sin32" &&
#zig test ./math/sin.zig --test-filter "math.sin64" &&
#zig test ./math/sin.zig --test-filter "math.sin32.special" &&
#zig test ./math/sin.zig --test-filter "math.sin64.special" &&
#zig test ./math/asin.zig --test-filter "math.asin" &&
#zig test ./math/asin.zig --test-filter "math.asin32" &&
#zig test ./math/asin.zig --test-filter "math.asin64" &&
#zig test ./math/asin.zig --test-filter "math.asin32.special" &&
#zig test ./math/asin.zig --test-filter "math.asin64.special" &&
#zig test ./math/exp.zig --test-filter "math.exp" &&
#zig test ./math/exp.zig --test-filter "math.exp32" &&
#zig test ./math/exp.zig --test-filter "math.exp64" &&
#zig test ./math/exp.zig --test-filter "math.exp32.special" &&
#zig test ./math/exp.zig --test-filter "math.exp64.special" &&
#zig test ./math/isinf.zig --test-filter "math.isInf" &&
#zig test ./math/isinf.zig --test-filter "math.isPositiveInf" &&
#zig test ./math/isinf.zig --test-filter "math.isNegativeInf" &&
#zig test ./math/acos.zig --test-filter "math.acos" &&
#zig test ./math/acos.zig --test-filter "math.acos32" &&
#zig test ./math/acos.zig --test-filter "math.acos64" &&
#zig test ./math/acos.zig --test-filter "math.acos32.special" &&
#zig test ./math/acos.zig --test-filter "math.acos64.special" &&
#zig test ./math/ceil.zig --test-filter "math.ceil" &&
#zig test ./math/ceil.zig --test-filter "math.ceil32" &&
#zig test ./math/ceil.zig --test-filter "math.ceil64" &&
#zig test ./math/ceil.zig --test-filter "math.ceil32.special" &&
#zig test ./math/ceil.zig --test-filter "math.ceil64.special" &&
#zig test ./math/isnormal.zig --test-filter "math.isNormal" &&
#zig test ./math/exp2.zig --test-filter "math.exp2" &&
#zig test ./math/exp2.zig --test-filter "math.exp2_32" &&
#zig test ./math/exp2.zig --test-filter "math.exp2_64" &&
#zig test ./math/exp2.zig --test-filter "math.exp2_32.special" &&
#zig test ./math/exp2.zig --test-filter "math.exp2_64.special" &&
#zig test ./math/modf.zig --test-filter "math.modf" &&
#zig test ./math/modf.zig --test-filter "math.modf32" &&
#zig test ./math/modf.zig --test-filter "math.modf64" &&
#zig test ./math/modf.zig --test-filter "math.modf32.special" &&
#zig test ./math/modf.zig --test-filter "math.modf64.special" &&
#zig test ./math/hypot.zig --test-filter "math.hypot" &&
#zig test ./math/hypot.zig --test-filter "math.hypot32" &&
#zig test ./math/hypot.zig --test-filter "math.hypot64" &&
#zig test ./math/hypot.zig --test-filter "math.hypot32.special" &&
#zig test ./math/hypot.zig --test-filter "math.hypot64.special" &&
#zig test ./math/pow.zig --test-filter "math.pow" &&
#zig test ./math/pow.zig --test-filter "math.pow.special" &&
#zig test ./mem.zig --test-filter "std.mem.secureZero" &&
#zig test ./mem.zig --test-filter "std.mem.compare" &&
#zig test ./mem.zig --test-filter "std.mem.lessThan" &&
#zig test ./mem.zig --test-filter "std.mem.trim" &&
#zig test ./mem.zig --test-filter "std.mem.indexOf" &&
#zig test ./mem.zig --test-filter "std.mem.readIntBig and readIntLittle" &&
#zig test ./mem.zig --test-filter "std.mem.writeIntBig and writeIntLittle" &&
#zig test ./mem.zig --test-filter "std.mem.split" &&
#zig test ./mem.zig --test-filter "std.mem.startsWith" &&
#zig test ./mem.zig --test-filter "std.mem.endsWith" &&
#zig test ./mem.zig --test-filter "std.mem.join" &&
#zig test ./mem.zig --test-filter "std.mem testStringEquality" &&
#zig test ./mem.zig --test-filter "std.mem testReadInt" &&
#zig test ./mem.zig --test-filter "std.mem.writeIntSlice" &&
#zig test ./mem.zig --test-filter "std.mem.min" &&
#zig test ./mem.zig --test-filter "std.mem.max" &&
#zig test ./mem.zig --test-filter "std.mem.reverse" &&
#zig test ./mem.zig --test-filter "std.mem.rotate" &&
#zig test ./mem.zig --test-filter "std.mem.asBytes" &&
#zig test ./mem.zig --test-filter "std.mem.toBytes" &&
#zig test ./mem.zig --test-filter "std.mem.bytesAsValue" &&
#zig test ./mem.zig --test-filter "std.mem.bytesToValue" &&
#zig test ./mem.zig --test-filter "std.mem.subArrayPtr" &&
#zig test ./spinlock.zig --test-filter "spinlock" &&
#zig test ./io_test.zig --test-filter "write a file, read it, then delete it" &&
#zig test ./io_test.zig --test-filter "BufferOutStream" &&
#zig test ./io_test.zig --test-filter "SliceInStream" &&
#zig test ./io_test.zig --test-filter "PeekStream" &&
#zig test ./io_test.zig --test-filter "SliceOutStream" &&
#zig test ./atomic/stack.zig --test-filter "std.atomic.stack" &&
#zig test ./atomic/queue.zig --test-filter "std.atomic.Queue" &&
#zig test ./atomic/queue.zig --test-filter "std.atomic.Queue single-threaded" &&
#zig test ./atomic/queue.zig --test-filter "std.atomic.Queue dump" &&
#zig test ./atomic/index.zig --test-filter "std.atomic" &&
#zig test ./lazy_init.zig --test-filter "std.lazyInit" &&
#zig test ./lazy_init.zig --test-filter "std.lazyInit(void)" &&
#zig test ./sort.zig --test-filter "stable sort" &&
#zig test ./sort.zig --test-filter "std.sort" &&
#zig test ./sort.zig --test-filter "std.sort descending" &&
#zig test ./sort.zig --test-filter "another sort case" &&
#zig test ./sort.zig --test-filter "sort fuzz testing" &&
#zig test ./heap.zig --test-filter "std.heap.c_allocator" &&
#zig test ./heap.zig --test-filter "std.heap.DirectAllocator" &&
#zig test ./heap.zig --test-filter "std.heap.ArenaAllocator" &&
#zig test ./heap.zig --test-filter "std.heap.FixedBufferAllocator" &&
#zig test ./heap.zig --test-filter "std.heap.FixedBufferAllocator Reuse memory on realloc" &&
#zig test ./heap.zig --test-filter "std.heap.ThreadSafeFixedBufferAllocator" &&
#zig test ./cstr.zig --test-filter "cstr fns" &&
#zig test ./json.zig --test-filter "json.token" &&
#zig test ./json.zig --test-filter "json.validate" &&
#zig test ./json.zig --test-filter "json.parser.dynamic" &&
#zig test ./event.zig --test-filter "import event tests" &&
#zig test ./rb.zig --test-filter "rb" &&
#
##ERROR: incorrect std.os.posixOpen call
#zig test ./dynamic_library.zig --test-filter "dynamic_library" &&
#
#zig test ./buffer.zig --test-filter "simple Buffer" &&
#zig test ./zig/parser_test.zig --test-filter "zig fmt: linksection" &&
#zig test ./zig/parser_test.zig --test-filter "zig fmt: shebang line" &&
#zig test ./zig/parser_test.zig --test-filter "zig fmt: correctly move doc comments on struct fields" &&
#zig test ./zig/parser_test.zig --test-filter "zig fmt: preserve space between async fn definitions" &&
#zig test ./zig/parser_test.zig --test-filter "zig fmt: comment to disable/enable zig fmt first" &&
#zig test ./zig/parser_test.zig --test-filter "zig fmt: comment to disable/enable zig fmt" &&
#zig test ./zig/parser_test.zig --test-filter "zig fmt: pointer of unknown length" &&
#zig test ./zig/parser_test.zig --test-filter "zig fmt: spaces around slice operator" &&
#zig test ./zig/parser_test.zig --test-filter "zig fmt: async call in if condition" &&
#zig test ./zig/parser_test.zig --test-filter "zig fmt: 2nd arg multiline string" &&
#zig test ./zig/parser_test.zig --test-filter "zig fmt: if condition wraps" &&
#zig test ./zig/parser_test.zig --test-filter "zig fmt: if condition has line break but must not wrap" &&
#zig test ./zig/parser_test.zig --test-filter "zig fmt: same-line doc comment on variable declaration" &&
#zig test ./zig/parser_test.zig --test-filter "zig fmt: if-else with comment before else" &&
#zig test ./zig/parser_test.zig --test-filter "zig fmt: respect line breaks in if-else" &&
#zig test ./zig/parser_test.zig --test-filter "zig fmt: respect line breaks after infix operators" &&
#zig test ./zig/parser_test.zig --test-filter "zig fmt: fn decl with trailing comma" &&
#zig test ./zig/parser_test.zig --test-filter "zig fmt: enum decl with no trailing comma" &&
#zig test ./zig/parser_test.zig --test-filter "zig fmt: switch comment before prong" &&
#zig test ./zig/parser_test.zig --test-filter "zig fmt: struct literal no trailing comma" &&
#zig test ./zig/parser_test.zig --test-filter "zig fmt: array literal with hint" &&
#zig test ./zig/parser_test.zig --test-filter "zig fmt: multiline string with backslash at end of line" &&
#zig test ./zig/parser_test.zig --test-filter "zig fmt: multiline string parameter in fn call with trailing comma" &&
#zig test ./zig/parser_test.zig --test-filter "zig fmt: trailing comma on fn call" &&
#zig test ./zig/parser_test.zig --test-filter "zig fmt: empty block with only comment" &&
#zig test ./zig/parser_test.zig --test-filter "zig fmt: no trailing comma on struct decl" &&
#zig test ./zig/parser_test.zig --test-filter "zig fmt: simple asm" &&
#zig test ./zig/parser_test.zig --test-filter "zig fmt: nested struct literal with one item" &&
#zig test ./zig/parser_test.zig --test-filter "zig fmt: switch cases trailing comma" &&
#zig test ./zig/parser_test.zig --test-filter "zig fmt: slice align" &&
#zig test ./zig/parser_test.zig --test-filter "zig fmt: add trailing comma to array literal" &&
#zig test ./zig/parser_test.zig --test-filter "zig fmt: first thing in file is line comment" &&
#zig test ./zig/parser_test.zig --test-filter "zig fmt: line comment after doc comment" &&
#zig test ./zig/parser_test.zig --test-filter "zig fmt: float literal with exponent" &&
#zig test ./zig/parser_test.zig --test-filter "zig fmt: float literal with exponent" &&
#zig test ./zig/parser_test.zig --test-filter "zig fmt: float literal with exponent" &&
#zig test ./zig/parser_test.zig --test-filter "zig fmt: if-else end of comptime" &&
#zig test ./zig/parser_test.zig --test-filter "zig fmt: nested blocks" &&
#zig test ./zig/parser_test.zig --test-filter "zig fmt: block with same line comment after end brace" &&
#zig test ./zig/parser_test.zig --test-filter "zig fmt: statements with comment between" &&
#zig test ./zig/parser_test.zig --test-filter "zig fmt: statements with empty line between" &&
#zig test ./zig/parser_test.zig --test-filter "zig fmt: ptr deref operator and unwrap optional operator" &&
#zig test ./zig/parser_test.zig --test-filter "zig fmt: comment after if before another if" &&
#zig test ./zig/parser_test.zig --test-filter "zig fmt: line comment between if block and else keyword" &&
#zig test ./zig/parser_test.zig --test-filter "zig fmt: same line comments in expression" &&
#zig test ./zig/parser_test.zig --test-filter "zig fmt: add comma on last switch prong" &&
#zig test ./zig/parser_test.zig --test-filter "zig fmt: same-line comment after a statement" &&
#zig test ./zig/parser_test.zig --test-filter "zig fmt: same-line comment after var decl in struct" &&
#zig test ./zig/parser_test.zig --test-filter "zig fmt: same-line comment after field decl" &&
#zig test ./zig/parser_test.zig --test-filter "zig fmt: same-line comment after switch prong" &&
#zig test ./zig/parser_test.zig --test-filter "zig fmt: same-line comment after non-block if expression" &&
#zig test ./zig/parser_test.zig --test-filter "zig fmt: same-line comment on comptime expression" &&
#zig test ./zig/parser_test.zig --test-filter "zig fmt: switch with empty body" &&
#zig test ./zig/parser_test.zig --test-filter "zig fmt: line comments in struct initializer" &&
#zig test ./zig/parser_test.zig --test-filter "zig fmt: doc comments before struct field" &&
#zig test ./zig/parser_test.zig --test-filter "zig fmt: error set declaration" &&
#zig test ./zig/parser_test.zig --test-filter "zig fmt: union(enum(u32)) with assigned enum values" &&
#zig test ./zig/parser_test.zig --test-filter "zig fmt: resume from suspend block" &&
#zig test ./zig/parser_test.zig --test-filter "zig fmt: comments before error set decl" &&
#zig test ./zig/parser_test.zig --test-filter "zig fmt: comments before switch prong" &&
#zig test ./zig/parser_test.zig --test-filter "zig fmt: comments before var decl in struct" &&
#zig test ./zig/parser_test.zig --test-filter "zig fmt: array literal with 1 item on 1 line" &&
#zig test ./zig/parser_test.zig --test-filter "zig fmt: comments before global variables" &&
#zig test ./zig/parser_test.zig --test-filter "zig fmt: comments in statements" &&
#zig test ./zig/parser_test.zig --test-filter "zig fmt: comments before test decl" &&
#zig test ./zig/parser_test.zig --test-filter "zig fmt: preserve spacing" &&
#zig test ./zig/parser_test.zig --test-filter "zig fmt: return types" &&
#zig test ./zig/parser_test.zig --test-filter "zig fmt: imports" &&
#zig test ./zig/parser_test.zig --test-filter "zig fmt: global declarations" &&
#zig test ./zig/parser_test.zig --test-filter "zig fmt: extern declaration" &&
#zig test ./zig/parser_test.zig --test-filter "zig fmt: alignment" &&
#zig test ./zig/parser_test.zig --test-filter "zig fmt: C main" &&
#zig test ./zig/parser_test.zig --test-filter "zig fmt: return" &&
#zig test ./zig/parser_test.zig --test-filter "zig fmt: pointer attributes" &&
#zig test ./zig/parser_test.zig --test-filter "zig fmt: slice attributes" &&
#zig test ./zig/parser_test.zig --test-filter "zig fmt: test declaration" &&
#zig test ./zig/parser_test.zig --test-filter "zig fmt: infix operators" &&
#zig test ./zig/parser_test.zig --test-filter "zig fmt: precedence" &&
#zig test ./zig/parser_test.zig --test-filter "zig fmt: prefix operators" &&
#zig test ./zig/parser_test.zig --test-filter "zig fmt: call expression" &&
#zig test ./zig/parser_test.zig --test-filter "zig fmt: var args" &&
#zig test ./zig/parser_test.zig --test-filter "zig fmt: var type" &&
#zig test ./zig/parser_test.zig --test-filter "zig fmt: functions" &&
#zig test ./zig/parser_test.zig --test-filter "zig fmt: multiline string" &&
#zig test ./zig/parser_test.zig --test-filter "zig fmt: values" &&
#zig test ./zig/parser_test.zig --test-filter "zig fmt: indexing" &&
#zig test ./zig/parser_test.zig --test-filter "zig fmt: struct declaration" &&
#zig test ./zig/parser_test.zig --test-filter "zig fmt: enum declaration" &&
#zig test ./zig/parser_test.zig --test-filter "zig fmt: union declaration" &&
#zig test ./zig/parser_test.zig --test-filter "zig fmt: arrays" &&
#zig test ./zig/parser_test.zig --test-filter "zig fmt: container initializers" &&
#zig test ./zig/parser_test.zig --test-filter "zig fmt: catch" &&
#zig test ./zig/parser_test.zig --test-filter "zig fmt: blocks" &&
#zig test ./zig/parser_test.zig --test-filter "zig fmt: switch" &&
#zig test ./zig/parser_test.zig --test-filter "zig fmt: while" &&
#zig test ./zig/parser_test.zig --test-filter "zig fmt: for" &&
#zig test ./zig/parser_test.zig --test-filter "zig fmt: if" &&
#zig test ./zig/parser_test.zig --test-filter "zig fmt: defer" &&
#zig test ./zig/parser_test.zig --test-filter "zig fmt: comptime" &&
#zig test ./zig/parser_test.zig --test-filter "zig fmt: fn type" &&
#zig test ./zig/parser_test.zig --test-filter "zig fmt: inline asm" &&
#zig test ./zig/parser_test.zig --test-filter "zig fmt: coroutines" &&
#zig test ./zig/parser_test.zig --test-filter "zig fmt: Block after if" &&
#zig test ./zig/parser_test.zig --test-filter "zig fmt: use" &&
#zig test ./zig/parser_test.zig --test-filter "zig fmt: string identifier" &&
#zig test ./zig/parser_test.zig --test-filter "zig fmt: error return" &&
#zig test ./zig/parse.zig --test-filter "std.zig.parser" &&
#zig test ./zig/ast.zig --test-filter "iterate" &&
#zig test ./zig/index.zig --test-filter "std.zig tests" &&
#zig test ./zig/tokenizer.zig --test-filter "tokenizer" &&
#zig test ./zig/tokenizer.zig --test-filter "tokenizer - unknown length pointer" &&
#zig test ./zig/tokenizer.zig --test-filter "tokenizer - char literal with hex escape" &&
#zig test ./zig/tokenizer.zig --test-filter "tokenizer - float literal e exponent" &&
#zig test ./zig/tokenizer.zig --test-filter "tokenizer - float literal p exponent" &&
#zig test ./zig/tokenizer.zig --test-filter "tokenizer - chars" &&
#zig test ./zig/tokenizer.zig --test-filter "tokenizer - invalid token characters" &&
#zig test ./zig/tokenizer.zig --test-filter "tokenizer - invalid literal/comment characters" &&
#zig test ./zig/tokenizer.zig --test-filter "tokenizer - utf8" &&
#zig test ./zig/tokenizer.zig --test-filter "tokenizer - invalid utf8" &&
#zig test ./zig/tokenizer.zig --test-filter "tokenizer - illegal unicode codepoints" &&
#zig test ./zig/tokenizer.zig --test-filter "tokenizer - string identifier and builtin fns" &&
#zig test ./zig/tokenizer.zig --test-filter "tokenizer - pipe and then invalid" &&
#zig test ./zig/tokenizer.zig --test-filter "tokenizer - line comment and doc comment" &&
#zig test ./zig/tokenizer.zig --test-filter "tokenizer - line comment followed by identifier" &&
#zig test ./fmt/index.zig --test-filter "fmt.parseInt" &&
#zig test ./fmt/index.zig --test-filter "parseUnsigned" &&
#zig test ./fmt/index.zig --test-filter "buf print int" &&
#zig test ./fmt/index.zig --test-filter "parse u64 digit too big" &&
#zig test ./fmt/index.zig --test-filter "parse unsigned comptime" &&
#zig test ./fmt/index.zig --test-filter "fmt.format" &&
#zig test ./fmt/index.zig --test-filter "fmt.trim" &&
#zig test ./fmt/index.zig --test-filter "fmt.hexToBytes" &&
#zig test ./mutex.zig --test-filter "std.Mutex" &&
#zig test ./index.zig --test-filter "std" &&
#zig test ./net.zig --test-filter "std.net.parseIp4" &&
#zig test ./net.zig --test-filter "std.net.parseIp6" &&
#zig test ./crypto/md5.zig --test-filter "md5 single" &&
#zig test ./crypto/md5.zig --test-filter "md5 streaming" &&
#zig test ./crypto/md5.zig --test-filter "md5 aligned final" &&
#zig test ./crypto/poly1305.zig --test-filter "poly1305 rfc7439 vector1" &&
#zig test ./crypto/sha2.zig --test-filter "sha224 single" &&
#zig test ./crypto/sha2.zig --test-filter "sha224 streaming" &&
#zig test ./crypto/sha2.zig --test-filter "sha256 single" &&
#zig test ./crypto/sha2.zig --test-filter "sha256 streaming" &&
#zig test ./crypto/sha2.zig --test-filter "sha256 aligned final" &&
#zig test ./crypto/sha2.zig --test-filter "sha384 single" &&
#zig test ./crypto/sha2.zig --test-filter "sha384 streaming" &&
#zig test ./crypto/sha2.zig --test-filter "sha512 single" &&
#zig test ./crypto/sha2.zig --test-filter "sha512 streaming" &&
#zig test ./crypto/sha2.zig --test-filter "sha512 aligned final" &&
#zig test ./crypto/hmac.zig --test-filter "hmac md5" &&
#zig test ./crypto/hmac.zig --test-filter "hmac sha1" &&
#zig test ./crypto/hmac.zig --test-filter "hmac sha256" &&
#zig test ./crypto/sha1.zig --test-filter "sha1 single" &&
#zig test ./crypto/sha1.zig --test-filter "sha1 streaming" &&
#zig test ./crypto/sha1.zig --test-filter "sha1 aligned final" &&
#zig test ./crypto/sha3.zig --test-filter "sha3-224 single" &&
#zig test ./crypto/sha3.zig --test-filter "sha3-224 streaming" &&
#zig test ./crypto/sha3.zig --test-filter "sha3-256 single" &&
#zig test ./crypto/sha3.zig --test-filter "sha3-256 streaming" &&
#zig test ./crypto/sha3.zig --test-filter "sha3-256 aligned final" &&
#zig test ./crypto/sha3.zig --test-filter "sha3-384 single" &&
#zig test ./crypto/sha3.zig --test-filter "sha3-384 streaming" &&
#zig test ./crypto/sha3.zig --test-filter "sha3-512 single" &&
#zig test ./crypto/sha3.zig --test-filter "sha3-512 streaming" &&
#zig test ./crypto/sha3.zig --test-filter "sha3-512 aligned final" &&
#zig test ./crypto/chacha20.zig --test-filter "crypto.chacha20 test vector sunscreen" &&
#zig test ./crypto/chacha20.zig --test-filter "crypto.chacha20 test vector 1" &&
#zig test ./crypto/chacha20.zig --test-filter "crypto.chacha20 test vector 2" &&
#zig test ./crypto/chacha20.zig --test-filter "crypto.chacha20 test vector 3" &&
#zig test ./crypto/chacha20.zig --test-filter "crypto.chacha20 test vector 4" &&
#zig test ./crypto/chacha20.zig --test-filter "crypto.chacha20 test vector 5" &&
#zig test ./crypto/index.zig --test-filter "crypto" &&
#zig test ./crypto/x25519.zig --test-filter "x25519 public key calculation from secret key" &&
#zig test ./crypto/x25519.zig --test-filter "x25519 rfc7748 vector1" &&
#zig test ./crypto/x25519.zig --test-filter "x25519 rfc7748 vector2" &&
#zig test ./crypto/x25519.zig --test-filter "x25519 rfc7748 one iteration" &&
#zig test ./crypto/x25519.zig --test-filter "x25519 rfc7748 1,000 iterations" &&
#zig test ./crypto/x25519.zig --test-filter "x25519 rfc7748 1,000,000 iterations" &&
#zig test ./crypto/blake2.zig --test-filter "blake2s224 single" &&
#zig test ./crypto/blake2.zig --test-filter "blake2s224 streaming" &&
#zig test ./crypto/blake2.zig --test-filter "blake2s256 single" &&
#zig test ./crypto/blake2.zig --test-filter "blake2s256 streaming" &&
#zig test ./crypto/blake2.zig --test-filter "blake2s256 aligned final" &&
#zig test ./crypto/blake2.zig --test-filter "blake2b384 single" &&
#zig test ./crypto/blake2.zig --test-filter "blake2b384 streaming" &&
#zig test ./crypto/blake2.zig --test-filter "blake2b512 single" &&
#zig test ./crypto/blake2.zig --test-filter "blake2b512 streaming" &&
#zig test ./crypto/blake2.zig --test-filter "blake2b512 aligned final" &&
#zig test ./buf_map.zig --test-filter "BufMap" &&
#zig test ./base64.zig --test-filter "base64" &&
#zig test ./unicode.zig --test-filter "utf8 encode" &&
#zig test ./unicode.zig --test-filter "utf8 encode error" &&
#zig test ./unicode.zig --test-filter "utf8 iterator on ascii" &&
#zig test ./unicode.zig --test-filter "utf8 view bad" &&
#zig test ./unicode.zig --test-filter "utf8 view ok" &&
#zig test ./unicode.zig --test-filter "bad utf8 slice" &&
#zig test ./unicode.zig --test-filter "valid utf8" &&
#zig test ./unicode.zig --test-filter "invalid utf8 continuation bytes" &&
#zig test ./unicode.zig --test-filter "overlong utf8 codepoint" &&
#zig test ./unicode.zig --test-filter "misc invalid utf8" &&
#zig test ./unicode.zig --test-filter "utf16leToUtf8" &&
#zig test ./segmented_list.zig --test-filter "std.SegmentedList" &&
#zig test ./hash/fnv.zig --test-filter "fnv1a-32" &&
#zig test ./hash/fnv.zig --test-filter "fnv1a-64" &&
#zig test ./hash/fnv.zig --test-filter "fnv1a-128" &&
#zig test ./hash/crc.zig --test-filter "crc32 ieee" &&
#zig test ./hash/crc.zig --test-filter "crc32 castagnoli" &&
#zig test ./hash/crc.zig --test-filter "small crc32 ieee" &&
#zig test ./hash/crc.zig --test-filter "small crc32 castagnoli" &&
#zig test ./hash/index.zig --test-filter "hash" &&
#zig test ./hash/siphash.zig --test-filter "siphash64-2-4 sanity" &&
#zig test ./hash/siphash.zig --test-filter "siphash128-2-4 sanity" &&
#zig test ./hash/adler.zig --test-filter "adler32 sanity" &&
#zig test ./hash/adler.zig --test-filter "adler32 long" &&
#zig test ./hash/adler.zig --test-filter "adler32 very long" &&
#zig test ./array_list.zig --test-filter "std.ArrayList.init" &&
#zig test ./array_list.zig --test-filter "std.ArrayList.basic" &&
#zig test ./array_list.zig --test-filter "std.ArrayList.swapRemove" &&
#zig test ./array_list.zig --test-filter "std.ArrayList.swapRemoveOrError" &&
#zig test ./array_list.zig --test-filter "std.ArrayList.iterator" &&
#zig test ./array_list.zig --test-filter "std.ArrayList.insert" &&
#zig test ./array_list.zig --test-filter "std.ArrayList.insertSlice" &&
#zig test ./hash_map.zig --test-filter "basic hash map usage" &&
#zig test ./hash_map.zig --test-filter "iterator hash map" &&
#zig test ./buf_set.zig --test-filter "BufSet" &&


echo "Done."

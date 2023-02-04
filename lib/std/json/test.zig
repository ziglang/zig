// RFC 8529 conformance tests.
//
// Tests are taken from https://github.com/nst/JSONTestSuite
// Read also http://seriot.ch/parsing_json.php for a good overview.

const std = @import("../std.zig");
const json = std.json;
const testing = std.testing;
const TokenStream = std.json.TokenStream;
const parse = std.json.parse;
const ParseOptions = std.json.ParseOptions;
const parseFree = std.json.parseFree;
const Parser = std.json.Parser;
const mem = std.mem;
const writeStream = std.json.writeStream;
const Value = std.json.Value;
const StringifyOptions = std.json.StringifyOptions;
const stringify = std.json.stringify;
const stringifyAlloc = std.json.stringifyAlloc;
const StreamingParser = std.json.StreamingParser;
const Token = std.json.Token;
const validate = std.json.validate;
const Array = std.json.Array;
const ObjectMap = std.json.ObjectMap;
const assert = std.debug.assert;

fn testNonStreaming(s: []const u8) !void {
    var p = json.Parser.init(testing.allocator, false);
    defer p.deinit();

    var tree = try p.parse(s);
    defer tree.deinit();
}

fn ok(s: []const u8) !void {
    try testing.expect(json.validate(s));

    try testNonStreaming(s);
}

fn err(s: []const u8) !void {
    try testing.expect(!json.validate(s));

    try testing.expect(std.meta.isError(testNonStreaming(s)));
}

fn utf8Error(s: []const u8) !void {
    try testing.expect(!json.validate(s));

    try testing.expectError(error.InvalidUtf8Byte, testNonStreaming(s));
}

fn any(s: []const u8) !void {
    _ = json.validate(s);

    testNonStreaming(s) catch {};
}

fn anyStreamingErrNonStreaming(s: []const u8) !void {
    _ = json.validate(s);

    try testing.expect(std.meta.isError(testNonStreaming(s)));
}

fn roundTrip(s: []const u8) !void {
    try testing.expect(json.validate(s));

    var p = json.Parser.init(testing.allocator, false);
    defer p.deinit();

    var tree = try p.parse(s);
    defer tree.deinit();

    var buf: [256]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    try tree.root.jsonStringify(.{}, fbs.writer());

    try testing.expectEqualStrings(s, fbs.getWritten());
}

////////////////////////////////////////////////////////////////////////////////////////////////////
//
// Additional tests not part of test JSONTestSuite.

test "y_trailing_comma_after_empty" {
    try roundTrip(
        \\{"1":[],"2":{},"3":"4"}
    );
}

test "n_object_closed_missing_value" {
    try err(
        \\{"a":}
    );
}

////////////////////////////////////////////////////////////////////////////////////////////////////

test "y_array_arraysWithSpaces" {
    try ok(
        \\[[]   ]
    );
}

test "y_array_empty" {
    try roundTrip(
        \\[]
    );
}

test "y_array_empty-string" {
    try roundTrip(
        \\[""]
    );
}

test "y_array_ending_with_newline" {
    try roundTrip(
        \\["a"]
    );
}

test "y_array_false" {
    try roundTrip(
        \\[false]
    );
}

test "y_array_heterogeneous" {
    try ok(
        \\[null, 1, "1", {}]
    );
}

test "y_array_null" {
    try roundTrip(
        \\[null]
    );
}

test "y_array_with_1_and_newline" {
    try ok(
        \\[1
        \\]
    );
}

test "y_array_with_leading_space" {
    try ok(
        \\ [1]
    );
}

test "y_array_with_several_null" {
    try roundTrip(
        \\[1,null,null,null,2]
    );
}

test "y_array_with_trailing_space" {
    try ok("[2] ");
}

test "y_number_0e+1" {
    try ok(
        \\[0e+1]
    );
}

test "y_number_0e1" {
    try ok(
        \\[0e1]
    );
}

test "y_number_after_space" {
    try ok(
        \\[ 4]
    );
}

test "y_number_double_close_to_zero" {
    try ok(
        \\[-0.000000000000000000000000000000000000000000000000000000000000000000000000000001]
    );
}

test "y_number_int_with_exp" {
    try ok(
        \\[20e1]
    );
}

test "y_number" {
    try ok(
        \\[123e65]
    );
}

test "y_number_minus_zero" {
    try ok(
        \\[-0]
    );
}

test "y_number_negative_int" {
    try roundTrip(
        \\[-123]
    );
}

test "y_number_negative_one" {
    try roundTrip(
        \\[-1]
    );
}

test "y_number_negative_zero" {
    try ok(
        \\[-0]
    );
}

test "y_number_real_capital_e" {
    try ok(
        \\[1E22]
    );
}

test "y_number_real_capital_e_neg_exp" {
    try ok(
        \\[1E-2]
    );
}

test "y_number_real_capital_e_pos_exp" {
    try ok(
        \\[1E+2]
    );
}

test "y_number_real_exponent" {
    try ok(
        \\[123e45]
    );
}

test "y_number_real_fraction_exponent" {
    try ok(
        \\[123.456e78]
    );
}

test "y_number_real_neg_exp" {
    try ok(
        \\[1e-2]
    );
}

test "y_number_real_pos_exponent" {
    try ok(
        \\[1e+2]
    );
}

test "y_number_simple_int" {
    try roundTrip(
        \\[123]
    );
}

test "y_number_simple_real" {
    try ok(
        \\[123.456789]
    );
}

test "y_object_basic" {
    try roundTrip(
        \\{"asd":"sdf"}
    );
}

test "y_object_duplicated_key_and_value" {
    try ok(
        \\{"a":"b","a":"b"}
    );
}

test "y_object_duplicated_key" {
    try ok(
        \\{"a":"b","a":"c"}
    );
}

test "y_object_empty" {
    try roundTrip(
        \\{}
    );
}

test "y_object_empty_key" {
    try roundTrip(
        \\{"":0}
    );
}

test "y_object_escaped_null_in_key" {
    try ok(
        \\{"foo\u0000bar": 42}
    );
}

test "y_object_extreme_numbers" {
    try ok(
        \\{ "min": -1.0e+28, "max": 1.0e+28 }
    );
}

test "y_object" {
    try ok(
        \\{"asd":"sdf", "dfg":"fgh"}
    );
}

test "y_object_long_strings" {
    try ok(
        \\{"x":[{"id": "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"}], "id": "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"}
    );
}

test "y_object_simple" {
    try roundTrip(
        \\{"a":[]}
    );
}

test "y_object_string_unicode" {
    try ok(
        \\{"title":"\u041f\u043e\u043b\u0442\u043e\u0440\u0430 \u0417\u0435\u043c\u043b\u0435\u043a\u043e\u043f\u0430" }
    );
}

test "y_object_with_newlines" {
    try ok(
        \\{
        \\"a": "b"
        \\}
    );
}

test "y_string_1_2_3_bytes_UTF-8_sequences" {
    try ok(
        \\["\u0060\u012a\u12AB"]
    );
}

test "y_string_accepted_surrogate_pair" {
    try ok(
        \\["\uD801\udc37"]
    );
}

test "y_string_accepted_surrogate_pairs" {
    try ok(
        \\["\ud83d\ude39\ud83d\udc8d"]
    );
}

test "y_string_allowed_escapes" {
    try ok(
        \\["\"\\\/\b\f\n\r\t"]
    );
}

test "y_string_backslash_and_u_escaped_zero" {
    try ok(
        \\["\\u0000"]
    );
}

test "y_string_backslash_doublequotes" {
    try roundTrip(
        \\["\""]
    );
}

test "y_string_comments" {
    try ok(
        \\["a/*b*/c/*d//e"]
    );
}

test "y_string_double_escape_a" {
    try ok(
        \\["\\a"]
    );
}

test "y_string_double_escape_n" {
    try roundTrip(
        \\["\\n"]
    );
}

test "y_string_escaped_control_character" {
    try ok(
        \\["\u0012"]
    );
}

test "y_string_escaped_noncharacter" {
    try ok(
        \\["\uFFFF"]
    );
}

test "y_string_in_array" {
    try ok(
        \\["asd"]
    );
}

test "y_string_in_array_with_leading_space" {
    try ok(
        \\[ "asd"]
    );
}

test "y_string_last_surrogates_1_and_2" {
    try ok(
        \\["\uDBFF\uDFFF"]
    );
}

test "y_string_nbsp_uescaped" {
    try ok(
        \\["new\u00A0line"]
    );
}

test "y_string_nonCharacterInUTF-8_U+10FFFF" {
    try ok(
        \\["􏿿"]
    );
}

test "y_string_nonCharacterInUTF-8_U+FFFF" {
    try ok(
        \\["￿"]
    );
}

test "y_string_null_escape" {
    try ok(
        \\["\u0000"]
    );
}

test "y_string_one-byte-utf-8" {
    try ok(
        \\["\u002c"]
    );
}

test "y_string_pi" {
    try ok(
        \\["π"]
    );
}

test "y_string_reservedCharacterInUTF-8_U+1BFFF" {
    try ok(
        \\["𛿿"]
    );
}

test "y_string_simple_ascii" {
    try ok(
        \\["asd "]
    );
}

test "y_string_space" {
    try roundTrip(
        \\" "
    );
}

test "y_string_surrogates_U+1D11E_MUSICAL_SYMBOL_G_CLEF" {
    try ok(
        \\["\uD834\uDd1e"]
    );
}

test "y_string_three-byte-utf-8" {
    try ok(
        \\["\u0821"]
    );
}

test "y_string_two-byte-utf-8" {
    try ok(
        \\["\u0123"]
    );
}

test "y_string_u+2028_line_sep" {
    try ok("[\"\xe2\x80\xa8\"]");
}

test "y_string_u+2029_par_sep" {
    try ok("[\"\xe2\x80\xa9\"]");
}

test "y_string_uescaped_newline" {
    try ok(
        \\["new\u000Aline"]
    );
}

test "y_string_uEscape" {
    try ok(
        \\["\u0061\u30af\u30EA\u30b9"]
    );
}

test "y_string_unescaped_char_delete" {
    try ok("[\"\x7f\"]");
}

test "y_string_unicode_2" {
    try ok(
        \\["⍂㈴⍂"]
    );
}

test "y_string_unicodeEscapedBackslash" {
    try ok(
        \\["\u005C"]
    );
}

test "y_string_unicode_escaped_double_quote" {
    try ok(
        \\["\u0022"]
    );
}

test "y_string_unicode" {
    try ok(
        \\["\uA66D"]
    );
}

test "y_string_unicode_U+10FFFE_nonchar" {
    try ok(
        \\["\uDBFF\uDFFE"]
    );
}

test "y_string_unicode_U+1FFFE_nonchar" {
    try ok(
        \\["\uD83F\uDFFE"]
    );
}

test "y_string_unicode_U+200B_ZERO_WIDTH_SPACE" {
    try ok(
        \\["\u200B"]
    );
}

test "y_string_unicode_U+2064_invisible_plus" {
    try ok(
        \\["\u2064"]
    );
}

test "y_string_unicode_U+FDD0_nonchar" {
    try ok(
        \\["\uFDD0"]
    );
}

test "y_string_unicode_U+FFFE_nonchar" {
    try ok(
        \\["\uFFFE"]
    );
}

test "y_string_utf8" {
    try ok(
        \\["€𝄞"]
    );
}

test "y_string_with_del_character" {
    try ok("[\"a\x7fa\"]");
}

test "y_structure_lonely_false" {
    try roundTrip(
        \\false
    );
}

test "y_structure_lonely_int" {
    try roundTrip(
        \\42
    );
}

test "y_structure_lonely_negative_real" {
    try ok(
        \\-0.1
    );
}

test "y_structure_lonely_null" {
    try roundTrip(
        \\null
    );
}

test "y_structure_lonely_string" {
    try roundTrip(
        \\"asd"
    );
}

test "y_structure_lonely_true" {
    try roundTrip(
        \\true
    );
}

test "y_structure_string_empty" {
    try roundTrip(
        \\""
    );
}

test "y_structure_trailing_newline" {
    try roundTrip(
        \\["a"]
    );
}

test "y_structure_true_in_array" {
    try roundTrip(
        \\[true]
    );
}

test "y_structure_whitespace_array" {
    try ok(" [] ");
}

////////////////////////////////////////////////////////////////////////////////////////////////////

test "n_array_1_true_without_comma" {
    try err(
        \\[1 true]
    );
}

test "n_array_a_invalid_utf8" {
    try err(
        \\[aå]
    );
}

test "n_array_colon_instead_of_comma" {
    try err(
        \\["": 1]
    );
}

test "n_array_comma_after_close" {
    try err(
        \\[""],
    );
}

test "n_array_comma_and_number" {
    try err(
        \\[,1]
    );
}

test "n_array_double_comma" {
    try err(
        \\[1,,2]
    );
}

test "n_array_double_extra_comma" {
    try err(
        \\["x",,]
    );
}

test "n_array_extra_close" {
    try err(
        \\["x"]]
    );
}

test "n_array_extra_comma" {
    try err(
        \\["",]
    );
}

test "n_array_incomplete_invalid_value" {
    try err(
        \\[x
    );
}

test "n_array_incomplete" {
    try err(
        \\["x"
    );
}

test "n_array_inner_array_no_comma" {
    try err(
        \\[3[4]]
    );
}

test "n_array_invalid_utf8" {
    try err(
        \\[ÿ]
    );
}

test "n_array_items_separated_by_semicolon" {
    try err(
        \\[1:2]
    );
}

test "n_array_just_comma" {
    try err(
        \\[,]
    );
}

test "n_array_just_minus" {
    try err(
        \\[-]
    );
}

test "n_array_missing_value" {
    try err(
        \\[   , ""]
    );
}

test "n_array_newlines_unclosed" {
    try err(
        \\["a",
        \\4
        \\,1,
    );
}

test "n_array_number_and_comma" {
    try err(
        \\[1,]
    );
}

test "n_array_number_and_several_commas" {
    try err(
        \\[1,,]
    );
}

test "n_array_spaces_vertical_tab_formfeed" {
    try err("[\"\x0aa\"\\f]");
}

test "n_array_star_inside" {
    try err(
        \\[*]
    );
}

test "n_array_unclosed" {
    try err(
        \\[""
    );
}

test "n_array_unclosed_trailing_comma" {
    try err(
        \\[1,
    );
}

test "n_array_unclosed_with_new_lines" {
    try err(
        \\[1,
        \\1
        \\,1
    );
}

test "n_array_unclosed_with_object_inside" {
    try err(
        \\[{}
    );
}

test "n_incomplete_false" {
    try err(
        \\[fals]
    );
}

test "n_incomplete_null" {
    try err(
        \\[nul]
    );
}

test "n_incomplete_true" {
    try err(
        \\[tru]
    );
}

test "n_multidigit_number_then_00" {
    try err("123\x00");
}

test "n_number_0.1.2" {
    try err(
        \\[0.1.2]
    );
}

test "n_number_-01" {
    try err(
        \\[-01]
    );
}

test "n_number_0.3e" {
    try err(
        \\[0.3e]
    );
}

test "n_number_0.3e+" {
    try err(
        \\[0.3e+]
    );
}

test "n_number_0_capital_E" {
    try err(
        \\[0E]
    );
}

test "n_number_0_capital_E+" {
    try err(
        \\[0E+]
    );
}

test "n_number_0.e1" {
    try err(
        \\[0.e1]
    );
}

test "n_number_0e" {
    try err(
        \\[0e]
    );
}

test "n_number_0e+" {
    try err(
        \\[0e+]
    );
}

test "n_number_1_000" {
    try err(
        \\[1 000.0]
    );
}

test "n_number_1.0e-" {
    try err(
        \\[1.0e-]
    );
}

test "n_number_1.0e" {
    try err(
        \\[1.0e]
    );
}

test "n_number_1.0e+" {
    try err(
        \\[1.0e+]
    );
}

test "n_number_-1.0." {
    try err(
        \\[-1.0.]
    );
}

test "n_number_1eE2" {
    try err(
        \\[1eE2]
    );
}

test "n_number_.-1" {
    try err(
        \\[.-1]
    );
}

test "n_number_+1" {
    try err(
        \\[+1]
    );
}

test "n_number_.2e-3" {
    try err(
        \\[.2e-3]
    );
}

test "n_number_2.e-3" {
    try err(
        \\[2.e-3]
    );
}

test "n_number_2.e+3" {
    try err(
        \\[2.e+3]
    );
}

test "n_number_2.e3" {
    try err(
        \\[2.e3]
    );
}

test "n_number_-2." {
    try err(
        \\[-2.]
    );
}

test "n_number_9.e+" {
    try err(
        \\[9.e+]
    );
}

test "n_number_expression" {
    try err(
        \\[1+2]
    );
}

test "n_number_hex_1_digit" {
    try err(
        \\[0x1]
    );
}

test "n_number_hex_2_digits" {
    try err(
        \\[0x42]
    );
}

test "n_number_infinity" {
    try err(
        \\[Infinity]
    );
}

test "n_number_+Inf" {
    try err(
        \\[+Inf]
    );
}

test "n_number_Inf" {
    try err(
        \\[Inf]
    );
}

test "n_number_invalid+-" {
    try err(
        \\[0e+-1]
    );
}

test "n_number_invalid-negative-real" {
    try err(
        \\[-123.123foo]
    );
}

test "n_number_invalid-utf-8-in-bigger-int" {
    try err(
        \\[123å]
    );
}

test "n_number_invalid-utf-8-in-exponent" {
    try err(
        \\[1e1å]
    );
}

test "n_number_invalid-utf-8-in-int" {
    try err(
        \\[0å]
    );
}

test "n_number_++" {
    try err(
        \\[++1234]
    );
}

test "n_number_minus_infinity" {
    try err(
        \\[-Infinity]
    );
}

test "n_number_minus_sign_with_trailing_garbage" {
    try err(
        \\[-foo]
    );
}

test "n_number_minus_space_1" {
    try err(
        \\[- 1]
    );
}

test "n_number_-NaN" {
    try err(
        \\[-NaN]
    );
}

test "n_number_NaN" {
    try err(
        \\[NaN]
    );
}

test "n_number_neg_int_starting_with_zero" {
    try err(
        \\[-012]
    );
}

test "n_number_neg_real_without_int_part" {
    try err(
        \\[-.123]
    );
}

test "n_number_neg_with_garbage_at_end" {
    try err(
        \\[-1x]
    );
}

test "n_number_real_garbage_after_e" {
    try err(
        \\[1ea]
    );
}

test "n_number_real_with_invalid_utf8_after_e" {
    try err(
        \\[1eå]
    );
}

test "n_number_real_without_fractional_part" {
    try err(
        \\[1.]
    );
}

test "n_number_starting_with_dot" {
    try err(
        \\[.123]
    );
}

test "n_number_U+FF11_fullwidth_digit_one" {
    try err(
        \\[ï¼]
    );
}

test "n_number_with_alpha_char" {
    try err(
        \\[1.8011670033376514H-308]
    );
}

test "n_number_with_alpha" {
    try err(
        \\[1.2a-3]
    );
}

test "n_number_with_leading_zero" {
    try err(
        \\[012]
    );
}

test "n_object_bad_value" {
    try err(
        \\["x", truth]
    );
}

test "n_object_bracket_key" {
    try err(
        \\{[: "x"}
    );
}

test "n_object_comma_instead_of_colon" {
    try err(
        \\{"x", null}
    );
}

test "n_object_double_colon" {
    try err(
        \\{"x"::"b"}
    );
}

test "n_object_emoji" {
    try err(
        \\{ð¨ð­}
    );
}

test "n_object_garbage_at_end" {
    try err(
        \\{"a":"a" 123}
    );
}

test "n_object_key_with_single_quotes" {
    try err(
        \\{key: 'value'}
    );
}

test "n_object_lone_continuation_byte_in_key_and_trailing_comma" {
    try err(
        \\{"¹":"0",}
    );
}

test "n_object_missing_colon" {
    try err(
        \\{"a" b}
    );
}

test "n_object_missing_key" {
    try err(
        \\{:"b"}
    );
}

test "n_object_missing_semicolon" {
    try err(
        \\{"a" "b"}
    );
}

test "n_object_missing_value" {
    try err(
        \\{"a":
    );
}

test "n_object_no-colon" {
    try err(
        \\{"a"
    );
}

test "n_object_non_string_key_but_huge_number_instead" {
    try err(
        \\{9999E9999:1}
    );
}

test "n_object_non_string_key" {
    try err(
        \\{1:1}
    );
}

test "n_object_repeated_null_null" {
    try err(
        \\{null:null,null:null}
    );
}

test "n_object_several_trailing_commas" {
    try err(
        \\{"id":0,,,,,}
    );
}

test "n_object_single_quote" {
    try err(
        \\{'a':0}
    );
}

test "n_object_trailing_comma" {
    try err(
        \\{"id":0,}
    );
}

test "n_object_trailing_comment" {
    try err(
        \\{"a":"b"}/**/
    );
}

test "n_object_trailing_comment_open" {
    try err(
        \\{"a":"b"}/**//
    );
}

test "n_object_trailing_comment_slash_open_incomplete" {
    try err(
        \\{"a":"b"}/
    );
}

test "n_object_trailing_comment_slash_open" {
    try err(
        \\{"a":"b"}//
    );
}

test "n_object_two_commas_in_a_row" {
    try err(
        \\{"a":"b",,"c":"d"}
    );
}

test "n_object_unquoted_key" {
    try err(
        \\{a: "b"}
    );
}

test "n_object_unterminated-value" {
    try err(
        \\{"a":"a
    );
}

test "n_object_with_single_string" {
    try err(
        \\{ "foo" : "bar", "a" }
    );
}

test "n_object_with_trailing_garbage" {
    try err(
        \\{"a":"b"}#
    );
}

test "n_single_space" {
    try err(" ");
}

test "n_string_1_surrogate_then_escape" {
    try err(
        \\["\uD800\"]
    );
}

test "n_string_1_surrogate_then_escape_u1" {
    try err(
        \\["\uD800\u1"]
    );
}

test "n_string_1_surrogate_then_escape_u1x" {
    try err(
        \\["\uD800\u1x"]
    );
}

test "n_string_1_surrogate_then_escape_u" {
    try err(
        \\["\uD800\u"]
    );
}

test "n_string_accentuated_char_no_quotes" {
    try err(
        \\[Ã©]
    );
}

test "n_string_backslash_00" {
    try err("[\"\x00\"]");
}

test "n_string_escaped_backslash_bad" {
    try err(
        \\["\\\"]
    );
}

test "n_string_escaped_ctrl_char_tab" {
    try err("\x5b\x22\x5c\x09\x22\x5d");
}

test "n_string_escaped_emoji" {
    try err("[\"\x5c\xc3\xb0\xc2\x9f\xc2\x8c\xc2\x80\"]");
}

test "n_string_escape_x" {
    try err(
        \\["\x00"]
    );
}

test "n_string_incomplete_escaped_character" {
    try err(
        \\["\u00A"]
    );
}

test "n_string_incomplete_escape" {
    try err(
        \\["\"]
    );
}

test "n_string_incomplete_surrogate_escape_invalid" {
    try err(
        \\["\uD800\uD800\x"]
    );
}

test "n_string_incomplete_surrogate" {
    try err(
        \\["\uD834\uDd"]
    );
}

test "n_string_invalid_backslash_esc" {
    try err(
        \\["\a"]
    );
}

test "n_string_invalid_unicode_escape" {
    try err(
        \\["\uqqqq"]
    );
}

test "n_string_invalid_utf8_after_escape" {
    try err("[\"\\\x75\xc3\xa5\"]");
}

test "n_string_invalid-utf-8-in-escape" {
    try err(
        \\["\uå"]
    );
}

test "n_string_leading_uescaped_thinspace" {
    try err(
        \\[\u0020"asd"]
    );
}

test "n_string_no_quotes_with_bad_escape" {
    try err(
        \\[\n]
    );
}

test "n_string_single_doublequote" {
    try err(
        \\"
    );
}

test "n_string_single_quote" {
    try err(
        \\['single quote']
    );
}

test "n_string_single_string_no_double_quotes" {
    try err(
        \\abc
    );
}

test "n_string_start_escape_unclosed" {
    try err(
        \\["\
    );
}

test "n_string_unescaped_crtl_char" {
    try err("[\"a\x00a\"]");
}

test "n_string_unescaped_newline" {
    try err(
        \\["new
        \\line"]
    );
}

test "n_string_unescaped_tab" {
    try err("[\"\t\"]");
}

test "n_string_unicode_CapitalU" {
    try err(
        \\"\UA66D"
    );
}

test "n_string_with_trailing_garbage" {
    try err(
        \\""x
    );
}

test "n_structure_100000_opening_arrays" {
    try err("[" ** 100000);
}

test "n_structure_angle_bracket_." {
    try err(
        \\<.>
    );
}

test "n_structure_angle_bracket_null" {
    try err(
        \\[<null>]
    );
}

test "n_structure_array_trailing_garbage" {
    try err(
        \\[1]x
    );
}

test "n_structure_array_with_extra_array_close" {
    try err(
        \\[1]]
    );
}

test "n_structure_array_with_unclosed_string" {
    try err(
        \\["asd]
    );
}

test "n_structure_ascii-unicode-identifier" {
    try err(
        \\aÃ¥
    );
}

test "n_structure_capitalized_True" {
    try err(
        \\[True]
    );
}

test "n_structure_close_unopened_array" {
    try err(
        \\1]
    );
}

test "n_structure_comma_instead_of_closing_brace" {
    try err(
        \\{"x": true,
    );
}

test "n_structure_double_array" {
    try err(
        \\[][]
    );
}

test "n_structure_end_array" {
    try err(
        \\]
    );
}

test "n_structure_incomplete_UTF8_BOM" {
    try err(
        \\ï»{}
    );
}

test "n_structure_lone-invalid-utf-8" {
    try err(
        \\å
    );
}

test "n_structure_lone-open-bracket" {
    try err(
        \\[
    );
}

test "n_structure_no_data" {
    try err(
        \\
    );
}

test "n_structure_null-byte-outside-string" {
    try err("[\x00]");
}

test "n_structure_number_with_trailing_garbage" {
    try err(
        \\2@
    );
}

test "n_structure_object_followed_by_closing_object" {
    try err(
        \\{}}
    );
}

test "n_structure_object_unclosed_no_value" {
    try err(
        \\{"":
    );
}

test "n_structure_object_with_comment" {
    try err(
        \\{"a":/*comment*/"b"}
    );
}

test "n_structure_object_with_trailing_garbage" {
    try err(
        \\{"a": true} "x"
    );
}

test "n_structure_open_array_apostrophe" {
    try err(
        \\['
    );
}

test "n_structure_open_array_comma" {
    try err(
        \\[,
    );
}

test "n_structure_open_array_object" {
    try err("[{\"\":" ** 50000);
}

test "n_structure_open_array_open_object" {
    try err(
        \\[{
    );
}

test "n_structure_open_array_open_string" {
    try err(
        \\["a
    );
}

test "n_structure_open_array_string" {
    try err(
        \\["a"
    );
}

test "n_structure_open_object_close_array" {
    try err(
        \\{]
    );
}

test "n_structure_open_object_comma" {
    try err(
        \\{,
    );
}

test "n_structure_open_object" {
    try err(
        \\{
    );
}

test "n_structure_open_object_open_array" {
    try err(
        \\{[
    );
}

test "n_structure_open_object_open_string" {
    try err(
        \\{"a
    );
}

test "n_structure_open_object_string_with_apostrophes" {
    try err(
        \\{'a'
    );
}

test "n_structure_open_open" {
    try err(
        \\["\{["\{["\{["\{
    );
}

test "n_structure_single_eacute" {
    try err(
        \\é
    );
}

test "n_structure_single_star" {
    try err(
        \\*
    );
}

test "n_structure_trailing_#" {
    try err(
        \\{"a":"b"}#{}
    );
}

test "n_structure_U+2060_word_joined" {
    try err(
        \\[â ]
    );
}

test "n_structure_uescaped_LF_before_string" {
    try err(
        \\[\u000A""]
    );
}

test "n_structure_unclosed_array" {
    try err(
        \\[1
    );
}

test "n_structure_unclosed_array_partial_null" {
    try err(
        \\[ false, nul
    );
}

test "n_structure_unclosed_array_unfinished_false" {
    try err(
        \\[ true, fals
    );
}

test "n_structure_unclosed_array_unfinished_true" {
    try err(
        \\[ false, tru
    );
}

test "n_structure_unclosed_object" {
    try err(
        \\{"asd":"asd"
    );
}

test "n_structure_unicode-identifier" {
    try err(
        \\Ã¥
    );
}

test "n_structure_UTF8_BOM_no_data" {
    try err(
        \\ï»¿
    );
}

test "n_structure_whitespace_formfeed" {
    try err("[\x0c]");
}

test "n_structure_whitespace_U+2060_word_joiner" {
    try err(
        \\[â ]
    );
}

////////////////////////////////////////////////////////////////////////////////////////////////////

test "i_number_double_huge_neg_exp" {
    try any(
        \\[123.456e-789]
    );
}

test "i_number_huge_exp" {
    try any(
        \\[0.4e00669999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999969999999006]
    );
}

test "i_number_neg_int_huge_exp" {
    try any(
        \\[-1e+9999]
    );
}

test "i_number_pos_double_huge_exp" {
    try any(
        \\[1.5e+9999]
    );
}

test "i_number_real_neg_overflow" {
    try any(
        \\[-123123e100000]
    );
}

test "i_number_real_pos_overflow" {
    try any(
        \\[123123e100000]
    );
}

test "i_number_real_underflow" {
    try any(
        \\[123e-10000000]
    );
}

test "i_number_too_big_neg_int" {
    try any(
        \\[-123123123123123123123123123123]
    );
}

test "i_number_too_big_pos_int" {
    try any(
        \\[100000000000000000000]
    );
}

test "i_number_very_big_negative_int" {
    try any(
        \\[-237462374673276894279832749832423479823246327846]
    );
}

test "i_object_key_lone_2nd_surrogate" {
    try anyStreamingErrNonStreaming(
        \\{"\uDFAA":0}
    );
}

test "i_string_1st_surrogate_but_2nd_missing" {
    try anyStreamingErrNonStreaming(
        \\["\uDADA"]
    );
}

test "i_string_1st_valid_surrogate_2nd_invalid" {
    try anyStreamingErrNonStreaming(
        \\["\uD888\u1234"]
    );
}

test "i_string_incomplete_surrogate_and_escape_valid" {
    try anyStreamingErrNonStreaming(
        \\["\uD800\n"]
    );
}

test "i_string_incomplete_surrogate_pair" {
    try anyStreamingErrNonStreaming(
        \\["\uDd1ea"]
    );
}

test "i_string_incomplete_surrogates_escape_valid" {
    try anyStreamingErrNonStreaming(
        \\["\uD800\uD800\n"]
    );
}

test "i_string_invalid_lonely_surrogate" {
    try anyStreamingErrNonStreaming(
        \\["\ud800"]
    );
}

test "i_string_invalid_surrogate" {
    try anyStreamingErrNonStreaming(
        \\["\ud800abc"]
    );
}

test "i_string_invalid_utf-8" {
    try any(
        \\["ÿ"]
    );
}

test "i_string_inverted_surrogates_U+1D11E" {
    try anyStreamingErrNonStreaming(
        \\["\uDd1e\uD834"]
    );
}

test "i_string_iso_latin_1" {
    try any(
        \\["é"]
    );
}

test "i_string_lone_second_surrogate" {
    try anyStreamingErrNonStreaming(
        \\["\uDFAA"]
    );
}

test "i_string_lone_utf8_continuation_byte" {
    try any(
        \\[""]
    );
}

test "i_string_not_in_unicode_range" {
    try any(
        \\["ô¿¿¿"]
    );
}

test "i_string_overlong_sequence_2_bytes" {
    try any(
        \\["À¯"]
    );
}

test "i_string_overlong_sequence_6_bytes" {
    try any(
        \\["ü¿¿¿¿"]
    );
}

test "i_string_overlong_sequence_6_bytes_null" {
    try any(
        \\["ü"]
    );
}

test "i_string_truncated-utf-8" {
    try any(
        \\["àÿ"]
    );
}

test "i_string_utf16BE_no_BOM" {
    try any("\x00\x5b\x00\x22\x00\xc3\xa9\x00\x22\x00\x5d");
}

test "i_string_utf16LE_no_BOM" {
    try any("\x5b\x00\x22\x00\xc3\xa9\x00\x22\x00\x5d\x00");
}

test "i_string_UTF-16LE_with_BOM" {
    try any("\xc3\xbf\xc3\xbe\x5b\x00\x22\x00\xc3\xa9\x00\x22\x00\x5d\x00");
}

test "i_string_UTF-8_invalid_sequence" {
    try any(
        \\["æ¥Ñú"]
    );
}

test "i_string_UTF8_surrogate_U+D800" {
    try any(
        \\["í "]
    );
}

test "i_structure_500_nested_arrays" {
    try any(("[" ** 500) ++ ("]" ** 500));
}

test "i_structure_UTF-8_BOM_empty_object" {
    try any(
        \\ï»¿{}
    );
}

test "truncated UTF-8 sequence" {
    try utf8Error("\"\xc2\"");
    try utf8Error("\"\xdf\"");
    try utf8Error("\"\xed\xa0\"");
    try utf8Error("\"\xf0\x80\"");
    try utf8Error("\"\xf0\x80\x80\"");
}

test "invalid continuation byte" {
    try utf8Error("\"\xc2\x00\"");
    try utf8Error("\"\xc2\x7f\"");
    try utf8Error("\"\xc2\xc0\"");
    try utf8Error("\"\xc3\xc1\"");
    try utf8Error("\"\xc4\xf5\"");
    try utf8Error("\"\xc5\xff\"");
    try utf8Error("\"\xe4\x80\x00\"");
    try utf8Error("\"\xe5\x80\x10\"");
    try utf8Error("\"\xe6\x80\xc0\"");
    try utf8Error("\"\xe7\x80\xf5\"");
    try utf8Error("\"\xe8\x00\x80\"");
    try utf8Error("\"\xf2\x00\x80\x80\"");
    try utf8Error("\"\xf0\x80\x00\x80\"");
    try utf8Error("\"\xf1\x80\xc0\x80\"");
    try utf8Error("\"\xf2\x80\x80\x00\"");
    try utf8Error("\"\xf3\x80\x80\xc0\"");
    try utf8Error("\"\xf4\x80\x80\xf5\"");
}

test "disallowed overlong form" {
    try utf8Error("\"\xc0\x80\"");
    try utf8Error("\"\xc0\x90\"");
    try utf8Error("\"\xc1\x80\"");
    try utf8Error("\"\xc1\x90\"");
    try utf8Error("\"\xe0\x80\x80\"");
    try utf8Error("\"\xf0\x80\x80\x80\"");
}

test "out of UTF-16 range" {
    try utf8Error("\"\xf4\x90\x80\x80\"");
    try utf8Error("\"\xf5\x80\x80\x80\"");
    try utf8Error("\"\xf6\x80\x80\x80\"");
    try utf8Error("\"\xf7\x80\x80\x80\"");
    try utf8Error("\"\xf8\x80\x80\x80\"");
    try utf8Error("\"\xf9\x80\x80\x80\"");
    try utf8Error("\"\xfa\x80\x80\x80\"");
    try utf8Error("\"\xfb\x80\x80\x80\"");
    try utf8Error("\"\xfc\x80\x80\x80\"");
    try utf8Error("\"\xfd\x80\x80\x80\"");
    try utf8Error("\"\xfe\x80\x80\x80\"");
    try utf8Error("\"\xff\x80\x80\x80\"");
}

test "parse" {
    var ts = TokenStream.init("false");
    try testing.expectEqual(false, try parse(bool, &ts, ParseOptions{}));
    ts = TokenStream.init("true");
    try testing.expectEqual(true, try parse(bool, &ts, ParseOptions{}));
    ts = TokenStream.init("1");
    try testing.expectEqual(@as(u1, 1), try parse(u1, &ts, ParseOptions{}));
    ts = TokenStream.init("50");
    try testing.expectError(error.Overflow, parse(u1, &ts, ParseOptions{}));
    ts = TokenStream.init("42");
    try testing.expectEqual(@as(u64, 42), try parse(u64, &ts, ParseOptions{}));
    ts = TokenStream.init("42.0");
    try testing.expectEqual(@as(f64, 42), try parse(f64, &ts, ParseOptions{}));
    ts = TokenStream.init("null");
    try testing.expectEqual(@as(?bool, null), try parse(?bool, &ts, ParseOptions{}));
    ts = TokenStream.init("true");
    try testing.expectEqual(@as(?bool, true), try parse(?bool, &ts, ParseOptions{}));

    ts = TokenStream.init("\"foo\"");
    try testing.expectEqual(@as([3]u8, "foo".*), try parse([3]u8, &ts, ParseOptions{}));
    ts = TokenStream.init("[102, 111, 111]");
    try testing.expectEqual(@as([3]u8, "foo".*), try parse([3]u8, &ts, ParseOptions{}));
    ts = TokenStream.init("[]");
    try testing.expectEqual(@as([0]u8, undefined), try parse([0]u8, &ts, ParseOptions{}));

    ts = TokenStream.init("\"12345678901234567890\"");
    try testing.expectEqual(@as(u64, 12345678901234567890), try parse(u64, &ts, ParseOptions{}));
    ts = TokenStream.init("\"123.456\"");
    try testing.expectEqual(@as(f64, 123.456), try parse(f64, &ts, ParseOptions{}));
}

test "parse into enum" {
    const T = enum(u32) {
        Foo = 42,
        Bar,
        @"with\\escape",
    };
    var ts = TokenStream.init("\"Foo\"");
    try testing.expectEqual(@as(T, .Foo), try parse(T, &ts, ParseOptions{}));
    ts = TokenStream.init("42");
    try testing.expectEqual(@as(T, .Foo), try parse(T, &ts, ParseOptions{}));
    ts = TokenStream.init("\"with\\\\escape\"");
    try testing.expectEqual(@as(T, .@"with\\escape"), try parse(T, &ts, ParseOptions{}));
    ts = TokenStream.init("5");
    try testing.expectError(error.InvalidEnumTag, parse(T, &ts, ParseOptions{}));
    ts = TokenStream.init("\"Qux\"");
    try testing.expectError(error.InvalidEnumTag, parse(T, &ts, ParseOptions{}));
}

test "parse with trailing data" {
    var ts = TokenStream.init("falsed");
    try testing.expectEqual(false, try parse(bool, &ts, ParseOptions{ .allow_trailing_data = true }));
    ts = TokenStream.init("falsed");
    try testing.expectError(error.InvalidTopLevelTrailing, parse(bool, &ts, ParseOptions{ .allow_trailing_data = false }));
    // trailing whitespace is okay
    ts = TokenStream.init("false \n");
    try testing.expectEqual(false, try parse(bool, &ts, ParseOptions{ .allow_trailing_data = false }));
}

test "parse into that allocates a slice" {
    var ts = TokenStream.init("\"foo\"");
    try testing.expectError(error.AllocatorRequired, parse([]u8, &ts, ParseOptions{}));

    const options = ParseOptions{ .allocator = testing.allocator };
    {
        ts = TokenStream.init("\"foo\"");
        const r = try parse([]u8, &ts, options);
        defer parseFree([]u8, r, options);
        try testing.expectEqualSlices(u8, "foo", r);
    }
    {
        ts = TokenStream.init("[102, 111, 111]");
        const r = try parse([]u8, &ts, options);
        defer parseFree([]u8, r, options);
        try testing.expectEqualSlices(u8, "foo", r);
    }
    {
        ts = TokenStream.init("\"with\\\\escape\"");
        const r = try parse([]u8, &ts, options);
        defer parseFree([]u8, r, options);
        try testing.expectEqualSlices(u8, "with\\escape", r);
    }
}

test "parse into tagged union" {
    {
        const T = union(enum) {
            int: i32,
            float: f64,
            string: []const u8,
        };
        var ts = TokenStream.init("1.5");
        try testing.expectEqual(T{ .float = 1.5 }, try parse(T, &ts, ParseOptions{}));
    }

    { // failing allocations should be bubbled up instantly without trying next member
        var fail_alloc = testing.FailingAllocator.init(testing.allocator, 0);
        const options = ParseOptions{ .allocator = fail_alloc.allocator() };
        const T = union(enum) {
            // both fields here match the input
            string: []const u8,
            array: [3]u8,
        };
        var ts = TokenStream.init("[1,2,3]");
        try testing.expectError(error.OutOfMemory, parse(T, &ts, options));
    }

    {
        // if multiple matches possible, takes first option
        const T = union(enum) {
            x: u8,
            y: u8,
        };
        var ts = TokenStream.init("42");
        try testing.expectEqual(T{ .x = 42 }, try parse(T, &ts, ParseOptions{}));
    }

    { // needs to back out when first union member doesn't match
        const T = union(enum) {
            A: struct { x: u32 },
            B: struct { y: u32 },
        };
        var ts = TokenStream.init("{\"y\":42}");
        try testing.expectEqual(T{ .B = .{ .y = 42 } }, try parse(T, &ts, ParseOptions{}));
    }
}

test "parse union bubbles up AllocatorRequired" {
    { // string member first in union (and not matching)
        const T = union(enum) {
            string: []const u8,
            int: i32,
        };
        var ts = TokenStream.init("42");
        try testing.expectError(error.AllocatorRequired, parse(T, &ts, ParseOptions{}));
    }

    { // string member not first in union (and matching)
        const T = union(enum) {
            int: i32,
            float: f64,
            string: []const u8,
        };
        var ts = TokenStream.init("\"foo\"");
        try testing.expectError(error.AllocatorRequired, parse(T, &ts, ParseOptions{}));
    }
}

test "parseFree descends into tagged union" {
    var fail_alloc = testing.FailingAllocator.init(testing.allocator, 1);
    const options = ParseOptions{ .allocator = fail_alloc.allocator() };
    const T = union(enum) {
        int: i32,
        float: f64,
        string: []const u8,
    };
    // use a string with unicode escape so we know result can't be a reference to global constant
    var ts = TokenStream.init("\"with\\u0105unicode\"");
    const r = try parse(T, &ts, options);
    try testing.expectEqual(std.meta.Tag(T).string, @as(std.meta.Tag(T), r));
    try testing.expectEqualSlices(u8, "withąunicode", r.string);
    try testing.expectEqual(@as(usize, 0), fail_alloc.deallocations);
    parseFree(T, r, options);
    try testing.expectEqual(@as(usize, 1), fail_alloc.deallocations);
}

test "parse with comptime field" {
    {
        const T = struct {
            comptime a: i32 = 0,
            b: bool,
        };
        var ts = TokenStream.init(
            \\{
            \\  "a": 0,
            \\  "b": true
            \\}
        );
        try testing.expectEqual(T{ .a = 0, .b = true }, try parse(T, &ts, ParseOptions{}));
    }

    { // string comptime values currently require an allocator
        const T = union(enum) {
            foo: struct {
                comptime kind: []const u8 = "boolean",
                b: bool,
            },
            bar: struct {
                comptime kind: []const u8 = "float",
                b: f64,
            },
        };

        const options = ParseOptions{
            .allocator = std.testing.allocator,
        };

        var ts = TokenStream.init(
            \\{
            \\  "kind": "float",
            \\  "b": 1.0
            \\}
        );
        const r = try parse(T, &ts, options);

        // check that parseFree doesn't try to free comptime fields
        parseFree(T, r, options);
    }
}

test "parse into struct with no fields" {
    const T = struct {};
    var ts = TokenStream.init("{}");
    try testing.expectEqual(T{}, try parse(T, &ts, ParseOptions{}));
}

const test_const_value: usize = 123;

test "parse into struct with default const pointer field" {
    const T = struct { a: *const usize = &test_const_value };
    var ts = TokenStream.init("{}");
    try testing.expectEqual(T{}, try parse(T, &ts, .{}));
}

const test_default_usize: usize = 123;
const test_default_usize_ptr: *align(1) const usize = &test_default_usize;
const test_default_str: []const u8 = "test str";
const test_default_str_slice: [2][]const u8 = [_][]const u8{
    "test1",
    "test2",
};

test "freeing parsed structs with pointers to default values" {
    const T = struct {
        int: *const usize = &test_default_usize,
        int_ptr: *allowzero align(1) const usize = test_default_usize_ptr,
        str: []const u8 = test_default_str,
        str_slice: []const []const u8 = &test_default_str_slice,
    };

    var ts = json.TokenStream.init("{}");
    const options = .{ .allocator = std.heap.page_allocator };
    const parsed = try json.parse(T, &ts, options);

    try testing.expectEqual(T{}, parsed);

    json.parseFree(T, parsed, options);
}

test "parse into struct where destination and source lengths mismatch" {
    const T = struct { a: [2]u8 };
    var ts = TokenStream.init("{\"a\": \"bbb\"}");
    try testing.expectError(error.LengthMismatch, parse(T, &ts, ParseOptions{}));
}

test "parse into struct with misc fields" {
    @setEvalBranchQuota(10000);
    const options = ParseOptions{ .allocator = testing.allocator };
    const T = struct {
        int: i64,
        float: f64,
        @"with\\escape": bool,
        @"withąunicode😂": bool,
        language: []const u8,
        optional: ?bool,
        default_field: i32 = 42,
        static_array: [3]f64,
        dynamic_array: []f64,

        complex: struct {
            nested: []const u8,
        },

        veryComplex: []struct {
            foo: []const u8,
        },

        a_union: Union,
        const Union = union(enum) {
            x: u8,
            float: f64,
            string: []const u8,
        };
    };
    var ts = TokenStream.init(
        \\{
        \\  "int": 420,
        \\  "float": 3.14,
        \\  "with\\escape": true,
        \\  "with\u0105unicode\ud83d\ude02": false,
        \\  "language": "zig",
        \\  "optional": null,
        \\  "static_array": [66.6, 420.420, 69.69],
        \\  "dynamic_array": [66.6, 420.420, 69.69],
        \\  "complex": {
        \\    "nested": "zig"
        \\  },
        \\  "veryComplex": [
        \\    {
        \\      "foo": "zig"
        \\    }, {
        \\      "foo": "rocks"
        \\    }
        \\  ],
        \\  "a_union": 100000
        \\}
    );
    const r = try parse(T, &ts, options);
    defer parseFree(T, r, options);
    try testing.expectEqual(@as(i64, 420), r.int);
    try testing.expectEqual(@as(f64, 3.14), r.float);
    try testing.expectEqual(true, r.@"with\\escape");
    try testing.expectEqual(false, r.@"withąunicode😂");
    try testing.expectEqualSlices(u8, "zig", r.language);
    try testing.expectEqual(@as(?bool, null), r.optional);
    try testing.expectEqual(@as(i32, 42), r.default_field);
    try testing.expectEqual(@as(f64, 66.6), r.static_array[0]);
    try testing.expectEqual(@as(f64, 420.420), r.static_array[1]);
    try testing.expectEqual(@as(f64, 69.69), r.static_array[2]);
    try testing.expectEqual(@as(usize, 3), r.dynamic_array.len);
    try testing.expectEqual(@as(f64, 66.6), r.dynamic_array[0]);
    try testing.expectEqual(@as(f64, 420.420), r.dynamic_array[1]);
    try testing.expectEqual(@as(f64, 69.69), r.dynamic_array[2]);
    try testing.expectEqualSlices(u8, r.complex.nested, "zig");
    try testing.expectEqualSlices(u8, "zig", r.veryComplex[0].foo);
    try testing.expectEqualSlices(u8, "rocks", r.veryComplex[1].foo);
    try testing.expectEqual(T.Union{ .float = 100000 }, r.a_union);
}

test "parse into struct with strings and arrays with sentinels" {
    @setEvalBranchQuota(10000);
    const options = ParseOptions{ .allocator = testing.allocator };
    const T = struct {
        language: [:0]const u8,
        language_without_sentinel: []const u8,
        data: [:99]const i32,
        simple_data: []const i32,
    };
    var ts = TokenStream.init(
        \\{
        \\  "language": "zig",
        \\  "language_without_sentinel": "zig again!",
        \\  "data": [1, 2, 3],
        \\  "simple_data": [4, 5, 6]
        \\}
    );
    const r = try parse(T, &ts, options);
    defer parseFree(T, r, options);

    try testing.expectEqualSentinel(u8, 0, "zig", r.language);

    const data = [_:99]i32{ 1, 2, 3 };
    try testing.expectEqualSentinel(i32, 99, data[0..data.len], r.data);

    // Make sure that arrays who aren't supposed to have a sentinel still parse without one.
    try testing.expectEqual(@as(?i32, null), std.meta.sentinel(@TypeOf(r.simple_data)));
    try testing.expectEqual(@as(?u8, null), std.meta.sentinel(@TypeOf(r.language_without_sentinel)));
}

test "parse into struct with duplicate field" {
    // allow allocator to detect double frees by keeping bucket in use
    const ballast = try testing.allocator.alloc(u64, 1);
    defer testing.allocator.free(ballast);

    const options_first = ParseOptions{ .allocator = testing.allocator, .duplicate_field_behavior = .UseFirst };

    const options_last = ParseOptions{
        .allocator = testing.allocator,
        .duplicate_field_behavior = .UseLast,
    };

    const str = "{ \"a\": 1, \"a\": 0.25 }";

    const T1 = struct { a: *u64 };
    // both .UseFirst and .UseLast should fail because second "a" value isn't a u64
    var ts = TokenStream.init(str);
    try testing.expectError(error.InvalidNumber, parse(T1, &ts, options_first));
    ts = TokenStream.init(str);
    try testing.expectError(error.InvalidNumber, parse(T1, &ts, options_last));

    const T2 = struct { a: f64 };
    ts = TokenStream.init(str);
    try testing.expectEqual(T2{ .a = 1.0 }, try parse(T2, &ts, options_first));
    ts = TokenStream.init(str);
    try testing.expectEqual(T2{ .a = 0.25 }, try parse(T2, &ts, options_last));

    const T3 = struct { comptime a: f64 = 1.0 };
    // .UseFirst should succeed because second "a" value is unconditionally ignored (even though != 1.0)
    const t3 = T3{ .a = 1.0 };
    ts = TokenStream.init(str);
    try testing.expectEqual(t3, try parse(T3, &ts, options_first));
    // .UseLast should fail because second "a" value is 0.25 which is not equal to default value of 1.0
    ts = TokenStream.init(str);
    try testing.expectError(error.UnexpectedValue, parse(T3, &ts, options_last));
}

test "parse into struct ignoring unknown fields" {
    const T = struct {
        int: i64,
        language: []const u8,
    };

    const ops = ParseOptions{
        .allocator = testing.allocator,
        .ignore_unknown_fields = true,
    };

    var ts = TokenStream.init(
        \\{
        \\  "int": 420,
        \\  "float": 3.14,
        \\  "with\\escape": true,
        \\  "with\u0105unicode\ud83d\ude02": false,
        \\  "optional": null,
        \\  "static_array": [66.6, 420.420, 69.69],
        \\  "dynamic_array": [66.6, 420.420, 69.69],
        \\  "complex": {
        \\    "nested": "zig"
        \\  },
        \\  "veryComplex": [
        \\    {
        \\      "foo": "zig"
        \\    }, {
        \\      "foo": "rocks"
        \\    }
        \\  ],
        \\  "a_union": 100000,
        \\  "language": "zig"
        \\}
    );
    const r = try parse(T, &ts, ops);
    defer parseFree(T, r, ops);

    try testing.expectEqual(@as(i64, 420), r.int);
    try testing.expectEqualSlices(u8, "zig", r.language);
}

const ParseIntoRecursiveUnionDefinitionValue = union(enum) {
    integer: i64,
    array: []const ParseIntoRecursiveUnionDefinitionValue,
};

test "parse into recursive union definition" {
    const T = struct {
        values: ParseIntoRecursiveUnionDefinitionValue,
    };
    const ops = ParseOptions{ .allocator = testing.allocator };

    var ts = TokenStream.init("{\"values\":[58]}");
    const r = try parse(T, &ts, ops);
    defer parseFree(T, r, ops);

    try testing.expectEqual(@as(i64, 58), r.values.array[0].integer);
}

const ParseIntoDoubleRecursiveUnionValueFirst = union(enum) {
    integer: i64,
    array: []const ParseIntoDoubleRecursiveUnionValueSecond,
};

const ParseIntoDoubleRecursiveUnionValueSecond = union(enum) {
    boolean: bool,
    array: []const ParseIntoDoubleRecursiveUnionValueFirst,
};

test "parse into double recursive union definition" {
    const T = struct {
        values: ParseIntoDoubleRecursiveUnionValueFirst,
    };
    const ops = ParseOptions{ .allocator = testing.allocator };

    var ts = TokenStream.init("{\"values\":[[58]]}");
    const r = try parse(T, &ts, ops);
    defer parseFree(T, r, ops);

    try testing.expectEqual(@as(i64, 58), r.values.array[0].array[0].integer);
}

test "json.parser.dynamic" {
    var p = Parser.init(testing.allocator, false);
    defer p.deinit();

    const s =
        \\{
        \\  "Image": {
        \\      "Width":  800,
        \\      "Height": 600,
        \\      "Title":  "View from 15th Floor",
        \\      "Thumbnail": {
        \\          "Url":    "http://www.example.com/image/481989943",
        \\          "Height": 125,
        \\          "Width":  100
        \\      },
        \\      "Animated" : false,
        \\      "IDs": [116, 943, 234, 38793],
        \\      "ArrayOfObject": [{"n": "m"}],
        \\      "double": 1.3412,
        \\      "LargeInt": 18446744073709551615
        \\    }
        \\}
    ;

    var tree = try p.parse(s);
    defer tree.deinit();

    var root = tree.root;

    var image = root.Object.get("Image").?;

    const width = image.Object.get("Width").?;
    try testing.expect(width.Integer == 800);

    const height = image.Object.get("Height").?;
    try testing.expect(height.Integer == 600);

    const title = image.Object.get("Title").?;
    try testing.expect(mem.eql(u8, title.String, "View from 15th Floor"));

    const animated = image.Object.get("Animated").?;
    try testing.expect(animated.Bool == false);

    const array_of_object = image.Object.get("ArrayOfObject").?;
    try testing.expect(array_of_object.Array.items.len == 1);

    const obj0 = array_of_object.Array.items[0].Object.get("n").?;
    try testing.expect(mem.eql(u8, obj0.String, "m"));

    const double = image.Object.get("double").?;
    try testing.expect(double.Float == 1.3412);

    const large_int = image.Object.get("LargeInt").?;
    try testing.expect(mem.eql(u8, large_int.NumberString, "18446744073709551615"));
}

test "write json then parse it" {
    var out_buffer: [1000]u8 = undefined;

    var fixed_buffer_stream = std.io.fixedBufferStream(&out_buffer);
    const out_stream = fixed_buffer_stream.writer();
    var jw = writeStream(out_stream, 4);

    try jw.beginObject();

    try jw.objectField("f");
    try jw.emitBool(false);

    try jw.objectField("t");
    try jw.emitBool(true);

    try jw.objectField("int");
    try jw.emitNumber(1234);

    try jw.objectField("array");
    try jw.beginArray();

    try jw.arrayElem();
    try jw.emitNull();

    try jw.arrayElem();
    try jw.emitNumber(12.34);

    try jw.endArray();

    try jw.objectField("str");
    try jw.emitString("hello");

    try jw.endObject();

    var parser = Parser.init(testing.allocator, false);
    defer parser.deinit();
    var tree = try parser.parse(fixed_buffer_stream.getWritten());
    defer tree.deinit();

    try testing.expect(tree.root.Object.get("f").?.Bool == false);
    try testing.expect(tree.root.Object.get("t").?.Bool == true);
    try testing.expect(tree.root.Object.get("int").?.Integer == 1234);
    try testing.expect(tree.root.Object.get("array").?.Array.items[0].Null == {});
    try testing.expect(tree.root.Object.get("array").?.Array.items[1].Float == 12.34);
    try testing.expect(mem.eql(u8, tree.root.Object.get("str").?.String, "hello"));
}

fn testParse(arena_allocator: std.mem.Allocator, json_str: []const u8) !Value {
    var p = Parser.init(arena_allocator, false);
    return (try p.parse(json_str)).root;
}

test "parsing empty string gives appropriate error" {
    var arena_allocator = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena_allocator.deinit();
    try testing.expectError(error.UnexpectedEndOfJson, testParse(arena_allocator.allocator(), ""));
}

test "parse tree should not contain dangling pointers" {
    var arena_allocator = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena_allocator.deinit();

    var p = json.Parser.init(arena_allocator.allocator(), false);
    defer p.deinit();

    var tree = try p.parse("[]");
    defer tree.deinit();

    // Allocation should succeed
    var i: usize = 0;
    while (i < 100) : (i += 1) {
        try tree.root.Array.append(std.json.Value{ .Integer = 100 });
    }
    try testing.expectEqual(tree.root.Array.items.len, 100);
}

test "integer after float has proper type" {
    var arena_allocator = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena_allocator.deinit();
    const parsed = try testParse(arena_allocator.allocator(),
        \\{
        \\  "float": 3.14,
        \\  "ints": [1, 2, 3]
        \\}
    );
    try std.testing.expect(parsed.Object.get("ints").?.Array.items[0] == .Integer);
}

test "parse exponential into int" {
    const T = struct { int: i64 };
    var ts = TokenStream.init("{ \"int\": 4.2e2 }");
    const r = try parse(T, &ts, ParseOptions{});
    try testing.expectEqual(@as(i64, 420), r.int);
    ts = TokenStream.init("{ \"int\": 0.042e2 }");
    try testing.expectError(error.InvalidNumber, parse(T, &ts, ParseOptions{}));
    ts = TokenStream.init("{ \"int\": 18446744073709551616.0 }");
    try testing.expectError(error.Overflow, parse(T, &ts, ParseOptions{}));
}

test "escaped characters" {
    var arena_allocator = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena_allocator.deinit();
    const input =
        \\{
        \\  "backslash": "\\",
        \\  "forwardslash": "\/",
        \\  "newline": "\n",
        \\  "carriagereturn": "\r",
        \\  "tab": "\t",
        \\  "formfeed": "\f",
        \\  "backspace": "\b",
        \\  "doublequote": "\"",
        \\  "unicode": "\u0105",
        \\  "surrogatepair": "\ud83d\ude02"
        \\}
    ;

    const obj = (try testParse(arena_allocator.allocator(), input)).Object;

    try testing.expectEqualSlices(u8, obj.get("backslash").?.String, "\\");
    try testing.expectEqualSlices(u8, obj.get("forwardslash").?.String, "/");
    try testing.expectEqualSlices(u8, obj.get("newline").?.String, "\n");
    try testing.expectEqualSlices(u8, obj.get("carriagereturn").?.String, "\r");
    try testing.expectEqualSlices(u8, obj.get("tab").?.String, "\t");
    try testing.expectEqualSlices(u8, obj.get("formfeed").?.String, "\x0C");
    try testing.expectEqualSlices(u8, obj.get("backspace").?.String, "\x08");
    try testing.expectEqualSlices(u8, obj.get("doublequote").?.String, "\"");
    try testing.expectEqualSlices(u8, obj.get("unicode").?.String, "ą");
    try testing.expectEqualSlices(u8, obj.get("surrogatepair").?.String, "😂");
}

test "string copy option" {
    const input =
        \\{
        \\  "noescape": "aą😂",
        \\  "simple": "\\\/\n\r\t\f\b\"",
        \\  "unicode": "\u0105",
        \\  "surrogatepair": "\ud83d\ude02"
        \\}
    ;

    var arena_allocator = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena_allocator.deinit();
    const allocator = arena_allocator.allocator();

    var parser = Parser.init(allocator, false);
    const tree_nocopy = try parser.parse(input);
    const obj_nocopy = tree_nocopy.root.Object;

    parser = Parser.init(allocator, true);
    const tree_copy = try parser.parse(input);
    const obj_copy = tree_copy.root.Object;

    for ([_][]const u8{ "noescape", "simple", "unicode", "surrogatepair" }) |field_name| {
        try testing.expectEqualSlices(u8, obj_nocopy.get(field_name).?.String, obj_copy.get(field_name).?.String);
    }

    const nocopy_addr = &obj_nocopy.get("noescape").?.String[0];
    const copy_addr = &obj_copy.get("noescape").?.String[0];

    var found_nocopy = false;
    for (input) |_, index| {
        try testing.expect(copy_addr != &input[index]);
        if (nocopy_addr == &input[index]) {
            found_nocopy = true;
        }
    }
    try testing.expect(found_nocopy);
}

test "stringify alloc" {
    const allocator = std.testing.allocator;
    const expected =
        \\{"foo":"bar","answer":42,"my_friend":"sammy"}
    ;
    const actual = try stringifyAlloc(allocator, .{ .foo = "bar", .answer = 42, .my_friend = "sammy" }, .{});
    defer allocator.free(actual);

    try std.testing.expectEqualStrings(expected, actual);
}

test "json.serialize issue #5959" {
    var parser: StreamingParser = undefined;
    // StreamingParser has multiple internal fields set to undefined. This causes issues when using
    // expectEqual so these are zeroed. We are testing for equality here only because this is a
    // known small test reproduction which hits the relevant LLVM issue.
    std.mem.set(u8, @ptrCast([*]u8, &parser)[0..@sizeOf(StreamingParser)], 0);
    try std.testing.expectEqual(parser, parser);
}

fn checkNext(p: *TokenStream, id: std.meta.Tag(Token)) !void {
    const token = (p.next() catch unreachable).?;
    try testing.expect(std.meta.activeTag(token) == id);
}

test "json.token" {
    const s =
        \\{
        \\  "Image": {
        \\      "Width":  800,
        \\      "Height": 600,
        \\      "Title":  "View from 15th Floor",
        \\      "Thumbnail": {
        \\          "Url":    "http://www.example.com/image/481989943",
        \\          "Height": 125,
        \\          "Width":  100
        \\      },
        \\      "Animated" : false,
        \\      "IDs": [116, 943, 234, 38793]
        \\    }
        \\}
    ;

    var p = TokenStream.init(s);

    try checkNext(&p, .ObjectBegin);
    try checkNext(&p, .String); // Image
    try checkNext(&p, .ObjectBegin);
    try checkNext(&p, .String); // Width
    try checkNext(&p, .Number);
    try checkNext(&p, .String); // Height
    try checkNext(&p, .Number);
    try checkNext(&p, .String); // Title
    try checkNext(&p, .String);
    try checkNext(&p, .String); // Thumbnail
    try checkNext(&p, .ObjectBegin);
    try checkNext(&p, .String); // Url
    try checkNext(&p, .String);
    try checkNext(&p, .String); // Height
    try checkNext(&p, .Number);
    try checkNext(&p, .String); // Width
    try checkNext(&p, .Number);
    try checkNext(&p, .ObjectEnd);
    try checkNext(&p, .String); // Animated
    try checkNext(&p, .False);
    try checkNext(&p, .String); // IDs
    try checkNext(&p, .ArrayBegin);
    try checkNext(&p, .Number);
    try checkNext(&p, .Number);
    try checkNext(&p, .Number);
    try checkNext(&p, .Number);
    try checkNext(&p, .ArrayEnd);
    try checkNext(&p, .ObjectEnd);
    try checkNext(&p, .ObjectEnd);

    try testing.expect((try p.next()) == null);
}

test "json.token mismatched close" {
    var p = TokenStream.init("[102, 111, 111 }");
    try checkNext(&p, .ArrayBegin);
    try checkNext(&p, .Number);
    try checkNext(&p, .Number);
    try checkNext(&p, .Number);
    try testing.expectError(error.UnexpectedClosingBrace, p.next());
}

test "json.token premature object close" {
    var p = TokenStream.init("{ \"key\": }");
    try checkNext(&p, .ObjectBegin);
    try checkNext(&p, .String);
    try testing.expectError(error.InvalidValueBegin, p.next());
}

test "json.validate" {
    try testing.expectEqual(true, validate("{}"));
    try testing.expectEqual(true, validate("[]"));
    try testing.expectEqual(true, validate("[{[[[[{}]]]]}]"));
    try testing.expectEqual(false, validate("{]"));
    try testing.expectEqual(false, validate("[}"));
    try testing.expectEqual(false, validate("{{{{[]}}}]"));
}

test "Value.jsonStringify" {
    {
        var buffer: [10]u8 = undefined;
        var fbs = std.io.fixedBufferStream(&buffer);
        try @as(Value, .Null).jsonStringify(.{}, fbs.writer());
        try testing.expectEqualSlices(u8, fbs.getWritten(), "null");
    }
    {
        var buffer: [10]u8 = undefined;
        var fbs = std.io.fixedBufferStream(&buffer);
        try (Value{ .Bool = true }).jsonStringify(.{}, fbs.writer());
        try testing.expectEqualSlices(u8, fbs.getWritten(), "true");
    }
    {
        var buffer: [10]u8 = undefined;
        var fbs = std.io.fixedBufferStream(&buffer);
        try (Value{ .Integer = 42 }).jsonStringify(.{}, fbs.writer());
        try testing.expectEqualSlices(u8, fbs.getWritten(), "42");
    }
    {
        var buffer: [10]u8 = undefined;
        var fbs = std.io.fixedBufferStream(&buffer);
        try (Value{ .NumberString = "43" }).jsonStringify(.{}, fbs.writer());
        try testing.expectEqualSlices(u8, fbs.getWritten(), "43");
    }
    {
        var buffer: [10]u8 = undefined;
        var fbs = std.io.fixedBufferStream(&buffer);
        try (Value{ .Float = 42 }).jsonStringify(.{}, fbs.writer());
        try testing.expectEqualSlices(u8, fbs.getWritten(), "4.2e+01");
    }
    {
        var buffer: [10]u8 = undefined;
        var fbs = std.io.fixedBufferStream(&buffer);
        try (Value{ .String = "weeee" }).jsonStringify(.{}, fbs.writer());
        try testing.expectEqualSlices(u8, fbs.getWritten(), "\"weeee\"");
    }
    {
        var buffer: [10]u8 = undefined;
        var fbs = std.io.fixedBufferStream(&buffer);
        var vals = [_]Value{
            .{ .Integer = 1 },
            .{ .Integer = 2 },
            .{ .NumberString = "3" },
        };
        try (Value{
            .Array = Array.fromOwnedSlice(undefined, &vals),
        }).jsonStringify(.{}, fbs.writer());
        try testing.expectEqualSlices(u8, fbs.getWritten(), "[1,2,3]");
    }
    {
        var buffer: [10]u8 = undefined;
        var fbs = std.io.fixedBufferStream(&buffer);
        var obj = ObjectMap.init(testing.allocator);
        defer obj.deinit();
        try obj.putNoClobber("a", .{ .String = "b" });
        try (Value{ .Object = obj }).jsonStringify(.{}, fbs.writer());
        try testing.expectEqualSlices(u8, fbs.getWritten(), "{\"a\":\"b\"}");
    }
}

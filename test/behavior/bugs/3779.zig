const std = @import("std");

const TestEnum = enum { TestEnumValue };
const tag_name = @tagName(TestEnum.TestEnumValue);
const ptr_tag_name: [*:0]const u8 = tag_name;

test "@tagName() returns a string literal" {
    try std.testing.expectEqual([:0]const u8, @TypeOf(tag_name));
    try std.testing.expectEqualStrings("TestEnumValue", tag_name);
    try std.testing.expectEqualStrings("TestEnumValue", ptr_tag_name[0..tag_name.len]);
}

const TestError = error{TestErrorCode};
const error_name = @errorName(TestError.TestErrorCode);
const ptr_error_name: [*:0]const u8 = error_name;

test "@errorName() returns a string literal" {
    try std.testing.expectEqual([:0]const u8, @TypeOf(error_name));
    try std.testing.expectEqualStrings("TestErrorCode", error_name);
    try std.testing.expectEqualStrings("TestErrorCode", ptr_error_name[0..error_name.len]);
}

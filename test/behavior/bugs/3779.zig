const std = @import("std");

const TestEnum = enum { TestEnumValue };
const tag_name = @tagName(TestEnum.TestEnumValue);
const ptr_tag_name: [*:0]const u8 = tag_name;

test "@tagName() returns a string literal" {
    try std.testing.expectEqual([:0]const u8, @TypeOf(tag_name));
    try std.testing.expectEqualStrings("TestEnumValue", tag_name);
    try std.testing.expectEqualStrings("TestEnumValue", ptr_tag_name[0..tag_name.len]);
}

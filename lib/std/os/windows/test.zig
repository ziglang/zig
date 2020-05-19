const std = @import("../../std.zig");
const builtin = @import("builtin");
const mem = std.mem;
const windows = std.os.windows;
const expect = std.testing.expect;

test "sliceToAltPrefixedFileW" {
    const rel_path = "fake/relative/path.txt";
    const conv_rel_path = try windows.sliceToAltPrefixedFileW(rel_path);
    expect(mem.eql(u16, conv_rel_path.span(), std.unicode.utf8ToUtf16LeStringLiteral("fake\\relative\\path.txt")));

    const abs_path = "c:/absolute_path/should_be_supported.txt";
    const conv_bas_path = try windows.sliceToAltPrefixedFileW(abs_path);
    expect(mem.eql(u16, conv_bas_path.span(), std.unicode.utf8ToUtf16LeStringLiteral("\\\\?\\c:\\absolute_path\\should_be_supported.txt")));
}

const std = @import("std");
const builtin = @import("builtin");

// Note: the environment variables under test are set by the build.zig
pub fn main() !void {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .init;
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var arena_state = std.heap.ArenaAllocator.init(allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();

    // hasNonEmptyEnvVar
    {
        try std.testing.expect(try std.process.hasNonEmptyEnvVar(allocator, "FOO"));
        try std.testing.expect(!(try std.process.hasNonEmptyEnvVar(allocator, "FOO=")));
        try std.testing.expect(!(try std.process.hasNonEmptyEnvVar(allocator, "FO")));
        try std.testing.expect(!(try std.process.hasNonEmptyEnvVar(allocator, "FOOO")));
        if (builtin.os.tag == .windows) {
            try std.testing.expect(try std.process.hasNonEmptyEnvVar(allocator, "foo"));
        }
        try std.testing.expect(try std.process.hasNonEmptyEnvVar(allocator, "EQUALS"));
        try std.testing.expect(!(try std.process.hasNonEmptyEnvVar(allocator, "EQUALS=ABC")));
        try std.testing.expect(try std.process.hasNonEmptyEnvVar(allocator, "КИРиллИЦА"));
        if (builtin.os.tag == .windows) {
            try std.testing.expect(try std.process.hasNonEmptyEnvVar(allocator, "кирИЛЛица"));
        }
        try std.testing.expect(!(try std.process.hasNonEmptyEnvVar(allocator, "NO_VALUE")));
        try std.testing.expect(!(try std.process.hasNonEmptyEnvVar(allocator, "NOT_SET")));
        if (builtin.os.tag == .windows) {
            try std.testing.expect(try std.process.hasNonEmptyEnvVar(allocator, "=HIDDEN"));
            try std.testing.expect(try std.process.hasNonEmptyEnvVar(allocator, "INVALID_UTF16_\xed\xa0\x80"));
        }
    }

    // hasNonEmptyEnvVarContstant
    {
        try std.testing.expect(std.process.hasNonEmptyEnvVarConstant("FOO"));
        try std.testing.expect(!std.process.hasNonEmptyEnvVarConstant("FOO="));
        try std.testing.expect(!std.process.hasNonEmptyEnvVarConstant("FO"));
        try std.testing.expect(!std.process.hasNonEmptyEnvVarConstant("FOOO"));
        if (builtin.os.tag == .windows) {
            try std.testing.expect(std.process.hasNonEmptyEnvVarConstant("foo"));
        }
        try std.testing.expect(std.process.hasNonEmptyEnvVarConstant("EQUALS"));
        try std.testing.expect(!std.process.hasNonEmptyEnvVarConstant("EQUALS=ABC"));
        try std.testing.expect(std.process.hasNonEmptyEnvVarConstant("КИРиллИЦА"));
        if (builtin.os.tag == .windows) {
            try std.testing.expect(std.process.hasNonEmptyEnvVarConstant("кирИЛЛица"));
        }
        try std.testing.expect(!(std.process.hasNonEmptyEnvVarConstant("NO_VALUE")));
        try std.testing.expect(!(std.process.hasNonEmptyEnvVarConstant("NOT_SET")));
        if (builtin.os.tag == .windows) {
            try std.testing.expect(std.process.hasNonEmptyEnvVarConstant("=HIDDEN"));
            try std.testing.expect(std.process.hasNonEmptyEnvVarConstant("INVALID_UTF16_\xed\xa0\x80"));
        }
    }

    // hasEnvVar
    {
        try std.testing.expect(try std.process.hasEnvVar(allocator, "FOO"));
        try std.testing.expect(!(try std.process.hasEnvVar(allocator, "FOO=")));
        try std.testing.expect(!(try std.process.hasEnvVar(allocator, "FO")));
        try std.testing.expect(!(try std.process.hasEnvVar(allocator, "FOOO")));
        if (builtin.os.tag == .windows) {
            try std.testing.expect(try std.process.hasEnvVar(allocator, "foo"));
        }
        try std.testing.expect(try std.process.hasEnvVar(allocator, "EQUALS"));
        try std.testing.expect(!(try std.process.hasEnvVar(allocator, "EQUALS=ABC")));
        try std.testing.expect(try std.process.hasEnvVar(allocator, "КИРиллИЦА"));
        if (builtin.os.tag == .windows) {
            try std.testing.expect(try std.process.hasEnvVar(allocator, "кирИЛЛица"));
        }
        try std.testing.expect(try std.process.hasEnvVar(allocator, "NO_VALUE"));
        try std.testing.expect(!(try std.process.hasEnvVar(allocator, "NOT_SET")));
        if (builtin.os.tag == .windows) {
            try std.testing.expect(try std.process.hasEnvVar(allocator, "=HIDDEN"));
            try std.testing.expect(try std.process.hasEnvVar(allocator, "INVALID_UTF16_\xed\xa0\x80"));
        }
    }

    // hasEnvVarConstant
    {
        try std.testing.expect(std.process.hasEnvVarConstant("FOO"));
        try std.testing.expect(!std.process.hasEnvVarConstant("FOO="));
        try std.testing.expect(!std.process.hasEnvVarConstant("FO"));
        try std.testing.expect(!std.process.hasEnvVarConstant("FOOO"));
        if (builtin.os.tag == .windows) {
            try std.testing.expect(std.process.hasEnvVarConstant("foo"));
        }
        try std.testing.expect(std.process.hasEnvVarConstant("EQUALS"));
        try std.testing.expect(!std.process.hasEnvVarConstant("EQUALS=ABC"));
        try std.testing.expect(std.process.hasEnvVarConstant("КИРиллИЦА"));
        if (builtin.os.tag == .windows) {
            try std.testing.expect(std.process.hasEnvVarConstant("кирИЛЛица"));
        }
        try std.testing.expect(std.process.hasEnvVarConstant("NO_VALUE"));
        try std.testing.expect(!(std.process.hasEnvVarConstant("NOT_SET")));
        if (builtin.os.tag == .windows) {
            try std.testing.expect(std.process.hasEnvVarConstant("=HIDDEN"));
            try std.testing.expect(std.process.hasEnvVarConstant("INVALID_UTF16_\xed\xa0\x80"));
        }
    }

    // getEnvVarOwned
    {
        try std.testing.expectEqualSlices(u8, "123", try std.process.getEnvVarOwned(arena, "FOO"));
        try std.testing.expectError(error.EnvironmentVariableNotFound, std.process.getEnvVarOwned(arena, "FOO="));
        try std.testing.expectError(error.EnvironmentVariableNotFound, std.process.getEnvVarOwned(arena, "FO"));
        try std.testing.expectError(error.EnvironmentVariableNotFound, std.process.getEnvVarOwned(arena, "FOOO"));
        if (builtin.os.tag == .windows) {
            try std.testing.expectEqualSlices(u8, "123", try std.process.getEnvVarOwned(arena, "foo"));
        }
        try std.testing.expectEqualSlices(u8, "ABC=123", try std.process.getEnvVarOwned(arena, "EQUALS"));
        try std.testing.expectError(error.EnvironmentVariableNotFound, std.process.getEnvVarOwned(arena, "EQUALS=ABC"));
        try std.testing.expectEqualSlices(u8, "non-ascii አማርኛ \u{10FFFF}", try std.process.getEnvVarOwned(arena, "КИРиллИЦА"));
        if (builtin.os.tag == .windows) {
            try std.testing.expectEqualSlices(u8, "non-ascii አማርኛ \u{10FFFF}", try std.process.getEnvVarOwned(arena, "кирИЛЛица"));
        }
        try std.testing.expectEqualSlices(u8, "", try std.process.getEnvVarOwned(arena, "NO_VALUE"));
        try std.testing.expectError(error.EnvironmentVariableNotFound, std.process.getEnvVarOwned(arena, "NOT_SET"));
        if (builtin.os.tag == .windows) {
            try std.testing.expectEqualSlices(u8, "hi", try std.process.getEnvVarOwned(arena, "=HIDDEN"));
            try std.testing.expectEqualSlices(u8, "\xed\xa0\x80", try std.process.getEnvVarOwned(arena, "INVALID_UTF16_\xed\xa0\x80"));
        }
    }

    // parseEnvVarInt
    {
        try std.testing.expectEqual(123, try std.process.parseEnvVarInt("FOO", u32, 10));
        try std.testing.expectError(error.EnvironmentVariableNotFound, std.process.parseEnvVarInt("FO", u32, 10));
        try std.testing.expectError(error.EnvironmentVariableNotFound, std.process.parseEnvVarInt("FOOO", u32, 10));
        try std.testing.expectEqual(0x123, try std.process.parseEnvVarInt("FOO", u32, 16));
        if (builtin.os.tag == .windows) {
            try std.testing.expectEqual(123, try std.process.parseEnvVarInt("foo", u32, 10));
        }
        try std.testing.expectError(error.InvalidCharacter, std.process.parseEnvVarInt("EQUALS", u32, 10));
        try std.testing.expectError(error.EnvironmentVariableNotFound, std.process.parseEnvVarInt("EQUALS=ABC", u32, 10));
        try std.testing.expectError(error.InvalidCharacter, std.process.parseEnvVarInt("КИРиллИЦА", u32, 10));
        try std.testing.expectError(error.InvalidCharacter, std.process.parseEnvVarInt("NO_VALUE", u32, 10));
        try std.testing.expectError(error.EnvironmentVariableNotFound, std.process.parseEnvVarInt("NOT_SET", u32, 10));
        if (builtin.os.tag == .windows) {
            try std.testing.expectError(error.InvalidCharacter, std.process.parseEnvVarInt("=HIDDEN", u32, 10));
            try std.testing.expectError(error.InvalidCharacter, std.process.parseEnvVarInt("INVALID_UTF16_\xed\xa0\x80", u32, 10));
        }
    }

    // EnvMap
    {
        var env_map = try std.process.getEnvMap(allocator);
        defer env_map.deinit();

        try std.testing.expectEqualSlices(u8, "123", env_map.get("FOO").?);
        try std.testing.expectEqual(null, env_map.get("FO"));
        try std.testing.expectEqual(null, env_map.get("FOOO"));
        if (builtin.os.tag == .windows) {
            try std.testing.expectEqualSlices(u8, "123", env_map.get("foo").?);
        }
        try std.testing.expectEqualSlices(u8, "ABC=123", env_map.get("EQUALS").?);
        try std.testing.expectEqual(null, env_map.get("EQUALS=ABC"));
        try std.testing.expectEqualSlices(u8, "non-ascii አማርኛ \u{10FFFF}", env_map.get("КИРиллИЦА").?);
        if (builtin.os.tag == .windows) {
            try std.testing.expectEqualSlices(u8, "non-ascii አማርኛ \u{10FFFF}", env_map.get("кирИЛЛица").?);
        }
        try std.testing.expectEqualSlices(u8, "", env_map.get("NO_VALUE").?);
        try std.testing.expectEqual(null, env_map.get("NOT_SET"));
        if (builtin.os.tag == .windows) {
            try std.testing.expectEqualSlices(u8, "hi", env_map.get("=HIDDEN").?);
            try std.testing.expectEqualSlices(u8, "\xed\xa0\x80", env_map.get("INVALID_UTF16_\xed\xa0\x80").?);
        }
    }
}

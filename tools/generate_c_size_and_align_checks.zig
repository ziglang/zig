//! Usage: zig run tools/generate_c_size_and_align_checks.zig -- [target_triple]
//! e.g. zig run tools/generate_c_size_and_align_checks.zig -- x86_64-linux-gnu
//!
//! Prints _Static_asserts for the size and alignment of all the basic built-in C
//! types. The output can be run through a compiler for the specified target to
//! verify that Zig's values are the same as those used by a C compiler for the
//! target.

const std = @import("std");

fn cName(ty: std.Target.CType) []const u8 {
    return switch (ty) {
        .char => "char",
        .short => "short",
        .ushort => "unsigned short",
        .int => "int",
        .uint => "unsigned int",
        .long => "long",
        .ulong => "unsigned long",
        .longlong => "long long",
        .ulonglong => "unsigned long long",
        .float => "float",
        .double => "double",
        .longdouble => "long double",
    };
}

pub fn main() !void {
    var general_purpose_allocator: std.heap.GeneralPurposeAllocator(.{}) = .init;
    defer std.debug.assert(general_purpose_allocator.deinit() == .ok);
    const gpa = general_purpose_allocator.allocator();

    var arena_instance = std.heap.ArenaAllocator.init(gpa);
    defer arena_instance.deinit();
    const arena = arena_instance.allocator();

    const args = try std.cli.parse(struct {
        positional: struct {
            target_triple: [:0]const u8,
        },
    }, arena, .{});

    const query = try std.Target.Query.parse(.{ .arch_os_abi = args.positional.target_triple });
    const target = try std.zig.system.resolveTargetQuery(query);

    var buffer: [2000]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writerStreaming(&buffer);
    const w = &stdout_writer.interface;
    inline for (@typeInfo(std.Target.CType).@"enum".fields) |field| {
        const c_type: std.Target.CType = @enumFromInt(field.value);
        try w.print("_Static_assert(sizeof({0s}) == {1d}, \"sizeof({0s}) == {1d}\");\n", .{
            cName(c_type),
            target.cTypeByteSize(c_type),
        });
        try w.print("_Static_assert(_Alignof({0s}) == {1d}, \"_Alignof({0s}) == {1d}\");\n", .{
            cName(c_type),
            target.cTypeAlignment(c_type),
        });
        try w.print("_Static_assert(__alignof({0s}) == {1d}, \"__alignof({0s}) == {1d}\");\n\n", .{
            cName(c_type),
            target.cTypePreferredAlignment(c_type),
        });
    }
    try w.flush();
}

const link = @import("link.zig");
const Module = @import("Module.zig");

const C = link.File.C;
const Decl = Module.Decl;
const CStandard = Module.CStandard;

pub fn generate(file: *C, decl: *Decl, standard: CStandard) !void {
    const writer = file.file.?.writer();
    try writer.print("Generating decl '{}', targeting {}", .{ decl.name, @tagName(standard) });
}

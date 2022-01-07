//! Emit assembly from Mir
//! Only use if not using llvm
const std = @import("std");
const Module = @import("Module.zig");
const Compilation = @import("Compilation.zig");

const EmitAsm = @This();

// maps the section, to a map of the decls in that section and the code from that decl
section_to_decl_to_code_map: std.StringHashMapUnmanaged(std.AutoHashMapUnmanaged(*Module.Decl, []const u8)) = .{},

mod: *Module,

// If the decl exists, update the assembly from it,
// otherwise add it to the decl_to_asm_map
pub fn updateTextDecl(self: *EmitAsm, decl: *Module.Decl, assmembly: []const u8) !void {
    var buf = std.ArrayList(u8).init(self.mod.gpa);
    const w = buf.writer();

    // TODO handle exporting different linkage and section
    if (self.mod.decl_exports.get(decl)) |exports| {
        for (exports) |ex| {
            try w.print("{s}:\n", .{ex.options.name});
        }
    }
    try w.print("{s}:\n", .{decl.name});

    try w.writeAll(assmembly);

    const s = buf.toOwnedSlice();

    const section = try self.mod.comp.bin_file.getDeclLinksection(decl);
    defer self.mod.comp.bin_file.allocator.free(section);
    const section_with_asm = try std.mem.concat(self.mod.gpa, u8, &.{ "section ", section, "\n" });
    const gop_res = try self.section_to_decl_to_code_map.getOrPut(self.mod.gpa, section_with_asm);
    if (!gop_res.found_existing) {
        gop_res.value_ptr.* = .{};
        try gop_res.value_ptr.put(self.mod.gpa, decl, s);
    } else {
        try gop_res.value_ptr.put(self.mod.gpa, decl, s);
        self.mod.gpa.free(section_with_asm);
    }
}

pub fn updateDataDecl(self: *EmitAsm, decl: *Module.Decl, code: []const u8) !void {
    var buf = std.ArrayList(u8).init(self.mod.gpa);
    const w = buf.writer();

    const section = try self.mod.comp.bin_file.getDeclLinksection(decl);
    defer self.mod.comp.bin_file.allocator.free(section);
    const section_with_asm = try std.mem.concat(self.mod.gpa, u8, &.{ "section ", section, "\n" });
    // TODO handle exporting different linkage and section
    if (self.mod.decl_exports.get(decl)) |exports| {
        for (exports) |ex| {
            try w.print("{s}:\n", .{ex.options.name});
        }
    }
    try w.print("{s}:\n    .ascii \"{}\"\n", .{ decl.name, std.zig.fmtEscapes(code) });

    const s = buf.toOwnedSlice();

    const gop_res = try self.section_to_decl_to_code_map.getOrPut(self.mod.gpa, section_with_asm);
    if (!gop_res.found_existing) {
        gop_res.value_ptr.* = .{};
        try gop_res.value_ptr.put(self.mod.gpa, decl, s);
    } else {
        try gop_res.value_ptr.put(self.mod.gpa, decl, s);
        self.mod.gpa.free(section_with_asm);
    }
}

// removes the decl from the map
pub fn freeDecl(self: *EmitAsm, decl: *Module.Decl) void {
    var it = self.section_to_decl_to_code_map.iterator();
    while (it.next()) |kv| {
        if (kv.value_ptr.remove(decl)) return;
    }
}

// writes all the decls to a file
pub fn flush(self: *EmitAsm) !void {
    const emit = self.mod.comp.emit_asm.?;
    const directory = if (emit.directory) |d| d else self.mod.zig_cache_artifact_directory;

    const fd = try directory.handle.createFile(emit.basename, .{});
    defer fd.close();

    var decl_and_section_count: usize = 0;
    {
        var it = self.section_to_decl_to_code_map.iterator();
        while (it.next()) |kv| {
            decl_and_section_count += 1;
            decl_and_section_count += kv.value_ptr.count();
        }
    }
    var iovecs = try self.mod.gpa.alloc(std.os.iovec_const, decl_and_section_count + 1);
    defer self.mod.gpa.free(iovecs);

    var i: usize = 0;
    var it = self.section_to_decl_to_code_map.iterator();
    while (it.next()) |kv| {
        // section name
        iovecs[i] = .{ .iov_base = kv.key_ptr.ptr, .iov_len = kv.key_ptr.len };
        i += 1;
        // decls in the section
        var itd = kv.value_ptr.iterator();
        while (itd.next()) |kvv| {
            iovecs[i] = .{
                .iov_base = kvv.value_ptr.ptr,
                .iov_len = kvv.value_ptr.len,
            };
            i += 1;
        }
    }

    // TODO make the global offset table actually contain the actual addresses of
    // the functions, set by the assembler
    // it may be necessary to make a new global offset table in assembler, like
    // got: .dq func1\n.dq func2 etc...
    const gotcode_and_addr = self.mod.comp.bin_file.getGot();
    const got = gotcode_and_addr.code;
    const got_addr = gotcode_and_addr.addr;
    const gotasm = try std.fmt.allocPrint(self.mod.gpa, "; the global offset table\nsection .got start=0x{x} vstart=0x{x}\n    .ascii \"{}\"\n", .{ got_addr, got_addr, std.zig.fmtEscapes(got) });
    defer self.mod.gpa.free(gotasm);
    iovecs[i] = .{ .iov_base = gotasm.ptr, .iov_len = gotasm.len };

    try fd.writevAll(iovecs);
}

pub fn deinit(self: *EmitAsm) void {
    var it = self.section_to_decl_to_code_map.iterator();
    while (it.next()) |kv| {
        var itd = kv.value_ptr.iterator();
        self.mod.gpa.free(kv.key_ptr.*);
        while (itd.next()) |kvv| {
            self.mod.gpa.free(kvv.value_ptr.*);
        }
        kv.value_ptr.deinit(self.mod.gpa);
    }
    self.section_to_decl_to_code_map.deinit(self.mod.gpa);
}

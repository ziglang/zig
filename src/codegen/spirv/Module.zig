//! This structure represents a SPIR-V (sections) module being compiled, and keeps track of all relevant information.
//! That includes the actual instructions, the current result-id bound, and data structures for querying result-id's
//! of data which needs to be persistent over different calls to Decl code generation.
//!
//! A SPIR-V binary module supports both little- and big endian layout. The layout is detected by the magic word in the
//! header. Therefore, we can ignore any byte order throughout the implementation, and just use the host byte order,
//! and make this a problem for the consumer.
const Module = @This();

const std = @import("std");
const Allocator = std.mem.Allocator;

const ZigDecl = @import("../../Module.zig").Decl;

const spec = @import("spec.zig");
const Word = spec.Word;
const IdRef = spec.IdRef;

const Section = @import("Section.zig");

/// A general-purpose allocator which may be used to allocate resources for this module
gpa: Allocator,

/// An arena allocator used to store things that have the same lifetime as this module.
arena: Allocator,

/// Module layout, according to SPIR-V Spec section 2.4, "Logical Layout of a Module".
sections: struct {
    /// Capability instructions
    capabilities: Section = .{},
    /// OpExtension instructions
    extensions: Section = .{},
    // OpExtInstImport instructions - skip for now.
    // memory model defined by target, not required here.
    /// OpEntryPoint instructions.
    entry_points: Section = .{},
    // OpExecutionMode and OpExecutionModeId instructions - skip for now.
    /// OpString, OpSourcExtension, OpSource, OpSourceContinued.
    debug_strings: Section = .{},
    // OpName, OpMemberName - skip for now.
    // OpModuleProcessed - skip for now.
    /// Annotation instructions (OpDecorate etc).
    annotations: Section = .{},
    /// Type declarations, constants, global variables
    /// Below this section, OpLine and OpNoLine is allowed.
    types_globals_constants: Section = .{},
    // Functions without a body - skip for now.
    /// Regular function definitions.
    functions: Section = .{},
} = .{},

/// SPIR-V instructions return result-ids. This variable holds the module-wide counter for these.
next_result_id: Word,

/// Cache for results of OpString instructions for module file names fed to OpSource.
/// Since OpString is pretty much only used for those, we don't need to keep track of all strings,
/// just the ones for OpLine. Note that OpLine needs the result of OpString, and not that of OpSource.
source_file_names: std.StringHashMapUnmanaged(IdRef) = .{},

pub fn init(gpa: Allocator, arena: Allocator) Module {
    return .{
        .gpa = gpa,
        .arena = arena,
        .next_result_id = 1, // 0 is an invalid SPIR-V result id, so start counting at 1.
    };
}

pub fn deinit(self: *Module) void {
    self.sections.capabilities.deinit(self.gpa);
    self.sections.extensions.deinit(self.gpa);
    self.sections.entry_points.deinit(self.gpa);
    self.sections.debug_strings.deinit(self.gpa);
    self.sections.annotations.deinit(self.gpa);
    self.sections.types_globals_constants.deinit(self.gpa);
    self.sections.functions.deinit(self.gpa);

    self.source_file_names.deinit(self.gpa);

    self.* = undefined;
}

pub fn allocId(self: *Module) spec.IdResult {
    defer self.next_result_id += 1;
    return .{.id = self.next_result_id};
}

pub fn idBound(self: Module) Word {
    return self.next_result_id;
}

/// Fetch the result-id of an OpString instruction that encodes the path of the source
/// file of the decl. This function may also emit an OpSource with source-level information regarding
/// the decl.
pub fn resolveSourceFileName(self: *Module, decl: *ZigDecl) !IdRef {
    const path = decl.getFileScope().sub_file_path;
    const result = try self.source_file_names.getOrPut(self.gpa, path);
    if (!result.found_existing) {
        const file_result_id = self.allocId();
        result.value_ptr.* = file_result_id.toRef();
        try self.sections.debug_strings.emit(self.gpa, .OpString, .{
            .id_result = file_result_id,
            .string = path,
        });

        try self.sections.debug_strings.emit(self.gpa, .OpSource, .{
            .source_language = .Unknown, // TODO: Register Zig source language.
            .version = 0, // TODO: Zig version as u32?
            .file = file_result_id.toRef(),
            .source = null, // TODO: Store actual source also?
        });
    }

    return result.value_ptr.*;
}

/// Emit this module as a spir-v binary.
pub fn flush(self: Module, file: std.fs.File) !void {
    // See SPIR-V Spec section 2.3, "Physical Layout of a SPIR-V Module and Instruction"

    const header = [_]Word{
        spec.magic_number,
        (spec.version.major << 16) | (spec.version.minor << 8),
        0, // TODO: Register Zig compiler magic number.
        self.idBound(),
        0, // Schema (currently reserved for future use)
    };

    // Note: needs to be kept in order according to section 2.3!
    const buffers = &[_][]const Word{
        &header,
        self.sections.capabilities.toWords(),
        self.sections.extensions.toWords(),
        self.sections.entry_points.toWords(),
        self.sections.debug_strings.toWords(),
        self.sections.annotations.toWords(),
        self.sections.types_globals_constants.toWords(),
        self.sections.functions.toWords(),
    };

    var iovc_buffers: [buffers.len]std.os.iovec_const = undefined;
    var file_size: u64 = 0;
    for (iovc_buffers) |*iovc, i| {
        // Note, since spir-v supports both little and big endian we can ignore byte order here and
        // just treat the words as a sequence of bytes.
        const bytes = std.mem.sliceAsBytes(buffers[i]);
        iovc.* = .{ .iov_base = bytes.ptr, .iov_len = bytes.len };
        file_size += bytes.len;
    }

    try file.seekTo(0);
    try file.setEndPos(file_size);
    try file.pwritevAll(&iovc_buffers, 0);
}

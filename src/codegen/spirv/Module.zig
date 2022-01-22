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
const assert = std.debug.assert;

const ZigDecl = @import("../../Module.zig").Decl;

const spec = @import("spec.zig");
const Word = spec.Word;
const IdRef = spec.IdRef;
const IdResult = spec.IdResult;
const IdResultType = spec.IdResultType;

const Section = @import("Section.zig");
const Type = @import("type.zig").Type;

const TypeCache = std.ArrayHashMapUnmanaged(Type, IdResultType, Type.ShallowHashContext32, true);

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

/// SPIR-V type cache. Note that according to SPIR-V spec section 2.8, Types and Variables, non-pointer
/// non-aggrerate types (which includes matrices and vectors) must have a _unique_ representation in
/// the final binary.
/// Note: Uses ArrayHashMap which is insertion ordered, so that we may refer to other types by index (Type.Ref).
type_cache: TypeCache = .{},

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
    self.type_cache.deinit(self.gpa);

    self.* = undefined;
}

pub fn allocId(self: *Module) spec.IdResult {
    defer self.next_result_id += 1;
    return .{ .id = self.next_result_id };
}

pub fn idBound(self: Module) Word {
    return self.next_result_id;
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

/// Fetch a result-id for a spir-v type. This function deduplicates the type as appropriate,
/// and returns a cached version if that exists.
/// Note: This function does not attempt to perform any validation on the type.
/// The type is emitted in a shallow fashion; any child types should already
/// be emitted at this point.
pub fn resolveType(self: *Module, ty: Type) !Type.Ref {
    const result = try self.type_cache.getOrPut(self.gpa, ty);
    if (!result.found_existing) {
        result.value_ptr.* = try self.emitType(ty);
    }
    return result.index;
}

pub fn resolveTypeId(self: *Module, ty: Type) !IdRef {
    return self.typeResultId(try self.resolveType(ty));
}

/// Get the result-id of a particular type, by reference. Asserts type_ref is valid.
pub fn typeResultId(self: Module, type_ref: Type.Ref) IdResultType {
    return self.type_cache.values()[type_ref];
}

/// Get the result-id of a particular type as IdRef, by Type.Ref. Asserts type_ref is valid.
pub fn typeRefId(self: Module, type_ref: Type.Ref) IdRef {
    return self.type_cache.values()[type_ref].toRef();
}

/// Unconditionally emit a spir-v type into the appropriate section.
/// Note: If this function is called with a type that is already generated, it may yield an invalid module
/// as non-pointer non-aggregrate types must me unique!
/// Note: This function does not attempt to perform any validation on the type.
/// The type is emitted in a shallow fashion; any child types should already
/// be emitted at this point.
pub fn emitType(self: *Module, ty: Type) !IdResultType {
    const result_id = self.allocId();
    const ref_id = result_id.toRef();
    const types = &self.sections.types_globals_constants;
    const annotations = &self.sections.annotations;
    const result_id_operand = .{ .id_result = result_id };

    switch (ty.tag()) {
        .void => try types.emit(self.gpa, .OpTypeVoid, result_id_operand),
        .bool => try types.emit(self.gpa, .OpTypeBool, result_id_operand),
        .int => try types.emit(self.gpa, .OpTypeInt, .{
            .id_result = result_id,
            .width = ty.payload(.int).width,
            .signedness = switch (ty.payload(.int).signedness) {
                .unsigned => @as(spec.LiteralInteger, 0),
                .signed => 1,
            },
        }),
        .float => try types.emit(self.gpa, .OpTypeFloat, .{
            .id_result = result_id,
            .width = ty.payload(.float).width,
        }),
        .vector => try types.emit(self.gpa, .OpTypeVector, .{
            .id_result = result_id,
            .component_type = self.typeResultId(ty.childType()).toRef(),
            .component_count = ty.payload(.vector).component_count,
        }),
        .matrix => try types.emit(self.gpa, .OpTypeMatrix, .{
            .id_result = result_id,
            .column_type = self.typeResultId(ty.childType()).toRef(),
            .column_count = ty.payload(.matrix).column_count,
        }),
        .image => {
            const info = ty.payload(.image);
            try types.emit(self.gpa, .OpTypeImage, .{
                .id_result = result_id,
                .sampled_type = self.typeResultId(ty.childType()).toRef(),
                .dim = info.dim,
                .depth = @enumToInt(info.depth),
                .arrayed = @boolToInt(info.arrayed),
                .ms = @boolToInt(info.multisampled),
                .sampled = @enumToInt(info.sampled),
                .image_format = info.format,
                .access_qualifier = info.access_qualifier,
            });
        },
        .sampler => try types.emit(self.gpa, .OpTypeSampler, result_id_operand),
        .sampled_image => try types.emit(self.gpa, .OpTypeSampledImage, .{
            .id_result = result_id,
            .image_type = self.typeResultId(ty.childType()).toRef(),
        }),
        .array => {
            const info = ty.payload(.array);
            assert(info.length != 0);
            try types.emit(self.gpa, .OpTypeArray, .{
                .id_result = result_id,
                .element_type = self.typeResultId(ty.childType()).toRef(),
                .length = .{ .id = 0 }, // TODO: info.length must be emitted as constant!
            });
            if (info.array_stride != 0) {
                try annotations.decorate(self.gpa, ref_id, .{ .ArrayStride = .{ .array_stride = info.array_stride } });
            }
        },
        .runtime_array => {
            const info = ty.payload(.runtime_array);
            try types.emit(self.gpa, .OpTypeRuntimeArray, .{
                .id_result = result_id,
                .element_type = self.typeResultId(ty.childType()).toRef(),
            });
            if (info.array_stride != 0) {
                try annotations.decorate(self.gpa, ref_id, .{ .ArrayStride = .{ .array_stride = info.array_stride } });
            }
        },
        .@"struct" => {
            const info = ty.payload(.@"struct");
            try types.emitRaw(self.gpa, .OpTypeStruct, 1 + info.members.len);
            types.writeOperand(IdResult, result_id);
            for (info.members) |member| {
                types.writeOperand(IdRef, self.typeResultId(member.ty).toRef());
            }
            try self.decorateStruct(ref_id, info);
        },
        .@"opaque" => try types.emit(self.gpa, .OpTypeOpaque, .{
            .id_result = result_id,
            .literal_string = ty.payload(.@"opaque").name,
        }),
        .pointer => {
            const info = ty.payload(.pointer);
            try types.emit(self.gpa, .OpTypePointer, .{
                .id_result = result_id,
                .storage_class = info.storage_class,
                .type = self.typeResultId(ty.childType()).toRef(),
            });
            if (info.array_stride != 0) {
                try annotations.decorate(self.gpa, ref_id, .{ .ArrayStride = .{ .array_stride = info.array_stride } });
            }
            if (info.alignment) |alignment| {
                try annotations.decorate(self.gpa, ref_id, .{ .Alignment = .{ .alignment = alignment } });
            }
            if (info.max_byte_offset) |max_byte_offset| {
                try annotations.decorate(self.gpa, ref_id, .{ .MaxByteOffset = .{ .max_byte_offset = max_byte_offset } });
            }
        },
        .function => {
            const info = ty.payload(.function);
            try types.emitRaw(self.gpa, .OpTypeFunction, 2 + info.parameters.len);
            types.writeOperand(IdResult, result_id);
            types.writeOperand(IdRef, self.typeResultId(info.return_type).toRef());
            for (info.parameters) |parameter_type| {
                types.writeOperand(IdRef, self.typeResultId(parameter_type).toRef());
            }
        },
        .event => try types.emit(self.gpa, .OpTypeEvent, result_id_operand),
        .device_event => try types.emit(self.gpa, .OpTypeDeviceEvent, result_id_operand),
        .reserve_id => try types.emit(self.gpa, .OpTypeReserveId, result_id_operand),
        .queue => try types.emit(self.gpa, .OpTypeQueue, result_id_operand),
        .pipe => try types.emit(self.gpa, .OpTypePipe, .{
            .id_result = result_id,
            .qualifier = ty.payload(.pipe).qualifier,
        }),
        .pipe_storage => try types.emit(self.gpa, .OpTypePipeStorage, result_id_operand),
        .named_barrier => try types.emit(self.gpa, .OpTypeNamedBarrier, result_id_operand),
    }

    return result_id.toResultType();
}

fn decorateStruct(self: *Module, target: IdRef, info: *const Type.Payload.Struct) !void {
    const annotations = &self.sections.annotations;

    // Decorations for the struct type itself.
    if (info.decorations.block)
        try annotations.decorate(self.gpa, target, .Block);
    if (info.decorations.buffer_block)
        try annotations.decorate(self.gpa, target, .BufferBlock);
    if (info.decorations.glsl_shared)
        try annotations.decorate(self.gpa, target, .GLSLShared);
    if (info.decorations.glsl_packed)
        try annotations.decorate(self.gpa, target, .GLSLPacked);
    if (info.decorations.c_packed)
        try annotations.decorate(self.gpa, target, .CPacked);

    // Decorations for the struct members.
    const extra = info.member_decoration_extra;
    var extra_i: u32 = 0;
    for (info.members) |member, i| {
        const d = member.decorations;
        const index = @intCast(Word, i);
        switch (d.matrix_layout) {
            .row_major => try annotations.decorateMember(self.gpa, target, index, .RowMajor),
            .col_major => try annotations.decorateMember(self.gpa, target, index, .ColMajor),
            .none => {},
        }
        if (d.matrix_layout != .none) {
            try annotations.decorateMember(self.gpa, target, index, .{
                .MatrixStride = .{ .matrix_stride = extra[extra_i] },
            });
            extra_i += 1;
        }

        if (d.no_perspective)
            try annotations.decorateMember(self.gpa, target, index, .NoPerspective);
        if (d.flat)
            try annotations.decorateMember(self.gpa, target, index, .Flat);
        if (d.patch)
            try annotations.decorateMember(self.gpa, target, index, .Patch);
        if (d.centroid)
            try annotations.decorateMember(self.gpa, target, index, .Centroid);
        if (d.sample)
            try annotations.decorateMember(self.gpa, target, index, .Sample);
        if (d.invariant)
            try annotations.decorateMember(self.gpa, target, index, .Invariant);
        if (d.@"volatile")
            try annotations.decorateMember(self.gpa, target, index, .Volatile);
        if (d.coherent)
            try annotations.decorateMember(self.gpa, target, index, .Coherent);
        if (d.non_writable)
            try annotations.decorateMember(self.gpa, target, index, .NonWritable);
        if (d.non_readable)
            try annotations.decorateMember(self.gpa, target, index, .NonReadable);

        if (d.builtin) {
            try annotations.decorateMember(self.gpa, target, index, .{
                .BuiltIn = .{ .built_in = @intToEnum(spec.BuiltIn, extra[extra_i]) },
            });
            extra_i += 1;
        }
        if (d.stream) {
            try annotations.decorateMember(self.gpa, target, index, .{
                .Stream = .{ .stream_number = extra[extra_i] },
            });
            extra_i += 1;
        }
        if (d.location) {
            try annotations.decorateMember(self.gpa, target, index, .{
                .Location = .{ .location = extra[extra_i] },
            });
            extra_i += 1;
        }
        if (d.component) {
            try annotations.decorateMember(self.gpa, target, index, .{
                .Component = .{ .component = extra[extra_i] },
            });
            extra_i += 1;
        }
        if (d.xfb_buffer) {
            try annotations.decorateMember(self.gpa, target, index, .{
                .XfbBuffer = .{ .xfb_buffer_number = extra[extra_i] },
            });
            extra_i += 1;
        }
        if (d.xfb_stride) {
            try annotations.decorateMember(self.gpa, target, index, .{
                .XfbStride = .{ .xfb_stride = extra[extra_i] },
            });
            extra_i += 1;
        }
        if (d.user_semantic) {
            const len = extra[extra_i];
            extra_i += 1;
            const semantic = @ptrCast([*]const u8, &extra[extra_i])[0..len];
            try annotations.decorateMember(self.gpa, target, index, .{
                .UserSemantic = .{ .semantic = semantic },
            });
            extra_i += std.math.divCeil(u32, extra_i, @sizeOf(u32)) catch unreachable;
        }
    }
}

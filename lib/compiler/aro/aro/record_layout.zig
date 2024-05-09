//! Record layout code adapted from https://github.com/mahkoh/repr-c
//! Licensed under MIT license: https://github.com/mahkoh/repr-c/tree/master/repc/facade

const std = @import("std");
const Type = @import("Type.zig");
const Attribute = @import("Attribute.zig");
const Compilation = @import("Compilation.zig");
const Parser = @import("Parser.zig");
const Record = Type.Record;
const Field = Record.Field;
const TypeLayout = Type.TypeLayout;
const FieldLayout = Type.FieldLayout;
const target_util = @import("target.zig");

const BITS_PER_BYTE = 8;

const OngoingBitfield = struct {
    size_bits: u64,
    unused_size_bits: u64,
};

const SysVContext = struct {
    /// Does the record have an __attribute__((packed)) annotation.
    attr_packed: bool,
    /// The value of #pragma pack(N) at the type level if any.
    max_field_align_bits: ?u64,
    /// The alignment of this record.
    aligned_bits: u32,
    is_union: bool,
    /// The size of the record. This might not be a multiple of 8 if the record contains bit-fields.
    /// For structs, this is also the offset of the first bit after the last field.
    size_bits: u64,
    /// non-null if the previous field was a non-zero-sized bit-field. Only used by MinGW.
    ongoing_bitfield: ?OngoingBitfield,

    comp: *const Compilation,

    fn init(ty: Type, comp: *const Compilation, pragma_pack: ?u8) SysVContext {
        var pack_value: ?u64 = null;
        if (pragma_pack) |pak| {
            pack_value = pak * BITS_PER_BYTE;
        }
        var req_align: u29 = BITS_PER_BYTE;
        if (ty.requestedAlignment(comp)) |aln| {
            req_align = aln * BITS_PER_BYTE;
        }
        return SysVContext{
            .attr_packed = ty.hasAttribute(.@"packed"),
            .max_field_align_bits = pack_value,
            .aligned_bits = req_align,
            .is_union = ty.is(.@"union"),
            .size_bits = 0,
            .comp = comp,
            .ongoing_bitfield = null,
        };
    }

    fn layoutFields(self: *SysVContext, rec: *const Record) void {
        for (rec.fields, 0..) |*fld, fld_indx| {
            if (fld.ty.specifier == .invalid) continue;
            const type_layout = computeLayout(fld.ty, self.comp);

            var field_attrs: ?[]const Attribute = null;
            if (rec.field_attributes) |attrs| {
                field_attrs = attrs[fld_indx];
            }
            if (self.comp.target.isMinGW()) {
                fld.layout = self.layoutMinGWField(fld, field_attrs, type_layout);
            } else {
                if (fld.isRegularField()) {
                    fld.layout = self.layoutRegularField(field_attrs, type_layout);
                } else {
                    fld.layout = self.layoutBitField(field_attrs, type_layout, fld.isNamed(), fld.specifiedBitWidth());
                }
            }
        }
    }

    /// On MinGW the alignment of the field is calculated in the usual way except that the alignment of
    /// the underlying type is ignored in three cases
    /// - the field is packed
    /// - the field is a bit-field and the previous field was a non-zero-sized bit-field with the same type size
    /// - the field is a zero-sized bit-field and the previous field was not a non-zero-sized bit-field
    /// See test case 0068.
    fn ignoreTypeAlignment(is_attr_packed: bool, bit_width: ?u32, ongoing_bitfield: ?OngoingBitfield, fld_layout: TypeLayout) bool {
        if (is_attr_packed) return true;
        if (bit_width) |width| {
            if (ongoing_bitfield) |ongoing| {
                if (ongoing.size_bits == fld_layout.size_bits) return true;
            } else {
                if (width == 0) return true;
            }
        }
        return false;
    }

    fn layoutMinGWField(
        self: *SysVContext,
        field: *const Field,
        field_attrs: ?[]const Attribute,
        field_layout: TypeLayout,
    ) FieldLayout {
        const annotation_alignment_bits = BITS_PER_BYTE * (Type.annotationAlignment(self.comp, field_attrs) orelse 1);
        const is_attr_packed = self.attr_packed or isPacked(field_attrs);
        const ignore_type_alignment = ignoreTypeAlignment(is_attr_packed, field.bit_width, self.ongoing_bitfield, field_layout);

        var field_alignment_bits: u64 = field_layout.field_alignment_bits;
        if (ignore_type_alignment) {
            field_alignment_bits = BITS_PER_BYTE;
        }
        field_alignment_bits = @max(field_alignment_bits, annotation_alignment_bits);
        if (self.max_field_align_bits) |bits| {
            field_alignment_bits = @min(field_alignment_bits, bits);
        }

        // The field affects the record alignment in one of three cases
        // - the field is a regular field
        // - the field is a zero-width bit-field following a non-zero-width bit-field
        // - the field is a non-zero-width bit-field and not packed.
        // See test case 0069.
        const update_record_alignment =
            field.isRegularField() or
            (field.specifiedBitWidth() == 0 and self.ongoing_bitfield != null) or
            (field.specifiedBitWidth() != 0 and !is_attr_packed);

        // If a field affects the alignment of a record, the alignment is calculated in the
        // usual way except that __attribute__((packed)) is ignored on a zero-width bit-field.
        // See test case 0068.
        if (update_record_alignment) {
            var ty_alignment_bits = field_layout.field_alignment_bits;
            if (is_attr_packed and (field.isRegularField() or field.specifiedBitWidth() != 0)) {
                ty_alignment_bits = BITS_PER_BYTE;
            }
            ty_alignment_bits = @max(ty_alignment_bits, annotation_alignment_bits);
            if (self.max_field_align_bits) |bits| {
                ty_alignment_bits = @intCast(@min(ty_alignment_bits, bits));
            }
            self.aligned_bits = @max(self.aligned_bits, ty_alignment_bits);
        }

        // NOTE: ty_alignment_bits and field_alignment_bits are different in the following case:
        // Y = { size: 64, alignment: 64 }struct {
        //     { offset: 0, size: 1 }c { size: 8, alignment: 8 }char:1,
        //     @attr_packed _ { size: 64, alignment: 64 }long long:0,
        //     { offset: 8, size: 8 }d { size: 8, alignment: 8 }char,
        // }
        if (field.isRegularField()) {
            return self.layoutRegularFieldMinGW(field_layout.size_bits, field_alignment_bits);
        } else {
            return self.layoutBitFieldMinGW(field_layout.size_bits, field_alignment_bits, field.isNamed(), field.specifiedBitWidth());
        }
    }

    fn layoutBitFieldMinGW(
        self: *SysVContext,
        ty_size_bits: u64,
        field_alignment_bits: u64,
        is_named: bool,
        width: u64,
    ) FieldLayout {
        std.debug.assert(width <= ty_size_bits); // validated in parser

        // In a union, the size of the underlying type does not affect the size of the union.
        // See test case 0070.
        if (self.is_union) {
            self.size_bits = @max(self.size_bits, width);
            if (!is_named) return .{};
            return .{
                .offset_bits = 0,
                .size_bits = width,
            };
        }
        if (width == 0) {
            self.ongoing_bitfield = null;
        } else {
            // If there is an ongoing bit-field in a struct whose underlying type has the same size and
            // if there is enough space left to place this bit-field, then this bit-field is placed in
            // the ongoing bit-field and the size of the struct is not affected by this
            // bit-field. See test case 0037.
            if (self.ongoing_bitfield) |*ongoing| {
                if (ongoing.size_bits == ty_size_bits and ongoing.unused_size_bits >= width) {
                    const offset_bits = self.size_bits - ongoing.unused_size_bits;
                    ongoing.unused_size_bits -= width;
                    if (!is_named) return .{};
                    return .{
                        .offset_bits = offset_bits,
                        .size_bits = width,
                    };
                }
            }
            // Otherwise this field is part of a new ongoing bit-field.
            self.ongoing_bitfield = .{
                .size_bits = ty_size_bits,
                .unused_size_bits = ty_size_bits - width,
            };
        }
        const offset_bits = std.mem.alignForward(u64, self.size_bits, field_alignment_bits);
        self.size_bits = if (width == 0) offset_bits else offset_bits + ty_size_bits;
        if (!is_named) return .{};
        return .{
            .offset_bits = offset_bits,
            .size_bits = width,
        };
    }

    fn layoutRegularFieldMinGW(
        self: *SysVContext,
        ty_size_bits: u64,
        field_alignment_bits: u64,
    ) FieldLayout {
        self.ongoing_bitfield = null;
        // A struct field starts at the next offset in the struct that is properly
        // aligned with respect to the start of the struct. See test case 0033.
        // A union field always starts at offset 0.
        const offset_bits = if (self.is_union) 0 else std.mem.alignForward(u64, self.size_bits, field_alignment_bits);

        // Set the size of the record to the maximum of the current size and the end of
        // the field. See test case 0034.
        self.size_bits = @max(self.size_bits, offset_bits + ty_size_bits);

        return .{
            .offset_bits = offset_bits,
            .size_bits = ty_size_bits,
        };
    }

    fn layoutRegularField(
        self: *SysVContext,
        fld_attrs: ?[]const Attribute,
        fld_layout: TypeLayout,
    ) FieldLayout {
        var fld_align_bits = fld_layout.field_alignment_bits;

        // If the struct or the field is packed, then the alignment of the underlying type is
        // ignored. See test case 0084.
        if (self.attr_packed or isPacked(fld_attrs)) {
            fld_align_bits = BITS_PER_BYTE;
        }

        // The field alignment can be increased by __attribute__((aligned)) annotations on the
        // field. See test case 0085.
        if (Type.annotationAlignment(self.comp, fld_attrs)) |anno| {
            fld_align_bits = @max(fld_align_bits, anno * BITS_PER_BYTE);
        }

        // #pragma pack takes precedence over all other attributes. See test cases 0084 and
        // 0085.
        if (self.max_field_align_bits) |req_bits| {
            fld_align_bits = @intCast(@min(fld_align_bits, req_bits));
        }

        // A struct field starts at the next offset in the struct that is properly
        // aligned with respect to the start of the struct.
        const offset_bits = if (self.is_union) 0 else std.mem.alignForward(u64, self.size_bits, fld_align_bits);
        const size_bits = fld_layout.size_bits;

        // The alignment of a record is the maximum of its field alignments. See test cases
        // 0084, 0085, 0086.
        self.size_bits = @max(self.size_bits, offset_bits + size_bits);
        self.aligned_bits = @max(self.aligned_bits, fld_align_bits);

        return .{
            .offset_bits = offset_bits,
            .size_bits = size_bits,
        };
    }

    fn layoutBitField(
        self: *SysVContext,
        fld_attrs: ?[]const Attribute,
        fld_layout: TypeLayout,
        is_named: bool,
        bit_width: u64,
    ) FieldLayout {
        const ty_size_bits = fld_layout.size_bits;
        var ty_fld_algn_bits: u32 = fld_layout.field_alignment_bits;

        if (bit_width > 0) {
            std.debug.assert(bit_width <= ty_size_bits); // Checked in parser
            // Some targets ignore the alignment of the underlying type when laying out
            // non-zero-sized bit-fields. See test case 0072. On such targets, bit-fields never
            // cross a storage boundary. See test case 0081.
            if (target_util.ignoreNonZeroSizedBitfieldTypeAlignment(self.comp.target)) {
                ty_fld_algn_bits = 1;
            }
        } else {
            // Some targets ignore the alignment of the underlying type when laying out
            // zero-sized bit-fields. See test case 0073.
            if (target_util.ignoreZeroSizedBitfieldTypeAlignment(self.comp.target)) {
                ty_fld_algn_bits = 1;
            }
            // Some targets have a minimum alignment of zero-sized bit-fields. See test case
            // 0074.
            if (target_util.minZeroWidthBitfieldAlignment(self.comp.target)) |target_align| {
                ty_fld_algn_bits = @max(ty_fld_algn_bits, target_align);
            }
        }

        // __attribute__((packed)) on the record is identical to __attribute__((packed)) on each
        // field. See test case 0067.
        const attr_packed = self.attr_packed or isPacked(fld_attrs);
        const has_packing_annotation = attr_packed or self.max_field_align_bits != null;

        const annotation_alignment: u32 = if (Type.annotationAlignment(self.comp, fld_attrs)) |anno| anno * BITS_PER_BYTE else 1;

        const first_unused_bit: u64 = if (self.is_union) 0 else self.size_bits;
        var field_align_bits: u64 = 1;

        if (bit_width == 0) {
            field_align_bits = @max(ty_fld_algn_bits, annotation_alignment);
        } else if (self.comp.langopts.emulate == .gcc) {
            // On GCC, the field alignment is at least the alignment requested by annotations
            // except as restricted by #pragma pack. See test case 0083.
            field_align_bits = annotation_alignment;
            if (self.max_field_align_bits) |max_bits| {
                field_align_bits = @min(annotation_alignment, max_bits);
            }

            // On GCC, if there are no packing annotations and
            // - the field would otherwise start at an offset such that it would cross a
            //   storage boundary or
            // - the alignment of the type is larger than its size,
            // then it is aligned to the type's field alignment. See test case 0083.
            if (!has_packing_annotation) {
                const start_bit = std.mem.alignForward(u64, first_unused_bit, field_align_bits);

                const does_field_cross_boundary = start_bit % ty_fld_algn_bits + bit_width > ty_size_bits;

                if (ty_fld_algn_bits > ty_size_bits or does_field_cross_boundary) {
                    field_align_bits = @max(field_align_bits, ty_fld_algn_bits);
                }
            }
        } else {
            std.debug.assert(self.comp.langopts.emulate == .clang);

            // On Clang, the alignment requested by annotations is not respected if it is
            // larger than the value of #pragma pack. See test case 0083.
            if (annotation_alignment <= self.max_field_align_bits orelse std.math.maxInt(u29)) {
                field_align_bits = @max(field_align_bits, annotation_alignment);
            }
            // On Clang, if there are no packing annotations and the field would cross a
            // storage boundary if it were positioned at the first unused bit in the record,
            // it is aligned to the type's field alignment. See test case 0083.
            if (!has_packing_annotation) {
                const does_field_cross_boundary = first_unused_bit % ty_fld_algn_bits + bit_width > ty_size_bits;

                if (does_field_cross_boundary)
                    field_align_bits = @max(field_align_bits, ty_fld_algn_bits);
            }
        }

        const offset_bits = std.mem.alignForward(u64, first_unused_bit, field_align_bits);
        self.size_bits = @max(self.size_bits, offset_bits + bit_width);

        // Unnamed fields do not contribute to the record alignment except on a few targets.
        // See test case 0079.
        if (is_named or target_util.unnamedFieldAffectsAlignment(self.comp.target)) {
            var inherited_align_bits: u32 = undefined;

            if (bit_width == 0) {
                // If the width is 0, #pragma pack and __attribute__((packed)) are ignored.
                // See test case 0075.
                inherited_align_bits = @max(ty_fld_algn_bits, annotation_alignment);
            } else if (self.max_field_align_bits) |max_align_bits| {
                // Otherwise, if a #pragma pack is in effect, __attribute__((packed)) on the field or
                // record is ignored. See test case 0076.
                inherited_align_bits = @max(ty_fld_algn_bits, annotation_alignment);
                inherited_align_bits = @intCast(@min(inherited_align_bits, max_align_bits));
            } else if (attr_packed) {
                // Otherwise, if the field or the record is packed, the field alignment is 1 bit unless
                // it is explicitly increased with __attribute__((aligned)). See test case 0077.
                inherited_align_bits = annotation_alignment;
            } else {
                // Otherwise, the field alignment is the field alignment of the underlying type unless
                // it is explicitly increased with __attribute__((aligned)). See test case 0078.
                inherited_align_bits = @max(ty_fld_algn_bits, annotation_alignment);
            }
            self.aligned_bits = @max(self.aligned_bits, inherited_align_bits);
        }

        if (!is_named) return .{};
        return .{
            .size_bits = bit_width,
            .offset_bits = offset_bits,
        };
    }
};

const MsvcContext = struct {
    req_align_bits: u32,
    max_field_align_bits: ?u32,
    /// The alignment of pointers that point to an object of this type. This is greater than or equal
    /// to the required alignment. Once all fields have been laid out, the size of the record will be
    /// rounded up to this value.
    pointer_align_bits: u32,
    /// The alignment of this type when it is used as a record field. This is greater than or equal to
    /// the pointer alignment.
    field_align_bits: u32,
    size_bits: u64,
    ongoing_bitfield: ?OngoingBitfield,
    contains_non_bitfield: bool,
    is_union: bool,
    comp: *const Compilation,

    fn init(ty: Type, comp: *const Compilation, pragma_pack: ?u8) MsvcContext {
        var pack_value: ?u32 = null;
        if (ty.hasAttribute(.@"packed")) {
            // __attribute__((packed)) behaves like #pragma pack(1) in clang. See test case 0056.
            pack_value = BITS_PER_BYTE;
        }
        if (pack_value == null) {
            if (pragma_pack) |pack| {
                pack_value = pack * BITS_PER_BYTE;
            }
        }
        if (pack_value) |pack| {
            pack_value = msvcPragmaPack(comp, pack);
        }

        // The required alignment can be increased by adding a __declspec(align)
        // annotation. See test case 0023.
        var must_align: u29 = BITS_PER_BYTE;
        if (ty.requestedAlignment(comp)) |req_align| {
            must_align = req_align * BITS_PER_BYTE;
        }
        return MsvcContext{
            .req_align_bits = must_align,
            .pointer_align_bits = must_align,
            .field_align_bits = must_align,
            .size_bits = 0,
            .max_field_align_bits = pack_value,
            .ongoing_bitfield = null,
            .contains_non_bitfield = false,
            .is_union = ty.is(.@"union"),
            .comp = comp,
        };
    }

    fn layoutField(self: *MsvcContext, fld: *const Field, fld_attrs: ?[]const Attribute) FieldLayout {
        const type_layout = computeLayout(fld.ty, self.comp);

        // The required alignment of the field is the maximum of the required alignment of the
        // underlying type and the __declspec(align) annotation on the field itself.
        // See test case 0028.
        var req_align = type_layout.required_alignment_bits;
        if (Type.annotationAlignment(self.comp, fld_attrs)) |anno| {
            req_align = @max(anno * BITS_PER_BYTE, req_align);
        }

        // The required alignment of a record is the maximum of the required alignments of its
        // fields except that the required alignment of bitfields is ignored.
        // See test case 0029.
        if (fld.isRegularField()) {
            self.req_align_bits = @max(self.req_align_bits, req_align);
        }

        // The offset of the field is based on the field alignment of the underlying type.
        // See test case 0027.
        var fld_align_bits = type_layout.field_alignment_bits;
        if (self.max_field_align_bits) |max_align| {
            fld_align_bits = @min(fld_align_bits, max_align);
        }
        // check the requested alignment of the field type.
        if (fld.ty.requestedAlignment(self.comp)) |type_req_align| {
            fld_align_bits = @max(fld_align_bits, type_req_align * 8);
        }

        if (isPacked(fld_attrs)) {
            // __attribute__((packed)) on a field is a clang extension. It behaves as if #pragma
            // pack(1) had been applied only to this field. See test case 0057.
            fld_align_bits = BITS_PER_BYTE;
        }
        // __attribute__((packed)) on a field is a clang extension. It behaves as if #pragma
        // pack(1) had been applied only to this field. See test case 0057.
        fld_align_bits = @max(fld_align_bits, req_align);
        if (fld.isRegularField()) {
            return self.layoutRegularField(type_layout.size_bits, fld_align_bits);
        } else {
            return self.layoutBitField(type_layout.size_bits, fld_align_bits, fld.specifiedBitWidth());
        }
    }

    fn layoutBitField(self: *MsvcContext, ty_size_bits: u64, field_align: u32, bit_width: u32) FieldLayout {
        if (bit_width == 0) {
            // A zero-sized bit-field that does not follow a non-zero-sized bit-field does not affect
            // the overall layout of the record. Even in a union where the order would otherwise
            // not matter. See test case 0035.
            if (self.ongoing_bitfield) |_| {
                self.ongoing_bitfield = null;
            } else {
                // this field takes 0 space.
                return .{ .offset_bits = self.size_bits, .size_bits = bit_width };
            }
        } else {
            std.debug.assert(bit_width <= ty_size_bits);
            // If there is an ongoing bit-field in a struct whose underlying type has the same size and
            // if there is enough space left to place this bit-field, then this bit-field is placed in
            // the ongoing bit-field and the overall layout of the struct is not affected by this
            // bit-field. See test case 0037.
            if (!self.is_union) {
                if (self.ongoing_bitfield) |*p| {
                    if (p.size_bits == ty_size_bits and p.unused_size_bits >= bit_width) {
                        const offset_bits = self.size_bits - p.unused_size_bits;
                        p.unused_size_bits -= bit_width;
                        return .{ .offset_bits = offset_bits, .size_bits = bit_width };
                    }
                }
            }
            // Otherwise this field is part of a new ongoing bit-field.
            self.ongoing_bitfield = .{ .size_bits = ty_size_bits, .unused_size_bits = ty_size_bits - bit_width };
        }
        const offset_bits = if (!self.is_union) bits: {
            // This is the one place in the layout of a record where the pointer alignment might
            // get assigned a smaller value than the field alignment. This can only happen if
            // the field or the type of the field has a required alignment. Otherwise the value
            // of field_alignment_bits is already bound by max_field_alignment_bits.
            // See test case 0038.
            const p_align = if (self.max_field_align_bits) |max_fld_align|
                @min(max_fld_align, field_align)
            else
                field_align;
            self.pointer_align_bits = @max(self.pointer_align_bits, p_align);
            self.field_align_bits = @max(self.field_align_bits, field_align);

            const offset_bits = std.mem.alignForward(u64, self.size_bits, field_align);
            self.size_bits = if (bit_width == 0) offset_bits else offset_bits + ty_size_bits;

            break :bits offset_bits;
        } else bits: {
            // Bit-fields do not affect the alignment of a union. See test case 0041.
            self.size_bits = @max(self.size_bits, ty_size_bits);
            break :bits 0;
        };
        return .{ .offset_bits = offset_bits, .size_bits = bit_width };
    }

    fn layoutRegularField(self: *MsvcContext, size_bits: u64, field_align: u32) FieldLayout {
        self.contains_non_bitfield = true;
        self.ongoing_bitfield = null;
        // The alignment of the field affects both the pointer alignment and the field
        // alignment of the record. See test case 0032.
        self.pointer_align_bits = @max(self.pointer_align_bits, field_align);
        self.field_align_bits = @max(self.field_align_bits, field_align);
        const offset_bits = switch (self.is_union) {
            true => 0,
            false => std.mem.alignForward(u64, self.size_bits, field_align),
        };
        self.size_bits = @max(self.size_bits, offset_bits + size_bits);
        return .{ .offset_bits = offset_bits, .size_bits = size_bits };
    }
    fn handleZeroSizedRecord(self: *MsvcContext) void {
        if (self.is_union) {
            // MSVC does not allow unions without fields.
            // If all fields in a union have size 0, the size of the union is set to
            // - its field alignment if it contains at least one non-bitfield
            // - 4 bytes if it contains only bitfields
            // See test case 0025.
            if (self.contains_non_bitfield) {
                self.size_bits = self.field_align_bits;
            } else {
                self.size_bits = 4 * BITS_PER_BYTE;
            }
        } else {
            // If all fields in a struct have size 0, its size is set to its required alignment
            // but at least to 4 bytes. See test case 0026.
            self.size_bits = @max(self.req_align_bits, 4 * BITS_PER_BYTE);
            self.pointer_align_bits = @intCast(@min(self.pointer_align_bits, self.size_bits));
        }
    }
};

pub fn compute(rec: *Type.Record, ty: Type, comp: *const Compilation, pragma_pack: ?u8) void {
    switch (comp.langopts.emulate) {
        .gcc, .clang => {
            var context = SysVContext.init(ty, comp, pragma_pack);

            context.layoutFields(rec);

            context.size_bits = std.mem.alignForward(u64, context.size_bits, context.aligned_bits);

            rec.type_layout = .{
                .size_bits = context.size_bits,
                .field_alignment_bits = context.aligned_bits,
                .pointer_alignment_bits = context.aligned_bits,
                .required_alignment_bits = BITS_PER_BYTE,
            };
        },
        .msvc => {
            var context = MsvcContext.init(ty, comp, pragma_pack);
            for (rec.fields, 0..) |*fld, fld_indx| {
                if (fld.ty.specifier == .invalid) continue;
                var field_attrs: ?[]const Attribute = null;
                if (rec.field_attributes) |attrs| {
                    field_attrs = attrs[fld_indx];
                }

                fld.layout = context.layoutField(fld, field_attrs);
            }
            if (context.size_bits == 0) {
                // As an extension, MSVC allows records that only contain zero-sized bitfields and empty
                // arrays. Such records would be zero-sized but this case is handled here separately to
                // ensure that there are no zero-sized records.
                context.handleZeroSizedRecord();
            }
            context.size_bits = std.mem.alignForward(u64, context.size_bits, context.pointer_align_bits);
            rec.type_layout = .{
                .size_bits = context.size_bits,
                .field_alignment_bits = context.field_align_bits,
                .pointer_alignment_bits = context.pointer_align_bits,
                .required_alignment_bits = context.req_align_bits,
            };
        },
    }
}

fn computeLayout(ty: Type, comp: *const Compilation) TypeLayout {
    if (ty.getRecord()) |rec| {
        const requested = BITS_PER_BYTE * (ty.requestedAlignment(comp) orelse 0);
        return .{
            .size_bits = rec.type_layout.size_bits,
            .pointer_alignment_bits = @max(requested, rec.type_layout.pointer_alignment_bits),
            .field_alignment_bits = @max(requested, rec.type_layout.field_alignment_bits),
            .required_alignment_bits = rec.type_layout.required_alignment_bits,
        };
    } else {
        const type_align = ty.alignof(comp) * BITS_PER_BYTE;
        return .{
            .size_bits = ty.bitSizeof(comp) orelse 0,
            .pointer_alignment_bits = type_align,
            .field_alignment_bits = type_align,
            .required_alignment_bits = BITS_PER_BYTE,
        };
    }
}

fn isPacked(attrs: ?[]const Attribute) bool {
    const a = attrs orelse return false;

    for (a) |attribute| {
        if (attribute.tag != .@"packed") continue;
        return true;
    }
    return false;
}

// The effect of #pragma pack(N) depends on the target.
//
// x86: By default, there is no maximum field alignment. N={1,2,4} set the maximum field
//      alignment to that value. All other N activate the default.
// x64: By default, there is no maximum field alignment. N={1,2,4,8} set the maximum field
//      alignment to that value. All other N activate the default.
// arm: By default, the maximum field alignment is 8. N={1,2,4,8,16} set the maximum field
//      alignment to that value. All other N activate the default.
// arm64: By default, the maximum field alignment is 8. N={1,2,4,8} set the maximum field
//        alignment to that value. N=16 disables the maximum field alignment. All other N
//        activate the default.
//
// See test case 0020.
pub fn msvcPragmaPack(comp: *const Compilation, pack: u32) ?u32 {
    return switch (pack) {
        8, 16, 32 => pack,
        64 => if (comp.target.cpu.arch == .x86) null else pack,
        128 => if (comp.target.cpu.arch == .thumb) pack else null,
        else => {
            return switch (comp.target.cpu.arch) {
                .thumb, .aarch64 => 64,
                else => null,
            };
        },
    };
}

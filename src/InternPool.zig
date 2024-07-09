//! All interned objects have both a value and a type.
//! This data structure is self-contained, with the following exceptions:
//! * Module.Namespace has a pointer to Module.File

/// One item per thread, indexed by `tid`, which is dense and unique per thread.
locals: []Local = &.{},
/// Length must be a power of two and represents the number of simultaneous
/// writers that can mutate any single sharded data structure.
shards: []Shard = &.{},
/// Cached number of active bits in a `tid`.
tid_width: if (single_threaded) u0 else std.math.Log2Int(u32) = 0,
/// Cached shift amount to put a `tid` in the top bits of a 31-bit value.
tid_shift_31: if (single_threaded) u0 else std.math.Log2Int(u32) = if (single_threaded) 0 else 31,
/// Cached shift amount to put a `tid` in the top bits of a 32-bit value.
tid_shift_32: if (single_threaded) u0 else std.math.Log2Int(u32) = if (single_threaded) 0 else 31,

/// Some types such as enums, structs, and unions need to store mappings from field names
/// to field index, or value to field index. In such cases, they will store the underlying
/// field names and values directly, relying on one of these maps, stored separately,
/// to provide lookup.
/// These are not serialized; it is computed upon deserialization.
maps: std.ArrayListUnmanaged(FieldMap) = .{},

/// An index into `tracked_insts` gives a reference to a single ZIR instruction which
/// persists across incremental updates.
tracked_insts: std.AutoArrayHashMapUnmanaged(TrackedInst, void) = .{},

/// Dependencies on the source code hash associated with a ZIR instruction.
/// * For a `declaration`, this is the entire declaration body.
/// * For a `struct_decl`, `union_decl`, etc, this is the source of the fields (but not declarations).
/// * For a `func`, this is the source of the full function signature.
/// These are also invalidated if tracking fails for this instruction.
/// Value is index into `dep_entries` of the first dependency on this hash.
src_hash_deps: std.AutoArrayHashMapUnmanaged(TrackedInst.Index, DepEntry.Index) = .{},
/// Dependencies on the value of a Decl.
/// Value is index into `dep_entries` of the first dependency on this Decl value.
decl_val_deps: std.AutoArrayHashMapUnmanaged(DeclIndex, DepEntry.Index) = .{},
/// Dependencies on the IES of a runtime function.
/// Value is index into `dep_entries` of the first dependency on this Decl value.
func_ies_deps: std.AutoArrayHashMapUnmanaged(Index, DepEntry.Index) = .{},
/// Dependencies on the full set of names in a ZIR namespace.
/// Key refers to a `struct_decl`, `union_decl`, etc.
/// Value is index into `dep_entries` of the first dependency on this namespace.
namespace_deps: std.AutoArrayHashMapUnmanaged(TrackedInst.Index, DepEntry.Index) = .{},
/// Dependencies on the (non-)existence of some name in a namespace.
/// Value is index into `dep_entries` of the first dependency on this name.
namespace_name_deps: std.AutoArrayHashMapUnmanaged(NamespaceNameKey, DepEntry.Index) = .{},

/// Given a `Depender`, points to an entry in `dep_entries` whose `depender`
/// matches. The `next_dependee` field can be used to iterate all such entries
/// and remove them from the corresponding lists.
first_dependency: std.AutoArrayHashMapUnmanaged(AnalUnit, DepEntry.Index) = .{},

/// Stores dependency information. The hashmaps declared above are used to look
/// up entries in this list as required. This is not stored in `extra` so that
/// we can use `free_dep_entries` to track free indices, since dependencies are
/// removed frequently.
dep_entries: std.ArrayListUnmanaged(DepEntry) = .{},
/// Stores unused indices in `dep_entries` which can be reused without a full
/// garbage collection pass.
free_dep_entries: std.ArrayListUnmanaged(DepEntry.Index) = .{},

/// Elements are ordered identically to the `import_table` field of `Zcu`.
///
/// Unlike `import_table`, this data is serialized as part of incremental
/// compilation state.
///
/// Key is the hash of the path to this file, used to store
/// `InternPool.TrackedInst`.
///
/// Value is the `Decl` of the struct that represents this `File`.
files: std.AutoArrayHashMapUnmanaged(Cache.BinDigest, OptionalDeclIndex) = .{},

/// Whether a multi-threaded intern pool is useful.
/// Currently `false` until the intern pool is actually accessed
/// from multiple threads to reduce the cost of this data structure.
const want_multi_threaded = false;

/// Whether a single-threaded intern pool impl is in use.
pub const single_threaded = builtin.single_threaded or !want_multi_threaded;

pub const FileIndex = enum(u32) {
    _,
};

pub const TrackedInst = extern struct {
    file: FileIndex,
    inst: Zir.Inst.Index,
    comptime {
        // The fields should be tightly packed. See also serialiation logic in `Compilation.saveState`.
        assert(@sizeOf(@This()) == @sizeOf(FileIndex) + @sizeOf(Zir.Inst.Index));
    }
    pub const Index = enum(u32) {
        _,
        pub fn resolveFull(i: TrackedInst.Index, ip: *const InternPool) TrackedInst {
            return ip.tracked_insts.keys()[@intFromEnum(i)];
        }
        pub fn resolve(i: TrackedInst.Index, ip: *const InternPool) Zir.Inst.Index {
            return i.resolveFull(ip).inst;
        }
        pub fn toOptional(i: TrackedInst.Index) Optional {
            return @enumFromInt(@intFromEnum(i));
        }
        pub const Optional = enum(u32) {
            none = std.math.maxInt(u32),
            _,
            pub fn unwrap(opt: Optional) ?TrackedInst.Index {
                return switch (opt) {
                    .none => null,
                    _ => @enumFromInt(@intFromEnum(opt)),
                };
            }
        };
    };
};

pub fn trackZir(
    ip: *InternPool,
    gpa: Allocator,
    file: FileIndex,
    inst: Zir.Inst.Index,
) Allocator.Error!TrackedInst.Index {
    const key: TrackedInst = .{
        .file = file,
        .inst = inst,
    };
    const gop = try ip.tracked_insts.getOrPut(gpa, key);
    return @enumFromInt(gop.index);
}

/// Analysis Unit. Represents a single entity which undergoes semantic analysis.
/// This is either a `Decl` (in future `Cau`) or a runtime function.
/// The LSB is used as a tag bit.
/// This is the "source" of an incremental dependency edge.
pub const AnalUnit = packed struct(u32) {
    kind: enum(u1) { decl, func },
    index: u31,
    pub const Unwrapped = union(enum) {
        decl: DeclIndex,
        func: InternPool.Index,
    };
    pub fn unwrap(as: AnalUnit) Unwrapped {
        return switch (as.kind) {
            .decl => .{ .decl = @enumFromInt(as.index) },
            .func => .{ .func = @enumFromInt(as.index) },
        };
    }
    pub fn wrap(raw: Unwrapped) AnalUnit {
        return switch (raw) {
            .decl => |decl| .{ .kind = .decl, .index = @intCast(@intFromEnum(decl)) },
            .func => |func| .{ .kind = .func, .index = @intCast(@intFromEnum(func)) },
        };
    }
    pub fn toOptional(as: AnalUnit) Optional {
        return @enumFromInt(@as(u32, @bitCast(as)));
    }
    pub const Optional = enum(u32) {
        none = std.math.maxInt(u32),
        _,
        pub fn unwrap(opt: Optional) ?AnalUnit {
            return switch (opt) {
                .none => null,
                _ => @bitCast(@intFromEnum(opt)),
            };
        }
    };
};

pub const Dependee = union(enum) {
    src_hash: TrackedInst.Index,
    decl_val: DeclIndex,
    func_ies: Index,
    namespace: TrackedInst.Index,
    namespace_name: NamespaceNameKey,
};

pub fn removeDependenciesForDepender(ip: *InternPool, gpa: Allocator, depender: AnalUnit) void {
    var opt_idx = (ip.first_dependency.fetchSwapRemove(depender) orelse return).value.toOptional();

    while (opt_idx.unwrap()) |idx| {
        const dep = ip.dep_entries.items[@intFromEnum(idx)];
        opt_idx = dep.next_dependee;

        const prev_idx = dep.prev.unwrap() orelse {
            // This entry is the start of a list in some `*_deps`.
            // We cannot easily remove this mapping, so this must remain as a dummy entry.
            ip.dep_entries.items[@intFromEnum(idx)].depender = .none;
            continue;
        };

        ip.dep_entries.items[@intFromEnum(prev_idx)].next = dep.next;
        if (dep.next.unwrap()) |next_idx| {
            ip.dep_entries.items[@intFromEnum(next_idx)].prev = dep.prev;
        }

        ip.free_dep_entries.append(gpa, idx) catch {
            // This memory will be reclaimed on the next garbage collection.
            // Thus, we do not need to propagate this error.
        };
    }
}

pub const DependencyIterator = struct {
    ip: *const InternPool,
    next_entry: DepEntry.Index.Optional,
    pub fn next(it: *DependencyIterator) ?AnalUnit {
        const idx = it.next_entry.unwrap() orelse return null;
        const entry = it.ip.dep_entries.items[@intFromEnum(idx)];
        it.next_entry = entry.next;
        return entry.depender.unwrap().?;
    }
};

pub fn dependencyIterator(ip: *const InternPool, dependee: Dependee) DependencyIterator {
    const first_entry = switch (dependee) {
        .src_hash => |x| ip.src_hash_deps.get(x),
        .decl_val => |x| ip.decl_val_deps.get(x),
        .func_ies => |x| ip.func_ies_deps.get(x),
        .namespace => |x| ip.namespace_deps.get(x),
        .namespace_name => |x| ip.namespace_name_deps.get(x),
    } orelse return .{
        .ip = ip,
        .next_entry = .none,
    };
    if (ip.dep_entries.items[@intFromEnum(first_entry)].depender == .none) return .{
        .ip = ip,
        .next_entry = .none,
    };
    return .{
        .ip = ip,
        .next_entry = first_entry.toOptional(),
    };
}

pub fn addDependency(ip: *InternPool, gpa: Allocator, depender: AnalUnit, dependee: Dependee) Allocator.Error!void {
    const first_depender_dep: DepEntry.Index.Optional = if (ip.first_dependency.get(depender)) |idx| dep: {
        // The entry already exists, so there is capacity to overwrite it later.
        break :dep idx.toOptional();
    } else none: {
        // Ensure there is capacity available to add this dependency later.
        try ip.first_dependency.ensureUnusedCapacity(gpa, 1);
        break :none .none;
    };

    // We're very likely to need space for a new entry - reserve it now to avoid
    // the need for error cleanup logic.
    if (ip.free_dep_entries.items.len == 0) {
        try ip.dep_entries.ensureUnusedCapacity(gpa, 1);
    }

    // This block should allocate an entry and prepend it to the relevant `*_deps` list.
    // The `next` field should be correctly initialized; all other fields may be undefined.
    const new_index: DepEntry.Index = switch (dependee) {
        inline else => |dependee_payload, tag| new_index: {
            const gop = try switch (tag) {
                .src_hash => ip.src_hash_deps,
                .decl_val => ip.decl_val_deps,
                .func_ies => ip.func_ies_deps,
                .namespace => ip.namespace_deps,
                .namespace_name => ip.namespace_name_deps,
            }.getOrPut(gpa, dependee_payload);

            if (gop.found_existing and ip.dep_entries.items[@intFromEnum(gop.value_ptr.*)].depender == .none) {
                // Dummy entry, so we can reuse it rather than allocating a new one!
                ip.dep_entries.items[@intFromEnum(gop.value_ptr.*)].next = .none;
                break :new_index gop.value_ptr.*;
            }

            // Prepend a new dependency.
            const new_index: DepEntry.Index, const ptr = if (ip.free_dep_entries.popOrNull()) |new_index| new: {
                break :new .{ new_index, &ip.dep_entries.items[@intFromEnum(new_index)] };
            } else .{ @enumFromInt(ip.dep_entries.items.len), ip.dep_entries.addOneAssumeCapacity() };
            ptr.next = if (gop.found_existing) gop.value_ptr.*.toOptional() else .none;
            gop.value_ptr.* = new_index;
            break :new_index new_index;
        },
    };

    ip.dep_entries.items[@intFromEnum(new_index)].depender = depender.toOptional();
    ip.dep_entries.items[@intFromEnum(new_index)].prev = .none;
    ip.dep_entries.items[@intFromEnum(new_index)].next_dependee = first_depender_dep;
    ip.first_dependency.putAssumeCapacity(depender, new_index);
}

/// String is the name whose existence the dependency is on.
/// DepEntry.Index refers to the first such dependency.
pub const NamespaceNameKey = struct {
    /// The instruction (`struct_decl` etc) which owns the namespace in question.
    namespace: TrackedInst.Index,
    /// The name whose existence the dependency is on.
    name: NullTerminatedString,
};

pub const DepEntry = extern struct {
    /// If null, this is a dummy entry - all other fields are `undefined`. It is
    /// the first and only entry in one of `intern_pool.*_deps`, and does not
    /// appear in any list by `first_dependency`, but is not in
    /// `free_dep_entries` since `*_deps` stores a reference to it.
    depender: AnalUnit.Optional,
    /// Index into `dep_entries` forming a doubly linked list of all dependencies on this dependee.
    /// Used to iterate all dependers for a given dependee during an update.
    /// null if this is the end of the list.
    next: DepEntry.Index.Optional,
    /// The other link for `next`.
    /// null if this is the start of the list.
    prev: DepEntry.Index.Optional,
    /// Index into `dep_entries` forming a singly linked list of dependencies *of* `depender`.
    /// Used to efficiently remove all `DepEntry`s for a single `depender` when it is re-analyzed.
    /// null if this is the end of the list.
    next_dependee: DepEntry.Index.Optional,

    pub const Index = enum(u32) {
        _,
        pub fn toOptional(dep: DepEntry.Index) Optional {
            return @enumFromInt(@intFromEnum(dep));
        }
        pub const Optional = enum(u32) {
            none = std.math.maxInt(u32),
            _,
            pub fn unwrap(opt: Optional) ?DepEntry.Index {
                return switch (opt) {
                    .none => null,
                    _ => @enumFromInt(@intFromEnum(opt)),
                };
            }
        };
    };
};

const Local = struct {
    /// These fields can be accessed from any thread by calling `acquire`.
    /// They are only modified by the owning thread.
    shared: Shared align(std.atomic.cache_line),
    /// This state is fully local to the owning thread and does not require any
    /// atomic access.
    mutate: struct {
        arena: std.heap.ArenaAllocator.State,

        items: ListMutate,
        extra: ListMutate,
        limbs: ListMutate,
        strings: ListMutate,

        decls: BucketListMutate,
        namespaces: BucketListMutate,
    } align(std.atomic.cache_line),

    const Shared = struct {
        items: List(Item),
        extra: Extra,
        limbs: Limbs,
        strings: Strings,

        decls: Decls,
        namespaces: Namespaces,

        pub fn getLimbs(shared: *const Local.Shared) Limbs {
            return switch (@sizeOf(Limb)) {
                @sizeOf(u32) => shared.extra,
                @sizeOf(u64) => shared.limbs,
                else => @compileError("unsupported host"),
            }.acquire();
        }
    };

    const Extra = List(struct { u32 });
    const Limbs = switch (@sizeOf(Limb)) {
        @sizeOf(u32) => Extra,
        @sizeOf(u64) => List(struct { u64 }),
        else => @compileError("unsupported host"),
    };
    const Strings = List(struct { u8 });

    const decls_bucket_width = 8;
    const decls_bucket_mask = (1 << decls_bucket_width) - 1;
    const decl_next_free_field = "src_namespace";
    const Decls = List(struct { *[1 << decls_bucket_width]Module.Decl });

    const namespaces_bucket_width = 8;
    const namespaces_bucket_mask = (1 << namespaces_bucket_width) - 1;
    const namespace_next_free_field = "decl_index";
    const Namespaces = List(struct { *[1 << namespaces_bucket_width]Module.Namespace });

    const ListMutate = struct {
        len: u32,

        const empty: ListMutate = .{
            .len = 0,
        };
    };

    const BucketListMutate = struct {
        last_bucket_len: u32,
        buckets_list: ListMutate,
        free_list: u32,

        const free_list_sentinel = std.math.maxInt(u32);

        const empty: BucketListMutate = .{
            .last_bucket_len = 0,
            .buckets_list = ListMutate.empty,
            .free_list = free_list_sentinel,
        };
    };

    fn List(comptime Elem: type) type {
        assert(@typeInfo(Elem) == .Struct);
        return struct {
            bytes: [*]align(@alignOf(Elem)) u8,

            const ListSelf = @This();
            const Mutable = struct {
                gpa: std.mem.Allocator,
                arena: *std.heap.ArenaAllocator.State,
                mutate: *ListMutate,
                list: *ListSelf,

                const fields = std.enums.values(std.meta.FieldEnum(Elem));

                fn PtrArrayElem(comptime len: usize) type {
                    const elem_info = @typeInfo(Elem).Struct;
                    const elem_fields = elem_info.fields;
                    var new_fields: [elem_fields.len]std.builtin.Type.StructField = undefined;
                    for (&new_fields, elem_fields) |*new_field, elem_field| new_field.* = .{
                        .name = elem_field.name,
                        .type = *[len]elem_field.type,
                        .default_value = null,
                        .is_comptime = false,
                        .alignment = 0,
                    };
                    return @Type(.{ .Struct = .{
                        .layout = .auto,
                        .fields = &new_fields,
                        .decls = &.{},
                        .is_tuple = elem_info.is_tuple,
                    } });
                }
                fn SliceElem(comptime opts: struct { is_const: bool = false }) type {
                    const elem_info = @typeInfo(Elem).Struct;
                    const elem_fields = elem_info.fields;
                    var new_fields: [elem_fields.len]std.builtin.Type.StructField = undefined;
                    for (&new_fields, elem_fields) |*new_field, elem_field| new_field.* = .{
                        .name = elem_field.name,
                        .type = @Type(.{ .Pointer = .{
                            .size = .Slice,
                            .is_const = opts.is_const,
                            .is_volatile = false,
                            .alignment = 0,
                            .address_space = .generic,
                            .child = elem_field.type,
                            .is_allowzero = false,
                            .sentinel = null,
                        } }),
                        .default_value = null,
                        .is_comptime = false,
                        .alignment = 0,
                    };
                    return @Type(.{ .Struct = .{
                        .layout = .auto,
                        .fields = &new_fields,
                        .decls = &.{},
                        .is_tuple = elem_info.is_tuple,
                    } });
                }

                pub fn append(mutable: Mutable, elem: Elem) Allocator.Error!void {
                    try mutable.ensureUnusedCapacity(1);
                    mutable.appendAssumeCapacity(elem);
                }

                pub fn appendAssumeCapacity(mutable: Mutable, elem: Elem) void {
                    var mutable_view = mutable.view();
                    defer mutable.mutate.len = @intCast(mutable_view.len);
                    mutable_view.appendAssumeCapacity(elem);
                }

                pub fn appendSliceAssumeCapacity(
                    mutable: Mutable,
                    slice: SliceElem(.{ .is_const = true }),
                ) void {
                    if (fields.len == 0) return;
                    const start = mutable.mutate.len;
                    const slice_len = @field(slice, @tagName(fields[0])).len;
                    assert(slice_len <= mutable.list.header().capacity - start);
                    mutable.mutate.len = @intCast(start + slice_len);
                    const mutable_view = mutable.view();
                    inline for (fields) |field| {
                        const field_slice = @field(slice, @tagName(field));
                        assert(field_slice.len == slice_len);
                        @memcpy(mutable_view.items(field)[start..][0..slice_len], field_slice);
                    }
                }

                pub fn appendNTimes(mutable: Mutable, elem: Elem, len: usize) Allocator.Error!void {
                    try mutable.ensureUnusedCapacity(len);
                    mutable.appendNTimesAssumeCapacity(elem, len);
                }

                pub fn appendNTimesAssumeCapacity(mutable: Mutable, elem: Elem, len: usize) void {
                    const start = mutable.mutate.len;
                    assert(len <= mutable.list.header().capacity - start);
                    mutable.mutate.len = @intCast(start + len);
                    const mutable_view = mutable.view();
                    inline for (fields) |field| {
                        @memset(mutable_view.items(field)[start..][0..len], @field(elem, @tagName(field)));
                    }
                }

                pub fn addManyAsArray(mutable: Mutable, comptime len: usize) Allocator.Error!PtrArrayElem(len) {
                    try mutable.ensureUnusedCapacity(len);
                    return mutable.addManyAsArrayAssumeCapacity(len);
                }

                pub fn addManyAsArrayAssumeCapacity(mutable: Mutable, comptime len: usize) PtrArrayElem(len) {
                    const start = mutable.mutate.len;
                    assert(len <= mutable.list.header().capacity - start);
                    mutable.mutate.len = @intCast(start + len);
                    const mutable_view = mutable.view();
                    var ptr_array: PtrArrayElem(len) = undefined;
                    inline for (fields) |field| {
                        @field(ptr_array, @tagName(field)) = mutable_view.items(field)[start..][0..len];
                    }
                    return ptr_array;
                }

                pub fn addManyAsSlice(mutable: Mutable, len: usize) Allocator.Error!SliceElem(.{}) {
                    try mutable.ensureUnusedCapacity(len);
                    return mutable.addManyAsSliceAssumeCapacity(len);
                }

                pub fn addManyAsSliceAssumeCapacity(mutable: Mutable, len: usize) SliceElem(.{}) {
                    const start = mutable.mutate.len;
                    assert(len <= mutable.list.header().capacity - start);
                    mutable.mutate.len = @intCast(start + len);
                    const mutable_view = mutable.view();
                    var slice: SliceElem(.{}) = undefined;
                    inline for (fields) |field| {
                        @field(slice, @tagName(field)) = mutable_view.items(field)[start..][0..len];
                    }
                    return slice;
                }

                pub fn shrinkRetainingCapacity(mutable: Mutable, len: usize) void {
                    assert(len <= mutable.mutate.len);
                    mutable.mutate.len = @intCast(len);
                }

                pub fn ensureUnusedCapacity(mutable: Mutable, unused_capacity: usize) Allocator.Error!void {
                    try mutable.ensureTotalCapacity(@intCast(mutable.mutate.len + unused_capacity));
                }

                pub fn ensureTotalCapacity(mutable: Mutable, total_capacity: usize) Allocator.Error!void {
                    const old_capacity = mutable.list.header().capacity;
                    if (old_capacity >= total_capacity) return;
                    var new_capacity = old_capacity;
                    while (new_capacity < total_capacity) new_capacity = (new_capacity + 10) * 2;
                    try mutable.setCapacity(new_capacity);
                }

                fn setCapacity(mutable: Mutable, capacity: u32) Allocator.Error!void {
                    var arena = mutable.arena.promote(mutable.gpa);
                    defer mutable.arena.* = arena.state;
                    const buf = try arena.allocator().alignedAlloc(
                        u8,
                        alignment,
                        bytes_offset + View.capacityInBytes(capacity),
                    );
                    var new_list: ListSelf = .{ .bytes = @ptrCast(buf[bytes_offset..].ptr) };
                    new_list.header().* = .{ .capacity = capacity };
                    const len = mutable.mutate.len;
                    // this cold, quickly predictable, condition enables
                    // the `MultiArrayList` optimization in `view`
                    if (len > 0) {
                        const old_slice = mutable.list.view().slice();
                        const new_slice = new_list.view().slice();
                        inline for (fields) |field| @memcpy(new_slice.items(field)[0..len], old_slice.items(field)[0..len]);
                    }
                    mutable.list.release(new_list);
                }

                fn view(mutable: Mutable) View {
                    const capacity = mutable.list.header().capacity;
                    assert(capacity > 0); // optimizes `MultiArrayList.Slice.items`
                    return .{
                        .bytes = mutable.list.bytes,
                        .len = mutable.mutate.len,
                        .capacity = capacity,
                    };
                }
            };

            const empty: ListSelf = .{ .bytes = @constCast(&(extern struct {
                header: Header,
                bytes: [0]u8 align(@alignOf(Elem)),
            }{
                .header = .{ .capacity = 0 },
                .bytes = .{},
            }).bytes) };

            const alignment = @max(@alignOf(Header), @alignOf(Elem));
            const bytes_offset = std.mem.alignForward(usize, @sizeOf(Header), @alignOf(Elem));
            const View = std.MultiArrayList(Elem);

            /// Must be called when accessing from another thread.
            fn acquire(list: *const ListSelf) ListSelf {
                return .{ .bytes = @atomicLoad([*]align(@alignOf(Elem)) u8, &list.bytes, .acquire) };
            }
            fn release(list: *ListSelf, new_list: ListSelf) void {
                @atomicStore([*]align(@alignOf(Elem)) u8, &list.bytes, new_list.bytes, .release);
            }

            const Header = extern struct {
                capacity: u32,
            };
            fn header(list: ListSelf) *Header {
                return @ptrFromInt(@intFromPtr(list.bytes) - bytes_offset);
            }

            fn view(list: ListSelf) View {
                const capacity = list.header().capacity;
                assert(capacity > 0); // optimizes `MultiArrayList.Slice.items`
                return .{
                    .bytes = list.bytes,
                    .len = capacity,
                    .capacity = capacity,
                };
            }
        };
    }

    pub fn getMutableItems(local: *Local, gpa: std.mem.Allocator) List(Item).Mutable {
        return .{
            .gpa = gpa,
            .arena = &local.mutate.arena,
            .mutate = &local.mutate.items,
            .list = &local.shared.items,
        };
    }

    pub fn getMutableExtra(local: *Local, gpa: std.mem.Allocator) Extra.Mutable {
        return .{
            .gpa = gpa,
            .arena = &local.mutate.arena,
            .mutate = &local.mutate.extra,
            .list = &local.shared.extra,
        };
    }

    /// On 32-bit systems, this array is ignored and extra is used for everything.
    /// On 64-bit systems, this array is used for big integers and associated metadata.
    /// Use the helper methods instead of accessing this directly in order to not
    /// violate the above mechanism.
    pub fn getMutableLimbs(local: *Local, gpa: std.mem.Allocator) Limbs.Mutable {
        return switch (@sizeOf(Limb)) {
            @sizeOf(u32) => local.getMutableExtra(gpa),
            @sizeOf(u64) => .{
                .gpa = gpa,
                .arena = &local.mutate.arena,
                .mutate = &local.mutate.limbs,
                .list = &local.shared.limbs,
            },
            else => @compileError("unsupported host"),
        };
    }

    /// In order to store references to strings in fewer bytes, we copy all
    /// string bytes into here. String bytes can be null. It is up to whomever
    /// is referencing the data here whether they want to store both index and length,
    /// thus allowing null bytes, or store only index, and use null-termination. The
    /// `strings` array is agnostic to either usage.
    pub fn getMutableStrings(local: *Local, gpa: std.mem.Allocator) Strings.Mutable {
        return .{
            .gpa = gpa,
            .arena = &local.mutate.arena,
            .mutate = &local.mutate.strings,
            .list = &local.shared.strings,
        };
    }

    /// Rather than allocating Decl objects with an Allocator, we instead allocate
    /// them with this BucketList. This provides four advantages:
    ///  * Stable memory so that one thread can access a Decl object while another
    ///    thread allocates additional Decl objects from this list.
    ///  * It allows us to use u32 indexes to reference Decl objects rather than
    ///    pointers, saving memory in Type, Value, and dependency sets.
    ///  * Using integers to reference Decl objects rather than pointers makes
    ///    serialization trivial.
    ///  * It provides a unique integer to be used for anonymous symbol names, avoiding
    ///    multi-threaded contention on an atomic counter.
    pub fn getMutableDecls(local: *Local, gpa: std.mem.Allocator) Decls.Mutable {
        return .{
            .gpa = gpa,
            .arena = &local.mutate.arena,
            .mutate = &local.mutate.decls.buckets_list,
            .list = &local.shared.decls,
        };
    }

    /// Same pattern as with `getMutableDecls`.
    pub fn getMutableNamespaces(local: *Local, gpa: std.mem.Allocator) Namespaces.Mutable {
        return .{
            .gpa = gpa,
            .arena = &local.mutate.arena,
            .mutate = &local.mutate.namespaces.buckets_list,
            .list = &local.shared.namespaces,
        };
    }
};

pub fn getLocal(ip: *InternPool, tid: Zcu.PerThread.Id) *Local {
    return &ip.locals[@intFromEnum(tid)];
}

pub fn getLocalShared(ip: *const InternPool, tid: Zcu.PerThread.Id) *const Local.Shared {
    return &ip.locals[@intFromEnum(tid)].shared;
}

const Shard = struct {
    shared: struct {
        map: Map(Index),
        string_map: Map(OptionalNullTerminatedString),
    } align(std.atomic.cache_line),
    mutate: struct {
        // TODO: measure cost of sharing unrelated mutate state
        map: Mutate align(std.atomic.cache_line),
        string_map: Mutate align(std.atomic.cache_line),
    },

    const Mutate = struct {
        mutex: std.Thread.Mutex.Recursive,
        len: u32,

        const empty: Mutate = .{
            .mutex = std.Thread.Mutex.Recursive.init,
            .len = 0,
        };
    };

    fn Map(comptime Value: type) type {
        comptime assert(@typeInfo(Value).Enum.tag_type == u32);
        _ = @as(Value, .none); // expected .none key
        return struct {
            /// header: Header,
            /// entries: [header.capacity]Entry,
            entries: [*]Entry,

            const empty: @This() = .{ .entries = @constCast(&(extern struct {
                header: Header,
                entries: [1]Entry,
            }{
                .header = .{ .capacity = 1 },
                .entries = .{.{ .value = .none, .hash = undefined }},
            }).entries) };

            const alignment = @max(@alignOf(Header), @alignOf(Entry));
            const entries_offset = std.mem.alignForward(usize, @sizeOf(Header), @alignOf(Entry));

            /// Must be called unless the mutate mutex is locked.
            fn acquire(map: *const @This()) @This() {
                return .{ .entries = @atomicLoad([*]Entry, &map.entries, .acquire) };
            }
            fn release(map: *@This(), new_map: @This()) void {
                @atomicStore([*]Entry, &map.entries, new_map.entries, .release);
            }

            const Header = extern struct {
                capacity: u32,

                fn mask(head: *const Header) u32 {
                    assert(std.math.isPowerOfTwo(head.capacity));
                    return head.capacity - 1;
                }
            };
            fn header(map: @This()) *Header {
                return @ptrFromInt(@intFromPtr(map.entries) - entries_offset);
            }

            const Entry = extern struct {
                value: Value,
                hash: u32,

                fn acquire(entry: *const Entry) Value {
                    return @atomicLoad(Value, &entry.value, .acquire);
                }
                fn release(entry: *Entry, value: Value) void {
                    @atomicStore(Value, &entry.value, value, .release);
                }
            };
        };
    }
};

fn getTidMask(ip: *const InternPool) u32 {
    return (@as(u32, 1) << ip.tid_width) - 1;
}

fn getIndexMask(ip: *const InternPool, comptime BackingInt: type) u32 {
    return @as(u32, std.math.maxInt(BackingInt)) >> ip.tid_width;
}

const FieldMap = std.ArrayHashMapUnmanaged(void, void, std.array_hash_map.AutoContext(void), false);

const builtin = @import("builtin");
const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const BigIntConst = std.math.big.int.Const;
const BigIntMutable = std.math.big.int.Mutable;
const Cache = std.Build.Cache;
const Limb = std.math.big.Limb;
const Hash = std.hash.Wyhash;

const InternPool = @This();
const Zcu = @import("Zcu.zig");
/// Deprecated.
const Module = Zcu;
const Zir = std.zig.Zir;

/// An index into `maps` which might be `none`.
pub const OptionalMapIndex = enum(u32) {
    none = std.math.maxInt(u32),
    _,

    pub fn unwrap(oi: OptionalMapIndex) ?MapIndex {
        if (oi == .none) return null;
        return @enumFromInt(@intFromEnum(oi));
    }
};

/// An index into `maps`.
pub const MapIndex = enum(u32) {
    _,

    pub fn toOptional(i: MapIndex) OptionalMapIndex {
        return @enumFromInt(@intFromEnum(i));
    }
};

pub const RuntimeIndex = enum(u32) {
    zero = 0,
    comptime_field_ptr = std.math.maxInt(u32),
    _,

    pub fn increment(ri: *RuntimeIndex) void {
        ri.* = @enumFromInt(@intFromEnum(ri.*) + 1);
    }
};

pub const ComptimeAllocIndex = enum(u32) { _ };

pub const DeclIndex = enum(u32) {
    _,

    const Unwrapped = struct {
        tid: Zcu.PerThread.Id,
        bucket_index: u32,
        index: u32,

        fn wrap(unwrapped: Unwrapped, ip: *const InternPool) DeclIndex {
            assert(@intFromEnum(unwrapped.tid) <= ip.getTidMask());
            assert(unwrapped.bucket_index <= ip.getIndexMask(u32) >> Local.decls_bucket_width);
            assert(unwrapped.index <= Local.decls_bucket_mask);
            return @enumFromInt(@as(u32, @intFromEnum(unwrapped.tid)) << ip.tid_shift_32 |
                unwrapped.bucket_index << Local.decls_bucket_width |
                unwrapped.index);
        }
    };
    fn unwrap(decl_index: DeclIndex, ip: *const InternPool) Unwrapped {
        const index = @intFromEnum(decl_index) & ip.getIndexMask(u32);
        return .{
            .tid = @enumFromInt(@intFromEnum(decl_index) >> ip.tid_shift_32 & ip.getTidMask()),
            .bucket_index = index >> Local.decls_bucket_width,
            .index = index & Local.decls_bucket_mask,
        };
    }

    pub fn toOptional(i: DeclIndex) OptionalDeclIndex {
        return @enumFromInt(@intFromEnum(i));
    }
};

pub const OptionalDeclIndex = enum(u32) {
    none = std.math.maxInt(u32),
    _,

    pub fn init(oi: ?DeclIndex) OptionalDeclIndex {
        return @enumFromInt(@intFromEnum(oi orelse return .none));
    }

    pub fn unwrap(oi: OptionalDeclIndex) ?DeclIndex {
        if (oi == .none) return null;
        return @enumFromInt(@intFromEnum(oi));
    }
};

pub const NamespaceIndex = enum(u32) {
    _,

    const Unwrapped = struct {
        tid: Zcu.PerThread.Id,
        bucket_index: u32,
        index: u32,

        fn wrap(unwrapped: Unwrapped, ip: *const InternPool) NamespaceIndex {
            assert(@intFromEnum(unwrapped.tid) <= ip.getTidMask());
            assert(unwrapped.bucket_index <= ip.getIndexMask(u32) >> Local.namespaces_bucket_width);
            assert(unwrapped.index <= Local.namespaces_bucket_mask);
            return @enumFromInt(@as(u32, @intFromEnum(unwrapped.tid)) << ip.tid_shift_32 |
                unwrapped.bucket_index << Local.namespaces_bucket_width |
                unwrapped.index);
        }
    };
    fn unwrap(namespace_index: NamespaceIndex, ip: *const InternPool) Unwrapped {
        const index = @intFromEnum(namespace_index) & ip.getIndexMask(u32);
        return .{
            .tid = @enumFromInt(@intFromEnum(namespace_index) >> ip.tid_shift_32 & ip.getTidMask()),
            .bucket_index = index >> Local.namespaces_bucket_width,
            .index = index & Local.namespaces_bucket_mask,
        };
    }

    pub fn toOptional(i: NamespaceIndex) OptionalNamespaceIndex {
        return @enumFromInt(@intFromEnum(i));
    }
};

pub const OptionalNamespaceIndex = enum(u32) {
    none = std.math.maxInt(u32),
    _,

    pub fn init(oi: ?NamespaceIndex) OptionalNamespaceIndex {
        return @enumFromInt(@intFromEnum(oi orelse return .none));
    }

    pub fn unwrap(oi: OptionalNamespaceIndex) ?NamespaceIndex {
        if (oi == .none) return null;
        return @enumFromInt(@intFromEnum(oi));
    }
};

/// An index into `strings`.
pub const String = enum(u32) {
    /// An empty string.
    empty = 0,
    _,

    pub fn toSlice(string: String, len: u64, ip: *const InternPool) []const u8 {
        return string.toOverlongSlice(ip)[0..@intCast(len)];
    }

    pub fn at(string: String, index: u64, ip: *const InternPool) u8 {
        return string.toOverlongSlice(ip)[@intCast(index)];
    }

    pub fn toNullTerminatedString(string: String, len: u64, ip: *const InternPool) NullTerminatedString {
        assert(std.mem.indexOfScalar(u8, string.toSlice(len, ip), 0) == null);
        assert(string.at(len, ip) == 0);
        return @enumFromInt(@intFromEnum(string));
    }

    const Unwrapped = struct {
        tid: Zcu.PerThread.Id,
        index: u32,

        fn wrap(unwrapped: Unwrapped, ip: *const InternPool) String {
            assert(@intFromEnum(unwrapped.tid) <= ip.getTidMask());
            assert(unwrapped.index <= ip.getIndexMask(u32));
            return @enumFromInt(@as(u32, @intFromEnum(unwrapped.tid)) << ip.tid_shift_32 | unwrapped.index);
        }
    };
    fn unwrap(string: String, ip: *const InternPool) Unwrapped {
        return .{
            .tid = @enumFromInt(@intFromEnum(string) >> ip.tid_shift_32 & ip.getTidMask()),
            .index = @intFromEnum(string) & ip.getIndexMask(u32),
        };
    }

    fn toOverlongSlice(string: String, ip: *const InternPool) []const u8 {
        const unwrapped_string = string.unwrap(ip);
        const strings = ip.getLocalShared(unwrapped_string.tid).strings.acquire();
        return strings.view().items(.@"0")[unwrapped_string.index..];
    }
};

/// An index into `strings` which might be `none`.
pub const OptionalString = enum(u32) {
    /// This is distinct from `none` - it is a valid index that represents empty string.
    empty = 0,
    none = std.math.maxInt(u32),
    _,

    pub fn unwrap(string: OptionalString) ?String {
        return if (string != .none) @enumFromInt(@intFromEnum(string)) else null;
    }

    pub fn toSlice(string: OptionalString, len: u64, ip: *const InternPool) ?[]const u8 {
        return (string.unwrap() orelse return null).toSlice(len, ip);
    }
};

/// An index into `strings`.
pub const NullTerminatedString = enum(u32) {
    /// An empty string.
    empty = 0,
    _,

    /// An array of `NullTerminatedString` existing within the `extra` array.
    /// This type exists to provide a struct with lifetime that is
    /// not invalidated when items are added to the `InternPool`.
    pub const Slice = struct {
        tid: Zcu.PerThread.Id,
        start: u32,
        len: u32,

        pub const empty: Slice = .{ .tid = .main, .start = 0, .len = 0 };

        pub fn get(slice: Slice, ip: *const InternPool) []NullTerminatedString {
            const extra = ip.getLocalShared(slice.tid).extra.acquire();
            return @ptrCast(extra.view().items(.@"0")[slice.start..][0..slice.len]);
        }
    };

    pub fn toString(self: NullTerminatedString) String {
        return @enumFromInt(@intFromEnum(self));
    }

    pub fn toOptional(self: NullTerminatedString) OptionalNullTerminatedString {
        return @enumFromInt(@intFromEnum(self));
    }

    pub fn toSlice(string: NullTerminatedString, ip: *const InternPool) [:0]const u8 {
        const overlong_slice = string.toString().toOverlongSlice(ip);
        return overlong_slice[0..std.mem.indexOfScalar(u8, overlong_slice, 0).? :0];
    }

    pub fn length(string: NullTerminatedString, ip: *const InternPool) u32 {
        return @intCast(string.toSlice(ip).len);
    }

    pub fn eqlSlice(string: NullTerminatedString, slice: []const u8, ip: *const InternPool) bool {
        const overlong_slice = string.toString().toOverlongSlice(ip);
        return overlong_slice.len > slice.len and
            std.mem.eql(u8, overlong_slice[0..slice.len], slice) and
            overlong_slice[slice.len] == 0;
    }

    const Adapter = struct {
        strings: []const NullTerminatedString,

        pub fn eql(ctx: @This(), a: NullTerminatedString, b_void: void, b_map_index: usize) bool {
            _ = b_void;
            return a == ctx.strings[b_map_index];
        }

        pub fn hash(ctx: @This(), a: NullTerminatedString) u32 {
            _ = ctx;
            return std.hash.uint32(@intFromEnum(a));
        }
    };

    /// Compare based on integer value alone, ignoring the string contents.
    pub fn indexLessThan(ctx: void, a: NullTerminatedString, b: NullTerminatedString) bool {
        _ = ctx;
        return @intFromEnum(a) < @intFromEnum(b);
    }

    pub fn toUnsigned(string: NullTerminatedString, ip: *const InternPool) ?u32 {
        const slice = string.toSlice(ip);
        if (slice.len > 1 and slice[0] == '0') return null;
        if (std.mem.indexOfScalar(u8, slice, '_')) |_| return null;
        return std.fmt.parseUnsigned(u32, slice, 10) catch null;
    }

    const FormatData = struct {
        string: NullTerminatedString,
        ip: *const InternPool,
    };
    fn format(
        data: FormatData,
        comptime specifier: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) @TypeOf(writer).Error!void {
        const slice = data.string.toSlice(data.ip);
        if (comptime std.mem.eql(u8, specifier, "")) {
            try writer.writeAll(slice);
        } else if (comptime std.mem.eql(u8, specifier, "i")) {
            try writer.print("{p}", .{std.zig.fmtId(slice)});
        } else @compileError("invalid format string '" ++ specifier ++ "' for '" ++ @typeName(NullTerminatedString) ++ "'");
    }

    pub fn fmt(string: NullTerminatedString, ip: *const InternPool) std.fmt.Formatter(format) {
        return .{ .data = .{ .string = string, .ip = ip } };
    }
};

/// An index into `strings` which might be `none`.
pub const OptionalNullTerminatedString = enum(u32) {
    /// This is distinct from `none` - it is a valid index that represents empty string.
    empty = 0,
    none = std.math.maxInt(u32),
    _,

    pub fn unwrap(string: OptionalNullTerminatedString) ?NullTerminatedString {
        return if (string != .none) @enumFromInt(@intFromEnum(string)) else null;
    }

    pub fn toSlice(string: OptionalNullTerminatedString, ip: *const InternPool) ?[:0]const u8 {
        return (string.unwrap() orelse return null).toSlice(ip);
    }
};

/// A single value captured in the closure of a namespace type. This is not a plain
/// `Index` because we must differentiate between the following cases:
/// * runtime-known value (where we store the type)
/// * comptime-known value (where we store the value)
/// * decl val (so that we can analyze the value lazily)
/// * decl ref (so that we can analyze the reference lazily)
pub const CaptureValue = packed struct(u32) {
    tag: enum(u2) { @"comptime", runtime, decl_val, decl_ref },
    idx: u30,

    pub fn wrap(val: Unwrapped) CaptureValue {
        return switch (val) {
            .@"comptime" => |i| .{ .tag = .@"comptime", .idx = @intCast(@intFromEnum(i)) },
            .runtime => |i| .{ .tag = .runtime, .idx = @intCast(@intFromEnum(i)) },
            .decl_val => |i| .{ .tag = .decl_val, .idx = @intCast(@intFromEnum(i)) },
            .decl_ref => |i| .{ .tag = .decl_ref, .idx = @intCast(@intFromEnum(i)) },
        };
    }
    pub fn unwrap(val: CaptureValue) Unwrapped {
        return switch (val.tag) {
            .@"comptime" => .{ .@"comptime" = @enumFromInt(val.idx) },
            .runtime => .{ .runtime = @enumFromInt(val.idx) },
            .decl_val => .{ .decl_val = @enumFromInt(val.idx) },
            .decl_ref => .{ .decl_ref = @enumFromInt(val.idx) },
        };
    }

    pub const Unwrapped = union(enum) {
        /// Index refers to the value.
        @"comptime": Index,
        /// Index refers to the type.
        runtime: Index,
        decl_val: DeclIndex,
        decl_ref: DeclIndex,
    };

    pub const Slice = struct {
        tid: Zcu.PerThread.Id,
        start: u32,
        len: u32,

        pub const empty: Slice = .{ .tid = .main, .start = 0, .len = 0 };

        pub fn get(slice: Slice, ip: *const InternPool) []CaptureValue {
            const extra = ip.getLocalShared(slice.tid).extra.acquire();
            return @ptrCast(extra.view().items(.@"0")[slice.start..][0..slice.len]);
        }
    };
};

pub const Key = union(enum) {
    int_type: IntType,
    ptr_type: PtrType,
    array_type: ArrayType,
    vector_type: VectorType,
    opt_type: Index,
    /// `anyframe->T`. The payload is the child type, which may be `none` to indicate
    /// `anyframe`.
    anyframe_type: Index,
    error_union_type: ErrorUnionType,
    simple_type: SimpleType,
    /// This represents a struct that has been explicitly declared in source code,
    /// or was created with `@Type`. It is unique and based on a declaration.
    /// It may be a tuple, if declared like this: `struct {A, B, C}`.
    struct_type: NamespaceType,
    /// This is an anonymous struct or tuple type which has no corresponding
    /// declaration. It is used for types that have no `struct` keyword in the
    /// source code, and were not created via `@Type`.
    anon_struct_type: AnonStructType,
    union_type: NamespaceType,
    opaque_type: NamespaceType,
    enum_type: NamespaceType,
    func_type: FuncType,
    error_set_type: ErrorSetType,
    /// The payload is the function body, either a `func_decl` or `func_instance`.
    inferred_error_set_type: Index,

    /// Typed `undefined`. This will never be `none`; untyped `undefined` is represented
    /// via `simple_value` and has a named `Index` tag for it.
    undef: Index,
    simple_value: SimpleValue,
    variable: Variable,
    extern_func: ExternFunc,
    func: Func,
    int: Key.Int,
    err: Error,
    error_union: ErrorUnion,
    enum_literal: NullTerminatedString,
    /// A specific enum tag, indicated by the integer tag value.
    enum_tag: EnumTag,
    /// An empty enum or union. TODO: this value's existence is strange, because such a type in
    /// reality has no values. See #15909.
    /// Payload is the type for which we are an empty value.
    empty_enum_value: Index,
    float: Float,
    ptr: Ptr,
    slice: Slice,
    opt: Opt,
    /// An instance of a struct, array, or vector.
    /// Each element/field stored as an `Index`.
    /// In the case of sentinel-terminated arrays, the sentinel value *is* stored,
    /// so the slice length will be one more than the type's array length.
    aggregate: Aggregate,
    /// An instance of a union.
    un: Union,

    /// A comptime function call with a memoized result.
    memoized_call: Key.MemoizedCall,

    pub const TypeValue = extern struct {
        ty: Index,
        val: Index,
    };

    pub const IntType = std.builtin.Type.Int;

    /// Extern for hashing via memory reinterpretation.
    pub const ErrorUnionType = extern struct {
        error_set_type: Index,
        payload_type: Index,
    };

    pub const ErrorSetType = struct {
        /// Set of error names, sorted by null terminated string index.
        names: NullTerminatedString.Slice,
        /// This is ignored by `get` but will always be provided by `indexToKey`.
        names_map: OptionalMapIndex = .none,

        /// Look up field index based on field name.
        pub fn nameIndex(self: ErrorSetType, ip: *const InternPool, name: NullTerminatedString) ?u32 {
            const map = &ip.maps.items[@intFromEnum(self.names_map.unwrap().?)];
            const adapter: NullTerminatedString.Adapter = .{ .strings = self.names.get(ip) };
            const field_index = map.getIndexAdapted(name, adapter) orelse return null;
            return @intCast(field_index);
        }
    };

    /// Extern layout so it can be hashed with `std.mem.asBytes`.
    pub const PtrType = extern struct {
        child: Index,
        sentinel: Index = .none,
        flags: Flags = .{},
        packed_offset: PackedOffset = .{ .bit_offset = 0, .host_size = 0 },

        pub const VectorIndex = enum(u16) {
            none = std.math.maxInt(u16),
            runtime = std.math.maxInt(u16) - 1,
            _,
        };

        pub const Flags = packed struct(u32) {
            size: Size = .One,
            /// `none` indicates the ABI alignment of the pointee_type. In this
            /// case, this field *must* be set to `none`, otherwise the
            /// `InternPool` equality and hashing functions will return incorrect
            /// results.
            alignment: Alignment = .none,
            is_const: bool = false,
            is_volatile: bool = false,
            is_allowzero: bool = false,
            /// See src/target.zig defaultAddressSpace function for how to obtain
            /// an appropriate value for this field.
            address_space: AddressSpace = .generic,
            vector_index: VectorIndex = .none,
        };

        pub const PackedOffset = packed struct(u32) {
            /// If this is non-zero it means the pointer points to a sub-byte
            /// range of data, which is backed by a "host integer" with this
            /// number of bytes.
            /// When host_size=pointee_abi_size and bit_offset=0, this must be
            /// represented with host_size=0 instead.
            host_size: u16,
            bit_offset: u16,
        };

        pub const Size = std.builtin.Type.Pointer.Size;
        pub const AddressSpace = std.builtin.AddressSpace;
    };

    /// Extern so that hashing can be done via memory reinterpreting.
    pub const ArrayType = extern struct {
        len: u64,
        child: Index,
        sentinel: Index = .none,

        pub fn lenIncludingSentinel(array_type: ArrayType) u64 {
            return array_type.len + @intFromBool(array_type.sentinel != .none);
        }
    };

    /// Extern so that hashing can be done via memory reinterpreting.
    pub const VectorType = extern struct {
        len: u32,
        child: Index,
    };

    pub const AnonStructType = struct {
        types: Index.Slice,
        /// This may be empty, indicating this is a tuple.
        names: NullTerminatedString.Slice,
        /// These elements may be `none`, indicating runtime-known.
        values: Index.Slice,

        pub fn isTuple(self: AnonStructType) bool {
            return self.names.len == 0;
        }

        pub fn fieldName(
            self: AnonStructType,
            ip: *const InternPool,
            index: usize,
        ) OptionalNullTerminatedString {
            if (self.names.len == 0)
                return .none;

            return self.names.get(ip)[index].toOptional();
        }
    };

    /// This is the hashmap key. To fetch other data associated with the type, see:
    /// * `loadStructType`
    /// * `loadUnionType`
    /// * `loadEnumType`
    /// * `loadOpaqueType`
    pub const NamespaceType = union(enum) {
        /// This type corresponds to an actual source declaration, e.g. `struct { ... }`.
        /// It is hashed based on its ZIR instruction index and set of captures.
        declared: struct {
            /// A `struct_decl`, `union_decl`, `enum_decl`, or `opaque_decl` instruction.
            zir_index: TrackedInst.Index,
            /// The captured values of this type. These values must be fully resolved per the language spec.
            captures: union(enum) {
                owned: CaptureValue.Slice,
                external: []const CaptureValue,
            },
        },
        /// This type is an automatically-generated enum tag type for a union.
        /// It is hashed based on the index of the union type it corresponds to.
        generated_tag: struct {
            /// The union for which this is a tag type.
            union_type: Index,
        },
        /// This type originates from a reification via `@Type`.
        /// It is hased based on its ZIR instruction index and fields, attributes, etc.
        /// To avoid making this key overly complex, the type-specific data is hased by Sema.
        reified: struct {
            /// A `reify` instruction.
            zir_index: TrackedInst.Index,
            /// A hash of this type's attributes, fields, etc, generated by Sema.
            type_hash: u64,
        },
        /// This type is `@TypeOf(.{})`.
        /// TODO: can we change the language spec to not special-case this type?
        empty_struct: void,
    };

    pub const FuncType = struct {
        param_types: Index.Slice,
        return_type: Index,
        /// Tells whether a parameter is comptime. See `paramIsComptime` helper
        /// method for accessing this.
        comptime_bits: u32,
        /// Tells whether a parameter is noalias. See `paramIsNoalias` helper
        /// method for accessing this.
        noalias_bits: u32,
        cc: std.builtin.CallingConvention,
        is_var_args: bool,
        is_generic: bool,
        is_noinline: bool,
        cc_is_generic: bool,
        section_is_generic: bool,
        addrspace_is_generic: bool,

        pub fn paramIsComptime(self: @This(), i: u5) bool {
            assert(i < self.param_types.len);
            return @as(u1, @truncate(self.comptime_bits >> i)) != 0;
        }

        pub fn paramIsNoalias(self: @This(), i: u5) bool {
            assert(i < self.param_types.len);
            return @as(u1, @truncate(self.noalias_bits >> i)) != 0;
        }

        pub fn eql(a: FuncType, b: FuncType, ip: *const InternPool) bool {
            return std.mem.eql(Index, a.param_types.get(ip), b.param_types.get(ip)) and
                a.return_type == b.return_type and
                a.comptime_bits == b.comptime_bits and
                a.noalias_bits == b.noalias_bits and
                a.cc == b.cc and
                a.is_var_args == b.is_var_args and
                a.is_generic == b.is_generic and
                a.is_noinline == b.is_noinline;
        }

        pub fn hash(self: FuncType, hasher: *Hash, ip: *const InternPool) void {
            for (self.param_types.get(ip)) |param_type| {
                std.hash.autoHash(hasher, param_type);
            }
            std.hash.autoHash(hasher, self.return_type);
            std.hash.autoHash(hasher, self.comptime_bits);
            std.hash.autoHash(hasher, self.noalias_bits);
            std.hash.autoHash(hasher, self.cc);
            std.hash.autoHash(hasher, self.is_var_args);
            std.hash.autoHash(hasher, self.is_generic);
            std.hash.autoHash(hasher, self.is_noinline);
        }
    };

    pub const Variable = struct {
        ty: Index,
        init: Index,
        decl: DeclIndex,
        lib_name: OptionalNullTerminatedString,
        is_extern: bool,
        is_const: bool,
        is_threadlocal: bool,
        is_weak_linkage: bool,
    };

    pub const ExternFunc = struct {
        ty: Index,
        /// The Decl that corresponds to the function itself.
        decl: DeclIndex,
        /// Library name if specified.
        /// For example `extern "c" fn write(...) usize` would have 'c' as library name.
        /// Index into the string table bytes.
        lib_name: OptionalNullTerminatedString,
    };

    pub const Func = struct {
        tid: Zcu.PerThread.Id,
        /// In the case of a generic function, this type will potentially have fewer parameters
        /// than the generic owner's type, because the comptime parameters will be deleted.
        ty: Index,
        /// If this is a function body that has been coerced to a different type, for example
        /// ```
        /// fn f2() !void {}
        /// const f: fn()anyerror!void = f2;
        /// ```
        /// then it contains the original type of the function body.
        uncoerced_ty: Index,
        /// Index into extra array of the `FuncAnalysis` corresponding to this function.
        /// Used for mutating that data.
        analysis_extra_index: u32,
        /// Index into extra array of the `zir_body_inst` corresponding to this function.
        /// Used for mutating that data.
        zir_body_inst_extra_index: u32,
        /// Index into extra array of the resolved inferred error set for this function.
        /// Used for mutating that data.
        /// 0 when the function does not have an inferred error set.
        resolved_error_set_extra_index: u32,
        /// When a generic function is instantiated, branch_quota is inherited from the
        /// active Sema context. Importantly, this value is also updated when an existing
        /// generic function instantiation is found and called.
        /// This field contains the index into the extra array of this value,
        /// so that it can be mutated.
        /// This will be 0 when the function is not a generic function instantiation.
        branch_quota_extra_index: u32,
        /// The Decl that corresponds to the function itself.
        owner_decl: DeclIndex,
        /// The ZIR instruction that is a function instruction. Use this to find
        /// the body. We store this rather than the body directly so that when ZIR
        /// is regenerated on update(), we can map this to the new corresponding
        /// ZIR instruction.
        zir_body_inst: TrackedInst.Index,
        /// Relative to owner Decl.
        lbrace_line: u32,
        /// Relative to owner Decl.
        rbrace_line: u32,
        lbrace_column: u32,
        rbrace_column: u32,

        /// The `func_decl` which is the generic function from whence this instance was spawned.
        /// If this is `none` it means the function is not a generic instantiation.
        generic_owner: Index,
        /// If this is a generic function instantiation, this will be non-empty.
        /// Corresponds to the parameters of the `generic_owner` type, which
        /// may have more parameters than `ty`.
        /// Each element is the comptime-known value the generic function was instantiated with,
        /// or `none` if the element is runtime-known.
        /// TODO: as a follow-up optimization, don't store `none` values here since that data
        /// is redundant with `comptime_bits` stored elsewhere.
        comptime_args: Index.Slice,

        /// Returns a pointer that becomes invalid after any additions to the `InternPool`.
        pub fn analysis(func: *const Func, ip: *const InternPool) *FuncAnalysis {
            const extra = ip.getLocalShared(func.tid).extra.acquire();
            return @ptrCast(&extra.view().items(.@"0")[func.analysis_extra_index]);
        }

        /// Returns a pointer that becomes invalid after any additions to the `InternPool`.
        pub fn zirBodyInst(func: *const Func, ip: *const InternPool) *TrackedInst.Index {
            const extra = ip.getLocalShared(func.tid).extra.acquire();
            return @ptrCast(&extra.view().items(.@"0")[func.zir_body_inst_extra_index]);
        }

        /// Returns a pointer that becomes invalid after any additions to the `InternPool`.
        pub fn branchQuota(func: *const Func, ip: *const InternPool) *u32 {
            const extra = ip.getLocalShared(func.tid).extra.acquire();
            return &extra.view().items(.@"0")[func.branch_quota_extra_index];
        }

        /// Returns a pointer that becomes invalid after any additions to the `InternPool`.
        pub fn resolvedErrorSet(func: *const Func, ip: *const InternPool) *Index {
            const extra = ip.getLocalShared(func.tid).extra.acquire();
            assert(func.analysis(ip).inferred_error_set);
            return @ptrCast(&extra.view().items(.@"0")[func.resolved_error_set_extra_index]);
        }
    };

    pub const Int = struct {
        ty: Index,
        storage: Storage,

        pub const Storage = union(enum) {
            u64: u64,
            i64: i64,
            big_int: BigIntConst,
            lazy_align: Index,
            lazy_size: Index,

            /// Big enough to fit any non-BigInt value
            pub const BigIntSpace = struct {
                /// The +1 is headroom so that operations such as incrementing once
                /// or decrementing once are possible without using an allocator.
                limbs: [(@sizeOf(u64) / @sizeOf(std.math.big.Limb)) + 1]std.math.big.Limb,
            };

            pub fn toBigInt(storage: Storage, space: *BigIntSpace) BigIntConst {
                return switch (storage) {
                    .big_int => |x| x,
                    inline .u64, .i64 => |x| BigIntMutable.init(&space.limbs, x).toConst(),
                    .lazy_align, .lazy_size => unreachable,
                };
            }
        };
    };

    pub const Error = extern struct {
        ty: Index,
        name: NullTerminatedString,
    };

    pub const ErrorUnion = struct {
        ty: Index,
        val: Value,

        pub const Value = union(enum) {
            err_name: NullTerminatedString,
            payload: Index,
        };
    };

    pub const EnumTag = extern struct {
        /// The enum type.
        ty: Index,
        /// The integer tag value which has the integer tag type of the enum.
        int: Index,
    };

    pub const Float = struct {
        ty: Index,
        /// The storage used must match the size of the float type being represented.
        storage: Storage,

        pub const Storage = union(enum) {
            f16: f16,
            f32: f32,
            f64: f64,
            f80: f80,
            f128: f128,
        };
    };

    pub const Ptr = struct {
        /// This is the pointer type, not the element type.
        ty: Index,
        /// The base address which this pointer is offset from.
        base_addr: BaseAddr,
        /// The offset of this pointer from `base_addr` in bytes.
        byte_offset: u64,

        pub const BaseAddr = union(enum) {
            const Tag = @typeInfo(BaseAddr).Union.tag_type.?;

            /// Points to the value of a single `Decl`, which may be constant or a `variable`.
            decl: DeclIndex,

            /// Points to the value of a single comptime alloc stored in `Sema`.
            comptime_alloc: ComptimeAllocIndex,

            /// Points to a single unnamed constant value.
            anon_decl: AnonDecl,

            /// Points to a comptime field of a struct. Index is the field's value.
            ///
            /// TODO: this exists because these fields are semantically mutable. We
            /// should probably change the language so that this isn't the case.
            comptime_field: Index,

            /// A pointer with a fixed integer address, usually from `@ptrFromInt`.
            ///
            /// The address is stored entirely by `byte_offset`, which will be positive
            /// and in-range of a `usize`. The base address is, for all intents and purposes, 0.
            int,

            /// A pointer to the payload of an error union. Index is the error union pointer.
            /// To ensure a canonical representation, the type of the base pointer must:
            /// * be a one-pointer
            /// * be `const`, `volatile` and `allowzero`
            /// * have alignment 1
            /// * have the same address space as this pointer
            /// * have a host size, bit offset, and vector index of 0
            /// See `Value.canonicalizeBasePtr` which enforces these properties.
            eu_payload: Index,

            /// A pointer to the payload of a non-pointer-like optional. Index is the
            /// optional pointer. To ensure a canonical representation, the base
            /// pointer is subject to the same restrictions as in `eu_payload`.
            opt_payload: Index,

            /// A pointer to a field of a slice, or of an auto-layout struct or union. Slice fields
            /// are referenced according to `Value.slice_ptr_index` and `Value.slice_len_index`.
            /// Base is the aggregate pointer, which is subject to the same restrictions as
            /// in `eu_payload`.
            field: BaseIndex,

            /// A pointer to an element of a comptime-only array. Base is the
            /// many-pointer we are indexing into. It is subject to the same restrictions
            /// as in `eu_payload`, except it must be a many-pointer rather than a one-pointer.
            ///
            /// The element type of the base pointer must NOT be an array. Additionally, the
            /// base pointer is guaranteed to not be an `arr_elem` into a pointer with the
            /// same child type. Thus, since there are no two comptime-only types which are
            /// IMC to one another, the only case where the base pointer may also be an
            /// `arr_elem` is when this pointer is semantically invalid (e.g. it reinterprets
            /// a `type` as a `comptime_int`). These restrictions are in place to ensure
            /// a canonical representation.
            ///
            /// This kind of base address differs from others in that it may refer to any
            /// sequence of values; for instance, an `arr_elem` at index 2 may refer to
            /// any number of elements starting from index 2.
            ///
            /// Index must not be 0. To refer to the element at index 0, simply reinterpret
            /// the aggregate pointer.
            arr_elem: BaseIndex,

            pub const MutDecl = struct {
                decl: DeclIndex,
                runtime_index: RuntimeIndex,
            };
            pub const BaseIndex = struct {
                base: Index,
                index: u64,
            };
            pub const AnonDecl = extern struct {
                val: Index,
                /// Contains the canonical pointer type of the anonymous
                /// declaration. This may equal `ty` of the `Ptr` or it may be
                /// different. Importantly, when lowering the anonymous decl,
                /// the original pointer type alignment must be used.
                orig_ty: Index,
            };
        };
    };

    pub const Slice = struct {
        /// This is the slice type, not the element type.
        ty: Index,
        /// The slice's `ptr` field. Must be a many-ptr with the same properties as `ty`.
        ptr: Index,
        /// The slice's `len` field. Must be a `usize`.
        len: Index,
    };

    /// `null` is represented by the `val` field being `none`.
    pub const Opt = extern struct {
        /// This is the optional type; not the payload type.
        ty: Index,
        /// This could be `none`, indicating the optional is `null`.
        val: Index,
    };

    pub const Union = extern struct {
        /// This is the union type; not the field type.
        ty: Index,
        /// Indicates the active field. This could be `none`, which indicates the tag is not known. `none` is only a valid value for extern and packed unions.
        /// In those cases, the type of `val` is:
        ///   extern: a u8 array of the same byte length as the union
        ///   packed: an unsigned integer with the same bit size as the union
        tag: Index,
        /// The value of the active field.
        val: Index,
    };

    pub const Aggregate = struct {
        ty: Index,
        storage: Storage,

        pub const Storage = union(enum) {
            bytes: String,
            elems: []const Index,
            repeated_elem: Index,

            pub fn values(self: *const Storage) []const Index {
                return switch (self.*) {
                    .bytes => &.{},
                    .elems => |elems| elems,
                    .repeated_elem => |*elem| @as(*const [1]Index, elem),
                };
            }
        };
    };

    pub const MemoizedCall = struct {
        func: Index,
        arg_values: []const Index,
        result: Index,
    };

    pub fn hash32(key: Key, ip: *const InternPool) u32 {
        return @truncate(key.hash64(ip));
    }

    pub fn hash64(key: Key, ip: *const InternPool) u64 {
        const asBytes = std.mem.asBytes;
        const KeyTag = @typeInfo(Key).Union.tag_type.?;
        const seed = @intFromEnum(@as(KeyTag, key));
        return switch (key) {
            // TODO: assert no padding in these types
            inline .ptr_type,
            .array_type,
            .vector_type,
            .opt_type,
            .anyframe_type,
            .error_union_type,
            .simple_type,
            .simple_value,
            .opt,
            .undef,
            .err,
            .enum_literal,
            .enum_tag,
            .empty_enum_value,
            .inferred_error_set_type,
            .un,
            => |x| Hash.hash(seed, asBytes(&x)),

            .int_type => |x| Hash.hash(seed + @intFromEnum(x.signedness), asBytes(&x.bits)),

            .error_union => |x| switch (x.val) {
                .err_name => |y| Hash.hash(seed + 0, asBytes(&x.ty) ++ asBytes(&y)),
                .payload => |y| Hash.hash(seed + 1, asBytes(&x.ty) ++ asBytes(&y)),
            },

            .variable => |variable| Hash.hash(seed, asBytes(&variable.decl)),

            .opaque_type,
            .enum_type,
            .union_type,
            .struct_type,
            => |namespace_type| {
                var hasher = Hash.init(seed);
                std.hash.autoHash(&hasher, std.meta.activeTag(namespace_type));
                switch (namespace_type) {
                    .declared => |declared| {
                        std.hash.autoHash(&hasher, declared.zir_index);
                        const captures = switch (declared.captures) {
                            .owned => |cvs| cvs.get(ip),
                            .external => |cvs| cvs,
                        };
                        for (captures) |cv| {
                            std.hash.autoHash(&hasher, cv);
                        }
                    },
                    .generated_tag => |generated_tag| {
                        std.hash.autoHash(&hasher, generated_tag.union_type);
                    },
                    .reified => |reified| {
                        std.hash.autoHash(&hasher, reified.zir_index);
                        std.hash.autoHash(&hasher, reified.type_hash);
                    },
                    .empty_struct => {},
                }
                return hasher.final();
            },

            .int => |int| {
                var hasher = Hash.init(seed);
                // Canonicalize all integers by converting them to BigIntConst.
                switch (int.storage) {
                    .u64, .i64, .big_int => {
                        var buffer: Key.Int.Storage.BigIntSpace = undefined;
                        const big_int = int.storage.toBigInt(&buffer);

                        std.hash.autoHash(&hasher, int.ty);
                        std.hash.autoHash(&hasher, big_int.positive);
                        for (big_int.limbs) |limb| std.hash.autoHash(&hasher, limb);
                    },
                    .lazy_align, .lazy_size => |lazy_ty| {
                        std.hash.autoHash(
                            &hasher,
                            @as(@typeInfo(Key.Int.Storage).Union.tag_type.?, int.storage),
                        );
                        std.hash.autoHash(&hasher, lazy_ty);
                    },
                }
                return hasher.final();
            },

            .float => |float| {
                var hasher = Hash.init(seed);
                std.hash.autoHash(&hasher, float.ty);
                switch (float.storage) {
                    inline else => |val| std.hash.autoHash(
                        &hasher,
                        @as(std.meta.Int(.unsigned, @bitSizeOf(@TypeOf(val))), @bitCast(val)),
                    ),
                }
                return hasher.final();
            },

            .slice => |slice| Hash.hash(seed, asBytes(&slice.ty) ++ asBytes(&slice.ptr) ++ asBytes(&slice.len)),

            .ptr => |ptr| {
                // Int-to-ptr pointers are hashed separately than decl-referencing pointers.
                // This is sound due to pointer provenance rules.
                const addr_tag: Key.Ptr.BaseAddr.Tag = ptr.base_addr;
                const seed2 = seed + @intFromEnum(addr_tag);
                const big_offset: i128 = ptr.byte_offset;
                const common = asBytes(&ptr.ty) ++ asBytes(&big_offset);
                return switch (ptr.base_addr) {
                    inline .decl,
                    .comptime_alloc,
                    .anon_decl,
                    .int,
                    .eu_payload,
                    .opt_payload,
                    .comptime_field,
                    => |x| Hash.hash(seed2, common ++ asBytes(&x)),

                    .arr_elem, .field => |x| Hash.hash(
                        seed2,
                        common ++ asBytes(&x.base) ++ asBytes(&x.index),
                    ),
                };
            },

            .aggregate => |aggregate| {
                var hasher = Hash.init(seed);
                std.hash.autoHash(&hasher, aggregate.ty);
                const len = ip.aggregateTypeLen(aggregate.ty);
                const child = switch (ip.indexToKey(aggregate.ty)) {
                    .array_type => |array_type| array_type.child,
                    .vector_type => |vector_type| vector_type.child,
                    .anon_struct_type, .struct_type => .none,
                    else => unreachable,
                };

                if (child == .u8_type) {
                    switch (aggregate.storage) {
                        .bytes => |bytes| for (bytes.toSlice(len, ip)) |byte| {
                            std.hash.autoHash(&hasher, KeyTag.int);
                            std.hash.autoHash(&hasher, byte);
                        },
                        .elems => |elems| for (elems[0..@intCast(len)]) |elem| {
                            const elem_key = ip.indexToKey(elem);
                            std.hash.autoHash(&hasher, @as(KeyTag, elem_key));
                            switch (elem_key) {
                                .undef => {},
                                .int => |int| std.hash.autoHash(
                                    &hasher,
                                    @as(u8, @intCast(int.storage.u64)),
                                ),
                                else => unreachable,
                            }
                        },
                        .repeated_elem => |elem| {
                            const elem_key = ip.indexToKey(elem);
                            var remaining = len;
                            while (remaining > 0) : (remaining -= 1) {
                                std.hash.autoHash(&hasher, @as(KeyTag, elem_key));
                                switch (elem_key) {
                                    .undef => {},
                                    .int => |int| std.hash.autoHash(
                                        &hasher,
                                        @as(u8, @intCast(int.storage.u64)),
                                    ),
                                    else => unreachable,
                                }
                            }
                        },
                    }
                    return hasher.final();
                }

                switch (aggregate.storage) {
                    .bytes => unreachable,
                    .elems => |elems| for (elems[0..@intCast(len)]) |elem|
                        std.hash.autoHash(&hasher, elem),
                    .repeated_elem => |elem| {
                        var remaining = len;
                        while (remaining > 0) : (remaining -= 1) std.hash.autoHash(&hasher, elem);
                    },
                }
                return hasher.final();
            },

            .error_set_type => |x| Hash.hash(seed, std.mem.sliceAsBytes(x.names.get(ip))),

            .anon_struct_type => |anon_struct_type| {
                var hasher = Hash.init(seed);
                for (anon_struct_type.types.get(ip)) |elem| std.hash.autoHash(&hasher, elem);
                for (anon_struct_type.values.get(ip)) |elem| std.hash.autoHash(&hasher, elem);
                for (anon_struct_type.names.get(ip)) |elem| std.hash.autoHash(&hasher, elem);
                return hasher.final();
            },

            .func_type => |func_type| {
                var hasher = Hash.init(seed);
                func_type.hash(&hasher, ip);
                return hasher.final();
            },

            .memoized_call => |memoized_call| {
                var hasher = Hash.init(seed);
                std.hash.autoHash(&hasher, memoized_call.func);
                for (memoized_call.arg_values) |arg| std.hash.autoHash(&hasher, arg);
                return hasher.final();
            },

            .func => |func| {
                // In the case of a function with an inferred error set, we
                // must not include the inferred error set type in the hash,
                // otherwise we would get false negatives for interning generic
                // function instances which have inferred error sets.

                if (func.generic_owner == .none and func.resolved_error_set_extra_index == 0) {
                    const bytes = asBytes(&func.owner_decl) ++ asBytes(&func.ty) ++
                        [1]u8{@intFromBool(func.uncoerced_ty == func.ty)};
                    return Hash.hash(seed, bytes);
                }

                var hasher = Hash.init(seed);
                std.hash.autoHash(&hasher, func.generic_owner);
                std.hash.autoHash(&hasher, func.uncoerced_ty == func.ty);
                for (func.comptime_args.get(ip)) |arg| std.hash.autoHash(&hasher, arg);
                if (func.resolved_error_set_extra_index == 0) {
                    std.hash.autoHash(&hasher, func.ty);
                } else {
                    var ty_info = ip.indexToFuncType(func.ty).?;
                    ty_info.return_type = ip.errorUnionPayload(ty_info.return_type);
                    ty_info.hash(&hasher, ip);
                }
                return hasher.final();
            },

            .extern_func => |x| Hash.hash(seed, asBytes(&x.ty) ++ asBytes(&x.decl)),
        };
    }

    pub fn eql(a: Key, b: Key, ip: *const InternPool) bool {
        const KeyTag = @typeInfo(Key).Union.tag_type.?;
        const a_tag: KeyTag = a;
        const b_tag: KeyTag = b;
        if (a_tag != b_tag) return false;
        switch (a) {
            .int_type => |a_info| {
                const b_info = b.int_type;
                return std.meta.eql(a_info, b_info);
            },
            .ptr_type => |a_info| {
                const b_info = b.ptr_type;
                return std.meta.eql(a_info, b_info);
            },
            .array_type => |a_info| {
                const b_info = b.array_type;
                return std.meta.eql(a_info, b_info);
            },
            .vector_type => |a_info| {
                const b_info = b.vector_type;
                return std.meta.eql(a_info, b_info);
            },
            .opt_type => |a_info| {
                const b_info = b.opt_type;
                return a_info == b_info;
            },
            .anyframe_type => |a_info| {
                const b_info = b.anyframe_type;
                return a_info == b_info;
            },
            .error_union_type => |a_info| {
                const b_info = b.error_union_type;
                return std.meta.eql(a_info, b_info);
            },
            .simple_type => |a_info| {
                const b_info = b.simple_type;
                return a_info == b_info;
            },
            .simple_value => |a_info| {
                const b_info = b.simple_value;
                return a_info == b_info;
            },
            .undef => |a_info| {
                const b_info = b.undef;
                return a_info == b_info;
            },
            .opt => |a_info| {
                const b_info = b.opt;
                return std.meta.eql(a_info, b_info);
            },
            .un => |a_info| {
                const b_info = b.un;
                return std.meta.eql(a_info, b_info);
            },
            .err => |a_info| {
                const b_info = b.err;
                return std.meta.eql(a_info, b_info);
            },
            .error_union => |a_info| {
                const b_info = b.error_union;
                return std.meta.eql(a_info, b_info);
            },
            .enum_literal => |a_info| {
                const b_info = b.enum_literal;
                return a_info == b_info;
            },
            .enum_tag => |a_info| {
                const b_info = b.enum_tag;
                return std.meta.eql(a_info, b_info);
            },
            .empty_enum_value => |a_info| {
                const b_info = b.empty_enum_value;
                return a_info == b_info;
            },

            .variable => |a_info| {
                const b_info = b.variable;
                return a_info.decl == b_info.decl;
            },
            .extern_func => |a_info| {
                const b_info = b.extern_func;
                return a_info.ty == b_info.ty and a_info.decl == b_info.decl;
            },
            .func => |a_info| {
                const b_info = b.func;

                if (a_info.generic_owner != b_info.generic_owner)
                    return false;

                if (a_info.generic_owner == .none) {
                    if (a_info.owner_decl != b_info.owner_decl)
                        return false;
                } else {
                    if (!std.mem.eql(
                        Index,
                        a_info.comptime_args.get(ip),
                        b_info.comptime_args.get(ip),
                    )) return false;
                }

                if ((a_info.ty == a_info.uncoerced_ty) !=
                    (b_info.ty == b_info.uncoerced_ty))
                {
                    return false;
                }

                if (a_info.ty == b_info.ty)
                    return true;

                // There is one case where the types may be inequal but we
                // still want to find the same function body instance. In the
                // case of the functions having an inferred error set, the key
                // used to find an existing function body will necessarily have
                // a unique inferred error set type, because it refers to the
                // function body InternPool Index. To make this case work we
                // omit the inferred error set from the equality check.
                if (a_info.resolved_error_set_extra_index == 0 or
                    b_info.resolved_error_set_extra_index == 0)
                {
                    return false;
                }
                var a_ty_info = ip.indexToFuncType(a_info.ty).?;
                a_ty_info.return_type = ip.errorUnionPayload(a_ty_info.return_type);
                var b_ty_info = ip.indexToFuncType(b_info.ty).?;
                b_ty_info.return_type = ip.errorUnionPayload(b_ty_info.return_type);
                return a_ty_info.eql(b_ty_info, ip);
            },

            .slice => |a_info| {
                const b_info = b.slice;
                if (a_info.ty != b_info.ty) return false;
                if (a_info.ptr != b_info.ptr) return false;
                if (a_info.len != b_info.len) return false;
                return true;
            },

            .ptr => |a_info| {
                const b_info = b.ptr;
                if (a_info.ty != b_info.ty) return false;
                if (a_info.byte_offset != b_info.byte_offset) return false;

                if (@as(Key.Ptr.BaseAddr.Tag, a_info.base_addr) != @as(Key.Ptr.BaseAddr.Tag, b_info.base_addr)) return false;

                return switch (a_info.base_addr) {
                    .decl => |a_decl| a_decl == b_info.base_addr.decl,
                    .comptime_alloc => |a_alloc| a_alloc == b_info.base_addr.comptime_alloc,
                    .anon_decl => |ad| ad.val == b_info.base_addr.anon_decl.val and
                        ad.orig_ty == b_info.base_addr.anon_decl.orig_ty,
                    .int => true,
                    .eu_payload => |a_eu_payload| a_eu_payload == b_info.base_addr.eu_payload,
                    .opt_payload => |a_opt_payload| a_opt_payload == b_info.base_addr.opt_payload,
                    .comptime_field => |a_comptime_field| a_comptime_field == b_info.base_addr.comptime_field,
                    .arr_elem => |a_elem| std.meta.eql(a_elem, b_info.base_addr.arr_elem),
                    .field => |a_field| std.meta.eql(a_field, b_info.base_addr.field),
                };
            },

            .int => |a_info| {
                const b_info = b.int;

                if (a_info.ty != b_info.ty)
                    return false;

                return switch (a_info.storage) {
                    .u64 => |aa| switch (b_info.storage) {
                        .u64 => |bb| aa == bb,
                        .i64 => |bb| aa == bb,
                        .big_int => |bb| bb.orderAgainstScalar(aa) == .eq,
                        .lazy_align, .lazy_size => false,
                    },
                    .i64 => |aa| switch (b_info.storage) {
                        .u64 => |bb| aa == bb,
                        .i64 => |bb| aa == bb,
                        .big_int => |bb| bb.orderAgainstScalar(aa) == .eq,
                        .lazy_align, .lazy_size => false,
                    },
                    .big_int => |aa| switch (b_info.storage) {
                        .u64 => |bb| aa.orderAgainstScalar(bb) == .eq,
                        .i64 => |bb| aa.orderAgainstScalar(bb) == .eq,
                        .big_int => |bb| aa.eql(bb),
                        .lazy_align, .lazy_size => false,
                    },
                    .lazy_align => |aa| switch (b_info.storage) {
                        .u64, .i64, .big_int, .lazy_size => false,
                        .lazy_align => |bb| aa == bb,
                    },
                    .lazy_size => |aa| switch (b_info.storage) {
                        .u64, .i64, .big_int, .lazy_align => false,
                        .lazy_size => |bb| aa == bb,
                    },
                };
            },

            .float => |a_info| {
                const b_info = b.float;

                if (a_info.ty != b_info.ty)
                    return false;

                if (a_info.ty == .c_longdouble_type and a_info.storage != .f80) {
                    // These are strange: we'll sometimes represent them as f128, even if the
                    // underlying type is smaller. f80 is an exception: see float_c_longdouble_f80.
                    const a_val: u128 = switch (a_info.storage) {
                        inline else => |val| @bitCast(@as(f128, @floatCast(val))),
                    };
                    const b_val: u128 = switch (b_info.storage) {
                        inline else => |val| @bitCast(@as(f128, @floatCast(val))),
                    };
                    return a_val == b_val;
                }

                const StorageTag = @typeInfo(Key.Float.Storage).Union.tag_type.?;
                assert(@as(StorageTag, a_info.storage) == @as(StorageTag, b_info.storage));

                switch (a_info.storage) {
                    inline else => |val, tag| {
                        const Bits = std.meta.Int(.unsigned, @bitSizeOf(@TypeOf(val)));
                        const a_bits: Bits = @bitCast(val);
                        const b_bits: Bits = @bitCast(@field(b_info.storage, @tagName(tag)));
                        return a_bits == b_bits;
                    },
                }
            },

            inline .opaque_type, .enum_type, .union_type, .struct_type => |a_info, a_tag_ct| {
                const b_info = @field(b, @tagName(a_tag_ct));
                if (std.meta.activeTag(a_info) != b_info) return false;
                switch (a_info) {
                    .declared => |a_d| {
                        const b_d = b_info.declared;
                        if (a_d.zir_index != b_d.zir_index) return false;
                        const a_captures = switch (a_d.captures) {
                            .owned => |s| s.get(ip),
                            .external => |cvs| cvs,
                        };
                        const b_captures = switch (b_d.captures) {
                            .owned => |s| s.get(ip),
                            .external => |cvs| cvs,
                        };
                        return std.mem.eql(u32, @ptrCast(a_captures), @ptrCast(b_captures));
                    },
                    .generated_tag => |a_gt| return a_gt.union_type == b_info.generated_tag.union_type,
                    .reified => |a_r| {
                        const b_r = b_info.reified;
                        return a_r.zir_index == b_r.zir_index and
                            a_r.type_hash == b_r.type_hash;
                    },
                    .empty_struct => return true,
                }
            },
            .aggregate => |a_info| {
                const b_info = b.aggregate;
                if (a_info.ty != b_info.ty) return false;

                const len = ip.aggregateTypeLen(a_info.ty);
                const StorageTag = @typeInfo(Key.Aggregate.Storage).Union.tag_type.?;
                if (@as(StorageTag, a_info.storage) != @as(StorageTag, b_info.storage)) {
                    for (0..@intCast(len)) |elem_index| {
                        const a_elem = switch (a_info.storage) {
                            .bytes => |bytes| ip.getIfExists(.{ .int = .{
                                .ty = .u8_type,
                                .storage = .{ .u64 = bytes.at(elem_index, ip) },
                            } }) orelse return false,
                            .elems => |elems| elems[elem_index],
                            .repeated_elem => |elem| elem,
                        };
                        const b_elem = switch (b_info.storage) {
                            .bytes => |bytes| ip.getIfExists(.{ .int = .{
                                .ty = .u8_type,
                                .storage = .{ .u64 = bytes.at(elem_index, ip) },
                            } }) orelse return false,
                            .elems => |elems| elems[elem_index],
                            .repeated_elem => |elem| elem,
                        };
                        if (a_elem != b_elem) return false;
                    }
                    return true;
                }

                switch (a_info.storage) {
                    .bytes => |a_bytes| {
                        const b_bytes = b_info.storage.bytes;
                        return a_bytes == b_bytes or
                            std.mem.eql(u8, a_bytes.toSlice(len, ip), b_bytes.toSlice(len, ip));
                    },
                    .elems => |a_elems| {
                        const b_elems = b_info.storage.elems;
                        return std.mem.eql(
                            Index,
                            a_elems[0..@intCast(len)],
                            b_elems[0..@intCast(len)],
                        );
                    },
                    .repeated_elem => |a_elem| {
                        const b_elem = b_info.storage.repeated_elem;
                        return a_elem == b_elem;
                    },
                }
            },
            .anon_struct_type => |a_info| {
                const b_info = b.anon_struct_type;
                return std.mem.eql(Index, a_info.types.get(ip), b_info.types.get(ip)) and
                    std.mem.eql(Index, a_info.values.get(ip), b_info.values.get(ip)) and
                    std.mem.eql(NullTerminatedString, a_info.names.get(ip), b_info.names.get(ip));
            },
            .error_set_type => |a_info| {
                const b_info = b.error_set_type;
                return std.mem.eql(NullTerminatedString, a_info.names.get(ip), b_info.names.get(ip));
            },
            .inferred_error_set_type => |a_info| {
                const b_info = b.inferred_error_set_type;
                return a_info == b_info;
            },

            .func_type => |a_info| {
                const b_info = b.func_type;
                return Key.FuncType.eql(a_info, b_info, ip);
            },

            .memoized_call => |a_info| {
                const b_info = b.memoized_call;
                return a_info.func == b_info.func and
                    std.mem.eql(Index, a_info.arg_values, b_info.arg_values);
            },
        }
    }

    pub fn typeOf(key: Key) Index {
        return switch (key) {
            .int_type,
            .ptr_type,
            .array_type,
            .vector_type,
            .opt_type,
            .anyframe_type,
            .error_union_type,
            .error_set_type,
            .inferred_error_set_type,
            .simple_type,
            .struct_type,
            .union_type,
            .opaque_type,
            .enum_type,
            .anon_struct_type,
            .func_type,
            => .type_type,

            inline .ptr,
            .slice,
            .int,
            .float,
            .opt,
            .variable,
            .extern_func,
            .func,
            .err,
            .error_union,
            .enum_tag,
            .aggregate,
            .un,
            => |x| x.ty,

            .enum_literal => .enum_literal_type,

            .undef => |x| x,
            .empty_enum_value => |x| x,

            .simple_value => |s| switch (s) {
                .undefined => .undefined_type,
                .void => .void_type,
                .null => .null_type,
                .false, .true => .bool_type,
                .empty_struct => .empty_struct_type,
                .@"unreachable" => .noreturn_type,
                .generic_poison => .generic_poison_type,
            },

            .memoized_call => unreachable,
        };
    }
};

pub const RequiresComptime = enum(u2) { no, yes, unknown, wip };

// Unlike `Tag.TypeUnion` which is an encoding, and `Key.UnionType` which is a
// minimal hashmap key, this type is a convenience type that contains info
// needed by semantic analysis.
pub const LoadedUnionType = struct {
    tid: Zcu.PerThread.Id,
    /// The index of the `Tag.TypeUnion` payload.
    extra_index: u32,
    /// The Decl that corresponds to the union itself.
    decl: DeclIndex,
    /// Represents the declarations inside this union.
    namespace: OptionalNamespaceIndex,
    /// The enum tag type.
    enum_tag_ty: Index,
    /// List of field types in declaration order.
    /// These are `none` until `status` is `have_field_types` or `have_layout`.
    field_types: Index.Slice,
    /// List of field alignments in declaration order.
    /// `none` means the ABI alignment of the type.
    /// If this slice has length 0 it means all elements are `none`.
    field_aligns: Alignment.Slice,
    /// Index of the union_decl or reify ZIR instruction.
    zir_index: TrackedInst.Index,
    captures: CaptureValue.Slice,

    pub const RuntimeTag = enum(u2) {
        none,
        safety,
        tagged,

        pub fn hasTag(self: RuntimeTag) bool {
            return switch (self) {
                .none => false,
                .tagged, .safety => true,
            };
        }
    };

    pub const Status = enum(u3) {
        none,
        field_types_wip,
        have_field_types,
        layout_wip,
        have_layout,
        fully_resolved_wip,
        /// The types and all its fields have had their layout resolved.
        /// Even through pointer, which `have_layout` does not ensure.
        fully_resolved,

        pub fn haveFieldTypes(status: Status) bool {
            return switch (status) {
                .none,
                .field_types_wip,
                => false,
                .have_field_types,
                .layout_wip,
                .have_layout,
                .fully_resolved_wip,
                .fully_resolved,
                => true,
            };
        }

        pub fn haveLayout(status: Status) bool {
            return switch (status) {
                .none,
                .field_types_wip,
                .have_field_types,
                .layout_wip,
                => false,
                .have_layout,
                .fully_resolved_wip,
                .fully_resolved,
                => true,
            };
        }
    };

    pub fn loadTagType(self: LoadedUnionType, ip: *const InternPool) LoadedEnumType {
        return ip.loadEnumType(self.enum_tag_ty);
    }

    /// Pointer to an enum type which is used for the tag of the union.
    /// This type is created even for untagged unions, even when the memory
    /// layout does not store the tag.
    /// Whether zig chooses this type or the user specifies it, it is stored here.
    /// This will be set to the null type until status is `have_field_types`.
    /// This accessor is provided so that the tag type can be mutated, and so that
    /// when it is mutated, the mutations are observed.
    /// The returned pointer expires with any addition to the `InternPool`.
    pub fn tagTypePtr(self: LoadedUnionType, ip: *const InternPool) *Index {
        const extra = ip.getLocalShared(self.tid).extra.acquire();
        const field_index = std.meta.fieldIndex(Tag.TypeUnion, "tag_ty").?;
        return @ptrCast(&extra.view().items(.@"0")[self.extra_index + field_index]);
    }

    /// The returned pointer expires with any addition to the `InternPool`.
    pub fn flagsPtr(self: LoadedUnionType, ip: *const InternPool) *Tag.TypeUnion.Flags {
        const extra = ip.getLocalShared(self.tid).extra.acquire();
        const field_index = std.meta.fieldIndex(Tag.TypeUnion, "flags").?;
        return @ptrCast(&extra.view().items(.@"0")[self.extra_index + field_index]);
    }

    /// The returned pointer expires with any addition to the `InternPool`.
    pub fn size(self: LoadedUnionType, ip: *const InternPool) *u32 {
        const extra = ip.getLocalShared(self.tid).extra.acquire();
        const field_index = std.meta.fieldIndex(Tag.TypeUnion, "size").?;
        return &extra.view().items(.@"0")[self.extra_index + field_index];
    }

    /// The returned pointer expires with any addition to the `InternPool`.
    pub fn padding(self: LoadedUnionType, ip: *const InternPool) *u32 {
        const extra = ip.getLocalShared(self.tid).extra.acquire();
        const field_index = std.meta.fieldIndex(Tag.TypeUnion, "padding").?;
        return &extra.view().items(.@"0")[self.extra_index + field_index];
    }

    pub fn hasTag(self: LoadedUnionType, ip: *const InternPool) bool {
        return self.flagsPtr(ip).runtime_tag.hasTag();
    }

    pub fn haveFieldTypes(self: LoadedUnionType, ip: *const InternPool) bool {
        return self.flagsPtr(ip).status.haveFieldTypes();
    }

    pub fn haveLayout(self: LoadedUnionType, ip: *const InternPool) bool {
        return self.flagsPtr(ip).status.haveLayout();
    }

    pub fn getLayout(self: LoadedUnionType, ip: *const InternPool) std.builtin.Type.ContainerLayout {
        return self.flagsPtr(ip).layout;
    }

    pub fn fieldAlign(self: LoadedUnionType, ip: *const InternPool, field_index: usize) Alignment {
        if (self.field_aligns.len == 0) return .none;
        return self.field_aligns.get(ip)[field_index];
    }

    /// This does not mutate the field of LoadedUnionType.
    pub fn setZirIndex(self: LoadedUnionType, ip: *InternPool, new_zir_index: TrackedInst.Index.Optional) void {
        const flags_field_index = std.meta.fieldIndex(Tag.TypeUnion, "flags").?;
        const zir_index_field_index = std.meta.fieldIndex(Tag.TypeUnion, "zir_index").?;
        const ptr: *TrackedInst.Index.Optional =
            @ptrCast(&ip.extra_.items[self.flags_index - flags_field_index + zir_index_field_index]);
        ptr.* = new_zir_index;
    }

    pub fn setFieldTypes(self: LoadedUnionType, ip: *const InternPool, types: []const Index) void {
        @memcpy(self.field_types.get(ip), types);
    }

    pub fn setFieldAligns(self: LoadedUnionType, ip: *const InternPool, aligns: []const Alignment) void {
        if (aligns.len == 0) return;
        assert(self.flagsPtr(ip).any_aligned_fields);
        @memcpy(self.field_aligns.get(ip), aligns);
    }
};

pub fn loadUnionType(ip: *const InternPool, index: Index) LoadedUnionType {
    const unwrapped_index = index.unwrap(ip);
    const extra_list = unwrapped_index.getExtra(ip);
    const data = unwrapped_index.getData(ip);
    const type_union = extraDataTrail(extra_list, Tag.TypeUnion, data);
    const fields_len = type_union.data.fields_len;

    var extra_index = type_union.end;
    const captures_len = if (type_union.data.flags.any_captures) c: {
        const len = extra_list.view().items(.@"0")[extra_index];
        extra_index += 1;
        break :c len;
    } else 0;

    const captures: CaptureValue.Slice = .{
        .tid = unwrapped_index.tid,
        .start = extra_index,
        .len = captures_len,
    };
    extra_index += captures_len;
    if (type_union.data.flags.is_reified) {
        extra_index += 2; // PackedU64
    }

    const field_types: Index.Slice = .{
        .tid = unwrapped_index.tid,
        .start = extra_index,
        .len = fields_len,
    };
    extra_index += fields_len;

    const field_aligns = if (type_union.data.flags.any_aligned_fields) a: {
        const a: Alignment.Slice = .{
            .tid = unwrapped_index.tid,
            .start = extra_index,
            .len = fields_len,
        };
        extra_index += std.math.divCeil(u32, fields_len, 4) catch unreachable;
        break :a a;
    } else Alignment.Slice.empty;

    return .{
        .tid = unwrapped_index.tid,
        .extra_index = data,
        .decl = type_union.data.decl,
        .namespace = type_union.data.namespace,
        .enum_tag_ty = type_union.data.tag_ty,
        .field_types = field_types,
        .field_aligns = field_aligns,
        .zir_index = type_union.data.zir_index,
        .captures = captures,
    };
}

pub const LoadedStructType = struct {
    tid: Zcu.PerThread.Id,
    /// The index of the `Tag.TypeStruct` or `Tag.TypeStructPacked` payload.
    extra_index: u32,
    /// The struct's owner Decl. `none` when the struct is `@TypeOf(.{})`.
    decl: OptionalDeclIndex,
    /// `none` when the struct has no declarations.
    namespace: OptionalNamespaceIndex,
    /// Index of the `struct_decl` or `reify` ZIR instruction.
    /// Only `none` when the struct is `@TypeOf(.{})`.
    zir_index: TrackedInst.Index.Optional,
    layout: std.builtin.Type.ContainerLayout,
    field_names: NullTerminatedString.Slice,
    field_types: Index.Slice,
    field_inits: Index.Slice,
    field_aligns: Alignment.Slice,
    runtime_order: RuntimeOrder.Slice,
    comptime_bits: ComptimeBits,
    offsets: Offsets,
    names_map: OptionalMapIndex,
    captures: CaptureValue.Slice,

    pub const ComptimeBits = struct {
        tid: Zcu.PerThread.Id,
        start: u32,
        /// This is the number of u32 elements, not the number of struct fields.
        len: u32,

        pub const empty: ComptimeBits = .{ .tid = .main, .start = 0, .len = 0 };

        pub fn get(this: ComptimeBits, ip: *const InternPool) []u32 {
            const extra = ip.getLocalShared(this.tid).extra.acquire();
            return extra.view().items(.@"0")[this.start..][0..this.len];
        }

        pub fn getBit(this: ComptimeBits, ip: *const InternPool, i: usize) bool {
            if (this.len == 0) return false;
            return @as(u1, @truncate(this.get(ip)[i / 32] >> @intCast(i % 32))) != 0;
        }

        pub fn setBit(this: ComptimeBits, ip: *const InternPool, i: usize) void {
            this.get(ip)[i / 32] |= @as(u32, 1) << @intCast(i % 32);
        }

        pub fn clearBit(this: ComptimeBits, ip: *const InternPool, i: usize) void {
            this.get(ip)[i / 32] &= ~(@as(u32, 1) << @intCast(i % 32));
        }
    };

    pub const Offsets = struct {
        tid: Zcu.PerThread.Id,
        start: u32,
        len: u32,

        pub const empty: Offsets = .{ .tid = .main, .start = 0, .len = 0 };

        pub fn get(this: Offsets, ip: *const InternPool) []u32 {
            const extra = ip.getLocalShared(this.tid).extra.acquire();
            return @ptrCast(extra.view().items(.@"0")[this.start..][0..this.len]);
        }
    };

    pub const RuntimeOrder = enum(u32) {
        /// Placeholder until layout is resolved.
        unresolved = std.math.maxInt(u32) - 0,
        /// Field not present at runtime
        omitted = std.math.maxInt(u32) - 1,
        _,

        pub const Slice = struct {
            tid: Zcu.PerThread.Id,
            start: u32,
            len: u32,

            pub const empty: Slice = .{ .tid = .main, .start = 0, .len = 0 };

            pub fn get(slice: RuntimeOrder.Slice, ip: *const InternPool) []RuntimeOrder {
                const extra = ip.getLocalShared(slice.tid).extra.acquire();
                return @ptrCast(extra.view().items(.@"0")[slice.start..][0..slice.len]);
            }
        };

        pub fn toInt(i: RuntimeOrder) ?u32 {
            return switch (i) {
                .omitted => null,
                .unresolved => unreachable,
                else => @intFromEnum(i),
            };
        }
    };

    /// Look up field index based on field name.
    pub fn nameIndex(self: LoadedStructType, ip: *const InternPool, name: NullTerminatedString) ?u32 {
        const names_map = self.names_map.unwrap() orelse {
            const i = name.toUnsigned(ip) orelse return null;
            if (i >= self.field_types.len) return null;
            return i;
        };
        const map = &ip.maps.items[@intFromEnum(names_map)];
        const adapter: NullTerminatedString.Adapter = .{ .strings = self.field_names.get(ip) };
        const field_index = map.getIndexAdapted(name, adapter) orelse return null;
        return @intCast(field_index);
    }

    /// Returns the already-existing field with the same name, if any.
    pub fn addFieldName(
        self: LoadedStructType,
        ip: *InternPool,
        name: NullTerminatedString,
    ) ?u32 {
        const extra = ip.getLocalShared(self.tid).extra.acquire();
        return ip.addFieldName(extra, self.names_map.unwrap().?, self.field_names.start, name);
    }

    pub fn fieldAlign(s: LoadedStructType, ip: *const InternPool, i: usize) Alignment {
        if (s.field_aligns.len == 0) return .none;
        return s.field_aligns.get(ip)[i];
    }

    pub fn fieldInit(s: LoadedStructType, ip: *InternPool, i: usize) Index {
        if (s.field_inits.len == 0) return .none;
        assert(s.haveFieldInits(ip));
        return s.field_inits.get(ip)[i];
    }

    /// Returns `none` in the case the struct is a tuple.
    pub fn fieldName(s: LoadedStructType, ip: *const InternPool, i: usize) OptionalNullTerminatedString {
        if (s.field_names.len == 0) return .none;
        return s.field_names.get(ip)[i].toOptional();
    }

    pub fn fieldIsComptime(s: LoadedStructType, ip: *const InternPool, i: usize) bool {
        return s.comptime_bits.getBit(ip, i);
    }

    pub fn setFieldComptime(s: LoadedStructType, ip: *InternPool, i: usize) void {
        s.comptime_bits.setBit(ip, i);
    }

    /// Reads the non-opv flag calculated during AstGen. Used to short-circuit more
    /// complicated logic.
    pub fn knownNonOpv(s: LoadedStructType, ip: *InternPool) bool {
        return switch (s.layout) {
            .@"packed" => false,
            .auto, .@"extern" => s.flagsPtr(ip).known_non_opv,
        };
    }

    /// The returned pointer expires with any addition to the `InternPool`.
    /// Asserts the struct is not packed.
    pub fn flagsPtr(self: LoadedStructType, ip: *InternPool) *Tag.TypeStruct.Flags {
        assert(self.layout != .@"packed");
        const extra = ip.getLocalShared(self.tid).extra.acquire();
        const flags_field_index = std.meta.fieldIndex(Tag.TypeStruct, "flags").?;
        return @ptrCast(&extra.view().items(.@"0")[self.extra_index + flags_field_index]);
    }

    /// The returned pointer expires with any addition to the `InternPool`.
    /// Asserts that the struct is packed.
    pub fn packedFlagsPtr(self: LoadedStructType, ip: *InternPool) *Tag.TypeStructPacked.Flags {
        assert(self.layout == .@"packed");
        const extra = ip.getLocalShared(self.tid).extra.acquire();
        const flags_field_index = std.meta.fieldIndex(Tag.TypeStructPacked, "flags").?;
        return @ptrCast(&extra.view().items(.@"0")[self.extra_index + flags_field_index]);
    }

    pub fn assumeRuntimeBitsIfFieldTypesWip(s: LoadedStructType, ip: *InternPool) bool {
        if (s.layout == .@"packed") return false;
        const flags_ptr = s.flagsPtr(ip);
        if (flags_ptr.field_types_wip) {
            flags_ptr.assumed_runtime_bits = true;
            return true;
        }
        return false;
    }

    pub fn setTypesWip(s: LoadedStructType, ip: *InternPool) bool {
        if (s.layout == .@"packed") return false;
        const flags_ptr = s.flagsPtr(ip);
        if (flags_ptr.field_types_wip) return true;
        flags_ptr.field_types_wip = true;
        return false;
    }

    pub fn clearTypesWip(s: LoadedStructType, ip: *InternPool) void {
        if (s.layout == .@"packed") return;
        s.flagsPtr(ip).field_types_wip = false;
    }

    pub fn setLayoutWip(s: LoadedStructType, ip: *InternPool) bool {
        if (s.layout == .@"packed") return false;
        const flags_ptr = s.flagsPtr(ip);
        if (flags_ptr.layout_wip) return true;
        flags_ptr.layout_wip = true;
        return false;
    }

    pub fn clearLayoutWip(s: LoadedStructType, ip: *InternPool) void {
        if (s.layout == .@"packed") return;
        s.flagsPtr(ip).layout_wip = false;
    }

    pub fn setAlignmentWip(s: LoadedStructType, ip: *InternPool) bool {
        if (s.layout == .@"packed") return false;
        const flags_ptr = s.flagsPtr(ip);
        if (flags_ptr.alignment_wip) return true;
        flags_ptr.alignment_wip = true;
        return false;
    }

    pub fn clearAlignmentWip(s: LoadedStructType, ip: *InternPool) void {
        if (s.layout == .@"packed") return;
        s.flagsPtr(ip).alignment_wip = false;
    }

    pub fn setInitsWip(s: LoadedStructType, ip: *InternPool) bool {
        switch (s.layout) {
            .@"packed" => {
                const flag = &s.packedFlagsPtr(ip).field_inits_wip;
                if (flag.*) return true;
                flag.* = true;
                return false;
            },
            .auto, .@"extern" => {
                const flag = &s.flagsPtr(ip).field_inits_wip;
                if (flag.*) return true;
                flag.* = true;
                return false;
            },
        }
    }

    pub fn clearInitsWip(s: LoadedStructType, ip: *InternPool) void {
        switch (s.layout) {
            .@"packed" => s.packedFlagsPtr(ip).field_inits_wip = false,
            .auto, .@"extern" => s.flagsPtr(ip).field_inits_wip = false,
        }
    }

    pub fn setFullyResolved(s: LoadedStructType, ip: *InternPool) bool {
        if (s.layout == .@"packed") return true;
        const flags_ptr = s.flagsPtr(ip);
        if (flags_ptr.fully_resolved) return true;
        flags_ptr.fully_resolved = true;
        return false;
    }

    pub fn clearFullyResolved(s: LoadedStructType, ip: *InternPool) void {
        s.flagsPtr(ip).fully_resolved = false;
    }

    /// The returned pointer expires with any addition to the `InternPool`.
    /// Asserts the struct is not packed.
    pub fn size(self: LoadedStructType, ip: *InternPool) *u32 {
        assert(self.layout != .@"packed");
        const extra = ip.getLocalShared(self.tid).extra.acquire();
        const size_field_index = std.meta.fieldIndex(Tag.TypeStruct, "size").?;
        return @ptrCast(&extra.view().items(.@"0")[self.extra_index + size_field_index]);
    }

    /// The backing integer type of the packed struct. Whether zig chooses
    /// this type or the user specifies it, it is stored here. This will be
    /// set to `none` until the layout is resolved.
    /// Asserts the struct is packed.
    pub fn backingIntType(s: LoadedStructType, ip: *InternPool) *Index {
        assert(s.layout == .@"packed");
        const extra = ip.getLocalShared(s.tid).extra.acquire();
        const field_index = std.meta.fieldIndex(Tag.TypeStructPacked, "backing_int_ty").?;
        return @ptrCast(&extra.view().items(.@"0")[s.extra_index + field_index]);
    }

    /// Asserts the struct is not packed.
    pub fn setZirIndex(s: LoadedStructType, ip: *InternPool, new_zir_index: TrackedInst.Index.Optional) void {
        assert(s.layout != .@"packed");
        const field_index = std.meta.fieldIndex(Tag.TypeStruct, "zir_index").?;
        ip.extra_.items[s.extra_index + field_index] = @intFromEnum(new_zir_index);
    }

    pub fn haveFieldTypes(s: LoadedStructType, ip: *const InternPool) bool {
        const types = s.field_types.get(ip);
        return types.len == 0 or types[0] != .none;
    }

    pub fn haveFieldInits(s: LoadedStructType, ip: *InternPool) bool {
        return switch (s.layout) {
            .@"packed" => s.packedFlagsPtr(ip).inits_resolved,
            .auto, .@"extern" => s.flagsPtr(ip).inits_resolved,
        };
    }

    pub fn setHaveFieldInits(s: LoadedStructType, ip: *InternPool) void {
        switch (s.layout) {
            .@"packed" => s.packedFlagsPtr(ip).inits_resolved = true,
            .auto, .@"extern" => s.flagsPtr(ip).inits_resolved = true,
        }
    }

    pub fn haveLayout(s: LoadedStructType, ip: *InternPool) bool {
        return switch (s.layout) {
            .@"packed" => s.backingIntType(ip).* != .none,
            .auto, .@"extern" => s.flagsPtr(ip).layout_resolved,
        };
    }

    pub fn isTuple(s: LoadedStructType, ip: *InternPool) bool {
        return s.layout != .@"packed" and s.flagsPtr(ip).is_tuple;
    }

    pub fn hasReorderedFields(s: LoadedStructType) bool {
        return s.layout == .auto;
    }

    pub const RuntimeOrderIterator = struct {
        ip: *InternPool,
        field_index: u32,
        struct_type: InternPool.LoadedStructType,

        pub fn next(it: *@This()) ?u32 {
            var i = it.field_index;

            if (i >= it.struct_type.field_types.len)
                return null;

            if (it.struct_type.hasReorderedFields()) {
                it.field_index += 1;
                return it.struct_type.runtime_order.get(it.ip)[i].toInt();
            }

            while (it.struct_type.fieldIsComptime(it.ip, i)) {
                i += 1;
                if (i >= it.struct_type.field_types.len)
                    return null;
            }

            it.field_index = i + 1;
            return i;
        }
    };

    /// Iterates over non-comptime fields in the order they are laid out in memory at runtime.
    /// May or may not include zero-bit fields.
    /// Asserts the struct is not packed.
    pub fn iterateRuntimeOrder(s: LoadedStructType, ip: *InternPool) RuntimeOrderIterator {
        assert(s.layout != .@"packed");
        return .{
            .ip = ip,
            .field_index = 0,
            .struct_type = s,
        };
    }

    pub const ReverseRuntimeOrderIterator = struct {
        ip: *InternPool,
        last_index: u32,
        struct_type: InternPool.LoadedStructType,

        pub fn next(it: *@This()) ?u32 {
            if (it.last_index == 0)
                return null;

            if (it.struct_type.hasReorderedFields()) {
                it.last_index -= 1;
                const order = it.struct_type.runtime_order.get(it.ip);
                while (order[it.last_index] == .omitted) {
                    it.last_index -= 1;
                    if (it.last_index == 0)
                        return null;
                }
                return order[it.last_index].toInt();
            }

            it.last_index -= 1;
            while (it.struct_type.fieldIsComptime(it.ip, it.last_index)) {
                it.last_index -= 1;
                if (it.last_index == 0)
                    return null;
            }

            return it.last_index;
        }
    };

    pub fn iterateRuntimeOrderReverse(s: LoadedStructType, ip: *InternPool) ReverseRuntimeOrderIterator {
        assert(s.layout != .@"packed");
        return .{
            .ip = ip,
            .last_index = s.field_types.len,
            .struct_type = s,
        };
    }
};

pub fn loadStructType(ip: *const InternPool, index: Index) LoadedStructType {
    const unwrapped_index = index.unwrap(ip);
    const extra_list = unwrapped_index.getExtra(ip);
    const item = unwrapped_index.getItem(ip);
    switch (item.tag) {
        .type_struct => {
            if (item.data == 0) return .{
                .tid = .main,
                .extra_index = 0,
                .decl = .none,
                .namespace = .none,
                .zir_index = .none,
                .layout = .auto,
                .field_names = NullTerminatedString.Slice.empty,
                .field_types = Index.Slice.empty,
                .field_inits = Index.Slice.empty,
                .field_aligns = Alignment.Slice.empty,
                .runtime_order = LoadedStructType.RuntimeOrder.Slice.empty,
                .comptime_bits = LoadedStructType.ComptimeBits.empty,
                .offsets = LoadedStructType.Offsets.empty,
                .names_map = .none,
                .captures = CaptureValue.Slice.empty,
            };
            const extra = extraDataTrail(extra_list, Tag.TypeStruct, item.data);
            const fields_len = extra.data.fields_len;
            var extra_index = extra.end;
            const captures_len = if (extra.data.flags.any_captures) c: {
                const len = extra_list.view().items(.@"0")[extra_index];
                extra_index += 1;
                break :c len;
            } else 0;
            const captures: CaptureValue.Slice = .{
                .tid = unwrapped_index.tid,
                .start = extra_index,
                .len = captures_len,
            };
            extra_index += captures_len;
            if (extra.data.flags.is_reified) {
                extra_index += 2; // PackedU64
            }
            const field_types: Index.Slice = .{
                .tid = unwrapped_index.tid,
                .start = extra_index,
                .len = fields_len,
            };
            extra_index += fields_len;
            const names_map: OptionalMapIndex, const names = if (!extra.data.flags.is_tuple) n: {
                const names_map: OptionalMapIndex = @enumFromInt(extra_list.view().items(.@"0")[extra_index]);
                extra_index += 1;
                const names: NullTerminatedString.Slice = .{
                    .tid = unwrapped_index.tid,
                    .start = extra_index,
                    .len = fields_len,
                };
                extra_index += fields_len;
                break :n .{ names_map, names };
            } else .{ .none, NullTerminatedString.Slice.empty };
            const inits: Index.Slice = if (extra.data.flags.any_default_inits) i: {
                const inits: Index.Slice = .{
                    .tid = unwrapped_index.tid,
                    .start = extra_index,
                    .len = fields_len,
                };
                extra_index += fields_len;
                break :i inits;
            } else Index.Slice.empty;
            const namespace: OptionalNamespaceIndex = if (extra.data.flags.has_namespace) n: {
                const n: NamespaceIndex = @enumFromInt(extra_list.view().items(.@"0")[extra_index]);
                extra_index += 1;
                break :n n.toOptional();
            } else .none;
            const aligns: Alignment.Slice = if (extra.data.flags.any_aligned_fields) a: {
                const a: Alignment.Slice = .{
                    .tid = unwrapped_index.tid,
                    .start = extra_index,
                    .len = fields_len,
                };
                extra_index += std.math.divCeil(u32, fields_len, 4) catch unreachable;
                break :a a;
            } else Alignment.Slice.empty;
            const comptime_bits: LoadedStructType.ComptimeBits = if (extra.data.flags.any_comptime_fields) c: {
                const len = std.math.divCeil(u32, fields_len, 32) catch unreachable;
                const c: LoadedStructType.ComptimeBits = .{
                    .tid = unwrapped_index.tid,
                    .start = extra_index,
                    .len = len,
                };
                extra_index += len;
                break :c c;
            } else LoadedStructType.ComptimeBits.empty;
            const runtime_order: LoadedStructType.RuntimeOrder.Slice = if (!extra.data.flags.is_extern) ro: {
                const ro: LoadedStructType.RuntimeOrder.Slice = .{
                    .tid = unwrapped_index.tid,
                    .start = extra_index,
                    .len = fields_len,
                };
                extra_index += fields_len;
                break :ro ro;
            } else LoadedStructType.RuntimeOrder.Slice.empty;
            const offsets: LoadedStructType.Offsets = o: {
                const o: LoadedStructType.Offsets = .{
                    .tid = unwrapped_index.tid,
                    .start = extra_index,
                    .len = fields_len,
                };
                extra_index += fields_len;
                break :o o;
            };
            return .{
                .tid = unwrapped_index.tid,
                .extra_index = item.data,
                .decl = extra.data.decl.toOptional(),
                .namespace = namespace,
                .zir_index = extra.data.zir_index.toOptional(),
                .layout = if (extra.data.flags.is_extern) .@"extern" else .auto,
                .field_names = names,
                .field_types = field_types,
                .field_inits = inits,
                .field_aligns = aligns,
                .runtime_order = runtime_order,
                .comptime_bits = comptime_bits,
                .offsets = offsets,
                .names_map = names_map,
                .captures = captures,
            };
        },
        .type_struct_packed, .type_struct_packed_inits => {
            const extra = extraDataTrail(extra_list, Tag.TypeStructPacked, item.data);
            const has_inits = item.tag == .type_struct_packed_inits;
            const fields_len = extra.data.fields_len;
            var extra_index = extra.end;
            const captures_len = if (extra.data.flags.any_captures) c: {
                const len = extra_list.view().items(.@"0")[extra_index];
                extra_index += 1;
                break :c len;
            } else 0;
            const captures: CaptureValue.Slice = .{
                .tid = unwrapped_index.tid,
                .start = extra_index,
                .len = captures_len,
            };
            extra_index += captures_len;
            if (extra.data.flags.is_reified) {
                extra_index += 2; // PackedU64
            }
            const field_types: Index.Slice = .{
                .tid = unwrapped_index.tid,
                .start = extra_index,
                .len = fields_len,
            };
            extra_index += fields_len;
            const field_names: NullTerminatedString.Slice = .{
                .tid = unwrapped_index.tid,
                .start = extra_index,
                .len = fields_len,
            };
            extra_index += fields_len;
            const field_inits: Index.Slice = if (has_inits) inits: {
                const i: Index.Slice = .{
                    .tid = unwrapped_index.tid,
                    .start = extra_index,
                    .len = fields_len,
                };
                extra_index += fields_len;
                break :inits i;
            } else Index.Slice.empty;
            return .{
                .tid = unwrapped_index.tid,
                .extra_index = item.data,
                .decl = extra.data.decl.toOptional(),
                .namespace = extra.data.namespace,
                .zir_index = extra.data.zir_index.toOptional(),
                .layout = .@"packed",
                .field_names = field_names,
                .field_types = field_types,
                .field_inits = field_inits,
                .field_aligns = Alignment.Slice.empty,
                .runtime_order = LoadedStructType.RuntimeOrder.Slice.empty,
                .comptime_bits = LoadedStructType.ComptimeBits.empty,
                .offsets = LoadedStructType.Offsets.empty,
                .names_map = extra.data.names_map.toOptional(),
                .captures = captures,
            };
        },
        else => unreachable,
    }
}

const LoadedEnumType = struct {
    /// The Decl that corresponds to the enum itself.
    decl: DeclIndex,
    /// Represents the declarations inside this enum.
    namespace: OptionalNamespaceIndex,
    /// An integer type which is used for the numerical value of the enum.
    /// This field is present regardless of whether the enum has an
    /// explicitly provided tag type or auto-numbered.
    tag_ty: Index,
    /// Set of field names in declaration order.
    names: NullTerminatedString.Slice,
    /// Maps integer tag value to field index.
    /// Entries are in declaration order, same as `fields`.
    /// If this is empty, it means the enum tags are auto-numbered.
    values: Index.Slice,
    tag_mode: TagMode,
    names_map: MapIndex,
    /// This is guaranteed to not be `.none` if explicit values are provided.
    values_map: OptionalMapIndex,
    /// This is `none` only if this is a generated tag type.
    zir_index: TrackedInst.Index.Optional,
    captures: CaptureValue.Slice,

    pub const TagMode = enum {
        /// The integer tag type was auto-numbered by zig.
        auto,
        /// The integer tag type was provided by the enum declaration, and the enum
        /// is exhaustive.
        explicit,
        /// The integer tag type was provided by the enum declaration, and the enum
        /// is non-exhaustive.
        nonexhaustive,
    };

    /// Look up field index based on field name.
    pub fn nameIndex(self: LoadedEnumType, ip: *const InternPool, name: NullTerminatedString) ?u32 {
        const map = &ip.maps.items[@intFromEnum(self.names_map)];
        const adapter: NullTerminatedString.Adapter = .{ .strings = self.names.get(ip) };
        const field_index = map.getIndexAdapted(name, adapter) orelse return null;
        return @intCast(field_index);
    }

    /// Look up field index based on tag value.
    /// Asserts that `values_map` is not `none`.
    /// This function returns `null` when `tag_val` does not have the
    /// integer tag type of the enum.
    pub fn tagValueIndex(self: LoadedEnumType, ip: *const InternPool, tag_val: Index) ?u32 {
        assert(tag_val != .none);
        // TODO: we should probably decide a single interface for this function, but currently
        // it's being called with both tag values and underlying ints. Fix this!
        const int_tag_val = switch (ip.indexToKey(tag_val)) {
            .enum_tag => |enum_tag| enum_tag.int,
            .int => tag_val,
            else => unreachable,
        };
        if (self.values_map.unwrap()) |values_map| {
            const map = &ip.maps.items[@intFromEnum(values_map)];
            const adapter: Index.Adapter = .{ .indexes = self.values.get(ip) };
            const field_index = map.getIndexAdapted(int_tag_val, adapter) orelse return null;
            return @intCast(field_index);
        }
        // Auto-numbered enum. Convert `int_tag_val` to field index.
        const field_index = switch (ip.indexToKey(int_tag_val).int.storage) {
            inline .u64, .i64 => |x| std.math.cast(u32, x) orelse return null,
            .big_int => |x| x.to(u32) catch return null,
            .lazy_align, .lazy_size => unreachable,
        };
        return if (field_index < self.names.len) field_index else null;
    }
};

pub fn loadEnumType(ip: *const InternPool, index: Index) LoadedEnumType {
    const unwrapped_index = index.unwrap(ip);
    const extra_list = unwrapped_index.getExtra(ip);
    const item = unwrapped_index.getItem(ip);
    const tag_mode: LoadedEnumType.TagMode = switch (item.tag) {
        .type_enum_auto => {
            const extra = extraDataTrail(extra_list, EnumAuto, item.data);
            var extra_index: u32 = @intCast(extra.end);
            if (extra.data.zir_index == .none) {
                extra_index += 1; // owner_union
            }
            const captures_len = if (extra.data.captures_len == std.math.maxInt(u32)) c: {
                extra_index += 2; // type_hash: PackedU64
                break :c 0;
            } else extra.data.captures_len;
            return .{
                .decl = extra.data.decl,
                .namespace = extra.data.namespace,
                .tag_ty = extra.data.int_tag_type,
                .names = .{
                    .tid = unwrapped_index.tid,
                    .start = extra_index + captures_len,
                    .len = extra.data.fields_len,
                },
                .values = Index.Slice.empty,
                .tag_mode = .auto,
                .names_map = extra.data.names_map,
                .values_map = .none,
                .zir_index = extra.data.zir_index,
                .captures = .{
                    .tid = unwrapped_index.tid,
                    .start = extra_index,
                    .len = captures_len,
                },
            };
        },
        .type_enum_explicit => .explicit,
        .type_enum_nonexhaustive => .nonexhaustive,
        else => unreachable,
    };
    const extra = extraDataTrail(extra_list, EnumExplicit, item.data);
    var extra_index: u32 = @intCast(extra.end);
    if (extra.data.zir_index == .none) {
        extra_index += 1; // owner_union
    }
    const captures_len = if (extra.data.captures_len == std.math.maxInt(u32)) c: {
        extra_index += 2; // type_hash: PackedU64
        break :c 0;
    } else extra.data.captures_len;
    return .{
        .decl = extra.data.decl,
        .namespace = extra.data.namespace,
        .tag_ty = extra.data.int_tag_type,
        .names = .{
            .tid = unwrapped_index.tid,
            .start = extra_index + captures_len,
            .len = extra.data.fields_len,
        },
        .values = .{
            .tid = unwrapped_index.tid,
            .start = extra_index + captures_len + extra.data.fields_len,
            .len = if (extra.data.values_map != .none) extra.data.fields_len else 0,
        },
        .tag_mode = tag_mode,
        .names_map = extra.data.names_map,
        .values_map = extra.data.values_map,
        .zir_index = extra.data.zir_index,
        .captures = .{
            .tid = unwrapped_index.tid,
            .start = extra_index,
            .len = captures_len,
        },
    };
}

/// Note that this type doubles as the payload for `Tag.type_opaque`.
pub const LoadedOpaqueType = struct {
    /// The opaque's owner Decl.
    decl: DeclIndex,
    /// Contains the declarations inside this opaque.
    namespace: OptionalNamespaceIndex,
    /// Index of the `opaque_decl` or `reify` instruction.
    zir_index: TrackedInst.Index,
    captures: CaptureValue.Slice,
};

pub fn loadOpaqueType(ip: *const InternPool, index: Index) LoadedOpaqueType {
    const unwrapped_index = index.unwrap(ip);
    const item = unwrapped_index.getItem(ip);
    assert(item.tag == .type_opaque);
    const extra = extraDataTrail(unwrapped_index.getExtra(ip), Tag.TypeOpaque, item.data);
    const captures_len = if (extra.data.captures_len == std.math.maxInt(u32))
        0
    else
        extra.data.captures_len;
    return .{
        .decl = extra.data.decl,
        .namespace = extra.data.namespace,
        .zir_index = extra.data.zir_index,
        .captures = .{
            .tid = unwrapped_index.tid,
            .start = extra.end,
            .len = captures_len,
        },
    };
}

pub const Item = struct {
    tag: Tag,
    /// The doc comments on the respective Tag explain how to interpret this.
    data: u32,
};

/// Represents an index into `map`. It represents the canonical index
/// of a `Value` within this `InternPool`. The values are typed.
/// Two values which have the same type can be equality compared simply
/// by checking if their indexes are equal, provided they are both in
/// the same `InternPool`.
/// When adding a tag to this enum, consider adding a corresponding entry to
/// `primitives` in AstGen.zig.
pub const Index = enum(u32) {
    pub const first_type: Index = .u0_type;
    pub const last_type: Index = .empty_struct_type;
    pub const first_value: Index = .undef;
    pub const last_value: Index = .empty_struct;

    u0_type,
    i0_type,
    u1_type,
    u8_type,
    i8_type,
    u16_type,
    i16_type,
    u29_type,
    u32_type,
    i32_type,
    u64_type,
    i64_type,
    u80_type,
    u128_type,
    i128_type,
    usize_type,
    isize_type,
    c_char_type,
    c_short_type,
    c_ushort_type,
    c_int_type,
    c_uint_type,
    c_long_type,
    c_ulong_type,
    c_longlong_type,
    c_ulonglong_type,
    c_longdouble_type,
    f16_type,
    f32_type,
    f64_type,
    f80_type,
    f128_type,
    anyopaque_type,
    bool_type,
    void_type,
    type_type,
    anyerror_type,
    comptime_int_type,
    comptime_float_type,
    noreturn_type,
    anyframe_type,
    null_type,
    undefined_type,
    enum_literal_type,
    atomic_order_type,
    atomic_rmw_op_type,
    calling_convention_type,
    address_space_type,
    float_mode_type,
    reduce_op_type,
    call_modifier_type,
    prefetch_options_type,
    export_options_type,
    extern_options_type,
    type_info_type,
    manyptr_u8_type,
    manyptr_const_u8_type,
    manyptr_const_u8_sentinel_0_type,
    single_const_pointer_to_comptime_int_type,
    slice_const_u8_type,
    slice_const_u8_sentinel_0_type,
    optional_noreturn_type,
    anyerror_void_error_union_type,
    /// Used for the inferred error set of inline/comptime function calls.
    adhoc_inferred_error_set_type,
    generic_poison_type,
    /// `@TypeOf(.{})`
    empty_struct_type,

    /// `undefined` (untyped)
    undef,
    /// `0` (comptime_int)
    zero,
    /// `0` (usize)
    zero_usize,
    /// `0` (u8)
    zero_u8,
    /// `1` (comptime_int)
    one,
    /// `1` (usize)
    one_usize,
    /// `1` (u8)
    one_u8,
    /// `4` (u8)
    four_u8,
    /// `-1` (comptime_int)
    negative_one,
    /// `std.builtin.CallingConvention.C`
    calling_convention_c,
    /// `std.builtin.CallingConvention.Inline`
    calling_convention_inline,
    /// `{}`
    void_value,
    /// `unreachable` (noreturn type)
    unreachable_value,
    /// `null` (untyped)
    null_value,
    /// `true`
    bool_true,
    /// `false`
    bool_false,
    /// `.{}` (untyped)
    empty_struct,

    /// Used for generic parameters where the type and value
    /// is not known until generic function instantiation.
    generic_poison,

    /// Used by Air/Sema only.
    none = std.math.maxInt(u32),

    _,

    /// An array of `Index` existing within the `extra` array.
    /// This type exists to provide a struct with lifetime that is
    /// not invalidated when items are added to the `InternPool`.
    pub const Slice = struct {
        tid: Zcu.PerThread.Id,
        start: u32,
        len: u32,

        pub const empty: Slice = .{ .tid = .main, .start = 0, .len = 0 };

        pub fn get(slice: Slice, ip: *const InternPool) []Index {
            const extra = ip.getLocalShared(slice.tid).extra.acquire();
            return @ptrCast(extra.view().items(.@"0")[slice.start..][0..slice.len]);
        }
    };

    /// Used for a map of `Index` values to the index within a list of `Index` values.
    const Adapter = struct {
        indexes: []const Index,

        pub fn eql(ctx: @This(), a: Index, b_void: void, b_map_index: usize) bool {
            _ = b_void;
            return a == ctx.indexes[b_map_index];
        }

        pub fn hash(ctx: @This(), a: Index) u32 {
            _ = ctx;
            return std.hash.uint32(@intFromEnum(a));
        }
    };

    const Unwrapped = struct {
        tid: Zcu.PerThread.Id,
        index: u32,

        fn wrap(unwrapped: Unwrapped, ip: *const InternPool) Index {
            assert(@intFromEnum(unwrapped.tid) <= ip.getTidMask());
            assert(unwrapped.index <= ip.getIndexMask(u31));
            return @enumFromInt(@as(u32, @intFromEnum(unwrapped.tid)) << ip.tid_shift_31 | unwrapped.index);
        }

        pub fn getExtra(unwrapped: Unwrapped, ip: *const InternPool) Local.Extra {
            return ip.getLocalShared(unwrapped.tid).extra.acquire();
        }

        pub fn getItem(unwrapped: Unwrapped, ip: *const InternPool) Item {
            const item_ptr = unwrapped.itemPtr(ip);
            const tag = @atomicLoad(Tag, item_ptr.tag_ptr, .acquire);
            return .{ .tag = tag, .data = item_ptr.data_ptr.* };
        }

        pub fn getTag(unwrapped: Unwrapped, ip: *const InternPool) Tag {
            const item_ptr = unwrapped.itemPtr(ip);
            return @atomicLoad(Tag, item_ptr.tag_ptr, .acquire);
        }

        pub fn getData(unwrapped: Unwrapped, ip: *const InternPool) u32 {
            return unwrapped.getItem(ip).data;
        }

        const ItemPtr = struct {
            tag_ptr: *Tag,
            data_ptr: *u32,
        };
        fn itemPtr(unwrapped: Unwrapped, ip: *const InternPool) ItemPtr {
            const slice = ip.getLocalShared(unwrapped.tid).items.acquire().view().slice();
            return .{
                .tag_ptr = &slice.items(.tag)[unwrapped.index],
                .data_ptr = &slice.items(.data)[unwrapped.index],
            };
        }
    };
    pub fn unwrap(index: Index, ip: *const InternPool) Unwrapped {
        return if (single_threaded) .{
            .tid = .main,
            .index = @intFromEnum(index),
        } else .{
            .tid = @enumFromInt(@intFromEnum(index) >> ip.tid_shift_31 & ip.getTidMask()),
            .index = @intFromEnum(index) & ip.getIndexMask(u31),
        };
    }

    /// This function is used in the debugger pretty formatters in tools/ to fetch the
    /// Tag to encoding mapping to facilitate fancy debug printing for this type.
    /// TODO merge this with `Tag.Payload`.
    fn dbHelper(self: *Index, tag_to_encoding_map: *struct {
        const DataIsIndex = struct { data: Index };
        const DataIsExtraIndexOfEnumExplicit = struct {
            const @"data.fields_len" = opaque {};
            data: *EnumExplicit,
            @"trailing.names.len": *@"data.fields_len",
            @"trailing.values.len": *@"data.fields_len",
            trailing: struct {
                names: []NullTerminatedString,
                values: []Index,
            },
        };
        const DataIsExtraIndexOfTypeStructAnon = struct {
            const @"data.fields_len" = opaque {};
            data: *TypeStructAnon,
            @"trailing.types.len": *@"data.fields_len",
            @"trailing.values.len": *@"data.fields_len",
            @"trailing.names.len": *@"data.fields_len",
            trailing: struct {
                types: []Index,
                values: []Index,
                names: []NullTerminatedString,
            },
        };

        removed: void,
        type_int_signed: struct { data: u32 },
        type_int_unsigned: struct { data: u32 },
        type_array_big: struct { data: *Array },
        type_array_small: struct { data: *Vector },
        type_vector: struct { data: *Vector },
        type_pointer: struct { data: *Tag.TypePointer },
        type_slice: DataIsIndex,
        type_optional: DataIsIndex,
        type_anyframe: DataIsIndex,
        type_error_union: struct { data: *Key.ErrorUnionType },
        type_anyerror_union: DataIsIndex,
        type_error_set: struct {
            const @"data.names_len" = opaque {};
            data: *Tag.ErrorSet,
            @"trailing.names.len": *@"data.names_len",
            trailing: struct { names: []NullTerminatedString },
        },
        type_inferred_error_set: DataIsIndex,
        type_enum_auto: struct {
            const @"data.fields_len" = opaque {};
            data: *EnumAuto,
            @"trailing.names.len": *@"data.fields_len",
            trailing: struct { names: []NullTerminatedString },
        },
        type_enum_explicit: DataIsExtraIndexOfEnumExplicit,
        type_enum_nonexhaustive: DataIsExtraIndexOfEnumExplicit,
        simple_type: void,
        type_opaque: struct { data: *Tag.TypeOpaque },
        type_struct: struct { data: *Tag.TypeStruct },
        type_struct_anon: DataIsExtraIndexOfTypeStructAnon,
        type_struct_packed: struct { data: *Tag.TypeStructPacked },
        type_struct_packed_inits: struct { data: *Tag.TypeStructPacked },
        type_tuple_anon: DataIsExtraIndexOfTypeStructAnon,
        type_union: struct { data: *Tag.TypeUnion },
        type_function: struct {
            const @"data.flags.has_comptime_bits" = opaque {};
            const @"data.flags.has_noalias_bits" = opaque {};
            const @"data.params_len" = opaque {};
            data: *Tag.TypeFunction,
            @"trailing.comptime_bits.len": *@"data.flags.has_comptime_bits",
            @"trailing.noalias_bits.len": *@"data.flags.has_noalias_bits",
            @"trailing.param_types.len": *@"data.params_len",
            trailing: struct { comptime_bits: []u32, noalias_bits: []u32, param_types: []Index },
        },

        undef: DataIsIndex,
        simple_value: void,
        ptr_decl: struct { data: *PtrDecl },
        ptr_comptime_alloc: struct { data: *PtrComptimeAlloc },
        ptr_anon_decl: struct { data: *PtrAnonDecl },
        ptr_anon_decl_aligned: struct { data: *PtrAnonDeclAligned },
        ptr_comptime_field: struct { data: *PtrComptimeField },
        ptr_int: struct { data: *PtrInt },
        ptr_eu_payload: struct { data: *PtrBase },
        ptr_opt_payload: struct { data: *PtrBase },
        ptr_elem: struct { data: *PtrBaseIndex },
        ptr_field: struct { data: *PtrBaseIndex },
        ptr_slice: struct { data: *PtrSlice },
        opt_payload: struct { data: *Tag.TypeValue },
        opt_null: DataIsIndex,
        int_u8: struct { data: u8 },
        int_u16: struct { data: u16 },
        int_u32: struct { data: u32 },
        int_i32: struct { data: i32 },
        int_usize: struct { data: u32 },
        int_comptime_int_u32: struct { data: u32 },
        int_comptime_int_i32: struct { data: i32 },
        int_small: struct { data: *IntSmall },
        int_positive: struct { data: u32 },
        int_negative: struct { data: u32 },
        int_lazy_align: struct { data: *IntLazy },
        int_lazy_size: struct { data: *IntLazy },
        error_set_error: struct { data: *Key.Error },
        error_union_error: struct { data: *Key.Error },
        error_union_payload: struct { data: *Tag.TypeValue },
        enum_literal: struct { data: NullTerminatedString },
        enum_tag: struct { data: *Tag.EnumTag },
        float_f16: struct { data: f16 },
        float_f32: struct { data: f32 },
        float_f64: struct { data: *Float64 },
        float_f80: struct { data: *Float80 },
        float_f128: struct { data: *Float128 },
        float_c_longdouble_f80: struct { data: *Float80 },
        float_c_longdouble_f128: struct { data: *Float128 },
        float_comptime_float: struct { data: *Float128 },
        variable: struct { data: *Tag.Variable },
        extern_func: struct { data: *Key.ExternFunc },
        func_decl: struct {
            const @"data.analysis.inferred_error_set" = opaque {};
            data: *Tag.FuncDecl,
            @"trailing.resolved_error_set.len": *@"data.analysis.inferred_error_set",
            trailing: struct { resolved_error_set: []Index },
        },
        func_instance: struct {
            const @"data.analysis.inferred_error_set" = opaque {};
            const @"data.generic_owner.data.ty.data.params_len" = opaque {};
            data: *Tag.FuncInstance,
            @"trailing.resolved_error_set.len": *@"data.analysis.inferred_error_set",
            @"trailing.comptime_args.len": *@"data.generic_owner.data.ty.data.params_len",
            trailing: struct { resolved_error_set: []Index, comptime_args: []Index },
        },
        func_coerced: struct {
            data: *Tag.FuncCoerced,
        },
        only_possible_value: DataIsIndex,
        union_value: struct { data: *Key.Union },
        bytes: struct { data: *Bytes },
        aggregate: struct {
            const @"data.ty.data.len orelse data.ty.data.fields_len" = opaque {};
            data: *Tag.Aggregate,
            @"trailing.element_values.len": *@"data.ty.data.len orelse data.ty.data.fields_len",
            trailing: struct { element_values: []Index },
        },
        repeated: struct { data: *Repeated },

        memoized_call: struct {
            const @"data.args_len" = opaque {};
            data: *MemoizedCall,
            @"trailing.arg_values.len": *@"data.args_len",
            trailing: struct { arg_values: []Index },
        },
    }) void {
        _ = self;
        const map_fields = @typeInfo(@typeInfo(@TypeOf(tag_to_encoding_map)).Pointer.child).Struct.fields;
        @setEvalBranchQuota(2_000);
        inline for (@typeInfo(Tag).Enum.fields, 0..) |tag, start| {
            inline for (0..map_fields.len) |offset| {
                if (comptime std.mem.eql(u8, tag.name, map_fields[(start + offset) % map_fields.len].name)) break;
            } else {
                @compileError(@typeName(Tag) ++ "." ++ tag.name ++ " missing dbHelper tag_to_encoding_map entry");
            }
        }
    }

    comptime {
        if (!builtin.strip_debug_info) {
            _ = &dbHelper;
        }
    }
};

pub const static_keys = [_]Key{
    .{ .int_type = .{
        .signedness = .unsigned,
        .bits = 0,
    } },

    .{ .int_type = .{
        .signedness = .signed,
        .bits = 0,
    } },

    .{ .int_type = .{
        .signedness = .unsigned,
        .bits = 1,
    } },

    .{ .int_type = .{
        .signedness = .unsigned,
        .bits = 8,
    } },

    .{ .int_type = .{
        .signedness = .signed,
        .bits = 8,
    } },

    .{ .int_type = .{
        .signedness = .unsigned,
        .bits = 16,
    } },

    .{ .int_type = .{
        .signedness = .signed,
        .bits = 16,
    } },

    .{ .int_type = .{
        .signedness = .unsigned,
        .bits = 29,
    } },

    .{ .int_type = .{
        .signedness = .unsigned,
        .bits = 32,
    } },

    .{ .int_type = .{
        .signedness = .signed,
        .bits = 32,
    } },

    .{ .int_type = .{
        .signedness = .unsigned,
        .bits = 64,
    } },

    .{ .int_type = .{
        .signedness = .signed,
        .bits = 64,
    } },

    .{ .int_type = .{
        .signedness = .unsigned,
        .bits = 80,
    } },

    .{ .int_type = .{
        .signedness = .unsigned,
        .bits = 128,
    } },

    .{ .int_type = .{
        .signedness = .signed,
        .bits = 128,
    } },

    .{ .simple_type = .usize },
    .{ .simple_type = .isize },
    .{ .simple_type = .c_char },
    .{ .simple_type = .c_short },
    .{ .simple_type = .c_ushort },
    .{ .simple_type = .c_int },
    .{ .simple_type = .c_uint },
    .{ .simple_type = .c_long },
    .{ .simple_type = .c_ulong },
    .{ .simple_type = .c_longlong },
    .{ .simple_type = .c_ulonglong },
    .{ .simple_type = .c_longdouble },
    .{ .simple_type = .f16 },
    .{ .simple_type = .f32 },
    .{ .simple_type = .f64 },
    .{ .simple_type = .f80 },
    .{ .simple_type = .f128 },
    .{ .simple_type = .anyopaque },
    .{ .simple_type = .bool },
    .{ .simple_type = .void },
    .{ .simple_type = .type },
    .{ .simple_type = .anyerror },
    .{ .simple_type = .comptime_int },
    .{ .simple_type = .comptime_float },
    .{ .simple_type = .noreturn },
    .{ .anyframe_type = .none },
    .{ .simple_type = .null },
    .{ .simple_type = .undefined },
    .{ .simple_type = .enum_literal },
    .{ .simple_type = .atomic_order },
    .{ .simple_type = .atomic_rmw_op },
    .{ .simple_type = .calling_convention },
    .{ .simple_type = .address_space },
    .{ .simple_type = .float_mode },
    .{ .simple_type = .reduce_op },
    .{ .simple_type = .call_modifier },
    .{ .simple_type = .prefetch_options },
    .{ .simple_type = .export_options },
    .{ .simple_type = .extern_options },
    .{ .simple_type = .type_info },

    // [*]u8
    .{ .ptr_type = .{
        .child = .u8_type,
        .flags = .{
            .size = .Many,
        },
    } },

    // [*]const u8
    .{ .ptr_type = .{
        .child = .u8_type,
        .flags = .{
            .size = .Many,
            .is_const = true,
        },
    } },

    // [*:0]const u8
    .{ .ptr_type = .{
        .child = .u8_type,
        .sentinel = .zero_u8,
        .flags = .{
            .size = .Many,
            .is_const = true,
        },
    } },

    // comptime_int
    .{ .ptr_type = .{
        .child = .comptime_int_type,
        .flags = .{
            .size = .One,
            .is_const = true,
        },
    } },

    // []const u8
    .{ .ptr_type = .{
        .child = .u8_type,
        .flags = .{
            .size = .Slice,
            .is_const = true,
        },
    } },

    // [:0]const u8
    .{ .ptr_type = .{
        .child = .u8_type,
        .sentinel = .zero_u8,
        .flags = .{
            .size = .Slice,
            .is_const = true,
        },
    } },

    // ?noreturn
    .{ .opt_type = .noreturn_type },

    // anyerror!void
    .{ .error_union_type = .{
        .error_set_type = .anyerror_type,
        .payload_type = .void_type,
    } },

    // adhoc_inferred_error_set_type
    .{ .simple_type = .adhoc_inferred_error_set },
    // generic_poison_type
    .{ .simple_type = .generic_poison },

    // empty_struct_type
    .{ .anon_struct_type = .{
        .types = Index.Slice.empty,
        .names = NullTerminatedString.Slice.empty,
        .values = Index.Slice.empty,
    } },

    .{ .simple_value = .undefined },

    .{ .int = .{
        .ty = .comptime_int_type,
        .storage = .{ .u64 = 0 },
    } },

    .{ .int = .{
        .ty = .usize_type,
        .storage = .{ .u64 = 0 },
    } },

    .{ .int = .{
        .ty = .u8_type,
        .storage = .{ .u64 = 0 },
    } },

    .{ .int = .{
        .ty = .comptime_int_type,
        .storage = .{ .u64 = 1 },
    } },

    .{ .int = .{
        .ty = .usize_type,
        .storage = .{ .u64 = 1 },
    } },

    // one_u8
    .{ .int = .{
        .ty = .u8_type,
        .storage = .{ .u64 = 1 },
    } },
    // four_u8
    .{ .int = .{
        .ty = .u8_type,
        .storage = .{ .u64 = 4 },
    } },
    // negative_one
    .{ .int = .{
        .ty = .comptime_int_type,
        .storage = .{ .i64 = -1 },
    } },
    // calling_convention_c
    .{ .enum_tag = .{
        .ty = .calling_convention_type,
        .int = .one_u8,
    } },
    // calling_convention_inline
    .{ .enum_tag = .{
        .ty = .calling_convention_type,
        .int = .four_u8,
    } },

    .{ .simple_value = .void },
    .{ .simple_value = .@"unreachable" },
    .{ .simple_value = .null },
    .{ .simple_value = .true },
    .{ .simple_value = .false },
    .{ .simple_value = .empty_struct },
    .{ .simple_value = .generic_poison },
};

/// How many items in the InternPool are statically known.
/// This is specified with an integer literal and a corresponding comptime
/// assert below to break an unfortunate and arguably incorrect dependency loop
/// when compiling.
pub const static_len = Zir.Inst.Index.static_len;
comptime {
    //@compileLog(static_keys.len);
    assert(static_len == static_keys.len);
}

pub const Tag = enum(u8) {
    /// This special tag represents a value which was removed from this pool via
    /// `InternPool.remove`. The item remains allocated to preserve indices, but
    /// lookups will consider it not equal to any other item, and all queries
    /// assert not this tag. `data` is unused.
    removed,

    /// An integer type.
    /// data is number of bits
    type_int_signed,
    /// An integer type.
    /// data is number of bits
    type_int_unsigned,
    /// An array type whose length requires 64 bits or which has a sentinel.
    /// data is payload to Array.
    type_array_big,
    /// An array type that has no sentinel and whose length fits in 32 bits.
    /// data is payload to Vector.
    type_array_small,
    /// A vector type.
    /// data is payload to Vector.
    type_vector,
    /// A fully explicitly specified pointer type.
    type_pointer,
    /// A slice type.
    /// data is Index of underlying pointer type.
    type_slice,
    /// An optional type.
    /// data is the child type.
    type_optional,
    /// The type `anyframe->T`.
    /// data is the child type.
    /// If the child type is `none`, the type is `anyframe`.
    type_anyframe,
    /// An error union type.
    /// data is payload to `Key.ErrorUnionType`.
    type_error_union,
    /// An error union type of the form `anyerror!T`.
    /// data is `Index` of payload type.
    type_anyerror_union,
    /// An error set type.
    /// data is payload to `ErrorSet`.
    type_error_set,
    /// The inferred error set type of a function.
    /// data is `Index` of a `func_decl` or `func_instance`.
    type_inferred_error_set,
    /// An enum type with auto-numbered tag values.
    /// The enum is exhaustive.
    /// data is payload index to `EnumAuto`.
    type_enum_auto,
    /// An enum type with an explicitly provided integer tag type.
    /// The enum is exhaustive.
    /// data is payload index to `EnumExplicit`.
    type_enum_explicit,
    /// An enum type with an explicitly provided integer tag type.
    /// The enum is non-exhaustive.
    /// data is payload index to `EnumExplicit`.
    type_enum_nonexhaustive,
    /// A type that can be represented with only an enum tag.
    /// data is SimpleType enum value.
    simple_type,
    /// An opaque type.
    /// data is index of Tag.TypeOpaque in extra.
    type_opaque,
    /// A non-packed struct type.
    /// data is 0 or extra index of `TypeStruct`.
    /// data == 0 represents `@TypeOf(.{})`.
    type_struct,
    /// An AnonStructType which stores types, names, and values for fields.
    /// data is extra index of `TypeStructAnon`.
    type_struct_anon,
    /// A packed struct, no fields have any init values.
    /// data is extra index of `TypeStructPacked`.
    type_struct_packed,
    /// A packed struct, one or more fields have init values.
    /// data is extra index of `TypeStructPacked`.
    type_struct_packed_inits,
    /// An AnonStructType which has only types and values for fields.
    /// data is extra index of `TypeStructAnon`.
    type_tuple_anon,
    /// A union type.
    /// `data` is extra index of `TypeUnion`.
    type_union,
    /// A function body type.
    /// `data` is extra index to `TypeFunction`.
    type_function,

    /// Typed `undefined`.
    /// `data` is `Index` of the type.
    /// Untyped `undefined` is stored instead via `simple_value`.
    undef,
    /// A value that can be represented with only an enum tag.
    /// data is SimpleValue enum value.
    simple_value,
    /// A pointer to a decl.
    /// data is extra index of `PtrDecl`, which contains the type and address.
    ptr_decl,
    /// A pointer to a decl that can be mutated at comptime.
    /// data is extra index of `PtrComptimeAlloc`, which contains the type and address.
    ptr_comptime_alloc,
    /// A pointer to an anonymous decl.
    /// data is extra index of `PtrAnonDecl`, which contains the pointer type and decl value.
    /// The alignment of the anonymous decl is communicated via the pointer type.
    ptr_anon_decl,
    /// A pointer to an anonymous decl.
    /// data is extra index of `PtrAnonDeclAligned`, which contains the pointer
    /// type and decl value.
    /// The original pointer type is also provided, which will be different than `ty`.
    /// This encoding is only used when a pointer to an anonymous decl is
    /// coerced to a different pointer type with a different alignment.
    ptr_anon_decl_aligned,
    /// data is extra index of `PtrComptimeField`, which contains the pointer type and field value.
    ptr_comptime_field,
    /// A pointer with an integer value.
    /// data is extra index of `PtrInt`, which contains the type and address (byte offset from 0).
    /// Only pointer types are allowed to have this encoding. Optional types must use
    /// `opt_payload` or `opt_null`.
    ptr_int,
    /// A pointer to the payload of an error union.
    /// data is extra index of `PtrBase`, which contains the type and base pointer.
    ptr_eu_payload,
    /// A pointer to the payload of an optional.
    /// data is extra index of `PtrBase`, which contains the type and base pointer.
    ptr_opt_payload,
    /// A pointer to an array element.
    /// data is extra index of PtrBaseIndex, which contains the base array and element index.
    /// In order to use this encoding, one must ensure that the `InternPool`
    /// already contains the elem pointer type corresponding to this payload.
    ptr_elem,
    /// A pointer to a container field.
    /// data is extra index of PtrBaseIndex, which contains the base container and field index.
    ptr_field,
    /// A slice.
    /// data is extra index of PtrSlice, which contains the ptr and len values
    ptr_slice,
    /// An optional value that is non-null.
    /// data is extra index of `TypeValue`.
    /// The type is the optional type (not the payload type).
    opt_payload,
    /// An optional value that is null.
    /// data is Index of the optional type.
    opt_null,
    /// Type: u8
    /// data is integer value
    int_u8,
    /// Type: u16
    /// data is integer value
    int_u16,
    /// Type: u32
    /// data is integer value
    int_u32,
    /// Type: i32
    /// data is integer value bitcasted to u32.
    int_i32,
    /// A usize that fits in 32 bits.
    /// data is integer value.
    int_usize,
    /// A comptime_int that fits in a u32.
    /// data is integer value.
    int_comptime_int_u32,
    /// A comptime_int that fits in an i32.
    /// data is integer value bitcasted to u32.
    int_comptime_int_i32,
    /// An integer value that fits in 32 bits with an explicitly provided type.
    /// data is extra index of `IntSmall`.
    int_small,
    /// A positive integer value.
    /// data is a limbs index to `Int`.
    int_positive,
    /// A negative integer value.
    /// data is a limbs index to `Int`.
    int_negative,
    /// The ABI alignment of a lazy type.
    /// data is extra index of `IntLazy`.
    int_lazy_align,
    /// The ABI size of a lazy type.
    /// data is extra index of `IntLazy`.
    int_lazy_size,
    /// An error value.
    /// data is extra index of `Key.Error`.
    error_set_error,
    /// An error union error.
    /// data is extra index of `Key.Error`.
    error_union_error,
    /// An error union payload.
    /// data is extra index of `TypeValue`.
    error_union_payload,
    /// An enum literal value.
    /// data is `NullTerminatedString` of the error name.
    enum_literal,
    /// An enum tag value.
    /// data is extra index of `EnumTag`.
    enum_tag,
    /// An f16 value.
    /// data is float value bitcasted to u16 and zero-extended.
    float_f16,
    /// An f32 value.
    /// data is float value bitcasted to u32.
    float_f32,
    /// An f64 value.
    /// data is extra index to Float64.
    float_f64,
    /// An f80 value.
    /// data is extra index to Float80.
    float_f80,
    /// An f128 value.
    /// data is extra index to Float128.
    float_f128,
    /// A c_longdouble value of 80 bits.
    /// data is extra index to Float80.
    /// This is used when a c_longdouble value is provided as an f80, because f80 has unnormalized
    /// values which cannot be losslessly represented as f128. It should only be used when the type
    /// underlying c_longdouble for the target is 80 bits.
    float_c_longdouble_f80,
    /// A c_longdouble value of 128 bits.
    /// data is extra index to Float128.
    /// This is used when a c_longdouble value is provided as any type other than an f80, since all
    /// other float types can be losslessly converted to and from f128.
    float_c_longdouble_f128,
    /// A comptime_float value.
    /// data is extra index to Float128.
    float_comptime_float,
    /// A global variable.
    /// data is extra index to Variable.
    variable,
    /// An extern function.
    /// data is extra index to ExternFunc.
    extern_func,
    /// A non-extern function corresponding directly to the AST node from whence it originated.
    /// data is extra index to `FuncDecl`.
    /// Only the owner Decl is used for hashing and equality because the other
    /// fields can get patched up during incremental compilation.
    func_decl,
    /// A generic function instantiation.
    /// data is extra index to `FuncInstance`.
    func_instance,
    /// A `func_decl` or a `func_instance` that has been coerced to a different type.
    /// data is extra index to `FuncCoerced`.
    func_coerced,
    /// This represents the only possible value for *some* types which have
    /// only one possible value. Not all only-possible-values are encoded this way;
    /// for example structs which have all comptime fields are not encoded this way.
    /// The set of values that are encoded this way is:
    /// * An array or vector which has length 0.
    /// * A struct which has all fields comptime-known.
    /// * An empty enum or union. TODO: this value's existence is strange, because such a type in reality has no values. See #15909
    /// data is Index of the type, which is known to be zero bits at runtime.
    only_possible_value,
    /// data is extra index to Key.Union.
    union_value,
    /// An array of bytes.
    /// data is extra index to `Bytes`.
    bytes,
    /// An instance of a struct, array, or vector.
    /// data is extra index to `Aggregate`.
    aggregate,
    /// An instance of an array or vector with every element being the same value.
    /// data is extra index to `Repeated`.
    repeated,

    /// A memoized comptime function call result.
    /// data is extra index to `MemoizedCall`
    memoized_call,

    const ErrorUnionType = Key.ErrorUnionType;
    const TypeValue = Key.TypeValue;
    const Error = Key.Error;
    const EnumTag = Key.EnumTag;
    const ExternFunc = Key.ExternFunc;
    const Union = Key.Union;
    const TypePointer = Key.PtrType;

    fn Payload(comptime tag: Tag) type {
        return switch (tag) {
            .removed => unreachable,
            .type_int_signed => unreachable,
            .type_int_unsigned => unreachable,
            .type_array_big => Array,
            .type_array_small => Vector,
            .type_vector => Vector,
            .type_pointer => TypePointer,
            .type_slice => unreachable,
            .type_optional => unreachable,
            .type_anyframe => unreachable,
            .type_error_union => ErrorUnionType,
            .type_anyerror_union => unreachable,
            .type_error_set => ErrorSet,
            .type_inferred_error_set => unreachable,
            .type_enum_auto => EnumAuto,
            .type_enum_explicit => EnumExplicit,
            .type_enum_nonexhaustive => EnumExplicit,
            .simple_type => unreachable,
            .type_opaque => TypeOpaque,
            .type_struct => TypeStruct,
            .type_struct_anon => TypeStructAnon,
            .type_struct_packed, .type_struct_packed_inits => TypeStructPacked,
            .type_tuple_anon => TypeStructAnon,
            .type_union => TypeUnion,
            .type_function => TypeFunction,

            .undef => unreachable,
            .simple_value => unreachable,
            .ptr_decl => PtrDecl,
            .ptr_comptime_alloc => PtrComptimeAlloc,
            .ptr_anon_decl => PtrAnonDecl,
            .ptr_anon_decl_aligned => PtrAnonDeclAligned,
            .ptr_comptime_field => PtrComptimeField,
            .ptr_int => PtrInt,
            .ptr_eu_payload => PtrBase,
            .ptr_opt_payload => PtrBase,
            .ptr_elem => PtrBaseIndex,
            .ptr_field => PtrBaseIndex,
            .ptr_slice => PtrSlice,
            .opt_payload => TypeValue,
            .opt_null => unreachable,
            .int_u8 => unreachable,
            .int_u16 => unreachable,
            .int_u32 => unreachable,
            .int_i32 => unreachable,
            .int_usize => unreachable,
            .int_comptime_int_u32 => unreachable,
            .int_comptime_int_i32 => unreachable,
            .int_small => IntSmall,
            .int_positive => unreachable,
            .int_negative => unreachable,
            .int_lazy_align => IntLazy,
            .int_lazy_size => IntLazy,
            .error_set_error => Error,
            .error_union_error => Error,
            .error_union_payload => TypeValue,
            .enum_literal => unreachable,
            .enum_tag => EnumTag,
            .float_f16 => unreachable,
            .float_f32 => unreachable,
            .float_f64 => unreachable,
            .float_f80 => unreachable,
            .float_f128 => unreachable,
            .float_c_longdouble_f80 => unreachable,
            .float_c_longdouble_f128 => unreachable,
            .float_comptime_float => unreachable,
            .variable => Variable,
            .extern_func => ExternFunc,
            .func_decl => FuncDecl,
            .func_instance => FuncInstance,
            .func_coerced => FuncCoerced,
            .only_possible_value => unreachable,
            .union_value => Union,
            .bytes => Bytes,
            .aggregate => Aggregate,
            .repeated => Repeated,
            .memoized_call => MemoizedCall,
        };
    }

    pub const Variable = struct {
        ty: Index,
        /// May be `none`.
        init: Index,
        decl: DeclIndex,
        /// Library name if specified.
        /// For example `extern "c" var stderrp = ...` would have 'c' as library name.
        lib_name: OptionalNullTerminatedString,
        flags: Flags,

        pub const Flags = packed struct(u32) {
            is_extern: bool,
            is_const: bool,
            is_threadlocal: bool,
            is_weak_linkage: bool,
            _: u28 = 0,
        };
    };

    /// Trailing:
    /// 0. element: Index for each len
    /// len is determined by the aggregate type.
    pub const Aggregate = struct {
        /// The type of the aggregate.
        ty: Index,
    };

    /// Trailing:
    /// 0. If `analysis.inferred_error_set` is `true`, `Index` of an `error_set` which
    ///    is a regular error set corresponding to the finished inferred error set.
    ///    A `none` value marks that the inferred error set is not resolved yet.
    pub const FuncDecl = struct {
        analysis: FuncAnalysis,
        owner_decl: DeclIndex,
        ty: Index,
        zir_body_inst: TrackedInst.Index,
        lbrace_line: u32,
        rbrace_line: u32,
        lbrace_column: u32,
        rbrace_column: u32,
    };

    /// Trailing:
    /// 0. If `analysis.inferred_error_set` is `true`, `Index` of an `error_set` which
    ///    is a regular error set corresponding to the finished inferred error set.
    ///    A `none` value marks that the inferred error set is not resolved yet.
    /// 1. For each parameter of generic_owner: `Index` if comptime, otherwise `none`
    pub const FuncInstance = struct {
        analysis: FuncAnalysis,
        // Needed by the linker for codegen. Not part of hashing or equality.
        owner_decl: DeclIndex,
        ty: Index,
        branch_quota: u32,
        /// Points to a `FuncDecl`.
        generic_owner: Index,
    };

    pub const FuncCoerced = struct {
        ty: Index,
        func: Index,
    };

    /// Trailing:
    /// 0. name: NullTerminatedString for each names_len
    pub const ErrorSet = struct {
        names_len: u32,
        /// Maps error names to declaration index.
        names_map: MapIndex,
    };

    /// Trailing:
    /// 0. comptime_bits: u32, // if has_comptime_bits
    /// 1. noalias_bits: u32, // if has_noalias_bits
    /// 2. param_type: Index for each params_len
    pub const TypeFunction = struct {
        params_len: u32,
        return_type: Index,
        flags: Flags,

        pub const Flags = packed struct(u32) {
            cc: std.builtin.CallingConvention,
            is_var_args: bool,
            is_generic: bool,
            has_comptime_bits: bool,
            has_noalias_bits: bool,
            is_noinline: bool,
            cc_is_generic: bool,
            section_is_generic: bool,
            addrspace_is_generic: bool,
            _: u16 = 0,
        };
    };

    /// Trailing:
    /// 0. captures_len: u32 // if `any_captures`
    /// 1. capture: CaptureValue // for each `captures_len`
    /// 2. type_hash: PackedU64 // if `is_reified`
    /// 3. field type: Index for each field; declaration order
    /// 4. field align: Alignment for each field; declaration order
    pub const TypeUnion = struct {
        flags: Flags,
        /// This could be provided through the tag type, but it is more convenient
        /// to store it directly. This is also necessary for `dumpStatsFallible` to
        /// work on unresolved types.
        fields_len: u32,
        /// Only valid after .have_layout
        size: u32,
        /// Only valid after .have_layout
        padding: u32,
        decl: DeclIndex,
        namespace: OptionalNamespaceIndex,
        /// The enum that provides the list of field names and values.
        tag_ty: Index,
        zir_index: TrackedInst.Index,

        pub const Flags = packed struct(u32) {
            any_captures: bool,
            runtime_tag: LoadedUnionType.RuntimeTag,
            /// If false, the field alignment trailing data is omitted.
            any_aligned_fields: bool,
            layout: std.builtin.Type.ContainerLayout,
            status: LoadedUnionType.Status,
            requires_comptime: RequiresComptime,
            assumed_runtime_bits: bool,
            assumed_pointer_aligned: bool,
            alignment: Alignment,
            is_reified: bool,
            _: u12 = 0,
        };
    };

    /// Trailing:
    /// 0. captures_len: u32 // if `any_captures`
    /// 1. capture: CaptureValue // for each `captures_len`
    /// 2. type_hash: PackedU64 // if `is_reified`
    /// 3. type: Index for each fields_len
    /// 4. name: NullTerminatedString for each fields_len
    /// 5. init: Index for each fields_len // if tag is type_struct_packed_inits
    pub const TypeStructPacked = struct {
        decl: DeclIndex,
        zir_index: TrackedInst.Index,
        fields_len: u32,
        namespace: OptionalNamespaceIndex,
        backing_int_ty: Index,
        names_map: MapIndex,
        flags: Flags,

        pub const Flags = packed struct(u32) {
            any_captures: bool,
            /// Dependency loop detection when resolving field inits.
            field_inits_wip: bool,
            inits_resolved: bool,
            is_reified: bool,
            _: u28 = 0,
        };
    };

    /// At first I thought of storing the denormalized data externally, such as...
    ///
    /// * runtime field order
    /// * calculated field offsets
    /// * size and alignment of the struct
    ///
    /// ...since these can be computed based on the other data here. However,
    /// this data does need to be memoized, and therefore stored in memory
    /// while the compiler is running, in order to avoid O(N^2) logic in many
    /// places. Since the data can be stored compactly in the InternPool
    /// representation, it is better for memory usage to store denormalized data
    /// here, and potentially also better for performance as well. It's also simpler
    /// than coming up with some other scheme for the data.
    ///
    /// Trailing:
    /// 0. captures_len: u32 // if `any_captures`
    /// 1. capture: CaptureValue // for each `captures_len`
    /// 2. type_hash: PackedU64 // if `is_reified`
    /// 3. type: Index for each field in declared order
    /// 4. if not is_tuple:
    ///    names_map: MapIndex,
    ///    name: NullTerminatedString // for each field in declared order
    /// 5. if any_default_inits:
    ///    init: Index // for each field in declared order
    /// 6. if has_namespace:
    ///    namespace: NamespaceIndex
    /// 7. if any_aligned_fields:
    ///    align: Alignment // for each field in declared order
    /// 8. if any_comptime_fields:
    ///    field_is_comptime_bits: u32 // minimal number of u32s needed, LSB is field 0
    /// 9. if not is_extern:
    ///    field_index: RuntimeOrder // for each field in runtime order
    /// 10. field_offset: u32 // for each field in declared order, undef until layout_resolved
    pub const TypeStruct = struct {
        decl: DeclIndex,
        zir_index: TrackedInst.Index,
        fields_len: u32,
        flags: Flags,
        size: u32,

        pub const Flags = packed struct(u32) {
            any_captures: bool,
            is_extern: bool,
            known_non_opv: bool,
            requires_comptime: RequiresComptime,
            is_tuple: bool,
            assumed_runtime_bits: bool,
            assumed_pointer_aligned: bool,
            has_namespace: bool,
            any_comptime_fields: bool,
            any_default_inits: bool,
            any_aligned_fields: bool,
            /// `.none` until layout_resolved
            alignment: Alignment,
            /// Dependency loop detection when resolving struct alignment.
            alignment_wip: bool,
            /// Dependency loop detection when resolving field types.
            field_types_wip: bool,
            /// Dependency loop detection when resolving struct layout.
            layout_wip: bool,
            /// Indicates whether `size`, `alignment`, runtime field order, and
            /// field offets are populated.
            layout_resolved: bool,
            /// Dependency loop detection when resolving field inits.
            field_inits_wip: bool,
            /// Indicates whether `field_inits` has been resolved.
            inits_resolved: bool,
            // The types and all its fields have had their layout resolved. Even through pointer,
            // which `layout_resolved` does not ensure.
            fully_resolved: bool,
            is_reified: bool,
            _: u6 = 0,
        };
    };

    /// Trailing:
    /// 0. capture: CaptureValue // for each `captures_len`
    pub const TypeOpaque = struct {
        /// The opaque's owner Decl.
        decl: DeclIndex,
        /// Contains the declarations inside this opaque.
        namespace: OptionalNamespaceIndex,
        /// The index of the `opaque_decl` instruction.
        zir_index: TrackedInst.Index,
        /// `std.math.maxInt(u32)` indicates this type is reified.
        captures_len: u32,
    };
};

/// State that is mutable during semantic analysis. This data is not used for
/// equality or hashing, except for `inferred_error_set` which is considered
/// to be part of the type of the function.
pub const FuncAnalysis = packed struct(u32) {
    state: State,
    is_cold: bool,
    is_noinline: bool,
    calls_or_awaits_errorable_fn: bool,
    stack_alignment: Alignment,

    /// True if this function has an inferred error set.
    inferred_error_set: bool,

    _: u14 = 0,

    pub const State = enum(u8) {
        /// This function has not yet undergone analysis, because we have not
        /// seen a potential runtime call. It may be analyzed in future.
        none,
        /// Analysis for this function has been queued, but not yet completed.
        queued,
        /// This function intentionally only has ZIR generated because it is marked
        /// inline, which means no runtime version of the function will be generated.
        inline_only,
        in_progress,
        /// There will be a corresponding ErrorMsg in Module.failed_decls
        sema_failure,
        /// This function might be OK but it depends on another Decl which did not
        /// successfully complete semantic analysis.
        dependency_failure,
        /// There will be a corresponding ErrorMsg in Module.failed_decls.
        /// Indicates that semantic analysis succeeded, but code generation for
        /// this function failed.
        codegen_failure,
        /// Semantic analysis and code generation of this function succeeded.
        success,
    };
};

pub const Bytes = struct {
    /// The type of the aggregate
    ty: Index,
    /// Index into strings, of len ip.aggregateTypeLen(ty)
    bytes: String,
};

pub const Repeated = struct {
    /// The type of the aggregate.
    ty: Index,
    /// The value of every element.
    elem_val: Index,
};

/// Trailing:
/// 0. type: Index for each fields_len
/// 1. value: Index for each fields_len
/// 2. name: NullTerminatedString for each fields_len
/// The set of field names is omitted when the `Tag` is `type_tuple_anon`.
pub const TypeStructAnon = struct {
    fields_len: u32,
};

/// Having `SimpleType` and `SimpleValue` in separate enums makes it easier to
/// implement logic that only wants to deal with types because the logic can
/// ignore all simple values. Note that technically, types are values.
pub const SimpleType = enum(u32) {
    f16 = @intFromEnum(Index.f16_type),
    f32 = @intFromEnum(Index.f32_type),
    f64 = @intFromEnum(Index.f64_type),
    f80 = @intFromEnum(Index.f80_type),
    f128 = @intFromEnum(Index.f128_type),
    usize = @intFromEnum(Index.usize_type),
    isize = @intFromEnum(Index.isize_type),
    c_char = @intFromEnum(Index.c_char_type),
    c_short = @intFromEnum(Index.c_short_type),
    c_ushort = @intFromEnum(Index.c_ushort_type),
    c_int = @intFromEnum(Index.c_int_type),
    c_uint = @intFromEnum(Index.c_uint_type),
    c_long = @intFromEnum(Index.c_long_type),
    c_ulong = @intFromEnum(Index.c_ulong_type),
    c_longlong = @intFromEnum(Index.c_longlong_type),
    c_ulonglong = @intFromEnum(Index.c_ulonglong_type),
    c_longdouble = @intFromEnum(Index.c_longdouble_type),
    anyopaque = @intFromEnum(Index.anyopaque_type),
    bool = @intFromEnum(Index.bool_type),
    void = @intFromEnum(Index.void_type),
    type = @intFromEnum(Index.type_type),
    anyerror = @intFromEnum(Index.anyerror_type),
    comptime_int = @intFromEnum(Index.comptime_int_type),
    comptime_float = @intFromEnum(Index.comptime_float_type),
    noreturn = @intFromEnum(Index.noreturn_type),
    null = @intFromEnum(Index.null_type),
    undefined = @intFromEnum(Index.undefined_type),
    enum_literal = @intFromEnum(Index.enum_literal_type),

    atomic_order = @intFromEnum(Index.atomic_order_type),
    atomic_rmw_op = @intFromEnum(Index.atomic_rmw_op_type),
    calling_convention = @intFromEnum(Index.calling_convention_type),
    address_space = @intFromEnum(Index.address_space_type),
    float_mode = @intFromEnum(Index.float_mode_type),
    reduce_op = @intFromEnum(Index.reduce_op_type),
    call_modifier = @intFromEnum(Index.call_modifier_type),
    prefetch_options = @intFromEnum(Index.prefetch_options_type),
    export_options = @intFromEnum(Index.export_options_type),
    extern_options = @intFromEnum(Index.extern_options_type),
    type_info = @intFromEnum(Index.type_info_type),

    adhoc_inferred_error_set = @intFromEnum(Index.adhoc_inferred_error_set_type),
    generic_poison = @intFromEnum(Index.generic_poison_type),
};

pub const SimpleValue = enum(u32) {
    /// This is untyped `undefined`.
    undefined = @intFromEnum(Index.undef),
    void = @intFromEnum(Index.void_value),
    /// This is untyped `null`.
    null = @intFromEnum(Index.null_value),
    /// This is the untyped empty struct literal: `.{}`
    empty_struct = @intFromEnum(Index.empty_struct),
    true = @intFromEnum(Index.bool_true),
    false = @intFromEnum(Index.bool_false),
    @"unreachable" = @intFromEnum(Index.unreachable_value),

    generic_poison = @intFromEnum(Index.generic_poison),
};

/// Stored as a power-of-two, with one special value to indicate none.
pub const Alignment = enum(u6) {
    @"1" = 0,
    @"2" = 1,
    @"4" = 2,
    @"8" = 3,
    @"16" = 4,
    @"32" = 5,
    @"64" = 6,
    none = std.math.maxInt(u6),
    _,

    pub fn toByteUnits(a: Alignment) ?u64 {
        return switch (a) {
            .none => null,
            else => @as(u64, 1) << @intFromEnum(a),
        };
    }

    pub fn fromByteUnits(n: u64) Alignment {
        if (n == 0) return .none;
        assert(std.math.isPowerOfTwo(n));
        return @enumFromInt(@ctz(n));
    }

    pub fn fromNonzeroByteUnits(n: u64) Alignment {
        assert(n != 0);
        return fromByteUnits(n);
    }

    pub fn toLog2Units(a: Alignment) u6 {
        assert(a != .none);
        return @intFromEnum(a);
    }

    /// This is just a glorified `@enumFromInt` but using it can help
    /// document the intended conversion.
    /// The parameter uses a u32 for convenience at the callsite.
    pub fn fromLog2Units(a: u32) Alignment {
        assert(a != @intFromEnum(Alignment.none));
        return @enumFromInt(a);
    }

    pub fn order(lhs: Alignment, rhs: Alignment) std.math.Order {
        assert(lhs != .none);
        assert(rhs != .none);
        return std.math.order(@intFromEnum(lhs), @intFromEnum(rhs));
    }

    /// Relaxed comparison. We have this as default because a lot of callsites
    /// were upgraded from directly using comparison operators on byte units,
    /// with the `none` value represented by zero.
    /// Prefer `compareStrict` if possible.
    pub fn compare(lhs: Alignment, op: std.math.CompareOperator, rhs: Alignment) bool {
        return std.math.compare(lhs.toRelaxedCompareUnits(), op, rhs.toRelaxedCompareUnits());
    }

    pub fn compareStrict(lhs: Alignment, op: std.math.CompareOperator, rhs: Alignment) bool {
        assert(lhs != .none);
        assert(rhs != .none);
        return std.math.compare(@intFromEnum(lhs), op, @intFromEnum(rhs));
    }

    /// Treats `none` as zero.
    /// This matches previous behavior of using `@max` directly on byte units.
    /// Prefer `maxStrict` if possible.
    pub fn max(lhs: Alignment, rhs: Alignment) Alignment {
        if (lhs == .none) return rhs;
        if (rhs == .none) return lhs;
        return maxStrict(lhs, rhs);
    }

    pub fn maxStrict(lhs: Alignment, rhs: Alignment) Alignment {
        assert(lhs != .none);
        assert(rhs != .none);
        return @enumFromInt(@max(@intFromEnum(lhs), @intFromEnum(rhs)));
    }

    /// Treats `none` as zero.
    /// This matches previous behavior of using `@min` directly on byte units.
    /// Prefer `minStrict` if possible.
    pub fn min(lhs: Alignment, rhs: Alignment) Alignment {
        if (lhs == .none) return lhs;
        if (rhs == .none) return rhs;
        return minStrict(lhs, rhs);
    }

    pub fn minStrict(lhs: Alignment, rhs: Alignment) Alignment {
        assert(lhs != .none);
        assert(rhs != .none);
        return @enumFromInt(@min(@intFromEnum(lhs), @intFromEnum(rhs)));
    }

    /// Align an address forwards to this alignment.
    pub fn forward(a: Alignment, addr: u64) u64 {
        assert(a != .none);
        const x = (@as(u64, 1) << @intFromEnum(a)) - 1;
        return (addr + x) & ~x;
    }

    /// Align an address backwards to this alignment.
    pub fn backward(a: Alignment, addr: u64) u64 {
        assert(a != .none);
        const x = (@as(u64, 1) << @intFromEnum(a)) - 1;
        return addr & ~x;
    }

    /// Check if an address is aligned to this amount.
    pub fn check(a: Alignment, addr: u64) bool {
        assert(a != .none);
        return @ctz(addr) >= @intFromEnum(a);
    }

    /// An array of `Alignment` objects existing within the `extra` array.
    /// This type exists to provide a struct with lifetime that is
    /// not invalidated when items are added to the `InternPool`.
    pub const Slice = struct {
        tid: Zcu.PerThread.Id,
        start: u32,
        /// This is the number of alignment values, not the number of u32 elements.
        len: u32,

        pub const empty: Slice = .{ .tid = .main, .start = 0, .len = 0 };

        pub fn get(slice: Slice, ip: *const InternPool) []Alignment {
            // TODO: implement @ptrCast between slices changing the length
            const extra = ip.getLocalShared(slice.tid).extra.acquire();
            //const bytes: []u8 = @ptrCast(extra.view().items(.@"0")[slice.start..]);
            const bytes: []u8 = std.mem.sliceAsBytes(extra.view().items(.@"0")[slice.start..]);
            return @ptrCast(bytes[0..slice.len]);
        }
    };

    pub fn toRelaxedCompareUnits(a: Alignment) u8 {
        const n: u8 = @intFromEnum(a);
        assert(n <= @intFromEnum(Alignment.none));
        if (n == @intFromEnum(Alignment.none)) return 0;
        return n + 1;
    }

    const LlvmBuilderAlignment = @import("codegen/llvm/Builder.zig").Alignment;

    pub fn toLlvm(this: @This()) LlvmBuilderAlignment {
        return @enumFromInt(@intFromEnum(this));
    }

    pub fn fromLlvm(other: LlvmBuilderAlignment) @This() {
        return @enumFromInt(@intFromEnum(other));
    }
};

/// Used for non-sentineled arrays that have length fitting in u32, as well as
/// vectors.
pub const Vector = struct {
    len: u32,
    child: Index,
};

pub const Array = struct {
    len0: u32,
    len1: u32,
    child: Index,
    sentinel: Index,

    pub const Length = PackedU64;

    pub fn getLength(a: Array) u64 {
        return (PackedU64{
            .a = a.len0,
            .b = a.len1,
        }).get();
    }
};

/// Trailing:
/// 0. owner_union: Index // if `zir_index == .none`
/// 1. capture: CaptureValue // for each `captures_len`
/// 2. type_hash: PackedU64 // if reified (`captures_len == std.math.maxInt(u32)`)
/// 3. field name: NullTerminatedString for each fields_len; declaration order
/// 4. tag value: Index for each fields_len; declaration order
pub const EnumExplicit = struct {
    /// The Decl that corresponds to the enum itself.
    decl: DeclIndex,
    /// `std.math.maxInt(u32)` indicates this type is reified.
    captures_len: u32,
    /// This may be `none` if there are no declarations.
    namespace: OptionalNamespaceIndex,
    /// An integer type which is used for the numerical value of the enum, which
    /// has been explicitly provided by the enum declaration.
    int_tag_type: Index,
    fields_len: u32,
    /// Maps field names to declaration index.
    names_map: MapIndex,
    /// Maps field values to declaration index.
    /// If this is `none`, it means the trailing tag values are absent because
    /// they are auto-numbered.
    values_map: OptionalMapIndex,
    /// `none` means this is a generated tag type.
    /// There will be a trailing union type for which this is a tag.
    zir_index: TrackedInst.Index.Optional,
};

/// Trailing:
/// 0. owner_union: Index // if `zir_index == .none`
/// 1. capture: CaptureValue // for each `captures_len`
/// 2. type_hash: PackedU64 // if reified (`captures_len == std.math.maxInt(u32)`)
/// 3. field name: NullTerminatedString for each fields_len; declaration order
pub const EnumAuto = struct {
    /// The Decl that corresponds to the enum itself.
    decl: DeclIndex,
    /// `std.math.maxInt(u32)` indicates this type is reified.
    captures_len: u32,
    /// This may be `none` if there are no declarations.
    namespace: OptionalNamespaceIndex,
    /// An integer type which is used for the numerical value of the enum, which
    /// was inferred by Zig based on the number of tags.
    int_tag_type: Index,
    fields_len: u32,
    /// Maps field names to declaration index.
    names_map: MapIndex,
    /// `none` means this is a generated tag type.
    /// There will be a trailing union type for which this is a tag.
    zir_index: TrackedInst.Index.Optional,
};

pub const PackedU64 = packed struct(u64) {
    a: u32,
    b: u32,

    pub fn get(x: PackedU64) u64 {
        return @bitCast(x);
    }

    pub fn init(x: u64) PackedU64 {
        return @bitCast(x);
    }
};

pub const PtrDecl = struct {
    ty: Index,
    decl: DeclIndex,
    byte_offset_a: u32,
    byte_offset_b: u32,
    fn init(ty: Index, decl: DeclIndex, byte_offset: u64) @This() {
        return .{
            .ty = ty,
            .decl = decl,
            .byte_offset_a = @intCast(byte_offset >> 32),
            .byte_offset_b = @truncate(byte_offset),
        };
    }
    fn byteOffset(data: @This()) u64 {
        return @as(u64, data.byte_offset_a) << 32 | data.byte_offset_b;
    }
};

pub const PtrAnonDecl = struct {
    ty: Index,
    val: Index,
    byte_offset_a: u32,
    byte_offset_b: u32,
    fn init(ty: Index, val: Index, byte_offset: u64) @This() {
        return .{
            .ty = ty,
            .val = val,
            .byte_offset_a = @intCast(byte_offset >> 32),
            .byte_offset_b = @truncate(byte_offset),
        };
    }
    fn byteOffset(data: @This()) u64 {
        return @as(u64, data.byte_offset_a) << 32 | data.byte_offset_b;
    }
};

pub const PtrAnonDeclAligned = struct {
    ty: Index,
    val: Index,
    /// Must be nonequal to `ty`. Only the alignment from this value is important.
    orig_ty: Index,
    byte_offset_a: u32,
    byte_offset_b: u32,
    fn init(ty: Index, val: Index, orig_ty: Index, byte_offset: u64) @This() {
        return .{
            .ty = ty,
            .val = val,
            .orig_ty = orig_ty,
            .byte_offset_a = @intCast(byte_offset >> 32),
            .byte_offset_b = @truncate(byte_offset),
        };
    }
    fn byteOffset(data: @This()) u64 {
        return @as(u64, data.byte_offset_a) << 32 | data.byte_offset_b;
    }
};

pub const PtrComptimeAlloc = struct {
    ty: Index,
    index: ComptimeAllocIndex,
    byte_offset_a: u32,
    byte_offset_b: u32,
    fn init(ty: Index, index: ComptimeAllocIndex, byte_offset: u64) @This() {
        return .{
            .ty = ty,
            .index = index,
            .byte_offset_a = @intCast(byte_offset >> 32),
            .byte_offset_b = @truncate(byte_offset),
        };
    }
    fn byteOffset(data: @This()) u64 {
        return @as(u64, data.byte_offset_a) << 32 | data.byte_offset_b;
    }
};

pub const PtrComptimeField = struct {
    ty: Index,
    field_val: Index,
    byte_offset_a: u32,
    byte_offset_b: u32,
    fn init(ty: Index, field_val: Index, byte_offset: u64) @This() {
        return .{
            .ty = ty,
            .field_val = field_val,
            .byte_offset_a = @intCast(byte_offset >> 32),
            .byte_offset_b = @truncate(byte_offset),
        };
    }
    fn byteOffset(data: @This()) u64 {
        return @as(u64, data.byte_offset_a) << 32 | data.byte_offset_b;
    }
};

pub const PtrBase = struct {
    ty: Index,
    base: Index,
    byte_offset_a: u32,
    byte_offset_b: u32,
    fn init(ty: Index, base: Index, byte_offset: u64) @This() {
        return .{
            .ty = ty,
            .base = base,
            .byte_offset_a = @intCast(byte_offset >> 32),
            .byte_offset_b = @truncate(byte_offset),
        };
    }
    fn byteOffset(data: @This()) u64 {
        return @as(u64, data.byte_offset_a) << 32 | data.byte_offset_b;
    }
};

pub const PtrBaseIndex = struct {
    ty: Index,
    base: Index,
    index: Index,
    byte_offset_a: u32,
    byte_offset_b: u32,
    fn init(ty: Index, base: Index, index: Index, byte_offset: u64) @This() {
        return .{
            .ty = ty,
            .base = base,
            .index = index,
            .byte_offset_a = @intCast(byte_offset >> 32),
            .byte_offset_b = @truncate(byte_offset),
        };
    }
    fn byteOffset(data: @This()) u64 {
        return @as(u64, data.byte_offset_a) << 32 | data.byte_offset_b;
    }
};

pub const PtrInt = struct {
    ty: Index,
    byte_offset_a: u32,
    byte_offset_b: u32,
    fn init(ty: Index, byte_offset: u64) @This() {
        return .{
            .ty = ty,
            .byte_offset_a = @intCast(byte_offset >> 32),
            .byte_offset_b = @truncate(byte_offset),
        };
    }
    fn byteOffset(data: @This()) u64 {
        return @as(u64, data.byte_offset_a) << 32 | data.byte_offset_b;
    }
};

pub const PtrSlice = struct {
    /// The slice type.
    ty: Index,
    /// A many pointer value.
    ptr: Index,
    /// A usize value.
    len: Index,
};

/// Trailing: Limb for every limbs_len
pub const Int = packed struct {
    ty: Index,
    limbs_len: u32,

    const limbs_items_len = @divExact(@sizeOf(Int), @sizeOf(Limb));
};

pub const IntSmall = struct {
    ty: Index,
    value: u32,
};

pub const IntLazy = struct {
    ty: Index,
    lazy_ty: Index,
};

/// A f64 value, broken up into 2 u32 parts.
pub const Float64 = struct {
    piece0: u32,
    piece1: u32,

    pub fn get(self: Float64) f64 {
        const int_bits = @as(u64, self.piece0) | (@as(u64, self.piece1) << 32);
        return @bitCast(int_bits);
    }

    fn pack(val: f64) Float64 {
        const bits: u64 = @bitCast(val);
        return .{
            .piece0 = @truncate(bits),
            .piece1 = @truncate(bits >> 32),
        };
    }
};

/// A f80 value, broken up into 2 u32 parts and a u16 part zero-padded to a u32.
pub const Float80 = struct {
    piece0: u32,
    piece1: u32,
    piece2: u32, // u16 part, top bits

    pub fn get(self: Float80) f80 {
        const int_bits = @as(u80, self.piece0) |
            (@as(u80, self.piece1) << 32) |
            (@as(u80, self.piece2) << 64);
        return @bitCast(int_bits);
    }

    fn pack(val: f80) Float80 {
        const bits: u80 = @bitCast(val);
        return .{
            .piece0 = @truncate(bits),
            .piece1 = @truncate(bits >> 32),
            .piece2 = @truncate(bits >> 64),
        };
    }
};

/// A f128 value, broken up into 4 u32 parts.
pub const Float128 = struct {
    piece0: u32,
    piece1: u32,
    piece2: u32,
    piece3: u32,

    pub fn get(self: Float128) f128 {
        const int_bits = @as(u128, self.piece0) |
            (@as(u128, self.piece1) << 32) |
            (@as(u128, self.piece2) << 64) |
            (@as(u128, self.piece3) << 96);
        return @bitCast(int_bits);
    }

    fn pack(val: f128) Float128 {
        const bits: u128 = @bitCast(val);
        return .{
            .piece0 = @truncate(bits),
            .piece1 = @truncate(bits >> 32),
            .piece2 = @truncate(bits >> 64),
            .piece3 = @truncate(bits >> 96),
        };
    }
};

/// Trailing:
/// 0. arg value: Index for each args_len
pub const MemoizedCall = struct {
    func: Index,
    args_len: u32,
    result: Index,
};

pub fn init(ip: *InternPool, gpa: Allocator, available_threads: usize) !void {
    errdefer ip.deinit(gpa);
    assert(ip.locals.len == 0 and ip.shards.len == 0);
    assert(available_threads > 0 and available_threads <= std.math.maxInt(u8));

    const used_threads = if (single_threaded) 1 else available_threads;
    ip.locals = try gpa.alloc(Local, used_threads);
    @memset(ip.locals, .{
        .shared = .{
            .items = Local.List(Item).empty,
            .extra = Local.Extra.empty,
            .limbs = Local.Limbs.empty,
            .strings = Local.Strings.empty,

            .decls = Local.Decls.empty,
            .namespaces = Local.Namespaces.empty,
        },
        .mutate = .{
            .arena = .{},

            .items = Local.ListMutate.empty,
            .extra = Local.ListMutate.empty,
            .limbs = Local.ListMutate.empty,
            .strings = Local.ListMutate.empty,

            .decls = Local.BucketListMutate.empty,
            .namespaces = Local.BucketListMutate.empty,
        },
    });

    ip.tid_width = @intCast(std.math.log2_int_ceil(usize, used_threads));
    ip.tid_shift_31 = if (single_threaded) 0 else 31 - ip.tid_width;
    ip.tid_shift_32 = if (single_threaded) 0 else ip.tid_shift_31 +| 1;
    ip.shards = try gpa.alloc(Shard, @as(usize, 1) << ip.tid_width);
    @memset(ip.shards, .{
        .shared = .{
            .map = Shard.Map(Index).empty,
            .string_map = Shard.Map(OptionalNullTerminatedString).empty,
        },
        .mutate = .{
            .map = Shard.Mutate.empty,
            .string_map = Shard.Mutate.empty,
        },
    });

    // Reserve string index 0 for an empty string.
    assert((try ip.getOrPutString(gpa, .main, "", .no_embedded_nulls)) == .empty);

    // This inserts all the statically-known values into the intern pool in the
    // order expected.
    for (&static_keys, 0..) |key, key_index| switch (@as(Index, @enumFromInt(key_index))) {
        .empty_struct_type => assert(try ip.getAnonStructType(gpa, .main, .{
            .types = &.{},
            .names = &.{},
            .values = &.{},
        }) == .empty_struct_type),
        else => |expected_index| assert(try ip.get(gpa, .main, key) == expected_index),
    };

    if (std.debug.runtime_safety) {
        // Sanity check.
        assert(ip.indexToKey(.bool_true).simple_value == .true);
        assert(ip.indexToKey(.bool_false).simple_value == .false);

        const cc_inline = ip.indexToKey(.calling_convention_inline).enum_tag.int;
        const cc_c = ip.indexToKey(.calling_convention_c).enum_tag.int;

        assert(ip.indexToKey(cc_inline).int.storage.u64 ==
            @intFromEnum(std.builtin.CallingConvention.Inline));

        assert(ip.indexToKey(cc_c).int.storage.u64 ==
            @intFromEnum(std.builtin.CallingConvention.C));

        assert(ip.indexToKey(ip.typeOf(cc_inline)).int_type.bits ==
            @typeInfo(@typeInfo(std.builtin.CallingConvention).Enum.tag_type).Int.bits);
    }
}

pub fn deinit(ip: *InternPool, gpa: Allocator) void {
    for (ip.maps.items) |*map| map.deinit(gpa);
    ip.maps.deinit(gpa);

    ip.tracked_insts.deinit(gpa);

    ip.src_hash_deps.deinit(gpa);
    ip.decl_val_deps.deinit(gpa);
    ip.func_ies_deps.deinit(gpa);
    ip.namespace_deps.deinit(gpa);
    ip.namespace_name_deps.deinit(gpa);

    ip.first_dependency.deinit(gpa);

    ip.dep_entries.deinit(gpa);
    ip.free_dep_entries.deinit(gpa);

    ip.files.deinit(gpa);

    gpa.free(ip.shards);
    for (ip.locals) |*local| {
        const buckets_len = local.mutate.namespaces.buckets_list.len;
        if (buckets_len > 0) for (
            local.shared.namespaces.view().items(.@"0")[0..buckets_len],
            0..,
        ) |namespace_bucket, buckets_index| {
            for (namespace_bucket[0..if (buckets_index < buckets_len - 1)
                namespace_bucket.len
            else
                local.mutate.namespaces.last_bucket_len]) |*namespace|
            {
                namespace.decls.deinit(gpa);
                namespace.usingnamespace_set.deinit(gpa);
            }
        };
        local.mutate.arena.promote(gpa).deinit();
    }
    gpa.free(ip.locals);

    ip.* = undefined;
}

pub fn indexToKey(ip: *const InternPool, index: Index) Key {
    assert(index != .none);
    const unwrapped_index = index.unwrap(ip);
    const item = unwrapped_index.getItem(ip);
    const data = item.data;
    return switch (item.tag) {
        .removed => unreachable,
        .type_int_signed => .{
            .int_type = .{
                .signedness = .signed,
                .bits = @intCast(data),
            },
        },
        .type_int_unsigned => .{
            .int_type = .{
                .signedness = .unsigned,
                .bits = @intCast(data),
            },
        },
        .type_array_big => {
            const array_info = extraData(unwrapped_index.getExtra(ip), Array, data);
            return .{ .array_type = .{
                .len = array_info.getLength(),
                .child = array_info.child,
                .sentinel = array_info.sentinel,
            } };
        },
        .type_array_small => {
            const array_info = extraData(unwrapped_index.getExtra(ip), Vector, data);
            return .{ .array_type = .{
                .len = array_info.len,
                .child = array_info.child,
                .sentinel = .none,
            } };
        },
        .simple_type => .{ .simple_type = @enumFromInt(@intFromEnum(index)) },
        .simple_value => .{ .simple_value = @enumFromInt(@intFromEnum(index)) },

        .type_vector => {
            const vector_info = extraData(unwrapped_index.getExtra(ip), Vector, data);
            return .{ .vector_type = .{
                .len = vector_info.len,
                .child = vector_info.child,
            } };
        },

        .type_pointer => .{ .ptr_type = extraData(unwrapped_index.getExtra(ip), Tag.TypePointer, data) },

        .type_slice => {
            const many_ptr_index: Index = @enumFromInt(data);
            const many_ptr_unwrapped = many_ptr_index.unwrap(ip);
            const many_ptr_item = many_ptr_unwrapped.getItem(ip);
            assert(many_ptr_item.tag == .type_pointer);
            var ptr_info = extraData(many_ptr_unwrapped.getExtra(ip), Tag.TypePointer, many_ptr_item.data);
            ptr_info.flags.size = .Slice;
            return .{ .ptr_type = ptr_info };
        },

        .type_optional => .{ .opt_type = @enumFromInt(data) },
        .type_anyframe => .{ .anyframe_type = @enumFromInt(data) },

        .type_error_union => .{ .error_union_type = extraData(unwrapped_index.getExtra(ip), Key.ErrorUnionType, data) },
        .type_anyerror_union => .{ .error_union_type = .{
            .error_set_type = .anyerror_type,
            .payload_type = @enumFromInt(data),
        } },
        .type_error_set => .{ .error_set_type = extraErrorSet(unwrapped_index.tid, unwrapped_index.getExtra(ip), data) },
        .type_inferred_error_set => .{
            .inferred_error_set_type = @enumFromInt(data),
        },

        .type_opaque => .{ .opaque_type = ns: {
            const extra = extraDataTrail(unwrapped_index.getExtra(ip), Tag.TypeOpaque, data);
            if (extra.data.captures_len == std.math.maxInt(u32)) {
                break :ns .{ .reified = .{
                    .zir_index = extra.data.zir_index,
                    .type_hash = 0,
                } };
            }
            break :ns .{ .declared = .{
                .zir_index = extra.data.zir_index,
                .captures = .{ .owned = .{
                    .tid = unwrapped_index.tid,
                    .start = extra.end,
                    .len = extra.data.captures_len,
                } },
            } };
        } },

        .type_struct => .{ .struct_type = ns: {
            if (data == 0) break :ns .empty_struct;
            const extra_list = unwrapped_index.getExtra(ip);
            const extra = extraDataTrail(extra_list, Tag.TypeStruct, data);
            if (extra.data.flags.is_reified) {
                assert(!extra.data.flags.any_captures);
                break :ns .{ .reified = .{
                    .zir_index = extra.data.zir_index,
                    .type_hash = extraData(extra_list, PackedU64, extra.end).get(),
                } };
            }
            break :ns .{ .declared = .{
                .zir_index = extra.data.zir_index,
                .captures = .{ .owned = if (extra.data.flags.any_captures) .{
                    .tid = unwrapped_index.tid,
                    .start = extra.end + 1,
                    .len = extra_list.view().items(.@"0")[extra.end],
                } else CaptureValue.Slice.empty },
            } };
        } },

        .type_struct_packed, .type_struct_packed_inits => .{ .struct_type = ns: {
            const extra_list = unwrapped_index.getExtra(ip);
            const extra = extraDataTrail(extra_list, Tag.TypeStructPacked, data);
            if (extra.data.flags.is_reified) {
                assert(!extra.data.flags.any_captures);
                break :ns .{ .reified = .{
                    .zir_index = extra.data.zir_index,
                    .type_hash = extraData(extra_list, PackedU64, extra.end).get(),
                } };
            }
            break :ns .{ .declared = .{
                .zir_index = extra.data.zir_index,
                .captures = .{ .owned = if (extra.data.flags.any_captures) .{
                    .tid = unwrapped_index.tid,
                    .start = extra.end + 1,
                    .len = extra_list.view().items(.@"0")[extra.end],
                } else CaptureValue.Slice.empty },
            } };
        } },
        .type_struct_anon => .{ .anon_struct_type = extraTypeStructAnon(unwrapped_index.tid, unwrapped_index.getExtra(ip), data) },
        .type_tuple_anon => .{ .anon_struct_type = extraTypeTupleAnon(unwrapped_index.tid, unwrapped_index.getExtra(ip), data) },
        .type_union => .{ .union_type = ns: {
            const extra_list = unwrapped_index.getExtra(ip);
            const extra = extraDataTrail(extra_list, Tag.TypeUnion, data);
            if (extra.data.flags.is_reified) {
                assert(!extra.data.flags.any_captures);
                break :ns .{ .reified = .{
                    .zir_index = extra.data.zir_index,
                    .type_hash = extraData(extra_list, PackedU64, extra.end).get(),
                } };
            }
            break :ns .{ .declared = .{
                .zir_index = extra.data.zir_index,
                .captures = .{ .owned = if (extra.data.flags.any_captures) .{
                    .tid = unwrapped_index.tid,
                    .start = extra.end + 1,
                    .len = extra_list.view().items(.@"0")[extra.end],
                } else CaptureValue.Slice.empty },
            } };
        } },

        .type_enum_auto => .{ .enum_type = ns: {
            const extra_list = unwrapped_index.getExtra(ip);
            const extra = extraDataTrail(extra_list, EnumAuto, data);
            const zir_index = extra.data.zir_index.unwrap() orelse {
                assert(extra.data.captures_len == 0);
                break :ns .{ .generated_tag = .{
                    .union_type = @enumFromInt(extra_list.view().items(.@"0")[extra.end]),
                } };
            };
            if (extra.data.captures_len == std.math.maxInt(u32)) {
                break :ns .{ .reified = .{
                    .zir_index = zir_index,
                    .type_hash = extraData(extra_list, PackedU64, extra.end).get(),
                } };
            }
            break :ns .{ .declared = .{
                .zir_index = zir_index,
                .captures = .{ .owned = .{
                    .tid = unwrapped_index.tid,
                    .start = extra.end,
                    .len = extra.data.captures_len,
                } },
            } };
        } },
        .type_enum_explicit, .type_enum_nonexhaustive => .{ .enum_type = ns: {
            const extra_list = unwrapped_index.getExtra(ip);
            const extra = extraDataTrail(extra_list, EnumExplicit, data);
            const zir_index = extra.data.zir_index.unwrap() orelse {
                assert(extra.data.captures_len == 0);
                break :ns .{ .generated_tag = .{
                    .union_type = @enumFromInt(extra_list.view().items(.@"0")[extra.end]),
                } };
            };
            if (extra.data.captures_len == std.math.maxInt(u32)) {
                break :ns .{ .reified = .{
                    .zir_index = zir_index,
                    .type_hash = extraData(extra_list, PackedU64, extra.end).get(),
                } };
            }
            break :ns .{ .declared = .{
                .zir_index = zir_index,
                .captures = .{ .owned = .{
                    .tid = unwrapped_index.tid,
                    .start = extra.end,
                    .len = extra.data.captures_len,
                } },
            } };
        } },
        .type_function => .{ .func_type = extraFuncType(unwrapped_index.tid, unwrapped_index.getExtra(ip), data) },

        .undef => .{ .undef = @enumFromInt(data) },
        .opt_null => .{ .opt = .{
            .ty = @enumFromInt(data),
            .val = .none,
        } },
        .opt_payload => {
            const extra = extraData(unwrapped_index.getExtra(ip), Tag.TypeValue, data);
            return .{ .opt = .{
                .ty = extra.ty,
                .val = extra.val,
            } };
        },
        .ptr_decl => {
            const info = extraData(unwrapped_index.getExtra(ip), PtrDecl, data);
            return .{ .ptr = .{ .ty = info.ty, .base_addr = .{ .decl = info.decl }, .byte_offset = info.byteOffset() } };
        },
        .ptr_comptime_alloc => {
            const info = extraData(unwrapped_index.getExtra(ip), PtrComptimeAlloc, data);
            return .{ .ptr = .{ .ty = info.ty, .base_addr = .{ .comptime_alloc = info.index }, .byte_offset = info.byteOffset() } };
        },
        .ptr_anon_decl => {
            const info = extraData(unwrapped_index.getExtra(ip), PtrAnonDecl, data);
            return .{ .ptr = .{ .ty = info.ty, .base_addr = .{ .anon_decl = .{
                .val = info.val,
                .orig_ty = info.ty,
            } }, .byte_offset = info.byteOffset() } };
        },
        .ptr_anon_decl_aligned => {
            const info = extraData(unwrapped_index.getExtra(ip), PtrAnonDeclAligned, data);
            return .{ .ptr = .{ .ty = info.ty, .base_addr = .{ .anon_decl = .{
                .val = info.val,
                .orig_ty = info.orig_ty,
            } }, .byte_offset = info.byteOffset() } };
        },
        .ptr_comptime_field => {
            const info = extraData(unwrapped_index.getExtra(ip), PtrComptimeField, data);
            return .{ .ptr = .{ .ty = info.ty, .base_addr = .{ .comptime_field = info.field_val }, .byte_offset = info.byteOffset() } };
        },
        .ptr_int => {
            const info = extraData(unwrapped_index.getExtra(ip), PtrInt, data);
            return .{ .ptr = .{
                .ty = info.ty,
                .base_addr = .int,
                .byte_offset = info.byteOffset(),
            } };
        },
        .ptr_eu_payload => {
            const info = extraData(unwrapped_index.getExtra(ip), PtrBase, data);
            return .{ .ptr = .{ .ty = info.ty, .base_addr = .{ .eu_payload = info.base }, .byte_offset = info.byteOffset() } };
        },
        .ptr_opt_payload => {
            const info = extraData(unwrapped_index.getExtra(ip), PtrBase, data);
            return .{ .ptr = .{ .ty = info.ty, .base_addr = .{ .opt_payload = info.base }, .byte_offset = info.byteOffset() } };
        },
        .ptr_elem => {
            // Avoid `indexToKey` recursion by asserting the tag encoding.
            const info = extraData(unwrapped_index.getExtra(ip), PtrBaseIndex, data);
            const index_item = info.index.unwrap(ip).getItem(ip);
            return switch (index_item.tag) {
                .int_usize => .{ .ptr = .{ .ty = info.ty, .base_addr = .{ .arr_elem = .{
                    .base = info.base,
                    .index = index_item.data,
                } }, .byte_offset = info.byteOffset() } },
                .int_positive => @panic("TODO"), // implement along with behavior test coverage
                else => unreachable,
            };
        },
        .ptr_field => {
            // Avoid `indexToKey` recursion by asserting the tag encoding.
            const info = extraData(unwrapped_index.getExtra(ip), PtrBaseIndex, data);
            const index_item = info.index.unwrap(ip).getItem(ip);
            return switch (index_item.tag) {
                .int_usize => .{ .ptr = .{ .ty = info.ty, .base_addr = .{ .field = .{
                    .base = info.base,
                    .index = index_item.data,
                } }, .byte_offset = info.byteOffset() } },
                .int_positive => @panic("TODO"), // implement along with behavior test coverage
                else => unreachable,
            };
        },
        .ptr_slice => {
            const info = extraData(unwrapped_index.getExtra(ip), PtrSlice, data);
            return .{ .slice = .{
                .ty = info.ty,
                .ptr = info.ptr,
                .len = info.len,
            } };
        },
        .int_u8 => .{ .int = .{
            .ty = .u8_type,
            .storage = .{ .u64 = data },
        } },
        .int_u16 => .{ .int = .{
            .ty = .u16_type,
            .storage = .{ .u64 = data },
        } },
        .int_u32 => .{ .int = .{
            .ty = .u32_type,
            .storage = .{ .u64 = data },
        } },
        .int_i32 => .{ .int = .{
            .ty = .i32_type,
            .storage = .{ .i64 = @as(i32, @bitCast(data)) },
        } },
        .int_usize => .{ .int = .{
            .ty = .usize_type,
            .storage = .{ .u64 = data },
        } },
        .int_comptime_int_u32 => .{ .int = .{
            .ty = .comptime_int_type,
            .storage = .{ .u64 = data },
        } },
        .int_comptime_int_i32 => .{ .int = .{
            .ty = .comptime_int_type,
            .storage = .{ .i64 = @as(i32, @bitCast(data)) },
        } },
        .int_positive => ip.indexToKeyBigInt(unwrapped_index.tid, data, true),
        .int_negative => ip.indexToKeyBigInt(unwrapped_index.tid, data, false),
        .int_small => {
            const info = extraData(unwrapped_index.getExtra(ip), IntSmall, data);
            return .{ .int = .{
                .ty = info.ty,
                .storage = .{ .u64 = info.value },
            } };
        },
        .int_lazy_align, .int_lazy_size => |tag| {
            const info = extraData(unwrapped_index.getExtra(ip), IntLazy, data);
            return .{ .int = .{
                .ty = info.ty,
                .storage = switch (tag) {
                    .int_lazy_align => .{ .lazy_align = info.lazy_ty },
                    .int_lazy_size => .{ .lazy_size = info.lazy_ty },
                    else => unreachable,
                },
            } };
        },
        .float_f16 => .{ .float = .{
            .ty = .f16_type,
            .storage = .{ .f16 = @bitCast(@as(u16, @intCast(data))) },
        } },
        .float_f32 => .{ .float = .{
            .ty = .f32_type,
            .storage = .{ .f32 = @bitCast(data) },
        } },
        .float_f64 => .{ .float = .{
            .ty = .f64_type,
            .storage = .{ .f64 = extraData(unwrapped_index.getExtra(ip), Float64, data).get() },
        } },
        .float_f80 => .{ .float = .{
            .ty = .f80_type,
            .storage = .{ .f80 = extraData(unwrapped_index.getExtra(ip), Float80, data).get() },
        } },
        .float_f128 => .{ .float = .{
            .ty = .f128_type,
            .storage = .{ .f128 = extraData(unwrapped_index.getExtra(ip), Float128, data).get() },
        } },
        .float_c_longdouble_f80 => .{ .float = .{
            .ty = .c_longdouble_type,
            .storage = .{ .f80 = extraData(unwrapped_index.getExtra(ip), Float80, data).get() },
        } },
        .float_c_longdouble_f128 => .{ .float = .{
            .ty = .c_longdouble_type,
            .storage = .{ .f128 = extraData(unwrapped_index.getExtra(ip), Float128, data).get() },
        } },
        .float_comptime_float => .{ .float = .{
            .ty = .comptime_float_type,
            .storage = .{ .f128 = extraData(unwrapped_index.getExtra(ip), Float128, data).get() },
        } },
        .variable => {
            const extra = extraData(unwrapped_index.getExtra(ip), Tag.Variable, data);
            return .{ .variable = .{
                .ty = extra.ty,
                .init = extra.init,
                .decl = extra.decl,
                .lib_name = extra.lib_name,
                .is_extern = extra.flags.is_extern,
                .is_const = extra.flags.is_const,
                .is_threadlocal = extra.flags.is_threadlocal,
                .is_weak_linkage = extra.flags.is_weak_linkage,
            } };
        },
        .extern_func => .{ .extern_func = extraData(unwrapped_index.getExtra(ip), Tag.ExternFunc, data) },
        .func_instance => .{ .func = ip.extraFuncInstance(unwrapped_index.tid, unwrapped_index.getExtra(ip), data) },
        .func_decl => .{ .func = extraFuncDecl(unwrapped_index.tid, unwrapped_index.getExtra(ip), data) },
        .func_coerced => .{ .func = ip.extraFuncCoerced(unwrapped_index.getExtra(ip), data) },
        .only_possible_value => {
            const ty: Index = @enumFromInt(data);
            const ty_unwrapped = ty.unwrap(ip);
            const ty_extra = ty_unwrapped.getExtra(ip);
            const ty_item = ty_unwrapped.getItem(ip);
            return switch (ty_item.tag) {
                .type_array_big => {
                    const sentinel = @as(
                        *const [1]Index,
                        @ptrCast(&ty_extra.view().items(.@"0")[ty_item.data + std.meta.fieldIndex(Array, "sentinel").?]),
                    );
                    return .{ .aggregate = .{
                        .ty = ty,
                        .storage = .{ .elems = sentinel[0..@intFromBool(sentinel[0] != .none)] },
                    } };
                },
                .type_array_small,
                .type_vector,
                .type_struct_packed,
                => .{ .aggregate = .{
                    .ty = ty,
                    .storage = .{ .elems = &.{} },
                } },

                // There is only one possible value precisely due to the
                // fact that this values slice is fully populated!
                .type_struct, .type_struct_packed_inits => {
                    const info = loadStructType(ip, ty);
                    return .{ .aggregate = .{
                        .ty = ty,
                        .storage = .{ .elems = @ptrCast(info.field_inits.get(ip)) },
                    } };
                },

                // There is only one possible value precisely due to the
                // fact that this values slice is fully populated!
                .type_struct_anon, .type_tuple_anon => {
                    const type_struct_anon = extraDataTrail(ty_extra, TypeStructAnon, ty_item.data);
                    const fields_len = type_struct_anon.data.fields_len;
                    const values = ty_extra.view().items(.@"0")[type_struct_anon.end + fields_len ..][0..fields_len];
                    return .{ .aggregate = .{
                        .ty = ty,
                        .storage = .{ .elems = @ptrCast(values) },
                    } };
                },

                .type_enum_auto,
                .type_enum_explicit,
                .type_union,
                => .{ .empty_enum_value = ty },

                else => unreachable,
            };
        },
        .bytes => {
            const extra = extraData(unwrapped_index.getExtra(ip), Bytes, data);
            return .{ .aggregate = .{
                .ty = extra.ty,
                .storage = .{ .bytes = extra.bytes },
            } };
        },
        .aggregate => {
            const extra_list = unwrapped_index.getExtra(ip);
            const extra = extraDataTrail(extra_list, Tag.Aggregate, data);
            const len: u32 = @intCast(ip.aggregateTypeLenIncludingSentinel(extra.data.ty));
            const fields: []const Index = @ptrCast(extra_list.view().items(.@"0")[extra.end..][0..len]);
            return .{ .aggregate = .{
                .ty = extra.data.ty,
                .storage = .{ .elems = fields },
            } };
        },
        .repeated => {
            const extra = extraData(unwrapped_index.getExtra(ip), Repeated, data);
            return .{ .aggregate = .{
                .ty = extra.ty,
                .storage = .{ .repeated_elem = extra.elem_val },
            } };
        },
        .union_value => .{ .un = extraData(unwrapped_index.getExtra(ip), Key.Union, data) },
        .error_set_error => .{ .err = extraData(unwrapped_index.getExtra(ip), Key.Error, data) },
        .error_union_error => {
            const extra = extraData(unwrapped_index.getExtra(ip), Key.Error, data);
            return .{ .error_union = .{
                .ty = extra.ty,
                .val = .{ .err_name = extra.name },
            } };
        },
        .error_union_payload => {
            const extra = extraData(unwrapped_index.getExtra(ip), Tag.TypeValue, data);
            return .{ .error_union = .{
                .ty = extra.ty,
                .val = .{ .payload = extra.val },
            } };
        },
        .enum_literal => .{ .enum_literal = @enumFromInt(data) },
        .enum_tag => .{ .enum_tag = extraData(unwrapped_index.getExtra(ip), Tag.EnumTag, data) },

        .memoized_call => {
            const extra_list = unwrapped_index.getExtra(ip);
            const extra = extraDataTrail(extra_list, MemoizedCall, data);
            return .{ .memoized_call = .{
                .func = extra.data.func,
                .arg_values = @ptrCast(extra_list.view().items(.@"0")[extra.end..][0..extra.data.args_len]),
                .result = extra.data.result,
            } };
        },
    };
}

fn extraErrorSet(tid: Zcu.PerThread.Id, extra: Local.Extra, extra_index: u32) Key.ErrorSetType {
    const error_set = extraDataTrail(extra, Tag.ErrorSet, extra_index);
    return .{
        .names = .{
            .tid = tid,
            .start = @intCast(error_set.end),
            .len = error_set.data.names_len,
        },
        .names_map = error_set.data.names_map.toOptional(),
    };
}

fn extraTypeStructAnon(tid: Zcu.PerThread.Id, extra: Local.Extra, extra_index: u32) Key.AnonStructType {
    const type_struct_anon = extraDataTrail(extra, TypeStructAnon, extra_index);
    const fields_len = type_struct_anon.data.fields_len;
    return .{
        .types = .{
            .tid = tid,
            .start = type_struct_anon.end,
            .len = fields_len,
        },
        .values = .{
            .tid = tid,
            .start = type_struct_anon.end + fields_len,
            .len = fields_len,
        },
        .names = .{
            .tid = tid,
            .start = type_struct_anon.end + fields_len + fields_len,
            .len = fields_len,
        },
    };
}

fn extraTypeTupleAnon(tid: Zcu.PerThread.Id, extra: Local.Extra, extra_index: u32) Key.AnonStructType {
    const type_struct_anon = extraDataTrail(extra, TypeStructAnon, extra_index);
    const fields_len = type_struct_anon.data.fields_len;
    return .{
        .types = .{
            .tid = tid,
            .start = type_struct_anon.end,
            .len = fields_len,
        },
        .values = .{
            .tid = tid,
            .start = type_struct_anon.end + fields_len,
            .len = fields_len,
        },
        .names = .{
            .tid = tid,
            .start = 0,
            .len = 0,
        },
    };
}

fn extraFuncType(tid: Zcu.PerThread.Id, extra: Local.Extra, extra_index: u32) Key.FuncType {
    const type_function = extraDataTrail(extra, Tag.TypeFunction, extra_index);
    var trail_index: usize = type_function.end;
    const comptime_bits: u32 = if (!type_function.data.flags.has_comptime_bits) 0 else b: {
        const x = extra.view().items(.@"0")[trail_index];
        trail_index += 1;
        break :b x;
    };
    const noalias_bits: u32 = if (!type_function.data.flags.has_noalias_bits) 0 else b: {
        const x = extra.view().items(.@"0")[trail_index];
        trail_index += 1;
        break :b x;
    };
    return .{
        .param_types = .{
            .tid = tid,
            .start = @intCast(trail_index),
            .len = type_function.data.params_len,
        },
        .return_type = type_function.data.return_type,
        .comptime_bits = comptime_bits,
        .noalias_bits = noalias_bits,
        .cc = type_function.data.flags.cc,
        .is_var_args = type_function.data.flags.is_var_args,
        .is_noinline = type_function.data.flags.is_noinline,
        .cc_is_generic = type_function.data.flags.cc_is_generic,
        .section_is_generic = type_function.data.flags.section_is_generic,
        .addrspace_is_generic = type_function.data.flags.addrspace_is_generic,
        .is_generic = type_function.data.flags.is_generic,
    };
}

fn extraFuncDecl(tid: Zcu.PerThread.Id, extra: Local.Extra, extra_index: u32) Key.Func {
    const P = Tag.FuncDecl;
    const func_decl = extraDataTrail(extra, P, extra_index);
    return .{
        .tid = tid,
        .ty = func_decl.data.ty,
        .uncoerced_ty = func_decl.data.ty,
        .analysis_extra_index = extra_index + std.meta.fieldIndex(P, "analysis").?,
        .zir_body_inst_extra_index = extra_index + std.meta.fieldIndex(P, "zir_body_inst").?,
        .resolved_error_set_extra_index = if (func_decl.data.analysis.inferred_error_set) func_decl.end else 0,
        .branch_quota_extra_index = 0,
        .owner_decl = func_decl.data.owner_decl,
        .zir_body_inst = func_decl.data.zir_body_inst,
        .lbrace_line = func_decl.data.lbrace_line,
        .rbrace_line = func_decl.data.rbrace_line,
        .lbrace_column = func_decl.data.lbrace_column,
        .rbrace_column = func_decl.data.rbrace_column,
        .generic_owner = .none,
        .comptime_args = Index.Slice.empty,
    };
}

fn extraFuncInstance(ip: *const InternPool, tid: Zcu.PerThread.Id, extra: Local.Extra, extra_index: u32) Key.Func {
    const extra_items = extra.view().items(.@"0");
    const analysis_extra_index = extra_index + std.meta.fieldIndex(Tag.FuncInstance, "analysis").?;
    const analysis: FuncAnalysis = @bitCast(@atomicLoad(u32, &extra_items[analysis_extra_index], .monotonic));
    const owner_decl: DeclIndex = @enumFromInt(extra_items[extra_index + std.meta.fieldIndex(Tag.FuncInstance, "owner_decl").?]);
    const ty: Index = @enumFromInt(extra_items[extra_index + std.meta.fieldIndex(Tag.FuncInstance, "ty").?]);
    const generic_owner: Index = @enumFromInt(extra_items[extra_index + std.meta.fieldIndex(Tag.FuncInstance, "generic_owner").?]);
    const func_decl = ip.funcDeclInfo(generic_owner);
    const end_extra_index = extra_index + @as(u32, @typeInfo(Tag.FuncInstance).Struct.fields.len);
    return .{
        .tid = tid,
        .ty = ty,
        .uncoerced_ty = ty,
        .analysis_extra_index = analysis_extra_index,
        .zir_body_inst_extra_index = func_decl.zir_body_inst_extra_index,
        .resolved_error_set_extra_index = if (analysis.inferred_error_set) end_extra_index else 0,
        .branch_quota_extra_index = extra_index + std.meta.fieldIndex(Tag.FuncInstance, "branch_quota").?,
        .owner_decl = owner_decl,
        .zir_body_inst = func_decl.zir_body_inst,
        .lbrace_line = func_decl.lbrace_line,
        .rbrace_line = func_decl.rbrace_line,
        .lbrace_column = func_decl.lbrace_column,
        .rbrace_column = func_decl.rbrace_column,
        .generic_owner = generic_owner,
        .comptime_args = .{
            .tid = tid,
            .start = end_extra_index + @intFromBool(analysis.inferred_error_set),
            .len = ip.funcTypeParamsLen(func_decl.ty),
        },
    };
}

fn extraFuncCoerced(ip: *const InternPool, extra: Local.Extra, extra_index: u32) Key.Func {
    const func_coerced = extraData(extra, Tag.FuncCoerced, extra_index);
    const func_unwrapped = func_coerced.func.unwrap(ip);
    const sub_item = func_unwrapped.getItem(ip);
    const func_extra = func_unwrapped.getExtra(ip);
    var func: Key.Func = switch (sub_item.tag) {
        .func_instance => ip.extraFuncInstance(func_unwrapped.tid, func_extra, sub_item.data),
        .func_decl => extraFuncDecl(func_unwrapped.tid, func_extra, sub_item.data),
        else => unreachable,
    };
    func.ty = func_coerced.ty;
    return func;
}

fn indexToKeyBigInt(ip: *const InternPool, tid: Zcu.PerThread.Id, limb_index: u32, positive: bool) Key {
    const limbs_items = ip.getLocalShared(tid).getLimbs().view().items(.@"0");
    const int: Int = @bitCast(limbs_items[limb_index..][0..Int.limbs_items_len].*);
    return .{ .int = .{
        .ty = int.ty,
        .storage = .{ .big_int = .{
            .limbs = limbs_items[limb_index + Int.limbs_items_len ..][0..int.limbs_len],
            .positive = positive,
        } },
    } };
}

const GetOrPutKey = union(enum) {
    existing: Index,
    new: struct {
        ip: *InternPool,
        tid: Zcu.PerThread.Id,
        shard: *Shard,
        map_index: u32,
    },

    fn put(gop: *GetOrPutKey) Index {
        return gop.putAt(0);
    }
    fn putAt(gop: *GetOrPutKey, offset: u32) Index {
        switch (gop.*) {
            .existing => unreachable,
            .new => |info| {
                const index = Index.Unwrapped.wrap(.{
                    .tid = info.tid,
                    .index = info.ip.getLocal(info.tid).mutate.items.len - 1 - offset,
                }, info.ip);
                info.shard.shared.map.entries[info.map_index].release(index);
                info.shard.mutate.map.len += 1;
                info.shard.mutate.map.mutex.unlock();
                gop.* = .{ .existing = index };
                return index;
            },
        }
    }

    fn assign(gop: *GetOrPutKey, new_gop: GetOrPutKey) void {
        gop.deinit();
        gop.* = new_gop;
    }

    fn deinit(gop: *GetOrPutKey) void {
        switch (gop.*) {
            .existing => {},
            .new => |info| info.shard.mutate.map.mutex.unlock(),
        }
        gop.* = undefined;
    }
};
fn getOrPutKey(
    ip: *InternPool,
    gpa: Allocator,
    tid: Zcu.PerThread.Id,
    key: Key,
) Allocator.Error!GetOrPutKey {
    const full_hash = key.hash64(ip);
    const hash: u32 = @truncate(full_hash >> 32);
    const shard = &ip.shards[@intCast(full_hash & (ip.shards.len - 1))];
    var map = shard.shared.map.acquire();
    const Map = @TypeOf(map);
    var map_mask = map.header().mask();
    var map_index = hash;
    while (true) : (map_index += 1) {
        map_index &= map_mask;
        const entry = &map.entries[map_index];
        const index = entry.acquire();
        if (index == .none) break;
        if (entry.hash != hash) continue;
        if (ip.indexToKey(index).eql(key, ip)) return .{ .existing = index };
    }
    shard.mutate.map.mutex.lock();
    errdefer shard.mutate.map.mutex.unlock();
    if (map.entries != shard.shared.map.entries) {
        map = shard.shared.map;
        map_mask = map.header().mask();
        map_index = hash;
    }
    while (true) : (map_index += 1) {
        map_index &= map_mask;
        const entry = &map.entries[map_index];
        const index = entry.value;
        if (index == .none) break;
        if (entry.hash != hash) continue;
        if (ip.indexToKey(index).eql(key, ip)) {
            defer shard.mutate.map.mutex.unlock();
            return .{ .existing = index };
        }
    }
    const map_header = map.header().*;
    if (shard.mutate.map.len >= map_header.capacity * 3 / 5) {
        const arena_state = &ip.getLocal(tid).mutate.arena;
        var arena = arena_state.promote(gpa);
        defer arena_state.* = arena.state;
        const new_map_capacity = map_header.capacity * 2;
        const new_map_buf = try arena.allocator().alignedAlloc(
            u8,
            Map.alignment,
            Map.entries_offset + new_map_capacity * @sizeOf(Map.Entry),
        );
        const new_map: Map = .{ .entries = @ptrCast(new_map_buf[Map.entries_offset..].ptr) };
        new_map.header().* = .{ .capacity = new_map_capacity };
        @memset(new_map.entries[0..new_map_capacity], .{ .value = .none, .hash = undefined });
        const new_map_mask = new_map.header().mask();
        map_index = 0;
        while (map_index < map_header.capacity) : (map_index += 1) {
            const entry = &map.entries[map_index];
            const index = entry.value;
            if (index == .none) continue;
            const item_hash = entry.hash;
            var new_map_index = item_hash;
            while (true) : (new_map_index += 1) {
                new_map_index &= new_map_mask;
                const new_entry = &new_map.entries[new_map_index];
                if (new_entry.value != .none) continue;
                new_entry.* = .{
                    .value = index,
                    .hash = item_hash,
                };
                break;
            }
        }
        map = new_map;
        map_index = hash;
        while (true) : (map_index += 1) {
            map_index &= new_map_mask;
            if (map.entries[map_index].value == .none) break;
        }
        shard.shared.map.release(new_map);
    }
    map.entries[map_index].hash = hash;
    return .{ .new = .{
        .ip = ip,
        .tid = tid,
        .shard = shard,
        .map_index = map_index,
    } };
}

pub fn get(ip: *InternPool, gpa: Allocator, tid: Zcu.PerThread.Id, key: Key) Allocator.Error!Index {
    var gop = try ip.getOrPutKey(gpa, tid, key);
    defer gop.deinit();
    if (gop == .existing) return gop.existing;
    const local = ip.getLocal(tid);
    const items = local.getMutableItems(gpa);
    const extra = local.getMutableExtra(gpa);
    try items.ensureUnusedCapacity(1);
    switch (key) {
        .int_type => |int_type| {
            const t: Tag = switch (int_type.signedness) {
                .signed => .type_int_signed,
                .unsigned => .type_int_unsigned,
            };
            items.appendAssumeCapacity(.{
                .tag = t,
                .data = int_type.bits,
            });
        },
        .ptr_type => |ptr_type| {
            assert(ptr_type.child != .none);
            assert(ptr_type.sentinel == .none or ip.typeOf(ptr_type.sentinel) == ptr_type.child);

            if (ptr_type.flags.size == .Slice) {
                var new_key = key;
                new_key.ptr_type.flags.size = .Many;
                const ptr_type_index = try ip.get(gpa, tid, new_key);
                gop.assign(try ip.getOrPutKey(gpa, tid, key));

                try items.ensureUnusedCapacity(1);
                items.appendAssumeCapacity(.{
                    .tag = .type_slice,
                    .data = @intFromEnum(ptr_type_index),
                });
                return gop.put();
            }

            var ptr_type_adjusted = ptr_type;
            if (ptr_type.flags.size == .C) ptr_type_adjusted.flags.is_allowzero = true;

            items.appendAssumeCapacity(.{
                .tag = .type_pointer,
                .data = try addExtra(extra, ptr_type_adjusted),
            });
        },
        .array_type => |array_type| {
            assert(array_type.child != .none);
            assert(array_type.sentinel == .none or ip.typeOf(array_type.sentinel) == array_type.child);

            if (std.math.cast(u32, array_type.len)) |len| {
                if (array_type.sentinel == .none) {
                    items.appendAssumeCapacity(.{
                        .tag = .type_array_small,
                        .data = try addExtra(extra, Vector{
                            .len = len,
                            .child = array_type.child,
                        }),
                    });
                    return gop.put();
                }
            }

            const length = Array.Length.init(array_type.len);
            items.appendAssumeCapacity(.{
                .tag = .type_array_big,
                .data = try addExtra(extra, Array{
                    .len0 = length.a,
                    .len1 = length.b,
                    .child = array_type.child,
                    .sentinel = array_type.sentinel,
                }),
            });
        },
        .vector_type => |vector_type| {
            items.appendAssumeCapacity(.{
                .tag = .type_vector,
                .data = try addExtra(extra, Vector{
                    .len = vector_type.len,
                    .child = vector_type.child,
                }),
            });
        },
        .opt_type => |payload_type| {
            assert(payload_type != .none);
            items.appendAssumeCapacity(.{
                .tag = .type_optional,
                .data = @intFromEnum(payload_type),
            });
        },
        .anyframe_type => |payload_type| {
            // payload_type might be none, indicating the type is `anyframe`.
            items.appendAssumeCapacity(.{
                .tag = .type_anyframe,
                .data = @intFromEnum(payload_type),
            });
        },
        .error_union_type => |error_union_type| {
            items.appendAssumeCapacity(if (error_union_type.error_set_type == .anyerror_type) .{
                .tag = .type_anyerror_union,
                .data = @intFromEnum(error_union_type.payload_type),
            } else .{
                .tag = .type_error_union,
                .data = try addExtra(extra, error_union_type),
            });
        },
        .error_set_type => |error_set_type| {
            assert(error_set_type.names_map == .none);
            assert(std.sort.isSorted(NullTerminatedString, error_set_type.names.get(ip), {}, NullTerminatedString.indexLessThan));
            const names = error_set_type.names.get(ip);
            const names_map = try ip.addMap(gpa, names.len);
            addStringsToMap(ip, names_map, names);
            const names_len = error_set_type.names.len;
            try extra.ensureUnusedCapacity(@typeInfo(Tag.ErrorSet).Struct.fields.len + names_len);
            items.appendAssumeCapacity(.{
                .tag = .type_error_set,
                .data = addExtraAssumeCapacity(extra, Tag.ErrorSet{
                    .names_len = names_len,
                    .names_map = names_map,
                }),
            });
            extra.appendSliceAssumeCapacity(.{@ptrCast(error_set_type.names.get(ip))});
        },
        .inferred_error_set_type => |ies_index| {
            items.appendAssumeCapacity(.{
                .tag = .type_inferred_error_set,
                .data = @intFromEnum(ies_index),
            });
        },
        .simple_type => |simple_type| {
            assert(@intFromEnum(simple_type) == items.mutate.len);
            items.appendAssumeCapacity(.{
                .tag = .simple_type,
                .data = 0, // avoid writing `undefined` bits to a file
            });
        },
        .simple_value => |simple_value| {
            assert(@intFromEnum(simple_value) == items.mutate.len);
            items.appendAssumeCapacity(.{
                .tag = .simple_value,
                .data = 0, // avoid writing `undefined` bits to a file
            });
        },
        .undef => |ty| {
            assert(ty != .none);
            items.appendAssumeCapacity(.{
                .tag = .undef,
                .data = @intFromEnum(ty),
            });
        },

        .struct_type => unreachable, // use getStructType() instead
        .anon_struct_type => unreachable, // use getAnonStructType() instead
        .union_type => unreachable, // use getUnionType() instead
        .opaque_type => unreachable, // use getOpaqueType() instead

        .enum_type => unreachable, // use getEnumType() instead
        .func_type => unreachable, // use getFuncType() instead
        .extern_func => unreachable, // use getExternFunc() instead
        .func => unreachable, // use getFuncInstance() or getFuncDecl() instead

        .variable => |variable| {
            const has_init = variable.init != .none;
            if (has_init) assert(variable.ty == ip.typeOf(variable.init));
            items.appendAssumeCapacity(.{
                .tag = .variable,
                .data = try addExtra(extra, Tag.Variable{
                    .ty = variable.ty,
                    .init = variable.init,
                    .decl = variable.decl,
                    .lib_name = variable.lib_name,
                    .flags = .{
                        .is_extern = variable.is_extern,
                        .is_const = variable.is_const,
                        .is_threadlocal = variable.is_threadlocal,
                        .is_weak_linkage = variable.is_weak_linkage,
                    },
                }),
            });
        },

        .slice => |slice| {
            assert(ip.indexToKey(slice.ty).ptr_type.flags.size == .Slice);
            assert(ip.indexToKey(ip.typeOf(slice.ptr)).ptr_type.flags.size == .Many);
            items.appendAssumeCapacity(.{
                .tag = .ptr_slice,
                .data = try addExtra(extra, PtrSlice{
                    .ty = slice.ty,
                    .ptr = slice.ptr,
                    .len = slice.len,
                }),
            });
        },

        .ptr => |ptr| {
            const ptr_type = ip.indexToKey(ptr.ty).ptr_type;
            assert(ptr_type.flags.size != .Slice);
            items.appendAssumeCapacity(switch (ptr.base_addr) {
                .decl => |decl| .{
                    .tag = .ptr_decl,
                    .data = try addExtra(extra, PtrDecl.init(ptr.ty, decl, ptr.byte_offset)),
                },
                .comptime_alloc => |alloc_index| .{
                    .tag = .ptr_comptime_alloc,
                    .data = try addExtra(extra, PtrComptimeAlloc.init(ptr.ty, alloc_index, ptr.byte_offset)),
                },
                .anon_decl => |anon_decl| if (ptrsHaveSameAlignment(ip, ptr.ty, ptr_type, anon_decl.orig_ty)) item: {
                    if (ptr.ty != anon_decl.orig_ty) {
                        var new_key = key;
                        new_key.ptr.base_addr.anon_decl.orig_ty = ptr.ty;
                        gop.assign(try ip.getOrPutKey(gpa, tid, new_key));
                        if (gop == .existing) return gop.existing;
                    }
                    break :item .{
                        .tag = .ptr_anon_decl,
                        .data = try addExtra(extra, PtrAnonDecl.init(ptr.ty, anon_decl.val, ptr.byte_offset)),
                    };
                } else .{
                    .tag = .ptr_anon_decl_aligned,
                    .data = try addExtra(extra, PtrAnonDeclAligned.init(ptr.ty, anon_decl.val, anon_decl.orig_ty, ptr.byte_offset)),
                },
                .comptime_field => |field_val| item: {
                    assert(field_val != .none);
                    break :item .{
                        .tag = .ptr_comptime_field,
                        .data = try addExtra(extra, PtrComptimeField.init(ptr.ty, field_val, ptr.byte_offset)),
                    };
                },
                .eu_payload, .opt_payload => |base| item: {
                    switch (ptr.base_addr) {
                        .eu_payload => assert(ip.indexToKey(
                            ip.indexToKey(ip.typeOf(base)).ptr_type.child,
                        ) == .error_union_type),
                        .opt_payload => assert(ip.indexToKey(
                            ip.indexToKey(ip.typeOf(base)).ptr_type.child,
                        ) == .opt_type),
                        else => unreachable,
                    }
                    break :item .{
                        .tag = switch (ptr.base_addr) {
                            .eu_payload => .ptr_eu_payload,
                            .opt_payload => .ptr_opt_payload,
                            else => unreachable,
                        },
                        .data = try addExtra(extra, PtrBase.init(ptr.ty, base, ptr.byte_offset)),
                    };
                },
                .int => .{
                    .tag = .ptr_int,
                    .data = try addExtra(extra, PtrInt.init(ptr.ty, ptr.byte_offset)),
                },
                .arr_elem, .field => |base_index| {
                    const base_ptr_type = ip.indexToKey(ip.typeOf(base_index.base)).ptr_type;
                    switch (ptr.base_addr) {
                        .arr_elem => assert(base_ptr_type.flags.size == .Many),
                        .field => {
                            assert(base_ptr_type.flags.size == .One);
                            switch (ip.indexToKey(base_ptr_type.child)) {
                                .anon_struct_type => |anon_struct_type| {
                                    assert(ptr.base_addr == .field);
                                    assert(base_index.index < anon_struct_type.types.len);
                                },
                                .struct_type => {
                                    assert(ptr.base_addr == .field);
                                    assert(base_index.index < ip.loadStructType(base_ptr_type.child).field_types.len);
                                },
                                .union_type => {
                                    const union_type = ip.loadUnionType(base_ptr_type.child);
                                    assert(ptr.base_addr == .field);
                                    assert(base_index.index < union_type.field_types.len);
                                },
                                .ptr_type => |slice_type| {
                                    assert(ptr.base_addr == .field);
                                    assert(slice_type.flags.size == .Slice);
                                    assert(base_index.index < 2);
                                },
                                else => unreachable,
                            }
                        },
                        else => unreachable,
                    }
                    const index_index = try ip.get(gpa, tid, .{ .int = .{
                        .ty = .usize_type,
                        .storage = .{ .u64 = base_index.index },
                    } });
                    gop.assign(try ip.getOrPutKey(gpa, tid, key));
                    try items.ensureUnusedCapacity(1);
                    items.appendAssumeCapacity(.{
                        .tag = switch (ptr.base_addr) {
                            .arr_elem => .ptr_elem,
                            .field => .ptr_field,
                            else => unreachable,
                        },
                        .data = try addExtra(extra, PtrBaseIndex.init(ptr.ty, base_index.base, index_index, ptr.byte_offset)),
                    });
                    return gop.put();
                },
            });
        },

        .opt => |opt| {
            assert(ip.isOptionalType(opt.ty));
            assert(opt.val == .none or ip.indexToKey(opt.ty).opt_type == ip.typeOf(opt.val));
            items.appendAssumeCapacity(if (opt.val == .none) .{
                .tag = .opt_null,
                .data = @intFromEnum(opt.ty),
            } else .{
                .tag = .opt_payload,
                .data = try addExtra(extra, Tag.TypeValue{
                    .ty = opt.ty,
                    .val = opt.val,
                }),
            });
        },

        .int => |int| b: {
            assert(ip.isIntegerType(int.ty));
            switch (int.storage) {
                .u64, .i64, .big_int => {},
                .lazy_align, .lazy_size => |lazy_ty| {
                    items.appendAssumeCapacity(.{
                        .tag = switch (int.storage) {
                            else => unreachable,
                            .lazy_align => .int_lazy_align,
                            .lazy_size => .int_lazy_size,
                        },
                        .data = try addExtra(extra, IntLazy{
                            .ty = int.ty,
                            .lazy_ty = lazy_ty,
                        }),
                    });
                    return gop.put();
                },
            }
            switch (int.ty) {
                .u8_type => switch (int.storage) {
                    .big_int => |big_int| {
                        items.appendAssumeCapacity(.{
                            .tag = .int_u8,
                            .data = big_int.to(u8) catch unreachable,
                        });
                        break :b;
                    },
                    inline .u64, .i64 => |x| {
                        items.appendAssumeCapacity(.{
                            .tag = .int_u8,
                            .data = @as(u8, @intCast(x)),
                        });
                        break :b;
                    },
                    .lazy_align, .lazy_size => unreachable,
                },
                .u16_type => switch (int.storage) {
                    .big_int => |big_int| {
                        items.appendAssumeCapacity(.{
                            .tag = .int_u16,
                            .data = big_int.to(u16) catch unreachable,
                        });
                        break :b;
                    },
                    inline .u64, .i64 => |x| {
                        items.appendAssumeCapacity(.{
                            .tag = .int_u16,
                            .data = @as(u16, @intCast(x)),
                        });
                        break :b;
                    },
                    .lazy_align, .lazy_size => unreachable,
                },
                .u32_type => switch (int.storage) {
                    .big_int => |big_int| {
                        items.appendAssumeCapacity(.{
                            .tag = .int_u32,
                            .data = big_int.to(u32) catch unreachable,
                        });
                        break :b;
                    },
                    inline .u64, .i64 => |x| {
                        items.appendAssumeCapacity(.{
                            .tag = .int_u32,
                            .data = @as(u32, @intCast(x)),
                        });
                        break :b;
                    },
                    .lazy_align, .lazy_size => unreachable,
                },
                .i32_type => switch (int.storage) {
                    .big_int => |big_int| {
                        const casted = big_int.to(i32) catch unreachable;
                        items.appendAssumeCapacity(.{
                            .tag = .int_i32,
                            .data = @as(u32, @bitCast(casted)),
                        });
                        break :b;
                    },
                    inline .u64, .i64 => |x| {
                        items.appendAssumeCapacity(.{
                            .tag = .int_i32,
                            .data = @as(u32, @bitCast(@as(i32, @intCast(x)))),
                        });
                        break :b;
                    },
                    .lazy_align, .lazy_size => unreachable,
                },
                .usize_type => switch (int.storage) {
                    .big_int => |big_int| {
                        if (big_int.to(u32)) |casted| {
                            items.appendAssumeCapacity(.{
                                .tag = .int_usize,
                                .data = casted,
                            });
                            break :b;
                        } else |_| {}
                    },
                    inline .u64, .i64 => |x| {
                        if (std.math.cast(u32, x)) |casted| {
                            items.appendAssumeCapacity(.{
                                .tag = .int_usize,
                                .data = casted,
                            });
                            break :b;
                        }
                    },
                    .lazy_align, .lazy_size => unreachable,
                },
                .comptime_int_type => switch (int.storage) {
                    .big_int => |big_int| {
                        if (big_int.to(u32)) |casted| {
                            items.appendAssumeCapacity(.{
                                .tag = .int_comptime_int_u32,
                                .data = casted,
                            });
                            break :b;
                        } else |_| {}
                        if (big_int.to(i32)) |casted| {
                            items.appendAssumeCapacity(.{
                                .tag = .int_comptime_int_i32,
                                .data = @as(u32, @bitCast(casted)),
                            });
                            break :b;
                        } else |_| {}
                    },
                    inline .u64, .i64 => |x| {
                        if (std.math.cast(u32, x)) |casted| {
                            items.appendAssumeCapacity(.{
                                .tag = .int_comptime_int_u32,
                                .data = casted,
                            });
                            break :b;
                        }
                        if (std.math.cast(i32, x)) |casted| {
                            items.appendAssumeCapacity(.{
                                .tag = .int_comptime_int_i32,
                                .data = @as(u32, @bitCast(casted)),
                            });
                            break :b;
                        }
                    },
                    .lazy_align, .lazy_size => unreachable,
                },
                else => {},
            }
            switch (int.storage) {
                .big_int => |big_int| {
                    if (big_int.to(u32)) |casted| {
                        items.appendAssumeCapacity(.{
                            .tag = .int_small,
                            .data = try addExtra(extra, IntSmall{
                                .ty = int.ty,
                                .value = casted,
                            }),
                        });
                        return gop.put();
                    } else |_| {}

                    const tag: Tag = if (big_int.positive) .int_positive else .int_negative;
                    try addInt(ip, gpa, tid, int.ty, tag, big_int.limbs);
                },
                inline .u64, .i64 => |x| {
                    if (std.math.cast(u32, x)) |casted| {
                        items.appendAssumeCapacity(.{
                            .tag = .int_small,
                            .data = try addExtra(extra, IntSmall{
                                .ty = int.ty,
                                .value = casted,
                            }),
                        });
                        return gop.put();
                    }

                    var buf: [2]Limb = undefined;
                    const big_int = BigIntMutable.init(&buf, x).toConst();
                    const tag: Tag = if (big_int.positive) .int_positive else .int_negative;
                    try addInt(ip, gpa, tid, int.ty, tag, big_int.limbs);
                },
                .lazy_align, .lazy_size => unreachable,
            }
        },

        .err => |err| {
            assert(ip.isErrorSetType(err.ty));
            items.appendAssumeCapacity(.{
                .tag = .error_set_error,
                .data = try addExtra(extra, err),
            });
        },

        .error_union => |error_union| {
            assert(ip.isErrorUnionType(error_union.ty));
            items.appendAssumeCapacity(switch (error_union.val) {
                .err_name => |err_name| .{
                    .tag = .error_union_error,
                    .data = try addExtra(extra, Key.Error{
                        .ty = error_union.ty,
                        .name = err_name,
                    }),
                },
                .payload => |payload| .{
                    .tag = .error_union_payload,
                    .data = try addExtra(extra, Tag.TypeValue{
                        .ty = error_union.ty,
                        .val = payload,
                    }),
                },
            });
        },

        .enum_literal => |enum_literal| items.appendAssumeCapacity(.{
            .tag = .enum_literal,
            .data = @intFromEnum(enum_literal),
        }),

        .enum_tag => |enum_tag| {
            assert(ip.isEnumType(enum_tag.ty));
            switch (ip.indexToKey(enum_tag.ty)) {
                .simple_type => assert(ip.isIntegerType(ip.typeOf(enum_tag.int))),
                .enum_type => assert(ip.typeOf(enum_tag.int) == ip.loadEnumType(enum_tag.ty).tag_ty),
                else => unreachable,
            }
            items.appendAssumeCapacity(.{
                .tag = .enum_tag,
                .data = try addExtra(extra, enum_tag),
            });
        },

        .empty_enum_value => |enum_or_union_ty| items.appendAssumeCapacity(.{
            .tag = .only_possible_value,
            .data = @intFromEnum(enum_or_union_ty),
        }),

        .float => |float| {
            switch (float.ty) {
                .f16_type => items.appendAssumeCapacity(.{
                    .tag = .float_f16,
                    .data = @as(u16, @bitCast(float.storage.f16)),
                }),
                .f32_type => items.appendAssumeCapacity(.{
                    .tag = .float_f32,
                    .data = @as(u32, @bitCast(float.storage.f32)),
                }),
                .f64_type => items.appendAssumeCapacity(.{
                    .tag = .float_f64,
                    .data = try addExtra(extra, Float64.pack(float.storage.f64)),
                }),
                .f80_type => items.appendAssumeCapacity(.{
                    .tag = .float_f80,
                    .data = try addExtra(extra, Float80.pack(float.storage.f80)),
                }),
                .f128_type => items.appendAssumeCapacity(.{
                    .tag = .float_f128,
                    .data = try addExtra(extra, Float128.pack(float.storage.f128)),
                }),
                .c_longdouble_type => switch (float.storage) {
                    .f80 => |x| items.appendAssumeCapacity(.{
                        .tag = .float_c_longdouble_f80,
                        .data = try addExtra(extra, Float80.pack(x)),
                    }),
                    inline .f16, .f32, .f64, .f128 => |x| items.appendAssumeCapacity(.{
                        .tag = .float_c_longdouble_f128,
                        .data = try addExtra(extra, Float128.pack(x)),
                    }),
                },
                .comptime_float_type => items.appendAssumeCapacity(.{
                    .tag = .float_comptime_float,
                    .data = try addExtra(extra, Float128.pack(float.storage.f128)),
                }),
                else => unreachable,
            }
        },

        .aggregate => |aggregate| {
            const ty_key = ip.indexToKey(aggregate.ty);
            const len = ip.aggregateTypeLen(aggregate.ty);
            const child = switch (ty_key) {
                .array_type => |array_type| array_type.child,
                .vector_type => |vector_type| vector_type.child,
                .anon_struct_type, .struct_type => .none,
                else => unreachable,
            };
            const sentinel = switch (ty_key) {
                .array_type => |array_type| array_type.sentinel,
                .vector_type, .anon_struct_type, .struct_type => .none,
                else => unreachable,
            };
            const len_including_sentinel = len + @intFromBool(sentinel != .none);
            switch (aggregate.storage) {
                .bytes => |bytes| {
                    assert(child == .u8_type);
                    if (sentinel != .none) {
                        assert(bytes.at(@intCast(len), ip) == ip.indexToKey(sentinel).int.storage.u64);
                    }
                },
                .elems => |elems| {
                    if (elems.len != len) {
                        assert(elems.len == len_including_sentinel);
                        assert(elems[@intCast(len)] == sentinel);
                    }
                },
                .repeated_elem => |elem| {
                    assert(sentinel == .none or elem == sentinel);
                },
            }
            switch (ty_key) {
                .array_type, .vector_type => {
                    for (aggregate.storage.values()) |elem| {
                        assert(ip.typeOf(elem) == child);
                    }
                },
                .struct_type => {
                    for (aggregate.storage.values(), ip.loadStructType(aggregate.ty).field_types.get(ip)) |elem, field_ty| {
                        assert(ip.typeOf(elem) == field_ty);
                    }
                },
                .anon_struct_type => |anon_struct_type| {
                    for (aggregate.storage.values(), anon_struct_type.types.get(ip)) |elem, ty| {
                        assert(ip.typeOf(elem) == ty);
                    }
                },
                else => unreachable,
            }

            if (len == 0) {
                items.appendAssumeCapacity(.{
                    .tag = .only_possible_value,
                    .data = @intFromEnum(aggregate.ty),
                });
                return gop.put();
            }

            switch (ty_key) {
                .anon_struct_type => |anon_struct_type| opv: {
                    switch (aggregate.storage) {
                        .bytes => |bytes| for (anon_struct_type.values.get(ip), bytes.at(0, ip)..) |value, byte| {
                            if (value == .none) break :opv;
                            switch (ip.indexToKey(value)) {
                                .undef => break :opv,
                                .int => |int| switch (int.storage) {
                                    .u64 => |x| if (x != byte) break :opv,
                                    else => break :opv,
                                },
                                else => unreachable,
                            }
                        },
                        .elems => |elems| if (!std.mem.eql(
                            Index,
                            anon_struct_type.values.get(ip),
                            elems,
                        )) break :opv,
                        .repeated_elem => |elem| for (anon_struct_type.values.get(ip)) |value| {
                            if (value != elem) break :opv;
                        },
                    }
                    // This encoding works thanks to the fact that, as we just verified,
                    // the type itself contains a slice of values that can be provided
                    // in the aggregate fields.
                    items.appendAssumeCapacity(.{
                        .tag = .only_possible_value,
                        .data = @intFromEnum(aggregate.ty),
                    });
                    return gop.put();
                },
                else => {},
            }

            repeated: {
                switch (aggregate.storage) {
                    .bytes => |bytes| for (bytes.toSlice(len, ip)[1..]) |byte|
                        if (byte != bytes.at(0, ip)) break :repeated,
                    .elems => |elems| for (elems[1..@intCast(len)]) |elem|
                        if (elem != elems[0]) break :repeated,
                    .repeated_elem => {},
                }
                const elem = switch (aggregate.storage) {
                    .bytes => |bytes| elem: {
                        const elem = try ip.get(gpa, tid, .{ .int = .{
                            .ty = .u8_type,
                            .storage = .{ .u64 = bytes.at(0, ip) },
                        } });
                        gop.assign(try ip.getOrPutKey(gpa, tid, key));
                        try items.ensureUnusedCapacity(1);
                        break :elem elem;
                    },
                    .elems => |elems| elems[0],
                    .repeated_elem => |elem| elem,
                };

                try extra.ensureUnusedCapacity(@typeInfo(Repeated).Struct.fields.len);
                items.appendAssumeCapacity(.{
                    .tag = .repeated,
                    .data = addExtraAssumeCapacity(extra, Repeated{
                        .ty = aggregate.ty,
                        .elem_val = elem,
                    }),
                });
                return gop.put();
            }

            if (child == .u8_type) bytes: {
                const strings = ip.getLocal(tid).getMutableStrings(gpa);
                const start = strings.mutate.len;
                try strings.ensureUnusedCapacity(@intCast(len_including_sentinel + 1));
                try extra.ensureUnusedCapacity(@typeInfo(Bytes).Struct.fields.len);
                switch (aggregate.storage) {
                    .bytes => |bytes| strings.appendSliceAssumeCapacity(.{bytes.toSlice(len, ip)}),
                    .elems => |elems| for (elems[0..@intCast(len)]) |elem| switch (ip.indexToKey(elem)) {
                        .undef => {
                            strings.shrinkRetainingCapacity(start);
                            break :bytes;
                        },
                        .int => |int| strings.appendAssumeCapacity(.{@intCast(int.storage.u64)}),
                        else => unreachable,
                    },
                    .repeated_elem => |elem| switch (ip.indexToKey(elem)) {
                        .undef => break :bytes,
                        .int => |int| @memset(
                            strings.addManyAsSliceAssumeCapacity(@intCast(len))[0],
                            @intCast(int.storage.u64),
                        ),
                        else => unreachable,
                    },
                }
                if (sentinel != .none) strings.appendAssumeCapacity(.{
                    @intCast(ip.indexToKey(sentinel).int.storage.u64),
                });
                const string = try ip.getOrPutTrailingString(
                    gpa,
                    tid,
                    @intCast(len_including_sentinel),
                    .maybe_embedded_nulls,
                );
                items.appendAssumeCapacity(.{
                    .tag = .bytes,
                    .data = addExtraAssumeCapacity(extra, Bytes{
                        .ty = aggregate.ty,
                        .bytes = string,
                    }),
                });
                return gop.put();
            }

            try extra.ensureUnusedCapacity(
                @typeInfo(Tag.Aggregate).Struct.fields.len + @as(usize, @intCast(len_including_sentinel + 1)),
            );
            items.appendAssumeCapacity(.{
                .tag = .aggregate,
                .data = addExtraAssumeCapacity(extra, Tag.Aggregate{
                    .ty = aggregate.ty,
                }),
            });
            extra.appendSliceAssumeCapacity(.{@ptrCast(aggregate.storage.elems)});
            if (sentinel != .none) extra.appendAssumeCapacity(.{@intFromEnum(sentinel)});
        },

        .un => |un| {
            assert(un.ty != .none);
            assert(un.val != .none);
            items.appendAssumeCapacity(.{
                .tag = .union_value,
                .data = try addExtra(extra, un),
            });
        },

        .memoized_call => |memoized_call| {
            for (memoized_call.arg_values) |arg| assert(arg != .none);
            try extra.ensureUnusedCapacity(@typeInfo(MemoizedCall).Struct.fields.len +
                memoized_call.arg_values.len);
            items.appendAssumeCapacity(.{
                .tag = .memoized_call,
                .data = addExtraAssumeCapacity(extra, MemoizedCall{
                    .func = memoized_call.func,
                    .args_len = @intCast(memoized_call.arg_values.len),
                    .result = memoized_call.result,
                }),
            });
            extra.appendSliceAssumeCapacity(.{@ptrCast(memoized_call.arg_values)});
        },
    }
    return gop.put();
}

pub const UnionTypeInit = struct {
    flags: packed struct {
        runtime_tag: LoadedUnionType.RuntimeTag,
        any_aligned_fields: bool,
        layout: std.builtin.Type.ContainerLayout,
        status: LoadedUnionType.Status,
        requires_comptime: RequiresComptime,
        assumed_runtime_bits: bool,
        assumed_pointer_aligned: bool,
        alignment: Alignment,
    },
    has_namespace: bool,
    fields_len: u32,
    enum_tag_ty: Index,
    /// May have length 0 which leaves the values unset until later.
    field_types: []const Index,
    /// May have length 0 which leaves the values unset until later.
    /// The logic for `any_aligned_fields` is asserted to have been done before
    /// calling this function.
    field_aligns: []const Alignment,
    key: union(enum) {
        declared: struct {
            zir_index: TrackedInst.Index,
            captures: []const CaptureValue,
        },
        reified: struct {
            zir_index: TrackedInst.Index,
            type_hash: u64,
        },
    },
};

pub fn getUnionType(
    ip: *InternPool,
    gpa: Allocator,
    tid: Zcu.PerThread.Id,
    ini: UnionTypeInit,
) Allocator.Error!WipNamespaceType.Result {
    var gop = try ip.getOrPutKey(gpa, tid, .{ .union_type = switch (ini.key) {
        .declared => |d| .{ .declared = .{
            .zir_index = d.zir_index,
            .captures = .{ .external = d.captures },
        } },
        .reified => |r| .{ .reified = .{
            .zir_index = r.zir_index,
            .type_hash = r.type_hash,
        } },
    } });
    defer gop.deinit();
    if (gop == .existing) return .{ .existing = gop.existing };

    const local = ip.getLocal(tid);
    const items = local.getMutableItems(gpa);
    try items.ensureUnusedCapacity(1);
    const extra = local.getMutableExtra(gpa);

    const align_elements_len = if (ini.flags.any_aligned_fields) (ini.fields_len + 3) / 4 else 0;
    const align_element: u32 = @bitCast([1]u8{@intFromEnum(Alignment.none)} ** 4);
    try extra.ensureUnusedCapacity(@typeInfo(Tag.TypeUnion).Struct.fields.len +
        // TODO: fmt bug
        // zig fmt: off
        switch (ini.key) {
            .declared => |d| @intFromBool(d.captures.len != 0) + d.captures.len,
            .reified => 2, // type_hash: PackedU64
        } +
        // zig fmt: on
        ini.fields_len + // field types
        align_elements_len);

    const extra_index = addExtraAssumeCapacity(extra, Tag.TypeUnion{
        .flags = .{
            .any_captures = ini.key == .declared and ini.key.declared.captures.len != 0,
            .runtime_tag = ini.flags.runtime_tag,
            .any_aligned_fields = ini.flags.any_aligned_fields,
            .layout = ini.flags.layout,
            .status = ini.flags.status,
            .requires_comptime = ini.flags.requires_comptime,
            .assumed_runtime_bits = ini.flags.assumed_runtime_bits,
            .assumed_pointer_aligned = ini.flags.assumed_pointer_aligned,
            .alignment = ini.flags.alignment,
            .is_reified = ini.key == .reified,
        },
        .fields_len = ini.fields_len,
        .size = std.math.maxInt(u32),
        .padding = std.math.maxInt(u32),
        .decl = undefined, // set by `finish`
        .namespace = .none, // set by `finish`
        .tag_ty = ini.enum_tag_ty,
        .zir_index = switch (ini.key) {
            inline else => |x| x.zir_index,
        },
    });

    items.appendAssumeCapacity(.{
        .tag = .type_union,
        .data = extra_index,
    });

    switch (ini.key) {
        .declared => |d| if (d.captures.len != 0) {
            extra.appendAssumeCapacity(.{@intCast(d.captures.len)});
            extra.appendSliceAssumeCapacity(.{@ptrCast(d.captures)});
        },
        .reified => |r| _ = addExtraAssumeCapacity(extra, PackedU64.init(r.type_hash)),
    }

    // field types
    if (ini.field_types.len > 0) {
        assert(ini.field_types.len == ini.fields_len);
        extra.appendSliceAssumeCapacity(.{@ptrCast(ini.field_types)});
    } else {
        extra.appendNTimesAssumeCapacity(.{@intFromEnum(Index.none)}, ini.fields_len);
    }

    // field alignments
    if (ini.flags.any_aligned_fields) {
        extra.appendNTimesAssumeCapacity(.{align_element}, align_elements_len);
        if (ini.field_aligns.len > 0) {
            assert(ini.field_aligns.len == ini.fields_len);
            @memcpy((Alignment.Slice{
                .tid = tid,
                .start = @intCast(extra.mutate.len - align_elements_len),
                .len = @intCast(ini.field_aligns.len),
            }).get(ip), ini.field_aligns);
        }
    } else {
        assert(ini.field_aligns.len == 0);
    }

    return .{ .wip = .{
        .tid = tid,
        .index = gop.put(),
        .decl_extra_index = extra_index + std.meta.fieldIndex(Tag.TypeUnion, "decl").?,
        .namespace_extra_index = if (ini.has_namespace)
            extra_index + std.meta.fieldIndex(Tag.TypeUnion, "namespace").?
        else
            null,
    } };
}

pub const WipNamespaceType = struct {
    tid: Zcu.PerThread.Id,
    index: Index,
    decl_extra_index: u32,
    namespace_extra_index: ?u32,
    pub fn finish(wip: WipNamespaceType, ip: *InternPool, decl: DeclIndex, namespace: OptionalNamespaceIndex) Index {
        const extra_items = ip.getLocalShared(wip.tid).extra.acquire().view().items(.@"0");
        extra_items[wip.decl_extra_index] = @intFromEnum(decl);
        if (wip.namespace_extra_index) |i| {
            extra_items[i] = @intFromEnum(namespace.unwrap().?);
        } else {
            assert(namespace == .none);
        }
        return wip.index;
    }
    pub fn cancel(wip: WipNamespaceType, ip: *InternPool, tid: Zcu.PerThread.Id) void {
        ip.remove(tid, wip.index);
    }

    pub const Result = union(enum) {
        wip: WipNamespaceType,
        existing: Index,
    };
};

pub const StructTypeInit = struct {
    layout: std.builtin.Type.ContainerLayout,
    fields_len: u32,
    known_non_opv: bool,
    requires_comptime: RequiresComptime,
    is_tuple: bool,
    any_comptime_fields: bool,
    any_default_inits: bool,
    inits_resolved: bool,
    any_aligned_fields: bool,
    has_namespace: bool,
    key: union(enum) {
        declared: struct {
            zir_index: TrackedInst.Index,
            captures: []const CaptureValue,
        },
        reified: struct {
            zir_index: TrackedInst.Index,
            type_hash: u64,
        },
    },
};

pub fn getStructType(
    ip: *InternPool,
    gpa: Allocator,
    tid: Zcu.PerThread.Id,
    ini: StructTypeInit,
) Allocator.Error!WipNamespaceType.Result {
    var gop = try ip.getOrPutKey(gpa, tid, .{ .struct_type = switch (ini.key) {
        .declared => |d| .{ .declared = .{
            .zir_index = d.zir_index,
            .captures = .{ .external = d.captures },
        } },
        .reified => |r| .{ .reified = .{
            .zir_index = r.zir_index,
            .type_hash = r.type_hash,
        } },
    } });
    defer gop.deinit();
    if (gop == .existing) return .{ .existing = gop.existing };

    const local = ip.getLocal(tid);
    const items = local.getMutableItems(gpa);
    const extra = local.getMutableExtra(gpa);

    const names_map = try ip.addMap(gpa, ini.fields_len);
    errdefer _ = ip.maps.pop();

    const zir_index = switch (ini.key) {
        inline else => |x| x.zir_index,
    };

    const is_extern = switch (ini.layout) {
        .auto => false,
        .@"extern" => true,
        .@"packed" => {
            try extra.ensureUnusedCapacity(@typeInfo(Tag.TypeStructPacked).Struct.fields.len +
                // TODO: fmt bug
                // zig fmt: off
                switch (ini.key) {
                    .declared => |d| @intFromBool(d.captures.len != 0) + d.captures.len,
                    .reified => 2, // type_hash: PackedU64
                } +
                // zig fmt: on
                ini.fields_len + // types
                ini.fields_len + // names
                ini.fields_len); // inits
            const extra_index = addExtraAssumeCapacity(extra, Tag.TypeStructPacked{
                .decl = undefined, // set by `finish`
                .zir_index = zir_index,
                .fields_len = ini.fields_len,
                .namespace = .none,
                .backing_int_ty = .none,
                .names_map = names_map,
                .flags = .{
                    .any_captures = ini.key == .declared and ini.key.declared.captures.len != 0,
                    .field_inits_wip = false,
                    .inits_resolved = ini.inits_resolved,
                    .is_reified = ini.key == .reified,
                },
            });
            try items.append(.{
                .tag = if (ini.any_default_inits) .type_struct_packed_inits else .type_struct_packed,
                .data = extra_index,
            });
            switch (ini.key) {
                .declared => |d| if (d.captures.len != 0) {
                    extra.appendAssumeCapacity(.{@intCast(d.captures.len)});
                    extra.appendSliceAssumeCapacity(.{@ptrCast(d.captures)});
                },
                .reified => |r| {
                    _ = addExtraAssumeCapacity(extra, PackedU64.init(r.type_hash));
                },
            }
            extra.appendNTimesAssumeCapacity(.{@intFromEnum(Index.none)}, ini.fields_len);
            extra.appendNTimesAssumeCapacity(.{@intFromEnum(OptionalNullTerminatedString.none)}, ini.fields_len);
            if (ini.any_default_inits) {
                extra.appendNTimesAssumeCapacity(.{@intFromEnum(Index.none)}, ini.fields_len);
            }
            return .{ .wip = .{
                .tid = tid,
                .index = gop.put(),
                .decl_extra_index = extra_index + std.meta.fieldIndex(Tag.TypeStructPacked, "decl").?,
                .namespace_extra_index = if (ini.has_namespace)
                    extra_index + std.meta.fieldIndex(Tag.TypeStructPacked, "namespace").?
                else
                    null,
            } };
        },
    };

    const align_elements_len = if (ini.any_aligned_fields) (ini.fields_len + 3) / 4 else 0;
    const align_element: u32 = @bitCast([1]u8{@intFromEnum(Alignment.none)} ** 4);
    const comptime_elements_len = if (ini.any_comptime_fields) (ini.fields_len + 31) / 32 else 0;

    try extra.ensureUnusedCapacity(@typeInfo(Tag.TypeStruct).Struct.fields.len +
        // TODO: fmt bug
        // zig fmt: off
        switch (ini.key) {
            .declared => |d| @intFromBool(d.captures.len != 0) + d.captures.len,
            .reified => 2, // type_hash: PackedU64
        } +
        // zig fmt: on
        (ini.fields_len * 5) + // types, names, inits, runtime order, offsets
        align_elements_len + comptime_elements_len +
        2); // names_map + namespace
    const extra_index = addExtraAssumeCapacity(extra, Tag.TypeStruct{
        .decl = undefined, // set by `finish`
        .zir_index = zir_index,
        .fields_len = ini.fields_len,
        .size = std.math.maxInt(u32),
        .flags = .{
            .any_captures = ini.key == .declared and ini.key.declared.captures.len != 0,
            .is_extern = is_extern,
            .known_non_opv = ini.known_non_opv,
            .requires_comptime = ini.requires_comptime,
            .is_tuple = ini.is_tuple,
            .assumed_runtime_bits = false,
            .assumed_pointer_aligned = false,
            .has_namespace = ini.has_namespace,
            .any_comptime_fields = ini.any_comptime_fields,
            .any_default_inits = ini.any_default_inits,
            .any_aligned_fields = ini.any_aligned_fields,
            .alignment = .none,
            .alignment_wip = false,
            .field_types_wip = false,
            .layout_wip = false,
            .layout_resolved = false,
            .field_inits_wip = false,
            .inits_resolved = ini.inits_resolved,
            .fully_resolved = false,
            .is_reified = ini.key == .reified,
        },
    });
    try items.append(.{
        .tag = .type_struct,
        .data = extra_index,
    });
    switch (ini.key) {
        .declared => |d| if (d.captures.len != 0) {
            extra.appendAssumeCapacity(.{@intCast(d.captures.len)});
            extra.appendSliceAssumeCapacity(.{@ptrCast(d.captures)});
        },
        .reified => |r| {
            _ = addExtraAssumeCapacity(extra, PackedU64.init(r.type_hash));
        },
    }
    extra.appendNTimesAssumeCapacity(.{@intFromEnum(Index.none)}, ini.fields_len);
    if (!ini.is_tuple) {
        extra.appendAssumeCapacity(.{@intFromEnum(names_map)});
        extra.appendNTimesAssumeCapacity(.{@intFromEnum(OptionalNullTerminatedString.none)}, ini.fields_len);
    }
    if (ini.any_default_inits) {
        extra.appendNTimesAssumeCapacity(.{@intFromEnum(Index.none)}, ini.fields_len);
    }
    const namespace_extra_index: ?u32 = if (ini.has_namespace) i: {
        extra.appendAssumeCapacity(undefined); // set by `finish`
        break :i @intCast(extra.mutate.len - 1);
    } else null;
    if (ini.any_aligned_fields) {
        extra.appendNTimesAssumeCapacity(.{align_element}, align_elements_len);
    }
    if (ini.any_comptime_fields) {
        extra.appendNTimesAssumeCapacity(.{0}, comptime_elements_len);
    }
    if (ini.layout == .auto) {
        extra.appendNTimesAssumeCapacity(.{@intFromEnum(LoadedStructType.RuntimeOrder.unresolved)}, ini.fields_len);
    }
    extra.appendNTimesAssumeCapacity(.{std.math.maxInt(u32)}, ini.fields_len);
    return .{ .wip = .{
        .tid = tid,
        .index = gop.put(),
        .decl_extra_index = extra_index + std.meta.fieldIndex(Tag.TypeStruct, "decl").?,
        .namespace_extra_index = namespace_extra_index,
    } };
}

pub const AnonStructTypeInit = struct {
    types: []const Index,
    /// This may be empty, indicating this is a tuple.
    names: []const NullTerminatedString,
    /// These elements may be `none`, indicating runtime-known.
    values: []const Index,
};

pub fn getAnonStructType(
    ip: *InternPool,
    gpa: Allocator,
    tid: Zcu.PerThread.Id,
    ini: AnonStructTypeInit,
) Allocator.Error!Index {
    assert(ini.types.len == ini.values.len);
    for (ini.types) |elem| assert(elem != .none);

    const local = ip.getLocal(tid);
    const items = local.getMutableItems(gpa);
    const extra = local.getMutableExtra(gpa);

    const prev_extra_len = extra.mutate.len;
    const fields_len: u32 = @intCast(ini.types.len);

    try items.ensureUnusedCapacity(1);
    try extra.ensureUnusedCapacity(
        @typeInfo(TypeStructAnon).Struct.fields.len + (fields_len * 3),
    );

    const extra_index = addExtraAssumeCapacity(extra, TypeStructAnon{
        .fields_len = fields_len,
    });
    extra.appendSliceAssumeCapacity(.{@ptrCast(ini.types)});
    extra.appendSliceAssumeCapacity(.{@ptrCast(ini.values)});
    errdefer extra.mutate.len = prev_extra_len;

    var gop = try ip.getOrPutKey(gpa, tid, .{
        .anon_struct_type = if (ini.names.len == 0) extraTypeTupleAnon(tid, extra.list.*, extra_index) else k: {
            assert(ini.names.len == ini.types.len);
            extra.appendSliceAssumeCapacity(.{@ptrCast(ini.names)});
            break :k extraTypeStructAnon(tid, extra.list.*, extra_index);
        },
    });
    defer gop.deinit();
    if (gop == .existing) {
        extra.mutate.len = prev_extra_len;
        return gop.existing;
    }

    items.appendAssumeCapacity(.{
        .tag = if (ini.names.len == 0) .type_tuple_anon else .type_struct_anon,
        .data = extra_index,
    });
    return gop.put();
}

/// This is equivalent to `Key.FuncType` but adjusted to have a slice for `param_types`.
pub const GetFuncTypeKey = struct {
    param_types: []const Index,
    return_type: Index,
    comptime_bits: u32 = 0,
    noalias_bits: u32 = 0,
    /// `null` means generic.
    cc: ?std.builtin.CallingConvention = .Unspecified,
    is_var_args: bool = false,
    is_generic: bool = false,
    is_noinline: bool = false,
    section_is_generic: bool = false,
    addrspace_is_generic: bool = false,
};

pub fn getFuncType(
    ip: *InternPool,
    gpa: Allocator,
    tid: Zcu.PerThread.Id,
    key: GetFuncTypeKey,
) Allocator.Error!Index {
    // Validate input parameters.
    assert(key.return_type != .none);
    for (key.param_types) |param_type| assert(param_type != .none);

    const local = ip.getLocal(tid);
    const items = local.getMutableItems(gpa);
    try items.ensureUnusedCapacity(1);
    const extra = local.getMutableExtra(gpa);

    // The strategy here is to add the function type unconditionally, then to
    // ask if it already exists, and if so, revert the lengths of the mutated
    // arrays. This is similar to what `getOrPutTrailingString` does.
    const prev_extra_len = extra.mutate.len;
    const params_len: u32 = @intCast(key.param_types.len);

    try extra.ensureUnusedCapacity(@typeInfo(Tag.TypeFunction).Struct.fields.len +
        @intFromBool(key.comptime_bits != 0) +
        @intFromBool(key.noalias_bits != 0) +
        params_len);

    const func_type_extra_index = addExtraAssumeCapacity(extra, Tag.TypeFunction{
        .params_len = params_len,
        .return_type = key.return_type,
        .flags = .{
            .cc = key.cc orelse .Unspecified,
            .is_var_args = key.is_var_args,
            .has_comptime_bits = key.comptime_bits != 0,
            .has_noalias_bits = key.noalias_bits != 0,
            .is_generic = key.is_generic,
            .is_noinline = key.is_noinline,
            .cc_is_generic = key.cc == null,
            .section_is_generic = key.section_is_generic,
            .addrspace_is_generic = key.addrspace_is_generic,
        },
    });

    if (key.comptime_bits != 0) extra.appendAssumeCapacity(.{key.comptime_bits});
    if (key.noalias_bits != 0) extra.appendAssumeCapacity(.{key.noalias_bits});
    extra.appendSliceAssumeCapacity(.{@ptrCast(key.param_types)});
    errdefer extra.mutate.len = prev_extra_len;

    var gop = try ip.getOrPutKey(gpa, tid, .{
        .func_type = extraFuncType(tid, extra.list.*, func_type_extra_index),
    });
    defer gop.deinit();
    if (gop == .existing) {
        extra.mutate.len = prev_extra_len;
        return gop.existing;
    }

    items.appendAssumeCapacity(.{
        .tag = .type_function,
        .data = func_type_extra_index,
    });
    return gop.put();
}

pub fn getExternFunc(
    ip: *InternPool,
    gpa: Allocator,
    tid: Zcu.PerThread.Id,
    key: Key.ExternFunc,
) Allocator.Error!Index {
    var gop = try ip.getOrPutKey(gpa, tid, .{ .extern_func = key });
    defer gop.deinit();
    if (gop == .existing) return gop.existing;

    const local = ip.getLocal(tid);
    const items = local.getMutableItems(gpa);
    try items.ensureUnusedCapacity(1);
    const extra = local.getMutableExtra(gpa);

    const prev_extra_len = extra.mutate.len;
    const extra_index = try addExtra(extra, @as(Tag.ExternFunc, key));
    errdefer extra.mutate.len = prev_extra_len;
    items.appendAssumeCapacity(.{
        .tag = .extern_func,
        .data = extra_index,
    });
    errdefer items.mutate.len -= 1;
    return gop.put();
}

pub const GetFuncDeclKey = struct {
    owner_decl: DeclIndex,
    ty: Index,
    zir_body_inst: TrackedInst.Index,
    lbrace_line: u32,
    rbrace_line: u32,
    lbrace_column: u32,
    rbrace_column: u32,
    cc: ?std.builtin.CallingConvention,
    is_noinline: bool,
};

pub fn getFuncDecl(
    ip: *InternPool,
    gpa: Allocator,
    tid: Zcu.PerThread.Id,
    key: GetFuncDeclKey,
) Allocator.Error!Index {
    const local = ip.getLocal(tid);
    const items = local.getMutableItems(gpa);
    try items.ensureUnusedCapacity(1);
    const extra = local.getMutableExtra(gpa);

    // The strategy here is to add the function type unconditionally, then to
    // ask if it already exists, and if so, revert the lengths of the mutated
    // arrays. This is similar to what `getOrPutTrailingString` does.
    const prev_extra_len = extra.mutate.len;

    try extra.ensureUnusedCapacity(@typeInfo(Tag.FuncDecl).Struct.fields.len);

    const func_decl_extra_index = addExtraAssumeCapacity(extra, Tag.FuncDecl{
        .analysis = .{
            .state = if (key.cc == .Inline) .inline_only else .none,
            .is_cold = false,
            .is_noinline = key.is_noinline,
            .calls_or_awaits_errorable_fn = false,
            .stack_alignment = .none,
            .inferred_error_set = false,
        },
        .owner_decl = key.owner_decl,
        .ty = key.ty,
        .zir_body_inst = key.zir_body_inst,
        .lbrace_line = key.lbrace_line,
        .rbrace_line = key.rbrace_line,
        .lbrace_column = key.lbrace_column,
        .rbrace_column = key.rbrace_column,
    });
    errdefer extra.mutate.len = prev_extra_len;

    var gop = try ip.getOrPutKey(gpa, tid, .{
        .func = extraFuncDecl(tid, extra.list.*, func_decl_extra_index),
    });
    defer gop.deinit();
    if (gop == .existing) {
        extra.mutate.len = prev_extra_len;
        return gop.existing;
    }

    items.appendAssumeCapacity(.{
        .tag = .func_decl,
        .data = func_decl_extra_index,
    });
    return gop.put();
}

pub const GetFuncDeclIesKey = struct {
    owner_decl: DeclIndex,
    param_types: []Index,
    noalias_bits: u32,
    comptime_bits: u32,
    bare_return_type: Index,
    /// null means generic.
    cc: ?std.builtin.CallingConvention,
    /// null means generic.
    alignment: ?Alignment,
    section_is_generic: bool,
    addrspace_is_generic: bool,
    is_var_args: bool,
    is_generic: bool,
    is_noinline: bool,
    zir_body_inst: TrackedInst.Index,
    lbrace_line: u32,
    rbrace_line: u32,
    lbrace_column: u32,
    rbrace_column: u32,
};

pub fn getFuncDeclIes(
    ip: *InternPool,
    gpa: Allocator,
    tid: Zcu.PerThread.Id,
    key: GetFuncDeclIesKey,
) Allocator.Error!Index {
    // Validate input parameters.
    assert(key.bare_return_type != .none);
    for (key.param_types) |param_type| assert(param_type != .none);

    const local = ip.getLocal(tid);
    const items = local.getMutableItems(gpa);
    try items.ensureUnusedCapacity(4);
    const extra = local.getMutableExtra(gpa);

    // The strategy here is to add the function decl unconditionally, then to
    // ask if it already exists, and if so, revert the lengths of the mutated
    // arrays. This is similar to what `getOrPutTrailingString` does.
    const prev_extra_len = extra.mutate.len;
    const params_len: u32 = @intCast(key.param_types.len);

    try extra.ensureUnusedCapacity(@typeInfo(Tag.FuncDecl).Struct.fields.len +
        1 + // inferred_error_set
        @typeInfo(Tag.ErrorUnionType).Struct.fields.len +
        @typeInfo(Tag.TypeFunction).Struct.fields.len +
        @intFromBool(key.comptime_bits != 0) +
        @intFromBool(key.noalias_bits != 0) +
        params_len);

    const func_index = Index.Unwrapped.wrap(.{
        .tid = tid,
        .index = items.mutate.len + 0,
    }, ip);
    const error_union_type = Index.Unwrapped.wrap(.{
        .tid = tid,
        .index = items.mutate.len + 1,
    }, ip);
    const error_set_type = Index.Unwrapped.wrap(.{
        .tid = tid,
        .index = items.mutate.len + 2,
    }, ip);
    const func_ty = Index.Unwrapped.wrap(.{
        .tid = tid,
        .index = items.mutate.len + 3,
    }, ip);

    const func_decl_extra_index = addExtraAssumeCapacity(extra, Tag.FuncDecl{
        .analysis = .{
            .state = if (key.cc == .Inline) .inline_only else .none,
            .is_cold = false,
            .is_noinline = key.is_noinline,
            .calls_or_awaits_errorable_fn = false,
            .stack_alignment = .none,
            .inferred_error_set = true,
        },
        .owner_decl = key.owner_decl,
        .ty = func_ty,
        .zir_body_inst = key.zir_body_inst,
        .lbrace_line = key.lbrace_line,
        .rbrace_line = key.rbrace_line,
        .lbrace_column = key.lbrace_column,
        .rbrace_column = key.rbrace_column,
    });
    extra.appendAssumeCapacity(.{@intFromEnum(Index.none)});

    const func_type_extra_index = addExtraAssumeCapacity(extra, Tag.TypeFunction{
        .params_len = params_len,
        .return_type = error_union_type,
        .flags = .{
            .cc = key.cc orelse .Unspecified,
            .is_var_args = key.is_var_args,
            .has_comptime_bits = key.comptime_bits != 0,
            .has_noalias_bits = key.noalias_bits != 0,
            .is_generic = key.is_generic,
            .is_noinline = key.is_noinline,
            .cc_is_generic = key.cc == null,
            .section_is_generic = key.section_is_generic,
            .addrspace_is_generic = key.addrspace_is_generic,
        },
    });
    if (key.comptime_bits != 0) extra.appendAssumeCapacity(.{key.comptime_bits});
    if (key.noalias_bits != 0) extra.appendAssumeCapacity(.{key.noalias_bits});
    extra.appendSliceAssumeCapacity(.{@ptrCast(key.param_types)});

    items.appendSliceAssumeCapacity(.{
        .tag = &.{
            .func_decl,
            .type_error_union,
            .type_inferred_error_set,
            .type_function,
        },
        .data = &.{
            func_decl_extra_index,
            addExtraAssumeCapacity(extra, Tag.ErrorUnionType{
                .error_set_type = error_set_type,
                .payload_type = key.bare_return_type,
            }),
            @intFromEnum(func_index),
            func_type_extra_index,
        },
    });
    errdefer {
        items.mutate.len -= 4;
        extra.mutate.len = prev_extra_len;
    }

    var func_gop = try ip.getOrPutKey(gpa, tid, .{
        .func = extraFuncDecl(tid, extra.list.*, func_decl_extra_index),
    });
    defer func_gop.deinit();
    if (func_gop == .existing) {
        // An existing function type was found; undo the additions to our two arrays.
        items.mutate.len -= 4;
        extra.mutate.len = prev_extra_len;
        return func_gop.existing;
    }
    var error_union_type_gop = try ip.getOrPutKey(gpa, tid, .{ .error_union_type = .{
        .error_set_type = error_set_type,
        .payload_type = key.bare_return_type,
    } });
    defer error_union_type_gop.deinit();
    var error_set_type_gop = try ip.getOrPutKey(gpa, tid, .{
        .inferred_error_set_type = func_index,
    });
    defer error_set_type_gop.deinit();
    var func_ty_gop = try ip.getOrPutKey(gpa, tid, .{
        .func_type = extraFuncType(tid, extra.list.*, func_type_extra_index),
    });
    defer func_ty_gop.deinit();
    assert(func_gop.putAt(3) == func_index);
    assert(error_union_type_gop.putAt(2) == error_union_type);
    assert(error_set_type_gop.putAt(1) == error_set_type);
    assert(func_ty_gop.putAt(0) == func_ty);
    return func_index;
}

pub fn getErrorSetType(
    ip: *InternPool,
    gpa: Allocator,
    tid: Zcu.PerThread.Id,
    names: []const NullTerminatedString,
) Allocator.Error!Index {
    assert(std.sort.isSorted(NullTerminatedString, names, {}, NullTerminatedString.indexLessThan));

    const local = ip.getLocal(tid);
    const items = local.getMutableItems(gpa);
    const extra = local.getMutableExtra(gpa);
    try extra.ensureUnusedCapacity(@typeInfo(Tag.ErrorSet).Struct.fields.len + names.len);

    // The strategy here is to add the type unconditionally, then to ask if it
    // already exists, and if so, revert the lengths of the mutated arrays.
    // This is similar to what `getOrPutTrailingString` does.
    const prev_extra_len = extra.mutate.len;
    errdefer extra.mutate.len = prev_extra_len;

    const predicted_names_map: MapIndex = @enumFromInt(ip.maps.items.len);

    const error_set_extra_index = addExtraAssumeCapacity(extra, Tag.ErrorSet{
        .names_len = @intCast(names.len),
        .names_map = predicted_names_map,
    });
    extra.appendSliceAssumeCapacity(.{@ptrCast(names)});
    errdefer extra.mutate.len = prev_extra_len;

    var gop = try ip.getOrPutKey(gpa, tid, .{
        .error_set_type = extraErrorSet(tid, extra.list.*, error_set_extra_index),
    });
    defer gop.deinit();
    if (gop == .existing) {
        extra.mutate.len = prev_extra_len;
        return gop.existing;
    }

    try items.append(.{
        .tag = .type_error_set,
        .data = error_set_extra_index,
    });
    errdefer items.mutate.len -= 1;

    const names_map = try ip.addMap(gpa, names.len);
    assert(names_map == predicted_names_map);
    errdefer _ = ip.maps.pop();

    addStringsToMap(ip, names_map, names);

    return gop.put();
}

pub const GetFuncInstanceKey = struct {
    /// Has the length of the instance function (may be lesser than
    /// comptime_args).
    param_types: []Index,
    /// Has the length of generic_owner's parameters (may be greater than
    /// param_types).
    comptime_args: []const Index,
    noalias_bits: u32,
    bare_return_type: Index,
    cc: std.builtin.CallingConvention,
    alignment: Alignment,
    section: OptionalNullTerminatedString,
    is_noinline: bool,
    generic_owner: Index,
    inferred_error_set: bool,
};

pub fn getFuncInstance(
    ip: *InternPool,
    gpa: Allocator,
    tid: Zcu.PerThread.Id,
    arg: GetFuncInstanceKey,
) Allocator.Error!Index {
    if (arg.inferred_error_set)
        return getFuncInstanceIes(ip, gpa, tid, arg);

    const func_ty = try ip.getFuncType(gpa, tid, .{
        .param_types = arg.param_types,
        .return_type = arg.bare_return_type,
        .noalias_bits = arg.noalias_bits,
        .cc = arg.cc,
        .is_noinline = arg.is_noinline,
    });

    const local = ip.getLocal(tid);
    const items = local.getMutableItems(gpa);
    const extra = local.getMutableExtra(gpa);
    try extra.ensureUnusedCapacity(@typeInfo(Tag.FuncInstance).Struct.fields.len +
        arg.comptime_args.len);

    const generic_owner = unwrapCoercedFunc(ip, arg.generic_owner);

    assert(arg.comptime_args.len == ip.funcTypeParamsLen(ip.typeOf(generic_owner)));

    const prev_extra_len = extra.mutate.len;
    errdefer extra.mutate.len = prev_extra_len;

    const func_extra_index = addExtraAssumeCapacity(extra, Tag.FuncInstance{
        .analysis = .{
            .state = if (arg.cc == .Inline) .inline_only else .none,
            .is_cold = false,
            .is_noinline = arg.is_noinline,
            .calls_or_awaits_errorable_fn = false,
            .stack_alignment = .none,
            .inferred_error_set = false,
        },
        // This is populated after we create the Decl below. It is not read
        // by equality or hashing functions.
        .owner_decl = undefined,
        .ty = func_ty,
        .branch_quota = 0,
        .generic_owner = generic_owner,
    });
    extra.appendSliceAssumeCapacity(.{@ptrCast(arg.comptime_args)});

    var gop = try ip.getOrPutKey(gpa, tid, .{
        .func = ip.extraFuncInstance(tid, extra.list.*, func_extra_index),
    });
    defer gop.deinit();
    if (gop == .existing) {
        extra.mutate.len = prev_extra_len;
        return gop.existing;
    }

    const func_index = Index.Unwrapped.wrap(.{ .tid = tid, .index = items.mutate.len }, ip);
    try items.append(.{
        .tag = .func_instance,
        .data = func_extra_index,
    });
    errdefer items.mutate.len -= 1;
    try finishFuncInstance(
        ip,
        gpa,
        tid,
        extra,
        generic_owner,
        func_index,
        func_extra_index,
        arg.alignment,
        arg.section,
    );
    return gop.put();
}

/// This function exists separately than `getFuncInstance` because it needs to
/// create 4 new items in the InternPool atomically before it can look for an
/// existing item in the map.
pub fn getFuncInstanceIes(
    ip: *InternPool,
    gpa: Allocator,
    tid: Zcu.PerThread.Id,
    arg: GetFuncInstanceKey,
) Allocator.Error!Index {
    // Validate input parameters.
    assert(arg.inferred_error_set);
    assert(arg.bare_return_type != .none);
    for (arg.param_types) |param_type| assert(param_type != .none);

    const local = ip.getLocal(tid);
    const items = local.getMutableItems(gpa);
    const extra = local.getMutableExtra(gpa);
    try items.ensureUnusedCapacity(4);

    const generic_owner = unwrapCoercedFunc(ip, arg.generic_owner);

    // The strategy here is to add the function decl unconditionally, then to
    // ask if it already exists, and if so, revert the lengths of the mutated
    // arrays. This is similar to what `getOrPutTrailingString` does.
    const prev_extra_len = extra.mutate.len;
    const params_len: u32 = @intCast(arg.param_types.len);

    try extra.ensureUnusedCapacity(@typeInfo(Tag.FuncInstance).Struct.fields.len +
        1 + // inferred_error_set
        arg.comptime_args.len +
        @typeInfo(Tag.ErrorUnionType).Struct.fields.len +
        @typeInfo(Tag.TypeFunction).Struct.fields.len +
        @intFromBool(arg.noalias_bits != 0) +
        params_len);

    const func_index = Index.Unwrapped.wrap(.{
        .tid = tid,
        .index = items.mutate.len + 0,
    }, ip);
    const error_union_type = Index.Unwrapped.wrap(.{
        .tid = tid,
        .index = items.mutate.len + 1,
    }, ip);
    const error_set_type = Index.Unwrapped.wrap(.{
        .tid = tid,
        .index = items.mutate.len + 2,
    }, ip);
    const func_ty = Index.Unwrapped.wrap(.{
        .tid = tid,
        .index = items.mutate.len + 3,
    }, ip);

    const func_extra_index = addExtraAssumeCapacity(extra, Tag.FuncInstance{
        .analysis = .{
            .state = if (arg.cc == .Inline) .inline_only else .none,
            .is_cold = false,
            .is_noinline = arg.is_noinline,
            .calls_or_awaits_errorable_fn = false,
            .stack_alignment = .none,
            .inferred_error_set = true,
        },
        // This is populated after we create the Decl below. It is not read
        // by equality or hashing functions.
        .owner_decl = undefined,
        .ty = func_ty,
        .branch_quota = 0,
        .generic_owner = generic_owner,
    });
    extra.appendAssumeCapacity(.{@intFromEnum(Index.none)}); // resolved error set
    extra.appendSliceAssumeCapacity(.{@ptrCast(arg.comptime_args)});

    const func_type_extra_index = addExtraAssumeCapacity(extra, Tag.TypeFunction{
        .params_len = params_len,
        .return_type = error_union_type,
        .flags = .{
            .cc = arg.cc,
            .is_var_args = false,
            .has_comptime_bits = false,
            .has_noalias_bits = arg.noalias_bits != 0,
            .is_generic = false,
            .is_noinline = arg.is_noinline,
            .cc_is_generic = false,
            .section_is_generic = false,
            .addrspace_is_generic = false,
        },
    });
    // no comptime_bits because has_comptime_bits is false
    if (arg.noalias_bits != 0) extra.appendAssumeCapacity(.{arg.noalias_bits});
    extra.appendSliceAssumeCapacity(.{@ptrCast(arg.param_types)});

    items.appendSliceAssumeCapacity(.{
        .tag = &.{
            .func_instance,
            .type_error_union,
            .type_inferred_error_set,
            .type_function,
        },
        .data = &.{
            func_extra_index,
            addExtraAssumeCapacity(extra, Tag.ErrorUnionType{
                .error_set_type = error_set_type,
                .payload_type = arg.bare_return_type,
            }),
            @intFromEnum(func_index),
            func_type_extra_index,
        },
    });
    errdefer {
        items.mutate.len -= 4;
        extra.mutate.len = prev_extra_len;
    }

    var func_gop = try ip.getOrPutKey(gpa, tid, .{
        .func = ip.extraFuncInstance(tid, extra.list.*, func_extra_index),
    });
    defer func_gop.deinit();
    if (func_gop == .existing) {
        // Hot path: undo the additions to our two arrays.
        items.mutate.len -= 4;
        extra.mutate.len = prev_extra_len;
        return func_gop.existing;
    }
    var error_union_type_gop = try ip.getOrPutKey(gpa, tid, .{ .error_union_type = .{
        .error_set_type = error_set_type,
        .payload_type = arg.bare_return_type,
    } });
    defer error_union_type_gop.deinit();
    var error_set_type_gop = try ip.getOrPutKey(gpa, tid, .{
        .inferred_error_set_type = func_index,
    });
    defer error_set_type_gop.deinit();
    var func_ty_gop = try ip.getOrPutKey(gpa, tid, .{
        .func_type = extraFuncType(tid, extra.list.*, func_type_extra_index),
    });
    defer func_ty_gop.deinit();
    try finishFuncInstance(
        ip,
        gpa,
        tid,
        extra,
        generic_owner,
        func_index,
        func_extra_index,
        arg.alignment,
        arg.section,
    );
    assert(func_gop.putAt(3) == func_index);
    assert(error_union_type_gop.putAt(2) == error_union_type);
    assert(error_set_type_gop.putAt(1) == error_set_type);
    assert(func_ty_gop.putAt(0) == func_ty);
    return func_index;
}

fn finishFuncInstance(
    ip: *InternPool,
    gpa: Allocator,
    tid: Zcu.PerThread.Id,
    extra: Local.Extra.Mutable,
    generic_owner: Index,
    func_index: Index,
    func_extra_index: u32,
    alignment: Alignment,
    section: OptionalNullTerminatedString,
) Allocator.Error!void {
    const fn_owner_decl = ip.declPtr(ip.funcDeclOwner(generic_owner));
    const decl_index = try ip.createDecl(gpa, tid, .{
        .name = undefined,
        .fqn = undefined,
        .src_namespace = fn_owner_decl.src_namespace,
        .has_tv = true,
        .owns_tv = true,
        .val = @import("Value.zig").fromInterned(func_index),
        .alignment = alignment,
        .@"linksection" = section,
        .@"addrspace" = fn_owner_decl.@"addrspace",
        .analysis = .complete,
        .zir_decl_index = fn_owner_decl.zir_decl_index,
        .is_pub = fn_owner_decl.is_pub,
        .is_exported = fn_owner_decl.is_exported,
        .kind = .anon,
    });
    errdefer ip.destroyDecl(tid, decl_index);

    // Populate the owner_decl field which was left undefined until now.
    extra.view().items(.@"0")[
        func_extra_index + std.meta.fieldIndex(Tag.FuncInstance, "owner_decl").?
    ] = @intFromEnum(decl_index);

    // TODO: improve this name
    const decl = ip.declPtr(decl_index);
    decl.name = try ip.getOrPutStringFmt(gpa, tid, "{}__anon_{d}", .{
        fn_owner_decl.name.fmt(ip), @intFromEnum(decl_index),
    }, .no_embedded_nulls);
}

pub const EnumTypeInit = struct {
    has_namespace: bool,
    has_values: bool,
    tag_mode: LoadedEnumType.TagMode,
    fields_len: u32,
    key: union(enum) {
        declared: struct {
            zir_index: TrackedInst.Index,
            captures: []const CaptureValue,
        },
        reified: struct {
            zir_index: TrackedInst.Index,
            type_hash: u64,
        },
    },
};

pub const WipEnumType = struct {
    tid: Zcu.PerThread.Id,
    index: Index,
    tag_ty_index: u32,
    decl_index: u32,
    namespace_index: ?u32,
    names_map: MapIndex,
    names_start: u32,
    values_map: OptionalMapIndex,
    values_start: u32,

    pub fn prepare(
        wip: WipEnumType,
        ip: *InternPool,
        decl: DeclIndex,
        namespace: OptionalNamespaceIndex,
    ) void {
        const extra = ip.getLocalShared(wip.tid).extra.acquire();
        const extra_items = extra.view().items(.@"0");
        extra_items[wip.decl_index] = @intFromEnum(decl);
        if (wip.namespace_index) |i| {
            extra_items[i] = @intFromEnum(namespace.unwrap().?);
        } else {
            assert(namespace == .none);
        }
    }

    pub fn setTagTy(wip: WipEnumType, ip: *InternPool, tag_ty: Index) void {
        assert(ip.isIntegerType(tag_ty));
        const extra = ip.getLocalShared(wip.tid).extra.acquire();
        extra.view().items(.@"0")[wip.tag_ty_index] = @intFromEnum(tag_ty);
    }

    pub const FieldConflict = struct {
        kind: enum { name, value },
        prev_field_idx: u32,
    };

    /// Returns the already-existing field with the same name or value, if any.
    /// If the enum is automatially numbered, `value` must be `.none`.
    /// Otherwise, the type of `value` must be the integer tag type of the enum.
    pub fn nextField(wip: WipEnumType, ip: *InternPool, name: NullTerminatedString, value: Index) ?FieldConflict {
        const unwrapped_index = wip.index.unwrap(ip);
        const extra_list = ip.getLocalShared(unwrapped_index.tid).extra.acquire();
        const extra_items = extra_list.view().items(.@"0");
        if (ip.addFieldName(extra_list, wip.names_map, wip.names_start, name)) |conflict| {
            return .{ .kind = .name, .prev_field_idx = conflict };
        }
        if (value == .none) {
            assert(wip.values_map == .none);
            return null;
        }
        assert(ip.typeOf(value) == @as(Index, @enumFromInt(extra_items[wip.tag_ty_index])));
        const map = &ip.maps.items[@intFromEnum(wip.values_map.unwrap().?)];
        const field_index = map.count();
        const indexes = extra_items[wip.values_start..][0..field_index];
        const adapter: Index.Adapter = .{ .indexes = @ptrCast(indexes) };
        const gop = map.getOrPutAssumeCapacityAdapted(value, adapter);
        if (gop.found_existing) {
            return .{ .kind = .value, .prev_field_idx = @intCast(gop.index) };
        }
        extra_items[wip.values_start + field_index] = @intFromEnum(value);
        return null;
    }

    pub fn cancel(wip: WipEnumType, ip: *InternPool, tid: Zcu.PerThread.Id) void {
        ip.remove(tid, wip.index);
    }

    pub const Result = union(enum) {
        wip: WipEnumType,
        existing: Index,
    };
};

pub fn getEnumType(
    ip: *InternPool,
    gpa: Allocator,
    tid: Zcu.PerThread.Id,
    ini: EnumTypeInit,
) Allocator.Error!WipEnumType.Result {
    var gop = try ip.getOrPutKey(gpa, tid, .{ .enum_type = switch (ini.key) {
        .declared => |d| .{ .declared = .{
            .zir_index = d.zir_index,
            .captures = .{ .external = d.captures },
        } },
        .reified => |r| .{ .reified = .{
            .zir_index = r.zir_index,
            .type_hash = r.type_hash,
        } },
    } });
    defer gop.deinit();
    if (gop == .existing) return .{ .existing = gop.existing };

    const local = ip.getLocal(tid);
    const items = local.getMutableItems(gpa);
    try items.ensureUnusedCapacity(1);
    const extra = local.getMutableExtra(gpa);

    const names_map = try ip.addMap(gpa, ini.fields_len);
    errdefer _ = ip.maps.pop();

    switch (ini.tag_mode) {
        .auto => {
            assert(!ini.has_values);
            try extra.ensureUnusedCapacity(@typeInfo(EnumAuto).Struct.fields.len +
                // TODO: fmt bug
                // zig fmt: off
                switch (ini.key) {
                    .declared => |d| d.captures.len,
                    .reified => 2, // type_hash: PackedU64
                } +
                // zig fmt: on
                ini.fields_len); // field types

            const extra_index = addExtraAssumeCapacity(extra, EnumAuto{
                .decl = undefined, // set by `prepare`
                .captures_len = switch (ini.key) {
                    .declared => |d| @intCast(d.captures.len),
                    .reified => std.math.maxInt(u32),
                },
                .namespace = .none,
                .int_tag_type = .none, // set by `prepare`
                .fields_len = ini.fields_len,
                .names_map = names_map,
                .zir_index = switch (ini.key) {
                    inline else => |x| x.zir_index,
                }.toOptional(),
            });
            items.appendAssumeCapacity(.{
                .tag = .type_enum_auto,
                .data = extra_index,
            });
            switch (ini.key) {
                .declared => |d| extra.appendSliceAssumeCapacity(.{@ptrCast(d.captures)}),
                .reified => |r| _ = addExtraAssumeCapacity(extra, PackedU64.init(r.type_hash)),
            }
            const names_start = extra.mutate.len;
            _ = extra.addManyAsSliceAssumeCapacity(ini.fields_len);
            return .{ .wip = .{
                .tid = tid,
                .index = gop.put(),
                .tag_ty_index = extra_index + std.meta.fieldIndex(EnumAuto, "int_tag_type").?,
                .decl_index = extra_index + std.meta.fieldIndex(EnumAuto, "decl").?,
                .namespace_index = if (ini.has_namespace) extra_index + std.meta.fieldIndex(EnumAuto, "namespace").? else null,
                .names_map = names_map,
                .names_start = @intCast(names_start),
                .values_map = .none,
                .values_start = undefined,
            } };
        },
        .explicit, .nonexhaustive => {
            const values_map: OptionalMapIndex = if (!ini.has_values) .none else m: {
                const values_map = try ip.addMap(gpa, ini.fields_len);
                break :m values_map.toOptional();
            };
            errdefer if (ini.has_values) {
                _ = ip.maps.pop();
            };

            try extra.ensureUnusedCapacity(@typeInfo(EnumExplicit).Struct.fields.len +
                // TODO: fmt bug
                // zig fmt: off
                switch (ini.key) {
                    .declared => |d| d.captures.len,
                    .reified => 2, // type_hash: PackedU64
                } +
                // zig fmt: on
                ini.fields_len + // field types
                ini.fields_len * @intFromBool(ini.has_values)); // field values

            const extra_index = addExtraAssumeCapacity(extra, EnumExplicit{
                .decl = undefined, // set by `prepare`
                .captures_len = switch (ini.key) {
                    .declared => |d| @intCast(d.captures.len),
                    .reified => std.math.maxInt(u32),
                },
                .namespace = .none,
                .int_tag_type = .none, // set by `prepare`
                .fields_len = ini.fields_len,
                .names_map = names_map,
                .values_map = values_map,
                .zir_index = switch (ini.key) {
                    inline else => |x| x.zir_index,
                }.toOptional(),
            });
            items.appendAssumeCapacity(.{
                .tag = switch (ini.tag_mode) {
                    .auto => unreachable,
                    .explicit => .type_enum_explicit,
                    .nonexhaustive => .type_enum_nonexhaustive,
                },
                .data = extra_index,
            });
            switch (ini.key) {
                .declared => |d| extra.appendSliceAssumeCapacity(.{@ptrCast(d.captures)}),
                .reified => |r| _ = addExtraAssumeCapacity(extra, PackedU64.init(r.type_hash)),
            }
            const names_start = extra.mutate.len;
            _ = extra.addManyAsSliceAssumeCapacity(ini.fields_len);
            const values_start = extra.mutate.len;
            if (ini.has_values) {
                _ = extra.addManyAsSliceAssumeCapacity(ini.fields_len);
            }
            return .{ .wip = .{
                .tid = tid,
                .index = gop.put(),
                .tag_ty_index = extra_index + std.meta.fieldIndex(EnumAuto, "int_tag_type").?,
                .decl_index = extra_index + std.meta.fieldIndex(EnumAuto, "decl").?,
                .namespace_index = if (ini.has_namespace) extra_index + std.meta.fieldIndex(EnumAuto, "namespace").? else null,
                .names_map = names_map,
                .names_start = @intCast(names_start),
                .values_map = values_map,
                .values_start = @intCast(values_start),
            } };
        },
    }
}

const GeneratedTagEnumTypeInit = struct {
    decl: DeclIndex,
    owner_union_ty: Index,
    tag_ty: Index,
    names: []const NullTerminatedString,
    values: []const Index,
    tag_mode: LoadedEnumType.TagMode,
};

/// Creates an enum type which was automatically-generated as the tag type of a
/// `union` with no explicit tag type. Since this is only called once per union
/// type, it asserts that no matching type yet exists.
pub fn getGeneratedTagEnumType(
    ip: *InternPool,
    gpa: Allocator,
    tid: Zcu.PerThread.Id,
    ini: GeneratedTagEnumTypeInit,
) Allocator.Error!Index {
    assert(ip.isUnion(ini.owner_union_ty));
    assert(ip.isIntegerType(ini.tag_ty));
    for (ini.values) |val| assert(ip.typeOf(val) == ini.tag_ty);

    const local = ip.getLocal(tid);
    const items = local.getMutableItems(gpa);
    try items.ensureUnusedCapacity(1);
    const extra = local.getMutableExtra(gpa);

    const names_map = try ip.addMap(gpa, ini.names.len);
    errdefer _ = ip.maps.pop();
    ip.addStringsToMap(names_map, ini.names);

    const fields_len: u32 = @intCast(ini.names.len);

    const prev_extra_len = extra.mutate.len;
    switch (ini.tag_mode) {
        .auto => {
            try extra.ensureUnusedCapacity(@typeInfo(EnumAuto).Struct.fields.len +
                1 + // owner_union
                fields_len); // field names
            items.appendAssumeCapacity(.{
                .tag = .type_enum_auto,
                .data = addExtraAssumeCapacity(extra, EnumAuto{
                    .decl = ini.decl,
                    .captures_len = 0,
                    .namespace = .none,
                    .int_tag_type = ini.tag_ty,
                    .fields_len = fields_len,
                    .names_map = names_map,
                    .zir_index = .none,
                }),
            });
            extra.appendAssumeCapacity(.{@intFromEnum(ini.owner_union_ty)});
            extra.appendSliceAssumeCapacity(.{@ptrCast(ini.names)});
        },
        .explicit, .nonexhaustive => {
            try extra.ensureUnusedCapacity(@typeInfo(EnumExplicit).Struct.fields.len +
                1 + // owner_union
                fields_len + // field names
                ini.values.len); // field values

            const values_map: OptionalMapIndex = if (ini.values.len != 0) m: {
                const map = try ip.addMap(gpa, ini.values.len);
                addIndexesToMap(ip, map, ini.values);
                break :m map.toOptional();
            } else .none;
            // We don't clean up the values map on error!
            errdefer @compileError("error path leaks values_map");

            items.appendAssumeCapacity(.{
                .tag = switch (ini.tag_mode) {
                    .explicit => .type_enum_explicit,
                    .nonexhaustive => .type_enum_nonexhaustive,
                    .auto => unreachable,
                },
                .data = addExtraAssumeCapacity(extra, EnumExplicit{
                    .decl = ini.decl,
                    .captures_len = 0,
                    .namespace = .none,
                    .int_tag_type = ini.tag_ty,
                    .fields_len = fields_len,
                    .names_map = names_map,
                    .values_map = values_map,
                    .zir_index = .none,
                }),
            });
            extra.appendAssumeCapacity(.{@intFromEnum(ini.owner_union_ty)});
            extra.appendSliceAssumeCapacity(.{@ptrCast(ini.names)});
            extra.appendSliceAssumeCapacity(.{@ptrCast(ini.values)});
        },
    }
    errdefer extra.mutate.len = prev_extra_len;
    errdefer switch (ini.tag_mode) {
        .auto => {},
        .explicit, .nonexhaustive => _ = if (ini.values.len != 0) ip.maps.pop(),
    };

    var gop = try ip.getOrPutKey(gpa, tid, .{ .enum_type = .{
        .generated_tag = .{ .union_type = ini.owner_union_ty },
    } });
    defer gop.deinit();
    return gop.put();
}

pub const OpaqueTypeInit = struct {
    has_namespace: bool,
    key: union(enum) {
        declared: struct {
            zir_index: TrackedInst.Index,
            captures: []const CaptureValue,
        },
        reified: struct {
            zir_index: TrackedInst.Index,
            // No type hash since reifid opaques have no data other than the `@Type` location
        },
    },
};

pub fn getOpaqueType(
    ip: *InternPool,
    gpa: Allocator,
    tid: Zcu.PerThread.Id,
    ini: OpaqueTypeInit,
) Allocator.Error!WipNamespaceType.Result {
    var gop = try ip.getOrPutKey(gpa, tid, .{ .opaque_type = switch (ini.key) {
        .declared => |d| .{ .declared = .{
            .zir_index = d.zir_index,
            .captures = .{ .external = d.captures },
        } },
        .reified => |r| .{ .reified = .{
            .zir_index = r.zir_index,
            .type_hash = 0,
        } },
    } });
    defer gop.deinit();
    if (gop == .existing) return .{ .existing = gop.existing };

    const local = ip.getLocal(tid);
    const items = local.getMutableItems(gpa);
    const extra = local.getMutableExtra(gpa);
    try items.ensureUnusedCapacity(1);

    try extra.ensureUnusedCapacity(@typeInfo(Tag.TypeOpaque).Struct.fields.len + switch (ini.key) {
        .declared => |d| d.captures.len,
        .reified => 0,
    });
    const extra_index = addExtraAssumeCapacity(extra, Tag.TypeOpaque{
        .decl = undefined, // set by `finish`
        .namespace = .none,
        .zir_index = switch (ini.key) {
            inline else => |x| x.zir_index,
        },
        .captures_len = switch (ini.key) {
            .declared => |d| @intCast(d.captures.len),
            .reified => std.math.maxInt(u32),
        },
    });
    items.appendAssumeCapacity(.{
        .tag = .type_opaque,
        .data = extra_index,
    });
    switch (ini.key) {
        .declared => |d| extra.appendSliceAssumeCapacity(.{@ptrCast(d.captures)}),
        .reified => {},
    }
    return .{ .wip = .{
        .tid = tid,
        .index = gop.put(),
        .decl_extra_index = extra_index + std.meta.fieldIndex(Tag.TypeOpaque, "decl").?,
        .namespace_extra_index = if (ini.has_namespace)
            extra_index + std.meta.fieldIndex(Tag.TypeOpaque, "namespace").?
        else
            null,
    } };
}

pub fn getIfExists(ip: *const InternPool, key: Key) ?Index {
    const full_hash = key.hash64(ip);
    const hash: u32 = @truncate(full_hash >> 32);
    const shard = &ip.shards[@intCast(full_hash & (ip.shards.len - 1))];
    const map = shard.shared.map.acquire();
    const map_mask = map.header().mask();
    var map_index = hash;
    while (true) : (map_index += 1) {
        map_index &= map_mask;
        const entry = &map.entries[map_index];
        const index = entry.acquire();
        if (index == .none) return null;
        if (entry.hash != hash) continue;
        if (ip.indexToKey(index).eql(key, ip)) return index;
    }
}

fn addStringsToMap(
    ip: *InternPool,
    map_index: MapIndex,
    strings: []const NullTerminatedString,
) void {
    const map = &ip.maps.items[@intFromEnum(map_index)];
    const adapter: NullTerminatedString.Adapter = .{ .strings = strings };
    for (strings) |string| {
        const gop = map.getOrPutAssumeCapacityAdapted(string, adapter);
        assert(!gop.found_existing);
    }
}

fn addIndexesToMap(
    ip: *InternPool,
    map_index: MapIndex,
    indexes: []const Index,
) void {
    const map = &ip.maps.items[@intFromEnum(map_index)];
    const adapter: Index.Adapter = .{ .indexes = indexes };
    for (indexes) |index| {
        const gop = map.getOrPutAssumeCapacityAdapted(index, adapter);
        assert(!gop.found_existing);
    }
}

fn addMap(ip: *InternPool, gpa: Allocator, cap: usize) Allocator.Error!MapIndex {
    const ptr = try ip.maps.addOne(gpa);
    errdefer _ = ip.maps.pop();
    ptr.* = .{};
    try ptr.ensureTotalCapacity(gpa, cap);
    return @enumFromInt(ip.maps.items.len - 1);
}

/// This operation only happens under compile error conditions.
/// Leak the index until the next garbage collection.
/// Invalidates all references to this index.
pub fn remove(ip: *InternPool, tid: Zcu.PerThread.Id, index: Index) void {
    const unwrapped_index = index.unwrap(ip);
    if (@intFromEnum(index) < static_keys.len) {
        // The item being removed replaced a special index via `InternPool.resolveBuiltinType`.
        // Restore the original item at this index.
        assert(static_keys[@intFromEnum(index)] == .simple_type);
        const items = ip.getLocalShared(unwrapped_index.tid).items.acquire().view();
        @atomicStore(Tag, &items.items(.tag)[unwrapped_index.index], .simple_type, .monotonic);
        return;
    }

    if (unwrapped_index.tid == tid) {
        const items_len = &ip.getLocal(unwrapped_index.tid).mutate.items.len;
        if (unwrapped_index.index == items_len.* - 1) {
            // Happy case - we can just drop the item without affecting any other indices.
            items_len.* -= 1;
            return;
        }
    }

    // We must preserve the item so that indices following it remain valid.
    // Thus, we will rewrite the tag to `removed`, leaking the item until
    // next GC but causing `KeyAdapter` to ignore it.
    const items = ip.getLocalShared(unwrapped_index.tid).items.acquire().view();
    @atomicStore(Tag, &items.items(.tag)[unwrapped_index.index], .removed, .monotonic);
}

fn addInt(
    ip: *InternPool,
    gpa: Allocator,
    tid: Zcu.PerThread.Id,
    ty: Index,
    tag: Tag,
    limbs: []const Limb,
) !void {
    const local = ip.getLocal(tid);
    const items_list = local.getMutableItems(gpa);
    const limbs_list = local.getMutableLimbs(gpa);
    const limbs_len: u32 = @intCast(limbs.len);
    try limbs_list.ensureUnusedCapacity(Int.limbs_items_len + limbs_len);
    items_list.appendAssumeCapacity(.{
        .tag = tag,
        .data = limbs_list.mutate.len,
    });
    limbs_list.addManyAsArrayAssumeCapacity(Int.limbs_items_len)[0].* = @bitCast(Int{
        .ty = ty,
        .limbs_len = limbs_len,
    });
    limbs_list.appendSliceAssumeCapacity(.{limbs});
}

fn addExtra(extra: Local.Extra.Mutable, item: anytype) Allocator.Error!u32 {
    const fields = @typeInfo(@TypeOf(item)).Struct.fields;
    try extra.ensureUnusedCapacity(fields.len);
    return addExtraAssumeCapacity(extra, item);
}

fn addExtraAssumeCapacity(extra: Local.Extra.Mutable, item: anytype) u32 {
    const result: u32 = extra.mutate.len;
    inline for (@typeInfo(@TypeOf(item)).Struct.fields) |field| {
        extra.appendAssumeCapacity(.{switch (field.type) {
            Index,
            DeclIndex,
            NamespaceIndex,
            OptionalNamespaceIndex,
            MapIndex,
            OptionalMapIndex,
            RuntimeIndex,
            String,
            NullTerminatedString,
            OptionalNullTerminatedString,
            Tag.TypePointer.VectorIndex,
            TrackedInst.Index,
            TrackedInst.Index.Optional,
            ComptimeAllocIndex,
            => @intFromEnum(@field(item, field.name)),

            u32,
            i32,
            FuncAnalysis,
            Tag.TypePointer.Flags,
            Tag.TypeFunction.Flags,
            Tag.TypePointer.PackedOffset,
            Tag.TypeUnion.Flags,
            Tag.TypeStruct.Flags,
            Tag.TypeStructPacked.Flags,
            Tag.Variable.Flags,
            => @bitCast(@field(item, field.name)),

            else => @compileError("bad field type: " ++ @typeName(field.type)),
        }});
    }
    return result;
}

fn addLimbsExtraAssumeCapacity(ip: *InternPool, extra: anytype) u32 {
    switch (@sizeOf(Limb)) {
        @sizeOf(u32) => return addExtraAssumeCapacity(ip, extra),
        @sizeOf(u64) => {},
        else => @compileError("unsupported host"),
    }
    const result: u32 = @intCast(ip.limbs.items.len);
    inline for (@typeInfo(@TypeOf(extra)).Struct.fields, 0..) |field, i| {
        const new: u32 = switch (field.type) {
            u32 => @field(extra, field.name),
            Index => @intFromEnum(@field(extra, field.name)),
            else => @compileError("bad field type: " ++ @typeName(field.type)),
        };
        if (i % 2 == 0) {
            ip.limbs.appendAssumeCapacity(new);
        } else {
            ip.limbs.items[ip.limbs.items.len - 1] |= @as(u64, new) << 32;
        }
    }
    return result;
}

fn extraDataTrail(extra: Local.Extra, comptime T: type, index: u32) struct { data: T, end: u32 } {
    const extra_items = extra.view().items(.@"0");
    var result: T = undefined;
    const fields = @typeInfo(T).Struct.fields;
    inline for (fields, index..) |field, extra_index| {
        const extra_item = extra_items[extra_index];
        @field(result, field.name) = switch (field.type) {
            Index,
            DeclIndex,
            NamespaceIndex,
            OptionalNamespaceIndex,
            MapIndex,
            OptionalMapIndex,
            RuntimeIndex,
            String,
            NullTerminatedString,
            OptionalNullTerminatedString,
            Tag.TypePointer.VectorIndex,
            TrackedInst.Index,
            TrackedInst.Index.Optional,
            ComptimeAllocIndex,
            => @enumFromInt(extra_item),

            u32,
            i32,
            Tag.TypePointer.Flags,
            Tag.TypeFunction.Flags,
            Tag.TypePointer.PackedOffset,
            Tag.TypeUnion.Flags,
            Tag.TypeStruct.Flags,
            Tag.TypeStructPacked.Flags,
            Tag.Variable.Flags,
            FuncAnalysis,
            => @bitCast(extra_item),

            else => @compileError("bad field type: " ++ @typeName(field.type)),
        };
    }
    return .{
        .data = result,
        .end = @intCast(index + fields.len),
    };
}

fn extraData(extra: Local.Extra, comptime T: type, index: u32) T {
    return extraDataTrail(extra, T, index).data;
}

test "basic usage" {
    const gpa = std.testing.allocator;

    var ip: InternPool = .{};
    defer ip.deinit(gpa);

    const i32_type = try ip.get(gpa, .main, .{ .int_type = .{
        .signedness = .signed,
        .bits = 32,
    } });
    const array_i32 = try ip.get(gpa, .main, .{ .array_type = .{
        .len = 10,
        .child = i32_type,
        .sentinel = .none,
    } });

    const another_i32_type = try ip.get(gpa, .main, .{ .int_type = .{
        .signedness = .signed,
        .bits = 32,
    } });
    try std.testing.expect(another_i32_type == i32_type);

    const another_array_i32 = try ip.get(gpa, .main, .{ .array_type = .{
        .len = 10,
        .child = i32_type,
        .sentinel = .none,
    } });
    try std.testing.expect(another_array_i32 == array_i32);
}

pub fn childType(ip: *const InternPool, i: Index) Index {
    return switch (ip.indexToKey(i)) {
        .ptr_type => |ptr_type| ptr_type.child,
        .vector_type => |vector_type| vector_type.child,
        .array_type => |array_type| array_type.child,
        .opt_type, .anyframe_type => |child| child,
        else => unreachable,
    };
}

/// Given a slice type, returns the type of the ptr field.
pub fn slicePtrType(ip: *const InternPool, index: Index) Index {
    switch (index) {
        .slice_const_u8_type => return .manyptr_const_u8_type,
        .slice_const_u8_sentinel_0_type => return .manyptr_const_u8_sentinel_0_type,
        else => {},
    }
    const item = index.unwrap(ip).getItem(ip);
    switch (item.tag) {
        .type_slice => return @enumFromInt(item.data),
        else => unreachable, // not a slice type
    }
}

/// Given a slice value, returns the value of the ptr field.
pub fn slicePtr(ip: *const InternPool, index: Index) Index {
    const unwrapped_index = index.unwrap(ip);
    const item = unwrapped_index.getItem(ip);
    switch (item.tag) {
        .ptr_slice => return extraData(unwrapped_index.getExtra(ip), PtrSlice, item.data).ptr,
        else => unreachable, // not a slice value
    }
}

/// Given a slice value, returns the value of the len field.
pub fn sliceLen(ip: *const InternPool, index: Index) Index {
    const unwrapped_index = index.unwrap(ip);
    const item = unwrapped_index.getItem(ip);
    switch (item.tag) {
        .ptr_slice => return extraData(unwrapped_index.getExtra(ip), PtrSlice, item.data).len,
        else => unreachable, // not a slice value
    }
}

/// Given an existing value, returns the same value but with the supplied type.
/// Only some combinations are allowed:
/// * identity coercion
/// * undef => any
/// * int <=> int
/// * int <=> enum
/// * enum_literal => enum
/// * float <=> float
/// * ptr <=> ptr
/// * opt ptr <=> ptr
/// * opt ptr <=> opt ptr
/// * int <=> ptr
/// * null_value => opt
/// * payload => opt
/// * error set <=> error set
/// * error union <=> error union
/// * error set => error union
/// * payload => error union
/// * fn <=> fn
/// * aggregate <=> aggregate (where children can also be coerced)
pub fn getCoerced(
    ip: *InternPool,
    gpa: Allocator,
    tid: Zcu.PerThread.Id,
    val: Index,
    new_ty: Index,
) Allocator.Error!Index {
    const old_ty = ip.typeOf(val);
    if (old_ty == new_ty) return val;

    switch (val) {
        .undef => return ip.get(gpa, tid, .{ .undef = new_ty }),
        .null_value => {
            if (ip.isOptionalType(new_ty)) return ip.get(gpa, tid, .{ .opt = .{
                .ty = new_ty,
                .val = .none,
            } });

            if (ip.isPointerType(new_ty)) switch (ip.indexToKey(new_ty).ptr_type.flags.size) {
                .One, .Many, .C => return ip.get(gpa, tid, .{ .ptr = .{
                    .ty = new_ty,
                    .base_addr = .int,
                    .byte_offset = 0,
                } }),
                .Slice => return ip.get(gpa, tid, .{ .slice = .{
                    .ty = new_ty,
                    .ptr = try ip.get(gpa, tid, .{ .ptr = .{
                        .ty = ip.slicePtrType(new_ty),
                        .base_addr = .int,
                        .byte_offset = 0,
                    } }),
                    .len = try ip.get(gpa, tid, .{ .undef = .usize_type }),
                } }),
            };
        },
        else => {
            const unwrapped_val = val.unwrap(ip);
            const val_item = unwrapped_val.getItem(ip);
            switch (val_item.tag) {
                .func_decl => return getCoercedFuncDecl(ip, gpa, tid, val, new_ty),
                .func_instance => return getCoercedFuncInstance(ip, gpa, tid, val, new_ty),
                .func_coerced => {
                    const func: Index = @enumFromInt(unwrapped_val.getExtra(ip).view().items(.@"0")[
                        val_item.data + std.meta.fieldIndex(Tag.FuncCoerced, "func").?
                    ]);
                    switch (func.unwrap(ip).getTag(ip)) {
                        .func_decl => return getCoercedFuncDecl(ip, gpa, tid, val, new_ty),
                        .func_instance => return getCoercedFuncInstance(ip, gpa, tid, val, new_ty),
                        else => unreachable,
                    }
                },
                else => {},
            }
        },
    }

    switch (ip.indexToKey(val)) {
        .undef => return ip.get(gpa, tid, .{ .undef = new_ty }),
        .extern_func => |extern_func| if (ip.isFunctionType(new_ty))
            return ip.get(gpa, tid, .{ .extern_func = .{
                .ty = new_ty,
                .decl = extern_func.decl,
                .lib_name = extern_func.lib_name,
            } }),

        .func => unreachable,

        .int => |int| switch (ip.indexToKey(new_ty)) {
            .enum_type => return ip.get(gpa, tid, .{ .enum_tag = .{
                .ty = new_ty,
                .int = try ip.getCoerced(gpa, tid, val, ip.loadEnumType(new_ty).tag_ty),
            } }),
            .ptr_type => switch (int.storage) {
                inline .u64, .i64 => |int_val| return ip.get(gpa, tid, .{ .ptr = .{
                    .ty = new_ty,
                    .base_addr = .int,
                    .byte_offset = @intCast(int_val),
                } }),
                .big_int => unreachable, // must be a usize
                .lazy_align, .lazy_size => {},
            },
            else => if (ip.isIntegerType(new_ty))
                return ip.getCoercedInts(gpa, tid, int, new_ty),
        },
        .float => |float| switch (ip.indexToKey(new_ty)) {
            .simple_type => |simple| switch (simple) {
                .f16,
                .f32,
                .f64,
                .f80,
                .f128,
                .c_longdouble,
                .comptime_float,
                => return ip.get(gpa, tid, .{ .float = .{
                    .ty = new_ty,
                    .storage = float.storage,
                } }),
                else => {},
            },
            else => {},
        },
        .enum_tag => |enum_tag| if (ip.isIntegerType(new_ty))
            return ip.getCoercedInts(gpa, tid, ip.indexToKey(enum_tag.int).int, new_ty),
        .enum_literal => |enum_literal| switch (ip.indexToKey(new_ty)) {
            .enum_type => {
                const enum_type = ip.loadEnumType(new_ty);
                const index = enum_type.nameIndex(ip, enum_literal).?;
                return ip.get(gpa, tid, .{ .enum_tag = .{
                    .ty = new_ty,
                    .int = if (enum_type.values.len != 0)
                        enum_type.values.get(ip)[index]
                    else
                        try ip.get(gpa, tid, .{ .int = .{
                            .ty = enum_type.tag_ty,
                            .storage = .{ .u64 = index },
                        } }),
                } });
            },
            else => {},
        },
        .slice => |slice| if (ip.isPointerType(new_ty) and ip.indexToKey(new_ty).ptr_type.flags.size == .Slice)
            return ip.get(gpa, tid, .{ .slice = .{
                .ty = new_ty,
                .ptr = try ip.getCoerced(gpa, tid, slice.ptr, ip.slicePtrType(new_ty)),
                .len = slice.len,
            } })
        else if (ip.isIntegerType(new_ty))
            return ip.getCoerced(gpa, tid, slice.ptr, new_ty),
        .ptr => |ptr| if (ip.isPointerType(new_ty) and ip.indexToKey(new_ty).ptr_type.flags.size != .Slice)
            return ip.get(gpa, tid, .{ .ptr = .{
                .ty = new_ty,
                .base_addr = ptr.base_addr,
                .byte_offset = ptr.byte_offset,
            } })
        else if (ip.isIntegerType(new_ty))
            switch (ptr.base_addr) {
                .int => return ip.get(gpa, tid, .{ .int = .{
                    .ty = .usize_type,
                    .storage = .{ .u64 = @intCast(ptr.byte_offset) },
                } }),
                else => {},
            },
        .opt => |opt| switch (ip.indexToKey(new_ty)) {
            .ptr_type => |ptr_type| return switch (opt.val) {
                .none => switch (ptr_type.flags.size) {
                    .One, .Many, .C => try ip.get(gpa, tid, .{ .ptr = .{
                        .ty = new_ty,
                        .base_addr = .int,
                        .byte_offset = 0,
                    } }),
                    .Slice => try ip.get(gpa, tid, .{ .slice = .{
                        .ty = new_ty,
                        .ptr = try ip.get(gpa, tid, .{ .ptr = .{
                            .ty = ip.slicePtrType(new_ty),
                            .base_addr = .int,
                            .byte_offset = 0,
                        } }),
                        .len = try ip.get(gpa, tid, .{ .undef = .usize_type }),
                    } }),
                },
                else => |payload| try ip.getCoerced(gpa, tid, payload, new_ty),
            },
            .opt_type => |child_type| return try ip.get(gpa, tid, .{ .opt = .{
                .ty = new_ty,
                .val = switch (opt.val) {
                    .none => .none,
                    else => try ip.getCoerced(gpa, tid, opt.val, child_type),
                },
            } }),
            else => {},
        },
        .err => |err| if (ip.isErrorSetType(new_ty))
            return ip.get(gpa, tid, .{ .err = .{
                .ty = new_ty,
                .name = err.name,
            } })
        else if (ip.isErrorUnionType(new_ty))
            return ip.get(gpa, tid, .{ .error_union = .{
                .ty = new_ty,
                .val = .{ .err_name = err.name },
            } }),
        .error_union => |error_union| if (ip.isErrorUnionType(new_ty))
            return ip.get(gpa, tid, .{ .error_union = .{
                .ty = new_ty,
                .val = error_union.val,
            } }),
        .aggregate => |aggregate| {
            const new_len: usize = @intCast(ip.aggregateTypeLen(new_ty));
            direct: {
                const old_ty_child = switch (ip.indexToKey(old_ty)) {
                    inline .array_type, .vector_type => |seq_type| seq_type.child,
                    .anon_struct_type, .struct_type => break :direct,
                    else => unreachable,
                };
                const new_ty_child = switch (ip.indexToKey(new_ty)) {
                    inline .array_type, .vector_type => |seq_type| seq_type.child,
                    .anon_struct_type, .struct_type => break :direct,
                    else => unreachable,
                };
                if (old_ty_child != new_ty_child) break :direct;
                switch (aggregate.storage) {
                    .bytes => |bytes| return ip.get(gpa, tid, .{ .aggregate = .{
                        .ty = new_ty,
                        .storage = .{ .bytes = bytes },
                    } }),
                    .elems => |elems| {
                        const elems_copy = try gpa.dupe(Index, elems[0..new_len]);
                        defer gpa.free(elems_copy);
                        return ip.get(gpa, tid, .{ .aggregate = .{
                            .ty = new_ty,
                            .storage = .{ .elems = elems_copy },
                        } });
                    },
                    .repeated_elem => |elem| {
                        return ip.get(gpa, tid, .{ .aggregate = .{
                            .ty = new_ty,
                            .storage = .{ .repeated_elem = elem },
                        } });
                    },
                }
            }
            // Direct approach failed - we must recursively coerce elems
            const agg_elems = try gpa.alloc(Index, new_len);
            defer gpa.free(agg_elems);
            // First, fill the vector with the uncoerced elements. We do this to avoid key
            // lifetime issues, since it'll allow us to avoid referencing `aggregate` after we
            // begin interning elems.
            switch (aggregate.storage) {
                .bytes => |bytes| {
                    // We have to intern each value here, so unfortunately we can't easily avoid
                    // the repeated indexToKey calls.
                    for (agg_elems, 0..) |*elem, index| {
                        elem.* = try ip.get(gpa, tid, .{ .int = .{
                            .ty = .u8_type,
                            .storage = .{ .u64 = bytes.at(index, ip) },
                        } });
                    }
                },
                .elems => |elems| @memcpy(agg_elems, elems[0..new_len]),
                .repeated_elem => |elem| @memset(agg_elems, elem),
            }
            // Now, coerce each element to its new type.
            for (agg_elems, 0..) |*elem, i| {
                const new_elem_ty = switch (ip.indexToKey(new_ty)) {
                    inline .array_type, .vector_type => |seq_type| seq_type.child,
                    .anon_struct_type => |anon_struct_type| anon_struct_type.types.get(ip)[i],
                    .struct_type => ip.loadStructType(new_ty).field_types.get(ip)[i],
                    else => unreachable,
                };
                elem.* = try ip.getCoerced(gpa, tid, elem.*, new_elem_ty);
            }
            return ip.get(gpa, tid, .{ .aggregate = .{ .ty = new_ty, .storage = .{ .elems = agg_elems } } });
        },
        else => {},
    }

    switch (ip.indexToKey(new_ty)) {
        .opt_type => |child_type| switch (val) {
            .null_value => return ip.get(gpa, tid, .{ .opt = .{
                .ty = new_ty,
                .val = .none,
            } }),
            else => return ip.get(gpa, tid, .{ .opt = .{
                .ty = new_ty,
                .val = try ip.getCoerced(gpa, tid, val, child_type),
            } }),
        },
        .error_union_type => |error_union_type| return ip.get(gpa, tid, .{ .error_union = .{
            .ty = new_ty,
            .val = .{ .payload = try ip.getCoerced(gpa, tid, val, error_union_type.payload_type) },
        } }),
        else => {},
    }
    if (std.debug.runtime_safety) {
        std.debug.panic("InternPool.getCoerced of {s} not implemented from {s} to {s}", .{
            @tagName(ip.indexToKey(val)),
            @tagName(ip.indexToKey(old_ty)),
            @tagName(ip.indexToKey(new_ty)),
        });
    }
    unreachable;
}

fn getCoercedFuncDecl(
    ip: *InternPool,
    gpa: Allocator,
    tid: Zcu.PerThread.Id,
    val: Index,
    new_ty: Index,
) Allocator.Error!Index {
    const unwrapped_val = val.unwrap(ip);
    const prev_ty: Index = @enumFromInt(unwrapped_val.getExtra(ip).view().items(.@"0")[
        unwrapped_val.getData(ip) + std.meta.fieldIndex(Tag.FuncDecl, "ty").?
    ]);
    if (new_ty == prev_ty) return val;
    return getCoercedFunc(ip, gpa, tid, val, new_ty);
}

fn getCoercedFuncInstance(
    ip: *InternPool,
    gpa: Allocator,
    tid: Zcu.PerThread.Id,
    val: Index,
    new_ty: Index,
) Allocator.Error!Index {
    const unwrapped_val = val.unwrap(ip);
    const prev_ty: Index = @enumFromInt(unwrapped_val.getExtra(ip).view().items(.@"0")[
        unwrapped_val.getData(ip) + std.meta.fieldIndex(Tag.FuncInstance, "ty").?
    ]);
    if (new_ty == prev_ty) return val;
    return getCoercedFunc(ip, gpa, tid, val, new_ty);
}

fn getCoercedFunc(
    ip: *InternPool,
    gpa: Allocator,
    tid: Zcu.PerThread.Id,
    func: Index,
    ty: Index,
) Allocator.Error!Index {
    const local = ip.getLocal(tid);
    const items = local.getMutableItems(gpa);
    try items.ensureUnusedCapacity(1);
    const extra = local.getMutableExtra(gpa);

    const prev_extra_len = extra.mutate.len;
    try extra.ensureUnusedCapacity(@typeInfo(Tag.FuncCoerced).Struct.fields.len);

    const extra_index = addExtraAssumeCapacity(extra, Tag.FuncCoerced{
        .ty = ty,
        .func = func,
    });
    errdefer extra.mutate.len = prev_extra_len;

    var gop = try ip.getOrPutKey(gpa, tid, .{
        .func = ip.extraFuncCoerced(extra.list.*, extra_index),
    });
    defer gop.deinit();
    if (gop == .existing) {
        extra.mutate.len = prev_extra_len;
        return gop.existing;
    }

    items.appendAssumeCapacity(.{
        .tag = .func_coerced,
        .data = extra_index,
    });
    return gop.put();
}

/// Asserts `val` has an integer type.
/// Assumes `new_ty` is an integer type.
pub fn getCoercedInts(ip: *InternPool, gpa: Allocator, tid: Zcu.PerThread.Id, int: Key.Int, new_ty: Index) Allocator.Error!Index {
    return ip.get(gpa, tid, .{ .int = .{
        .ty = new_ty,
        .storage = int.storage,
    } });
}

pub fn indexToFuncType(ip: *const InternPool, val: Index) ?Key.FuncType {
    const unwrapped_val = val.unwrap(ip);
    const item = unwrapped_val.getItem(ip);
    switch (item.tag) {
        .type_function => return extraFuncType(unwrapped_val.tid, unwrapped_val.getExtra(ip), item.data),
        else => return null,
    }
}

/// includes .comptime_int_type
pub fn isIntegerType(ip: *const InternPool, ty: Index) bool {
    return switch (ty) {
        .usize_type,
        .isize_type,
        .c_char_type,
        .c_short_type,
        .c_ushort_type,
        .c_int_type,
        .c_uint_type,
        .c_long_type,
        .c_ulong_type,
        .c_longlong_type,
        .c_ulonglong_type,
        .comptime_int_type,
        => true,
        else => switch (ty.unwrap(ip).getTag(ip)) {
            .type_int_signed,
            .type_int_unsigned,
            => true,
            else => false,
        },
    };
}

/// does not include .enum_literal_type
pub fn isEnumType(ip: *const InternPool, ty: Index) bool {
    return switch (ty) {
        .atomic_order_type,
        .atomic_rmw_op_type,
        .calling_convention_type,
        .address_space_type,
        .float_mode_type,
        .reduce_op_type,
        .call_modifier_type,
        => true,
        else => ip.indexToKey(ty) == .enum_type,
    };
}

pub fn isUnion(ip: *const InternPool, ty: Index) bool {
    return ip.indexToKey(ty) == .union_type;
}

pub fn isFunctionType(ip: *const InternPool, ty: Index) bool {
    return ip.indexToKey(ty) == .func_type;
}

pub fn isPointerType(ip: *const InternPool, ty: Index) bool {
    return ip.indexToKey(ty) == .ptr_type;
}

pub fn isOptionalType(ip: *const InternPool, ty: Index) bool {
    return ip.indexToKey(ty) == .opt_type;
}

/// includes .inferred_error_set_type
pub fn isErrorSetType(ip: *const InternPool, ty: Index) bool {
    return switch (ty) {
        .anyerror_type, .adhoc_inferred_error_set_type => true,
        else => switch (ip.indexToKey(ty)) {
            .error_set_type, .inferred_error_set_type => true,
            else => false,
        },
    };
}

pub fn isInferredErrorSetType(ip: *const InternPool, ty: Index) bool {
    return ty == .adhoc_inferred_error_set_type or ip.indexToKey(ty) == .inferred_error_set_type;
}

pub fn isErrorUnionType(ip: *const InternPool, ty: Index) bool {
    return ip.indexToKey(ty) == .error_union_type;
}

pub fn isAggregateType(ip: *const InternPool, ty: Index) bool {
    return switch (ip.indexToKey(ty)) {
        .array_type, .vector_type, .anon_struct_type, .struct_type => true,
        else => false,
    };
}

pub fn errorUnionSet(ip: *const InternPool, ty: Index) Index {
    return ip.indexToKey(ty).error_union_type.error_set_type;
}

pub fn errorUnionPayload(ip: *const InternPool, ty: Index) Index {
    return ip.indexToKey(ty).error_union_type.payload_type;
}

/// The is only legal because the initializer is not part of the hash.
pub fn mutateVarInit(ip: *InternPool, index: Index, init_index: Index) void {
    const unwrapped_index = index.unwrap(ip);
    const extra_list = unwrapped_index.getExtra(ip);
    const item = unwrapped_index.getItem(ip);
    assert(item.tag == .variable);
    @atomicStore(u32, &extra_list.view().items(.@"0")[item.data + std.meta.fieldIndex(Tag.Variable, "init").?], @intFromEnum(init_index), .release);
}

pub fn dump(ip: *const InternPool) void {
    dumpStatsFallible(ip, std.heap.page_allocator) catch return;
    dumpAllFallible(ip) catch return;
}

fn dumpStatsFallible(ip: *const InternPool, arena: Allocator) anyerror!void {
    var items_len: usize = 0;
    var extra_len: usize = 0;
    var limbs_len: usize = 0;
    var decls_len: usize = 0;
    for (ip.locals) |*local| {
        items_len += local.mutate.items.len;
        extra_len += local.mutate.extra.len;
        limbs_len += local.mutate.limbs.len;
        decls_len += local.mutate.decls.buckets_list.len;
    }
    const items_size = (1 + 4) * items_len;
    const extra_size = 4 * extra_len;
    const limbs_size = 8 * limbs_len;
    const decls_size = @sizeOf(Module.Decl) * decls_len;

    // TODO: map overhead size is not taken into account
    const total_size = @sizeOf(InternPool) + items_size + extra_size + limbs_size + decls_size;

    std.debug.print(
        \\InternPool size: {d} bytes
        \\  {d} items: {d} bytes
        \\  {d} extra: {d} bytes
        \\  {d} limbs: {d} bytes
        \\  {d} decls: {d} bytes
        \\
    , .{
        total_size,
        items_len,
        items_size,
        extra_len,
        extra_size,
        limbs_len,
        limbs_size,
        decls_len,
        decls_size,
    });

    const TagStats = struct {
        count: usize = 0,
        bytes: usize = 0,
    };
    var counts = std.AutoArrayHashMap(Tag, TagStats).init(arena);
    for (ip.locals) |*local| {
        const items = local.shared.items.view().slice();
        const extra_list = local.shared.extra;
        const extra_items = extra_list.view().items(.@"0");
        for (
            items.items(.tag)[0..local.mutate.items.len],
            items.items(.data)[0..local.mutate.items.len],
        ) |tag, data| {
            const gop = try counts.getOrPut(tag);
            if (!gop.found_existing) gop.value_ptr.* = .{};
            gop.value_ptr.count += 1;
            gop.value_ptr.bytes += 1 + 4 + @as(usize, switch (tag) {
                // Note that in this case, we have technically leaked some extra data
                // bytes which we do not account for here.
                .removed => 0,

                .type_int_signed => 0,
                .type_int_unsigned => 0,
                .type_array_small => @sizeOf(Vector),
                .type_array_big => @sizeOf(Array),
                .type_vector => @sizeOf(Vector),
                .type_pointer => @sizeOf(Tag.TypePointer),
                .type_slice => 0,
                .type_optional => 0,
                .type_anyframe => 0,
                .type_error_union => @sizeOf(Key.ErrorUnionType),
                .type_anyerror_union => 0,
                .type_error_set => b: {
                    const info = extraData(extra_list, Tag.ErrorSet, data);
                    break :b @sizeOf(Tag.ErrorSet) + (@sizeOf(u32) * info.names_len);
                },
                .type_inferred_error_set => 0,
                .type_enum_explicit, .type_enum_nonexhaustive => b: {
                    const info = extraData(extra_list, EnumExplicit, data);
                    var ints = @typeInfo(EnumExplicit).Struct.fields.len;
                    if (info.zir_index == .none) ints += 1;
                    ints += if (info.captures_len != std.math.maxInt(u32))
                        info.captures_len
                    else
                        @typeInfo(PackedU64).Struct.fields.len;
                    ints += info.fields_len;
                    if (info.values_map != .none) ints += info.fields_len;
                    break :b @sizeOf(u32) * ints;
                },
                .type_enum_auto => b: {
                    const info = extraData(extra_list, EnumAuto, data);
                    const ints = @typeInfo(EnumAuto).Struct.fields.len + info.captures_len + info.fields_len;
                    break :b @sizeOf(u32) * ints;
                },
                .type_opaque => b: {
                    const info = extraData(extra_list, Tag.TypeOpaque, data);
                    const ints = @typeInfo(Tag.TypeOpaque).Struct.fields.len + info.captures_len;
                    break :b @sizeOf(u32) * ints;
                },
                .type_struct => b: {
                    if (data == 0) break :b 0;
                    const extra = extraDataTrail(extra_list, Tag.TypeStruct, data);
                    const info = extra.data;
                    var ints: usize = @typeInfo(Tag.TypeStruct).Struct.fields.len;
                    if (info.flags.any_captures) {
                        const captures_len = extra_items[extra.end];
                        ints += 1 + captures_len;
                    }
                    ints += info.fields_len; // types
                    if (!info.flags.is_tuple) {
                        ints += 1; // names_map
                        ints += info.fields_len; // names
                    }
                    if (info.flags.any_default_inits)
                        ints += info.fields_len; // inits
                    ints += @intFromBool(info.flags.has_namespace); // namespace
                    if (info.flags.any_aligned_fields)
                        ints += (info.fields_len + 3) / 4; // aligns
                    if (info.flags.any_comptime_fields)
                        ints += (info.fields_len + 31) / 32; // comptime bits
                    if (!info.flags.is_extern)
                        ints += info.fields_len; // runtime order
                    ints += info.fields_len; // offsets
                    break :b @sizeOf(u32) * ints;
                },
                .type_struct_anon => b: {
                    const info = extraData(extra_list, TypeStructAnon, data);
                    break :b @sizeOf(TypeStructAnon) + (@sizeOf(u32) * 3 * info.fields_len);
                },
                .type_struct_packed => b: {
                    const extra = extraDataTrail(extra_list, Tag.TypeStructPacked, data);
                    const captures_len = if (extra.data.flags.any_captures)
                        extra_items[extra.end]
                    else
                        0;
                    break :b @sizeOf(u32) * (@typeInfo(Tag.TypeStructPacked).Struct.fields.len +
                        @intFromBool(extra.data.flags.any_captures) + captures_len +
                        extra.data.fields_len * 2);
                },
                .type_struct_packed_inits => b: {
                    const extra = extraDataTrail(extra_list, Tag.TypeStructPacked, data);
                    const captures_len = if (extra.data.flags.any_captures)
                        extra_items[extra.end]
                    else
                        0;
                    break :b @sizeOf(u32) * (@typeInfo(Tag.TypeStructPacked).Struct.fields.len +
                        @intFromBool(extra.data.flags.any_captures) + captures_len +
                        extra.data.fields_len * 3);
                },
                .type_tuple_anon => b: {
                    const info = extraData(extra_list, TypeStructAnon, data);
                    break :b @sizeOf(TypeStructAnon) + (@sizeOf(u32) * 2 * info.fields_len);
                },

                .type_union => b: {
                    const extra = extraDataTrail(extra_list, Tag.TypeUnion, data);
                    const captures_len = if (extra.data.flags.any_captures)
                        extra_items[extra.end]
                    else
                        0;
                    const per_field = @sizeOf(u32); // field type
                    // 1 byte per field for alignment, rounded up to the nearest 4 bytes
                    const alignments = if (extra.data.flags.any_aligned_fields)
                        ((extra.data.fields_len + 3) / 4) * 4
                    else
                        0;
                    break :b @sizeOf(Tag.TypeUnion) +
                        4 * (@intFromBool(extra.data.flags.any_captures) + captures_len) +
                        (extra.data.fields_len * per_field) + alignments;
                },

                .type_function => b: {
                    const info = extraData(extra_list, Tag.TypeFunction, data);
                    break :b @sizeOf(Tag.TypeFunction) +
                        (@sizeOf(Index) * info.params_len) +
                        (@as(u32, 4) * @intFromBool(info.flags.has_comptime_bits)) +
                        (@as(u32, 4) * @intFromBool(info.flags.has_noalias_bits));
                },

                .undef => 0,
                .simple_type => 0,
                .simple_value => 0,
                .ptr_decl => @sizeOf(PtrDecl),
                .ptr_comptime_alloc => @sizeOf(PtrComptimeAlloc),
                .ptr_anon_decl => @sizeOf(PtrAnonDecl),
                .ptr_anon_decl_aligned => @sizeOf(PtrAnonDeclAligned),
                .ptr_comptime_field => @sizeOf(PtrComptimeField),
                .ptr_int => @sizeOf(PtrInt),
                .ptr_eu_payload => @sizeOf(PtrBase),
                .ptr_opt_payload => @sizeOf(PtrBase),
                .ptr_elem => @sizeOf(PtrBaseIndex),
                .ptr_field => @sizeOf(PtrBaseIndex),
                .ptr_slice => @sizeOf(PtrSlice),
                .opt_null => 0,
                .opt_payload => @sizeOf(Tag.TypeValue),
                .int_u8 => 0,
                .int_u16 => 0,
                .int_u32 => 0,
                .int_i32 => 0,
                .int_usize => 0,
                .int_comptime_int_u32 => 0,
                .int_comptime_int_i32 => 0,
                .int_small => @sizeOf(IntSmall),

                .int_positive,
                .int_negative,
                => b: {
                    const limbs_list = local.shared.getLimbs();
                    const int: Int = @bitCast(limbs_list.view().items(.@"0")[data..][0..Int.limbs_items_len].*);
                    break :b @sizeOf(Int) + int.limbs_len * @sizeOf(Limb);
                },

                .int_lazy_align, .int_lazy_size => @sizeOf(IntLazy),

                .error_set_error, .error_union_error => @sizeOf(Key.Error),
                .error_union_payload => @sizeOf(Tag.TypeValue),
                .enum_literal => 0,
                .enum_tag => @sizeOf(Tag.EnumTag),

                .bytes => b: {
                    const info = extraData(extra_list, Bytes, data);
                    const len: usize = @intCast(ip.aggregateTypeLenIncludingSentinel(info.ty));
                    break :b @sizeOf(Bytes) + len + @intFromBool(info.bytes.at(len - 1, ip) != 0);
                },
                .aggregate => b: {
                    const info = extraData(extra_list, Tag.Aggregate, data);
                    const fields_len: u32 = @intCast(ip.aggregateTypeLenIncludingSentinel(info.ty));
                    break :b @sizeOf(Tag.Aggregate) + (@sizeOf(Index) * fields_len);
                },
                .repeated => @sizeOf(Repeated),

                .float_f16 => 0,
                .float_f32 => 0,
                .float_f64 => @sizeOf(Float64),
                .float_f80 => @sizeOf(Float80),
                .float_f128 => @sizeOf(Float128),
                .float_c_longdouble_f80 => @sizeOf(Float80),
                .float_c_longdouble_f128 => @sizeOf(Float128),
                .float_comptime_float => @sizeOf(Float128),
                .variable => @sizeOf(Tag.Variable),
                .extern_func => @sizeOf(Tag.ExternFunc),
                .func_decl => @sizeOf(Tag.FuncDecl),
                .func_instance => b: {
                    const info = extraData(extra_list, Tag.FuncInstance, data);
                    const ty = ip.typeOf(info.generic_owner);
                    const params_len = ip.indexToKey(ty).func_type.param_types.len;
                    break :b @sizeOf(Tag.FuncInstance) + @sizeOf(Index) * params_len;
                },
                .func_coerced => @sizeOf(Tag.FuncCoerced),
                .only_possible_value => 0,
                .union_value => @sizeOf(Key.Union),

                .memoized_call => b: {
                    const info = extraData(extra_list, MemoizedCall, data);
                    break :b @sizeOf(MemoizedCall) + (@sizeOf(Index) * info.args_len);
                },
            });
        }
    }
    const SortContext = struct {
        map: *std.AutoArrayHashMap(Tag, TagStats),
        pub fn lessThan(ctx: @This(), a_index: usize, b_index: usize) bool {
            const values = ctx.map.values();
            return values[a_index].bytes > values[b_index].bytes;
            //return values[a_index].count > values[b_index].count;
        }
    };
    counts.sort(SortContext{ .map = &counts });
    const len = @min(50, counts.count());
    std.debug.print("  top 50 tags:\n", .{});
    for (counts.keys()[0..len], counts.values()[0..len]) |tag, stats| {
        std.debug.print("    {s}: {d} occurrences, {d} total bytes\n", .{
            @tagName(tag), stats.count, stats.bytes,
        });
    }
}

fn dumpAllFallible(ip: *const InternPool) anyerror!void {
    var bw = std.io.bufferedWriter(std.io.getStdErr().writer());
    const w = bw.writer();
    for (ip.locals, 0..) |*local, tid| {
        const items = local.shared.items.view();
        for (
            items.items(.tag)[0..local.mutate.items.len],
            items.items(.data)[0..local.mutate.items.len],
            0..,
        ) |tag, data, index| {
            const i = Index.Unwrapped.wrap(.{ .tid = @enumFromInt(tid), .index = @intCast(index) }, ip);
            try w.print("${d} = {s}(", .{ i, @tagName(tag) });
            switch (tag) {
                .removed => {},

                .simple_type => try w.print("{s}", .{@tagName(@as(SimpleType, @enumFromInt(@intFromEnum(i))))}),
                .simple_value => try w.print("{s}", .{@tagName(@as(SimpleValue, @enumFromInt(@intFromEnum(i))))}),

                .type_int_signed,
                .type_int_unsigned,
                .type_array_small,
                .type_array_big,
                .type_vector,
                .type_pointer,
                .type_optional,
                .type_anyframe,
                .type_error_union,
                .type_anyerror_union,
                .type_error_set,
                .type_inferred_error_set,
                .type_enum_explicit,
                .type_enum_nonexhaustive,
                .type_enum_auto,
                .type_opaque,
                .type_struct,
                .type_struct_anon,
                .type_struct_packed,
                .type_struct_packed_inits,
                .type_tuple_anon,
                .type_union,
                .type_function,
                .undef,
                .ptr_decl,
                .ptr_comptime_alloc,
                .ptr_anon_decl,
                .ptr_anon_decl_aligned,
                .ptr_comptime_field,
                .ptr_int,
                .ptr_eu_payload,
                .ptr_opt_payload,
                .ptr_elem,
                .ptr_field,
                .ptr_slice,
                .opt_payload,
                .int_u8,
                .int_u16,
                .int_u32,
                .int_i32,
                .int_usize,
                .int_comptime_int_u32,
                .int_comptime_int_i32,
                .int_small,
                .int_positive,
                .int_negative,
                .int_lazy_align,
                .int_lazy_size,
                .error_set_error,
                .error_union_error,
                .error_union_payload,
                .enum_literal,
                .enum_tag,
                .bytes,
                .aggregate,
                .repeated,
                .float_f16,
                .float_f32,
                .float_f64,
                .float_f80,
                .float_f128,
                .float_c_longdouble_f80,
                .float_c_longdouble_f128,
                .float_comptime_float,
                .variable,
                .extern_func,
                .func_decl,
                .func_instance,
                .func_coerced,
                .union_value,
                .memoized_call,
                => try w.print("{d}", .{data}),

                .opt_null,
                .type_slice,
                .only_possible_value,
                => try w.print("${d}", .{data}),
            }
            try w.writeAll(")\n");
        }
    }
    try bw.flush();
}

pub fn dumpGenericInstances(ip: *const InternPool, allocator: Allocator) void {
    ip.dumpGenericInstancesFallible(allocator) catch return;
}

pub fn dumpGenericInstancesFallible(ip: *const InternPool, allocator: Allocator) anyerror!void {
    var arena_allocator = std.heap.ArenaAllocator.init(allocator);
    defer arena_allocator.deinit();
    const arena = arena_allocator.allocator();

    var bw = std.io.bufferedWriter(std.io.getStdErr().writer());
    const w = bw.writer();

    var instances: std.AutoArrayHashMapUnmanaged(Index, std.ArrayListUnmanaged(Index)) = .{};
    for (ip.locals, 0..) |*local, tid| {
        const items = local.shared.items.view().slice();
        const extra_list = local.shared.extra;
        for (
            items.items(.tag)[0..local.mutate.items.len],
            items.items(.data)[0..local.mutate.items.len],
            0..,
        ) |tag, data, index| {
            if (tag != .func_instance) continue;
            const info = extraData(extra_list, Tag.FuncInstance, data);

            const gop = try instances.getOrPut(arena, info.generic_owner);
            if (!gop.found_existing) gop.value_ptr.* = .{};

            try gop.value_ptr.append(
                arena,
                Index.Unwrapped.wrap(.{ .tid = @enumFromInt(tid), .index = @intCast(index) }, ip),
            );
        }
    }

    const SortContext = struct {
        values: []std.ArrayListUnmanaged(Index),
        pub fn lessThan(ctx: @This(), a_index: usize, b_index: usize) bool {
            return ctx.values[a_index].items.len > ctx.values[b_index].items.len;
        }
    };

    instances.sort(SortContext{ .values = instances.values() });
    var it = instances.iterator();
    while (it.next()) |entry| {
        const generic_fn_owner_decl = ip.declPtrConst(ip.funcDeclOwner(entry.key_ptr.*));
        try w.print("{} ({}): \n", .{ generic_fn_owner_decl.name.fmt(ip), entry.value_ptr.items.len });
        for (entry.value_ptr.items) |index| {
            const unwrapped_index = index.unwrap(ip);
            const func = ip.extraFuncInstance(unwrapped_index.tid, unwrapped_index.getExtra(ip), unwrapped_index.getData(ip));
            const owner_decl = ip.declPtrConst(func.owner_decl);
            try w.print("  {}: (", .{owner_decl.name.fmt(ip)});
            for (func.comptime_args.get(ip)) |arg| {
                if (arg != .none) {
                    const key = ip.indexToKey(arg);
                    try w.print(" {} ", .{key});
                }
            }
            try w.writeAll(")\n");
        }
    }

    try bw.flush();
}

pub fn declPtr(ip: *InternPool, decl_index: DeclIndex) *Module.Decl {
    return @constCast(ip.declPtrConst(decl_index));
}

pub fn declPtrConst(ip: *const InternPool, decl_index: DeclIndex) *const Module.Decl {
    const unwrapped_decl_index = decl_index.unwrap(ip);
    const decls = ip.getLocalShared(unwrapped_decl_index.tid).decls.acquire();
    const decls_bucket = decls.view().items(.@"0")[unwrapped_decl_index.bucket_index];
    return &decls_bucket[unwrapped_decl_index.index];
}

pub fn namespacePtr(ip: *InternPool, namespace_index: NamespaceIndex) *Module.Namespace {
    const unwrapped_namespace_index = namespace_index.unwrap(ip);
    const namespaces = ip.getLocalShared(unwrapped_namespace_index.tid).namespaces.acquire();
    const namespaces_bucket = namespaces.view().items(.@"0")[unwrapped_namespace_index.bucket_index];
    return &namespaces_bucket[unwrapped_namespace_index.index];
}

pub fn createDecl(
    ip: *InternPool,
    gpa: Allocator,
    tid: Zcu.PerThread.Id,
    initialization: Module.Decl,
) Allocator.Error!DeclIndex {
    const local = ip.getLocal(tid);
    const free_list_next = local.mutate.decls.free_list;
    if (free_list_next != Local.BucketListMutate.free_list_sentinel) {
        const reused_decl_index: DeclIndex = @enumFromInt(free_list_next);
        const reused_decl = ip.declPtr(reused_decl_index);
        local.mutate.decls.free_list = @intFromEnum(@field(reused_decl, Local.decl_next_free_field));
        reused_decl.* = initialization;
        return reused_decl_index;
    }
    const decls = local.getMutableDecls(gpa);
    if (local.mutate.decls.last_bucket_len == 0) {
        try decls.ensureUnusedCapacity(1);
        var arena = decls.arena.promote(decls.gpa);
        defer decls.arena.* = arena.state;
        decls.appendAssumeCapacity(.{try arena.allocator().create(
            [1 << Local.decls_bucket_width]Module.Decl,
        )});
    }
    const unwrapped_decl_index: DeclIndex.Unwrapped = .{
        .tid = tid,
        .bucket_index = decls.mutate.len - 1,
        .index = local.mutate.decls.last_bucket_len,
    };
    local.mutate.decls.last_bucket_len =
        (unwrapped_decl_index.index + 1) & Local.namespaces_bucket_mask;
    const decl_index = unwrapped_decl_index.wrap(ip);
    ip.declPtr(decl_index).* = initialization;
    return decl_index;
}

pub fn destroyDecl(ip: *InternPool, tid: Zcu.PerThread.Id, decl_index: DeclIndex) void {
    const local = ip.getLocal(tid);
    const decl = ip.declPtr(decl_index);
    decl.* = undefined;
    @field(decl, Local.decl_next_free_field) = @enumFromInt(local.mutate.decls.free_list);
    local.mutate.decls.free_list = @intFromEnum(decl_index);
}

pub fn createNamespace(
    ip: *InternPool,
    gpa: Allocator,
    tid: Zcu.PerThread.Id,
    initialization: Module.Namespace,
) Allocator.Error!NamespaceIndex {
    const local = ip.getLocal(tid);
    const free_list_next = local.mutate.namespaces.free_list;
    if (free_list_next != Local.BucketListMutate.free_list_sentinel) {
        const reused_namespace_index: NamespaceIndex = @enumFromInt(free_list_next);
        const reused_namespace = ip.namespacePtr(reused_namespace_index);
        local.mutate.namespaces.free_list =
            @intFromEnum(@field(reused_namespace, Local.namespace_next_free_field));
        reused_namespace.* = initialization;
        return reused_namespace_index;
    }
    const namespaces = local.getMutableNamespaces(gpa);
    if (local.mutate.namespaces.last_bucket_len == 0) {
        try namespaces.ensureUnusedCapacity(1);
        var arena = namespaces.arena.promote(namespaces.gpa);
        defer namespaces.arena.* = arena.state;
        namespaces.appendAssumeCapacity(.{try arena.allocator().create(
            [1 << Local.namespaces_bucket_width]Module.Namespace,
        )});
    }
    const unwrapped_namespace_index: NamespaceIndex.Unwrapped = .{
        .tid = tid,
        .bucket_index = namespaces.mutate.len - 1,
        .index = local.mutate.namespaces.last_bucket_len,
    };
    local.mutate.namespaces.last_bucket_len =
        (unwrapped_namespace_index.index + 1) & Local.namespaces_bucket_mask;
    const namespace_index = unwrapped_namespace_index.wrap(ip);
    ip.namespacePtr(namespace_index).* = initialization;
    return namespace_index;
}

pub fn destroyNamespace(
    ip: *InternPool,
    tid: Zcu.PerThread.Id,
    namespace_index: NamespaceIndex,
) void {
    const local = ip.getLocal(tid);
    const namespace = ip.namespacePtr(namespace_index);
    namespace.* = .{
        .parent = undefined,
        .file_scope = undefined,
        .decl_index = undefined,
    };
    @field(namespace, Local.namespace_next_free_field) =
        @enumFromInt(local.mutate.namespaces.free_list);
    local.mutate.namespaces.free_list = @intFromEnum(namespace_index);
}

const EmbeddedNulls = enum {
    no_embedded_nulls,
    maybe_embedded_nulls,

    fn StringType(comptime embedded_nulls: EmbeddedNulls) type {
        return switch (embedded_nulls) {
            .no_embedded_nulls => NullTerminatedString,
            .maybe_embedded_nulls => String,
        };
    }

    fn OptionalStringType(comptime embedded_nulls: EmbeddedNulls) type {
        return switch (embedded_nulls) {
            .no_embedded_nulls => OptionalNullTerminatedString,
            .maybe_embedded_nulls => OptionalString,
        };
    }
};

pub fn getOrPutString(
    ip: *InternPool,
    gpa: Allocator,
    tid: Zcu.PerThread.Id,
    slice: []const u8,
    comptime embedded_nulls: EmbeddedNulls,
) Allocator.Error!embedded_nulls.StringType() {
    const strings = ip.getLocal(tid).getMutableStrings(gpa);
    try strings.ensureUnusedCapacity(slice.len + 1);
    strings.appendSliceAssumeCapacity(.{slice});
    strings.appendAssumeCapacity(.{0});
    return ip.getOrPutTrailingString(gpa, tid, @intCast(slice.len + 1), embedded_nulls);
}

pub fn getOrPutStringFmt(
    ip: *InternPool,
    gpa: Allocator,
    tid: Zcu.PerThread.Id,
    comptime format: []const u8,
    args: anytype,
    comptime embedded_nulls: EmbeddedNulls,
) Allocator.Error!embedded_nulls.StringType() {
    // ensure that references to strings in args do not get invalidated
    const format_z = format ++ .{0};
    const len: u32 = @intCast(std.fmt.count(format_z, args));
    const strings = ip.getLocal(tid).getMutableStrings(gpa);
    const slice = try strings.addManyAsSlice(len);
    assert((std.fmt.bufPrint(slice[0], format_z, args) catch unreachable).len == len);
    return ip.getOrPutTrailingString(gpa, tid, len, embedded_nulls);
}

pub fn getOrPutStringOpt(
    ip: *InternPool,
    gpa: Allocator,
    tid: Zcu.PerThread.Id,
    slice: ?[]const u8,
    comptime embedded_nulls: EmbeddedNulls,
) Allocator.Error!embedded_nulls.OptionalStringType() {
    const string = try getOrPutString(ip, gpa, tid, slice orelse return .none, embedded_nulls);
    return string.toOptional();
}

/// Uses the last len bytes of strings as the key.
pub fn getOrPutTrailingString(
    ip: *InternPool,
    gpa: Allocator,
    tid: Zcu.PerThread.Id,
    len: u32,
    comptime embedded_nulls: EmbeddedNulls,
) Allocator.Error!embedded_nulls.StringType() {
    const strings = ip.getLocal(tid).getMutableStrings(gpa);
    const start: u32 = @intCast(strings.mutate.len - len);
    if (len > 0 and strings.view().items(.@"0")[strings.mutate.len - 1] == 0) {
        strings.mutate.len -= 1;
    } else {
        try strings.ensureUnusedCapacity(1);
    }
    const key: []const u8 = strings.view().items(.@"0")[start..];
    const value: embedded_nulls.StringType() =
        @enumFromInt(@as(u32, @intFromEnum(tid)) << ip.tid_shift_32 | start);
    const has_embedded_null = std.mem.indexOfScalar(u8, key, 0) != null;
    switch (embedded_nulls) {
        .no_embedded_nulls => assert(!has_embedded_null),
        .maybe_embedded_nulls => if (has_embedded_null) {
            strings.appendAssumeCapacity(.{0});
            return value;
        },
    }

    const full_hash = Hash.hash(0, key);
    const hash: u32 = @truncate(full_hash >> 32);
    const shard = &ip.shards[@intCast(full_hash & (ip.shards.len - 1))];
    var map = shard.shared.string_map.acquire();
    const Map = @TypeOf(map);
    var map_mask = map.header().mask();
    var map_index = hash;
    while (true) : (map_index += 1) {
        map_index &= map_mask;
        const entry = &map.entries[map_index];
        const index = entry.acquire().unwrap() orelse break;
        if (entry.hash != hash) continue;
        if (!index.eqlSlice(key, ip)) continue;
        strings.shrinkRetainingCapacity(start);
        return @enumFromInt(@intFromEnum(index));
    }
    shard.mutate.string_map.mutex.lock();
    defer shard.mutate.string_map.mutex.unlock();
    if (map.entries != shard.shared.string_map.entries) {
        shard.mutate.string_map.len += 1;
        map = shard.shared.string_map;
        map_mask = map.header().mask();
        map_index = hash;
    }
    while (true) : (map_index += 1) {
        map_index &= map_mask;
        const entry = &map.entries[map_index];
        const index = entry.acquire().unwrap() orelse break;
        if (entry.hash != hash) continue;
        if (!index.eqlSlice(key, ip)) continue;
        strings.shrinkRetainingCapacity(start);
        return @enumFromInt(@intFromEnum(index));
    }
    defer shard.mutate.string_map.len += 1;
    const map_header = map.header().*;
    if (shard.mutate.string_map.len < map_header.capacity * 3 / 5) {
        const entry = &map.entries[map_index];
        entry.hash = hash;
        entry.release(@enumFromInt(@intFromEnum(value)));
        strings.appendAssumeCapacity(.{0});
        return value;
    }
    const arena_state = &ip.getLocal(tid).mutate.arena;
    var arena = arena_state.promote(gpa);
    defer arena_state.* = arena.state;
    const new_map_capacity = map_header.capacity * 2;
    const new_map_buf = try arena.allocator().alignedAlloc(
        u8,
        Map.alignment,
        Map.entries_offset + new_map_capacity * @sizeOf(Map.Entry),
    );
    const new_map: Map = .{ .entries = @ptrCast(new_map_buf[Map.entries_offset..].ptr) };
    new_map.header().* = .{ .capacity = new_map_capacity };
    @memset(new_map.entries[0..new_map_capacity], .{ .value = .none, .hash = undefined });
    const new_map_mask = new_map.header().mask();
    map_index = 0;
    while (map_index < map_header.capacity) : (map_index += 1) {
        const entry = &map.entries[map_index];
        const index = entry.value.unwrap() orelse continue;
        const item_hash = entry.hash;
        var new_map_index = item_hash;
        while (true) : (new_map_index += 1) {
            new_map_index &= new_map_mask;
            const new_entry = &new_map.entries[new_map_index];
            if (new_entry.value != .none) continue;
            new_entry.* = .{
                .value = index.toOptional(),
                .hash = item_hash,
            };
            break;
        }
    }
    map = new_map;
    map_index = hash;
    while (true) : (map_index += 1) {
        map_index &= new_map_mask;
        if (map.entries[map_index].value == .none) break;
    }
    map.entries[map_index] = .{
        .value = @enumFromInt(@intFromEnum(value)),
        .hash = hash,
    };
    shard.shared.string_map.release(new_map);
    strings.appendAssumeCapacity(.{0});
    return value;
}

pub fn getString(ip: *InternPool, key: []const u8) OptionalNullTerminatedString {
    const full_hash = Hash.hash(0, key);
    const hash: u32 = @truncate(full_hash >> 32);
    const shard = &ip.shards[@intCast(full_hash & (ip.shards.len - 1))];
    const map = shard.shared.string_map.acquire();
    const map_mask = map.header().mask();
    var map_index = hash;
    while (true) : (map_index += 1) {
        map_index &= map_mask;
        const entry = map.at(map_index);
        const index = entry.acquire().unwrap() orelse return null;
        if (entry.hash != hash) continue;
        if (index.eqlSlice(key, ip)) return index;
    }
}

pub fn typeOf(ip: *const InternPool, index: Index) Index {
    // This optimization of static keys is required so that typeOf can be called
    // on static keys that haven't been added yet during static key initialization.
    // An alternative would be to topological sort the static keys, but this would
    // mean that the range of type indices would not be dense.
    return switch (index) {
        .u0_type,
        .i0_type,
        .u1_type,
        .u8_type,
        .i8_type,
        .u16_type,
        .i16_type,
        .u29_type,
        .u32_type,
        .i32_type,
        .u64_type,
        .i64_type,
        .u80_type,
        .u128_type,
        .i128_type,
        .usize_type,
        .isize_type,
        .c_char_type,
        .c_short_type,
        .c_ushort_type,
        .c_int_type,
        .c_uint_type,
        .c_long_type,
        .c_ulong_type,
        .c_longlong_type,
        .c_ulonglong_type,
        .c_longdouble_type,
        .f16_type,
        .f32_type,
        .f64_type,
        .f80_type,
        .f128_type,
        .anyopaque_type,
        .bool_type,
        .void_type,
        .type_type,
        .anyerror_type,
        .comptime_int_type,
        .comptime_float_type,
        .noreturn_type,
        .anyframe_type,
        .null_type,
        .undefined_type,
        .enum_literal_type,
        .atomic_order_type,
        .atomic_rmw_op_type,
        .calling_convention_type,
        .address_space_type,
        .float_mode_type,
        .reduce_op_type,
        .call_modifier_type,
        .prefetch_options_type,
        .export_options_type,
        .extern_options_type,
        .type_info_type,
        .manyptr_u8_type,
        .manyptr_const_u8_type,
        .manyptr_const_u8_sentinel_0_type,
        .single_const_pointer_to_comptime_int_type,
        .slice_const_u8_type,
        .slice_const_u8_sentinel_0_type,
        .optional_noreturn_type,
        .anyerror_void_error_union_type,
        .adhoc_inferred_error_set_type,
        .generic_poison_type,
        .empty_struct_type,
        => .type_type,

        .undef => .undefined_type,
        .zero, .one, .negative_one => .comptime_int_type,
        .zero_usize, .one_usize => .usize_type,
        .zero_u8, .one_u8, .four_u8 => .u8_type,
        .calling_convention_c, .calling_convention_inline => .calling_convention_type,
        .void_value => .void_type,
        .unreachable_value => .noreturn_type,
        .null_value => .null_type,
        .bool_true, .bool_false => .bool_type,
        .empty_struct => .empty_struct_type,
        .generic_poison => .generic_poison_type,

        // This optimization on tags is needed so that indexToKey can call
        // typeOf without being recursive.
        _ => {
            const unwrapped_index = index.unwrap(ip);
            const item = unwrapped_index.getItem(ip);
            return switch (item.tag) {
                .removed => unreachable,

                .type_int_signed,
                .type_int_unsigned,
                .type_array_big,
                .type_array_small,
                .type_vector,
                .type_pointer,
                .type_slice,
                .type_optional,
                .type_anyframe,
                .type_error_union,
                .type_anyerror_union,
                .type_error_set,
                .type_inferred_error_set,
                .type_enum_auto,
                .type_enum_explicit,
                .type_enum_nonexhaustive,
                .type_opaque,
                .type_struct,
                .type_struct_anon,
                .type_struct_packed,
                .type_struct_packed_inits,
                .type_tuple_anon,
                .type_union,
                .type_function,
                => .type_type,

                .undef,
                .opt_null,
                .only_possible_value,
                => @enumFromInt(item.data),

                .simple_type, .simple_value => unreachable, // handled via Index above

                inline .ptr_decl,
                .ptr_comptime_alloc,
                .ptr_anon_decl,
                .ptr_anon_decl_aligned,
                .ptr_comptime_field,
                .ptr_int,
                .ptr_eu_payload,
                .ptr_opt_payload,
                .ptr_elem,
                .ptr_field,
                .ptr_slice,
                .opt_payload,
                .error_union_payload,
                .int_small,
                .int_lazy_align,
                .int_lazy_size,
                .error_set_error,
                .error_union_error,
                .enum_tag,
                .variable,
                .extern_func,
                .func_decl,
                .func_instance,
                .func_coerced,
                .union_value,
                .bytes,
                .aggregate,
                .repeated,
                => |t| {
                    const extra_list = unwrapped_index.getExtra(ip);
                    return @enumFromInt(extra_list.view().items(.@"0")[item.data + std.meta.fieldIndex(t.Payload(), "ty").?]);
                },

                .int_u8 => .u8_type,
                .int_u16 => .u16_type,
                .int_u32 => .u32_type,
                .int_i32 => .i32_type,
                .int_usize => .usize_type,

                .int_comptime_int_u32,
                .int_comptime_int_i32,
                => .comptime_int_type,

                // Note these are stored in limbs data, not extra data.
                .int_positive,
                .int_negative,
                => {
                    const limbs_list = ip.getLocalShared(unwrapped_index.tid).getLimbs();
                    const int: Int = @bitCast(limbs_list.view().items(.@"0")[item.data..][0..Int.limbs_items_len].*);
                    return int.ty;
                },

                .enum_literal => .enum_literal_type,
                .float_f16 => .f16_type,
                .float_f32 => .f32_type,
                .float_f64 => .f64_type,
                .float_f80 => .f80_type,
                .float_f128 => .f128_type,

                .float_c_longdouble_f80,
                .float_c_longdouble_f128,
                => .c_longdouble_type,

                .float_comptime_float => .comptime_float_type,

                .memoized_call => unreachable,
            };
        },

        .none => unreachable,
    };
}

/// Assumes that the enum's field indexes equal its value tags.
pub fn toEnum(ip: *const InternPool, comptime E: type, i: Index) E {
    const int = ip.indexToKey(i).enum_tag.int;
    return @enumFromInt(ip.indexToKey(int).int.storage.u64);
}

pub fn aggregateTypeLen(ip: *const InternPool, ty: Index) u64 {
    return switch (ip.indexToKey(ty)) {
        .struct_type => ip.loadStructType(ty).field_types.len,
        .anon_struct_type => |anon_struct_type| anon_struct_type.types.len,
        .array_type => |array_type| array_type.len,
        .vector_type => |vector_type| vector_type.len,
        else => unreachable,
    };
}

pub fn aggregateTypeLenIncludingSentinel(ip: *const InternPool, ty: Index) u64 {
    return switch (ip.indexToKey(ty)) {
        .struct_type => ip.loadStructType(ty).field_types.len,
        .anon_struct_type => |anon_struct_type| anon_struct_type.types.len,
        .array_type => |array_type| array_type.lenIncludingSentinel(),
        .vector_type => |vector_type| vector_type.len,
        else => unreachable,
    };
}

pub fn funcTypeReturnType(ip: *const InternPool, ty: Index) Index {
    const unwrapped_ty = ty.unwrap(ip);
    const ty_extra = unwrapped_ty.getExtra(ip);
    const ty_item = unwrapped_ty.getItem(ip);
    const child_extra, const child_item = switch (ty_item.tag) {
        .type_pointer => child: {
            const child_index: Index = @enumFromInt(ty_extra.view().items(.@"0")[
                ty_item.data + std.meta.fieldIndex(Tag.TypePointer, "child").?
            ]);
            const unwrapped_child = child_index.unwrap(ip);
            break :child .{ unwrapped_child.getExtra(ip), unwrapped_child.getItem(ip) };
        },
        .type_function => .{ ty_extra, ty_item },
        else => unreachable,
    };
    assert(child_item.tag == .type_function);
    return @enumFromInt(child_extra.view().items(.@"0")[
        child_item.data + std.meta.fieldIndex(Tag.TypeFunction, "return_type").?
    ]);
}

pub fn isNoReturn(ip: *const InternPool, ty: Index) bool {
    switch (ty) {
        .noreturn_type => return true,
        else => {
            const unwrapped_ty = ty.unwrap(ip);
            const ty_item = unwrapped_ty.getItem(ip);
            return switch (ty_item.tag) {
                .type_error_set => unwrapped_ty.getExtra(ip).view().items(.@"0")[ty_item.data + std.meta.fieldIndex(Tag.ErrorSet, "names_len").?] == 0,
                else => false,
            };
        },
    }
}

pub fn isUndef(ip: *const InternPool, val: Index) bool {
    return val == .undef or val.unwrap(ip).getTag(ip) == .undef;
}

pub fn isVariable(ip: *const InternPool, val: Index) bool {
    return val.unwrap(ip).getTag(ip) == .variable;
}

pub fn getBackingDecl(ip: *const InternPool, val: Index) OptionalDeclIndex {
    var base = val;
    while (true) {
        const unwrapped_base = base.unwrap(ip);
        const base_item = unwrapped_base.getItem(ip);
        const base_extra_items = unwrapped_base.getExtra(ip).view().items(.@"0");
        switch (base_item.tag) {
            .ptr_decl => return @enumFromInt(base_extra_items[
                base_item.data + std.meta.fieldIndex(PtrDecl, "decl").?
            ]),
            inline .ptr_eu_payload,
            .ptr_opt_payload,
            .ptr_elem,
            .ptr_field,
            => |tag| base = @enumFromInt(base_extra_items[
                base_item.data + std.meta.fieldIndex(tag.Payload(), "base").?
            ]),
            .ptr_slice => base = @enumFromInt(base_extra_items[
                base_item.data + std.meta.fieldIndex(PtrSlice, "ptr").?
            ]),
            else => return .none,
        }
    }
}

pub fn getBackingAddrTag(ip: *const InternPool, val: Index) ?Key.Ptr.BaseAddr.Tag {
    var base = val;
    while (true) {
        const unwrapped_base = base.unwrap(ip);
        const base_item = unwrapped_base.getItem(ip);
        switch (base_item.tag) {
            .ptr_decl => return .decl,
            .ptr_comptime_alloc => return .comptime_alloc,
            .ptr_anon_decl,
            .ptr_anon_decl_aligned,
            => return .anon_decl,
            .ptr_comptime_field => return .comptime_field,
            .ptr_int => return .int,
            inline .ptr_eu_payload,
            .ptr_opt_payload,
            .ptr_elem,
            .ptr_field,
            => |tag| base = @enumFromInt(unwrapped_base.getExtra(ip).view().items(.@"0")[
                base_item.data + std.meta.fieldIndex(tag.Payload(), "base").?
            ]),
            inline .ptr_slice => |tag| base = @enumFromInt(unwrapped_base.getExtra(ip).view().items(.@"0")[
                base_item.data + std.meta.fieldIndex(tag.Payload(), "ptr").?
            ]),
            else => return null,
        }
    }
}

/// This is a particularly hot function, so we operate directly on encodings
/// rather than the more straightforward implementation of calling `indexToKey`.
pub fn zigTypeTagOrPoison(ip: *const InternPool, index: Index) error{GenericPoison}!std.builtin.TypeId {
    return switch (index) {
        .u0_type,
        .i0_type,
        .u1_type,
        .u8_type,
        .i8_type,
        .u16_type,
        .i16_type,
        .u29_type,
        .u32_type,
        .i32_type,
        .u64_type,
        .i64_type,
        .u80_type,
        .u128_type,
        .i128_type,
        .usize_type,
        .isize_type,
        .c_char_type,
        .c_short_type,
        .c_ushort_type,
        .c_int_type,
        .c_uint_type,
        .c_long_type,
        .c_ulong_type,
        .c_longlong_type,
        .c_ulonglong_type,
        => .Int,

        .c_longdouble_type,
        .f16_type,
        .f32_type,
        .f64_type,
        .f80_type,
        .f128_type,
        => .Float,

        .anyopaque_type => .Opaque,
        .bool_type => .Bool,
        .void_type => .Void,
        .type_type => .Type,
        .anyerror_type, .adhoc_inferred_error_set_type => .ErrorSet,
        .comptime_int_type => .ComptimeInt,
        .comptime_float_type => .ComptimeFloat,
        .noreturn_type => .NoReturn,
        .anyframe_type => .AnyFrame,
        .null_type => .Null,
        .undefined_type => .Undefined,
        .enum_literal_type => .EnumLiteral,

        .atomic_order_type,
        .atomic_rmw_op_type,
        .calling_convention_type,
        .address_space_type,
        .float_mode_type,
        .reduce_op_type,
        .call_modifier_type,
        => .Enum,

        .prefetch_options_type,
        .export_options_type,
        .extern_options_type,
        => .Struct,

        .type_info_type => .Union,

        .manyptr_u8_type,
        .manyptr_const_u8_type,
        .manyptr_const_u8_sentinel_0_type,
        .single_const_pointer_to_comptime_int_type,
        .slice_const_u8_type,
        .slice_const_u8_sentinel_0_type,
        => .Pointer,

        .optional_noreturn_type => .Optional,
        .anyerror_void_error_union_type => .ErrorUnion,
        .empty_struct_type => .Struct,

        .generic_poison_type => return error.GenericPoison,

        // values, not types
        .undef => unreachable,
        .zero => unreachable,
        .zero_usize => unreachable,
        .zero_u8 => unreachable,
        .one => unreachable,
        .one_usize => unreachable,
        .one_u8 => unreachable,
        .four_u8 => unreachable,
        .negative_one => unreachable,
        .calling_convention_c => unreachable,
        .calling_convention_inline => unreachable,
        .void_value => unreachable,
        .unreachable_value => unreachable,
        .null_value => unreachable,
        .bool_true => unreachable,
        .bool_false => unreachable,
        .empty_struct => unreachable,
        .generic_poison => unreachable,

        _ => switch (index.unwrap(ip).getTag(ip)) {
            .removed => unreachable,

            .type_int_signed,
            .type_int_unsigned,
            => .Int,

            .type_array_big,
            .type_array_small,
            => .Array,

            .type_vector => .Vector,

            .type_pointer,
            .type_slice,
            => .Pointer,

            .type_optional => .Optional,
            .type_anyframe => .AnyFrame,

            .type_error_union,
            .type_anyerror_union,
            => .ErrorUnion,

            .type_error_set,
            .type_inferred_error_set,
            => .ErrorSet,

            .type_enum_auto,
            .type_enum_explicit,
            .type_enum_nonexhaustive,
            => .Enum,

            .simple_type => unreachable, // handled via Index tag above

            .type_opaque => .Opaque,

            .type_struct,
            .type_struct_anon,
            .type_struct_packed,
            .type_struct_packed_inits,
            .type_tuple_anon,
            => .Struct,

            .type_union => .Union,

            .type_function => .Fn,

            // values, not types
            .undef,
            .simple_value,
            .ptr_decl,
            .ptr_comptime_alloc,
            .ptr_anon_decl,
            .ptr_anon_decl_aligned,
            .ptr_comptime_field,
            .ptr_int,
            .ptr_eu_payload,
            .ptr_opt_payload,
            .ptr_elem,
            .ptr_field,
            .ptr_slice,
            .opt_payload,
            .opt_null,
            .int_u8,
            .int_u16,
            .int_u32,
            .int_i32,
            .int_usize,
            .int_comptime_int_u32,
            .int_comptime_int_i32,
            .int_small,
            .int_positive,
            .int_negative,
            .int_lazy_align,
            .int_lazy_size,
            .error_set_error,
            .error_union_error,
            .error_union_payload,
            .enum_literal,
            .enum_tag,
            .float_f16,
            .float_f32,
            .float_f64,
            .float_f80,
            .float_f128,
            .float_c_longdouble_f80,
            .float_c_longdouble_f128,
            .float_comptime_float,
            .variable,
            .extern_func,
            .func_decl,
            .func_instance,
            .func_coerced,
            .only_possible_value,
            .union_value,
            .bytes,
            .aggregate,
            .repeated,
            // memoization, not types
            .memoized_call,
            => unreachable,
        },
        .none => unreachable, // special tag
    };
}

pub fn isFuncBody(ip: *const InternPool, index: Index) bool {
    return switch (index.unwrap(ip).getTag(ip)) {
        .func_decl, .func_instance, .func_coerced => true,
        else => false,
    };
}

pub fn funcAnalysis(ip: *const InternPool, index: Index) *FuncAnalysis {
    const unwrapped_index = index.unwrap(ip);
    const extra = unwrapped_index.getExtra(ip);
    const item = unwrapped_index.getItem(ip);
    const extra_index = switch (item.tag) {
        .func_decl => item.data + std.meta.fieldIndex(Tag.FuncDecl, "analysis").?,
        .func_instance => item.data + std.meta.fieldIndex(Tag.FuncInstance, "analysis").?,
        .func_coerced => {
            const extra_index = item.data + std.meta.fieldIndex(Tag.FuncCoerced, "func").?;
            const func_index: Index = @enumFromInt(extra.view().items(.@"0")[extra_index]);
            const unwrapped_func = func_index.unwrap(ip);
            const func_item = unwrapped_func.getItem(ip);
            return @ptrCast(&unwrapped_func.getExtra(ip).view().items(.@"0")[
                switch (func_item.tag) {
                    .func_decl => func_item.data + std.meta.fieldIndex(Tag.FuncDecl, "analysis").?,
                    .func_instance => func_item.data + std.meta.fieldIndex(Tag.FuncInstance, "analysis").?,
                    else => unreachable,
                }
            ]);
        },
        else => unreachable,
    };
    return @ptrCast(&extra.view().items(.@"0")[extra_index]);
}

pub fn funcHasInferredErrorSet(ip: *const InternPool, i: Index) bool {
    return funcAnalysis(ip, i).inferred_error_set;
}

pub fn funcZirBodyInst(ip: *const InternPool, index: Index) TrackedInst.Index {
    const unwrapped_index = index.unwrap(ip);
    const item = unwrapped_index.getItem(ip);
    const item_extra = unwrapped_index.getExtra(ip);
    const zir_body_inst_field_index = std.meta.fieldIndex(Tag.FuncDecl, "zir_body_inst").?;
    switch (item.tag) {
        .func_decl => return @enumFromInt(item_extra.view().items(.@"0")[item.data + zir_body_inst_field_index]),
        .func_instance => {
            const generic_owner_field_index = std.meta.fieldIndex(Tag.FuncInstance, "generic_owner").?;
            const func_decl_index: Index = @enumFromInt(item_extra.view().items(.@"0")[item.data + generic_owner_field_index]);
            const unwrapped_func_decl = func_decl_index.unwrap(ip);
            const func_decl_item = unwrapped_func_decl.getItem(ip);
            const func_decl_extra = unwrapped_func_decl.getExtra(ip);
            assert(func_decl_item.tag == .func_decl);
            return @enumFromInt(func_decl_extra.view().items(.@"0")[func_decl_item.data + zir_body_inst_field_index]);
        },
        .func_coerced => {
            const uncoerced_func_index: Index = @enumFromInt(item_extra.view().items(.@"0")[
                item.data + std.meta.fieldIndex(Tag.FuncCoerced, "func").?
            ]);
            return ip.funcZirBodyInst(uncoerced_func_index);
        },
        else => unreachable,
    }
}

pub fn iesFuncIndex(ip: *const InternPool, ies_index: Index) Index {
    const item = ies_index.unwrap(ip).getItem(ip);
    assert(item.tag == .type_inferred_error_set);
    const func_index: Index = @enumFromInt(item.data);
    switch (func_index.unwrap(ip).getTag(ip)) {
        .func_decl, .func_instance => {},
        else => unreachable, // assertion failed
    }
    return func_index;
}

/// Returns a mutable pointer to the resolved error set type of an inferred
/// error set function. The returned pointer is invalidated when anything is
/// added to `ip`.
pub fn iesResolved(ip: *const InternPool, ies_index: Index) *Index {
    const ies_item = ies_index.getItem(ip);
    assert(ies_item.tag == .type_inferred_error_set);
    return funcIesResolved(ip, ies_item.data);
}

/// Returns a mutable pointer to the resolved error set type of an inferred
/// error set function. The returned pointer is invalidated when anything is
/// added to `ip`.
pub fn funcIesResolved(ip: *const InternPool, func_index: Index) *Index {
    assert(funcHasInferredErrorSet(ip, func_index));
    const unwrapped_func = func_index.unwrap(ip);
    const func_extra = unwrapped_func.getExtra(ip);
    const func_item = unwrapped_func.getItem(ip);
    const extra_index = switch (func_item.tag) {
        .func_decl => func_item.data + @typeInfo(Tag.FuncDecl).Struct.fields.len,
        .func_instance => func_item.data + @typeInfo(Tag.FuncInstance).Struct.fields.len,
        .func_coerced => {
            const uncoerced_func_index: Index = @enumFromInt(func_extra.view().items(.@"0")[
                func_item.data + std.meta.fieldIndex(Tag.FuncCoerced, "func").?
            ]);
            const unwrapped_uncoerced_func = uncoerced_func_index.unwrap(ip);
            const uncoerced_func_item = unwrapped_uncoerced_func.getItem(ip);
            return @ptrCast(&unwrapped_uncoerced_func.getExtra(ip).view().items(.@"0")[
                switch (uncoerced_func_item.tag) {
                    .func_decl => uncoerced_func_item.data + @typeInfo(Tag.FuncDecl).Struct.fields.len,
                    .func_instance => uncoerced_func_item.data + @typeInfo(Tag.FuncInstance).Struct.fields.len,
                    else => unreachable,
                }
            ]);
        },
        else => unreachable,
    };
    return @ptrCast(&func_extra.view().items(.@"0")[extra_index]);
}

pub fn funcDeclInfo(ip: *const InternPool, index: Index) Key.Func {
    const unwrapped_index = index.unwrap(ip);
    const item = unwrapped_index.getItem(ip);
    assert(item.tag == .func_decl);
    return extraFuncDecl(unwrapped_index.tid, unwrapped_index.getExtra(ip), item.data);
}

pub fn funcDeclOwner(ip: *const InternPool, index: Index) DeclIndex {
    return funcDeclInfo(ip, index).owner_decl;
}

pub fn funcTypeParamsLen(ip: *const InternPool, index: Index) u32 {
    const unwrapped_index = index.unwrap(ip);
    const extra_list = unwrapped_index.getExtra(ip);
    const item = unwrapped_index.getItem(ip);
    assert(item.tag == .type_function);
    return extra_list.view().items(.@"0")[item.data + std.meta.fieldIndex(Tag.TypeFunction, "params_len").?];
}

pub fn unwrapCoercedFunc(ip: *const InternPool, index: Index) Index {
    const unwrapped_index = index.unwrap(ip);
    const item = unwrapped_index.getItem(ip);
    return switch (item.tag) {
        .func_coerced => @enumFromInt(unwrapped_index.getExtra(ip).view().items(.@"0")[
            item.data + std.meta.fieldIndex(Tag.FuncCoerced, "func").?
        ]),
        .func_instance, .func_decl => index,
        else => unreachable,
    };
}

/// Having resolved a builtin type to a real struct/union/enum (which is now at `resolverd_index`),
/// make `want_index` refer to this type instead. This invalidates `resolved_index`, so must be
/// called only when it is guaranteed that no reference to `resolved_index` exists.
pub fn resolveBuiltinType(
    ip: *InternPool,
    tid: Zcu.PerThread.Id,
    want_index: Index,
    resolved_index: Index,
) void {
    assert(@intFromEnum(want_index) >= @intFromEnum(Index.first_type));
    assert(@intFromEnum(want_index) <= @intFromEnum(Index.last_type));

    // Make sure the type isn't already resolved!
    assert(ip.indexToKey(want_index) == .simple_type);

    // Make sure it's the same kind of type
    assert((ip.zigTypeTagOrPoison(want_index) catch unreachable) ==
        (ip.zigTypeTagOrPoison(resolved_index) catch unreachable));

    // Copy the data
    const item = resolved_index.unwrap(ip).getItem(ip);
    const unwrapped_index = want_index.unwrap(ip);
    var items = ip.getLocalShared(unwrapped_index.tid).items.acquire().view().slice();
    items.items(.data)[unwrapped_index.index] = item.data;
    @atomicStore(Tag, &items.items(.tag)[unwrapped_index.index], item.tag, .release);
    ip.remove(tid, resolved_index);
}

pub fn anonStructFieldTypes(ip: *const InternPool, i: Index) []const Index {
    return ip.indexToKey(i).anon_struct_type.types;
}

pub fn anonStructFieldsLen(ip: *const InternPool, i: Index) u32 {
    return @intCast(ip.indexToKey(i).anon_struct_type.types.len);
}

/// Asserts the type is a struct.
pub fn structDecl(ip: *const InternPool, i: Index) OptionalDeclIndex {
    return switch (ip.indexToKey(i)) {
        .struct_type => |t| t.decl,
        else => unreachable,
    };
}

/// Returns the already-existing field with the same name, if any.
pub fn addFieldName(
    ip: *InternPool,
    extra: Local.Extra,
    names_map: MapIndex,
    names_start: u32,
    name: NullTerminatedString,
) ?u32 {
    const extra_items = extra.view().items(.@"0");
    const map = &ip.maps.items[@intFromEnum(names_map)];
    const field_index = map.count();
    const strings = extra_items[names_start..][0..field_index];
    const adapter: NullTerminatedString.Adapter = .{ .strings = @ptrCast(strings) };
    const gop = map.getOrPutAssumeCapacityAdapted(name, adapter);
    if (gop.found_existing) return @intCast(gop.index);
    extra_items[names_start + field_index] = @intFromEnum(name);
    return null;
}

/// Used only by `get` for pointer values, and mainly intended to use `Tag.ptr_anon_decl`
/// encoding instead of `Tag.ptr_anon_decl_aligned` when possible.
fn ptrsHaveSameAlignment(ip: *InternPool, a_ty: Index, a_info: Key.PtrType, b_ty: Index) bool {
    if (a_ty == b_ty) return true;
    const b_info = ip.indexToKey(b_ty).ptr_type;
    return a_info.flags.alignment == b_info.flags.alignment and
        (a_info.child == b_info.child or a_info.flags.alignment != .none);
}

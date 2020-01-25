const std = @import("std");
const Allocator = std.mem.Allocator;

const mem = std.mem;
const fmt = std.fmt;

pub const rdata = @import("dns/rdata.zig");
pub const RData = rdata.DNSRData;

pub const QuestionList = std.ArrayList(Question);
pub const ResourceList = std.ArrayList(Resource);
const InError = std.io.SliceInStream.Error;
pub const DNSDeserializer = std.io.Deserializer(.Big, .Bit, InError);
pub const Error = error{
    UnknownType,
    RDATANotSupported,
    DeserialFail,
    ParseFail,
};

/// The response code of a packet.
pub const ResponseCode = enum(u4) {
    NoError = 0,
    FmtError = 1,
    ServFail = 2,
    NameErr = 3,
    NotImpl = 4,
    Refused = 5,
};

/// Represents a DNS type.
/// Keep in mind this enum does not declare all possible DNS types.
pub const Type = enum(u16) {
    A = 1,
    NS = 2,
    MD = 3,
    MF = 4,
    CNAME = 5,
    SOA = 6,
    MB = 7,
    MG = 8,
    MR = 9,
    NULL = 10,
    WKS = 11,
    PTR = 12,
    HINFO = 13,
    MINFO = 14,
    MX = 15,
    TXT = 16,

    AAAA = 28,
    // TODO LOC = 29, (check if it's worth it. https://tools.ietf.org/html/rfc1876)
    SRV = 33,

    // those types are only valid in request packets. they may be wanted
    // later on for completeness, but for now, it's more hassle than it's worth.
    // AXFR = 252,
    // MAILB = 253,
    // MAILA = 254,
    // ANY = 255,

    // should this enum be non-exhaustive?
    // trying to get it non-exhaustive gives "TODO @tagName on non-exhaustive enum https://github.com/ziglang/zig/issues/3991"
    //_,

    /// Convert a given string to an integer representing a Type.
    pub fn fromStr(str: []const u8) !@This() {
        if (str.len > 10) return error.Overflow;

        var uppercased: [10]u8 = undefined;
        toUpper(str, uppercased[0..]);

        const type_info = @typeInfo(@This()).Enum;
        inline for (type_info.fields) |field| {
            if (mem.eql(u8, uppercased[0..str.len], field.name)) {
                return @intToEnum(@This(), field.value);
            }
        }

        return error.InvalidDnsType;
    }
};

pub const Class = enum(u16) {
    IN = 1,
    CS = 2,
    CH = 3,
    HS = 4,
    WILDCARD = 255,
};

fn toUpper(str: []const u8, out: []u8) void {
    for (str) |c, i| {
        out[i] = std.ascii.toUpper(c);
    }
}

/// Describes the header of a DNS packet.
pub const Header = packed struct {
    id: u16 = 0,
    qr_flag: bool = false,
    opcode: i4 = 0,

    aa_flag: bool = false,
    tc: bool = false,
    rd: bool = false,
    ra: bool = false,
    z: u3 = 0,
    rcode: ResponseCode = .NoError,

    /// Amount of questions in the packet.
    qdcount: u16 = 0,

    /// Amount of answers in the packet.
    ancount: u16 = 0,

    /// Amount of nameservers in the packet.
    nscount: u16 = 0,

    /// Amount of additional recordsin the packet.
    arcount: u16 = 0,
};

/// Represents a single DNS domain-name, which is a slice of strings.
///
/// The "www.google.com" friendly domain name can be represented in DNS as a
/// sequence of labels: first "www", then "google", then "com", with a length
/// prefix for all of them, ending in a null byte.
///
/// Keep in mind Name's are not singularly deserializeable, as the names
/// could be pointers to different bytes in the packet.
/// (RFC1035, section 4.1.4 Message Compression)
pub const Name = struct {
    /// The name's labels.
    labels: [][]const u8,

    /// Returns the total size in bytes of the Name as if it was sent
    /// over a socket.
    pub fn size(self: @This()) usize {
        // by default, add the null octet at the end of it
        var total_size: usize = 1;

        for (self.labels) |label| {
            // length octet + the actual label octets
            total_size += @sizeOf(u8);
            total_size += label.len * @sizeOf(u8);
        }

        return total_size;
    }

    /// Convert a Name to a human-friendly domain name.
    /// Does not add a period to the end of it.
    pub fn toStr(self: @This(), allocator: *Allocator) ![]u8 {
        return try std.mem.join(allocator, ".", self.labels);
    }

    /// Get a Name out of a domain name ("www.google.com", for example).
    pub fn fromString(allocator: *Allocator, domain: []const u8) !@This() {
        if (domain.len > 255) return error.Overflow;

        const period_count = blk: {
            var it = std.mem.separate(domain, ".");
            var count: usize = 0;
            while (it.next()) |_| count += 1;
            break :blk count;
        };
        var it = std.mem.separate(domain, ".");

        var labels: [][]const u8 = try allocator.alloc([]u8, period_count);
        var labels_idx: usize = 0;

        while (labels_idx < period_count) : (labels_idx += 1) {
            var label = it.next().?;
            labels[labels_idx] = label;
        }

        return Name{ .labels = labels[0..] };
    }

    pub fn serialize(self: @This(), serializer: var) !void {
        for (self.labels) |label| {
            std.debug.assert(label.len < 255);
            try serializer.serialize(@intCast(u8, label.len));
            for (label) |byte| {
                try serializer.serialize(byte);
            }
        }

        // null-octet for the end of labels for this name
        try serializer.serialize(@as(u8, 0));
    }

    /// Format the given DNS name.
    pub fn format(
        self: @This(),
        comptime f: []const u8,
        options: fmt.FormatOptions,
        context: var,
        comptime Errors: type,
        output: fn (@TypeOf(context), []const u8) Errors!void,
    ) Errors!void {
        if (f.len != 0) {
            @compileError("Unknown format character: '" ++ f ++ "'");
        }

        for (self.labels) |label| {
            try fmt.format(context, Errors, output, "{}.", .{label});
        }
    }
};

/// Represents a DNS question sent on the packet's question list.
pub const Question = struct {
    qname: Name,
    qtype: Type,
    qclass: Class,
};

/// Represents a single DNS resource. Appears on the answer, authority,
/// and additional lists of the packet.
pub const Resource = struct {
    name: Name,

    rr_type: Type,
    class: Class,
    ttl: i32,

    /// Use the dns.rdata module to interprete a resource's RDATA.
    opaque_rdata: []u8,

    /// Give the size, in bytes, of the binary representation of a resource.
    pub fn size(resource: @This()) usize {
        var res_size: usize = 0;

        // name for the resource
        res_size += resource.name.size();

        // rr_type, class, ttl, rdlength are 3 u16's and one u32.
        res_size += @sizeOf(u16) * 3;
        res_size += @sizeOf(u32);

        res_size += resource.opaque_rdata.len * @sizeOf(u8);

        return res_size;
    }

    pub fn serialize(self: @This(), serializer: var) !void {
        try serializer.serialize(self.name);
        try serializer.serialize(self.rr_type);
        try serializer.serialize(self.class);
        try serializer.serialize(self.ttl);

        try serializer.serialize(@intCast(u16, self.opaque_rdata.len));
        try serializer.serialize(self.opaque_rdata);
    }
};

/// Represents a Label if it is a pointer to a set of labels OR a single label.
/// Name's, by RFC1035 can appear in three ways (in binary form):
///  - As a set of labels, ending with a null byte.
///  - As a set of labels, with a pointer to another set of labels,
///     ending with null.
///  - As a pointer to another set of labels.
///
/// Recursive parsing is used to convert all pointers into proper labels.
const LabelComponent = union(enum) {
    Pointer: [][]const u8,
    Label: []u8,
};

/// Deserialize a type, but turn any error caused by it into Error.DeserialFail.
///
/// This is required because of the following facts:
///  - nonasync stack-allocated recursive functions must have explicit error sets.
///  - std.io.Deserializer's error set is not stable.
fn inDeserial(deserializer: var, comptime T: type) Error!T {
    return deserializer.deserialize(T) catch |_| {
        return Error.DeserialFail;
    };
}

/// Represents a full DNS packet, including all conversion to and from binary.
/// This struct supports the io.Serializer and io.Deserializer interfaces.
/// The serialization of DNS packets only serializes the question list. Be
/// careful with adding things other than questions, as the header will be
/// modified, but the lists won't appear in the final result.
pub const Packet = struct {
    const Self = @This();
    allocator: *Allocator,

    raw_bytes: []const u8,

    header: Header,
    questions: QuestionList,
    answers: ResourceList,
    authority: ResourceList,
    additional: ResourceList,

    /// Initialize a Packet with an allocator (for internal parsing)
    /// and a raw_bytes slice for pointer deserialization purposes (as they
    /// point to an offset *inside* the existing DNS packet's binary)
    /// Caller owns the memory.
    pub fn init(allocator: *Allocator, raw_bytes: []const u8) Packet {
        var self = Packet{
            .header = Header{},

            // keeping the original packet bytes
            // for compression purposes
            .raw_bytes = raw_bytes,
            .allocator = allocator,

            .questions = QuestionList.init(allocator),
            .answers = ResourceList.init(allocator),
            .authority = ResourceList.init(allocator),
            .additional = ResourceList.init(allocator),
        };
        return self;
    }

    /// Return if this packet makes sense, if the headers' provided lengths
    /// match the lengths of the given packets. This is not checked when
    /// serializing.
    pub fn is_valid(self: *Self) bool {
        return (self.questions.len == self.header.qdcount and
            self.answers.len == self.header.ancount and
            self.authority.len == self.header.nscount and
            self.additional.len == self.header.arcount);
    }

    /// Serialize a ResourceList.
    fn serializeRList(
        self: Packet,
        serializer: var,
        rlist: ResourceList,
    ) !void {
        for (rlist.toSlice()) |resource| {
            try serializer.serialize(resource);
        }
    }

    pub fn serialize(self: Packet, serializer: var) !void {
        std.debug.assert(self.header.qdcount == self.questions.len);
        std.debug.assert(self.header.ancount == self.answers.len);
        std.debug.assert(self.header.nscount == self.authority.len);
        std.debug.assert(self.header.arcount == self.additional.len);

        try serializer.serialize(self.header);

        for (self.questions.toSlice()) |question| {
            try serializer.serialize(question.qname);
            try serializer.serialize(question.qtype);
            try serializer.serialize(@enumToInt(question.qclass));
        }

        try self.serializeRList(serializer, self.answers);
        try self.serializeRList(serializer, self.authority);
        try self.serializeRList(serializer, self.additional);
    }

    fn deserializePointer(
        self: *Self,
        ptr_offset_1: u8,
        deserializer: var,
    ) (Error || Allocator.Error)![][]const u8 {
        // we need to read another u8 and merge both ptr_prefix_1 and the
        // u8 we read into an u16

        // the final offset is u14, but we keep it as u16 to prevent having
        // to do too many complicated things in regards to deserializer state.
        const ptr_offset_2 = try inDeserial(deserializer, u8);

        // merge them together
        var ptr_offset: u16 = (ptr_offset_1 << 7) | ptr_offset_2;

        // set first two bits of ptr_offset to zero as they're the
        // pointer prefix bits (which are always 1, which brings problems)
        ptr_offset &= ~@as(u16, 1 << 15);
        ptr_offset &= ~@as(u16, 1 << 14);

        // we need to make a proper [][]const u8 which means
        // re-deserializing labels but using start_slice instead
        var offset_size_opt = std.mem.indexOf(u8, self.raw_bytes[ptr_offset..], "\x00");

        if (offset_size_opt) |offset_size| {
            var start_slice = self.raw_bytes[ptr_offset .. ptr_offset + (offset_size + 1)];

            var in = std.io.SliceInStream.init(start_slice);
            var in_stream = &in.stream;
            var new_deserializer = DNSDeserializer.init(in_stream);

            // the old (nonfunctional approach) a simpleDeserializeName
            // to counteract the problems with just slapping deserializeName
            // in and doing recursion. however that's problematic as pointers
            // could be pointing to other pointers.

            // because of https://github.com/ziglang/zig/issues/1006
            // and the disallowance of recursive async fns, we heap-allocate this call

            var frame = try self.allocator.create(@Frame(Packet.deserializeName));
            defer self.allocator.destroy(frame);
            frame.* = async self.deserializeName(&new_deserializer);
            var name = try await frame;

            return name.labels;
        } else {
            return Error.ParseFail;
        }
    }

    /// Deserialize the given label into a LabelComponent, which can be either
    /// A Pointer or a full Label.
    fn deserializeLabel(
        self: *Self,
        deserializer: var,
    ) (Error || Allocator.Error)!?LabelComponent {
        // check if label is a pointer, this byte will contain 11 as the starting
        // point of it
        var ptr_prefix = try inDeserial(deserializer, u8);
        if (ptr_prefix == 0) return null;

        var bit1 = (ptr_prefix & (1 << 7)) != 0;
        var bit2 = (ptr_prefix & (1 << 6)) != 0;

        if (bit1 and bit2) {
            var labels = try self.deserializePointer(ptr_prefix, deserializer);
            return LabelComponent{ .Pointer = labels };
        } else {
            // the ptr_prefix is currently encoding the label's size
            var label = try self.allocator.alloc(u8, ptr_prefix);

            // properly deserialize the slice
            var label_idx: usize = 0;
            while (label_idx < ptr_prefix) : (label_idx += 1) {
                label[label_idx] = try inDeserial(deserializer, u8);
            }

            return LabelComponent{ .Label = label };
        }

        return null;
    }

    /// Deserializes a Name, which represents a slice of slice of u8 ([][]u8)
    pub fn deserializeName(
        self: *Self,
        deserial: *DNSDeserializer,
    ) (Error || Allocator.Error)!Name {

        // Removing this causes the compiler to send a
        // 'error: recursive function cannot be async'
        if (std.io.mode == .evented) {
            _ = @frame();
        }

        // allocate empty label slice
        var deserializer = deserial;
        var labels: [][]const u8 = try self.allocator.alloc([]u8, 0);
        var labels_idx: usize = 0;

        while (true) {
            var label = try self.deserializeLabel(deserializer);

            if (label) |denulled_label| {
                labels = try self.allocator.realloc(labels, (labels_idx + 1));

                switch (denulled_label) {
                    .Pointer => |label_ptr| {
                        if (labels_idx == 0) {
                            return Name{ .labels = label_ptr };
                        } else {
                            // in here we have an existing label in the labels slice, e.g "leah",
                            // and then label_ptr points to a [][]const u8, e.g
                            // [][]const u8{"ns", "cloudflare", "com"}. we
                            // need to copy that, as a suffix, to the existing
                            // labels slice
                            for (label_ptr) |label_ptr_label, idx| {
                                labels[labels_idx] = label_ptr_label;
                                labels_idx += 1;

                                // reallocate to account for the next incoming label
                                if (idx != label_ptr.len - 1) {
                                    labels = try self.allocator.realloc(labels, (labels_idx + 1));
                                }
                            }

                            return Name{ .labels = labels };
                        }
                    },
                    .Label => |label_val| labels[labels_idx] = label_val,
                    else => unreachable,
                }
            } else {
                break;
            }

            labels_idx += 1;
        }

        return Name{ .labels = labels };
    }

    /// (almost) Deserialize an RDATA section. This only deserializes to a slice of u8.
    /// Parsing of RDATA sections are in their own dns.rdata module.
    fn deserializeRData(self: *Self, deserializer: var) ![]u8 {
        var rdata_length = try deserializer.deserialize(u16);
        var opaque_rdata = try self.allocator.alloc(u8, rdata_length);
        var i: u16 = 0;

        while (i < rdata_length) : (i += 1) {
            opaque_rdata[i] = try deserializer.deserialize(u8);
        }

        return opaque_rdata;
    }

    /// Deserialize a list of Resource which sizes are controlled by the
    /// header's given count.
    fn deserialResourceList(
        self: *Self,
        deserializer: var,
        comptime header_field: []const u8,
        rs_list: *ResourceList,
    ) !void {
        const total = @field(self.*.header, header_field);

        var i: usize = 0;
        while (i < total) : (i += 1) {
            var name = try self.deserializeName(deserializer);
            var rr_type = try deserializer.deserialize(u16);
            var class = try deserializer.deserialize(u16);
            var ttl = try deserializer.deserialize(i32);

            // rdlength and rdata are under deserializeRData
            var opaque_rdata = try self.deserializeRData(deserializer);

            var resource = Resource{
                .name = name,
                .rr_type = @intToEnum(Type, rr_type),
                .class = @intToEnum(Class, class),
                .ttl = ttl,
                .opaque_rdata = opaque_rdata,
            };

            try rs_list.append(resource);
        }
    }

    pub fn deserialize(self: *Self, deserializer: var) !void {
        self.header = try deserializer.deserialize(Header);

        // deserialize our questions, but since they contain Name,
        // the deserialization is messier than what it should be..

        var i: usize = 0;
        while (i < self.header.qdcount) {
            // question contains {name, qtype, qclass}
            var name = try self.deserializeName(deserializer);
            var qtype = try deserializer.deserialize(u16);
            var qclass = try deserializer.deserialize(u16);

            var question = Question{
                .qname = name,
                .qtype = @intToEnum(Type, qtype),
                .qclass = @intToEnum(Class, qclass),
            };

            try self.questions.append(question);
            i += 1;
        }

        try self.deserialResourceList(deserializer, "ancount", &self.answers);
        try self.deserialResourceList(deserializer, "nscount", &self.authority);
        try self.deserialResourceList(deserializer, "arcount", &self.additional);
    }

    pub fn addQuestion(self: *Self, question: Question) !void {
        self.header.qdcount += 1;
        try self.questions.append(question);
    }

    pub fn addAnswer(self: *Self, resource: Resource) !void {
        self.header.ancount += 1;
        try self.answers.append(resource);
    }

    pub fn addAuthority(self: *Self, resource: Resource) !void {
        self.header.nscount += 1;
        try self.authority.append(resource);
    }

    pub fn addAdditional(self: *Self, resource: Resource) !void {
        self.header.arcount += 1;
        try self.additional.append(resource);
    }

    fn sliceSizes(self: Self) usize {
        var pkt_size: usize = 0;

        for (self.questions.toSlice()) |question| {
            pkt_size += question.qname.size();

            // add both qtype and qclass (both u16's)
            pkt_size += @sizeOf(u16);
            pkt_size += @sizeOf(u16);
        }

        for (self.answers.toSlice()) |resource| {
            pkt_size += resource.size();
        }

        for (self.authority.toSlice()) |resource| {
            pkt_size += resource.size();
        }

        for (self.additional.toSlice()) |resource| {
            pkt_size += resource.size();
        }

        return pkt_size;
    }

    /// Returns the size in bytes of the binary representation of the packet.
    pub fn size(self: Self) usize {
        return @sizeOf(Header) + self.sliceSizes();
    }
};

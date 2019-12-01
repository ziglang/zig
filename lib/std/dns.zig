const std = @import("std");
const Allocator = std.mem.Allocator;

// TODO rename to Packet, Resource, Question, Header

pub const QuestionList = std.ArrayList(Question);
pub const ResourceList = std.ArrayList(Resource);
pub const DNSDeserializer = std.io.Deserializer(.Big, .Bit, std.io.SliceInStream.Error);
pub const DNSError = error{
    UnknownDNSType,
    RDATANotSupported,
    DeserialFail,
    ParseFail,
};

/// Represents a DNS type.
pub const DNSType = enum(u16) {
    A = 1,
    NS,
    MD,
    MF,
    CNAME = 5,
    SOA,
    MB,
    MG,
    MR,
    NULL,
    WKS,
    PTR,
    HINFO,
    MINFO,
    MX,
    TXT,

    AAAA = 28,
    //LOC,
    //SRV,

    // QTYPE only, but merging under DNSType
    // for nicer API

    // TODO: add them back, maybe?
    //AXFR = 252,
    //MAILB,
    //MAILA,
    //WILDCARD,

    /// Convert a given string to an integer representing a DNSType.
    pub fn fromStr(str: []const u8) !DNSType {
        if (str.len > 10) return error.Overflow;

        var uppercased: [10]u8 = [_]u8{0} ** 16;
        toUpper(str, uppercased[0..]);

        var to_compare: [10]u8 = undefined;
        const type_info = @typeInfo(DNSType).Enum;

        inline for (type_info.fields) |field| {
            std.mem.copy(u8, to_compare[0..], field.name);

            // we have to secureZero here because a previous comparison
            // might have used those zero bytes for itself.
            std.mem.secureZero(u8, to_compare[field.name.len..]);

            if (std.mem.eql(u8, uppercased, to_compare)) {
                return @intToEnum(DNSType, field.value);
            }
        }

        return error.InvalidType;
    }
};

pub const DNSClass = enum(u16) {
    IN = 1,
    CS,
    CH,
    HS,
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
    rcode: u4 = 0,

    qdcount: u16 = 0,
    ancount: u16 = 0,
    nscount: u16 = 0,
    arcount: u16 = 0,

    /// Returns a "human-friendly" representation of the header for
    /// debugging purposes
    pub fn repr(self: *Header) ![]u8 {
        var buf: [1024]u8 = undefined;
        return std.fmt.bufPrint(
            &buf,
            "Header<{},{},{},{},{},{},{},{},{},{},{},{},{}>",
            self.id,
            self.qr_flag,
            self.opcode,
            self.aa_flag,
            self.tc,
            self.rd,
            self.ra,
            self.z,
            self.rcode,
            self.qdcount,
            self.ancount,
            self.nscount,
            self.arcount,
        );
    }
};

/// Represents a single DNS domain-name, which is a slice of strings. The
/// "www.google.com" friendly domain name would be represented in DNS as a
/// sequence of labels: first "www", then "google", then "com", with a length
/// prefix for all of them, ending in a null byte.
///
/// Due to DNS pointers, it becomes easier to process [][]const u8 instead of
/// []u8 or []const u8 as you can merge things easily internally.
pub const DNSName = struct {
    labels: [][]const u8,

    /// Returns the total size in bytes of the DNSName as if it was sent
    /// over a socket.
    pub fn size(self: *const @This()) usize {
        // by default, add the null octet at the end of it
        var size: usize = 1;

        for (self.labels) |label| {
            // length octet + the actual label octets
            size += @sizeOf(u8);
            size += label.len * @sizeOf(u8);
        }

        return size;
    }

    /// Convert a DNSName to a human-friendly domain name.
    /// Does not add a period to the end of it.
    pub fn toStr(self: *const @This(), allocator: *Allocator) ![]u8 {
        return try std.mem.join(allocator, ".", self.labels);
    }

    /// Get a DNSName out of a domain name ("www.google.com", for example).
    pub fn fromString(allocator: *Allocator, domain: []const u8) !@This() {
        if (domain.len > 255) return error.Overflow;

        var period_count = splitCount(domain, '.');
        var labels: [][]const u8 = try allocator.alloc([]u8, period_count);

        var it = std.mem.separate(domain, ".");
        var labels_idx: usize = 0;

        while (labels_idx < period_count) : (labels_idx += 1) {
            var label = it.next().?;
            labels[labels_idx] = label;
        }

        return DNSName{ .labels = labels[0..] };
    }
};

/// Return the amount of elements as if they were split by `delim`.
fn splitCount(data: []const u8, delim: u8) usize {
    // TODO maybe some std.mem.count function?
    var size: usize = 0;

    for (data) |byte| {
        if (byte == delim) size += 1;
    }

    size += 1;

    return size;
}

/// Represents a DNS question sent on the packet's question list.
pub const Question = struct {
    qname: DNSName,
    qtype: DNSType,
    qclass: DNSClass,
};

/// Represents any RDATA information. This is opaque (as a []u8) because RDATA
/// is very different than parsing the packet, as there can be many kinds of
/// DNS types, each with their own RDATA structure. Look over the rdata module
/// for parsing of OpaqueDNSRData into a nicer DNSRData.
pub const OpaqueDNSRData = struct {
    len: u16,
    value: []u8,
};

/// Represents a single DNS resource. Appears on the answer, authority,
/// and additional lists
pub const Resource = struct {
    name: DNSName,

    rr_type: DNSType,
    class: DNSClass,
    ttl: i32,

    // NOTE: this is DIFFERENT from DNSName due to rdlength being an u16,
    // instead of an u8.
    // NOTE: maybe we re-deserialize this one specifically on
    // another section of the source dedicated to specific RDATA
    rdata: OpaqueDNSRData,
};

const LabelComponentTag = enum {
    Pointer,
    Label,
};

/// Represents a Label if it is a pointer to a set of labels OR a single label.
/// DNSName's, by RFC1035 can appear in three ways (in binary form):
///  - As a set of labels, ending with a null byte.
///  - As a set of labels, with a pointer to another set of labels,
///     ending with null.
///  - As a pointer to another set of labels.
/// Recursive parsing is used to convert all pointers into proper labels
/// for nicer usage of the library.
const LabelComponent = union(LabelComponentTag) {
    Pointer: [][]const u8,
    Label: []u8,
};

/// Give the size, in bytes, of the binary representation of a resource.
fn resourceSize(resource: Resource) usize {
    var res_size: usize = 0;

    // name for the resource
    res_size += resource.name.size();

    // rr_type, class, ttl, rdlength are 3 u16's and one u32.
    res_size += @sizeOf(u16) * 3;
    res_size += @sizeOf(u32);

    // rdata
    res_size += @sizeOf(u16);
    res_size += resource.rdata.len * @sizeOf(u8);

    return res_size;
}

/// Deserialize a type, but send any error to stderr (if compiled in Debug mode)
/// This is required due to the recusive requirements of DNSName parsing as
/// explained in LabelComponent. Zig as of right now does not allow recursion
/// on functions with infferred error sets, and enforcing an error set
/// (which is the only solution) caused even more problems due to
/// io.Deserializer not giving a stable error set at compile-time.
fn inDeserial(deserializer: var, comptime T: type) DNSError!T {
    return deserializer.deserialize(T) catch |deserial_error| {
        // debugWarn("got error: {}\n", deserial_error);
        return DNSError.DeserialFail;
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
            .header = Header.init(),

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

    /// Serialize a Resource list.
    fn serializeRList(
        self: Packet,
        serializer: var,
        rlist: ResourceList,
    ) !void {
        for (rlist.toSlice()) |resource| {
            // serialize the name for the given resource
            try serializer.serialize(resource.name.labels.len);

            for (resource.name.labels) |label| {
                try serializer.serialize(label);
            }

            try serializer.serialize(resource.rr_type);
            try serializer.serialize(resource.class);
            try serializer.serialize(resource.ttl);

            try serializer.serialize(resource.rdata.len);
            try serializer.serialize(resource.rdata.value);
        }
    }

    pub fn serialize(self: Packet, serializer: var) !void {
        try serializer.serialize(self.header);

        for (self.questions.toSlice()) |question| {
            for (question.qname.labels) |label| {
                try serializer.serialize(@intCast(u8, label.len));

                for (label) |byte| {
                    try serializer.serialize(byte);
                }
            }

            // null-octet for the end of labels
            try serializer.serialize(@as(u8, 0));

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
    ) (DNSError || Allocator.Error)![][]const u8 {
        // we need to read another u8 and merge both ptr_prefix_1 and the
        // u8 we read into an u16

        // the final offset is u14, but we keep it as u16 to prevent having
        // to do too many complicated things.
        var ptr_offset_2 = try inDeserial(deserializer, u8);

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
            return DNSError.ParseFail;
        }
    }

    /// Deserialize the given label into a LabelComponent, which can be either
    /// A Pointer or a full Label.
    fn deserializeLabel(
        self: *Self,
        deserializer: var,
    ) (DNSError || Allocator.Error)!?LabelComponent {
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

    /// Deserializes a DNSName, which represents a slice of slice of u8 ([][]u8)
    pub fn deserializeName(
        self: *Self,
        deserial: *DNSDeserializer,
    ) (DNSError || Allocator.Error)!DNSName {
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
                            return DNSName{ .labels = label_ptr };
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

                            return DNSName{ .labels = labels };
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

        return DNSName{ .labels = labels };
    }

    /// Deserialises DNS RDATA information into an OpaqueDNSRData struct
    /// for later parsing/unparsing.
    fn deserializeRData(self: *Self, deserializer: var) !OpaqueDNSRData {
        var rdlength = try deserializer.deserialize(u16);
        var rdata = try self.allocator.alloc(u8, rdlength);
        var i: u16 = 0;

        while (i < rdlength) : (i += 1) {
            rdata[i] = try deserializer.deserialize(u8);
        }

        return OpaqueDNSRData{ .len = rdlength, .value = rdata };
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
            var rdata = try self.deserializeRData(deserializer);

            var resource = Resource{
                .name = name,
                .rr_type = @intToEnum(DNSType, rr_type),
                .class = @intToEnum(DNSClass, class),
                .ttl = ttl,
                .rdata = rdata,
            };

            try rs_list.append(resource);
        }
    }

    pub fn deserialize(self: *Self, deserializer: var) !void {
        self.header = try deserializer.deserialize(Header);

        // deserialize our questions, but since they contain DNSName,
        // the deserialization is messier than what it should be..

        var i: usize = 0;
        while (i < self.header.qdcount) {
            // question contains {name, qtype, qclass}
            var name = try self.deserializeName(deserializer);
            var qtype = try deserializer.deserialize(u16);
            var qclass = try deserializer.deserialize(u16);

            var question = Question{
                .qname = name,
                .qtype = @intToEnum(DNSType, qtype),
                .qclass = @intToEnum(DNSClass, qclass),
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

    fn sliceSizes(self: Self) usize {
        var pkt_size: usize = 0;

        for (self.questions.toSlice()) |question| {
            pkt_size += question.qname.size();

            // add both qtype and qclass (both u16's)
            pkt_size += @sizeOf(u16);
            pkt_size += @sizeOf(u16);
        }

        for (self.answers.toSlice()) |answer| {
            pkt_size += resourceSize(answer);
        }

        return pkt_size;
    }

    /// Returns the size in bytes of the binary representation of the packet.
    pub fn size(self: Self) usize {
        return @sizeOf(Header) + self.sliceSizes();
    }
};

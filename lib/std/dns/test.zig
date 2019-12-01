const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;
const io = std.io;
const OutError = io.SliceOutStream.Error;
const InError = io.SliceInStream.Error;

const dns = std.dns;
const Packet = dns.Packet;

test "toDNSName" {
    var arena = std.heap.ArenaAllocator.init(std.heap.direct_allocator);
    defer arena.deinit();
    const allocator = &arena.allocator;

    const domain = "www.google.com";
    var name = try dns.toDNSName(allocator, domain[0..]);
    std.debug.assert(name.labels.len == 3);
    testing.expect(std.mem.eql(u8, name.labels[0], "www"));
    testing.expect(std.mem.eql(u8, name.labels[1], "google"));
    testing.expect(std.mem.eql(u8, name.labels[2], "com"));
}

// extracted with 'dig google.com a +noedns'
const TEST_PKT_QUERY = "FEUBIAABAAAAAAAABmdvb2dsZQNjb20AAAEAAQ==";
const TEST_PKT_RESPONSE = "RM2BgAABAAEAAAAABmdvb2dsZQNjb20AAAEAAcAMAAEAAQAAASwABNg6yo4=";
const GOOGLE_COM_LABELS = [_][]const u8{ "google"[0..], "com"[0..] };

test "Packet serialize/deserialize" {
    // setup a random id packet
    var arena = std.heap.ArenaAllocator.init(std.heap.direct_allocator);
    defer arena.deinit();
    const allocator = &arena.allocator;

    var packet = dns.Packet.init(allocator, ""[0..]);

    var r = std.rand.DefaultPrng.init(std.time.timestamp());
    const random_id = r.random.int(u16);
    packet.header.id = random_id;

    // then we'll serialize it under a buffer on the stack,
    // deserialize it, and the header.id should be equal to random_id
    var buf = try serialTest(allocator, packet);

    // deserialize it
    var new_packet = try deserialTest(allocator, buf);

    testing.expectEqual(new_packet.header.id, packet.header.id);

    const fields = [_][]const u8{ "id", "opcode", "qdcount", "ancount" };

    var new_header = new_packet.header;
    var header = packet.header;

    inline for (fields) |field| {
        testing.expectEqual(@field(new_header, field), @field(header, field));
    }
}

fn decodeBase64(encoded: []const u8) ![]u8 {
    var buf: [0x10000]u8 = undefined;
    var decoded = buf[0..try std.base64.standard_decoder.calcSize(encoded)];
    try std.base64.standard_decoder.decode(decoded, encoded);
    return decoded;
}

fn expectGoogleLabels(actual: [][]const u8) void {
    for (actual) |label, idx| {
        std.testing.expectEqualSlices(u8, label, GOOGLE_COM_LABELS[idx]);
    }
}

test "deserialization of original google.com/A" {
    var arena = std.heap.ArenaAllocator.init(std.heap.direct_allocator);
    defer arena.deinit();
    const allocator = &arena.allocator;

    var decoded = try decodeBase64(TEST_PKT_QUERY[0..]);
    var pkt = try deserialTest(allocator, decoded);

    std.debug.assert(pkt.header.id == 5189);
    std.debug.assert(pkt.header.qdcount == 1);
    std.debug.assert(pkt.header.ancount == 0);
    std.debug.assert(pkt.header.nscount == 0);
    std.debug.assert(pkt.header.arcount == 0);

    const question = pkt.questions.at(0);

    expectGoogleLabels(question.qname.labels);
    std.testing.expectEqual(question.qtype, dns.DNSType.A);
    std.testing.expectEqual(question.qclass, dns.DNSClass.IN);
}

test "deserialization of reply google.com/A" {
    var arena = std.heap.ArenaAllocator.init(std.heap.direct_allocator);
    defer arena.deinit();
    const allocator = &arena.allocator;

    var decoded = try decodeBase64(TEST_PKT_RESPONSE[0..]);
    var pkt = try deserialTest(allocator, decoded);

    std.debug.assert(pkt.header.qdcount == 1);
    std.debug.assert(pkt.header.ancount == 1);
    std.debug.assert(pkt.header.nscount == 0);
    std.debug.assert(pkt.header.arcount == 0);

    var question = pkt.questions.at(0);

    expectGoogleLabels(question.qname.labels);
    testing.expectEqual(dns.DNSType.A, question.qtype);
    testing.expectEqual(dns.DNSClass.IN, question.qclass);

    var answer = pkt.answers.at(0);

    expectGoogleLabels(answer.name.labels);
    testing.expectEqual(dns.DNSType.A, answer.rr_type);
    testing.expectEqual(dns.DNSClass.IN, answer.class);
    testing.expectEqual(@as(i32, 300), answer.ttl);
}

fn encodeBase64(out: []const u8) []const u8 {
    var buffer: [0x10000]u8 = undefined;
    var encoded = buffer[0..std.base64.Base64Encoder.calcSize(out.len)];
    std.base64.standard_encoder.encode(encoded, out);

    return encoded;
}

fn encodePacket(pkt: Packet) ![]const u8 {
    var out = try serialTest(pkt.allocator, pkt);
    return encodeBase64(out);
}

test "serialization of google.com/A" {
    // setup a random id packet
    var arena = std.heap.ArenaAllocator.init(std.heap.direct_allocator);
    defer arena.deinit();
    const allocator = &arena.allocator;

    var pkt = dns.Packet.init(allocator, ""[0..]);
    pkt.header.id = 5189;
    pkt.header.rd = true;
    pkt.header.z = 2;

    var qname = try dns.toDNSName(allocator, "google.com");

    var question = dns.Question{
        .qname = qname,
        .qtype = dns.DNSType.A,
        .qclass = dns.DNSClass.IN,
    };

    try pkt.addQuestion(question);

    var encoded = try encodePacket(pkt);
    testing.expectEqualSlices(u8, encoded, TEST_PKT_QUERY);
}
fn serialTest(allocator: *Allocator, packet: Packet) ![]u8 {
    var buf = try allocator.alloc(u8, packet.size());

    var out = io.SliceOutStream.init(buf);
    var out_stream = &out.stream;
    var serializer = io.Serializer(.Big, .Bit, OutError).init(out_stream);

    try serializer.serialize(packet);
    try serializer.flush();
    return buf;
}

fn deserialTest(allocator: *Allocator, buf: []u8) !Packet {
    var in = io.SliceInStream.init(buf);
    var stream = &in.stream;
    var deserializer = dns.DNSDeserializer.init(stream);
    var pkt = Packet.init(allocator, buf);
    try deserializer.deserializeInto(&pkt);
    return pkt;
}

test "string convert to type" {
    var parsed = try dns.DNSType.fromStr("AAAA");
    testing.expectEqual(.AAAA, parsed);
}

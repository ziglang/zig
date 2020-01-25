const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;
const io = std.io;
const OutError = io.SliceOutStream.Error;
const InError = io.SliceInStream.Error;

const dns = std.dns;
const rdata = std.dns.rdata;
const Packet = dns.Packet;

test "convert domain string to dns name" {
    var arena = std.heap.ArenaAllocator.init(std.heap.direct_allocator);
    defer arena.deinit();
    const allocator = &arena.allocator;

    const domain = "www.google.com";
    var name = try dns.Name.fromString(allocator, domain[0..]);
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
    std.testing.expectEqual(question.qtype, dns.Type.A);
    std.testing.expectEqual(question.qclass, dns.Class.IN);
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
    testing.expectEqual(dns.Type.A, question.qtype);
    testing.expectEqual(dns.Class.IN, question.qclass);

    var answer = pkt.answers.at(0);

    expectGoogleLabels(answer.name.labels);
    testing.expectEqual(dns.Type.A, answer.rr_type);
    testing.expectEqual(dns.Class.IN, answer.class);
    testing.expectEqual(@as(i32, 300), answer.ttl);

    var answer_rdata = try rdata.deserializeRData(pkt, answer);
    testing.expectEqual(dns.Type.A, @as(dns.Type, answer_rdata));

    const addr = @ptrCast(*[4]u8, &answer_rdata.A.in.addr).*;
    testing.expectEqual(@as(u8, 216), addr[0]);
    testing.expectEqual(@as(u8, 58), addr[1]);
    testing.expectEqual(@as(u8, 202), addr[2]);
    testing.expectEqual(@as(u8, 142), addr[3]);
}

fn encodeBase64(buffer: []u8, out: []const u8) []const u8 {
    var encoded = buffer[0..std.base64.Base64Encoder.calcSize(out.len)];
    std.base64.standard_encoder.encode(encoded, out);

    return encoded;
}

fn encodePacket(buffer: []u8, pkt: Packet) ![]const u8 {
    var out = try serialTest(pkt.allocator, pkt);
    return encodeBase64(buffer, out);
}

test "serialization of google.com/A (question)" {
    // setup a random id packet
    var arena = std.heap.ArenaAllocator.init(std.heap.direct_allocator);
    defer arena.deinit();
    const allocator = &arena.allocator;

    var pkt = dns.Packet.init(allocator, ""[0..]);
    pkt.header.id = 5189;
    pkt.header.rd = true;
    pkt.header.z = 2;

    var qname = try dns.Name.fromString(allocator, "google.com");

    try pkt.addQuestion(dns.Question{ .qname = qname, .qtype = .A, .qclass = .IN });

    var buffer: [128]u8 = undefined;
    var encoded = try encodePacket(&buffer, pkt);
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

test "convert string to dns type" {
    var parsed = try dns.Type.fromStr("AAAA");
    testing.expectEqual(dns.Type.AAAA, parsed);
}

test "size() methods are good" {
    var arena = std.heap.ArenaAllocator.init(std.heap.direct_allocator);
    defer arena.deinit();
    const allocator = &arena.allocator;

    var name = try dns.Name.fromString(allocator, "example.com");

    // length + data + length + data + null
    testing.expectEqual(@as(usize, 1 + 7 + 1 + 3 + 1), name.size());

    var resource = dns.Resource{
        .name = name,
        .rr_type = .A,
        .class = .IN,
        .ttl = 300,
        .opaque_rdata = "",
    };

    // name + rr (2) + class (2) + ttl (4) + rdlength (2)
    testing.expectEqual(@as(usize, name.size() + 10 + resource.opaque_rdata.len), resource.size());
}

// This is a known packet generated by zigdig. It would be welcome to have it
// tested in other libraries.
const SERIALIZED_PKT = "FEUBIAAAAAEAAAAABmdvb2dsZQNjb20AAAEAAQAAASwABAEAAH8=";

test "rdata serialization" {
    var arena = std.heap.ArenaAllocator.init(std.heap.direct_allocator);
    defer arena.deinit();
    const allocator = &arena.allocator;

    var pkt = dns.Packet.init(allocator, ""[0..]);
    pkt.header.id = 5189;
    pkt.header.rd = true;
    pkt.header.z = 2;

    var name = try dns.Name.fromString(allocator, "google.com");
    var pkt_rdata = dns.rdata.DNSRData{
        .A = try std.net.Address.parseIp4("127.0.0.1", 0),
    };

    var rdata_buffer = try allocator.alloc(u8, 0x10000);
    var opaque_rdata = rdata_buffer[0..pkt_rdata.size()];
    var out = io.SliceOutStream.init(rdata_buffer);
    var out_stream = &out.stream;
    var serializer = io.Serializer(.Big, .Bit, OutError).init(out_stream);
    try rdata.serializeRData(pkt_rdata, &serializer);

    try pkt.addAnswer(dns.Resource{
        .name = name,
        .rr_type = .A,
        .class = .IN,
        .ttl = 300,
        .opaque_rdata = opaque_rdata,
    });

    var buffer: [128]u8 = undefined;
    var res = try encodePacket(&buffer, pkt);
    testing.expectEqualSlices(u8, res, SERIALIZED_PKT);
}

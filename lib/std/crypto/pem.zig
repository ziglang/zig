const std = @import("std");
const mem = std.mem;
const sort = std.sort;
const testing = std.testing;
const base64 = std.base64;
const StringHashMap = std.hash_map.StringHashMap;
const Allocator = std.mem.Allocator;

/// pem block data.
pub const Block = struct {
    /// The pem type.
    type: []const u8,
    /// Optional headers.
    headers: StringHashMap([]const u8),
    /// Decoded content of a PEM file.
    bytes: []const u8,
    allocator: Allocator,

    const Self = @This();
    
    pub fn init(allocator: Allocator) Block {
        const headers = StringHashMap([]const u8).init(allocator);
        
        return .{
            .type = "",
            .headers = headers,
            .bytes = "",
            .allocator = allocator,
        };
    }

    /// Frees any memory that was allocated during Pem decoding.
    pub fn deinit(self: *Self) void {
        var headers = self.headers;
        headers.deinit();
        
        self.allocator.free(self.bytes);
        self.* = undefined;
    }
};

// pem errors
pub const Error = error {
    NotPemData,
    PemDataEmpty,
    PemHeaderHasColon,
};

const pem_start = "\n-----BEGIN ";
const pem_end = "\n-----END ";
const pem_end_of_line = "-----";
const colon = ":";

/// Decodes pem bytes.
pub fn decode(allocator: Allocator, data: []const u8) !Block {
    var rest = data;
    
    while (true) {
        if (mem.startsWith(u8, rest, pem_start[1..])) {
            rest = rest[pem_start.len-1..];
        } else {
            const cut_data = cut(rest, pem_start);
            if (cut_data.found) {
                rest = cut_data.after;
            } else {
                return Error.NotPemData;
            }
        }
        
        const line_data = getLine(rest);
        if (!mem.endsWith(u8, line_data.line, pem_end_of_line)) {
            continue;
        }
        
        const type_line = line_data.line[0 .. line_data.line.len-pem_end_of_line.len];

        rest = line_data.rest;
        
        var p = Block.init(allocator);
        p.type = type_line;
        
        while (true) {
            if (rest.len == 0) {
                return Error.PemDataEmpty;
            }
            
            const line_data2 = getLine(rest);
            
            const cut_data = cut(line_data2.line, colon);
            if (!cut_data.found) {
                break;
            }
            
            const key = trimSpace(cut_data.before);
            const val = trimSpace(cut_data.after);
           
            try p.headers.put(key, val);
            
            rest = line_data2.rest;
        }
        
        var end_index: usize = 0; 
        var end_trailer_index: usize = 0;
        
        if (p.headers.count() == 0 and mem.startsWith(u8, rest, pem_end[1..])) {
            end_index = 0;
            end_trailer_index = pem_end.len - 1;
        } else {
            if (mem.indexOf(u8, rest, pem_end)) |val| {
                end_index = val;
                end_trailer_index = end_index + pem_end.len;
            } else {
                continue;
            }
        }
        
        var end_trailer = rest[end_trailer_index..];
        const end_trailer_len = type_line.len + pem_end_of_line.len;
        if (end_trailer.len < end_trailer_len) {
            continue;
        }

        const rest_of_end_line = end_trailer[end_trailer_len..];
        end_trailer = end_trailer[0..end_trailer_len];
        if (!mem.startsWith(u8, end_trailer, type_line) or !mem.endsWith(u8, end_trailer, pem_end_of_line)) {
            continue;
        }
        
        const line_data2 = getLine(rest_of_end_line);
        if (line_data2.line.len != 0) {
            continue;
        }
        
        const base64_data = try removeSpacesAndTabs(allocator, rest[0..end_index]);
        const base64_decode_len = try base64.standard.Decoder.calcSizeForSlice(base64_data);

        const decoded_data = try allocator.alloc(u8, base64_decode_len);
        try base64.standard.Decoder.decode(decoded_data, base64_data);

        p.bytes = decoded_data;

        return p;
    }
}

const nl = "\n";

const pem_line_length = 64;

fn appendHeader(list: *std.ArrayList(u8), k: []const u8, v: []const u8) !void {
    try list.appendSlice(k);
    try list.appendSlice(":");
    try list.appendSlice(v);
    try list.appendSlice("\n");
}

/// Encodes pem bytes.
pub fn encode(allocator: Allocator, b: Block) ![:0]u8 {
    var headers1 = (try b.headers.clone()).iterator();
    while (headers1.next()) |kv| {
        if (mem.indexOf(u8, kv.value_ptr.*, ":") != null) {
            return Error.PemHeaderHasColon;
        }
    }
    
    var buf = std.ArrayList(u8).init(allocator);
    defer buf.deinit();

    try buf.appendSlice(pem_start[1..]);

    try buf.appendSlice(b.type);
    try buf.appendSlice("-----\n");
    
    if (b.headers.count() > 0) {
        const proc_type = "Proc-Type";

        var h = try allocator.alloc([]const u8, b.headers.count());

        var has_proc_type: bool = false;
        
        var kv_i: usize = 0;

        var headers = (try b.headers.clone()).iterator();
        while (headers.next()) |kv| {
            if (mem.eql(u8, kv.key_ptr.*, proc_type)) {
                has_proc_type = true;
                continue;
            }

            h[kv_i] = kv.key_ptr.*;
            kv_i += 1;
        }

        if (has_proc_type) {
            if (b.headers.get(proc_type)) |vv| {
                try appendHeader(&buf, proc_type, vv[0..]);
            }

            h.len -= 1;
            h = h[0..];
        }

        // strings sort a to z
        sort.block([]const u8, h, {}, stringSort([]const u8));
        
        for (h) |k| {
            if (b.headers.get(k)) |val| {
                try appendHeader(&buf, k, val);
            }
        }

        try buf.appendSlice("\n");
    }

    const bytes_len = base64.standard.Encoder.calcSize(b.bytes.len);
    const buffer = try allocator.alloc(u8, bytes_len);

    const banse64_encoded = base64.standard.Encoder.encode(buffer, b.bytes);

    var idx: usize = 0;
    while (true) {
        if (banse64_encoded[idx..].len < pem_line_length) {
            try buf.appendSlice(banse64_encoded[idx..]);
            try buf.appendSlice(nl);
            break;
        } else {
            try buf.appendSlice(banse64_encoded[idx..(idx+pem_line_length)]);
            try buf.appendSlice(nl);

            idx += pem_line_length;
        }
    }

    try buf.appendSlice(pem_end[1..]);
    try buf.appendSlice(b.type);
    try buf.appendSlice("-----\n");

    return buf.toOwnedSliceSentinel(0);
}

pub fn stringSort(comptime T: type) fn (void, T, T) bool {
    return struct {
        pub fn inner(_: void, a: T, b: T) bool {
            if (a.len < b.len) {
                for (a, 0..) |aa, i| {
                    if (aa > b[i]) {
                        return false;
                    }
                }
            } else {
                for (b, 0..) |bb, j| {
                    if (bb < a[j]) {
                        return false;
                    }
                }
            }

            return true;
        }
    }.inner;
}

const GetLineData = struct {
    line: []const u8,
    rest: []const u8,
};

fn getLine(data: []const u8) GetLineData {
    var i = data.len;
    var j = i;

    if (mem.indexOf(u8, data, "\n")) |val| {
        i = val;
        j = i + 1;
        if (i > 0 and data[i-1] == '\r') {
            i -= 1;
        }
    }
    
    return .{
        .line = mem.trimRight(u8, data[0..i], " \t"), 
        .rest = data[j..],
    };
}

fn removeSpacesAndTabs(alloc: Allocator, data: []const u8) ![:0]u8 {
    var buf = std.ArrayList(u8).init(alloc);
    defer buf.deinit();
    
    var n: usize = 0;

    for (data) |b| {
        if (b == ' ' or b == '\t' or b == '\n') {
            continue;
        }
        
        try buf.append(b);
        n += 1;
    }

    return buf.toOwnedSliceSentinel(0);
}

const CutData = struct {
    before: []const u8,
    after: []const u8,
    found: bool,
};

fn cut(s: []const u8, sep: []const u8) CutData {
    const i = mem.indexOf(u8, s, sep);
    if (i) |j| {
        return .{
            .before = s[0..j],
            .after = s[j+sep.len..],
            .found = true,
        };
    }

    return .{
        .before = s,
        .after = "",
        .found = false,
    };
}

fn trimSpace(s: []const u8) []const u8 {
    var start: usize = 0;
    while (start < s.len) : (start += 1) {
        if (!std.ascii.isWhitespace(s[start])) {
            break;
        }
    }
    
    var stop = s.len - 1;
    while (stop > start) : (stop -= 1) {
        if (!std.ascii.isWhitespace(s[stop])) {
            break;
        }
    }
    
    if (start == stop) {
        return "";
    }
    
    return s[start..(stop+1)];
}

pub fn base64Encode(alloc: Allocator, input: []const u8) ![]const u8 {
    const encoder = base64.standard.Encoder;
    const encode_len = encoder.calcSize(input.len);

    const buffer = try alloc.alloc(u8, encode_len);
    const res = encoder.encode(buffer, input);

    return res;
}

test "ASN.1 type CERTIFICATE" {
    const byte =
        "-----BEGIN CERTIFICATE-----\n" ++
        "MIIBmTCCAUegAwIBAgIBKjAJBgUrDgMCHQUAMBMxETAPBgNVBAMTCEF0bGFudGlz\n" ++
        "MB4XDTEyMDcwOTAzMTAzOFoXDTEzMDcwOTAzMTAzN1owEzERMA8GA1UEAxMIQXRs\n" ++
        "YW50aXMwXDANBgkqhkiG9w0BAQEFAANLADBIAkEAu+BXo+miabDIHHx+yquqzqNh\n" ++
        "Ryn/XtkJIIHVcYtHvIX+S1x5ErgMoHehycpoxbErZmVR4GCq1S2diNmRFZCRtQID\n" ++
        "AQABo4GJMIGGMAwGA1UdEwEB/wQCMAAwIAYDVR0EAQH/BBYwFDAOMAwGCisGAQQB\n" ++
        "gjcCARUDAgeAMB0GA1UdJQQWMBQGCCsGAQUFBwMCBggrBgEFBQcDAzA1BgNVHQEE\n" ++
        "LjAsgBA0jOnSSuIHYmnVryHAdywMoRUwEzERMA8GA1UEAxMIQXRsYW50aXOCASow\n" ++
        "CQYFKw4DAh0FAANBAKi6HRBaNEL5R0n56nvfclQNaXiDT174uf+lojzA4lhVInc0\n" ++
        "ILwpnZ1izL4MlI9eCSHhVQBHEp2uQdXJB+d5Byg=\n" ++
        "-----END CERTIFICATE-----\n";

    // const alloc = testing.allocator;
    const alloc = std.heap.page_allocator;
 
    var pem = try decode(alloc, byte);
    defer pem.deinit();

    try testing.expectFmt("CERTIFICATE", "{s}", .{pem.type});
    try testing.expect(pem.bytes.len > 0);

    const check = 
        "MIIBmTCCAUegAwIBAgIBKjAJBgUrDgMCHQUAMBMxETAPBgNVBAMTCEF0bGFudGlz" ++
        "MB4XDTEyMDcwOTAzMTAzOFoXDTEzMDcwOTAzMTAzN1owEzERMA8GA1UEAxMIQXRs" ++
        "YW50aXMwXDANBgkqhkiG9w0BAQEFAANLADBIAkEAu+BXo+miabDIHHx+yquqzqNh" ++
        "Ryn/XtkJIIHVcYtHvIX+S1x5ErgMoHehycpoxbErZmVR4GCq1S2diNmRFZCRtQID" ++
        "AQABo4GJMIGGMAwGA1UdEwEB/wQCMAAwIAYDVR0EAQH/BBYwFDAOMAwGCisGAQQB" ++
        "gjcCARUDAgeAMB0GA1UdJQQWMBQGCCsGAQUFBwMCBggrBgEFBQcDAzA1BgNVHQEE" ++
        "LjAsgBA0jOnSSuIHYmnVryHAdywMoRUwEzERMA8GA1UEAxMIQXRsYW50aXOCASow" ++
        "CQYFKw4DAh0FAANBAKi6HRBaNEL5R0n56nvfclQNaXiDT174uf+lojzA4lhVInc0" ++
        "ILwpnZ1izL4MlI9eCSHhVQBHEp2uQdXJB+d5Byg=";

    try testing.expectEqualStrings(check, try base64Encode(alloc, pem.bytes));
}

test "ASN.1 type CERTIFICATE + Explanatory Text" {
    const byte =
        "Subject: CN=Atlantis\n" ++
        "Issuer: CN=Atlantis\n" ++
        "Validity: from 7/9/2012 3:10:38 AM UTC to 7/9/2013 3:10:37 AM UTC\n" ++
        "-----BEGIN CERTIFICATE-----\n" ++
        "MIIBmTCCAUegAwIBAgIBKjAJBgUrDgMCHQUAMBMxETAPBgNVBAMTCEF0bGFudGlz\n" ++
        "MB4XDTEyMDcwOTAzMTAzOFoXDTEzMDcwOTAzMTAzN1owEzERMA8GA1UEAxMIQXRs\n" ++
        "YW50aXMwXDANBgkqhkiG9w0BAQEFAANLADBIAkEAu+BXo+miabDIHHx+yquqzqNh\n" ++
        "Ryn/XtkJIIHVcYtHvIX+S1x5ErgMoHehycpoxbErZmVR4GCq1S2diNmRFZCRtQID\n" ++
        "AQABo4GJMIGGMAwGA1UdEwEB/wQCMAAwIAYDVR0EAQH/BBYwFDAOMAwGCisGAQQB\n" ++
        "gjcCARUDAgeAMB0GA1UdJQQWMBQGCCsGAQUFBwMCBggrBgEFBQcDAzA1BgNVHQEE\n" ++
        "LjAsgBA0jOnSSuIHYmnVryHAdywMoRUwEzERMA8GA1UEAxMIQXRsYW50aXOCASow\n" ++
        "CQYFKw4DAh0FAANBAKi6HRBaNEL5R0n56nvfclQNaXiDT174uf+lojzA4lhVInc0\n" ++
        "ILwpnZ1izL4MlI9eCSHhVQBHEp2uQdXJB+d5Byg=\n" ++
        "-----END CERTIFICATE-----\n";

    const alloc = std.heap.page_allocator;
    var pem = try decode(alloc, byte);
    defer pem.deinit();

    try testing.expectFmt("CERTIFICATE", "{s}", .{pem.type});
    try testing.expect(pem.bytes.len > 0);

    const check = 
        "MIIBmTCCAUegAwIBAgIBKjAJBgUrDgMCHQUAMBMxETAPBgNVBAMTCEF0bGFudGlz" ++
        "MB4XDTEyMDcwOTAzMTAzOFoXDTEzMDcwOTAzMTAzN1owEzERMA8GA1UEAxMIQXRs" ++
        "YW50aXMwXDANBgkqhkiG9w0BAQEFAANLADBIAkEAu+BXo+miabDIHHx+yquqzqNh" ++
        "Ryn/XtkJIIHVcYtHvIX+S1x5ErgMoHehycpoxbErZmVR4GCq1S2diNmRFZCRtQID" ++
        "AQABo4GJMIGGMAwGA1UdEwEB/wQCMAAwIAYDVR0EAQH/BBYwFDAOMAwGCisGAQQB" ++
        "gjcCARUDAgeAMB0GA1UdJQQWMBQGCCsGAQUFBwMCBggrBgEFBQcDAzA1BgNVHQEE" ++
        "LjAsgBA0jOnSSuIHYmnVryHAdywMoRUwEzERMA8GA1UEAxMIQXRsYW50aXOCASow" ++
        "CQYFKw4DAh0FAANBAKi6HRBaNEL5R0n56nvfclQNaXiDT174uf+lojzA4lhVInc0" ++
        "ILwpnZ1izL4MlI9eCSHhVQBHEp2uQdXJB+d5Byg=";

    try testing.expectEqualStrings(check, try base64Encode(alloc, pem.bytes));
}

test "ASN.1 type RSA PRIVATE With headers" {
    const byte =
        "-----BEGIN RSA PRIVATE-----\n" ++
        "ID: RSA IDs\n" ++
        "ABC: thsasd   \n" ++
        "\n" ++
        "MIIBmTCCAUegAwIBAgIBKjAJBgUrDgMCHQUAMBMxETAPBgNVBAMTCEF0bGFudGlz\n" ++
        "MB4XDTEyMDcwOTAzMTAzOFoXDTEzMDcwOTAzMTAzN1owEzERMA8GA1UEAxMIQXRs\n" ++
        "YW50aXMwXDANBgkqhkiG9w0BAQEFAANLADBIAkEAu+BXo+miabDIHHx+yquqzqNh\n" ++
        "Ryn/XtkJIIHVcYtHvIX+S1x5ErgMoHehycpoxbErZmVR4GCq1S2diNmRFZCRtQID\n" ++
        "AQABo4GJMIGGMAwGA1UdEwEB/wQCMAAwIAYDVR0EAQH/BBYwFDAOMAwGCisGAQQB\n" ++
        "gjcCARUDAgeAMB0GA1UdJQQWMBQGCCsGAQUFBwMCBggrBgEFBQcDAzA1BgNVHQEE\n" ++
        "LjAsgBA0jOnSSuIHYmnVryHAdywMoRUwEzERMA8GA1UEAxMIQXRsYW50aXOCASow\n" ++
        "CQYFKw4DAh0FAANBAKi6HRBaNEL5R0n56nvfclQNaXiDT174uf+lojzA4lhVInc0\n" ++
        "ILwpnZ1izL4MlI9eCSHhVQBHEp2uQdXJB+d5Byg=\n" ++
        "-----END RSA PRIVATE-----\n";

    const alloc = std.heap.page_allocator;
    var pem = try decode(alloc, byte);
    defer pem.deinit();

    try testing.expectFmt("RSA PRIVATE", "{s}", .{pem.type});
    try testing.expect(pem.bytes.len > 0);

    const header_1 = pem.headers.get("ID").?;
    const header_2 = pem.headers.get("ABC").?;
    try testing.expectFmt("RSA IDs", "{s}", .{header_1});
    try testing.expectFmt("thsasd", "{s}", .{header_2});

    const check = 
        "MIIBmTCCAUegAwIBAgIBKjAJBgUrDgMCHQUAMBMxETAPBgNVBAMTCEF0bGFudGlz" ++
        "MB4XDTEyMDcwOTAzMTAzOFoXDTEzMDcwOTAzMTAzN1owEzERMA8GA1UEAxMIQXRs" ++
        "YW50aXMwXDANBgkqhkiG9w0BAQEFAANLADBIAkEAu+BXo+miabDIHHx+yquqzqNh" ++
        "Ryn/XtkJIIHVcYtHvIX+S1x5ErgMoHehycpoxbErZmVR4GCq1S2diNmRFZCRtQID" ++
        "AQABo4GJMIGGMAwGA1UdEwEB/wQCMAAwIAYDVR0EAQH/BBYwFDAOMAwGCisGAQQB" ++
        "gjcCARUDAgeAMB0GA1UdJQQWMBQGCCsGAQUFBwMCBggrBgEFBQcDAzA1BgNVHQEE" ++
        "LjAsgBA0jOnSSuIHYmnVryHAdywMoRUwEzERMA8GA1UEAxMIQXRsYW50aXOCASow" ++
        "CQYFKw4DAh0FAANBAKi6HRBaNEL5R0n56nvfclQNaXiDT174uf+lojzA4lhVInc0" ++
        "ILwpnZ1izL4MlI9eCSHhVQBHEp2uQdXJB+d5Byg=";

    try testing.expectEqualStrings(check, try base64Encode(alloc, pem.bytes));
}

test "encode pem bin" {
    const alloc = std.heap.page_allocator;
    
    var pp = Block.init(alloc);
    pp.type = "RSA PRIVATE";
    try pp.headers.put("TTTYYY", "dghW66666");
    try pp.headers.put("Proc-Type", "4,Encond");
    pp.bytes = "pem bytes";

    const allocator = std.heap.page_allocator;
    const encoded_pem = try encode(allocator, pp);

    const check =
        \\-----BEGIN RSA PRIVATE-----
        \\Proc-Type:4,Encond
        \\TTTYYY:dghW66666
        \\
        \\cGVtIGJ5dGVz
        \\-----END RSA PRIVATE-----
        \\
    ;

    try testing.expectFmt(check, "{s}", .{encoded_pem});

    const alloc2 = std.heap.page_allocator;
    var pem = try decode(alloc2, encoded_pem);
    defer pem.deinit();

    try testing.expectFmt("RSA PRIVATE", "{s}", .{pem.type});
    try testing.expect(pem.bytes.len > 0);
    try testing.expectFmt("pem bytes", "{s}", .{pem.bytes});

    const header_1 = pem.headers.get("Proc-Type").?;
    const header_2 = pem.headers.get("TTTYYY").?;
    try testing.expectFmt("4,Encond", "{s}", .{header_1});
    try testing.expectFmt("dghW66666", "{s}", .{header_2});
    
}


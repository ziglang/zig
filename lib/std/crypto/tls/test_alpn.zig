const std = @import("std");
const testing = std.testing;
const tls = std.crypto.tls;

test "ALPN extension in ClientHello" {
    // Test that ALPN extension is properly encoded in ClientHello
    _ = testing.allocator;
    
    // Create a mock reader/writer for testing
    var read_buffer: [16384]u8 = undefined;
    var write_buffer: [16384]u8 = undefined;
    
    var read_stream = std.io.fixedBufferStream(&read_buffer);
    var write_stream = std.io.fixedBufferStream(&write_buffer);
    
    const reader = read_stream.reader();
    const writer = write_stream.writer();
    
    // Create options with ALPN
    const alpn_protocols = [_][]const u8{ "h2", "http/1.1" };
    const options = tls.Client.Options{
        .host = .{ .explicit = "example.com" },
        .ca = .no_verification,
        .alpn_protocols = &alpn_protocols,
        .read_buffer = &read_buffer,
        .write_buffer = &write_buffer,
    };
    
    // The init will fail because we don't have a real server response,
    // but we can check that the ALPN extension was sent
    _ = tls.Client.init(&reader, &writer, options) catch |err| {
        // Expected to fail with read error since we have no server
        try testing.expect(err == error.ReadFailed);
    };
    
    // Check that ClientHello was written with ALPN extension
    const written = write_stream.getWritten();
    
    // Look for ALPN extension type (0x00 0x10)
    var found_alpn = false;
    for (written, 0..) |byte, i| {
        if (i + 1 < written.len and byte == 0x00 and written[i + 1] == 0x10) {
            found_alpn = true;
            
            // Verify the ALPN content follows
            if (i + 6 < written.len) {
                // Extension length (2 bytes)
                const ext_len = (@as(u16, written[i + 2]) << 8) | written[i + 3];
                try testing.expect(ext_len > 0);
                
                // Protocol list length (2 bytes)
                const list_len = (@as(u16, written[i + 4]) << 8) | written[i + 5];
                try testing.expect(list_len > 0);
                
                // First protocol should be "h2" (length 2)
                if (i + 7 < written.len) {
                    const first_proto_len = written[i + 6];
                    try testing.expectEqual(@as(u8, 2), first_proto_len);
                    
                    // Check "h2"
                    if (i + 9 < written.len) {
                        try testing.expectEqual(@as(u8, 'h'), written[i + 7]);
                        try testing.expectEqual(@as(u8, '2'), written[i + 8]);
                    }
                }
            }
            break;
        }
    }
    
    try testing.expect(found_alpn);
}

test "ALPN negotiation result" {
    // Test that negotiated ALPN protocol is properly stored
    // This would require a mock server response, which is complex
    // For now, we just verify the field exists and can be accessed
    
    _ = testing.allocator;
    const client: tls.Client = undefined;
    
    // Verify the negotiated_alpn field exists and is accessible
    const alpn = client.negotiated_alpn;
    try testing.expect(alpn == null); // Should be null by default
}
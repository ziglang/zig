//!
//! this is a port of https://go.dev/src/archive/tar/reader_test.go
//!
const std = @import("std");
const testing = std.testing;
const mem = std.mem;
const tar = std.tar;
const FormatSet = tar.FormatSet;
const unixTime = tar.unixTime;
const FileType = tar.FileType;
const Header = tar.Header;
const builtin = @import("builtin");
const test_common = @import("test_common.zig");

const str_long_x10 = "long" ** 10;
const one_to_nine_slash_x30 = "123456789/" ** 30;
const talloc = std.testing.allocator;

const TestCase = struct {
    file: []const u8, // Test input file
    headers: []const Header = &.{}, // Expected headers
    chksums: []const []const u8 = &.{}, // MD5 checksum of files, empty if not checked
    err: ?anyerror = null, // Expected error to occur
    // TODO remove this field when no more test cases are skipped
    skip: bool = false, // Wether to skip test case
};

test "std.tar validate testdata headers" {
    // skip due to 'incorrect alignment', maybe the same as
    // https://github.com/ziglang/zig/issues/14036
    if (builtin.os.tag == .windows and builtin.mode == .Debug)
        return error.SkipZigTest;

    const test_cases = comptime [_]TestCase{
        .{
            .file = "gnu.tar",
            .headers = &.{ .{
                .name = "small.txt",
                .mode = 0o640,
                .uid = 73025,
                .gid = 5000,
                .size = 5,
                .mtime = unixTime(1244428340, 0),
                .type = .normal,
                .uname = "dsymonds",
                .gname = "eng",
                .fmt = FormatSet.initOne(.gnu),
            }, .{
                .name = "small2.txt",
                .mode = 0o640,
                .uid = 73025,
                .gid = 5000,
                .size = 11,
                .mtime = unixTime(1244436044, 0),
                .type = .normal,
                .uname = "dsymonds",
                .gname = "eng",
                .fmt = FormatSet.initOne(.gnu),
            } },
            .chksums = &.{
                "e38b27eaccb4391bdec553a7f3ae6b2f",
                "c65bd2e50a56a2138bf1716f2fd56fe9",
            },
        },
        .{
            .skip = true,
            .file = "sparse-formats.tar",
            .headers = &.{ .{
                .name = "sparse-gnu",
                .mode = 420,
                .uid = 1000,
                .gid = 1000,
                .size = 200,
                .mtime = unixTime(1392395740, 0),
                .type = @intToEnum(FileType, 0x53),
                .linkname = "",
                .uname = "david",
                .gname = "david",
                .dev_major = 0,
                .dev_minor = 0,
                .fmt = FormatSet.initOne(.gnu),
            }, .{
                .name = "sparse-posix-0.0",
                .mode = 420,
                .uid = 1000,
                .gid = 1000,
                .size = 200,
                .mtime = unixTime(1392342187, 0),
                .type = @intToEnum(FileType, 0x30),
                .linkname = "",
                .uname = "david",
                .gname = "david",
                .dev_major = 0,
                .dev_minor = 0,
                .pax_recs = &.{
                    "GNU.sparse.size",      "200",
                    "GNU.sparse.numblocks", "95",
                    "GNU.sparse.map",       "1,1,3,1,5,1,7,1,9,1,11,1,13,1,15,1,17,1,19,1,21,1,23,1,25,1,27,1,29,1,31,1,33,1,35,1,37,1,39,1,41,1,43,1,45,1,47,1,49,1,51,1,53,1,55,1,57,1,59,1,61,1,63,1,65,1,67,1,69,1,71,1,73,1,75,1,77,1,79,1,81,1,83,1,85,1,87,1,89,1,91,1,93,1,95,1,97,1,99,1,101,1,103,1,105,1,107,1,109,1,111,1,113,1,115,1,117,1,119,1,121,1,123,1,125,1,127,1,129,1,131,1,133,1,135,1,137,1,139,1,141,1,143,1,145,1,147,1,149,1,151,1,153,1,155,1,157,1,159,1,161,1,163,1,165,1,167,1,169,1,171,1,173,1,175,1,177,1,179,1,181,1,183,1,185,1,187,1,189,1",
                },
                .fmt = FormatSet.initOne(.pax),
            }, .{
                .name = "sparse-posix-0.1",
                .mode = 420,
                .uid = 1000,
                .gid = 1000,
                .size = 200,
                .mtime = unixTime(1392340456, 0),
                .type = @intToEnum(FileType, 0x30),
                .linkname = "",
                .uname = "david",
                .gname = "david",
                .dev_major = 0,
                .dev_minor = 0,
                .pax_recs = &.{
                    "GNU.sparse.size",      "200",
                    "GNU.sparse.numblocks", "95",
                    "GNU.sparse.map",       "1,1,3,1,5,1,7,1,9,1,11,1,13,1,15,1,17,1,19,1,21,1,23,1,25,1,27,1,29,1,31,1,33,1,35,1,37,1,39,1,41,1,43,1,45,1,47,1,49,1,51,1,53,1,55,1,57,1,59,1,61,1,63,1,65,1,67,1,69,1,71,1,73,1,75,1,77,1,79,1,81,1,83,1,85,1,87,1,89,1,91,1,93,1,95,1,97,1,99,1,101,1,103,1,105,1,107,1,109,1,111,1,113,1,115,1,117,1,119,1,121,1,123,1,125,1,127,1,129,1,131,1,133,1,135,1,137,1,139,1,141,1,143,1,145,1,147,1,149,1,151,1,153,1,155,1,157,1,159,1,161,1,163,1,165,1,167,1,169,1,171,1,173,1,175,1,177,1,179,1,181,1,183,1,185,1,187,1,189,1",
                    "GNU.sparse.name",      "sparse-posix-0.1",
                },
                .fmt = FormatSet.initOne(.pax),
            }, .{
                .name = "sparse-posix-1.0",
                .mode = 420,
                .uid = 1000,
                .gid = 1000,
                .size = 200,
                .mtime = unixTime(1392337404, 0),
                .type = @intToEnum(FileType, 0x30),
                .linkname = "",
                .uname = "david",
                .gname = "david",
                .dev_major = 0,
                .dev_minor = 0,
                .pax_recs = &.{
                    "GNU.sparse.major",    "1",
                    "GNU.sparse.minor",    "0",
                    "GNU.sparse.realsize", "200",
                    "GNU.sparse.name",     "sparse-posix-1.0",
                },
                .fmt = FormatSet.initOne(.pax),
            }, .{
                .name = "end",
                .mode = 420,
                .uid = 1000,
                .gid = 1000,
                .size = 4,
                .mtime = unixTime(1392398319, 0),
                .type = @intToEnum(FileType, 0x30),
                .linkname = "",
                .uname = "david",
                .gname = "david",
                .dev_major = 0,
                .dev_minor = 0,
                .fmt = FormatSet.initOne(.gnu),
            } },
            .chksums = &.{
                "6f53234398c2449fe67c1812d993012f",
                "6f53234398c2449fe67c1812d993012f",
                "6f53234398c2449fe67c1812d993012f",
                "6f53234398c2449fe67c1812d993012f",
                "b0061974914468de549a2af8ced10316",
            },
        },
        .{
            .file = "star.tar",
            .headers = &.{ .{
                .name = "small.txt",
                .mode = 0o640,
                .uid = 73025,
                .gid = 5000,
                .size = 5,
                .mtime = unixTime(1244592783, 0),
                .type = .normal,
                .uname = "dsymonds",
                .gname = "eng",
                .atime = unixTime(1244592783, 0),
                .ctime = unixTime(1244592783, 0),
            }, .{
                .name = "small2.txt",
                .mode = 0o640,
                .uid = 73025,
                .gid = 5000,
                .size = 11,
                .mtime = unixTime(1244592783, 0),
                .type = .normal,
                .uname = "dsymonds",
                .gname = "eng",
                .atime = unixTime(1244592783, 0),
                .ctime = unixTime(1244592783, 0),
            } },
        },
        .{
            .file = "v7.tar",
            .headers = &.{ .{
                .name = "small.txt",
                .mode = 0o444,
                .uid = 73025,
                .gid = 5000,
                .size = 5,
                .mtime = unixTime(1244593104, 0),
                .type = .normal,
            }, .{
                .name = "small2.txt",
                .mode = 0o444,
                .uid = 73025,
                .gid = 5000,
                .size = 11,
                .mtime = unixTime(1244593104, 0),
                .type = .normal,
            } },
        },
        .{
            .file = "pax.tar",
            .headers = &.{ .{
                .name = "a/123456789101112131415161718192021222324252627282930313233343536373839404142434445464748495051525354555657585960616263646566676869707172737475767778798081828384858687888990919293949596979899100",
                .mode = 0o664,
                .uid = 1000,
                .gid = 1000,
                .uname = "shane",
                .gname = "shane",
                .size = 7,
                .mtime = unixTime(1350244992, 23960108),
                .ctime = unixTime(1350244992, 23960108),
                .atime = unixTime(1350244992, 23960108),
                .type = .normal,
                .pax_recs = &.{
                    "path",  "a/123456789101112131415161718192021222324252627282930313233343536373839404142434445464748495051525354555657585960616263646566676869707172737475767778798081828384858687888990919293949596979899100",
                    "mtime", "1350244992.023960108",
                    "atime", "1350244992.023960108",
                    "ctime", "1350244992.023960108",
                },
                .fmt = FormatSet.initOne(.pax),
            }, .{
                .name = "a/b",
                .mode = 0o777,
                .uid = 1000,
                .gid = 1000,
                .uname = "shane",
                .gname = "shane",
                .size = 0,
                .mtime = unixTime(1350266320, 910238425),
                .ctime = unixTime(1350266320, 910238425),
                .atime = unixTime(1350266320, 910238425),
                .type = .symbolic_link,
                .linkname = "123456789101112131415161718192021222324252627282930313233343536373839404142434445464748495051525354555657585960616263646566676869707172737475767778798081828384858687888990919293949596979899100",
                .pax_recs = &.{
                    "linkpath", "123456789101112131415161718192021222324252627282930313233343536373839404142434445464748495051525354555657585960616263646566676869707172737475767778798081828384858687888990919293949596979899100",
                    "mtime",    "1350266320.910238425",
                    "atime",    "1350266320.910238425",
                    "ctime",    "1350266320.910238425",
                },
                .fmt = FormatSet.initOne(.pax),
            } },
        },
        .{
            .file = "pax-bad-hdr-file.tar",
            .err = error.InvalidCharacter,
        },
        .{
            .file = "pax-bad-mtime-file.tar",
            .err = error.InvalidCharacter,
        },
        .{
            .file = "pax-pos-size-file.tar",
            .headers = &.{.{
                .name = "foo",
                .mode = 0o640,
                .uid = 319973,
                .gid = 5000,
                .size = 999,
                .mtime = unixTime(1442282516, 0),
                .type = .normal,
                .uname = "joetsai",
                .gname = "eng",
                .pax_recs = &.{
                    "size", "000000000000000000000999",
                },
                .fmt = FormatSet.initOne(.pax),
            }},
            .chksums = &.{
                "0afb597b283fe61b5d4879669a350556",
            },
        },
        .{
            .file = "pax-records.tar",
            .headers = &.{.{
                .type = .normal,
                .name = "file",
                .uname = str_long_x10,
                .mtime = unixTime(0, 0),
                .pax_recs = &.{
                    "GOLANG.pkg", "tar",
                    "comment",    "Hello, 世界",
                    "uname",      str_long_x10,
                },
                .fmt = FormatSet.initOne(.pax),
            }},
        },
        .{
            .file = "pax-global-records.tar",
            .headers = &.{ .{
                .type = .global_extended_header,
                .name = "global1",
                .pax_recs = &.{ "path", "global1", "mtime", "1500000000.0" },
                .fmt = FormatSet.initOne(.pax),
            }, .{
                .type = .normal,
                .name = "file1",
                .mtime = unixTime(0, 0),
                .fmt = FormatSet.initOne(.ustar),
            }, .{
                .type = .normal,
                .name = "file2",
                .pax_recs = &.{ "path", "file2" },
                .mtime = unixTime(0, 0),
                .fmt = FormatSet.initOne(.pax),
            }, .{
                .type = .global_extended_header,
                .name = "GlobalHead.0.0",
                .pax_recs = &.{ "path", "" },
                .fmt = FormatSet.initOne(.pax),
            }, .{
                .type = .normal,
                .name = "file3",
                .mtime = unixTime(0, 0),
                .fmt = FormatSet.initOne(.ustar),
            }, .{
                .type = .normal,
                .name = "file4",
                .mtime = unixTime(1400000000, 0),
                .pax_recs = &.{ "mtime", "1400000000" },
                .fmt = FormatSet.initOne(.pax),
            } },
        },
        .{
            .file = "nil-uid.tar", // golang.org/issue/5290
            .headers = &.{.{
                .name = "P1050238.JPG.log",
                .mode = 0o664,
                .uid = 0,
                .gid = 0,
                .size = 14,
                .mtime = unixTime(1365454838, 0),
                .type = .normal,
                .linkname = "",
                .uname = "eyefi",
                .gname = "eyefi",
                .dev_major = 0,
                .dev_minor = 0,
                .fmt = FormatSet.initOne(.gnu),
            }},
        },
        .{
            .file = "xattrs.tar",
            .headers = &.{
                .{
                    .name = "small.txt",
                    .mode = 0o644,
                    .uid = 1000,
                    .gid = 10,
                    .size = 5,
                    .mtime = unixTime(1386065770, 448252320),
                    .type = .normal,
                    .uname = "alex",
                    .gname = "wheel",
                    .atime = unixTime(1389782991, 419875220),
                    .ctime = unixTime(1389782956, 794414986),
                    .pax_recs = &.{
                        "user.key",                      "value",
                        "user.key2",                     "value2",
                        "security.selinux",              ".unconfined_u=.object_r=.default_t=s0\x00",
                        // Interestingly, selinux encodes the terminating null inside the xattr
                        "mtime",                         "1386065770.44825232",
                        "atime",                         "1389782991.41987522",
                        "ctime",                         "1389782956.794414986",
                        "SCHILY.xattr.user.key",         "value",
                        "SCHILY.xattr.user.key2",        "value2",
                        "SCHILY.xattr.security.selinux", ".unconfined_u=.object_r=.default_t=s0\x00",
                    },
                    .fmt = FormatSet.initOne(.pax),
                },
                .{
                    .name = "small2.txt",
                    .mode = 0o644,
                    .uid = 1000,
                    .gid = 10,
                    .size = 11,
                    .mtime = unixTime(1386065770, 449252304),
                    .type = .normal,
                    .uname = "alex",
                    .gname = "wheel",
                    .atime = unixTime(1389782991, 419875220),
                    .ctime = unixTime(1386065770, 449252304),
                    .pax_recs = &.{
                        "security.selinux",              ".unconfined_u=.object_r=.default_t=s0\x00",
                        "mtime",                         "1386065770.449252304",
                        "atime",                         "1389782991.41987522",
                        "ctime",                         "1386065770.449252304",
                        "SCHILY.xattr.security.selinux", ".unconfined_u=.object_r=.default_t=s0\x00",
                    },
                    .fmt = FormatSet.initOne(.pax),
                },
            },
        },
        .{
            // Matches the behavior of GNU, BSD, and STAR tar utilities.
            .file = "gnu-multi-hdrs.tar",
            .headers = &.{.{
                .name = "GNU2/GNU2/long-path-name",
                .linkname = "GNU4/GNU4/long-linkpath-name",
                .mtime = unixTime(0, 0),
                .type = .symbolic_link,
                .fmt = FormatSet.initOne(.gnu),
            }},
        },
        .{
            .skip = true,
            // GNU tar file with atime and ctime fields set.
            // Created with the GNU tar v1.27.1.
            //  tar --incremental -S -cvf gnu-incremental.tar test2
            .file = "gnu-incremental.tar",
            .headers = &.{ .{
                .name = "test2/",
                .mode = 16877,
                .uid = 1000,
                .gid = 1000,
                .size = 14,
                .mtime = unixTime(1441973427, 0),
                .type = @intToEnum(FileType, 'D'),
                .uname = "rawr",
                .gname = "dsnet",
                .atime = unixTime(1441974501, 0),
                .ctime = unixTime(1441973436, 0),
                .fmt = FormatSet.initOne(.gnu),
            }, .{
                .name = "test2/foo",
                .mode = 33188,
                .uid = 1000,
                .gid = 1000,
                .size = 64,
                .mtime = unixTime(1441973363, 0),
                .type = .normal,
                .uname = "rawr",
                .gname = "dsnet",
                .atime = unixTime(1441974501, 0),
                .ctime = unixTime(1441973436, 0),
                .fmt = FormatSet.initOne(.gnu),
            }, .{
                .name = "test2/sparse",
                .mode = 33188,
                .uid = 1000,
                .gid = 1000,
                .size = 536870912,
                .mtime = unixTime(1441973427, 0),
                .type = @intToEnum(FileType, 'S'),
                .uname = "rawr",
                .gname = "dsnet",
                .atime = unixTime(1441991948, 0),
                .ctime = unixTime(1441973436, 0),
                .fmt = FormatSet.initOne(.gnu),
            } },
        },
        .{
            // Matches the behavior of GNU and BSD tar utilities.
            .file = "pax-multi-hdrs.tar",
            .headers = &.{.{
                .name = "bar",
                .linkname = "PAX4/PAX4/long-linkpath-name",
                .mtime = unixTime(0, 0),
                .type = @intToEnum(tar.FileType, '2'),
                .pax_recs = &.{
                    "linkpath", "PAX4/PAX4/long-linkpath-name",
                },
                .fmt = FormatSet.initOne(.pax),
            }},
        },
        .{
            // Both BSD and GNU tar truncate long names at first NUL even
            // if there is data following that NUL character.
            // This is reasonable as GNU long names are C-strings.
            .file = "gnu-long-nul.tar",
            .headers = &.{.{
                .name = "0123456789",
                .mode = 0o644,
                .uid = 1000,
                .gid = 1000,
                .mtime = unixTime(1486082191, 0),
                .type = .normal,
                .uname = "rawr",
                .gname = "dsnet",
                .fmt = FormatSet.initOne(.gnu),
            }},
        },
        .{
            // This archive was generated by Writer but is readable by both
            // GNU and BSD tar utilities.
            // The archive generated by GNU is nearly byte-for-byte identical
            // to the Go version except the Go version sets a negative dev_minor
            // just to force the GNU format.
            .file = "gnu-utf8.tar",
            .headers = &.{.{
                .name = "☺☻☹☺☻☹☺☻☹☺☻☹☺☻☹☺☻☹☺☻☹☺☻☹☺☻☹☺☻☹☺☻☹☺☻☹☺☻☹☺☻☹☺☻☹☺☻☹☺☻☹☺☻☹",
                .mode = 0o644,
                .uid = 1000,
                .gid = 1000,
                .mtime = unixTime(0, 0),
                .type = .normal,
                .uname = "☺",
                .gname = "⚹",
                .fmt = FormatSet.initOne(.gnu),
            }},
        },
        .{
            // This archive was generated by Writer but is readable by both
            // GNU and BSD tar utilities.
            // The archive generated by GNU is nearly byte-for-byte identical
            // to the Go version except the Go version sets a negative dev_minor
            // just to force the GNU format.
            .file = "gnu-not-utf8.tar",
            .headers = &.{.{
                .name = "hi\x80\x81\x82\x83bye",
                .mode = 0o644,
                .uid = 1000,
                .gid = 1000,
                .mtime = unixTime(0, 0),
                .type = .normal,
                .uname = "rawr",
                .gname = "dsnet",
                .fmt = FormatSet.initOne(.gnu),
            }},
        },
        .{
            // BSD tar v3.1.2 and GNU tar v1.27.1 both rejects PAX records
            // with NULs in the key.
            .file = "pax-nul-xattrs.tar",
            .err = error.Header,
        },
        .{
            // BSD tar v3.1.2 rejects a PAX path with NUL in the value, while
            // GNU tar v1.27.1 simply truncates at first NUL.
            // We emulate the behavior of BSD since it is strange doing NUL
            // truncations since PAX records are length-prefix strings instead
            // of NUL-terminated C-strings.
            .file = "pax-nul-path.tar",
            .err = error.Header,
        },
        .{
            .file = "neg-size.tar",
            .err = error.Overflow,
        },
        .{
            .file = "issue10968.tar",
            .err = error.InvalidCharacter,
        },
        .{
            .file = "issue11169.tar",
            .err = error.UnexpectedEndOfStream,
        },
        .{
            .file = "issue12435.tar",
            .err = error.Overflow,
        },
        .{
            .skip = true,
            // Ensure that we can read back the original Header as written with
            // a buggy pre-Go1.8 tar.Writer.
            .file = "invalid-go17.tar",
            .headers = &.{.{
                .name = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa/foo",
                .uid = 0o10000000,
                .mtime = unixTime(0, 0),
                .type = .normal,
            }},
        },
        .{
            // USTAR archive with a regular entry with non-zero device numbers.
            .file = "ustar-file-devs.tar",
            .headers = &.{.{
                .name = "file",
                .mode = 0o644,
                .type = .normal,
                .mtime = unixTime(0, 0),
                .dev_major = 1,
                .dev_minor = 1,
                .fmt = FormatSet.initOne(.ustar),
            }},
        },
        .{
            // Generated by Go, works on BSD tar v3.1.2 and GNU tar v.1.27.1.
            .file = "gnu-nil-sparse-data.tar",
            .headers = &.{.{
                .name = "sparse.db",
                .type = .gnu_sparse,
                .size = 1000,
                .mtime = unixTime(0, 0),
                .fmt = FormatSet.initOne(.gnu),
            }},
        },
        .{
            .skip = true,
            // Generated by Go, works on BSD tar v3.1.2 and GNU tar v.1.27.1.
            .file = "gnu-nil-sparse-hole.tar",
            .headers = &.{.{
                .name = "sparse.db",
                .type = .gnu_sparse,
                .size = 1000,
                .mtime = unixTime(0, 0),
                .fmt = FormatSet.initOne(.gnu),
            }},
        },
        .{
            .skip = true,
            // Generated by Go, works on BSD tar v3.1.2 and GNU tar v.1.27.1.
            .file = "pax-nil-sparse-data.tar",
            .headers = &.{.{
                .name = "sparse.db",
                .type = .normal,
                .size = 1000,
                .mtime = unixTime(0, 0),
                .pax_recs = &.{
                    "size",                "1512",
                    "GNU.sparse.major",    "1",
                    "GNU.sparse.minor",    "0",
                    "GNU.sparse.realsize", "1000",
                    "GNU.sparse.name",     "sparse.db",
                },
                .fmt = FormatSet.initOne(.pax),
            }},
        },
        .{
            .skip = true,
            // Generated by Go, works on BSD tar v3.1.2 and GNU tar v.1.27.1.
            .file = "pax-nil-sparse-hole.tar",
            .headers = &.{.{
                .name = "sparse.db",
                .type = .normal,
                .size = 1000,
                .mtime = unixTime(0, 0),
                .pax_recs = &.{
                    "size",                "512",
                    "GNU.sparse.major",    "1",
                    "GNU.sparse.minor",    "0",
                    "GNU.sparse.realsize", "1000",
                    "GNU.sparse.name",     "sparse.db",
                },
                .fmt = FormatSet.initOne(.pax),
            }},
        },
        .{
            .file = "trailing-slash.tar",
            .headers = &.{.{
                .type = .directory,
                .name = one_to_nine_slash_x30,
                .mtime = unixTime(0, 0),
                .pax_recs = &.{ "path", one_to_nine_slash_x30 },
                .fmt = FormatSet.initOne(.pax),
            }},
        },
    };

    var headers_tested: usize = 0;
    var cases_skipped: usize = 0;
    var errors: usize = 0;

    inline for (test_cases) |test_case| {
        if (test_case.skip) {
            cases_skipped += 1;
            continue;
        }
        std.log.info("\n--- test_case.file={s} ---", .{test_case.file});
        var fbs = try test_common.decompressGz("testdata/" ++ test_case.file ++ ".gz", talloc);
        defer talloc.free(fbs.buffer);
        const reader = fbs.reader();
        var buf: [tar.block_len]u8 = undefined;
        var iter = tar.headerIterator(reader, &buf, talloc);
        defer iter.deinit();
        for (test_case.headers, 0..) |header_, i| {
            // since we don't maintain a hash map of pax records, merge pax_recs
            // into this header record
            var expected = header_;
            var j: usize = 0;
            while (j < expected.pax_recs.len) : (j += 2) {
                const k = expected.pax_recs[j];
                const val = expected.pax_recs[j + 1];
                try tar.mergePax(.{ k, val }, &expected);
            }
            std.log.debug("expected: {}", .{expected});
            const mhdr = try iter.next();
            try testing.expect(mhdr != null);
            const actual = mhdr.?;
            std.log.debug("actual  : {}", .{actual});

            // test Header fields by their type.
            // can't use testing.expectEqualDeep() because pax_recs field won't match.
            inline for (std.meta.fields(Header)) |fd| {
                _ = switch (fd.type) {
                    []const u8 => testing.expectEqualStrings(@field(expected, fd.name), @field(actual, fd.name)),
                    []const []const u8 => testing.expect(true), // dummy so types match
                    i64,
                    i32,
                    i128,
                    => if (@field(expected, fd.name) != -1)
                        testing.expectEqual(@field(expected, fd.name), @field(actual, fd.name))
                    else
                        testing.expect(true),
                    FileType,
                    std.time.Instant,
                    FormatSet,
                    => testing.expectEqual(@field(expected, fd.name), @field(actual, fd.name)),
                    else => return @compileLog(comptime std.fmt.comptimePrint("todo {s}", .{@typeName(fd.type)})),
                } catch |e| {
                    std.log.err("field '{s}' not equal", .{fd.name});
                    return e;
                };
            }

            if (actual.size == -1) continue;
            const block_size = std.mem.alignForwardGeneric(usize, @intCast(usize, actual.size), 512);
            // validate checksums if exist or skip over file contents
            if (test_case.chksums.len > i) {
                var h = std.crypto.hash.Md5.init(.{});
                const content = try talloc.alloc(u8, block_size);
                defer talloc.free(content);
                _ = try reader.read(content);
                h.update(content[0..@intCast(usize, actual.size)]);
                var hbuf: [16]u8 = undefined;
                h.final(&hbuf);
                const hex = std.fmt.bytesToHex(hbuf, .lower);
                try testing.expectEqualStrings(test_case.chksums[i], &hex);
            } else { // skip over file contents
                switch (actual.type) {
                    .normal, .normal2 => try reader.skipBytes(block_size, .{}),
                    else => {},
                }
            }
        }

        // check any remaining headers for errors
        var merr: ?anyerror = null;
        while (true) {
            const next = iter.next() catch |e| {
                merr = e;
                break;
            };
            if (next == null) break;
        }

        if (test_case.err) |e| {
            if (e != merr) {
                errors += 1;
                std.log.err("errors don't match. expecting {!} found {?!}", .{ e, merr });
            }
            try testing.expect(merr != null);
            try testing.expectEqual(e, merr.?);
        }

        headers_tested += test_case.headers.len;
    }
    std.log.info(
        "test Reader: tar test cases: {} total, {} passed, {} errored, {} skipped, {} total headers checked.",
        .{ test_cases.len, test_cases.len - cases_skipped - errors, errors, cases_skipped, headers_tested },
    );
}

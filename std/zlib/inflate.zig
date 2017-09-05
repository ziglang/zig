
error Z_STREAM_ERROR;
error Z_STREAM_END;
error Z_NEED_DICT;
error Z_ERRNO;
error Z_STREAM_ERROR;
error Z_DATA_ERROR;
error Z_MEM_ERROR;
error Z_BUF_ERROR;
error Z_VERSION_ERROR;

pub Flush = enum {
    NO_FLUSH,
    PARTIAL_FLUSH,
    SYNC_FLUSH,
    FULL_FLUSH,
    FINISH,
    BLOCK,
    TREES,
};

const code = struct {
    /// operation, extra bits, table bits
    op: u8,
    /// bits in this part of the code
    bits: u8,
    /// offset in table or code value
    val: u16,
};

/// State maintained between inflate() calls -- approximately 7K bytes, not
/// including the allocated sliding window, which is up to 32K bytes.
const inflate_state = struct {
    z_stream *  strm;             /* pointer back to this zlib stream */
    inflate_mode mode;          /* current inflate mode */
    int last;                   /* true if processing last block */
    int wrap;                   /* bit 0 true for zlib, bit 1 true for gzip,
                                   bit 2 true to validate check value */
    int havedict;               /* true if dictionary provided */
    int flags;                  /* gzip header method and flags (0 if zlib) */
    unsigned dmax;              /* zlib header max distance (INFLATE_STRICT) */
    unsigned long check;        /* protected copy of check value */
    unsigned long total;        /* protected copy of output count */
    gz_headerp head;            /* where to save gzip header information */
        /* sliding window */
    unsigned wbits;             /* log base 2 of requested window size */
    unsigned wsize;             /* window size or zero if not using window */
    unsigned whave;             /* valid bytes in the window */
    unsigned wnext;             /* window write index */
    u8 FAR *window;  /* allocated sliding window, if needed */
        /* bit accumulator */
    unsigned long hold;         /* input bit accumulator */
    unsigned bits;              /* number of bits in "in" */
        /* for string and stored block copying */
    unsigned length;            /* literal or length of data to copy */
    unsigned offset;            /* distance back to copy string from */
        /* for table and code decoding */
    unsigned extra;             /* extra bits needed */
        /* fixed and dynamic code tables */
    code const FAR *lencode;    /* starting table for length/literal codes */
    code const FAR *distcode;   /* starting table for distance codes */
    unsigned lenbits;           /* index bits for lencode */
    unsigned distbits;          /* index bits for distcode */
        /* dynamic table building */
    unsigned ncode;             /* number of code length code lengths */
    unsigned nlen;              /* number of length code lengths */
    unsigned ndist;             /* number of distance code lengths */
    unsigned have;              /* number of code lengths in lens[] */
    code FAR *next;             /* next available space in codes[] */
    unsigned short lens[320];   /* temporary storage for code lengths */
    unsigned short work[288];   /* work area for code table building */
    code codes[ENOUGH];         /* space for code tables */
    int sane;                   /* if false, allow invalid distance too far */
    int back;                   /* bits back of last unprocessed length/lit */
    unsigned was;               /* initial length of match */
};

const alloc_func = fn(opaque: &c_void, items: u16, size: u16);
const free_func = fn(opaque: &c_void, address: &c_void);

const z_stream = struct {
    /// next input byte
    next_in: &u8,
    /// number of bytes available at next_in
    avail_in: u16,
    /// total number of input bytes read so far
    total_in: u32,

    /// next output byte will go here
    next_out: &u8,
    /// remaining free space at next_out
    avail_out: u16,
    /// total number of bytes output so far */
    total_out: u32,

    /// last error message, NULL if no error
    msg: &const u8,
    /// not visible by applications
    state: &inflate_state,

    /// used to allocate the internal state
    zalloc: alloc_func,
    /// used to free the internal state
    zfree: free_func,
    /// private data object passed to zalloc and zfree
    opaque: &c_void,

    /// best guess about the data type: binary or text
    /// for deflate, or the decoding state for inflate
    data_type: i32,

    /// Adler-32 or CRC-32 value of the uncompressed data
    adler: u32,
};

// Possible inflate modes between inflate() calls
/// i: waiting for magic header
pub const HEAD = 16180;
/// i: waiting for method and flags (gzip)
pub const FLAGS = 16181;
/// i: waiting for modification time (gzip)
pub const TIME = 16182;
/// i: waiting for extra flags and operating system (gzip)
pub const OS = 16183;
/// i: waiting for extra length (gzip)
pub const EXLEN = 16184;
/// i: waiting for extra bytes (gzip)
pub const EXTRA = 16185;
/// i: waiting for end of file name (gzip)
pub const NAME = 16186;
/// i: waiting for end of comment (gzip)
pub const COMMENT = 16187;
/// i: waiting for header crc (gzip)
pub const HCRC = 16188;
/// i: waiting for dictionary check value
pub const DICTID = 16189;
/// waiting for inflateSetDictionary() call
pub const DICT = 16190;
/// i: waiting for type bits, including last-flag bit
pub const TYPE = 16191;
/// i: same, but skip check to exit inflate on new block
pub const TYPEDO = 16192;
/// i: waiting for stored size (length and complement)
pub const STORED = 16193;
/// i/o: same as COPY below, but only first time in
pub const COPY_ = 16194;
/// i/o: waiting for input or output to copy stored block
pub const COPY = 16195;
/// i: waiting for dynamic block table lengths
pub const TABLE = 16196;
/// i: waiting for code length code lengths
pub const LENLENS = 16197;
/// i: waiting for length/lit and distance code lengths
pub const CODELENS = 16198;
/// i: same as LEN below, but only first time in
pub const LEN_ = 16199;
/// i: waiting for length/lit/eob code
pub const LEN = 16200;
/// i: waiting for length extra bits
pub const LENEXT = 16201;
/// i: waiting for distance code
pub const DIST = 16202;
/// i: waiting for distance extra bits
pub const DISTEXT = 16203;
/// o: waiting for output space to copy string
pub const MATCH = 16204;
/// o: waiting for output space to write literal
pub const LIT = 16205;
/// i: waiting for 32-bit check value
pub const CHECK = 16206;
/// i: waiting for 32-bit length (gzip)
pub const LENGTH = 16207;
/// finished check, done -- remain here until reset
pub const DONE = 16208;
/// got a data error -- remain here until reset
pub const BAD = 16209;
/// got an inflate() memory error -- remain here until reset
pub const MEM = 16210;
/// looking for synchronization bytes to restart inflate() */
pub const SYNC = 16211;

/// inflate() uses a state machine to process as much input data and generate as
/// much output data as possible before returning.  The state machine is
/// structured roughly as follows:
///
///  for (;;) switch (state) {
///  ...
///  case STATEn:
///      if (not enough input data or output space to make progress)
///          return;
///      ... make progress ...
///      state = STATEm;
///      break;
///  ...
///  }
///
/// so when inflate() is called again, the same case is attempted again, and
/// if the appropriate resources are provided, the machine proceeds to the
/// next state.  The NEEDBITS() macro is usually the way the state evaluates
/// whether it can proceed or should return.  NEEDBITS() does the return if
/// the requested bits are not available.  The typical use of the BITS macros
/// is:
///
///      NEEDBITS(n);
///      ... do something with BITS(n) ...
///      DROPBITS(n);
///
/// where NEEDBITS(n) either returns from inflate() if there isn't enough
/// input left to load n bits into the accumulator, or it continues.  BITS(n)
/// gives the low n bits in the accumulator.  When done, DROPBITS(n) drops
/// the low n bits off the accumulator.  INITBITS() clears the accumulator
/// and sets the number of available bits to zero.  BYTEBITS() discards just
/// enough bits to put the accumulator on a byte boundary.  After BYTEBITS()
/// and a NEEDBITS(8), then BITS(8) would return the next byte in the stream.
///
/// NEEDBITS(n) uses PULLBYTE() to get an available byte of input, or to return
/// if there is no input available.  The decoding of variable length codes uses
/// PULLBYTE() directly in order to pull just enough bytes to decode the next
/// code, and no more.
///
/// Some states loop until they get enough input, making sure that enough
/// state information is maintained to continue the loop where it left off
/// if NEEDBITS() returns in the loop.  For example, want, need, and keep
/// would all have to actually be part of the saved state in case NEEDBITS()
/// returns:
///
///  case STATEw:
///      while (want < need) {
///          NEEDBITS(n);
///          keep[want++] = BITS(n);
///          DROPBITS(n);
///      }
///      state = STATEx;
///  case STATEx:
///
/// As shown above, if the next state is also the next case, then the break
/// is omitted.
///
/// A state may also return if there is not enough output space available to
/// complete that state.  Those states are copying stored data, writing a
/// literal byte, and copying a matching string.
///
/// When returning, a "goto inf_leave" is used to update the total counters,
/// update the check value, and determine whether any progress has been made
/// during that inflate() call in order to return the proper return code.
/// Progress is defined as a change in either strm->avail_in or strm->avail_out.
/// When there is a window, goto inf_leave will update the window with the last
/// output written.  If a goto inf_leave occurs in the middle of decompression
/// and there is no window currently, goto inf_leave will create one and copy
/// output to the window for the next call of inflate().
///
/// In this implementation, the flush parameter of inflate() only affects the
/// return code (per zlib.h).  inflate() always writes as much as possible to
/// strm->next_out, given the space available and the provided input--the effect
/// documented in zlib.h of Z_SYNC_FLUSH.  Furthermore, inflate() always defers
/// the allocation of and copying into a sliding window until necessary, which
/// provides the effect documented in zlib.h for Z_FINISH when the entire input
/// stream available.  So the only thing the flush parameter actually does is:
/// when flush is set to Z_FINISH, inflate() cannot return Z_OK.  Instead it
/// will return Z_BUF_ERROR if it has not reached the end of the stream.
pub fn inflate(strm: &z_stream, flush: Flush, gunzip: bool) -> %void {
    // next input
    var next: &const u8 = undefined;
    // next output
    var put: &u8 = undefined;

    // available input and output
    var have: u16 = undefined;
    var left: u16 = undefined;

    // bit buffer
    var hold: u32 = undefined;
    // bits in bit buffer
    var bits: u16 = undefined;
    // save starting available input and output
    var in: u16 = undefined;
    var out: u16 = undefined;
    // number of stored or match bytes to copy
    var copy: u16 = undefined;
    // where to copy match bytes from
    var from: &u8 = undefined;
    // current decoding table entry
    var here: code = undefined;
    // parent table entry
    var last: code = undefined;
    // length to copy for repeats, bits to drop
    var len: u16 = undefined;
    
    // return code
    var ret: error = undefined;

    // buffer for gzip header crc calculation
    var hbuf: [4]u8 = undefined;

    // permutation of code lengths
    const short_order = []u16 = {16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15};

    if (inflateStateCheck(strm) or strm.next_out == Z_NULL or (strm.next_in == Z_NULL and strm.avail_in != 0)) {
        return error.Z_STREAM_ERROR;
    }

    var state: &inflate_state = strm.state;
    if (state.mode == TYPE) {
        state.mode = TYPEDO; // skip check
    }
        put = strm.next_out; \
        left = strm.avail_out; \
        next = strm.next_in; \
        have = strm.avail_in; \
        hold = state.hold; \
        bits = state.bits; \
    in = have;
    out = left;
    ret = Z_OK;
    for (;;)
        switch (state.mode) {
        case HEAD:
            if (state.wrap == 0) {
                state.mode = TYPEDO;
                break;
            }
            NEEDBITS(16);
#ifdef GUNZIP
            if ((state.wrap & 2) && hold == 0x8b1f) {  /* gzip header */
                if (state.wbits == 0)
                    state.wbits = 15;
                state.check = crc32(0L, Z_NULL, 0);
                CRC2(state.check, hold);
                INITBITS();
                state.mode = FLAGS;
                break;
            }
            state.flags = 0;           /* expect zlib header */
            if (state.head != Z_NULL)
                state.head.done = -1;
            if (!(state.wrap & 1) ||   /* check if zlib header allowed */
#else
            if (
#endif
                ((BITS(8) << 8) + (hold >> 8)) % 31) {
                strm.msg = (char *)"incorrect header check";
                state.mode = BAD;
                break;
            }
            if (BITS(4) != Z_DEFLATED) {
                strm.msg = (char *)"unknown compression method";
                state.mode = BAD;
                break;
            }
            DROPBITS(4);
            len = BITS(4) + 8;
            if (state.wbits == 0)
                state.wbits = len;
            if (len > 15 || len > state.wbits) {
                strm.msg = (char *)"invalid window size";
                state.mode = BAD;
                break;
            }
            state.dmax = 1U << len;
            Tracev((stderr, "inflate:   zlib header ok\n"));
            strm.adler = state.check = adler32(0L, Z_NULL, 0);
            state.mode = hold & 0x200 ? DICTID : TYPE;
            INITBITS();
            break;
#ifdef GUNZIP
        case FLAGS:
            NEEDBITS(16);
            state.flags = (int)(hold);
            if ((state.flags & 0xff) != Z_DEFLATED) {
                strm.msg = (char *)"unknown compression method";
                state.mode = BAD;
                break;
            }
            if (state.flags & 0xe000) {
                strm.msg = (char *)"unknown header flags set";
                state.mode = BAD;
                break;
            }
            if (state.head != Z_NULL)
                state.head.text = (int)((hold >> 8) & 1);
            if ((state.flags & 0x0200) && (state.wrap & 4))
                CRC2(state.check, hold);
            INITBITS();
            state.mode = TIME;
        case TIME:
            NEEDBITS(32);
            if (state.head != Z_NULL)
                state.head.time = hold;
            if ((state.flags & 0x0200) && (state.wrap & 4))
                CRC4(state.check, hold);
            INITBITS();
            state.mode = OS;
        case OS:
            NEEDBITS(16);
            if (state.head != Z_NULL) {
                state.head.xflags = (int)(hold & 0xff);
                state.head.os = (int)(hold >> 8);
            }
            if ((state.flags & 0x0200) && (state.wrap & 4))
                CRC2(state.check, hold);
            INITBITS();
            state.mode = EXLEN;
        case EXLEN:
            if (state.flags & 0x0400) {
                NEEDBITS(16);
                state.length = (unsigned)(hold);
                if (state.head != Z_NULL)
                    state.head.extra_len = (unsigned)hold;
                if ((state.flags & 0x0200) && (state.wrap & 4))
                    CRC2(state.check, hold);
                INITBITS();
            }
            else if (state.head != Z_NULL)
                state.head.extra = Z_NULL;
            state.mode = EXTRA;
        case EXTRA:
            if (state.flags & 0x0400) {
                copy = state.length;
                if (copy > have) copy = have;
                if (copy) {
                    if (state.head != Z_NULL &&
                        state.head.extra != Z_NULL) {
                        len = state.head.extra_len - state.length;
                        zmemcpy(state.head.extra + len, next,
                                len + copy > state.head.extra_max ?
                                state.head.extra_max - len : copy);
                    }
                    if ((state.flags & 0x0200) && (state.wrap & 4))
                        state.check = crc32(state.check, next, copy);
                    have -= copy;
                    next += copy;
                    state.length -= copy;
                }
                if (state.length) goto inf_leave;
            }
            state.length = 0;
            state.mode = NAME;
        case NAME:
            if (state.flags & 0x0800) {
                if (have == 0) goto inf_leave;
                copy = 0;
                do {
                    len = (unsigned)(next[copy++]);
                    if (state.head != Z_NULL &&
                            state.head.name != Z_NULL &&
                            state.length < state.head.name_max)
                        state.head.name[state.length++] = (Bytef)len;
                } while (len && copy < have);
                if ((state.flags & 0x0200) && (state.wrap & 4))
                    state.check = crc32(state.check, next, copy);
                have -= copy;
                next += copy;
                if (len) goto inf_leave;
            }
            else if (state.head != Z_NULL)
                state.head.name = Z_NULL;
            state.length = 0;
            state.mode = COMMENT;
        case COMMENT:
            if (state.flags & 0x1000) {
                if (have == 0) goto inf_leave;
                copy = 0;
                do {
                    len = (unsigned)(next[copy++]);
                    if (state.head != Z_NULL &&
                            state.head.comment != Z_NULL &&
                            state.length < state.head.comm_max)
                        state.head.comment[state.length++] = (Bytef)len;
                } while (len && copy < have);
                if ((state.flags & 0x0200) && (state.wrap & 4))
                    state.check = crc32(state.check, next, copy);
                have -= copy;
                next += copy;
                if (len) goto inf_leave;
            }
            else if (state.head != Z_NULL)
                state.head.comment = Z_NULL;
            state.mode = HCRC;
        case HCRC:
            if (state.flags & 0x0200) {
                NEEDBITS(16);
                if ((state.wrap & 4) && hold != (state.check & 0xffff)) {
                    strm.msg = (char *)"header crc mismatch";
                    state.mode = BAD;
                    break;
                }
                INITBITS();
            }
            if (state.head != Z_NULL) {
                state.head.hcrc = (int)((state.flags >> 9) & 1);
                state.head.done = 1;
            }
            strm.adler = state.check = crc32(0L, Z_NULL, 0);
            state.mode = TYPE;
            break;
#endif
        case DICTID:
            NEEDBITS(32);
            strm.adler = state.check = ZSWAP32(hold);
            INITBITS();
            state.mode = DICT;
        case DICT:
            if (state.havedict == 0) {
                strm.next_out = put; \
                strm.avail_out = left; \
                strm.next_in = next; \
                strm.avail_in = have; \
                state.hold = hold; \
                state.bits = bits; \
                return Z_NEED_DICT;
            }
            strm.adler = state.check = adler32(0L, Z_NULL, 0);
            state.mode = TYPE;
        case TYPE:
            if (flush == Z_BLOCK || flush == Z_TREES) goto inf_leave;
        case TYPEDO:
            if (state.last) {
                BYTEBITS();
                state.mode = CHECK;
                break;
            }
            NEEDBITS(3);
            state.last = BITS(1);
            DROPBITS(1);
            switch (BITS(2)) {
            case 0:                             /* stored block */
                Tracev((stderr, "inflate:     stored block%s\n",
                        state.last ? " (last)" : ""));
                state.mode = STORED;
                break;
            case 1:                             /* fixed block */
                fixedtables(state);
                Tracev((stderr, "inflate:     fixed codes block%s\n",
                        state.last ? " (last)" : ""));
                state.mode = LEN_;             /* decode codes */
                if (flush == Z_TREES) {
                    DROPBITS(2);
                    goto inf_leave;
                }
                break;
            case 2:                             /* dynamic block */
                Tracev((stderr, "inflate:     dynamic codes block%s\n",
                        state.last ? " (last)" : ""));
                state.mode = TABLE;
                break;
            case 3:
                strm.msg = (char *)"invalid block type";
                state.mode = BAD;
            }
            DROPBITS(2);
            break;
        case STORED:
            BYTEBITS();                         /* go to byte boundary */
            NEEDBITS(32);
            if ((hold & 0xffff) != ((hold >> 16) ^ 0xffff)) {
                strm.msg = (char *)"invalid stored block lengths";
                state.mode = BAD;
                break;
            }
            state.length = (unsigned)hold & 0xffff;
            Tracev((stderr, "inflate:       stored length %u\n",
                    state.length));
            INITBITS();
            state.mode = COPY_;
            if (flush == Z_TREES) goto inf_leave;
        case COPY_:
            state.mode = COPY;
        case COPY:
            copy = state.length;
            if (copy) {
                if (copy > have) copy = have;
                if (copy > left) copy = left;
                if (copy == 0) goto inf_leave;
                zmemcpy(put, next, copy);
                have -= copy;
                next += copy;
                left -= copy;
                put += copy;
                state.length -= copy;
                break;
            }
            Tracev((stderr, "inflate:       stored end\n"));
            state.mode = TYPE;
            break;
        case TABLE:
            NEEDBITS(14);
            state.nlen = BITS(5) + 257;
            DROPBITS(5);
            state.ndist = BITS(5) + 1;
            DROPBITS(5);
            state.ncode = BITS(4) + 4;
            DROPBITS(4);
#ifndef PKZIP_BUG_WORKAROUND
            if (state.nlen > 286 || state.ndist > 30) {
                strm.msg = (char *)"too many length or distance symbols";
                state.mode = BAD;
                break;
            }
#endif
            Tracev((stderr, "inflate:       table sizes ok\n"));
            state.have = 0;
            state.mode = LENLENS;
        case LENLENS:
            while (state.have < state.ncode) {
                NEEDBITS(3);
                state.lens[order[state.have++]] = (unsigned short)BITS(3);
                DROPBITS(3);
            }
            while (state.have < 19)
                state.lens[order[state.have++]] = 0;
            state.next = state.codes;
            state.lencode = (const code FAR *)(state.next);
            state.lenbits = 7;
            ret = inflate_table(CODES, state.lens, 19, &(state.next),
                                &(state.lenbits), state.work);
            if (ret) {
                strm.msg = (char *)"invalid code lengths set";
                state.mode = BAD;
                break;
            }
            Tracev((stderr, "inflate:       code lengths ok\n"));
            state.have = 0;
            state.mode = CODELENS;
        case CODELENS:
            while (state.have < state.nlen + state.ndist) {
                for (;;) {
                    here = state.lencode[BITS(state.lenbits)];
                    if ((unsigned)(here.bits) <= bits) break;
                    PULLBYTE();
                }
                if (here.val < 16) {
                    DROPBITS(here.bits);
                    state.lens[state.have++] = here.val;
                }
                else {
                    if (here.val == 16) {
                        NEEDBITS(here.bits + 2);
                        DROPBITS(here.bits);
                        if (state.have == 0) {
                            strm.msg = (char *)"invalid bit length repeat";
                            state.mode = BAD;
                            break;
                        }
                        len = state.lens[state.have - 1];
                        copy = 3 + BITS(2);
                        DROPBITS(2);
                    }
                    else if (here.val == 17) {
                        NEEDBITS(here.bits + 3);
                        DROPBITS(here.bits);
                        len = 0;
                        copy = 3 + BITS(3);
                        DROPBITS(3);
                    }
                    else {
                        NEEDBITS(here.bits + 7);
                        DROPBITS(here.bits);
                        len = 0;
                        copy = 11 + BITS(7);
                        DROPBITS(7);
                    }
                    if (state.have + copy > state.nlen + state.ndist) {
                        strm.msg = (char *)"invalid bit length repeat";
                        state.mode = BAD;
                        break;
                    }
                    while (copy--)
                        state.lens[state.have++] = (unsigned short)len;
                }
            }

            /* handle error breaks in while */
            if (state.mode == BAD) break;

            /* check for end-of-block code (better have one) */
            if (state.lens[256] == 0) {
                strm.msg = (char *)"invalid code -- missing end-of-block";
                state.mode = BAD;
                break;
            }

            /* build code tables -- note: do not change the lenbits or distbits
               values here (9 and 6) without reading the comments in inftrees.h
               concerning the ENOUGH constants, which depend on those values */
            state.next = state.codes;
            state.lencode = (const code FAR *)(state.next);
            state.lenbits = 9;
            ret = inflate_table(LENS, state.lens, state.nlen, &(state.next),
                                &(state.lenbits), state.work);
            if (ret) {
                strm.msg = (char *)"invalid literal/lengths set";
                state.mode = BAD;
                break;
            }
            state.distcode = (const code FAR *)(state.next);
            state.distbits = 6;
            ret = inflate_table(DISTS, state.lens + state.nlen, state.ndist,
                            &(state.next), &(state.distbits), state.work);
            if (ret) {
                strm.msg = (char *)"invalid distances set";
                state.mode = BAD;
                break;
            }
            Tracev((stderr, "inflate:       codes ok\n"));
            state.mode = LEN_;
            if (flush == Z_TREES) goto inf_leave;
        case LEN_:
            state.mode = LEN;
        case LEN:
            if (have >= 6 && left >= 258) {
                strm.next_out = put; \
                strm.avail_out = left; \
                strm.next_in = next; \
                strm.avail_in = have; \
                state.hold = hold; \
                state.bits = bits; \

                inflate_fast(strm, out);

                put = strm.next_out; \
                left = strm.avail_out; \
                next = strm.next_in; \
                have = strm.avail_in; \
                hold = state.hold; \
                bits = state.bits; \
                if (state.mode == TYPE)
                    state.back = -1;
                break;
            }
            state.back = 0;
            for (;;) {
                here = state.lencode[BITS(state.lenbits)];
                if ((unsigned)(here.bits) <= bits) break;
                PULLBYTE();
            }
            if (here.op && (here.op & 0xf0) == 0) {
                last = here;
                for (;;) {
                    here = state.lencode[last.val +
                            (BITS(last.bits + last.op) >> last.bits)];
                    if ((unsigned)(last.bits + here.bits) <= bits) break;
                    PULLBYTE();
                }
                DROPBITS(last.bits);
                state.back += last.bits;
            }
            DROPBITS(here.bits);
            state.back += here.bits;
            state.length = (unsigned)here.val;
            if ((int)(here.op) == 0) {
                Tracevv((stderr, here.val >= 0x20 && here.val < 0x7f ?
                        "inflate:         literal '%c'\n" :
                        "inflate:         literal 0x%02x\n", here.val));
                state.mode = LIT;
                break;
            }
            if (here.op & 32) {
                Tracevv((stderr, "inflate:         end of block\n"));
                state.back = -1;
                state.mode = TYPE;
                break;
            }
            if (here.op & 64) {
                strm.msg = (char *)"invalid literal/length code";
                state.mode = BAD;
                break;
            }
            state.extra = (unsigned)(here.op) & 15;
            state.mode = LENEXT;
        case LENEXT:
            if (state.extra) {
                NEEDBITS(state.extra);
                state.length += BITS(state.extra);
                DROPBITS(state.extra);
                state.back += state.extra;
            }
            Tracevv((stderr, "inflate:         length %u\n", state.length));
            state.was = state.length;
            state.mode = DIST;
        case DIST:
            for (;;) {
                here = state.distcode[BITS(state.distbits)];
                if ((unsigned)(here.bits) <= bits) break;
                PULLBYTE();
            }
            if ((here.op & 0xf0) == 0) {
                last = here;
                for (;;) {
                    here = state.distcode[last.val +
                            (BITS(last.bits + last.op) >> last.bits)];
                    if ((unsigned)(last.bits + here.bits) <= bits) break;
                    PULLBYTE();
                }
                DROPBITS(last.bits);
                state.back += last.bits;
            }
            DROPBITS(here.bits);
            state.back += here.bits;
            if (here.op & 64) {
                strm.msg = (char *)"invalid distance code";
                state.mode = BAD;
                break;
            }
            state.offset = (unsigned)here.val;
            state.extra = (unsigned)(here.op) & 15;
            state.mode = DISTEXT;
        case DISTEXT:
            if (state.extra) {
                NEEDBITS(state.extra);
                state.offset += BITS(state.extra);
                DROPBITS(state.extra);
                state.back += state.extra;
            }
#ifdef INFLATE_STRICT
            if (state.offset > state.dmax) {
                strm.msg = (char *)"invalid distance too far back";
                state.mode = BAD;
                break;
            }
#endif
            Tracevv((stderr, "inflate:         distance %u\n", state.offset));
            state.mode = MATCH;
        case MATCH:
            if (left == 0) goto inf_leave;
            copy = out - left;
            if (state.offset > copy) {         /* copy from window */
                copy = state.offset - copy;
                if (copy > state.whave) {
                    if (state.sane) {
                        strm.msg = (char *)"invalid distance too far back";
                        state.mode = BAD;
                        break;
                    }
#ifdef INFLATE_ALLOW_INVALID_DISTANCE_TOOFAR_ARRR
                    Trace((stderr, "inflate.c too far\n"));
                    copy -= state.whave;
                    if (copy > state.length) copy = state.length;
                    if (copy > left) copy = left;
                    left -= copy;
                    state.length -= copy;
                    do {
                        *put++ = 0;
                    } while (--copy);
                    if (state.length == 0) state.mode = LEN;
                    break;
#endif
                }
                if (copy > state.wnext) {
                    copy -= state.wnext;
                    from = state.window + (state.wsize - copy);
                }
                else
                    from = state.window + (state.wnext - copy);
                if (copy > state.length) copy = state.length;
            }
            else {                              /* copy from output */
                from = put - state.offset;
                copy = state.length;
            }
            if (copy > left) copy = left;
            left -= copy;
            state.length -= copy;
            do {
                *put++ = *from++;
            } while (--copy);
            if (state.length == 0) state.mode = LEN;
            break;
        case LIT:
            if (left == 0) goto inf_leave;
            *put++ = (u8)(state.length);
            left--;
            state.mode = LEN;
            break;
        case CHECK:
            if (state.wrap) {
                NEEDBITS(32);
                out -= left;
                strm.total_out += out;
                state.total += out;
                if ((state.wrap & 4) && out)
                    strm.adler = state.check =
                        UPDATE(state.check, put - out, out);
                out = left;
                if ((state.wrap & 4) && (
#ifdef GUNZIP
                     state.flags ? hold :
#endif
                     ZSWAP32(hold)) != state.check) {
                    strm.msg = (char *)"incorrect data check";
                    state.mode = BAD;
                    break;
                }
                INITBITS();
                Tracev((stderr, "inflate:   check matches trailer\n"));
            }
#ifdef GUNZIP
            state.mode = LENGTH;
        case LENGTH:
            if (state.wrap && state.flags) {
                NEEDBITS(32);
                if (hold != (state.total & 0xffffffffUL)) {
                    strm.msg = (char *)"incorrect length check";
                    state.mode = BAD;
                    break;
                }
                INITBITS();
                Tracev((stderr, "inflate:   length matches trailer\n"));
            }
#endif
            state.mode = DONE;
        case DONE:
            ret = Z_STREAM_END;
            goto inf_leave;
        case BAD:
            ret = Z_DATA_ERROR;
            goto inf_leave;
        case MEM:
            return Z_MEM_ERROR;
        case SYNC:
        default:
            return Z_STREAM_ERROR;
        }

    /*
       Return from inflate(), updating the total counts and the check value.
       If there was no progress during the inflate() call, return a buffer
       error.  Call updatewindow() to create and/or update the window state.
       Note: a memory error from inflate() is non-recoverable.
     */
  inf_leave:
    strm.next_out = put; \
    strm.avail_out = left; \
    strm.next_in = next; \
    strm.avail_in = have; \
    state.hold = hold; \
    state.bits = bits; \
    if (state.wsize || (out != strm.avail_out && state.mode < BAD &&
            (state.mode < CHECK || flush != Z_FINISH)))
        if (updatewindow(strm, strm.next_out, out - strm.avail_out)) {
            state.mode = MEM;
            return Z_MEM_ERROR;
        }
    in -= strm.avail_in;
    out -= strm.avail_out;
    strm.total_in += in;
    strm.total_out += out;
    state.total += out;
    if ((state.wrap & 4) && out)
        strm.adler = state.check =
            UPDATE(state.check, strm.next_out - out, out);
    strm.data_type = (int)state.bits + (state.last ? 64 : 0) +
                      (state.mode == TYPE ? 128 : 0) +
                      (state.mode == LEN_ || state.mode == COPY_ ? 256 : 0);
    if (((in == 0 && out == 0) || flush == Z_FINISH) && ret == Z_OK)
        ret = Z_BUF_ERROR;
    return ret;
}

local int inflateStateCheck(z_stream *  strm) {
    struct inflate_state FAR *state;
    if (strm == Z_NULL ||
        strm.zalloc == (alloc_func)0 || strm.zfree == (free_func)0)
        return 1;
    state = (struct inflate_state FAR *)strm.state;
    if (state == Z_NULL || state.strm != strm ||
        state.mode < HEAD || state.mode > SYNC)
        return 1;
    return 0;
}

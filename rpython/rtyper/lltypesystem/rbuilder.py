from rpython.rlib import rgc, jit
from rpython.rlib.objectmodel import enforceargs, dont_inline, always_inline
from rpython.rlib.rarithmetic import ovfcheck, r_uint, intmask
from rpython.rtyper.debug import ll_assert
from rpython.rlib.unroll import unrolling_iterable
from rpython.rtyper.rptr import PtrRepr
from rpython.rtyper.lltypesystem import lltype, rffi, rstr
from rpython.rtyper.lltypesystem.lltype import staticAdtMethod, nullptr
from rpython.rtyper.lltypesystem.rstr import (STR, UNICODE, char_repr,
    string_repr, unichar_repr, unicode_repr)
from rpython.rtyper.rbuilder import AbstractStringBuilderRepr
from rpython.tool.sourcetools import func_with_new_name
from rpython.rtyper.annlowlevel import llstr, llunicode



# ------------------------------------------------------------
# Basic idea:
#
# - A StringBuilder has a rstr.STR of the specified initial size
#   (100 by default), which is filled gradually.
#
# - When it is full, we allocate extra buffers as an extra rstr.STR,
#   and the already-filled one is added to a chained list of STRINGPIECE
#   objects.
#
# - At build() time, we consolidate all these pieces into a single
#   rstr.STR, which is both returned and re-attached to the StringBuilder,
#   replacing the STRINGPIECEs.
#
# - The data is copied at most twice, and only once in case it fits
#   into the initial size (and the GC supports shrinking the STR).
#
# XXX in build(), we could try keeping around a global weakref to the
# chain of STRINGPIECEs and reuse them the next time.
#
# ------------------------------------------------------------


STRINGPIECE = lltype.GcStruct('stringpiece',
    ('buf', lltype.Ptr(STR)),
    ('prev_piece', lltype.Ptr(lltype.GcForwardReference())))
STRINGPIECE.prev_piece.TO.become(STRINGPIECE)

STRINGBUILDER = lltype.GcStruct('stringbuilder',
    ('current_buf', lltype.Ptr(STR)),
    ('current_pos', lltype.Signed),
    ('current_end', lltype.Signed),
    ('total_size', lltype.Signed),
    ('extra_pieces', lltype.Ptr(STRINGPIECE)),
    adtmeths={
        'copy_string_contents': staticAdtMethod(rstr.copy_string_contents),
        'copy_raw_to_string': staticAdtMethod(rstr.copy_raw_to_string),
        'mallocfn': staticAdtMethod(rstr.mallocstr),
    }
)

UNICODEPIECE = lltype.GcStruct('unicodepiece',
    ('buf', lltype.Ptr(UNICODE)),
    ('prev_piece', lltype.Ptr(lltype.GcForwardReference())))
UNICODEPIECE.prev_piece.TO.become(UNICODEPIECE)

UNICODEBUILDER = lltype.GcStruct('unicodebuilder',
    ('current_buf', lltype.Ptr(UNICODE)),
    ('current_pos', lltype.Signed),
    ('current_end', lltype.Signed),
    ('total_size', lltype.Signed),
    ('extra_pieces', lltype.Ptr(UNICODEPIECE)),
    adtmeths={
        'copy_string_contents': staticAdtMethod(rstr.copy_unicode_contents),
        'copy_raw_to_string': staticAdtMethod(rstr.copy_raw_to_unicode),
        'mallocfn': staticAdtMethod(rstr.mallocunicode),
    }
)

# ------------------------------------------------------------
# The generic piece of code to append a string (or a slice of it)
# to a builder; it is inlined inside various functions below

@always_inline
def _ll_append(ll_builder, ll_str, start, size):
    pos = ll_builder.current_pos
    end = ll_builder.current_end
    if (end - pos) < size:
        ll_grow_and_append(ll_builder, ll_str, start, size)
    else:
        ll_builder.current_pos = pos + size
        ll_builder.copy_string_contents(ll_str, ll_builder.current_buf,
                                        start, pos, size)

# ------------------------------------------------------------
# Logic to grow a builder (by adding a new string to it)

@dont_inline
@enforceargs(None, int)
def ll_grow_by(ll_builder, needed):
    try:
        needed = ovfcheck(needed + ll_builder.total_size)
        needed = ovfcheck(needed + 63) & ~63
        total_size = ovfcheck(ll_builder.total_size + needed)
    except OverflowError:
        raise MemoryError
    #
    new_string = ll_builder.mallocfn(needed)
    #
    PIECE = lltype.typeOf(ll_builder.extra_pieces).TO
    old_piece = lltype.malloc(PIECE)
    old_piece.buf = ll_builder.current_buf
    old_piece.prev_piece = ll_builder.extra_pieces
    ll_assert(bool(old_piece.buf), "no buf??")
    ll_builder.current_buf = new_string
    ll_builder.current_pos = 0
    ll_builder.current_end = needed
    ll_builder.total_size = total_size
    ll_builder.extra_pieces = old_piece

@dont_inline
def ll_grow_and_append(ll_builder, ll_str, start, size):
    # A fast-path, meant for builders that only receive a single big
    # string before build() is called.  Also works in some other cases.
    if (size > 1280 and ll_builder.current_pos == 0
                    and start == 0 and size == len(ll_str.chars)):
        try:
            total_size = ovfcheck(ll_builder.total_size + size)
        except OverflowError:
            pass
        else:
            PIECE = lltype.typeOf(ll_builder.extra_pieces).TO
            old_piece = lltype.malloc(PIECE)
            old_piece.buf = ll_str
            old_piece.prev_piece = ll_builder.extra_pieces
            ll_builder.total_size = total_size
            ll_builder.extra_pieces = old_piece
            return

    # First, the part that still fits in the current piece
    part1 = ll_builder.current_end - ll_builder.current_pos
    ll_assert(part1 < size, "part1 >= size")
    ll_builder.copy_string_contents(ll_str, ll_builder.current_buf,
                                    start, ll_builder.current_pos,
                                    part1)
    start += part1
    size -= part1
    # Allocate the new piece
    ll_grow_by(ll_builder, size)
    ll_assert(ll_builder.current_pos == 0, "current_pos must be 0 after grow()")
    # Finally, the second part of the string
    ll_builder.current_pos = size
    ll_builder.copy_string_contents(ll_str, ll_builder.current_buf,
                                    start, 0, size)

# ------------------------------------------------------------
# builder.append()

@always_inline
def ll_append(ll_builder, ll_str):
    if jit.we_are_jitted():
        ll_jit_append(ll_builder, ll_str)
    else:
        # no-jit case: inline the logic of _ll_append() in the caller
        _ll_append(ll_builder, ll_str, 0, len(ll_str.chars))

@dont_inline
def ll_jit_append(ll_builder, ll_str):
    # jit case: first try special cases for known small lengths
    if ll_jit_try_append_slice(ll_builder, ll_str, 0, len(ll_str.chars)):
        return
    # fall-back to do a residual call to ll_append_res0
    ll_append_res0(ll_builder, ll_str)

@jit.dont_look_inside
def ll_append_res0(ll_builder, ll_str):
    _ll_append(ll_builder, ll_str, 0, len(ll_str.chars))

# ------------------------------------------------------------
# builder.append_char()

@always_inline
def ll_append_char(ll_builder, char):
    jit.conditional_call(ll_builder.current_pos == ll_builder.current_end,
                         ll_grow_by, ll_builder, 1)
    pos = ll_builder.current_pos
    ll_builder.current_pos = pos + 1
    ll_builder.current_buf.chars[pos] = char

# ------------------------------------------------------------
# builder.append_slice()

@always_inline
def ll_append_slice(ll_builder, ll_str, start, end):
    if jit.we_are_jitted():
        ll_jit_append_slice(ll_builder, ll_str, start, end)
    else:
        # no-jit case: inline the logic of _ll_append() in the caller
        _ll_append(ll_builder, ll_str, start, end - start)

@dont_inline
def ll_jit_append_slice(ll_builder, ll_str, start, end):
    # jit case: first try special cases for known small lengths
    if ll_jit_try_append_slice(ll_builder, ll_str, start, end - start):
        return
    # fall-back to do a residual call to ll_append_res_slice
    ll_append_res_slice(ll_builder, ll_str, start, end)

@jit.dont_look_inside
def ll_append_res_slice(ll_builder, ll_str, start, end):
    _ll_append(ll_builder, ll_str, start, end - start)

# ------------------------------------------------------------
# Special-casing for the JIT: appending strings (or slices) of
# a known length up to MAX_N.  These functions all contain an
# inlined copy of _ll_append(), but with a known small N, gcc
# will compile the copy_string_contents() efficiently.

MAX_N = 10

def make_func_for_size(N):
    @jit.dont_look_inside
    def ll_append_0(ll_builder, ll_str):
        _ll_append(ll_builder, ll_str, 0, N)
    ll_append_0 = func_with_new_name(ll_append_0, "ll_append_0_%d" % N)
    #
    @jit.dont_look_inside
    def ll_append_start(ll_builder, ll_str, start):
        _ll_append(ll_builder, ll_str, start, N)
    ll_append_start = func_with_new_name(ll_append_start,
                                                  "ll_append_start_%d" % N)
    return ll_append_0, ll_append_start, N

unroll_func_for_size = unrolling_iterable([make_func_for_size(_n)
                                           for _n in range(2, MAX_N + 1)])

@jit.unroll_safe
def ll_jit_try_append_slice(ll_builder, ll_str, start, size):
    if jit.isconstant(size):
        if size == 0:
            return True
        # a special case: if the builder's pos and end are still contants
        # (typically if the builder is still virtual), and if 'size' fits,
        # then we don't need any reallocation and can just set the
        # characters in the buffer, in a way that won't force anything.
        if (jit.isconstant(ll_builder.current_pos) and
            jit.isconstant(ll_builder.current_end) and
            size <= (ll_builder.current_end - ll_builder.current_pos) and
            size <= 16):
            pos = ll_builder.current_pos
            buf = ll_builder.current_buf
            stop = pos + size
            ll_builder.current_pos = stop
            while pos < stop:
                buf.chars[pos] = ll_str.chars[start]
                pos += 1
                start += 1
            return True
        # turn appends of length 1 into ll_append_char().
        if size == 1:
            ll_append_char(ll_builder, ll_str.chars[start])
            return True
        # turn appends of length 2 to 10 into residual calls to
        # specialized functions, for the lengths 2 to 10, where
        # gcc will optimize the known-length copy_string_contents()
        # as much as possible.
        for func0, funcstart, for_size in unroll_func_for_size:
            if size == for_size:
                if jit.isconstant(start) and start == 0:
                    func0(ll_builder, ll_str)
                else:
                    funcstart(ll_builder, ll_str, start)
                return True
    return False     # use the fall-back path

# ------------------------------------------------------------
# builder.append_multiple_char()

@always_inline
def ll_append_multiple_char(ll_builder, char, times):
    if jit.we_are_jitted():
        if ll_jit_try_append_multiple_char(ll_builder, char, times):
            return
    _ll_append_multiple_char(ll_builder, char, times)

@jit.dont_look_inside
def _ll_append_multiple_char(ll_builder, char, times):
    part1 = ll_builder.current_end - ll_builder.current_pos
    if times > part1:
        times -= part1
        buf = ll_builder.current_buf
        for i in xrange(ll_builder.current_pos, ll_builder.current_end):
            buf.chars[i] = char
        ll_grow_by(ll_builder, times)
    #
    buf = ll_builder.current_buf
    pos = ll_builder.current_pos
    end = pos + times
    ll_builder.current_pos = end
    for i in xrange(pos, end):
        buf.chars[i] = char

@jit.unroll_safe
def ll_jit_try_append_multiple_char(ll_builder, char, size):
    if jit.isconstant(size):
        if size == 0:
            return True
        # a special case: if the builder's pos and end are still contants
        # (typically if the builder is still virtual), and if 'size' fits,
        # then we don't need any reallocation and can just set the
        # characters in the buffer, in a way that won't force anything.
        if (jit.isconstant(ll_builder.current_pos) and
            jit.isconstant(ll_builder.current_end) and
            size <= (ll_builder.current_end - ll_builder.current_pos) and
            size <= 16):
            pos = ll_builder.current_pos
            buf = ll_builder.current_buf
            stop = pos + size
            ll_builder.current_pos = stop
            while pos < stop:
                buf.chars[pos] = char
                pos += 1
            return True
        if size == 1:
            ll_append_char(ll_builder, char)
            return True
    return False     # use the fall-back path

# ------------------------------------------------------------
# builder.append_charpsize()

@jit.dont_look_inside
def ll_append_charpsize(ll_builder, charp, size):
    part1 = ll_builder.current_end - ll_builder.current_pos
    if size > part1:
        # First, the part that still fits
        ll_builder.copy_raw_to_string(charp, ll_builder.current_buf,
                                      ll_builder.current_pos, part1)
        charp = rffi.ptradd(charp, part1)
        size -= part1
        ll_grow_by(ll_builder, size)
    #
    pos = ll_builder.current_pos
    ll_builder.current_pos = pos + size
    ll_builder.copy_raw_to_string(charp, ll_builder.current_buf, pos, size)

# ------------------------------------------------------------
# builder.getlength()

@always_inline
def ll_getlength(ll_builder):
    num_chars_missing_from_last_piece = (
        ll_builder.current_end - ll_builder.current_pos)
    return ll_builder.total_size - num_chars_missing_from_last_piece

# ------------------------------------------------------------
# builder.build()

@jit.look_inside_iff(lambda ll_builder: jit.isvirtual(ll_builder))
def ll_build(ll_builder):
    # NB. usually the JIT doesn't look inside this function; it does
    # so only in the simplest example where it could virtualize everything
    if ll_builder.extra_pieces:
        ll_fold_pieces(ll_builder)
    elif ll_builder.current_pos != ll_builder.total_size:
        ll_shrink_final(ll_builder)
    return ll_builder.current_buf

def ll_shrink_final(ll_builder):
    final_size = ll_builder.current_pos
    ll_assert(final_size <= ll_builder.total_size,
              "final_size > ll_builder.total_size?")
    buf = rgc.ll_shrink_array(ll_builder.current_buf, final_size)
    ll_builder.current_buf = buf
    ll_builder.current_end = final_size
    ll_builder.total_size = final_size

def ll_fold_pieces(ll_builder):
    final_size = BaseStringBuilderRepr.ll_getlength(ll_builder)
    ll_assert(final_size >= 0, "negative final_size")
    extra = ll_builder.extra_pieces
    ll_builder.extra_pieces = lltype.nullptr(lltype.typeOf(extra).TO)
    #
    # A fast-path if the builder contains exactly one big piece:
    # discard the allocated current_buf and put the big piece there
    if ll_builder.current_pos == 0 and not extra.prev_piece:
        piece = extra.buf
        ll_assert(final_size == len(piece.chars),
                  "bogus final_size in fold_pieces")
        ll_builder.total_size = final_size
        ll_builder.current_buf = piece
        ll_builder.current_pos = final_size
        ll_builder.current_end = final_size
        return
    #
    result = ll_builder.mallocfn(final_size)
    piece = ll_builder.current_buf
    piece_lgt = ll_builder.current_pos
    ll_assert(ll_builder.current_end == len(piece.chars),
              "bogus last piece_lgt")
    ll_builder.total_size = final_size
    ll_builder.current_buf = result
    ll_builder.current_pos = final_size
    ll_builder.current_end = final_size

    dst = final_size
    while True:
        dst -= piece_lgt
        ll_assert(dst >= 0, "rbuilder build: overflow")
        ll_builder.copy_string_contents(piece, result, 0, dst, piece_lgt)
        if not extra:
            break
        piece = extra.buf
        piece_lgt = len(piece.chars)
        extra = extra.prev_piece
    ll_assert(dst == 0, "rbuilder build: underflow")

# ------------------------------------------------------------
# bool(builder)

def ll_bool(ll_builder):
    return ll_builder != nullptr(lltype.typeOf(ll_builder).TO)

# ------------------------------------------------------------

class BaseStringBuilderRepr(AbstractStringBuilderRepr):
    def empty(self):
        return nullptr(self.lowleveltype.TO)

    ll_append               = staticmethod(ll_append)
    ll_append_char          = staticmethod(ll_append_char)
    ll_append_slice         = staticmethod(ll_append_slice)
    ll_append_multiple_char = staticmethod(ll_append_multiple_char)
    ll_append_charpsize     = staticmethod(ll_append_charpsize)
    ll_getlength            = staticmethod(ll_getlength)
    ll_build                = staticmethod(ll_build)
    ll_bool                 = staticmethod(ll_bool)

class StringBuilderRepr(BaseStringBuilderRepr):
    lowleveltype = lltype.Ptr(STRINGBUILDER)
    basetp = STR
    convert_to_ll = staticmethod(llstr)
    string_repr = string_repr
    char_repr = char_repr
    raw_ptr_repr = PtrRepr(
        lltype.Ptr(lltype.Array(lltype.Char, hints={'nolength': True}))
    )

    @staticmethod
    def ll_new(init_size):
        # Clamp 'init_size' to be a value between 0 and 1280.
        # Negative values are mapped to 1280.
        init_size = intmask(min(r_uint(init_size), r_uint(1280)))
        ll_builder = lltype.malloc(STRINGBUILDER)
        ll_builder.current_buf = ll_builder.mallocfn(init_size)
        ll_builder.current_pos = 0
        ll_builder.current_end = init_size
        ll_builder.total_size = init_size
        return ll_builder


class UnicodeBuilderRepr(BaseStringBuilderRepr):
    lowleveltype = lltype.Ptr(UNICODEBUILDER)
    basetp = UNICODE
    convert_to_ll = staticmethod(llunicode)
    string_repr = unicode_repr
    char_repr = unichar_repr
    raw_ptr_repr = PtrRepr(
        lltype.Ptr(lltype.Array(lltype.UniChar, hints={'nolength': True}))
    )

    @staticmethod
    def ll_new(init_size):
        # Clamp 'init_size' to be a value between 0 and 1280.
        # Negative values are mapped to 1280.
        init_size = intmask(min(r_uint(init_size), r_uint(1280)))
        ll_builder = lltype.malloc(UNICODEBUILDER)
        ll_builder.current_buf = ll_builder.mallocfn(init_size)
        ll_builder.current_pos = 0
        ll_builder.current_end = init_size
        ll_builder.total_size = init_size
        return ll_builder


unicodebuilder_repr = UnicodeBuilderRepr()
stringbuilder_repr = StringBuilderRepr()

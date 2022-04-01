import sys
from rpython.rlib.debug import check_nonneg
from rpython.rlib.rsre.rsre_core import AbstractMatchContext, EndOfString
from rpython.rlib.rsre import rsre_char
from rpython.rlib.objectmodel import we_are_translated
from rpython.rlib import rutf8


class Utf8MatchContext(AbstractMatchContext):
    """A context that matches unicode, but encoded in a utf8 string.
    Be careful because most positions taken by, handled in, and returned
    by this class are expressed in *bytes*, not in characters.
    """

    def __init__(self, utf8string, match_start, end):
        AbstractMatchContext.__init__(self, match_start, end)
        self._utf8 = utf8string

    def str(self, index):
        check_nonneg(index)
        return rutf8.codepoint_at_pos(self._utf8, index)

    def get_single_byte(self, base_position, index):
        return self._utf8[base_position + index]

    def next(self, position):
        return rutf8.next_codepoint_pos(self._utf8, position)
    next_indirect = next

    def prev(self, position):
        if position <= 0:
            raise EndOfString
        position = rutf8.prev_codepoint_pos(self._utf8, position)
        assert position >= 0
        return position
    prev_indirect = prev

    def next_n(self, position, n, end_position):
        i = 0
        # avoid range(n) since n can be quite large
        while i < n:
            if position >= end_position:
                raise EndOfString
            position = rutf8.next_codepoint_pos(self._utf8, position)
            i += 1
        return position

    def prev_n(self, position, n, start_position):
        i = 0
        # avoid range(n) since n can be quite large
        while i < n:
            if position <= start_position:
                raise EndOfString
            position = rutf8.prev_codepoint_pos(self._utf8, position)
            i += 1
        assert position >= 0
        return position

    def debug_check_pos(self, position):
        if we_are_translated():
            return
        if position == len(self._utf8):
            return   # end of string is fine
        assert not (0x80 <= self._utf8[position] < 0xC0)   # continuation byte

    def maximum_distance(self, position_low, position_high):
        # may overestimate if there are non-ascii chars
        return position_high - position_low


def make_utf8_ctx(utf8string, bytestart, byteend):
    if bytestart < 0: bytestart = 0
    elif bytestart > len(utf8string): bytestart = len(utf8string)
    if byteend < 0: byteend = 0
    elif byteend > len(utf8string): byteend = len(utf8string)
    ctx = Utf8MatchContext(utf8string, bytestart, byteend)
    ctx.debug_check_pos(bytestart)
    ctx.debug_check_pos(byteend)
    return ctx

def utf8search(pattern, utf8string, bytestart=0, byteend=sys.maxint):
    # bytestart and byteend must be valid byte positions inside the
    # utf8string.
    from rpython.rlib.rsre.rsre_core import search_context

    ctx = make_utf8_ctx(utf8string, bytestart, byteend)
    if search_context(ctx, pattern):
        return ctx
    else:
        return None

def utf8match(pattern, utf8string, bytestart=0, byteend=sys.maxint,
              fullmatch=False):
    # bytestart and byteend must be valid byte positions inside the
    # utf8string.
    from rpython.rlib.rsre.rsre_core import match_context, MODE_FULL

    ctx = make_utf8_ctx(utf8string, bytestart, byteend)
    if fullmatch:
        ctx.match_mode = MODE_FULL
    if match_context(ctx, pattern):
        return ctx
    else:
        return None

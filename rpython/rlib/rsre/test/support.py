import sys, random
from rpython.rlib import debug
from rpython.rlib.rsre.rsre_core import _adjust, match_context, search_context
from rpython.rlib.rsre.rsre_core import MODE_FULL
from rpython.rlib.rsre.rsre_core import StrMatchContext, EndOfString


class Position(object):
    def __init__(self, p):
        assert isinstance(p, int)
        if p < 0:
            raise debug.NegativeArgumentNotAllowed(
                "making a Position with byte index %r" % p)
        self._p = p
    def __repr__(self):
        return '<Position %d>' % (self._p)
    def __cmp__(self, other):
        if isinstance(other, Position):
            return cmp(self._p, other._p)
        if type(other) is int and other == -1:
            return cmp(self._p, -1)
        raise TypeError("cannot compare %r with %r" % (self, other))


class MatchContextForTests(StrMatchContext):
    """Concrete subclass for matching in a plain string, tweaked for tests"""

    ZERO = Position(0)

    def next(self, position):
        assert isinstance(position, Position)
        return Position(position._p + 1)
    next_indirect = next

    def prev(self, position):
        assert isinstance(position, Position)
        if position._p == 0:
            raise EndOfString
        return Position(position._p - 1)
    prev_indirect = prev

    def next_n(self, position, n, end_position):
        assert isinstance(position, Position)
        assert isinstance(end_position, Position)
        assert position._p <= end_position._p
        r = position._p + n
        if r > end_position._p:
            raise EndOfString
        return Position(r)

    def prev_n(self, position, n, start_position):
        assert isinstance(position, Position)
        assert isinstance(start_position, Position)
        assert position._p >= start_position._p
        r = position._p - n
        if r < start_position._p:
            raise EndOfString
        return Position(r)

    def _real_pos(self, position):
        if type(position) is int and position == -1:
            return -1
        assert isinstance(position, Position)
        return position._p

    def group(self, groupnum=0):
        frm, to = self.span(groupnum)
        if self.ZERO <= frm <= to:
            return self._string[self._real_pos(frm):self._real_pos(to)]
        else:
            return None

    def str(self, position):
        assert isinstance(position, Position)
        return ord(self._string[position._p])

    def debug_check_pos(self, position):
        assert isinstance(position, Position)

    #def minimum_distance(self, position_low, position_high):
    #    """Return an estimate.  The real value may be higher."""
    #    assert isinstance(position_low, Position)
    #    assert isinstance(position_high, Position)
    #    dist = position_high._p - position_low._p
    #    if dist == 0:
    #        return 0
    #    return random.randrange(1, dist + 1)

    def maximum_distance(self, position_low, position_high):
        """Return an estimate.  The real value may be lower."""
        assert isinstance(position_low, Position)
        assert isinstance(position_high, Position)
        return position_high._p - position_low._p + random.randrange(0, 10)

    def bytes_difference(self, position1, position2):
        assert isinstance(position1, Position)
        assert isinstance(position2, Position)
        return position1._p - position2._p

    def get_single_byte(self, base_position, index):
        assert isinstance(base_position, Position)
        assert isinstance(index, int)
        return ord(self._string[base_position._p + index])

    def go_forward_by_bytes(self, base_position, index):
        assert isinstance(base_position, Position)
        assert isinstance(index, int)
        return Position(base_position._p + index)


def match(pattern, string, start=0, end=sys.maxint, fullmatch=False):
    start, end = _adjust(start, end, len(string))
    start = Position(start)
    end = Position(end)
    ctx = MatchContextForTests(string, start, end)
    if fullmatch:
        ctx.match_mode = MODE_FULL
    if match_context(ctx, pattern):
        return ctx
    else:
        return None

def fullmatch(pattern, string, start=0, end=sys.maxint):
    return match(pattern, string, start, end, fullmatch=True)

def search(pattern, string, start=0, end=sys.maxint):
    start, end = _adjust(start, end, len(string))
    start = Position(start)
    end = Position(end)
    ctx = MatchContextForTests(string, start, end)
    if search_context(ctx, pattern):
        return ctx
    else:
        return None

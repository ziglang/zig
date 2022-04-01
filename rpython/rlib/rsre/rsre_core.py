import sys
from rpython.rlib.debug import check_nonneg
from rpython.rlib.unroll import unrolling_iterable
from rpython.rlib.rsre import rsre_char, rsre_constants as consts
from rpython.tool.sourcetools import func_with_new_name
from rpython.rlib.objectmodel import we_are_translated, not_rpython
from rpython.rlib import jit
from rpython.rlib.rsre.rsre_jit import install_jitdriver, install_jitdriver_spec

_seen_specname = {}

def specializectx(func):
    """A decorator that specializes 'func(ctx,...)' for each concrete subclass
    of AbstractMatchContext.  During annotation, if 'ctx' is known to be a
    specific subclass, calling 'func' is a direct call; if 'ctx' is only known
    to be of class AbstractMatchContext, calling 'func' is an indirect call.
    """
    from rpython.rlib.rsre.rsre_utf8 import Utf8MatchContext

    assert func.__code__.co_varnames[0] == 'ctx'
    specname = '_spec_' + func.__name__
    while specname in _seen_specname:
        specname += '_'
    _seen_specname[specname] = True
    # Install a copy of the function under the name '_spec_funcname' in each
    # concrete subclass
    specialized_methods = []
    for prefix, concreteclass in [('buf', BufMatchContext),
                                  ('str', StrMatchContext),
                                  ('uni', UnicodeMatchContext),
                                  ('utf8', Utf8MatchContext),
                                  ]:
        newfunc = func_with_new_name(func, prefix + specname)
        assert not hasattr(concreteclass, specname)
        setattr(concreteclass, specname, newfunc)
        specialized_methods.append(newfunc)
    # Return a dispatcher function, specialized on the exact type of 'ctx'
    def dispatch(ctx, *args):
        return getattr(ctx, specname)(*args)
    dispatch._annspecialcase_ = 'specialize:argtype(0)'
    dispatch._specialized_methods_ = specialized_methods
    return func_with_new_name(dispatch, specname)

# ____________________________________________________________

class Error(Exception):
    def __init__(self, msg):
        self.msg = msg

class EndOfString(Exception):
    pass

class CompiledPattern(object):
    _immutable_fields_ = ['pattern[*]', 'flags']

    def __init__(self, pattern, flags):
        self.pattern = pattern
        if not consts.V37:      # 'flags' is ignored in >=3.7 mode
            self.flags = flags
        # check we don't get the old value of MAXREPEAT
        # during the untranslated tests. 
        # On python3, MAXCODE can appear in patterns. It will be 65535
        # when CODESIZE is 2
        if not we_are_translated() and rsre_char.CODESIZE != 2:
            assert 65535 not in pattern

    def lowa(self, char_ord):
        """Pre-3.7: uses getlower(flags).
           Post-3.7: this is always getlower_ascii().
        """
        if not consts.V37:
            return rsre_char.getlower(char_ord, self.flags)
        else:
            return rsre_char.getlower_ascii(char_ord)

    def char_loc_ignore(self, index, char_ord):
        assert consts.V37
        pattern = self.pat(index)
        return (char_ord == pattern or
                rsre_char.getlower_locale(char_ord) == pattern or
                rsre_char.getupper_locale(char_ord) == pattern)

    def charset_loc_ignore(self, ctx, ppos, char_ord):
        lo = rsre_char.getlower_locale(char_ord)
        if rsre_char.check_charset(ctx, self, ppos, lo):
            return True
        up = rsre_char.getupper_locale(char_ord)
        return up != lo and rsre_char.check_charset(ctx, self, ppos, up)

    def pat(self, index):
        jit.promote(self)
        check_nonneg(index)
        result = self.pattern[index]
        # Check that we only return non-negative integers from this helper.
        # It is possible that self.pattern contains negative integers
        # (see set_charset() and set_bigcharset() in rsre_char.py)
        # but they should not be fetched via this helper here.
        assert result >= 0
        return result

MODE_ANY = '\x00'         # an empty match is fine
MODE_NONEMPTY = '\x01'    # must have a non-empty match
MODE_FULL = '\x02'        # must match the whole string

class AbstractMatchContext(object):
    """Abstract base class"""
    _immutable_fields_ = ['end']
    match_start = 0
    match_end = 0
    match_marks = None
    match_marks_flat = None
    match_mode = MODE_ANY

    def __init__(self, match_start, end):
        # 'match_start' and 'end' must be known to be non-negative
        # and they must not be more than len(string).
        check_nonneg(match_start)
        check_nonneg(end)
        self.match_start = match_start
        self.end = end

    def reset(self, start, must_advance=False):
        self.match_start = start
        self.match_marks = None
        self.match_marks_flat = None
        #
        assert MODE_ANY == chr(False)
        assert MODE_NONEMPTY == chr(True)
        self.match_mode = chr(must_advance)

    @not_rpython
    def _fullmatch_only(self, x=None):
        raise Exception("'ctx.fullmatch_only' was replaced with"
                        " 'ctx.match_mode'")
    fullmatch_only = property(_fullmatch_only, _fullmatch_only)

    @not_rpython
    def str(self, index):
        """Must be overridden in a concrete subclass.
        The @not_rpython is used to generate a translation-time crash
        if there is a call to str() that is indirect.  All calls must
        be direct for performance reasons; you need to specialize the
        caller with @specializectx."""
        raise NotImplementedError

    # The following methods are provided to be overriden in
    # Utf8MatchContext.  The non-utf8 implementation is provided
    # by the FixedMatchContext abstract subclass, in order to use
    # the same @not_rpython safety trick as above.  If you get a
    # "not_rpython" error during translation, either consider
    # calling the methods xxx_indirect() instead of xxx(), or if
    # applicable add the @specializectx decorator.
    ZERO = 0
    @not_rpython
    def next(self, position):
        raise NotImplementedError
    @not_rpython
    def prev(self, position):
        raise NotImplementedError
    @not_rpython
    def next_n(self, position, n):
        raise NotImplementedError
    @not_rpython
    def prev_n(self, position, n, start_position):
        raise NotImplementedError
    @not_rpython
    def debug_check_pos(self, position):
        raise NotImplementedError
    @not_rpython
    def maximum_distance(self, position_low, position_high):
        raise NotImplementedError
    @not_rpython
    def get_single_byte(self, base_position, index):
        raise NotImplementedError

    def bytes_difference(self, position1, position2):
        return position1 - position2
    def go_forward_by_bytes(self, base_position, index):
        return base_position + index
    def next_indirect(self, position):
        assert position < self.end
        return position + 1     # like next(), but can be called indirectly
    def prev_indirect(self, position):
        position -= 1           # like prev(), but can be called indirectly
        if position < 0:
            raise EndOfString
        return position

    def get_mark(self, gid):
        return find_mark(self.match_marks, gid)

    def flatten_marks(self):
        # for testing
        if self.match_marks_flat is None:
            self._compute_flattened_marks()
        return self.match_marks_flat

    def _compute_flattened_marks(self):
        self.match_marks_flat = [self.match_start, self.match_end]
        mark = self.match_marks
        if mark is not None:
            self.match_lastindex = mark.gid
        else:
            self.match_lastindex = -1
        while mark is not None:
            index = mark.gid + 2
            while index >= len(self.match_marks_flat):
                self.match_marks_flat.append(-1)
            if self.match_marks_flat[index] == -1:
                self.match_marks_flat[index] = mark.position
            mark = mark.prev
        self.match_marks = None    # clear

    def span(self, groupnum=0):
        # compatibility
        fmarks = self.flatten_marks()
        groupnum *= 2
        if groupnum >= len(fmarks):
            return (-1, -1)
        return (fmarks[groupnum], fmarks[groupnum+1])

    def group(self, groupnum=0):
        frm, to = self.span(groupnum)
        if 0 <= frm <= to:
            return self._string[frm:to]
        else:
            return None

    def fresh_copy(self, start):
        raise NotImplementedError

class FixedMatchContext(AbstractMatchContext):
    """Abstract subclass to introduce the default implementation for
    these position methods.  The Utf8MatchContext subclass doesn't
    inherit from here."""

    next = AbstractMatchContext.next_indirect
    prev = AbstractMatchContext.prev_indirect

    def next_n(self, position, n, end_position):
        position += n
        if position > end_position:
            raise EndOfString
        return position

    def prev_n(self, position, n, start_position):
        position -= n
        if position < start_position:
            raise EndOfString
        return position

    def debug_check_pos(self, position):
        pass

    def maximum_distance(self, position_low, position_high):
        return position_high - position_low


class BufMatchContext(FixedMatchContext):
    """Concrete subclass for matching in a buffer."""

    _immutable_fields_ = ["_buffer"]

    def __init__(self, buf, match_start, end):
        FixedMatchContext.__init__(self, match_start, end)
        self._buffer = buf

    def str(self, index):
        check_nonneg(index)
        return ord(self._buffer.getitem(index))

    def fresh_copy(self, start):
        return BufMatchContext(self._buffer, start,
                               self.end)

    def get_single_byte(self, base_position, index):
        return self.str(base_position + index)


class StrMatchContext(FixedMatchContext):
    """Concrete subclass for matching in a plain string."""

    _immutable_fields_ = ["_string"]

    def __init__(self, string, match_start, end):
        FixedMatchContext.__init__(self, match_start, end)
        self._string = string

    def str(self, index):
        check_nonneg(index)
        return ord(self._string[index])

    def fresh_copy(self, start):
        return StrMatchContext(self._string, start,
                               self.end)

    def get_single_byte(self, base_position, index):
        return self.str(base_position + index)

    def _real_pos(self, index):
        return index     # overridden by tests


class UnicodeMatchContext(FixedMatchContext):
    """Concrete subclass for matching in a unicode string."""

    _immutable_fields_ = ["_unicodestr"]

    def __init__(self, unicodestr, match_start, end):
        FixedMatchContext.__init__(self, match_start, end)
        self._unicodestr = unicodestr

    def str(self, index):
        check_nonneg(index)
        return ord(self._unicodestr[index])

    def fresh_copy(self, start):
        return UnicodeMatchContext(self._unicodestr, start,
                                   self.end)

    def get_single_byte(self, base_position, index):
        return self.str(base_position + index)

# ____________________________________________________________

class Mark(object):
    _immutable_ = True

    def __init__(self, gid, position, prev):
        self.gid = gid
        self.position = position
        self.prev = prev      # chained list

def find_mark(mark, gid):
    while mark is not None:
        if mark.gid == gid:
            return mark.position
        mark = mark.prev
    return -1

# ____________________________________________________________

class MatchResult(object):
    subresult = None

    def move_to_next_result(self, ctx, pattern):
        # returns either 'self' or None
        result = self.subresult
        if result is None:
            return
        if result.move_to_next_result(ctx, pattern):
            return self
        return self.find_next_result(ctx, pattern)

    def find_next_result(self, ctx, pattern):
        raise NotImplementedError

MATCHED_OK = MatchResult()

class BranchMatchResult(MatchResult):

    def __init__(self, ppos, ptr, marks):
        self.ppos = ppos
        self.start_ptr = ptr
        self.start_marks = marks

    @jit.unroll_safe
    def find_first_result(self, ctx, pattern):
        ppos = jit.hint(self.ppos, promote=True)
        while pattern.pat(ppos):
            result = sre_match(ctx, pattern, ppos + 1, self.start_ptr, self.start_marks)
            ppos += pattern.pat(ppos)
            if result is not None:
                self.subresult = result
                self.ppos = ppos
                return self
    find_next_result = find_first_result

class RepeatOneMatchResult(MatchResult):
    install_jitdriver('RepeatOne',
                      greens=['nextppos', 'pattern'],
                      reds=['ptr', 'self', 'ctx'],
                      debugprint=(1, 0))   # indices in 'greens'

    def __init__(self, nextppos, minptr, ptr, marks):
        self.nextppos = nextppos
        self.minptr = minptr
        self.start_ptr = ptr
        self.start_marks = marks

    def find_first_result(self, ctx, pattern):
        ptr = self.start_ptr
        nextppos = self.nextppos
        while ptr >= self.minptr:
            ctx.jitdriver_RepeatOne.jit_merge_point(
                self=self, ptr=ptr, ctx=ctx, nextppos=nextppos,
                pattern=pattern)
            result = sre_match(ctx, pattern, nextppos, ptr, self.start_marks)
            try:
                ptr = ctx.prev_indirect(ptr)
            except EndOfString:
                ptr = -1
            if result is not None:
                self.subresult = result
                self.start_ptr = ptr
                return self
    find_next_result = find_first_result


class MinRepeatOneMatchResult(MatchResult):
    install_jitdriver('MinRepeatOne',
                      greens=['nextppos', 'ppos3', 'pattern'],
                      reds=['max_count', 'ptr', 'self', 'ctx'],
                      debugprint=(2, 0))   # indices in 'greens'

    def __init__(self, nextppos, ppos3, max_count, ptr, marks):
        self.nextppos = nextppos
        self.ppos3 = ppos3
        self.max_count = max_count
        self.start_ptr = ptr
        self.start_marks = marks

    def find_first_result(self, ctx, pattern):
        ptr = self.start_ptr
        nextppos = self.nextppos
        max_count = self.max_count
        ppos3 = self.ppos3
        while max_count >= 0:
            ctx.jitdriver_MinRepeatOne.jit_merge_point(
                self=self, ptr=ptr, ctx=ctx, nextppos=nextppos, ppos3=ppos3,
                max_count=max_count, pattern=pattern)
            result = sre_match(ctx, pattern, nextppos, ptr, self.start_marks)
            if result is not None:
                self.subresult = result
                self.start_ptr = ptr
                self.max_count = max_count
                return self
            if not self.next_char_ok(ctx, pattern, ptr, ppos3):
                break
            ptr = ctx.next_indirect(ptr)
            max_count -= 1

    def find_next_result(self, ctx, pattern):
        ptr = self.start_ptr
        if not self.next_char_ok(ctx, pattern, ptr, self.ppos3):
            return
        self.start_ptr = ctx.next_indirect(ptr)
        return self.find_first_result(ctx, pattern)

    def next_char_ok(self, ctx, pattern, ptr, ppos):
        if ptr == ctx.end:
            return False
        op = pattern.pat(ppos)
        for op1, checkerfn in unroll_char_checker:
            if op1 == op:
                return checkerfn(ctx, pattern, ptr, ppos)
        # obscure case: it should be a single char pattern, but isn't
        # one of the opcodes in unroll_char_checker (see test_ext_opcode)
        return sre_match(ctx, pattern, ppos, ptr, self.start_marks) is not None

class AbstractUntilMatchResult(MatchResult):

    def __init__(self, ppos, tailppos, ptr, marks):
        self.ppos = ppos
        self.tailppos = tailppos
        self.cur_ptr = ptr
        self.cur_marks = marks
        self.pending = None
        self.num_pending = 0

class Pending(object):
    def __init__(self, ptr, marks, enum, next):
        self.ptr = ptr
        self.marks = marks
        self.enum = enum
        self.next = next     # chained list

class MaxUntilMatchResult(AbstractUntilMatchResult):
    install_jitdriver('MaxUntil',
                      greens=['ppos', 'tailppos', 'match_more', 'pattern'],
                      reds=['ptr', 'marks', 'self', 'ctx'],
                      debugprint=(3, 0, 2))

    def find_first_result(self, ctx, pattern):
        return self.search_next(ctx, pattern, match_more=True)

    def find_next_result(self, ctx, pattern):
        return self.search_next(ctx, pattern, match_more=False)

    def search_next(self, ctx, pattern, match_more):
        ppos = self.ppos
        tailppos = self.tailppos
        ptr = self.cur_ptr
        marks = self.cur_marks
        while True:
            ctx.jitdriver_MaxUntil.jit_merge_point(
                ppos=ppos, tailppos=tailppos, match_more=match_more,
                ptr=ptr, marks=marks, self=self, ctx=ctx,
                pattern=pattern)
            if match_more:
                max = pattern.pat(ppos+2)
                if max == rsre_char.MAXREPEAT or self.num_pending < max:
                    # try to match one more 'item'
                    enum = sre_match(ctx, pattern, ppos + 3, ptr, marks)
                else:
                    enum = None    # 'max' reached, no more matches
            else:
                p = self.pending
                if p is None:
                    return
                self.pending = p.next
                self.num_pending -= 1
                ptr = p.ptr
                marks = p.marks
                enum = p.enum.move_to_next_result(ctx, pattern)
            #
            min = pattern.pat(ppos+1)
            if enum is not None:
                # matched one more 'item'.  record it and continue.
                last_match_zero_length = (ctx.match_end == ptr)
                self.pending = Pending(ptr, marks, enum, self.pending)
                self.num_pending += 1
                ptr = ctx.match_end
                marks = ctx.match_marks
                if last_match_zero_length and self.num_pending >= min:
                    # zero-width protection: after an empty match, if there
                    # are enough matches, don't try to match more.  Instead,
                    # fall through to trying to match 'tail'.
                    pass
                else:
                    match_more = True
                    continue

            # 'item' no longer matches.
            if self.num_pending >= min:
                # try to match 'tail' if we have enough 'item'
                result = sre_match(ctx, pattern, tailppos, ptr, marks)
                if result is not None:
                    self.subresult = result
                    self.cur_ptr = ptr
                    self.cur_marks = marks
                    return self
            match_more = False

class MinUntilMatchResult(AbstractUntilMatchResult):

    def find_first_result(self, ctx, pattern):
        return self.search_next(ctx, pattern, resume=False)

    def find_next_result(self, ctx, pattern):
        return self.search_next(ctx, pattern, resume=True)

    def search_next(self, ctx, pattern, resume):
        # XXX missing jit support here
        ppos = self.ppos
        min = pattern.pat(ppos+1)
        max = pattern.pat(ppos+2)
        ptr = self.cur_ptr
        marks = self.cur_marks
        while True:
            # try to match 'tail' if we have enough 'item'
            if not resume and self.num_pending >= min:
                result = sre_match(ctx, pattern, self.tailppos, ptr, marks)
                if result is not None:
                    self.subresult = result
                    self.cur_ptr = ptr
                    self.cur_marks = marks
                    return self
            resume = False

            if max == rsre_char.MAXREPEAT or self.num_pending < max:
                # try to match one more 'item'
                enum = sre_match(ctx, pattern, ppos + 3, ptr, marks)
                #
                # zero-width match protection
                if self.num_pending >= min:
                    while enum is not None and ptr == ctx.match_end:
                        enum = enum.move_to_next_result(ctx, pattern)
            else:
                enum = None    # 'max' reached, no more matches

            while enum is None:
                # 'item' does not match; try to get further results from
                # the 'pending' list.
                p = self.pending
                if p is None:
                    return
                self.pending = p.next
                self.num_pending -= 1
                ptr = p.ptr
                marks = p.marks
                enum = p.enum.move_to_next_result(ctx, pattern)

            # matched one more 'item'.  record it and continue
            self.pending = Pending(ptr, marks, enum, self.pending)
            self.num_pending += 1
            ptr = ctx.match_end
            marks = ctx.match_marks

# ____________________________________________________________

@specializectx
@jit.unroll_safe
def sre_match(ctx, pattern, ppos, ptr, marks):
    """Returns either None or a MatchResult object.  Usually we only need
    the first result, but there is the case of REPEAT...UNTIL where we
    need all results; in that case we use the method move_to_next_result()
    of the MatchResult."""
    while True:
        op = pattern.pat(ppos)
        ppos += 1

        #jit.jit_debug("sre_match", op, ppos, ptr)
        #
        # When using the JIT, calls to sre_match() must always have a constant
        # (green) argument for 'ppos'.  If not, the following assert fails.
        jit.assert_green(op)

        if op == consts.OPCODE_FAILURE:
            return

        elif op == consts.OPCODE_SUCCESS:
            mode = ctx.match_mode
            if mode == MODE_FULL:
                if ptr != ctx.end:
                    return     # not a full match
            elif mode == MODE_NONEMPTY:
                if ptr == ctx.match_start:
                    return     # empty match
            ctx.match_end = ptr
            ctx.match_marks = marks
            return MATCHED_OK

        elif (op == consts.OPCODE_MAX_UNTIL or
              op == consts.OPCODE_MIN_UNTIL):
            ctx.match_end = ptr
            ctx.match_marks = marks
            return MATCHED_OK

        elif op == consts.OPCODE_ANY:
            # match anything (except a newline)
            # <ANY>
            if ptr >= ctx.end or rsre_char.is_linebreak(ctx.str(ptr)):
                return
            ptr = ctx.next(ptr)

        elif op == consts.OPCODE_ANY_ALL:
            # match anything
            # <ANY_ALL>
            if ptr >= ctx.end:
                return
            ptr = ctx.next(ptr)

        elif op == consts.OPCODE_ASSERT:
            # assert subpattern
            # <ASSERT> <0=skip> <1=back> <pattern>
            try:
                ptr1 = ctx.prev_n(ptr, pattern.pat(ppos+1), ctx.ZERO)
            except EndOfString:
                return
            saved = ctx.match_mode
            ctx.match_mode = MODE_ANY
            stop = sre_match(ctx, pattern, ppos + 2, ptr1, marks) is None
            ctx.match_mode = saved
            if stop:
                return
            marks = ctx.match_marks
            ppos += pattern.pat(ppos)

        elif op == consts.OPCODE_ASSERT_NOT:
            # assert not subpattern
            # <ASSERT_NOT> <0=skip> <1=back> <pattern>

            try:
                ptr1 = ctx.prev_n(ptr, pattern.pat(ppos+1), ctx.ZERO)
            except EndOfString:
                pass
            else:
                saved = ctx.match_mode
                ctx.match_mode = MODE_ANY
                stop = sre_match(ctx, pattern, ppos + 2, ptr1, marks) is not None
                ctx.match_mode = saved
                if stop:
                    return
            ppos += pattern.pat(ppos)

        elif op == consts.OPCODE_AT:
            # match at given position (e.g. at beginning, at boundary, etc.)
            # <AT> <code>
            if not sre_at(ctx, pattern.pat(ppos), ptr):
                return
            ppos += 1

        elif op == consts.OPCODE_BRANCH:
            # alternation
            # <BRANCH> <0=skip> code <JUMP> ... <NULL>
            result = BranchMatchResult(ppos, ptr, marks)
            return result.find_first_result(ctx, pattern)

        elif op == consts.OPCODE_CATEGORY:
            # seems to be never produced, but used by some tests from
            # pypy/module/_sre/test
            # <CATEGORY> <category>
            if (ptr == ctx.end or
                not rsre_char.category_dispatch(pattern.pat(ppos), ctx.str(ptr))):
                return
            ptr = ctx.next(ptr)
            ppos += 1

        elif op == consts.OPCODE_GROUPREF:
            # match backreference
            # <GROUPREF> <groupnum>
            startptr, length_bytes = get_group_ref(ctx, marks, pattern.pat(ppos))
            if length_bytes < 0:
                return     # group was not previously defined
            if not match_repeated(ctx, ptr, startptr, length_bytes):
                return     # no match
            ptr = ctx.go_forward_by_bytes(ptr, length_bytes)
            ppos += 1

        elif op == consts.OPCODE_GROUPREF_IGNORE:
            # match backreference
            # <GROUPREF> <groupnum>
            startptr, length_bytes = get_group_ref(ctx, marks, pattern.pat(ppos))
            if length_bytes < 0:
                return     # group was not previously defined
            ptr = match_repeated_ignore(ctx, ptr, startptr, length_bytes, pattern)
            if ptr < ctx.ZERO:
                return     # no match
            ppos += 1

        elif consts.eq(op, consts.OPCODE37_GROUPREF_UNI_IGNORE):
            # unicode version of OPCODE_GROUPREF_IGNORE
            # <GROUPREF> <groupnum>
            startptr, length_bytes = get_group_ref(ctx, marks, pattern.pat(ppos))
            if length_bytes < 0:
                return     # group was not previously defined
            ptr = match_repeated_uni_ignore(ctx, ptr, startptr, length_bytes)
            if ptr < ctx.ZERO:
                return     # no match
            ppos += 1

        elif consts.eq(op, consts.OPCODE37_GROUPREF_LOC_IGNORE):
            # locale version of OPCODE_GROUPREF_IGNORE
            # <GROUPREF> <groupnum>
            startptr, length_bytes = get_group_ref(ctx, marks, pattern.pat(ppos))
            if length_bytes < 0:
                return     # group was not previously defined
            ptr = match_repeated_loc_ignore(ctx, ptr, startptr, length_bytes)
            if ptr < ctx.ZERO:
                return     # no match
            ppos += 1

        elif op == consts.OPCODE_GROUPREF_EXISTS:
            # conditional match depending on the existence of a group
            # <GROUPREF_EXISTS> <group> <skip> codeyes <JUMP> codeno ...
            _, length_bytes = get_group_ref(ctx, marks, pattern.pat(ppos))
            if length_bytes >= 0:
                ppos += 2                  # jump to 'codeyes'
            else:
                ppos += pattern.pat(ppos+1)    # jump to 'codeno'

        elif op == consts.OPCODE_IN:
            # match set member (or non_member)
            # <IN> <skip> <set>
            if ptr >= ctx.end or not rsre_char.check_charset(ctx, pattern, ppos+1,
                                                             ctx.str(ptr)):
                return
            ppos += pattern.pat(ppos)
            ptr = ctx.next(ptr)

        elif op == consts.OPCODE_IN_IGNORE:
            # match set member (or non_member), ignoring case
            # <IN> <skip> <set>
            if ptr >= ctx.end or not rsre_char.check_charset(ctx, pattern, ppos+1,
                                                             pattern.lowa(ctx.str(ptr))):
                return
            ppos += pattern.pat(ppos)
            ptr = ctx.next(ptr)

        elif consts.eq(op, consts.OPCODE37_IN_UNI_IGNORE):
            # match set member (or non_member), ignoring case, unicode mode
            # <IN> <skip> <set>
            if ptr >= ctx.end or not rsre_char.check_charset(ctx, pattern, ppos+1,
                                                             rsre_char.getlower_unicode(ctx.str(ptr))):
                return
            ppos += pattern.pat(ppos)
            ptr = ctx.next(ptr)

        elif consts.eq(op, consts.OPCODE37_IN_LOC_IGNORE):
            # match set member (or non_member), ignoring case, locale mode
            # <IN> <skip> <set>
            if ptr >= ctx.end or not pattern.charset_loc_ignore(ctx, ppos+1,
                                                                ctx.str(ptr)):
                return
            ppos += pattern.pat(ppos)
            ptr = ctx.next(ptr)

        elif op == consts.OPCODE_INFO:
            # optimization info block
            # <INFO> <0=skip> <1=flags> <2=min> ...
            if ctx.maximum_distance(ptr, ctx.end) < pattern.pat(ppos+2):
                return
            ppos += pattern.pat(ppos)

        elif op == consts.OPCODE_JUMP:
            ppos += pattern.pat(ppos)

        elif op == consts.OPCODE_LITERAL:
            # match literal string
            # <LITERAL> <code>
            if ptr >= ctx.end or ctx.str(ptr) != pattern.pat(ppos):
                return
            ppos += 1
            ptr = ctx.next(ptr)

        elif op == consts.OPCODE_LITERAL_IGNORE:
            # match literal string, ignoring case
            # <LITERAL_IGNORE> <code>
            if ptr >= ctx.end or pattern.lowa(ctx.str(ptr)) != pattern.pat(ppos):
                return
            ppos += 1
            ptr = ctx.next(ptr)

        elif consts.eq(op, consts.OPCODE37_LITERAL_UNI_IGNORE):
            # match literal string, ignoring case, unicode mode
            # <LITERAL_IGNORE> <code>
            if ptr >= ctx.end or rsre_char.getlower_unicode(ctx.str(ptr)) != pattern.pat(ppos):
                return
            ppos += 1
            ptr = ctx.next(ptr)

        elif consts.eq(op, consts.OPCODE37_LITERAL_LOC_IGNORE):
            # match literal string, ignoring case, locale mode
            # <LITERAL_IGNORE> <code>
            if ptr >= ctx.end or not pattern.char_loc_ignore(ppos, ctx.str(ptr)):
                return
            ppos += 1
            ptr = ctx.next(ptr)

        elif op == consts.OPCODE_MARK:
            # set mark
            # <MARK> <gid>
            gid = pattern.pat(ppos)
            marks = Mark(gid, ptr, marks)
            ppos += 1

        elif op == consts.OPCODE_NOT_LITERAL:
            # match if it's not a literal string
            # <NOT_LITERAL> <code>
            if ptr >= ctx.end or ctx.str(ptr) == pattern.pat(ppos):
                return
            ppos += 1
            ptr = ctx.next(ptr)

        elif op == consts.OPCODE_NOT_LITERAL_IGNORE:
            # match if it's not a literal string, ignoring case
            # <NOT_LITERAL> <code>
            if ptr >= ctx.end or pattern.lowa(ctx.str(ptr)) == pattern.pat(ppos):
                return
            ppos += 1
            ptr = ctx.next(ptr)

        elif consts.eq(op, consts.OPCODE37_NOT_LITERAL_UNI_IGNORE):
            # match if it's not a literal string, ignoring case, unicode mode
            # <NOT_LITERAL> <code>
            if ptr >= ctx.end or rsre_char.getlower_unicode(ctx.str(ptr)) == pattern.pat(ppos):
                return
            ppos += 1
            ptr = ctx.next(ptr)

        elif consts.eq(op, consts.OPCODE37_NOT_LITERAL_LOC_IGNORE):
            # match if it's not a literal string, ignoring case, locale mode
            # <NOT_LITERAL> <code>
            if ptr >= ctx.end or pattern.char_loc_ignore(ppos, ctx.str(ptr)):
                return
            ppos += 1
            ptr = ctx.next(ptr)

        elif op == consts.OPCODE_REPEAT:
            # general repeat.  in this version of the re module, all the work
            # is done here, and not on the later UNTIL operator.
            # <REPEAT> <skip> <1=min> <2=max> item <UNTIL> tail
            # FIXME: we probably need to deal with zero-width matches in here..

            # decode the later UNTIL operator to see if it is actually
            # a MAX_UNTIL or MIN_UNTIL
            untilppos = ppos + pattern.pat(ppos)
            tailppos = untilppos + 1
            op = pattern.pat(untilppos)
            if op == consts.OPCODE_MAX_UNTIL:
                # the hard case: we have to match as many repetitions as
                # possible, followed by the 'tail'.  we do this by
                # remembering each state for each possible number of
                # 'item' matching.
                result = MaxUntilMatchResult(ppos, tailppos, ptr, marks)
                return result.find_first_result(ctx, pattern)

            elif op == consts.OPCODE_MIN_UNTIL:
                # first try to match the 'tail', and if it fails, try
                # to match one more 'item' and try again
                result = MinUntilMatchResult(ppos, tailppos, ptr, marks)
                return result.find_first_result(ctx, pattern)

            else:
                raise Error("missing UNTIL after REPEAT")

        elif op == consts.OPCODE_REPEAT_ONE:
            # match repeated sequence (maximizing regexp).
            # this operator only works if the repeated item is
            # exactly one character wide, and we're not already
            # collecting backtracking points.  for other cases,
            # use the MAX_REPEAT operator.
            # <REPEAT_ONE> <skip> <1=min> <2=max> item <SUCCESS> tail
            start = ptr

            try:
                minptr = ctx.next_n(start, pattern.pat(ppos+1), ctx.end)
            except EndOfString:
                return    # cannot match
            ptr = find_repetition_end(ctx, pattern, ppos+3, start,
                                      pattern.pat(ppos+2),
                                      marks)
            # when we arrive here, ptr points to the tail of the target
            # string.  check if the rest of the pattern matches,
            # and backtrack if not.
            nextppos = ppos + pattern.pat(ppos)
            result = RepeatOneMatchResult(nextppos, minptr, ptr, marks)
            return result.find_first_result(ctx, pattern)

        elif op == consts.OPCODE_MIN_REPEAT_ONE:
            # match repeated sequence (minimizing regexp).
            # this operator only works if the repeated item is
            # exactly one character wide, and we're not already
            # collecting backtracking points.  for other cases,
            # use the MIN_REPEAT operator.
            # <MIN_REPEAT_ONE> <skip> <1=min> <2=max> item <SUCCESS> tail
            start = ptr
            min = pattern.pat(ppos+1)
            if min > 0:
                try:
                    minptr = ctx.next_n(ptr, min, ctx.end)
                except EndOfString:
                    return    # cannot match
                # count using pattern min as the maximum
                ptr = find_repetition_end(ctx, pattern, ppos+3, ptr, min, marks)
                if ptr < minptr:
                    return   # did not match minimum number of times

            max_count = sys.maxint
            max = pattern.pat(ppos+2)
            if max != rsre_char.MAXREPEAT:
                max_count = max - min
                assert max_count >= 0
            nextppos = ppos + pattern.pat(ppos)
            result = MinRepeatOneMatchResult(nextppos, ppos+3, max_count,
                                             ptr, marks)
            return result.find_first_result(ctx, pattern)

        else:
            raise Error("bad pattern code %d" % op)


def get_group_ref(ctx, marks, groupnum):
    gid = groupnum * 2
    startptr = find_mark(marks, gid)
    if startptr < ctx.ZERO:
        return 0, -1
    endptr = find_mark(marks, gid + 1)
    length_bytes = ctx.bytes_difference(endptr, startptr)
    return startptr, length_bytes

@specializectx
def match_repeated(ctx, ptr, oldptr, length_bytes):
    if ctx.bytes_difference(ctx.end, ptr) < length_bytes:
        return False
    for i in range(length_bytes):
        if ctx.get_single_byte(ptr, i) != ctx.get_single_byte(oldptr, i):
            return False
    return True

@specializectx
def match_repeated_ignore(ctx, ptr, oldptr, length_bytes, pattern):
    oldend = ctx.go_forward_by_bytes(oldptr, length_bytes)
    while oldptr < oldend:
        if ptr >= ctx.end:
            return -1
        if pattern.lowa(ctx.str(ptr)) != pattern.lowa(ctx.str(oldptr)):
            return -1
        ptr = ctx.next(ptr)
        oldptr = ctx.next(oldptr)
    return ptr

@specializectx
def match_repeated_uni_ignore(ctx, ptr, oldptr, length_bytes):
    oldend = ctx.go_forward_by_bytes(oldptr, length_bytes)
    while oldptr < oldend:
        if ptr >= ctx.end:
            return -1
        if rsre_char.getlower_unicode(ctx.str(ptr)) != rsre_char.getlower_unicode(ctx.str(oldptr)):
            return -1
        ptr = ctx.next(ptr)
        oldptr = ctx.next(oldptr)
    return ptr

@specializectx
def match_repeated_loc_ignore(ctx, ptr, oldptr, length_bytes):
    oldend = ctx.go_forward_by_bytes(oldptr, length_bytes)
    while oldptr < oldend:
        if ptr >= ctx.end:
            return -1
        if rsre_char.getlower_locale(ctx.str(ptr)) != rsre_char.getlower_locale(ctx.str(oldptr)):
            return -1
        ptr = ctx.next(ptr)
        oldptr = ctx.next(oldptr)
    return ptr

@specializectx
def find_repetition_end(ctx, pattern, ppos, ptr, maxcount, marks):
    end = ctx.end
    # First get rid of the cases where we don't have room for any match.
    if maxcount <= 0 or ptr >= end:
        return ptr
    ptrp1 = ctx.next(ptr)
    # Check the first character directly.  If it doesn't match, we are done.
    # The idea is to be fast for cases like re.search("b+"), where we expect
    # the common case to be a non-match.  It's much faster with the JIT to
    # have the non-match inlined here rather than detect it in the fre() call.
    op = pattern.pat(ppos)
    for op1, checkerfn in unroll_char_checker:
        if op1 == op:
            if checkerfn(ctx, pattern, ptr, ppos):
                break
            return ptr
    else:
        # obscure case: it should be a single char pattern, but isn't
        # one of the opcodes in unroll_char_checker (see test_ext_opcode)
        return general_find_repetition_end(ctx, pattern, ppos, ptr, maxcount, marks)
    # It matches at least once.  If maxcount == 1 (relatively common),
    # then we are done.
    if maxcount == 1:
        return ptrp1
    # Else we really need to count how many times it matches.
    if maxcount != rsre_char.MAXREPEAT:
        # adjust end
        try:
            end = ctx.next_n(ptr, maxcount, end)
        except EndOfString:
            pass
    op = pattern.pat(ppos)
    for op1, fre in unroll_fre_checker:
        if op1 == op:
            return fre(ctx, pattern, ptrp1, end, ppos)
    raise Error("rsre.find_repetition_end[%d]" % op)

@specializectx
def general_find_repetition_end(ctx, pattern, ppos, ptr, maxcount, marks):
    # moved into its own JIT-opaque function
    end = ctx.end
    if maxcount != rsre_char.MAXREPEAT:
        # adjust end
        end1 = ptr + maxcount
        if end1 <= end:
            end = end1
    while ptr < end and sre_match(ctx, pattern, ppos, ptr, marks) is not None:
        ptr = ctx.next(ptr)
    return ptr

@specializectx
def match_ANY(ctx, pattern, ptr, ppos):   # dot wildcard.
    return not rsre_char.is_linebreak(ctx.str(ptr))
def match_ANY_ALL(ctx, pattern, ptr, ppos):
    return True    # match anything (including a newline)
@specializectx
def match_IN(ctx, pattern, ptr, ppos):
    return rsre_char.check_charset(ctx, pattern, ppos+2, ctx.str(ptr))
@specializectx
def match_IN_IGNORE(ctx, pattern, ptr, ppos):
    return rsre_char.check_charset(ctx, pattern, ppos+2, pattern.lowa(ctx.str(ptr)))
@specializectx
def match_IN_UNI_IGNORE(ctx, pattern, ptr, ppos):
    return rsre_char.check_charset(ctx, pattern, ppos+2, rsre_char.getlower_unicode(ctx.str(ptr)))
@specializectx
def match_IN_LOC_IGNORE(ctx, pattern, ptr, ppos):
    return pattern.charset_loc_ignore(ctx, ppos+2, ctx.str(ptr))
@specializectx
def match_LITERAL(ctx, pattern, ptr, ppos):
    return ctx.str(ptr) == pattern.pat(ppos+1)
@specializectx
def match_LITERAL_IGNORE(ctx, pattern, ptr, ppos):
    return pattern.lowa(ctx.str(ptr)) == pattern.pat(ppos+1)
@specializectx
def match_LITERAL_UNI_IGNORE(ctx, pattern, ptr, ppos):
    return rsre_char.getlower_unicode(ctx.str(ptr)) == pattern.pat(ppos+1)
@specializectx
def match_LITERAL_LOC_IGNORE(ctx, pattern, ptr, ppos):
    return pattern.char_loc_ignore(ppos+1, ctx.str(ptr))
@specializectx
def match_NOT_LITERAL(ctx, pattern, ptr, ppos):
    return ctx.str(ptr) != pattern.pat(ppos+1)
@specializectx
def match_NOT_LITERAL_IGNORE(ctx, pattern, ptr, ppos):
    return pattern.lowa(ctx.str(ptr)) != pattern.pat(ppos+1)
@specializectx
def match_NOT_LITERAL_UNI_IGNORE(ctx, pattern, ptr, ppos):
    return rsre_char.getlower_unicode(ctx.str(ptr)) != pattern.pat(ppos+1)
@specializectx
def match_NOT_LITERAL_LOC_IGNORE(ctx, pattern, ptr, ppos):
    return not pattern.char_loc_ignore(ppos+1, ctx.str(ptr))

def _make_fre(checkerfn):
    if checkerfn == match_ANY_ALL:
        def fre(ctx, pattern, ptr, end, ppos):
            return end
    elif checkerfn in (match_IN, match_IN_IGNORE, match_IN_UNI_IGNORE):
        # produces three jitdrivers:
        #     MatchIn
        #     MatchInIgnore
        #     MatchInUniIgnore
        name = checkerfn.__name__.title().replace('_', '')
        method_name = "jitdriver_" + name
        install_jitdriver_spec(name,
                               greens=['ppos', 'pattern'],
                               reds=['ptr', 'end', 'ctx'],
                               debugprint=(1, 0))
        @specializectx
        def fre(ctx, pattern, ptr, end, ppos):
            while True:
                getattr(ctx, method_name).jit_merge_point(ctx=ctx, ptr=ptr,
                                                      end=end, ppos=ppos,
                                                      pattern=pattern)
                if ptr < end and checkerfn(ctx, pattern, ptr, ppos):
                    ptr = ctx.next(ptr)
                else:
                    return ptr
    else:
        # in the other cases, the fre() function is not JITted at all
        # and is present as a residual call.
        @specializectx
        def fre(ctx, pattern, ptr, end, ppos):
            while ptr < end and checkerfn(ctx, pattern, ptr, ppos):
                ptr = ctx.next(ptr)
            return ptr
    fre = func_with_new_name(fre, 'fre_' + checkerfn.__name__)
    return fre

unroll_char_checker = [
    (consts.OPCODE_ANY,                match_ANY),
    (consts.OPCODE_ANY_ALL,            match_ANY_ALL),
    (consts.OPCODE_IN,                 match_IN),
    (consts.OPCODE_IN_IGNORE,          match_IN_IGNORE),
    (consts.OPCODE37_IN_UNI_IGNORE,           match_IN_UNI_IGNORE),
    (consts.OPCODE37_IN_LOC_IGNORE,           match_IN_LOC_IGNORE),
    (consts.OPCODE_LITERAL,            match_LITERAL),
    (consts.OPCODE_LITERAL_IGNORE,     match_LITERAL_IGNORE),
    (consts.OPCODE37_LITERAL_UNI_IGNORE,      match_LITERAL_UNI_IGNORE),
    (consts.OPCODE37_LITERAL_LOC_IGNORE,      match_LITERAL_LOC_IGNORE),
    (consts.OPCODE_NOT_LITERAL,        match_NOT_LITERAL),
    (consts.OPCODE_NOT_LITERAL_IGNORE, match_NOT_LITERAL_IGNORE),
    (consts.OPCODE37_NOT_LITERAL_UNI_IGNORE,  match_NOT_LITERAL_UNI_IGNORE),
    (consts.OPCODE37_NOT_LITERAL_LOC_IGNORE,  match_NOT_LITERAL_LOC_IGNORE),
    ]
unroll_char_checker = [(_op, _fn) for (_op, _fn) in unroll_char_checker
                       if _op is not None]   # possibly removes the OPCODE37_*
unroll_fre_checker = [(_op, _make_fre(_fn))
                      for (_op, _fn) in unroll_char_checker]

unroll_char_checker = unrolling_iterable(unroll_char_checker)
unroll_fre_checker  = unrolling_iterable(unroll_fre_checker)

##### At dispatch

@specializectx
def sre_at(ctx, atcode, ptr):
    if (atcode == consts.AT_BEGINNING or
        atcode == consts.AT_BEGINNING_STRING):
        return ptr == ctx.ZERO

    elif atcode == consts.AT_BEGINNING_LINE:
        try:
            prevptr = ctx.prev(ptr)
        except EndOfString:
            return True
        return rsre_char.is_linebreak(ctx.str(prevptr))

    elif atcode == consts.AT_BOUNDARY:
        return at_boundary(ctx, ptr)

    elif atcode == consts.AT_NON_BOUNDARY:
        return at_non_boundary(ctx, ptr)

    elif atcode == consts.AT_END:
        return (ptr == ctx.end or
            (ctx.next(ptr) == ctx.end and rsre_char.is_linebreak(ctx.str(ptr))))

    elif atcode == consts.AT_END_LINE:
        return ptr == ctx.end or rsre_char.is_linebreak(ctx.str(ptr))

    elif atcode == consts.AT_END_STRING:
        return ptr == ctx.end

    elif atcode == consts.AT_LOC_BOUNDARY:
        return at_loc_boundary(ctx, ptr)

    elif atcode == consts.AT_LOC_NON_BOUNDARY:
        return at_loc_non_boundary(ctx, ptr)

    elif atcode == consts.AT_UNI_BOUNDARY:
        return at_uni_boundary(ctx, ptr)

    elif atcode == consts.AT_UNI_NON_BOUNDARY:
        return at_uni_non_boundary(ctx, ptr)

    return False

def _make_boundary(word_checker):
    @specializectx
    def at_boundary(ctx, ptr):
        if ctx.end == ctx.ZERO:
            return False
        try:
            prevptr = ctx.prev(ptr)
        except EndOfString:
            that = False
        else:
            that = word_checker(ctx.str(prevptr))
        this = ptr < ctx.end and word_checker(ctx.str(ptr))
        return this != that
    @specializectx
    def at_non_boundary(ctx, ptr):
        if ctx.end == ctx.ZERO:
            return False
        try:
            prevptr = ctx.prev(ptr)
        except EndOfString:
            that = False
        else:
            that = word_checker(ctx.str(prevptr))
        this = ptr < ctx.end and word_checker(ctx.str(ptr))
        return this == that
    return at_boundary, at_non_boundary

at_boundary, at_non_boundary = _make_boundary(rsre_char.is_word)
at_loc_boundary, at_loc_non_boundary = _make_boundary(rsre_char.is_loc_word)
at_uni_boundary, at_uni_non_boundary = _make_boundary(rsre_char.is_uni_word)

# ____________________________________________________________

def _adjust(start, end, length):
    if start < 0: start = 0
    elif start > length: start = length
    if end < 0: end = 0
    elif end > length: end = length
    return start, end

def match(pattern, string, start=0, end=sys.maxint, fullmatch=False):
    assert isinstance(pattern, CompiledPattern)
    start, end = _adjust(start, end, len(string))
    ctx = StrMatchContext(string, start, end)
    if fullmatch:
        ctx.match_mode = MODE_FULL
    if match_context(ctx, pattern):
        return ctx
    else:
        return None

def fullmatch(pattern, string, start=0, end=sys.maxint):
    return match(pattern, string, start, end, fullmatch=True)

def search(pattern, string, start=0, end=sys.maxint):
    assert isinstance(pattern, CompiledPattern)
    start, end = _adjust(start, end, len(string))
    ctx = StrMatchContext(string, start, end)
    if search_context(ctx, pattern):
        return ctx
    else:
        return None

install_jitdriver('Match',
                  greens=['pattern'], reds=['ctx'],
                  debugprint=(0,))

def match_context(ctx, pattern):
    ctx.original_pos = ctx.match_start
    if ctx.end < ctx.match_start:
        return False
    ctx.jitdriver_Match.jit_merge_point(ctx=ctx, pattern=pattern)
    return sre_match(ctx, pattern, 0, ctx.match_start, None) is not None

def search_context(ctx, pattern):
    ctx.original_pos = ctx.match_start
    if ctx.end < ctx.match_start:
        return False
    base = 0
    charset = False
    if pattern.pat(base) == consts.OPCODE_INFO:
        flags = pattern.pat(2)
        if flags & consts.SRE_INFO_PREFIX:
            if pattern.pat(5) > 1:
                return fast_search(ctx, pattern)
        else:
            charset = (flags & consts.SRE_INFO_CHARSET)
        base += 1 + pattern.pat(1)
    if pattern.pat(base) == consts.OPCODE_LITERAL:
        return literal_search(ctx, pattern, base)
    if charset:
        return charset_search(ctx, pattern, base)
    return regular_search(ctx, pattern, base)

install_jitdriver('RegularSearch',
                  greens=['base', 'pattern'],
                  reds=['start', 'ctx'],
                  debugprint=(1, 0))

def regular_search(ctx, pattern, base):
    start = ctx.match_start
    while True:
        ctx.jitdriver_RegularSearch.jit_merge_point(ctx=ctx, pattern=pattern,
                                                    start=start, base=base)
        if sre_match(ctx, pattern, base, start, None) is not None:
            ctx.match_start = start
            return True
        if start >= ctx.end:
            break
        start = ctx.next_indirect(start)
    return False

install_jitdriver_spec("LiteralSearch",
                       greens=['base', 'character', 'pattern'],
                       reds=['start', 'ctx'],
                       debugprint=(2, 0, 1))
@specializectx
def literal_search(ctx, pattern, base):
    # pattern starts with a literal character.  this is used
    # for short prefixes, and if fast search is disabled
    character = pattern.pat(base + 1)
    base += 2
    start = ctx.match_start
    while start < ctx.end:
        ctx.jitdriver_LiteralSearch.jit_merge_point(ctx=ctx, start=start,
                                          base=base, character=character, pattern=pattern)
        start1 = ctx.next(start)
        if ctx.str(start) == character:
            if sre_match(ctx, pattern, base, start1, None) is not None:
                ctx.match_start = start
                return True
        start = start1
    return False

install_jitdriver_spec("CharsetSearch",
                       greens=['base', 'pattern'],
                       reds=['start', 'ctx'],
                       debugprint=(1, 0))
@specializectx
def charset_search(ctx, pattern, base):
    # pattern starts with a character from a known set
    start = ctx.match_start
    while start < ctx.end:
        ctx.jitdriver_CharsetSearch.jit_merge_point(ctx=ctx, start=start,
                                                    base=base, pattern=pattern)
        if rsre_char.check_charset(ctx, pattern, 5, ctx.str(start)):
            if sre_match(ctx, pattern, base, start, None) is not None:
                ctx.match_start = start
                return True
        start = ctx.next(start)
    return False

install_jitdriver_spec('FastSearch',
                       greens=['i', 'prefix_len', 'pattern'],
                       reds=['string_position', 'ctx'],
                       debugprint=(2, 0))
@specializectx
def fast_search(ctx, pattern):
    # skips forward in a string as fast as possible using information from
    # an optimization info block
    # <INFO> <1=skip> <2=flags> <3=min> <4=...>
    #        <5=length> <6=skip> <7=prefix data> <overlap data>
    string_position = ctx.match_start
    if string_position >= ctx.end:
        return False
    prefix_len = pattern.pat(5)
    assert prefix_len >= 0
    i = 0
    while True:
        ctx.jitdriver_FastSearch.jit_merge_point(ctx=ctx,
                string_position=string_position, i=i, prefix_len=prefix_len,
                pattern=pattern)
        char_ord = ctx.str(string_position)
        if char_ord != pattern.pat(7 + i):
            if i > 0:
                overlap_offset = prefix_len + (7 - 1)
                i = pattern.pat(overlap_offset + i)
                continue
        else:
            i += 1
            if i == prefix_len:
                # start = string_position + 1 - prefix_len: computed later
                ptr = string_position
                prefix_skip = pattern.pat(6)
                if prefix_skip == prefix_len:
                    ptr = ctx.next(ptr)
                else:
                    assert prefix_skip < prefix_len
                    ptr = ctx.prev_n(ptr, prefix_len-1 - prefix_skip, ctx.ZERO)
                #flags = pattern.pat(2)
                #if flags & rsre_char.SRE_INFO_LITERAL:
                #    # matched all of pure literal pattern
                #    ctx.match_start = start
                #    ctx.match_end = ptr
                #    ctx.match_marks = None
                #    return True
                pattern_offset = pattern.pat(1) + 1
                ppos_start = pattern_offset + 2 * prefix_skip
                if sre_match(ctx, pattern, ppos_start, ptr, None) is not None:
                    start = ctx.prev_n(ptr, prefix_skip, ctx.ZERO)
                    ctx.match_start = start
                    return True
                overlap_offset = prefix_len + (7 - 1)
                i = pattern.pat(overlap_offset + i)
        string_position = ctx.next(string_position)
        if string_position >= ctx.end:
            return False

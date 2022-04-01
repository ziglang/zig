"""
This is not used in a PyPy translation, but it can be used
in RPython code.  It exports the same interface as the
Python 're' module.  You can call the functions at the start
of the module (expect the ones with @not_rpython for now).
They must be called with a *constant* pattern string.
"""
import re, sys
from rpython.rlib.rsre import rsre_core, rsre_char
from rpython.rlib.rsre.rpy import get_code as _get_code
from rpython.rlib.unicodedata import unicodedb
from rpython.rlib.objectmodel import specialize, we_are_translated
from rpython.rlib.objectmodel import not_rpython
rsre_char.set_unicode_db(unicodedb)


I = IGNORECASE = re.I   # ignore case
L = LOCALE     = re.L   # assume current 8-bit locale
U = UNICODE    = re.U   # assume unicode locale
M = MULTILINE  = re.M   # make anchors look for newline
S = DOTALL     = re.S   # make dot match newline
X = VERBOSE    = re.X   # ignore whitespace and comments


@specialize.call_location()
def match(pattern, string, flags=0):
    return compile(pattern, flags).match(string)

@specialize.call_location()
def search(pattern, string, flags=0):
    return compile(pattern, flags).search(string)

@specialize.call_location()
def findall(pattern, string, flags=0):
    return compile(pattern, flags).findall(string)

@specialize.call_location()
def finditer(pattern, string, flags=0):
    return compile(pattern, flags).finditer(string)

@not_rpython
def sub(pattern, repl, string, count=0):
    return compile(pattern).sub(repl, string, count)

@not_rpython
def subn(pattern, repl, string, count=0):
    return compile(pattern).subn(repl, string, count)

@specialize.call_location()
def split(pattern, string, maxsplit=0):
    return compile(pattern).split(string, maxsplit)

@specialize.memo()
def compile(pattern, flags=0):
    code, flags, args = _get_code(pattern, flags, allargs=True)
    return RSREPattern(pattern, code, flags, *args)

escape = re.escape
error = re.error


class RSREPattern(object):

    def __init__(self, pattern, code, flags,
                 num_groups, groupindex, indexgroup):
        self._code = code
        self.pattern = pattern
        self.flags = flags
        self.groups = num_groups
        self.groupindex = groupindex
        self._indexgroup = indexgroup

    def match(self, string, pos=0, endpos=sys.maxint):
        return self._make_match(rsre_core.match(self._code, string,
                                                pos, endpos))

    def search(self, string, pos=0, endpos=sys.maxint):
        return self._make_match(rsre_core.search(self._code, string,
                                                 pos, endpos))

    def findall(self, string, pos=0, endpos=sys.maxint):
        matchlist = []
        scanner = self.scanner(string, pos, endpos)
        while True:
            match = scanner.search()
            if match is None:
                break
            if self.groups == 0 or self.groups == 1:
                item = match.group(self.groups)
            else:
                assert False, ("findall() not supported if there is more "
                               "than one group: not valid RPython")
                item = match.groups("")
            matchlist.append(item)
        return matchlist

    def finditer(self, string, pos=0, endpos=sys.maxint):
        scanner = self.scanner(string, pos, endpos)
        while True:
            match = scanner.search()
            if match is None:
                break
            yield match

    @not_rpython
    def subn(self, repl, string, count=0):
        filter = repl
        if not callable(repl) and "\\" in repl:
            # handle non-literal strings; hand it over to the template compiler
            filter = re._subx(self, repl)
        start = 0
        sublist = []
        force_unicode = (isinstance(string, unicode) or
                         isinstance(repl, unicode))
        n = last_pos = 0
        while not count or n < count:
            match = rsre_core.search(self._code, string, start)
            if match is None:
                break
            if last_pos < match.match_start:
                sublist.append(string[last_pos:match.match_start])
            if not (last_pos == match.match_start
                             == match.match_end and n > 0):
                # the above ignores empty matches on latest position
                if callable(filter):
                    piece = filter(self._make_match(match))
                else:
                    piece = filter
                sublist.append(piece)
                last_pos = match.match_end
                n += 1
            elif last_pos >= len(string):
                break     # empty match at the end: finished
            #
            start = match.match_end
            if start == match.match_start:
                start += 1

        if last_pos < len(string):
            sublist.append(string[last_pos:])

        if n == 0:
            # not just an optimization -- see test_sub_unicode
            return string, n

        if force_unicode:
            item = u"".join(sublist)
        else:
            item = "".join(sublist)
        return item, n

    @not_rpython
    def sub(self, repl, string, count=0):
        item, n = self.subn(repl, string, count)
        return item

    def split(self, string, maxsplit=0):
        splitlist = []
        start = 0
        n = 0
        last = 0
        while not maxsplit or n < maxsplit:
            match = rsre_core.search(self._code, string, start)
            if match is None:
                break
            if match.match_start == match.match_end: # zero-width match
                if match.match_start == len(string): # at end of string
                    break
                start = match.match_end + 1
                continue
            splitlist.append(string[last:match.match_start])
            # add groups (if any)
            if self.groups:
                match1 = self._make_match(match)
                splitlist.extend(match1.groups(None))
            n += 1
            last = start = match.match_end
        splitlist.append(string[last:])
        return splitlist

    def scanner(self, string, start=0, end=sys.maxint):
        return SREScanner(self, string, start, end)

    def _make_match(self, res):
        if res is None:
            return None
        return RSREMatch(self, res)


class RSREMatch(object):

    def __init__(self, pattern, ctx):
        self.re = pattern
        self._ctx = ctx

    def span(self, groupnum=0):
#        if not isinstance(groupnum, (int, long)):
#            groupnum = self.re.groupindex[groupnum]

        return self._ctx.span(groupnum)

    def start(self, groupnum=0):
        return self.span(groupnum)[0]

    def end(self, groupnum=0):
        return self.span(groupnum)[1]

    def group(self, group=0):
        frm, to = self.span(group)
        if 0 <= frm <= to:
            return self._ctx._string[frm:to]
        else:
            return None

#    def group(self, *groups):
#        groups = groups or (0,)
#        result = []
#        for group in groups:
#            frm, to = self.span(group)
#            if 0 <= frm <= to:
#                result.append(self._ctx._string[frm:to])
#            else:
#                result.append(None)
#        if len(result) > 1:
#            return tuple(result)


    def groups(self, default=None):
        fmarks = self._ctx.flatten_marks()
        grps = []
        for i in range(1, self.re.groups+1):
            grp = self.group(i)
            if grp is None: grp = default
            grps.append(grp)
        if not we_are_translated():
            grps = tuple(grps)    # xxx mostly to make tests happy
        return grps

    def groupdict(self, default=None):
        d = {}
        for key, value in self.re.groupindex.iteritems():
            grp = self.group(value)
            if grp is None: grp = default
            d[key] = grp
        return d

    def expand(self, template):
        return re._expand(self.re, self, template)

    @property
    def regs(self):
        fmarks = self._ctx.flatten_marks()
        return tuple([(fmarks[i], fmarks[i+1])
                      for i in range(0, len(fmarks), 2)])

    @property
    def lastindex(self):
        self._ctx.flatten_marks()
        if self._ctx.match_lastindex < 0:
            return None
        return self._ctx.match_lastindex // 2 + 1

    @property
    def lastgroup(self):
        lastindex = self.lastindex
        if lastindex < 0 or lastindex >= len(self.re._indexgroup):
            return None
        return self.re._indexgroup[lastindex]

    @property
    def string(self):
        return self._ctx._string

    @property
    def pos(self):
        return self._ctx.match_start

    @property
    def endpos(self):
        return self._ctx.end


class SREScanner(object):
    def __init__(self, pattern, string, start, end):
        self.pattern = pattern
        self._string = string
        self._start = start
        self._end = end

    def _match_search(self, matcher):
        if self._start > len(self._string):
            return None
        match = matcher(self._string, self._start, self._end)
        if match is None:
            self._start += 1     # obscure corner case
        else:
            self._start = match.end()
            if match.start() == self._start:
                self._start += 1
        return match

    def match(self):
        return self._match_search(self.pattern.match)

    def search(self):
        return self._match_search(self.pattern.search)

class Scanner:
    # This class is copied directly from re.py.
    def __init__(self, lexicon, flags=0):
        from rpython.rlib.rsre.rpy.sre_constants import BRANCH, SUBPATTERN
        from rpython.rlib.rsre.rpy import sre_parse
        self.lexicon = lexicon
        # combine phrases into a compound pattern
        p = []
        s = sre_parse.Pattern()
        s.flags = flags
        for phrase, action in lexicon:
            p.append(sre_parse.SubPattern(s, [
                (SUBPATTERN, (len(p)+1, sre_parse.parse(phrase, flags))),
                ]))
        s.groups = len(p)+1
        p = sre_parse.SubPattern(s, [(BRANCH, (None, p))])
        self.scanner = compile(p)
    def scan(self, string):
        result = []
        append = result.append
        match = self.scanner.scanner(string).match
        i = 0
        while 1:
            m = match()
            if not m:
                break
            j = m.end()
            if i == j:
                break
            action = self.lexicon[m.lastindex-1][1]
            if callable(action):
                self.match = m
                action = action(self, m.group())
            if action is not None:
                append(action)
            i = j
        return result, string[i:]

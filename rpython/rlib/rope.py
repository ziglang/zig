import py
import sys
import math

from rpython.rlib.rarithmetic import intmask, ovfcheck
from rpython.rlib.rarithmetic import r_uint, LONG_BIT

LOG2 = math.log(2)
NBITS = int(math.log(sys.maxint) / LOG2) + 2

# XXX should optimize the numbers
NEW_NODE_WHEN_LENGTH = 32
CONVERT_WHEN_SMALLER = 8
MAX_DEPTH = 32 # maybe should be smaller
CONCATENATE_WHEN_MULTIPLYING = 128
HIGHEST_BIT_SET = intmask(1L << (NBITS - 1))

def find_fib_index(l):
    if l == 0:
        return -1
    a, b = 1, 2
    i = 0
    while 1:
        if a <= l < b:
            return i
        a, b = b, a + b
        i += 1

mul_by_1000003_pow_table = [intmask(pow(1000003, 2**_i, 2**LONG_BIT))
                            for _i in range(LONG_BIT)]

def masked_mul_by_1000003_pow(a, b):
    """Computes intmask(a * (1000003**b))."""
    index = 0
    b = r_uint(b)
    while b:
        if b & 1:
            a = intmask(a * mul_by_1000003_pow_table[index])
        b >>= 1
        index += 1
    return a


class GlobalRopeInfo(object):
    """contains data that is "global" to the whole string, e.g. requires
    an iteration over the whole string"""
    def __init__(self):
        self.charbitmask = 0
        self.hash = 0
        self.is_bytestring = False
        self.is_ascii = False

    def combine(self, other, rightlength):
        result = GlobalRopeInfo()
        result.charbitmask = self.charbitmask | other.charbitmask
        h1 = self.hash
        h2 = other.hash
        x = intmask(h2 + masked_mul_by_1000003_pow(h1, rightlength))
        x |= HIGHEST_BIT_SET
        result.hash = x
        result.is_ascii = self.is_ascii and other.is_ascii
        result.is_bytestring = self.is_bytestring and other.is_bytestring
        return result


class StringNode(object):
    _additional_info = None
    def additional_info(self):
        addinfo = self._additional_info
        if addinfo is None:
            return self.compute_additional_info()
        return addinfo

    def compute_additional_info(self):
        raise NotImplementedError("base class")

    def length(self):
        raise NotImplementedError("base class")

    def is_ascii(self):
        raise NotImplementedError("base class")

    def is_bytestring(self):
        raise NotImplementedError("base class")

    def depth(self):
        return 0

    def hash_part(self):
        raise NotImplementedError("base class")

    def charbitmask(self):
        raise NotImplementedError("base class")

    def check_balanced(self):
        return True

    def getchar(self, index):
        raise NotImplementedError("abstract base class")

    def getunichar(self, index):
        raise NotImplementedError("abstract base class")

    def getint(self, index):
        raise NotImplementedError("abstract base class")

    def getrope(self, index):
        raise NotImplementedError("abstract base class")

    def getslice(self, start, stop):
        raise NotImplementedError("abstract base class")

    def can_contain_int(self, value):
        return True #conservative default

    def view(self):
        view([self])

    def rebalance(self):
        return self

    def flatten_string(self):
        raise NotImplementedError("abstract base class")

    def flatten_unicode(self):
        raise NotImplementedError("abstract base class")

    def _concat(self, other):
        raise NotImplementedError("abstract base class")

    def __add__(self, other):
        return concatenate(self, other)

    def _cleanup_(self):
        self.additional_info()

class LiteralNode(StringNode):
    def find_int(self, what, start, stop):
        raise NotImplementedError("abstract base class")



class LiteralStringNode(LiteralNode):
    def __init__(self, s):
        assert isinstance(s, str)
        self.s = s

    def length(self):
        return len(self.s)

    def is_ascii(self):
        return self.additional_info().is_ascii

    def is_bytestring(self):
        return True

    def flatten_string(self):
        return self.s

    def flatten_unicode(self):
        return self.s.decode('latin-1')

    def hash_part(self):
        return self.additional_info().hash

    def compute_additional_info(self):
        additional_info = GlobalRopeInfo()
        is_ascii = True
        charbitmask = 0
        partial_hash = 0
        for c in self.s:
            ordc = ord(c)
            partial_hash = (1000003*partial_hash) + ord(c)
            if ordc >= 128:
                is_ascii = False
            charbitmask |= intmask(1 << (ordc & 0x1F))
        partial_hash = intmask(partial_hash)
        partial_hash |= HIGHEST_BIT_SET

        additional_info.hash = partial_hash
        additional_info.is_ascii = is_ascii
        additional_info.charbitmask = charbitmask
        additional_info.is_bytestring = True
        self._additional_info = additional_info
        return additional_info

    def charbitmask(self):
        return self.additional_info().charbitmask

    def getchar(self, index):
        return self.s[index]

    def getunichar(self, index):
        return unichr(ord(self.s[index]))

    def getint(self, index):
        return ord(self.s[index])

    def getrope(self, index):
        return LiteralStringNode.PREBUILT[ord(self.s[index])]

    def can_contain_int(self, value):
        if value > 255:
            return False
        if self.is_ascii() and value > 127:
            return False
        return (1 << (value & 0x1f)) & self.charbitmask()

    def getslice(self, start, stop):
        assert 0 <= start <= stop
        return LiteralStringNode(self.s[start:stop])


    def find_int(self, what, start, stop):
        if not self.can_contain_int(what):
            return -1
        return self.s.find(chr(what), start, stop)

    def _concat(self, other):
        if (isinstance(other, LiteralStringNode) and
            len(other.s) + len(self.s) < NEW_NODE_WHEN_LENGTH):
            return LiteralStringNode(self.s + other.s)
        elif (isinstance(other, LiteralUnicodeNode) and
              len(other.u) + len(self.s) < NEW_NODE_WHEN_LENGTH and
              len(self.s) < CONVERT_WHEN_SMALLER):
            return LiteralUnicodeNode(self.s.decode("latin-1") + other.u)
        return BinaryConcatNode(self, other)

    def dot(self, seen, toplevel=False):
        if self in seen:
            return
        seen[self] = True
        addinfo = str(self.s).replace('"', "'") or "_"
        if len(addinfo) > 10:
            addinfo = addinfo[:3] + "..." + addinfo[-3:]
        yield ('"%s" [shape=box,label="length: %s\\n%s"];' % (
            id(self), len(self.s),
            repr(addinfo).replace('"', '').replace("\\", "\\\\")))
LiteralStringNode.EMPTY = LiteralStringNode("")
LiteralStringNode.PREBUILT = [LiteralStringNode(chr(i)) for i in range(256)]
del i


class LiteralUnicodeNode(LiteralNode):
    def __init__(self, u):
        assert isinstance(u, unicode)
        self.u = u

    def length(self):
        return len(self.u)

    def flatten_unicode(self):
        return self.u

    def is_ascii(self):
        return False # usually not

    def is_bytestring(self):
        return False

    def hash_part(self):
        return self.additional_info().hash

    def compute_additional_info(self):
        additional_info = GlobalRopeInfo()
        charbitmask = 0
        partial_hash = 0
        for c in self.u:
            ordc = ord(c)
            charbitmask |= intmask(1 << (ordc & 0x1F))
            partial_hash = (1000003*partial_hash) + ordc
        partial_hash = intmask(partial_hash)
        partial_hash |= HIGHEST_BIT_SET

        additional_info.charbitmask = intmask(charbitmask)
        additional_info.hash = partial_hash
        self._additional_info = additional_info
        return additional_info

    def charbitmask(self):
        return self.additional_info().charbitmask

    def getunichar(self, index):
        return self.u[index]

    def getint(self, index):
        return ord(self.u[index])

    def getrope(self, index):
        ch = ord(self.u[index])
        if ch < 256:
            return LiteralStringNode.PREBUILT[ch]
        if len(self.u) == 1:
            return self
        return LiteralUnicodeNode(unichr(ch))

    def can_contain_int(self, value):
        return (1 << (value & 0x1f)) & self.charbitmask()

    def getslice(self, start, stop):
        assert 0 <= start <= stop
        return LiteralUnicodeNode(self.u[start:stop])

    def find_int(self, what, start, stop):
        if not self.can_contain_int(what):
            return -1
        return self.u.find(unichr(what), start, stop)

    def _concat(self, other):
        if (isinstance(other, LiteralUnicodeNode) and
            len(other.u) + len(self.u) < NEW_NODE_WHEN_LENGTH):
            return LiteralUnicodeNode(self.u + other.u)
        elif (isinstance(other, LiteralStringNode) and
              len(other.s) + len(self.u) < NEW_NODE_WHEN_LENGTH and
              len(other.s) < CONVERT_WHEN_SMALLER):
            return LiteralUnicodeNode(self.u + other.s.decode("latin-1"))
        return BinaryConcatNode(self, other)

    def dot(self, seen, toplevel=False):
        if self in seen:
            return
        seen[self] = True
        addinfo = repr(self.u).replace('"', "'") or "_"
        if len(addinfo) > 10:
            addinfo = addinfo[:3] + "..." + addinfo[-3:]
        yield ('"%s" [shape=box,label="length: %s\\n%s"];' % (
            id(self), len(self.u),
            repr(addinfo).replace('"', '').replace("\\", "\\\\")))

def make_binary_get(getter):
    def get(self, index):
        while isinstance(self, BinaryConcatNode):
            llen = self.left.length()
            if index >= llen:
                self = self.right
                index -= llen
            else:
                self = self.left
        return getattr(self, getter)(index)
    return get

class BinaryConcatNode(StringNode):
    def __init__(self, left, right, balanced=False):
        self.left = left
        self.right = right
        try:
            self.len = ovfcheck(left.length() + right.length())
        except OverflowError:
            raise
        self._depth = 0
        # XXX the balance should become part of the depth
        self.balanced = balanced
        if balanced:
            self.balance_known = True
        else:
            self.balance_known = False

    def is_ascii(self):
        return self.additional_info().is_ascii

    def is_bytestring(self):
        return self.additional_info().is_bytestring

    def check_balanced(self):
        if self.balance_known:
            return self.balanced
        # balance calculation
        # XXX improve?
        if not self.left.check_balanced() or not self.right.check_balanced():
            balanced = False
        else:
            balanced = (find_fib_index(self.len // (NEW_NODE_WHEN_LENGTH / 2)) >=
                        self._depth)
        self.balanced = balanced
        self.balance_known = True
        return balanced

    def length(self):
        return self.len

    def depth(self):
        depth = self._depth
        if not depth:
            depth = self._depth = max(self.left.depth(),
                                      self.right.depth()) + 1
        return depth

    getchar = make_binary_get("getchar")
    getunichar = make_binary_get("getunichar")
    getint = make_binary_get("getint")
    getrope = make_binary_get("getrope")

    def can_contain_int(self, value):
        if self.is_bytestring() and value > 255:
            return False
        if self.is_ascii() and value > 127:
            return False
        return (1 << (value & 0x1f)) & self.charbitmask()

    def getslice(self, start, stop):
        if start == 0:
            if stop == self.length():
                return self
            return getslice_left(self, stop)
        if stop == self.length():
            return getslice_right(self, start)
        return concatenate(
            getslice_right(self.left, start),
            getslice_left(self.right, stop - self.left.length()))

    def flatten_string(self):
        f = fringe(self)
        return "".join([node.flatten_string() for node in f])

    def flatten_unicode(self):
        f = fringe(self)
        return u"".join([node.flatten_unicode() for node in f])

    def hash_part(self):
        return self.additional_info().hash

    def compute_additional_info(self):
        leftaddinfo = self.left.additional_info()
        rightaddinfo = self.right.additional_info()
        additional_info =  leftaddinfo.combine(rightaddinfo,
                                               self.right.length())
        self._additional_info = additional_info
        return additional_info

    def charbitmask(self):
        return self.additional_info().charbitmask

    def rebalance(self):
        if self.balanced:
            return self
        return rebalance([self], self.len)


    def _concat(self, other):
        if isinstance(other, LiteralNode):
            r = self.right
            if isinstance(r, LiteralNode):
                return BinaryConcatNode(self.left,
                                        r._concat(other))
        return BinaryConcatNode(self, other)

    def dot(self, seen, toplevel=False):
        if self in seen:
            return
        seen[self] = True
        if toplevel:
            addition = ", fillcolor=red"
        elif self.check_balanced():
            addition = ", fillcolor=yellow"
        else:
            addition = ""
        yield '"%s" [shape=octagon,label="+\\ndepth=%s, length=%s"%s];' % (
                id(self), self.depth(), self.len, addition)
        for child in [self.left, self.right]:
            yield '"%s" -> "%s";' % (id(self), id(child))
            for line in child.dot(seen):
                yield line


def concatenate(node1, node2):
    if node1.length() == 0:
        return node2
    if node2.length() == 0:
        return node1
    result = node1._concat(node2)
    if rebalance and result.depth() > MAX_DEPTH: #XXX better check
        return result.rebalance()
    return result


def getslice(node, start, stop, step, slicelength=-1):
    if slicelength == -1:
        # XXX for testing only
        slicelength = len(xrange(start, stop, step))
    start, stop, node = find_straddling(node, start, stop)
    if step != 1:
        iter = SeekableItemIterator(node)
        iter.seekforward(start)
        if node.is_bytestring():
            result = [iter.nextchar()]
            for i in range(slicelength - 1):
                iter.seekforward(step - 1)
                result.append(iter.nextchar())
            return rope_from_charlist(result)
        else:
            result = [iter.nextunichar()]
            for i in range(slicelength - 1):
                iter.seekforward(step - 1)
                result.append(iter.nextunichar())
            return rope_from_unicharlist(result)
    return node.getslice(start, stop)

def getslice_one(node, start, stop):
    start, stop, node = find_straddling(node, start, stop)
    return node.getslice(start, stop)

def find_straddling(node, start, stop):
    while 1:
        if isinstance(node, BinaryConcatNode):
            llen = node.left.length()
            if start >= llen:
                node = node.right
                start = start - llen
                stop = stop - llen
                continue
            if stop <= llen:
                node = node.left
                continue
        return start, stop, node

def getslice_right(node, start):
    while 1:
        if start == 0:
            return node
        if isinstance(node, BinaryConcatNode):
            llen = node.left.length()
            if start >= llen:
                node = node.right
                start = start - llen
                continue
            else:
                return concatenate(getslice_right(node.left, start),
                                   node.right)
        return node.getslice(start, node.length())

def getslice_left(node, stop):
    while 1:
        if stop == node.length():
            return node
        if isinstance(node, BinaryConcatNode):
            llen = node.left.length()
            if stop <= llen:
                node = node.left
                continue
            else:
                return concatenate(node.left,
                                   getslice_left(node.right, stop - llen))
        return node.getslice(0, stop)


def multiply(node, times):
    if times <= 0:
        return LiteralStringNode.EMPTY
    if times == 1:
        return node
    twopower = node
    number = 1
    result = None
    while number <= times:
        if number & times:
            if result is None:
                result = twopower
            elif result.length() < CONCATENATE_WHEN_MULTIPLYING:
                result = concatenate(result, twopower)
            else:
                result = BinaryConcatNode(result, twopower)
        try:
            number = ovfcheck(number * 2)
        except OverflowError:
            break
        if twopower.length() < CONCATENATE_WHEN_MULTIPLYING:
            twopower = concatenate(twopower, twopower)
        else:
            twopower = BinaryConcatNode(twopower, twopower)
    return result


def join(node, l):
    if node.length() == 0:
        return rebalance(l)
    nodelist = [None] * (2 * len(l) - 1)
    length = 0
    for i in range(len(l)):
        nodelist[2 * i] = l[i]
        length += l[i].length()
    for i in range(len(l) - 1):
        nodelist[2 * i + 1] = node
    length += (len(l) - 1) * node.length()
    return rebalance(nodelist, length)

def rebalance(nodelist, sizehint=-1):
    if sizehint < 0:
        sizehint = 0
        for node in nodelist:
            sizehint += node.length()
    if sizehint == 0:
        return LiteralStringNode.EMPTY
    nodelist.reverse()

    # this code is based on the Fibonacci identity:
    #   sum(fib(i) for i in range(n+1)) == fib(n+2)
    l = [None] * (find_fib_index(sizehint) + 2)
    stack = nodelist
    empty_up_to = len(l)
    a = b = sys.maxint
    first_node = None
    while stack:
        curr = stack.pop()
        while isinstance(curr, BinaryConcatNode) and not curr.check_balanced():
            stack.append(curr.right)
            curr = curr.left

        currlen = curr.length()
        if currlen == 0:
            continue

        if currlen < a:
            # we can put 'curr' to its preferred location, which is in
            # the known empty part at the beginning of 'l'
            a, b = 1, 2
            empty_up_to = 0
            while not (currlen < b):
                empty_up_to += 1
                a, b = b, a+b
        else:
            # sweep all elements up to the preferred location for 'curr'
            while not (currlen < b and l[empty_up_to] is None):
                if l[empty_up_to] is not None:
                    curr = l[empty_up_to]._concat(curr)
                    l[empty_up_to] = None
                    currlen = curr.length()
                else:
                    empty_up_to += 1
                    a, b = b, a+b

        if empty_up_to == len(l):
            return curr
        l[empty_up_to] = curr
        first_node = curr

    # sweep all elements
    curr = first_node
    for index in range(empty_up_to + 1, len(l)):
        if l[index] is not None:
            curr = BinaryConcatNode(l[index], curr)
    assert curr is not None
    return curr

# __________________________________________________________________________
# construction from normal strings

def rope_from_charlist(charlist):
    nodelist = []
    size = 0
    for i in range(0, len(charlist), NEW_NODE_WHEN_LENGTH):
        chars = charlist[i: min(len(charlist), i + NEW_NODE_WHEN_LENGTH)]
        nodelist.append(LiteralStringNode("".join(chars)))
        size += len(chars)
    return rebalance(nodelist, size)

def rope_from_unicharlist(charlist):
    nodelist = []
    length = len(charlist)
    if not length:
        return LiteralStringNode.EMPTY
    i = 0
    while i < length:
        unichunk = []
        while i < length:
            c = ord(charlist[i])
            if c < 256:
                break
            unichunk.append(unichr(c))
            i += 1
        if unichunk:
            nodelist.append(LiteralUnicodeNode(u"".join(unichunk)))
        strchunk = []
        while i < length:
            c = ord(charlist[i])
            if c >= 256:
                break
            strchunk.append(chr(c))
            i += 1
        if strchunk:
            nodelist.append(LiteralStringNode("".join(strchunk)))
    return rebalance(nodelist, length)

def rope_from_unicode(uni):
    nodelist = []
    length = len(uni)
    if not length:
        return LiteralStringNode.EMPTY
    i = 0
    while i < length:
        start = i
        while i < length:
            c = ord(uni[i])
            if c < 256:
                break
            i += 1
        if i != start:
            nodelist.append(LiteralUnicodeNode(uni[start:i]))
        start = i
        while i < length:
            c = ord(uni[i])
            if c >= 256:
                break
            i += 1
        if i != start:
            nodelist.append(LiteralStringNode(uni[start:i].encode("latin-1")))
    return rebalance(nodelist, length)

def rope_from_unichar(unichar):
    intval = ord(unichar)
    if intval > 256:
        return LiteralUnicodeNode(unichar)
    return LiteralStringNode.PREBUILT[intval]

# __________________________________________________________________________
# searching

def find_int(node, what, start=0, stop=-1):
    offset = 0
    length = node.length()
    if stop == -1:
        stop = length
    if start != 0 or stop != length:
        newstart, newstop, node = find_straddling(node, start, stop)
        offset = start - newstart
        start = newstart
        stop = newstop
    assert 0 <= start <= stop
    if isinstance(node, LiteralNode):
        pos = node.find_int(what, start, stop)
        if pos == -1:
            return pos
        return pos + offset
    if not node.can_contain_int(what):
        return -1
    # invariant: stack should only contain nodes that can contain the int what
    stack = [node]
    i = 0
    while stack:
        curr = stack.pop()
        while isinstance(curr, BinaryConcatNode):
            if curr.left.can_contain_int(what):
                if curr.right.can_contain_int(what):
                    stack.append(curr.right)
                curr = curr.left
            else:
                i += curr.left.length()
                # if left cannot contain what, then right must contain it
                curr = curr.right
        nodelength = curr.length()
        fringenode = curr
        if i + nodelength <= start:
            i += nodelength
            continue
        searchstart = max(0, start - i)
        searchstop = min(stop - i, nodelength)
        if searchstop <= 0:
            return -1
        assert isinstance(fringenode, LiteralNode)
        pos = fringenode.find_int(what, searchstart, searchstop)
        if pos != -1:
            return pos + i + offset
        i += nodelength
    return -1

def find(node, subnode, start=0, stop=-1):

    len1 = node.length()
    len2 = subnode.length()
    if stop > len1 or stop == -1:
        stop = len1
    if stop - start < 0:
        return -1
    if len2 == 1:
        return find_int(node, subnode.getint(0), start, stop)
    if len2 == 0:
        return start
    if len2 > stop - start:
        return -1
    restart = construct_restart_positions_node(subnode)
    return _find_node(node, subnode, start, stop, restart)

def _find_node(node, subnode, start, stop, restart):
    len2 = subnode.length()
    m = start
    iter = SeekableItemIterator(node)
    iter.seekforward(start)
    c = iter.nextint()
    i = 0
    subiter = SeekableItemIterator(subnode)
    d = subiter.nextint()
    while m + i < stop:
        if c == d:
            i += 1
            if i == len2:
                return m
            d = subiter.nextint()
            if m + i < stop:
                c = iter.nextint()
        else:
            # mismatch, go back to the last possible starting pos
            if i == 0:
                m += 1
                if m + i < stop:
                    c = iter.nextint()
            else:
                e = restart[i - 1]
                new_m = m + i - e
                assert new_m <= m + i
                seek = m + i - new_m
                if seek:
                    iter.seekback(m + i - new_m)
                    c = iter.nextint()
                m = new_m
                subiter.seekback(i - e + 1)
                d = subiter.nextint()
                i = e
    return -1

def construct_restart_positions_node(node):
    length = node.length()
    restart = [0] * length
    restart[0] = 0
    i = 1
    j = 0
    iter1 = ItemIterator(node)
    iter1.nextint()
    c1 = iter1.nextint()
    iter2 = SeekableItemIterator(node)
    c2 = iter2.nextint()
    while 1:
        if c1 == c2:
            j += 1
            if j < length:
                c2 = iter2.nextint()
            restart[i] = j
            i += 1
            if i < length:
                c1 = iter1.nextint()
            else:
                break
        elif j>0:
            new_j = restart[j-1]
            assert new_j < j
            iter2.seekback(j - new_j + 1)
            c2 = iter2.nextint()
            j = new_j
        else:
            restart[i] = 0
            i += 1
            if i < length:
                c1 = iter1.nextint()
            else:
                break
            j = 0
            iter2 = SeekableItemIterator(node)
            c2 = iter2.nextint()
    return restart

def view(objs):
    from dotviewer import graphclient
    content = ["digraph G{"]
    seen = {}
    for i, obj in enumerate(objs):
        if obj is None:
            content.append(str(i) + ";")
        else:
            content.extend(obj.dot(seen, toplevel=True))
    content.append("}")
    p = py.test.ensuretemp("automaton").join("temp.dot")
    p.write("\n".join(content))
    graphclient.display_dot_file(str(p))


# __________________________________________________________________________
# iteration

class FringeIterator(object):
    def __init__(self, node):
        self.stack = [node]

    def next(self):
        while self.stack:
            curr = self.stack.pop()
            while 1:
                if isinstance(curr, BinaryConcatNode):
                    self.stack.append(curr.right)
                    curr = curr.left
                else:
                    return curr
        raise StopIteration

    def _seekforward(self, length):
        """seek forward up to n characters, returning the number remaining chars.
        experimental api"""
        curr = None
        while self.stack:
            curr = self.stack.pop()
            if length < curr.length():
                break
            length -= curr.length()
        else:
            raise StopIteration
        while isinstance(curr, BinaryConcatNode):
            left_length = curr.left.length()
            if length < left_length:
                self.stack.append(curr.right)
                curr = curr.left
            else:
                length -= left_length
                curr = curr.right
        self.stack.append(curr)
        return length


def fringe(node):
    result = []
    iter = FringeIterator(node)
    while 1:
        try:
            result.append(iter.next())
        except StopIteration:
            return result


class ReverseFringeIterator(object):
    def __init__(self, node):
        self.stack = [node]

    def next(self):
        while self.stack:
            curr = self.stack.pop()
            while 1:
                if isinstance(curr, BinaryConcatNode):
                    self.stack.append(curr.left)
                    curr = curr.right
                else:
                    return curr
        raise StopIteration


class ItemIterator(object):
    def __init__(self, node, start=0):
        self.iter = FringeIterator(node)
        self.node = None
        self.nodelength = 0
        self.index = 0
        if start:
            self._advance_to(start)

    def _advance_to(self, index):
        self.index = self.iter._seekforward(index)
        self.node = self.iter.next()
        self.nodelength = self.node.length()

    def getnode(self):
        node = self.node
        if node is None:
            while 1:
                node = self.node = self.iter.next()
                nodelength = self.nodelength = node.length()
                if nodelength != 0:
                    self.index = 0
                    return node
        return node

    def advance_index(self):
        index = self.index
        if index == self.nodelength - 1:
            self.node = None
        else:
            self.index = index + 1

    def nextchar(self):
        node = self.getnode()
        result = node.getchar(self.index)
        self.advance_index()
        return result

    def nextunichar(self):
        node = self.getnode()
        result = node.getunichar(self.index)
        self.advance_index()
        return result

    def nextrope(self):
        node = self.getnode()
        result = node.getrope(self.index)
        self.advance_index()
        return result

    def nextint(self):
        node = self.getnode()
        result = node.getint(self.index)
        self.advance_index()
        return result

class ReverseItemIterator(object):
    def __init__(self, node):
        self.iter = ReverseFringeIterator(node)
        self.node = None
        self.index = 0

    def getnode(self):
        node = self.node
        index = self.index
        if node is None:
            while 1:
                node = self.node = self.iter.next()
                index = self.index = node.length() - 1
                if index != -1:
                    return node
        return node


    def advance_index(self):
        if self.index == 0:
            self.node = None
        else:
            self.index -= 1

    def nextchar(self):
        node = self.getnode()
        result = node.getchar(self.index)
        self.advance_index()
        return result

    def nextint(self):
        node = self.getnode()
        result = node.getint(self.index)
        self.advance_index()
        return result

    def nextunichar(self):
        node = self.getnode()
        result = node.getunichar(self.index)
        self.advance_index()
        return result

def make_seekable_method(resultgetter, backward=False):
    if backward:
        direction = -1
    else:
        direction = 1
    def next(self):
        node = self.getnode()
        result = getattr(node, resultgetter)(self.index)
        self.index += direction
        return result
    return next

class SeekableItemIterator(object):
    def __init__(self, node):
        self.stack = []
        self.tookleft = []
        self.find_downward(node)
        assert False not in self.tookleft

    def find_downward(self, node, items=0):
        assert 0 <= items < node.length()
        while isinstance(node, BinaryConcatNode):
            self.stack.append(node)
            left = node.left
            if items >= left.length():
                items -= left.length()
                node = node.right
                self.tookleft.append(False)
            else:
                node = node.left
                self.tookleft.append(True)
        assert len(self.tookleft) == len(self.stack)
        self.node = node
        self.nodelength = node.length()
        self.index = items
        return self.node

    def getnode(self):
        if self.index == self.nodelength:
            self.seekforward(0)
        if self.index == -1:
            self.seekback(0)
        return self.node

    nextchar = make_seekable_method("getchar")
    nextunichar = make_seekable_method("getunichar")
    nextint = make_seekable_method("getint")
    lastchar = make_seekable_method("getchar", backward=True)
    lastunichar = make_seekable_method("getunichar", backward=True)
    lastint = make_seekable_method("getint", backward=True)

    def seekforward(self, numchars):
        if numchars < (self.nodelength - self.index):
            self.index += numchars
            return
        numchars -= self.nodelength - self.index
        while self.stack:
            tookleft = self.tookleft.pop()
            if tookleft:
                node = self.stack[-1]
                assert isinstance(node, BinaryConcatNode)
                right = node.right
                if right.length() > numchars:
                    self.tookleft.append(False)
                    self.find_downward(right, numchars)
                    return
                numchars -= right.length()
            self.stack.pop()
        raise StopIteration


    def seekback(self, numchars):
        if numchars <= self.index:
            self.index -= numchars
            return
        numchars -= self.index
        while self.stack:
            tookleft = self.tookleft.pop()
            if not tookleft:
                node = self.stack[-1]
                assert isinstance(node, BinaryConcatNode)
                left = node.left
                if left.length() >= numchars:
                    self.tookleft.append(True)
                    self.find_downward(left, left.length() - numchars)
                    return
                numchars -= left.length()
            self.stack.pop()
        raise StopIteration


class FindIterator(object):
    def __init__(self, node, sub, start=0, stop=-1):
        self.node = node
        self.sub = sub
        len1 = self.length = node.length()
        len2 = sub.length()
        self.search_length = len2
        self.start = start
        if stop == -1 or stop > len1:
            stop = len1
        self.stop = stop
        if len2 == 0:
            self.restart_positions = None
        elif len2 == 1:
            self.restart_positions = None
        elif len2 > stop - start:
            self.restart_positions = None
            # ensure that a StopIteration is immediately raised
            self.stop = self.start
        else:
            self.restart_positions = construct_restart_positions_node(sub)

    def next(self):
        if self.search_length == 0:
            if (self.stop - self.start) < 0:
                raise StopIteration
            start = self.start
            self.start += 1
            return start
        elif self.search_length == 1:
            result = find_int(self.node, self.sub.getint(0),
                              self.start, self.stop)
            if result == -1:
                self.start = self.length
                raise StopIteration
            self.start = result + 1
            return result
        if self.start >= self.stop:
            raise StopIteration
        result = _find_node(self.node, self.sub, self.start,
                            self.stop, self.restart_positions)
        if result == -1:
            self.start = self.length
            raise StopIteration
        self.start = result + self.search_length
        return result

# __________________________________________________________________________
# comparison


def eq(node1, node2):
    if node1 is node2:
        return True
    if node1.length() != node2.length():
        return False
    if hash_rope(node1) != hash_rope(node2):
        return False
    if (isinstance(node1, LiteralStringNode) and
        isinstance(node2, LiteralStringNode)):
        return node1.s == node2.s
    if (isinstance(node1, LiteralUnicodeNode) and
        isinstance(node2, LiteralUnicodeNode)):
        return node1.u == node2.u
    iter1 = ItemIterator(node1)
    iter2 = ItemIterator(node2)
    # XXX could be cleverer and detect partial equalities
    while 1:
        try:
            c = iter1.nextint()
        except StopIteration:
            return True
        if c != iter2.nextint():
            return False

def compare(node1, node2):
    len1 = node1.length()
    len2 = node2.length()
    if not len1:
        if not len2:
            return 0
        return -1
    if not len2:
        return 1

    cmplen = min(len1, len2)
    i = 0
    iter1 = ItemIterator(node1)
    iter2 = ItemIterator(node2)
    while i < cmplen:
        diff = iter1.nextint() - iter2.nextint()
        if diff != 0:
            return diff
        i += 1
    return len1 - len2


def startswith(self, prefix, start, end):
    if prefix.length() == 0:
        return True
    if self.length() == 0:
        return False
    stop = start + prefix.length()
    if stop > end:
        return False
    iter1 = ItemIterator(self, start)
    iter2 = ItemIterator(prefix)
    for i in range(prefix.length()):
        if iter1.nextint() != iter2.nextint():
            return False
    return True

def endswith(self, suffix, start, end):
    if suffix.length() == 0:
        return True
    if self.length() == 0:
        return False
    begin = end - suffix.length()
    if begin < start:
        return False
    iter1 = ItemIterator(self, begin)
    iter2 = ItemIterator(suffix)
    for i in range(suffix.length()):
        if iter1.nextint() != iter2.nextint():
            return False
    return True

def strip(node, left=True, right=True, predicate=lambda i: chr(i).isspace(),
          *extraargs):
    length = node.length()

    lpos = 0
    rpos = length

    if left:
        iter = ItemIterator(node)
        while lpos < rpos and predicate(iter.nextint(), *extraargs):
            lpos += 1

    if right:
        iter = ReverseItemIterator(node)
        while rpos > lpos and predicate(iter.nextint(), *extraargs):
            rpos -= 1

    assert rpos >= lpos
    return getslice_one(node, lpos, rpos)
strip._annspecialcase_ = "specialize:arg(3)"

def split(node, sub, maxsplit=-1):
    startidx = 0
    substrings = []
    iter = FindIterator(node, sub)
    while maxsplit != 0:
        try:
            foundidx = iter.next()
        except StopIteration:
            break
        substrings.append(getslice_one(node, startidx, foundidx))
        startidx = foundidx + sub.length()
        maxsplit = maxsplit - 1
    substrings.append(getslice_one(node, startidx, node.length()))
    return substrings


def split_chars(node, maxsplit=-1, predicate=lambda x: chr(x).isspace()):
    result = []
    length = node.length()
    if not length:
        return result
    i = 0
    iter = ItemIterator(node)
    while True:
        # find the beginning of the next word
        while i < length:
            if not predicate(iter.nextint()):
                break   # found
            i += 1
        else:
            break  # end of string, finished

        # find the end of the word
        if maxsplit == 0:
            j = length   # take all the rest of the string
        else:
            j = i + 1
            while j < length and not predicate(iter.nextint()):
                j += 1
            maxsplit -= 1   # NB. if it's already < 0, it stays < 0

        # the word is value[i:j]
        result.append(getslice_one(node, i, j))

        # continue to look from the character following the space after the word
        i = j + 1
    return result


def rsplit_chars(node, maxsplit=-1, predicate=lambda x: chr(x).isspace()):
    result = []
    length = node.length()
    i = length - 1
    iter = ReverseItemIterator(node)
    while True:
        # starting from the end, find the end of the next word
        while i >= 0:
            if not predicate(iter.nextint()):
                break   # found
            i -= 1
        else:
            break  # end of string, finished

        # find the start of the word
        # (more precisely, 'j' will be the space character before the word)
        if maxsplit == 0:
            j = -1   # take all the rest of the string
        else:
            j = i - 1
            while j >= 0 and not predicate(iter.nextint()):
                j -= 1
            maxsplit -= 1   # NB. if it's already < 0, it stays < 0

        # the word is value[j+1:i+1]
        j1 = j + 1
        assert j1 >= 0
        result.append(getslice_one(node, j1, i + 1))

        # continue to look from the character before the space before the word
        i = j - 1

    result.reverse()
    return result


def split_completely(node, maxsplit=-1):
    upper = node.length()
    if maxsplit > 0 and maxsplit < upper + 2:
        upper = maxsplit - 1
        assert upper >= 0
    substrings = [by]
    iter = ItemIterator(node)
    for i in range(upper):
        substrings.append(iter.nextrope())
    substrings.append(rope.getslice_one(node, upper, length))


def splitlines(node, keepends=False):
    length = node.length()
    if length == 0:
        return []

    result = []
    iter = ItemIterator(node)
    i = j = 0
    last = ord(" ")
    char = iter.nextint()
    while i < length:
        # Find a line and append it
        while char != ord('\n') and char != ord('\r'):
            try:
                i += 1
                last = char
                char = iter.nextint()
            except StopIteration:
                break
        # Skip the line break reading CRLF as one line break
        eol = i
        i += 1
        last = char
        try:
            char = iter.nextint()
        except StopIteration:
            pass
        else:
            if last == ord('\r') and char == ord('\n'):
                i += 1
                try:
                    last = char
                    char = iter.nextint()
                except StopIteration:
                    pass
        if keepends:
            eol = i
        result.append(getslice_one(node, j, eol))
        j = i

    if j == 0:
        result.append(node)
    elif j < length:
        result.append(getslice_one(node, j, length))

    return result

# __________________________________________________________________________
# misc

def hash_rope(rope):
    length = rope.length()
    if length == 0:
        return -1
    x = rope.hash_part()
    x <<= 1 # get rid of the bit that is always set
    x ^= rope.getint(0)
    x ^= rope.length()
    return intmask(x)

# ____________________________________________________________
# to and from unicode conversion

def str_decode_ascii(rope):
    assert rope.is_bytestring()
    if rope.is_ascii():
        return rope
    return None

def str_decode_latin1(rope):
    assert rope.is_bytestring()
    return rope

def str_decode_utf8(rope):
    from rpython.rlib.runicode import str_decode_utf_8
    if rope.is_ascii():
        return rope
    elif isinstance(rope, BinaryConcatNode):
        lresult = str_decode_utf8(rope.left)
        if lresult is not None:
            return BinaryConcatNode(lresult,
                                    str_decode_utf8(rope.right))
    elif isinstance(rope, LiteralStringNode):
        try:
            result, consumed = str_decode_utf_8(rope.s, len(rope.s), "strict",
                                                False)
        except UnicodeDecodeError:
            return None
        if consumed < len(rope.s):
            return None
        return rope_from_unicode(result)
    s = rope.flatten_string()
    try:
        result, consumed = str_decode_utf_8(s, len(s), "strict", True)
        return rope_from_unicode(result)
    except UnicodeDecodeError:
        pass


def unicode_encode_ascii(rope):
    if rope.is_ascii():
        return rope

def unicode_encode_latin1(rope):
    if rope.is_bytestring():
        return rope

def unicode_encode_utf8(rope, allow_surrogates=False):
    from rpython.rlib.runicode import unicode_encode_utf_8
    if rope.is_ascii():
        return rope
    elif isinstance(rope, BinaryConcatNode):
        return BinaryConcatNode(unicode_encode_utf8(rope.left),
                                unicode_encode_utf8(rope.right))
    elif isinstance(rope, LiteralUnicodeNode):
        return LiteralStringNode(
            unicode_encode_utf_8(rope.u, len(rope.u), "strict",
                                 allow_surrogates=allow_surrogates))
    elif isinstance(rope, LiteralStringNode):
        return LiteralStringNode(_str_encode_utf_8(rope.s))

def _str_encode_utf_8(s):
    size = len(s)
    result = []
    i = 0
    while i < size:
        ch = ord(s[i])
        i += 1
        if (ch < 0x80):
            # Encode ASCII
            result.append(chr(ch))
            continue
        # Encode Latin-1
        result.append(chr((0xc0 | (ch >> 6))))
        result.append(chr((0x80 | (ch & 0x3f))))
    return "".join(result)

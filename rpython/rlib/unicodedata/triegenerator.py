import pprint

MINLIST  = 5 # minimum number of codepoints in range to make a list
MAXBLANK = 8 # max number of holes in a row in list range

STRIDXBITS = 16 # bits to use for string index. Remaining are
                # used for parent pointer

#
# The trie of the unicode names is stored as a list, with 16-bit
# indexes for left, right and parent pointer, and also pointer
# into the string table (which is really just a long string)
#
# note, the size of the parent and the string pointer depend
# on STRIDXBITS, the latter being used for the string pointer
# and whatever is left for the parent pointer
#
# Each node is represented by 3 entrines in the _charnodes list:
#
# [leftright, parentstr, codepoint]
#
# (keeping them dirctly in the list rather than as 3-tuples
# saves 8 bytes per entry)
#
# where leftrigt is left << 16 | right
# and parentstr is parent << STRIDXBITS | string
# (with some additional logic to account for the fact that integers
# are signed)

class TrieEntry(object):
    allstrings = set()
    counter = [0]

    def __init__(self, substring, parent, left=False, codepoint=-1):
        self.substring = substring
        self.allstrings.add(substring)
        self.codepoint = codepoint
        self.parent = parent
        self.left = self.right = None
        self.index = self.counter[0]
        self.counter[0] += 1
        if parent:
            if left:
                assert parent.left is None
                parent.left = self
            else:
                assert parent.right is None
                parent.right = self

    def as_list(self, stringidx):
        parentidx = leftidx = rightidx = -1
        if self.left:
            leftidx = self.left.index

        if self.right:
            rightidx = self.right.index

        if self.parent:
            parentidx = self.parent.index

        stridx = stringidx[self.substring]

        leftright = (leftidx&0xffff) << 16 | (rightidx&0xffff)
        if leftright >= 2**31:
            leftright = int(~0x7fffffff | (0x7fffffff&leftright))

        parentstr = ((parentidx & ((1<<(32-STRIDXBITS))-1)) << STRIDXBITS |
                      (stridx & ((1<<STRIDXBITS)-1)))
        if parentstr >= 2**31:
            parentstr = int(~0x7fffffff | (0x7fffffff&parentstr))

        return (leftright, parentstr, self.codepoint)

classdef = """
def trie_lookup(name):
    charnode = 0
    while 0 <= charnode < 0xffff: # 16bit number, 0xffff = None
        charnode *= 3
        leftright = _charnodes[charnode]
        parentstr = _charnodes[charnode + 1]
        codepoint = _charnodes[charnode + 2]

        if leftright < 0:
            # XXX assumes msb is sign
            left = 0x8000 | ((leftright & 0x7fffffff) >> 16)
        else:
            left = (leftright & 0x7fffffff) >> 16
        right = leftright & 0xffff

        if parentstr < 0:
            # XXX assumes msb is sign
            parent = 0x8000 | ((parentstr & 0x7fffffff) >> %(STRIDXBITS)d)
        else:
            parent = (parentstr & 0x7fffffff) >> %(STRIDXBITS)d
        stridx = parentstr & ((1 << %(STRIDXBITS)d) - 1)

        strlen = ord(_stringtable[stridx])
        substring = _stringtable[stridx+1:stridx+1+strlen]

        if codepoint != -1 and name == substring:
            return int(codepoint)
        if name.startswith(substring):
            name = name[strlen:]
            charnode = left
        else:
            charnode = right
    raise KeyError(name)

def name_of_node(charnode):
    res = []
    prevnode = -1
    while 0 <= charnode < 0xffff: # 16bit number, 0xffff = None
        charnode *= 3
        leftright = _charnodes[charnode]
        parentstr = _charnodes[charnode + 1]
        codepoint = _charnodes[charnode + 2]

        if leftright < 0:
            # XXX assumes msg is sign
            left = 0x8000 | ((leftright & 0x7fffffff) >> 16)
        else:
            left = (leftright & 0x7fffffff) >> 16
        right = leftright & 0xffff

        if parentstr < 0:
            # XXX assumes msb is sign
            parent = 0x8000 | ((parentstr & 0x7fffffff) >> %(STRIDXBITS)d)
        else:
            parent = (parentstr & 0x7fffffff) >> %(STRIDXBITS)d

        if prevnode < 0 or prevnode == left:
            stridx = parentstr & ((1<<%(STRIDXBITS)d)-1)
            strlen = ord(_stringtable[stridx])
            substring = _stringtable[stridx+1:stridx+1+strlen]
            res.append(substring)

        prevnode = charnode // 3
        charnode = parent

    res.reverse()
    return ''.join(res)

""" % globals()

def findranges(d):
    ranges = []
    for i in range(max(d)+1):
        if i in d:
            if not ranges:
                ranges.append((i,i))
                last = i
                continue
            if last + 1 == i:
                ranges[-1] = (ranges[-1][0], i)
            else:
                ranges.append((i,i))
            last = i
    return ranges

def collapse_ranges(ranges):
    collapsed = [ranges[0]]
    for i in range(1,len(ranges)):
        lows, lowe = collapsed[-1]
        highs, highe = ranges[i]
        if highs - lowe < MAXBLANK:
            collapsed[-1] = (lows, highe)
        else:
            collapsed.append(ranges[i])

    return collapsed

def build_compression_tree(outfile, ucdata):
    print >> outfile, "#" + "_" * 60
    print >> outfile, "# output from build_compression_tree"
    if not ucdata:
        print >> outfile, empty_trie_functions
        return
    print >> outfile, classdef

    reversedict = {}
    rootnode = gen_compression_tree(ucdata.keys(), ucdata, reversedict)

    # write string table
    print >> outfile, "_stringtable = ("
    stringidx = {}
    stridx = 0
    for string in sorted(rootnode.allstrings):
        strlen = len(string)
        assert strlen < 256, "Substring too long, > 255 chars"
        print >> outfile, "%r" % (chr(strlen) + string)
        stringidx[string] = stridx
        stridx += strlen + 1

    print >> outfile, ")"

    assert stridx < (1<<STRIDXBITS), "Too many strings, > %d chars" % (
        ((1<<STRIDXBITS) - 1))

    # build trie list
    nodelist = []
    maxidx = 0
    nodes = [rootnode]

    while nodes:
        n = nodes.pop()
        nodelist.append(n)
        if n.left:
            nodes.append(n.left)
        if n.right:
            nodes.append(n.right)

    nodelist.sort(key=lambda x: x.index)
    newnodes = []
    map(newnodes.extend, (n.as_list(stringidx) for n in nodelist))
    print >> outfile, "_charnodes =",
    pprint.pprint(newnodes, stream=outfile)

    function = ["def lookup_charcode(code):",
                "    res = -1"]
    ranges = collapse_ranges(findranges(reversedict))
    prefix = ""
    for low, high in ranges:
        if high - low <= MINLIST:
            for code in range(low, high + 1):
                if code in reversedict:
                    function.append(
                        "    %sif code == %d: res = %s" %
                        (prefix, code, reversedict[code].index))
                    prefix = "el"
            continue

        function.append(
            "    %sif %d <= code <= %d: res = _charnames_%d[code-%d]" % (
            prefix, low, high, low, low))
        prefix = "el"

        print >> outfile, "_charnames_%d = [" % (low,)
        for code in range(low, high + 1):
            if code in reversedict:
                print >> outfile, "%s," % (reversedict[code].index,)
            else:
                print >> outfile, "-1,"
        print >> outfile, "]\n"

    function.extend(["    if res == -1: raise KeyError(code)",
                     "    return name_of_node(res)",
                     "",
                     ])
    print >> outfile, '\n'.join(function)
    print >> outfile, "# end output from build_compression_tree"
    print >> outfile, "#" + "_" * 60
    return rootnode

def gen_compression_tree(stringlist, ucdata, reversedict, parent=None, parent_str="", left=False):
    # Find "best" startstring
    if not stringlist:
        return None
    codes = {}
    for string in stringlist:
        for stop in range(1, len(string) + 1):
            codes[string[:stop]] = codes.get(string[:stop], 0) + 1

    s = [((freq), code) for (code, freq) in codes.iteritems()]
    s.sort()
    if not s:
        return None
    newcode = s[-1][1]

    has_substring = []
    other_substring = []
    codepoint = -1
    for string in stringlist:
        if string == newcode:
            codepoint = ucdata[parent_str+string]
        elif string.startswith(newcode):
            has_substring.append(string[len(newcode):])
        else:
            other_substring.append(string)

    btnode = TrieEntry(newcode, parent, left, codepoint)
    if codepoint != -1:
        reversedict[codepoint] = btnode

    gen_compression_tree(
        has_substring, ucdata, reversedict,
        parent=btnode, parent_str=parent_str+newcode,
        left=True)
    gen_compression_tree(
        other_substring, ucdata, reversedict,
        parent=btnode, parent_str=parent_str,
        left=False)

    return btnode

def count_tree(tree):
    def subsum(tree, cset):
        if not tree:
            return 0, 0
        cset.add(tree.substring)
        lcount, ldepth = subsum(tree.left,cset)
        rcount, rdepth = subsum(tree.right,cset)
        return lcount+rcount+1, max(ldepth, rdepth) + 1

    cset = set()
    nodecount = subsum(tree, cset)
    strsize = sum(3*4 + len(s) for s in cset)
    nchars = sum(map(len, cset))

    return strsize, nodecount, nchars

if __name__ == '__main__':
    testdata = {
        'AAA' : 0,
        'AAAA' : 1,
        'AAB' : 2,
        'ABA' : 3,
        'BBB' : 4,
        'ACA' : 5,
        }

    import sys

    build_compression_tree(sys.stdout, testdata)

empty_trie_functions = """
def trie_lookup(name):
    raise KeyError
def lookup_charcode(code):
    raise KeyError
"""

#!/usr/bin/env python
""" Usage: traceviewer.py [--use-threshold] loopfile
"""

import optparse
import sys
import re
import math
import py

from rpython.translator.tool.graphpage import GraphPage
from rpython.translator.tool.make_dot import DotGen
from rpython.tool import logparser
from rpython.tool import progressbar

class SubPage(GraphPage):
    def compute(self, graph):
        self.links = {}
        dotgen = DotGen(str(graph.no))
        # split over debug_merge_points
        counter = 0
        lines = graph.content.split("\n")
        lines_so_far = []
        for line in lines:
            line = re.sub('.\[.*\]', '', line)
            boxes = re.findall('([pif]\d+)', line)
            for box in boxes:
                self.links[box] = box
            if 'debug_merge_point' in line:
                dotgen.emit_node('node%d' % counter, shape="box",
                                 label="\n".join(lines_so_far))
                if counter != 0:
                    dotgen.emit_edge('node%d' % (counter - 1), 'node%d' % counter)
                counter += 1
                lines_so_far = []
            lines_so_far.append(line)
        dotgen.emit_node('node%d' % counter, shape="box",
                         label="\n".join(lines_so_far))
        dotgen.emit_edge('node%d' % (counter - 1), 'node%d' % counter)
        self.source = dotgen.generate(target=None)

class Page(GraphPage):
    def compute(self, graphs, counts):
        dotgen = DotGen('trace')
        self.loops = graphs
        self.links = {}
        self.cache = {}
        for loop in self.loops:
            loop.generate(dotgen, counts)
            loop.getlinks(self.links)
            self.cache["loop" + str(loop.no)] = loop
        self.source = dotgen.generate(target=None)

    def followlink(self, label):
        return SubPage(self.cache[label])

BOX_COLOR = (128, 0, 96)

GUARDNO_RE = "((0x)?[\da-f]+)"
def guard_number(guardno_match):
    if (len(guardno_match) == 1 # ("12354",)
        or guardno_match[1] != "0x" # ("12345", None)
    ):
        return int(guardno_match[0])
    else: # ("0x12ef", "0x")
        return int(guardno_match[0], 16)

def guard_number_string(guardno_match):
    return guardno_match[0] # its always the first group

class BasicBlock(object):
    counter = 0
    startlineno = 0

    def __init__(self, content):
        self.content = content
        self.no = self.counter
        self.__class__.counter += 1

    def name(self):
        return 'node' + str(self.no)

    def getlinks(self, links):
        links[self.linksource] = self.name()

    def generate(self, dotgen, counts):
        val = counts.get(self.key, 0)
        if False: #val > counts.threshold:
            fillcolor = get_gradient_color(self.ratio)
        else:
            fillcolor = "white"
        dotgen.emit_node(self.name(), label=self.header,
                         shape='box', fillcolor=fillcolor)

    def get_content(self):
        return self._content

    def set_content(self, content):
        self._content = content
        groups = re.findall('Guard' + GUARDNO_RE, content)
        if not groups:
            self.first_guard = -1
            self.last_guard = -1
        else:
            # guards can be out of order nowadays
            groups = sorted(map(guard_number, groups))
            self.first_guard = groups[0]
            self.last_guard = groups[-1]

    content = property(get_content, set_content)

def get_gradient_color(ratio):
    if ratio == 0:
        return 'white'
    ratio = math.log(ratio)      # from -infinity to +infinity
    #
    # ratio: <---------------------- 1.8 --------------------->
    #        <-- towards green ---- YELLOW ---- towards red -->
    #
    ratio -= 1.8
    ratio = math.atan(ratio * 5) / (math.pi/2)
    # now ratio is between -1 and 1
    if ratio >= 0.0:
        # from yellow (ratio=0) to red (ratio=1)
        return '#FF%02X00' % (int((1.0-ratio)*255.5),)
    else:
        # from yellow (ratio=0) to green (ratio=-1)
        return '#%02XFF00' % (int((1.0+ratio)*255.5),)

class FinalBlock(BasicBlock):
    def __init__(self, content, target):
        self.target = target
        BasicBlock.__init__(self, content)

    def postprocess(self, loops, memo, counts):
        postprocess_loop(self.target, loops, memo, counts)

    def generate(self, dotgen, counts):
        BasicBlock.generate(self, dotgen, counts)
        if self.target is not None:
            dotgen.emit_edge(self.name(), self.target.name())

class Block(BasicBlock):
    def __init__(self, content, left, right):
        self.left = left
        self.right = right
        BasicBlock.__init__(self, content)

    def postprocess(self, loops, memo, counts):
        postprocess_loop(self.left, loops, memo, counts)
        postprocess_loop(self.right, loops, memo, counts)

    def generate(self, dotgen, counts):
        BasicBlock.generate(self, dotgen, counts)
        dotgen.emit_edge(self.name(), self.left.name())
        dotgen.emit_edge(self.name(), self.right.name())

def split_one_loop(real_loops, guard_s, guard_content, lineno, no, allloops):
    for i in range(len(allloops) - 1, -1, -1):
        loop = allloops[i]
        if no < loop.first_guard or no > loop.last_guard:
            continue
        content = loop.content
        pos = content.find(guard_s + '>')
        if pos != -1:
            newpos = content.rfind("\n", 0, pos)
            oldpos = content.find("\n", pos)
            assert newpos != -1
            if oldpos == -1:
                oldpos = len(content)
            if isinstance(loop, Block):
                left = Block(content[oldpos:], loop.left, loop.right)
            else:
                left = FinalBlock(content[oldpos:], None)
            right = FinalBlock(guard_content, None)
            mother = Block(content[:oldpos], len(allloops), len(allloops) + 1)
            allloops[i] = mother
            allloops.append(left)
            allloops.append(right)
            if hasattr(loop, 'loop_no'):
                real_loops[loop.loop_no] = mother
                mother.loop_no = loop.loop_no
            mother.guard_s = guard_s
            mother.startlineno = loop.startlineno
            left.startlineno = loop.startlineno + content.count("\n", 0, pos)
            right.startlineno = lineno
            return
    else:
        raise Exception("Did not find")

MAX_LOOPS = 300
LINE_CUTOFF = 300

def fillappend(lst, elem, no):
    there = len(lst)
    assert there <= no
    for _ in range(no - there):
        lst.append(None)
    lst.append(elem)

def splitloops(loops):
    real_loops = []
    counter = 1
    bar = progressbar.ProgressBar(color='blue')
    allloops = []
    for i, loop in enumerate(loops): 
        if i > MAX_LOOPS:
            return real_loops, allloops
        bar.render((i * 100) / len(loops))
        firstline = loop[:loop.find("\n")]
        m = re.match('# Loop (\d+)', firstline)
        if m:
            no = int(m.group(1))
            assert len(real_loops) <= no
            _loop = FinalBlock(loop, None)
            fillappend(real_loops, _loop, no)
            _loop.startlineno = counter
            _loop.loop_no = no
            allloops.append(_loop)
        else:
            m = re.search("bridge out of Guard " + GUARDNO_RE, firstline)
            assert m
            guard_s = 'Guard' + guard_number_string(m.groups())
            split_one_loop(real_loops, guard_s, loop, counter,
                           guard_number(m.groups()), allloops)
        counter += loop.count("\n") + 2
    return real_loops, allloops


def find_name_key(l):
    m = re.search("debug_merge_point\((?:\d+,\ )*'(.*)'(?:, \d+)*\)", l.content)
    if m is None:
        # default fallback
        return '?', '?'
    info = m.group(1)

    # PyPy (pypy/module/pypyjit/interp_jit.py, pypy/interpreter/generator.py)
    # '<code object f5. file 'f.py'. line 34> #63 GET_ITER'
    # '<code object f5. file 'f.py'. line 34> <generator>'
    m = re.search("^(<code object (.*?)> (.*?))$", info)
    if m:
        return m.group(2) + " " + m.group(3), m.group(1)

    # PyPy cffi (pypy/module/_cffi_backend/ccallback.py)
    # 'cffi_callback <code object f5. file 'f.py'. line 34>', 'cffi_callback <?>'
    # 'cffi_call_python somestr'
    m = re.search("^((cffi_callback) <code object (.*?)>)$", info)
    if m:
        return "%s (%s)" %(m.group(3), m.group(2)), m.group(1)
    m = re.search("^((cffi_callback) <\?>)$", info)
    if m:
        return "? (%s)" %(m.group(2)), m.group(1)
    m = re.search("^((cffi_call_python) (.*))$", info)
    if m:
        return "%s (%s)" %(m.group(3), m.group(2)), m.group(1)

    # RSqueak/lang-smalltalk (spyvm/interpreter.py)
    # '(SequenceableCollection >> #replaceFrom:to:with:startingAt:) [8]: <0x14>pushTemporaryVariableBytecode(4)'
    m = re.search("^(\(((.+?) >> )?(#.*)\) \[(\d+)\].+?>(.*?)(?:\(\d+\))?)$", info)
    if m:
        if m.group(3):
            return "%s>>%s @ %s <%s>" % (m.group(3), m.group(4), m.group(5), m.group(6)), m.group(1)
        else:
            return "%s @ %s <%s>" % (m.group(4), m.group(5), m.group(6)), m.group(1)

    # lang-js (js/jscode.py)
    # '54: LOAD LIST 4'
    # '44: LOAD_MEMBER_DOT function: barfoo'
    # '87: end of opcodes'
    m = re.search("^((\d+): (.+?)(:? function: (.+?))?)$", info)
    if m:
        if m.group(5):
            return "%s @ %s <%s>" % (m.group(5), m.group(2), m.group(3)), m.group(1)
        else:
            return "? @ %s <%s>" % (m.group(2), m.group(3)), m.group(1)

    # pycket (pycket/interpreter.py) [sorted down because the s-exp is very generic]
    # 'Green_Ast is None'
    # 'Label(safe_return_multi_vals:pycket.interpreter:565)'
    # '(*node2 item AppRand1_289 AppRand2_116)'
    if info[0] == '(' and info[-1] == ')':
        if len(info) > 64: #s-exp can be quite long
            return info[:64] +'...', info

    # info fallback (eg, rsre_jit, qoppy, but also
    #  pyhaskell (pyhaskell/interpreter/haskell.py)
    #  pyrolog (prolog/interpreter/continuation.py)
    #  RPySOM/RTruffleSom (src/som/interpreter/interpreter.py)
    #  Topaz (topaz/interpreter.py)
    #  hippyvm (hippy/interpreter.py)
    return info, info

def postprocess_loop(loop, loops, memo, counts):

    if loop in memo:
        return
    memo.add(loop)
    if loop is None:
        return
    name, loop.key = find_name_key(loop)
    opsno = loop.content.count("\n")
    lastline = loop.content[loop.content.rfind("\n", 0, len(loop.content) - 2):]
    m = re.search('descr=<Loop(\d+)', lastline)
    if m is not None:
        assert isinstance(loop, FinalBlock)
        loop.target = loops[int(m.group(1))]
    bcodes = loop.content.count('debug_merge_point')
    loop.linksource = "loop" + str(loop.no)
    loop.header = ("%s loop%d\nrun %s times\n%d operations\n%d opcodes" %
                   (name, loop.no, counts.get(loop.key, '?'), opsno, bcodes))
    loop.header += "\n" * (opsno / 100)
    if bcodes == 0:
        loop.ratio = opsno
    else:
        loop.ratio = float(opsno) / bcodes
    content = loop.content
    loop.content = "Logfile at %d\n" % loop.startlineno + content
    loop.postprocess(loops, memo, counts)

def postprocess(loops, allloops, counts):
    for loop in allloops:
        if isinstance(loop, Block):
            loop.left = allloops[loop.left]
            loop.right = allloops[loop.right]
    memo = set()
    for loop in loops:
        postprocess_loop(loop, loops, memo, counts)

class Counts(dict):
    pass

def main(loopfile, use_threshold, view=True):
    countname = py.path.local(loopfile + '.count')
    if countname.check():
        #counts = [line.split(':', 1) for line in countname.readlines()]
        #counts = Counts([('<code' + k.strip("\n"), int(v.strip('\n').strip()))
        #                 for v, k in counts])
        counts = Counts([])
        l = list(sorted(counts.values()))
        if len(l) > 20 and use_threshold:
            counts.threshold = l[-20]
        else:
            counts.threshold = 0
        for_print = [(v, k) for k, v in counts.iteritems()]
        for_print.sort()
    else:
        counts = {}
    log = logparser.parse_log_file(loopfile)
    loops = logparser.extract_category(log, "jit-log-opt-")
    real_loops, allloops = splitloops(loops)
    postprocess(real_loops, allloops, counts)
    if view:
        Page(allloops, counts).display()

if __name__ == '__main__':
    parser = optparse.OptionParser(usage=__doc__)
    parser.add_option('--use-threshold', dest='use_threshold',
                      action="store_true", default=False)
    options, args = parser.parse_args(sys.argv)
    if len(args) != 2:
        print __doc__
        sys.exit(1)
    main(args[1], options.use_threshold)

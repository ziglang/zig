#! /usr/bin/env python
"""
Viewer for the output of compiled programs generating code.
Use on the log files created with 'PYPYLOG=jit-backend-dump:log'.

Try:
    ./viewcode.py --text log        # text only disassembly
    ./viewcode.py log               # also includes a pygame viewer
"""

import new
import operator
import os
import py
import re
import sys
import subprocess
from bisect import bisect_left

# ____________________________________________________________
# Some support code from Psyco.  There is more over there,
# I am porting it in a lazy fashion...  See py-utils/xam.py

if sys.platform == "win32":
    pass   # lots more in Psyco

class ObjdumpNotFound(Exception):
    pass

def find_objdump():
    exe = ('objdump', 'gobjdump', 'objdump.exe')
    path = os.environ['PATH'].split(os.pathsep)
    for e in exe:
        for p in path:
            path_to = os.path.join(p, e)
            if not os.path.exists(path_to):
                continue
            return e
    raise ObjdumpNotFound('(g)objdump was not found in PATH')

def machine_code_dump(data, originaddr, backend_name, label_list=None):
    objdump_machine_option = {
        'x86': 'i386',
        'x86-without-sse2': 'i386',
        'x86_32': 'i386',
        'x86_64': 'i386:x86-64',
        'x86-64': 'i386:x86-64',
        'i386': 'i386',
        'arm': 'arm',
        'arm_32': 'arm',
        'aarch64': 'aarch64',
        'ppc' : 'powerpc:common64',
        'ppc-64' : 'powerpc:common64',
        's390x': 's390:64-bit',
    }
    machine_endianness = {
        # default value: 'little'
        'ppc' : sys.byteorder,     # i.e. same as the running machine...
        'ppc-64' : sys.byteorder,     # i.e. same as the running machine...
        's390x' : sys.byteorder,     # i.e. same as the running machine...
    }
    cmd = find_objdump()
    objdump = ('%(command)s -b binary -m %(machine)s '
               '--endian=%(endianness)s '
               '--disassembler-options=intel-mnemonics '
               '--adjust-vma=%(origin)d -D %(file)s')
    #
    f = open(tmpfile, 'wb')
    f.write(data)
    f.close()
    p = subprocess.Popen(objdump % {
        'command': cmd,
        'file': tmpfile,
        'origin': originaddr,
        'machine': objdump_machine_option[backend_name],
        'endianness': machine_endianness.get(backend_name, 'little'),
    }, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    stdout, stderr = p.communicate()
    assert not p.returncode, ('Encountered an error running objdump: %s' %
                              stderr)
    # drop some objdump cruft
    lines = stdout.splitlines(True)[6:]     # drop some objdump cruft
    return format_code_dump_with_labels(originaddr, lines, label_list)

def format_code_dump_with_labels(originaddr, lines, label_list):
    from rpython.rlib.rarithmetic import r_uint
    if not label_list:
        label_list = []
    originaddr = r_uint(originaddr)
    itlines = iter(lines)
    yield itlines.next() # don't process the first line
    for lbl_start, lbl_name in label_list:
        for line in itlines:
            addr, _ = line.split(':', 1)
            addr = int(addr, 16)
            if addr >= originaddr+lbl_start:
                yield '\n'
                if lbl_name is None:
                    yield '--end of the loop--\n'
                else:
                    yield str(lbl_name) + '\n'
                yield line
                break
            yield line
    # yield all the remaining lines
    for line in itlines:
        yield line

def load_symbols(filename):
    # the program that lists symbols, and the output it gives
    symbollister = 'nm %s'
    re_symbolentry = re.compile(r'([0-9a-fA-F]+)\s\w\s(.*)')
    #
    print 'loading symbols from %s...' % (filename,)
    symbols = {}
    p = subprocess.Popen(symbollister % filename, shell=True,
                         stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    stdout, stderr = p.communicate()
    assert not p.returncode, ('Encountered an error running nm: %s' %
                              stderr)
    for line in stdout.splitlines(True):
        match = re_symbolentry.match(line)
        if match:
            addr = long(match.group(1), 16)
            name = match.group(2)
            if name.startswith('pypy_g_'):
                name = '\xb7' + name[7:]
            symbols[addr] = name
    print '%d symbols found' % (len(symbols),)
    return symbols

re_addr = re.compile(r'[\s,$]0x([0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]+)')
re_lineaddr = re.compile(r'\s*0?x?([0-9a-fA-F]+)')

def lineaddresses(line):
    result = []
    i = 0
    while 1:
        match = re_addr.search(line, i)
        if not match:
            break
        i = match.end()
        addr = long(match.group(1), 16)
        result.append(addr)
    return result

# ____________________________________________________________

class CodeRange(object):
    fallthrough = False

    def __init__(self, world, addr, data):
        self.world = world
        self.addr = addr
        self.data = data

    def __repr__(self):
        return '<CodeRange %s length %d>' % (hex(self.addr), len(self.data))

    def touches(self, other):
        return (self .addr < other.addr + len(other.data) and
                other.addr < self .addr + len(self.data))

    def update_from_old(self, other):
        if other.addr < self.addr:
            delta = self.addr - other.addr
            assert delta <= len(other.data)
            self.addr -= delta
            self.data = other.data[:delta] + self.data
        self_end  = self .addr + len(self .data)
        other_end = other.addr + len(other.data)
        if other_end > self_end:
            extra = other_end - self_end
            assert extra <= len(other.data)
            self.data += other.data[-extra:]

    def cmpop(op):
        def _cmp(self, other):
            if not isinstance(other, CodeRange):
                return NotImplemented
            return op((self.addr, self.data), (other.addr, other.data))
        return _cmp
    __lt__ = cmpop(operator.lt)
    __le__ = cmpop(operator.le)
    __eq__ = cmpop(operator.eq)
    __ne__ = cmpop(operator.ne)
    __gt__ = cmpop(operator.gt)
    __ge__ = cmpop(operator.ge)
    del cmpop

    def disassemble(self):
        if not hasattr(self, 'text'):
            lines = machine_code_dump(self.data, self.addr, self.world.backend_name)
            lines = list(lines)
            # instead of adding symbol names in the dumps we could
            # also make the 0xNNNNNNNN addresses be red and show the
            # symbol name when the mouse is over them
            logentries = self.world.logentries
            symbols = self.world.symbols
            for i, line in enumerate(lines):
                match = re_lineaddr.match(line)
                if match:
                    addr = long(match.group(1), 16)
                    logentry = logentries.get(addr)
                    if logentry:
                        lines[i] = '\n%s\n%s' % (logentry, lines[i])
                for addr in lineaddresses(line):
                    sym = symbols.get(addr)
                    if sym:
                        lines[i] = '%s\t%s\n' % (lines[i].rstrip(), sym)
            self.text = ''.join(lines)
        return self.text

    def findjumps(self):
        text = self.disassemble()
        lines = text.splitlines()
        line = ''
        for i, line in enumerate(lines):
            if '\tj' not in line: # poor heuristic to recognize lines that
                continue          # could be jump instructions
            addrs = list(lineaddresses(line))
            if not addrs:
                continue
            addr = addrs[-1]
            final = '\tjmp' in line
            yield i, addr, final
        if self.fallthrough and '\tret' not in line and "\tjmp    r11" not in line:
            yield len(lines), self.addr + len(self.data), True


class World(object):

    def __init__(self):
        self.ranges = []
        self.labeltargets = {}
        self.jumps = {}
        self.symbols = {}
        self.logentries = {}
        self.backend_name = None
        self.executable_name = None

    def parse(self, f, textonly=True):
        for line in f:
            if line.startswith('BACKEND '):
                self.backend_name = line.split(' ')[1].strip()
            elif line.startswith('CODE_DUMP '):
                pieces = line.split()
                assert pieces[1].startswith('@')
                assert pieces[2].startswith('+')
                if len(pieces) == 3:
                    continue     # empty line
                baseaddr = long(pieces[1][1:], 16)
                if baseaddr < 0:
                    baseaddr += (2 * sys.maxint + 2)
                offset = int(pieces[2][1:])
                addr = baseaddr + offset
                data = pieces[3].replace(':', '').decode('hex')
                coderange = CodeRange(self, addr, data)
                i = bisect_left(self.ranges, coderange)
                j = i
                while i>0 and coderange.touches(self.ranges[i-1]):
                    coderange.update_from_old(self.ranges[i-1])
                    i -= 1
                while j<len(self.ranges) and coderange.touches(self.ranges[j]):
                    coderange.update_from_old(self.ranges[j])
                    j += 1
                self.ranges[i:j] = [coderange]
            elif line.startswith('LOG '):
                pieces = line.split(None, 3)
                assert pieces[1].startswith('@')
                assert pieces[2].startswith('+')
                baseaddr = long(pieces[1][1:], 16)
                if baseaddr < 0:
                    baseaddr += (2 * sys.maxint + 2)
                offset = int(pieces[2][1:])
                addr = baseaddr + offset
                self.logentries[addr] = pieces[3]
            elif line.startswith('SYS_EXECUTABLE '):
                filename = line[len('SYS_EXECUTABLE '):].strip()
                if filename != self.executable_name and filename != '??':
                    try:
                        self.symbols.update(load_symbols(filename))
                    except Exception as e:
                        print e
                    self.executable_name = filename

    def find_cross_references(self):
        # find cross-references between blocks
        fnext = 0.1
        for i, r in enumerate(self.ranges):
            for lineno, targetaddr, _ in r.findjumps():
                self.labeltargets[targetaddr] = True
            if i % 100 == 99:
                f = float(i) / len(self.ranges)
                if f >= fnext:
                    sys.stderr.write("%d%%" % int(f*100.0))
                    fnext += 0.1
                sys.stderr.write(".")
        sys.stderr.write("100%")
        # split blocks at labeltargets
        t = self.labeltargets
        #print t
        for r in self.ranges:
            #print r.addr, r.addr + len(r.data)
            for i in range(r.addr + 1, r.addr + len(r.data)):
                if i in t:
                    #print i
                    ofs = i - r.addr
                    self.ranges.append(CodeRange(self, i, r.data[ofs:]))
                    r.data = r.data[:ofs]
                    r.fallthrough = True
                    try:
                        del r.text
                    except AttributeError:
                        pass
                    break
        # hack hack hacked
        sys.stderr.write("\n")

    def show(self, showtext=True, showgraph=True):
        if showgraph:
            g1 = Graph('codedump')
        self.ranges.sort()
        for r in self.ranges:
            disassembled = r.disassemble()
            if showtext:
                print disassembled
            if showgraph:
                text, width = tab2columns(disassembled)
                text = '0x%x\n\n%s' % (r.addr, text)
                g1.emit_node('N_%x' % r.addr, shape="box", label=text,
                             width=str(width*0.1125))
                for lineno, targetaddr, final in r.findjumps():
                    if final:
                        color = "black"
                    else:
                        color = "red"
                    g1.emit_edge('N_%x' % r.addr, 'N_%x' % targetaddr,
                                 color=color)
        sys.stdout.flush()
        if showgraph:
            g1.display()

    def showtextonly(self):
        self.ranges.sort()
        for r in self.ranges:
            disassembled = r.disassemble()
            print disassembled
            del r.text


def tab2columns(text):
    lines = text.split('\n')
    columnwidth = []
    for line in lines:
        columns = line.split('\t')[:-1]
        while len(columnwidth) < len(columns):
            columnwidth.append(0)
        for i, s in enumerate(columns):
            width = len(s.strip())
            if not s.endswith(':'):
                width += 2
            columnwidth[i] = max(columnwidth[i], width)
    columnwidth.append(1)
    result = []
    for line in lines:
        columns = line.split('\t')
        text = []
        for width, s in zip(columnwidth, columns):
            text.append(s.strip().ljust(width))
        result.append(' '.join(text))
    lengths = [len(line) for line in result]
    lengths.append(1)
    totalwidth = max(lengths)
    return '\\l'.join(result), totalwidth

# ____________________________________________________________
# XXX pasted from
# http://codespeak.net/svn/user/arigo/hack/misc/graphlib.py
# but needs to be a bit more subtle later

from rpython.translator.tool.make_dot import DotGen
from dotviewer.graphclient import display_page

class Graph(DotGen):

    def highlight(self, word, text, linked_to=None):
        if not hasattr(self, '_links'):
            self._links = {}
            self._links_to = {}
        self._links[word] = text
        if linked_to:
            self._links_to[word] = linked_to

    def display(self):
        "Display a graph page locally."
        display_page(_Page(self))


class NoGraph(Exception):
    pass

class _Page:
    def __init__(self, graph_builder):
        if callable(graph_builder):
            graph = graph_builder()
        else:
            graph = graph_builder
        if graph is None:
            raise NoGraph
        self.graph_builder = graph_builder

    def content(self):
        return _PageContent(self.graph_builder)

class _PageContent:
    fixedfont = True

    def __init__(self, graph_builder):
        if callable(graph_builder):
            graph = graph_builder()
        else:
            graph = graph_builder
        assert graph is not None
        self.graph_builder = graph_builder
        self.graph = graph
        self.links = getattr(graph, '_links', {})
        if not hasattr(graph, '_source'):
            graph._source = graph.generate(target=None)
        self.source = graph._source

    def followlink(self, link):
        try:
            return _Page(self.graph._links_to[link])
        except NoGraph:
            return _Page(self.graph_builder)

# ____________________________________________________________

if __name__ == '__main__':
    # don't use rpython.tool.udir here to avoid removing old usessions which
    # might still contain interesting executables
    udir = py.path.local.make_numbered_dir(prefix='viewcode-', keep=2)
    tmpfile = str(udir.join('dump.tmp'))

    # hack hack
    import rpython.tool
    mod = new.module('rpython.tool.udir')
    mod.udir = udir
    sys.modules['rpython.tool.udir'] = mod
    rpython.tool.udir = mod

    if '--text' in sys.argv:
        sys.argv.remove('--text')
        showgraph = False
    else:
        showgraph = True
    if len(sys.argv) != 2:
        print >> sys.stderr, __doc__
        sys.exit(2)
    #
    import cStringIO
    from rpython.tool import logparser
    log1 = logparser.parse_log_file(sys.argv[1])
    text1 = logparser.extract_category(log1, catprefix='jit-backend-dump')
    f = cStringIO.StringIO()
    f.writelines(text1)
    f.seek(0)
    del log1, text1
    #
    world = World()
    world.parse(f)
    if showgraph:
        world.find_cross_references()
        world.show(showtext=True)
    else:
        world.showtextonly()
else:
    from rpython.tool.udir import udir
    tmpfile = str(udir.join('dump.tmp'))
    

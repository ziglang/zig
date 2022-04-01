import re, sys

from rpython.jit.metainterp.resoperation import opname
from rpython.jit.tool.oparser import OpParser
from rpython.tool.logparser import parse_log_file, extract_category
from copy import copy

def parse_code_data(arg):
    name = None
    lineno = 0
    filename = None
    bytecode_no = 0
    bytecode_name = None
    mask = 0
    # generic format: the numbers are 'startlineno-currentlineno',
    # and this function returns currentlineno as the value
    # 'bytecode_no = currentlineno ^ -1': i.e. it abuses bytecode_no,
    # which doesn't make sense in the generic format, as a negative
    # number
    m = re.match(r'(.+?);(.+?):(\d+)-(\d+)~(.*)', arg)
    if m is not None:
        mask = -1
    else:
        # PyPy2 format: bytecode_no is really a bytecode index,
        # which must be turned into a real line number by parsing the
        # source file
        m = re.search(r'<code object ([<>\w]+)[\.,] file \'(.+?)\'[\.,] '
                      r'line (\d+)> #(\d+) (\w+)', arg)
    if m is None:
        # a non-code loop, like StrLiteralSearch or something
        if arg:
            bytecode_name = arg
    else:
        name, filename, lineno, bytecode_no, bytecode_name = m.groups()
    return name, bytecode_name, filename, int(lineno), int(bytecode_no) ^ mask

class Op(object):
    bridge = None
    offset = None
    asm = None
    failargs = ()

    def __init__(self, name, args, res, descr, failargs=None):
        self.name = name
        self.args = args
        self.res = res
        self.descr = descr
        self._is_guard = name.startswith('guard_')
        if self._is_guard:
            self.guard_no = int(self.descr[len('<Guard0x'):-1], 16)
        self.failargs = failargs

    def as_json(self):
        d = {
            'name': self.name,
            'args': self.args,
            'res': self.res,
        }
        if self.descr is not None:
            d['descr'] = self.descr
        if self.bridge is not None:
            d['bridge'] = self.bridge.as_json()
        if self.asm is not None:
            d['asm'] = self.asm
        return d

    def setfailargs(self, failargs):
        self.failargs = failargs

    def getarg(self, i):
        return self.args[i]

    def getargs(self):
        return self.args[:]

    def getres(self):
        return self.res

    def getdescr(self):
        return self.descr

    def is_guard(self):
        return self._is_guard

    def repr(self):
        args = self.getargs()
        if self.descr is not None:
            args.append('descr=%s' % self.descr)
        arglist = ', '.join(args)
        if self.res is not None:
            return '%s = %s(%s)' % (self.getres(), self.name, arglist)
        else:
            return '%s(%s)' % (self.name, arglist)

    def __repr__(self):
        return self.repr()

class SimpleParser(OpParser):

    # factory method
    Op = Op
    use_mock_model = True

    def postprocess(self, loop, backend_dump=None, backend_tp=None,
                    dump_start=0):
        if backend_dump is not None:
            raw_asm = self._asm_disassemble(backend_dump.decode('hex'),
                                            backend_tp, dump_start)
            # additional mess: if the backend_dump starts with a series
            # of zeros, raw_asm's first regular line is *after* that,
            # after a line saying "...".  So we assume that start==dump_start
            # if this parameter was passed.
            asm = []
            start = dump_start
            for elem in raw_asm:
                if len(elem.split("\t")) < 3:
                    continue
                e = elem.split("\t")
                adr = e[0]
                v = elem   # --- more compactly:  " ".join(e[2:])
                if not start:     # only if 'dump_start' is left at 0
                    start = int(adr.strip(":"), 16)
                ofs = int(adr.strip(":"), 16) - start
                if ofs >= 0:
                    asm.append((ofs, v.strip("\n")))
            asm_index = 0
            for i, op in enumerate(loop.operations):
                end = 0
                j = i + 1
                while end == 0:
                    if j == len(loop.operations):
                        end = loop.last_offset
                        break
                    if loop.operations[j].offset is None:
                        j += 1
                    else:
                        end = loop.operations[j].offset
                if op.offset is not None:
                    while asm[asm_index][0] < op.offset:
                        asm_index += 1
                    end_index = asm_index
                    while asm[end_index][0] < end and end_index < len(asm) - 1:
                        end_index += 1
                    op.asm = '\n'.join([asm[i][1] for i in range(asm_index, end_index)])
        return loop

    def _asm_disassemble(self, d, tp, origin_addr):
        from rpython.jit.backend.tool.viewcode import machine_code_dump
        return list(machine_code_dump(d, origin_addr, tp))

    @classmethod
    def parse_from_input(cls, input, **kwds):
        parser = cls(input, None, {}, 'lltype', None,
                     nonstrict=True)
        loop = parser.parse()
        return parser.postprocess(loop, **kwds)

    def parse_args(self, opname, argspec):
        if not argspec.strip():
            return [], None
        if opname == 'debug_merge_point':
            return argspec.split(", ", 2), None
        else:
            args = argspec.split(', ')
            descr = None
            if args[-1].startswith('descr='):
                descr = args[-1][len('descr='):]
                args = args[:-1]
            if args == ['']:
                args = []
            return (args, descr)

    def box_for_var(self, res):
        return res

    def create_op(self, opnum, args, res, descr, fail_args):
        return self.Op(intern(opname[opnum].lower()), args, res,
                       descr, fail_args)

    def create_op_no_result(self, opnum, args, descr, fail_args):
        return self.Op(intern(opname[opnum].lower()), args, None,
                       descr, fail_args)

    def update_memo(self, val, name):
        pass

class NonCodeError(Exception):
    pass

class TraceForOpcode(object):
    code = None
    is_bytecode = True
    inline_level = None
    has_dmp = False

    def __init__(self, operations, storage, loopname):
        for op in operations:
            if op.name == 'debug_merge_point':
                self.inline_level = int(op.args[0])
                parsed = parse_code_data(op.args[2][1:-1])
                (self.name, self.bytecode_name, self.filename,
                 self.startlineno, self.bytecode_no) = parsed
                break
        else:
            self.inline_level = 0
            parsed = parse_code_data(loopname)
            (self.name, self.bytecode_name, self.filename,
             self.startlineno, self.bytecode_no) = parsed
        self.operations = operations
        self.storage = storage
        generic_format = (self.bytecode_no < 0)
        self.code = storage.disassemble_code(self.filename, self.startlineno,
                                             self.name, generic_format)

    def repr(self):
        if self.filename is None:
            return self.bytecode_name
        return "%s, file '%s', line %d" % (self.name, self.filename,
                                           self.startlineno)

    def getcode(self):
        return self.code

    def has_valid_code(self):
        return self.code is not None

    def getopcode(self):
        if self.code is None:
            return None
        return self.code.get_opcode_from_info(self)

    def getlineno(self):
        code = self.getopcode()
        if code is None:
            return None
        return code.lineno
    lineno = property(getlineno)

    def getline_starts_here(self):
        return self.getopcode().line_starts_here
    line_starts_here = property(getline_starts_here)

    def __repr__(self):
        return "[%s\n]" % "\n    ".join([repr(op) for op in self.operations])

    def pretty_print(self, out):
        pass

class Function(object):
    filename = None
    name = None
    startlineno = 0
    _linerange = None
    _lineset = None
    is_bytecode = False
    inline_level = None
    bytecode_name = None

    # factory method
    TraceForOpcode = TraceForOpcode

    def __init__(self, chunks, path, storage, inputargs=''):
        self.path = path
        self.inputargs = inputargs
        self.chunks = chunks
        for chunk in self.chunks:
            if chunk.bytecode_name is not None:
                self.startlineno = chunk.startlineno
                self.filename = chunk.filename
                self.name = chunk.name
                self.inline_level = chunk.inline_level
                break
        self.storage = storage

    @classmethod
    def from_operations(cls, operations, storage, limit=None, inputargs='',
                        loopname=''):
        """ Slice given operation list into a chain of TraceForOpcode chunks.
        Also detect inlined functions and make them Function
        """
        stack = []

        def getpath(stack):
            return ",".join([str(len(v)) for v in stack])

        def append_to_res(bc):
            if bc.inline_level is not None:
                if bc.inline_level == len(stack) - 1:
                    pass
                elif bc.inline_level > len(stack) - 1:
                    stack.append([])
                else:
                    while bc.inline_level + 1 < len(stack):
                        last = stack.pop()
                        stack[-1].append(cls(last, getpath(stack), storage))
            stack[-1].append(bc)

        so_far = []
        stack = []
        nothing_yet = True
        for op in operations:
            if op.name == 'debug_merge_point':
                if so_far:
                    opc = cls.TraceForOpcode(so_far, storage, loopname)
                    if nothing_yet:
                        nothing_yet = False
                        for i in xrange(opc.inline_level + 1):
                            stack.append([])
                    append_to_res(opc)
                    if limit:
                        break
                    so_far = []
            so_far.append(op)
        if so_far:
            append_to_res(cls.TraceForOpcode(so_far, storage, loopname))
        # wrap stack back up
        if not stack:
            # no ops whatsoever
            return cls([], getpath(stack), storage, inputargs)
        while True:
            next = stack.pop()
            if not stack:
                return cls(next, getpath(stack), storage, inputargs)
            stack[-1].append(cls(next, getpath(stack), storage))


    def getlinerange(self):
        if self._linerange is None:
            self._compute_linerange()
        return self._linerange
    linerange = property(getlinerange)

    def getlineset(self):
        if self._lineset is None:
            self._compute_linerange()
        return self._lineset
    lineset = property(getlineset)

    def has_valid_code(self):
        for chunk in self.chunks:
            if chunk.has_valid_code():
                return True
        return False

    def _compute_linerange(self):
        self._lineset = set()
        minline = sys.maxint
        maxline = -1
        for chunk in self.chunks:
            if chunk.is_bytecode and chunk.has_valid_code():
                lineno = chunk.lineno
                minline = min(minline, lineno)
                maxline = max(maxline, lineno)
                if chunk.line_starts_here or len(chunk.operations) > 1:
                    self._lineset.add(lineno)
        if minline == sys.maxint:
            minline = 0
            maxline = 0
        self._linerange = minline, maxline

    def repr(self):
        if self.filename is None:
            return self.chunks[0].bytecode_name
        return "%s, file '%s', line %d" % (self.name, self.filename,
                                           self.startlineno)

    def __repr__(self):
        return "[%s]" % ", ".join([repr(chunk) for chunk in self.chunks])

    def pretty_print(self, out):
        print >>out, "Loop starting at %s in %s at %d" % (self.name,
                                        self.filename, self.startlineno)
        lineno = -1
        for chunk in self.chunks:
            if chunk.filename is not None and chunk.lineno != lineno:
                lineno = chunk.lineno
                source = chunk.getcode().source[chunk.lineno -
                                                chunk.startlineno]
                print >>out, "  ", source
            chunk.pretty_print(out)


def adjust_bridges(loop, bridges):
    """ Slice given loop according to given bridges to follow. Returns a plain
    list of operations.
    """
    ops = loop.operations
    res = []
    i = 0
    while i < len(ops):
        op = ops[i]
        if op.is_guard() and bridges.get('loop-' + hex(op.guard_no)[2:], None):
            res.append(op)
            i = 0
            if hasattr(op.bridge, 'force_asm'):
                op.bridge.force_asm()
            ops = op.bridge.operations
        else:
            res.append(op)
            i += 1
    return res

def parse_addresses(part, callback=None):
    hex_re = '0x(-?[\da-f]+)'
    addrs = {}
    if callback is None:
        def callback(addr, stop_addr, bootstrap_addr, name, code_name):
            addrs.setdefault(bootstrap_addr, []).append(name)
    for entry in part:
        m = re.search('has address %(hex)s to %(hex)s \(bootstrap %(hex)s' %
                      {'hex': hex_re}, entry)
        if not m:
            # a bridge
            m = re.search('has address ' + hex_re + ' to ' + hex_re, entry)
            addr = int(m.group(1), 16)
            bootstrap_addr = addr
            stop_addr = int(m.group(2), 16)
            entry = entry.lower()
            m = re.search('guard ' + hex_re, entry)
            name = 'guard ' + m.group(1)
            code_name = 'bridge'
        else:
            name = entry[:entry.find('(') - 1].lower()
            addr = int(m.group(1), 16)
            stop_addr = int(m.group(2), 16)
            bootstrap_addr = int(m.group(3), 16)
            code_name = entry[entry.find('(') + 1:m.span(0)[0] - 2]
        callback(addr, stop_addr, bootstrap_addr, name, code_name)
    return addrs

def import_log(logname, ParserCls=SimpleParser):
    log = parse_log_file(logname)
    addrs = parse_addresses(extract_category(log, 'jit-backend-addr'))
    from rpython.jit.backend.tool.viewcode import World
    world = World()
    for entry in extract_category(log, 'jit-backend-dump'):
        world.parse(entry.splitlines(True))
    dumps = {}
    for r in world.ranges:
        for pos1 in range(r.addr, r.addr + len(r.data)):
            if pos1 in addrs and addrs[pos1]:
                name = addrs[pos1].pop(0) # they should come in order
                data = r.data.encode('hex')
                dumps[name] = (world.backend_name, r.addr, data)
    loops = []
    cat = extract_category(log, 'jit-log-opt')
    if not cat:
        cat = extract_category(log, 'jit-log-rewritten')
    if not cat:
        cat = extract_category(log, 'jit-log-noopt')        
    for entry in cat:
        parser = ParserCls(entry, None, {}, 'lltype', None,
                           nonstrict=True)
        loop = parser.parse()
        comm = loop.comment
        comm = comm.lower()
        if comm.startswith('# bridge'):
            m = re.search('guard 0x(-?[\da-f]+)', comm)
            name = 'guard ' + m.group(1)
        elif "(" in comm:
            name = comm[2:comm.find('(')-1]
        else:
            name = " ".join(comm[2:].split(" ", 2)[:2])
        if name in dumps:
            bname, start_ofs, dump = dumps[name]
            loop.force_asm = (lambda dump=dump, start_ofs=start_ofs,
                              bname=bname, loop=loop:
                              parser.postprocess(loop, backend_tp=bname,
                                                 backend_dump=dump,
                                                 dump_start=start_ofs))
        loops += split_trace(loop)
    return log, loops

def split_trace(trace):
    labels = [0]
    if trace.comment and 'Guard' in trace.comment:
        descrs = ['bridge %d' % int(
            re.search('Guard 0x(-?[\da-f]+)', trace.comment).group(1), 16)]
    else:
        descrs = ['entry ' + re.search('Loop (\d+)', trace.comment).group(1)]
    for i, op in enumerate(trace.operations):
        if op.name == 'label':
            labels.append(i)
            descrs.append(op.descr)
    labels.append(len(trace.operations) - 1)
    parts = []
    for i in range(len(labels) - 1):
        start, stop = labels[i], labels[i+1]
        part = copy(trace)
        part.operations = trace.operations[start : stop + 1]
        part.descr = descrs[i]
        part.comment = trace.comment
        parts.append(part)

    return parts

def parse_log_counts(input, loops):
    if not input:
        return
    lines = input[-1].splitlines()
    mapping = {}
    for loop in loops:
        mapping[loop.descr] = loop
    for line in lines:
        if line:
            num, count = line.split(':', 2)
            try:
                mapping[num].count = int(count)
            except KeyError:
                pass # too bad

def mangle_descr(descr):
    if descr.startswith('TargetToken('):
        return descr[len('TargetToken('):-1]
    if descr.startswith('<Guard'):
        return 'bridge-' + str(int(descr[len('<Guard0x'):-1], 16))
    if descr.startswith('<Loop'):
        return 'entry-' + descr[len('<Loop'):-1]
    return descr.replace(" ", '-')


if __name__ == '__main__':
    import_log(sys.argv[1])


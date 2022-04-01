
""" This file represents a storage mechanism that let us invent unique names
for all loops and bridges, so http requests can refer to them by name
"""

import py
import os
import linecache
from rpython.tool.disassembler import dis
from rpython.tool.jitlogparser.module_finder import gather_all_code_objs

class LoopStorage(object):
    def __init__(self, extrapath=None):
        self.loops = None
        self.functions = {}
        self.codes = {}
        self.disassembled_codes = {}
        self.extrapath = extrapath

    def load_code(self, fname):
        try:
            return self.codes[fname]
        except KeyError:
            if os.path.isabs(fname):
                res = gather_all_code_objs(fname)
            else:
                if self.extrapath is None:
                    raise IOError("Cannot find %s" % fname)
                res = gather_all_code_objs(os.path.join(self.extrapath, fname))
            self.codes[fname] = res
            return res

    def disassemble_code(self, fname, startlineno, name, generic_format=False):
        # 'generic_format' is False for PyPy2 (returns a
        # disassembler.CodeRepresentation) or True otherwise (returns a
        # GenericCode, without attempting any disassembly)
        try:
            if py.path.local(fname).check(file=False):
                return None # cannot find source file
        except py.error.EACCES:
            return None # cannot open the file
        key = (fname, startlineno, name)
        try:
            return self.disassembled_codes[key]
        except KeyError:
            pass
        if generic_format:
            res = GenericCode(fname, startlineno, name)
        else:
            codeobjs = self.load_code(fname)
            if (startlineno, name) not in codeobjs:
                # cannot find the code obj at this line: this can happen for
                # various reasons, e.g. because the .py files changed since
                # the log was produced, or because the co_firstlineno
                # attribute of the code object is wrong (e.g., code objects
                # produced by gateway.applevel(), such as the ones found in
                # nanos.py)
                return None
            code = codeobjs[(startlineno, name)]
            res = dis(code)
        self.disassembled_codes[key] = res
        return res

    def reconnect_loops(self, loops):
        """ Re-connect loops in a way that entry bridges are filtered out
        and normal bridges are associated with guards. Returning list of
        normal loops.
        """
        res = []
        guard_dict = {}
        for loop_no, loop in enumerate(loops):
            for op in loop.operations:
                if op.name.startswith('guard_') or op.name.startswith('vec_guard_'):
                    guard_dict[int(op.descr[len('<Guard0x'):-1], 16)] = (op, loop)
        for loop in loops:
            if loop.comment:
                comment = loop.comment.strip()
                if 'entry bridge' in comment:
                    pass
                elif comment.startswith('# bridge out of'):
                    no = int(comment[len('# bridge out of Guard 0x'):].split(' ', 1)[0], 16)
                    op, parent = guard_dict[no]
                    op.bridge = loop
                    op.percentage = ((getattr(loop, 'count', 1) * 100) /
                                     max(getattr(parent, 'count', 1), 1))
                    loop.no = no
                    continue
            res.append(loop)
        self.loops = res
        return res


class GenericCode(object):
    def __init__(self, fname, startlineno, name):
        self.filename = fname
        self.startlineno = startlineno
        self.name = name
        self._first_bytecodes = {}     # {lineno: bytecode_name}
        self._source = None

    def __repr__(self):
        return 'GenericCode(%r, %r, %r)' % (
            self.filename, self.startlineno, self.name)

    def get_opcode_from_info(self, info):
        lineno = ~info.bytecode_no
        bname = info.bytecode_name
        if self._first_bytecodes.setdefault(lineno, bname) == bname:
            # this is the first opcode of the line---or, at least,
            # the first time we ask for an Opcode on that line.
            line_starts_here = True
        else:
            line_starts_here = False
        return GenericOpcode(lineno, line_starts_here, bname)

    @property
    def source(self):
        if self._source is None:
            src = linecache.getlines(self.filename)
            if self.startlineno > 0:
                src = src[self.startlineno - 1:]
            self._source = [s.rstrip('\n\r') for s in src]
        return self._source


class GenericOpcode(object):
    def __init__(self, lineno, line_starts_here, bytecode_extra=''):
        self.lineno = lineno
        self.line_starts_here = line_starts_here
        self.bytecode_extra = bytecode_extra

    def __repr__(self):
        return 'GenericOpcode(%r, %r, %r)' % (
            self.lineno, self.line_starts_here, self.bytecode_extra)

    def __eq__(self, other):
        if not isinstance(other, GenericOpcode):
            return NotImplemented
        return (self.lineno == other.lineno and
                self.line_starts_here == other.line_starts_here and
                self.bytecode_extra == other.bytecode_extra)

    def __ne__(self, other):
        if not isinstance(other, GenericOpcode):
            return NotImplemented
        return not (self == other)

    def __hash__(self):
        return hash((self.lineno, self.line_starts_here, self.bytecode_extra))

    def match_name(self, opcode_name):
        return (self.bytecode_extra == opcode_name or
                self.bytecode_extra.endswith(' ' + opcode_name))

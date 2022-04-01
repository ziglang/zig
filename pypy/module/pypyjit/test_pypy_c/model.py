import py
import sys
import re
import os.path
try:
    from _pytest.assertion import newinterpret
except ImportError:   # e.g. Python 2.5
    newinterpret = None
from rpython.tool.jitlogparser.parser import (SimpleParser, Function,
                                              TraceForOpcode)
from rpython.tool.jitlogparser.storage import LoopStorage


def find_id_linenos(code):
    """
    Parse the given function and return a dictionary mapping "ids" to
    "line number".  Ids are identified by comments with a special syntax::

        # "myid" corresponds to the whole line
        print 'foo' # ID: myid
    """
    result = {}
    start_lineno = code.startlineno
    for i, line in enumerate(py.code.Source(code.source)):
        m = re.search('# ID: (\w+)', line)
        if m:
            name = m.group(1)
            lineno = start_lineno+i
            result.setdefault(name, lineno)
    return result


class Log(object):
    def __init__(self, rawtraces):
        storage = LoopStorage()
        traces = [SimpleParser.parse_from_input(rawtrace) for rawtrace in rawtraces]
        traces = storage.reconnect_loops(traces)
        self.loops = [TraceWithIds.from_trace(trace, storage) for trace in traces]

    def _filter(self, loop, is_entry_bridge=False):
        if is_entry_bridge == '*':
            return loop
        assert is_entry_bridge in (True, False)
        return PartialTraceWithIds(loop, is_entry_bridge)

    def loops_by_filename(self, filename, **kwds):
        """
        Return all loops which start in the file ``filename``
        """
        return [self._filter(loop, **kwds)  for loop in self.loops
                if loop.filename == filename]

    def loops_by_id(self, id, **kwds):
        """
        Return all loops which contain the ID ``id``
        """
        return [self._filter(loop, **kwds) for loop in self.loops
                if loop.has_id(id)]

    @classmethod
    def opnames(self, oplist):
        return [op.name for op in oplist]

class TraceWithIds(Function):

    def __init__(self, *args, **kwds):
        Function.__init__(self, *args, **kwds)
        self.ids = {}
        self.code = self.chunks[0].getcode()
        if not self.code and len(self.chunks)>1 and \
               isinstance(self.chunks[1], TraceForOpcode):
            # First chunk might be missing the debug_merge_point op
            self.code = self.chunks[1].getcode()
        if self.code:
            self.compute_ids(self.ids)

    @classmethod
    def from_trace(cls, trace, storage):
        res = cls.from_operations(trace.operations, storage)
        return res

    def flatten_chunks(self):
        """
        return a flat sequence of TraceForOpcode objects, including the ones
        inside inlined functions
        """
        for chunk in self.chunks:
            if isinstance(chunk, TraceForOpcode):
                yield chunk
            else:
                for subchunk in chunk.flatten_chunks():
                    yield subchunk

    def compute_ids(self, ids):
        #
        # 1. compute the ids of self, i.e. the outer function
        id2lineno = find_id_linenos(self.code)
        all_my_tracecodes = self.get_list_of_tracecodes()
        for id, lineno in id2lineno.iteritems():
            seen = set()
            opcodes = []
            for tracecode in all_my_tracecodes:
                if tracecode.lineno == lineno:
                    opcode = tracecode.getopcode()
                    if opcode not in seen:
                        seen.add(opcode)
                        opcodes.append(opcode)
            if opcodes:
                ids[id] = opcodes
        #
        # 2. compute the ids of all the inlined functions
        for chunk in self.chunks:
            if isinstance(chunk, TraceWithIds) and chunk.code:
                chunk.compute_ids(ids)

    def get_list_of_tracecodes(self):
        result = []
        for chunk in self.chunks:
            if isinstance(chunk, TraceForOpcode):
                result.append(chunk)
        return result

    def has_id(self, id):
        return id in self.ids

    def _ops_for_chunk(self, chunk, include_guard_not_invalidated):
        for op in chunk.operations:
            if op.name not in ('debug_merge_point', 'enter_portal_frame',
                               'leave_portal_frame') and \
                (op.name != 'guard_not_invalidated' or include_guard_not_invalidated):
                yield op

    def _allops(self, opcode=None, include_guard_not_invalidated=True):
        opcode_name = opcode
        for chunk in self.flatten_chunks():
            opcode = chunk.getopcode()
            if opcode_name is None or \
                   (opcode and opcode.match_name(opcode_name)):
                for op in self._ops_for_chunk(chunk, include_guard_not_invalidated):
                    yield op
            else:
                for op in chunk.operations:
                    if op.name == 'label':
                        yield op

    def allops(self, *args, **kwds):
        return list(self._allops(*args, **kwds))

    def format_ops(self, id=None, **kwds):
        if id is None:
            ops = self.allops(**kwds)
        else:
            ops = self.ops_by_id(id, **kwds)
        return '\n'.join(map(str, ops))

    def print_ops(self, *args, **kwds):
        print self.format_ops(*args, **kwds)

    def _ops_by_id(self, id, include_guard_not_invalidated=True, opcode=None):
        opcode_name = opcode
        target_opcodes = self.ids[id]
        loop_ops = self.allops(opcode)
        for chunk in self.flatten_chunks():
            opcode = chunk.getopcode()
            if opcode in target_opcodes and (opcode_name is None or
                                             opcode.match_name(opcode_name)):
                for op in self._ops_for_chunk(chunk, include_guard_not_invalidated):
                    if op in loop_ops:
                        yield op

    def ops_by_id(self, *args, **kwds):
        return list(self._ops_by_id(*args, **kwds))

    def match(self, expected_src, **kwds):
        ops = self.allops()
        matcher = OpMatcher(ops)
        return matcher.match(expected_src, **kwds)

    def match_by_id(self, id, expected_src, ignore_ops=[], **kwds):
        ops = list(self.ops_by_id(id, **kwds))
        matcher = OpMatcher(ops, id)
        return matcher.match(expected_src, ignore_ops=ignore_ops)

class PartialTraceWithIds(TraceWithIds):
    def __init__(self, trace, is_entry_bridge=False):
        self.trace = trace
        self.is_entry_bridge = is_entry_bridge
    
    def allops(self, *args, **kwds):
        if self.is_entry_bridge:
            return self.entry_bridge_ops(*args, **kwds)
        else:
            return self.simple_loop_ops(*args, **kwds)

    def simple_loop_ops(self, *args, **kwds):
        ops = list(self._allops(*args, **kwds))
        labels = [op for op in ops if op.name == 'label']
        jumpop = self.chunks[-1].operations[-1]
        assert jumpop.name == 'jump'
        assert jumpop.getdescr() == labels[-1].getdescr()
        i = ops.index(labels[-1])
        return ops[i+1:]

    def entry_bridge_ops(self, *args, **kwds):
        ops = list(self._allops(*args, **kwds))
        labels = [op for op in ops if op.name == 'label']
        i0 = ops.index(labels[0])
        i1 = ops.index(labels[1])
        return ops[i0+1:i1]

    @property
    def chunks(self):
        return self.trace.chunks

    @property
    def ids(self):
        return self.trace.ids

    @property
    def filename(self):
        return self.trace.filename
    
    @property
    def code(self):
        return self.trace.code
    
    
class InvalidMatch(Exception):
    opindex = None

    def __init__(self, message, frame):
        Exception.__init__(self, message)
        # copied and adapted from pytest's magic AssertionError
        f = py.code.Frame(frame)
        try:
            source = f.code.fullsource
            if source is not None:
                try:
                    source = source.getstatement(f.lineno)
                except IndexError:
                    source = None
                else:
                    source = str(source.deindent()).strip()
        except py.error.ENOENT:
            source = None
        if source and source.startswith('self._assert(') and newinterpret:
            # transform self._assert(x, 'foo') into assert x, 'foo'
            source = source.replace('self._assert(', 'assert ')
            source = source[:-1] # remove the trailing ')'
            self.msg = newinterpret.interpret(source, f, should_fail=True)
        else:
            self.msg = "<could not determine information>"


class OpMatcher(object):

    def __init__(self, ops, id=None):
        self.ops = ops
        self.id = id
        self.src = '\n'.join(map(str, ops))
        self.alpha_map = {}

    @classmethod
    def parse_ops(cls, src):
        ops = [cls.parse_op(line) for line in src.splitlines()]
        ops.append(('--end--', None, [], '...', True))
        return [op for op in ops if op is not None]

    @classmethod
    def parse_op(cls, line):
        # strip comment after '#', but not if it appears inside parentheses
        if '#' in line:
            nested = 0
            for i, c in enumerate(line):
                if c == '(':
                    nested += 1
                elif c == ')':
                    assert nested > 0, "more ')' than '(' in %r" % (line,)
                    nested -= 1
                elif c == '#' and nested == 0:
                    line = line[:i]
                    break
        #
        if line.strip() == 'guard_not_invalidated?':
            return 'guard_not_invalidated', None, [], '...', False
        if line.strip() == 'dummy_get_utf8?':
            # this is because unicode used to generate dummy getfield_gc_r
            # of the _utf8 field.  Nowadays it no longer does.  This line
            # is equivalent to a comment now.
            return None

        # find the resvar, if any
        if ' = ' in line:
            resvar, _, line = line.partition(' = ')
            resvar = resvar.strip()
        else:
            resvar = None
        line = line.strip()
        if not line:
            return None
        if line in ('...', '{{{', '}}}'):
            return line
        opname, _, args = line.partition('(')
        opname = opname.strip()
        assert args.endswith(')')
        args = args[:-1]
        args = args.split(',')
        args = map(str.strip, args)
        if args == ['']:
            args = []
        if args and args[-1].startswith('descr='):
            descr = args.pop()
            descr = descr[len('descr='):]
        else:
            descr = None
        return opname, resvar, args, descr, True

    @classmethod
    def preprocess_expected_src(cls, src):
        # all loops decrement the tick-counter at the end. The rpython code is
        # in jump_absolute() in pypyjit/interp.py. The string --TICK-- is
        # replaced with the corresponding operations, so that tests don't have
        # to repeat it every time
        ticker_check = """
            guard_not_invalidated?
            ticker0 = getfield_raw_i(#, descr=<FieldS pypysig_long_struct.c_value .*>)
            ticker_cond0 = int_lt(ticker0, 0)
            guard_false(ticker_cond0, descr=...)
        """
        src = src.replace('--TICK--', ticker_check)
        #
        # this is the ticker check generated if we have threads
        thread_ticker_check = """
            guard_not_invalidated?
            ticker0 = getfield_raw_i(#, descr=<FieldS pypysig_long_struct.c_value .*>)
            ticker1 = int_sub(ticker0, #)
            setfield_raw(#, ticker1, descr=<FieldS pypysig_long_struct.c_value .*>)
            ticker_cond0 = int_lt(ticker1, 0)
            guard_false(ticker_cond0, descr=...)
        """
        src = src.replace('--THREAD-TICK--', thread_ticker_check)
        #
        # this is the ticker check generated in PyFrame.handle_operation_error
        exc_ticker_check = """
            ticker2 = getfield_raw_i(#, descr=<FieldS pypysig_long_struct.c_value .*>)
            ticker_cond1 = int_lt(ticker2, 0)
            guard_false(ticker_cond1, descr=...)
        """
        src = src.replace('--EXC-TICK--', exc_ticker_check)
        #
        # ISINF is done as a macro; fix it here
        r = re.compile('(\w+) = --ISINF--[(](\w+)[)]')
        src = r.sub(r'\2\B999 = float_add(\2, ...)\n\1 = float_eq(\2\B999, \2)',
                    src)
        return src

    @classmethod
    def is_const(cls, v1):
        return isinstance(v1, str) and v1.startswith('ConstClass(')

    @staticmethod
    def as_numeric_const(v1):
        # returns one of:  ('int', value)  ('float', value)  None
        try:
            return ('int', int(v1))
        except ValueError:
            pass
        if '.' in v1:
            try:
                return ('float', float(v1))
            except ValueError:
                pass
        return None

    def match_var(self, v1, exp_v2):
        assert v1 != '_'
        if exp_v2 == '_':           # accept anything
            return True
        if exp_v2 is None:
            return v1 is None
        assert exp_v2 != '...'      # bogus use of '...' in the expected code
        n1 = self.as_numeric_const(v1)
        if exp_v2 == '#':           # accept any (integer or float) number
            return n1 is not None
        n2 = self.as_numeric_const(exp_v2)
        if n1 is not None or n2 is not None:
            # at least one is a number; check that both are, and are equal
            return n1 == n2
        if self.is_const(v1) or self.is_const(exp_v2):
            return v1[:-1].startswith(exp_v2[:-1])
        if v1 not in self.alpha_map:
            self.alpha_map[v1] = exp_v2
        return self.alpha_map[v1] == exp_v2

    def match_descr(self, descr, exp_descr):
        if descr == exp_descr or exp_descr == '...':
            return True
        self._assert(exp_descr is not None and re.match(exp_descr, descr), "descr mismatch")

    def _assert(self, cond, message):
        if not cond:
            raise InvalidMatch(message, frame=sys._getframe(1))

    def match_op(self, op, (exp_opname, exp_res, exp_args, exp_descr, _)):
        if exp_opname == '--end--':
            self._assert(op == '--end--', 'got more ops than expected')
            return
        self._assert(op != '--end--', 'got less ops than expected')
        self._assert(op.name == exp_opname, "operation mismatch")
        self.match_var(op.res, exp_res)
        if exp_args[-1:] == ['...']:      # exp_args ends with '...'
            exp_args = exp_args[:-1]
            self._assert(len(op.args) >= len(exp_args), "not enough arguments")
        else:
            self._assert(len(op.args) == len(exp_args), "wrong number of arguments")
        for arg, exp_arg in zip(op.args, exp_args):
            self._assert(self.match_var(arg, exp_arg), "variable mismatch: %r instead of %r" % (arg, exp_arg))
        self.match_descr(op.descr, exp_descr)


    def _next_op(self, iter_ops, ignore_ops=set()):
        try:
            while True:
                op = iter_ops.next()
                if op.name not in ignore_ops:
                    break
        except StopIteration:
            return '--end--'
        return op

    def try_match(self, op, exp_op):
        try:
            # try to match the op, but be sure not to modify the
            # alpha-renaming map in case the match does not work
            alpha_map = self.alpha_map.copy()
            self.match_op(op, exp_op)
        except InvalidMatch:
            # it did not match: rollback the alpha_map
            self.alpha_map = alpha_map
            return False
        else:
            return True

    def match_until(self, until_op, iter_ops):
        while True:
            op = self._next_op(iter_ops)
            if self.try_match(op, until_op):
                # it matched! The '...' operator ends here
                return op
            self._assert(op != '--end--',
                         'nothing in the end of the loop matches %r' %
                          (until_op,))

    def match_any_order(self, iter_exp_ops, iter_ops, ignore_ops):
        exp_ops = []
        for exp_op in iter_exp_ops:
            if exp_op == '}}}':
                break
            exp_ops.append(exp_op)
        else:
            assert 0, "'{{{' not followed by '}}}'"
        while exp_ops:
            op = self._next_op(iter_ops, ignore_ops=ignore_ops)
            # match 'op' against any of the exp_ops; the first successful
            # match is kept, and the exp_op gets removed from the list
            for i, exp_op in enumerate(exp_ops):
                if self.try_match(op, exp_op):
                    del exp_ops[i]
                    break
            else:
                self._assert(0, \
                    "operation %r not found within the {{{ }}} block" % (op,))

    def match_loop(self, expected_ops, ignore_ops):
        """
        A note about partial matching: the '...' operator is non-greedy,
        i.e. it matches all the operations until it finds one that matches
        what is after the '...'.  The '{{{' and '}}}' operators mark a
        group of lines that can match in any order.
        """
        iter_exp_ops = iter(expected_ops)
        iter_ops = RevertableIterator(self.ops)
        for exp_op in iter_exp_ops:
            try:
                if exp_op == '...':
                    # loop until we find an operation which matches
                    try:
                        exp_op = iter_exp_ops.next()
                    except StopIteration:
                        # the ... is the last line in the expected_ops, so we just
                        # return because it matches everything until the end
                        return
                    op = self.match_until(exp_op, iter_ops)
                elif exp_op == '{{{':
                    self.match_any_order(iter_exp_ops, iter_ops, ignore_ops)
                    continue
                else:
                    op = self._next_op(iter_ops, ignore_ops=ignore_ops)
                try:
                    self.match_op(op, exp_op)
                except InvalidMatch:
                    if type(exp_op) is str or exp_op[4] is not False:
                        raise
                    #else: optional operation
                    iter_ops.revert_one()
                    continue       # try to match with the next exp_op
            except InvalidMatch as e:
                e.opindex = iter_ops.index - 1
                raise

    def match(self, expected_src, ignore_ops=[]):
        def format(src, opindex=None):
            if src is None:
                return ''
            text = str(py.code.Source(src).deindent().indent())
            lines = text.splitlines(True)
            if opindex is not None and 0 <= opindex <= len(lines):
                lines.insert(opindex, '\n\t===== HERE =====\n')
            return ''.join(lines)
        #
        expected_src = self.preprocess_expected_src(expected_src)
        expected_ops = self.parse_ops(expected_src)
        try:
            self.match_loop(expected_ops, ignore_ops)
        except InvalidMatch as e:
            print '@' * 40
            print "Loops don't match"
            print "================="
            print 'loop id = %r' % (self.id,)
            print e.args
            print e.msg
            print
            print "Ignore ops:", ignore_ops
            print "Got:"
            print format(self.src, e.opindex)
            print
            print "Expected:"
            print format(expected_src)
            raise     # always propagate the exception in case of mismatch
        else:
            return True


class RevertableIterator(object):
    def __init__(self, sequence):
        self.sequence = sequence
        self.index = 0
    def __iter__(self):
        return self
    def next(self):
        index = self.index
        self.index = index + 1
        if index >= len(self.sequence):
            raise StopIteration
        return self.sequence[index]
    def revert_one(self):
        self.index -= 1

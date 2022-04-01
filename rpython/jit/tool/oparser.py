
""" Simplify optimize tests by allowing to write them
in a nicer fashion
"""

import re

from rpython.jit.tool.oparser_model import get_model

from rpython.jit.metainterp.resoperation import rop, ResOperation, \
     InputArgInt, InputArgRef, InputArgFloat, InputArgVector, \
     ResOpWithDescr, N_aryOp, UnaryOp, PlainResOp, optypes, OpHelpers, \
     VectorizationInfo

class ParseError(Exception):
    pass


def default_fail_descr(model, opnum, fail_args=None):
    if opnum == rop.FINISH:
        return model.BasicFinalDescr()
    return model.BasicFailDescr()


class OpParser(object):

    use_mock_model = False

    def __init__(self, input, cpu, namespace, boxkinds,
                 invent_fail_descr=default_fail_descr,
                 nonstrict=False, postproces=None):
        self.input = input
        self.vars = {}
        self._postproces = postproces
        self.cpu = cpu
        self._consts = namespace
        self.boxkinds = boxkinds or {}
        if namespace is not None:
            self._cache = namespace.setdefault('_CACHE_', {})
        else:
            self._cache = {}
        self.invent_fail_descr = invent_fail_descr
        self.nonstrict = nonstrict
        self.model = get_model(self.use_mock_model)
        self.original_jitcell_token = self.model.JitCellToken()

    def get_const(self, name, typ):
        if self._consts is None:
            return name
        obj = self._consts[name]
        if typ == 'ptr':
            return self.model.ConstPtr(obj)
        elif typ == 'int':
            return self.model.ConstInt(obj)
        else:
            assert typ == 'class'
            return self.model.ConstInt(self.model.ptr_to_int(obj))

    def get_descr(self, poss_descr, allow_invent):
        if poss_descr.startswith('<'):
            return None
        try:
            return self._consts[poss_descr]
        except KeyError:
            if allow_invent:
                int(poss_descr)
                token = self.model.JitCellToken()
                tt = self.model.TargetToken(token)
                self._consts[poss_descr] = tt
                return tt
            else:
                raise

    def inputarg_for_var(self, elem):
        try:
            return self._cache[elem]
        except KeyError:
            pass
        if elem[0] in 'ifrpv':
            box = OpHelpers.inputarg_from_tp(elem[0])
            number = elem[1:]
            if elem.startswith('v'):
                pattern = re.compile('.*\[(\d+)x(i|f)(\d+)\]')
                match = pattern.match(elem)
                if match:
                    box.datatype = match.group(2)[0]
                    box.bytesize = int(match.group(3)) // 8
                    box.count = int(match.group(1))
                    box.signed == item_type == 'i'
                    number = elem[1:elem.find('[')]
        else:
            number = elem[1:]
            for prefix, boxclass in self.boxkinds.iteritems():
                if elem.startswith(prefix):
                    box = boxclass()
                    break
            else:
                raise ParseError("Unknown variable type: %s" % elem)
        self._cache[elem] = box
        box._str = elem
        return box

    def parse_header_line(self, line):
        elements = line.split(",")
        vars = []
        for elem in elements:
            elem = elem.strip()
            vars.append(self.newinputarg(elem))
        return vars

    def newinputarg(self, elem):
        if elem.startswith('i'):
            v = InputArgInt(0)
        elif elem.startswith('f'):
            v = InputArgFloat.fromfloat(0.0)
        elif elem.startswith('v'):
            v = InputArgVector()
            elem = self.update_vector(v, elem)
        else:
            from rpython.rtyper.lltypesystem import lltype, llmemory
            assert elem.startswith('p')
            v = InputArgRef(lltype.nullptr(llmemory.GCREF.TO))
        # ensure that the variable gets the proper naming
        self.update_memo(v, elem)
        self.vars[elem] = v
        return v

    def newvar(self, elem):
        box = self.inputarg_for_var(elem)
        self.vars[elem] = box
        return box

    def is_float(self, arg):
        try:
            float(arg)
            return True
        except ValueError:
            return False

    def getvar(self, arg):
        if not arg:
            return self.model.ConstInt(0)
        try:
            return self.model.ConstInt(int(arg))
        except ValueError:
            if self.is_float(arg):
                return self.model.ConstFloat(self.model.convert_to_floatstorage(arg))
            if (arg.startswith('"') or arg.startswith("'") or
                arg.startswith('s"')):
                info = arg[1:].strip("'\"")
                return self.model.get_const_ptr_for_string(info)
            if arg.startswith('u"'):
                info = arg[1:].strip("'\"")
                return self.model.get_const_ptr_for_unicode(info)
            if arg.startswith('ConstClass('):
                name = arg[len('ConstClass('):-1]
                return self.get_const(name, 'class')
            elif arg.startswith('ConstInt('):
                name = arg[len('ConstInt('):-1]
                return self.get_const(name, 'int')
            elif arg.startswith('v') and '[' in arg:
                i = 1
                while i < len(arg) and arg[i] != '[':
                    i += 1
                return self.getvar(arg[:i])
            elif arg == 'None':
                return None
            elif arg == 'NULL':
                return self.model.ConstPtr(self.model.ConstPtr.value)
            elif arg.startswith('ConstPtr('):
                name = arg[len('ConstPtr('):-1]
                return self.get_const(name, 'ptr')
            if arg not in self.vars and self.nonstrict:
                self.newvar(arg)
            return self.vars[arg]

    def parse_args(self, opname, argspec):
        args = []
        descr = None
        if argspec.strip():
            allargs = [arg for arg in argspec.split(",")
                       if arg != '']

            poss_descr = allargs[-1].strip()
            if poss_descr.startswith('descr='):
                descr = self.get_descr(poss_descr[len('descr='):],
                                       opname == 'label')
                allargs = allargs[:-1]
            for arg in allargs:
                arg = arg.strip()
                try:
                    args.append(self.getvar(arg))
                except KeyError:
                    raise ParseError("Unknown var: %s" % arg)
        return args, descr

    def parse_op(self, line):
        num = line.find('(')
        if num == -1:
            raise ParseError("invalid line: %s" % line)
        opname = line[:num]
        try:
            opnum = getattr(rop, opname.upper())
        except AttributeError:
            if opname == 'escape_i':
                opnum = ESCAPE_OP_I.OPNUM
            elif opname == 'escape_f':
                opnum = ESCAPE_OP_F.OPNUM
            elif opname == 'escape_n':
                opnum = ESCAPE_OP_N.OPNUM
            elif opname == 'escape_r':
                opnum = ESCAPE_OP_R.OPNUM
            elif opname == 'force_spill':
                opnum = FORCE_SPILL.OPNUM
            else:
                raise ParseError("unknown op: %s" % opname)
        endnum = line.rfind(')')
        if endnum == -1:
            raise ParseError("invalid line: %s" % line)
        args, descr = self.parse_args(opname, line[num + 1:endnum])
        if rop._GUARD_FIRST <= opnum <= rop._GUARD_LAST:
            i = line.find('[', endnum) + 1
            j = line.rfind(']', i)
            if (i <= 0 or j <= 0) and not self.nonstrict:
                raise ParseError("missing fail_args for guard operation")
            fail_args = []
            if i < j:
                for arg in line[i:j].split(','):
                    arg = arg.strip()
                    if arg == 'None':
                        fail_arg = None
                    else:
                        if arg.startswith('v') and '[' in arg:
                            arg = arg[:arg.find('[')]
                        try:
                            fail_arg = self.vars[arg]
                        except KeyError:
                            raise ParseError(
                                "Unknown var in fail_args: %s" % arg)
                    fail_args.append(fail_arg)
            if descr is None and self.invent_fail_descr:
                descr = self.invent_fail_descr(self.model, opnum, fail_args)
        else:
            fail_args = None
            if opnum == rop.FINISH:
                if descr is None and self.invent_fail_descr:
                    descr = self.invent_fail_descr(self.model, opnum, fail_args)
            elif opnum == rop.JUMP:
                if descr is None and self.invent_fail_descr:
                    descr = self.original_jitcell_token

        return opnum, args, descr, fail_args

    def create_op(self, opnum, args, res, descr, fail_args):
        res = ResOperation(opnum, args, descr)
        if fail_args is not None:
            res.setfailargs(fail_args)
        if self._postproces:
            self._postproces(res)
        return res

    def parse_result_op(self, line):
        res, op = line.split("=", 1)
        res = res.strip()
        op = op.strip()
        opnum, args, descr, fail_args = self.parse_op(op)
        if res in self.vars:
            raise ParseError("Double assign to var %s in line: %s" % (res, line))
        resop = self.create_op(opnum, args, res, descr, fail_args)
        if not self.use_mock_model:
            res = self.update_vector(resop, res)
        self.update_memo(resop, res)
        self.vars[res] = resop
        return resop

    def update_memo(self, val, name):
        """ This updates the id of the operation or inputarg.
            Internally you will see the same variable names as
            in the trace as string.
        """
        pass
        #regex = re.compile("[prifv](\d+)")
        #match = regex.match(name)
        #if match:
        #    counter = int(match.group(1))
        #    countdict = val._repr_memo
        #    assert val not in countdict._d
        #    countdict._d[val] = counter
        #    if countdict.counter < counter:
        #        countdict.counter = counter

    def update_vector(self, resop, var):
        pattern = re.compile('.*\[(\d+)x(u?)(i|f)(\d+)\]')
        match = pattern.match(var)
        if match:
            vecinfo = VectorizationInfo(None)
            vecinfo.count = int(match.group(1))
            vecinfo.signed = not (match.group(2) == 'u')
            vecinfo.datatype = match.group(3)
            vecinfo.bytesize = int(match.group(4)) // 8
            resop._vec_debug_info = vecinfo
            resop.bytesize = vecinfo.bytesize
            return var[:var.find('[')]

        vecinfo = VectorizationInfo(resop)
        vecinfo.count = -1
        resop._vec_debug_info = vecinfo
        return var

    def parse_op_no_result(self, line):
        opnum, args, descr, fail_args = self.parse_op(line)
        res = self.create_op(opnum, args, None, descr, fail_args)
        return res

    def parse_next_op(self, line):
        if "=" in line and line.find('(') > line.find('='):
            return self.parse_result_op(line)
        else:
            return self.parse_op_no_result(line)

    def parse(self):
        lines = self.input.splitlines()
        ops = []
        newlines = []
        first_comment = None
        for line in lines:
            # for simplicity comments are not allowed on
            # debug_merge_point or jit_debug lines
            if '#' in line and ('debug_merge_point(' not in line and
                                'jit_debug(' not in line):
                if line.lstrip()[0] == '#': # comment only
                    if first_comment is None:
                        first_comment = line
                    continue
                comm = line.rfind('#')
                rpar = line.find(')') # assume there's a op(...)
                if comm > rpar:
                    line = line[:comm].rstrip()
            if not line.strip():
                continue  # a comment or empty line
            newlines.append(line)
        base_indent, inpargs, newlines = self.parse_inpargs(newlines)
        num, ops, last_offset = self.parse_ops(base_indent, newlines, 0)
        if num < len(newlines):
            raise ParseError("unexpected dedent at line: %s" % newlines[num])
        loop = self.model.ExtendedTreeLoop("loop")
        loop.comment = first_comment
        loop.original_jitcell_token = self.original_jitcell_token
        loop.operations = ops
        loop.inputargs = inpargs
        loop.last_offset = last_offset
        return loop

    def parse_ops(self, indent, lines, start):
        num = start
        ops = []
        last_offset = None
        while num < len(lines):
            line = lines[num]
            if not line.startswith(" " * indent):
                # dedent
                return num, ops
            elif line.startswith(" "*(indent + 1)):
                raise ParseError("indentation not valid any more")
            elif line.startswith(" " * indent + "#"):
                num += 1
                continue
            else:
                line = line.strip()
                offset, line = self.parse_offset(line)
                if line == '--end of the loop--':
                    last_offset = offset
                else:
                    op = self.parse_next_op(line)
                    if offset:
                        op.offset = offset
                    ops.append(op)
                num += 1
        return num, ops, last_offset

    def postprocess(self, loop):
        """ A hook that can be overloaded to do some postprocessing
        """
        return loop

    def parse_offset(self, line):
        if line.startswith('+'):
            # it begins with an offset, like: "+10: i1 = int_add(...)"
            offset, _, line = line.partition(':')
            offset = int(offset)
            return offset, line.strip()
        return None, line

    def parse_inpargs(self, lines):
        line = lines[0]
        base_indent = len(line) - len(line.lstrip(' '))
        line = line.strip()
        if not line.startswith('[') and self.nonstrict:
            return base_indent, [], lines
        lines = lines[1:]
        if line == '[]':
            return base_indent, [], lines
        if not line.startswith('[') or not line.endswith(']'):
            raise ParseError("Wrong header: %s" % line)
        inpargs = self.parse_header_line(line[1:-1])
        return base_indent, inpargs, lines

def parse(input, cpu=None, namespace=None,
          boxkinds=None, invent_fail_descr=default_fail_descr,
          no_namespace=False, nonstrict=False, OpParser=OpParser,
          postprocess=None):
    if namespace is None and not no_namespace:
        namespace = {}
    return OpParser(input, cpu, namespace, boxkinds,
                    invent_fail_descr, nonstrict, postprocess).parse()

def pick_cls(inp):
    from rpython.jit.metainterp import history

    if inp.type == 'i':
        return history.IntFrontendOp
    elif inp.type == 'r':
        return history.RefFrontendOp
    else:
        assert inp.type == 'f'
        return history.FloatFrontendOp

def convert_loop_to_trace(loop, metainterp_sd, skip_last=False):
    from rpython.jit.metainterp.opencoder import Trace
    from rpython.jit.metainterp.test.test_opencoder import FakeFrame
    from rpython.jit.metainterp import history, resume

    def get(a):
        if isinstance(a, history.Const):
            return a
        return mapping[a]

    class jitcode:
        index = 200

    inputargs = [pick_cls(inparg)(i) for i, inparg in
                 enumerate(loop.inputargs)]
    mapping = {}
    for one, two in zip(loop.inputargs, inputargs):
        mapping[one] = two
    trace = Trace(inputargs, metainterp_sd)
    ops = loop.operations
    if skip_last:
        ops = ops[:-1]
    for op in ops:
        newpos = trace.record_op(op.getopnum(), [get(arg) for arg in 
            op.getarglist()], op.getdescr())
        if rop.is_guard(op.getopnum()):
            failargs = []
            if op.getfailargs():
                failargs = [get(arg) for arg in op.getfailargs()]
            frame = FakeFrame(100, jitcode, failargs)
            resume.capture_resumedata([frame], None, [], trace)
        if op.type != 'v':
            newop = pick_cls(op)(newpos)
            mapping[op] = newop
    trace._mapping = mapping # for tests
    return trace

def pure_parse(*args, **kwds):
    kwds['invent_fail_descr'] = None
    return parse(*args, **kwds)


def _box_counter_more_than(model, s):
    if s.isdigit():
        model._counter = max(model._counter, int(s)+1)

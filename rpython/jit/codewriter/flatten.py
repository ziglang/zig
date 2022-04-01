from rpython.flowspace.model import Variable, Constant, c_last_exception
from rpython.jit.metainterp.history import AbstractDescr, getkind
from rpython.rtyper.lltypesystem import lltype


class SSARepr(object):
    def __init__(self, name):
        self.name = name
        self.insns = []
        self._insns_pos = None     # after being assembled

class Label(object):
    def __init__(self, name):
        self.name = name
    def __repr__(self):
        return "Label(%r)" % (self.name, )
    def __eq__(self, other):
        return isinstance(other, Label) and other.name == self.name

class TLabel(object):
    def __init__(self, name):
        self.name = name
    def __repr__(self):
        return "TLabel(%r)" % (self.name, )
    def __eq__(self, other):
        return isinstance(other, TLabel) and other.name == self.name

class Register(object):
    def __init__(self, kind, index):
        self.kind = kind          # 'int', 'ref' or 'float'
        self.index = index
    def __repr__(self):
        return "%%%s%d" % (self.kind[0], self.index)

class ListOfKind(object):
    # a list of Regs/Consts, all of the same 'kind'.
    # We cannot use a plain list, because we wouldn't know what 'kind' of
    # Regs/Consts would be expected in case the list is empty.
    def __init__(self, kind, content):
        assert kind in KINDS
        self.kind = kind
        self.content = tuple(content)
    def __repr__(self):
        return '%s%s' % (self.kind[0].upper(), list(self.content))
    def __iter__(self):
        return iter(self.content)
    def __nonzero__(self):
        return bool(self.content)
    def __eq__(self, other):
        return (isinstance(other, ListOfKind) and
                self.kind == other.kind and self.content == other.content)

class IndirectCallTargets(object):
    def __init__(self, lst):
        self.lst = lst       # list of JitCodes
    def __repr__(self):
        return '<IndirectCallTargets>'

KINDS = ['int', 'ref', 'float']

# ____________________________________________________________

def flatten_graph(graph, regallocs, _include_all_exc_links=False,
                  cpu=None):
    """Flatten the graph into an SSARepr, with already-computed register
    allocations.  'regallocs' in a dict {kind: RegAlloc}."""
    flattener = GraphFlattener(graph, regallocs, _include_all_exc_links, cpu)
    flattener.enforce_input_args()
    flattener.generate_ssa_form()
    return flattener.ssarepr


class GraphFlattener(object):

    def __init__(self, graph, regallocs, _include_all_exc_links=False,
                 cpu=None):
        self.graph = graph
        self.regallocs = regallocs
        self.cpu = cpu
        self._include_all_exc_links = _include_all_exc_links
        self.registers = {}
        if graph:
            name = graph.name
        else:
            name = '?'
        self.ssarepr = SSARepr(name)

    def enforce_input_args(self):
        inputargs = self.graph.startblock.inputargs
        numkinds = {}
        for v in inputargs:
            kind = getkind(v.concretetype)
            if kind == 'void':
                continue
            curcol = self.regallocs[kind].getcolor(v)
            realcol = numkinds.get(kind, 0)
            numkinds[kind] = realcol + 1
            if curcol != realcol:
                assert curcol > realcol
                self.regallocs[kind].swapcolors(realcol, curcol)

    def generate_ssa_form(self):
        self.seen_blocks = {}
        self.make_bytecode_block(self.graph.startblock)

    def make_bytecode_block(self, block, handling_ovf=False):
        if block.exits == ():
            self.make_return(block.inputargs)
            return
        if block in self.seen_blocks:
            self.emitline("goto", TLabel(block))
            self.emitline("---")
            return
        # inserting a goto not necessary, falling through
        self.seen_blocks[block] = True
        self.emitline(Label(block))
        #
        operations = block.operations
        for i, op in enumerate(operations):
            if '_ovf' in op.opname:
                if (len(block.exits) not in (2, 3) or
                    block.exitswitch is not c_last_exception):
                    raise Exception("detected a block containing ovfcheck()"
                                    " but no OverflowError is caught, this"
                                    " is not legal in jitted blocks")
            self.serialize_op(op)
        #
        self.insert_exits(block, handling_ovf)

    def make_return(self, args):
        if len(args) == 1:
            # return from function
            [v] = args
            kind = getkind(v.concretetype)
            if kind == 'void':
                self.emitline("void_return")
            else:
                self.emitline("%s_return" % kind, self.getcolor(args[0]))
        elif len(args) == 2:
            # exception block, raising an exception from a function
            if isinstance(args[1], Variable):
                self.emitline("-live-")     # xxx hack
            self.emitline("raise", self.getcolor(args[1]))
        else:
            raise Exception("?")
        self.emitline("---")

    def make_link(self, link, handling_ovf):
        if (link.target.exits == ()
            and link.last_exception not in link.args
            and link.last_exc_value not in link.args):
            self.make_return(link.args)     # optimization only
            return
        self.insert_renamings(link)
        self.make_bytecode_block(link.target, handling_ovf)

    def make_exception_link(self, link, handling_ovf):
        # Like make_link(), but also introduces the 'last_exception' and
        # 'last_exc_value' as variables if needed.  Also check if the link
        # is jumping directly to the re-raising exception block.
        assert link.last_exception is not None
        assert link.last_exc_value is not None
        if link.target.operations == () and link.args == [link.last_exception,
                                                          link.last_exc_value]:
            if handling_ovf:
                exc_data = self.cpu.rtyper.exceptiondata
                ll_ovf = exc_data.get_standard_ll_exc_instance_by_class(
                    OverflowError)
                c = Constant(ll_ovf, concretetype=lltype.typeOf(ll_ovf))
                self.emitline("raise", c)
            else:
                self.emitline("reraise")
            self.emitline("---")
            return   # done
        self.make_link(link, handling_ovf)

    def insert_exits(self, block, handling_ovf=False):
        if len(block.exits) == 1:
            # A single link, fall-through
            link = block.exits[0]
            assert link.exitcase in (None, False, True)
            # the cases False or True should not really occur, but can show
            # up in the manually hacked graphs for generators...
            self.make_link(link, handling_ovf)
        #
        elif block.canraise:
            # An exception block. See test_exc_exitswitch in test_flatten.py
            # for an example of what kind of code this makes.
            index = -1
            opname = block.operations[index].opname
            if '_ovf' in opname:
                # ovf checking operation as a lat thing, -live- should be
                # one before it
                line = self.popline()
                self.emitline(opname[:7] + '_jump_if_ovf',
                              TLabel(block.exits[1]), *line[1:])
                assert len(block.exits) in (2, 3)
                self.make_link(block.exits[0], False)
                self.emitline(Label(block.exits[1]))
                self.make_exception_link(block.exits[1], True)
                if len(block.exits) == 3:
                    assert block.exits[2].exitcase is Exception
                    self.make_exception_link(block.exits[2], False)
                return
            else:
                while True:
                    lastopname = block.operations[index].opname
                    if lastopname != '-live-':
                        break
                    index -= 1
            assert block.exits[0].exitcase is None # is this always True?
            #
            if not self._include_all_exc_links:
                if index == -1:
                    # cannot raise: the last instruction is not
                    # actually a '-live-'
                    self.make_link(block.exits[0], False)
                    return
            #
            self.emitline('catch_exception', TLabel(block.exits[0]))
            self.make_link(block.exits[0], False)
            self.emitline(Label(block.exits[0]))
            for link in block.exits[1:]:
                if link.exitcase is Exception:
                    # this link captures all exceptions
                    self.make_exception_link(link, False)
                    break
                self.emitline('goto_if_exception_mismatch',
                              Constant(link.llexitcase,
                                       lltype.typeOf(link.llexitcase)),
                              TLabel(link))
                self.make_exception_link(link, False)
                self.emitline(Label(link))
            else:
                # no link captures all exceptions, so we have to put a reraise
                # for the other exceptions
                self.emitline("reraise")
                self.emitline("---")
        #
        elif len(block.exits) == 2 and (
                isinstance(block.exitswitch, tuple) or
                block.exitswitch.concretetype == lltype.Bool):
            # Two exit links with a boolean condition
            linkfalse, linktrue = block.exits
            if linkfalse.llexitcase == True:
                linkfalse, linktrue = linktrue, linkfalse
            opname = 'goto_if_not'
            if isinstance(block.exitswitch, tuple):
                # special case produced by jtransform.optimize_goto_if_not()
                opname = 'goto_if_not_' + block.exitswitch[0]
                opargs = block.exitswitch[1:]
                if opargs[-1] == '-live-before':
                    opargs = opargs[:-1]
            else:
                assert block.exitswitch.concretetype == lltype.Bool
                opargs = [block.exitswitch]
            #
            lst = self.flatten_list(opargs) + [TLabel(linkfalse)]
            self.emitline('-live-')
            self.emitline(opname, *lst)
            #if not livebefore:
            #    self.emitline('-live-', TLabel(linkfalse))
            # true path:
            self.make_link(linktrue, handling_ovf)
            # false path:
            self.emitline(Label(linkfalse))
            self.make_link(linkfalse, handling_ovf)
        #
        else:
            # A switch.
            #
            switches = [link for link in block.exits
                        if link.exitcase != 'default']
            switches.sort(key=lambda link: link.llexitcase)
            kind = getkind(block.exitswitch.concretetype)
            assert kind == 'int'    # XXX
            #
            # A switch on an integer, implementable efficiently with the
            # help of a SwitchDictDescr.  We use this even if there are
            # very few cases: in pyjitpl.py, opimpl_switch() will promote
            # the int only if it matches one of the cases.
            from rpython.jit.codewriter.jitcode import SwitchDictDescr
            switchdict = SwitchDictDescr()
            switchdict._labels = []
            self.emitline('-live-')    # for 'guard_value'
            self.emitline('switch', self.getcolor(block.exitswitch),
                                    switchdict)
            # emit the default path
            if block.exits[-1].exitcase == 'default':
                self.make_link(block.exits[-1], handling_ovf)
            else:
                self.emitline("unreachable")
                self.emitline("---")
            #
            for switch in switches:
                key = lltype.cast_primitive(lltype.Signed,
                                            switch.llexitcase)
                switchdict._labels.append((key, TLabel(switch)))
                # emit code for that path
                # note: we need a -live- for all the 'guard_false' we produce
                # if the switched value doesn't match any case.
                self.emitline(Label(switch))
                self.emitline('-live-')
                self.make_link(switch, handling_ovf)

    def insert_renamings(self, link):
        renamings = {}
        lst = [(self.getcolor(v), self.getcolor(link.target.inputargs[i]))
               for i, v in enumerate(link.args)
               if v.concretetype is not lltype.Void and
                  v not in (link.last_exception, link.last_exc_value)]
        lst.sort(key=lambda(v, w): w.index)
        for v, w in lst:
            if v == w:
                continue
            frm, to = renamings.setdefault(w.kind, ([], []))
            frm.append(v)
            to.append(w)
        for kind in KINDS:
            if kind in renamings:
                frm, to = renamings[kind]
                # Produce a series of %s_copy.  If there is a cycle, it
                # is handled with a %s_push to save the first value of
                # the cycle, some number of %s_copy, and finally a
                # %s_pop to load the last value.
                result = reorder_renaming_list(frm, to)
                for v, w in result:
                    if w is None:
                        self.emitline('%s_push' % kind, v)
                    elif v is None:
                        self.emitline('%s_pop' % kind, "->", w)
                    else:
                        self.emitline('%s_copy' % kind, v, "->", w)
        self.generate_last_exc(link, link.target.inputargs)

    def generate_last_exc(self, link, inputargs):
        # Write 'last_exc_xxx' operations that load the last exception
        # directly into the locations specified by 'inputargs'.  This
        # must be done at the end of the link renamings.
        if link.last_exception is link.last_exc_value is None:
            return
        for v, w in zip(link.args, inputargs):
            if v is link.last_exception:
                self.emitline("last_exception", "->", self.getcolor(w))
        for v, w in zip(link.args, inputargs):
            if v is link.last_exc_value:
                self.emitline("last_exc_value", "->", self.getcolor(w))

    def emitline(self, *line):
        self.ssarepr.insns.append(line)

    def popline(self):
        return self.ssarepr.insns.pop()

    def flatten_list(self, arglist):
        args = []
        for v in arglist:
            if isinstance(v, Variable):
                v = self.getcolor(v)
            elif isinstance(v, Constant):
                pass
            elif isinstance(v, ListOfKind):
                lst = [self.getcolor(x) for x in v]
                v = ListOfKind(v.kind, lst)
            elif isinstance(v, (AbstractDescr,
                                IndirectCallTargets)):
                pass
            else:
                raise NotImplementedError(type(v))
            args.append(v)
        return args

    def serialize_op(self, op):
        args = self.flatten_list(op.args)
        if op.result is not None:
            kind = getkind(op.result.concretetype)
            if kind != 'void':
                args.append("->")
                args.append(self.getcolor(op.result))
        self.emitline(op.opname, *args)

    def getcolor(self, v):
        if isinstance(v, Constant):
            return v
        kind = getkind(v.concretetype)
        col = self.regallocs[kind].getcolor(v)    # if kind=='void', fix caller
        try:
            r = self.registers[kind, col]
        except KeyError:
            r = self.registers[kind, col] = Register(kind, col)
        return r

# ____________________________________________________________

def reorder_renaming_list(frm, to):
    result = []
    pending_indices = range(len(to))
    while pending_indices:
        not_read = dict.fromkeys([frm[i] for i in pending_indices])
        still_pending_indices = []
        for i in pending_indices:
            if to[i] not in not_read:
                result.append((frm[i], to[i]))
            else:
                still_pending_indices.append(i)
        if len(pending_indices) == len(still_pending_indices):
            # no progress -- there is a cycle
            assert None not in not_read
            result.append((frm[pending_indices[0]], None))
            frm[pending_indices[0]] = None
            continue
        pending_indices = still_pending_indices
    return result

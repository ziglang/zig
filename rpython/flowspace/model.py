# The model produced by the flowobjspace
# this is to be used by the translator mainly.
#
# the below object/attribute model evolved from
# a discussion in Berlin, 4th of october 2003
import types
import py

from rpython.tool.uid import uid, Hashable
from rpython.tool.sourcetools import PY_IDENTIFIER, nice_repr_for_func


class FunctionGraph(object):
    def __init__(self, name, startblock, return_var=None):
        self.name = name  # function name (possibly mangled already)
        self.startblock = startblock
        # build default returnblock
        self.returnblock = Block([return_var or Variable()])
        self.returnblock.operations = ()
        self.returnblock.exits = ()
        # block corresponding to exception results
        self.exceptblock = Block([Variable('etype'),   # exception class
                                  Variable('evalue')])  # exception value
        self.exceptblock.operations = ()
        self.exceptblock.exits = ()
        self.tag = None

    def getargs(self):
        return self.startblock.inputargs

    def getreturnvar(self):
        return self.returnblock.inputargs[0]

    @property
    def source(self):
        if hasattr(self, "_source"):
            return self._source
        from rpython.tool.sourcetools import getsource
        self.func    # can raise AttributeError
        src = getsource(self.func)
        if src is None:
            raise AttributeError('source not found')
        return src

    @source.setter
    def source(self, value):
        self._source = value

    @property
    def startline(self):
        return self.func.__code__.co_firstlineno

    @property
    def filename(self):
        return self.func.__code__.co_filename

    def __str__(self):
        if hasattr(self, 'func'):
            return nice_repr_for_func(self.func, self.name)
        else:
            return self.name

    def __repr__(self):
        return '<FunctionGraph of %s at 0x%x>' % (self, uid(self))

    def iterblocks(self):
        block = self.startblock
        yield block
        seen = {block: True}
        stack = list(block.exits[::-1])
        while stack:
            block = stack.pop().target
            if block not in seen:
                yield block
                seen[block] = True
                stack += block.exits[::-1]

    def iterlinks(self):
        block = self.startblock
        seen = {block: True}
        stack = list(block.exits[::-1])
        while stack:
            link = stack.pop()
            yield link
            block = link.target
            if block not in seen:
                seen[block] = True
                stack += block.exits[::-1]

    def iterblockops(self):
        for block in self.iterblocks():
            for op in block.operations:
                yield block, op

    def show(self, t=None):
        from rpython.translator.tool.graphpage import FlowGraphPage
        FlowGraphPage(t, [self]).display()

    def showbg(self, t=None):
        import os
        self.show(t)
        if os.fork() == 0:
            self.show(t)
            os._exit(0)

    view = show


class Link(object):

    __slots__ = """args target exitcase llexitcase prevblock
                last_exception last_exc_value""".split()

    def __init__(self, args, target, exitcase=None):
        if target is not None:
            assert len(args) == len(target.inputargs), "output args mismatch"
        self.args = list(args)     # mixed list of var/const
        self.target = target       # block
        self.exitcase = exitcase   # this is a concrete value
        self.prevblock = None      # the block this Link is an exit of

        # exception passing vars
        self.last_exception = None
        self.last_exc_value = None

    # right now only exception handling needs to introduce new variables on the links
    def extravars(self, last_exception=None, last_exc_value=None):
        self.last_exception = last_exception
        self.last_exc_value = last_exc_value

    def getextravars(self):
        "Return the extra vars created by this Link."
        result = []
        if isinstance(self.last_exception, Variable):
            result.append(self.last_exception)
        if isinstance(self.last_exc_value, Variable):
            result.append(self.last_exc_value)
        return result

    def copy(self, rename=lambda x: x):
        newargs = [rename(a) for a in self.args]
        newlink = Link(newargs, self.target, self.exitcase)
        newlink.prevblock = self.prevblock
        newlink.last_exception = rename(self.last_exception)
        newlink.last_exc_value = rename(self.last_exc_value)
        if hasattr(self, 'llexitcase'):
            newlink.llexitcase = self.llexitcase
        return newlink

    def replace(self, mapping):
        def rename(v):
            if v is not None:
                return v.replace(mapping)
        return self.copy(rename)

    def settarget(self, targetblock):
        assert len(self.args) == len(targetblock.inputargs), (
            "output args mismatch")
        self.target = targetblock

    def __repr__(self):
        return "link from %s to %s" % (str(self.prevblock), str(self.target))

    def show(self):
        from rpython.translator.tool.graphpage import try_show
        return try_show(self)

    view = show


class Block(object):
    __slots__ = """inputargs operations exitswitch
                exits blockcolor generation""".split()

    def __init__(self, inputargs):
        self.inputargs = list(inputargs)  # mixed list of variable/const XXX
        self.operations = []              # list of SpaceOperation(s)
        self.exitswitch = None            # a variable or
                                          #  Constant(last_exception), see below
        self.exits = []                   # list of Link(s)

    def is_final_block(self):
        return self.operations == ()      # return or except block

    def at(self):
        if self.operations and self.operations[0].offset >= 0:
            return "@%d" % self.operations[0].offset
        else:
            return ""

    def __str__(self):
        if self.operations:
            txt = "block@%d" % self.operations[0].offset
        else:
            if (not self.exits) and len(self.inputargs) == 1:
                txt = "return block"
            elif (not self.exits) and len(self.inputargs) == 2:
                txt = "raise block"
            else:
                txt = "codeless block"
        if len(self.inputargs) > 0:
            if len(self.inputargs) > 1:
                txt += '[%s...]' % (self.inputargs[0],)
            else:
                txt += '[%s]' % (self.inputargs[0],)
        return txt

    def __repr__(self):
        txt = "%s with %d exits" % (str(self), len(self.exits))
        if self.exitswitch:
            txt = "%s(%s)" % (txt, self.exitswitch)
        return txt

    @property
    def canraise(self):
        return self.exitswitch is c_last_exception

    @property
    def raising_op(self):
        if self.canraise:
            return self.operations[-1]

    def getvariables(self):
        "Return all variables mentioned in this Block."
        result = self.inputargs[:]
        for op in self.operations:
            result += op.args
            result.append(op.result)
        return uniqueitems([w for w in result if isinstance(w, Variable)])

    def getconstants(self):
        "Return all constants mentioned in this Block."
        result = self.inputargs[:]
        for op in self.operations:
            result += op.args
        return uniqueitems([w for w in result if isinstance(w, Constant)])

    def renamevariables(self, mapping):
        self.inputargs = [a.replace(mapping) for a in self.inputargs]
        self.operations = [op.replace(mapping) for op in self.operations]
        if self.exitswitch is not None:
            self.exitswitch = self.exitswitch.replace(mapping)
        for link in self.exits:
            link.args = [a.replace(mapping) for a in link.args]

    def closeblock(self, *exits):
        assert self.exits == [], "block already closed"
        self.recloseblock(*exits)

    def recloseblock(self, *exits):
        for exit in exits:
            exit.prevblock = self
        self.exits = exits

    def show(self):
        from rpython.translator.tool.graphpage import try_show
        return try_show(self)

    def _slowly_get_graph(self):
        import gc
        pending = [self]   # pending blocks
        seen = {self: True, None: True}
        for x in pending:
            for y in gc.get_referrers(x):
                if isinstance(y, FunctionGraph):
                    return y
                elif isinstance(y, Link):
                    block = y.prevblock
                    if block not in seen:
                        pending.append(block)
                        seen[block] = True
                elif isinstance(y, dict):
                    pending.append(y)   # go back from the dict to the real obj
        return pending

    view = show


class Variable(object):
    __slots__ = ["_name", "_nr", "annotation", "concretetype"]

    dummyname = 'v'
    namesdict = {dummyname: (dummyname, 0)}

    @property
    def name(self):
        _name = self._name
        _nr = self._nr
        if _nr == -1:
            # consume numbers lazily
            nd = self.namesdict
            _nr = self._nr = nd[_name][1]
            nd[_name] = (_name, _nr + 1)
        return "%s%d" % (_name, _nr)

    @property
    def renamed(self):
        return self._name is not self.dummyname

    def __init__(self, name=None):
        self._name = self.dummyname
        self._nr = -1
        self.annotation = None
        # numbers are bound lazily, when the name is requested
        if name is not None:
            self.rename(name)

    def __repr__(self):
        return self.name

    def rename(self, name):
        if self._name is not self.dummyname:   # don't rename several times
            return
        if type(name) is not str:
            #assert isinstance(name, Variable) -- disabled for speed reasons
            name = name._name
            if name is self.dummyname:    # the other Variable wasn't renamed either
                return
        else:
            # remove strange characters in the name
            name = name.translate(PY_IDENTIFIER) + '_'
            if name[0] <= '9':   # skipped the   '0' <=   which is always true
                name = '_' + name
            name = self.namesdict.setdefault(name, (name, 0))[0]
        self._name = name
        self._nr = -1

    def set_name_from(self, v):
        # this is for SSI_to_SSA only which should not know about internals
        v.name  # make sure v's name is finalized
        self._name = v._name
        self._nr = v._nr

    def set_name(self, name, nr):
        # this is for wrapper.py which wants to assign a name explicitly
        self._name = intern(name)
        self._nr = nr

    def foldable(self):
        return False

    def copy(self):
        """Make a copy of the Variable, preserving annotations and concretetype."""
        newvar = Variable(self)
        newvar.annotation = self.annotation
        if hasattr(self, 'concretetype'):
            newvar.concretetype = self.concretetype
        return newvar

    def replace(self, mapping):
        return mapping.get(self, self)


class Constant(Hashable):
    __slots__ = ["concretetype"]

    def __init__(self, value, concretetype=None):
        Hashable.__init__(self, value)
        if concretetype is not None:
            self.concretetype = concretetype

    def foldable(self):
        to_check = self.value
        if hasattr(to_check, 'im_self'):
            to_check = to_check.im_self
        if isinstance(to_check, (type, types.ClassType, types.ModuleType)):
            # classes/types/modules are assumed immutable
            return True
        if (hasattr(to_check, '__class__') and
                to_check.__class__.__module__ == '__builtin__'):
            # builtin object
            return True
        # User-created instance
        if hasattr(to_check, '_freeze_'):
            assert to_check._freeze_() is True
            return True
        else:
            # cannot count on it not mutating at runtime!
            return False

    def replace(self, mapping):
        return self


class FSException(object):
    def __init__(self, w_type, w_value):
        assert w_type is not None
        self.w_type = w_type
        self.w_value = w_value

    def __str__(self):
        return '[%s: %s]' % (self.w_type, self.w_value)

class ConstException(Constant, FSException):
    def foldable(self):
        return True

    @property
    def w_type(self):
        return Constant(type(self.value))

    @property
    def w_value(self):
        return Constant(self.value)


class UnwrapException(Exception):
    """Attempted to unwrap a Variable."""

class WrapException(Exception):
    """Attempted wrapping of a type that cannot sanely appear in flow graph or
    during its construction"""


# method-wrappers have not enough introspection in CPython
if hasattr(complex.real.__get__, 'im_self'):
    type_with_bad_introspection = None     # on top of PyPy
else:
    type_with_bad_introspection = type(complex.real.__get__)

def const(obj):
    if hasattr(obj, "_flowspace_rewrite_directly_as_"):
        obj = obj._flowspace_rewrite_directly_as_
    if isinstance(obj, (Variable, Constant)):
        raise TypeError("already wrapped: " + repr(obj))
    # method-wrapper have ill-defined comparison and introspection
    # to appear in a flow graph
    if type(obj) is type_with_bad_introspection:
        raise WrapException
    elif isinstance(obj, Exception):
        return ConstException(obj)
    return Constant(obj)

class SpaceOperation(object):

    def __init__(self, opname, args, result, offset=-1):
        self.opname = intern(opname)      # operation name
        self.args = list(args)    # mixed list of var/const
        self.result = result      # either Variable or Constant instance
        self.offset = offset      # offset in code string

    def __eq__(self, other):
        return (self.__class__ is other.__class__ and
                self.opname == other.opname and
                self.args == other.args and
                self.result == other.result)

    def __ne__(self, other):
        return not (self == other)

    def __hash__(self):
        return hash((self.opname, tuple(self.args), self.result))

    def __repr__(self):
        return "%r = %s(%s)" % (self.result, self.opname,
                                ", ".join(map(repr, self.args)))

    def replace(self, mapping):
        newargs = [arg.replace(mapping) for arg in self.args]
        newresult = self.result.replace(mapping)
        return type(self)(self.opname, newargs, newresult, self.offset)

class Atom(object):
    def __init__(self, name):
        self.__name__ = name  # make save_global happy
    def __repr__(self):
        return self.__name__

last_exception = Atom('last_exception')
c_last_exception = Constant(last_exception)
# if Block().exitswitch == Constant(last_exception), it means that we are
# interested in catching the exception that the *last operation* of the
# block could raise.  The exitcases of the links are None for no exception
# or XxxError classes to catch the matching exceptions.

def uniqueitems(lst):
    "Returns a list with duplicate elements removed."
    result = []
    seen = {}
    for item in lst:
        if item not in seen:
            result.append(item)
            seen[item] = True
    return result


def flattenobj(*args):
    for arg in args:
        try:
            for atom in flattenobj(*arg):
                yield atom
        except:
            yield arg

def mkentrymap(funcgraph):
    "Returns a dict mapping Blocks to lists of Links."
    startlink = Link(funcgraph.getargs(), funcgraph.startblock)
    result = {funcgraph.startblock: [startlink]}
    for link in funcgraph.iterlinks():
        lst = result.setdefault(link.target, [])
        lst.append(link)
    return result

def copygraph(graph, shallow=False, varmap={}, shallowvars=False):
    "Make a copy of a flow graph."
    blockmap = {}
    varmap = varmap.copy()
    shallowvars = shallowvars or shallow

    def copyvar(v):
        if shallowvars:
            return v
        try:
            return varmap[v]
        except KeyError:
            if isinstance(v, Variable):
                v2 = varmap[v] = Variable(v)
                if hasattr(v, 'concretetype'):
                    v2.concretetype = v.concretetype
                return v2
            else:
                return v

    def copyblock(block):
        newblock = Block([copyvar(v) for v in block.inputargs])
        if block.operations == ():
            newblock.operations = ()
        else:
            def copyoplist(oplist):
                if shallow:
                    return oplist[:]
                result = []
                for op in oplist:
                    copyop = SpaceOperation(op.opname,
                                            [copyvar(v) for v in op.args],
                                            copyvar(op.result), op.offset)
                    #copyop.offset = op.offset
                    result.append(copyop)
                return result
            newblock.operations = copyoplist(block.operations)
        newblock.exitswitch = copyvar(block.exitswitch)
        return newblock

    for block in graph.iterblocks():
        blockmap[block] = copyblock(block)

    if graph.returnblock not in blockmap:
        blockmap[graph.returnblock] = copyblock(graph.returnblock)
    if graph.exceptblock not in blockmap:
        blockmap[graph.exceptblock] = copyblock(graph.exceptblock)

    for block, newblock in blockmap.items():
        newlinks = []
        for link in block.exits:
            newlink = link.copy(copyvar)
            newlink.target = blockmap[link.target]
            newlinks.append(newlink)
        newblock.closeblock(*newlinks)

    newstartblock = blockmap[graph.startblock]
    newgraph = FunctionGraph(graph.name, newstartblock)
    newgraph.returnblock = blockmap[graph.returnblock]
    newgraph.exceptblock = blockmap[graph.exceptblock]
    for key, value in graph.__dict__.items():
        newgraph.__dict__.setdefault(key, value)
    return newgraph

def checkgraph(graph):
    "Check the consistency of a flow graph."
    if not __debug__:
        return
    try:
        from rpython.rlib.rarithmetic import (is_valid_int, r_longlong,
            r_ulonglong, r_uint)
        vars_previous_blocks = {}

        exitblocks = {graph.returnblock: 1,   # retval
                      graph.exceptblock: 2}   # exc_cls, exc_value

        for block, nbargs in exitblocks.items():
            assert len(block.inputargs) == nbargs
            assert block.operations == ()
            assert block.exits == ()

        def definevar(v, only_in_link=None):
            assert isinstance(v, Variable)
            assert v not in vars, "duplicate variable %r" % (v,)
            assert v not in vars_previous_blocks, (
                "variable %r used in more than one block" % (v,))
            vars[v] = only_in_link

        def usevar(v, in_link=None):
            assert v in vars
            if in_link is not None:
                assert vars[v] is None or vars[v] is in_link


        for block in graph.iterblocks():
            assert type(block.exits) is tuple, (
                "block.exits is a %s (closeblock() or recloseblock() missing?)"
                % (type(block.exits).__name__,))
            if not block.exits:
                assert block in exitblocks
            vars = {}

            for v in block.inputargs:
                definevar(v)

            for op in block.operations:
                for v in op.args:
                    assert isinstance(v, (Constant, Variable))
                    if isinstance(v, Variable):
                        usevar(v)
                    else:
                        assert v.value is not last_exception
                        #assert v.value != last_exc_value
                if op.opname == 'direct_call':
                    assert isinstance(op.args[0], Constant)
                elif op.opname == 'indirect_call':
                    assert isinstance(op.args[0], Variable)
                definevar(op.result)

            exc_links = {}
            if block.exitswitch is None:
                assert len(block.exits) <= 1
                if block.exits:
                    assert block.exits[0].exitcase is None
            elif block.canraise:
                assert len(block.operations) >= 1
                # check if an exception catch is done on a reasonable
                # operation
                assert block.raising_op.opname not in ("keepalive",
                                                           "cast_pointer",
                                                           "same_as")
                assert len(block.exits) >= 2
                assert block.exits[0].exitcase is None
                for link in block.exits[1:]:
                    assert issubclass(link.exitcase, py.builtin.BaseException)
                    exc_links[link] = True
            else:
                assert isinstance(block.exitswitch, Variable)
                assert block.exitswitch in vars
                if (len(block.exits) == 2 and block.exits[0].exitcase is False
                                          and block.exits[1].exitcase is True):
                    # a boolean switch
                    pass
                else:
                    # a multiple-cases switch (or else the False and True
                    # branches are in the wrong order)
                    assert len(block.exits) >= 1
                    cases = [link.exitcase for link in block.exits]
                    has_default = cases[-1] == 'default'
                    for n in cases[:len(cases)-has_default]:
                        if is_valid_int(n):
                            continue
                        if isinstance(n, (r_longlong, r_ulonglong, r_uint)):
                            continue
                        if isinstance(n, (str, unicode)) and len(n) == 1:
                            continue
                        assert n != 'default', (
                            "'default' branch of a switch is not the last exit"
                            )
                        assert n is not None, (
                            "exitswitch Variable followed by a None exitcase")
                        raise AssertionError(
                            "switch on a non-primitive value %r" % (n,))

            allexitcases = {}
            for link in block.exits:
                assert len(link.args) == len(link.target.inputargs)
                assert link.prevblock is block
                exc_link = link in exc_links
                if exc_link:
                    for v in [link.last_exception, link.last_exc_value]:
                        assert isinstance(v, (Variable, Constant))
                        if isinstance(v, Variable):
                            definevar(v, only_in_link=link)
                else:
                    assert link.last_exception is None
                    assert link.last_exc_value is None
                for v in link.args:
                    assert isinstance(v, (Constant, Variable))
                    if isinstance(v, Variable):
                        usevar(v, in_link=link)
                        if exc_link:
                            assert v != block.operations[-1].result
                    #else:
                    #    if not exc_link:
                    #        assert v.value is not last_exception
                    #        #assert v.value != last_exc_value
                allexitcases[link.exitcase] = True
            assert len(allexitcases) == len(block.exits)
            vars_previous_blocks.update(vars)

    except AssertionError as e:
        # hack for debug tools only
        #graph.show()  # <== ENABLE THIS TO SEE THE BROKEN GRAPH
        if block and not hasattr(e, '__annotator_block'):
            setattr(e, '__annotator_block', block)
        raise

def summary(graph):
    # return a summary of the instructions found in a graph
    insns = {}
    for block in graph.iterblocks():
        for op in block.operations:
            if op.opname != 'same_as':
                insns[op.opname] = insns.get(op.opname, 0) + 1
    return insns

def safe_iterblocks(graph):
    # for debugging or displaying broken graphs.
    # You still have to check that the yielded blocks are really Blocks.
    block = getattr(graph, 'startblock', None)
    yield block
    seen = {block: True}
    stack = list(getattr(block, 'exits', [])[::-1])
    while stack:
        block = stack.pop().target
        if block not in seen:
            yield block
            seen[block] = True
            stack += getattr(block, 'exits', [])[::-1]

def safe_iterlinks(graph):
    # for debugging or displaying broken graphs.
    # You still have to check that the yielded links are really Links.
    block = getattr(graph, 'startblock', None)
    seen = {block: True}
    stack = list(getattr(block, 'exits', [])[::-1])
    while stack:
        link = stack.pop()
        yield link
        block = getattr(link, 'target', None)
        if block not in seen:
            seen[block] = True
            stack += getattr(block, 'exits', [])[::-1]

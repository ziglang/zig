# specialization support
import py

from rpython.tool.sourcetools import func_with_new_name
from rpython.tool.algo.unionfind import UnionFind
from rpython.flowspace.model import Block, Link, Variable
from rpython.flowspace.model import checkgraph
from rpython.flowspace.operation import op
from rpython.annotator import model as annmodel
from rpython.flowspace.argument import Signature
from rpython.annotator.model import SomePBC, SomeImpossibleValue, SomeBool
from rpython.annotator.model import unionof

def flatten_star_args(funcdesc, args_s):
    argnames, vararg, kwarg = funcdesc.signature
    assert not kwarg, "functions with ** arguments are not supported"
    if vararg:
        # calls to *arg functions: create one version per number of args
        assert len(args_s) == len(argnames) + 1
        s_tuple = args_s[-1]
        assert isinstance(s_tuple, annmodel.SomeTuple), (
            "calls f(..., *arg) require 'arg' to be a tuple")
        s_len = s_tuple.len()
        assert s_len.is_constant(), "calls require known number of args"
        nb_extra_args = s_len.const
        flattened_s = list(args_s[:-1])
        flattened_s.extend(s_tuple.items)

        def builder(translator, func):
            # build a hacked graph that doesn't take a *arg any more, but
            # individual extra arguments
            graph = translator.buildflowgraph(func)
            argnames, vararg, kwarg = graph.signature
            assert vararg, "graph should have a *arg at this point"
            assert not kwarg, "where does this **arg come from??"
            argscopy = [Variable(v) for v in graph.getargs()]
            starargs = [Variable('stararg%d'%i) for i in range(nb_extra_args)]
            newstartblock = Block(argscopy[:-1] + starargs)
            newtup = op.newtuple(*starargs)
            newtup.result = argscopy[-1]
            newstartblock.operations.append(newtup)
            newstartblock.closeblock(Link(argscopy, graph.startblock))
            graph.startblock = newstartblock
            argnames = argnames + ['.star%d' % i for i in range(nb_extra_args)]
            graph.signature = Signature(argnames)
            # note that we can mostly ignore defaults: if nb_extra_args > 0,
            # then defaults aren't applied.  if nb_extra_args == 0, then this
            # just removes the *arg and the defaults keep their meaning.
            if nb_extra_args > 0:
                graph.defaults = None   # shouldn't be used in this case
            checkgraph(graph)
            return graph

        key = ('star', nb_extra_args)
        return flattened_s, key, builder

    else:
        return args_s, None, None

def default_specialize(funcdesc, args_s):
    # first flatten the *args
    args_s, key, builder = flatten_star_args(funcdesc, args_s)
    # two versions: a regular one and one for instances with 'access_directly'
    jit_look_inside = getattr(funcdesc.pyobj, '_jit_look_inside_', True)
    # change args_s in place, "official" interface
    access_directly = False
    for i, s_obj in enumerate(args_s):
        if (isinstance(s_obj, annmodel.SomeInstance) and
            'access_directly' in s_obj.flags):
            if jit_look_inside:
                access_directly = True
                key = (AccessDirect, key)
                break
            else:
                new_flags = s_obj.flags.copy()
                del new_flags['access_directly']
                new_s_obj = annmodel.SomeInstance(s_obj.classdef, s_obj.can_be_None,
                                              flags = new_flags)
                args_s[i] = new_s_obj

    # done
    graph = funcdesc.cachedgraph(key, builder=builder)
    if access_directly:
        graph.access_directly = True
    return graph

class AccessDirect(object):
    """marker for specialization: set when any arguments is a SomeInstance
    which has the 'access_directly' flag set."""

def getuniquenondirectgraph(desc):
    result = []
    for key, graph in desc._cache.items():
        if (type(key) is tuple and len(key) == 2 and
            key[0] is AccessDirect):
            continue
        result.append(graph)
    assert len(result) == 1
    return result[0]

# ____________________________________________________________________________
# specializations

class MemoTable(object):
    def __init__(self, funcdesc, args, value):
        self.funcdesc = funcdesc
        self.table = {args: value}
        self.graph = None
        self.do_not_process = False

    def register_finish(self):
        bookkeeper = self.funcdesc.bookkeeper
        bookkeeper.pending_specializations.append(self.finish)

    def absorb(self, other):
        self.table.update(other.table)
        assert self.graph is None, "too late for MemoTable merge!"
        del other.graph   # just in case
        other.do_not_process = True

    fieldnamecounter = 0

    def getuniquefieldname(self):
        name = self.funcdesc.name
        fieldname = '$memofield_%s_%d' % (name, MemoTable.fieldnamecounter)
        MemoTable.fieldnamecounter += 1
        return fieldname

    def finish(self):
        if self.do_not_process:
            return
        assert self.graph is None, "MemoTable already finished"
        # list of which argument positions can take more than one value
        example_args, example_value = self.table.iteritems().next()
        nbargs = len(example_args)
        # list of sets of possible argument values -- one set per argument index
        sets = [set() for i in range(nbargs)]
        for args in self.table:
            for i in range(nbargs):
                sets[i].add(args[i])

        bookkeeper = self.funcdesc.bookkeeper
        annotator = bookkeeper.annotator
        name = self.funcdesc.name
        argnames = ['a%d' % i for i in range(nbargs)]

        def make_helper(firstarg, stmt, miniglobals):
            header = "def f(%s):" % (', '.join(argnames[firstarg:],))
            source = py.code.Source(stmt)
            source = source.putaround(header)
            exec source.compile() in miniglobals
            f = miniglobals['f']
            return func_with_new_name(f, 'memo_%s_%d' % (name, firstarg))

        def make_constant_subhelper(firstarg, result):
            # make a function that just returns the constant answer 'result'
            f = make_helper(firstarg, 'return result', {'result': result})
            f.constant_result = result
            return f

        def make_subhelper(args_so_far=()):
            firstarg = len(args_so_far)
            if firstarg == nbargs:
                # no argument left, return the known result
                # (or a dummy value if none corresponds exactly)
                result = self.table.get(args_so_far, example_value)
                return make_constant_subhelper(firstarg, result)
            else:
                nextargvalues = list(sets[len(args_so_far)])
                if nextargvalues == [True, False]:
                    nextargvalues = [False, True]
                nextfns = [make_subhelper(args_so_far + (arg,))
                           for arg in nextargvalues]
                # do all graphs return a constant?
                try:
                    constants = [fn.constant_result for fn in nextfns]
                except AttributeError:
                    constants = None    # one of the 'fn' has no constant_result
                restargs = ', '.join(argnames[firstarg+1:])

                # is there actually only one possible value for the current arg?
                if len(nextargvalues) == 1:
                    if constants:   # is the result a constant?
                        result = constants[0]
                        return make_constant_subhelper(firstarg, result)
                    else:
                        # ignore the first argument and just call the subhelper
                        stmt = 'return subhelper(%s)' % restargs
                        return make_helper(firstarg, stmt,
                                           {'subhelper': nextfns[0]})

                # is the arg a bool?
                elif nextargvalues == [False, True]:
                    stmt = ['if %s:' % argnames[firstarg]]
                    if hasattr(nextfns[True], 'constant_result'):
                        # the True branch has a constant result
                        case1 = nextfns[True].constant_result
                        stmt.append('    return case1')
                    else:
                        # must call the subhelper
                        case1 = nextfns[True]
                        stmt.append('    return case1(%s)' % restargs)
                    stmt.append('else:')
                    if hasattr(nextfns[False], 'constant_result'):
                        # the False branch has a constant result
                        case0 = nextfns[False].constant_result
                        stmt.append('    return case0')
                    else:
                        # must call the subhelper
                        case0 = nextfns[False]
                        stmt.append('    return case0(%s)' % restargs)

                    return make_helper(firstarg, '\n'.join(stmt),
                                       {'case0': case0,
                                        'case1': case1})

                # the arg is a set of PBCs
                else:
                    descs = [bookkeeper.getdesc(pbc) for pbc in nextargvalues]
                    fieldname = self.getuniquefieldname()
                    stmt = 'return getattr(%s, %r)' % (argnames[firstarg],
                                                       fieldname)
                    if constants:
                        # instead of calling these subhelpers indirectly,
                        # we store what they would return directly in the
                        # pbc memo fields
                        store = constants
                    else:
                        store = nextfns
                        # call the result of the getattr()
                        stmt += '(%s)' % restargs

                    # store the memo field values
                    for desc, value_to_store in zip(descs, store):
                        desc.create_new_attribute(fieldname, value_to_store)

                    return make_helper(firstarg, stmt, {})

        entrypoint = make_subhelper(args_so_far = ())
        self.graph = annotator.translator.buildflowgraph(entrypoint)
        self.graph.defaults = self.funcdesc.defaults

        # schedule this new graph for being annotated
        args_s = []
        for arg_types in sets:
            values_s = [bookkeeper.immutablevalue(x) for x in arg_types]
            args_s.append(unionof(*values_s))
        annotator.addpendinggraph(self.graph, args_s)

def all_values(s):
    """Return the exhaustive list of possible values matching annotation `s`.

    Raises `AnnotatorError` if no such (reasonably small) finite list exists.
    """
    if s.is_constant():
        return [s.const]
    elif isinstance(s, SomePBC):
        values = []
        assert not s.can_be_None, "memo call: cannot mix None and PBCs"
        for desc in s.descriptions:
            if desc.pyobj is None:
                raise annmodel.AnnotatorError(
                    "memo call with a class or PBC that has no "
                    "corresponding Python object (%r)" % (desc,))
            values.append(desc.pyobj)
        return values
    elif isinstance(s, SomeImpossibleValue):
        return []
    elif isinstance(s, SomeBool):
        return [False, True]
    else:
        raise annmodel.AnnotatorError("memo call: argument must be a class "
                                        "or a frozen PBC, got %r" % (s,))

def memo(funcdesc, args_s):
    # call the function now, and collect possible results

    # the list of all possible tuples of arguments to give to the memo function
    possiblevalues = cartesian_product([all_values(s_arg) for s_arg in args_s])

    # a MemoTable factory -- one MemoTable per family of arguments that can
    # be called together, merged via a UnionFind.
    bookkeeper = funcdesc.bookkeeper
    try:
        memotables = bookkeeper.all_specializations[funcdesc]
    except KeyError:
        func = funcdesc.pyobj
        if func is None:
            raise annmodel.AnnotatorError("memo call: no Python function object"
                                          "to call (%r)" % (funcdesc,))

        def compute_one_result(args):
            value = func(*args)
            memotable = MemoTable(funcdesc, args, value)
            memotable.register_finish()
            return memotable

        memotables = UnionFind(compute_one_result)
        bookkeeper.all_specializations[funcdesc] = memotables

    # merge the MemoTables for the individual argument combinations
    firstvalues = possiblevalues.next()
    _, _, memotable = memotables.find(firstvalues)
    for values in possiblevalues:
        _, _, memotable = memotables.union(firstvalues, values)

    if memotable.graph is not None:
        return memotable.graph   # if already computed
    else:
        # otherwise, for now, return the union of each possible result
        return unionof(*[bookkeeper.immutablevalue(v)
                         for v in memotable.table.values()])

def cartesian_product(lstlst):
    if not lstlst:
        yield ()
        return
    for tuple_tail in cartesian_product(lstlst[1:]):
        for value in lstlst[0]:
            yield (value,) + tuple_tail


def maybe_star_args(funcdesc, key, args_s):
    args_s, key1, builder = flatten_star_args(funcdesc, args_s)
    if key1 is not None:
        key = key + key1
    return funcdesc.cachedgraph(key, builder=builder)

def specialize_argvalue(funcdesc, args_s, *argindices):
    from rpython.annotator.model import SomePBC
    key = []
    for i in argindices:
        s = args_s[i]
        if s.is_constant():
            key.append(s.const)
        elif isinstance(s, SomePBC) and len(s.descriptions) == 1:
            # for test_specialize_arg_bound_method
            desc, = s.descriptions
            key.append(desc)
        else:
            raise annmodel.AnnotatorError("specialize:arg(%d): argument not "
                                          "constant: %r" % (i, s))
    key = tuple(key)
    return maybe_star_args(funcdesc, key, args_s)

def specialize_arg_or_var(funcdesc, args_s, *argindices):
    for argno in argindices:
        if not args_s[argno].is_constant():
            break
    else:
        # all constant
        return specialize_argvalue(funcdesc, args_s, *argindices)
    # some not constant
    return maybe_star_args(funcdesc, None, args_s)

def specialize_argtype(funcdesc, args_s, *argindices):
    key = tuple([args_s[i].knowntype for i in argindices])
    return maybe_star_args(funcdesc, key, args_s)

def specialize_arglistitemtype(funcdesc, args_s, i):
    s = args_s[i]
    if s.knowntype is not list:
        key = None
    else:
        key = s.listdef.listitem.s_value.knowntype
    return maybe_star_args(funcdesc, key, args_s)

def specialize_call_location(funcdesc, args_s, op):
    assert op is not None
    return maybe_star_args(funcdesc, (op,), args_s)

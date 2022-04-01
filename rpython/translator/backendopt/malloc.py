from rpython.flowspace.model import Variable, Constant, SpaceOperation
from rpython.tool.algo.unionfind import UnionFind
from rpython.rtyper.lltypesystem import lltype
from rpython.translator import simplify
from rpython.translator.backendopt import removenoops
from rpython.translator.backendopt.support import log


class LifeTime:

    def __init__(self, (block, var)):
        assert isinstance(var, Variable)
        self.variables = {(block, var)}
        self.creationpoints = set()   # set of ("type of creation point", ...)
        self.usepoints = set()        # set of ("type of use point",      ...)

    def absorb(self, other):
        self.variables.update(other.variables)
        self.creationpoints.update(other.creationpoints)
        self.usepoints.update(other.usepoints)


class BaseMallocRemover(object):

    IDENTITY_OPS = ('same_as',)
    SUBSTRUCT_OPS = ()
    MALLOC_OP = None
    FIELD_ACCESS = {}
    SUBSTRUCT_ACCESS = {}
    CHECK_ARRAY_INDEX = {}

    def __init__(self, verbose=True):
        self.verbose = verbose

    def check_malloc(self, op):
        return op.opname == self.MALLOC_OP

    def recreate_malloc(self, c, v):
        return SpaceOperation(self.MALLOC_OP, [c], v)

    def get_STRUCT(self, TYPE):
        raise NotImplementedError

    def visit_substruct_op(self, node, union, op):
        raise NotImplementedError

    def do_substruct_access(self, op):
        raise NotImplementedError

    def union_wrapper(self, S):
        return False

    def RTTI_dtor(self, STRUCT):
        return False

    def flatten(self, S):
        raise NotImplementedError

    def key_for_field_access(self, S, fldname):
        raise NotImplementedError

    def inline_type(self, TYPE):
        raise NotImplementedError

    def flowin(self, block, count, vars, newvarsmap):
        # in this 'block', follow where the 'var' goes to and replace
        # it by a flattened-out family of variables.  This family is given
        # by newvarsmap, whose keys are the 'flatnames'.

        def list_newvars():
            return [newvarsmap[key] for key in self.flatnames]

        assert block.operations != ()
        self.newops = []
        for op in block.operations:
            for arg in op.args[1:]:   # should be the first arg only
                assert arg not in vars
            if op.args and op.args[0] in vars:
                self.flowin_op(op, vars, newvarsmap)
            elif op.result in vars:
                assert op.opname == self.MALLOC_OP
                progress = True
                # drop the "malloc" operation
                newvarsmap = self.flatconstants.copy()   # zero initial values
                # if there are substructures, they are now individually
                # malloc'ed in an exploded way.  (They will typically be
                # removed again by the next malloc removal pass.)
                for key in self.needsubmallocs:
                    v = Variable()
                    v.concretetype = self.newvarstype[key]
                    c = Constant(v.concretetype.TO, lltype.Void)
                    if c.value == op.args[0].value:
                        progress = False   # replacing a malloc with
                                           # the same malloc!
                    newop = self.recreate_malloc(c, v)
                    self.newops.append(newop)
                    newvarsmap[key] = v
                count[0] += progress
            else:
                self.newops.append(op)

        assert block.exitswitch not in vars

        for link in block.exits:
            appended = False
            newargs = []
            for arg in link.args:
                if arg in vars:
                    if not appended:
                        newargs += list_newvars()
                        appended = True
                else:
                    newargs.append(arg)
            link.args[:] = newargs

        block.operations[:] = self.newops

    def compute_lifetimes(self, graph):
        """Compute the static data flow of the graph: returns a list of LifeTime
        instances, each of which corresponds to a set of Variables from the graph.
        The variables are grouped in the same LifeTime if a value can pass from
        one to the other by following the links.  Each LifeTime also records all
        places where a Variable in the set is used (read) or build (created).
        """
        lifetimes = UnionFind(LifeTime)

        def set_creation_point(block, var, *cp):
            _, _, info = lifetimes.find((block, var))
            info.creationpoints.add(cp)

        def set_use_point(block, var, *up):
            _, _, info = lifetimes.find((block, var))
            info.usepoints.add(up)

        def union(block1, var1, block2, var2):
            if isinstance(var1, Variable):
                lifetimes.union((block1, var1), (block2, var2))
            elif isinstance(var1, Constant):
                set_creation_point(block2, var2, "constant", var1)
            else:
                raise TypeError(var1)

        for var in graph.startblock.inputargs:
            set_creation_point(graph.startblock, var, "inputargs")
        set_use_point(graph.returnblock, graph.returnblock.inputargs[0], "return")
        set_use_point(graph.exceptblock, graph.exceptblock.inputargs[0], "except")
        set_use_point(graph.exceptblock, graph.exceptblock.inputargs[1], "except")

        for node in graph.iterblocks():
                for op in node.operations:
                    if op.opname in self.IDENTITY_OPS:
                        # special-case these operations to identify their input
                        # and output variables
                        union(node, op.args[0], node, op.result)
                        continue
                    if op.opname in self.SUBSTRUCT_OPS:
                        if self.visit_substruct_op(node, union, op):
                            continue
                    for i in range(len(op.args)):
                        if isinstance(op.args[i], Variable):
                            set_use_point(node, op.args[i], "op", node, op, i)
                    set_creation_point(node, op.result, "op", node, op)
                if isinstance(node.exitswitch, Variable):
                    set_use_point(node, node.exitswitch, "exitswitch", node)

        for node in graph.iterlinks():
            if isinstance(node.last_exception, Variable):
                set_creation_point(node.prevblock, node.last_exception,
                                   "last_exception")
            if isinstance(node.last_exc_value, Variable):
                set_creation_point(node.prevblock, node.last_exc_value,
                                   "last_exc_value")
            d = set()
            for i, arg in enumerate(node.args):
                union(node.prevblock, arg,
                      node.target, node.target.inputargs[i])
                if isinstance(arg, Variable):
                    if arg in d:
                        # same variable present several times in link.args
                        # consider it as a 'use' of the variable, which
                        # will disable malloc optimization (aliasing problems)
                        set_use_point(node.prevblock, arg, "dup", node, i)
                    else:
                        d.add(arg)

        return lifetimes.infos()

    def _try_inline_malloc(self, info):
        """Try to inline the mallocs creation and manipulation of the Variables
        in the given LifeTime."""
        # the values must be only ever created by a "malloc"
        lltypes = set()
        for cp in info.creationpoints:
            if cp[0] != "op":
                return False
            op = cp[2]
            if not self.check_malloc(op):
                return False
            if not self.inline_type(op.args[0].value):
                return False

            lltypes.add(op.result.concretetype)

        # there must be a single largest malloced GcStruct;
        # all variables can point to it or to initial substructures
        if len(lltypes) != 1:
            return False
        concretetype, = lltypes
        STRUCT = self.get_STRUCT(concretetype)

        # must be only ever accessed via getfield/setfield/getsubstruct/
        # direct_fieldptr, or touched by ptr_iszero/ptr_nonzero.
        # Note that same_as and cast_pointer are not recorded in usepoints.
        self.accessed_substructs = set()

        for up in info.usepoints:
            if up[0] != "op":
                return False
            kind, node, op, index = up
            if index != 0:
                return False
            if op.opname in self.CHECK_ARRAY_INDEX:
                if not isinstance(op.args[1], Constant):
                    return False    # non-constant array index
            if op.opname in self.FIELD_ACCESS:
                pass   # ok
            elif op.opname in self.SUBSTRUCT_ACCESS:
                self.do_substruct_access(op)
            else:
                return False

        # must not remove mallocs of structures that have a RTTI with a destructor
        if self.RTTI_dtor(STRUCT):
            return False

        # must not remove unions inlined as the only field of a GcStruct
        if self.union_wrapper(STRUCT):
            return False

        # success: replace each variable with a family of variables (one per field)

        # 'flatnames' is a list of (STRUCTTYPE, fieldname_in_that_struct) that
        # describes the list of variables that should replace the single
        # malloc'ed pointer variable that we are about to remove.  For primitive
        # or pointer fields, the new corresponding variable just stores the
        # actual value.  For substructures, if pointers to them are "equivalent"
        # to pointers to the parent structure (see equivalent_substruct()) then
        # they are just merged, and flatnames will also list the fields within
        # that substructure.  Other substructures are replaced by a single new
        # variable which is a pointer to a GcStruct-wrapper; each is malloc'ed
        # individually, in an exploded way.  (The next malloc removal pass will
        # get rid of them again, in the typical case.)
        self.flatnames = []
        self.flatconstants = {}
        self.needsubmallocs = []
        self.newvarstype = {}       # map {item-of-flatnames: concretetype}
        self.direct_fieldptr_key = {}
        self.flatten(STRUCT)
        assert len(self.direct_fieldptr_key) <= 1

        variables_by_block = {}
        for block, var in info.variables:
            vars = variables_by_block.setdefault(block, set())
            vars.add(var)

        count = [0]

        for block, vars in variables_by_block.items():

            # look for variables arriving from outside the block
            newvarsmap = None
            newinputargs = []
            inputvars = set()
            for var in block.inputargs:
                if var in vars:
                    inputvars.add(var)
                    if newvarsmap is None:
                        newvarsmap = {}
                        for key in self.flatnames:
                            newvar = Variable()
                            newvar.concretetype = self.newvarstype[key]
                            newvarsmap[key] = newvar
                            newinputargs.append(newvar)
                else:
                    newinputargs.append(var)
            block.inputargs[:] = newinputargs
            if inputvars:
                self.flowin(block, count, inputvars, newvarsmap)

            # look for variables created inside the block by a malloc
            vars_created_here = []
            for op in block.operations:
                if self.check_malloc(op) and op.result in vars:
                    vars_created_here.append(op.result)
            for var in vars_created_here:
                self.flowin(block, count, {var}, newvarsmap=None)

        return count[0]

    def remove_mallocs_once(self, graph):
        """Perform one iteration of malloc removal."""
        simplify.remove_identical_vars(graph)
        lifetimes = self.compute_lifetimes(graph)
        progress = 0
        for info in lifetimes:
            progress += self._try_inline_malloc(info)
        return progress

    def remove_simple_mallocs(self, graph):
        """Iteratively remove (inline) the mallocs that can be simplified away."""
        tot = 0
        while True:
            count = self.remove_mallocs_once(graph)
            if count:
                if self.verbose:
                    log.malloc('%d simple mallocs removed in %r' % (count, graph.name))
                else:
                    log.dot()
                tot += count
            else:
                break
        return tot


class LLTypeMallocRemover(BaseMallocRemover):

    IDENTITY_OPS = ("same_as", "cast_pointer")
    SUBSTRUCT_OPS = ("getsubstruct", "direct_fieldptr")
    MALLOC_OP = "malloc"
    FIELD_ACCESS =     dict.fromkeys(["getfield",
                                      "setfield",
                                      "ptr_iszero",
                                      "ptr_nonzero",
                                      "getarrayitem",
                                      "setarrayitem"])
    SUBSTRUCT_ACCESS = dict.fromkeys(["getsubstruct",
                                      "direct_fieldptr",
                                      "getarraysubstruct"])
    CHECK_ARRAY_INDEX = dict.fromkeys(["getarrayitem",
                                       "setarrayitem",
                                       "getarraysubstruct"])

    def check_malloc(self, op):
        if op.opname == 'malloc':
            flags = op.args[1].value
            if flags == {'flavor': 'gc'}:
                return True
        return False

    def recreate_malloc(self, c, v):
        return SpaceOperation(self.MALLOC_OP, [c,
                                               Constant({'flavor': 'gc'},
                                                        lltype.Void)],
                              v)

    def get_STRUCT(self, TYPE):
        STRUCT = TYPE.TO
        assert isinstance(STRUCT, lltype.GcStruct)
        return STRUCT

    def visit_substruct_op(self, node, union, op):
        S = op.args[0].concretetype.TO
        if self.equivalent_substruct(S, op.args[1].value):
            # assumed to be similar to a cast_pointer
            union(node, op.args[0], node, op.result)
            return True
        return False

    def do_substruct_access(self, op):
        S = op.args[0].concretetype.TO
        name = op.args[1].value
        if not isinstance(name, str):      # access by index
            name = 'item%d' % (name,)
        self.accessed_substructs.add((S, name))

    def inline_type(self, TYPE):
        return True

    def equivalent_substruct(self, S, fieldname):
        # we consider a pointer to a GcStruct S as equivalent to a
        # pointer to a substructure 'S.fieldname' if it's the first
        # inlined sub-GcStruct.  As an extension we also allow a pointer
        # to a GcStruct containing just one field to be equivalent to
        # a pointer to that field only (although a mere cast_pointer
        # would not allow casting).  This is needed to malloc-remove
        # the 'wrapper' GcStructs introduced by previous passes of
        # malloc removal.
        if not isinstance(S, lltype.GcStruct):
            return False
        if fieldname != S._names[0]:
            return False
        FIELDTYPE = S._flds[fieldname]
        if isinstance(FIELDTYPE, lltype.GcStruct):
            if FIELDTYPE._hints.get('union'):
                return False
            return True
        if len(S._names) == 1:
            return True
        return False

    def union_wrapper(self, S):
        # check if 'S' is a GcStruct containing a single inlined *union* Struct
        if not isinstance(S, lltype.GcStruct):
            return False
        assert not S._hints.get('union')    # not supported: "GcUnion"
        return (len(S._names) == 1 and
                isinstance(S._flds[S._names[0]], lltype.Struct) and
                S._flds[S._names[0]]._hints.get('union'))

    def RTTI_dtor(self, STRUCT):
        try:
            destr_ptr = lltype.getRuntimeTypeInfo(STRUCT)._obj.destructor_funcptr
            if destr_ptr:
                return True
        except (ValueError, AttributeError):
            pass
        return False

    def flatten(self, S):
        start = 0
        if S._names and self.equivalent_substruct(S, S._names[0]):
            SUBTYPE = S._flds[S._names[0]]
            if isinstance(SUBTYPE, lltype.Struct):
                self.flatten(SUBTYPE)
                start = 1
            else:
                ARRAY = lltype.FixedSizeArray(SUBTYPE, 1)
                self.direct_fieldptr_key[ARRAY, 'item0'] = S, S._names[0]
        for name in S._names[start:]:
            key = S, name
            FIELDTYPE = S._flds[name]
            if key in self.accessed_substructs:
                self.needsubmallocs.append(key)
                self.flatnames.append(key)
                self.newvarstype[key] = lltype.Ptr(lltype.GcStruct('wrapper',
                                                          ('data', FIELDTYPE)))
            elif not isinstance(FIELDTYPE, lltype.ContainerType):
                example = FIELDTYPE._defl()
                constant = Constant(example)
                constant.concretetype = FIELDTYPE
                self.flatconstants[key] = constant
                self.flatnames.append(key)
                self.newvarstype[key] = FIELDTYPE
            #else:
            #   the inlined substructure is never accessed, drop it

    def key_for_field_access(self, S, fldname):
        if isinstance(S, lltype.FixedSizeArray):
            if not isinstance(fldname, str):      # access by index
                fldname = 'item%d' % (fldname,)
            try:
                return self.direct_fieldptr_key[S, fldname]
            except KeyError:
                pass
        return S, fldname

    def handle_unreachable(self, v_result):
        from rpython.rtyper.lltypesystem.rstr import string_repr
        msg = "unreachable operation (from malloc.py)"
        ll_msg = string_repr.convert_const(msg)
        c_msg = Constant(ll_msg, lltype.typeOf(ll_msg))
        return SpaceOperation("debug_fatalerror", [c_msg], v_result)

    def flowin_op(self, op, vars, newvarsmap):
        if op.opname in ("getfield", "getarrayitem"):
            S = op.args[0].concretetype.TO
            fldname = op.args[1].value
            key = self.key_for_field_access(S, fldname)
            if key not in newvarsmap:
                newop = self.handle_unreachable(op.result)
            elif key in self.accessed_substructs:
                c_name = Constant('data', lltype.Void)
                newop = SpaceOperation("getfield",
                                       [newvarsmap[key], c_name],
                                       op.result)
            else:
                newop = SpaceOperation("same_as",
                                       [newvarsmap[key]],
                                       op.result)
            self.newops.append(newop)
        elif op.opname in ("setfield", "setarrayitem"):
            S = op.args[0].concretetype.TO
            fldname = op.args[1].value
            key = self.key_for_field_access(S, fldname)
            if key not in newvarsmap:
                newop = self.handle_unreachable(op.result)
                self.newops.append(newop)
            elif key in self.accessed_substructs:
                c_name = Constant('data', lltype.Void)
                newop = SpaceOperation("setfield",
                                 [newvarsmap[key], c_name, op.args[2]],
                                           op.result)
                self.newops.append(newop)
            else:
                newvarsmap[key] = op.args[2]
        elif op.opname in ("same_as", "cast_pointer"):
            vars.add(op.result)
            # Consider the two pointers (input and result) as
            # equivalent.  We can, and indeed must, use the same
            # flattened list of variables for both, as a "setfield"
            # via one pointer must be reflected in the other.
        elif op.opname in ("getsubstruct", "getarraysubstruct",
                           "direct_fieldptr"):
            S = op.args[0].concretetype.TO
            fldname = op.args[1].value
            if op.opname == "getarraysubstruct":
                fldname = 'item%d' % fldname
            equiv = self.equivalent_substruct(S, fldname)
            if equiv:
                # exactly like a cast_pointer
                assert op.result not in vars
                vars.add(op.result)
            else:
                # do it with a getsubstruct on the independently
                # malloc'ed GcStruct
                if op.opname == "direct_fieldptr":
                    opname = "direct_fieldptr"
                else:
                    opname = "getsubstruct"
                try:
                    v = newvarsmap[S, fldname]
                except KeyError:
                    newop = self.handle_unreachable(op.result)
                else:
                    cname = Constant('data', lltype.Void)
                    newop = SpaceOperation(opname,
                                           [v, cname],
                                           op.result)
                self.newops.append(newop)
        elif op.opname in ("ptr_iszero", "ptr_nonzero"):
            # we know the pointer is not NULL if it comes from
            # a successful malloc
            c = Constant(op.opname == "ptr_nonzero", lltype.Bool)
            newop = SpaceOperation('same_as', [c], op.result)
            self.newops.append(newop)
        else:
            raise AssertionError(op.opname)


def remove_simple_mallocs(graph, verbose=True):
    remover = LLTypeMallocRemover(verbose)
    return remover.remove_simple_mallocs(graph)


def remove_mallocs(translator, graphs=None):
    if graphs is None:
        graphs = translator.graphs
    tot = 0
    for graph in graphs:
        count = remove_simple_mallocs(graph, verbose=translator.config.translation.verbose)
        if count:
            # remove typical leftovers from malloc removal
            removenoops.remove_same_as(graph)
            simplify.eliminate_empty_blocks(graph)
            simplify.transform_dead_op_vars(graph, translator)
            tot += count
    log.malloc("removed %d simple mallocs in total" % tot)
    return tot

"""
RTyper: converts high-level operations into low-level operations in flow graphs.

The main class, with code to walk blocks and dispatch individual operations to
the care of the rtype_*() methods implemented in the other r* modules.  For
each high-level operation 'hop', the rtype_*() methods produce low-level
operations that are collected in the 'llops' list defined here.  When
necessary, conversions are inserted.

This logic borrows a bit from rpython.annotator.annrpython, without the
fixpoint computation part.
"""

import os

import py, math

from rpython.annotator import model as annmodel, unaryop, binaryop
from rpython.rtyper.llannotation import lltype_to_annotation
from rpython.flowspace.model import Variable, Constant, SpaceOperation
from rpython.rtyper.annlowlevel import (
        annotate_lowlevel_helper, LowLevelAnnotatorPolicy)
from rpython.rtyper.error import TyperError
from rpython.rtyper.exceptiondata import ExceptionData
from rpython.rtyper.lltypesystem.lltype import (Signed, Void, LowLevelType,
    ContainerType, typeOf, Primitive, getfunctionptr)
from rpython.rtyper.rmodel import Repr, inputconst
from rpython.rtyper import rclass
from rpython.rtyper.rclass import RootClassRepr
from rpython.tool.pairtype import pair
from rpython.translator.unsimplify import insert_empty_block
from rpython.translator.sandbox.rsandbox import make_sandbox_trampoline


class RTyperBackend(object):
    pass

class GenCBackend(RTyperBackend):
    pass
genc_backend = GenCBackend()

class LLInterpBackend(RTyperBackend):
    pass
llinterp_backend = LLInterpBackend()


class RPythonTyper(object):
    from rpython.rtyper.rmodel import log

    def __init__(self, annotator, backend=genc_backend):
        self.annotator = annotator
        self.backend = backend
        self.lowlevel_ann_policy = LowLevelAnnotatorPolicy(self)
        self.reprs = {}
        self._reprs_must_call_setup = []
        self._seen_reprs_must_call_setup = {}
        self._dict_traits = {}
        self.rootclass_repr = RootClassRepr(self)
        self.rootclass_repr.setup()
        self.instance_reprs = {}
        self.type_for_typeptr = {}
        self.pbc_reprs = {}
        self.classes_with_wrapper = {}
        self.wrapper_context = None # or add an extra arg to convertvar?
        self.classdef_to_pytypeobject = {}
        self.concrete_calltables = {}
        self.cache_dummy_values = {}
        self.lltype2vtable = {}
        # make the primitive_to_repr constant mapping
        self.primitive_to_repr = {}
        self.isinstance_helpers = {}
        self.exceptiondata = ExceptionData(self)
        self.custom_trace_funcs = []

        try:
            self.seed = int(os.getenv('RTYPERSEED'))
            s = 'Using %d as seed for block shuffling' % self.seed
            self.log.info(s)
        except:
            self.seed = 0

    def getconfig(self):
        return self.annotator.translator.config

    def getprimitiverepr(self, lltype):
        try:
            return self.primitive_to_repr[lltype]
        except KeyError:
            pass
        if isinstance(lltype, Primitive):
            repr = self.primitive_to_repr[lltype] = self.getrepr(lltype_to_annotation(lltype))
            return repr
        raise TyperError('There is no primitive repr for %r' % (lltype,))

    def add_wrapper(self, clsdef):
        # record that this class has a wrapper, and what the __init__ is
        cls = clsdef.classdesc.pyobj
        init = getattr(cls.__init__, 'im_func', None)
        self.classes_with_wrapper[cls] = init

    def set_wrapper_context(self, obj):
        # not nice, but we sometimes need to know which function we are wrapping
        self.wrapper_context = obj

    def add_pendingsetup(self, repr):
        assert isinstance(repr, Repr)
        if repr in self._seen_reprs_must_call_setup:
            #warning("ignoring already seen repr for setup: %r" %(repr,))
            return
        self._reprs_must_call_setup.append(repr)
        self._seen_reprs_must_call_setup[repr] = True

    def lltype_to_classdef_mapping(self):
        result = {}
        for (classdef, _), repr in self.instance_reprs.iteritems():
            result[repr.lowleveltype] = classdef
        return result

    def get_type_for_typeptr(self, typeptr):
        search = typeptr._obj
        try:
            return self.type_for_typeptr[search]
        except KeyError:
            # rehash the dictionary, and perform a linear scan
            # for the case of ll2ctypes typeptr
            found = None
            type_for_typeptr = {}
            for key, value in self.type_for_typeptr.items():
                type_for_typeptr[key] = value
                if key == search:
                    found = value
            self.type_for_typeptr = type_for_typeptr
            if found is None:
                raise KeyError(search)
            return found

    def set_type_for_typeptr(self, typeptr, TYPE):
        self.type_for_typeptr[typeptr._obj] = TYPE
        self.lltype2vtable[TYPE] = typeptr

    def get_real_typeptr_for_typeptr(self, typeptr):
        # perform a linear scan for the case of ll2ctypes typeptr
        search = typeptr._obj
        for key, value in self.type_for_typeptr.items():
            if key == search:
                return key._as_ptr()
        raise KeyError(search)

    def getrepr(self, s_obj):
        # s_objs are not hashable... try hard to find a unique key anyway
        key = s_obj.rtyper_makekey()
        assert key[0] is s_obj.__class__
        try:
            result = self.reprs[key]
        except KeyError:
            self.reprs[key] = None
            result = s_obj.rtyper_makerepr(self)
            assert not isinstance(result.lowleveltype, ContainerType), (
                "missing a Ptr in the type specification "
                "of %s:\n%r" % (s_obj, result.lowleveltype))
            self.reprs[key] = result
            self.add_pendingsetup(result)
        assert result is not None     # recursive getrepr()!
        return result

    def annotation(self, var):
        s_obj = self.annotator.annotation(var)
        return s_obj

    def binding(self, var):
        s_obj = self.annotator.binding(var)
        return s_obj

    def bindingrepr(self, var):
        return self.getrepr(self.binding(var))

    def specialize(self, dont_simplify_again=False):
        """Main entry point: specialize all annotated blocks of the program."""
        # specialize depends on annotator simplifications
        if not dont_simplify_again:
            self.annotator.simplify()
        self.exceptiondata.finish(self)

        # new blocks can be created as a result of specialize_block(), so
        # we need to be careful about the loop here.
        self.already_seen = {}
        self.specialize_more_blocks()
        self.exceptiondata.make_helpers(self)
        self.specialize_more_blocks()   # for the helpers just made

    def getannmixlevel(self):
        if self.annmixlevel is not None:
            return self.annmixlevel
        from rpython.rtyper.annlowlevel import MixLevelHelperAnnotator
        self.annmixlevel = MixLevelHelperAnnotator(self)
        return self.annmixlevel

    def specialize_more_blocks(self):
        if self.already_seen:
            newtext = ' more'
        else:
            newtext = ''
        blockcount = 0
        self.annmixlevel = None
        while True:
            # make sure all reprs so far have had their setup() called
            self.call_all_setups()

            # look for blocks not specialized yet
            pending = [block for block in self.annotator.annotated
                             if block not in self.already_seen]
            if not pending:
                break
            # shuffle blocks a bit
            if self.seed:
                import random
                r = random.Random(self.seed)
                r.shuffle(pending)

            previous_percentage = 0
            # specialize all blocks in the 'pending' list
            for block in pending:
                blockcount += 1
                self.specialize_block(block)
                self.already_seen[block] = True
                # progress bar
                n = len(self.already_seen)
                if n % 100 == 0:
                    total = len(self.annotator.annotated)
                    percentage = 100 * n // total
                    if percentage >= previous_percentage + 5:
                        previous_percentage = percentage
                        self.log.event('specializing: %d / %d blocks   (%d%%)' %
                                       (n, total, percentage))

        self.log.event('-=- specialized %d%s blocks -=-' % (
            blockcount, newtext))
        annmixlevel = self.annmixlevel
        del self.annmixlevel
        if annmixlevel is not None:
            annmixlevel.finish()

    def call_all_setups(self):
        # make sure all reprs so far have had their setup() called
        must_setup_more = []
        delayed = []
        while self._reprs_must_call_setup:
            r = self._reprs_must_call_setup.pop()
            if r.is_setup_delayed():
                delayed.append(r)
            else:
                r.setup()
                must_setup_more.append(r)
        for r in must_setup_more:
            r.setup_final()
        self._reprs_must_call_setup.extend(delayed)

    def setconcretetype(self, v):
        assert isinstance(v, Variable)
        v.concretetype = self.bindingrepr(v).lowleveltype

    def setup_block_entry(self, block):
        if block.operations == () and len(block.inputargs) == 2:
            # special case for exception blocks: force them to return an
            # exception type and value in a standardized format
            v1, v2 = block.inputargs
            v1.concretetype = self.exceptiondata.lltype_of_exception_type
            v2.concretetype = self.exceptiondata.lltype_of_exception_value
            return [self.exceptiondata.r_exception_type,
                    self.exceptiondata.r_exception_value]
        else:
            # normal path
            result = []
            for a in block.inputargs:
                r = self.bindingrepr(a)
                a.concretetype = r.lowleveltype
                result.append(r)
            return result

    def make_new_lloplist(self, block):
        return LowLevelOpList(self, block)

    def specialize_block(self, block):
        graph = self.annotator.annotated[block]
        if graph not in self.annotator.fixed_graphs:
            self.annotator.fixed_graphs[graph] = True
            # make sure that the return variables of all graphs
            # are concretetype'd
            self.setconcretetype(graph.getreturnvar())

        # give the best possible types to the input args
        try:
            self.setup_block_entry(block)
        except TyperError as e:
            self.gottypererror(e, block, "block-entry")
            raise


        # specialize all the operations, as far as possible
        if block.operations == ():   # return or except block
            return
        newops = self.make_new_lloplist(block)
        varmapping = {}
        for v in block.getvariables():
            varmapping[v] = v    # records existing Variables

        for hop in self.highlevelops(block, newops):
            try:
                hop.setup()  # this is called from here to catch TyperErrors...
                self.translate_hl_to_ll(hop, varmapping)
            except TyperError as e:
                self.gottypererror(e, block, hop.spaceop)
                raise

        block.operations[:] = newops
        block.renamevariables(varmapping)

        extrablock = None
        pos = newops.llop_raising_exceptions
        if (pos is not None and pos != len(newops) - 1):
            # this is for the case where the llop that raises the exceptions
            # is not the last one in the list.
            assert block.canraise
            noexclink = block.exits[0]
            assert noexclink.exitcase is None
            if pos == "removed":
                # the exception cannot actually occur at all.
                # This is set by calling exception_cannot_occur().
                # We just remove all exception links.
                block.exitswitch = None
                block.exits = block.exits[:1]
            else:
                # We have to split the block in two, with the exception-catching
                # exitswitch after the llop at 'pos', and the extra operations
                # in the new part of the block, corresponding to the
                # no-exception case.  See for example test_rlist.test_indexerror
                # or test_rpbc.test_multiple_ll_one_hl_op.
                assert 0 <= pos < len(newops) - 1
                extraops = block.operations[pos+1:]
                del block.operations[pos+1:]
                extrablock = insert_empty_block(noexclink, newops=extraops)

        if extrablock is None:
            self.insert_link_conversions(block)
        else:
            # skip the extrablock as a link target, its link doesn't need conversions
            # by construction, OTOH some of involved vars have no annotation
            # so proceeding with it would kill information
            self.insert_link_conversions(block, skip=1)
            # consider it as a link source instead
            self.insert_link_conversions(extrablock)

    def _convert_link(self, block, link):
        if link.exitcase is not None and link.exitcase != 'default':
            if isinstance(block.exitswitch, Variable):
                r_case = self.bindingrepr(block.exitswitch)
            else:
                assert block.canraise
                r_case = rclass.get_type_repr(self)
            link.llexitcase = r_case.convert_const(link.exitcase)
        else:
            link.llexitcase = None

        a = link.last_exception
        if isinstance(a, Variable):
            a.concretetype = self.exceptiondata.lltype_of_exception_type
        elif isinstance(a, Constant):
            link.last_exception = inputconst(
                self.exceptiondata.r_exception_type, a.value)

        a = link.last_exc_value
        if isinstance(a, Variable):
            a.concretetype = self.exceptiondata.lltype_of_exception_value
        elif isinstance(a, Constant):
            link.last_exc_value = inputconst(
                self.exceptiondata.r_exception_value, a.value)

    def insert_link_conversions(self, block, skip=0):
        # insert the needed conversions on the links
        can_insert_here = block.exitswitch is None and len(block.exits) == 1
        for link in block.exits[skip:]:
            self._convert_link(block, link)
            inputargs_reprs = self.setup_block_entry(link.target)
            newops = self.make_new_lloplist(block)
            newlinkargs = {}
            for i in range(len(link.args)):
                a1 = link.args[i]
                r_a2 = inputargs_reprs[i]
                if isinstance(a1, Constant):
                    link.args[i] = inputconst(r_a2, a1.value)
                    continue   # the Constant was typed, done
                if a1 is link.last_exception:
                    r_a1 = self.exceptiondata.r_exception_type
                elif a1 is link.last_exc_value:
                    r_a1 = self.exceptiondata.r_exception_value
                else:
                    r_a1 = self.bindingrepr(a1)
                if r_a1 == r_a2:
                    continue   # no conversion needed
                try:
                    new_a1 = newops.convertvar(a1, r_a1, r_a2)
                except TyperError as e:
                    self.gottypererror(e, block, link)
                    raise
                if new_a1 != a1:
                    newlinkargs[i] = new_a1

            if newops:
                if can_insert_here:
                    block.operations.extend(newops)
                else:
                    # cannot insert conversion operations around a single
                    # link, unless it is the only exit of this block.
                    # create a new block along the link...
                    newblock = insert_empty_block(link,
                    # ...and store the conversions there.
                                                  newops=newops)
                    link = newblock.exits[0]
            for i, new_a1 in newlinkargs.items():
                link.args[i] = new_a1

    def highlevelops(self, block, llops):
        # enumerate the HighLevelOps in a block.
        if block.operations:
            for op in block.operations[:-1]:
                yield HighLevelOp(self, op, [], llops)
            # look for exception links for the last operation
            if block.canraise:
                exclinks = block.exits[1:]
            else:
                exclinks = []
            yield HighLevelOp(self, block.operations[-1], exclinks, llops)

    def translate_hl_to_ll(self, hop, varmapping):
        #self.log.translating(hop.spaceop.opname, hop.args_s)
        resultvar = hop.dispatch()
        if hop.exceptionlinks and hop.llops.llop_raising_exceptions is None:
            raise TyperError("the graph catches %s, but the rtyper did not "
                             "take exceptions into account "
                             "(exception_is_here() not called)" % (
                [link.exitcase.__name__ for link in hop.exceptionlinks],))
        if resultvar is None:
            # no return value
            self.translate_no_return_value(hop)
        else:
            assert isinstance(resultvar, (Variable, Constant))
            op = hop.spaceop
            # for simplicity of the translate_meth, resultvar is usually not
            # op.result here.  We have to replace resultvar with op.result
            # in all generated operations.
            if hop.s_result.is_constant():
                if isinstance(resultvar, Constant) and \
                       isinstance(hop.r_result.lowleveltype, Primitive) and \
                       hop.r_result.lowleveltype is not Void:
                    # assert that they are equal, or both are 'nan'
                    assert resultvar.value == hop.s_result.const or (
                        math.isnan(resultvar.value) and
                        math.isnan(hop.s_result.const))

            resulttype = resultvar.concretetype
            op.result.concretetype = hop.r_result.lowleveltype
            if op.result.concretetype != resulttype:
                raise TyperError("inconsistent type for the result of '%s':\n"
                                 "annotator says %s,\n"
                                 "whose repr is %r\n"
                                 "but rtype_%s returned %r" % (
                    op.opname, hop.s_result,
                    hop.r_result, op.opname, resulttype))
            # figure out if the resultvar is a completely fresh Variable or not
            if (isinstance(resultvar, Variable) and
                resultvar.annotation is None and
                resultvar not in varmapping):
                # fresh Variable: rename it to the previously existing op.result
                varmapping[resultvar] = op.result
            elif resultvar is op.result:
                # special case: we got the previous op.result Variable again
                assert varmapping[resultvar] is resultvar
            else:
                # renaming unsafe.  Insert a 'same_as' operation...
                hop.llops.append(SpaceOperation('same_as', [resultvar],
                                                op.result))

    def translate_no_return_value(self, hop):
        op = hop.spaceop
        if hop.s_result != annmodel.s_ImpossibleValue:
            raise TyperError("the annotator doesn't agree that '%s' "
                             "has no return value" % op.opname)
        op.result.concretetype = Void

    def gottypererror(self, exc, block, position):
        """Record information about the location of a TyperError"""
        graph = self.annotator.annotated.get(block)
        exc.where = (graph, block, position)

    # __________ regular operations __________

    def _registeroperations(cls, unary_ops, binary_ops):
        d = {}
        # All unary operations
        for opname in unary_ops:
            fnname = 'translate_op_' + opname
            exec(py.code.compile("""
                def translate_op_%s(self, hop):
                    r_arg1 = hop.args_r[0]
                    return r_arg1.rtype_%s(hop)
                """ % (opname, opname)), globals(), d)
            setattr(cls, fnname, d[fnname])
        # All binary operations
        for opname in binary_ops:
            fnname = 'translate_op_' + opname
            exec(py.code.compile("""
                def translate_op_%s(self, hop):
                    r_arg1 = hop.args_r[0]
                    r_arg2 = hop.args_r[1]
                    return pair(r_arg1, r_arg2).rtype_%s(hop)
                """ % (opname, opname)), globals(), d)
            setattr(cls, fnname, d[fnname])
    _registeroperations = classmethod(_registeroperations)

    # this one is not in BINARY_OPERATIONS
    def translate_op_contains(self, hop):
        r_arg1 = hop.args_r[0]
        r_arg2 = hop.args_r[1]
        return pair(r_arg1, r_arg2).rtype_contains(hop)

    # __________ irregular operations __________

    def translate_op_newlist(self, hop):
        return rlist.rtype_newlist(hop)

    def translate_op_newdict(self, hop):
        return rdict.rtype_newdict(hop)

    def translate_op_alloc_and_set(self, hop):
        return rlist.rtype_alloc_and_set(hop)

    def translate_op_extend_with_str_slice(self, hop):
        r_arg1 = hop.args_r[0]
        r_arg2 = hop.args_r[3]
        return pair(r_arg1, r_arg2).rtype_extend_with_str_slice(hop)

    def translate_op_extend_with_char_count(self, hop):
        r_arg1 = hop.args_r[0]
        r_arg2 = hop.args_r[1]
        return pair(r_arg1, r_arg2).rtype_extend_with_char_count(hop)

    def translate_op_newtuple(self, hop):
        from rpython.rtyper.rtuple import rtype_newtuple
        return rtype_newtuple(hop)

    def translate_op_instantiate1(self, hop):
        if not isinstance(hop.s_result, annmodel.SomeInstance):
            raise TyperError("instantiate1 got s_result=%r" % (hop.s_result,))
        classdef = hop.s_result.classdef
        return rclass.rtype_new_instance(self, classdef, hop.llops)

    def default_translate_operation(self, hop):
        raise TyperError("unimplemented operation: '%s'" % hop.spaceop.opname)

    # __________ utilities __________

    def needs_wrapper(self, cls):
        return cls in self.classes_with_wrapper

    def get_wrapping_hint(self, clsdef):
        cls = clsdef.classdesc.pyobj
        return self.classes_with_wrapper[cls], self.wrapper_context

    def getcallable(self, graph):
        def getconcretetype(v):
            return self.bindingrepr(v).lowleveltype
        if self.annotator.translator.config.translation.sandbox:
            try:
                name = graph.func._sandbox_external_name
            except AttributeError:
                pass
            else:
                args_s = [v.annotation for v in graph.getargs()]
                s_result = graph.getreturnvar().annotation
                sandboxed = make_sandbox_trampoline(name, args_s, s_result)
                return self.getannmixlevel().delayedfunction(
                        sandboxed, args_s, s_result)

        return getfunctionptr(graph, getconcretetype)

    def annotate_helper(self, ll_function, argtypes):
        """Annotate the given low-level helper function and return its graph
        """
        args_s = []
        for s in argtypes:
            # assume 's' is a low-level type, unless it is already an annotation
            if not isinstance(s, annmodel.SomeObject):
                s = lltype_to_annotation(s)
            args_s.append(s)
        # hack for bound methods
        if hasattr(ll_function, 'im_func'):
            bk = self.annotator.bookkeeper
            args_s.insert(0, bk.immutablevalue(ll_function.im_self))
            ll_function = ll_function.im_func
        helper_graph = annotate_lowlevel_helper(self.annotator,
                                                ll_function, args_s,
                                                policy=self.lowlevel_ann_policy)
        return helper_graph

    def annotate_helper_fn(self, ll_function, argtypes):
        """Annotate the given low-level helper function
        and return it as a function pointer
        """
        graph = self.annotate_helper(ll_function, argtypes)
        return self.getcallable(graph)

# register operations from annotation model
RPythonTyper._registeroperations(unaryop.UNARY_OPERATIONS, binaryop.BINARY_OPERATIONS)

# ____________________________________________________________


class HighLevelOp(object):
    def __init__(self, rtyper, spaceop, exceptionlinks, llops):
        self.rtyper         = rtyper
        self.spaceop        = spaceop
        self.exceptionlinks = exceptionlinks
        self.llops          = llops

    def setup(self):
        rtyper = self.rtyper
        spaceop = self.spaceop
        self.args_v   = list(spaceop.args)
        self.args_s   = [rtyper.binding(a) for a in spaceop.args]
        self.s_result = rtyper.binding(spaceop.result)
        self.args_r   = [rtyper.getrepr(s_a) for s_a in self.args_s]
        self.r_result = rtyper.getrepr(self.s_result)
        rtyper.call_all_setups()  # compute ForwardReferences now

    @property
    def nb_args(self):
        return len(self.args_v)

    def copy(self):
        result = HighLevelOp(self.rtyper, self.spaceop,
                             self.exceptionlinks, self.llops)
        for key, value in self.__dict__.items():
            if type(value) is list:     # grunt
                value = value[:]
            setattr(result, key, value)
        return result

    def dispatch(self):
        rtyper = self.rtyper
        opname = self.spaceop.opname
        translate_meth = getattr(rtyper, 'translate_op_' + opname,
                                 rtyper.default_translate_operation)
        return translate_meth(self)

    def inputarg(self, converted_to, arg):
        """Returns the arg'th input argument of the current operation,
        as a Variable or Constant converted to the requested type.
        'converted_to' should be a Repr instance or a Primitive low-level
        type.
        """
        if not isinstance(converted_to, Repr):
            converted_to = self.rtyper.getprimitiverepr(converted_to)
        v = self.args_v[arg]
        if isinstance(v, Constant):
            return inputconst(converted_to, v.value)
        assert hasattr(v, 'concretetype')

        s_binding = self.args_s[arg]
        if s_binding.is_constant():
            return inputconst(converted_to, s_binding.const)

        r_binding = self.args_r[arg]
        return self.llops.convertvar(v, r_binding, converted_to)

    inputconst = staticmethod(inputconst)    # export via the HighLevelOp class

    def inputargs(self, *converted_to):
        if len(converted_to) != self.nb_args:
            raise TyperError("operation argument count mismatch:\n"
                             "'%s' has %d arguments, rtyper wants %d" % (
                self.spaceop.opname, self.nb_args, len(converted_to)))
        vars = []
        for i in range(len(converted_to)):
            vars.append(self.inputarg(converted_to[i], i))
        return vars

    def genop(self, opname, args_v, resulttype=None):
        return self.llops.genop(opname, args_v, resulttype)

    def gendirectcall(self, ll_function, *args_v):
        return self.llops.gendirectcall(ll_function, *args_v)

    def r_s_pop(self, index=-1):
        "Return and discard the argument with index position."
        self.args_v.pop(index)
        return self.args_r.pop(index), self.args_s.pop(index)

    def r_s_popfirstarg(self):
        "Return and discard the first argument."
        return self.r_s_pop(0)

    def v_s_insertfirstarg(self, v_newfirstarg, s_newfirstarg):
        r_newfirstarg = self.rtyper.getrepr(s_newfirstarg)
        self.args_v.insert(0, v_newfirstarg)
        self.args_r.insert(0, r_newfirstarg)
        self.args_s.insert(0, s_newfirstarg)

    def swap_fst_snd_args(self):
        self.args_v[0], self.args_v[1] = self.args_v[1], self.args_v[0]
        self.args_s[0], self.args_s[1] = self.args_s[1], self.args_s[0]
        self.args_r[0], self.args_r[1] = self.args_r[1], self.args_r[0]

    def has_implicit_exception(self, exc_cls):
        if self.llops.llop_raising_exceptions is not None:
            raise TyperError("already generated the llop that raises the "
                             "exception")
        if not self.exceptionlinks:
            return False  # don't record has_implicit_exception checks on
                          # high-level ops before the last one in the block
        if self.llops.implicit_exceptions_checked is None:
            self.llops.implicit_exceptions_checked = []
        result = False
        for link in self.exceptionlinks:
            if issubclass(exc_cls, link.exitcase):
                self.llops.implicit_exceptions_checked.append(link.exitcase)
                result = True
                # go on looping to add possibly more exceptions to the list
                # (e.g. Exception itself - see test_rlist.test_valueerror)
        return result

    def exception_is_here(self):
        self.llops._called_exception_is_here_or_cannot_occur = True
        if self.llops.llop_raising_exceptions is not None:
            raise TyperError("cannot catch an exception at more than one llop")
        if not self.exceptionlinks:
            return # ignored for high-level ops before the last one in the block
        if self.llops.implicit_exceptions_checked is not None:
            # sanity check: complain if an has_implicit_exception() check is
            # missing in the rtyper.
            for link in self.exceptionlinks:
                if link.exitcase not in self.llops.implicit_exceptions_checked:
                    raise TyperError("the graph catches %s, but the rtyper "
                                     "did not explicitely handle it" % (
                        link.exitcase.__name__,))
        self.llops.llop_raising_exceptions = len(self.llops)

    def exception_cannot_occur(self):
        self.llops._called_exception_is_here_or_cannot_occur = True
        if self.llops.llop_raising_exceptions is not None:
            raise TyperError("cannot catch an exception at more than one llop")
        if not self.exceptionlinks:
            return # ignored for high-level ops before the last one in the block
        self.llops.llop_raising_exceptions = "removed"

    def decompose_slice_args(self):
        # Select which kind of slicing is needed.  We support:
        #   * [start:]
        #   * [start:stop]
        #   * [:-1]
        s_start = self.args_s[1]
        s_stop = self.args_s[2]
        if (s_start.is_constant() and s_start.const in (None, 0) and
            s_stop.is_constant() and s_stop.const == -1):
            return "minusone", []
        if isinstance(s_start, annmodel.SomeInteger):
            if not s_start.nonneg:
                raise TyperError("slice start must be proved non-negative")
        if isinstance(s_stop, annmodel.SomeInteger):
            if not s_stop.nonneg:
                raise TyperError("slice stop must be proved non-negative")
        if s_start.is_constant() and s_start.const is None:
            v_start = inputconst(Signed, 0)
        else:
            v_start = self.inputarg(Signed, arg=1)
        if s_stop.is_constant() and s_stop.const is None:
            return "startonly", [v_start]
        else:
            v_stop = self.inputarg(Signed, arg=2)
            return "startstop", [v_start, v_stop]

# ____________________________________________________________

class LowLevelOpList(list):
    """A list with gen*() methods to build and append low-level
    operations to it.
    """
    # NB. the following two attributes are here instead of on HighLevelOp
    #     because we want them to be shared between a HighLevelOp and its
    #     copy()es.
    llop_raising_exceptions = None
    implicit_exceptions_checked = None

    def __init__(self, rtyper=None, originalblock=None):
        self.rtyper = rtyper
        self.originalblock = originalblock

    def getparentgraph(self):
        return self.rtyper.annotator.annotated[self.originalblock]

    def hasparentgraph(self):
        return self.originalblock is not None

    def record_extra_call(self, graph):
        if self.hasparentgraph():
            self.rtyper.annotator.translator.update_call_graph(
                caller_graph = self.getparentgraph(),
                callee_graph = graph,
                position_tag = object())

    def convertvar(self, orig_v, r_from, r_to):
        assert isinstance(orig_v, (Variable, Constant))
        if r_from != r_to:
            v = pair(r_from, r_to).convert_from_to(orig_v, self)
            if v is NotImplemented:
                raise TyperError("don't know how to convert from %r to %r" %
                                 (r_from, r_to))
            if v.concretetype != r_to.lowleveltype:
                raise TyperError("bug in conversion from %r to %r: "
                                 "returned a %r" % (r_from, r_to,
                                                    v.concretetype))
        else:
            v = orig_v
        return v

    def genop(self, opname, args_v, resulttype=None):
        try:
            for v in args_v:
                v.concretetype
        except AttributeError:
            raise AssertionError("wrong level!  you must call hop.inputargs()"
                                 " and pass its result to genop(),"
                                 " never hop.args_v directly.")
        vresult = Variable()
        self.append(SpaceOperation(opname, args_v, vresult))
        if resulttype is None:
            vresult.concretetype = Void
            return None
        else:
            if isinstance(resulttype, Repr):
                resulttype = resulttype.lowleveltype
            assert isinstance(resulttype, LowLevelType)
            vresult.concretetype = resulttype
            return vresult

    def gendirectcall(self, ll_function, *args_v):
        rtyper = self.rtyper
        args_s = []
        newargs_v = []
        with rtyper.annotator.using_policy(rtyper.lowlevel_ann_policy):
            for v in args_v:
                if v.concretetype is Void:
                    s_value = rtyper.annotation(v)
                    if s_value is None:
                        s_value = annmodel.s_None
                    if not s_value.is_constant():
                        raise TyperError("non-constant variable of type Void")
                    if not isinstance(s_value, (annmodel.SomePBC, annmodel.SomeNone)):
                        raise TyperError("non-PBC Void argument: %r", (s_value,))
                    args_s.append(s_value)
                else:
                    args_s.append(lltype_to_annotation(v.concretetype))
                newargs_v.append(v)

            self.rtyper.call_all_setups()  # compute ForwardReferences now

            # hack for bound methods
            if hasattr(ll_function, 'im_func'):
                bk = rtyper.annotator.bookkeeper
                args_s.insert(0, bk.immutablevalue(ll_function.im_self))
                newargs_v.insert(0, inputconst(Void, ll_function.im_self))
                ll_function = ll_function.im_func

        graph = annotate_lowlevel_helper(rtyper.annotator, ll_function, args_s,
                                         rtyper.lowlevel_ann_policy)
        self.record_extra_call(graph)

        # build the 'direct_call' operation
        f = self.rtyper.getcallable(graph)
        c = inputconst(typeOf(f), f)
        fobj = f._obj
        return self.genop('direct_call', [c]+newargs_v,
                          resulttype = typeOf(fobj).RESULT)

    def genconst(self, ll_value):
        return inputconst(typeOf(ll_value), ll_value)

    def genvoidconst(self, placeholder):
        return inputconst(Void, placeholder)

    def constTYPE(self, T):
        return T

# _______________________________________________________________________
# this has the side-effect of registering the unary and binary operations
# and the rtyper_chooserepr() methods
from rpython.rtyper import rint, rbool, rfloat, rnone
from rpython.rtyper import rrange
from rpython.rtyper import rstr, rdict, rlist, rbytearray
from rpython.rtyper import rbuiltin, rpbc
from rpython.rtyper import rptr
from rpython.rtyper import rweakref
from rpython.rtyper import raddress # memory addresses

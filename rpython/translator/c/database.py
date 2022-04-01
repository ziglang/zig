from collections import OrderedDict

from rpython.rtyper.lltypesystem.lltype import (Primitive, Ptr, typeOf,
    RuntimeTypeInfo, Struct, Array, FuncType, Void, ContainerType, OpaqueType,
    FixedSizeArray, Typedef)
from rpython.rtyper.lltypesystem import lltype, rffi
from rpython.rtyper.lltypesystem.llmemory import WeakRef, _WeakRefType, GCREF
from rpython.rtyper.lltypesystem.rffi import CConstant
from rpython.rtyper.lltypesystem import llgroup
from rpython.tool.sourcetools import valid_identifier
from rpython.translator.c.primitive import PrimitiveName, PrimitiveType
from rpython.translator.c.node import (
    StructDefNode, ArrayDefNode, FixedSizeArrayDefNode, BareBoneArrayDefNode,
    ContainerNodeFactory, ExtTypeOpaqueDefNode, FuncNode)
from rpython.translator.c.support import cdecl, CNameManager
from rpython.translator.c.support import log, barebonearray
from rpython.translator.c.extfunc import do_the_getting
from rpython.translator.c import gc
from rpython.tool.identity_dict import identity_dict


class NoCorrespondingNode(Exception):
    pass

# ____________________________________________________________

class LowLevelDatabase(object):
    gctransformer = None

    def __init__(self, translator=None, standalone=False,
                 gcpolicyclass=None,
                 gchooks=None,
                 exctransformer=None,
                 thread_enabled=False,
                 sandbox=False,
                 split_gc_address_space=False,
                 reverse_debugger=False):
        self.translator = translator
        self.standalone = standalone
        self.sandbox    = sandbox
        self.split_gc_address_space = split_gc_address_space
        self.reverse_debugger       = reverse_debugger
        if gcpolicyclass is None:
            gcpolicyclass = gc.RefcountingGcPolicy
        self.gcpolicy = gcpolicyclass(self, thread_enabled)
        self.exctransformer = exctransformer

        self.structdefnodes = {}
        self.pendingsetupnodes = []
        self.containernodes = {}
        self.containerlist = []
        self.idelayedfunctionnames = identity_dict()
        self.delayedfunctionptrs = []
        self.completedcontainers = 0
        self.containerstats = {}

        # late_initializations is for when the value you want to
        # assign to a constant object is something C doesn't think is
        # constant
        self.late_initializations = []
        self.namespace = CNameManager()

        if translator is not None:
            self.gctransformer = self.gcpolicy.gettransformer(translator, gchooks)
        self.completed = False

        self.instrument_ncounter = 0

    def gettypedefnode(self, T, varlength=None):
        if varlength is None:
            key = T
        else:
            key = T, varlength
        try:
            node = self.structdefnodes[key]
        except KeyError:
            if isinstance(T, Struct):
                if isinstance(T, FixedSizeArray):
                    node = FixedSizeArrayDefNode(self, T)
                else:
                    node = StructDefNode(self, T, varlength)
            elif isinstance(T, Array):
                if barebonearray(T):
                    node = BareBoneArrayDefNode(self, T, varlength)
                else:
                    node = ArrayDefNode(self, T, varlength)
            elif isinstance(T, OpaqueType) and T._hints.get("render_structure", False):
                node = ExtTypeOpaqueDefNode(self, T)
            elif T == WeakRef:
                REALT = self.gcpolicy.get_real_weakref_type()
                node = self.gettypedefnode(REALT)
            else:
                raise NoCorrespondingNode("don't know about %r" % (T,))
            self.structdefnodes[key] = node
            self.pendingsetupnodes.append(node)
        return node

    def gettype(self, T, varlength=None, who_asks=None, argnames=[]):
        if isinstance(T, Primitive) or T == GCREF:
            return PrimitiveType[T]
        elif isinstance(T, Typedef):
            return '%s @' % T.c_name
        elif isinstance(T, Ptr):
            if (isinstance(T.TO, OpaqueType) and
                T.TO._hints.get('c_pointer_typedef') is not None):
                return '%s @' % T.TO._hints['c_pointer_typedef']
            try:
                node = self.gettypedefnode(T.TO)
            except NoCorrespondingNode:
                pass
            else:
                if hasattr(node, 'getptrtype'):
                    return node.getptrtype()   # special-casing because of C
            typename = self.gettype(T.TO)   # who_asks not propagated
            return typename.replace('@', '*@')
        elif isinstance(T, (Struct, Array, _WeakRefType)):
            node = self.gettypedefnode(T, varlength=varlength)
            if who_asks is not None:
                who_asks.dependencies.add(node)
            return node.gettype()
        elif isinstance(T, FuncType):
            resulttype = self.gettype(T.RESULT)
            argtypes = []
            for i in range(len(T.ARGS)):
                if T.ARGS[i] is not Void:
                    argtype = self.gettype(T.ARGS[i])
                    try:
                        argname = argnames[i]
                    except IndexError:
                        argname = ''
                    argtypes.append(cdecl(argtype, argname))
            argtypes = ', '.join(argtypes) or 'void'
            return resulttype.replace('@', '(@)(%s)' % argtypes)
        elif isinstance(T, OpaqueType):
            if T == RuntimeTypeInfo:
                return  self.gcpolicy.rtti_type()
            elif T._hints.get("render_structure", False):
                node = self.gettypedefnode(T, varlength=varlength)
                if who_asks is not None:
                    who_asks.dependencies.add(node)
                return 'struct %s @' % node.name
            elif T._hints.get('external', None) == 'C':
                return '%s @' % T._hints['c_name']
            else:
                #raise Exception("don't know about opaque type %r" % (T,))
                return 'struct %s @' % (
                    valid_identifier('pypy_opaque_' + T.tag),)
        elif isinstance(T, llgroup.GroupType):
            return "/*don't use me*/ void @"
        else:
            raise Exception("don't know about type %r" % (T,))

    def getcontainernode(self, container, _dont_write_c_code=True, **buildkwds):
        try:
            node = self.containernodes[container]
        except KeyError:
            T = typeOf(container)
            if isinstance(T, (lltype.Array, lltype.Struct)):
                if hasattr(self.gctransformer, 'consider_constant'):
                    self.gctransformer.consider_constant(T, container)
            nodefactory = ContainerNodeFactory[T.__class__]
            node = nodefactory(self, T, container, **buildkwds)
            self.containernodes[container] = node
            # _dont_write_c_code should only be False for a hack in
            # weakrefnode_factory()
            if not _dont_write_c_code:
                return node
            kind = getattr(node, 'nodekind', '?')
            self.containerstats[kind] = self.containerstats.get(kind, 0) + 1
            self.containerlist.append(node)
            if self.completed:
                pass # we would like to fail here, but a few containers
                     # are found very late, e.g. _subarrays via addresses
                     # introduced by the GC transformer, or the type_info_table
        return node

    def get(self, obj, funcgen=None):
        if isinstance(obj, CConstant):
            return obj.c_name  # without further checks
        T = typeOf(obj)
        if isinstance(T, Primitive) or T == GCREF:
            return PrimitiveName[T](obj, self)
        elif isinstance(T, Ptr):
            if (isinstance(T.TO, OpaqueType) and
                T.TO._hints.get('c_pointer_typedef') is not None):
                if obj._obj is not None:
                    value = rffi.cast(rffi.SSIZE_T, obj)
                    return '((%s) %s)' % (cdecl(self.gettype(T), ''),
                                          self.get(value))
            if obj:   # test if the ptr is non-NULL
                try:
                    container = obj._obj
                except lltype.DelayedPointer:
                    # hack hack hack
                    name = obj._obj0
                    assert name.startswith('delayed!')
                    n = len('delayed!')
                    if len(name) == n:
                        raise
                    if isinstance(lltype.typeOf(obj).TO, lltype.FuncType):
                        if obj in self.idelayedfunctionnames:
                            return self.idelayedfunctionnames[obj][0]
                        funcname = name[n:]
                        funcname = self.namespace.uniquename('g_'+funcname)
                        self.idelayedfunctionnames[obj] = funcname, obj
                    else:
                        funcname = None      # can't use the name of a
                                             # delayed non-function ptr
                    self.delayedfunctionptrs.append(obj)
                    return funcname
                    # /hack hack hack
                else:
                    # hack hack hack
                    if obj in self.idelayedfunctionnames:
                        # this used to be a delayed function,
                        # make sure we use the same name
                        forcename = self.idelayedfunctionnames[obj][0]
                        node = self.getcontainernode(container,
                                                     forcename=forcename)
                        assert node.getptrname() == forcename
                        return forcename
                    # /hack hack hack

                if isinstance(container, int):
                    # special case for tagged odd-valued pointers
                    return '((%s) %d)' % (cdecl(self.gettype(T), ''),
                                          obj._obj)
                node = self.getcontainernode(container)
                if node._funccodegen_owner is None:
                    node._funccodegen_owner = funcgen
                return node.getptrname()
            else:
                return '((%s) NULL)' % (cdecl(self.gettype(T), ''), )
        else:
            raise Exception("don't know about %r" % (obj,))

    def complete(self, show_progress=True):
        assert not self.completed
        if self.translator and self.translator.rtyper:
            do_the_getting(self, self.translator.rtyper)
        def dump():
            lst = ['%s: %d' % keyvalue
                   for keyvalue in self.containerstats.items()]
            lst.sort()
            log.event('%8d nodes  [ %s ]' % (i, '  '.join(lst)))
        i = self.completedcontainers
        if show_progress:
            show_i = (i//1000 + 1) * 1000
        else:
            show_i = -1

        # The order of database completion is fragile with gc transformers.
        # Here is what occurs:
        #
        # 1. follow dependencies recursively from the entry point: data
        #    structures pointing to other structures or functions, and
        #    constants in functions pointing to other structures or functions.
        #    Because of the mixlevelannotator, this might find delayed
        #    (not-annotated-and-rtyped-yet) function pointers.  They are
        #    not followed at this point.  User finalizers (__del__) on the
        #    other hand are followed during this step too.
        #
        # 2. gctransformer.finish_helpers() - after this, all functions in
        #    the program have been rtyped.
        #
        # 3. follow new dependencies.  All previously delayed functions
        #    should have been resolved by 2 - they are gc helpers, like
        #    ll_finalize().  New FuncNodes are built for them.  No more
        #    FuncNodes can show up after this step.
        #
        # 4. gctransformer.finish_tables() - freeze the gc types table.
        #
        # 5. follow new dependencies (this should be only the gc type table,
        #    which contains only numbers and pointers to ll_finalizer
        #    functions seen in step 3).
        #
        # This is implemented by interleaving the follow-new-dependencies
        # steps with calls to the next 'finish' function from the following
        # list:
        finish_callbacks = []
        if self.gctransformer:
            finish_callbacks.append(('GC transformer: finished helpers',
                                     self.gctransformer.get_finish_helpers()))
            finish_callbacks.append(('GC transformer: finished tables',
                                     self.gctransformer.get_finish_tables()))

        def add_dependencies(newdependencies, parent=None):
            for value in newdependencies:
                #if isinstance(value, _uninitialized):
                #    continue
                if isinstance(value, lltype._uninitialized):
                    continue
                if isinstance(typeOf(value), ContainerType):
                    node = self.getcontainernode(value)
                    if parent and node._funccodegen_owner is not None:
                        node._funccodegen_owner = parent._funccodegen_owner
                else:
                    self.get(value, parent and parent._funccodegen_owner)

        while True:
            while True:
                while self.pendingsetupnodes:
                    lst = self.pendingsetupnodes
                    self.pendingsetupnodes = []
                    for nodedef in lst:
                        nodedef.setup()
                if i == len(self.containerlist):
                    break
                node = self.containerlist[i]
                add_dependencies(node.enum_dependencies(), node)
                i += 1
                self.completedcontainers = i
                if i == show_i:
                    dump()
                    show_i += 1000

            if self.delayedfunctionptrs:
                lst = self.delayedfunctionptrs
                self.delayedfunctionptrs = []
                progress = False
                for fnptr in lst:
                    try:
                        fnptr._obj
                    except lltype.DelayedPointer:   # still not resolved
                        self.delayedfunctionptrs.append(fnptr)
                    else:
                        self.get(fnptr)
                        progress = True
                if progress:
                    continue   # progress - follow all dependencies again

            if finish_callbacks:
                logmsg, finish = finish_callbacks.pop(0)
                if not hasattr(finish, 'next'):
                    newdependencies = finish()
                else:
                    # if 'finish' is a generator, consume the next element
                    # and put the generator again in the queue
                    try:
                        newdependencies = finish.next()
                        finish_callbacks.insert(0, (None, finish))
                    except StopIteration:
                        newdependencies = None
                if logmsg:
                    log.database(logmsg)
                if newdependencies:
                    add_dependencies(newdependencies)
                continue       # progress - follow all dependencies again

            break     # database is now complete

        assert not self.delayedfunctionptrs
        self.completed = True
        if self.gctransformer is not None:
            log.database("Inlining GC helpers and postprocessing")
            self.gctransformer.inline_helpers_and_postprocess(self.all_graphs())
        if show_progress:
            dump()
        log.database("Completed")

    def globalcontainers(self):
        for node in self.containerlist:
            if node.globalcontainer:
                yield node

    def get_lltype_of_exception_value(self):
        exceptiondata = self.translator.rtyper.exceptiondata
        return exceptiondata.lltype_of_exception_value

    def getstructdeflist(self):
        # return the StructDefNodes sorted according to dependencies
        result = []
        seen = set()
        def produce(node):
            if node not in seen:
                deps = list(node.dependencies)
                deps.sort(key=lambda x: x.name)
                for othernode in deps:
                    produce(othernode)
                result.append(node)
                seen.add(node)
        nodes = self.structdefnodes.values()
        nodes.sort(key=lambda x: x.name)
        for node in nodes:
            produce(node)
        return result

    def all_graphs(self):
        graphs = []
        for node in self.containerlist:
            if isinstance(node, FuncNode):
                for graph in node.graphs_to_patch():
                    graphs.append(graph)
        return graphs

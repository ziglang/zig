import sys
from rpython.flowspace.model import Constant
from rpython.rtyper.lltypesystem.lltype import (RttiStruct,
     RuntimeTypeInfo)
from rpython.translator.c.node import ContainerNode
from rpython.translator.c.support import cdecl
from rpython.translator.tool.cbuild import ExternalCompilationInfo

class BasicGcPolicy(object):

    def __init__(self, db, thread_enabled=False):
        self.db = db
        self.thread_enabled = thread_enabled

    def common_gcheader_definition(self, defnode):
        if defnode.db.gctransformer is not None:
            return defnode.db.gctransformer.HDR
        return None

    def struct_gcheader_definition(self, defnode):
        return self.common_gcheader_definition(defnode)

    def array_gcheader_definition(self, defnode):
        return self.common_gcheader_definition(defnode)

    def compilation_info(self):
        if not self.db:
            return ExternalCompilationInfo()

        gct = self.db.gctransformer
        return ExternalCompilationInfo(
            pre_include_bits=['/* using %s */' % (gct.__class__.__name__,),
                              '#define MALLOC_ZERO_FILLED %d' % (gct.malloc_zero_filled,),
                              ]
            )

    def need_no_typeptr(self):
        return False

    def gc_startup_code(self):
        return []

    def struct_setup(self, structdefnode, rtti):
        return None

    def array_setup(self, arraydefnode):
        return None

    def rtti_type(self):
        return ''

    def OP_GC_SET_MAX_HEAP_SIZE(self, funcgen, op):
        return ''

    def OP_GC_THREAD_PREPARE(self, funcgen, op):
        return ''

    def OP_GC_THREAD_RUN(self, funcgen, op):
        # The gc transformer leaves this operation in the graphs
        # in all cases except with framework+shadowstack.  In that
        # case the operation is removed because redundant with
        # rthread.get_or_make_ident().
        return 'RPY_THREADLOCALREF_ENSURE();'

    def OP_GC_THREAD_START(self, funcgen, op):
        return ''

    def OP_GC_THREAD_DIE(self, funcgen, op):
        # The gc transformer leaves this operation in the graphs
        # (but may insert a call to a gcrootfinder-specific
        # function just before).
        return 'RPython_ThreadLocals_ThreadDie();'

    def OP_GC_THREAD_BEFORE_FORK(self, funcgen, op):
        return '%s = NULL;' % funcgen.expr(op.result)

    def OP_GC_THREAD_AFTER_FORK(self, funcgen, op):
        return ''

    def OP_GC_WRITEBARRIER(self, funcgen, op):
        return ''

    def OP_GC_STACK_BOTTOM(self, funcgen, op):
        return ''

    def OP_GC_GCFLAG_EXTRA(self, funcgen, op):
        return '%s = 0;  /* gc_gcflag_extra%r */' % (
            funcgen.expr(op.result),
            op.args[0])


class RefcountingInfo:
    static_deallocator = None

class RefcountingGcPolicy(BasicGcPolicy):

    def gettransformer(self, translator, gchooks):
        from rpython.memory.gctransform import refcounting
        return refcounting.RefcountingGCTransformer(translator)

    # for structs

    def struct_setup(self, structdefnode, rtti):
        if rtti is not None:
            transformer = structdefnode.db.gctransformer
            fptr = transformer.static_deallocation_funcptr_for_type(
                structdefnode.STRUCT)
            structdefnode.gcinfo = RefcountingInfo()
            structdefnode.gcinfo.static_deallocator = structdefnode.db.get(fptr)

    # for arrays

    def array_setup(self, arraydefnode):
        pass

    # for rtti node

    def rtti_type(self):
        return 'void (@)(void *)'   # void dealloc_xx(struct xx *)

    def rtti_node_factory(self):
        return RefcountingRuntimeTypeInfo_OpaqueNode

    # zero malloc impl

    def OP_GC_CALL_RTTI_DESTRUCTOR(self, funcgen, op):
        args = [funcgen.expr(v) for v in op.args]
        line = '%s(%s);' % (args[0], ', '.join(args[1:]))
        return line

    def OP_GC_FREE(self, funcgen, op):
        args = [funcgen.expr(v) for v in op.args]
        return 'OP_FREE(%s);' % (args[0], )

    def OP_GC__COLLECT(self, funcgen, op):
        return ''

    def OP_GC__DISABLE_FINALIZERS(self, funcgen, op):
        return ''

    def OP_GC__ENABLE_FINALIZERS(self, funcgen, op):
        return ''


class RefcountingRuntimeTypeInfo_OpaqueNode(ContainerNode):
    nodekind = 'refcnt rtti'
    globalcontainer = True
    typename = 'void (@)(void *)'
    _funccodegen_owner = None

    def __init__(self, db, T, obj):
        assert T == RuntimeTypeInfo
        assert isinstance(obj.about, RttiStruct)
        self.db = db
        self.T = T
        self.obj = obj
        defnode = db.gettypedefnode(obj.about)
        self.implementationtypename = 'void (@)(void *)'
        self.name = defnode.gcinfo.static_deallocator

    def getptrname(self):
        return '((void (*)(void *)) %s)' % (self.name,)

    def enum_dependencies(self):
        return []

    def implementation(self):
        return []



class BoehmInfo:
    finalizer = None


class BoehmGcPolicy(BasicGcPolicy):

    def gettransformer(self, translator, gchooks):
        from rpython.memory.gctransform import boehm
        return boehm.BoehmGCTransformer(translator)

    def array_setup(self, arraydefnode):
        pass

    def struct_setup(self, structdefnode, rtti):
        pass

    def rtti_type(self):
        return BoehmGcRuntimeTypeInfo_OpaqueNode.typename

    def rtti_node_factory(self):
        return BoehmGcRuntimeTypeInfo_OpaqueNode

    def compilation_info(self):
        eci = BasicGcPolicy.compilation_info(self)

        from rpython.rtyper.tool.rffi_platform import configure_boehm
        eci = eci.merge(configure_boehm())

        pre_include_bits = []
        if sys.platform.startswith('linux'):
            pre_include_bits += ["#define _REENTRANT 1",
                                 "#define GC_LINUX_THREADS 1"]
        if sys.platform != "win32" and not sys.platform.startswith("openbsd"):
            # GC_REDIRECT_TO_LOCAL is not supported on Win32 by gc6.8
            pre_include_bits += ["#define GC_REDIRECT_TO_LOCAL 1"]

        hdr_flag = ''
        if not getattr(self.db.gctransformer, 'NO_HEADER', False):
            hdr_flag = '-DPYPY_BOEHM_WITH_HEADER'

        eci = eci.merge(ExternalCompilationInfo(
            pre_include_bits=pre_include_bits,
            # The following define is required by the thread module,
            # See module/thread/test/test_rthread.py
            compile_extra=['-DPYPY_USING_BOEHM_GC', hdr_flag],
            ))

        gct = self.db.gctransformer
        gct.finalizer_triggers = tuple(gct.finalizer_triggers)  # stop changing
        sourcelines = ['']
        for trig in gct.finalizer_triggers:
            sourcelines.append('RPY_EXTERN void %s(void);' % (
                self.db.get(trig),))
        sourcelines.append('')
        sourcelines.append('void (*boehm_fq_trigger[])(void) = {')
        for trig in gct.finalizer_triggers:
            sourcelines.append('\t%s,' % (self.db.get(trig),))
        sourcelines.append('\tNULL')
        sourcelines.append('};')
        sourcelines.append('struct boehm_fq_s *boehm_fq_queues[%d];' % (
            len(gct.finalizer_triggers) or 1,))
        sourcelines.append('')
        eci = eci.merge(ExternalCompilationInfo(
            separate_module_sources=['\n'.join(sourcelines)]))

        return eci

    def gc_startup_code(self):
        if sys.platform == 'win32':
            pass # yield 'assert(GC_all_interior_pointers == 0);'
        else:
            yield 'GC_all_interior_pointers = 0;'
        yield 'boehm_gc_startup_code();'

    def get_real_weakref_type(self):
        return self.db.gctransformer.WEAKLINK

    def convert_weakref_to(self, ptarget):
        return self.db.gctransformer.convert_weakref_to(ptarget)

    def OP_GC__COLLECT(self, funcgen, op):
        return 'GC_gcollect();'

    def OP_GC_SET_MAX_HEAP_SIZE(self, funcgen, op):
        nbytes = funcgen.expr(op.args[0])
        return 'GC_set_max_heap_size(%s);' % (nbytes,)

    def GC_KEEPALIVE(self, funcgen, v):
        return 'pypy_asm_keepalive(%s);' % funcgen.expr(v)

class BoehmGcRuntimeTypeInfo_OpaqueNode(ContainerNode):
    nodekind = 'boehm rtti'
    globalcontainer = True
    typename = 'char @'
    _funccodegen_owner = None

    def __init__(self, db, T, obj):
        assert T == RuntimeTypeInfo
        assert isinstance(obj.about, RttiStruct)
        self.db = db
        self.T = T
        self.obj = obj
        defnode = db.gettypedefnode(obj.about)
        self.implementationtypename = self.typename
        self.name = self.db.namespace.uniquename('g_rtti_v_'+ defnode.barename)

    def getptrname(self):
        return '(&%s)' % (self.name,)

    def enum_dependencies(self):
        return []

    def implementation(self):
        yield 'char %s  /* uninitialized */;' % self.name

class FrameworkGcRuntimeTypeInfo_OpaqueNode(BoehmGcRuntimeTypeInfo_OpaqueNode):
    nodekind = 'framework rtti'


# to get an idea how it looks like with no refcount/gc at all

class NoneGcPolicy(BoehmGcPolicy):

    gc_startup_code = RefcountingGcPolicy.gc_startup_code.im_func

    def compilation_info(self):
        eci = BasicGcPolicy.compilation_info(self)
        eci = eci.merge(ExternalCompilationInfo(
            post_include_bits=['#define PYPY_USING_NO_GC_AT_ALL'],
            ))
        return eci


class BasicFrameworkGcPolicy(BasicGcPolicy):

    def gettransformer(self, translator, gchooks):
        if hasattr(self, 'transformerclass'):    # for rpython/memory tests
            return self.transformerclass(translator, gchooks=gchooks)
        raise NotImplementedError

    def struct_setup(self, structdefnode, rtti):
        if rtti is not None and hasattr(rtti._obj, 'destructor_funcptr'):
            gctransf = self.db.gctransformer
            TYPE = structdefnode.STRUCT
            fptrs = gctransf.special_funcptr_for_type(TYPE)
            # make sure this is seen by the database early, i.e. before
            # finish_helpers() on the gctransformer
            destrptr = rtti._obj.destructor_funcptr
            self.db.get(destrptr)
            # the following, on the other hand, will only discover ll_finalizer
            # helpers.  The get() sees and records a delayed pointer.  It is
            # still important to see it so that it can be followed as soon as
            # the mixlevelannotator resolves it.
            for fptr in fptrs.values():
                self.db.get(fptr)

    def array_setup(self, arraydefnode):
        pass

    def rtti_type(self):
        return FrameworkGcRuntimeTypeInfo_OpaqueNode.typename

    def rtti_node_factory(self):
        return FrameworkGcRuntimeTypeInfo_OpaqueNode

    def gc_startup_code(self):
        fnptr = self.db.gctransformer.frameworkgc_setup_ptr.value
        yield '%s();' % (self.db.get(fnptr),)

    def get_real_weakref_type(self):
        from rpython.memory.gctypelayout import WEAKREF
        return WEAKREF

    def convert_weakref_to(self, ptarget):
        from rpython.memory.gctypelayout import convert_weakref_to
        return convert_weakref_to(ptarget)

    def OP_GC_RELOAD_POSSIBLY_MOVED(self, funcgen, op):
        if isinstance(op.args[1], Constant):
            return '/* %s */' % (op,)
        else:
            args = [funcgen.expr(v) for v in op.args]
            return '%s = %s; /* for moving GCs */' % (args[1], args[0])

    def need_no_typeptr(self):
        config = self.db.translator.config
        return config.translation.gcremovetypeptr

    def header_type(self, extra='*'):
        # Fish out the C name of the 'struct pypy_header0'
        HDR = self.db.gctransformer.HDR
        return self.db.gettype(HDR).replace('@', extra)

    def tid_fieldname(self, tid_field='tid'):
        # Fish out the C name of the tid field.
        HDR = self.db.gctransformer.HDR
        hdr_node = self.db.gettypedefnode(HDR)
        return hdr_node.c_struct_field_name(tid_field)

    def OP_GC_GETTYPEPTR_GROUP(self, funcgen, op):
        # expands to a number of steps, as per rpython/lltypesystem/opimpl.py,
        # all implemented by a single call to a C macro.
        [v_obj, c_grpptr, c_skipoffset, c_vtableinfo] = op.args
        tid_field = c_vtableinfo.value[2]
        typename = funcgen.db.gettype(op.result.concretetype)
        return (
        '%s = (%s)_OP_GET_NEXT_GROUP_MEMBER(%s, (pypy_halfword_t)%s->'
            '_gcheader.%s, %s);'
            % (funcgen.expr(op.result),
               cdecl(typename, ''),
               funcgen.expr(c_grpptr),
               funcgen.expr(v_obj),
               self.tid_fieldname(tid_field),
               funcgen.expr(c_skipoffset)))

    def OP_GC_WRITEBARRIER(self, funcgen, op):
        raise Exception("the FramewokGCTransformer should handle this")

    def OP_GC_GCFLAG_EXTRA(self, funcgen, op):
        subopnum = op.args[0].value
        if subopnum != 4:
            gcflag_extra = self.db.gctransformer.gcdata.gc.gcflag_extra
        else:
            gcflag_extra = self.db.gctransformer.gcdata.gc.gcflag_dummy
        #
        if gcflag_extra == 0:
            return BasicGcPolicy.OP_GC_GCFLAG_EXTRA(self, funcgen, op)
        if subopnum == 1:
            return '%s = 1;  /* has_gcflag_extra */' % (
                funcgen.expr(op.result),)
        hdrfield = '((%s)%s)->%s' % (self.header_type(),
                                     funcgen.expr(op.args[1]),
                                     self.tid_fieldname())
        parts = ['%s = (%s & %dL) != 0;' % (funcgen.expr(op.result),
                                            hdrfield,
                                            gcflag_extra)]
        if subopnum == 2:     # get_gcflag_extra
            parts.append('/* get_gcflag_extra */')
        elif subopnum == 3:     # toggle_gcflag_extra
            parts.insert(0, '%s ^= %dL;' % (hdrfield,
                                            gcflag_extra))
            parts.append('/* toggle_gcflag_extra */')
        elif subopnum == 4:     # get_gcflag_dummy
            parts.append('/* get_gcflag_dummy */')
        else:
            raise AssertionError(subopnum)
        return ' '.join(parts)

    def OP_GC_BIT(self, funcgen, op):
        # This is a two-arguments operation (x, y) where x is a
        # pointer and y is a constant power of two.  It returns 0 if
        # "(*(Signed*)x) & y == 0", and non-zero if it is "== y".
        #
        # On x86-64, emitting this is better than emitting a load
        # followed by an INT_AND for the case where y doesn't fit in
        # 32 bits.  I've seen situations where a register was wasted
        # to contain the constant 2**32 throughout a complete messy
        # function; the goal of this GC_BIT is to avoid that.
        #
        # Don't abuse, though.  If you need to check several bits in
        # sequence, then it's likely better to load the whole Signed
        # first; using GC_BIT would result in multiple accesses to
        # memory.
        #
        bitmask = op.args[1].value
        assert bitmask > 0 and (bitmask & (bitmask - 1)) == 0
        offset = 0
        while bitmask >= 0x100:
            offset += 1
            bitmask >>= 8
        if sys.byteorder == 'big':
            offset = 'sizeof(Signed)-%s' % (offset+1)
        return '%s = ((char *)%s)[%s] & %d;' % (funcgen.expr(op.result),
                                                funcgen.expr(op.args[0]),
                                                offset, bitmask)

class ShadowStackFrameworkGcPolicy(BasicFrameworkGcPolicy):

    def gettransformer(self, translator, gchooks):
        from rpython.memory.gctransform import shadowstack
        return shadowstack.ShadowStackFrameworkGCTransformer(translator, gchooks)

    def enter_roots_frame(self, funcgen, (c_gcdata, c_numcolors)):
        numcolors = c_numcolors.value
        # XXX hard-code the field name here
        gcpol_ss = '%s->gcd_inst_root_stack_top' % funcgen.expr(c_gcdata)
        #
        yield ('typedef struct { char %s; } pypy_ss_t;'
                   % ', '.join(['*s%d' % i for i in range(numcolors)]))
        funcgen.gcpol_ss = gcpol_ss

    def OP_GC_PUSH_ROOTS(self, funcgen, op):
        raise Exception("gc_push_roots should be removed by postprocess_graph")

    def OP_GC_POP_ROOTS(self, funcgen, op):
        raise Exception("gc_pop_roots should be removed by postprocess_graph")

    def OP_GC_ENTER_ROOTS_FRAME(self, funcgen, op):
        # avoid arithmatic on void*
        return '({0}) = (char*)({0}) + sizeof(pypy_ss_t);'.format(funcgen.gcpol_ss,)

    def OP_GC_LEAVE_ROOTS_FRAME(self, funcgen, op):
        # avoid arithmatic on void*
        return '({0}) = (char*)({0}) - sizeof(pypy_ss_t);'.format(funcgen.gcpol_ss,)

    def OP_GC_SAVE_ROOT(self, funcgen, op):
        num = op.args[0].value
        exprvalue = funcgen.expr(op.args[1])
        return '((pypy_ss_t *)%s)[-1].s%d = (char *)%s;' % (
            funcgen.gcpol_ss, num, exprvalue)

    def OP_GC_RESTORE_ROOT(self, funcgen, op):
        num = op.args[0].value
        exprvalue = funcgen.expr(op.args[1])
        typename = funcgen.db.gettype(op.args[1].concretetype)
        result = '%s = (%s)((pypy_ss_t *)%s)[-1].s%d;' % (
            exprvalue, cdecl(typename, ''), funcgen.gcpol_ss, num)
        if isinstance(op.args[1], Constant):
            return '/* %s */' % result
        else:
            return result


name_to_gcpolicy = {
    'boehm': BoehmGcPolicy,
    'ref': RefcountingGcPolicy,
    'none': NoneGcPolicy,
    'framework+shadowstack': ShadowStackFrameworkGcPolicy,
}



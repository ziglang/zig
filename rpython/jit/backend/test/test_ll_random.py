import py
from rpython.rtyper.lltypesystem import lltype, llmemory, rffi, rstr
from rpython.rtyper import rclass
from rpython.jit.backend.test import test_random
from rpython.jit.backend.test.test_random import getint, getref_base, getref
from rpython.jit.metainterp.resoperation import ResOperation, rop, optypes
from rpython.jit.metainterp.history import ConstInt, ConstPtr, getkind
from rpython.jit.metainterp.support import ptr2int
from rpython.jit.codewriter import heaptracker
from rpython.jit.codewriter.effectinfo import EffectInfo
from rpython.rtyper.annlowlevel import llhelper
from rpython.rlib.rarithmetic import intmask
from rpython.rtyper.llinterp import LLException

class LLtypeOperationBuilder(test_random.OperationBuilder):
    HAVE_SHORT_FIELDS = False

    def __init__(self, *args, **kw):
        test_random.OperationBuilder.__init__(self, *args, **kw)
        self.vtable_counter = 0
        # note: rstrs and runicodes contain either new local strings, or
        # constants.  In other words, all BoxPtrs here were created earlier
        # by the trace before, and so it should be kind of fine to mutate
        # them with strsetitem/unicodesetitem.
        self.rstrs = []
        self.runicodes = []
        self.structure_types = []
        self.structure_types_and_vtables = []

    def fork(self, cpu, loop, vars):
        fork = test_random.OperationBuilder.fork(self, cpu, loop, vars)
        fork.structure_types = self.structure_types
        fork.structure_types_and_vtables = self.structure_types_and_vtables
        return fork

    def _choose_ptr_vars(self, from_, type, array_of_structs):
        ptrvars = []
        for i in range(len(from_)):
            v, S = from_[i][:2]
            if not isinstance(S, type):
                continue
            if ((isinstance(S, lltype.Array) and
                 isinstance(S.OF, lltype.Struct)) == array_of_structs):
                ptrvars.append((v, S))
        return ptrvars

    def get_structptr_var(self, r, must_have_vtable=False, type=lltype.Struct,
                          array_of_structs=False):
        while True:
            ptrvars = self._choose_ptr_vars(self.ptrvars, type,
                                            array_of_structs)
            if ptrvars and r.random() < 0.8:
                v, S = r.choice(ptrvars)
            else:
                prebuilt_ptr_consts = self._choose_ptr_vars(
                    self.prebuilt_ptr_consts, type, array_of_structs)
                if prebuilt_ptr_consts and r.random() < 0.7:
                    v, S = r.choice(prebuilt_ptr_consts)
                else:
                    if type is lltype.Struct:
                        # create a new constant structure
                        must_have_vtable = must_have_vtable or r.random() < 0.5
                        p = self.get_random_structure(r,
                                                has_vtable=must_have_vtable)
                    else:
                        # create a new constant array
                        p = self.get_random_array(r,
                                    must_be_array_of_structs=array_of_structs)
                    S = lltype.typeOf(p).TO
                    v = ConstPtr(lltype.cast_opaque_ptr(llmemory.GCREF, p))
                    self.prebuilt_ptr_consts.append((v, S,
                                                     self.field_values(p)))
            if not (must_have_vtable and S._names[0] != 'parent'):
                break
        return v, S

    def get_arrayptr_var(self, r):
        return self.get_structptr_var(r, type=lltype.Array)

    def get_random_primitive_type(self, r):
        rval = r.random()
        if rval < 0.25:
            TYPE = lltype.Signed
        elif rval < 0.5:
            TYPE = lltype.Char
        elif rval < 0.75:
            TYPE = rffi.UCHAR
        else:
            TYPE = rffi.SHORT
            if not self.HAVE_SHORT_FIELDS:
                TYPE = lltype.Signed
        return TYPE

    def get_random_structure_type(self, r, with_vtable=None, cache=True,
                                  type=lltype.GcStruct):
        if cache and self.structure_types and r.random() < 0.5:
            return r.choice(self.structure_types)
        fields = []
        kwds = {}
        if with_vtable:
            fields.append(('parent', rclass.OBJECT))
            kwds['hints'] = {'vtable': with_vtable._obj}
        for i in range(r.randrange(1, 5)):
            if r.random() < 0.1:
                kind = 'r'
                TYPE = llmemory.GCREF
            else:
                kind = 'i'
                TYPE = self.get_random_primitive_type(r)
            fields.append(('%s%d' % (kind, i), TYPE))
        S = type('S%d' % self.counter, *fields, **kwds)
        self.counter += 1
        if cache:
            self.structure_types.append(S)
        return S

    def get_random_structure_type_and_vtable(self, r):
        if self.structure_types_and_vtables and r.random() < 0.5:
            return r.choice(self.structure_types_and_vtables)
        vtable = lltype.malloc(rclass.OBJECT_VTABLE, immortal=True)
        vtable.subclassrange_min = self.vtable_counter
        vtable.subclassrange_max = self.vtable_counter
        self.vtable_counter += 1
        S = self.get_random_structure_type(r, with_vtable=vtable, cache=False)
        name = S._name
        heaptracker.set_testing_vtable_for_gcstruct(S, vtable, name)
        self.structure_types_and_vtables.append((S, vtable))
        #
        return S, vtable

    def get_random_structure(self, r, has_vtable=False):
        if has_vtable:
            S, vtable = self.get_random_structure_type_and_vtable(r)
            p = lltype.malloc(S)
            p.parent.typeptr = vtable
        else:
            S = self.get_random_structure_type(r)
            p = lltype.malloc(S)
        for fieldname in lltype.typeOf(p).TO._names:
            if fieldname != 'parent':
                TYPE = getattr(S, fieldname)
                setattr(p, fieldname, rffi.cast(TYPE, r.random_integer()))
        return p

    def get_random_array_type(self, r, can_be_array_of_struct=False,
                              must_be_array_of_structs=False):
        if ((can_be_array_of_struct and r.random() < 0.1) or
            must_be_array_of_structs):
            TYPE = self.get_random_structure_type(r, cache=False,
                                                  type=lltype.Struct)
        else:
            TYPE = self.get_random_primitive_type(r)
        return lltype.GcArray(TYPE)

    def get_random_array(self, r, must_be_array_of_structs=False):
        A = self.get_random_array_type(r,
                           must_be_array_of_structs=must_be_array_of_structs)
        length = (r.random_integer() // 15) % 300  # length: between 0 and 299
                                                   # likely to be small
        p = lltype.malloc(A, length)
        if isinstance(A.OF, lltype.Primitive):
            for i in range(length):
                p[i] = rffi.cast(A.OF, r.random_integer())
        else:
            for i in range(length):
                for fname, TP in A.OF._flds.iteritems():
                    setattr(p[i], fname, rffi.cast(TP, r.random_integer()))
        return p

    def get_index(self, length, r):
        if length == 0:
            raise test_random.CannotProduceOperation
        v_index = r.choice(self.intvars)
        if not (0 <= getint(v_index) < length):
            v_index = ConstInt(r.random_integer() % length)
        return v_index

    def field_values(self, p):
        dic = {}
        S = lltype.typeOf(p).TO
        if isinstance(S, lltype.Struct):
            for fieldname in S._names:
                if fieldname != 'parent':
                    dic[fieldname] = getattr(p, fieldname)
        else:
            assert isinstance(S, lltype.Array)
            if isinstance(S.OF, lltype.Struct):
                for i in range(len(p)):
                    item = p[i]
                    s1 = {}
                    for fieldname in S.OF._names:
                        s1[fieldname] = getattr(item, fieldname)
                    dic[i] = s1
            else:
                for i in range(len(p)):
                    dic[i] = p[i]
        return dic

    def print_loop_prebuilt(self, names, writevar, s):
        written = {}
        for v, S, fields in self.prebuilt_ptr_consts:
            if S not in written:
                print >>s, '    %s = lltype.GcStruct(%r,' % (S._name, S._name)
                for name in S._names:
                    if name == 'parent':
                        print >>s, "              ('parent', rclass.OBJECT),"
                    else:
                        print >>s, '              (%r, lltype.Signed),'%(name,)
                print >>s, '              )'
                if S._names[0] == 'parent':
                    print >>s, '    %s_vtable = lltype.malloc(rclass.OBJECT_VTABLE, immortal=True)' % (S._name,)
                written[S] = True
            print >>s, '    p = lltype.malloc(%s)' % (S._name,)
            if S._names[0] == 'parent':
                print >>s, '    p.parent.typeptr = %s_vtable' % (S._name,)
            for name, value in fields.items():
                print >>s, '    p.%s = %d' % (name, value)
            writevar(v, 'preb', 'lltype.cast_opaque_ptr(llmemory.GCREF, p)')

# ____________________________________________________________

class GuardClassOperation(test_random.GuardOperation):
    def gen_guard(self, builder, r):
        ptrvars = [(v, S) for (v, S) in builder.ptrvars
                          if isinstance(S, lltype.Struct) and
                             S._names[0] == 'parent']
        if not ptrvars:
            raise test_random.CannotProduceOperation
        v, S = r.choice(ptrvars)
        if r.random() < 0.3:
            v2, S2 = v, S
        else:
            v2, S2 = builder.get_structptr_var(r, must_have_vtable=True)
        vtable = S._hints['vtable']._as_ptr()
        vtable2 = S2._hints['vtable']._as_ptr()
        c_vtable2 = ConstInt(ptr2int(vtable2))
        op = ResOperation(self.opnum, [v, c_vtable2], None)
        return op, (vtable == vtable2)

class GuardNonNullClassOperation(GuardClassOperation):
    def gen_guard(self, builder, r):
        if r.random() < 0.5:
            return GuardClassOperation.gen_guard(self, builder, r)
        else:
            NULL = lltype.nullptr(llmemory.GCREF.TO)
            op = ResOperation(rop.SAME_AS_R, [ConstPtr(NULL)])
            builder.loop.operations.append(op)
            v2, S2 = builder.get_structptr_var(r, must_have_vtable=True)
            vtable2 = S2._hints['vtable']._as_ptr()
            c_vtable2 = ConstInt(ptr2int(vtable2))
            op = ResOperation(self.opnum, [op, c_vtable2], None)
            return op, False

class ZeroPtrFieldOperation(test_random.AbstractOperation):
    def field_descr(self, builder, r):
        if getattr(builder.cpu, 'is_llgraph', False):
            raise test_random.CannotProduceOperation
        v, S = builder.get_structptr_var(r, )
        names = S._names
        if names[0] == 'parent':
            names = names[1:]
        choice = []
        for name in names:
            FIELD = getattr(S, name)
            if FIELD is lltype.Signed:  # xxx should be a gc ptr, but works too
                choice.append(name)
        if not choice:
            raise test_random.CannotProduceOperation
        name = r.choice(choice)
        descr = builder.cpu.fielddescrof(S, name)
        return v, descr.offset

    def produce_into(self, builder, r):
        v, offset = self.field_descr(builder, r)
        builder.do(self.opnum, [v, ConstInt(offset)], None)

class GetFieldOperation(test_random.AbstractOperation):
    def field_descr(self, builder, r):
        v, S = builder.get_structptr_var(r, )
        names = S._names
        if names[0] == 'parent':
            names = names[1:]
        choice = []
        kind = optypes[self.opnum]
        for name in names:
            FIELD = getattr(S, name)
            if not isinstance(FIELD, lltype.Ptr):
                if kind == 'n' or getkind(FIELD)[0] == kind:
                    choice.append(name)
        if not choice:
            raise test_random.CannotProduceOperation
        name = r.choice(choice)
        descr = builder.cpu.fielddescrof(S, name)
        descr._random_info = 'cpu.fielddescrof(..., %r)' % (name,)
        descr._random_type = S
        TYPE = getattr(S, name)
        return v, descr, TYPE

    def produce_into(self, builder, r):
        while True:
            try:
                v, descr, _ = self.field_descr(builder, r)
                self.put(builder, [v], descr)
            except lltype.UninitializedMemoryAccess:
                continue
            break

class GetInteriorFieldOperation(test_random.AbstractOperation):
    def field_descr(self, builder, r):
        v, A = builder.get_structptr_var(r, type=lltype.Array,
                                         array_of_structs=True)
        array = getref(lltype.Ptr(A), v)
        v_index = builder.get_index(len(array), r)
        choice = []
        for name in A.OF._names:
            FIELD = getattr(A.OF, name)
            if not isinstance(FIELD, lltype.Ptr):
                choice.append(name)
        if not choice:
            raise test_random.CannotProduceOperation
        name = r.choice(choice)
        descr = builder.cpu.interiorfielddescrof(A, name)
        descr._random_info = 'cpu.interiorfielddescrof(..., %r)' % (name,)
        descr._random_type = A
        TYPE = getattr(A.OF, name)
        return v, v_index, descr, TYPE

    def produce_into(self, builder, r):
        while True:
            try:
                v, v_index, descr, _ = self.field_descr(builder, r)
                self.put(builder, [v, v_index], descr)
            except lltype.UninitializedMemoryAccess:
                continue
            break

class SetFieldOperation(GetFieldOperation):
    def produce_into(self, builder, r):
        v, descr, TYPE = self.field_descr(builder, r)
        while True:
            if r.random() < 0.3:
                w = ConstInt(r.random_integer())
            else:
                w = r.choice(builder.intvars)
            value = getint(w)
            if rffi.cast(lltype.Signed, rffi.cast(TYPE, value)) == value:
                break
        builder.do(self.opnum, [v, w], descr)

class SetInteriorFieldOperation(GetInteriorFieldOperation):
    def produce_into(self, builder, r):
        v, v_index, descr, TYPE = self.field_descr(builder, r)
        while True:
            if r.random() < 0.3:
                w = ConstInt(r.random_integer())
            else:
                w = r.choice(builder.intvars)
            value = getint(w)
            if rffi.cast(lltype.Signed, rffi.cast(TYPE, value)) == value:
                break
        builder.do(self.opnum, [v, v_index, w], descr)

class NewOperation(test_random.AbstractOperation):
    def size_descr(self, builder, S, *vtable):
        descr = builder.cpu.sizeof(S, *vtable)
        descr._random_info = 'cpu.sizeof(...)'
        descr._random_type = S
        return descr

    def produce_into(self, builder, r):
        if self.opnum == rop.NEW_WITH_VTABLE:
            S, vtable = builder.get_random_structure_type_and_vtable(r)
            descr = self.size_descr(builder, S, vtable)
        else:
            S = builder.get_random_structure_type(r)
            descr = self.size_descr(builder, S)
        v_ptr = builder.do(self.opnum, [], descr)
        builder.ptrvars.append((v_ptr, S))

class ArrayOperation(test_random.AbstractOperation):
    def array_descr(self, builder, A):
        descr = builder.cpu.arraydescrof(A)
        descr._random_info = 'cpu.arraydescrof(...)'
        descr._random_type = A
        return descr

class GetArrayItemOperation(ArrayOperation):
    def field_descr(self, builder, r):
        v, A = builder.get_arrayptr_var(r)
        array = getref(lltype.Ptr(A), v)
        v_index = builder.get_index(len(array), r)
        descr = self.array_descr(builder, A)
        return v, A, v_index, descr

    def produce_into(self, builder, r):
        while True:
            try:
                v, _, v_index, descr = self.field_descr(builder, r)
                self.put(builder, [v, v_index], descr)
            except lltype.UninitializedMemoryAccess:
                continue
            break

class SetArrayItemOperation(GetArrayItemOperation):
    def produce_into(self, builder, r):
        v, A, v_index, descr = self.field_descr(builder, r)
        while True:
            if r.random() < 0.3:
                w = ConstInt(r.random_integer())
            else:
                w = r.choice(builder.intvars)
            value = getint(w)
            if rffi.cast(lltype.Signed, rffi.cast(A.OF, value)) == value:
                break
        builder.do(self.opnum, [v, v_index, w], descr)

class NewArrayOperation(ArrayOperation):
    def produce_into(self, builder, r):
        A = builder.get_random_array_type(r, can_be_array_of_struct=True)
        v_size = builder.get_index(300, r)
        v_ptr = builder.do(self.opnum, [v_size], self.array_descr(builder, A))
        builder.ptrvars.append((v_ptr, A))

class ArrayLenOperation(ArrayOperation):
    def produce_into(self, builder, r):
        v, A = builder.get_arrayptr_var(r)
        descr = self.array_descr(builder, A)
        self.put(builder, [v], descr)

class _UnicodeOperation:
    builder_cache = "runicodes"
    struct = rstr.UNICODE
    ptr = lltype.Ptr(struct)
    alloc = staticmethod(rstr.mallocunicode)
    # XXX This should really be runicode.MAXUNICODE, but then
    # lltype.cast_primitive complains.
    max = py.std.sys.maxunicode
    primitive = lltype.UniChar
    set_char = rop.UNICODESETITEM

class _StrOperation:
    builder_cache = "rstrs"
    struct = rstr.STR
    ptr = lltype.Ptr(struct)
    alloc = staticmethod(rstr.mallocstr)
    max = 255
    primitive = lltype.Char
    set_char = rop.STRSETITEM

class NewSeqOperation(test_random.AbstractOperation):
    def produce_into(self, builder, r):
        v_length = builder.get_index(10, r)
        v_ptr = builder.do(self.opnum, [v_length])
        getattr(builder, self.builder_cache).append(v_ptr)
        # Initialize the string. Is there a better way to do this?
        for i in range(getint(v_length)):
            v_index = ConstInt(i)
            v_char = ConstInt(r.random_integer() % self.max)
            builder.do(self.set_char, [v_ptr, v_index, v_char])

class NewStrOperation(NewSeqOperation, _StrOperation):
    pass

class NewUnicodeOperation(NewSeqOperation, _UnicodeOperation):
    pass

class AbstractStringOperation(test_random.AbstractOperation):
    def get_string(self, builder, r):
        current = getattr(builder, self.builder_cache)
        if current and r.random() < .8:
            v_string = r.choice(current)
            string = getref(self.ptr, v_string)
        else:
            string = self.alloc(getint(builder.get_index(500, r)))
            v_string = ConstPtr(lltype.cast_opaque_ptr(llmemory.GCREF, string))
            current.append(v_string)
        for i in range(len(string.chars)):
            char = r.random_integer() % self.max
            string.chars[i] = lltype.cast_primitive(self.primitive, char)
        return v_string

class AbstractGetItemOperation(AbstractStringOperation):
    def produce_into(self, builder, r):
        v_string = self.get_string(builder, r)
        v_index = builder.get_index(len(getref(self.ptr, v_string).chars), r)
        builder.do(self.opnum, [v_string, v_index])

class AbstractSetItemOperation(AbstractStringOperation):
    def produce_into(self, builder, r):
        v_string = self.get_string(builder, r)
        if isinstance(v_string, ConstPtr):
            raise test_random.CannotProduceOperation  # setitem(Const, ...)
        v_index = builder.get_index(len(getref(self.ptr, v_string).chars), r)
        v_target = ConstInt(r.random_integer() % self.max)
        builder.do(self.opnum, [v_string, v_index, v_target])

class AbstractStringLenOperation(AbstractStringOperation):
    def produce_into(self, builder, r):
        v_string = self.get_string(builder, r)
        builder.do(self.opnum, [v_string])

class AbstractCopyContentOperation(AbstractStringOperation):
    def produce_into(self, builder, r):
        v_srcstring = self.get_string(builder, r)
        v_dststring = self.get_string(builder, r)
        src = getref(self.ptr, v_srcstring)
        dst = getref(self.ptr, v_dststring)
        if src == dst:                                # because it's not a
            raise test_random.CannotProduceOperation  # memmove(), but memcpy()
        srclen = len(src.chars)
        dstlen = len(dst.chars)
        v_length = builder.get_index(min(srclen, dstlen), r)
        v_srcstart = builder.get_index(srclen - getint(v_length) + 1, r)
        v_dststart = builder.get_index(dstlen - getint(v_length) + 1, r)
        builder.do(self.opnum, [v_srcstring, v_dststring,
                                v_srcstart, v_dststart, v_length])

class StrGetItemOperation(AbstractGetItemOperation, _StrOperation):
    pass

class UnicodeGetItemOperation(AbstractGetItemOperation, _UnicodeOperation):
    pass

class StrSetItemOperation(AbstractSetItemOperation, _StrOperation):
    pass

class UnicodeSetItemOperation(AbstractSetItemOperation, _UnicodeOperation):
    pass

class StrLenOperation(AbstractStringLenOperation, _StrOperation):
    pass

class UnicodeLenOperation(AbstractStringLenOperation, _UnicodeOperation):
    pass

class CopyStrContentOperation(AbstractCopyContentOperation, _StrOperation):
    pass

class CopyUnicodeContentOperation(AbstractCopyContentOperation,
                                  _UnicodeOperation):
    pass


# there are five options in total:
# 1. non raising call and guard_no_exception
# 2. raising call and guard_exception
# 3. raising call and wrong guard_exception
# 4. raising call and guard_no_exception
# 5. non raising call and guard_exception
# (6. test of a cond_call, always non-raising and guard_no_exception)

class BaseCallOperation(test_random.AbstractOperation):
    def non_raising_func_code(self, builder, r):
        subset = builder.subset_of_intvars(r)
        funcargs = ", ".join(['arg_%d' % i for i in range(len(subset))])
        sum = "intmask(%s)" % " + ".join(
            ['arg_%d' % i for i in range(len(subset))] + ['42'])
        if self.opnum == rop.CALL_I:
            result = 'sum'
        elif self.opnum == rop.CALL_F:
            result = 'float(sum)'
        elif self.opnum == rop.CALL_N:
            result = ''
        else:
            raise AssertionError(self.opnum)
        code = py.code.Source("""
        def f(%s):
            sum = %s
            return %s
        """ % (funcargs, sum, result)).compile()
        d = {'intmask': intmask}
        exec(code, d)
        return subset, d['f']

    def raising_func_code(self, builder, r):
        subset = builder.subset_of_intvars(r)
        funcargs = ", ".join(['arg_%d' % i for i in range(len(subset))])
        S, v = builder.get_structptr_var(r, must_have_vtable=True)

        code = py.code.Source("""
        def f(%s):
            raise LLException(vtable, ptr)
        """ % funcargs).compile()
        vtableptr = v._hints['vtable']._as_ptr()
        d = {
            'ptr': getref_base(S),
            'vtable': vtableptr,
            'LLException': LLException,
            }
        exec(code, d)
        return subset, d['f'], vtableptr

    def getresulttype(self):
        if self.opnum == rop.CALL_I or self.opnum == rop.COND_CALL_VALUE_I:
            return lltype.Signed
        elif self.opnum == rop.CALL_F:
            return lltype.Float
        elif self.opnum == rop.CALL_N or self.opnum == rop.COND_CALL:
            return lltype.Void
        else:
            raise AssertionError(self.opnum)

    def getcalldescr(self, builder, TP):
        assert TP.RESULT == self.getresulttype()
        ef = EffectInfo.MOST_GENERAL
        return builder.cpu.calldescrof(TP, TP.ARGS, TP.RESULT, ef)

# 1. non raising call and guard_no_exception
class CallOperation(BaseCallOperation):
    def produce_into(self, builder, r):
        fail_subset = builder.subset_of_intvars(r)
        subset, f = self.non_raising_func_code(builder, r)
        RES = self.getresulttype()
        TP = lltype.FuncType([lltype.Signed] * len(subset), RES)
        ptr = llhelper(lltype.Ptr(TP), f)
        c_addr = ConstInt(ptr2int(ptr))
        args = [c_addr] + subset
        descr = self.getcalldescr(builder, TP)
        self.put(builder, args, descr)
        op = ResOperation(rop.GUARD_NO_EXCEPTION, [],
                          descr=builder.getfaildescr())
        op.setfailargs(fail_subset)
        builder.loop.operations.append(op)

# 5. Non raising-call and GUARD_EXCEPTION

class CallOperationException(BaseCallOperation):
    def produce_into(self, builder, r):
        subset, f = self.non_raising_func_code(builder, r)
        RES = self.getresulttype()
        TP = lltype.FuncType([lltype.Signed] * len(subset), RES)
        ptr = llhelper(lltype.Ptr(TP), f)
        c_addr = ConstInt(ptr2int(ptr))
        args = [c_addr] + subset
        descr = self.getcalldescr(builder, TP)
        self.put(builder, args, descr)
        _, vtableptr = builder.get_random_structure_type_and_vtable(r)
        exc_box = ConstInt(ptr2int(vtableptr))
        op = ResOperation(rop.GUARD_EXCEPTION, [exc_box],
                          descr=builder.getfaildescr())
        op.setfailargs(builder.subset_of_intvars(r))
        op._exc_box = None
        builder.should_fail_by = op
        builder.guard_op = op
        builder.loop.operations.append(op)

# 2. raising call and guard_exception

class RaisingCallOperation(BaseCallOperation):
    def produce_into(self, builder, r):
        fail_subset = builder.subset_of_intvars(r)
        subset, f, exc = self.raising_func_code(builder, r)
        TP = lltype.FuncType([lltype.Signed] * len(subset), lltype.Void)
        ptr = llhelper(lltype.Ptr(TP), f)
        c_addr = ConstInt(ptr2int(ptr))
        args = [c_addr] + subset
        descr = self.getcalldescr(builder, TP)
        self.put(builder, args, descr)
        exc_box = ConstInt(ptr2int(exc))
        op = ResOperation(rop.GUARD_EXCEPTION, [exc_box],
                          descr=builder.getfaildescr())
        op.setfailargs(fail_subset)
        builder.loop.operations.append(op)

# 4. raising call and guard_no_exception

class RaisingCallOperationGuardNoException(BaseCallOperation):
    def produce_into(self, builder, r):
        subset, f, exc = self.raising_func_code(builder, r)
        TP = lltype.FuncType([lltype.Signed] * len(subset), lltype.Void)
        ptr = llhelper(lltype.Ptr(TP), f)
        c_addr = ConstInt(ptr2int(ptr))
        args = [c_addr] + subset
        descr = self.getcalldescr(builder, TP)
        self.put(builder, args, descr)
        op = ResOperation(rop.GUARD_NO_EXCEPTION, [],
                          descr=builder.getfaildescr())
        op._exc_box = ConstInt(ptr2int(exc))
        op.setfailargs(builder.subset_of_intvars(r))
        builder.should_fail_by = op
        builder.guard_op = op
        builder.loop.operations.append(op)

# 3. raising call and wrong guard_exception

class RaisingCallOperationWrongGuardException(BaseCallOperation):
    def produce_into(self, builder, r):
        subset, f, exc = self.raising_func_code(builder, r)
        TP = lltype.FuncType([lltype.Signed] * len(subset), lltype.Void)
        ptr = llhelper(lltype.Ptr(TP), f)
        c_addr = ConstInt(ptr2int(ptr))
        args = [c_addr] + subset
        descr = self.getcalldescr(builder, TP)
        self.put(builder, args, descr)
        while True:
            _, vtableptr = builder.get_random_structure_type_and_vtable(r)
            if vtableptr != exc:
                break
        other_box = ConstInt(ptr2int(vtableptr))
        op = ResOperation(rop.GUARD_EXCEPTION, [other_box],
                          descr=builder.getfaildescr())
        op._exc_box = ConstInt(ptr2int(exc))
        op.setfailargs(builder.subset_of_intvars(r))
        builder.should_fail_by = op
        builder.guard_op = op
        builder.loop.operations.append(op)

# 6. a conditional call (for now always with no exception raised)
class CondCallOperation(BaseCallOperation):

    def produce_into(self, builder, r):
        fail_subset = builder.subset_of_intvars(r)
        if self.opnum == rop.COND_CALL:
            RESULT_TYPE = lltype.Void
            v_cond = builder.get_bool_var(r)
        else:
            RESULT_TYPE = lltype.Signed
            v_cond = r.choice(builder.intvars)
        subset = builder.subset_of_intvars(r)[:4]
        for i in range(len(subset)):
            if r.random() < 0.35:
                subset[i] = ConstInt(r.random_integer())
        #
        seen = []
        def call_me(*args):
            if len(seen) == 0:
                seen.append(args)
            else:
                assert seen[0] == args
            if RESULT_TYPE is lltype.Signed:
                return len(args) - 42000
        #
        TP = lltype.FuncType([lltype.Signed] * len(subset), RESULT_TYPE)
        ptr = llhelper(lltype.Ptr(TP), call_me)
        c_addr = ConstInt(ptr2int(ptr))
        args = [v_cond, c_addr] + subset
        descr = self.getcalldescr(builder, TP)
        self.put(builder, args, descr)
        op = ResOperation(rop.GUARD_NO_EXCEPTION, [],
                          descr=builder.getfaildescr())
        op.setfailargs(fail_subset)
        builder.loop.operations.append(op)

# ____________________________________________________________

OPERATIONS = test_random.OPERATIONS[:]

for i in range(4):      # make more common
    OPERATIONS.append(GetFieldOperation(rop.GETFIELD_GC_I))
    OPERATIONS.append(GetFieldOperation(rop.GETFIELD_GC_I))
    OPERATIONS.append(GetInteriorFieldOperation(rop.GETINTERIORFIELD_GC_I))
    OPERATIONS.append(GetInteriorFieldOperation(rop.GETINTERIORFIELD_GC_I))
    OPERATIONS.append(SetFieldOperation(rop.SETFIELD_GC))
    OPERATIONS.append(SetInteriorFieldOperation(rop.SETINTERIORFIELD_GC))
    OPERATIONS.append(NewOperation(rop.NEW))
    OPERATIONS.append(NewOperation(rop.NEW_WITH_VTABLE))

    OPERATIONS.append(GetArrayItemOperation(rop.GETARRAYITEM_GC_I))
    OPERATIONS.append(GetArrayItemOperation(rop.GETARRAYITEM_GC_I))
    OPERATIONS.append(SetArrayItemOperation(rop.SETARRAYITEM_GC))
    OPERATIONS.append(NewArrayOperation(rop.NEW_ARRAY_CLEAR))
    OPERATIONS.append(ArrayLenOperation(rop.ARRAYLEN_GC))
    OPERATIONS.append(NewStrOperation(rop.NEWSTR))
    OPERATIONS.append(NewUnicodeOperation(rop.NEWUNICODE))
    OPERATIONS.append(StrGetItemOperation(rop.STRGETITEM))
    OPERATIONS.append(UnicodeGetItemOperation(rop.UNICODEGETITEM))
    OPERATIONS.append(StrSetItemOperation(rop.STRSETITEM))
    OPERATIONS.append(UnicodeSetItemOperation(rop.UNICODESETITEM))
    OPERATIONS.append(StrLenOperation(rop.STRLEN))
    OPERATIONS.append(UnicodeLenOperation(rop.UNICODELEN))
    OPERATIONS.append(CopyStrContentOperation(rop.COPYSTRCONTENT))
    OPERATIONS.append(CopyUnicodeContentOperation(rop.COPYUNICODECONTENT))

for i in range(2):
    OPERATIONS.append(GuardClassOperation(rop.GUARD_CLASS))
    OPERATIONS.append(CondCallOperation(rop.COND_CALL))
    OPERATIONS.append(CondCallOperation(rop.COND_CALL_VALUE_I))
    OPERATIONS.append(RaisingCallOperation(rop.CALL_N))
    OPERATIONS.append(RaisingCallOperationGuardNoException(rop.CALL_N))
    OPERATIONS.append(RaisingCallOperationWrongGuardException(rop.CALL_N))
OPERATIONS.append(GuardNonNullClassOperation(rop.GUARD_NONNULL_CLASS))

for _opnum in [rop.CALL_I, rop.CALL_F, rop.CALL_N]:
    OPERATIONS.append(CallOperation(_opnum))
    OPERATIONS.append(CallOperationException(_opnum))

LLtypeOperationBuilder.OPERATIONS = OPERATIONS

# ____________________________________________________________

def test_ll_random_function():
    test_random.test_random_function(LLtypeOperationBuilder)

"""This implements pyjitpl's execution of operations.
"""

from rpython.rtyper.lltypesystem import lltype, rstr, llmemory
from rpython.rlib.rarithmetic import ovfcheck, r_longlong, is_valid_int
from rpython.rlib.unroll import unrolling_iterable
from rpython.rlib.objectmodel import specialize
from rpython.rlib.debug import fatalerror
from rpython.jit.metainterp.history import check_descr
from rpython.jit.metainterp.history import INT, REF, FLOAT, VOID, AbstractDescr
from rpython.jit.metainterp.history import ConstInt, ConstFloat, ConstPtr
from rpython.jit.metainterp import resoperation
from rpython.jit.metainterp.resoperation import rop, opname
from rpython.jit.metainterp.blackhole import BlackholeInterpreter, NULL
from rpython.jit.codewriter import longlong

# ____________________________________________________________

@specialize.arg(4)
def _do_call(cpu, metainterp, argboxes, descr, rettype):
    assert metainterp is not None
    # count the number of arguments of the different types
    count_i = count_r = count_f = 0
    for i in range(1, len(argboxes)):
        type = argboxes[i].type
        if   type == INT:   count_i += 1
        elif type == REF:   count_r += 1
        elif type == FLOAT: count_f += 1
    # allocate lists for each type that has at least one argument
    if count_i: args_i = [0] * count_i
    else:       args_i = None
    if count_r: args_r = [NULL] * count_r
    else:       args_r = None
    if count_f: args_f = [longlong.ZEROF] * count_f
    else:       args_f = None
    # fill in the lists
    count_i = count_r = count_f = 0
    for i in range(1, len(argboxes)):
        box = argboxes[i]
        if   box.type == INT:
            args_i[count_i] = box.getint()
            count_i += 1
        elif box.type == REF:
            args_r[count_r] = box.getref_base()
            count_r += 1
        elif box.type == FLOAT:
            args_f[count_f] = box.getfloatstorage()
            count_f += 1
    # get the function address as an integer
    func = argboxes[0].getint()
    # do the call using the correct function from the cpu
    if rettype == INT:
        try:
            result = cpu.bh_call_i(func, args_i, args_r, args_f, descr)
        except Exception as e:
            metainterp.execute_raised(e)
            result = 0
        return result
    if rettype == REF:
        try:
            result = cpu.bh_call_r(func, args_i, args_r, args_f, descr)
        except Exception as e:
            metainterp.execute_raised(e)
            result = NULL
        return result
    if rettype == FLOAT:
        try:
            result = cpu.bh_call_f(func, args_i, args_r, args_f, descr)
        except Exception as e:
            metainterp.execute_raised(e)
            result = longlong.ZEROF
        return result
    if rettype == VOID:
        try:
            cpu.bh_call_v(func, args_i, args_r, args_f, descr)
        except Exception as e:
            metainterp.execute_raised(e)
        return None
    raise AssertionError("bad rettype")

def new_do_call(rettype):
    def do_call(cpu, metainterp, argboxes, descr):
        return _do_call(cpu, metainterp, argboxes, descr, rettype)
    do_call.__name__ = "do_call_" + rettype
    return do_call

do_call_r = new_do_call("r")
do_call_i = new_do_call("i")
do_call_f = new_do_call("f")
do_call_n = new_do_call("v")
do_call_loopinvariant_r = do_call_r
do_call_loopinvariant_i = do_call_i
do_call_loopinvariant_f = do_call_f
do_call_loopinvariant_n = do_call_n
do_call_may_force_r = do_call_r
do_call_may_force_i = do_call_i
do_call_may_force_f = do_call_f
do_call_may_force_n = do_call_n

def do_cond_call(cpu, metainterp, argboxes, descr):
    condbox = argboxes[0]
    if condbox.getint():
        do_call_n(cpu, metainterp, argboxes[1:], descr)

def do_cond_call_value_i(cpu, metainterp, argboxes, descr):
    value = argboxes[0].getint()
    if value == 0:
        value = do_call_i(cpu, metainterp, argboxes[1:], descr)
    return value

def do_cond_call_value_r(cpu, metainterp, argboxes, descr):
    value = argboxes[0].getref_base()
    if not value:
        value = do_call_r(cpu, metainterp, argboxes[1:], descr)
    return value

def do_getarrayitem_gc_i(cpu, _, arraybox, indexbox, arraydescr):
    array = arraybox.getref_base()
    index = indexbox.getint()
    return cpu.bh_getarrayitem_gc_i(array, index, arraydescr)

def do_getarrayitem_gc_r(cpu, _, arraybox, indexbox, arraydescr):
    array = arraybox.getref_base()
    index = indexbox.getint()
    return cpu.bh_getarrayitem_gc_r(array, index, arraydescr)

def do_getarrayitem_gc_f(cpu, _, arraybox, indexbox, arraydescr):
    array = arraybox.getref_base()
    index = indexbox.getint()
    return cpu.bh_getarrayitem_gc_f(array, index, arraydescr)

def do_getarrayitem_raw_i(cpu, _, arraybox, indexbox, arraydescr):
    array = arraybox.getint()
    index = indexbox.getint()
    return cpu.bh_getarrayitem_raw_i(array, index, arraydescr)

def do_getarrayitem_raw_f(cpu, _, arraybox, indexbox, arraydescr):
    array = arraybox.getint()
    index = indexbox.getint()
    return cpu.bh_getarrayitem_raw_f(array, index, arraydescr)

def do_setarrayitem_gc(cpu, _, arraybox, indexbox, itembox, arraydescr):
    array = arraybox.getref_base()
    index = indexbox.getint()
    if arraydescr.is_array_of_pointers():
        cpu.bh_setarrayitem_gc_r(array, index, itembox.getref_base(),
                                 arraydescr)
    elif arraydescr.is_array_of_floats():
        cpu.bh_setarrayitem_gc_f(array, index, itembox.getfloatstorage(),
                                 arraydescr)
    else:
        cpu.bh_setarrayitem_gc_i(array, index, itembox.getint(), arraydescr)

def do_setarrayitem_raw(cpu, _, arraybox, indexbox, itembox, arraydescr):
    array = arraybox.getint()
    index = indexbox.getint()
    assert not arraydescr.is_array_of_pointers()
    if arraydescr.is_array_of_floats():
        cpu.bh_setarrayitem_raw_f(array, index, itembox.getfloatstorage(),
                                  arraydescr)
    else:
        cpu.bh_setarrayitem_raw_i(array, index, itembox.getint(), arraydescr)

def do_getinteriorfield_gc(cpu, _, arraybox, indexbox, descr):
    raise Exception("implement me")
    xxxx
    array = arraybox.getref_base()
    index = indexbox.getint()
    if descr.is_pointer_field():
        return BoxPtr(cpu.bh_getinteriorfield_gc_r(array, index, descr))
    elif descr.is_float_field():
        return BoxFloat(cpu.bh_getinteriorfield_gc_f(array, index, descr))
    else:
        return BoxInt(cpu.bh_getinteriorfield_gc_i(array, index, descr))

def do_setinteriorfield_gc(cpu, _, arraybox, indexbox, valuebox, descr):
    array = arraybox.getref_base()
    index = indexbox.getint()
    if descr.is_pointer_field():
        cpu.bh_setinteriorfield_gc_r(array, index, valuebox.getref_base(),
                                     descr)
    elif descr.is_float_field():
        cpu.bh_setinteriorfield_gc_f(array, index, valuebox.getfloatstorage(),
                                     descr)
    else:
        cpu.bh_setinteriorfield_gc_i(array, index, valuebox.getint(), descr)

def do_getfield_gc_i(cpu, _, structbox, fielddescr):
    struct = structbox.getref_base()
    return cpu.bh_getfield_gc_i(struct, fielddescr)

def do_getfield_gc_r(cpu, _, structbox, fielddescr):
    struct = structbox.getref_base()
    return cpu.bh_getfield_gc_r(struct, fielddescr)

def do_getfield_gc_f(cpu, _, structbox, fielddescr):
    struct = structbox.getref_base()
    return cpu.bh_getfield_gc_f(struct, fielddescr)

def do_getfield_raw_i(cpu, _, structbox, fielddescr):
    check_descr(fielddescr)
    struct = structbox.getint()
    return cpu.bh_getfield_raw_i(struct, fielddescr)

def do_getfield_raw_f(cpu, _, structbox, fielddescr):
    check_descr(fielddescr)
    struct = structbox.getint()
    return cpu.bh_getfield_raw_f(struct, fielddescr)

def do_getfield_raw_r(cpu, _, structbox, fielddescr):
    check_descr(fielddescr)
    struct = structbox.getint()
    return cpu.bh_getfield_raw_r(struct, fielddescr)

def do_setfield_gc(cpu, _, structbox, itembox, fielddescr):
    struct = structbox.getref_base()
    if fielddescr.is_pointer_field():
        cpu.bh_setfield_gc_r(struct, itembox.getref_base(), fielddescr)
    elif fielddescr.is_float_field():
        cpu.bh_setfield_gc_f(struct, itembox.getfloatstorage(), fielddescr)
    else:
        cpu.bh_setfield_gc_i(struct, itembox.getint(), fielddescr)

def do_setfield_raw(cpu, _, structbox, itembox, fielddescr):
    struct = structbox.getint()
    assert not fielddescr.is_pointer_field()
    if fielddescr.is_float_field():
        cpu.bh_setfield_raw_f(struct, itembox.getfloatstorage(), fielddescr)
    else:
        cpu.bh_setfield_raw_i(struct, itembox.getint(), fielddescr)

def do_raw_store(cpu, _, addrbox, offsetbox, valuebox, arraydescr):
    addr = addrbox.getint()
    offset = offsetbox.getint()
    if arraydescr.is_array_of_pointers():
        raise AssertionError("cannot store GC pointers in raw store")
    elif arraydescr.is_array_of_floats():
        cpu.bh_raw_store_f(addr, offset, valuebox.getfloatstorage(),arraydescr)
    else:
        cpu.bh_raw_store_i(addr, offset, valuebox.getint(), arraydescr)

def do_raw_load(cpu, _, addrbox, offsetbox, arraydescr):
    raise Exception("implement me")    
    xxx
    addr = addrbox.getint()
    offset = offsetbox.getint()
    if arraydescr.is_array_of_pointers():
        raise AssertionError("cannot store GC pointers in raw store")
    elif arraydescr.is_array_of_floats():
        return BoxFloat(cpu.bh_raw_load_f(addr, offset, arraydescr))
    else:
        return BoxInt(cpu.bh_raw_load_i(addr, offset, arraydescr))

def do_gc_store_indexed(cpu, _, addrbox, indexbox, valuebox, scalebox,
                        base_ofsbox, bytesbox, arraydescr):
    addr = addrbox.getref_base()
    index = indexbox.getint()
    scale = scalebox.getint()
    base_ofs = base_ofsbox.getint()
    bytes = bytesbox.getint()
    if arraydescr.is_array_of_pointers():
        raise AssertionError("cannot store GC pointers in gc_store_indexed for now")
    elif arraydescr.is_array_of_floats():
        floatval = valuebox.getfloatstorage()
        cpu.bh_gc_store_indexed_f(addr, index, floatval, scale, base_ofs, bytes,
                                  arraydescr)
    else:
        intval = valuebox.getint()
        cpu.bh_gc_store_indexed_i(addr, index, intval, scale, base_ofs, bytes,
                                  arraydescr)


def exec_new_with_vtable(cpu, descr):
    return cpu.bh_new_with_vtable(descr)

def do_new_with_vtable(cpu, _, clsbox):
    return exec_new_with_vtable(cpu, clsbox)

def do_int_add_ovf(cpu, metainterp, box1, box2):
    # the overflow operations can be called without a metainterp, if an
    # overflow cannot occur
    a = box1.getint()
    b = box2.getint()
    try:
        z = ovfcheck(a + b)
    except OverflowError:
        assert metainterp is not None
        metainterp.ovf_flag = True
        z = 0
    return z

def do_int_sub_ovf(cpu, metainterp, box1, box2):
    a = box1.getint()
    b = box2.getint()
    try:
        z = ovfcheck(a - b)
    except OverflowError:
        assert metainterp is not None
        metainterp.ovf_flag = True
        z = 0
    return z

def do_int_mul_ovf(cpu, metainterp, box1, box2):
    a = box1.getint()
    b = box2.getint()
    try:
        z = ovfcheck(a * b)
    except OverflowError:
        assert metainterp is not None
        metainterp.ovf_flag = True
        z = 0
    return z

def do_same_as_i(cpu, _, v):
    return v.getint()

def do_same_as_r(cpu, _, v):
    return v.getref_base()

def do_same_as_f(cpu, _, v):
    return v.getfloatstorage()

def do_copystrcontent(cpu, _, srcbox, dstbox,
                      srcstartbox, dststartbox, lengthbox):
    src = srcbox.getref(lltype.Ptr(rstr.STR))
    dst = dstbox.getref(lltype.Ptr(rstr.STR))
    srcstart = srcstartbox.getint()
    dststart = dststartbox.getint()
    length = lengthbox.getint()
    rstr.copy_string_contents(src, dst, srcstart, dststart, length)

def do_copyunicodecontent(cpu, _, srcbox, dstbox,
                          srcstartbox, dststartbox, lengthbox):
    src = srcbox.getref(lltype.Ptr(rstr.UNICODE))
    dst = dstbox.getref(lltype.Ptr(rstr.UNICODE))
    srcstart = srcstartbox.getint()
    dststart = dststartbox.getint()
    length = lengthbox.getint()
    rstr.copy_unicode_contents(src, dst, srcstart, dststart, length)

def do_keepalive(cpu, _, x):
    pass

def do_assert_not_none(cpu, _, box):
    if not box.getref_base():
        fatalerror("found during JITting: ll_assert_not_none() failed")

# ____________________________________________________________


def _make_execute_list():
    execute_by_num_args = {}
    for key in opname.values():
        value = getattr(rop, key)
        if not key.startswith('_'):
            if (rop._FINAL_FIRST <= value <= rop._FINAL_LAST or
                rop._GUARD_FIRST <= value <= rop._GUARD_LAST):
                continue
            # find which list to store the operation in, based on num_args
            num_args = resoperation.oparity[value]
            withdescr = resoperation.opwithdescr[value]
            dictkey = num_args, withdescr
            if dictkey not in execute_by_num_args:
                execute_by_num_args[dictkey] = [None] * (rop._LAST+1)
            execute = execute_by_num_args[dictkey]
            #
            if execute[value] is not None:
                raise AssertionError("duplicate entry for op number %d"% value)
            #
            # Fish for a way for the pyjitpl interpreter to delegate
            # really running the operation to the blackhole interpreter
            # or directly to the cpu.  First try the do_xxx() functions
            # explicitly encoded above:
            name = 'do_' + key.lower()
            if name in globals():
                execute[value] = globals()[name]
                continue
            #
            # Maybe the same without the _PURE suffix?
            if key[-7:-2] == '_PURE':
                key = key[:-7] + key[-2:]
                name = 'do_' + key.lower()
                if name in globals():
                    execute[value] = globals()[name]
                    continue
            #
            # If missing, fallback to the bhimpl_xxx() method of the
            # blackhole interpreter.  This only works if there is a
            # method of the exact same name and it accepts simple
            # parameters.
            name = 'bhimpl_' + key.lower()
            if hasattr(BlackholeInterpreter, name):
                func = make_execute_function(
                    key.lower(),
                    getattr(BlackholeInterpreter, name).im_func)
                if func is not None:
                    execute[value] = func
                    continue
            if value in (rop.FORCE_TOKEN,
                         rop.CALL_ASSEMBLER_R,
                         rop.CALL_ASSEMBLER_F,
                         rop.CALL_ASSEMBLER_I,
                         rop.CALL_ASSEMBLER_N,
                         rop.INCREMENT_DEBUG_COUNTER,
                         rop.COND_CALL_VALUE_R,
                         rop.COND_CALL_VALUE_I,
                         rop.COND_CALL_GC_WB,
                         rop.COND_CALL_GC_WB_ARRAY,
                         rop.ZERO_ARRAY,
                         rop.DEBUG_MERGE_POINT,
                         rop.JIT_DEBUG,
                         rop.ENTER_PORTAL_FRAME,
                         rop.LEAVE_PORTAL_FRAME,
                         rop.SETARRAYITEM_RAW,
                         rop.SETINTERIORFIELD_RAW,
                         rop.CALL_RELEASE_GIL_I,
                         rop.CALL_RELEASE_GIL_F,
                         rop.CALL_RELEASE_GIL_N,
                         rop.QUASIIMMUT_FIELD,
                         rop.CHECK_MEMORY_ERROR,
                         rop.CALL_MALLOC_NURSERY,
                         rop.CALL_MALLOC_NURSERY_VARSIZE,
                         rop.CALL_MALLOC_NURSERY_VARSIZE_FRAME,
                         rop.NURSERY_PTR_INCREMENT,
                         rop.LABEL,
                         rop.ESCAPE_I,
                         rop.ESCAPE_N,
                         rop.ESCAPE_R,
                         rop.ESCAPE_F,
                         rop.FORCE_SPILL,
                         rop.SAVE_EXC_CLASS,
                         rop.SAVE_EXCEPTION,
                         rop.RESTORE_EXCEPTION,
                         rop.VEC_LOAD_I,
                         rop.VEC_LOAD_F,
                         rop.GC_LOAD_I,
                         rop.GC_LOAD_R,
                         rop.GC_LOAD_F,
                         rop.GC_LOAD_INDEXED_R,
                         rop.VEC_STORE,
                         rop.GC_STORE,
                         rop.GC_STORE_INDEXED,
                         rop.LOAD_FROM_GC_TABLE,
                         rop.LOAD_EFFECTIVE_ADDRESS,
                         ):      # list of opcodes never executed by pyjitpl
                continue
            if rop._VEC_PURE_FIRST <= value <= rop._VEC_PURE_LAST:
                continue

            raise AssertionError("missing %r" % (key,))
    return execute_by_num_args

def make_execute_function(name, func):
    # Make a wrapper for 'func'.  The func is a simple bhimpl_xxx function
    # from the BlackholeInterpreter class.  The wrapper is a new function
    # that receives boxed values (but returns a non-boxed value).
    for argtype in func.argtypes:
        if argtype not in ('i', 'r', 'f', 'd', 'cpu'):
            return None
    if list(func.argtypes).count('d') > 1:
        return None
    argtypes = unrolling_iterable(func.argtypes)
    #
    def do(cpu, _, *argboxes):
        newargs = ()
        for argtype in argtypes:
            if argtype == 'cpu':
                value = cpu
            elif argtype == 'd':
                value = argboxes[-1]
                assert isinstance(value, AbstractDescr)
                argboxes = argboxes[:-1]
            else:
                argbox = argboxes[0]
                argboxes = argboxes[1:]
                if argtype == 'i':   value = argbox.getint()
                elif argtype == 'r': value = argbox.getref_base()
                elif argtype == 'f': value = argbox.getfloatstorage()
            newargs = newargs + (value,)
        assert not argboxes
        #
        return func(*newargs)
    #
    do.__name__ = 'do_' + name
    return do

def get_execute_funclist(num_args, withdescr):
    # workaround, similar to the next one
    return EXECUTE_BY_NUM_ARGS[num_args, withdescr]
get_execute_funclist._annspecialcase_ = 'specialize:memo'

def get_execute_function(opnum, num_args, withdescr):
    # workaround for an annotation limitation: putting this code in
    # a specialize:memo function makes sure the following line is
    # constant-folded away.  Only works if opnum and num_args are
    # constants, of course.
    func = EXECUTE_BY_NUM_ARGS[num_args, withdescr][opnum]
    #assert func is not None, "EXECUTE_BY_NUM_ARGS[%s, %s][%s]" % (
    #    num_args, withdescr, resoperation.opname[opnum])
    return func
get_execute_function._annspecialcase_ = 'specialize:memo'

def has_descr(opnum):
    # workaround, similar to the previous one
    return resoperation.opwithdescr[opnum]
has_descr._annspecialcase_ = 'specialize:memo'


def execute(cpu, metainterp, opnum, descr, *argboxes):
    # only for opnums with a fixed arity
    num_args = len(argboxes)
    withdescr = has_descr(opnum)
    if withdescr:
        check_descr(descr)
        argboxes = argboxes + (descr,)
    else:
        assert descr is None
    func = get_execute_function(opnum, num_args, withdescr)
    return func(cpu, metainterp, *argboxes)  # note that the 'argboxes' tuple
                                             # optionally ends with the descr
execute._annspecialcase_ = 'specialize:arg(2)'

def execute_varargs(cpu, metainterp, opnum, argboxes, descr):
    # only for opnums with a variable arity (calls, typically)
    check_descr(descr)
    func = get_execute_function(opnum, -1, True)
    return func(cpu, metainterp, argboxes, descr)
execute_varargs._annspecialcase_ = 'specialize:arg(2)'

@specialize.argtype(0)
def wrap_constant(value):
    if lltype.typeOf(value) == lltype.Signed:
        return ConstInt(value)
    elif isinstance(value, bool):
        return ConstInt(int(value))
    elif lltype.typeOf(value) == longlong.FLOATSTORAGE:
        return ConstFloat(value)
    elif isinstance(value, float):
        return ConstFloat(longlong.getfloatstorage(value))
    else:
        assert lltype.typeOf(value) == llmemory.GCREF
        return ConstPtr(value)

def constant_from_op(op):
    if op.type == 'i':
        return ConstInt(op.getint())
    elif op.type == 'r':
        return ConstPtr(op.getref_base())
    else:
        assert op.type == 'f'
        return ConstFloat(op.getfloatstorage())

unrolled_range = unrolling_iterable(range(rop._LAST))
    
def execute_nonspec_const(cpu, metainterp, opnum, argboxes, descr=None,
                          type='i'):
    for num in unrolled_range:
        if num == opnum:
            return wrap_constant(_execute_arglist(cpu, metainterp, num,
                                                  argboxes, descr))
    assert False

@specialize.arg(2)
def _execute_arglist(cpu, metainterp, opnum, argboxes, descr=None):
    arity = resoperation.oparity[opnum]    
    assert arity == -1 or len(argboxes) == arity
    if resoperation.opwithdescr[opnum]:
        check_descr(descr)
        if arity == -1:
            func = get_execute_function(opnum, -1, True)
            if func:
                return func(cpu, metainterp, argboxes, descr)
        if arity == 0:
            func = get_execute_function(opnum, 0, True)
            if func:
                return func(cpu, metainterp, descr)
        if arity == 1:
            func = get_execute_function(opnum, 1, True)
            if func:
                return func(cpu, metainterp, argboxes[0], descr)
        if arity == 2:
            func = get_execute_function(opnum, 2, True)
            if func:
                return func(cpu, metainterp, argboxes[0], argboxes[1], descr)
        if arity == 3:
            func = get_execute_function(opnum, 3, True)
            if func:
                return func(cpu, metainterp, argboxes[0], argboxes[1],
                            argboxes[2], descr)
    else:
        assert descr is None
        if arity == 1:
            func = get_execute_function(opnum, 1, False)
            if func:
                return func(cpu, metainterp, argboxes[0])
        if arity == 2:
            func = get_execute_function(opnum, 2, False)
            if func:
                return func(cpu, metainterp, argboxes[0], argboxes[1])
        if arity == 3:
            func = get_execute_function(opnum, 3, False)
            if func:
                return func(cpu, metainterp, argboxes[0], argboxes[1],
                            argboxes[2])
        if arity == 5:    # copystrcontent, copyunicodecontent
            func = get_execute_function(opnum, 5, False)
            if func:
                return func(cpu, metainterp, argboxes[0], argboxes[1],
                        argboxes[2], argboxes[3], argboxes[4])
    raise NotImplementedError


EXECUTE_BY_NUM_ARGS = _make_execute_list()

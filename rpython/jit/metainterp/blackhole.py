from rpython.jit.codewriter import longlong
from rpython.jit.codewriter.jitcode import JitCode, SwitchDictDescr
from rpython.jit.metainterp.compile import ResumeAtPositionDescr
from rpython.jit.metainterp.jitexc import get_llexception, reraise
from rpython.jit.metainterp import jitexc
from rpython.jit.metainterp.history import MissingValue
from rpython.jit.metainterp.support import (
    adr2int, int2adr, ptr2int, int_signext)
from rpython.rlib import longlong2float
from rpython.rlib.debug import ll_assert, make_sure_not_resized
from rpython.rlib.debug import check_annotation
from rpython.rlib.objectmodel import we_are_translated, specialize
from rpython.rlib.rarithmetic import intmask, LONG_BIT, r_uint, ovfcheck
from rpython.rlib.unroll import unrolling_iterable
from rpython.rtyper.lltypesystem import lltype, llmemory, rffi
from rpython.rtyper import rclass
from rpython.rtyper.lltypesystem.lloperation import llop
from rpython.rlib.jit_libffi import CIF_DESCRIPTION_P


def arguments(*argtypes, **kwds):
    resulttype = kwds.pop('returns', None)
    assert not kwds
    def decorate(function):
        function.argtypes = argtypes
        function.resulttype = resulttype
        return function
    return decorate

LONGLONG_TYPECODE = 'i' if longlong.is_64_bit else 'f'


class LeaveFrame(jitexc.JitException):
    pass

def signedord(c):
    value = ord(c)
    value = intmask(value << (LONG_BIT-8)) >> (LONG_BIT-8)
    return value

NULL = lltype.nullptr(llmemory.GCREF.TO)

# ____________________________________________________________


class BlackholeInterpBuilder(object):
    verbose = True

    def __init__(self, codewriter, metainterp_sd=None):
        self.cpu = codewriter.cpu
        asm = codewriter.assembler
        self.setup_insns(asm.insns)
        self.setup_descrs(asm.descrs)
        self.metainterp_sd = metainterp_sd
        self.num_interpreters = 0
        self.blackholeinterps = None

    def _cleanup_(self):
        self.blackholeinterps = None

    def setup_insns(self, insns):
        assert len(insns) <= 256, "too many instructions!"
        self._insns = [None] * len(insns)
        for key, value in insns.items():
            assert self._insns[value] is None
            self._insns[value] = key
        self.op_catch_exception = insns.get('catch_exception/L', -1)
        self.op_rvmprof_code = insns.get('rvmprof_code/ii', -1)
        #
        all_funcs = []
        for key in self._insns:
            assert key.count('/') == 1, "bad key: %r" % (key,)
            name, argcodes = key.split('/')
            all_funcs.append(self._get_method(name, argcodes))
        all_funcs = unrolling_iterable(enumerate(all_funcs))
        #
        def dispatch_loop(self, code, position):
            assert position >= 0
            while True:
                if (not we_are_translated()
                    and self.jitcode._startpoints is not None):
                    assert position in self.jitcode._startpoints, (
                        "the current position %d is in the middle of "
                        "an instruction!" % position)
                opcode = ord(code[position])
                position += 1
                for i, func in all_funcs:
                    if opcode == i:
                        position = func(self, code, position)
                        break
                else:
                    raise AssertionError("bad opcode")
        dispatch_loop._dont_inline_ = True
        self.dispatch_loop = dispatch_loop

    def setup_descrs(self, descrs):
        self.descrs = descrs

    def _get_method(self, name, argcodes):
        #
        def handler(self, code, position):
            assert position >= 0
            args = ()
            next_argcode = 0
            for argtype in argtypes:
                if argtype == 'i' or argtype == 'r' or argtype == 'f':
                    # if argtype is 'i', then argcode can be 'i' or 'c';
                    # 'c' stands for a single signed byte that gives the
                    # value of a small constant.
                    argcode = argcodes[next_argcode]
                    next_argcode = next_argcode + 1
                    if argcode == 'i':
                        assert argtype == 'i'
                        value = self.registers_i[ord(code[position])]
                    elif argcode == 'c':
                        assert argtype == 'i'
                        value = signedord(code[position])
                    elif argcode == 'r':
                        assert argtype == 'r'
                        value = self.registers_r[ord(code[position])]
                    elif argcode == 'f':
                        assert argtype == 'f'
                        value = self.registers_f[ord(code[position])]
                    else:
                        raise AssertionError("bad argcode")
                    position += 1
                elif argtype == 'L':
                    # argcode should be 'L' too
                    assert argcodes[next_argcode] == 'L'
                    next_argcode = next_argcode + 1
                    value = ord(code[position]) | (ord(code[position+1])<<8)
                    position += 2
                elif argtype == 'I' or argtype == 'R' or argtype == 'F':
                    assert argcodes[next_argcode] == argtype
                    next_argcode = next_argcode + 1
                    value = self._get_list_of_values(code, position, argtype)
                    position += 1 + len(value)
                elif argtype == 'self':
                    value = self
                elif argtype == 'cpu':
                    value = self.cpu
                elif argtype == 'pc':
                    value = position
                elif argtype == 'd' or argtype == 'j':
                    assert argcodes[next_argcode] == 'd'
                    next_argcode = next_argcode + 1
                    index = ord(code[position]) | (ord(code[position+1])<<8)
                    value = self.descrs[index]
                    if argtype == 'j':
                        assert isinstance(value, JitCode)
                    position += 2
                else:
                    raise AssertionError("bad argtype: %r" % (argtype,))
                if not we_are_translated():
                    assert not isinstance(value, MissingValue), (
                        name, self.jitcode, position)
                args = args + (value,)

            if verbose and not we_are_translated():
                print '\tbh:', name, list(args),

            # call the method bhimpl_xxx()
            try:
                result = unboundmethod(*args)
            except Exception as e:
                if verbose and not we_are_translated():
                    print '-> %s!' % (e.__class__.__name__,)
                if resulttype == 'i' or resulttype == 'r' or resulttype == 'f':
                    position += 1
                self.position = position
                raise

            if verbose and not we_are_translated():
                if result is None:
                    print
                else:
                    print '->', result

            if resulttype == 'i':
                # argcode should be 'i' too
                assert argcodes[next_argcode] == '>'
                assert argcodes[next_argcode + 1] == 'i'
                next_argcode = next_argcode + 2
                if lltype.typeOf(result) is lltype.Bool:
                    result = int(result)
                assert lltype.typeOf(result) is lltype.Signed
                self.registers_i[ord(code[position])] = plain_int(result)
                position += 1
            elif resulttype == 'r':
                # argcode should be 'r' too
                assert argcodes[next_argcode] == '>'
                assert argcodes[next_argcode + 1] == 'r'
                next_argcode = next_argcode + 2
                assert lltype.typeOf(result) == llmemory.GCREF
                self.registers_r[ord(code[position])] = result
                position += 1
            elif resulttype == 'f':
                # argcode should be 'f' too
                assert argcodes[next_argcode] == '>'
                assert argcodes[next_argcode + 1] == 'f'
                next_argcode = next_argcode + 2
                assert lltype.typeOf(result) is longlong.FLOATSTORAGE
                self.registers_f[ord(code[position])] = result
                position += 1
            elif resulttype == "iL":
                result, new_position = result
                if new_position != -1:
                    position = new_position
                    next_argcode = next_argcode + 2
                else:
                    assert argcodes[next_argcode] == '>'
                    assert argcodes[next_argcode + 1] == 'i'
                    next_argcode = next_argcode + 2
                    if lltype.typeOf(result) is lltype.Bool:
                        result = int(result)
                    assert lltype.typeOf(result) is lltype.Signed
                    self.registers_i[ord(code[position])] = plain_int(result)
                    position += 1
            elif resulttype == 'L':
                assert result >= 0
                position = result
            else:
                assert resulttype is None
                assert result is None
            assert next_argcode == len(argcodes)
            return position
        #
        # Get the bhimpl_xxx method.  If we get an AttributeError here,
        # it means that either the implementation is missing, or that it
        # should not appear here at all but instead be transformed away
        # by codewriter/jtransform.py.
        unboundmethod = getattr(BlackholeInterpreter, 'bhimpl_' + name).im_func
        verbose = self.verbose
        argtypes = unrolling_iterable(unboundmethod.argtypes)
        resulttype = unboundmethod.resulttype
        handler.__name__ = 'handler_' + name
        return handler

    def acquire_interp(self):
        res = self.blackholeinterps
        if res is not None:
            self.blackholeinterps = res.back
            return res
        else:
            self.num_interpreters += 1
            return BlackholeInterpreter(self, self.num_interpreters)

    def release_interp(self, interp):
        interp.cleanup_registers()
        interp.back = self.blackholeinterps
        self.blackholeinterps = interp

def check_shift_count(b):
    if not we_are_translated():
        if b < 0 or b >= LONG_BIT:
            raise ValueError("Shift count, %d,  not in valid range, 0 .. %d." % (b, LONG_BIT-1))

def check_list_of_plain_integers(s_arg, bookkeeper):
    """Check that 'BlackhopeInterpreter.registers_i' is annotated as a
    non-resizable list of plain integers (and not r_int's for example)."""
    from rpython.annotator import model as annmodel
    assert isinstance(s_arg, annmodel.SomeList)
    s_arg.listdef.never_resize()
    assert s_arg.listdef.listitem.s_value.knowntype is int

def _check_int(s_arg, bookkeeper):
    assert s_arg.knowntype is int

def plain_int(x):
    """Check that 'x' is annotated as a plain integer (and not r_int)"""
    check_annotation(x, _check_int)
    return x


class BlackholeInterpreter(object):

    def __init__(self, builder, count_interpreter):
        self.builder            = builder
        self.cpu                = builder.cpu
        self.dispatch_loop      = builder.dispatch_loop
        self.descrs             = builder.descrs
        self.op_catch_exception = builder.op_catch_exception
        self.op_rvmprof_code    = builder.op_rvmprof_code
        self.count_interpreter  = count_interpreter
        #
        if we_are_translated():
            default_i = 0
            default_r = NULL
            default_f = longlong.ZEROF
        else:
            default_i = MissingValue()
            default_r = MissingValue()
            default_f = MissingValue()
        self.registers_i = [default_i] * 256
        self.registers_r = [default_r] * 256
        self.registers_f = [default_f] * 256
        self.tmpreg_i = default_i
        self.tmpreg_r = default_r
        self.tmpreg_f = default_f
        self.jitcode = None
        self.back = None # chain unused interpreters together via this
        check_annotation(self.registers_i, check_list_of_plain_integers)

    def __repr__(self):
        return '<BHInterp #%d>' % self.count_interpreter

    def setposition(self, jitcode, position):
        if jitcode is not self.jitcode:
            # the real performance impact of the following code is unclear,
            # but it should be minimized by the fact that a given
            # BlackholeInterpreter instance is likely to be reused with
            # exactly the same jitcode, so we don't do the copy again.
            self.copy_constants(self.registers_i, jitcode.constants_i)
            self.copy_constants(self.registers_r, jitcode.constants_r)
            self.copy_constants(self.registers_f, jitcode.constants_f)
        self.jitcode = jitcode
        self.position = position

    def setarg_i(self, index, value):
        assert lltype.typeOf(value) is lltype.Signed
        self.registers_i[index] = plain_int(value)

    def setarg_r(self, index, value):
        assert lltype.typeOf(value) == llmemory.GCREF
        self.registers_r[index] = value

    def setarg_f(self, index, value):
        assert lltype.typeOf(value) is longlong.FLOATSTORAGE
        self.registers_f[index] = value

    def run(self):
        while True:
            try:
                self.dispatch_loop(self, self.jitcode.code, self.position)
            except LeaveFrame:
                break
            except jitexc.JitException:
                raise     # go through
            except Exception as e:
                lle = get_llexception(self.cpu, e)
                self.handle_exception_in_frame(lle)

    def get_tmpreg_i(self):
        return self.tmpreg_i

    def get_tmpreg_r(self):
        result = self.tmpreg_r
        if we_are_translated():
            self.tmpreg_r = NULL
        else:
            del self.tmpreg_r
        return result

    def get_tmpreg_f(self):
        return self.tmpreg_f

    def _final_result_anytype(self):
        "NOT_RPYTHON"
        if self._return_type == 'i': return self.get_tmpreg_i()
        if self._return_type == 'r': return self.get_tmpreg_r()
        if self._return_type == 'f': return self.get_tmpreg_f()
        if self._return_type == 'v': return None
        raise ValueError(self._return_type)

    def cleanup_registers(self):
        # To avoid keeping references alive, this cleans up the registers_r.
        # It does not clear the references set by copy_constants(), but
        # these are all prebuilt constants anyway.
        for i in range(self.jitcode.num_regs_r()):
            self.registers_r[i] = NULL
        self.exception_last_value = lltype.nullptr(rclass.OBJECT)

    def get_current_position_info(self):
        return self.jitcode.get_live_vars_info(self.position)

    def handle_exception_in_frame(self, e):
        # This frame raises an exception.  First try to see if
        # the exception is handled in the frame itself.
        code = self.jitcode.code
        position = self.position
        if position < len(code):
            opcode = ord(code[position])
            if opcode == self.op_catch_exception:
                # store the exception on 'self', and jump to the handler
                self.exception_last_value = e
                target = ord(code[position+1]) | (ord(code[position+2])<<8)
                self.position = target
                return
            if opcode == self.op_rvmprof_code:
                # call the 'jit_rvmprof_code(1)' for rvmprof, but then
                # continue popping frames.  Decode the 'rvmprof_code' insn
                # manually here.
                from rpython.rlib.rvmprof import cintf
                arg1 = self.registers_i[ord(code[position + 1])]
                arg2 = self.registers_i[ord(code[position + 2])]
                assert arg1 == 1
                cintf.jit_rvmprof_code(arg1, arg2)
        # no 'catch_exception' insn follows: just reraise
        reraise(e)

    def handle_rvmprof_enter(self):
        code = self.jitcode.code
        position = self.position
        opcode = ord(code[position])
        if opcode == self.op_rvmprof_code:
            arg1 = self.registers_i[ord(code[position + 1])]
            arg2 = self.registers_i[ord(code[position + 2])]
            if arg1 == 1:
                # we are resuming at a position that will do a
                # jit_rvmprof_code(1), when really executed.  That's a
                # hint for the need for a jit_rvmprof_code(0).
                from rpython.rlib.rvmprof import cintf
                cintf.jit_rvmprof_code(0, arg2)

    def copy_constants(self, registers, constants):
        """Copy jitcode.constants[0] to registers[255],
                jitcode.constants[1] to registers[254],
                jitcode.constants[2] to registers[253], etc."""
        make_sure_not_resized(registers)
        make_sure_not_resized(constants)
        i = len(constants) - 1
        while i >= 0:
            j = 255 - i
            assert j >= 0
            registers[j] = constants[i]
            i -= 1
    copy_constants._annspecialcase_ = 'specialize:arglistitemtype(1)'

    # ----------

    @arguments("i", returns="i")
    def bhimpl_int_same_as(a):
        return a

    @arguments("i", "i", returns="i")
    def bhimpl_int_add(a, b):
        return intmask(a + b)

    @arguments("i", "i", returns="i")
    def bhimpl_int_sub(a, b):
        return intmask(a - b)

    @arguments("i", "i", returns="i")
    def bhimpl_int_mul(a, b):
        return intmask(a * b)

    @arguments("i", "i", returns="i")
    def bhimpl_uint_mul_high(a, b):
        from rpython.jit.metainterp.optimizeopt import intdiv
        a = r_uint(a)
        b = r_uint(b)
        c = intdiv.unsigned_mul_high(a, b)
        return intmask(c)

    @arguments("L", "i", "i", returns="iL")
    def bhimpl_int_add_jump_if_ovf(label, a, b):
        try:
            return ovfcheck(a + b), -1
        except OverflowError:
            return 0, label

    @arguments("L", "i", "i", returns="iL")
    def bhimpl_int_sub_jump_if_ovf(label, a, b):
        try:
            return ovfcheck(a - b), -1
        except OverflowError:
            return 0, label

    @arguments("L", "i", "i", returns="iL")
    def bhimpl_int_mul_jump_if_ovf(label, a, b):
        try:
            return ovfcheck(a * b), -1
        except OverflowError:
            return 0, label

    @arguments("i", "i", returns="i")
    def bhimpl_int_and(a, b):
        return a & b

    @arguments("i", "i", returns="i")
    def bhimpl_int_or(a, b):
        return a | b

    @arguments("i", "i", returns="i")
    def bhimpl_int_xor(a, b):
        return a ^ b

    @arguments("i", "i", returns="i")
    def bhimpl_int_rshift(a, b):
        check_shift_count(b)
        return a >> b

    @arguments("i", "i", returns="i")
    def bhimpl_int_lshift(a, b):
        check_shift_count(b)
        return intmask(a << b)

    @arguments("i", "i", returns="i")
    def bhimpl_uint_rshift(a, b):
        check_shift_count(b)
        c = r_uint(a) >> r_uint(b)
        return intmask(c)

    @arguments("i", returns="i")
    def bhimpl_int_neg(a):
        return intmask(-a)

    @arguments("i", returns="i")
    def bhimpl_int_invert(a):
        return intmask(~a)

    @arguments("i", "i", returns="i")
    def bhimpl_int_lt(a, b):
        return a < b
    @arguments("i", "i", returns="i")
    def bhimpl_int_le(a, b):
        return a <= b
    @arguments("i", "i", returns="i")
    def bhimpl_int_eq(a, b):
        return a == b
    @arguments("i", "i", returns="i")
    def bhimpl_int_ne(a, b):
        return a != b
    @arguments("i", "i", returns="i")
    def bhimpl_int_gt(a, b):
        return a > b
    @arguments("i", "i", returns="i")
    def bhimpl_int_ge(a, b):
        return a >= b
    @arguments("i", returns="i")
    def bhimpl_int_is_zero(a):
        return not a
    @arguments("i", returns="i")
    def bhimpl_int_is_true(a):
        return bool(a)
    @arguments("i", "i", "i", returns="i")
    def bhimpl_int_between(a, b, c):
        return a <= b < c
    @arguments("i", returns="i")
    def bhimpl_int_force_ge_zero(i):
        if i < 0:
            return 0
        return i
    @arguments("i", "i", returns="i")
    def bhimpl_int_signext(a, b):
        return int_signext(a, b)

    @arguments("i", "i", returns="i")
    def bhimpl_uint_lt(a, b):
        return r_uint(a) < r_uint(b)
    @arguments("i", "i", returns="i")
    def bhimpl_uint_le(a, b):
        return r_uint(a) <= r_uint(b)
    @arguments("i", "i", returns="i")
    def bhimpl_uint_gt(a, b):
        return r_uint(a) > r_uint(b)
    @arguments("i", "i", returns="i")
    def bhimpl_uint_ge(a, b):
        return r_uint(a) >= r_uint(b)

    @arguments("r", "r", returns="i")
    def bhimpl_ptr_eq(a, b):
        return a == b
    @arguments("r", "r", returns="i")
    def bhimpl_ptr_ne(a, b):
        return a != b
    @arguments("r", returns="i")
    def bhimpl_ptr_iszero(a):
        return not a
    @arguments("r", returns="i")
    def bhimpl_ptr_nonzero(a):
        return bool(a)
    @arguments("r", "r", returns="i")
    def bhimpl_instance_ptr_eq(a, b):
        return a == b
    @arguments("r", "r", returns="i")
    def bhimpl_instance_ptr_ne(a, b):
        return a != b
    @arguments("r", returns="i")
    def bhimpl_cast_ptr_to_int(a):
        i = lltype.cast_ptr_to_int(a)
        ll_assert((i & 1) == 1, "bhimpl_cast_ptr_to_int: not an odd int")
        return i
    @arguments("i", returns="r")
    def bhimpl_cast_int_to_ptr(i):
        ll_assert((i & 1) == 1, "bhimpl_cast_int_to_ptr: not an odd int")
        return lltype.cast_int_to_ptr(llmemory.GCREF, i)

    @arguments("r")
    def bhimpl_assert_not_none(a):
        assert a

    @arguments("r", "i")
    def bhimpl_record_exact_class(a, b):
        pass

    @arguments("i", returns="i")
    def bhimpl_int_copy(a):
        return a
    @arguments("r", returns="r")
    def bhimpl_ref_copy(a):
        return a
    @arguments("f", returns="f")
    def bhimpl_float_copy(a):
        return a

    @arguments("i")
    def bhimpl_int_guard_value(a):
        pass
    @arguments("r")
    def bhimpl_ref_guard_value(a):
        pass
    @arguments("f")
    def bhimpl_float_guard_value(a):
        pass
    @arguments("r", "i", "d", returns="r")
    def bhimpl_str_guard_value(a, i, d):
        return a

    @arguments("self", "i")
    def bhimpl_int_push(self, a):
        self.tmpreg_i = a
    @arguments("self", "r")
    def bhimpl_ref_push(self, a):
        self.tmpreg_r = a
    @arguments("self", "f")
    def bhimpl_float_push(self, a):
        self.tmpreg_f = a

    @arguments("self", returns="i")
    def bhimpl_int_pop(self):
        return self.get_tmpreg_i()
    @arguments("self", returns="r")
    def bhimpl_ref_pop(self):
        return self.get_tmpreg_r()
    @arguments("self", returns="f")
    def bhimpl_float_pop(self):
        return self.get_tmpreg_f()

    # ----------
    # float operations

    @arguments("f", returns="f")
    def bhimpl_float_neg(a):
        a = longlong.getrealfloat(a)
        x = -a
        return longlong.getfloatstorage(x)
    @arguments("f", returns="f")
    def bhimpl_float_abs(a):
        a = longlong.getrealfloat(a)
        x = abs(a)
        return longlong.getfloatstorage(x)

    @arguments("f", "f", returns="f")
    def bhimpl_float_add(a, b):
        a = longlong.getrealfloat(a)
        b = longlong.getrealfloat(b)
        x = a + b
        return longlong.getfloatstorage(x)
    @arguments("f", "f", returns="f")
    def bhimpl_float_sub(a, b):
        a = longlong.getrealfloat(a)
        b = longlong.getrealfloat(b)
        x = a - b
        return longlong.getfloatstorage(x)
    @arguments("f", "f", returns="f")
    def bhimpl_float_mul(a, b):
        a = longlong.getrealfloat(a)
        b = longlong.getrealfloat(b)
        x = a * b
        return longlong.getfloatstorage(x)
    @arguments("f", "f", returns="f")
    def bhimpl_float_truediv(a, b):
        a = longlong.getrealfloat(a)
        b = longlong.getrealfloat(b)
        x = a / b
        return longlong.getfloatstorage(x)

    @arguments("f", "f", returns="i")
    def bhimpl_float_lt(a, b):
        a = longlong.getrealfloat(a)
        b = longlong.getrealfloat(b)
        return a < b
    @arguments("f", "f", returns="i")
    def bhimpl_float_le(a, b):
        a = longlong.getrealfloat(a)
        b = longlong.getrealfloat(b)
        return a <= b
    @arguments("f", "f", returns="i")
    def bhimpl_float_eq(a, b):
        a = longlong.getrealfloat(a)
        b = longlong.getrealfloat(b)
        return a == b
    @arguments("f", "f", returns="i")
    def bhimpl_float_ne(a, b):
        a = longlong.getrealfloat(a)
        b = longlong.getrealfloat(b)
        return a != b
    @arguments("f", "f", returns="i")
    def bhimpl_float_gt(a, b):
        a = longlong.getrealfloat(a)
        b = longlong.getrealfloat(b)
        return a > b
    @arguments("f", "f", returns="i")
    def bhimpl_float_ge(a, b):
        a = longlong.getrealfloat(a)
        b = longlong.getrealfloat(b)
        return a >= b

    @arguments("f", "f", "L", "pc", returns="L")
    def bhimpl_goto_if_not_float_lt(a, b, target, pc):
        a = longlong.getrealfloat(a)
        b = longlong.getrealfloat(b)
        if a < b:
            return pc
        else:
            return target
    @arguments("f", "f", "L", "pc", returns="L")
    def bhimpl_goto_if_not_float_le(a, b, target, pc):
        a = longlong.getrealfloat(a)
        b = longlong.getrealfloat(b)
        if a <= b:
            return pc
        else:
            return target
    @arguments("f", "f", "L", "pc", returns="L")
    def bhimpl_goto_if_not_float_eq(a, b, target, pc):
        a = longlong.getrealfloat(a)
        b = longlong.getrealfloat(b)
        if a == b:
            return pc
        else:
            return target
    @arguments("f", "f", "L", "pc", returns="L")
    def bhimpl_goto_if_not_float_ne(a, b, target, pc):
        a = longlong.getrealfloat(a)
        b = longlong.getrealfloat(b)
        if a != b:
            return pc
        else:
            return target
    @arguments("f", "f", "L", "pc", returns="L")
    def bhimpl_goto_if_not_float_gt(a, b, target, pc):
        a = longlong.getrealfloat(a)
        b = longlong.getrealfloat(b)
        if a > b:
            return pc
        else:
            return target
    @arguments("f", "f", "L", "pc", returns="L")
    def bhimpl_goto_if_not_float_ge(a, b, target, pc):
        a = longlong.getrealfloat(a)
        b = longlong.getrealfloat(b)
        if a >= b:
            return pc
        else:
            return target

    @arguments("f", returns="i")
    def bhimpl_cast_float_to_int(a):
        a = longlong.getrealfloat(a)
        # note: we need to call int() twice to care for the fact that
        # int(-2147483648.0) returns a long :-(
        # we could also call intmask() instead of the outermost int(), but
        # it's probably better to explicitly crash (by getting a long) if a
        # non-translated version tries to cast a too large float to an int.
        return int(int(a))

    @arguments("i", returns="f")
    def bhimpl_cast_int_to_float(a):
        x = float(a)
        return longlong.getfloatstorage(x)

    @arguments("f", returns="i")
    def bhimpl_cast_float_to_singlefloat(a):
        from rpython.rlib.rarithmetic import r_singlefloat
        a = longlong.getrealfloat(a)
        a = r_singlefloat(a)
        return longlong.singlefloat2int(a)

    @arguments("i", returns="f")
    def bhimpl_cast_singlefloat_to_float(a):
        a = longlong.int2singlefloat(a)
        a = float(a)
        return longlong.getfloatstorage(a)

    @arguments("f", returns=LONGLONG_TYPECODE)
    def bhimpl_convert_float_bytes_to_longlong(a):
        a = longlong.getrealfloat(a)
        return longlong2float.float2longlong(a)

    @arguments(LONGLONG_TYPECODE, returns="f")
    def bhimpl_convert_longlong_bytes_to_float(a):
        a = longlong2float.longlong2float(a)
        return longlong.getfloatstorage(a)

    # ----------
    # control flow operations

    @arguments("self", "i")
    def bhimpl_int_return(self, a):
        self.tmpreg_i = a
        self._return_type = 'i'
        raise LeaveFrame

    @arguments("self", "r")
    def bhimpl_ref_return(self, a):
        self.tmpreg_r = a
        self._return_type = 'r'
        raise LeaveFrame

    @arguments("self", "f")
    def bhimpl_float_return(self, a):
        self.tmpreg_f = a
        self._return_type = 'f'
        raise LeaveFrame

    @arguments("self")
    def bhimpl_void_return(self):
        self._return_type = 'v'
        raise LeaveFrame

    @arguments("i", "L", "pc", returns="L")
    def bhimpl_goto_if_not(a, target, pc):
        if a:
            return pc
        else:
            return target

    @arguments("i", "i", "L", "pc", returns="L")
    def bhimpl_goto_if_not_int_lt(a, b, target, pc):
        if a < b:
            return pc
        else:
            return target

    @arguments("i", "i", "L", "pc", returns="L")
    def bhimpl_goto_if_not_int_le(a, b, target, pc):
        if a <= b:
            return pc
        else:
            return target

    @arguments("i", "i", "L", "pc", returns="L")
    def bhimpl_goto_if_not_int_eq(a, b, target, pc):
        if a == b:
            return pc
        else:
            return target

    @arguments("i", "i", "L", "pc", returns="L")
    def bhimpl_goto_if_not_int_ne(a, b, target, pc):
        if a != b:
            return pc
        else:
            return target

    @arguments("i", "i", "L", "pc", returns="L")
    def bhimpl_goto_if_not_int_gt(a, b, target, pc):
        if a > b:
            return pc
        else:
            return target

    @arguments("i", "i", "L", "pc", returns="L")
    def bhimpl_goto_if_not_int_ge(a, b, target, pc):
        if a >= b:
            return pc
        else:
            return target

    bhimpl_goto_if_not_int_is_true = bhimpl_goto_if_not

    @arguments("i", "L", "pc", returns="L")
    def bhimpl_goto_if_not_int_is_zero(a, target, pc):
        if not a:
            return pc
        else:
            return target

    @arguments("r", "r", "L", "pc", returns="L")
    def bhimpl_goto_if_not_ptr_eq(a, b, target, pc):
        if a == b:
            return pc
        else:
            return target

    @arguments("r", "r", "L", "pc", returns="L")
    def bhimpl_goto_if_not_ptr_ne(a, b, target, pc):
        if a != b:
            return pc
        else:
            return target

    @arguments("r", "L", "pc", returns="L")
    def bhimpl_goto_if_not_ptr_iszero(a, target, pc):
        if not a:
            return pc
        else:
            return target

    @arguments("r", "L", "pc", returns="L")
    def bhimpl_goto_if_not_ptr_nonzero(a, target, pc):
        if a:
            return pc
        else:
            return target

    @arguments("L", returns="L")
    def bhimpl_goto(target):
        return target

    @arguments("i", "d", "pc", returns="L")
    def bhimpl_switch(switchvalue, switchdict, pc):
        assert isinstance(switchdict, SwitchDictDescr)
        try:
            return switchdict.dict[switchvalue]
        except KeyError:
            return pc

    @arguments()
    def bhimpl_unreachable():
        raise AssertionError("unreachable")

    # ----------
    # exception handling operations

    @arguments("L")
    def bhimpl_catch_exception(target):
        """This is a no-op when run normally.  When an exception occurs
        and the instruction that raised is immediately followed by a
        catch_exception, then the code in handle_exception_in_frame()
        will capture the exception and jump to 'target'."""

    @arguments("self", "i", "L", "pc", returns="L")
    def bhimpl_goto_if_exception_mismatch(self, vtable, target, pc):
        adr = int2adr(vtable)
        bounding_class = llmemory.cast_adr_to_ptr(adr, rclass.CLASSTYPE)
        real_instance = self.exception_last_value
        assert real_instance
        if rclass.ll_issubclass(real_instance.typeptr, bounding_class):
            return pc
        else:
            return target

    @arguments("self", returns="i")
    def bhimpl_last_exception(self):
        real_instance = self.exception_last_value
        assert real_instance
        return ptr2int(real_instance.typeptr)

    @arguments("self", returns="r")
    def bhimpl_last_exc_value(self):
        real_instance = self.exception_last_value
        assert real_instance
        return lltype.cast_opaque_ptr(llmemory.GCREF, real_instance)

    @arguments("self", "r")
    def bhimpl_raise(self, excvalue):
        e = lltype.cast_opaque_ptr(rclass.OBJECTPTR, excvalue)
        assert e
        reraise(e)

    @arguments("self")
    def bhimpl_reraise(self):
        e = self.exception_last_value
        assert e
        reraise(e)

    @arguments("r")
    def bhimpl_debug_fatalerror(msg):
        from rpython.rtyper.lltypesystem import rstr
        msg = lltype.cast_opaque_ptr(lltype.Ptr(rstr.STR), msg)
        llop.debug_fatalerror(lltype.Void, msg)

    @arguments("r", "i", "i", "i", "i")
    def bhimpl_jit_debug(string, arg1=0, arg2=0, arg3=0, arg4=0):
        pass

    @arguments("i")
    def bhimpl_jit_enter_portal_frame(x):
        pass

    @arguments()
    def bhimpl_jit_leave_portal_frame():
        pass

    @arguments("i")
    def bhimpl_int_assert_green(x):
        pass
    @arguments("r")
    def bhimpl_ref_assert_green(x):
        pass
    @arguments("f")
    def bhimpl_float_assert_green(x):
        pass

    @arguments(returns="i")
    def bhimpl_current_trace_length():
        return -1

    @arguments("i", returns="i")
    def bhimpl_int_isconstant(x):
        return False

    @arguments("f", returns="i")
    def bhimpl_float_isconstant(x):
        return False

    @arguments("r", returns="i")
    def bhimpl_ref_isconstant(x):
        return False

    @arguments("r", returns="i")
    def bhimpl_ref_isvirtual(x):
        return False

    # ----------
    # the main hints and recursive calls

    @arguments("i")
    def bhimpl_loop_header(jdindex):
        pass

    @arguments("self", "i", "I", "R", "F", "I", "R", "F")
    def bhimpl_jit_merge_point(self, jdindex, *args):
        if self.nextblackholeinterp is None:    # we are the last level
            raise jitexc.ContinueRunningNormally(*args)
            # Note that the case above is an optimization: the case
            # below would work too.  But it keeps unnecessary stuff on
            # the stack; the solution above first gets rid of the blackhole
            # interpreter completely.
        else:
            # This occurs when we reach 'jit_merge_point' in the portal
            # function called by recursion.  In this case, we can directly
            # call the interpreter main loop from here, and just return its
            # result.
            sd = self.builder.metainterp_sd
            result_type = sd.jitdrivers_sd[jdindex].result_type
            if result_type == 'v':
                self.bhimpl_recursive_call_v(jdindex, *args)
                self.bhimpl_void_return()
            elif result_type == 'i':
                x = self.bhimpl_recursive_call_i(jdindex, *args)
                self.bhimpl_int_return(x)
            elif result_type == 'r':
                x = self.bhimpl_recursive_call_r(jdindex, *args)
                self.bhimpl_ref_return(x)
            elif result_type == 'f':
                x = self.bhimpl_recursive_call_f(jdindex, *args)
                self.bhimpl_float_return(x)
            assert False

    def get_portal_runner(self, jdindex):
        jitdriver_sd = self.builder.metainterp_sd.jitdrivers_sd[jdindex]
        fnptr = adr2int(jitdriver_sd.portal_runner_adr)
        calldescr = jitdriver_sd.mainjitcode.calldescr
        return fnptr, calldescr

    @arguments("self", "i", "I", "R", "F", "I", "R", "F", returns="i")
    def bhimpl_recursive_call_i(self, jdindex, greens_i, greens_r, greens_f,
                                               reds_i,   reds_r,   reds_f):
        fnptr, calldescr = self.get_portal_runner(jdindex)
        return self.cpu.bh_call_i(fnptr,
                                  greens_i + reds_i,
                                  greens_r + reds_r,
                                  greens_f + reds_f, calldescr)
    @arguments("self", "i", "I", "R", "F", "I", "R", "F", returns="r")
    def bhimpl_recursive_call_r(self, jdindex, greens_i, greens_r, greens_f,
                                               reds_i,   reds_r,   reds_f):
        fnptr, calldescr = self.get_portal_runner(jdindex)
        return self.cpu.bh_call_r(fnptr,
                                  greens_i + reds_i,
                                  greens_r + reds_r,
                                  greens_f + reds_f, calldescr)
    @arguments("self", "i", "I", "R", "F", "I", "R", "F", returns="f")
    def bhimpl_recursive_call_f(self, jdindex, greens_i, greens_r, greens_f,
                                               reds_i,   reds_r,   reds_f):
        fnptr, calldescr = self.get_portal_runner(jdindex)
        return self.cpu.bh_call_f(fnptr,
                                  greens_i + reds_i,
                                  greens_r + reds_r,
                                  greens_f + reds_f, calldescr)
    @arguments("self", "i", "I", "R", "F", "I", "R", "F")
    def bhimpl_recursive_call_v(self, jdindex, greens_i, greens_r, greens_f,
                                               reds_i,   reds_r,   reds_f):
        fnptr, calldescr = self.get_portal_runner(jdindex)
        return self.cpu.bh_call_v(fnptr,
                                  greens_i + reds_i,
                                  greens_r + reds_r,
                                  greens_f + reds_f, calldescr)

    # ----------
    # virtual refs

    @arguments("r", returns="r")
    def bhimpl_virtual_ref(a):
        return a

    @arguments("r")
    def bhimpl_virtual_ref_finish(a):
        pass

    # ----------
    # list operations

    @arguments("cpu", "r", "i", "d", returns="i")
    def bhimpl_check_neg_index(cpu, array, index, arraydescr):
        if index < 0:
            index += cpu.bh_arraylen_gc(array, arraydescr)
        return index

    @arguments("cpu", "r", "i", "d", returns="i")
    def bhimpl_check_resizable_neg_index(cpu, lst, index, lengthdescr):
        if index < 0:
            index += cpu.bh_getfield_gc_i(lst, lengthdescr)
        return index

    @arguments("cpu", "i", "d", "d", "d", "d", returns="r")
    def bhimpl_newlist(cpu, length, structdescr, lengthdescr,
                       itemsdescr, arraydescr):
        result = cpu.bh_new(structdescr)
        cpu.bh_setfield_gc_i(result, length, lengthdescr)
        if (arraydescr.is_array_of_structs() or
            arraydescr.is_array_of_pointers()):
            items = cpu.bh_new_array_clear(length, arraydescr)
        else:
            items = cpu.bh_new_array(length, arraydescr)
        cpu.bh_setfield_gc_r(result, items, itemsdescr)
        return result

    @arguments("cpu", "i", "d", "d", "d", "d", returns="r")
    def bhimpl_newlist_clear(cpu, length, structdescr, lengthdescr,
                             itemsdescr, arraydescr):
        result = cpu.bh_new(structdescr)
        cpu.bh_setfield_gc_i(result, length, lengthdescr)
        items = cpu.bh_new_array_clear(length, arraydescr)
        cpu.bh_setfield_gc_r(result, items, itemsdescr)
        return result

    @arguments("cpu", "i", "d", "d", "d", "d", returns="r")
    def bhimpl_newlist_hint(cpu, lengthhint, structdescr, lengthdescr,
                            itemsdescr, arraydescr):
        result = cpu.bh_new(structdescr)
        cpu.bh_setfield_gc_i(result, 0, lengthdescr)
        if (arraydescr.is_array_of_structs() or
            arraydescr.is_array_of_pointers()):
            items = cpu.bh_new_array_clear(lengthhint, arraydescr)
        else:
            items = cpu.bh_new_array(lengthhint, arraydescr)
        cpu.bh_setfield_gc_r(result, items, itemsdescr)
        return result

    @arguments("cpu", "r", "i", "d", "d", returns="i")
    def bhimpl_getlistitem_gc_i(cpu, lst, index, itemsdescr, arraydescr):
        items = cpu.bh_getfield_gc_r(lst, itemsdescr)
        return cpu.bh_getarrayitem_gc_i(items, index, arraydescr)
    @arguments("cpu", "r", "i", "d", "d", returns="r")
    def bhimpl_getlistitem_gc_r(cpu, lst, index, itemsdescr, arraydescr):
        items = cpu.bh_getfield_gc_r(lst, itemsdescr)
        return cpu.bh_getarrayitem_gc_r(items, index, arraydescr)
    @arguments("cpu", "r", "i", "d", "d", returns="f")
    def bhimpl_getlistitem_gc_f(cpu, lst, index, itemsdescr, arraydescr):
        items = cpu.bh_getfield_gc_r(lst, itemsdescr)
        return cpu.bh_getarrayitem_gc_f(items, index, arraydescr)

    @arguments("cpu", "r", "i", "i", "d", "d")
    def bhimpl_setlistitem_gc_i(cpu, lst, index, nval, itemsdescr, arraydescr):
        items = cpu.bh_getfield_gc_r(lst, itemsdescr)
        cpu.bh_setarrayitem_gc_i(items, index, nval, arraydescr)
    @arguments("cpu", "r", "i", "r", "d", "d")
    def bhimpl_setlistitem_gc_r(cpu, lst, index, nval, itemsdescr, arraydescr):
        items = cpu.bh_getfield_gc_r(lst, itemsdescr)
        cpu.bh_setarrayitem_gc_r(items, index, nval, arraydescr)
    @arguments("cpu", "r", "i", "f", "d", "d")
    def bhimpl_setlistitem_gc_f(cpu, lst, index, nval, itemsdescr, arraydescr):
        items = cpu.bh_getfield_gc_r(lst, itemsdescr)
        cpu.bh_setarrayitem_gc_f(items, index, nval, arraydescr)

    # ----------
    # the following operations are directly implemented by the backend

    @arguments("cpu", "i", "R", "d", returns="i")
    def bhimpl_residual_call_r_i(cpu, func, args_r, calldescr):
        return cpu.bh_call_i(func, None, args_r, None, calldescr)
    @arguments("cpu", "i", "R", "d", returns="r")
    def bhimpl_residual_call_r_r(cpu, func, args_r, calldescr):
        return cpu.bh_call_r(func, None, args_r, None, calldescr)
    @arguments("cpu", "i", "R", "d")
    def bhimpl_residual_call_r_v(cpu, func, args_r, calldescr):
        return cpu.bh_call_v(func, None, args_r, None, calldescr)

    @arguments("cpu", "i", "I", "R", "d", returns="i")
    def bhimpl_residual_call_ir_i(cpu, func, args_i, args_r, calldescr):
        return cpu.bh_call_i(func, args_i, args_r, None, calldescr)
    @arguments("cpu", "i", "I", "R", "d", returns="r")
    def bhimpl_residual_call_ir_r(cpu, func, args_i, args_r, calldescr):
        return cpu.bh_call_r(func, args_i, args_r, None, calldescr)
    @arguments("cpu", "i", "I", "R", "d")
    def bhimpl_residual_call_ir_v(cpu, func, args_i, args_r, calldescr):
        return cpu.bh_call_v(func, args_i, args_r, None, calldescr)

    @arguments("cpu", "i", "I", "R", "F", "d", returns="i")
    def bhimpl_residual_call_irf_i(cpu, func, args_i,args_r,args_f,calldescr):
        return cpu.bh_call_i(func, args_i, args_r, args_f, calldescr)
    @arguments("cpu", "i", "I", "R", "F", "d", returns="r")
    def bhimpl_residual_call_irf_r(cpu, func, args_i,args_r,args_f,calldescr):
        return cpu.bh_call_r(func, args_i, args_r, args_f, calldescr)
    @arguments("cpu", "i", "I", "R", "F", "d", returns="f")
    def bhimpl_residual_call_irf_f(cpu, func, args_i,args_r,args_f,calldescr):
        return cpu.bh_call_f(func, args_i, args_r, args_f, calldescr)
    @arguments("cpu", "i", "I", "R", "F", "d")
    def bhimpl_residual_call_irf_v(cpu, func, args_i,args_r,args_f,calldescr):
        return cpu.bh_call_v(func, args_i, args_r, args_f, calldescr)

    @arguments("cpu", "i", "i", "I", "R", "d")
    def bhimpl_conditional_call_ir_v(cpu, condition, func, args_i, args_r,
                                     calldescr):
        # conditional calls - condition is a flag, and they cannot return stuff
        if condition:
            cpu.bh_call_v(func, args_i, args_r, None, calldescr)

    @arguments("cpu", "i", "i", "I", "R", "d", returns="i")
    def bhimpl_conditional_call_value_ir_i(cpu, value, func, args_i, args_r,
                                           calldescr):
        if value == 0:
            value = cpu.bh_call_i(func, args_i, args_r, None, calldescr)
        return value

    @arguments("cpu", "r", "i", "I", "R", "d", returns="r")
    def bhimpl_conditional_call_value_ir_r(cpu, value, func, args_i, args_r,
                                           calldescr):
        if not value:
            value = cpu.bh_call_r(func, args_i, args_r, None, calldescr)
        return value

    @arguments("cpu", "j", "R", returns="i")
    def bhimpl_inline_call_r_i(cpu, jitcode, args_r):
        return cpu.bh_call_i(adr2int(jitcode.fnaddr),
                             None, args_r, None, jitcode.calldescr)
    @arguments("cpu", "j", "R", returns="r")
    def bhimpl_inline_call_r_r(cpu, jitcode, args_r):
        return cpu.bh_call_r(adr2int(jitcode.fnaddr),
                             None, args_r, None, jitcode.calldescr)
    @arguments("cpu", "j", "R")
    def bhimpl_inline_call_r_v(cpu, jitcode, args_r):
        return cpu.bh_call_v(adr2int(jitcode.fnaddr),
                             None, args_r, None, jitcode.calldescr)

    @arguments("cpu", "j", "I", "R", returns="i")
    def bhimpl_inline_call_ir_i(cpu, jitcode, args_i, args_r):
        return cpu.bh_call_i(adr2int(jitcode.fnaddr),
                             args_i, args_r, None, jitcode.calldescr)
    @arguments("cpu", "j", "I", "R", returns="r")
    def bhimpl_inline_call_ir_r(cpu, jitcode, args_i, args_r):
        return cpu.bh_call_r(adr2int(jitcode.fnaddr),
                             args_i, args_r, None, jitcode.calldescr)
    @arguments("cpu", "j", "I", "R")
    def bhimpl_inline_call_ir_v(cpu, jitcode, args_i, args_r):
        return cpu.bh_call_v(adr2int(jitcode.fnaddr),
                             args_i, args_r, None, jitcode.calldescr)

    @arguments("cpu", "j", "I", "R", "F", returns="i")
    def bhimpl_inline_call_irf_i(cpu, jitcode, args_i, args_r, args_f):
        return cpu.bh_call_i(adr2int(jitcode.fnaddr),
                             args_i, args_r, args_f, jitcode.calldescr)
    @arguments("cpu", "j", "I", "R", "F", returns="r")
    def bhimpl_inline_call_irf_r(cpu, jitcode, args_i, args_r, args_f):
        return cpu.bh_call_r(adr2int(jitcode.fnaddr),
                             args_i, args_r, args_f, jitcode.calldescr)
    @arguments("cpu", "j", "I", "R", "F", returns="f")
    def bhimpl_inline_call_irf_f(cpu, jitcode, args_i, args_r, args_f):
        return cpu.bh_call_f(adr2int(jitcode.fnaddr),
                             args_i, args_r, args_f, jitcode.calldescr)
    @arguments("cpu", "j", "I", "R", "F")
    def bhimpl_inline_call_irf_v(cpu, jitcode, args_i, args_r, args_f):
        return cpu.bh_call_v(adr2int(jitcode.fnaddr),
                             args_i, args_r, args_f, jitcode.calldescr)

    @arguments("cpu", "i", "d", returns="r")
    def bhimpl_new_array(cpu, length, arraydescr):
        return cpu.bh_new_array(length, arraydescr)

    @arguments("cpu", "i", "d", returns="r")
    def bhimpl_new_array_clear(cpu, length, arraydescr):
        return cpu.bh_new_array_clear(length, arraydescr)

    @arguments("cpu", "r", "i", "d", returns="i")
    def bhimpl_getarrayitem_gc_i(cpu, array, index, arraydescr):
        return cpu.bh_getarrayitem_gc_i(array, index, arraydescr)
    @arguments("cpu", "r", "i", "d", returns="r")
    def bhimpl_getarrayitem_gc_r(cpu, array, index, arraydescr):
        return cpu.bh_getarrayitem_gc_r(array, index, arraydescr)
    @arguments("cpu", "r", "i", "d", returns="f")
    def bhimpl_getarrayitem_gc_f(cpu, array, index, arraydescr):
        return cpu.bh_getarrayitem_gc_f(array, index, arraydescr)

    bhimpl_getarrayitem_gc_i_pure = bhimpl_getarrayitem_gc_i
    bhimpl_getarrayitem_gc_r_pure = bhimpl_getarrayitem_gc_r
    bhimpl_getarrayitem_gc_f_pure = bhimpl_getarrayitem_gc_f

    @arguments("cpu", "i", "i", "d", returns="i")
    def bhimpl_getarrayitem_raw_i(cpu, array, index, arraydescr):
        return cpu.bh_getarrayitem_raw_i(array, index, arraydescr)
    @arguments("cpu", "i", "i", "d", returns="f")
    def bhimpl_getarrayitem_raw_f(cpu, array, index, arraydescr):
        return cpu.bh_getarrayitem_raw_f(array, index, arraydescr)

    @arguments("cpu", "r", "i", "i", "d")
    def bhimpl_setarrayitem_gc_i(cpu, array, index, newvalue, arraydescr):
        cpu.bh_setarrayitem_gc_i(array, index, newvalue, arraydescr)
    @arguments("cpu", "r", "i", "r", "d")
    def bhimpl_setarrayitem_gc_r(cpu, array, index, newvalue, arraydescr):
        cpu.bh_setarrayitem_gc_r(array, index, newvalue, arraydescr)
    @arguments("cpu", "r", "i", "f", "d")
    def bhimpl_setarrayitem_gc_f(cpu, array, index, newvalue, arraydescr):
        cpu.bh_setarrayitem_gc_f(array, index, newvalue, arraydescr)

    @arguments("cpu", "i", "i", "i", "d")
    def bhimpl_setarrayitem_raw_i(cpu, array, index, newvalue, arraydescr):
        cpu.bh_setarrayitem_raw_i(array, index, newvalue, arraydescr)
    @arguments("cpu", "i", "i", "f", "d")
    def bhimpl_setarrayitem_raw_f(cpu, array, index, newvalue, arraydescr):
        cpu.bh_setarrayitem_raw_f(array, index, newvalue, arraydescr)

    # note, there is no 'r' here, since it can't happen

    @arguments("cpu", "r", "d", returns="i")
    def bhimpl_arraylen_gc(cpu, array, arraydescr):
        return cpu.bh_arraylen_gc(array, arraydescr)

    @arguments("cpu", "r", "i", "d", "d", returns="i")
    def bhimpl_getarrayitem_vable_i(cpu, vable, index, fielddescr, arraydescr):
        fielddescr.get_vinfo().clear_vable_token(vable)
        array = cpu.bh_getfield_gc_r(vable, fielddescr)
        return cpu.bh_getarrayitem_gc_i(array, index, arraydescr)
    @arguments("cpu", "r", "i", "d", "d", returns="r")
    def bhimpl_getarrayitem_vable_r(cpu, vable, index, fielddescr, arraydescr):
        fielddescr.get_vinfo().clear_vable_token(vable)
        array = cpu.bh_getfield_gc_r(vable, fielddescr)
        return cpu.bh_getarrayitem_gc_r(array, index, arraydescr)
    @arguments("cpu", "r", "i", "d", "d", returns="f")
    def bhimpl_getarrayitem_vable_f(cpu, vable, index, fielddescr, arraydescr):
        fielddescr.get_vinfo().clear_vable_token(vable)
        array = cpu.bh_getfield_gc_r(vable, fielddescr)
        return cpu.bh_getarrayitem_gc_f(array, index, arraydescr)

    @arguments("cpu", "r", "i", "i", "d", "d")
    def bhimpl_setarrayitem_vable_i(cpu, vable, index, newval, fdescr, adescr):
        fdescr.get_vinfo().clear_vable_token(vable)
        array = cpu.bh_getfield_gc_r(vable, fdescr)
        cpu.bh_setarrayitem_gc_i(array, index, newval, adescr)
    @arguments("cpu", "r", "i", "r", "d", "d")
    def bhimpl_setarrayitem_vable_r(cpu, vable, index, newval, fdescr, adescr):
        fdescr.get_vinfo().clear_vable_token(vable)
        array = cpu.bh_getfield_gc_r(vable, fdescr)
        cpu.bh_setarrayitem_gc_r(array, index, newval, adescr)
    @arguments("cpu", "r", "i", "f", "d", "d")
    def bhimpl_setarrayitem_vable_f(cpu, vable, index, newval, fdescr, adescr):
        fdescr.get_vinfo().clear_vable_token(vable)
        array = cpu.bh_getfield_gc_r(vable, fdescr)
        cpu.bh_setarrayitem_gc_f(array, index, newval, adescr)

    @arguments("cpu", "r", "d", "d", returns="i")
    def bhimpl_arraylen_vable(cpu, vable, fdescr, adescr):
        fdescr.get_vinfo().clear_vable_token(vable)
        array = cpu.bh_getfield_gc_r(vable, fdescr)
        return cpu.bh_arraylen_gc(array, adescr)

    @arguments("cpu", "r", "i", "d", returns="i")
    def bhimpl_getinteriorfield_gc_i(cpu, array, index, descr):
        return cpu.bh_getinteriorfield_gc_i(array, index, descr)
    @arguments("cpu", "r", "i", "d", returns="r")
    def bhimpl_getinteriorfield_gc_r(cpu, array, index, descr):
        return cpu.bh_getinteriorfield_gc_r(array, index, descr)
    @arguments("cpu", "r", "i", "d", returns="f")
    def bhimpl_getinteriorfield_gc_f(cpu, array, index, descr):
        return cpu.bh_getinteriorfield_gc_f(array, index, descr)

    @arguments("cpu", "r", "i", "i", "d")
    def bhimpl_setinteriorfield_gc_i(cpu, array, index, value, descr):
        cpu.bh_setinteriorfield_gc_i(array, index, value, descr)
    @arguments("cpu", "r", "i", "r", "d")
    def bhimpl_setinteriorfield_gc_r(cpu, array, index, value, descr):
        cpu.bh_setinteriorfield_gc_r(array, index, value, descr)
    @arguments("cpu", "r", "i", "f", "d")
    def bhimpl_setinteriorfield_gc_f(cpu, array, index, value, descr):
        cpu.bh_setinteriorfield_gc_f(array, index, value, descr)

    @arguments("cpu", "r", "d", returns="i")
    def bhimpl_getfield_gc_i(cpu, struct, fielddescr):
        return cpu.bh_getfield_gc_i(struct, fielddescr)
    @arguments("cpu", "r", "d", returns="r")
    def bhimpl_getfield_gc_r(cpu, struct, fielddescr):
        return cpu.bh_getfield_gc_r(struct, fielddescr)
    @arguments("cpu", "r", "d", returns="f")
    def bhimpl_getfield_gc_f(cpu, struct, fielddescr):
        return cpu.bh_getfield_gc_f(struct, fielddescr)

    bhimpl_getfield_gc_i_pure = bhimpl_getfield_gc_i
    bhimpl_getfield_gc_r_pure = bhimpl_getfield_gc_r
    bhimpl_getfield_gc_f_pure = bhimpl_getfield_gc_f

    @arguments("cpu", "r", "d", returns="i")
    def bhimpl_getfield_vable_i(cpu, struct, fielddescr):
        fielddescr.get_vinfo().clear_vable_token(struct)
        return cpu.bh_getfield_gc_i(struct, fielddescr)

    @arguments("cpu", "r", "d", returns="r")
    def bhimpl_getfield_vable_r(cpu, struct, fielddescr):
        fielddescr.get_vinfo().clear_vable_token(struct)
        return cpu.bh_getfield_gc_r(struct, fielddescr)

    @arguments("cpu", "r", "d", returns="f")
    def bhimpl_getfield_vable_f(cpu, struct, fielddescr):
        fielddescr.get_vinfo().clear_vable_token(struct)
        return cpu.bh_getfield_gc_f(struct, fielddescr)

    bhimpl_getfield_gc_i_greenfield = bhimpl_getfield_gc_i
    bhimpl_getfield_gc_r_greenfield = bhimpl_getfield_gc_r
    bhimpl_getfield_gc_f_greenfield = bhimpl_getfield_gc_f

    @arguments("cpu", "i", "d", returns="i")
    def bhimpl_getfield_raw_i(cpu, struct, fielddescr):
        return cpu.bh_getfield_raw_i(struct, fielddescr)
    @arguments("cpu", "i", "d", returns="r")
    def bhimpl_getfield_raw_r(cpu, struct, fielddescr):   # for pure only
        return cpu.bh_getfield_raw_r(struct, fielddescr)
    @arguments("cpu", "i", "d", returns="f")
    def bhimpl_getfield_raw_f(cpu, struct, fielddescr):
        return cpu.bh_getfield_raw_f(struct, fielddescr)

    @arguments("cpu", "r", "i", "d")
    def bhimpl_setfield_gc_i(cpu, struct, newvalue, fielddescr):
        cpu.bh_setfield_gc_i(struct, newvalue, fielddescr)
    @arguments("cpu", "r", "r", "d")
    def bhimpl_setfield_gc_r(cpu, struct, newvalue, fielddescr):
        cpu.bh_setfield_gc_r(struct, newvalue, fielddescr)
    @arguments("cpu", "r", "f", "d")
    def bhimpl_setfield_gc_f(cpu, struct, newvalue, fielddescr):
        cpu.bh_setfield_gc_f(struct, newvalue, fielddescr)

    @arguments("cpu", "r", "i", "d")
    def bhimpl_setfield_vable_i(cpu, struct, newvalue, fielddescr):
        fielddescr.get_vinfo().clear_vable_token(struct)
        cpu.bh_setfield_gc_i(struct, newvalue, fielddescr)
    @arguments("cpu", "r", "r", "d")
    def bhimpl_setfield_vable_r(cpu, struct, newvalue, fielddescr):
        fielddescr.get_vinfo().clear_vable_token(struct)
        cpu.bh_setfield_gc_r(struct, newvalue, fielddescr)
    @arguments("cpu", "r", "f", "d")
    def bhimpl_setfield_vable_f(cpu, struct, newvalue, fielddescr):
        fielddescr.get_vinfo().clear_vable_token(struct)
        cpu.bh_setfield_gc_f(struct, newvalue, fielddescr)

    @arguments("cpu", "i", "i", "d")
    def bhimpl_setfield_raw_i(cpu, struct, newvalue, fielddescr):
        cpu.bh_setfield_raw_i(struct, newvalue, fielddescr)
    @arguments("cpu", "i", "f", "d")
    def bhimpl_setfield_raw_f(cpu, struct, newvalue, fielddescr):
        cpu.bh_setfield_raw_f(struct, newvalue, fielddescr)

    @arguments("cpu", "i", "i", "i", "d")
    def bhimpl_raw_store_i(cpu, addr, offset, newvalue, arraydescr):
        cpu.bh_raw_store_i(addr, offset, newvalue, arraydescr)
    @arguments("cpu", "i", "i", "f", "d")
    def bhimpl_raw_store_f(cpu, addr, offset, newvalue, arraydescr):
        cpu.bh_raw_store_f(addr, offset, newvalue, arraydescr)

    @arguments("cpu", "i", "i", "d", returns="i")
    def bhimpl_raw_load_i(cpu, addr, offset, arraydescr):
        return cpu.bh_raw_load_i(addr, offset, arraydescr)
    @arguments("cpu", "i", "i", "d", returns="f")
    def bhimpl_raw_load_f(cpu, addr, offset, arraydescr):
        return cpu.bh_raw_load_f(addr, offset, arraydescr)

    @arguments("cpu", "r", "i", "i", "i", "i", returns="i")
    def bhimpl_gc_load_indexed_i(cpu, addr, index, scale, base_ofs, bytes):
        return cpu.bh_gc_load_indexed_i(addr, index,scale,base_ofs, bytes)
    @arguments("cpu", "r", "i", "i", "i", "i", returns="f")
    def bhimpl_gc_load_indexed_f(cpu, addr, index, scale, base_ofs, bytes):
        return cpu.bh_gc_load_indexed_f(addr, index,scale,base_ofs, bytes)

    @arguments("cpu", "r", "i", "i", "i", "i", "i", "d")
    def bhimpl_gc_store_indexed_i(cpu, addr, index, val, scale, base_ofs, bytes,
                                  arraydescr):
        return cpu.bh_gc_store_indexed_i(addr, index, val, scale,base_ofs, bytes,
                                         arraydescr)

    @arguments("cpu", "r", "i", "f", "i", "i", "i", "d")
    def bhimpl_gc_store_indexed_f(cpu, addr, index, val, scale, base_ofs, bytes,
                                  arraydescr):
        return cpu.bh_gc_store_indexed_f(addr, index, val, scale,base_ofs, bytes,
                                         arraydescr)

    @arguments("r", "d", "d")
    def bhimpl_record_quasiimmut_field(struct, fielddescr, mutatefielddescr):
        pass

    @arguments("cpu", "r", "d")
    def bhimpl_jit_force_quasi_immutable(cpu, struct, mutatefielddescr):
        from rpython.jit.metainterp import quasiimmut
        quasiimmut.do_force_quasi_immutable(cpu, struct, mutatefielddescr)

    @arguments("r")
    def bhimpl_hint_force_virtualizable(r):
        pass

    @arguments("cpu", "d", returns="r")
    def bhimpl_new(cpu, descr):
        return cpu.bh_new(descr)

    @arguments("cpu", "d", returns="r")
    def bhimpl_new_with_vtable(cpu, descr):
        return cpu.bh_new_with_vtable(descr)

    @arguments("cpu", "r", returns="i")
    def bhimpl_guard_class(cpu, struct):
        return cpu.bh_classof(struct)

    @arguments("cpu", "i", returns="r")
    def bhimpl_newstr(cpu, length):
        return cpu.bh_newstr(length)
    @arguments("cpu", "r", returns="i")
    def bhimpl_strlen(cpu, string):
        return cpu.bh_strlen(string)
    @arguments("cpu", "r", "i", returns="i")
    def bhimpl_strgetitem(cpu, string, index):
        return cpu.bh_strgetitem(string, index)
    @arguments("cpu", "r", "i", "i")
    def bhimpl_strsetitem(cpu, string, index, newchr):
        cpu.bh_strsetitem(string, index, newchr)
    @arguments("cpu", "r", "r", "i", "i", "i")
    def bhimpl_copystrcontent(cpu, src, dst, srcstart, dststart, length):
        cpu.bh_copystrcontent(src, dst, srcstart, dststart, length)
    @arguments("cpu", "r", returns="i")
    def bhimpl_strhash(cpu, string):
        return cpu.bh_strhash(string)

    @arguments("cpu", "i", returns="r")
    def bhimpl_newunicode(cpu, length):
        return cpu.bh_newunicode(length)
    @arguments("cpu", "r", returns="i")
    def bhimpl_unicodelen(cpu, unicode):
        return cpu.bh_unicodelen(unicode)
    @arguments("cpu", "r", "i", returns="i")
    def bhimpl_unicodegetitem(cpu, unicode, index):
        return cpu.bh_unicodegetitem(unicode, index)
    @arguments("cpu", "r", "i", "i")
    def bhimpl_unicodesetitem(cpu, unicode, index, newchr):
        cpu.bh_unicodesetitem(unicode, index, newchr)
    @arguments("cpu", "r", "r", "i", "i", "i")
    def bhimpl_copyunicodecontent(cpu, src, dst, srcstart, dststart, length):
        cpu.bh_copyunicodecontent(src, dst, srcstart, dststart, length)
    @arguments("cpu", "r", returns="i")
    def bhimpl_unicodehash(cpu, unicode):
        return cpu.bh_unicodehash(unicode)

    @arguments("i", "i")
    def bhimpl_rvmprof_code(leaving, unique_id):
        from rpython.rlib.rvmprof import cintf
        cintf.jit_rvmprof_code(leaving, unique_id)

    # ----------
    # helpers to resume running in blackhole mode when a guard failed

    def _resume_mainloop(self, current_exc):
        assert lltype.typeOf(current_exc) == rclass.OBJECTPTR
        try:
            # if there is a current exception, raise it now
            # (it may be caught by a catch_operation in this frame)
            if current_exc:
                self.handle_exception_in_frame(current_exc)
            # unless the call above raised again the exception,
            # we now proceed to interpret the bytecode in this frame
            self.run()
        #
        except jitexc.JitException as e:
            raise     # go through
        except Exception as e:
            # if we get an exception, return it to the caller frame
            current_exc = get_llexception(self.cpu, e)
            if not self.nextblackholeinterp:
                self._exit_frame_with_exception(current_exc)
            return current_exc
        #
        # pass the frame's return value to the caller
        caller = self.nextblackholeinterp
        if not caller:
            self._done_with_this_frame()
        kind = self._return_type
        if kind == 'i':
            caller._setup_return_value_i(self.get_tmpreg_i())
        elif kind == 'r':
            caller._setup_return_value_r(self.get_tmpreg_r())
        elif kind == 'f':
            caller._setup_return_value_f(self.get_tmpreg_f())
        else:
            assert kind == 'v'
        return lltype.nullptr(rclass.OBJECTPTR.TO)

    def _prepare_resume_from_failure(self, deadframe):
        return lltype.cast_opaque_ptr(rclass.OBJECTPTR,
                                        self.cpu.grab_exc_value(deadframe))

    # connect the return of values from the called frame to the
    # 'xxx_call_yyy' instructions from the caller frame
    def _setup_return_value_i(self, result):
        assert lltype.typeOf(result) is lltype.Signed
        self.registers_i[ord(self.jitcode.code[self.position-1])] = plain_int(
                                                                        result)
    def _setup_return_value_r(self, result):
        assert lltype.typeOf(result) == llmemory.GCREF
        self.registers_r[ord(self.jitcode.code[self.position-1])] = result
    def _setup_return_value_f(self, result):
        assert lltype.typeOf(result) is longlong.FLOATSTORAGE
        self.registers_f[ord(self.jitcode.code[self.position-1])] = result

    def _done_with_this_frame(self):
        # rare case: we only get there if the blackhole interps all returned
        # normally (in general we get a ContinueRunningNormally exception).
        kind = self._return_type
        if kind == 'v':
            raise jitexc.DoneWithThisFrameVoid()
        elif kind == 'i':
            raise jitexc.DoneWithThisFrameInt(self.get_tmpreg_i())
        elif kind == 'r':
            raise jitexc.DoneWithThisFrameRef(self.get_tmpreg_r())
        elif kind == 'f':
            raise jitexc.DoneWithThisFrameFloat(self.get_tmpreg_f())
        else:
            assert False

    def _exit_frame_with_exception(self, e):
        sd = self.builder.metainterp_sd
        e = lltype.cast_opaque_ptr(llmemory.GCREF, e)
        raise jitexc.ExitFrameWithExceptionRef(e)

    def _handle_jitexception_in_portal(self, e):
        # This case is really rare, but can occur if
        # convert_and_run_from_pyjitpl() gets called in this situation:
        #
        #     [function 1]             <---- top BlackholeInterpreter()
        #     [recursive portal jit code]
        #     ...
        #     [bottom portal jit code]   <---- bottom BlackholeInterpreter()
        #
        # and then "function 1" contains a call to "function 2", which
        # calls "can_enter_jit".  The latter can terminate by raising a
        # JitException.  In that case, the JitException is not supposed
        # to fall through the whole chain of BlackholeInterpreters, but
        # be caught and handled just below the level "recursive portal
        # jit code".  The present function is called to handle the case
        # of recursive portal jit codes.
        for jd in self.builder.metainterp_sd.jitdrivers_sd:
            if jd.mainjitcode is self.jitcode:
                break
        else:
            assert 0, "portal jitcode not found??"
        # call the helper in warmspot.py.  It might either raise a
        # regular exception (which should then be propagated outside
        # of 'self', not caught inside), or return (the return value
        # gets stored in nextblackholeinterp).
        jd.handle_jitexc_from_bh(self.nextblackholeinterp, e)

    def _copy_data_from_miframe(self, miframe):
        self.setposition(miframe.jitcode, miframe.pc)
        for i in range(self.jitcode.num_regs_i()):
            box = miframe.registers_i[i]
            if not we_are_translated() and isinstance(box, MissingValue):
                continue
            if box is not None:
                self.setarg_i(i, box.getint())
        for i in range(self.jitcode.num_regs_r()):
            box = miframe.registers_r[i]
            if not we_are_translated() and isinstance(box, MissingValue):
                continue
            if box is not None:
                self.setarg_r(i, box.getref_base())
        for i in range(self.jitcode.num_regs_f()):
            box = miframe.registers_f[i]
            if not we_are_translated() and isinstance(box, MissingValue):
                continue
            if box is not None:
                self.setarg_f(i, box.getfloatstorage())

    @specialize.arg(3)
    def _get_list_of_values(self, code, position, argtype):
        length = ord(code[position])
        position += 1
        value = []
        for i in range(length):
            index = ord(code[position+i])
            if   argtype == 'I': reg = self.registers_i[index]
            elif argtype == 'R': reg = self.registers_r[index]
            elif argtype == 'F': reg = self.registers_f[index]
            else: assert 0
            if not we_are_translated():
                assert not isinstance(reg, MissingValue), (
                    name, self.jitcode, position)
            value.append(reg)
        make_sure_not_resized(value)
        return value

# ____________________________________________________________

def _run_forever(blackholeinterp, current_exc):
    while True:
        try:
            current_exc = blackholeinterp._resume_mainloop(current_exc)
        except jitexc.JitException as e:
            blackholeinterp, current_exc = _handle_jitexception(
                blackholeinterp, e)
        blackholeinterp.builder.release_interp(blackholeinterp)
        blackholeinterp = blackholeinterp.nextblackholeinterp

def _handle_jitexception(blackholeinterp, exc):
    # See comments in _handle_jitexception_in_portal().
    while blackholeinterp.jitcode.jitdriver_sd is None:
        blackholeinterp.builder.release_interp(blackholeinterp)
        blackholeinterp = blackholeinterp.nextblackholeinterp
    if blackholeinterp.nextblackholeinterp is None:
        blackholeinterp.builder.release_interp(blackholeinterp)
        raise exc     # bottommost entry: go through
    # We have reached a recursive portal level.
    try:
        blackholeinterp._handle_jitexception_in_portal(exc)
    except Exception as e:
        # It raised a general exception (it should not be a JitException here).
        lle = get_llexception(blackholeinterp.cpu, e)
    else:
        # It set up the nextblackholeinterp to contain the return value.
        lle = lltype.nullptr(rclass.OBJECTPTR.TO)
    # We will continue to loop in _run_forever() from the parent level.
    return blackholeinterp, lle

def resume_in_blackhole(metainterp_sd, jitdriver_sd, resumedescr, deadframe,
                        all_virtuals=None):
    from rpython.jit.metainterp.resume import blackhole_from_resumedata
    #debug_start('jit-blackhole')
    blackholeinterp = blackhole_from_resumedata(
        metainterp_sd.blackholeinterpbuilder,
        metainterp_sd.jitcodes,
        jitdriver_sd,
        resumedescr,
        deadframe,
        all_virtuals)

    current_exc = blackholeinterp._prepare_resume_from_failure(deadframe)

    _run_forever(blackholeinterp, current_exc)
resume_in_blackhole._dont_inline_ = True

def convert_and_run_from_pyjitpl(metainterp, raising_exception=False):
    # Get a chain of blackhole interpreters and fill them by copying
    # 'metainterp.framestack'.
    #debug_start('jit-blackhole')
    metainterp_sd = metainterp.staticdata
    nextbh = None
    for frame in metainterp.framestack:
        curbh = metainterp_sd.blackholeinterpbuilder.acquire_interp()
        curbh._copy_data_from_miframe(frame)
        curbh.nextblackholeinterp = nextbh
        nextbh = curbh
    firstbh = nextbh
    #
    if metainterp.last_exc_value:
        current_exc = metainterp.last_exc_value
    else:
        current_exc = lltype.nullptr(rclass.OBJECTPTR.TO)
    if not raising_exception:
        firstbh.exception_last_value = current_exc
        current_exc = lltype.nullptr(rclass.OBJECTPTR.TO)
    #
    _run_forever(firstbh, current_exc)
convert_and_run_from_pyjitpl._dont_inline_ = True

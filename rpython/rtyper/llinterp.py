import cStringIO
import os
import sys
import traceback

import py

from rpython.flowspace.model import (FunctionGraph, Constant, Variable)
from rpython.rlib import rstackovf
from rpython.rlib.objectmodel import (ComputedIntSymbolic, CDefinedIntSymbolic,
    Symbolic)
# intmask is used in an exec'd code block
from rpython.rlib.rarithmetic import (ovfcheck, is_valid_int, intmask,
    r_uint, r_longlong, r_ulonglong, r_longlonglong)
from rpython.rtyper.lltypesystem import lltype, llmemory, lloperation, llheap
from rpython.rtyper import rclass
from rpython.tool.ansi_print import AnsiLogger

# by default this logger's output is disabled.
# e.g. tests can then switch on logging to get more help
# for failing tests
log = AnsiLogger('llinterp')
log.output_disabled = True


class LLException(Exception):

    # .error_value is used only by tests: in particular,
    # test_exceptiontransform uses it to check what is the return value of the
    # function in case of exception
    UNDEFINED_ERROR_VALUE = object() # sentinel for self.error_value

    def __init__(self, *args, **kwargs):
        "NOT_RPYTHON"
        Exception.__init__(self, *args)
        self.error_value = kwargs.pop('error_value', self.UNDEFINED_ERROR_VALUE)
        if kwargs:
            raise TypeError('unexpected keyword arguments: %s' % kwargs.keys())

    def __str__(self):
        etype = self.args[0]
        #evalue = self.args[1]
        if len(self.args) > 2:
            f = cStringIO.StringIO()
            original_type, original_value, original_tb = self.args[2]
            traceback.print_exception(original_type, original_value, original_tb,
                                      file=f)
            extra = '\n' + f.getvalue().rstrip('\n')
            extra = extra.replace('\n', '\n | ') + '\n `------'
        else:
            extra = ''
        return '<LLException %r%s>' % (type_name(etype), extra)

class LLFatalError(Exception):
    def __str__(self):
        return ': '.join([str(x) for x in self.args])

class LLAssertFailure(Exception):
    pass


def type_name(etype):
    return ''.join(etype.name.chars)

class LLInterpreter(object):
    """ low level interpreter working with concrete values. """

    current_interpreter = None

    def __init__(self, typer, tracing=True, exc_data_ptr=None):
        self.bindings = {}
        self.typer = typer
        # 'heap' is module or object that provides malloc, etc for lltype ops
        self.heap = llheap
        self.exc_data_ptr = exc_data_ptr
        self.frame_stack = []
        self.tracer = None
        self.frame_class = LLFrame
        if tracing:
            self.tracer = Tracer()

    def eval_graph(self, graph, args=(), recursive=False):
        llframe = self.frame_class(graph, args, self)
        if self.tracer and not recursive:
            global tracer1
            tracer1 = self.tracer
            self.tracer.start()
        retval = None
        self.traceback_frames = []
        old_frame_stack = self.frame_stack[:]
        prev_interpreter = LLInterpreter.current_interpreter
        LLInterpreter.current_interpreter = self
        try:
            try:
                retval = llframe.eval()
            except LLException as e:
                log.error("LLEXCEPTION: %s" % (e, ))
                self.print_traceback()
                if self.tracer:
                    self.tracer.dump('LLException: %s\n' % (e,))
                raise
            except Exception as e:
                if getattr(e, '_go_through_llinterp_uncaught_', False):
                    raise
                log.error("AN ERROR OCCURED: %s" % (e, ))
                self.print_traceback()
                if self.tracer:
                    line = str(e)
                    if line:
                        line = ': ' + line
                    line = '* %s' % (e.__class__.__name__,) + line
                    self.tracer.dump(line + '\n')
                raise
        finally:
            LLInterpreter.current_interpreter = prev_interpreter
            assert old_frame_stack == self.frame_stack
            if self.tracer:
                if retval is not None:
                    self.tracer.dump('   ---> %r\n' % (retval,))
                if not recursive:
                    self.tracer.stop()
        return retval

    def print_traceback(self):
        frames = self.traceback_frames
        frames.reverse()
        self.traceback_frames = []
        lines = []
        for frame in frames:
            logline = frame.graph.name + "()"
            if frame.curr_block is None:
                logline += " <not running yet>"
                lines.append(logline)
                continue
            try:
                logline += " " + self.typer.annotator.annotated[frame.curr_block].func.__module__
            except (KeyError, AttributeError, TypeError):
                logline += " <unknown module>"
            lines.append(logline)
            for i, operation in enumerate(frame.curr_block.operations):
                if i == frame.curr_operation_index:
                    logline = "E  %s"
                else:
                    logline = "   %s"
                lines.append(logline % (operation, ))
        if self.tracer:
            self.tracer.dump('Traceback\n', bold=True)
            for line in lines:
                self.tracer.dump(line + '\n')
        for line in lines:
            log.traceback(line)

    def get_tlobj(self):
        try:
            return self._tlobj
        except AttributeError:
            from rpython.rtyper.lltypesystem import rffi
            PERRNO = rffi.CArrayPtr(rffi.INT)
            fake_p_errno = lltype.malloc(PERRNO.TO, 1, flavor='raw', zero=True,
                                         track_allocation=False)
            self._tlobj = {'RPY_TLOFS_p_errno': fake_p_errno,
                           #'thread_ident': ...,
                           }
            return self._tlobj

    def find_roots(self, is_minor=False):
        """Return a list of the addresses of the roots."""
        #log.findroots("starting")
        roots = []
        for frame in reversed(self.frame_stack):
            #log.findroots("graph", frame.graph.name)
            frame.find_roots(roots)
            # If a call is done with 'is_minor=True', we can stop after the
            # first frame in the stack that was already seen by the previous
            # call with 'is_minor=True'.  (We still need to trace that frame,
            # but not its callers.)
            if is_minor:
                if getattr(frame, '_find_roots_already_seen', False):
                    break
                frame._find_roots_already_seen = True
        return roots

    def find_exception(self, exc):
        assert isinstance(exc, LLException)
        klass, inst = exc.args[0], exc.args[1]
        for cls in enumerate_exceptions_top_down():
            if "".join(klass.name.chars) == cls.__name__:
                return cls
        raise ValueError("couldn't match exception, maybe it"
                      " has RPython attributes like OSError?")

    def get_transformed_exc_data(self, graph):
        if hasattr(graph, 'exceptiontransformed'):
            return graph.exceptiontransformed
        if getattr(graph, 'rgenop', False):
            return self.exc_data_ptr
        return None

    def _store_exception(self, exc):
        raise PleaseOverwriteStoreException("You just invoked ll2ctypes callback without overwriting _store_exception on llinterpreter")

class PleaseOverwriteStoreException(Exception):
    pass

def checkptr(ptr):
    assert isinstance(lltype.typeOf(ptr), lltype.Ptr)

def checkadr(addr):
    assert lltype.typeOf(addr) is llmemory.Address


class LLFrame(object):
    def __init__(self, graph, args, llinterpreter):
        assert not graph or isinstance(graph, FunctionGraph)
        self.graph = graph
        self.args = args
        self.llinterpreter = llinterpreter
        self.heap = llinterpreter.heap
        self.bindings = {}
        self.curr_block = None
        self.curr_operation_index = 0
        self.alloca_objects = []

    def newsubframe(self, graph, args):
        return self.__class__(graph, args, self.llinterpreter)

    # _______________________________________________________
    # variable setters/getters helpers

    def clear(self):
        self.bindings.clear()

    def fillvars(self, block, values):
        vars = block.inputargs
        assert len(vars) == len(values), (
                   "block %s received %d args, expected %d" % (
                    block, len(values), len(vars)))
        for var, val in zip(vars, values):
            self.setvar(var, val)

    def setvar(self, var, val):
        if var.concretetype is not lltype.Void:
            try:
                val = lltype.enforce(var.concretetype, val)
            except TypeError:
                assert False, "type error: input value of type:\n\n\t%r\n\n===> variable of type:\n\n\t%r\n" % (lltype.typeOf(val), var.concretetype)
        assert isinstance(var, Variable)
        self.bindings[var] = val

    def setifvar(self, var, val):
        if isinstance(var, Variable):
            self.setvar(var, val)

    def getval(self, varorconst):
        try:
            val = varorconst.value
        except AttributeError:
            val = self.bindings[varorconst]
        if isinstance(val, ComputedIntSymbolic):
            val = val.compute_fn()
        if varorconst.concretetype is not lltype.Void:
            try:
                val = lltype.enforce(varorconst.concretetype, val)
            except TypeError:
                assert False, "type error: %r val from %r var/const" % (lltype.typeOf(val), varorconst.concretetype)
        return val

    # _______________________________________________________
    # other helpers
    def getoperationhandler(self, opname):
        ophandler = getattr(self, 'op_' + opname, None)
        if ophandler is None:
            # try to import the operation from opimpl.py
            ophandler = lloperation.LL_OPERATIONS[opname].fold
            setattr(self.__class__, 'op_' + opname, staticmethod(ophandler))
        return ophandler
    # _______________________________________________________
    # evaling functions

    def eval(self):
        graph = self.graph
        tracer = self.llinterpreter.tracer
        if tracer:
            tracer.enter(graph)
        self.llinterpreter.frame_stack.append(self)
        try:
            try:
                nextblock = graph.startblock
                args = self.args
                while 1:
                    self.clear()
                    self.fillvars(nextblock, args)
                    nextblock, args = self.eval_block(nextblock)
                    if nextblock is None:
                        for obj in self.alloca_objects:
                            obj._obj._free()
                        return args
            except Exception:
                self.llinterpreter.traceback_frames.append(self)
                raise
        finally:
            leavingframe = self.llinterpreter.frame_stack.pop()
            assert leavingframe is self
            if tracer:
                tracer.leave()

    def eval_block(self, block):
        """ return (nextblock, values) tuple. If nextblock
            is None, values is the concrete return value.
        """
        self.curr_block = block
        e = None

        try:
            for i, op in enumerate(block.operations):
                self.curr_operation_index = i
                self.eval_operation(op)
        except LLException as e:
            if op is not block.raising_op:
                raise
        except RuntimeError as e:
            rstackovf.check_stack_overflow()
            # xxx fish fish fish for proper etype and evalue to use
            rtyper = self.llinterpreter.typer
            bk = rtyper.annotator.bookkeeper
            classdef = bk.getuniqueclassdef(rstackovf._StackOverflow)
            exdata = rtyper.exceptiondata
            evalue = exdata.get_standard_ll_exc_instance(rtyper, classdef)
            etype = exdata.fn_type_of_exc_inst(evalue)
            e = LLException(etype, evalue)
            if op is not block.raising_op:
                raise e

        # determine nextblock and/or return value
        if len(block.exits) == 0:
            # return block
            tracer = self.llinterpreter.tracer
            if len(block.inputargs) == 2:
                # exception
                if tracer:
                    tracer.dump('raise')
                etypevar, evaluevar = block.getvariables()
                etype = self.getval(etypevar)
                evalue = self.getval(evaluevar)
                # watch out, these are _ptr's
                raise LLException(etype, evalue)
            resultvar, = block.getvariables()
            result = self.getval(resultvar)
            exc_data = self.llinterpreter.get_transformed_exc_data(self.graph)
            if exc_data:
                # re-raise the exception set by this graph, if any
                etype = exc_data.exc_type
                if etype:
                    evalue = exc_data.exc_value
                    if tracer:
                        tracer.dump('raise')
                    exc_data.exc_type = lltype.typeOf(etype)._defl()
                    exc_data.exc_value = lltype.typeOf(evalue)._defl()
                    raise LLException(etype, evalue, error_value=result)
            if tracer:
                tracer.dump('return')
            return None, result
        elif block.exitswitch is None:
            # single-exit block
            assert len(block.exits) == 1
            link = block.exits[0]
        elif block.canraise:
            link = block.exits[0]
            if e:
                exdata = self.llinterpreter.typer.exceptiondata
                cls = e.args[0]
                inst = e.args[1]
                for link in block.exits[1:]:
                    assert issubclass(link.exitcase, py.builtin.BaseException)
                    if self.op_direct_call(exdata.fn_exception_match,
                                           cls, link.llexitcase):
                        self.setifvar(link.last_exception, cls)
                        self.setifvar(link.last_exc_value, inst)
                        break
                else:
                    # no handler found, pass on
                    raise e
        else:
            llexitvalue = self.getval(block.exitswitch)
            if block.exits[-1].exitcase == "default":
                defaultexit = block.exits[-1]
                nondefaultexits = block.exits[:-1]
                assert defaultexit.llexitcase is None
            else:
                defaultexit = None
                nondefaultexits = block.exits
            for link in nondefaultexits:
                if link.llexitcase == llexitvalue:
                    break   # found -- the result is in 'link'
            else:
                if defaultexit is None:
                    raise ValueError("exit case %r not found in the exit links "
                                     "of %r" % (llexitvalue, block))
                else:
                    link = defaultexit
        return link.target, [self.getval(x) for x in link.args]

    def eval_operation(self, operation):
        tracer = self.llinterpreter.tracer
        if tracer:
            tracer.dump(str(operation))
        ophandler = self.getoperationhandler(operation.opname)
        # XXX slighly unnice but an important safety check
        if operation.opname == 'direct_call':
            assert isinstance(operation.args[0], Constant)
        elif operation.opname == 'indirect_call':
            assert isinstance(operation.args[0], Variable)
        if getattr(ophandler, 'specialform', False):
            retval = ophandler(*operation.args)
        else:
            vals = [self.getval(x) for x in operation.args]
            if getattr(ophandler, 'need_result_type', False):
                vals.insert(0, operation.result.concretetype)
            try:
                retval = ophandler(*vals)
            except LLException as e:
                # safety check check that the operation is allowed to raise that
                # exception
                if operation.opname in lloperation.LL_OPERATIONS:
                    canraise = lloperation.LL_OPERATIONS[operation.opname].canraise
                    if Exception not in canraise:
                        exc = self.llinterpreter.find_exception(e)
                        for canraiseexc in canraise:
                            if issubclass(exc, canraiseexc):
                                break
                        else:
                            raise TypeError("the operation %s is not expected to raise %s" % (operation, exc))

                # for exception-transformed graphs, store the LLException
                # into the exc_data used by this graph
                exc_data = self.llinterpreter.get_transformed_exc_data(
                    self.graph)
                if exc_data:
                    etype = e.args[0]
                    evalue = e.args[1]
                    exc_data.exc_type = etype
                    exc_data.exc_value = evalue
                    retval = e.error_value
                    if retval is LLException.UNDEFINED_ERROR_VALUE:
                        from rpython.translator import exceptiontransform
                        # if we are here it means that the exception was
                        # caused by a builtin op such as int_add_ovf (i.e.,
                        # NOT a call): in this case, we just use the default
                        # error_value
                        T = operation.result.concretetype
                        retval = exceptiontransform.default_error_value(T)
                else:
                    raise
        self.setvar(operation.result, retval)
        if tracer:
            if retval is None:
                tracer.dump('\n')
            else:
                tracer.dump('   ---> %r\n' % (retval,))

    def make_llexception(self, exc=None):
        if exc is None:
            original = sys.exc_info()
            exc = original[1]
            # it makes no sense to convert some exception classes that
            # just mean something buggy crashed
            if isinstance(exc, (AssertionError, AttributeError,
                                TypeError, NameError,
                                KeyboardInterrupt, SystemExit,
                                ImportError, SyntaxError)):
                raise original[0], original[1], original[2]     # re-raise it
            # for testing the JIT (see ContinueRunningNormally) we need
            # to let some exceptions introduced by the JIT go through
            # the llinterpreter uncaught
            if getattr(exc, '_go_through_llinterp_uncaught_', False):
                raise original[0], original[1], original[2]     # re-raise it
            extraargs = (original,)
        else:
            extraargs = ()
        typer = self.llinterpreter.typer
        exdata = typer.exceptiondata
        evalue = exdata.get_standard_ll_exc_instance_by_class(exc.__class__)
        etype = self.op_direct_call(exdata.fn_type_of_exc_inst, evalue)
        raise LLException(etype, evalue, *extraargs)

    def invoke_callable_with_pyexceptions(self, fptr, *args):
        obj = fptr._obj
        try:
            return obj._callable(*args)
        except LLException as e:
            raise
        except Exception as e:
            if getattr(e, '_go_through_llinterp_uncaught_', False):
                raise
            if getattr(obj, '_debugexc', False):
                log.ERROR('The llinterpreter got an '
                          'unexpected exception when calling')
                log.ERROR('the external function %r:' % (fptr,))
                log.ERROR('%s: %s' % (e.__class__.__name__, e))
                if self.llinterpreter.tracer:
                    self.llinterpreter.tracer.flush()
                import sys
                from rpython.translator.tool.pdbplus import PdbPlusShow
                PdbPlusShow(None).post_mortem(sys.exc_info()[2])
            self.make_llexception()

    def find_roots(self, roots):
        #log.findroots(self.curr_block.inputargs)
        vars = []
        for v in self.curr_block.inputargs:
            if isinstance(v, Variable):
                vars.append(v)
        for op in self.curr_block.operations[:self.curr_operation_index]:
            vars.append(op.result)

        for v in vars:
            TYPE = v.concretetype
            if isinstance(TYPE, lltype.Ptr) and TYPE.TO._gckind == 'gc':
                roots.append(_address_of_local_var(self, v))

    # __________________________________________________________
    # misc LL operation implementations

    def op_debug_view(self, *ll_objects):
        from rpython.translator.tool.lltracker import track
        track(*ll_objects)

    def op_debug_assert(self, x, msg):
        if not x:
            raise LLAssertFailure(msg)

    def op_debug_assert_not_none(self, x):
        if not x:
            raise LLAssertFailure("ll_assert_not_none() failed")

    def op_debug_fatalerror(self, ll_msg, ll_exc=None):
        msg = ''.join(ll_msg.chars)
        if ll_exc is None:
            raise LLFatalError(msg)
        else:
            ll_exc_type = lltype.cast_pointer(rclass.OBJECTPTR, ll_exc).typeptr
            raise LLFatalError(msg, LLException(ll_exc_type, ll_exc))

    def op_debug_llinterpcall(self, pythonfunction, *args_ll):
        try:
            return pythonfunction(*args_ll)
        except:
            self.make_llexception()

    def op_debug_forked(self, *args):
        raise NotImplementedError

    def op_debug_start_traceback(self, *args):
        pass    # xxx write debugging code here?

    def op_debug_reraise_traceback(self, *args):
        pass    # xxx write debugging code here?

    def op_debug_record_traceback(self, *args):
        pass    # xxx write debugging code here?

    def op_debug_print_traceback(self, *args):
        pass    # xxx write debugging code here?

    def op_debug_catch_exception(self, *args):
        pass    # xxx write debugging code here?

    def op_jit_marker(self, *args):
        pass

    def op_jit_record_exact_class(self, *args):
        pass

    def op_jit_conditional_call(self, *args):
        raise NotImplementedError("should not be called while not jitted")

    def op_jit_conditional_call_value(self, *args):
        raise NotImplementedError("should not be called while not jitted")

    def op_get_exception_addr(self, *args):
        raise NotImplementedError

    def op_get_exc_value_addr(self, *args):
        raise NotImplementedError

    def op_instrument_count(self, ll_tag, ll_label):
        pass # xxx for now

    def op_keepalive(self, value):
        pass

    def op_hint(self, x, hints):
        return x

    def op_decode_arg(self, fname, i, name, vargs, vkwds):
        raise NotImplementedError("decode_arg")

    def op_decode_arg_def(self, fname, i, name, vargs, vkwds, default):
        raise NotImplementedError("decode_arg_def")

    def op_check_no_more_arg(self, fname, n, vargs):
        raise NotImplementedError("check_no_more_arg")

    def op_getslice(self, vargs, start, stop_should_be_None):
        raise NotImplementedError("getslice")   # only for argument parsing

    def op_check_self_nonzero(self, fname, vself):
        raise NotImplementedError("check_self_nonzero")

    def op_setfield(self, obj, fieldname, fieldvalue):
        # obj should be pointer
        FIELDTYPE = getattr(lltype.typeOf(obj).TO, fieldname)
        if FIELDTYPE is not lltype.Void:
            self.heap.setfield(obj, fieldname, fieldvalue)

    def op_bare_setfield(self, obj, fieldname, fieldvalue):
        # obj should be pointer
        FIELDTYPE = getattr(lltype.typeOf(obj).TO, fieldname)
        if FIELDTYPE is not lltype.Void:
            setattr(obj, fieldname, fieldvalue)

    def op_getinteriorfield(self, obj, *offsets):
        checkptr(obj)
        ob = obj
        for o in offsets:
            if isinstance(o, str):
                ob = getattr(ob, o)
            else:
                ob = ob[o]
        assert not isinstance(ob, lltype._interior_ptr)
        return ob

    def getinneraddr(self, obj, *offsets):
        TYPE = lltype.typeOf(obj).TO
        addr = llmemory.cast_ptr_to_adr(obj)
        for o in offsets:
            if isinstance(o, str):
                addr += llmemory.offsetof(TYPE, o)
                TYPE = getattr(TYPE, o)
            else:
                addr += llmemory.itemoffsetof(TYPE, o)
                TYPE = TYPE.OF
        return addr, TYPE

    def op_setinteriorfield(self, obj, *fieldnamesval):
        offsets, fieldvalue = fieldnamesval[:-1], fieldnamesval[-1]
        inneraddr, FIELD = self.getinneraddr(obj, *offsets)
        if FIELD is not lltype.Void:
            self.heap.setinterior(obj, inneraddr, FIELD, fieldvalue, offsets)

    def op_bare_setinteriorfield(self, obj, *fieldnamesval):
        offsets, fieldvalue = fieldnamesval[:-1], fieldnamesval[-1]
        inneraddr, FIELD = self.getinneraddr(obj, *offsets)
        if FIELD is not lltype.Void:
            llheap.setinterior(obj, inneraddr, FIELD, fieldvalue)

    def op_getarrayitem(self, array, index):
        return array[index]

    def op_setarrayitem(self, array, index, item):
        # array should be a pointer
        ITEMTYPE = lltype.typeOf(array).TO.OF
        if ITEMTYPE is not lltype.Void:
            self.heap.setarrayitem(array, index, item)

    def op_bare_setarrayitem(self, array, index, item):
        # array should be a pointer
        ITEMTYPE = lltype.typeOf(array).TO.OF
        if ITEMTYPE is not lltype.Void:
            array[index] = item

    def perform_call(self, f, ARGS, args):
        fobj = f._obj
        has_callable = getattr(fobj, '_callable', None) is not None
        if hasattr(fobj, 'graph'):
            graph = fobj.graph
        else:
            assert has_callable, "don't know how to execute %r" % f
            return self.invoke_callable_with_pyexceptions(f, *args)
        args_v = graph.getargs()
        if len(ARGS) != len(args_v):
            raise TypeError("graph with %d args called with wrong func ptr type: %r" %(len(args_v), ARGS))
        for T, v in zip(ARGS, args_v):
            if not lltype.isCompatibleType(T, v.concretetype):
                raise TypeError("graph with %r args called with wrong func ptr type: %r" %
                                (tuple([v.concretetype for v in args_v]), ARGS))
        frame = self.newsubframe(graph, args)
        return frame.eval()

    def op_direct_call(self, f, *args):
        FTYPE = lltype.typeOf(f).TO
        return self.perform_call(f, FTYPE.ARGS, args)

    def op_indirect_call(self, f, *args):
        graphs = args[-1]
        args = args[:-1]
        if graphs is not None:
            obj = f._obj
            if hasattr(obj, 'graph'):
                assert obj.graph in graphs
        else:
            pass
            #log.warn("op_indirect_call with graphs=None:", f)
        return self.op_direct_call(f, *args)

    def op_malloc(self, obj, flags):
        flavor = flags['flavor']
        zero = flags.get('zero', False)
        track_allocation = flags.get('track_allocation', True)
        if flavor == "stack":
            result = self.heap.malloc(obj, zero=zero, flavor='raw')
            self.alloca_objects.append(result)
            return result
        ptr = self.heap.malloc(obj, zero=zero, flavor=flavor,
                               track_allocation=track_allocation)
        return ptr

    def op_malloc_varsize(self, obj, flags, size):
        flavor = flags['flavor']
        zero = flags.get('zero', False)
        track_allocation = flags.get('track_allocation', True)
        assert flavor in ('gc', 'raw')
        try:
            ptr = self.heap.malloc(obj, size, zero=zero, flavor=flavor,
                                   track_allocation=track_allocation)
            return ptr
        except MemoryError:
            self.make_llexception()

    def op_free(self, obj, flags):
        assert flags['flavor'] == 'raw'
        track_allocation = flags.get('track_allocation', True)
        self.heap.free(obj, flavor='raw', track_allocation=track_allocation)

    def op_gc_add_memory_pressure(self, size):
        self.heap.add_memory_pressure(size)

    def op_gc_fq_next_dead(self, fq_tag):
        return self.heap.gc_fq_next_dead(fq_tag)

    def op_gc_fq_register(self, fq_tag, obj):
        self.heap.gc_fq_register(fq_tag, obj)

    def op_gc_gettypeid(self, obj):
        return lloperation.llop.combine_ushort(lltype.Signed, self.heap.gettypeid(obj), 0)

    def op_shrink_array(self, obj, smallersize):
        return self.heap.shrink_array(obj, smallersize)

    def op_zero_gc_pointers_inside(self, obj):
        raise NotImplementedError("zero_gc_pointers_inside")

    def op_gc_get_stats(self, obj):
        raise NotImplementedError("gc_get_stats")

    def op_gc_writebarrier_before_copy(self, source, dest,
                                       source_start, dest_start, length):
        if hasattr(self.heap, 'writebarrier_before_copy'):
            return self.heap.writebarrier_before_copy(source, dest,
                                                      source_start, dest_start,
                                                      length)
        else:
            return True

    def op_gc_writebarrier_before_move(self, array):
        if hasattr(self.heap, 'writebarrier_before_move'):
            self.heap.writebarrier_before_move(array)

    def op_getfield(self, obj, field):
        checkptr(obj)
        # check the difference between op_getfield and op_getsubstruct:
        assert not isinstance(getattr(lltype.typeOf(obj).TO, field),
                              lltype.ContainerType)
        return getattr(obj, field)

    def op_force_cast(self, RESTYPE, obj):
        from rpython.rtyper.lltypesystem import ll2ctypes
        return ll2ctypes.force_cast(RESTYPE, obj)
    op_force_cast.need_result_type = True

    def op_cast_int_to_ptr(self, RESTYPE, int1):
        return lltype.cast_int_to_ptr(RESTYPE, int1)
    op_cast_int_to_ptr.need_result_type = True

    def op_cast_ptr_to_int(self, ptr1):
        checkptr(ptr1)
        return lltype.cast_ptr_to_int(ptr1)

    def op_cast_opaque_ptr(self, RESTYPE, obj):
        checkptr(obj)
        return lltype.cast_opaque_ptr(RESTYPE, obj)
    op_cast_opaque_ptr.need_result_type = True

    def op_length_of_simple_gcarray_from_opaque(self, obj):
        checkptr(obj)
        return lltype.length_of_simple_gcarray_from_opaque(obj)

    def op_cast_ptr_to_adr(self, ptr):
        checkptr(ptr)
        return llmemory.cast_ptr_to_adr(ptr)

    def op_cast_adr_to_int(self, adr, mode):
        checkadr(adr)
        return llmemory.cast_adr_to_int(adr, mode)

    def op_convert_float_bytes_to_longlong(self, f):
        from rpython.rlib import longlong2float
        return longlong2float.float2longlong(f)

    def op_weakref_create(self, v_obj):
        def objgetter():    # special support for gcwrapper.py
            return self.getval(v_obj)
        assert self.llinterpreter.typer.getconfig().translation.rweakref
        return self.heap.weakref_create_getlazy(objgetter)
    op_weakref_create.specialform = True

    def op_weakref_deref(self, PTRTYPE, obj):
        assert self.llinterpreter.typer.getconfig().translation.rweakref
        return self.heap.weakref_deref(PTRTYPE, obj)
    op_weakref_deref.need_result_type = True

    def op_cast_ptr_to_weakrefptr(self, obj):
        assert self.llinterpreter.typer.getconfig().translation.rweakref
        return llmemory.cast_ptr_to_weakrefptr(obj)

    def op_cast_weakrefptr_to_ptr(self, PTRTYPE, obj):
        assert self.llinterpreter.typer.getconfig().translation.rweakref
        return llmemory.cast_weakrefptr_to_ptr(PTRTYPE, obj)
    op_cast_weakrefptr_to_ptr.need_result_type = True

    def op_gc__collect(self, *gen):
        self.heap.collect(*gen)

    def op_gc__collect_step(self):
        return self.heap.collect_step()

    def op_gc__enable(self):
        self.heap.enable()

    def op_gc__disable(self):
        self.heap.disable()

    def op_gc__isenabled(self):
        return self.heap.isenabled()

    def op_gc_heap_stats(self):
        raise NotImplementedError

    def op_gc_obtain_free_space(self, size):
        raise NotImplementedError

    def op_gc_can_move(self, ptr):
        addr = llmemory.cast_ptr_to_adr(ptr)
        return self.heap.can_move(addr)

    def op_gc_thread_run(self):
        self.heap.thread_run()

    def op_gc_thread_start(self):
        self.heap.thread_start()

    def op_gc_thread_die(self):
        self.heap.thread_die()

    def op_gc_thread_before_fork(self):
        raise NotImplementedError

    def op_gc_thread_after_fork(self):
        raise NotImplementedError

    def op_gc_free(self, addr):
        # what can you do?
        pass
        #raise NotImplementedError("gc_free")

    def op_gc_fetch_exception(self):
        raise NotImplementedError("gc_fetch_exception")

    def op_gc_restore_exception(self, exc):
        raise NotImplementedError("gc_restore_exception")

    def op_gc_adr_of_nursery_top(self):
        raise NotImplementedError
    def op_gc_adr_of_nursery_free(self):
        raise NotImplementedError

    def op_gc_adr_of_root_stack_base(self):
        raise NotImplementedError
    def op_gc_adr_of_root_stack_top(self):
        raise NotImplementedError

    def op_gc_modified_shadowstack(self):
        raise NotImplementedError

    def op_gc_call_rtti_destructor(self, rtti, addr):
        if hasattr(rtti._obj, 'destructor_funcptr'):
            d = rtti._obj.destructor_funcptr
            obptr = addr.ref()
            return self.op_direct_call(d, obptr)

    def op_gc_deallocate(self, TYPE, addr):
        raise NotImplementedError("gc_deallocate")

    def op_gc_reload_possibly_moved(self, v_newaddr, v_ptr):
        assert v_newaddr.concretetype is llmemory.Address
        assert isinstance(v_ptr.concretetype, lltype.Ptr)
        assert v_ptr.concretetype.TO._gckind == 'gc'
        newaddr = self.getval(v_newaddr)
        p = llmemory.cast_adr_to_ptr(newaddr, v_ptr.concretetype)
        if isinstance(v_ptr, Constant):
            assert v_ptr.value == p
        else:
            self.setvar(v_ptr, p)
    op_gc_reload_possibly_moved.specialform = True

    def op_gc_identityhash(self, obj):
        return lltype.identityhash(obj)

    def op_gc_id(self, ptr):
        PTR = lltype.typeOf(ptr)
        if isinstance(PTR, lltype.Ptr):
            return self.heap.gc_id(ptr)
        raise NotImplementedError("gc_id on %r" % (PTR,))

    def op_gc_set_max_heap_size(self, maxsize):
        raise NotImplementedError("gc_set_max_heap_size")

    def op_gc_stack_bottom(self):
        # Marker when we enter RPython code from C code.  It used to be
        # essential for trackgcroot.py.  Nowaways it is mostly unused,
        # except by revdb.
        pass

    def op_gc_pin(self, obj):
        addr = llmemory.cast_ptr_to_adr(obj)
        return self.heap.pin(addr)

    def op_gc_unpin(self, obj):
        addr = llmemory.cast_ptr_to_adr(obj)
        self.heap.unpin(addr)

    def op_gc__is_pinned(self, obj):
        addr = llmemory.cast_ptr_to_adr(obj)
        return self.heap._is_pinned(addr)

    def op_gc_get_type_info_group(self):
        raise NotImplementedError("gc_get_type_info_group")

    def op_gc_get_rpy_memory_usage(self):
        raise NotImplementedError("gc_get_rpy_memory_usage")

    def op_gc_get_rpy_roots(self):
        raise NotImplementedError("gc_get_rpy_roots")

    def op_gc_get_rpy_referents(self):
        raise NotImplementedError("gc_get_rpy_referents")

    def op_gc_is_rpy_instance(self):
        raise NotImplementedError("gc_is_rpy_instance")

    def op_gc_get_rpy_type_index(self):
        raise NotImplementedError("gc_get_rpy_type_index")

    def op_gc_dump_rpy_heap(self):
        raise NotImplementedError("gc_dump_rpy_heap")

    def op_gc_typeids_z(self):
        raise NotImplementedError("gc_typeids_z")

    def op_gc_typeids_list(self):
        raise NotImplementedError("gc_typeids_list")

    def op_gc_gcflag_extra(self, subopnum, *args):
        return self.heap.gcflag_extra(subopnum, *args)

    def op_gc_rawrefcount_init(self, *args):
        raise NotImplementedError("gc_rawrefcount_init")

    def op_gc_rawrefcount_to_obj(self, *args):
        raise NotImplementedError("gc_rawrefcount_to_obj")

    def op_gc_rawrefcount_from_obj(self, *args):
        raise NotImplementedError("gc_rawrefcount_from_obj")

    def op_gc_rawrefcount_create_link_pyobj(self, *args):
        raise NotImplementedError("gc_rawrefcount_create_link_pyobj")

    def op_gc_rawrefcount_create_link_pypy(self, *args):
        raise NotImplementedError("gc_rawrefcount_create_link_pypy")

    def op_gc_rawrefcount_mark_deallocating(self, *args):
        raise NotImplementedError("gc_rawrefcount_mark_deallocating")

    def op_gc_rawrefcount_next_dead(self, *args):
        raise NotImplementedError("gc_rawrefcount_next_dead")

    def op_do_malloc_fixedsize(self):
        raise NotImplementedError("do_malloc_fixedsize")
    def op_do_malloc_fixedsize_clear(self):
        raise NotImplementedError("do_malloc_fixedsize_clear")
    def op_do_malloc_varsize(self):
        raise NotImplementedError("do_malloc_varsize")
    def op_do_malloc_varsize_clear(self):
        raise NotImplementedError("do_malloc_varsize_clear")

    def op_get_write_barrier_failing_case(self):
        raise NotImplementedError("get_write_barrier_failing_case")

    def op_get_write_barrier_from_array_failing_case(self):
        raise NotImplementedError("get_write_barrier_from_array_failing_case")

    def op_stack_current(self):
        return 0

    def op_threadlocalref_addr(self):
        return _address_of_thread_local()

    def op_threadlocalref_get(self, RESTYPE, offset):
        return self.op_raw_load(RESTYPE, _address_of_thread_local(), offset)
    op_threadlocalref_get.need_result_type = True

    op_threadlocalref_load = op_threadlocalref_get

    def op_threadlocalref_store(self, offset, value):
        self.op_raw_store(_address_of_thread_local(), offset, value)

    def op_threadlocalref_acquire(self, prev):
        raise NotImplementedError
    def op_threadlocalref_release(self, prev):
        raise NotImplementedError
    def op_threadlocalref_enum(self, prev):
        raise NotImplementedError

    # __________________________________________________________
    # operations on addresses

    def op_raw_malloc(self, size, zero):
        assert lltype.typeOf(size) == lltype.Signed
        return llmemory.raw_malloc(size, zero=zero)

    def op_boehm_malloc(self, size):
        assert lltype.typeOf(size) == lltype.Signed
        raw = llmemory.raw_malloc(size)
        return llmemory.cast_adr_to_ptr(raw, llmemory.GCREF)
    op_boehm_malloc_atomic = op_boehm_malloc

    def op_boehm_register_finalizer(self, p, finalizer):
        pass

    def op_boehm_disappearing_link(self, link, obj):
        pass

    def op_raw_malloc_usage(self, size):
        assert lltype.typeOf(size) == lltype.Signed
        return llmemory.raw_malloc_usage(size)

    def op_raw_free(self, addr):
        checkadr(addr)
        llmemory.raw_free(addr)

    def op_raw_memclear(self, addr, size):
        checkadr(addr)
        llmemory.raw_memclear(addr, size)

    def op_raw_memcopy(self, fromaddr, toaddr, size):
        checkadr(fromaddr)
        checkadr(toaddr)
        llmemory.raw_memcopy(fromaddr, toaddr, size)

    def op_raw_memset(self, addr, byte, size):
        raise NotImplementedError

    op_raw_memmove = op_raw_memcopy # this is essentially the same here

    def op_raw_load(self, RESTYPE, addr, offset):
        checkadr(addr)
        if isinstance(offset, int):
            from rpython.rtyper.lltypesystem import rffi
            ll_p = rffi.cast(rffi.CCHARP, addr)
            ll_p = rffi.cast(rffi.CArrayPtr(RESTYPE),
                             rffi.ptradd(ll_p, offset))
            value = ll_p[0]
        elif getattr(addr, 'is_fake_thread_local_addr', False):
            assert type(offset) is CDefinedIntSymbolic
            value = self.llinterpreter.get_tlobj()[offset.expr]
        else:
            assert offset.TYPE == RESTYPE
            value = getattr(addr, str(RESTYPE).lower())[offset.repeat]
        assert lltype.typeOf(value) == RESTYPE
        return value
    op_raw_load.need_result_type = True

    def op_raw_store(self, addr, offset, value):
        # XXX handle the write barrier by delegating to self.heap instead
        self.op_bare_raw_store(addr, offset, value)

    def op_bare_raw_store(self, addr, offset, value):
        checkadr(addr)
        ARGTYPE = lltype.typeOf(value)
        if isinstance(offset, int):
            from rpython.rtyper.lltypesystem import rffi
            ll_p = rffi.cast(rffi.CCHARP, addr)
            ll_p = rffi.cast(rffi.CArrayPtr(ARGTYPE),
                             rffi.ptradd(ll_p, offset))
            ll_p[0] = value
        elif getattr(addr, 'is_fake_thread_local_addr', False):
            assert type(offset) is CDefinedIntSymbolic
            self.llinterpreter.get_tlobj()[offset.expr] = value
        elif isinstance(offset, llmemory.ArrayLengthOffset):
            assert len(addr.ptr) == value  # invalid ArrayLengthOffset
        else:
            assert offset.TYPE == ARGTYPE
            getattr(addr, str(ARGTYPE).lower())[offset.repeat] = value

    def op_track_alloc_start(self, addr):
        # we don't do tracking at this level
        checkadr(addr)

    def op_track_alloc_stop(self, addr):
        checkadr(addr)

    def op_gc_enter_roots_frame(self, gcdata, numcolors):
        """Fetch from the gcdata the current root_stack_top; bump it
        by 'numcolors'; and assert that the new area is fully
        uninitialized so far.
        """
        assert not hasattr(self, '_inside_roots_frame')
        p = gcdata.inst_root_stack_top.ptr
        q = lltype.direct_ptradd(p, numcolors)
        self._inside_roots_frame = (p, q, numcolors, gcdata)
        gcdata.inst_root_stack_top = llmemory.cast_ptr_to_adr(q)
        #
        array = p._obj._parentstructure()
        index = p._obj._parent_index
        for i in range(index, index + numcolors):
            assert isinstance(array.getitem(i), lltype._uninitialized)

    def op_gc_leave_roots_frame(self):
        """Cancel gc_enter_roots_frame() by removing the frame from
        the root_stack_top.  Writes uninitialized entries in its old place.
        """
        (p, q, numcolors, gcdata) = self._inside_roots_frame
        assert gcdata.inst_root_stack_top.ptr == q
        gcdata.inst_root_stack_top = llmemory.cast_ptr_to_adr(p)
        del self._inside_roots_frame
        #
        array = p._obj._parentstructure()
        index = p._obj._parent_index
        for i in range(index, index + numcolors):
            array.setitem(i, lltype._uninitialized(llmemory.Address))

    def op_gc_save_root(self, num, value):
        """Save one value (int or ptr) into the frame."""
        (p, q, numcolors, gcdata) = self._inside_roots_frame
        assert 0 <= num < numcolors
        if isinstance(value, int):
            assert value & 1    # must be odd
            v = llmemory.cast_int_to_adr(value)
        else:
            v = llmemory.cast_ptr_to_adr(value)
        llmemory.cast_ptr_to_adr(p).address[num] = v

    def op_gc_restore_root(self, c_num, v_value):
        """Restore one value from the frame."""
        num = c_num.value
        (p, q, numcolors, gcdata) = self._inside_roots_frame
        assert 0 <= num < numcolors
        assert isinstance(v_value.concretetype, lltype.Ptr)
        assert v_value.concretetype.TO._gckind == 'gc'
        newvalue = llmemory.cast_ptr_to_adr(p).address[num]
        newvalue = llmemory.cast_adr_to_ptr(newvalue, v_value.concretetype)
        self.setvar(v_value, newvalue)
    op_gc_restore_root.specialform = True

    def op_gc_push_roots(self, *args):
        raise NotImplementedError

    def op_gc_pop_roots(self, *args):
        raise NotImplementedError

    # ____________________________________________________________
    # Overflow-detecting variants

    def op_int_add_ovf(self, x, y):
        assert isinstance(x, (int, long, llmemory.AddressOffset))
        assert isinstance(y, (int, long, llmemory.AddressOffset))
        try:
            return ovfcheck(x + y)
        except OverflowError:
            self.make_llexception()

    def op_int_add_nonneg_ovf(self, x, y):
        if isinstance(y, int):
            assert y >= 0
        return self.op_int_add_ovf(x, y)

    def op_int_sub_ovf(self, x, y):
        assert isinstance(x, (int, long))
        assert isinstance(y, (int, long))
        try:
            return ovfcheck(x - y)
        except OverflowError:
            self.make_llexception()

    def op_int_mul_ovf(self, x, y):
        assert isinstance(x, (int, long, llmemory.AddressOffset))
        assert isinstance(y, (int, long, llmemory.AddressOffset))
        try:
            return ovfcheck(x * y)
        except OverflowError:
            self.make_llexception()

    def op_int_is_true(self, x):
        # special case
        if type(x) is CDefinedIntSymbolic:
            x = x.default
        # if type(x) is a subclass of Symbolic, bool(x) will usually raise
        # a TypeError -- unless __nonzero__ has been explicitly overridden.
        assert is_valid_int(x) or isinstance(x, Symbolic)
        return bool(x)

    # hack for jit.codegen.llgraph

    def op_check_and_clear_exc(self):
        exc_data = self.llinterpreter.get_transformed_exc_data(self.graph)
        assert exc_data
        etype = exc_data.exc_type
        evalue = exc_data.exc_value
        exc_data.exc_type = lltype.typeOf(etype)._defl()
        exc_data.exc_value = lltype.typeOf(evalue)._defl()
        return bool(etype)

    def op_gc_move_out_of_nursery(self, obj):
        raise NotImplementedError("gc_move_out_of_nursery")

    def op_gc_increase_root_stack_depth(self, new_depth):
        raise NotImplementedError("gc_increase_root_stack_depth")

    def op_revdb_stop_point(self, *args):
        pass
    def op_revdb_send_answer(self, *args):
        raise NotImplementedError
    def op_revdb_breakpoint(self, *args):
        raise NotImplementedError
    def op_revdb_get_value(self, *args):
        raise NotImplementedError
    def op_revdb_get_unique_id(self, *args):
        raise NotImplementedError
    def op_revdb_watch_save_state(self, *args):
        return False
    def op_revdb_watch_restore_state(self, *args):
        raise NotImplementedError
    def op_revdb_weakref_create(self, *args):
        raise NotImplementedError
    def op_revdb_weakref_deref(self, *args):
        raise NotImplementedError
    def op_revdb_call_destructor(self, *args):
        raise NotImplementedError
    def op_revdb_strtod(self, *args):
        raise NotImplementedError
    def op_revdb_frexp(self, *args):
        raise NotImplementedError
    def op_revdb_modf(self, *args):
        raise NotImplementedError
    def op_revdb_dtoa(self, *args):
        raise NotImplementedError
    def op_revdb_do_next_call(self):
        pass
    def op_revdb_set_thread_breakpoint(self, *args):
        raise NotImplementedError


class Tracer(object):
    Counter = 0
    file = None
    TRACE = int(os.getenv('PYPY_TRACE') or '0')

    HEADER = """<html><head>
        <script language=javascript type='text/javascript'>
        function togglestate(n) {
          var item = document.getElementById('div'+n)
          if (item.style.display == 'none')
            item.style.display = 'block';
          else
            item.style.display = 'none';
        }

        function toggleall(lst) {
          for (var i = 0; i<lst.length; i++) {
            togglestate(lst[i]);
          }
        }
        </script>
        </head>

        <body><pre>
    """

    FOOTER = """</pre>
        <script language=javascript type='text/javascript'>
        toggleall(%r);
        </script>

    </body></html>"""

    ENTER = ('''\n\t<a href="javascript:togglestate(%d)">%s</a>'''
             '''\n<div id="div%d" style="display: %s">\t''')
    LEAVE = '''\n</div>\t'''

    def htmlquote(self, s, text_to_html={}):
        # HTML quoting, lazily initialized
        if not text_to_html:
            import htmlentitydefs
            for key, value in htmlentitydefs.entitydefs.items():
                text_to_html[value] = '&' + key + ';'
        return ''.join([text_to_html.get(c, c) for c in s])

    def start(self):
        # start of a dump file
        if not self.TRACE:
            return
        from rpython.tool.udir import udir
        n = Tracer.Counter
        Tracer.Counter += 1
        filename = 'llinterp_trace_%d.html' % n
        self.file = udir.join(filename).open('w')
        print >> self.file, self.HEADER

        linkname = str(udir.join('llinterp_trace.html'))
        try:
            os.unlink(linkname)
        except OSError:
            pass
        try:
            os.symlink(filename, linkname)
        except (AttributeError, OSError):
            pass

        self.count = 0
        self.indentation = ''
        self.depth = 0
        self.latest_call_chain = []

    def stop(self):
        # end of a dump file
        if self.file:
            print >> self.file, self.FOOTER % (self.latest_call_chain[1:])
            self.file.close()
            self.file = None

    def enter(self, graph):
        # enter evaluation of a graph
        if self.file:
            del self.latest_call_chain[self.depth:]
            self.depth += 1
            self.latest_call_chain.append(self.count)
            s = self.htmlquote(str(graph))
            i = s.rfind(')')
            s = s[:i+1] + '<b>' + s[i+1:] + '</b>'
            if self.count == 0:
                display = 'block'
            else:
                display = 'none'
            text = self.ENTER % (self.count, s, self.count, display)
            self.indentation += '    '
            self.file.write(text.replace('\t', self.indentation))
            self.count += 1

    def leave(self):
        # leave evaluation of a graph
        if self.file:
            self.indentation = self.indentation[:-4]
            self.file.write(self.LEAVE.replace('\t', self.indentation))
            self.depth -= 1

    def dump(self, text, bold=False):
        if self.file:
            text = self.htmlquote(text)
            if bold:
                text = '<b>%s</b>' % (text,)
            self.file.write(text.replace('\n', '\n'+self.indentation))

    def flush(self):
        if self.file:
            self.file.flush()

def wrap_callable(llinterpreter, fn, obj, method_name):
    if method_name is None:
        # fn is a StaticMethod
        if obj is not None:
            self_arg = [obj]
        else:
            self_arg = []
        func_graph = fn.graph
    else:
        # obj is an instance, we want to call 'method_name' on it
        assert fn is None
        self_arg = [obj]
        func_graph = obj._TYPE._methods[method_name._str].graph

    return wrap_graph(llinterpreter, func_graph, self_arg)

def wrap_graph(llinterpreter, graph, self_arg):
    """
    Returns a callable that inteprets the given func or method_name when called.
    """

    def interp_func(*args):
        graph_args = self_arg + list(args)
        return llinterpreter.eval_graph(graph, args=graph_args)
    interp_func.graph = graph
    interp_func.self_arg = self_arg
    return graph.name, interp_func


def enumerate_exceptions_top_down():
    import exceptions
    result = []
    seen = {}
    def addcls(cls):
        if (type(cls) is type(Exception) and
            issubclass(cls, py.builtin.BaseException)):
            if cls in seen:
                return
            for base in cls.__bases__:   # bases first
                addcls(base)
            result.append(cls)
            seen[cls] = True
    for cls in exceptions.__dict__.values():
        addcls(cls)
    return result

class _address_of_local_var(object):
    _TYPE = llmemory.Address
    def __init__(self, frame, v):
        self._frame = frame
        self._v = v
    def _getaddress(self):
        return _address_of_local_var_accessor(self._frame, self._v)
    address = property(_getaddress)

class _address_of_local_var_accessor(object):
    def __init__(self, frame, v):
        self.frame = frame
        self.v = v
    def __getitem__(self, index):
        if index != 0:
            raise IndexError("address of local vars only support [0] indexing")
        p = self.frame.getval(self.v)
        result = llmemory.cast_ptr_to_adr(p)
        # the GC should never see instances of _gctransformed_wref
        result = self.unwrap_possible_weakref(result)
        return result
    def __setitem__(self, index, newvalue):
        if index != 0:
            raise IndexError("address of local vars only support [0] indexing")
        if self.v.concretetype == llmemory.WeakRefPtr:
            # fish some more
            assert isinstance(newvalue, llmemory.fakeaddress)
            p = llmemory.cast_ptr_to_weakrefptr(newvalue.ptr)
        else:
            p = llmemory.cast_adr_to_ptr(newvalue, self.v.concretetype)
        self.frame.setvar(self.v, p)
    def unwrap_possible_weakref(self, addr):
        # fish fish fish
        if addr and isinstance(addr.ptr._obj, llmemory._gctransformed_wref):
            return llmemory.fakeaddress(addr.ptr._obj._ptr)
        return addr

class _address_of_thread_local(object):
    _TYPE = llmemory.Address
    is_fake_thread_local_addr = True

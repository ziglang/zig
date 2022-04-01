from rpython.rtyper.lltypesystem import rffi, lltype, llmemory
from rpython.translator.tool.cbuild import ExternalCompilationInfo
from rpython.translator import cdir
import py, sys
from rpython.rlib import jit, rgc
from rpython.rlib.debug import ll_assert
from rpython.rlib.objectmodel import we_are_translated, specialize
from rpython.rlib.objectmodel import CDefinedIntSymbolic, not_rpython
from rpython.rtyper.lltypesystem.lloperation import llop
from rpython.rtyper.tool import rffi_platform
from rpython.rtyper.extregistry import ExtRegistryEntry

class RThreadError(Exception):
    pass
error = RThreadError

translator_c_dir = py.path.local(cdir)

eci = ExternalCompilationInfo(
    includes = ['src/thread.h'],
    separate_module_files = [translator_c_dir / 'src' / 'thread.c'],
    include_dirs = [translator_c_dir],
)

class CConfig:
    _compilation_info_ = eci
    RPYTHREAD_NAME = rffi_platform.DefinedConstantString('RPYTHREAD_NAME')
    USE_SEMAPHORES = rffi_platform.Defined('USE_SEMAPHORES')
    CS_GNU_LIBPTHREAD_VERSION = rffi_platform.DefinedConstantInteger(
        '_CS_GNU_LIBPTHREAD_VERSION')
cconfig = rffi_platform.configure(CConfig)
globals().update(cconfig)


def llexternal(name, args, result, **kwds):
    kwds.setdefault('sandboxsafe', True)
    return rffi.llexternal(name, args, result, compilation_info=eci,
                           **kwds)

@not_rpython
def _emulated_start_new_thread(func):
    import thread
    try:
        ident = thread.start_new_thread(func, ())
    except thread.error:
        ident = -1
    return rffi.cast(lltype.Signed, ident)

CALLBACK = lltype.Ptr(lltype.FuncType([], lltype.Void))
c_thread_start = llexternal('RPyThreadStart', [CALLBACK], lltype.Signed,
                            _callable=_emulated_start_new_thread,
                            releasegil=True)  # release the GIL, but most
                                              # importantly, reacquire it
                                              # around the callback

TLOCKP = rffi.COpaquePtr('struct RPyOpaque_ThreadLock',
                          compilation_info=eci)
TLOCKP_SIZE = rffi_platform.sizeof('struct RPyOpaque_ThreadLock', eci)
c_thread_lock_init = llexternal('RPyThreadLockInit', [TLOCKP], rffi.INT,
                                releasegil=False)   # may add in a global list
c_thread_lock_dealloc_NOAUTO = llexternal('RPyOpaqueDealloc_ThreadLock',
                                          [TLOCKP], lltype.Void,
                                          _nowrapper=True)
c_thread_acquirelock = llexternal('RPyThreadAcquireLock', [TLOCKP, rffi.INT],
                                  rffi.INT,
                                  releasegil=True)    # release the GIL
c_thread_acquirelock_timed = llexternal('RPyThreadAcquireLockTimed',
                                        [TLOCKP, rffi.LONGLONG, rffi.INT],
                                        rffi.INT,
                                        releasegil=True)    # release the GIL
c_thread_releaselock = llexternal('RPyThreadReleaseLock', [TLOCKP],
                                  lltype.Signed,
                                  _nowrapper=True)   # *don't* release the GIL

# another set of functions, this time in versions that don't cause the
# GIL to be released.  Used to be there to handle the GIL lock itself,
# but that was changed (see rgil.py).  Now here for performance only.
c_thread_acquirelock_NOAUTO = llexternal('RPyThreadAcquireLock',
                                         [TLOCKP, rffi.INT], rffi.INT,
                                         _nowrapper=True)
c_thread_acquirelock_timed_NOAUTO = llexternal('RPyThreadAcquireLockTimed',
                                         [TLOCKP, rffi.LONGLONG, rffi.INT],
                                         rffi.INT, _nowrapper=True)
c_thread_releaselock_NOAUTO = c_thread_releaselock


def allocate_lock():
    # Add some memory pressure for the size of the lock because it is an
    # Opaque object
    lock = Lock(allocate_ll_lock())
    rgc.add_memory_pressure(TLOCKP_SIZE, lock)
    return lock

@specialize.arg(0)
def ll_start_new_thread(func):
    from rpython.rlib import rgil
    _check_thread_enabled()
    rgil.allocate()
    # ^^^ convenience: any RPython program which uses explicitly
    # rthread.start_new_thread() will initialize the GIL at that
    # point.
    ident = c_thread_start(func)
    if ident == -1:
        raise error("can't start new thread")
    return ident

# wrappers...

def get_ident():
    if we_are_translated():
        return tlfield_thread_ident.getraw()
    else:
        try:
            import thread
        except ImportError:
            return 42
        return thread.get_ident()

def get_or_make_ident():
    if we_are_translated():
        return tlfield_thread_ident.get_or_make_raw()
    else:
        return get_ident()

@specialize.arg(0)
def start_new_thread(x, y):
    """In RPython, no argument can be passed.  You have to use global
    variables to pass information to the new thread.  That's not very
    nice, but at least it avoids some levels of GC issues.
    """
    assert len(y) == 0
    return ll_start_new_thread(x)

class DummyLock(object):
    def acquire(self, flag):
        return True

    def is_acquired(self):
        return False

    def release(self):
        pass

    def _freeze_(self):
        return True

    def __enter__(self):
        pass

    def __exit__(self, *args):
        pass

dummy_lock = DummyLock()

class Lock(object):
    """ Container for low-level implementation
    of a lock object
    """
    _immutable_fields_ = ["_lock"]

    def __init__(self, ll_lock):
        self._lock = ll_lock

    def acquire(self, flag):
        if flag:
            res = c_thread_acquirelock(self._lock, 1)
            if rffi.cast(lltype.Signed, res) != 1:
                raise error("lock acquire returned an unexpected error")
            return True
        else:
            res = c_thread_acquirelock_timed_NOAUTO(
                self._lock,
                rffi.cast(rffi.LONGLONG, 0),
                rffi.cast(rffi.INT, 0))
            res = rffi.cast(lltype.Signed, res)
            return bool(res)

    def is_acquired(self):
        """ check if the lock is acquired (does not release the GIL) """
        res = c_thread_acquirelock_timed_NOAUTO(
            self._lock,
            rffi.cast(rffi.LONGLONG, 0),
            rffi.cast(rffi.INT, 0))
        res = rffi.cast(lltype.Signed, res)
        return not bool(res)

    def acquire_timed(self, timeout):
        """Timeout is in microseconds.  Returns 0 in case of failure,
        1 in case it works, 2 if interrupted by a signal."""
        res = c_thread_acquirelock_timed(self._lock, timeout, 1)
        res = rffi.cast(lltype.Signed, res)
        return res

    def release(self):
        if c_thread_releaselock(self._lock) != 0:
            raise error("the lock was not previously acquired")

    def __del__(self):
        if free_ll_lock is None:  # happens when tests are shutting down
            return
        free_ll_lock(self._lock)

    def __enter__(self):
        self.acquire(True)

    def __exit__(self, *args):
        self.release()

    def _cleanup_(self):
        raise Exception("seeing a prebuilt rpython.rlib.rthread.Lock instance")

def _check_thread_enabled():
    pass
class Entry(ExtRegistryEntry):
    _about_ = _check_thread_enabled
    def compute_result_annotation(self):
        translator = self.bookkeeper.annotator.translator
        if not translator.config.translation.thread:
            raise Exception(
                "this RPython program uses threads: translate with '--thread'")
    def specialize_call(self, hop):
        hop.exception_cannot_occur()

# ____________________________________________________________
#
# Stack size

get_stacksize = llexternal('RPyThreadGetStackSize', [], lltype.Signed)
set_stacksize = llexternal('RPyThreadSetStackSize', [lltype.Signed],
                           lltype.Signed)

# ____________________________________________________________
#
# Hack

thread_after_fork = llexternal('RPyThreadAfterFork', [], lltype.Void)

# ____________________________________________________________
#
# GIL support wrappers

null_ll_lock = lltype.nullptr(TLOCKP.TO)

def allocate_ll_lock():
    # track_allocation=False here; be careful to lltype.free() it.  The
    # reason it is set to False is that we get it from all app-level
    # lock objects, as well as from the GIL, which exists at shutdown.
    ll_lock = lltype.malloc(TLOCKP.TO, flavor='raw', track_allocation=False)
    res = c_thread_lock_init(ll_lock)
    if rffi.cast(lltype.Signed, res) <= 0:
        lltype.free(ll_lock, flavor='raw', track_allocation=False)
        raise error("out of resources")
    return ll_lock

def free_ll_lock(ll_lock):
    acquire_NOAUTO(ll_lock, False)
    release_NOAUTO(ll_lock)
    c_thread_lock_dealloc_NOAUTO(ll_lock)
    lltype.free(ll_lock, flavor='raw', track_allocation=False)

def acquire_NOAUTO(ll_lock, flag):
    flag = rffi.cast(rffi.INT, int(flag))
    res = c_thread_acquirelock_NOAUTO(ll_lock, flag)
    res = rffi.cast(lltype.Signed, res)
    return bool(res)

def release_NOAUTO(ll_lock):
    if not we_are_translated():
        ll_assert(not acquire_NOAUTO(ll_lock, False), "NOAUTO lock not held!")
    c_thread_releaselock_NOAUTO(ll_lock)

# ____________________________________________________________
#
# Thread integration.
# These are five completely ad-hoc operations at the moment.

@jit.dont_look_inside
def gc_thread_run():
    """To call whenever the current thread (re-)acquired the GIL.
    """
    if we_are_translated():
        llop.gc_thread_run(lltype.Void)
gc_thread_run._always_inline_ = True

@jit.dont_look_inside
def gc_thread_start():
    """To call at the beginning of a new thread.
    """
    if we_are_translated():
        llop.gc_thread_start(lltype.Void)

@jit.dont_look_inside
def gc_thread_die():
    """To call just before the final GIL release done by a dying
    thread.  After a thread_die(), no more gc operation should
    occur in this thread.
    """
    if we_are_translated():
        llop.gc_thread_die(lltype.Void)
gc_thread_die._always_inline_ = True

@jit.dont_look_inside
def gc_thread_before_fork():
    """To call just before fork().  Prepares for forking, after
    which only the current thread will be alive.
    """
    if we_are_translated():
        return llop.gc_thread_before_fork(llmemory.Address)
    else:
        return llmemory.NULL

@jit.dont_look_inside
def gc_thread_after_fork(result_of_fork, opaqueaddr):
    """To call just after fork().
    """
    if we_are_translated():
        llop.gc_thread_after_fork(lltype.Void, result_of_fork, opaqueaddr)
    else:
        assert opaqueaddr == llmemory.NULL

# ____________________________________________________________
#
# Thread-locals.


class ThreadLocalField(object):
    @not_rpython
    def __init__(self, FIELDTYPE, fieldname, loop_invariant=False):
        "must be prebuilt"
        try:
            from thread import _local
        except ImportError:
            class _local(object):
                pass
        self.FIELDTYPE = FIELDTYPE
        self.fieldname = fieldname
        self.local = _local()      # <- not rpython
        zero = rffi.cast(FIELDTYPE, 0)
        offset = CDefinedIntSymbolic('RPY_TLOFS_%s' % self.fieldname,
                                     default='?')
        offset.loop_invariant = loop_invariant
        self._offset = offset

        def getraw():
            if we_are_translated():
                _threadlocalref_seeme(self)
                return llop.threadlocalref_get(FIELDTYPE, offset)
            else:
                return getattr(self.local, 'rawvalue', zero)

        @jit.dont_look_inside
        def get_or_make_raw():
            if we_are_translated():
                _threadlocalref_seeme(self)
                return llop.threadlocalref_load(FIELDTYPE, offset)
            else:
                return getattr(self.local, 'rawvalue', zero)

        @jit.dont_look_inside
        def setraw(value):
            if we_are_translated():
                _threadlocalref_seeme(self)
                llop.threadlocalref_store(lltype.Void, offset, value)
            else:
                self.local.rawvalue = value

        def getoffset():
            _threadlocalref_seeme(self)
            return offset

        self.getraw = getraw
        self.get_or_make_raw = get_or_make_raw
        self.setraw = setraw
        self.getoffset = getoffset

    def _freeze_(self):
        return True


class ThreadLocalReference(ThreadLocalField):
    # A thread-local that points to an object.  The object stored in such
    # a thread-local is kept alive as long as the thread is not finished
    # (but only with our own GCs!  it seems not to work with Boehm...)
    # (also, on Windows, if you're not making a DLL but an EXE, it will
    # leak the objects when a thread finishes; see threadlocal.c.)
    _COUNT = 1

    @not_rpython
    def __init__(self, Cls, loop_invariant=False):
        "must be prebuilt"
        self.Cls = Cls
        unique_id = ThreadLocalReference._COUNT
        ThreadLocalReference._COUNT += 1
        ThreadLocalField.__init__(self, lltype.Signed, 'tlref%d' % unique_id,
                                  loop_invariant=loop_invariant)
        offset = self._offset

        def get():
            if we_are_translated():
                from rpython.rtyper import rclass
                from rpython.rtyper.annlowlevel import cast_base_ptr_to_instance
                _threadlocalref_seeme(self)
                ptr = llop.threadlocalref_get(rclass.OBJECTPTR, offset)
                return cast_base_ptr_to_instance(Cls, ptr)
            else:
                return getattr(self.local, 'value', None)

        @jit.dont_look_inside
        def set(value):
            assert isinstance(value, Cls) or value is None
            if we_are_translated():
                from rpython.rtyper.annlowlevel import cast_instance_to_base_ptr
                ptr = cast_instance_to_base_ptr(value)
                _threadlocalref_seeme(self)
                llop.threadlocalref_store(lltype.Void, offset, ptr)
                rgc.register_custom_trace_hook(TRACETLREF, _lambda_trace_tlref)
                rgc.ll_writebarrier(_tracetlref_obj)
            else:
                self.local.value = value

        self.get = get
        self.set = set

        def _trace_tlref(gc, obj, callback, arg):
            p = llmemory.NULL
            llop.threadlocalref_acquire(lltype.Void)
            while True:
                p = llop.threadlocalref_enum(llmemory.Address, p)
                if not p:
                    break
                gc._trace_callback(callback, arg, p + offset)
            llop.threadlocalref_release(lltype.Void)
        _lambda_trace_tlref = lambda: _trace_tlref
        # WAAAH obscurity: can't use a name that may be non-unique,
        # otherwise the types compare equal, even though we call
        # register_custom_trace_hook() to register different trace
        # functions...
        TRACETLREF = lltype.GcStruct('TRACETLREF%d' % unique_id)
        _tracetlref_obj = lltype.malloc(TRACETLREF, immortal=True)

    @staticmethod
    def automatic_keepalive(config):
        """Returns True if translated with a GC that keeps alive
        the set() value until the end of the thread.  Returns False
        if you need to keep it alive yourself (but in that case, you
        should also reset it to None before the thread finishes).
        """
        return (config.translation.gctransformer == "framework" and
                # see translator/c/src/threadlocal.c for the following line
                (not _win32 or config.translation.shared))


tlfield_thread_ident = ThreadLocalField(lltype.Signed, "thread_ident",
                                        loop_invariant=True)
tlfield_p_errno = ThreadLocalField(rffi.CArrayPtr(rffi.INT), "p_errno",
                                   loop_invariant=True)
tlfield_rpy_errno = ThreadLocalField(rffi.INT, "rpy_errno")
tlfield_alt_errno = ThreadLocalField(rffi.INT, "alt_errno")
_win32 = (sys.platform == "win32")
if _win32:
    from rpython.rlib import rwin32
    tlfield_rpy_lasterror = ThreadLocalField(rwin32.DWORD, "rpy_lasterror")
    tlfield_alt_lasterror = ThreadLocalField(rwin32.DWORD, "alt_lasterror")

@not_rpython
def _threadlocalref_seeme(field):
    pass

class _Entry(ExtRegistryEntry):
    _about_ = _threadlocalref_seeme

    def compute_result_annotation(self, s_field):
        field = s_field.const
        self.bookkeeper.thread_local_fields.add(field)

    def specialize_call(self, hop):
        hop.exception_cannot_occur()

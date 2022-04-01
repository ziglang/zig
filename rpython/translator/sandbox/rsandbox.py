"""Generation of sandboxing stand-alone executable from RPython code.
In place of real calls to any external function, this code builds
trampolines that marshal their input arguments, dump them to STDOUT,
and wait for an answer on STDIN.  Enable with 'translate.py --sandbox'.
"""
import py

from rpython.rlib import rmarshal, types
from rpython.rlib.signature import signature

# ____________________________________________________________
#
# Sandboxing code generator for external functions
#

from rpython.rlib import rposix
from rpython.rtyper.lltypesystem import lltype, rffi
from rpython.rtyper.llannotation import lltype_to_annotation
from rpython.rtyper.annlowlevel import MixLevelHelperAnnotator
from rpython.tool.ansi_print import AnsiLogger

log = AnsiLogger("sandbox")


# a version of os.read() and os.write() that are not mangled
# by the sandboxing mechanism
ll_read_not_sandboxed = rposix.external('read',
                                        [rffi.INT, rffi.CCHARP, rffi.SIZE_T],
                                        rffi.SIZE_T,
                                        sandboxsafe=True,
                                        _nowrapper=True)

ll_write_not_sandboxed = rposix.external('write',
                                         [rffi.INT, rffi.CCHARP, rffi.SIZE_T],
                                         rffi.SIZE_T,
                                         sandboxsafe=True,
                                         _nowrapper=True)


@signature(types.int(), types.ptr(rffi.CCHARP.TO), types.int(),
    returns=types.none())
def writeall_not_sandboxed(fd, buf, length):
    fd = rffi.cast(rffi.INT, fd)
    while length > 0:
        size = rffi.cast(rffi.SIZE_T, length)
        count = rffi.cast(lltype.Signed, ll_write_not_sandboxed(fd, buf, size))
        if count <= 0:
            raise IOError
        length -= count
        buf = lltype.direct_ptradd(lltype.direct_arrayitems(buf), count)
        buf = rffi.cast(rffi.CCHARP, buf)


class FdLoader(rmarshal.Loader):
    def __init__(self, fd):
        rmarshal.Loader.__init__(self, "")
        self.fd = fd
        self.buflen = 4096

    def need_more_data(self):
        buflen = self.buflen
        with lltype.scoped_alloc(rffi.CCHARP.TO, buflen) as buf:
            buflen = rffi.cast(rffi.SIZE_T, buflen)
            fd = rffi.cast(rffi.INT, self.fd)
            count = ll_read_not_sandboxed(fd, buf, buflen)
            count = rffi.cast(lltype.Signed, count)
            if count <= 0:
                raise IOError
            self.buf += ''.join([buf[i] for i in range(count)])
            self.buflen *= 2

def sandboxed_io(buf):
    STDIN = 0
    STDOUT = 1
    # send the buffer with the marshalled fnname and input arguments to STDOUT
    with lltype.scoped_alloc(rffi.CCHARP.TO, len(buf)) as p:
        for i in range(len(buf)):
            p[i] = buf[i]
        writeall_not_sandboxed(STDOUT, p, len(buf))
    # build a Loader that will get the answer from STDIN
    loader = FdLoader(STDIN)
    # check for errors
    error = load_int(loader)
    if error != 0:
        reraise_error(error, loader)
    else:
        # no exception; the caller will decode the actual result
        return loader

def reraise_error(error, loader):
    if error == 1:
        raise OSError(load_int(loader), "external error")
    elif error == 2:
        raise IOError
    elif error == 3:
        raise OverflowError
    elif error == 4:
        raise ValueError
    elif error == 5:
        raise ZeroDivisionError
    elif error == 6:
        raise MemoryError
    elif error == 7:
        raise KeyError
    elif error == 8:
        raise IndexError
    else:
        raise RuntimeError


@signature(types.str(), returns=types.impossible())
def not_implemented_stub(msg):
    STDERR = 2
    with rffi.scoped_str2charp(msg + '\n') as buf:
        writeall_not_sandboxed(STDERR, buf, len(msg) + 1)
    raise RuntimeError(msg)  # XXX in RPython, the msg is ignored

def make_stub(fnname, msg):
    """Build always-raising stub function to replace unsupported external."""
    log.WARNING(msg)

    def execute(*args):
        not_implemented_stub(msg)
    execute.__name__ = 'sandboxed_%s' % (fnname,)
    return execute

def sig_ll(fnobj):
    FUNCTYPE = lltype.typeOf(fnobj)
    args_s = [lltype_to_annotation(ARG) for ARG in FUNCTYPE.ARGS]
    s_result = lltype_to_annotation(FUNCTYPE.RESULT)
    return args_s, s_result

dump_string = rmarshal.get_marshaller(str)
load_int = rmarshal.get_loader(int)

def get_sandbox_stub(fnobj, rtyper):
    fnname = fnobj._name
    args_s, s_result = sig_ll(fnobj)
    msg = "Not implemented: sandboxing for external function '%s'" % (fnname,)
    execute = make_stub(fnname, msg)
    return _annotate(rtyper, execute, args_s, s_result)

def make_sandbox_trampoline(fnname, args_s, s_result):
    """Create a trampoline function with the specified signature.

    The trampoline is meant to be used in place of real calls to the external
    function named 'fnname'.  It marshals its input arguments, dumps them to
    STDOUT, and waits for an answer on STDIN.
    """
    try:
        dump_arguments = rmarshal.get_marshaller(tuple(args_s))
        load_result = rmarshal.get_loader(s_result)
    except (rmarshal.CannotMarshal, rmarshal.CannotUnmarshall) as e:
        msg = "Cannot sandbox function '%s': %s" % (fnname, e)
        execute = make_stub(fnname, msg)
    else:
        def execute(*args):
            # marshal the function name and input arguments
            buf = []
            dump_string(buf, fnname)
            dump_arguments(buf, args)
            # send the buffer and wait for the answer
            loader = sandboxed_io(buf)
            # decode the answer
            result = load_result(loader)
            loader.check_finished()
            return result
        execute.__name__ = 'sandboxed_%s' % (fnname,)
    return execute


def _annotate(rtyper, f, args_s, s_result):
    ann = MixLevelHelperAnnotator(rtyper)
    graph = ann.getgraph(f, args_s, s_result)
    ann.finish()
    return graph

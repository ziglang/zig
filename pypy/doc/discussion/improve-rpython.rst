Possible improvements of the rpython language
=============================================

Improve the interpreter API
---------------------------

- Rationalize the modules, and the names, of the different functions needed to
  implement a pypy module. A typical rpython file is likely to contain many
  `import` statements::

    from pypy.interpreter.baseobjspace import W_Root
    from pypy.interpreter.gateway import ObjSpace, W_Root
    from pypy.interpreter.argument import Arguments
    from pypy.interpreter.typedef import TypeDef, GetSetProperty
    from pypy.interpreter.typedef import interp_attrproperty, interp_attrproperty_w
    from pypy.interpreter.gateway import interp2app
    from pypy.interpreter.error import OperationError
    from rpython.rtyper.lltypesystem import rffi, lltype

- A more direct declarative way to write Typedef::

    class W_Socket(W_Root):
        _typedef_name_ = 'socket'
        _typedef_base_ = W_EventualBaseClass

        @interp2app_method("connect", ['self', ObjSpace, W_Root])
        def connect_w(self, space, w_addr):
            ...

- Support for metaclasses written in rpython. For a sample, see the skipped test
  `pypy.objspace.std.test.TestTypeObject.test_metaclass_typedef`

RPython language
----------------

- Arithmetic with unsigned integer, and between integer of different signedness,
  when this is not ambiguous.  At least, comparison and assignment with
  constants should be allowed.

- Allocate variables on the stack, and pass their address ("by reference") to
  llexternal functions. For a typical usage, see
  `rpython.rlib.rsocket.RSocket.getsockopt_int`.

Extensible type system for llexternal
-------------------------------------

llexternal allows the description of a C function, and conveys the same
information about the arguments as a C header.  But this is often not enough.
For example, a parameter of type `int*` is converted to
`rffi.CArrayPtr(rffi.INT)`, but this information is not enough to use the
function. The parameter could be an array of int, a reference to a single value,
for input or output...

A "type system" could hold this additional information, and automatically
generate some conversion code to ease the usage of the function from
rpython. For example::

    # double frexp(double x, int *exp);
    frexp = llexternal("frexp", [rffi.DOUBLE, OutPtr(rffi.int)], rffi.DOUBLE)

`OutPtr` indicates that the parameter is output-only, which need not to be
initialized, and which *value* is returned to the caller. In rpython the call
becomes::

    fraction, exponent = frexp(value)

Also, we could imagine that one item in the llexternal argument list corresponds
to two parameters in C. Here, OutCharBufferN indicates that the caller will pass
a rpython string; the framework will pass buffer and length to the function::

    # ssize_t write(int fd, const void *buf, size_t count);
    write = llexternal("write", [rffi.INT, CharBufferAndSize], rffi.SSIZE_T)

The rpython code that calls this function is very simple::

    written = write(fd, data)

compared with the present::

    count = len(data)
    buf = rffi.get_nonmovingbuffer(data)
    try:
        written = rffi.cast(lltype.Signed, os_write(
            rffi.cast(rffi.INT, fd),
            buf, rffi.cast(rffi.SIZE_T, count)))
    finally:
        rffi.free_nonmovingbuffer(data, buf)

Typemaps are very useful for large APIs where the same conversions are needed in
many places.  XXX example

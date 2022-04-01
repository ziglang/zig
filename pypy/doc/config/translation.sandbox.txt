Generate a special fully-sandboxed executable.

The fully-sandboxed executable cannot be run directly, but
only as a subprocess of an outer "controlling" process.  The
sandboxed process is "safe" in the sense that it doesn't do
any library or system call - instead, whenever it would like
to perform such an operation, it marshals the operation name
and the arguments to its stdout and it waits for the
marshalled result on its stdin.  This controller process must
handle these operation requests, in any way it likes, allowing
full virtualization.

For examples of controller processes, see
``pypy/translator/sandbox/interact.py`` and
``pypy/translator/sandbox/pypy_interact.py``.

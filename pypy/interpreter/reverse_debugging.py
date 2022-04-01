import sys
from rpython.rlib import revdb
from rpython.rlib.debug import make_sure_not_resized
from rpython.rlib.objectmodel import specialize, we_are_translated
from rpython.rtyper.annlowlevel import cast_gcref_to_instance
from pypy.interpreter.error import OperationError, oefmt
from pypy.interpreter.baseobjspace import W_Root
from pypy.interpreter import gateway, typedef, pycode, pytraceback, pyframe
from pypy.module.marshal import interp_marshal
from pypy.interpreter.executioncontext import AbstractActionFlag, ActionFlag


class DBState:
    standard_code = True
    breakpoint_stack_id = 0
    breakpoint_funcnames = None
    breakpoint_filelines = None
    breakpoint_by_file = None
    breakpoint_version = 0
    printed_objects = {}
    metavars = []
    watch_progs = []
    watch_futures = {}

dbstate = DBState()


pycode.PyCode.co_revdb_linestarts = None   # or a string: see below
pycode.PyCode.co_revdb_bkpt_version = 0    # see check_and_trigger_bkpt()
pycode.PyCode.co_revdb_bkpt_cache = None   # see check_and_trigger_bkpt()

# invariant: "f_revdb_nextline_instr" is the bytecode offset of
# the start of the line that follows "last_instr".
pyframe.PyFrame.f_revdb_nextline_instr = -1


# ____________________________________________________________


def setup_revdb(space):
    """Called at run-time, before the space is set up.

    The various register_debug_command() lines attach functions
    to some commands that 'revdb.py' can call, if we are running
    in replay mode.
    """
    assert space.config.translation.reverse_debugger
    dbstate.space = space

    make_sure_not_resized(dbstate.watch_progs)
    make_sure_not_resized(dbstate.metavars)

    revdb.register_debug_command(revdb.CMD_PRINT, lambda_print)
    revdb.register_debug_command(revdb.CMD_BACKTRACE, lambda_backtrace)
    revdb.register_debug_command(revdb.CMD_LOCALS, lambda_locals)
    revdb.register_debug_command(revdb.CMD_BREAKPOINTS, lambda_breakpoints)
    revdb.register_debug_command(revdb.CMD_STACKID, lambda_stackid)
    revdb.register_debug_command("ALLOCATING", lambda_allocating)
    revdb.register_debug_command(revdb.CMD_ATTACHID, lambda_attachid)
    revdb.register_debug_command(revdb.CMD_COMPILEWATCH, lambda_compilewatch)
    revdb.register_debug_command(revdb.CMD_CHECKWATCH, lambda_checkwatch)
    revdb.register_debug_command(revdb.CMD_WATCHVALUES, lambda_watchvalues)


# ____________________________________________________________


def enter_call(caller_frame, callee_frame):
    if dbstate.breakpoint_funcnames is not None:
        name = callee_frame.getcode().co_name
        if name in dbstate.breakpoint_funcnames:
            revdb.breakpoint(dbstate.breakpoint_funcnames[name])
    if dbstate.breakpoint_stack_id != 0 and caller_frame is not None:
        if dbstate.breakpoint_stack_id == revdb.get_unique_id(caller_frame):
            revdb.breakpoint(-1)
    #
    code = callee_frame.pycode
    if code.co_revdb_linestarts is None:
        build_co_revdb_linestarts(code)

def leave_call(caller_frame, got_exception):
    if dbstate.breakpoint_stack_id != 0 and caller_frame is not None:
        if dbstate.breakpoint_stack_id == revdb.get_unique_id(caller_frame):
            revdb.breakpoint(-2)
    if we_are_translated():
        stop_point_activate(-2 + got_exception)

def stop_point():
    if we_are_translated():
        revdb.breakpoint(-3)


def jump_backward(frame, jumpto):
    # When we see a jump backward, we set 'f_revdb_nextline_instr' in
    # such a way that the next instruction, at 'jumpto', will trigger
    # stop_point_activate().  We have to trigger it even if
    # 'jumpto' is not actually a start of line.  For example, after a
    # 'while foo:', the body ends with a JUMP_ABSOLUTE which
    # jumps back to the *second* opcode of the while.
    frame.f_revdb_nextline_instr = jumpto


def potential_stop_point(frame):
    if not we_are_translated():
        return
    #
    # We only record a stop_point at every line, not every bytecode.
    # Uses roughly the same algo as ExecutionContext.run_trace_func()
    # to know where the line starts are, but tweaked for speed,
    # avoiding the quadratic complexity when run N times with a large
    # code object.
    #
    cur = frame.last_instr
    if cur < frame.f_revdb_nextline_instr:
        return    # fast path: we're still inside the same line as before
    #
    call_stop_point_at_line = True
    co_revdb_linestarts = frame.pycode.co_revdb_linestarts
    if cur > frame.f_revdb_nextline_instr:
        #
        # We jumped forward over the start of the next line.  We're
        # inside a different line, but we will only trigger a stop
        # point if we're at the starting bytecode of that line.  Fetch
        # from co_revdb_linestarts the start of the line that is at or
        # follows 'cur'.
        ch = ord(co_revdb_linestarts[cur])
        if ch == 0:
            pass   # we are at the start of a line now
        else:
            # We are not, so don't call stop_point_activate().
            # We still have to fill f_revdb_nextline_instr.
            call_stop_point_at_line = False
    #
    if call_stop_point_at_line:
        stop_point_activate(pycode=frame.pycode, opindex=cur)
        cur += 1
        ch = ord(co_revdb_linestarts[cur])
    #
    # Update f_revdb_nextline_instr.  Check if 'ch' was greater than
    # 255, in which case it was rounded down to 255 and we have to
    # continue looking
    nextline_instr = cur + ch
    while ch == 255:
        ch = ord(co_revdb_linestarts[nextline_instr])
        nextline_instr += ch
    frame.f_revdb_nextline_instr = nextline_instr


def build_co_revdb_linestarts(code):
    # Inspired by findlinestarts() in the 'dis' standard module.
    # Set up 'bits' so that it contains \x00 at line starts and \xff
    # in-between.
    bits = ['\xff'] * (len(code.co_code) + 1)
    if not code.hidden_applevel:
        lnotab = code.co_lnotab
        addr = 0
        p = 0
        newline = 1
        while p + 1 < len(lnotab):
            byte_incr = ord(lnotab[p])
            line_incr = ord(lnotab[p+1])   # signed (maybe negative) from py3.6
            if byte_incr:
                if newline != 0:
                    bits[addr] = '\x00'
                    newline = 0
                addr += byte_incr
            newline |= line_incr
            p += 2
        if newline:
            bits[addr] = '\x00'
    bits[len(code.co_code)] = '\x00'
    #
    # Change 'bits' so that the character at 'i', if not \x00, measures
    # how far the next \x00 is
    next_null = len(code.co_code)
    p = next_null - 1
    while p >= 0:
        if bits[p] == '\x00':
            next_null = p
        else:
            ch = next_null - p
            if ch > 255: ch = 255
            bits[p] = chr(ch)
        p -= 1
    lstart = ''.join(bits)
    code.co_revdb_linestarts = lstart
    return lstart

def get_final_lineno(code):
    lineno = code.co_firstlineno
    largest_line_no = lineno
    lnotab = code.co_lnotab
    p = 1
    while p < len(lnotab):
        line_incr = ord(lnotab[p])
        if line_incr > 0x7f:
            line_incr -= 0x100
        lineno += line_incr
        if lineno > largest_line_no:
            largest_line_no = lineno
        p += 2
    return largest_line_no

def find_line_starts(code):
    # RPython version of dis.findlinestarts()
    lnotab = code.co_lnotab
    lastlineno = -1
    lineno = code.co_firstlineno
    addr = 0
    p = 0
    result = []
    while p < len(lnotab) - 1:
        byte_incr = ord(lnotab[p + 0])
        line_incr = ord(lnotab[p + 1])
        if byte_incr:
            if lineno != lastlineno:
                result.append((addr, lineno))
                lastlineno = lineno
            addr += byte_incr
        if line_incr > 0x7f:
            line_incr -= 0x100
        lineno += line_incr
        p += 2
    if lineno != lastlineno:
        result.append((addr, lineno))
    return result

class NonStandardCode(object):
    def __enter__(self):
        dbstate.standard_code = False
        self.t = dbstate.space.actionflag._ticker
        self.c = dbstate.space.actionflag._ticker_revdb_count
    def __exit__(self, *args):
        dbstate.space.actionflag._ticker = self.t
        dbstate.space.actionflag._ticker_revdb_count = self.c
        dbstate.standard_code = True
non_standard_code = NonStandardCode()


def stop_point_activate(place=0, pycode=None, opindex=-1):
    if revdb.watch_save_state():
        any_watch_point = False
        # ^^ this flag is set to True if we must continue to enter this
        # block of code.  If it is still False for watch_restore_state()
        # below, then future watch_save_state() will return False too---
        # until the next time revdb.c:set_revdb_breakpoints() is called.
        space = dbstate.space
        with non_standard_code:
            watch_id = -1
            if dbstate.breakpoint_by_file is not None:
                any_watch_point = True
                if pycode is not None:
                    watch_id = check_and_trigger_bkpt(pycode, opindex)
            if watch_id == -1:
                for prog, watch_id, expected in dbstate.watch_progs:
                    any_watch_point = True
                    try:
                        got = _run_watch(space, prog)
                    except OperationError as e:
                        got = e.errorstr(space)
                    except Exception:
                        break
                    if got != expected:
                        break
                else:
                    watch_id = -1
        revdb.watch_restore_state(any_watch_point)
        if watch_id != -1:
            revdb.breakpoint(watch_id)
    revdb.stop_point(place)


def future_object(space):
    return space.w_Ellipsis    # a random prebuilt object

def load_metavar(index):
    assert index >= 0
    space = dbstate.space
    metavars = dbstate.metavars
    w_var = metavars[index] if index < len(metavars) else None
    if w_var is None:
        raise oefmt(space.w_NameError, "no constant object '$%d'",
                    index)
    if w_var is future_object(space):
        raise oefmt(space.w_RuntimeError,
                    "'$%d' refers to an object created later in time",
                    index)
    return w_var

def set_metavar(index, w_obj):
    assert index >= 0
    if index >= len(dbstate.metavars):
        missing = index + 1 - len(dbstate.metavars)
        dbstate.metavars = dbstate.metavars + [None] * missing
    dbstate.metavars[index] = w_obj


# ____________________________________________________________


def fetch_cur_frame(silent=False):
    ec = dbstate.space.threadlocals.get_ec()
    if ec is None:
        frame = None
    else:
        frame = ec.topframeref()
    if frame is None and not silent:
        revdb.send_print("No stack.")
    return frame

def compile(source, mode):
    assert not dbstate.standard_code
    space = dbstate.space
    compiler = space.createcompiler()
    code = compiler.compile(source, '<revdb>', mode, 0,
                            hidden_applevel=True)
    return code


class W_RevDBOutput(W_Root):
    softspace = 0

    def __init__(self, space):
        self.space = space

    def descr_write(self, w_buffer):
        assert not dbstate.standard_code
        space = self.space
        if space.isinstance_w(w_buffer, space.w_unicode):
            w_buffer = space.call_method(w_buffer, 'encode',
                                         space.newtext('utf-8'))   # safe?
        revdb.send_output(space.bytes_w(w_buffer))

def descr_get_softspace(space, revdb):
    return space.newint(revdb.softspace)
def descr_set_softspace(space, revdb, w_newvalue):
    revdb.softspace = space.int_w(w_newvalue)

W_RevDBOutput.typedef = typedef.TypeDef(
    "revdb_output",
    write = gateway.interp2app(W_RevDBOutput.descr_write),
    # XXX is 'softspace' still necessary in Python 3?
    softspace = typedef.GetSetProperty(descr_get_softspace,
                                       descr_set_softspace,
                                       cls=W_RevDBOutput),
    )

def revdb_displayhook(space, w_obj):
    """Modified sys.displayhook() that also outputs '$NUM = ',
    for non-prebuilt objects.  Such objects are then recorded in
    'printed_objects'.
    """
    assert not dbstate.standard_code
    if space.is_w(w_obj, space.w_None):
        return
    uid = revdb.get_unique_id(w_obj)
    if uid > 0:
        dbstate.printed_objects[uid] = w_obj
        revdb.send_nextnid(uid)   # outputs '$NUM = '
    space.setitem(space.builtin.w_dict, space.newtext('_'), w_obj)
    # do repr() after setitem: if w_obj was produced successfully,
    # but its repr crashes because it tries to do I/O, then we already
    # have it recorded in '_' and in '$NUM ='.
    w_repr = space.repr(w_obj)
    if space.isinstance_w(w_repr, space.w_unicode):
        w_repr = space.call_method(w_repr, 'encode',
                                   space.newtext('utf-8'))   # safe?
    revdb.send_print(space.bytes_w(w_repr))

@gateway.unwrap_spec(name='text0', level=int)
def revdb_importhook(space, name, w_globals=None,
                     w_locals=None, w_fromlist=None, level=-1):
    # Incredibly simplified version of __import__, which only returns
    # already-imported modules and doesn't call any custom import
    # hooks.  Recognizes only absolute imports.  With a 'fromlist'
    # argument that is a non-empty list, returns the module 'name3' if
    # the 'name' argument is 'name1.name2.name3'.  With an empty or
    # None 'fromlist' argument, returns the module 'name1' instead.
    return space.appexec([space.newtext(name), w_fromlist or space.w_None,
                          space.newint(level), space.sys],
    """(name, fromlist, level, sys):
        if level > 0:
            raise ImportError("only absolute imports are "
                               "supported in the debugger")
        basename = name.split('.')[0]
        try:
            basemod = sys.modules[basename]
            mod = sys.modules[name]
        except KeyError:
            raise ImportError("'%s' not found or not imported yet "
                    "(the debugger can't import new modules, "
                    "and only supports absolute imports)" % (name,))
        if fromlist:
            return mod
        return basemod
    """)

@specialize.memo()
def get_revdb_displayhook(space):
    return gateway.interp2app(revdb_displayhook).spacebind(space)

@specialize.memo()
def get_revdb_importhook(space):
    return gateway.interp2app(revdb_importhook).spacebind(space)


def prepare_print_environment(space):
    assert not dbstate.standard_code
    w_revdb_output = W_RevDBOutput(space)
    w_displayhook = get_revdb_displayhook(space)
    w_import = get_revdb_importhook(space)
    space.sys.setdictvalue(space, 'stdout', w_revdb_output)
    space.sys.setdictvalue(space, 'stderr', w_revdb_output)
    space.sys.setdictvalue(space, 'displayhook', w_displayhook)
    space.builtin.setdictvalue(space, '__import__', w_import)

def command_print(cmd, expression):
    frame = fetch_cur_frame()
    if frame is None:
        return
    space = dbstate.space
    with non_standard_code:
        try:
            prepare_print_environment(space)
            code = compile(expression, 'single')
            try:
                code.exec_code(space,
                               frame.get_w_globals(),
                               frame.getdictscope())

            except OperationError as operationerr:
                # can't use sys.excepthook: it will likely try to do 'import
                # traceback', which might not be doable without using I/O
                tb = operationerr.get_traceback()
                if tb is not None:
                    revdb.send_print("Traceback (most recent call last):")
                    while tb is not None:
                        if not isinstance(tb, pytraceback.PyTraceback):
                            revdb.send_print("  ??? %s" % tb)
                            break
                        show_frame(tb.frame, tb.get_lineno(), indent='  ')
                        tb = tb.next
                revdb.send_print(operationerr.errorstr(space))

                # set the sys.last_xxx attributes
                w_type = operationerr.w_type
                w_value = operationerr.get_w_value(space)
                w_tb = operationerr.get_traceback()
                w_dict = space.sys.w_dict
                space.setitem(w_dict, space.newtext('last_type'), w_type)
                space.setitem(w_dict, space.newtext('last_value'), w_value)
                space.setitem(w_dict, space.newtext('last_traceback'), w_tb)

        except OperationError as e:
            revdb.send_print(e.errorstr(space, use_repr=True))
lambda_print = lambda: command_print


def file_and_lineno(frame, lineno):
    code = frame.getcode()
    return 'File "%s", line %d in %s' % (
        code.co_filename, lineno, code.co_name)

def show_frame(frame, lineno=0, indent=''):
    if lineno == 0:
        lineno = frame.get_last_lineno()
    revdb.send_output("%s%s\n%s  " % (
        indent,
        file_and_lineno(frame, lineno),
        indent))
    revdb.send_linecache(frame.getcode().co_filename, lineno)

def display_function_part(frame, max_lines_before, max_lines_after):
    if frame is None:
        return
    code = frame.getcode()
    if code.co_filename.startswith('<builtin>'):
        return
    first_lineno = code.co_firstlineno
    current_lineno = frame.get_last_lineno()
    final_lineno = get_final_lineno(code)
    #
    ellipsis_after = False
    if first_lineno < current_lineno - max_lines_before - 1:
        first_lineno = current_lineno - max_lines_before
        revdb.send_print("...")
    if final_lineno > current_lineno + max_lines_after + 1:
        final_lineno = current_lineno + max_lines_after
        ellipsis_after = True
    #
    for i in range(first_lineno, final_lineno + 1):
        if i == current_lineno:
            if revdb.current_place() == -2: # <= this is the arg to stop_point()
                prompt = "<< "     # return
            elif revdb.current_place() == -1:
                prompt = "!! "     # exceptional return
            else:
                prompt = " > "     # plain line
            revdb.send_output(prompt)
        else:
            revdb.send_output("   ")
        revdb.send_linecache(code.co_filename, i, strip=False)
    #
    if ellipsis_after:
        revdb.send_print("...")

def command_backtrace(cmd, extra):
    frame = fetch_cur_frame(silent=True)
    if cmd.c_arg1 == 0:
        if frame is not None:
            revdb.send_print("%s:" % (
                file_and_lineno(frame, frame.get_last_lineno()),))
        display_function_part(frame, max_lines_before=8, max_lines_after=5)
    elif cmd.c_arg1 == 2:
        display_function_part(frame, max_lines_before=1000,max_lines_after=1000)
    else:
        revdb.send_print("Current call stack (most recent call last):")
        if frame is None:
            revdb.send_print("  (empty)")
        frames = []
        while frame is not None:
            frames.append(frame)
            if len(frames) == 200:
                revdb.send_print("  ...")
                break
            frame = frame.get_f_back()
        while len(frames) > 0:
            show_frame(frames.pop(), indent='  ')
lambda_backtrace = lambda: command_backtrace


def command_locals(cmd, extra):
    frame = fetch_cur_frame()
    if frame is None:
        return
    space = dbstate.space
    with non_standard_code:
        try:
            prepare_print_environment(space)
            space.appexec([space.sys,
                           frame.getdictscope()], """(sys, locals):
                lst = sorted(locals.keys())
                print('Locals:')
                for key in lst:
                    try:
                        print('    %s =' % key, end=' ', flush=True)
                        s = '%r' % locals[key]
                        if len(s) > 140:
                            s = s[:100] + '...' + s[-30:]
                        print(s)
                    except:
                        exc, val, tb = sys.exc_info()
                        print('!<%s: %r>' % (exc, val))
            """)
        except OperationError as e:
            revdb.send_print(e.errorstr(space, use_repr=True))
lambda_locals = lambda: command_locals

# ____________________________________________________________


def check_and_trigger_bkpt(pycode, opindex):
    # We cache on 'pycode.co_revdb_bkpt_cache' either None or a dict
    # mapping {opindex: bkpt_num}.  This cache is updated when the
    # version in 'pycode.co_revdb_bkpt_version' does not match
    # 'dbstate.breakpoint_version' any more.
    if pycode.co_revdb_bkpt_version != dbstate.breakpoint_version:
        update_bkpt_cache(pycode)
    cache = pycode.co_revdb_bkpt_cache
    if cache is not None and opindex in cache:
        return cache[opindex]
    else:
        return -1

def update_bkpt_cache(pycode):
    # initialized by command_breakpoints():
    #     dbstate.breakpoint_filelines == [('FILENAME', lineno, bkpt_num)]
    # computed lazily (here, first half of the logic):
    #     dbstate.breakpoint_by_file == {'co_filename': {lineno: bkpt_num}}
    # the goal is to set:
    #     pycode.co_revdb_bkpt_cache == {opindex: bkpt_num}

    co_filename = pycode.co_filename
    try:
        linenos = dbstate.breakpoint_by_file[co_filename]
    except KeyError:
        linenos = None
        match = co_filename.upper()    # ignore cAsE in filename matching
        for filename, lineno, bkpt_num in dbstate.breakpoint_filelines:
            if match.endswith(filename) and (
                    len(match) == len(filename) or
                    match[-len(filename)-1] in '/\\'):    # a valid prefix
                if linenos is None:
                    linenos = {}
                linenos[lineno] = bkpt_num
        dbstate.breakpoint_by_file[co_filename] = linenos

    newcache = None
    if linenos is not None:
        # parse co_lnotab to figure out the opindexes that correspond
        # to the marked line numbers.  here, linenos == {lineno: bkpt_num}
        for addr, lineno in find_line_starts(pycode):
            if lineno in linenos:
                if newcache is None:
                    newcache = {}
                newcache[addr] = linenos[lineno]

    pycode.co_revdb_bkpt_cache = newcache
    pycode.co_revdb_bkpt_version = dbstate.breakpoint_version


def valid_identifier(s):
    if not s:
        return False
    if s[0].isdigit():
        return False
    for c in s:
        if not (c.isalnum() or c == '_'):
            return False
    return True

def add_breakpoint_funcname(name, i):
    if dbstate.breakpoint_funcnames is None:
        dbstate.breakpoint_funcnames = {}
    dbstate.breakpoint_funcnames[name] = i

def add_breakpoint_fileline(filename, lineno, i):
    # dbstate.breakpoint_filelines is just a list of (FILENAME, lineno, i).
    # dbstate.breakpoint_by_file is {co_filename: {lineno: i}}, but
    # computed lazily when we encounter a code object with the given
    # co_filename.  Any suffix 'filename' matches 'co_filename'.
    if dbstate.breakpoint_filelines is None:
        dbstate.breakpoint_filelines = []
        dbstate.breakpoint_by_file = {}
    dbstate.breakpoint_filelines.append((filename.upper(), lineno, i))

def add_breakpoint(name, i):
    # if it is empty, complain
    if not name:
        revdb.send_print("Empty breakpoint name")
        revdb.send_change_breakpoint(i)
        return
    # if it is surrounded by < >, it is the name of a code object
    if name.startswith('<') and name.endswith('>'):
        add_breakpoint_funcname(name, i)
        return
    # if it has no ':', it can be a valid identifier (which we
    # register as a function name), or a lineno
    original_name = name
    j = name.rfind(':')
    if j < 0:
        try:
            lineno = int(name)
        except ValueError:
            if name.endswith('()'):
                n = len(name) - 2
                assert n >= 0
                name = name[:n]
            if not valid_identifier(name):
                revdb.send_print(
                    'Note: "%s()" doesn''t look like a function name. '
                    'Setting breakpoint anyway' % name)
            add_breakpoint_funcname(name, i)
            name += '()'
            if name != original_name:
                revdb.send_change_breakpoint(i, name)
            return
        # "number" does the same as ":number"
        filename = ''
    else:
        # if it has a ':', it must end in ':lineno'
        try:
            lineno = int(name[j+1:])
        except ValueError:
            revdb.send_print('expected a line number after colon')
            revdb.send_change_breakpoint(i)
            return
        filename = name[:j]

    # the text before must be a pathname, possibly a relative one,
    # or be escaped by < >.  if it isn't, make it absolute and normalized
    # and warn if it doesn't end in '.py'.
    if filename == '':
        frame = fetch_cur_frame()
        if frame is None:
            revdb.send_change_breakpoint(i)
            return
        filename = frame.getcode().co_filename
    elif filename.startswith('<') and filename.endswith('>'):
        pass    # use unmodified
    elif not filename.lower().endswith('.py'):
        # use unmodified, but warn
        revdb.send_print(
            'Note: "%s" doesn''t look like a Python filename. '
            'Setting breakpoint anyway' % (filename,))

    add_breakpoint_fileline(filename, lineno, i)
    name = '%s:%d' % (filename, lineno)
    if name != original_name:
        revdb.send_change_breakpoint(i, name)

def command_breakpoints(cmd, extra):
    space = dbstate.space
    dbstate.breakpoint_stack_id = cmd.c_arg1
    revdb.set_thread_breakpoint(cmd.c_arg2)
    dbstate.breakpoint_funcnames = None
    dbstate.breakpoint_filelines = None
    dbstate.breakpoint_by_file = None
    dbstate.breakpoint_version += 1
    watch_progs = []
    with non_standard_code:
        for i, kind, name in revdb.split_breakpoints_arg(extra):
            if kind == 'B':
                add_breakpoint(name, i)
            elif kind == 'W':
                code = interp_marshal.loads(space, space.newbytes(name))
                watch_progs.append((code, i, ''))
    dbstate.watch_progs = watch_progs[:]
lambda_breakpoints = lambda: command_breakpoints


def command_watchvalues(cmd, extra):
    expected = extra.split('\x00')
    for j in range(len(dbstate.watch_progs)):
        prog, i, _ = dbstate.watch_progs[j]
        if i >= len(expected):
            raise IndexError
        dbstate.watch_progs[j] = prog, i, expected[i]
lambda_watchvalues = lambda: command_watchvalues


def command_stackid(cmd, extra):
    frame = fetch_cur_frame(silent=True)
    if frame is not None and cmd.c_arg1 != 0:     # parent_flag
        frame = dbstate.space.getexecutioncontext().getnextframe_nohidden(frame)
    if frame is None:
        uid = 0
    else:
        uid = revdb.get_unique_id(frame)
    if revdb.current_place() == -2:
        hidden_level = 1      # hide the "<<" events from next/bnext commands
    else:
        hidden_level = 0
    revdb.send_answer(revdb.ANSWER_STACKID, uid, hidden_level)
lambda_stackid = lambda: command_stackid


def command_allocating(uid, gcref):
    w_obj = cast_gcref_to_instance(W_Root, gcref)
    dbstate.printed_objects[uid] = w_obj
    try:
        index_metavar = dbstate.watch_futures.pop(uid)
    except KeyError:
        pass
    else:
        set_metavar(index_metavar, w_obj)
lambda_allocating = lambda: command_allocating


def command_attachid(cmd, extra):
    space = dbstate.space
    index_metavar = cmd.c_arg1
    uid = cmd.c_arg2
    try:
        w_obj = dbstate.printed_objects[uid]
    except KeyError:
        # uid not found, probably a future object
        dbstate.watch_futures[uid] = index_metavar
        w_obj = future_object(space)
    set_metavar(index_metavar, w_obj)
lambda_attachid = lambda: command_attachid


def command_compilewatch(cmd, expression):
    space = dbstate.space
    with non_standard_code:
        try:
            code = compile(expression, 'eval')
            marshalled_code = space.bytes_w(interp_marshal.dumps(
                space, code,
                space.newint(interp_marshal.Py_MARSHAL_VERSION)))
        except OperationError as e:
            revdb.send_watch(e.errorstr(space), ok_flag=0)
        else:
            revdb.send_watch(marshalled_code, ok_flag=1)
lambda_compilewatch = lambda: command_compilewatch

def command_checkwatch(cmd, marshalled_code):
    space = dbstate.space
    with non_standard_code:
        try:
            code = interp_marshal.loads(space, space.newbytes(marshalled_code))
            text = _run_watch(space, code)
        except OperationError as e:
            revdb.send_watch(e.errorstr(space), ok_flag=0)
        else:
            revdb.send_watch(text, ok_flag=1)
lambda_checkwatch = lambda: command_checkwatch


def _run_watch(space, prog):
    # must be called from non_standard_code!
    w_dict = space.builtin.w_dict
    w_res = prog.exec_code(space, w_dict, w_dict)
    return space.text_w(space.repr(w_res))


# ____________________________________________________________


ActionFlag._ticker_revdb_count = -1

class RDBSignalActionFlag(AbstractActionFlag):
    # Used instead of pypy.module.signal.interp_signal.SignalActionFlag
    # when we have reverse-debugging.  That other class would work too,
    # but inefficiently: it would generate two words of data per bytecode.
    # This class is tweaked to generate one byte per _SIG_TICKER_COUNT
    # bytecodes, at the expense of not reacting to signals instantly.

    # Threads: after 10'000 calls to decrement_ticker(), it should
    # return -1.  It should also return -1 if there was a signal.
    # This is done by calling _update_ticker_from_signals() every 100
    # calls, and invoking rsignal.pypysig_check_and_reset(); this in
    # turn returns -1 if there was a signal or if it was called 100
    # times.

    _SIG_TICKER_COUNT = 100
    _ticker = 0
    _ticker_revdb_count = _SIG_TICKER_COUNT * 10

    def get_ticker(self):
        return self._ticker

    def reset_ticker(self, value):
        self._ticker = value

    def rearm_ticker(self):
        self._ticker = -1

    def decrement_ticker(self, by):
        if we_are_translated():
            c = self._ticker_revdb_count - 1
            if c < 0:
                c = self._update_ticker_from_signals()
            self._ticker_revdb_count = c
        #if self.has_bytecode_counter:    # this 'if' is constant-folded
        #    print ("RDBSignalActionFlag: has_bytecode_counter: "
        #           "not supported for now")
        #    raise NotImplementedError
        return self._ticker

    def _update_ticker_from_signals(self):
        from rpython.rlib import rsignal
        if dbstate.standard_code:
            if rsignal.pypysig_check_and_reset():
                self.rearm_ticker()
        return self._SIG_TICKER_COUNT
    _update_ticker_from_signals._dont_inline_ = True

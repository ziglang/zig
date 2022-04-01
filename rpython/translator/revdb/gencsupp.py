import py, random, sys
from rpython.rtyper.lltypesystem import lltype, llmemory, rffi, rstr
from rpython.rtyper.lltypesystem.lloperation import LL_OPERATIONS
from rpython.translator.c.support import cdecl
from rpython.rlib import exports, revdb

#
# How It Works: we arrange things so that when replaying, all variables
# have the "same" content as they had during recording.  More precisely,
# we divide all variables according to their type in two categories:
#
#  * non-GC pointers, whose values are bitwise identical.
#
#  * GC pointers: these things are "moving", in the sense that the
#    bitwise value of a GC pointer during recording is different from
#    its bitwise value during replaying.  The object at the new
#    address contains the "same" content as the original one, using
#    this definition of "same".
#
# Note that most non-GC pointers are not followed during replaying: we
# never call external libraries nor call malloc to get pieces of raw
# memory.  Writes to raw memory are ignored, and reads return a value
# recorded in the log file.  However, the following are still needed:
#
#  * function pointers pointing to RPython functions;
#
#  * "static-immutable" structs like vtables.
#
# For now. we must make sure that these are at the same address as
# they were.  This is very roughly checked.  On Linux, it means you
# must run with Address Space Layout Randomization disabled.  This
# might be fixed in the future.
#


def extra_files():
    srcdir = py.path.local(__file__).join('..', 'src-revdb')
    return [
        srcdir / 'revdb.c',
    ]

## def mangle_name_prebuilt_raw(database, node, S):
##     if (S._gckind != 'gc' and not S._hints.get('is_excdata')
##                           and not S._hints.get('static_immutable')
##                           and not S._hints.get('ignore_revdb')
##                           and not S._hints.get('gcheader')):
##         database.all_raw_structures.append(node)
##         node.name = 'RPY_RDB_A(%s)' % (node.name,)
##         return True
##     else:
##         return False

def prepare_function(funcgen):
    if getattr(getattr(funcgen.graph, 'func', None), '_revdb_c_only_', False):
        extra_enter_text = 'RPY_REVDB_C_ONLY_ENTER'
        extra_return_text = 'RPY_REVDB_C_ONLY_LEAVE'
        return extra_enter_text, extra_return_text
    stack_bottom = False
    for block in funcgen.graph.iterblocks():
        for op in block.operations:
            if op.opname == 'gc_stack_bottom':
                stack_bottom = True
    if stack_bottom:
        name = funcgen.functionname
        funcgen.db.stack_bottom_funcnames.append(name)
        extra_enter_text = '\n'.join(
            ['/* this function is a callback */',
             'RPY_REVDB_CALLBACKLOC(RPY_CALLBACKLOC_%s);' % name] +
            ['\t' + emit('/*arg*/', funcgen.lltypename(v), funcgen.expr(v))
                for v in funcgen.graph.getargs()])
        extra_return_text = '/* RPY_CALLBACK_LEAVE(); */'
        return extra_enter_text, extra_return_text
    else:
        return None, None

def emit_void(normal_code):
    return 'RPY_REVDB_EMIT_VOID(%s);' % (normal_code,)

def emit(normal_code, tp, value):
    if tp == 'void @':
        return emit_void(normal_code)
    return 'RPY_REVDB_EMIT(%s, %s, %s);' % (normal_code, cdecl(tp, '_e'), value)

def emit_residual_call(funcgen, call_code, v_result, expr_result):
    if hasattr(funcgen, 'revdb_do_next_call'):
        del funcgen.revdb_do_next_call
        return call_code   # a hack for ll_call_destructor() to mean
                           # that the calls should really be done.
                           # Also used in rpython.rlib.clibffi.
    #
    if call_code in ('RPyGilAcquire();', 'RPyGilRelease();'):
        # Could also work with a regular RPY_REVDB_CALL_VOID, but we
        # use a different byte (0xFD, 0xFE instead of 0xFC) to detect more
        # sync misses.  In a single-threaded environment this 0xFD or 0xFE
        # byte is not needed at all, but in a multi-threaded
        # environment it ensures that during replaying, just after
        # reading the 0xFD or 0xFE, we switch to a different thread if needed
        # (actually implemented with stacklets).
        if call_code == 'RPyGilAcquire();':
            return 'RPY_REVDB_CALL_GIL_ACQUIRE();'
        else:
            return 'RPY_REVDB_CALL_GIL_RELEASE();'
    #
    tp = funcgen.lltypename(v_result)
    if tp == 'void @':
        return 'RPY_REVDB_CALL_VOID(%s);' % (call_code,)
    return 'RPY_REVDB_CALL(%s, %s, %s);' % (call_code, cdecl(tp, '_e'),
                                            expr_result)

def record_malloc_uid(expr):
    return ' RPY_REVDB_REC_UID(%s);' % (expr,)

def boehm_register_finalizer(funcgen, op):
    return 'rpy_reverse_db_register_destructor(%s, %s);' % (
        funcgen.expr(op.args[0]), funcgen.expr(op.args[1]))

def cast_gcptr_to_int(funcgen, op):
    return '%s = RPY_REVDB_CAST_PTR_TO_INT(%s);' % (
        funcgen.expr(op.result), funcgen.expr(op.args[0]))

set_revdb_protected = set(opname for opname, opdesc in LL_OPERATIONS.items()
                                 if opdesc.revdb_protect)


def prepare_database(db):
    FUNCPTR = lltype.Ptr(lltype.FuncType([revdb._CMDPTR, lltype.Ptr(rstr.STR)],
                                         lltype.Void))
    ALLOCFUNCPTR = lltype.Ptr(lltype.FuncType([rffi.LONGLONG, llmemory.GCREF],
                                              lltype.Void))

    bk = db.translator.annotator.bookkeeper
    cmds = getattr(db.translator, 'revdb_commands', {})
    numcmds = [(num, func) for (num, func) in cmds.items()
                           if isinstance(num, int)]

    S = lltype.Struct('RPY_REVDB_COMMANDS',
                  ('names', lltype.FixedSizeArray(rffi.INT, len(numcmds) + 1)),
                  ('funcs', lltype.FixedSizeArray(FUNCPTR, len(numcmds))),
                  ('alloc', ALLOCFUNCPTR))
    s = lltype.malloc(S, flavor='raw', immortal=True, zero=True)

    i = 0
    for name, func in cmds.items():
        fnptr = lltype.getfunctionptr(bk.getdesc(func).getuniquegraph())
        if isinstance(name, int):
            assert name != 0
            s.names[i] = rffi.cast(rffi.INT, name)
            s.funcs[i] = fnptr
            i += 1
        elif name == "ALLOCATING":
            s.alloc = fnptr
        else:
            raise AssertionError("bad tag in register_debug_command(): %r"
                                 % (name,))

    exports.EXPORTS_obj2name[s._as_obj()] = 'rpy_revdb_commands'
    db.get(s)

    db.stack_bottom_funcnames = []
    ## db.all_raw_structures = []

def write_revdb_def_file(db, target_path):
    f = target_path.open('w')
    funcnames = sorted(db.stack_bottom_funcnames)
    ## print >> f, "#define RDB_VERSION  0x%x" % random.randrange(0, sys.maxint)
    ## print >> f
    for i, fn in enumerate(funcnames):
        print >> f, '#define RPY_CALLBACKLOC_%s %d' % (fn, i)
    print >> f
    print >> f, '#define RPY_CALLBACKLOCS \\'
    funcnames = funcnames or ['NULL']
    for i, fn in enumerate(funcnames):
        if i == len(funcnames) - 1:
            tail = ''
        else:
            tail = ', \\'
        print >> f, '\t(void *)%s%s' % (fn, tail)
    ## print >> f

    ## def _base(name):
    ##     assert name.startswith('RPY_RDB_A(')
    ##     if name.endswith('.b'):
    ##         name = name[:-2]
    ##     name = name[len('RPY_RDB_A('):-1]
    ##     return name

    ## rawstructs = sorted(db.all_raw_structures, key=lambda node: node.name)
    ## print >> f, '#define RPY_RDB_A(name)  (*rpy_rdb_struct.name)'
    ## print >> f, 'struct rpy_rdb_a_s {'
    ## for i, node in enumerate(rawstructs):
    ##     print >> f, '\t%s;' % (cdecl(node.typename, '*'+_base(node.name)),)
    ## if not rawstructs:
    ##     print >> f, '\tchar dummy;'
    ## print >> f, '};'
    ## print >> f, 'RPY_EXTERN struct rpy_rdb_a_s rpy_rdb_struct;'
    ## print >> f
    ## print >> f, '#define RPY_RDB_STRUCT_CONTENT \\'
    ## if not rawstructs:
    ##     print >> f, '\t0'
    ## else:
    ##     for i, node in enumerate(rawstructs):
    ##         if i == len(rawstructs) - 1:
    ##             tail = ''
    ##         else:
    ##             tail = ', \\'
    ##         name = '&' + _base(node.name)
    ##         if node.typename != node.implementationtypename:
    ##             name = '(%s)%s' % (cdecl(node.typename, '*'), name)
    ##         print >> f, '\t%s%s' % (name, tail)
    f.close()


""" error handling features, just a way of displaying errors
"""

import sys

import py

from rpython.flowspace.model import Variable
from rpython.rlib import jit


SHOW_TRACEBACK = False
SHOW_ANNOTATIONS = True
SHOW_DEFAULT_LINES_OF_CODE = 0


def source_lines1(graph, block, operindex=None, offset=None, long=False,
    show_lines_of_code=SHOW_DEFAULT_LINES_OF_CODE):
    if block is not None:
        if block is graph.returnblock:
            return ['<return block>']
    try:
        source = graph.source
    except AttributeError:
        return ['no source!']
    else:
        graph_lines = source.split("\n")
        if offset is not None:
            linestart = offset2lineno(graph.func.__code__, offset)
            linerange = (linestart, linestart)
            here = None
        else:
            if block is None or not block.operations:
                return []

            def toline(operindex):
                return offset2lineno(graph.func.__code__, block.operations[operindex].offset)
            if operindex is None:
                linerange = (toline(0), toline(-1))
                if not long:
                    return ['?']
                here = None
            else:
                operline = toline(operindex)
                if long:
                    linerange = (toline(0), toline(-1))
                    here = operline
                else:
                    linerange = (operline, operline)
                    here = None
        lines = ["Happened at file %s line %d" % (graph.filename, here or linerange[0]), ""]
        for n in range(max(0, linerange[0]-show_lines_of_code),
            min(linerange[1]+1+show_lines_of_code, len(graph_lines)+graph.startline)):
            if n == here:
                prefix = '==> '
            else:
                prefix = '    '
            lines.append(prefix + graph_lines[n-graph.startline])
        lines.append("")
        return lines

def source_lines(graph, *args, **kwds):
    lines = source_lines1(graph, *args, **kwds)
    return ['In %r:' % (graph,)] + lines

def gather_error(annotator, graph, block, operindex):
    msg = [""]

    if operindex is not None:
        oper = block.operations[operindex]
        if oper.opname == 'simple_call':
            format_simple_call(annotator, oper, msg)
    else:
        oper = None
    msg.append("    %s\n" % str(oper))
    msg += source_lines(graph, block, operindex, long=True)
    if oper is not None:
        if SHOW_ANNOTATIONS:
            msg += format_annotations(annotator, oper)
            msg += ['']
    return "\n".join(msg)

def format_annotations(annotator, oper):
    msg = []
    msg.append("Known variable annotations:")
    for arg in oper.args + [oper.result]:
        if isinstance(arg, Variable):
            try:
                msg.append(" " + str(arg) + " = " + str(annotator.binding(arg)))
            except KeyError:
                pass
    return msg

def format_blocked_annotation_error(annotator, blocked_blocks):
    text = []
    for block, (graph, index) in blocked_blocks.items():
        text.append("Blocked block -- operation cannot succeed")
        text.append(gather_error(annotator, graph, block, index))
    return '\n'.join(text)

def format_simple_call(annotator, oper, msg):
    msg.append("Occurred processing the following simple_call:")
    try:
        descs = annotator.binding(oper.args[0]).descriptions
    except (KeyError, AttributeError) as e:
        msg.append("      (%s getting at the binding!)" % (
            e.__class__.__name__,))
        return
    for desc in list(descs):
        func = desc.pyobj
        if func is None:
            r = repr(desc)
        else:
            try:
                if isinstance(func, type):
                    func_name = "%s.__init__" % func.__name__
                    func = func.__init__.im_func
                else:
                    func_name = func.__name__
                r = "function %s <%s, line %s>" % (func_name,
                       func.__code__.co_filename, func.__code__.co_firstlineno)
            except (AttributeError, TypeError):
                r = repr(desc)
        msg.append("  %s returning" % (r,))
        msg.append("")

def debug(drv, use_pdb=True):
    # XXX unify some code with rpython.translator.goal.translate
    from rpython.translator.tool.pdbplus import PdbPlusShow
    from rpython.translator.driver import log
    t = drv.translator

    class options:
        huge = 100

    tb = None
    import traceback
    errmsg = ["Error:\n"]
    exc, val, tb = sys.exc_info()

    errmsg.extend([" %s" % line for line in traceback.format_exception(exc, val, [])])
    block = getattr(val, '__annotator_block', None)
    if block:
        class FileLike:
            def write(self, s):
                errmsg.append(" %s" % s)
        errmsg.append("Processing block:\n")
        t.about(block, FileLike())
    log.ERROR(''.join(errmsg))

    log.event("start debugger...")

    if use_pdb:
        pdb_plus_show = PdbPlusShow(t)
        pdb_plus_show.start(tb)


@jit.elidable
def offset2lineno(c, stopat):
    # even position in lnotab denote byte increments, odd line increments.
    # see dis.findlinestarts in the python std. library for more details
    tab = c.co_lnotab
    line = c.co_firstlineno
    addr = 0
    for i in range(0, len(tab), 2):
        addr = addr + ord(tab[i])
        if addr > stopat:
            break
        line = line + ord(tab[i+1])
    return line

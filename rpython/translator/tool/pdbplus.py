import pdb, bdb
import types
import code
import sys
from rpython.flowspace.model import FunctionGraph

class NoTTY(Exception):
    pass

class PdbPlusShow(pdb.Pdb):

    def __init__(self, translator):
        pdb.Pdb.__init__(self)
        if self.prompt == "(Pdb) ":
            self.prompt = "(Pdb+) "
        else:
            self.prompt = self.prompt.replace("(", "(Pdb+ on ", 1)
        self.translator = translator
        self.exposed = {}

    def post_mortem(self, t):
        self.reset()
        while t.tb_next is not None:
            t = t.tb_next
        self.interaction(t.tb_frame, t)

    def preloop(self):
        if not hasattr(sys.stdout, 'isatty') or not sys.stdout.isatty():
            raise NoTTY("Cannot start the debugger when stdout is captured.")
        pdb.Pdb.preloop(self)

    def expose(self, d):
        self.exposed.update(d)

    def _show(self, page):
        page.display_background()

    def _importobj(self, fullname):
        obj = None
        name = ''
        for comp in fullname.split('.'):
            name += comp
            obj = getattr(obj, comp, None)
            if obj is None:
                try:
                    obj = __import__(name, {}, {}, ['*'])
                except ImportError:
                    raise NameError
            name += '.'
        return obj

    TRYPREFIXES = ['','pypy.','pypy.objspace.','pypy.interpreter.', 'pypy.objspace.std.' ]

    def _mygetval(self, arg, errmsg):
        try:
            return eval(arg, self.curframe.f_globals,
                    self.curframe.f_locals)
        except:
            t, v = sys.exc_info()[:2]
            if isinstance(t, str):
                exc_type_name = t
            else: exc_type_name = t.__name__
            if not isinstance(arg, str):
                print '*** %s' % errmsg, "\t[%s: %s]" % (exc_type_name, v)
            else:
                print '*** %s:' % errmsg, arg, "\t[%s: %s]" % (exc_type_name, v)
            raise

    def _getobj(self, name):
        if '.' in name:
            for pfx in self.TRYPREFIXES:
                try:
                    return self._importobj(pfx+name)
                except NameError:
                    pass
        try:
            return self._mygetval(name, "Not found")
        except (KeyboardInterrupt, SystemExit, MemoryError):
            raise
        except:
            pass
        return None

    def do_find(self, arg):
        """find obj [as var]
find dotted named obj, possibly using prefixing with some packages
in pypy (see help pypyprefixes); the result is assigned to var or _."""
        objarg, var = self._parse_modif(arg)
        obj = self._getobj(objarg)
        if obj is None:
            return
        print obj
        self._setvar(var, obj)

    def _parse_modif(self, arg, modif='as'):
        var = '_'
        aspos = arg.rfind(modif+' ')
        if aspos != -1:
            objarg = arg[:aspos].strip()
            var = arg[aspos+(1+len(modif)):].strip()
        else:
            objarg = arg
        return objarg, var

    def _setvar(self, var, obj):
        self.curframe.f_locals[var] = obj

    class GiveUp(Exception):
        pass

    def _getcdef(self, cls):
        try:
            return self.translator.annotator.bookkeeper.getuniqueclassdef(cls)
        except Exception:
            print "*** cannot get classdef: %s" % cls
            return None

    def _make_flt(self, expr):
        try:
            expr = compile(expr, '<filter>', 'eval')
        except SyntaxError:
            print "*** syntax: %s" % expr
            return None
        def flt(c):
            marker = object()
            try:
                old = self.curframe.f_locals.get('cand', marker)
                self.curframe.f_locals['cand'] = c
                try:
                    return self._mygetval(expr, "oops")
                except (KeyboardInterrupt, SystemExit, MemoryError):
                    raise
                except:
                    raise self.GiveUp
            finally:
                if old is not marker:
                    self.curframe.f_locals['cand'] = old
                else:
                    del self.curframe.f_locals['cand']
        return flt

    def do_finddescs(self, arg):
        """finddescs kind expr [as var]
find annotation descs of kind (ClassDesc|FuncionDesc|...)
 for which expr is true, cand in it referes to
the candidate desc; the result list is assigned to var or _."""
        expr, var = self._parse_modif(arg)
        kind, expr = expr.split(None, 1)
        flt = self._make_flt(expr)
        if flt is None:
            return
        from rpython.annotator import description
        kind_cls = getattr(description, kind, None)
        if kind_cls is None:
            kind = kind.title()+'Desc'
            kind_cls = getattr(description, kind, None)
        if kind_cls is None:
            return

        descs = []
        try:
            for c in self.translator.annotator.bookkeeper.descs.itervalues():
                if isinstance(c, kind_cls) and flt(c):
                    descs.append(c)
        except self.GiveUp:
            return
        self._setvar(var, descs)

    def do_showg(self, arg):
        """showg obj
show graph for obj, obj can be an expression or a dotted name
(in which case prefixing with some packages in pypy is tried (see help pypyprefixes)).
if obj is a function or method, the localized call graph is shown;
if obj is a class or ClassDef the class definition graph is shown"""
        from rpython.annotator.classdesc import ClassDef
        from rpython.translator.tool import graphpage
        translator = self.translator
        obj = self._getobj(arg)
        if obj is None:
            return
        if hasattr(obj, 'im_func'):
            obj = obj.im_func
        if isinstance(obj, types.FunctionType):
            page = graphpage.LocalizedCallGraphPage(translator, self._allgraphs(obj))
        elif isinstance(obj, FunctionGraph):
            page = graphpage.FlowGraphPage(translator, [obj])
        elif isinstance(obj, (type, types.ClassType)):
            classdef = self._getcdef(obj)
            if classdef is None:
                return
            page = graphpage.ClassDefPage(translator, classdef)
        elif isinstance(obj, ClassDef):
            page = graphpage.ClassDefPage(translator, obj)
        else:
            print "*** Nothing to do"
            return
        self._show(page)

    def do_findv(self, varname):
        """ findv [varname]
find a stack frame that has a certain variable (the default is "graph")
"""
        if not varname:
            varname = "graph"
        printfr = self.print_stack_entry
        self.print_stack_entry = lambda *args: None
        try:
            num = 0
            while self.curindex:
                frame = self.curframe
                if varname in frame.f_locals:
                    printfr(self.stack[self.curindex])
                    print "%s = %s" % (varname, frame.f_locals[varname])
                    return
                num += 1
                self.do_up(None)
            print "no %s found" % (varname, )
            for i in range(num):
                self.do_down(None)
        finally:
            del self.print_stack_entry

    def _attrs(self, arg, pr):
        arg, expr = self._parse_modif(arg, 'match')
        if expr == '_':
            expr = 'True'
        obj = self._getobj(arg)
        if obj is None:
            return
        try:
            obj = list(obj)
        except:
            obj = [obj]
        clsdefs = []
        for x in obj:
            if isinstance(x, (type, types.ClassType)):
                cdef = self._getcdef(x)
                if cdef is None:
                    continue
                clsdefs.append(cdef)
            else:
                clsdefs.append(x)

        def longname(c):
            return c.name
        clsdefs.sort(lambda x,y: cmp(longname(x), longname(y)))
        flt = self._make_flt(expr)
        if flt is None:
            return
        for cdef in clsdefs:
            try:
                attrs = [a for a in cdef.attrs.itervalues() if flt(a)]
            except self.GiveUp:
                return
            if attrs:
                print "%s:" % cdef.name
                pr(attrs)

    def do_attrs(self, arg):
        """attrs obj [match expr]
list annotated attrs of class|def obj or list of classe(def)s obj,
obj can be an expression or a dotted name
(in which case prefixing with some packages in pypy is tried (see help pypyprefixes));
expr is an optional filtering expression; cand in it refer to the candidate Attribute
information object, which has a .name and .s_value."""
        def pr(attrs):
            print " " + ' '.join([a.name for a in attrs])
        self._attrs(arg, pr)

    def do_attrsann(self, arg):
        """attrsann obj [match expr]
list with their annotation annotated attrs of class|def obj or list of classe(def)s obj,
obj can be an expression or a dotted name
(in which case prefixing with some packages in pypy is tried (see help pypyprefixes));
expr is an optional filtering expression; cand in it refer to the candidate Attribute
information object, which has a .name and .s_value."""
        def pr(attrs):
            for a in attrs:
                print ' %s %s' % (a.name, a.s_value)
        self._attrs(arg, pr)

    def do_readpos(self, arg):
        """readpos obj attrname [match expr] [as var]
list the read positions of annotated attr with attrname of class or classdef obj,
obj can be an expression or a dotted name
(in which case prefixing with some packages in pypy is tried (see help pypyprefixes));
expr is an optional filtering expression; cand in it refer to the candidate read
position information, which has a .func (which can be None), a .graph  and .block and .i;
the list of the read positions functions is set to var or _."""
        class Pos:
            def __init__(self, graph, func, block, i):
                self.graph = graph
                self.func = func
                self.block = block
                self.i = i
        arg, var = self._parse_modif(arg, 'as')
        arg, expr = self._parse_modif(arg, 'match')
        if expr == '_':
            expr = 'True'
        args = arg.split()
        if len(args) != 2:
            print "*** expected obj attrname:", arg
            return
        arg, attrname = args
        # allow quotes around attrname
        if (attrname.startswith("'") and attrname.endswith("'")
            or attrname.startswith('"') and attrname.endswith('"')):
            attrname = attrname[1:-1]

        obj = self._getobj(arg)
        if obj is None:
            return
        if isinstance(obj, (type, types.ClassType)):
            obj = self._getcdef(obj)
            if obj is None:
                return
        bk = self.translator.annotator.bookkeeper
        attrs = obj.attrs
        if attrname not in attrs:
            print "*** bogus:", attrname
            return
        pos = bk.getattr_locations(obj.classdesc, attrname)
        if not pos:
            return
        flt = self._make_flt(expr)
        if flt is None:
            return
        r = {}
        try:
            for p in pos:
                graph, block, i = p
                if hasattr(graph, 'func'):
                    func = graph.func
                else:
                    func = None
                if flt(Pos(graph, func, block, i)):
                    if func is not None:
                        print func.__module__ or '?', func.__name__, block, i
                    else:
                        print graph, block, i
                    if i >= 0:
                        op = block.operations[i]
                        print " ", op
                        print " ",
                        for arg in op.args:
                            print "%s: %s" % (arg, self.translator.annotator.binding(arg)),
                        print

                    r[func] = True
        except self.GiveUp:
            return
        self._setvar(var, r.keys())


    def do_flowg(self, arg):
        """flowg obj
show flow graph for function obj, obj can be an expression or a dotted name
(in which case prefixing with some packages in pypy is tried (see help pypyprefixes))"""
        from rpython.translator.tool import graphpage
        obj = self._getobj(arg)
        if obj is None:
            return
        if hasattr(obj, 'im_func'):
            obj = obj.im_func
        if isinstance(obj, types.FunctionType):
            graphs = self._allgraphs(obj)
        elif isinstance(obj, FunctionGraph):
            graphs = [obj]
        else:
            print "*** Not a function"
            return
        self._show(graphpage.FlowGraphPage(self.translator, graphs))

    def _allgraphs(self, func):
        graphs = {}
        funcdesc = self.translator.annotator.bookkeeper.getdesc(func)
        for graph in funcdesc._cache.itervalues():
            graphs[graph] = True
        for graph in self.translator.graphs:
            if getattr(graph, 'func', None) is func:
                graphs[graph] = True
        return graphs.keys()


    def do_callg(self, arg):
        """callg obj
show localized call-graph for function obj, obj can be an expression or a dotted name
(in which case prefixing with some packages in pypy is tried (see help pypyprefixes))"""
        from rpython.translator.tool import graphpage
        obj = self._getobj(arg)
        if obj is None:
            return
        if hasattr(obj, 'im_func'):
            obj = obj.im_func
        if isinstance(obj, types.FunctionType):
            graphs = self._allgraphs(obj)
        elif isinstance(obj, FunctionGraph):
            graphs = [obj]
        else:
            print "*** Not a function"
            return
        self._show(graphpage.LocalizedCallGraphPage(self.translator, graphs))

    def do_classhier(self, arg):
        """classhier
show class hierarchy graph"""
        from rpython.translator.tool import graphpage
        self._show(graphpage.ClassHierarchyPage(self.translator))

    def do_callgraph(self, arg):
        """callgraph
show the program's call graph"""
        from rpython.translator.tool import graphpage
        self._show(graphpage.TranslatorPage(self.translator, 100))

    def do_interact(self, arg):
        """invoke a code.py sub prompt"""
        ns = self.curframe.f_globals.copy()
        ns.update(self.curframe.f_locals)
        code.interact("*interactive*", local=ns)

    def help_graphs(self):
        print "graph commands are: callgraph, showg, flowg, callg, classhier"

    def help_ann_other(self):
        print "other annotation related commands are: find, finddescs, attrs, attrsann, readpos"

    def help_pypyprefixes(self):
        print "these prefixes are tried for dotted names in graph commands:"
        print self.TRYPREFIXES

    # start helpers
    def start(self, tb):
        if tb is None:
            fn, args = self.set_trace, ()
        else:
            fn, args = self.post_mortem, (tb,)
        try:
            t = self.translator # define enviroments, xxx more stuff
            exec("")
            locals().update(self.exposed)
            fn(*args)
            pass # for debugger to land
        except bdb.BdbQuit:
            pass


def pdbcatch(f):
    "A decorator that throws you in a pdbplus if the given function raises."
    from rpython.tool.sourcetools import func_with_new_name
    def wrapper(*args, **kwds):
        try:
            return f(*args, **kwds)
        except:
            import sys
            PdbPlusShow(None).post_mortem(sys.exc_info()[2])
            raise
    wrapper = func_with_new_name(wrapper, f.__name__)
    return wrapper

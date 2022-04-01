import py
from rpython.rlib.objectmodel import not_rpython

class Node(object):
    def view(self):
        from dotviewer import graphclient
        content = ["digraph G{"]
        content.extend(self.dot())
        content.append("}")
        try:
            p = py.test.ensuretemp("automaton").join("temp.dot")
            remove = False
        except AttributeError: # pytest lacks ensuretemp, make a normal one
            p = py.path.local.mkdtemp().join('automaton.dot')
            remove = True
        p.write("\n".join(content))
        graphclient.display_dot_file(str(p))
        if remove:
            p.dirpath().remove()

class Symbol(Node):

    def __init__(self, symbol, additional_info, token):
        self.symbol = symbol
        self.additional_info = additional_info
        self.token = token

    def getsourcepos(self):
        return self.token.source_pos
    
    def __repr__(self):
        return "Symbol(%r, %r)" % (self.symbol, self.additional_info)

    def dot(self):
        symbol = (self.symbol.replace("\\", "\\\\").replace('"', '\\"')
                                                   .replace('\n', '\\l'))
        addinfo = str(self.additional_info).replace('"', "'") or "_"
        yield ('"%s" [shape=box,label="%s\\n%s"];' % (
            id(self), symbol,
            repr(addinfo).replace('"', '').replace("\\", "\\\\")))

    @not_rpython
    def visit(self, visitor):
        if isinstance(visitor, RPythonVisitor):
            return visitor.dispatch(self)
        method = getattr(visitor, "visit_" + self.symbol, None)
        if method is None:
            return self
        return method(self)

class Nonterminal(Node):
    def __init__(self, symbol, children):
        self.children = children
        self.symbol = symbol

    def getsourcepos(self):
        try:
            return self.children[0].getsourcepos()
        except IndexError:
            raise

    def __str__(self):
        return "%s(%s)" % (self.symbol, ", ".join([str(c) for c in self.children]))

    def __repr__(self):
        return "Nonterminal(%r, %r)" % (self.symbol, self.children)

    def dot(self):
        yield '"%s" [label="%s"];' % (id(self), self.symbol)
        for child in self.children:
            yield '"%s" -> "%s";' % (id(self), id(child))
            if isinstance(child, Node):
                for line in child.dot():
                    yield line
            else:
                yield '"%s" [label="%s"];' % (
                    id(child),
                    repr(child).replace('"', '').replace("\\", "\\\\"))

    @not_rpython
    def visit(self, visitor):
        if isinstance(visitor, RPythonVisitor):
            return visitor.dispatch(self)
        general = getattr(visitor, "visit", None)
        if general is None:
            return getattr(visitor, "visit_" + self.symbol)(self)
        else:
            specific = getattr(visitor, "visit_" + self.symbol, None)
            if specific is None:
                return general(self)
            else:
                return specific(self)

class VisitError(Exception):
    def __init__(self, node):
        self.node = node
        self.args = (node, )

    def __str__(self):
        return "could not visit %s" % (self.node, )

def make_dispatch_function(__general_nonterminal_visit=None,
                           __general_symbol_visit=None,
                           __general_visit=None,
                           **dispatch_table):
    def dispatch(self, node):
        if isinstance(node, Nonterminal):
            func = dispatch_table.get(node.symbol, None)
            if func is None:
                if __general_nonterminal_visit:
                    return __general_nonterminal_visit(self, node)
            else:
                return func(self, node)
        elif isinstance(node, Symbol):
            func = dispatch_table.get(node.symbol, None)
            if func is None:
                if __general_symbol_visit:
                    return __general_symbol_visit(self, node)
            else:
                return func(self, node)
        if __general_visit:
            return __general_visit(self, node)
        raise VisitError(node)
    return dispatch

class CreateDispatchDictionaryMetaclass(type):
    def __new__(cls, name_, bases, dct):
        dispatch_table = {}
        for name, value in dct.iteritems():
            if name.startswith("visit_"):
                dispatch_table[name[len("visit_"):]] = value
        for special in ["general_symbol_visit",
                        "general_nonterminal_visit",
                        "general_visit"]:
            if special in dct:
                dispatch_table["__" + special] = dct[special]
        dct["dispatch"] = make_dispatch_function(**dispatch_table)
        return type.__new__(cls, name_, bases, dct)

class RPythonVisitor(object):
    __metaclass__ = CreateDispatchDictionaryMetaclass

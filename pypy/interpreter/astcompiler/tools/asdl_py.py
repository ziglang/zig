"""
Generate AST node definitions from an ASDL description.
"""

import sys
import os
import asdl


class ASDLVisitor(asdl.VisitorBase):

    def __init__(self, stream, data):
        super(ASDLVisitor, self).__init__()
        self.stream = stream
        self.data = data

    def visitModule(self, mod, *args):
        for df in mod.dfns:
            self.visit(df, *args)

    def visitSum(self, sum, *args):
        for tp in sum.types:
            self.visit(tp, *args)

    def visitType(self, tp, *args):
        self.visit(tp.value, *args)

    def visitProduct(self, prod, *args):
        for field in prod.fields:
            self.visit(field, *args)

    def visitConstructor(self, cons, *args):
        for field in cons.fields:
            self.visit(field, *args)

    def visitField(self, field, *args):
        pass

    def emit(self, line, level=0):
        indent = "    "*level
        self.stream.write(indent + line + "\n")


def is_simple_sum(sum):
    assert isinstance(sum, asdl.Sum)
    for constructor in sum.types:
        if constructor.fields:
            return False
    return True

def asdl_of(name, obj):
    if isinstance(obj, asdl.Product) or isinstance(obj, asdl.Constructor):
        fields = ", ".join(map(str, obj.fields))
        if fields:
            fields = "({})".format(fields)
        return "{}{}".format(name, fields)
    else:
        if is_simple_sum(obj):
            types = " | ".join(type.name for type in obj.types)
        else:
            sep = "\n{}| ".format(" " * (len(name) + 1))
            types = sep.join(
                asdl_of(type.name, type) for type in obj.types
            )
        return "{} = {}".format(name, types)

class ASTNodeVisitor(ASDLVisitor):

    def visitType(self, tp):
        self.visit(tp.value, tp.name)

    def visitSum(self, sum, base):
        if is_simple_sum(sum):
            assert not sum.attributes
            self.emit("class %s(AST):" % (base,))
            self.emit("@staticmethod", 1)
            self.emit("def from_object(space, w_node):", 1)
            for i, cons in enumerate(sum.types):
                self.emit("if space.isinstance_w(w_node, get(space).w_%s):"
                          % (cons.name,), 2)
                self.emit("return %i" % (i+1,), 3)
            self.emit("raise oefmt(space.w_TypeError,", 2)
            self.emit("        \"expected some sort of %s, got %%R\", w_node)" % (base,), 2)
            doc = asdl_of(base, sum)
            self.emit("State.ast_type('%s', 'AST', None, doc=%r)" % (base, doc))
            self.emit("")
            for i, cons in enumerate(sum.types):
                self.emit("class _%s(%s):" % (cons.name, base))
                self.emit("def to_object(self, space):", 1)
                self.emit("return space.call_function(get(space).w_%s)" % (cons.name,), 2)
                doc = asdl_of(cons.name, cons)
                self.emit("State.ast_type('%s', '%s', None, doc=%r)" % (cons.name, base, doc))
                self.emit("")
            for i, cons in enumerate(sum.types):
                self.emit("%s = %i" % (cons.name, i + 1))
            self.emit("")
            self.emit("%s_to_class = [" % (base,))
            for cons in sum.types:
                self.emit("_%s," % (cons.name,), 1)
            self.emit("]")
            self.emit("")
        else:
            self.emit("class %s(AST):" % (base,))
            if sum.attributes:
                self.emit("")
                args = ", ".join(attr.name for attr in sum.attributes)
                self.emit("def __init__(self, %s):" % (args,), 1)
                for attr in sum.attributes:
                    self.visit(attr)
                self.emit("")
            self.emit("@staticmethod", 1)
            self.emit("def from_object(space, w_node):", 1)
            self.emit("if space.is_w(w_node, space.w_None):", 2)
            self.emit("    return None", 2)
            for typ in sum.types:
                self.emit("if space.isinstance_w(w_node, get(space).w_%s):"
                          % (typ.name,), 2)
                self.emit("return %s.from_object(space, w_node)"
                          % (typ.name,), 3)
            self.emit("raise oefmt(space.w_TypeError,", 2)
            self.emit("        \"expected some sort of %s, got %%R\", w_node)" % (base,), 2)
            doc = asdl_of(base, sum)
            defaults = [x.name for x in sum.attributes if x.opt]
            self.emit("State.ast_type(%r, 'AST', None, %s, default_none_fields=%r, doc=%r)" %
                      (base, [attr.name for attr in sum.attributes], 
                       defaults, doc))
            self.emit("")
            for cons in sum.types:
                self.visit(cons, base, sum.attributes)
                self.emit("")

    def visitProduct(self, product, name):
        self.emit("class %s(AST):" % (name,))
        self.emit("")
        self.make_constructor(product.fields + product.attributes, product)
        self.emit("")
        self.make_mutate_over(product, name)
        self.emit("def walkabout(self, visitor):", 1)
        self.emit("visitor.visit_%s(self)" % (name,), 2)
        self.emit("")
        self.make_converters(product.fields + product.attributes, name)
        if product.attributes:
            attr_names = ', %s' % ([a.name for a in product.attributes],)
        else:
            attr_names = ''
        doc = asdl_of(name, product)
        defaults = [x.name for x in product.fields + product.attributes if x.opt]
        self.emit("State.ast_type(%r, 'AST', %s%s, default_none_fields=%r, doc=%r)" %
                  (name, [f.name for f in product.fields], attr_names,
                   defaults, doc))
        self.emit("")

    def get_value_converter(self, field, value):
        if field.type in self.data.simple_types:
            return "%s_to_class[%s - 1]().to_object(space)" % (field.type, value)
        elif field.type == "string":
            # that's a wrapped string, but it can be optional
            if field.opt:
                return "%s if %s is not None else space.w_None" % (value, value)
            return value
        elif field.type in ("object", "singleton", "constant",
                            "bytes"):
            return value
        elif field.type == "bool":
            return "space.newbool(%s)" % (value,)
        elif field.type == "int":
            return "space.newint(%s)" % (value,)
        elif field.type == "identifier":
            if field.opt:
                return "space.newtext_or_none(%s)" % (value,)
            return "space.newtext(%s)" % (value,)
        else:
            wrapper = "%s.to_object(space)" % (value,)
            allow_none = field.opt
            # Some sequences allow None values:
            # - arguments.kw_defaults (for mandatory kw-only arguments)
            # - Dict.keys (for **nested_dict elements)
            if field.name in ('kw_defaults', 'keys'):
                allow_none = True
            if allow_none:
                wrapper += " if %s is not None else space.w_None" % (value,)
            return wrapper

    def get_value_extractor(self, field, value):
        if field.type in self.data.simple_types:
            return "%s.from_object(space, %s)" % (field.type, value)
        elif field.type in ("object", "singleton", "constant"):
            return value
        elif field.type in ("string", "bytes"):
            return "check_string(space, %s, %d)" % (value, field.opt)
        elif field.type in ("identifier",):
            if field.opt:
                return "space.text_or_none_w(%s)" % (value,)
            return "space.text_w(%s)" % (value,)
        elif field.type in ("int",):
            return "obj_to_int(space, %s, %s)" % (value, field.opt)
        elif field.type in ("bool",):
            return "space.bool_w(%s)" % (value,)
        else:
            extractor = "%s.from_object(space, %s)" % (field.type, value)
            if field.opt:
                if field.type == 'expr':
                    # the expr.from_object() method should accept w_None and
                    # return None; nothing more to do here
                    pass
                elif field.type == 'arg':
                    # the method arg.from_object() doesn't accept w_None
                    extractor += (
                        ' if not space.is_w(%s, space.w_None) else None'
                        % (value,))
                else:
                    raise NotImplementedError(field.type)
            return extractor

    def get_field_converter(self, field):
        if field.seq:
            lines = []
            lines.append("if self.%s is None:" % field.name)
            lines.append("    %s_w = []" % field.name)
            lines.append("else:")
            wrapper = self.get_value_converter(field, "node")
            lines.append("    %s_w = [%s for node in self.%s] # %s" %
                         (field.name, wrapper, field.name, field.type))
            lines.append("w_%s = space.newlist(%s_w)" % (field.name, field.name))
            return lines
        else:
            wrapper = self.get_value_converter(field, "self.%s" % field.name)
            return ["w_%s = %s  # %s" % (field.name, wrapper, field.type)]

    def get_field_extractor(self, field):
        if field.seq:
            lines = []
            lines.append("%s_w = space.unpackiterable(w_%s)" %
                         (field.name, field.name))
            value = self.get_value_extractor(field, "w_item")
            lines.append("_%s = [%s for w_item in %s_w]" %
                         (field.name, value, field.name))
        else:
            value = self.get_value_extractor(field, "w_%s" % (field.name,))
            lines = ["_%s = %s" % (field.name, value)]
            if not field.opt and field.type not in ("int",):
                lines.append("if _%s is None:" % (field.name,))
                lines.append("    raise_required_value(space, w_node, '%s')"
                             % (field.name,))

        return lines

    def make_converters(self, fields, name, extras=None):
        self.emit("def to_object(self, space):", 1)
        self.emit("w_node = space.call_function(get(space).w_%s)" % name, 2)
        all_fields = fields + extras if extras else fields
        for field in all_fields:
            # bit of a mess
            wrapping_code = self.get_field_converter(field)
            for line in wrapping_code:
                self.emit(line, 2)
            self.emit("assert w_%s is not None" % field.name, 2)
            setter = "space.setattr(w_node, space.newtext(%r), w_%s)" % (
                    str(field.name), field.name)
            if field.opt and field.type == "string":
                self.emit("if self.%s:" % (field.name, ), 2)
                self.emit(setter, 3)
            else:
                self.emit(setter, 2)
        self.emit("return w_node", 2)
        self.emit("")
        self.emit("@staticmethod", 1)
        self.emit("def from_object(space, w_node):", 1)
        for field in all_fields:
            self.emit("w_%s = get_field(space, w_node, '%s', %s)" % (
                    field.name, field.name, field.opt), 2)
        for field in all_fields:
            unwrapping_code = self.get_field_extractor(field)
            for line in unwrapping_code:
                self.emit(line, 2)
        self.emit("return %s(%s)" % (
                name, ', '.join("_%s" % (field.name,) for field in all_fields)), 2)
        self.emit("")

    def make_constructor(self, fields, node, extras=None, base=None):
        if fields or extras:
            arg_fields = fields + extras if extras else fields
            args = ", ".join(str(field.name) for field in arg_fields)
            self.emit("def __init__(self, %s):" % args, 1)
            for field in fields:
                self.visit(field)
            if extras:
                base_args = ", ".join(str(field.name) for field in extras)
                self.emit("%s.__init__(self, %s)" % (base, base_args), 2)

    def make_mutate_over(self, cons, name):
        self.emit("def mutate_over(self, visitor):", 1)
        for field in cons.fields:
            if (field.type not in asdl.builtin_types and
                field.type not in self.data.simple_types):
                if field.opt or field.seq:
                    level = 3
                    self.emit("if self.%s:" % (field.name,), 2)
                else:
                    level = 2
                if field.seq:
                    sub = field.name
                    self.emit("for i in range(len(self.{})):".format(sub),
                        level)
                    self.emit("if self.{}[i] is not None:".format(sub),
                        level + 1)
                    self.emit(
                        "self.{0}[i] = self.{0}[i].mutate_over(visitor)".format(sub),
                        level + 2)
                else:
                    sub = field.name
                    self.emit(
                        "self.{0} = self.{0}.mutate_over(visitor)".format(sub),
                        level)
        self.emit("return visitor.visit_%s(self)" % (name,), 2)
        self.emit("")

    def visitConstructor(self, cons, base, extra_attributes):
        self.emit("class %s(%s):" % (cons.name, base))
        self.emit("")
        self.make_constructor(cons.fields, cons, extra_attributes, base)
        self.emit("")
        self.emit("def walkabout(self, visitor):", 1)
        self.emit("visitor.visit_%s(self)" % (cons.name,), 2)
        self.emit("")
        self.make_mutate_over(cons, cons.name)
        self.make_converters(cons.fields, cons.name, extra_attributes)
        doc = asdl_of(cons.name, cons)
        defaults = [x.name for x in cons.fields if x.opt]
        self.emit("State.ast_type(%r, '%s', %s, default_none_fields=%r, doc=%r)" %
                  (cons.name, base, [f.name for f in cons.fields],
                   defaults, doc))
        self.emit("")

    def visitField(self, field):
        self.emit("self.%s = %s" % (field.name, field.name), 2)


class ASTVisitorVisitor(ASDLVisitor):
    """A meta visitor! :)"""

    def visitModule(self, mod):
        self.emit("class ASTVisitor(object):")
        self.emit("")
        self.emit("def visit_sequence(self, seq):", 1)
        self.emit("if seq is not None:", 2)
        self.emit("for node in seq:", 3)
        self.emit("if node is not None:", 4)
        self.emit("node.walkabout(self)", 5)
        self.emit("")
        self.emit("def visit_kwonlydefaults(self, seq):", 1)
        self.emit("if seq is not None:", 2)
        self.emit("for node in seq:", 3)
        self.emit("if node:", 4)
        self.emit("node.walkabout(self)", 5)
        self.emit("")
        self.emit("def default_visitor(self, node):", 1)
        self.emit("raise NodeVisitorNotImplemented", 2)
        self.emit("")
        super(ASTVisitorVisitor, self).visitModule(mod)
        self.emit("")

    def visitType(self, tp):
        if not (isinstance(tp.value, asdl.Sum) and
                is_simple_sum(tp.value)):
            super(ASTVisitorVisitor, self).visitType(tp, tp.name)

    def visitProduct(self, prod, name):
        self.emit("def visit_%s(self, node):" % (name,), 1)
        self.emit("return self.default_visitor(node)", 2)

    def visitConstructor(self, cons, _):
        self.emit("def visit_%s(self, node):" % (cons.name,), 1)
        self.emit("return self.default_visitor(node)", 2)


class GenericASTVisitorVisitor(ASDLVisitor):

    def visitModule(self, mod):
        self.emit("class GenericASTVisitor(ASTVisitor):")
        self.emit("")
        self.emit("def visited(self, node):", 1)
        self.emit("pass  # base implementation", 2)
        self.emit("")
        super(GenericASTVisitorVisitor, self).visitModule(mod)
        self.emit("")

    def visitType(self, tp):
        if not (isinstance(tp.value, asdl.Sum) and
                is_simple_sum(tp.value)):
            super(GenericASTVisitorVisitor, self).visitType(tp, tp.name)

    def visitProduct(self, prod, name):
        self.make_visitor(name, prod.fields)

    def visitConstructor(self, cons, _):
        self.make_visitor(cons.name, cons.fields)

    def make_visitor(self, name, fields):
        self.emit("def visit_%s(self, node):" % (name,), 1)
        self.emit("self.visited(node)", 2)
        have_body = False
        for field in fields:
            if self.visitField(field):
                have_body = True
        if not have_body:
            self.emit("pass", 2)
        self.emit("")

    def visitField(self, field):
        if (field.type not in asdl.builtin_types and
            field.type not in self.data.simple_types):
            level = 2
            template = "node.%s.walkabout(self)"
            if field.seq:
                template = "self.visit_sequence(node.%s)"
            elif field.opt:
                self.emit("if node.%s:" % (field.name,), 2)
                level = 3
            self.emit(template % (field.name,), level)
            return True
        return False


class ASDLData(object):

    def __init__(self, tree):
        simple_types = set()
        prod_simple = set()
        field_masks = {}
        required_masks = {}
        optional_masks = {}
        cons_attributes = {}
        def add_masks(fields, node):
            required_mask = 0
            optional_mask = 0
            for i, field in enumerate(fields):
                flag = 1 << i
                if field not in field_masks:
                    field_masks[field] = flag
                else:
                    assert field_masks[field] == flag
                if field.opt:
                    optional_mask |= flag
                else:
                    required_mask |= flag
            required_masks[node] = required_mask
            optional_masks[node] = optional_mask
        for tp in tree.dfns:
            if isinstance(tp.value, asdl.Sum):
                sum = tp.value
                if is_simple_sum(sum):
                    simple_types.add(tp.name)
                else:
                    attrs = [field for field in sum.attributes]
                    for cons in sum.types:
                        add_masks(attrs + cons.fields, cons)
                        cons_attributes[cons] = attrs
            else:
                prod = tp.value
                prod_simple.add(tp.name)
                add_masks(prod.fields, prod)
        prod_simple.update(simple_types)
        self.cons_attributes = cons_attributes
        self.simple_types = simple_types
        self.prod_simple = prod_simple
        self.field_masks = field_masks
        self.required_masks = required_masks
        self.optional_masks = optional_masks


HEAD = r"""# Generated by tools/asdl_py.py
from rpython.tool.pairtype import extendabletype
from rpython.tool.sourcetools import func_with_new_name
from rpython.rlib.objectmodel import specialize

from pypy.interpreter import typedef
from pypy.interpreter.baseobjspace import W_Root
from pypy.interpreter.error import OperationError, oefmt
from pypy.interpreter.gateway import interp2app
from pypy.interpreter.pyparser.parser import TokenASTBase

def raise_required_value(space, w_obj, name):
    raise oefmt(space.w_ValueError,
                "field '%s' is required for %T", name, w_obj)

def check_string(space, w_obj, allow_none=False):
    if allow_none and space.is_w(w_obj, space.w_None):
        return w_obj

    if not (space.isinstance_w(w_obj, space.w_bytes) or
            space.isinstance_w(w_obj, space.w_unicode)):
        raise oefmt(space.w_TypeError,
                    "AST string must be of type str or unicode")
    return w_obj

def get_field(space, w_node, name, optional):
    w_obj = w_node.getdictvalue(space, name)
    if w_obj is None:
        if not optional:
            raise oefmt(space.w_TypeError,
                "required field '%s' missing from %T", name, w_node)
        w_obj = space.w_None
    return w_obj

def obj_to_int(space, w_value, optional):
    if optional and space.is_w(w_value, space.w_None):
        return 0
    if not space.isinstance_w(w_value, space.w_long):
        raise oefmt(space.w_ValueError,
                    "invalid integer value: %R", w_value)
    return space.int_w(w_value)


class AST(TokenASTBase):
    __metaclass__ = extendabletype
    _attrs_ = ['lineno', 'col_offset', 'end_lineno', 'end_col_offset']

    def walkabout(self, visitor):
        raise AssertionError("walkabout() implementation not provided")

    def mutate_over(self, visitor):
        raise AssertionError("mutate_over() implementation not provided")


class NodeVisitorNotImplemented(Exception):
    pass


class _FieldsWrapper(W_Root):
    "Hack around the fact we can't store tuples on a TypeDef."

    def __init__(self, fields):
        assert fields == []

    def spacebind(self, space):
        return space.newtuple([])


class W_AST(W_Root):
    w_dict = None

    def getdict(self, space):
        if self.w_dict is None:
            self.w_dict = space.newdict(instance=True)
        return self.w_dict

    def reduce_w(self, space):
        w_dict = self.w_dict
        if w_dict is None:
            w_dict = space.newdict()
        w_type = space.type(self)
        return space.newtuple([space.type(self),
                               space.newtuple([]),
                               w_dict])

    def setstate_w(self, space, w_state):
        for w_name in space.unpackiterable(w_state):
            space.setattr(self, w_name,
                          space.getitem(w_state, w_name))

def W_AST_new(space, w_type, __args__):
    node = space.allocate_instance(W_AST, w_type)
    return node

def W_AST_init(space, w_self, __args__):
    args_w, kwargs_w = __args__.unpack()
    fields_w = space.fixedview(space.getattr(space.type(w_self),
                               space.newtext("_fields")))
    num_fields = len(fields_w) if fields_w else 0
    if args_w and len(args_w) > num_fields:
        suffix = 's' if num_fields == 1 else ''
        raise oefmt(space.w_TypeError,
            "%T constructor takes at most %d positional argument%s", w_self,
            num_fields, suffix)
    if args_w:
        for i in range(min(len(fields_w), len(args_w))):
            w_field = fields_w[i]
            w_arg = args_w[i]
            space.setattr(w_self, w_field, w_arg)
    # XXX bit wrong complexity but should be fine
    for field, w_value in kwargs_w.iteritems():
        found = len(args_w)
        for i, w_field in enumerate(fields_w):
            if space.text_w(w_field) == field:
                found = i
                break
        if found < len(args_w):
            raise oefmt(space.w_TypeError,
                "%T got multiple values for argument '%8'",
                w_self, field)
        space.setattr(w_self, space.newtext(field), w_value)


W_AST.typedef = typedef.TypeDef("_ast.AST",
    _fields=_FieldsWrapper([]),
    _attributes=_FieldsWrapper([]),
    __reduce__=interp2app(W_AST.reduce_w),
    __setstate__=interp2app(W_AST.setstate_w),
    __dict__ = typedef.GetSetProperty(typedef.descr_get_dict,
                                      typedef.descr_set_dict, cls=W_AST),
    __new__=interp2app(W_AST_new),
    __init__=interp2app(W_AST_init),
)

class State:
    AST_TYPES = []

    @classmethod
    def ast_type(cls, name, base, fields, attributes=None, default_none_fields=None, doc=None):
        cls.AST_TYPES.append((name, base, fields, attributes, default_none_fields, doc))

    def __init__(self, space):
        self.w_AST = space.gettypeobject(W_AST.typedef)
        for info in self.AST_TYPES:
            self.make_new_type(space, *info)

    def make_new_type(self, space, name, base, fields, attributes, default_none_fields, doc):
        w_base = getattr(self, 'w_%s' % base)
        w_dict = space.newdict()
        space.setitem_str(w_dict, '__module__', space.newtext('_ast'))
        if fields is not None:
            space.setitem_str(w_dict, "_fields",
                              space.newtuple([space.newtext(f) for f in fields]))
        if attributes is not None:
            space.setitem_str(w_dict, "_attributes",
                              space.newtuple([space.newtext(a) for a in attributes]))
        if default_none_fields:
            for field in default_none_fields:
                space.setitem_str(w_dict, field, space.w_None)
        w_type = space.call_function(
            space.w_type,
            space.newtext(name), space.newtuple([w_base]), w_dict)
        setattr(self, 'w_%s' % name, w_type)
        if doc is not None:
            space.setattr(w_type, space.newtext("__doc__"), space.newtext(doc))

def get(space):
    return space.fromcache(State)

"""

visitors = [ASTNodeVisitor, ASTVisitorVisitor, GenericASTVisitorVisitor]


def main(argv):
    if len(argv) == 3:
        def_file, out_file = argv[1:]
    elif len(argv) == 1:
        print "Assuming default values of Python.asdl and ast.py"
        here = os.path.dirname(__file__)
        def_file = os.path.join(here, "Python.asdl")
        out_file = os.path.join(here, "..", "ast.py")
    else:
        print >> sys.stderr, "invalid arguments"
        return 2
    mod = asdl.parse(def_file)
    data = ASDLData(mod)
    fp = open(out_file, "w")
    try:
        fp.write(HEAD)
        for visitor in visitors:
            visitor(fp, data).visit(mod)
    finally:
        fp.close()


if __name__ == "__main__":
    sys.exit(main(sys.argv))

""" Trace object space configuration options - set with __pytrace__=1
in py.py """

from pypy.tool.traceop import ResultPrinter, ResultPrinterVerbose

def get_operations_all():
    from pypy.interpreter.baseobjspace import ObjSpace
    operations = dict([(r[0], r[0]) for r in ObjSpace.MethodTable])
    for name in ObjSpace.IrregularOpTable + ["get_and_call_function"]:
        operations[name] = name

    # Remove list
    for name in ["wrap", "unwrap"]:
        if name in operations:
            del operations[name]

    return operations

config = {
    # An optional filename to use for trace output.  None is stdout
    "output_filename" : None,

    # Use a simple wrapped repr (fast) or try to do something more intelligent (slow)
    "repr_type_simple" : True,

    # Some internal interpreter code is written at applevel - by default
    # it is a good idea to hide this.
    "show_hidden_applevel" : False,

    # Many operations call back into the object space
    "recursive_operations" : False,

    # Show the bytecode or just the operations
    "show_bytecode" : True,

    # Indentor string used for output
    "indentor" : '  ',

    # Show wrapped values in bytecode
    "show_wrapped_consts_bytecode" : True,

    # Used to show realtive position in tree 
    "tree_pos_indicator" : "|-",

    "result_printer_clz" : ResultPrinter,

    "operations" : get_operations_all()
}

"""A _string module, to export formatter_parser and
   formatter_field_name_split to the string.Formatter class
   implemented in Python."""


from pypy.interpreter.mixedmodule import MixedModule

class Module(MixedModule):
    "string helper module"

    interpleveldefs = {
        'formatter_field_name_split': 'formatter.formatter_field_name_split',
        'formatter_parser': 'formatter.formatter_parser',
    }

    appleveldefs = {}


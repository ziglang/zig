import py

import sys
import docutils
from docutils import nodes
from docutils.parsers.rst import roles

def register_linkrole(role_name, callback):
    def source_role(name, rawtext, text, lineno, inliner, options={},
                    content=[]):
        text, target = callback(name, text)
        reference_node = nodes.reference(rawtext, text, name=text, refuri=target)
        return [reference_node], []
    source_role.content = True
    source_role.options = {}
    roles.register_canonical_role(role_name, source_role)

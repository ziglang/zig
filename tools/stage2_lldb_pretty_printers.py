# pretty printing for stage 2.
# put "command script /path/to/stage2_lldb_pretty_printers.py" and "type category enable stage2" in ~/.lldbinit to load it automatically.
import lldb
import stage2_pretty_printers_common as common

category = 'stage2'
module = category + '_lldb_pretty_printers'

class type_Type_SynthProvider:
    def __init__(self, type, _=None):
        self.type = type

    def update(self):
        self.tag = self.type.GetChildMemberWithName('tag_if_small_enough').Clone('tag')
        self.payload = None
        if self.tag.GetValueAsUnsigned() >= common.Type.no_payload_count:
            ptr_otherwise = self.type.GetChildMemberWithName('ptr_otherwise')
            self.tag = ptr_otherwise.Dereference().GetChildMemberWithName('tag')
            payload_type = self.type.target.FindFirstType('type.' + common.Type.payload_type_names[self.tag.GetValue()])
            self.payload = ptr_otherwise.Cast(payload_type.GetPointerType()).Dereference().GetChildMemberWithName('data').Clone('payload')

    def num_children(self):
        return 1 + (self.payload is not None)

    def get_child_index(self, name):
        return ['tag', 'payload'].index(name)

    def get_child_at_index(self, index):
        return [self.tag, self.payload][index]

class value_Value_SynthProvider:
    def __init__(self, value, _=None):
        self.value = value

    def update(self):
        self.tag = self.value.GetChildMemberWithName('tag_if_small_enough').Clone('tag')
        self.payload = None
        if self.tag.GetValueAsUnsigned() >= common.Value.no_payload_count:
            ptr_otherwise = self.value.GetChildMemberWithName('ptr_otherwise')
            self.tag = ptr_otherwise.Dereference().GetChildMemberWithName('tag')
            payload_type = self.value.target.FindFirstType('value.' + common.Value.payload_type_names[self.tag.GetValue()])
            self.payload = ptr_otherwise.Cast(payload_type.GetPointerType()).Dereference().GetChildMemberWithName('data').Clone('payload')

    def num_children(self):
        return 1 + (self.payload is not None)

    def get_child_index(self, name):
        return ['tag', 'payload'].index(name)

    def get_child_at_index(self, index):
        return [self.tag, self.payload][index]

def add(debugger, type, summary=False, synth=False):
    if summary: debugger.HandleCommand('type summary add --python-function ' + module + '.' + type.replace('.', '_') + '_SummaryProvider "' + type + '" --category ' + category)
    if synth: debugger.HandleCommand('type synthetic add --python-class ' + module + '.' + type.replace('.', '_') + '_SynthProvider "' + type + '" --category ' + category)

def __lldb_init_module(debugger, _=None):
    add(debugger, 'type.Type', synth=True)
    add(debugger, 'value.Value', synth=True)

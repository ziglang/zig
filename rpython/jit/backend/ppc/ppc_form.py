from rpython.jit.backend.ppc.form import Form
from rpython.jit.backend.ppc.ppc_field import ppc_fields

class PPCForm(Form):
    fieldmap = ppc_fields

    def __init__(self, *fnames):
        super(PPCForm, self).__init__(*("opcode",) + fnames)

    def __call__(self, opcode, **specializations):
        specializations['opcode'] = opcode
        return super(PPCForm, self).__call__(**specializations)

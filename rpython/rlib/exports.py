from rpython.rtyper.lltypesystem.lltype import typeOf, ContainerType

# XXX kill me

def export_struct(name, struct):
    assert name not in EXPORTS_names, "Duplicate export " + name
    assert isinstance(typeOf(struct), ContainerType)
    EXPORTS_names.add(name)
    EXPORTS_obj2name[struct] = name

def clear():
    global EXPORTS_names, EXPORTS_obj2name
    EXPORTS_names = set()
    EXPORTS_obj2name = {}
clear()

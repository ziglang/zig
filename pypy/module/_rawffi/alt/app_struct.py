from _rawffi import alt

class MetaStructure(type):

    def __new__(cls, name, bases, dic):
        cls._compute_shape(name, dic)
        return type.__new__(cls, name, bases, dic)

    @classmethod
    def _compute_shape(cls, name, dic):
        fields = dic.get('_fields_')
        if fields is None:
            return
        struct_descr = alt._StructDescr(name, fields)
        for field in fields:
            dic[field.name] = field
        dic['_struct_'] = struct_descr


class Structure(metaclass=MetaStructure):
    pass

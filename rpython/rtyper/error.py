
class TyperError(Exception):
    def __str__(self):
        result = Exception.__str__(self)
        if hasattr(self, 'where'):
            result += '\n.. %s\n.. %r\n.. %r' % self.where
        return result

class MissingRTypeOperation(TyperError):
    pass

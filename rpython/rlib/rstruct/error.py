
class StructError(Exception):
    def __init__(self, msg):
        self.msg = msg

    def __str__(self):
        return self.msg


class StructOverflowError(StructError):
    pass

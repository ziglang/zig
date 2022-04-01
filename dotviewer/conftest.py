import py

def pytest_addoption(parser):
    group = parser.getgroup("dotviever")
    group.addoption('--pygame', action="store_true", 
        dest="pygame", default=False, 
        help="allow interactive tests using Pygame")

def pytest_configure(config):
    global option
    option = config.option

include "llvm/Option/OptParser.td"

// link.exe accepts options starting with either a dash or a slash.

// Flag that takes no arguments.
class F<string name> : Flag<["/", "-", "-?"], name>;

// Flag that takes one argument after ":".
class P<string name, string help> :
      Joined<["/", "-", "-?"], name#":">, HelpText<help>;

// Boolean flag suffixed by ":no".
multiclass B<string name, string help> {
  def "" : F<name>;
  def _no : F<name#":no">, HelpText<help>;
}

def align   : P<"align", "Section alignment">;
def alternatename : P<"alternatename", "Define weak alias">;
def base    : P<"base", "Base address of the program">;
def defaultlib : P<"defaultlib", "Add the library to the list of input files">;
def delayload : P<"delayload", "Delay loaded DLL name">;
def entry   : P<"entry", "Name of entry point symbol">;
def errorlimit : P<"errorlimit",
    "Maximum number of errors to emit before stopping (0 = no limit)">;
def export  : P<"export", "Export a function">;
// No help text because /failifmismatch is not intended to be used by the user.
def failifmismatch : P<"failifmismatch", "">;
def heap    : P<"heap", "Size of the heap">;
def implib  : P<"implib", "Import library name">;
def libpath : P<"libpath", "Additional library search path">;
def linkrepro : P<"linkrepro", "Dump linker invocation and input files for debugging">;
def lldsavetemps : F<"lldsavetemps">,
    HelpText<"Save temporary files instead of deleting them">;
def machine : P<"machine", "Specify target platform">;
def merge   : P<"merge", "Combine sections">;
def mllvm   : P<"mllvm", "Options to pass to LLVM">;
def nodefaultlib : P<"nodefaultlib", "Remove a default library">;
def opt     : P<"opt", "Control optimizations">;
def out     : P<"out", "Path to file to write output">;
def pdb : P<"pdb", "PDB file path">;
def section : P<"section", "Specify section attributes">;
def stack   : P<"stack", "Size of the stack">;
def stub    : P<"stub", "Specify DOS stub file">;
def subsystem : P<"subsystem", "Specify subsystem">;
def version : P<"version", "Specify a version number in the PE header">;

def disallowlib : Joined<["/", "-", "-?"], "disallowlib:">, Alias<nodefaultlib>;

def manifest : F<"manifest">;
def manifest_colon : P<"manifest", "Create manifest file">;
def manifestuac : P<"manifestuac", "User access control">;
def manifestfile : P<"manifestfile", "Manifest file path">;
def manifestdependency : P<"manifestdependency",
                           "Attributes for <dependency> in manifest file">;
def manifestinput : P<"manifestinput", "Specify manifest file">;

// We cannot use multiclass P because class name "incl" is different
// from its command line option name. We do this because "include" is
// a reserved keyword in tablegen.
def incl : Joined<["/", "-"], "include:">,
    HelpText<"Force symbol to be added to symbol table as undefined one">;

// "def" is also a keyword.
def deffile : Joined<["/", "-"], "def:">,
    HelpText<"Use module-definition file">;

def debug : F<"debug">, HelpText<"Embed a symbol table in the image">;
def debugtype : P<"debugtype", "Debug Info Options">;
def dll : F<"dll">, HelpText<"Create a DLL">;
def driver : P<"driver", "Generate a Windows NT Kernel Mode Driver">;
def nodefaultlib_all : F<"nodefaultlib">;
def noentry : F<"noentry">;
def profile : F<"profile">;
def swaprun_cd : F<"swaprun:cd">;
def swaprun_net : F<"swaprun:net">;
def verbose : F<"verbose">;

def force : F<"force">,
    HelpText<"Allow undefined symbols when creating executables">;
def force_unresolved : F<"force:unresolved">;

defm allowbind: B<"allowbind", "Disable DLL binding">;
defm allowisolation : B<"allowisolation", "Set NO_ISOLATION bit">;
defm appcontainer : B<"appcontainer",
                      "Image can only be run in an app container">;
defm dynamicbase : B<"dynamicbase",
                     "Disable address space layout randomization">;
defm fixed    : B<"fixed", "Enable base relocations">;
defm highentropyva : B<"highentropyva", "Set HIGH_ENTROPY_VA bit">;
defm largeaddressaware : B<"largeaddressaware", "Disable large addresses">;
defm nxcompat : B<"nxcompat", "Disable data execution provention">;
defm safeseh : B<"safeseh", "Produce an image with Safe Exception Handler">;
defm tsaware  : B<"tsaware", "Create non-Terminal Server aware executable">;

def help : F<"help">;
def help_q : Flag<["/?", "-?"], "">, Alias<help>;

// LLD extensions
def nopdb : F<"nopdb">, HelpText<"Disable PDB generation for DWARF users">;
def nosymtab : F<"nosymtab">;
def msvclto : F<"msvclto">;

// Flags for debugging
def lldmap : F<"lldmap">;
def lldmap_file : Joined<["/", "-"], "lldmap:">;

//==============================================================================
// The flags below do nothing. They are defined only for link.exe compatibility.
//==============================================================================

class QF<string name> : Joined<["/", "-", "-?"], name#":">;

multiclass QB<string name> {
  def "" : F<name>;
  def _no : F<name#":no">;
}

def functionpadmin : F<"functionpadmin">;
def ignoreidl : F<"ignoreidl">;
def incremental : F<"incremental">;
def no_incremental : F<"incremental:no">;
def nologo : F<"nologo">;
def throwingnew : F<"throwingnew">;
def editandcontinue : F<"editandcontinue">;
def fastfail : F<"fastfail">;

def delay : QF<"delay">;
def errorreport : QF<"errorreport">;
def idlout : QF<"idlout">;
def ignore : QF<"ignore">;
def maxilksize : QF<"maxilksize">;
def pdbaltpath : QF<"pdbaltpath">;
def tlbid : QF<"tlbid">;
def tlbout : QF<"tlbout">;
def verbose_all : QF<"verbose">;
def guardsym : QF<"guardsym">;

defm wx : QB<"wx">;

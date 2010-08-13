#
# Contain a parser to extract the command line options, and a class definition for
# command line options
#

import getopt, os, sys

#----------------------------------------------

# the usage message
USAGE_MSG = '''
Description: compile shell for Orio

Usage: %s [options] <ifile> 
  <ifile>   input file containing the annotated code

Options:
  -c, --pre-command=<string>     Command string with which to prefix the execution of the 
                                 Orio-built code, e.g., tauex
  -e, --erase-annot              remove annotations from the output
  -h, --help                     display this message
  -k, --keep-temps               do not remove intermediate generated files
  -o <file>, --output=<file>     place the output in <file> (only valid when processing 
                                 single files)
  -p, --output-prefix=<string>   generate output filename from input filename by prepending 
                                 the specified string (default is '_', e.g., f.c becomes _f.c).
  -r, --rename-objects           after compiling the Orio-generated source, rename the object 
                                 files to be the same as those that would result from compiling
                                 the original source code
  -s <file>, --spec=<file>       read tuning specifications from <file>
  -v, --verbose                  verbosely show details of the results of the running program

environment variables: 
  ORIO_FLAGS                     the string value is used to augment the list of Orio command-lin
                                 options
  ORIO_DEBUG                     when set, print debugging information (orio.main.y for developer use)
                                 
For more details, please refer to the documentation at https://trac.mcs.anl.gov/projects/performance/wiki/OrioUserGuide
''' % os.path.basename(sys.argv[0])

#----------------------------------------------

class CmdParser:
    '''Parser for command line options'''
    
    def __init__(self):
        '''To instantiate the command line option parser'''
        pass

    #----------------------------------------------

    def parse(self, argv):
        '''To extract the command line options'''

        # Preprocess the command line to accomodate cases when Orio is used 
        # as a preprocessor to the compiler, e.g., orcc <orio_opts> compiler <compiler_tops> source.c
        orioargv = []
        otherargv = []
        srcfiles = {}
        index = 1
        wrapper = False
        for arg in argv[1:]:
            if not wrapper  and arg.startswith('-'): 
                orioargv.append(arg)
                continue
            argisinput = False
            if not arg.startswith('-'):
                # Look for the source(s)
                if arg.count('.') > 0:
                    suffix = arg[arg.rfind('.')+1:]
                    if suffix.lower() in ['c','cpp','cxx','h','hpp','hxx','f','f90','f95','f03']:
                        srcfiles[arg] = '_' + arg
                        argisinput = True
            if not argisinput:
                if not wrapper: wrapper = True
                if wrapper: otherargv.append(arg)
            index += 1

        # fix non-Orio command line options as much as possible (esp. -D) since the shell eats quotes and such
        externalargs=[]
        index = 0
        while index < len(otherargv):
            arg = otherargv[index]
            if arg.count('=') > 0 and arg.startswith('-D'):
                key,val=arg.split('=')
                index += 1
                if val[0] == val[-1] == '"':
                    val = "'" + val + "'"
                else:
                    val = "'\"" + val
                    if index < len(otherargv): arg = otherargv[index]
                    while index < len(otherargv) and not arg.startswith('-'): 
                        val += ' ' + arg
                        arg = otherargv[index]
                        index += 1
                    val += "\"'"
                externalargs.append(key + '=' + val)
            else:
                externalargs.append(arg)
                index += 1
        #debug('orio.main.cmd_line_opts: new args: %s' % str(externalargs))

        # check the ORIO_FLAGS env. variable for more options
        if 'ORIO_FLAGS' in os.environ.keys():
            orioargv.extend(os.environ['ORIO_FLAGS'].split())

        # get all options
        try:
            opts, args = getopt.getopt(orioargv,
                                       'c:ehko:p:rs:v',
                                       ['pre-command=', 'erase-annot', 'help', 'keep-temps',' output=', 
                                       'output-prefix=', 'rename-objects', 'spec=', 'verbose'])
        except Exception, e:
            sys.stderr.write('Orio command-line error: %s' % e)
            sys.stderr.write(USAGE_MSG + '\n')
            sys.exit(1)

        cmdline = {}
        # evaluate all options
        for opt, arg in opts:
            if opt in ('-c', '--pre-command'):
                cmdline['pre_cmd'] = arg
            elif opt in ('-e', '--erase-annot'):
                cmdline['erase_annot'] = True
            elif opt in ('-h', '--help'):
                sys.stdout.write(USAGE_MSG +'\n')
                sys.exit(0)
            elif opt in ('-k', '--keep-temps'):
                cmdline['keep_temps'] = True
            elif opt in ('-o', '--output'):
                cmdline['out_filename'] = arg
            elif opt in ('-p', '--output-prefix'):
                cmdline['out_prefix'] = arg
            elif opt in ('-r', '--rename-objects'):
                cmdline['rename_objects'] = True
            elif opt in ('-s', '--spec'):
                cmdline['spec_filename'] = arg
            elif opt in ('-v', '--verbose'):
                cmdline['verbose'] = True

        # check on the arguments
        if len(srcfiles) < 1:
            if otherargv: 
                cmdline['disable_orio'] = True
            else:
                sys.stderr.write('Orio command-line error: missing file arguments')
                sys.stderr.write(USAGE_MSG + '\n')
                sys.exit(1)

        for src_filename in srcfiles:
            # check if the source file is readable
            try:
                f = open(src_filename, 'r')
                f.close()
            except:
                sys.stderr.write('orio.main.cmd_line_opts: cannot open source file for reading: %s' % src_filename)
                sys.exit(1)

        if 'spec_filename' in cmdline.keys(): spec_filename = cmdline['spec_filename']
        else: spec_filename = None
        # check if the tuning specification file is readable
        if spec_filename:
            try:
                f = open(spec_filename, 'r')
                f.close()
            except:
                sys.stderr.write('orio.main.cmd_line_opts: cannot open file for reading: %s' % spec_filename)
                sys.exit(1)

        # create the output filenames
        if len(srcfiles) == 1 and 'out_filename' in cmdline.keys(): 
            srcfiles[srcfiles.keys()[0]] = cmdline['out_filename']
        else:
            for src_filename in srcfiles.keys():
                dirs, fname = os.path.split(src_filename)
                if ['out_prefix'] in cmdline.keys(): out_prefix=cmdline['out_prefix']
                else: out_prefix = '_'
                srcfiles[src_filename] = os.path.join(dirs, out_prefix + fname)

        cmdline['src_filenames'] = srcfiles
        return cmdline


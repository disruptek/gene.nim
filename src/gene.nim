# See https://nim-lang.org/docs/nimprof.html
# Compiles with --profiler:on and a report will automatically be generated
# nimble build -d:release --profiler:on
# import nimprof
# setSamplingFrequency(1)

import times, strutils, logging

import gene/types
import gene/vm
import gene/parser
import gene/interpreter
import gene/compiler
import gene/cpu
import cmdline/option_parser

proc setupLogger(debugging: bool) =
  var consoleLogger = newConsoleLogger()
  addHandler(consoleLogger)
  consoleLogger.levelThreshold = Level.lvlInfo
  if debugging:
    consoleLogger.levelThreshold = Level.lvlDebug

proc quit_with*(errorcode: int, newline = false) =
  if newline:
    echo ""
  echo "Good bye!"
  quit(errorcode)

# https://stackoverflow.com/questions/5762491/how-to-print-color-in-console-using-system-out-println
# https://en.wikipedia.org/wiki/ANSI_escape_code
proc error(message: string): string =
  return "\u001B[31m" & message & "\u001B[0m"

proc prompt(message: string): string =
  return "\u001B[36m" & message & "\u001B[0m"

proc main() =
  var options = parseOptions()
  setupLogger(options.debugging)

  if options.repl:
    echo "Welcome to interactive Gene!"
    echo "Note: press Ctrl-D to exit."

    if options.debugging:
      echo "The logger level is set to DEBUG."

    var vm = new_vm()
    var input = ""
    while true:
      write(stdout, prompt("Gene> "))
      try:
        input = input & readLine(stdin)
        case input:
        of "":
          continue
        else:
          discard

        var r: GeneValue
        if options.running_mode == Interpreted:
          r = vm.eval(input)
        else:
          var c = new_compiler()
          var module = c.compile(input)
          r = vm.run(module)

        # Reset input
        input = ""

        writeLine(stdout, r)
      except EOFError:
        quit_with(0, true)
      except ParseError as e:
        # Incomplete expression
        if e.msg.startsWith("EOF"):
          continue
        else:
          input = ""
      except Exception as e:
        input = ""
        var s = e.getStackTrace()
        s.stripLineEnd
        echo s
        echo error("$#: $#" % [$e.name, $e.msg])

  else:
    var vm = new_vm()
    var file = options.file
    if options.running_mode == Interpreted:
      let parsed = read_all(readFile(file))
      let start = cpuTime()
      let result = vm.eval(parsed)
      echo "Time: " & $(cpuTime() - start)
      echo result
    else:
      var c = new_compiler()
      var module = c.compile(readFile(file))
      let start = cpuTime()
      let result = vm.run(module)
      echo "Time: " & $(cpuTime() - start)
      echo result

when isMainModule:
  main()

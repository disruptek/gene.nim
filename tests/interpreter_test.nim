# To run these tests, simply execute `nimble test`.

import unittest

import gene/types
import gene/vm_types
import gene/interpreter

test "Interpreter = VM.eval()":
  var vm = new_vm()
  check vm.eval("nil") == GeneNil

  vm = new_vm()
  check vm.eval("1") == new_gene_int(1)

  vm = new_vm()
  check vm.eval("true") == GeneTrue

  vm = new_vm()
  check vm.eval("1 2 3") == new_gene_int(3)

  vm = new_vm()
  check vm.eval("(var a 1) a") == new_gene_int(1)

  vm = new_vm()
  check vm.eval("(if true 1)") == new_gene_int(1)

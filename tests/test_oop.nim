import unittest, tables

import gene/types
import gene/interpreter

import ./helpers

# OOP:
#
# * Single inheritance
# * private / protected / public methods
# * method_missing - can only be defined in classes
# * Mixin: all stuff in mixin are copied to the target class/mixin
# * Properties: just a shortcut for defining .prop/.prop= methods

test_interpreter "(class A)", proc(r: GeneValue) =
  check r.internal.class.name == "A"

test_interpreter """
  (class A)
  (new A)
""", proc(r: GeneValue) =
  check r.internal.instance.class.name == "A"

test_interpreter """
  (class A
    (method new []
      (@description = "Class A")
    )
  )
  (new A)
""", proc(r: GeneValue) =
  check r.internal.instance.value.gene.props["description"] == "Class A"

test_interpreter """
  (class A
    (method new []
      (@description = "Class A")
    )
  )
  ((new A) .@description)
""", proc(r: GeneValue) =
  check r.str == "Class A"

test_interpreter """
  (class A
    (method new description
      (@description = description)
    )
  )
  (new A "test")
""", proc(r: GeneValue) =
  check r.internal.instance.value.gene.props["description"] == "test"

test_interpreter """
  (class A
    (method test []
      "test"
    )
  )
  ((new A) .test)
""", "test"

test_interpreter """
  (class A
    (method test [a b]
      (a + b)
    )
  )
  ((new A) .test 1 2)
""", 3

test_interpreter """
  (class A
    (method test []
      "A.test"
    )
  )
  (class B < A
  )
  ((new B) .test)
""", "A.test"

test_interpreter """
  (class A
    (method test a
      a
    )
  )
  (class B < A
    (method test a
      (super ...)
    )
  )
  ((new B) .test 1)
""", 1

test_interpreter """
  (mixin M
    (method test _
      1
    )
  )
  (class A
    (include M)
  )
  ((new A) .test)
""", 1

# # Single inheritance with flexibility of changing class, overwriting methods
# test_interpreter """
#   (class A
#     (method test _
#       1
#     )
#   )
#   (class B
#     (method test _
#       2
#     )
#   )
#   (var a (new A))
#   ((a as B) .test)
# """, 2

# test_interpreter """
#   (class A
#     (method test _
#       1
#     )
#   )
#   (class B
#     (method test _
#       2
#     )
#   )
#   (var a (new A))
#   ((a as
#     (class < B
#       (method test _
#         3
#       )
#     )
#    ) .test)
# """, 3

test "Interpreter / eval: native method":
  proc test_fn(args: seq[GeneValue]): GeneValue {.nimcall.} =
    args[0].int + args[1].int
  GLOBAL_NS.internal.ns["test_fn"] = test_fn.proc_to_gene
  var code = cleanup """
    (class A
      (native_method test test_fn)
    )
    ((new A) .test 1 2)
  """
  var interpreter = new_vm()
  check interpreter.eval(code) == 3

test_core """
  (macro my_class [name rest...]
    # Get super class
    (var super_class
      (if ((rest .get 0) == :<)
        (rest .del 0)
        (caller_eval (rest .del 0))
      else
        gene/Object
      )
    )
    # Create class
    (var cls (gene/Class/new name super_class))

    # Evaluate body
    (for item in rest
      (eval ^self cls item)
    )
    cls
  )
  (var B (my_class A
    (method new []
      (@description = "Class A")
    )
  ))
  ((new B) .@description)
""", proc(r: GeneValue) =
  check r.str == "Class A"

import unittest

import gene/types

import ./helpers

# Functional programming:
#
# * Return function as result
# * Pass function around
# * Closure
# * Iterators
# * Pure function (mark function as pure, all standard lib should be marked pure if true)
# * Continuation - is it possible?

test_interpreter "(fn f a a)", proc(r: GeneValue) =
  check r.internal.fn.name == "f"

test_interpreter "(fn f _)", proc(r: GeneValue) =
  check r.internal.fn.args.len == 0

test_interpreter "(fn f [] 1) (f)", 1
test_interpreter "(fn f a (a + 1)) (f 1)", 2

test_interpreter """
  (fn f []
    (return 1)
    2
  )
  (f)
""", 1

test_interpreter """
  (fn fib n
    (if (n < 2)
      n
    else
      ((fib (n - 1)) + (fib (n - 2)))
    )
  )
  (fib 6)
""", 8

test_interpreter """
  (fn f []
    (fn g a a)
  )
  ((f) 1)
""", 1

test_interpreter """
  (fn f a
    (fn g _ a)
  )
  ((f 1))
""", 1

# test_interpreter """
#   (fn g ret
#     (ret 1)
#   )
#   (fn f []
#     # return can be assigned and will remember which function
#     # to return from
#     # Caution: "r" should only be used in nested functions/blocks inside "f"
#     (var r return)
#     (loop
#       (g r)
#     )
#   )
#   (f 1)
# """, 1
#
# test_interpreter """
#   (fn f []
#     # return can be assigned and will remember which function
#     # to return from
#     (var r return)
#     (fn g []
#       (r 1) # r is from f's scope
#     )
#     (loop
#       (g)
#     )
#   )
#   (f 1)
# """, 1

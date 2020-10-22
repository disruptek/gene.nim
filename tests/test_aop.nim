import gene/types

import ./helpers

# AOP(Aspect Oriented Programming):
#
# * before
# * after
# * around
#
# * Can alter arguments
# * Can alter result
# * Can skip run
# * Can trigger retry
# * ...
#
# * AOP for OOP
#   Can be applied to classes and methods
#
# * AOP for functions
#   Can be applied to existing functions (not macros and blocks)
#
# Aspects should be grouped, but how?
# * OOP: on class level
# * Functions: ?
#
# Design by Contract - can be implemented with AOP
# * precondition
# * postcondition
# * invariant
#

# test_interpreter """
#   (class A
#     (method test a
#       a
#     )
#     (before "test" (fnx a
#       (if a > 0
#         a
#       else
#         0
#       )
#     ))
#   )
#   ((new A) .test -1)
# """, 0

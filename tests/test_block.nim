import unittest

import gene/types

import ./helpers

#
# Support blocks like Ruby block
#
# * Good for iterators etc
# * yield:
# * return: return from the calling function, not from the iterator function
# * next:
# * break
#
# Block syntax
# (-> ...)
# (a -> ...)
# ([a b] -> ...)
#
# If last argument is a block, a special block argument is accessible
#
# (yield 1 2) will call the block with arguments and return value
# from the block
#
# Maybe there is not need for special syntax like Ruby, we can invoke
# it like regular function
#

# test_interpreter """
#   (fn f b
#     (b 1)
#     0
#   )
#   (fn g _
#     (f (a -> (return a)))
#   )
#   (g)
# """, 1

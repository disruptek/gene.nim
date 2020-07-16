# To run these tests, simply execute `nimble test`.

import gene/types
import ./common

test_compiler "1",
  new_gene_int(1)
test_compiler "(1 + 2)",
  new_gene_int(3)
test_compiler "(3 - 2)",
  new_gene_int(1)
test_compiler "(1 < 2)",
  GeneTrue
test_compiler "(if true 1)",
  new_gene_int(1)
test_compiler "(if false 1 else 2)",
  new_gene_int(2)
test_compiler "(if false 1 elif true 2 else 3)",
  new_gene_int(2)
test_compiler "(if false 1 elif false 2 else 3)",
  new_gene_int(3)

test_compiler "(var a 1) a",
  new_gene_int(1)

test_compiler "(fn f [] 1) (f)",
  new_gene_int(1)

test_compiler "(fn f a (a + 1)) (f 1)",
  new_gene_int(2)

test_compiler """
  (fn fib n
    (if (n < 2)
      n
    else
      ((fib (n - 1)) + (fib (n - 2)))
    )
  )
  (fib 6)
""", new_gene_int(8)
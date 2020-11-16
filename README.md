# Gene - a general purpose language written in Nim

## Credit

The parser and basic data types are built on top of [EDN Parser](https://github.com/rosado/edn.nim) that is
created by Roland Sadowski.

## Notes

* Build

```
nimble build
```

* Run interactive Gene interpreter (after building the executable)

```
./gene
```

* Run all tests

```
nimble test
```

* Run specific test file

```
nim c -r tests/test_parser.nim
```

* Watch changes and build bin/gene and run tests

```
while 1; do fswatch -v -r src tests/*.nim Cargo.toml | nim c --out:bin/gene src/gene.nim && nimble test; sleep 0.2; done
```

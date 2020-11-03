import strutils, tables

import ./types

const SIMPLE_BINARY_OPS* = [
  "+", "-", "*", "/",
  "=",
  "==", "!=", "<", "<=", ">", ">=",
  "&&", "||", # TODO: xor
  "&",  "|",  # TODO: xor for bit operation
]

type
  Normalizer* = proc(self: GeneValue): bool

var Normalizers: seq[Normalizer]

# Important: order of normalizers matters. normalize() should be tested as a whole

Normalizers.add proc(self: GeneValue): bool =
  var op = self.gene.op
  if op.kind == GeneSymbol:
    if op.symbol.startsWith(".@"):
      if op.symbol.endsWith("="):
        var name = op.symbol.substr(2, op.symbol.len-2)
        self.gene.op = new_gene_symbol("@=")
        self.gene.data.insert(new_gene_string_move(name), 0)
      else:
        self.gene.op = new_gene_symbol("@")
        self.gene.data = @[new_gene_string_move(op.symbol.substr(2))]
      return true

Normalizers.add proc(self: GeneValue): bool =
  var op = self.gene.op
  if op.kind == GeneSymbol and op.symbol == "if":
    var i = 1  # start index after condition
    var cond = self.gene.data[0]
    if cond == Not:
      cond = new_gene_gene(Not, self.gene.data[1])
      i += 1
    var then_blk: seq[GeneValue] = @[]
    var else_blk: seq[GeneValue] = @[]
    var state = "cond"
    while i < self.gene.data.len:
      var item = self.gene.data[i]
      case state:
      of "cond":
        if item == Then:
          discard
        elif item == Else:
          state = "else"
        else:
          then_blk.add(item)
      of "else":
        else_blk.add(item)
      i += 1
    self.gene.props["cond"] = cond
    self.gene.props["then"] = then_blk
    self.gene.props["else"] = else_blk
    self.gene.data.reset

Normalizers.add proc(self: GeneValue): bool =
  var op = self.gene.op
  if op.kind == GeneSymbol:
    if op.symbol == "import" or op.symbol == "import_native":
      var names: seq[GeneValue] = @[]
      var module: GeneValue
      var expect_module = false
      for val in self.gene.data:
        if expect_module:
          module = val
        elif val.kind == GeneSymbol and val.symbol == "from":
          expect_module = true
        else:
          names.add(val)
      self.gene.props["names"] = new_gene_vec(names)
      self.gene.props["module"] = module
      return true

Normalizers.add proc(self: GeneValue): bool =
  if self.gene.op.kind == GeneSymbol:
    if self.gene.op.symbol == "fnx":
      self.gene.op = new_gene_symbol("fn")
      self.gene.data.insert(new_gene_symbol("_"), 0)
      return true
    elif self.gene.op.symbol == "fnxx":
      self.gene.op = new_gene_symbol("fn")
      self.gene.data.insert(new_gene_symbol("_"), 0)
      self.gene.data.insert(new_gene_symbol("_"), 0)
      return true

Normalizers.add proc(self: GeneValue): bool =
  if self.gene.data.len < 1:
    return false
  var op = self.gene.op
  var first = self.gene.data[0]
  if first.kind == GeneSymbol:
    if first.symbol == "+=":
      self.gene.op = new_gene_symbol("=")
      var second = self.gene.data[1]
      self.gene.data[0] = op
      self.gene.data[1] = new_gene_gene(new_gene_symbol("+"), op, second)
      return true
    elif first.symbol == "=" and op.kind == GeneSymbol and op.symbol.startsWith("@"):
      # (@prop = val)
      self.gene.op = new_gene_symbol("@=")
      self.gene.data[0] = new_gene_string(op.symbol[1..^1])
      return true

Normalizers.add proc(self: GeneValue): bool =
  if self.gene.data.len < 1:
    return false
  var first = self.gene.data[0]
  if first.kind != GeneSymbol or first.symbol notin SIMPLE_BINARY_OPS:
    return false

  self.gene.data.delete 0
  self.gene.data.insert self.gene.op, 0
  self.gene.op = first
  return true

Normalizers.add proc(self: GeneValue): bool =
  if self.gene.data.len < 1:
    return false
  var op = self.gene.op
  var first = self.gene.data[0]
  if first.kind == GeneSymbol and first.symbol.startsWith(".@"):
    if first.symbol.endsWith("="):
      todo()
    else:
      self.gene.op = new_gene_symbol("@")
      self.gene.data[0] = new_gene_string_move(first.symbol.substr(2))
      self.gene.props["self"] = op
    return true

Normalizers.add proc(self: GeneValue): bool =
  if self.gene.data.len < 1:
    return false
  var op = self.gene.op
  var first = self.gene.data[0]
  if first.kind == GeneSymbol and first.symbol[0] == '.' and first.symbol != "...":
    self.gene.props["self"] = op
    self.gene.props["method"] = new_gene_string_move(first.symbol.substr(1))
    self.gene.data.delete 0
    self.gene.op = new_gene_symbol("$invoke_method")
    return true

Normalizers.add proc(self: GeneValue): bool =
  if self.gene.data.len < 1:
    return false
  var first = self.gene.data[0]
  if first.kind == GeneSymbol and first.symbol == "->":
    self.gene.props["args"] = self.gene.op
    self.gene.op = self.gene.data[0]
    self.gene.data.delete 0
    return true

# # Normalize symbols like "a..." etc
# # @Return: a normalized value to replace the original value
# proc normalize_symbol(self: GeneValue): GeneValue =
#   todo()

# Normalize self.vec, self.gene.data, self.map, self.gene.props etc but don't go further
proc normalize_children*(self:  GeneValue) =
  todo()

proc normalize*(self:  GeneValue) =
  if self.kind != GeneGene or self.gene.normalized:
    return
  if self.gene.op == Quote:
    return
  for n in Normalizers:
    if n(self):
      self.gene.normalized = true
      break

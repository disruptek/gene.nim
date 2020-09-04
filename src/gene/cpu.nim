# import strformat, logging
import tables, hashes

import ./types
import ./interpreter
import ./vm
import ./compiler

#################### Interfaces ##################

#################### Implementations #############

proc run*(self: var VM, module: Module): GeneValue =
  self.cur_block = module.default

  var instr: Instruction
  self.pos = 0
  while self.pos < self.cur_block.instructions.len:
    instr = self.cur_block.instructions[self.pos]
    # debug(&"{self.pos:>4} {instr}")
    case instr.kind:
    of Default:
      self.pos += 1
      self.cur_stack[0] = instr.val
    of Save:
      self.pos += 1
      self.cur_stack[instr.reg] = instr.val
    of Copy:
      self.pos += 1
      self.cur_stack[instr.reg2] = self.cur_stack[instr.reg]
    of Global:
      self.pos += 1
      self.cur_stack[0] = new_gene_internal(APP.ns)
    of Self:
      self.pos += 1
      self.cur_stack[0] = self.cur_stack.self
    of DefMember:
      self.pos += 1
      let key = instr.reg
      self.cur_stack.cur_scope[key] = self.cur_stack[0]
    of DefNsMember:
      self.pos += 1
      let name = instr.val
      case name.kind:
      of GeneSymbol:
        var key = name.symbol.hash
        self.cur_stack.cur_ns[key] = self.cur_stack[0]
      of GeneComplexSymbol:
        var csymbol = name.csymbol
        var ns: Namespace
        case csymbol.first:
        of "global":
          ns = APP.ns
        else:
          ns = self.cur_stack.cur_ns
          var key = csymbol.first.hash
          ns = ns[key].internal.ns
        for i in 0..<csymbol.rest.len - 1:
          var key = csymbol.rest[i].hash
          ns = ns[key].internal.ns
        var key = csymbol.rest[^1].hash
        ns[key] = self.cur_stack[0]
      else:
        not_allowed()
    of GetMember:
      self.pos += 1
      var key = instr.reg
      self.cur_stack[0] = self.cur_stack.get(key)
    of Add:
      self.pos += 1
      let first = self.cur_stack[instr.reg].num
      let second = self.cur_stack[instr.reg2].num
      self.cur_stack[0] = new_gene_int(first + second)
    of AddI:
      self.pos += 1
      let first = self.cur_stack[instr.reg].num
      let second = instr.val.num
      self.cur_stack[0] = new_gene_int(first + second)
    of Sub:
      self.pos += 1
      let first = self.cur_stack[instr.reg].num
      let second = self.cur_stack[instr.reg2].num
      self.cur_stack[0] = new_gene_int(first - second)
    of SubI:
      self.pos += 1
      let first = self.cur_stack[instr.reg].num
      let second = instr.val.num
      self.cur_stack[0] = new_gene_int(first - second)
    of Lt:
      self.pos += 1
      let first = self.cur_stack[instr.reg].num
      let second = self.cur_stack[instr.reg2].num
      self.cur_stack[0] = new_gene_bool(first < second)
    of LtI:
      self.pos += 1
      let first = self.cur_stack[instr.reg].num
      let second = instr.val.num
      self.cur_stack[0] = new_gene_bool(first < second)
    of Jump:
      self.pos = cast[int](instr.val.num)
    of JumpIfFalse:
      if self.cur_stack[instr.reg].isTruthy:
        self.pos += 1
      else:
        self.pos = cast[int](instr.val.num)
    of CreateFunction:
      self.pos += 1
      var fn = instr.val
      let key = cast[Hash](fn.internal.fn.name.hash)
      self.cur_stack.cur_ns[key] = fn
      self.cur_stack[0] = instr.val
    of CreateArguments:
      self.pos += 1
      var args = instr.val
      self.cur_stack[instr.reg] = args
    of CreateNamespace:
      self.pos += 1
      var name = instr.val.str
      var ns = new_namespace(name)
      var val = new_gene_internal(ns)
      let key = cast[Hash](name.hash)
      self.cur_stack.cur_ns[key] = val
      self.cur_stack[0] = val
    of Import:
      self.pos += 1
      var module = self.cur_stack[0].str
      var ns: Namespace
      if not APP.namespaces.hasKey(module):
        self.eval_module(module)
      ns = APP.namespaces[module]
      if ns == nil:
        todo("Evaluate module")
      var names = instr.val.vec
      for name in names:
        var s = name.symbol
        let key = cast[Hash](s.hash)
        self.cur_stack.cur_ns[key] = ns[key]
    of CreateClass:
      self.pos += 1
      var name = instr.val.str
      var class = new_class(name)
      var val = new_gene_internal(class)
      let key = cast[Hash](name.hash)
      self.cur_stack.cur_ns[key] = val
      self.cur_stack[0] = val
    of CreateMethod:
      self.pos += 1
      var fn = self.cur_stack[0].internal.fn
      var class = self.cur_stack.self.internal.class
      class.methods[fn.name] = fn
    of CreateInstance:
      self.pos += 1
      var class = self.cur_stack[0].internal.class
      var instance = new_gene_instance(new_instance(class))
      self.cur_stack[0] = instance
      if class.methods.hasKey("new"):
        var fn = class.methods["new"]
        var stack = self.cur_stack
        var args = self.cur_stack[instr.reg].internal.args
        self.cur_stack = StackMgr.get
        self.cur_stack.cur_ns = stack.cur_ns
        self.cur_stack.cur_scope = ScopeMgr.get()
        self.cur_stack.self = instance
        self.cur_stack.caller_stack = stack
        self.cur_stack.caller_blk = self.cur_block
        self.cur_stack.caller_pos = self.pos
        for i in 0..<fn.args.len:
          var arg = fn.args[i]
          var val = args[i]
          let key = cast[Hash](arg.hash)
          self.cur_stack.cur_scope[key] = val
        self.cur_block = fn.body_block
        self.pos = 0
    of PropGet:
      self.pos += 1
      var name = instr.val.str
      var this = self.cur_stack[0]
      var val = this.instance.value.gene_props[name]
      self.cur_stack[0] = val
    of PropSet:
      self.pos += 1
      var name = instr.val.str
      var val = self.cur_stack[instr.reg]
      self.cur_stack.self.instance.value.gene_props[name] = val

    of InvokeMethod:
      self.pos += 1
      var this = self.cur_stack[instr.reg]
      var name = instr.val.str
      var fn = this.instance.class.methods[name]
      var args = self.cur_stack[instr.reg2].internal.args
      var stack = self.cur_stack
      var cur_stack = StackMgr.get
      cur_stack.self = this
      cur_stack.cur_ns = stack.cur_ns
      cur_stack.cur_scope = ScopeMgr.get()
      for i in 0..<fn.args.len:
        var arg = fn.args[i]
        var val = args[i]
        let key = cast[Hash](arg.hash)
        cur_stack.cur_scope[key] = val
      cur_stack.caller_stack = stack
      cur_stack.caller_blk = self.cur_block
      cur_stack.caller_pos = self.pos
      self.cur_stack = cur_stack
      self.cur_block = fn.body_block
      self.pos = 0

    of Call:
      self.pos += 1
      var stack = self.cur_stack
      var fn = stack[0].internal.fn
      var args = stack[instr.reg].internal.args
      var cur_stack = StackMgr.get()
      cur_stack.cur_ns = stack.cur_ns
      cur_stack.cur_scope = ScopeMgr.get()
      for i in 0..<fn.args.len:
        var arg = fn.args[i]
        var val = args[i]
        let key = cast[Hash](arg.hash)
        cur_stack.cur_scope[key] = val
      cur_stack.caller_stack = stack
      cur_stack.caller_blk = self.cur_block
      cur_stack.caller_pos = self.pos
      self.cur_stack = cur_stack
      self.cur_block = fn.body_block
      self.pos = 0

    of CallNative:
      self.pos += 1
      var name = instr.val.str
      case name:
      of "str_len":
        var args = self.cur_stack[instr.reg].internal.args
        var str = args[0].str
        self.cur_stack[0] = new_gene_int(str.len)
      else:
        todo(name)

    of CallBlock:
      self.pos += 1
      var stack = self.cur_stack
      var cur_stack = StackMgr.get
      cur_stack.cur_ns = stack.cur_ns
      cur_stack.cur_scope = ScopeMgr.get()
      cur_stack.self = stack[instr.reg2]
      cur_stack.caller_stack = stack
      cur_stack.caller_blk = self.cur_block
      cur_stack.caller_pos = self.pos
      self.cur_stack = cur_stack
      self.cur_block = stack[instr.reg].internal.blk
      self.pos = 0

    of CallEnd:
      var stack = self.cur_stack
      self.cur_stack = stack.caller_stack
      if not self.cur_block.no_return:
        self.cur_stack[0] = stack[0]
      self.cur_block = stack.caller_blk
      self.pos = stack.caller_pos
      ScopeMgr.free(stack.cur_scope)
      StackMgr.free(stack)

    of SetItem:
      self.pos += 1
      var val = self.cur_stack[instr.reg]
      var index = instr.val.num
      if val.kind == GeneInternal and val.internal.kind == GeneArguments:
        val.internal.args[cast[int](index)] = self.cur_stack[0]
      else:
        todo($instr)
    else:
      # self.pos += 1
      todo($instr)

  result = self.cur_stack.default

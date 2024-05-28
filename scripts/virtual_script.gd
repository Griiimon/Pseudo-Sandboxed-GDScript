class_name VirtualScript
extends RefCounted


class Variable:
	var type: int
	var value: Variant

	func _init(_type: int):
		type= _type 



class Function:
	enum Type { BUILT_IN, CUSTOM }
	
	var name: String
	var type: Type
	var arguments: Array[String]
	var code: Code
	var callable: Callable


	func _init(_name: String, _type: Type= Type.BUILT_IN, _arguments: Array[String]= [], _code: Code= null):
		name= _name
		type= _type
		arguments= _arguments
		code= _code

	
	func set_callable(_callable: Callable):
		callable= _callable
		return self


	func run(arg_values: Array):
		match type:
			Type.BUILT_IN:
				assert(callable)
				callable.call(arg_values)
			Type.CUSTOM:
				code.run(arguments, arg_values)

	
	func get_return_value():
		if code:
			return code.return_value


class CodeNode:
	var desc: String
	
	func _init(s: String):
		desc= s
		prints("Create", s, "node")
		
		
	func add_line(text: String)-> CodeNode:
		var line:= CodeLine.new()
		var parse_result: ParseResult= line.parse(text)
		if parse_result.ignore_line:
			return self
		var current_node: CodeNode= self
		var new_node: CodeNode= current_node.on_add_line(line)
		return new_node if new_node else current_node


	func on_add_line(line: CodeLine)-> CodeNode:
		return null


	func close_block(next_line: CodeLine):
		pass


	func is_parsing_finished()-> bool:
		return false
	
	
	func can_finish_parsing()-> bool:
		return false

	
	func dump_node_tree(indent: int, with_content: bool, suffix: String= ""):
		print(" ".repeat(indent), desc, suffix)



class BlockNode extends CodeNode:
	var nodes: Array[CodeNode]
	var parsing_finished: bool= false
	var current_node: CodeNode
	
	
	func _init():
		super("Block")


	func run(script: VirtualScript, local_code: Code= null):
		for node in nodes:
			var done: bool= false
			while not done:
				if node.execute(script, local_code).has_finished:
					done= true


	func on_add_line(line: CodeLine):
				
		if nodes.is_empty() or nodes[-1].is_parsing_finished():
			var new_node: bool= false
			if line.type == CodeLine.Type.FLOW_CONTROL:
				match line.parameter:
					CodeLine.FlowControls.IF:
						nodes.append(IfNode.new())
						new_node= true
					CodeLine.FlowControls.WHILE:
						nodes.append(WhileNode.new())
						new_node= true
						
			if new_node:
				nodes[-1].on_add_line(line)
			else:
				nodes.append(line)
		else:
			nodes[-1].on_add_line(line)


	func close_block(next_line: CodeLine):
		if nodes.is_empty() or not nodes[-1].can_finish_parsing():
			parsing_finished= true
		else:
			if nodes[-1].is_parsing_finished():
				parsing_finished= true
			else:
				nodes[-1].close_block(next_line)


	func execute(script: VirtualScript, local_code: Code)-> CodeExecutionResult:
		if not current_node:
			assert(not nodes.is_empty())
			current_node= nodes[0]
		#else:
			#var idx: int= nodes.find(current_node)
			#current_node= nodes[idx + 1]
			
		var result: CodeExecutionResult= current_node.execute(script, local_code)
		if current_node == nodes.back() and result.has_finished:
			return CodeExecutionResult.new().finish()
		if result.has_finished:
			var idx: int= nodes.find(current_node)
			current_node= nodes[idx + 1]
		return CodeExecutionResult.new()
		

	func is_parsing_finished()-> bool:
		return parsing_finished


	func can_finish_parsing()-> bool:
		return true


	func dump_node_tree(indent: int, with_content: bool, suffix: String= ""):
		super(indent, with_content, suffix)
		indent+= 1
		for node in nodes:
			node.dump_node_tree(indent, with_content)



class IfNode extends CodeNode:
	enum State { CONDITION, TRUE_BLOCK, FALSE_BLOCK }
	var statement: CodeLine
	var true_block: BlockNode
	var false_block: BlockNode
	var parsing_finished: bool= false
	
	var state= State.CONDITION


	func _init():
		super("If")


	func on_add_line(line: CodeLine):
		if not statement:
			statement= line
			true_block= BlockNode.new()
		elif false_block:
			false_block.on_add_line(line)
		elif not true_block.is_parsing_finished():
			true_block.on_add_line(line)
		elif line.type == CodeLine.Type.FLOW_CONTROL and line.parameter == CodeLine.FlowControls.ELSE:
			false_block= BlockNode.new()
		else:
			assert(false)

	func close_block(next_line: CodeLine):
		if false_block:
			false_block.close_block(next_line)
			parsing_finished= false_block.is_parsing_finished()
		elif true_block:
			true_block.close_block(next_line)
			if true_block.is_parsing_finished():
				if not next_line or next_line.type != CodeLine.Type.FLOW_CONTROL or next_line.parameter != CodeLine.FlowControls.ELSE:
					parsing_finished= true


	func execute(script: VirtualScript, local_code: Code)-> CodeExecutionResult:
		match state:
			State.CONDITION:
				var result: CodeExecutionResult= statement.execute(script, local_code)
				if result.value:
					state= State.TRUE_BLOCK
				elif false_block:
					state= State.FALSE_BLOCK
				else :
					result.has_finished= true
					
				return result
			State.TRUE_BLOCK:
				var result: CodeExecutionResult= true_block.execute(script, local_code)
				#if not result.has_error:
					#if result.has_finished:
						#if false_block:
							#state= State.FALSE_BLOCK
							#result.has_finished= false
				return result
			State.FALSE_BLOCK:
				return false_block.execute(script, local_code)
		
		assert(false)
		return CodeExecutionResult.new()


	func is_parsing_finished()-> bool:
		return parsing_finished


	func can_finish_parsing()-> bool:
		return true


	func dump_node_tree(indent: int, with_content: bool, suffix: String= ""):
		super(indent, with_content, ( "   " + statement.orig_text) if with_content else "")
		indent+= 1
		true_block.dump_node_tree(indent, with_content, " [True]")
		if false_block:
			false_block.dump_node_tree(indent, with_content, " [False]")



class LoopNode extends CodeNode:
	enum State { CONDITION, BLOCK }
	
	var state= State.CONDITION
	var statement: CodeLine
	var block: BlockNode


	func on_add_line(line: CodeLine):
		if not statement:
			statement= line
			block= BlockNode.new()
		else:
			block.on_add_line(line)


	func close_block(next_line: CodeLine):
		block.close_block(next_line)


	func is_parsing_finished()-> bool:
		return block.is_parsing_finished()


	func can_finish_parsing()-> bool:
		return true



class WhileNode extends LoopNode:

	func _init():
		super("While")


	func execute(script: VirtualScript, local_code: Code)-> CodeExecutionResult:
		match state:
			State.CONDITION:
				var result: CodeExecutionResult= statement.execute(script, local_code)
				if result.value:
					state= State.BLOCK
				else :
					result.has_finished= true
					
				return result
			State.BLOCK:
				var result: CodeExecutionResult= block.execute(script, local_code)
				if result.has_finished:
					state= State.CONDITION
				result.has_finished= false
				return result
		
		assert(false)
		return CodeExecutionResult.new()


	func dump_node_tree(indent: int, with_content: bool, suffix: String= ""):
		super(indent, with_content, ( "   " + statement.orig_text) if with_content else "")



class Code:
	var root: CodeNode
#	var current_block: CodeNode
	var parent_script: VirtualScript
	var return_value: Variant
	
	var local_variables:= {}
	
	var nesting: int= 0
	var store_nesting:= {}
	
	func _init(_script: VirtualScript):
		root= BlockNode.new()
		parent_script= _script
	

	func run(variable_names: Array[String]= [], variable_values: Array= []):
		assert(len(variable_names) == len(variable_values), str("Variables/Values count doesn't match ", len(variable_names), " vs ", len(variable_values)))
		
		for i in len(variable_names):
			var var_name: String= variable_names[i]
			var var_value= variable_values[i]
			var local_var:= VirtualScript.Variable.new(typeof(var_value))
			local_var.value= var_value
			local_variables[var_name]= local_var 
			
		root.run(parent_script, self)


	func create_inline(text: String)-> Code:
		root.add_line(text)
		return self



class CodeLine extends CodeNode:
	enum Type { CREATE_VARIABLE, ASSIGN_VARIABLE, FLOW_CONTROL, RETURN, PASS, CUSTOM, FUNCTION }
	enum FlowControls { IF, ELSE, ELIF, FOR, WHILE }
	
	var type: Type
	var parameter: Variant
	var parameter2: Variant
	var expression: String
	
	var orig_text: String


	func _init(pre_parse: bool= false):
		if not pre_parse:
			super("CodeLine")
	
	
	func execute(script: VirtualScript, local_code: Code)-> CodeExecutionResult:
		print(get_desc(), "  ||  \"", orig_text, "\"")
		
		if expression:
			pre_parse_expression(script, local_code)
		
		match type:
			Type.CREATE_VARIABLE:

				if not parameter or not parameter is String:
					return CodeExecutionResult.new().error("Create variable: missing/incorrect variable name")
				if not parameter2 or not parameter2 is String:
					return CodeExecutionResult.new().error("Create variable: missing/incorrect variable type")
				
				script.create_variable(parameter, VirtualScript.get_type_from_string(parameter2))

			Type.ASSIGN_VARIABLE:

				if not parameter or not parameter is String:
					return CodeExecutionResult.new().error("Assign Variable: missing/incorrect variable name")

				var result: EvaluationResult= script.solve_expression(expression, local_code)
				if result.has_error:
					return CodeExecutionResult.new().error("Evaluation error: " + result.error_text)
				script.assign_variable(parameter, result.value)
			
			Type.FLOW_CONTROL:
				
				match parameter:

					FlowControls.IF:
						var result: EvaluationResult= script.solve_expression(expression, local_code)
						if result.has_error:
							return CodeExecutionResult.new().error("Evaluation error: " + result.error_text)
						return CodeExecutionResult.new(result.value)
					
					FlowControls.WHILE:
						var result: EvaluationResult= script.solve_expression(expression, local_code)
						if result.has_error:
							return CodeExecutionResult.new().error("Evaluation error: " + result.error_text)
						return CodeExecutionResult.new(result.value)
			
			Type.RETURN:
				var result: EvaluationResult= script.solve_expression(expression, local_code)
				if result.has_error:
					return CodeExecutionResult.new().error("Evaluation error: " + result.error_text)
				local_code.return_value= result.result_value
		
			Type.PASS:
				pass

		
		return CodeExecutionResult.new().finish()


	func pre_parse_expression(script: VirtualScript, local_code: Code):
		for func_name in script.all_functions.keys():
			if func_name + "(" in expression:
				# TODO build priority list by checking how many '(' - ')' are preceeding the function call
				# and resolve code from highest priority
				
				var regex:= RegEx.new()
				var arg_values: Array= parse_function_arguments(func_name, expression, script, local_code, regex)

				prints(func_name, "argument values", arg_values)
				var func_ref: Function= script.all_functions[func_name]
				func_ref.run(arg_values)
				var return_val= func_ref.get_return_value()
				if return_val:
					expression= regex.sub(expression, str())
				prints("Expression after replacing", expression)


	func parse(text: String)-> ParseResult:
		prints("Parsing line", text)
		orig_text= text
		
		if text.begins_with("#"):
			type= Type.PASS
			return ParseResult.new().ignore()
		elif text.begins_with("var "):
			var s: String= text.substr(4)
			if not ":" in s:
				return MyResult.new().error("Parse error: variable definition missing : type")
			type= Type.CREATE_VARIABLE
			var parts: PackedStringArray= s.split(":")
			parameter= parts[0].strip_edges()
			parameter2= parts[1].strip_edges()
		elif text.begins_with("if "):
			type= Type.FLOW_CONTROL
			parameter= FlowControls.IF
			expression= text.trim_prefix("if ").rstrip(":")
		elif text.begins_with("return "):
			var s: String= text.substr(7)
			type= Type.RETURN
			expression= s
		elif text.begins_with("pass"):
			type= Type.PASS
		elif text.begins_with("else"):
			type= Type.FLOW_CONTROL
			parameter= FlowControls.ELSE
		elif "=" in text and not "==" in text:
			var parts: PackedStringArray= text.split("=")
			type= Type.ASSIGN_VARIABLE
			parameter= parts[0].strip_edges()
			expression= parts[1].strip_edges()
		elif text.begins_with("while "):
			type= Type.FLOW_CONTROL
			parameter= FlowControls.WHILE
			expression= text.trim_prefix("while ").rstrip(":")
		else:
			for func_name in VirtualScriptHelper.built_in_functions:
				if text.begins_with(func_name + "("):
					type= Type.FUNCTION
					expression= text
					return ParseResult.new()
			assert(false, "Can't parse line:  " + text)

		return ParseResult.new()


	func parse_function_arguments(func_name: String, _expression: String, script: VirtualScript, local_code: Code, regex: RegEx)-> Array:
		assert((func_name + "(") in _expression)
		
		var arg_str: String= _expression.trim_prefix(func_name + "(").trim_suffix(")")
		prints("Trimmed arg_str", arg_str)
		var args: Array[String]= []
		var i:= 0
		var start: int
		var stack:= 0
		while i < len(arg_str):
			if arg_str[i] == "," and stack == 0:
				args.append(arg_str.substr(start, i - start).strip_edges())
				start= i + 1
			elif arg_str[i] == "(":
				stack+= 1
			elif arg_str[i] == ")":
				stack-= 1
				assert(stack >= 0)

			i+= 1
		
		args.append(arg_str.substr(start, i - start))

		prints(func_name, "arguments", args)
		var arg_values: Array= []

		for arg in args:
			var result: EvaluationResult= script.solve_expression(arg, local_code)
			if result.value != null:
				if result.has_error:
					return CodeExecutionResult.new().error("Evaluation error: " + result.error_text)
				arg_values.append(result.value)

		return arg_values


	func is_parsing_finished()-> bool:
		return true

		
	func get_desc()-> String:
		var result:= ""
		result+= Type.keys()[type]
		match type:
			Type.CREATE_VARIABLE:
				result+= " " + parameter
			Type.ASSIGN_VARIABLE:
				result+= " " + parameter + "="
			Type.FLOW_CONTROL:
				result+= " " + FlowControls.keys()[parameter]
		result+= " " + expression
		return result


	func dump_node_tree(indent: int, with_content: bool, suffix: String= ""):
		super(indent, with_content, ("   " + orig_text ) if with_content else "")


class CodeExecutionResult extends MyResult:
	var value: Variant
	var has_finished: bool= false

	func _init(_value= null):
		value= _value
		

	func finish():
		has_finished= true
		return self



class ParseResult extends MyResult:
	var ignore_line: bool= false
	
	func ignore():
		ignore_line= true
		return self


var variables:= {}
var functions:= {}
var all_functions: Dictionary

var code: Code= Code.new(self)

var close_block_queue: int= 0

var attached_to_node: Node



func run():
	print("RUN")
	all_functions= {}
	all_functions.merge(functions)
	all_functions.merge(VirtualScriptHelper.built_in_functions)
	
	code.run()


func assign_variable(var_name: String, value: Variant):
	if not var_name in variables:
		assert(attached_to_node and attached_to_node.get(var_name) != null)
		attached_to_node.set(var_name, value)
	else:
		variables[var_name].value= value


func create_variable(var_name: String, type: int):
	variables[var_name]= Variable.new(type)
	# TODO set default value


func solve_expression(expression: String, local_code: Code)-> EvaluationResult:
	if expression.is_empty(): return EvaluationResult.new()
	var all_variables:= variables.duplicate()
	if local_code != code:
		all_variables.merge(local_code.local_variables, true)
	
	return Evaluator.evaluate(expression, all_variables.keys(), all_variables.values().map(func(v): return v.value), attached_to_node)


func add_line(text: String):
	text= text.strip_edges()
	
	if not text: return
	
	while close_block_queue > 0:
		close_block_queue-= 1
		var closing_line: CodeLine
		if close_block_queue == 0:
			closing_line= CodeLine.new(true)
			closing_line.parse(text)
		code.root.close_block(closing_line)
		
		
	code.root.add_line(text)


func close_block():
	print("Close block")
	close_block_queue+= 1
	

func register_function(func_name: String, type: Function.Type, arguments: Array[String], func_code: Code):
	functions[func_name]= Function.new(func_name, type, arguments, func_code)


func parse_file(file_path: String):
	assert(FileAccess.file_exists(file_path), file_path + " doesn't exist")
	
	var indents:= 0
	
	for line in FileAccess.get_file_as_string(file_path).split("\n"):
		line= line.strip_edges(false, true)
		var line_indents:= line.count("\t")
		
		if indents != line_indents:
			while indents > line_indents:
				close_block()
				indents-= 1
				
			indents= line_indents
		
		add_line(line)


func process_callback(delta: float):
	pass


func physics_process_callback(delta: float):
	pass


func tree_exiting_signal():
	pass
	

func tree_exited_signal():
	pass


func dump_variables():
	for var_name in variables.keys():
		print(var_name + ": " + str(variables[var_name].value))


func dump_node_tree(with_content: bool= false):
	code.root.dump_node_tree(0, with_content)


static func get_type_from_string(type_desc: String)-> int:
	type_desc= type_desc.to_lower()
	match type_desc:
		"int":
			return TYPE_INT
		"float":
			return TYPE_FLOAT
		"string":
			return TYPE_STRING
		"array":
			return TYPE_ARRAY
		_:
			assert(false, "unhandled type " + type_desc)
			return -1

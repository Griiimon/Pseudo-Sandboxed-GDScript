class_name VirtualScript
extends RefCounted


class Variable:
	var type: int
	var value: Variant

	func _init(_type: int):
		type= _type 


class Function:
	var name: String
	var arguments: Array[String]
	var code: Code

	func _init(_name: String, _arguments: Array[String], _code: Code):
		name= _name
		arguments= _arguments
		code= _code


class Code:
	var root: CodeBlock
	var current_block: CodeBlock
	var previous_block: CodeBlock
	var parent_script: VirtualScript
	var return_value: Variant
	
	var local_variables:= {}
	
	var nesting: int= 0
	var store_nesting:= {}
	
	func _init(_script: VirtualScript):
		root= CodeBlock.new()
		current_block= root
		parent_script= _script
	

	func run(variable_names: Array[String]= [], variable_values: Array= []):
		assert(len(variable_names) == len(variable_values))
		
		for i in len(variable_names):
			var var_name: String= variable_names[i]
			var var_value= variable_values[i]
			var local_var:= VirtualScript.Variable.new(typeof(var_value))
			local_var.value= var_value
			local_variables[var_name]= local_var 
			
		current_block.run(parent_script, self)


	func jump_to_block(block: CodeBlock):
		current_block= block
		run()
	
	
	func create_inline(text: String)-> Code:
		root.add_line(text)
		return self

class CodeLine:
	enum Type { CREATE_VARIABLE, ASSIGN_VARIABLE, FLOW_CONTROL, RETURN, PASS, CUSTOM }
	enum FlowControls { IF, ELSE, ELIF, FOR, WHILE }
	
	var type: Type
	var parameter: Variant
	var parameter2: Variant
	var expression: String
	
	var orig_text: String
	
	
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
				script.assign_variable(parameter, result.result_value)
			
			Type.FLOW_CONTROL:
				
				match parameter:

					FlowControls.IF:

						var result: EvaluationResult= script.solve_expression(expression, local_code)
						if result.has_error:
							return CodeExecutionResult.new().error("Evaluation error: " + result.error_text)
						var current_block: CodeBlock= script.code.current_block
						var fork: bool= not result.result_value
						prints("  fork:", fork)
						return CodeExecutionResult.new(current_block.next_block if not fork else current_block.fork_block)

					FlowControls.ELSE:

						return CodeExecutionResult.new(script.code.current_block.next_block)

					FlowControls.WHILE:
						
						var result: EvaluationResult= script.solve_expression(expression, local_code)
						if result.has_error:
							return CodeExecutionResult.new().error("Evaluation error: " + result.error_text)
						var current_block: CodeBlock= script.code.current_block
						current_block.next_block if result.result_value else current_block.fork_block
						return CodeExecutionResult.new(current_block.next_block if result.result_value else current_block.fork_block)

			Type.RETURN:
				var result: EvaluationResult= script.solve_expression(expression, local_code)
				if result.has_error:
					return CodeExecutionResult.new().error("Evaluation error: " + result.error_text)
				local_code.return_value= result.result_value
		
			Type.PASS:
				pass
		
		return CodeExecutionResult.new()


	func pre_parse_expression(script: VirtualScript, local_code: Code):
		for func_name in script.functions.keys():
			if func_name in expression:
				# TODO build priority list by checking how many '(' - ')' are preceeding the function call
				# and resolve code from highest priority
				 
				assert((func_name + "(") in expression)
				var regex= RegEx.new()
				regex.compile(func_name + "\\(([^,]+),\\s*([^)]+)\\)")
				var regex_result: RegExMatch = regex.search(expression)
				assert(regex_result)

				var arg_str= regex_result.get_string().substr(len(func_name) + 1).rstrip(")")
				prints(func_name, "arguments", arg_str)
				var func_ref: Function= script.functions[func_name]
				var arg_values: Array

				for arg in arg_str.split(","):
					var result: EvaluationResult= script.solve_expression(arg, local_code)
					if result.has_error:
						return CodeExecutionResult.new().error("Evaluation error: " + result.error_text)
					arg_values.append(result.result_value)

				prints(func_name, "argument values", arg_values)
				func_ref.code.run(func_ref.arguments, arg_values)
				expression= regex.sub(expression, str(func_ref.code.return_value))
				prints("Expression after replacing", expression)


	func parse(text: String)-> ParseResult:
		prints("Parsing line", text)
		orig_text= text
		
		if text.begins_with("var "):
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
			return ParseResult.new(true)
		elif text.begins_with("return "):
			var s: String= text.substr(7)
			type= Type.RETURN
			expression= s
		elif text.begins_with("pass"):
			type= Type.PASS
		elif text.begins_with("else"):
			type= Type.FLOW_CONTROL
			parameter= FlowControls.ELSE
			return ParseResult.new(true)
		elif "=" in text and not "==" in text:
			var parts: PackedStringArray= text.split("=")
			type= Type.ASSIGN_VARIABLE
			parameter= parts[0].strip_edges()
			expression= parts[1].strip_edges()
		else:
			assert(false)

		return ParseResult.new()


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
		

class CodeBlock:
	var lines: Array[CodeLine]
	
	var next_block: CodeBlock
	var fork_block: CodeBlock


	func run(script: VirtualScript, local_code: Code= null):
		for line in lines:
			var result: CodeExecutionResult= line.execute(script, local_code)
			if result.jump_to_block:
				# TODO jump should be a result of this func AFTER it finished
				# so we don't pile on the call stack
				script.code.jump_to_block(result.jump_to_block)
				return


	func add_line(text: String)-> CodeBlock:
		var line:= CodeLine.new()
		var parse_result: ParseResult= line.parse(text)
		lines.append(line)
		if parse_result.create_block:
			assert(not next_block)
			next_block= CodeBlock.new()
		return next_block


class CodeExecutionResult extends MyResult:
	var jump_to_block: CodeBlock
	
	func _init(jump: CodeBlock= null):
		jump_to_block= jump


class ParseResult extends MyResult:
	var create_block: bool
	
	func _init(_create_block: bool= false):
		create_block= _create_block


var variables:= {}
var functions:= {}

var code: Code= Code.new(self)



func run():
	print("RUN")
	code.current_block= code.root
	code.run()


func assign_variable(var_name: String, value: Variant):
	variables[var_name].value= value


func create_variable(var_name: String, type: int):
	variables[var_name]= Variable.new(type)
	# TODO set default value


func solve_expression(expression: String, local_code: Code)-> EvaluationResult:
	var all_variables:= variables.duplicate()
	if local_code != code:
		all_variables.merge(local_code.local_variables, true)
	
	return Evaluator.evaluate(expression, all_variables.keys(), all_variables.values().map(func(v): return v.value))


func add_line(text: String):
	var new_block: CodeBlock= code.current_block.add_line(text)
	
	if new_block:
		code.store_nesting[code.nesting]= code.current_block
		#if code.previous_block:
			#code.previous_block.next_block= new_block
		code.previous_block= code.current_block
		code.current_block= new_block

		print(" ".repeat(code.nesting) + "->")
		code.nesting+= 1


func close_block():
	var new_block:= CodeBlock.new()
	
	#if code.previous_block:
		#code.previous_block.fork_block= new_block
	code.previous_block= code.current_block
	code.current_block= new_block

	print(" ".repeat(code.nesting) + "<-")
	code.nesting-= 1
	if code.nesting >= 0:
		code.store_nesting[code.nesting].fork_block= new_block


func register_function(func_name: String, arguments: Array[String], func_code: Code):
	functions[func_name]= Function.new(func_name, arguments, func_code)


func dump_variables():
	for var_name in variables.keys():
		print(var_name + ": " + str(variables[var_name].value))


func dump_tree():
	print(" ------- TREE -------- ")
	var current_block: CodeBlock= code.root
	
	while current_block:
		for line in current_block.lines:
			print(line.get_desc())
		var s:= ""
		if current_block.next_block:
			s+= " --> " + current_block.next_block.lines[0].get_desc()
		if current_block.fork_block:
			s+= " |-> " + current_block.fork_block.lines[0].get_desc()
		print(s)
		current_block= current_block.next_block
		

	print(" --------------------- ")


static func get_type_from_string(type_desc: String)-> int:
	match type_desc.to_lower():
		"int":
			return TYPE_INT
		"float":
			return TYPE_FLOAT
		"string":
			return TYPE_STRING
		"array":
			return TYPE_ARRAY
		_:
			assert(false)
			return -1

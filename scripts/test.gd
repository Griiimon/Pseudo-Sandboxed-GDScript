extends Node

func _ready():
	
	#var result: EvaluationResult= Evaluator.evaluate("x == 1", ["x"], [2])
	#
	#if result.has_error:
		#push_error(result.error_text)
	#else:
		#print(result.result)
#
	#get_tree().quit()
	#return

	start.call_deferred()


func start():
	var script:= VirtualScript.new()
	
	#test1(script)
	#test2(script)
	#script.parse_file("res://virtual scripts/if_else.txt")
	#script.parse_file("res://virtual scripts/built_in_funcs.txt")
	#script.parse_file("res://virtual scripts/loops.txt")
	script.parse_file("res://virtual scripts/function.txt")
	print("---")
	script.dump_node_tree(true)
	print("---")
	
	script.run()
	print("---")
	
	script.dump_variables()
	
	#get_tree().quit.call_deferred()


func test1(script: VirtualScript):
	script.register_function("my_func", VirtualScript.FunctionDefinition.Type.CUSTOM, ["a", "b"], VirtualScript.Code.new(script).create_inline("return a + b", script).root)
	#script.register_function("my_func", VirtualScript.FunctionDefinition.Type.CUSTOM, ["a", "b"], VirtualScript.Code.new(script).create_inline("return a + b", script))
	#script.register_function("my_func", VirtualScript.Function.Type.CUSTOM, ["a"], VirtualScript.Code.new(script).create_inline("return a"))
	
	script.add_line("var x: int")
	script.add_line("x = 1")

	script.add_line("if my_func(x, 1) == 2:")
	#script.add_line("if my_func(x) == 2:")
	script.add_line("x= 2")


func test2(script: VirtualScript):
	pass
	

func node_test2(script: VirtualScript):
	$Sprite2D.show()
	VirtualScriptManager.attach_script(script, $Sprite2D)

	script.register_function("_process", VirtualScript.FunctionDefinition.Type.CUSTOM, ["delta"], VirtualScript.Code.new(script).create_inline("position = position + Vector2(delta * 10, 0)", script).root)
	#script.add_line("position= position - Vector2(200, 200)")


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
	script.parse_file("res://virtual scripts/script.txt")
	
	script.run()
	
	script.dump_variables()
	
	get_tree().quit.call_deferred()


func test1(script: VirtualScript):
	script.register_function("my_func", ["a", "b"], VirtualScript.Code.new(script).create_inline("return a + b"))
	
	script.add_line("var x: int")
	script.add_line("x = 1")

	script.add_line("if my_func(x, 1) == 2:")
	script.add_line("x= 2")


func test2(script: VirtualScript):
	
	script.add_line("var x: int")
	script.add_line("x = 1")

	script.add_line("if true:")
	#script.add_line("pass")
	script.add_line("if false:")
	script.add_line("x= 100")
	script.close_block()
	script.add_line("else:")
	script.add_line("x = -100")
	script.close_block()
	script.close_block()
	script.add_line("else:")
	script.add_line("x = -1")

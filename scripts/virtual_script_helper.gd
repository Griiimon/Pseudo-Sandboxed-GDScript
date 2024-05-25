class_name VirtualScriptHelper

static var built_in_functions:= {
	"print": VirtualScript.Function.new("print").set_callable(func(arr: Array): print("".join(arr.map(func(x): return str(x))))), 
	"prints": VirtualScript.Function.new("prints").set_callable(func(arr: Array): print(" ".join(arr.map(func(x): return str(x))))) }

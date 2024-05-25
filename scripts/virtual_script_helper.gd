class_name VirtualScriptHelper

static var built_in_functions:= {
	"print": VirtualScript.Function.new("print").set_callable(func(arr: Array): print(arr.map(func(x): return str(x)))) }

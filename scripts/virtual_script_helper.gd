class_name VirtualScriptHelper


static var built_in_functions:= {
	"print": VirtualScript.Function.new("print").set_callable(func(arr: Array): print("".join(arr.map(func(x): return str(x))))), 
	"prints": VirtualScript.Function.new("prints").set_callable(func(arr: Array): print(" ".join(arr.map(func(x): return str(x))))),
	"push_warning": VirtualScript.Function.new("push_warning").set_callable(func(arr: Array): push_warning("".join(arr.map(func(x): return str(x))))), 
	"push_error": VirtualScript.Function.new("push_error").set_callable(func(arr: Array): push_error("".join(arr.map(func(x): return str(x))))), 
	"randomize": VirtualScript.Function.new("randomize").set_callable(func(arr: Array): randomize()), 
	"seed": VirtualScript.Function.new("seed").set_callable(func(arr: Array): seed(arr[0])),  
	"assert": VirtualScript.Function.new("assert").set_callable(func(arr: Array): assert(arr[0], arr[1])) } 




static func find_matching_parenthesis(s: String, start: int)-> int:
	#Find the index of the matching parenthesis """
	var stack:= 0
	for i in range(start, len(s)):
		if s[i] == '(':
			stack += 1
		elif s[i] == ')':
			stack -= 1
			if stack == 0:
				return i
	return -1

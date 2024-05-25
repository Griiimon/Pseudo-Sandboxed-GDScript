class_name MyResult

var has_error: bool= false
var error_text: String

func error(text: String):
	error_text= text
	has_error= true
	return self


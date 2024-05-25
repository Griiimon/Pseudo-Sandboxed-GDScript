class_name Evaluator


static func evaluate(command, variable_names = [], variable_values = [], base_instance= null) -> EvaluationResult:
	prints("Evaluating", ">>", command, "<<", variable_names, variable_values)
	var expression = Expression.new()
	var error = expression.parse(command, variable_names)
	if error != OK:
		return EvaluationResult.new().error(expression.get_error_text())


	var result = expression.execute(variable_values, base_instance)

	if expression.has_execute_failed():
		return EvaluationResult.new().error("Expression execute failed")
	
	return EvaluationResult.new(result)



extends Node


var registered_scripts: Array[VirtualScript]


func _process(delta):
	for script in registered_scripts:
		script.process_callback(delta)


func _physics_process(delta):
	for script in registered_scripts:
		script.physics_process_callback(delta)


func attach_script(script: VirtualScript, node: Node):
	script.attached_to_node= node
	register_script(script)
	node.tree_exiting.connect(node_tree_exiting_signal.bind(script))
	node.tree_exited.connect(script.tree_exited_signal)


func register_script(script: VirtualScript):
	if not script in registered_scripts:
		registered_scripts.append(script)


func unregister_script(script: VirtualScript):
	registered_scripts.erase(script)


func node_tree_exiting_signal(script: VirtualScript):
	script.tree_exiting_signal()
	script.attached_to_node= null
	unregister_script(script)

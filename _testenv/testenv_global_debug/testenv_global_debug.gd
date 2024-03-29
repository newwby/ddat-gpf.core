extends Node2D

#01. tool
#02. extends <- switched with class_name (originally 02.)
#03. class_name <- switched with extends (originally 03.)

##############################################################################

#04. # dependencies, docstring, #//TODO

# This is a modified version of the 3.5 gdscript style guide
# https://docs.godotengine.org/en/3.5/tutorials/scripting/gdscript/gdscript_styleguide.html

# all arguments should be prefixed with arg_ so it is clear in the code
# block what is a parameter and what is an argument at first glance
#
#	 func _example(arg_argument_name):
#		pass

##############################################################################

#05. signals
#06. enums
#07. constants
#
#08. exported variables
#09. public variables
#10. private variables
#11. onready variables

##############################################################################

# virtual methods


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.
	GlobalDebug.update_debug_overlay("key_example", 300)
	GlobalDebug.update_debug_overlay("key_example", 305)
	GlobalDebug.update_debug_overlay("key_example", 301, GlobalDebug.FLAG_OVERLAY_POSITION.BOTTOM_LEFT)
	GlobalDebug.add_dev_command("test_command", self, "print_test_statement")

# Called every frame. 'arg_delta' is the elapsed time since the previous frame.
#func _process(arg_delta):
#	GlobalDebug.update_debug_overlay("key_example", arg_delta)


##############################################################################

# public methods


func print_test_statement():
	print("this is the testenvRoot_global_debug test print statement")


##############################################################################

# private methods


#func example_method():
#	pass


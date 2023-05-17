extends GameGlobal

#class_name GlobalLog

##############################################################################

enum LOG_CODES {UNDEFINED, ERROR, WARNING, TRACE, INFO}

const USER_LOG_DIRECTORY = "/logs/gpf_logger"

# if in debug mode, errors will force a false assertion and stop the project
const DEBUGGER_ASSERTS_ERRORS := false

# if false warnings/errors will be logged in release versions
# if true warnings/errors will be pushed and printed
const WARNINGS_PRINT_TO_CONSOLE := true
const ERRORS_PRINT_TO_CONSOLE := true

# if you wish to globally disable a log type you can do so here
const ALLOW_ERROR := true
const ALLOW_INFO := true
const ALLOW_TRACE := true
const ALLOW_WARNING := true

# stored logs (see log_register) will be saved to disk on project close
var on_exit_log_to_disk := true

# if set true, all logs will be saved and remembered during the run session
# if set false logs will not be remembered (though they will still be
# output to console and consequently the user log files)
# logs made whilst this is set false cannot be recovered
var record_logs := true

# record of who logged what and when
# nothing is recorded if record_logs is set to false
var log_register = {}

# use to enable or disable log permissions on a per script basis
# call change_log_permissions to modify
# if an object isn't in log_permissions their permissions default to allowed
var log_permissions = {}

onready var coderef = ErrorCodes.new()

##############################################################################


class LogRecord:
	var owner: Object
	var timestamp: int
	var log_code_id: int
	var log_code_name: String
	var log_message: String
	var logged_to_console: bool = false
	var saved_to_disk: bool = false
	var full_log_string: String
	
	func _init(
			arg_owner: Object,
			arg_log_timestamp: int,
			arg_log_code_id: int,
			arg_log_code_name: String,
			arg_log_message: String,
			arg_log_string: String
			):
		self.owner = arg_owner
		self.timestamp = arg_log_timestamp
		self.log_code_id = arg_log_code_id
		self.log_code_name = arg_log_code_name
		self.log_message = arg_log_message
		self.full_log_string = arg_log_string


##############################################################################

# virtual methods


# Called when the node enters the scene tree for the first time.
func _ready():
	# logger prevents automatic quit on notification
	get_tree().set_auto_accept_quit(false)
	# logger is always allowed to log about self
	# (parent gameGlobal class, for ddat-gpf singletons, disables by default)
	change_log_permissions(self, true)
	_logger_startup()
#	GlobalLog.trace(self, "test log")


# hijack the exit process to force save logs to disk on quit
# to quit, use: get_tree().notification(MainLoop.NOTIFICATION_WM_QUIT_REQUEST)
# get_tree().quit() will skip this behaviour
func _notification(what):
	if what == MainLoop.NOTIFICATION_WM_QUIT_REQUEST:
		if on_exit_log_to_disk:
			_save_all_logs_to_disk()
		get_tree().quit()


##############################################################################

# public methods


# method allows blocking specific scripts from making log calls
# (useful for scripts whose debugging logs spam the console)
# [param]
# arg_caller should be the object you wish to allow or disallow logging from
# arg_permission is whether to allow (if true) or disallow (if false)
func change_log_permissions(arg_caller: Object, arg_permission: bool):
	log_permissions[arg_caller] = arg_permission


# see _log for parameter explanation
func error(arg_caller: Object, arg_error_message):
	_log(arg_caller, arg_error_message, 1)


# see _log for parameter explanation
func info(arg_caller: Object, arg_error_message):
	_log(arg_caller, arg_error_message, 4)


# see _log for parameter explanation
func trace(arg_caller: Object, arg_error_message):
	_log(arg_caller, arg_error_message, 3)


# arguments as _log but accepts caller but does not accept error_message
# does nothing if not in a debug build
func log_stack_trace(arg_caller: Object):
	if OS.is_debug_build():
		var full_stack_trace = get_stack()
		var error_stack_trace = full_stack_trace[1]
		var error_func_id = error_stack_trace["function"]
		var error_node_id = error_stack_trace["source"]
		var error_line_id = error_stack_trace["line"]
		var stack_trace_print_string =\
				"\nStack Trace: [{f}] [{s}] [{l}]".format({\
					"f": error_func_id,
					"s": error_node_id,
					"l": error_line_id})
		GlobalLog.trace(arg_caller, stack_trace_print_string)


# see _log for parameter explanation
func warning(arg_caller: Object, arg_error_message):
	_log(arg_caller, arg_error_message, 2)


##############################################################################

# private methods


# get whether an object is allowed to make logging calls
# see 'change_log_permissions' method
# if an object isn't in log_permissions their permissions default to allowed
func _is_caller_permitted(arg_log_caller: Object) -> bool:
	var permission_state
	if arg_log_caller in log_permissions.keys():
		permission_state = log_permissions[arg_log_caller]
		if typeof(permission_state) == TYPE_BOOL:
			return permission_state
	# catchall
	return true


# method to check log is allowed (by ALLOW_ consts) before it goes ahead
# if passed an invalid log code (i.e. not in the enum), will return false
# if passed 'LOG_CODES.UNDEFINED' will return true
func _is_log_type_allowed(arg_log_code: int = 0) -> bool:
	match arg_log_code:
		LOG_CODES.UNDEFINED:
			return true
		LOG_CODES.ERROR:
			return ALLOW_ERROR
		LOG_CODES.INFO:
			return ALLOW_INFO
		LOG_CODES.TRACE:
			return ALLOW_TRACE
		LOG_CODES.WARNING:
			return ALLOW_WARNING
	# anything not in LOG_CODES enum will reach here
	return false


# main logging method
# prints to console or pushes a warning/error
# [param]
# #1, arg_caller - identifier for method caller, pass as self
#		will return self.name if name can be found
# #2, arg_error_message - ERR message
#		this can be a custom string, a value you want printed, an ERR
#		constant from globalScope or a key from the ErrorCodes class
# #3, arg_log_code - passed from the public logging methods
#		refers to the type of log (i.e. ERROR, WARNINGING, TRACE, or INFO),
#		and influences whether is printed or pushed
func _log(
		arg_caller: Object,
		arg_error_message,
		arg_log_code: int = 0
		):
	var caller_id: String = str(arg_caller)
#	if "name" in arg_caller:
#		caller_id += ": "+arg_caller.name
	
	var full_error_message: String
	if coderef.is_key(arg_error_message):
		full_error_message = coderef.get_error_string(arg_error_message)
	else:
		full_error_message = str(arg_error_message)
	
	var log_code_id: int =\
			arg_log_code if arg_log_code in LOG_CODES.values() else 0
	var log_code_name: String = str(LOG_CODES.keys()[log_code_id])
	
	var log_timestamp = Time.get_ticks_msec()
	
	var full_log_string =\
			"[t{time}] {caller}\t[{type}] | {message}".format({
				"type": log_code_name,
				"time": log_timestamp,
				"caller": str(caller_id),
				"message": str(full_error_message)
				})
	
	# if recording all logs, create an object to remember it
	# logs are recorded whether they log to debugger/console or not
	var log_record: LogRecord = null
	if record_logs:
		log_record = LogRecord.new(arg_caller, log_timestamp, log_code_id,
				log_code_name, full_error_message, full_log_string)
		_update_log_register(arg_caller, log_record)
	
	# check the log type is valid (see ALLOW_ consts/_is_log_type_allowed
	# method and log_permission dict)
	if not _is_log_type_allowed(arg_log_code):
		return
	if not _is_caller_permitted(arg_caller):
		return
	
	if arg_log_code == LOG_CODES.ERROR:
		push_error(full_log_string)
		# are all errors reason to stop project in debug mode?
		if DEBUGGER_ASSERTS_ERRORS and OS.is_debug_build():
			assert(2 == 3)
		if not ERRORS_PRINT_TO_CONSOLE:
			return
	
	elif arg_log_code == LOG_CODES.WARNING:
		push_warning(full_log_string)
		if not WARNINGS_PRINT_TO_CONSOLE:
			return
	
	# console output
	# only reachable by errors/warnings if print_to_console consts are set
	print(full_log_string)
	if log_record != null:
		log_record.logged_to_console = true


func _logger_startup():
	# get basic information on the user
	var user_datetime = OS.get_datetime()
	
	# convert the user datetime into something human-readable
	var user_date_as_string =\
			str(user_datetime["year"])+\
			"/"+str(user_datetime["month"])+\
			"/"+str(user_datetime["day"])
	# seperate into both date and time
	var user_time_as_string =\
			str(user_datetime["hour"])+\
			":"+str(user_datetime["minute"])+\
			":"+str(user_datetime["second"])
	
	var datetime_string = user_date_as_string+" "+user_time_as_string
	var user_model_name = OS.get_model_name()
	var user_name = OS.get_name()
	
	var startup_log_string = "\n"+\
			"Logger for {0} initialised at {1}".format([
				user_name+" "+user_model_name, datetime_string
			])
	GlobalLog.info(self, startup_log_string)


func _save_all_logs_to_disk():
	var log_directory_name =\
			Time.get_datetime_string_from_system(false, false).\
			replace("T", "_").replace("-", "_").replace(":", "_")
	var base_dir = GlobalData.get_dirpath_user()+"/"+USER_LOG_DIRECTORY
	var target_directory = base_dir+"/"+log_directory_name
	var log_string = ""
	var get_log_list := []
	for log_owner in log_register.keys():
		log_string = ""
		get_log_list = []
		get_log_list = log_register[log_owner]
		# log_register values are arrays of logRecords (key = log caller)
		if typeof(get_log_list) == TYPE_ARRAY:
			for log_item in get_log_list:
				if log_item is LogRecord:
					if not log_item.saved_to_disk\
					and log_item.logged_to_console:
						log_string += str(log_item.full_log_string)
						log_string += "\n"
						log_item.saved_to_disk = true
		_save_logstring_to_disk(target_directory, str(log_owner), log_string)


#//TODO move this save text function to globalData
func _save_logstring_to_disk(
			arg_target_directory: String,
			arg_log_caller: String,
			arg_logstring: String):
	# force write logging directory if doesn't exist
	if not GlobalData.validate_directory(arg_target_directory):
		if GlobalData.create_directory(arg_target_directory, true) != OK:
			GlobalLog.error(self, "could not create logging directory")
			return
	#
	var file_name = (str(arg_log_caller)+".txt")
	if not file_name.is_valid_filename():
		file_name = GlobalData.clean_file_name(file_name)
	
	if file_name.is_valid_filename():
		var full_file_path = str(arg_target_directory+"/"+file_name).to_lower()
		var newfile = File.new()
		newfile.open(full_file_path, File.WRITE)
		newfile.store_string(arg_logstring)
		newfile.close()
	else:
		GlobalLog.warning(self, "name '"+str(file_name)+"' invalid")


func _update_log_register(arg_caller: Object, arg_log_record: LogRecord):
	var caller_record
	if arg_caller in log_register.keys():
		caller_record = log_register[arg_caller]
		if typeof(caller_record) == TYPE_ARRAY:
			caller_record.append(arg_log_record)
		else:
			warning(self, "log_register entry for {e} != array".format({
					"e": arg_caller}))
	else:
		log_register[arg_caller] = [arg_log_record]


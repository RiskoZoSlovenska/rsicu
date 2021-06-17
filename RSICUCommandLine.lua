--[[--
	@script RSICUCommandLine
	@author RiskoZoSlovenska
	@date Jan 2021
	@license MIT

	(idk)

	A command-line REPL interface for the RSICU library.
]]

local rsicu = require("rsicu")
local vips = require("vips")
local Image = vips.Image

-- idk how to do this lol
local table = table
local string = string
local ipairs = ipairs
local pcall = pcall
local write, read = io.write, io.read
local writef = function(...) write(string.format(...)) end --- Shortcut for io.write(string.format())

local WELCOME
do
	local TITLE = "Welcome to RZS's Simple Image Cleaner Command Line v4!\n"
	WELCOME = TITLE .. string.rep("-", #TITLE - 1) .. "\n" -- Make the line as long as the title
end

local IMAGE_PROMPT = "\nInput the directory of the image which you want to process: "
local IMAGE_FAILED_ERROR = "Image %q cannot be found or opened (%s), please try again:"

local OPERATIONS_INFO = rsicu.getAvailableOperations()
local OPERATIONS_PROMPT
do -- Concat all the available operations into one string
	local operationsListString = ""
	for _, operation in ipairs(OPERATIONS_INFO) do
		operationsListString = operationsListString .. string.format(
			"\t%q (%s)\n",
			operation.key,
			operation.name
		)
	end

	OPERATIONS_PROMPT = string.format("\nInput the desired operations, space-separated, in order. Options are:\n%s", operationsListString)
end
local INVALID_OPERATION_ERROR = "Invalid operation %q, please try again: "

local NUM_PROMPT_TEMPLATE = "\nInput %s: %s (%s to %s inclusive, %s): "
local INVALID_NUM_ERROR = "Invalid number %q, please try again: "

local SAVING_NOTIFICATION = "\nSaving image as: %q"
local SAVE_SUCCESS_NOTIFICATION = "\nImage saved successfully.\n"
local BAD_FILENAME_ERROR = "Bad filename %q"
local SAVE_ERROR_TEMPLATE = "!!! Error writing image to file: %s"

local CONTINUE_PROMPT = "\nPress Enter to repeat the operation"



--[[--
	Repeatedly prompts the user to input a list of operation keys until a valid one is provided.

	@return string[] a list of keys of operations to be performed upon an image
]]
local function loadOperationKeys()
	write(OPERATIONS_PROMPT)

	while true do
		local input = read("*l")

		local operationKeys = {}
		for key in string.gmatch(input, "%w+") do
			table.insert(operationKeys, key)
		end

		local isValid, invalidKey = rsicu.checkOperationKeys(operationKeys)
		if isValid then
			return operationKeys
		else
			writef(INVALID_OPERATION_ERROR, invalidKey)
		end
	end
end


--[[--
	Repeatedly prompts the user to input a number, until a valid one (on that is within provided specifications) is provided.

	@param string operationName the name of the operation which this arg is for
	@param table paramInfo a table with desc, range and isInt fields which constrain the arg
]]
local function loadNumber(operationName, paramInfo)
	writef(
		NUM_PROMPT_TEMPLATE,
		operationName, paramInfo.desc, paramInfo.range[1], paramInfo.range[2], paramInfo.isInt and "integer" or "number"
	)

	while true do
		local input = read("*l")

		local value = tonumber(input)
		if rsicu.checkArg(value, paramInfo) then
			return value
		else
			writef(INVALID_NUM_ERROR, tostring(input))
		end
	end
end

--[[--
	Performs several @{loadNumber} prompts to load all the required operation arguments, in order.

	@param string[] operationKeys the list of keys of all the operations to be performed on the image
	@return number[][] a 2D array of arguments, with indexes correspnding to the operation's position
		in the input array
]]
local function loadOperationArgs(operationKeys)
	local allArgs = {}

	for _, key in ipairs(operationKeys) do
		local operationInfo = OPERATIONS_INFO[key]
		local operationArgs = {}

		for _, paramInfo in ipairs(operationInfo.params) do
			table.insert(operationArgs, loadNumber(operationInfo.name, paramInfo))
		end

		table.insert(allArgs, operationArgs)
	end

	return allArgs
end


--[[--
	Repeatedly prompts the user for an image filename, until a valid one is provided.

	@return Image an sRGB interpretation of the loaded image
]]
local function loadImage()
	write(IMAGE_PROMPT)

	while true do
		local filename = read("*l")

		local success, res = pcall(Image.new_from_file, filename)
		if success then
			return res:colourspace("srgb"), filename
		else
			local loadErrMsg = res:match(".+:%s*(.-)%s*$") or res
			writef(IMAGE_FAILED_ERROR, tostring(filename), loadErrMsg)
		end
	end
end

--[[--
	Saves the image to the same directory under a new file name in the format
	"root tag.ext", where "root.ext" is the original file name and tag is a 
	string returned by rsicu.getOperationsTag.

	@param Image image the image to save
	@param string filename the file's original file name
	@param string[] the list of keys of all the operations performed on the image
	@param number[][] the list of arguments used to perform the operations on the image
]]
local function saveImage(image, filename, operationKeys, operationsArgs)
	local root, ext = filename:match("(.+)(%..-)$")
	if not root then
		writef(BAD_FILENAME_ERROR, tostring(filename))
		return
	end

	local newFilename = root .. " " .. rsicu.getOperationsTag(operationKeys, operationsArgs) .. ext

	writef(SAVING_NOTIFICATION, newFilename)

	local success, err = pcall(image.write_to_file, image, newFilename)
	if not success then
		writef(SAVE_ERROR_TEMPLATE, err)
	else
		write(SAVE_SUCCESS_NOTIFICATION)
	end
end


--[[--
	Main program.
]]
local function main()
	write(WELCOME)

	local rawImage, filename = loadImage()
	local operationKeys = loadOperationKeys()
	local numOfParams = rsicu.countParams(operationKeys)

	while true do
		local operationArgs = loadOperationArgs(operationKeys)

		local processedImage = rsicu.processImage(rawImage, operationKeys, operationArgs)
		saveImage(processedImage, filename, operationKeys, operationArgs)

		-- Discard this image and gc it so it can be opened by other programs
		--processedImage:remove() -- This could possibly do it, but calling it ends the program (idk why)
		processedImage = nil
		collectgarbage()
		collectgarbage()

		-- If no args were needed, pause so we don't perform the operation over and over
		if numOfParams < 1 then
			write(CONTINUE_PROMPT)
			read() -- Wait for enter
		end
	end
end

main()
--[[--
	@module RSICU
	@author RiskoZoSlovenska
	@date Jan 2021
	(idk, am I supposed to put the @license field here too??)

	An extremely basic image processing "library".
]]

local vips = require("vips")
local Image = vips.Image

-- lol what is this ;-;
local string = string
local table = table
local math = math
local pairs, ipairs = pairs, ipairs
local pcall = pcall
local unpack = unpack

local OPERATIONS = {}
do
	local STANDARD_COLOUR_INTERVAL = {0, 255}
	local GENERIC_BRIGHTNESS_ARG_DESC_TEMPLATE = "brightness %s which pixels will be %s"

	local numOfOperations = 0


	--[[--
		Creates a new Operation container.

		@param string key
		@param string name
		@param function func the operation function
		@param ParamInfo... any parameter objects the function takes

		@return Operation
	]]
	local function buildOperation(key, name, func, ...)
		local operationTable = { -- Create the container
			id = numOfOperations,
			key = key,
			name = name,
			func = func,
			params = {...},
		}

		OPERATIONS[key] = operationTable
		numOfOperations = numOfOperations + 1
	end

	--[[--
		Creates a new ParamInfo container.

		@param string desc this parameter's description
		@param[opt=STANDARD_COLOUR_INTERVAL] number[] a 2-element array which denotes the param's range (inclusive)
		@param[opt=false] booleas determines whether arguments passed to this param have to be integers

		@return ParamInfo
	]]
	local function buildParam(desc, range, isDecimal)
		return {
			desc = desc,
			range = range or STANDARD_COLOUR_INTERVAL,
			isInt = not isDecimal,
		}
	end

	--[[--
		Formats the GENERIC_BRIGHTNESS_ARG_DESC_TEMPLATE.

		@param string aboveOrBelow
		@param string whiteOrBlack
	]]
	local function buildParamDesc1(aboveOrBelow, whiteOrBlack)
		return string.format(GENERIC_BRIGHTNESS_ARG_DESC_TEMPLATE, aboveOrBelow, whiteOrBlack)
	end


	--[[--
		Returns a new image in which all pixels lighter than a certain value are solid white.
	]]
	local function whiteThresholdFunc(image, map, threshold)
		return map:more(threshold):ifthenelse({255, 255, 255}, image)
	end

	--[[--
		Returns a new image in which all pixels darker than a certain value are solid black.
	]]
	local function blackThresholdFunc(image, map, threshold)
		return map:less(threshold):ifthenelse({0, 0, 0}, image)
	end

	--[[--
		Returns a new image in which all pixels lighter/darker than a certain value are solid white/black.
	]]
	local function thresholdFunc(image, map, threshold)
		return map:more(threshold)
	end

	--[[--
		Returns a new image in which all pixels have been made darker/lighter.
	]]
	local function brightnessFunc(image, map, delta)
		return image + delta
	end

	--[[--
		Returns a new image in which all pixels lighter than a certain value are solid white
		and all pixels darker than a certain value are darkened.
	]]
	local function blackBoostLooseFunc(image, map, boostThreshold, whiteThreshold, boost)
		local whitened = whiteThresholdFunc(image, map, whiteThreshold)

		return map:less(boostThreshold):ifthenelse(image - boost, whitened)
	end

	--[[--
		Returns a new image in which all pixels lighter than a certain value are solid white
		and all pixel darker are darkened.
	]]
	local function blackBoostFunc(image, map, threshold, boost)
		return blackBoostLooseFunc(image, map, threshold, threshold, boost)
	end

	--[[--
		Returns a gray-scale version of the image.
	]]
	local function grayifyFunc(image, map)
		return image:bandmean()
	end


	buildOperation(
		"th", "Threshold",
		thresholdFunc,

		buildParam(
			buildParamDesc1("below/above", "turned black/white")
		)
	)
	buildOperation(
		"wt", "White Threshold",
		whiteThresholdFunc,

		buildParam(
			buildParamDesc1("above", "turned white")
		)
	)
	buildOperation(
		"bt", "Black Threshold",
		blackThresholdFunc,

		buildParam(
			buildParamDesc1("below", "turned black")
		)
	)

	buildOperation(
		"bb", "Black Boost",
		blackBoostFunc,

		buildParam(
			buildParamDesc1("below/above", "darkened/turned white")
		),
		buildParam(
			"amount by which dark pixels will be darkened",
			{0, 255}
		)
	)
	buildOperation(
		"bbl", "Black Boost Loose",
		blackBoostLooseFunc,

		buildParam(
			buildParamDesc1("below", "darkened")
		),
		buildParam(
			buildParamDesc1("above", "turned white")
		),
		buildParam(
			"amount by which dark pixels will be darkened",
			{0, 255}
		)
	)

	buildOperation(
		"br", "Brightness",
		brightnessFunc,

		buildParam(
			"amount by which to increase the brightness",
			{-255, 255}
		)
	)
	buildOperation(
		"gr", "Grayify",
		grayifyFunc
	)
end



--[[--
	Runs an image through multiple operations.

	@param Image image the image to operate on. This should be an sRGB 1-4 band image
	@param string[] a list of keys of operations to perform
	@param number[][] a list of arguments for the operations to be made

	@return Image
	@throws Error while processing image, usually caused by faulty arguments
]]
local function processImage(image, operationKeys, operationsArgs)
	local noAlpha, alpha
	if image:bands() == 3 or image:bands() == 1 then -- No alpha band
		alpha = 255
		noAlpha = image
	else
		local bands = image:bandsplit()
		alpha = table.remove(bands) -- Extract the alpha band
		noAlpha = Image.bandjoin(bands)
	end
	local brightnessMap = image:flatten({background = 255}):bandmean() -- Get a brightness map


	-- Actually start making the operations now
	for index, key in ipairs(operationKeys) do
		local operation = OPERATIONS[key]
		local operationArgs = operationsArgs[index]

		local success, res = pcall(operation.func, noAlpha, brightnessMap, unpack(operationArgs))
		if not success then
			error(string.format(
				"Error while processing image (%s), check your arguments",
				res
			), 2)
		else
			noAlpha = res
		end
	end

	return noAlpha:bandjoin(alpha) -- Add the alpha band back in
end



--[[--
	Deepcopies an array/dictionary.

	@param table tbl
	@return table
]]
local function copyTable(tbl)
	local copy = {}

	for key, value in pairs(tbl) do
		copy[key] = type(value) == "table" and copyTable(value) or value
	end

	return copy
end

--[[--
	@return table an array of containers holding data about specific Operations. Each element is present twice,
		indexed under both a string key and a numerical index. Each element is a table of similar to the Operation
		container in structure, but the only fields present are `key`, `name` and `params`, where `params` is a
		ParamInfo container.
]]
local function getAvailableOperations()
	local availableOperations = {}

	for _, operation in pairs(OPERATIONS) do
		local operationInfo = { -- Create a sort of copy
			key = operation.key,
			name = operation.name,
			params = copyTable(operation.params)
		}

		availableOperations[operation.id + 1] = operationInfo
		availableOperations[operation.key] = operationInfo
	end

	return availableOperations
end

--[[--
	Checks whether a set of Operation keys are valid.
	Utility function.

	@param string[] the list of keys

	@return boolean whether they are valid
	@return string|nil the first invalid key, if there is one
]]
local function checkOperationKeys(keys)
	for _, key in ipairs(keys) do
		if not OPERATIONS[key] then
			return false, key
		end
	end

	return true, nil
end

--[[--
	Counts the number of arguments required for a set of Operations.
	Utility function.

	@param string[] a list of keys of Operations
	@return int the number of required arguments
]]
local function countParams(operationKeys)
	local totalParams = 0

	for _, key in ipairs(operationKeys) do
		local operation = assert(OPERATIONS[key], "Invalid operation key " .. tostring(key))
		totalParams = totalParams + #operation.params
	end

	return totalParams
end


--[[--
	Checks whether a number is valid according to a ParamInfo container.

	@param number num the number to check
	@param ParamInfo paramInfo

	@return boolean whether the number satisfies the ParamInfo
]]
local function checkArg(num, paramInfo)
	return (
		(num)
		and
		(num >= paramInfo.range[1] and num <= paramInfo.range[2])
		and
		(not paramInfo.isInt or math.floor(num) == num)
	)
end
assert(checkArg(128, {isInt = true, range = {0, 255}}))
assert(not checkArg(276, {isInt = true, range = {0, 255}}))
assert(not checkArg(128.6, {isInt = true, range = {0, 255}}))
assert(checkArg(128.6, {isInt = false, range = {0, 255}}))


--[[--
	Creates a short string that describes a set of operations.
	Utility function.

	@param string[] the keys of Operations that were performed
	@param number[][] the args the Operations were performed with
	@param[opt='_'] a string used to join all the individual tag components

	@return string the tag
]]
local function getOperationsTag(operationKeys, operationsArgs, joiner)
	local tagComponents = {}

	for index, operationKey in ipairs(operationKeys) do
		table.insert(tagComponents, string.upper(operationKey)) -- First insert the id

		for _, arg in ipairs(operationsArgs[index]) do
			table.insert(tagComponents, tostring(arg)) -- and then each number
		end
	end

	return table.concat(tagComponents, joiner or '_')
end



return {
	processImage = processImage,

	getAvailableOperations = getAvailableOperations,
	checkOperationKeys = checkOperationKeys,
	countParams = countParams,

	checkArg = checkArg,

	getOperationsTag = getOperationsTag,
}
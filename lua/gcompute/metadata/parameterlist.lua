local self = {}
GCompute.ParameterList = GCompute.MakeConstructor (self)

function self:ctor (parameters)
	self.ParameterCount = 0
	self.ParameterTypes = {}
	self.ParameterNames = {}
	self.ParameterDocumentation = {}
	
	self.VarArgs = false
	
	if parameters then
		for _, parameter in ipairs (parameters) do
			self:AddParameter (parameter [1], parameter [2])
		end
	end
end

--- Adds a parameter to the list
-- @param parameterType The type of the parameter, as a string or TypeReference
-- @param parameterName (Optional) The name of the parameter
-- @return The id of the newly added parameter
function self:AddParameter (parameterType, parameterName)
	if self.VarArgs then
		GCompute.Error ("ParameterList:AddParameter : Parameter list has already been terminated by a varargs parameter.")
		return
	end

	self.ParameterCount = self.ParameterCount + 1
	self:SetParameterType (self.ParameterCount, parameterType)
	self.ParameterNames [self.ParameterCount] = parameterName
	
	if parameterName == "..." then self.VarArgs = true end
	
	return self.ParameterCount
end

--- Adds parameters from a ParameterList to the list
-- @param parameterList The ParameterList from which to take parameters
function self:AddParameters (parameterList)
	for i = 1, parameterList:GetParameterCount () do
		self:AddParameter (parameterList:GetParameterType (i), parameterList:GetParameterName (i))
		self:SetParameterDocumentation (i, parameterList:GetParameterDocumentation (i))
	end
end

function self:ComputeMemoryUsage (memoryUsageReport, poolName)
	memoryUsageReport = memoryUsageReport or GCompute.MemoryUsageReport ()
	if memoryUsageReport:IsCounted (self) then return end
	
	memoryUsageReport:CreditTableStructure (poolName, self)
	
	for i = 1, self:GetParameterCount () do
		memoryUsageReport:CreditString (poolName, self:GetParameterName (i))
		memoryUsageReport:CreditString (poolName, self:GetParameterDocumentation (i))
		if self:GetParameterType (i) then
			self:GetParameterType (i):ComputeMemoryUsage (memoryUsageReport, poolName)
		end
	end
	
	return memoryUsageReport
end

--- Returns an iterator function for this parameter list
-- @return An iterator function for this parameter list
function self:GetEnumerator ()
	local i = 0
	return function ()
		i = i + 1
		return self.ParameterTypes [i], self.ParameterNames [i]
	end
end

--- Gets the number of parameters in this parameter list
-- @return The number of parameters in this parameter list
function self:GetParameterCount ()
	return self.ParameterCount
end

--- Gets the documentation string for the given parameter
-- @param parameterId The id of the parameter
-- @return The documentation string for the parameter
function self:GetParameterDocumentation (parameterId)
	return self.ParameterDocumentation [parameterId]
end

--- Gets the name of the given parameter
-- @param parameterId The id of the parameter
-- @return The name of the parameter or nil if it is unnamed
function self:GetParameterName (parameterId)
	return self.ParameterNames [parameterId]
end

--- Gets the type of the given parameter
-- @param parameterId The id of the parameter
-- @return The type of the parameter as a DeferredObjectResolution or Type or nil if unknown
function self:GetParameterType (parameterId)
	return self.ParameterTypes [parameterId]
end

--- Returns a boolean indicating whether this parameter list is empty
-- @return A boolean indicating whether this parameter list is empty
function self:IsEmpty ()
	return self.ParameterCount == 0
end

function self:IsVarArgs ()
	return self.VarArgs
end

--- Returns a boolean indicating whether this parameter list can match the given argument count
-- @param argumentCount The argument count to be matched against
-- @return A boolean indicating whether this parameter list can match the given argument count
function self:MatchesArgumentCount (argumentCount)
	if not self.VarArgs then return self:GetParameterCount () == argumentCount end
	
	return argumentCount >= self:GetParameterCount () - 1
end

--- Resolves the types of all parameters in this parameter list
function self:ResolveTypes (globalNamespace, localNamespace, errorReporter)
	errorReporter = errorReporter or GCompute.DefaultErrorReporter
	
	for i = 1, #self.ParameterTypes do
		if self.ParameterTypes [i]:IsDeferredObjectResolution () then
			self.ParameterTypes [i]:SetGlobalNamespace (globalNamespace)
			self.ParameterTypes [i]:SetLocalNamespace (localNamespace)
			self.ParameterTypes [i]:Resolve ()
			if self.ParameterTypes [i]:IsFailedResolution () then
				self.ParameterTypes [i]:GetAST ():GetMessages ():PipeToErrorReporter (errorReporter)
			else
				self.ParameterTypes [i] = self.ParameterTypes [i]:GetObject ()
			end
		end
	end
end

--- Sets the documentation string for the given parameter
-- @param parameterId The id of the parameter
-- @param documentation The documentation string for the parameter
function self:SetParameterDocumentation (parameterId, documentation)
	self.ParameterDocumentation [parameterId] = documentation
end

--- Sets the name of the given parameter
-- @param parameterId The id of the parameter
-- @param parameterName The new name of the parameter
function self:SetParameterName (parameterId, parameterName)
	self.ParameterNames [parameterId] = parameterName
end

--- Sets the type of the given parameter
-- @param parameterId The id of the parameter
-- @param parameterType The new type of the parameter as a string, DeferredObjectResolution or Type
function self:SetParameterType (parameterId, parameterType)
	if type (parameterType) == "string" then
		parameterType = GCompute.DeferredObjectResolution (parameterType, GCompute.ResolutionObjectType.Type)
	elseif parameterType and
	       not parameterType:IsDeferredObjectResolution () and
	       not parameterType:UnwrapAlias ():IsType () then
		GCompute.Error ("ParameterList:SetParameterType : parameterType must be a string, DeferredObjectResolution or Type")
	end
	self.ParameterTypes [parameterId] = parameterType
end

--- Returns a string representation of this parameter list
-- @return A string representation of this parameter list
function self:ToString ()
	local parameterList = ""
	for i = 1, self:GetParameterCount () do
		if parameterList ~= "" then
			parameterList = parameterList .. ", "
		end
		local parameterType = self:GetParameterType (i)
		local parameterName = self:GetParameterName (i)
		parameterType = parameterType and parameterType:GetFullName () or "[Unknown Type]"
		parameterList = parameterList .. parameterType
		if parameterName then
			parameterList = parameterList .. " " .. parameterName
		end
	end
	return "(" .. parameterList .. ")"
end

--- Checks for ParameterList type equality. Both ParameterLists must have all their parameter types pre-resolved.
function self:TypeEquals (otherParameterList)
	if self:GetParameterCount () ~= otherParameterList:GetParameterCount () then return false end
	if self:IsVarArgs () ~= otherParameterList:IsVarArgs () then return false end
	for i = 1, self:GetParameterCount () do
		if not self:GetParameterType (i):UnwrapAlias ():Equals (otherParameterList:GetParameterType (i)) then return false end
	end
	
	return true
end
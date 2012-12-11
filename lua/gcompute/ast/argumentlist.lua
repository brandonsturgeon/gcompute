local self = {}
self.__Type = "ArgumentList"
GCompute.AST.ArgumentList = GCompute.AST.MakeConstructor (self)

function self:ctor ()
	self.ArgumentCount = 0
	self.Arguments = {}
end

function self:AddArgument (expression)
	self.ArgumentCount = self.ArgumentCount + 1
	self:SetArgument (self.ArgumentCount, expression)
end

function self:AddArguments (arguments)
	for _, argument in ipairs (arguments) do
		self:AddArgument (argument)
	end
end

function self:ComputeMemoryUsage (memoryUsageReport)
	memoryUsageReport = memoryUsageReport or GCompute.MemoryUsageReport ()
	if memoryUsageReport:IsCounted (self) then return end
	
	memoryUsageReport:CreditTableStructure ("Syntax Trees", self)
	
	for i = 1, self:GetArgumentCount () do
		if self:GetArgument (i) then
			self:GetArgument (i):ComputeMemoryUsage (memoryUsageReport, "Syntax Trees")
		end
	end
	
	return memoryUsageReport
end

function self:ExecuteAsAST (astRunner, state)
	-- State 0+: Evaluate arguments
	if state + 1 <= self:GetArgumentCount () then
		astRunner:PushState (state + 1)
		
		-- Expresssion, state 0
		astRunner:PushNode (self:GetArgument (state + 1))
		astRunner:PushState (0)
	else
		-- Discard ArgumentList
		astRunner:PopNode ()
	end
end

function self:GetArgument (argumentId)
	return self.Arguments [argumentId]
end

function self:GetArgumentCount ()
	return self.ArgumentCount
end

function self:GetArgumentTypes ()
	local argumentTypes = {}
	for i = 1, self.ArgumentCount do
		argumentTypes [#argumentTypes + 1] = self.Arguments [i]:GetType ()
	end
	return argumentTypes
end

function self:GetChildEnumerator ()
	local i = 0
	return function ()
		i = i + 1
		while not self.Arguments [i] do
			if i >= self.ArgumentCount then break end
			i = i + 1
		end
		return self.Arguments [i]
	end
end

--- Returns an iterator function for this argument list
-- @return An iterator function for this argument list
function self:GetEnumerator ()
	local i = 0
	return function ()
		i = i + 1
		return self.Arguments [i]
	end
end

function self:IsEmpty ()
	return self.ArgumentCount == 0
end

function self:SetArgument (argumentId, expression)
	self.Arguments [argumentId] = expression
	if expression then expression:SetParent (self) end
end

function self:ToString ()
	local parameterList = ""
	for i = 1, self.ArgumentCount do
		if parameterList ~= "" then
			parameterList = parameterList .. ", "
		end
		parameterList = parameterList .. (self.Arguments [i] and self.Arguments [i]:ToString () or "[Nothing]")
	end
	return "(" .. parameterList .. ")"
end

function self:Visit (astVisitor, ...)
	for i = 1, self:GetArgumentCount () do
		local argument = self:GetArgument (i)
		if argument then
			self:SetArgument (i, argument:Visit (astVisitor, ...) or argument)
		end
	end
	
	local astOverride = astVisitor:VisitArgumentList (self, ...)
	if astOverride then return astOverride:Visit (astVisitor, ...) or astOverride end
end

GCompute.AST.EmptyArgumentList = GCompute.AST.ArgumentList ()
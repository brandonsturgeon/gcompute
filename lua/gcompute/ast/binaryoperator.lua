local self = {}
self.__Type = "BinaryOperator"
GCompute.AST.BinaryOperator = GCompute.AST.MakeConstructor (self, GCompute.AST.Expression)

local EvaluationFunctions = 
{
	["default"] = function (self, executionContext, left) executionContext:Error ("Unknown binary operator " .. self.Operator .. " in " .. self:ToString () .. ".") return left end,
	["+"] = function (self, executionContext, left, right) if type (left) == "string" then return left .. tostring (right) end return left + right end,
	["-"] = function (self, executionContext, left, right) return left - right end,
	["*"] = function (self, executionContext, left, right) return left * right end,
	["/"] = function (self, executionContext, left, right) return left / right end,
	["="] = function (self, executionContext, left, right) return right end,
	["<"] = function (self, executionContext, left, right) return left < right end,
	[">"] = function (self, executionContext, left, right) return left > right end,
	["<="] = function (self, executionContext, left, right) return left <= right end,
	[">="] = function (self, executionContext, left, right) return left >= right end,
	["=="] = function (self, executionContext, left, right) return left == right end
}

function self:ctor ()
	self.LeftExpression = nil
	self.RightExpression = nil
	
	self.Operator = "[Unknown Operator]"
	self.Precedence = 0
	
	self.EvaluationFunction = EvaluationFunctions.default
end

function self:ComputeMemoryUsage (memoryUsageReport)
	memoryUsageReport = memoryUsageReport or GCompute.MemoryUsageReport ()
	if memoryUsageReport:IsCounted (self) then return end
	
	memoryUsageReport:CreditTableStructure ("Syntax Trees", self)
	if self.LeftExpression then
		self.LeftExpression:ComputeMemoryUsage (memoryUsageReport)
	end
	if self.RightExpression then
		self.RightExpression:ComputeMemoryUsage (memoryUsageReport)
	end
	memoryUsageReport:CreditString ("Syntax Trees", self.Operator)
	return memoryUsageReport
end

function self:Evaluate (executionContext)
	local left, leftReference = self.LeftExpression:Evaluate (executionContext)
	local right, rightReference = self.RightExpression:Evaluate (executionContext)
	
	if left == nil then
		if not leftReference then
			executionContext:Error ("Failed to evaluate " .. self.LeftExpression:ToString () .. " in " .. self:ToString () .. ".")
		else
			executionContext:Error (self.LeftExpression:ToString () .. " is nil in " .. self:ToString () .. ".")
		end
	end
	if right == nil then
		if not rightReference then
			executionContext:Error ("Failed to evaluate " .. self.RightExpression:ToString () .. " in " .. self:ToString () .. ".")
		else
			executionContext:Error (self.RightExpression:ToString () .. " is nil in " .. self:ToString () .. ".")
		end
	end
	
	if left == nil or right == nil then
		return "[error]"
	end
	
	return self:EvaluationFunction (executionContext, left, right, leftReference, rightReference)
end

function self:ExecuteAsAST (astRunner, state)
	-- State 0: Evaluate left
	-- State 1: Evaluate right
	-- State 2: Call
	if state == 0 then
		-- Return to state 1
		astRunner:PushState (1)
	
		-- Expression, state 0
		astRunner:PushNode (self:GetLeftExpression ())
		astRunner:PushState (0)
	elseif state == 1 then
		-- Return to state 2
		astRunner:PushState (2)
	
		-- Expression, state 0
		astRunner:PushNode (self:GetRightExpression ())
		astRunner:PushState (0)
	elseif state == 2 then
		-- Discard BinaryOperator
		astRunner:PopNode ()
		
		local arguments = {}
		local right = astRunner:PopValue ()
		local left = astRunner:PopValue ()
		
		local functionCallPlan = self.FunctionCallPlan
		local functionDefinition = functionCallPlan:GetFunctionDefinition ()
		local func = functionCallPlan:GetFunction ()
		if not func and functionDefinition then
			func = functionDefinition:GetNativeFunction ()
		end
		
		if func then
			astRunner:PushValue (func (left, right))
		elseif functionDefinition then
			local block = functionDefinition:GetBlock ()
			if block then
				astRunner:PushNode (functionDefinition:GetBlock ())
				astRunner:PushState (0)
			else
				ErrorNoHalt ("Failed to run " .. self:ToString () .. " (FunctionDefinition has no native function or AST block node)\n")
			end
		else
			ErrorNoHalt ("Failed to run " .. self:ToString () .. " (no function or FunctionDefinition)\n")
		end
	end
end

function self:GetLeftExpression ()
	return self.LeftExpression
end

function self:GetOperator ()
	return self.Operator
end

function self:GetRightExpression ()
	return self.RightExpression
end

function self:SetLeftExpression (leftExpression)
	self.LeftExpression = leftExpression
	if self.LeftExpression then self.LeftExpression:SetParent (self) end
end

function self:SetRightExpression (rightExpression)
	self.RightExpression = rightExpression
	if self.RightExpression then self.RightExpression:SetParent (self) end
end

function self:SetOperator (operator)
	self.Operator = operator
	
	self.EvaluationFunction = EvaluationFunctions [operator] or EvaluationFunctions.default
end

function self:ToString ()
	local leftExpression = "[Unknown Expression]"
	local rightExpression = "[Unknown Expression]"
	
	if self.LeftExpression then
		leftExpression = self.LeftExpression:ToString ()
		if self.LeftExpression.Is and self.LeftExpression:Is ("BinaryOperator") then
			leftExpression = "(" .. leftExpression .. ")"
		end
	end
	if self.RightExpression then
		rightExpression = self.RightExpression:ToString ()
		if self.RightExpression.Is and self.RightExpression:Is ("BinaryOperator") then
			rightExpression = "(" .. rightExpression  .. ")"
		end
	end
	
	return leftExpression .. " " .. self.Operator .. " " .. rightExpression
end

function self:Visit (astVisitor, ...)
	if self:GetLeftExpression () then
		self:SetLeftExpression (self:GetLeftExpression ():Visit (astVisitor, ...) or self:GetLeftExpression ())
	end
	if self:GetRightExpression () then
		self:SetRightExpression (self:GetRightExpression ():Visit (astVisitor, ...) or self:GetRightExpression ())
	end
	
	return astVisitor:VisitExpression (self, ...)
end
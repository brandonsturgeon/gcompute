local self = {}
GCompute.ResolutionResults = GCompute.MakeConstructor (self)

function self:ctor ()
	self.Results         = {}
	self.FilteredResults = {}
end

function self:AddResult (resolutionResult)
	if #self.Results >= 100 then
		GCompute.Error ("Too many resolution results!")
		return
	end
	self.Results [#self.Results + 1] = resolutionResult
	self.FilteredResults [#self.FilteredResults + 1] = resolutionResult
end

function self:Clear ()
	self.Results         = {}
	self.FilteredResults = {}
end

function self:ClearFilter ()
	self.FilteredResults = {}
	for i = 1, #self.Results do
		self.FilteredResults [i] = self.Results [i]
	end
end

function self:ComputeMemoryUsage (memoryUsageReport)
	memoryUsageReport = memoryUsageReport or GCompute.MemoryUsageReport ()
	if memoryUsageReport:IsCounted (self) then return end
	
	memoryUsageReport:CreditTableStructure ("Resolution Results", self)
	memoryUsageReport:CreditTableStructure ("Resolution Results", self.Results)
	return memoryUsageReport
end

function self:FilterByLocality ()
	local bestResult = nil
	local bestLocalDistance = math.huge
	for i = 1, #self.FilteredResults do
		if self.FilteredResults [i]:IsLocal () and self.FilteredResults [i]:GetLocalDistance () < bestLocalDistance then
			bestResult = self.FilteredResults [i]
			bestLocalDistance = self.FilteredResults [i]:GetLocalDistance ()
		end
	end
	
	if bestResult then
		self.FilteredResults = { bestResult }
	end
end

function self:FilterByType (objectType)
	if objectType == GCompute.ResolutionObjectType.All then
	elseif objectType == GCompute.ResolutionObjectType.Namespace then
		self:FilterToNamespaces ()
	elseif objectType == GCompute.ResolutionObjectType.Container then
	elseif objectType == GCompute.ResolutionObjectType.Type then
		self:FilterToConcreteTypes ()
	elseif objectType == GCompute.ResolutionObjectType.ParametricType then
		self:FilterToParametricTypes ()
	end
end

--- Filters results down to concrete (non-parametric) types, whilst expanding OverloadedTypeDefinitions which are non-aliased or contain more than one TypeDefinition
function self:FilterToConcreteTypes ()
	local filteredResults = {}
	for i = 1, #self.FilteredResults do
		local isAlias = self.FilteredResults [i]:GetObject ():IsAlias ()
		local filteredObject = self.FilteredResults [i]:GetObject ():UnwrapAlias ()
		if filteredObject:IsType () then
			if filteredObject:GetTypeParameterList ():GetParameterCount () == 0 then
				filteredResults [#filteredResults + 1] = self.FilteredResults [i]
			end
		elseif filteredObject:IsOverloadedTypeDefinition () then
			if isAlias and filteredObject:GetTypeCount () == 1 then
				if filteredObject:GetType (1):GetTypeParameterList ():GetParameterCount () == 0 then
					filteredResults [#filteredResults + 1] = self.FilteredResults [i]
				end
			else
				for j = 1, filteredObject:GetTypeCount () do
					if filteredObject:GetType (j):GetTypeParameterList ():GetParameterCount () == 0 then
						local resolutionResult = GCompute.ResolutionResult (filteredObject:GetType (j), self.FilteredResults [i]:GetResultType ())
						resolutionResult:SetLocalDistance (self.FilteredResults [i]:GetLocalDistance ())
						filteredResults [#filteredResults + 1] = resolutionResult
					end
				end
			end
		end
	end
	self.FilteredResults = filteredResults
end

function self:FilterToNamespaces ()
	local filteredResults = {}
	for i = 1, #self.FilteredResults do
		local filteredObject = self.FilteredResults [i]:GetObject ():UnwrapAlias ()
		if filteredObject:IsNamespace () then
			filteredResults [#filteredResults + 1] = self.FilteredResults [i]
		end
	end
	self.FilteredResults = filteredResults
end

--- Filters results down to types and parametric types, whilst expanding OverloadedTypeDefinitions which are non-aliased or contain more than one TypeDefinition
function self:FilterToParametricTypes ()
	local filteredResults = {}
	for i = 1, #self.FilteredResults do
		local isAlias = self.FilteredResults [i]:GetObject ():IsAlias ()
		local filteredObject = self.FilteredResults [i]:GetObject ():UnwrapAlias ()
		if filteredObject:IsType () then
			filteredResults [#filteredResults + 1] = self.FilteredResults [i]
		elseif filteredObject:IsOverloadedTypeDefinition () then
			if isAlias and filteredObject:GetTypeCount () == 1 then
				filteredResults [#filteredResults + 1] = self.FilteredResults [i]
			else
				for j = 1, filteredObject:GetTypeCount () do
					local resolutionResult = GCompute.ResolutionResult (filteredObject:GetType (j), self.FilteredResults [i]:GetResultType ())
					resolutionResult:SetLocalDistance (self.FilteredResults [i]:GetLocalDistance ())
					filteredResults [#filteredResults + 1] = resolutionResult
				end
			end
		end
	end
	self.FilteredResults = filteredResults
end

function self:GetFilteredResult (index)
	return self.FilteredResults [index]
end

function self:GetFilteredResultCount ()
	return #self.FilteredResults
end

function self:GetFilteredResultObject (index)
	return self.FilteredResults [index] and self.FilteredResults [index]:GetObject () or nil
end

function self:GetResult (index)
	return self.Results [index]
end

function self:GetResultObject (index)
	return self.Results [index] and self.Results [index]:GetObject () or nil
end

function self:GetResultCount ()
	return #self.Results
end

function self:ToString ()
	local results = "[Resolution Results]"
	if #self.Results == 0 then
		results = results .. " { } { }"
		return results
	end
	
	results = results .. "\n{"
	for i = 1, #self.Results do
		results = results .. "\n    " .. self.Results [i]:ToString ():gsub ("\n", "\n    ")
	end
	results = results .. "\n}\n"
	
	if #self.FilteredResults == 0 then
		results = results .. "{ }"
		return results
	end
	
	results = results .. "{"
	for i = 1, #self.FilteredResults do
		results = results .. "\n    " .. self.FilteredResults [i]:ToString ():gsub ("\n", "\n    ")
	end
	results = results .. "\n}"
	
	return results
end
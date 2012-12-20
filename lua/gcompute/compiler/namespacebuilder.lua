local self = {}
GCompute.NamespaceBuilder = GCompute.MakeConstructor (self, GCompute.ASTVisitor)

--[[
	NamespaceBuilder
	
	1. Assigns a NamespaceDefinition to all Statements that should have one
		and adds member variables to them
	2. Assigns NamespaceDefinitions to FunctionDeclarations and AnonymousFunctions
		and adds function parameters to them
]]

function self:ctor (compilationUnit)
	self.CompilationUnit = compilationUnit
	self.AST = self.CompilationUnit:GetAbstractSyntaxTree ()
end

function self:VisitRoot (blockStatement)
	blockStatement:SetNamespace (blockStatement:GetNamespace () or GCompute.NamespaceDefinition ())
	blockStatement:GetNamespace ():SetConstructorAST (blockStatement)
	blockStatement:GetNamespace ():SetNamespaceType (GCompute.NamespaceType.Global)
end

function self:VisitBlock (blockStatement)
	blockStatement:SetNamespace (blockStatement:GetNamespace () or GCompute.NamespaceDefinition ())
	
	local namespace = blockStatement:GetNamespace ()
	namespace:SetDeclaringNamespace (blockStatement:GetParentNamespace ())
	namespace:SetDeclaringObject (blockStatement:GetParentNamespace ())
	namespace:SetConstructorAST (blockStatement)
	if namespace:GetNamespaceType () == GCompute.NamespaceType.Unknown then
		namespace:SetNamespaceType (GCompute.NamespaceType.Local)
	end
end

function self:VisitStatement (statement)
	if statement:HasNamespace () then
		if not statement:GetNamespace () and statement.SetNamespace then
			statement:SetNamespace (GCompute.NamespaceDefinition ())
		end
		if statement:GetNamespace () then
			statement:GetNamespace ():SetDeclaringNamespace (statement:GetParentNamespace ())
		end
	end
	
	if statement:Is ("FunctionDeclaration") then
		self:VisitFunction (statement)
	end
	
	if statement:Is ("RangeForLoop") then
		statement:GetNamespace ():SetNamespaceType (GCompute.NamespaceType.Local)
	end
	
	if statement:Is ("VariableDeclaration") then
		if not statement:GetType () then
			statement:SetType (GCompute.InferredType ())
		end
		
		local variableDefinition = statement:GetParentNamespace ():AddMemberVariable (statement:GetName (), statement:GetType ())
		statement:SetVariableDefinition (variableDefinition)
	end
end

function self:VisitExpression (expression)
	if expression:Is ("AnonymousFunction") then
		self:VisitFunction (expression)
	end
end

function self:VisitFunction (functionNode)
	local functionDefinition = nil
	
	local declaringObject = functionNode:GetParentNamespace ()
	while declaringObject:GetNamespace ():GetNamespaceType () ~= GCompute.NamespaceType.Global and
		  declaringObject:GetNamespace ():GetNamespaceType () ~= GCompute.NamespaceType.Type do
		declaringObject = declaringObject:GetDeclaringObject ()
	end
	
	if functionNode:Is ("FunctionDeclaration") then
		functionDefinition = declaringObject:GetNamespace ():AddMethod (functionNode:GetName (), functionNode:GetParameterList ():ToParameterList ())
	else
		functionDefinition = GCompute.FunctionDefinition ("<anonymous-function>", functionNode:GetParameterList ():ToParameterList ())
		declaringObject:GetNamespace ():SetupMemberHierarchy (functionDefinition)
	end
	
	functionDefinition:SetReturnType (GCompute.DeferredObjectResolution (functionNode:GetReturnTypeExpression (), GCompute.ResolutionObjectType.Type))
	functionDefinition:SetFunctionDeclaration (functionNode)
	functionNode:SetFunctionDefinition (functionDefinition)
	
	-- Set up function parameter namespace
	functionDefinition:BuildNamespace ()
	functionDefinition:GetNamespace ():SetDeclaringNamespace (functionNode:GetParentNamespace ())
	functionDefinition:GetNamespace ():SetDeclaringObject (functionNode:GetParentNamespace ())
end
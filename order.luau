--!strict

local o = {}

o.id = function<A>(x: A): A
	return x
end

o.head = function<A>(tbl: { A }): A
	return tbl[1]
end

o.tail = function<A>(tbl: { A }): A
	return tbl[#tbl]
end

o.array = function<A>(...: { A })
	return { ... }
end

o.rep = function(count: number)
	return function<A>(of: A): { A }
		return table.create(count, of)
	end
end

o.tupleToArray = function<A, B>(func: ({ A }) -> B)
	return function(...: A): B
		return func({ ... })
	end
end

o.flip = function<A, B, C>(func: (A) -> (B) -> C)
	return function(b: B)
		return function(a: A): C
			return func(a)(b)
		end
	end
end

o.apply = function<A, B>(func: (A) -> B): (A) -> B
	return function(value: A)
		return func(value)
	end
end

o.applyTo = o.flip(o.apply) :: <A, B>(value: A) -> (func: (A) -> B) -> B

o.empty = function<A, B>(tbl: { [A]: B }): boolean
	if next(tbl) ~= nil then
		return false
	end
	return true
end

o.notEmpty = function<A, B>(tbl: { [A]: B }): boolean
	return not o.empty(tbl)
end

o.p = function<A, B, C>(func: (A) -> (B) -> C)
	return function(g: (C) -> A)
		return function(a: A)
			return function(b: B): C
				return func(g(a))(g(b))
			end
		end
	end
end

o.append = function<A>(a: { A })
	return function(b: { A }): { A }
		local result = table.create(#a + #b)
		table.move(a, 1, #a, 1, result)
		table.move(b, 1, #b, #result + 1, result)
		return result
	end
end

o.compose2 = function<A, B>(f: (A) -> B)
	return function<C>(g: (B) -> C)
		return function(value: A): C
			return g(f(value))
		end
	end
end

o.curry = function<A>(func: (...any) -> A, n: number?): any
	local arity = n ~= nil and n or debug.info(func, "a")
	if arity <= 1 then
		return func
	end
	local function _curry(...)
		local applied = { ... }
		if arity == #applied then
			return func(unpack(applied))
		else
			return function<T...>(...: T...)
				return _curry(unpack(o.append(applied)({ ... })))
			end
		end
	end
	return _curry
end

o.foldl = function<A, B>(operator: (B) -> (A) -> B)
	return function(identity: B)
		return function(array: { A }): B
			local accum = identity
			for i, _ in array do
				accum = operator(accum)(array[i])
			end
			return accum
		end
	end
end

o.foldr = function<A, B, C>(operator: (A) -> (B) -> B)
	return function(identity: B)
		return function(array: { A }): B
			local accum = identity
			for i = #array, 1, -1 do
				accum = operator(accum)(array[i])
			end
			return accum
		end
	end
end

o.reduce = function<A, B>(operator: (A) -> (B) -> B)
	return function(array: { A }): { B }
		local accum = array[1]
		for i = 2, #array do
			accum = operator(accum)(array[i])
		end
		return accum
	end
end

o.reduceR = function<A, B>(operator: (A) -> (B) -> B)
	return function(array: { A }): { B }
		local accum = array[#array]
		for i = #array - 1, 1, -1 do
			accum = operator(accum)(array[i])
		end
		return accum
	end
end

o.merge = o.reduce(o.append) :: <A>({ { A } }) -> { A }

o.zip = function<A, B>(a: { A })
	return function(b: { B }): { { A & B } }
		local result = {}
		for index, value in a do
			result[#result + 1] = { value, b[index] }
		end
		return result
	end
end

o.zipWith = function<A, B, C>(operator: (A) -> (B) -> C)
	return function(a: { A })
		return function(b: { B }): { C }
			local result = {}
			for index, value in a do
				result[index] = operator(value)(b[index])
			end
			return result
		end
	end
end

o.unzip = function<A, B, C>(array: { { A & B } }): { { A } & { B } }
	local result = { {}, {} }
	for _, value in array do
		result[1][#result[1] + 1] = value[1]
		result[2][#result[2] + 1] = value[2]
	end
	return result
end

o.map = function<A, B>(mapper: (A) -> B)
	return function(array: { A }): { B }
		local result = table.create(#array)
		for _, value in array do
			result[#result + 1] = mapper(value)
		end
		return result
	end
end

o.flatMap = function<A, B>(mapper: (A) -> B)
	return function(array: { { A } }): { B }
		local result = o.map(mapper)(array)
		return o.merge(result)
	end
end

o.filter = function<A>(predicate: (A) -> boolean)
	return function(array: { A }): { A }
		local result = {}
		for _, v in array do
			if predicate(v) then
				result[#result + 1] = v
			end
		end
		return result
	end
end

o.reverse = function<A>(array: { A }): { A }
	local result = {}
	for i = #array, 1, -1 do
		result[#result + 1] = array[i]
	end
	return result
end

o.outerProduct = function<A, B, C>(operation: (A) -> (B) -> C)
	return function(a: { A })
		return function(b: { B }): { C }
			local mapper = o.apply(o.flip(o.map)(b))
			local array = o.map(operation)(a)
			return o.map(mapper)(array)
		end
	end
end

o.chunksOf = function(chunkSize: number)
	return function<A>(array: { A }): { { A } }
		local result = {}

		local remainder = (#array % chunkSize)

		local iterations = (#array // chunkSize) + o.safeDiv(remainder)(remainder)

		for i = 1, iterations do
			local startIndex = (i * chunkSize) - (chunkSize - 1)
			local endIndex = i * chunkSize

			result[i] = table.move(array, startIndex, endIndex, 1, {})
		end

		return result
	end
end

o.addIndex = function<A, B>(operator: ((A) -> B) -> ({ A }) -> { B })
	return function<K>(idxOp: (K) -> (A) -> B)
		return function(tbl: { [K]: A }): { [K]: B }
			local result = {}
			for i, _ in tbl do
				local appliedIndex = idxOp(i)
				local c = o.compose2(operator(appliedIndex))(o.head)

				local opResult = c({ tbl[i] })

				if typeof(i) == "number" then
					result[#result + 1] = opResult
				else
					result[i] = opResult
				end
			end
			return result
		end
	end
end

function o.indexes<A, B>(tbl: { [A]: B }): { A }
	local result = {}
	for i, _ in tbl do
		result[#result + 1] = i
	end
	return result
end

-- Debug

function o.trace<A>(value: A): A
	warn(value)
	return value
end

o.traceMsg = function(message: string)
	return function<A>(value: A): A
		warn(`{message}{value}`)
		return value
	end
end

-- Function Composition

o.buildComp = o.compose2(o.foldl)(o.flip) :: <A, B>(operator: (B) -> (A) -> B) -> (array: { A }) -> (identity: B) -> B
o.compose = o.buildComp(o.applyTo) :: (array: { (any) -> any }) -> (identity: any) -> any

-- Dictionary

o.prop = function(property: string)
	return function<A, B>(object: { [A]: B }): B
		return object[property]
	end
end

-- String

o.cut = function(pattern: string)
	return function(str: string): string
		local pieces = string.split(str, pattern)
		return `{pieces[1]}{pieces[#pieces]}`
	end
end

-- Logic

function o.isNil<A>(a: A?): boolean
	return a == nil
end

function o.isNotNil<A>(a: A?): boolean
	return a ~= nil
end

o.andOp = function(a: boolean)
	return function(b: boolean): boolean
		return a and b
	end
end

o.orOp = function(a: boolean)
	return function(b: boolean): boolean
		return a or b
	end
end

function o.notOp(bool: boolean): boolean
	return not bool
end

-- Math

o.add = function<A>(a: number)
	return function(b: number): number
		return a + b
	end
end

o.sub = function<A>(a: number)
	return function(b: number): number
		return a - b
	end
end

o.mul = function<A>(a: number)
	return function(b: number): number
		return a * b
	end
end

o.div = function<A>(a: number)
	return function(b: number): number
		return a / b
	end
end

o.floorDiv = function<A>(a: number)
	return function(b: number): number
		return a // b
	end
end

o.safeDiv = function<A>(a: number)
	return function(b: number): number
		return a / (b + 0 ^ b)
	end
end

o.exp = function<A>(a: number)
	return function(b: number): number
		return a ^ b
	end
end

o.mod = function<A>(a: number)
	return function(b: number): number
		return a % b
	end
end

o.even = function(a: number): boolean
	return a % 2 == 0
end

o.odd = function<A>(a: number): boolean
	return o.notOp(o.even(a))
end

function o.negate(num: number): number
	return -num
end

-- Relational

o.eq = function<A>(a: A)
	return function(b: A): boolean
		return a == b
	end
end

o.notEq = function<A>(a: A)
	return function(b: A): boolean
		return not (a == b)
	end
end

o.gt = function(a: number)
	return function(b: number): boolean
		return a > b
	end
end

o.gte = function(a: number)
	return function(b: number): boolean
		return a >= b
	end
end

o.lt = function(a: number)
	return function(b: number): boolean
		return a < b
	end
end

o.lte = function(a: number)
	return function(b: number): boolean
		return a <= b
	end
end

return o

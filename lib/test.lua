-- ———————————————————————————————————————————————————————————————————————————
-- timer.lua
-- ———————————————————————————————————————————————————————————————————————————

-- https://github.com/EntranceJew/timer/blob/master/timer.lua

timer = {
	namedTimers = {},
	--[[
		active,
		delay,
		delayTimer, --dt gets added to it until it is delay
		repetitions,
		repetitionsDone, --gets added to each cycle, 
		func,
	]]
	simpleTimers = {},
	--[[
		delay,
		delayTimer, --dt gets added to it until it is delay
		func,
	]]
}

--timer.namedTimers[identifier]
-- repetitions=0 for infinity
function timer.Adjust(identifier, delay, repetitions, func)
	if timer.namedTimers[identifier] then
		timer.namedTimers[identifier].delay = delay
		-- check for lower?
		timer.namedTimers[identifier].repetitions = repetitions
		-- check for lower?
		timer.namedTimers[identifier].func = func
		return true
	else
		return false
	end
end

timer.Check = timer.Update

function timer.Update(dt)
	for k,v in pairs(timer.namedTimers) do
		if v.active then
			v.delayTimer = v.delayTimer + dt
			if v.delayTimer >= v.delay then
				v.func()
				v.repetitionsDone = v.repetitionsDone + 1
				if v.repetitions ~= 0 and v.repetitionsDone >= v.repetitions then
					timer.namedTimers[k] = nil
				else
					v.delayTimer = v.delayTimer - v.delay
				end
			end
		end
	end
	for k,v in pairs(timer.simpleTimers) do
		v.delayTimer = v.delayTimer + dt
		if v.delayTimer >= v.delay then
			v.func()
			timer.simpleTimers[k]=nil
		end
	end
end --[[internal: go through all functions and do whatever is done]]

function timer.Create(identifier, delay, repetitions, func)
	if delay <= 0 then return false end
	timer.namedTimers[identifier] = {
		active = false,
		delay = delay,
		delayTimer = delay,
		repetitions = repetitions or 0,
		repetitionsDone = repetitions or 0,
		func = func
	}
end 

function timer.Destroy(identifier) 
	timer.namedTimers[identifier] = nil
end

function timer.Exists(identifier)
	return timer.namedTimers[identifier]~=nil
end

function timer.Pause(identifier)
	if timer.namedTimers[identifier] and timer.namedTimers[identifier].active then
		timer.namedTimers[identifier].active = false
		return true
	else
		return false
	end
end

timer.Remove = timer.Destroy

function timer.RepsLeft(identifier) 
	if timer.namedTimers[identifier] then
		return timer.namedTimers[identifier].repetitionsLeft
	end
end

function timer.Simple(delay, func)
	table.insert(timer.simpleTimers, {delay=delay,delayTimer=0,func=func})
end

function timer.Start(identifier) 
	if timer.namedTimers[identifier] then
		timer.namedTimers[identifier].active = true
		timer.namedTimers[identifier].delayTimer = 0
		timer.namedTimers[identifier].repetitionsDone = 0
		return true
	else
		return false
	end
end
function timer.Stop(identifier)
	if timer.namedTimers[identifier] and timer.namedTimers[identifier].active then
		timer.namedTimers[identifier].active = false
		timer.namedTimers[identifier].delayTimer = 0
		timer.namedTimers[identifier].repetitionsDone = 0
		return true
	else
		return false
	end
end

function timer.TimeLeft(identifier)
	if timer.namedTimers[identifier] then
		return timer.namedTimers[identifier].delay-timer.namedTimers[identifier].delayTimer
	else
		return 0
	end
end

function timer.Toggle(identifier)
	if timer.namedTimers[identifier] then
		if timer.namedTimers[identifier].active then
			timer.Pause(identifier)
		else
			timer.UnPause(identifier)
		end
		return timer.namedTimers[identifier].active
	end
end

function timer.UnPause(identifier)
	if timer.namedTimers[identifier] and not timer.namedTimers[identifier].active then
		timer.namedTimers[identifier].active = true
		return true
	else
		return false
	end
end





-- ———————————————————————————————————————————————————————————————————————————
-- Promise.lua
-- ———————————————————————————————————————————————————————————————————————————
-- FROM: https://github.com/Lestrigon17/lua-promises/blob/master/promises.lua


Promise = Promise or {};

Promise.ENUM_STATUS = {
    pending = 'pending',
    resolved = 'resolved',
    rejected = 'rejected'
}

local isDebugEnabled = false;

local function printError(err)
    if (not isDebugEnabled) then return end;
    error(err, 2);
end;

-- Create new promise
Promise.new = function(fnExecution)
    local promise  = {};
    promise.status = Promise.ENUM_STATUS.pending;
    promise.isPromise = true

    promise._fnAfter = {};
    promise._fnThrow = nil;
    promise._current = promise;

    promise.after = function(fnAfterExecution)
        if (type(fnAfterExecution)~='function') then 
            printError('Promise has `after` callback, which is not a function, please, check your code');
            return;
        end;

        table.insert(promise._fnAfter, fnAfterExecution);

        return promise;
    end;

    promise.throw = function(fnThrow)
        if (promise._fnThrow) then
            printError('Promise has more that 1 `throw` functions, please, check your promise code', 2);
            return;
        end;

        if (type(fnThrow)~='function') then 
            printError('Promise has `throw` callback, which is not a function, please, check your code');
            return;
        end;

        promise._fnThrow = fnThrow;

        return promise;
    end;

    local fnRewriteRule = function() end;

    local fnResolve = function(...)
        if (promise._current.status ~= Promise.ENUM_STATUS.pending) then return; end;
        promise._current.status = Promise.ENUM_STATUS.resolved;

        if (#promise._fnAfter == 0) then
            printError('Promise has no `after` callback, please, check your promise code', 2);
            return;
        end;

        local fnAfterCallback = table.remove(promise._fnAfter, 1);

        local possiblePromise = fnAfterCallback(...);

        if (#promise._fnAfter > 0) then
            if (not possiblePromise or not possiblePromise.isPromise) then
                printError('Promise function `after` expected new Promise, but get nil or non promise object!');
                return;
            end;
        end;

        if (possiblePromise and possiblePromise.isPromise) then
            promise._current = possiblePromise;
            fnRewriteRule(possiblePromise);
        end;
    end;

    local fnReject = function(...)
        if (promise._current.status ~= Promise.ENUM_STATUS.pending) then return; end;
        promise._current.status = Promise.ENUM_STATUS.rejected;

        if (promise._fnThrow == nil) then
            printError('Promise has no `Throw` callback, please, check your promise code', 2);
            return;
        end;

        promise._fnThrow(...);
    end;

    fnRewriteRule = function(promise)
        print('rewrite')
        promise.rewriteRule({
            fnResolve = fnResolve,
            fnReject = fnReject
        });
    end;

    promise.rewriteRule = function(data)
        if (data.fnResolve) then fnResolve = data.fnResolve; end;
        if (data.fnReject) then fnReject = data.fnReject; end;
        if (data.delayedLaunch) then promise.delayedLaunch = true; end;
    end;

    promise.launch = function()
        fnExecution(fnResolve, fnReject);
    end;

    timer.Simple(0, function() 
        if (promise.delayedLaunch) then return; end;
        fnExecution(fnResolve, fnReject); 
    end);

    return promise;
end;

-- Run all promise by chain
Promise._run = function(data, isAsync)
    if (not data or not istable(data)) then 
        return false, "Promise.all list, that recived, is not are list!"; 
    end;

    if (#data == 0) then
        return false, "Promise.all list is empty!";
    end;

    -- check all promises
    for _, promise in ipairs(data) do
        if (not promise or not promise.isPromise) then 
            return false, "Some item of Promise.all is not a promise!"; 
        end;
        
        if (not isAsync) then
            promise.rewriteRule({
                delayedLaunch = true;
            });
        end;
    end;

    return Promise.new(function(resolve, reject)
        local promiseResponse = {};
        local isRejected = false;
        local firstRejectError = nil;

        local function defaultAfter(i, ...)
            local arg = {...};
            print(i)
            if (#arg == 1) then
                promiseResponse[i] = arg[1];
            else 
                promiseResponse[i] = arg;
            end;
        end;

        local function defaultThrow(err)
            if (not firstRejectError) then
                firstRejectError = err;
            end;
            isRejected = true;
        end;

        if (isAsync) then
            for i, currentPromise in pairs(data) do
                currentPromise
                    .after(function(...)
                        defaultAfter(i, ...);
                    end)
                    .throw(defaultThrow);
            end;
        else
            local i = 1;

            local function runNextPromise()
                if (not data[i]) then return; end;
                local currentPromise = data[i];
                currentPromise
                    .after(function(...)
                        defaultAfter(i, ...);
                        
                        i = i + 1;

                        if (data[i]) then runNextPromise(); end;
                    end)
                    .throw(defaultThrow)
                    .launch();
            end;

            runNextPromise();
        end;

        local randomTag = os.time() .. "_" .. math.random(0, 999999);

        timer.Create(randomTag, 0, 0, function()
            local isAllPromisesCompleted = table.Count(promiseResponse) == #data;
            if (not isRejected and not isAllPromisesCompleted) then return; end;

            if (isRejected) then
                reject(firstRejectError);
            end;
            
            if (isAllPromisesCompleted) then
                resolve(promiseResponse);
            end;

            timer.Destroy(randomTag);
        end);
    end);
end;

-- Resolve without creation function
Promise.resolve = function(...)
    local args = ...
    return Promise.new(function(resolve, _)
        resolve(args);
    end);
end;

-- Resolve without creation function
Promise.reject = function(value)
    return Promise.new(function(_, reject)
        reject(value);
    end);
end;

Promise.all = function(data)
    local promise, errmsg = Promise._run(data, false);

    if (not promise) then
        return Promise.reject(errmsg);
    end;

    return promise;
end;

Promise.allAsync = function(data)
    local promise, errmsg = Promise._run(data, true);

    if (not promise) then
        return Promise.reject(errmsg);
    end;

    return promise;
end;


return Promise

local format = string.format
local floor = math.floor
local insert = table.insert

local M = { }

local function error_message(data, expected_type)  -- {{{
    --- Generate error message for validators.
  if data then
    return format('%s is not %s.', tostring(data), expected_type)
  end
  return format('is missing and should be %s.', expected_type)
end  -- }}}

function M.print_err(error_list, parents)  -- {{{
    --- Create a readable string output from the validation errors output.
    -- Makes prefix not nil, for posterior concatenation.
  local error_output = ''
  local parents = parents or ''
  if not error_list then return false end

    -- Iterates over the list of messages.
  for key, err in pairs(error_list) do   -- If it is a node, print it.
    if type(err) == 'string' then
      error_output = format('%s\n%s%s %s', error_output, parents ,key, err)
    else                                 -- If it is a table, recurse it.
      error_output = format('%s%s', error_output, M.print_err(err, format('%s%s.', parents, key)))
    end
  end

  return error_output
end  -- }}}

--- Validators -----------------------------------------------------------------

-- A validator is a function in charge of verifying data compliance.
-- @key Key of data being validated.
-- @data Current data tree level. Meta-validator might need to verify other keys. e.g. assert()
-- @return function that returns true on success, false and message describing the error

function M.is_string()  -- {{{
  return function(value)
    if type(value) ~= 'string' then
      return false, error_message(value, 'a string')
    end
    return true
  end
end  -- }}}

function M.is_integer()  -- {{{
  return function(value)
    if type(value) ~= 'number' or value%1 ~= 0 then
      return false, error_message(value, 'an integer')
    end
    return true
  end
end  -- }}}

function M.is_number()  -- {{{
  return function(value)
    if type(value) ~= 'number' then
      return false, error_message(value, 'a number')
    end
    return true
  end
end  -- }}}

function M.is_boolean()  -- {{{
  return function(value)
    if type(value) ~= 'boolean' then
      return false, error_message(value, 'a boolean')
    end
    return true
  end
end  -- }}}

function M.is_array(child_validator, is_object)  -- {{{
  return function(value, key, data)
    local result, err = nil
    local err_array = {}

      -- Iterate the array and validate them.
    if type(value) == 'table' then
      for index in pairs(value) do
        if not is_object and type(index) ~= 'number' then
          insert(err_array, error_message(value, 'an array') )
        else
          result, err = child_validator(value[index], index, value)
          if not result then
            err_array[index] = err
          end
        end
      end
    else
      insert(err_array, error_message(value, 'an array') )
    end

    if next(err_array) == nil then
      return true
    else
      return false, err_array
    end
  end
end  -- }}}

function M.optional(validator)  -- {{{
    -- When data is present apply the given validator on data.
  return function(value, key, data)
    if not value then return true
    else
      return validator(value, key, data)
    end
  end
end  -- }}}

function M.or_op(validator_a, validator_b)  -- {{{
    -- Allow data validation using two different validators and applying or condition between results.
  return function(value, key, data)
    if not value then return true
    else
      local valid, err_a = validator_a(value, key, data)
      if not valid then
        valid, err_b = validator_b(value, key, data)
      end
      if not valid then
        return valid, err_a .. " OR " .. err_b
      else
        return valid, nil
      end
    end
  end
end  -- }}}

function M.assert(key_check, match, validator)  -- {{{
    -- This function enforces the existence of key/value with the verification of the key_check.
  return function(value, key, data)
    if data[key_check] == match then
      return validator(value, key, data)
    else
      return true
    end
  end
end  -- }}}

function M.in_list(list)  -- {{{
    -- Ensure the value is contained in the given list.
  return function(value)
    local printed_list = "["
    for _, word in pairs(list) do
      if word == value then
        return true
      end
      printed_list = printed_list .. " '" .. tostring(word) .. "'"
    end
    printed_list = printed_list .. " ]"
    return false, { error_message(value, 'in list ' .. printed_list) }
  end
end  -- }}}

function M.is_table(schema, tolerant)  -- {{{
  return function(value)
    local result, err = nil

    if type(value) ~= 'table' then
        -- Enforce errors of childs value.
      _, err = validate_table({}, schema, tolerant)
      if not err then err = {} end
      result = false
      insert(err, error_message(value, 'a table') )
    else
      result, err = validate_table(value, schema, tolerant)
    end

    return result, err
  end
end  -- }}}

function validate_table(data, schema, tolerant)  -- {{{
    -- @param data Table containing the pairs to be validated.
    -- @param schema Schema against which the data will be validated.
    -- @return String describing the error or true.

    -- Array of error messages.
  local errs = {}
    -- Check if the data is empty.

    -- Check if all data keys are present in the schema.
  if not tolerant then
    for key in pairs(data) do
      if schema[key] == nil then
        errs[key] = 'is not allowed.'
      end
    end
  end

     -- Iterates over the keys of the data table.
  for key in pairs(schema) do
      -- Calls a function in the table and validates it.
    local result, err = schema[key](data[key], key, data)

      -- If validation fails, print the result and return it.
    if not result then
      errs[key] = err
    end
  end

    -- Lua does not give size of table holding only string as keys.
    -- Despite the use of #table we have to manually loop over it.
  for _ in pairs(errs) do
    return false, errs
  end

  return true
end  -- }}}

return M

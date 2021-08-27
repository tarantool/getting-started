local argparse = require('cartridge.argparse')
local errors = require('errors')

local AppError = errors.new_class('AppError')

local function read_args(opts, required)
    local args = argparse.get_opts(opts)
    if required then
        for _, opt in ipairs(opts) do
            if not args[opt] then
                return nil, AppError:new('%s must be set through ENV or cli argument', opt)
            end
        end
    end
    return args
end

return {
    read_args = read_args
}

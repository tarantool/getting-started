local httpd = require('cartridge').service_get('httpd')
local mime_types = require('http.mime_types')
local errors = require('errors')

local HTTPError = errors.new_class('HTTPError')

local function catfile(...)
    local sp = { ... }

    local path

    if #sp == 0 then
        return
    end

    for i, pe in pairs(sp) do
        if path == nil then
            path = pe
        elseif string.match(path, '.$') ~= '/' then
            if string.match(pe, '^.') ~= '/' then
                path = path .. '/' .. pe
            else
                path = path .. pe
            end
        else
            if string.match(pe, '^.') == '/' then
                path = path .. string.gsub(pe, '^/', '', 1)
            else
                path = path .. pe
            end
        end
    end

    return path
end

local function type_by_format(fmt)
    if fmt == nil then
        return 'application/octet-stream'
    end

    local t = mime_types[ fmt ]

    if t ~= nil then
        return t
    end

    return 'application/octet-stream'
end

local function extend(tbl, tblu, raise)
    local res = {}
    for k, v in pairs(tbl) do
        res[ k ] = v
    end
    for k, v in pairs(tblu) do
        if raise then
            if res[ k ] == nil then
                return nil, HTTPError:new(("Unknown option '%s'"):format(k))
            end
        end
        res[ k ] = v
    end
    return res
end

local function static_file(self, request, format)
    local file = catfile(self.options.app_dir, 'public', request.path)

    if self.options.cache_static and self.cache.static[ file ] ~= nil then
        return {
            code = 200,
            headers = {
                [ 'content-type'] = type_by_format(format),
            },
            body = self.cache.static[ file ]
        }
    end

    local s, fh = pcall(io.input, file)

    if not s then
        return { status = 404 }
    end

    local body = fh:read('*a')
    io.close(fh)

    if self.options.cache_static then
        self.cache.static[ file ] = body
    end

    return {
        status = 200,
        headers = {
            [ 'content-type'] = type_by_format(format),
        },
        body = body
    }
end

local function handler(self, request)
    if self.hooks.before_dispatch ~= nil then
        local _, err = self.hooks.before_dispatch(self, request)
        if err ~= nil then
            return err
        end
    end

    local format = 'html'

    local pformat = string.match(request.path, '[.]([^.]+)$')
    if pformat ~= nil then
        format = pformat
    end

    local r = self:match(request.method, request.path)
    if r == nil then
        return static_file(self, request, format)
    end

    local stash, err = extend(r.stash, { format = format })
    if not stash then
        return nil, err
    end

    request.endpoint = r.endpoint
    request.tstash   = stash

    local resp = r.endpoint.sub(request)
    if self.hooks.after_dispatch ~= nil then
        self.hooks.after_dispatch(request, resp)
    end
    return resp
end

httpd.options.handler = handler


return {
    httpd = httpd
}

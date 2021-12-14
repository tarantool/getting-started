local cartridge = require('cartridge')
local log = require('log')
local yaml = require('yaml')
local helper = require('app.libs.helper')
local jwt = require('app.libs.jwt')
local httpd = require('app.libs.httpd').httpd

local EXT_CONFIG_NAME = "extensions/config.yml"
local DEFAULT_COOKIE_DOMAIN = "try.tarantool.io"


local function is_ignore_auth(method, path)
    local ext_config = cartridge.config_get_readonly()
    if ext_config and ext_config[EXT_CONFIG_NAME] then
        ext_config = yaml.decode(ext_config[EXT_CONFIG_NAME])
        if ext_config then
            for _, f in pairs(ext_config['functions']) do
                for _, event in pairs(f['events']) do
                    if event.http and
                        event.http.path:lower() == path:lower() and
                        event.http.method:lower() ==  method:lower() then
                            return true
                    end
                end
            end
        end
    end
    return false
end

local function init()
    local is_enabled = helper.read_args({ jwt_auth = 'boolean' })['jwt_auth'] or false
    if not is_enabled then
        return nil
    end

    local public_key = helper.read_args({ public_key = 'string' }, true).public_key
    local domain = helper.read_args({ cookie_domain = 'string' }, false).cookie_domain or DEFAULT_COOKIE_DOMAIN

    local function before_dispatch(_, req)
        if is_ignore_auth(req.method, req.path) then
            return
        end

        local token = req:cookie('token') --or req.headers['authorization']
        if not token then
            log.info('Token not found')
            return nil, req:redirect_to('/')
        end

        -- token = token:gsub('Bearer ', '')
        local payload, err = jwt.decode(token, public_key)
        if not payload or not payload.user_id then
            log.info(err)
            local resp = req:redirect_to('/')
            resp.headers['Set-Cookie'] = ('token=%s;path=/;Max-Age=-1;domain=%s;HttpOnly'):format(token, domain)
            --resp.headers['authorization'] = ''
            return nil, resp
        end
    end

    httpd:hook('before_dispatch', before_dispatch)
end

return {
    init = init,
}

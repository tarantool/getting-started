local log = require('log')
local helper = require('app.libs.helper')
local jwt = require('app.libs.jwt')
local httpd = require('app.libs.httpd').httpd


local function init()
    local is_enabled = helper.read_args({ jwt_auth = 'boolean' })['jwt_auth'] or false
    if not is_enabled then
        return nil
    end

    local public_key = helper.read_args({ public_key = 'string' }, true).public_key

    local function before_dispatch(_, req)
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
            resp.headers['Set-Cookie'] = ('token=%s;path=/;Max-Age=-1;HttpOnly'):format(token)
            --resp.headers['authorization'] = ''
            return nil, resp
        end
    end

    httpd:hook('before_dispatch', before_dispatch)
end

return {
    init = init,
}

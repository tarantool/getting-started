#!/usr/bin/env tarantool

require('strict').on()
package.setsearchroot()

local front = require('frontend-core')
local cartridge = require('cartridge')
local analytics = require('analytics')
local tutorial_bundle = require('cartridge-app.bundle')
local clock = require('clock')
local json = require('json')

-- improve UX a bit:
-- make tarantool/cartridge-extensions enabled by default
require('extensions').permanent = true

local ENTERPRISE = 'Enterprise'

local roles = {
    'cartridge.roles.vshard-router',
    'cartridge.roles.vshard-storage',
    'extensions',
    'cartridge.roles.crud-router',
    'cartridge.roles.crud-storage',
}

local enterprise_roles = {
    'space-explorer'
}

local _, tarantool_type = unpack(require('tarantool').package:split(' '))
if tarantool_type == ENTERPRISE then
    for _, role in pairs(enterprise_roles) do
        table.insert(roles, role)
    end
end

local ok, err = cartridge.cfg({
    roles = roles,
    cluster_cookie = 'try-cartridge-cluster-cookie'
})

front.add('analytics_static', analytics.static_bundle)
front.add('ga', analytics.use_bundle({ ga = '22120502-2' }))

front.add('tutorial', tutorial_bundle)

local auth = require('app.auth')
auth.init()

local last_used = clock.time()

local httpd = cartridge.service_get('httpd')

local cartridge_before_dispatch = httpd.hooks.before_dispatch

local function before_dispatch(httpd, req)
    if cartridge_before_dispatch ~= nil and not string.find(req.path, '/last_used') then
        local ok, err = cartridge_before_dispatch(httpd, req)
        if err then
            return nil, err
        end
    end
    if string.find(req.path, '/admin') then
        last_used = clock.time()
    end
end

local cartridge_after_dispatch = httpd.hooks.after_dispatch

local function after_dispatch(req, resp)
    if cartridge_after_dispatch ~= nil then
        cartridge_after_dispatch(req, resp)
    end
    resp.headers = resp.headers or {}
    resp.headers['Set-Cookie']=('token=%s;path=/;expires=+7d;HttpOnly'):format(req:cookie('token'))
end

httpd:route(
    { path = '/last_used', public = true },
    function()
        return {
            body = json.encode({ last_used = last_used }),
            status = 200
        }
    end
)

httpd:hook('before_dispatch', before_dispatch)
httpd:hook('after_dispatch', after_dispatch)

assert(ok, tostring(err))

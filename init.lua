#!/usr/bin/env tarantool

require('strict').on()
package.setsearchroot()

local front = require('frontend-core')
local cartridge = require('cartridge')
local analytics = require('analytics')
local tutorial_bundle = require('cartridge-app.bundle')
local clock = require('clock')
local json = require('json')

local ok, err = cartridge.cfg({
    roles = {
        'cartridge.roles.vshard-router',
        'cartridge.roles.vshard-storage',
        'extensions',
        'cartridge.roles.crud-router',
        'cartridge.roles.crud-storage',
        'space-explorer',
    },
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
    if cartridge_before_dispatch ~= nil then
        local ok, err = cartridge_before_dispatch(httpd, req)
        if err then
            return nil, err
        end
    end
    if string.find(req.path, '/admin') then
        last_used = clock.time()
    end
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

assert(ok, tostring(err))

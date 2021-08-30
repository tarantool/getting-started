#!/usr/bin/env tarantool

require('strict').on()
package.setsearchroot()

local front = require('frontend-core')
local cartridge = require('cartridge')
local analytics = require('analytics')
local tutorial_bundle = require('cartridge-app.bundle')

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

assert(ok, tostring(err))

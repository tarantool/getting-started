local t = require('luatest')
local h = require('test.helper')

local yaml = require('yaml')

local helper = require('test.helper.integration')
local cluster = helper.cluster

local g = t.group('integration_api')

g.before_all = function()
    g.cluster = helper.cluster
    g.cluster:start()
end

g.after_all = function()
    helper.stop_cluster(g.cluster)
end

g.test_sample = function()
    local server = cluster.main_server
    local response = server:http_request('post', '/admin/api', {json = {query = '{ cluster { self { alias } } }'}})
    t.assert_equals(response.json, {data = { cluster = { self = { alias = 'router-1' } } }})
    t.assert_equals(server.net_box:eval('return box.cfg.memtx_dir'), server.workdir)
end

g.test_extensions = function()
    local server = cluster.main_server
    h.set_sections(server, {{
        filename = 'extensions/main.lua',
        content = [[
            local M = {}
            function M.echo(req)
                return {status = 200, body = req:param('msg')}
            end
            return M
        ]],
    }, {
        filename = 'extensions/config.yml',
        content = yaml.encode({
            functions = {
                say_meow = {
                    module = 'extensions.main',
                    handler = 'echo',
                    events = {{http = {path = '/echo', method = 'get'}}}
                }
            }
        })
    }})
    local response = server:http_request('get', '/echo?msg=hello')
    t.assert_equals(response.status, 200)
    t.assert_equals(response.body, 'hello')
end

local g = t.group('auth')

g.before_all = function()
    os.setenv('TARANTOOL_JWT_AUTH', 'True')
    g.cluster = helper.cluster
    g.cluster:start()

    local server = cluster.main_server
    h.set_sections(server, {{
        filename = 'extensions/main.lua',
        content = [[
            local M = {}
            function M.echo(req)
                return {status = 200, body = req:param('msg')}
            end
            function M.any(req)
                return {status = 200, body = 'any'}
            end
            return M
        ]],
    }, {
        filename = 'extensions/config.yml',
        content = yaml.encode({
            functions = {
                say_meow = {
                    module = 'extensions.main',
                    handler = 'echo',
                    events = {{http = {path = '/echo', method = 'get'}}}
                },
                say_any = {
                    module = 'extensions.main',
                    handler = 'any',
                    events = {{http = {path = '/any', method = 'any'}}}
                }
            }
        })
    }})
end

g.after_all = function()
    os.setenv('TARANTOOL_JWT_AUTH', nil)
    helper.stop_cluster(g.cluster)
end

g.test_ignore_jwt_auth_for_ext_routes_success = function ()
    local server = cluster.main_server
    local response = server:http_request('get', '/echo?msg=hello', {
        raise = false,
        http = {
            follow_location = false
        }
    })
    t.assert_equals(response.status, 200)
    t.assert_equals(response.body, 'hello')
end

g.test_ignore_jwt_auth_for_ext_routes_with_any_method = function ()
    local server = cluster.main_server
    local response = server:http_request('get', '/any', {
        raise = false,
        http = {
            follow_location = false
        }
    })
    t.assert_equals(response.status, 200)
    t.assert_equals(response.body, 'any')
end


g.test_ignore_jwt_auth_for_ext_routes_fail = function ()
    local server = cluster.main_server
    local response = server:http_request('get', '/admin', {
        raise = false,
        http = {
            follow_location = false
        }
    })
    t.assert_equals(response.status, 302)
end

local t = require('luatest')
local g = t.group('integration_api')
local h = require('test.helper')

local yaml = require('yaml')

local helper = require('test.helper.integration')
local cluster = helper.cluster

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

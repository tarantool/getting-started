-- This file is required automatically by luatest.
-- Add common configuration here.

local fio = require('fio')
local t = require('luatest')

local helper = {}

helper.root = fio.dirname(fio.abspath(package.search('init')))
helper.datadir = fio.pathjoin(helper.root, 'tmp', 'db_test')
helper.server_command = fio.pathjoin(helper.root, 'init.lua')

t.before_suite(function()
    fio.rmtree(helper.datadir)
    fio.mktree(helper.datadir)
end)

local jwt = "eyJhbGciOiJSUzI1NiIsInR5cCI6Imp3dCJ9.eyJ1c2VyX2lkIjoiMzY3YzBkNmQtNGJlOC00ZjA1LTlmZjMtNmY4MmZkYmYxM2ViIn0=.CasldudGMyXGuYNp98qjOFMLAVoBfjVgbm0Kx9qyYgJIDdnQ9loAJA71hFIGkFSVFlDHH7X+Dmi+gAWLwzwdbA=="

function helper.set_sections(srv, sections)
    return srv:graphql({
        query = [[
            mutation($sections: [ConfigSectionInput!]) {
                cluster {config(sections: $sections) {
                    filename content
                }}
            }
        ]],
        variables = {sections = sections},
    }, {
        http = {
            headers = {cookie = ('token=%s'):format(jwt)}
        }
    })
end

return helper

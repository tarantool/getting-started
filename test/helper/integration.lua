local t = require('luatest')
local cartridge_helpers = require('cartridge.test-helpers')
local shared = require('test.helper')
local helper = {shared = shared}

local JWT = "eyJhbGciOiJSUzI1NiIsInR5cCI6Imp3dCJ9.eyJ1c2VyX2lkIjoiMzY3YzBkNmQtNGJlOC00ZjA1LTlmZjMtNmY4MmZkYmYxM2ViIn0=.CasldudGMyXGuYNp98qjOFMLAVoBfjVgbm0Kx9qyYgJIDdnQ9loAJA71hFIGkFSVFlDHH7X+Dmi+gAWLwzwdbA=="

helper.cluster = cartridge_helpers.Cluster:new({
    server_command = shared.server_command,
    datadir = shared.datadir,
    use_vshard = false,
    replicasets = {
        {
            alias = 'router',
            uuid = cartridge_helpers.uuid('a'),
            roles = {'crud-router', 'extensions'},
            servers = {
                {
                    instance_uuid = cartridge_helpers.uuid('a', 1)
                }
            },
        },
    },
})

helper.cluster['apply_topology'] = function(self)
    local replicasets = table.deepcopy(self.replicasets)
    local replicaset_by_uuid = {}
    for _, replicaset in pairs(replicasets) do
        replicaset_by_uuid[replicaset.uuid] = replicaset
        replicaset.join_servers = {}
        replicaset.servers = nil
    end

    for _, server in pairs(self.servers) do
        table.insert(replicaset_by_uuid[server.replicaset_uuid].join_servers, {
            uri = server.advertise_uri,
            uuid = server.instance_uuid,
            labels = server.labels,
            zone = server.zone,
        })
    end

    self.main_server:graphql({
        query = [[
            mutation boot($replicasets: [EditReplicasetInput]) {
                cluster {
                    edit_topology(replicasets: $replicasets) { servers { uri } }
                }
            }
        ]],
        variables = {replicasets = replicasets},
    }, {
        http = {
            headers = {cookie = ('token=%s'):format(JWT)}
        }
    })
end


function helper.stop_cluster(cluster)
    assert(cluster ~= nil)
    cluster:stop()
end

return helper

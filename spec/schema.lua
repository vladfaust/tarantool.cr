box.cfg{listen = 3301}
box.schema.space.create('examples', {id = 999, not_exists = true})
box.space.examples:create_index('primary', {type = 'hash', parts = {1, 'unsigned', not_exists = true}})
box.space.examples:create_index('name', {type = 'tree', parts = {2, 'string', not_exists = true}})
box.space.examples:create_index('wage', {type = 'tree', parts = {3, 'unsigned', not_exists = true}})
box.schema.user.grant('guest', 'read,write', 'space', 'examples')
box.schema.user.grant('guest', 'read', 'space', '_space')

function reset()
    box.space.examples:truncate()
end


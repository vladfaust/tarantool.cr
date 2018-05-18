function setup()
    box.schema.space.create('examples', {id = 999, if_not_exists = true})
    box.space.examples:create_index('primary', {type = 'hash', parts = {1, 'unsigned'}, if_not_exists = true})
    box.space.examples:create_index('name', {type = 'tree', parts = {2, 'string'}, if_not_exists = true})
    box.space.examples:create_index('wage', {type = 'tree', parts = {3, 'unsigned'}, if_not_exists = true})

    if box.schema.user.exists('jake') == false then
        box.schema.user.create('jake', {password = 'qwerty'})
    end

    box.schema.user.grant('jake', 'read,write,execute', 'space', 'examples', {if_not_exists = true})
end

function reset()
    box.space.examples:truncate()
end


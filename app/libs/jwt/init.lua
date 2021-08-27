local digest = require('digest')
local errors = require('errors')
local json = require('json')

local rsa = require('app.libs.jwt.rsa')


local JWTError = errors.new_class('JWTError')

local function jwt_decode(str)
    local decoded_str = digest.base64_decode(str)

    local payload, err = JWTError:pcall(json.decode, decoded_str)
    if not payload then
        return nil, err
    end

    return payload
end

local function parse(token)
    local token_parts = token:split('.')
    if #token_parts ~= 3 then
        return nil, JWTError:new('Wrong token format')
    end

    local header, payload, signature = unpack(token_parts)
    local err
    header, err = jwt_decode(header)
    if err then
        return nil, err
    end

    payload, err = jwt_decode(payload)
    if err then
        return nil, err
    end

    return {
        header = header,
        payload = payload,
        signature = signature
    }
end

local function validate_signature(token, public_key)
    local splitted_token = token:split('.')
    local str = splitted_token[1] .. '.' .. splitted_token[2]
    local sign = digest.base64_decode(splitted_token[3])
    return rsa.new({ public_key = public_key }):verify(str, sign)
end

local function decode(jwt, secret)
    local parsed_token, err = parse(jwt)
    if not parsed_token then
        return nil, JWTError:new(("Inappropriate token format: %s"):format(err))
    end

    local ok, err = pcall(validate_signature, jwt, secret)
    if not ok then
        return nil, JWTError:new(("Can't validate token signature: %s"):format(err))
    end

    return parsed_token.payload
end

local function encode(payload, secret)
    local segments = {}

    table.insert(segments, digest.base64_encode(json.encode({typ='jwt', alg='RS256'})))
    table.insert(segments, digest.base64_encode(json.encode(payload)))

    local signing_input = table.concat(segments, '.')
    local sig, err = rsa.new({ private_key = secret }):sign(signing_input)
    if not sig then
        return nil, JWTError:new(("Can't encode: %s"):format(err))
    end

    sig = string.gsub(digest.base64_encode(sig), "\n", "")
    table.insert(segments, sig)

    return table.concat(segments, '.')
end

return {
    decode = decode,
    encode = encode,
}

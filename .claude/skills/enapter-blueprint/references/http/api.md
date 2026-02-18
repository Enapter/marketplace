# Lua API HTTP Reference

The `http` module implements communication over [HTTP](https://en.wikipedia.org/wiki/HTTP) protocol.

## `http.get`

```lua
-- @param url string URL of the resource to request
-- @return table|nil, string|nil
function http.get(url)
end
```

Performs a GET request to the specified URL. Returns two values: [`response`](#response-object) and `error`. When performing request failed (e.g. network timeout) `error` will contain _non-nil_ string. If any response is obtained, `error` will be _nil_ regardless of the HTTP response code.

Uses default client (the one with the default values of all [options](#client-options)), to make a request with custom client use [`http.client()`](#httpclient).

To make a request with custom headers use [`http.request()`](#httprequest) and [`client:do_request()`](#clientdo_request).

#### Example

```lua {1}
local response, err = http.get('https://enapter.com')
if err ~= nil then
  enapter.log('Cannot do request: ' .. err, 'error')
elseif response.code ~= 200 then
  enapter.log('Request returned non-OK code: ' .. response.code, 'error')
else
  enapter.log('Request succeeded: ' .. response.body)
end
```

## `http.post`

```lua
-- @param url string URL of the resource to request
-- @param content_type string The value of Content-Type request header
-- @post body string Request body
-- @return table|nil, string|nil
function http.post(url, content_type, body)
end
```

Performs a POST request to the specified URL. Returns two values: [`response`](#response-object) and `error`. When performing request failed (e.g. network timeout) `error` will contain _non-nil_ string. If any response is obtained, `error` will be _nil_ regardless of the HTTP response code.

`content_type` should contain the value of Content-Type request header that represents the kind of data contained in request `body`, e.g. `application/json`.

Uses default client (the one with the default values of all [options](#client-options)), to make a request with custom client use [`http.client()`](#httpclient).

To make a request with custom headers, use [`http.request()`](#httprequest) and [`client:do_request()`](#clientdo_request).

#### Example

```lua {2}
local json_body = '{ "query": "Enapter" }'
local response, err = http.post('https://enapter.com', 'application/json', json_body)
if err ~= nil then
  enapter.log('Cannot do request: ' .. err, 'error')
elseif response.code ~= 200 then
  enapter.log('Request returned non-OK code: ' .. response.code, 'error')
else
  enapter.log('Request succeeded: ' .. response.body)
end
```

## `http.post_form`

```lua
-- @param url string URL of the resource to request
-- @post form_data table Form data
-- @return table|nil, string|nil
function http.post_form(url, form_data)
end
```

Performs a POST request to the specified URL with data keys and values URL-encoded as the request body. Returns two values: [`response`](#response-object) and `error`. When performing request failed (e.g. network timeout) `error` will contain _non-nil_ string. If any response is obtained, `error` will be _nil_ regardless of the HTTP response code.

The Content-Type header is set to `application/x-www-form-urlencoded`.

Uses default client (the one with the default values of all [options](#client-options)), to make a request with custom client use [`http.client()`](#httpclient).

To make a request with custom headers, use [`http.request()`](#httprequest) and [`client:do_request()`](#clientdo_request).

<!-- FIXME: URL-encoding rules -->

#### Example

```lua {1}
local response, err = http.post_form('https://enapter.com', { query = 'Enapter' })
if err ~= nil then
  enapter.log('Cannot do request: ' .. err, 'error')
elseif response.code ~= 200 then
  enapter.log('Request returned non-OK code: ' .. response.code, 'error')
else
  enapter.log('Request succeeded: ' .. response.body)
end
```

## `http.client`

```lua
-- @param options table HTTP client options
-- @return table HTTP client
function http.client(options)
end
```

Creates a new HTTP [`client`](#client-object) instance with the given options.

### Supported Options {#client-options}

Name | Description | Default
---|---|---
`insecure_tls` | _optional_, disables TLS host verification, usable when it's impossible to properly verify the host certificate | `false`
`enable_cookie_jar` | _optional_, enables cookie jar that stores all inbound cookies and automatically inserts it into every outbound request | `false`
`timeout` | _optional_, request timeout in seconds | `10`

#### Example

```lua {1}
local client = http.client({
  insecure_tls = true,
  enable_cookie_jar = true,
  timeout = 10
})

local response, err = client:get('https://enapter.com')
if err ~= nil then
  enapter.log('Cannot do request: ' .. err, 'error')
else
  enapter.log('Response code: ' .. response.code)
end
```

## `client` Object

### `client:get`

```lua
-- @param url string URL of the resource to request
-- @return table|nil, string|nil
function client:get(url)
end
```

Performs a GET request to the specified URL. Returns two values: [`response`](#response-object) and `error`. When performing request failed (e.g. network timeout) `error` will contain _non-nil_ string. If any response is obtained, `error` will be _nil_ regardless of the HTTP response code.

To make a request with custom headers, use [`http.request()`](#httprequest) and [`client:do_request()`](#clientdo_request).

#### Example

```lua {1}
local response, err = client:get('https://enapter.com')
if err ~= nil then
  enapter.log('Cannot do request: ' .. err, 'error')
elseif response.code ~= 200 then
  enapter.log('Request returned non-OK code: ' .. response.code, 'error')
else
  enapter.log('Request succeeded: ' .. response.body)
end
```

### `client:post`

```lua
-- @param url string URL of the resource to request
-- @param content_type string The value of Content-Type request header
-- @post body string Request body
-- @return table|nil, string|nil
function client:post(url, content_type, body)
end
```

Performs a POST request to the specified URL. Returns two values: [`response`](#response-object) and `error`. When performing request failed (e.g. network timeout) `error` will contain _non-nil_ string. If any response is obtained, `error` will be _nil_ regardless of the HTTP response code.

`content_type` should contain the value of Content-Type request header that represents the kind of data contained in request `body`, e.g. `application/json`.

To make a request with custom headers, use [`http.request()`](#httprequest) and [`client:do_request()`](#clientdo_request).

#### Example

```lua {2}
local json_body = '{ "query": "Enapter" }'
local response, err = client:post('https://enapter.com', 'application/json', json_body)
if err ~= nil then
  enapter.log('Cannot do request: ' .. err, 'error')
elseif response.code ~= 200 then
  enapter.log('Request returned non-OK code: ' .. response.code, 'error')
else
  enapter.log('Request succeeded: ' .. response.body)
end
```

### `client:post_form`

```lua
-- @param url string URL of the resource to request
-- @post form_data table Form data
-- @return table|nil, string|nil
function client:post_form(url, form_data)
end
```

Performs a POST request to the specified URL with data keys and values URL-encoded as the request body. Returns two values: [`response`](#response-object) and `error`. When performing request failed (e.g. network timeout) `error` will contain _non-nil_ string. If any response is obtained, `error` will be _nil_ regardless of the HTTP response code.

The Content-Type header is set to `application/x-www-form-urlencoded`.

To make a request with custom headers, use [`http.request()`](#httprequest) and [`client:do_request()`](#clientdo_request).

<!-- FIXME: URL-encoding rules -->

#### Example

```lua {1}
local response, err = client:post_form('https://enapter.com', { query = 'Enapter' })
if err ~= nil then
  enapter.log('Cannot do request: ' .. err, 'error')
elseif response.code ~= 200 then
  enapter.log('Request returned non-OK code: ' .. response.code, 'error')
else
  enapter.log('Request succeeded: ' .. response.body)
end
```

### `client:do_request`

```lua
-- @param request table Request object
-- @return table|nil, string|nil
function client:do_request(request)
end
```

Performs a HTTP request using the provided [`request`](#request-object) object. Returns two values: [`response`](#response-object) and `error`. When performing request failed (e.g. network timeout) `error` will contain _non-nil_ string. If any response is obtained, `error` will be _nil_ regardless of the HTTP response code.

#### Example

```lua {3}
local request = http.request('GET', 'https://enapter.com')
local client = http.client({ timeout = 5 })
local response, err = client:do_request(request)
if err ~= nil then
  enapter.log('Cannot do request: ' .. err, 'error')
else
  enapter.log('Response code: ' .. response.code)
end
```

## `http.request`

```lua
-- @param method string Request method
-- @param url string URL of the resource to request
-- @param body string Request body
-- @return table Request object
function http.request(method, url, body)
end
```

Creates a new HTTP [`request`](#request-object) instance with the given parameters. Use [`client:do_request()`](#clientdo_request) to send this request for execution.

#### Example

```lua {1}
local request, err = http.request('POST', 'https://enapter.com', '{"query": "test"}')
local client = http.client({ timeout = 5 })
local response, err = client:do_request(request)
if err ~= nil then
  enapter.log('Cannot do request: ' .. err, 'error')
else
  enapter.log('Response code: ' .. response.code)
end
```

## `request` Object

### `request:set_basic_auth`

```lua
-- @param username string
-- @param password string
function request:set_basic_auth(username, password)
end
```

Sets request Authorization header to use HTTP Basic Authentication with the provided username and password.

#### Example

```lua {2}
local request, err = http.request('GET', 'https://enapter.com')
request:set_basic_auth('myuser', 'mypass')
```

### `request:set_header`

```lua
-- @param name string
-- @param value string
function request:set_header(name, value)
end
```

Sets the header entries associated with key to the single element value. It replaces any existing values associated with the key.

```lua {2}
local request, err = http.request('GET', 'https://enapter.com')
request:set_header('Content-Type', 'application/json')
```

### `request:add_cookie`

```lua
-- @param name string
-- @param value string
function request:add_cookie(name, value)
end
```

Adds a cookie to the request. It does not attach more than one Cookie header field. It does not override any cookie with the same name. That means all cookies, if any, are added into the same header line, separated with comma.

#### Example

```lua {2-4}
local request, err = http.request('GET', 'https://enapter.com')
request:add_cookie('_auth', 'aabbccdd-eeffeeff')
request:add_cookie('name', 'value')
request:add_cookie('name', 'value2')
```

The code above adds the following header to the request:

```http
Cookie: _auth=aabbccdd-eeffeeff; name=value; name=value2
```

## `response` Object

Response object is the value returned from [`client:get()`](#clientget), [`client:post()`](#clientpost), and similar functions.

### `response.code`

```lua
-- string
response.code
```

Holds the response HTTP code.

#### Example

```lua {4-5}
local response, err = http.get('https://enapter.com')
if err ~= nil then
  enapter.log('Cannot do request: ' .. err, 'error')
elseif response.code ~= 200 then
  enapter.log('Non-OK response: ' .. response.code)
else
  enapter.log('Response OK')
end
```

### `response.body`

```lua
-- string
response.body
```

Holds the whole response body as a string.

#### Example

```lua {5}
local response, err = http.get('https://enapter.com')
if err ~= nil then
  enapter.log('Cannot do request: ' .. err, 'error')
else
  enapter.log('Response body: ' .. response.body)
end
```

### `response.headers`

```lua
-- table
response.headers
```

Holds response headers as a table (key-value pairs). Header names are table keys. Table values contain a lists of header value entries, because every header can have multiple values associated with it (separated with comma in a raw response).

Use [`response.headers:get()`](#responseheadersget) if you need only first value entry.

#### Examples

Given the following HTTP response:

```http
Content-Type: application/json; charset=UTF-8
```

`response.headers['Content-Type']` will contain two entries:

```lua
response.headers['Content-Type'][1] == 'application/json'
response.headers['Content-Type'][2] == 'charset=UTF-8'
```

```lua {6}
local response, err = http.get('https://enapter.com')
if err ~= nil then
  enapter.log('Cannot do request: ' .. err, 'error')
else
  enapter.log('Response headers:')
  for name, values in pairs(response.headers) do
    -- Note that `values` are Lua table with header value entries
    enapter.log(name .. ': ' .. inspect(values))
  end
end
```

#### `response.headers:get`

```lua
-- @param name string
-- @return string Value of the first header value entry
function response.headers:get(name)
end
```

Returns the first header value entry by the given header name.

##### Example

```lua {5}
local response, err = http.get('https://enapter.com')
if err ~= nil then
  enapter.log('Cannot do request: ' .. err, 'error')
else
  local content_type = response.headers:get('Content-Type')
  if content_type == 'application/json' then
    enapter.log('Content-Type is JSON')
  else
    enapter.log('Content-Type: ' .. content_type)
  end
end
```

#### `response.headers:values`

```lua
-- @param name string
-- @return table All header value entries
function response.headers:values(name)
end
```

Returns all header value entries by the given header name.

##### Example

```lua {5}
local response, err = http.get('https://enapter.com')
if err ~= nil then
  enapter.log('Cannot do request: ' .. err, 'error')
else
  local cache_control_values = response.headers:values('Cache-Control')
  enapter.log('Cache-Control values:')
  for index, value in pairs(cache_control_values) do
    enapter.log(value)
  end
end
```

### `response.cookies`

```lua
-- table
response.cookies
```

Holds response cookies as a table (list). The table contains [`cookie`](#cookie-object) objects.

#### Example

```lua {5}
local response, err = http.get('https://enapter.com')
if err ~= nil then
  enapter.log('Cannot do request: ' .. err, 'error')
else
  for index, cookie in pairs(response.cookies) do
    if cookie.name == '_session_id' then
      enapter.log('Session ID: ' .. cookie.value .. ', expires at ' .. cookie.expires)
    end
  end
end
```

### `cookie` Object

Cookie objects are contained in [`response.cookies`](#responsecookies) list.

Field | Description
---|---
`cookie.name` | _string_, cookie name
`cookie.value` | _string_, cookie value
`cookie.expires` | _string_, cookie expiration date

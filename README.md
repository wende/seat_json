# SeatJson

Simple API testing DSL for Elixir/Phoenix, with Guardian integration

## Prerequirements
```elixir
defmodule MyApp.ApiTest do
  use ExUnit.Case, async: false
  use MyApp.ConnCase
  use SeatJson
  
  # YOUR TESTS GO HERE
end
```

## Example
```elixir
api :get, "/api/test",                                returns: {200, %{"test" => "ok"}} 
api :post, "/api/nonexistent",                        returns: {404, %{}} 
api :post, "/api/test/", [params: %{"test" => "ok"}], returns: {200, %{"test" => "ok"}} 
```

#### More advanced tests

```elixir
api :get, "api/for_users_only", [as: :none],    returns: {401, %{}} 
api :get, "api/for_users_only", [as: :default], returns: {200, %{}} 
api :get, "api/for_users_only", [as: :admin],   returns: {200, %{}} 
```

#### Authenthication example
```elixir
def insert_new_user(login, password) do
  Database.insert_user(login, password)
end

@tag call_before: {:insert_new_user, ["login", "password"]}
api :post, "/auth/login", [
  as: :none,
  info: "Allows user to log in",
  params:
  %{
    "email" => "email@example.com,
    "password" => "somepassword",
    "password_confirmation" => "somepassword",
    "name" => "Krzysztof Wende",
  }
],
returns: {200, %{"user" => %{"email" => _, "inserted_at" => _, "name" => _}}} 
```

## Documentation
### Use SeatJson
```elixir 
use SeatJson
```
`SeatJson.__using__/1` takes one parameter `auth: fn {tag, auth}`
Where `tag` is whatever atom You'd like to use, and auth is Guardian object
This macro maps to
`Guardian.Plug.sign_in(conn, auth.user, :token, perms: %{default: Guardian.Permissions.available(level)})`
If you don't provide `:auth` you can't use authenthication

###  api/4
```elixir
macro api(method, url, opts \\ [], returns: match, guards: assertion)
```
Arguments:

- `method` - HTTP method to use: :get, :post, :put, :delete, :patch etc
- `url` - Realtive or absolute path to use ex: `api/some/path/to/my/project`
- `opts`
  - `paramteres` - Map of parameters passed in body, ex: `%{test: my_api}`
  - `as` - Authenthication level of the api call, default: `:none`
  - `info` - Additional info about the test to be displayed
- `returns` - Tuple of status code and match map of the returned JSON, ex: `{200, %{"success" : true}}` remember that all of the keys must be strings, not atoms. If the map is left blank, the page won't be parsed
- `guards` - Additional checks for the returns, example:
```elixir
  ...
  returns: %{"test" => value},
  guards: value > 10 and value < 20
  )
```
## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed as:

  1. Add seat_json to your list of dependencies in `mix.exs`:

        def deps do
          [{:seat_json, "~> 0.0.1"}]
        end

  2. Ensure seat_json is started before your application:

        def application do
          [applications: [:seat_json]]
        end


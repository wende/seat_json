defmodule SeatJson do
  use ExUnit.CaseTemplate
  using auth: auth
    do quote do
      require ApiHelper
      import ApiHelper, only: [api: 3, check_call_before: 1]

      setup context do
        context = context
        |> unquote(auth).()
        |> check_call_before
        {:ok, context}
      end
    end
  end
  def check_call_before(%{call_before: {name, params}} = context) do
    apply(__MODULE__, name, params)
    context
  end
  def check_call_before(context), do: context

  def test_api(opts \\ [], auth, conn, ep)
  def test_api([headers: headers, params: p, body_params: bp], auth, conn, ep) do
    response = conn |> send_request(headers, p, bp, auth, ep)
     ## Check the body only if the page exists, otherwise Phoenix informs not existing entry in HTML
    {response.status, (unless response.status == 404, do: (Poison.decode! response.resp_body), else: %{})}
  end
  def test_api(opts, auth, conn, ep) do
    test_api [
      headers: opts[:headers] || [],
      params: opts[:params] || %{},
      body_params: opts[:body_params] || %{}
    ], auth, conn, ep
  end

  def parse(conn, opts \\ []) do
    opts = Keyword.put_new(opts, :parsers, [Plug.Parsers.URLENCODED, Plug.Parsers.MULTIPART])
    Plug.Parsers.call(conn, Plug.Parsers.init(opts))
  end
  defp send_request(conn, headers, params, body_params, auth, ep) do
    conn
    |> with_session
    |> with_auth(auth)
    |> with_headers(headers)
    |> with_params(params, body_params)
    |> ep.call([])
  end

  def with_auth(conn, {:none, _}), do: conn
  def with_auth(conn, {level, auth}) do
    conn
    |> Guardian.Plug.sign_in(auth.user, :token, perms: %{default: Guardian.Permissions.available(level)})
  end 

  def with_headers(conn, headers) do
    Enum.reduce headers, conn, fn {k, v}, conn -> ConnCase.put_req_header(conn, k, v) end
  end
  def with_params(conn, params, body_params) do
    parse(%{conn | body_params: body_params, params: params})
  end
  def with_session(conn) do
    session_opts = Plug.Session.init(store: :cookie, key: "_app",
                                     encryption_salt: "abc", signing_salt: "abc")
    conn
    |> Map.put(:secret_key_base, String.duplicate("abcdefgh", 8))
    |> Plug.Session.call(session_opts)
    |> Plug.Conn.fetch_session()
    |> Plug.Conn.fetch_query_params()
  end
  defmacro api(method, url, opts \\ [], returns: return) do
    Agent.start_link(fn -> 0 end, name: :counter)
    counter = Agent.get_and_update :counter, fn a -> {a, a+1} end
    method = to_string(method) |> String.upcase
    tag = opts[:as] || :none
    info = opts[:info]
    quote do
      @tag as: unquote(tag)
      test "API - #{unquote(method)} #{unquote(url)} as #{unquote(tag)} ##{unquote(counter)} #{unquote(info) || ""}", meta do
        result = ApiHelper.test_api(unquote(opts), meta[:auth] || {:none, nil}, conn(unquote(method), unquote(url)), @endpoint)
        try do
          (fn unquote(return) -> true end).(result)
        rescue
          FunctionClauseError -> raise "Got #{inspect(result, [pretty: true])}"
        end
      end
    end
  end
end

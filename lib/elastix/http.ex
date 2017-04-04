defmodule Elastix.HTTP do
  @moduledoc """
  """
  use HTTPoison.Base

  @doc false
  def process_url(url) do
    url
  end

  @doc false
  def request(method, url, body \\ "", headers \\ [], options \\ []) do
    query_url = if Keyword.has_key?(options, :params) do
      url <> "?" <> URI.encode_query(options[:params])
    else
      url
    end
    full_url = process_url(to_string(query_url))
    body = process_request_body(body)

    username = Elastix.config(:username)
    password = Elastix.config(:password)

    content_headers = headers
    |> Keyword.put_new(:"Content-Type", "application/json; charset=UTF-8")
    |> Keyword.put_new(:"Accept-Encoding", "gzip")

    full_headers = if Elastix.config(:shield) do
      Keyword.put(content_headers, :"Authorization", "Basic " <> Base.encode64("#{username}:#{password}"))
    else
      content_headers
    end

    options = Keyword.merge(default_httpoison_options(), options)
    {ok_err, http_resp} =
      HTTPoison.Base.request(
        __MODULE__,
        method,
        full_url,
        body,
        full_headers,
        options,
        &process_status_code/1,
        &process_headers/1,
        & &1)

    body = process_response_body http_resp.body, http_resp.headers

    {ok_err, %{http_resp | body: body}}
  end

  @doc false
  def process_response_body("", _), do: ""
  def process_response_body(body, headers) do
    body =
      case :proplists.lookup("Content-Encoding", headers) do
        {"Content-Encoding", "gzip"} -> :zlib.gunzip body
        _                            -> body
      end

    try do
      body |> to_string |> :jiffy.decode(jiffy_options())
    catch
      {:error, _} -> body
    end
  end

  defp jiffy_options do
    Elastix.config(:jiffy_options, [:return_maps, :use_nil])
  end

  defp default_httpoison_options do
    Elastix.config(:httpoison_options, [])
  end
end

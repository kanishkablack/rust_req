defmodule RustReq do
  @moduledoc """
  High-performance HTTP client using Rust NIFs for making external service calls at scale.

  This module provides both synchronous and asynchronous HTTP operations with support for:
  - GET and POST requests
  - Custom headers
  - Configurable timeouts
  - Proxy support
  - Redirect handling
  - Batch concurrent requests

  ## Examples

      # Simple GET request
      {:ok, {status, headers, body}} = RustReq.get("https://api.example.com/data")

      # GET with custom headers and options
      headers = [{"Authorization", "Bearer token123"}]
      options = %RustReq.Options{timeout_ms: 5000}
      {:ok, {status, headers, body}} = RustReq.get("https://api.example.com/data", headers, options)

      # POST with JSON body
      headers = [{"Content-Type", "application/json"}]
      body = Jason.encode!(%{name: "test"})
      {:ok, {status, headers, body}} = RustReq.post("https://api.example.com/users", headers, body)

      # Batch GET requests (concurrent)
      urls = ["https://api.example.com/1", "https://api.example.com/2"]
      results = RustReq.get_batch(urls)
  """

  alias RustReq.Native

  defmodule Options do
    @moduledoc """
    HTTP request options.

    ## Fields
    - `timeout_ms`: Request timeout in milliseconds (default: 30000)
    - `proxy`: Proxy URL (e.g., "http://proxy.example.com:8080")
    - `follow_redirects`: Whether to follow redirects (default: true)
    - `max_redirects`: Maximum number of redirects to follow (default: 10)
    """
    defstruct timeout_ms: 30_000,
              proxy: nil,
              follow_redirects: true,
              max_redirects: 10

    @type t :: %__MODULE__{
            timeout_ms: non_neg_integer() | nil,
            proxy: String.t() | nil,
            follow_redirects: boolean() | nil,
            max_redirects: non_neg_integer() | nil
          }
  end

  @doc """
  Performs a synchronous HTTP GET request.

  ## Parameters
  - `url`: The URL to request
  - `headers`: List of tuples for request headers (default: [])
  - `options`: RustReq.Options struct (default: %Options{})

  ## Returns
  - `{:ok, {status, headers, body}}` on success
  - `{:error, reason}` on failure

  ## Examples

      RustReq.get("https://api.example.com/data")
      RustReq.get("https://api.example.com/data", [{"Authorization", "Bearer token"}])
      RustReq.get("https://api.example.com/data", [], %RustReq.Options{timeout_ms: 5000})
  """
  @spec get(String.t(), keyword() | list(), Options.t()) ::
          {:ok, {non_neg_integer(), list({String.t(), String.t()}), String.t()}}
          | {:error, term()}
  def get(url, headers \\ [], options \\ %Options{}) do
    Native.http_get(url, normalize_headers(headers), options)
  catch
    :error, reason -> {:error, reason}
  end

  @doc """
  Performs a synchronous HTTP POST request.

  ## Parameters
  - `url`: The URL to request
  - `headers`: List of tuples for request headers (default: [])
  - `body`: Request body as string
  - `options`: RustReq.Options struct (default: %Options{})

  ## Returns
  - `{:ok, {status, headers, body}}` on success
  - `{:error, reason}` on failure

  ## Examples

      RustReq.post("https://api.example.com/users", [], ~s({"name":"John"}))
      RustReq.post("https://api.example.com/users", [{"Content-Type", "application/json"}], body)
  """
  @spec post(String.t(), keyword() | list(), String.t(), Options.t()) ::
          {:ok, {non_neg_integer(), list({String.t(), String.t()}), String.t()}}
          | {:error, term()}
  def post(url, headers \\ [], body, options \\ %Options{}) do
    Native.http_post(url, normalize_headers(headers), body, options)
  catch
    :error, reason -> {:error, reason}
  end

  @doc """
  Performs an asynchronous HTTP GET request (uses Tokio runtime internally).

  This is useful when making a single request but you want the Rust async runtime
  to handle it efficiently.

  ## Parameters
  - Same as `get/3`

  ## Examples

      RustReq.get_async("https://api.example.com/data")
  """
  @spec get_async(String.t(), keyword() | list(), Options.t()) ::
          {:ok, {non_neg_integer(), list({String.t(), String.t()}), String.t()}}
          | {:error, term()}
  def get_async(url, headers \\ [], options \\ %Options{}) do
    Native.http_get_async(url, normalize_headers(headers), options)
  catch
    :error, reason -> {:error, reason}
  end

  @doc """
  Performs an asynchronous HTTP POST request.

  ## Parameters
  - Same as `post/4`

  ## Examples

      RustReq.post_async("https://api.example.com/users", [], body)
  """
  @spec post_async(String.t(), keyword() | list(), String.t(), Options.t()) ::
          {:ok, {non_neg_integer(), list({String.t(), String.t()}), String.t()}}
          | {:error, term()}
  def post_async(url, headers \\ [], body, options \\ %Options{}) do
    Native.http_post_async(url, normalize_headers(headers), body, options)
  catch
    :error, reason -> {:error, reason}
  end

  @doc """
  Performs multiple HTTP GET requests concurrently.

  This is the most efficient way to make many requests at scale, as all requests
  are executed in parallel using Tokio's async runtime.

  ## Parameters
  - `urls`: List of URLs to request
  - `headers`: Headers to apply to all requests (default: [])
  - `options`: Options to apply to all requests (default: %Options{})

  ## Returns
  A list of results, where each result is either:
  - `{:ok, {status, headers, body}}`
  - `{:error, reason}`

  ## Examples

      urls = ["https://api.example.com/1", "https://api.example.com/2"]
      results = RustReq.get_batch(urls)

      Enum.each(results, fn
        {:ok, {status, _headers, body}} ->
          IO.puts("Success: \#{status}")
        {:error, reason} ->
          IO.puts("Error: \#{reason}")
      end)
  """
  @spec get_batch(list(String.t()), keyword() | list(), Options.t()) :: list()
  def get_batch(urls, headers \\ [], options \\ %Options{}) do
    case Native.http_get_batch(urls, normalize_headers(headers), options) do
      results when is_list(results) ->
        Enum.map(results, fn
          {:ok, {status, headers, body}} -> {:ok, {status, headers, body}}
          {:error, reason} -> {:error, reason}
        end)

      error ->
        {:error, error}
    end
  catch
    :error, reason -> {:error, reason}
  end

  # Normalize headers from keyword list or list of tuples to list of string tuples
  defp normalize_headers(headers) when is_list(headers) do
    Enum.map(headers, fn
      {k, v} when is_binary(k) and is_binary(v) -> {k, v}
      {k, v} when is_atom(k) -> {Atom.to_string(k), to_string(v)}
      {k, v} -> {to_string(k), to_string(v)}
    end)
  end
end

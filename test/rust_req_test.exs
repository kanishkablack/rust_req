defmodule RustReqTest do
  use ExUnit.Case
  doctest RustReq

  @moduletag :external

  describe "HTTP GET" do
    test "successful GET request" do
      case RustReq.get("https://httpbin.org/get") do
        {:ok, {status, _headers, body}} ->
          assert status == 200
          assert is_binary(body)
          assert String.contains?(body, "httpbin")

        {:error, reason} ->
          flunk("Request failed: #{inspect(reason)}")
      end
    end

    test "GET with custom headers" do
      headers = [{"User-Agent", "RustReq/0.1.0"}]

      case RustReq.get("https://httpbin.org/headers", headers) do
        {:ok, {status, _headers, body}} ->
          assert status == 200
          assert String.contains?(body, "RustReq")

        {:error, reason} ->
          flunk("Request failed: #{inspect(reason)}")
      end
    end

    test "GET with timeout option" do
      options = %RustReq.Options{timeout_ms: 5000}

      case RustReq.get("https://httpbin.org/delay/1", [], options) do
        {:ok, {status, _headers, _body}} ->
          assert status == 200

        {:error, reason} ->
          flunk("Request failed: #{inspect(reason)}")
      end
    end

    test "GET timeout error" do
      options = %RustReq.Options{timeout_ms: 100}

      case RustReq.get("https://httpbin.org/delay/10", [], options) do
        {:ok, _} ->
          flunk("Expected timeout error")

        {:error, :timeout} ->
          assert true

        {:error, _reason} ->
          # Also acceptable, as connection might fail differently
          assert true
      end
    end
  end

  describe "HTTP POST" do
    test "successful POST request" do
      headers = [{"Content-Type", "application/json"}]
      body = ~s({"name":"test","value":123})

      case RustReq.post("https://httpbin.org/post", headers, body) do
        {:ok, {status, _headers, response_body}} ->
          assert status == 200
          assert String.contains?(response_body, "test")

        {:error, reason} ->
          flunk("Request failed: #{inspect(reason)}")
      end
    end

    test "POST with custom headers" do
      headers = [
        {"Content-Type", "application/json"},
        {"X-Custom-Header", "custom-value"}
      ]

      body = ~s({"data":"value"})

      case RustReq.post("https://httpbin.org/post", headers, body) do
        {:ok, {status, _headers, response_body}} ->
          assert status == 200
          assert String.contains?(response_body, "custom-value")

        {:error, reason} ->
          flunk("Request failed: #{inspect(reason)}")
      end
    end
  end

  describe "Async operations" do
    test "async GET request" do
      case RustReq.get_async("https://httpbin.org/get") do
        {:ok, {status, _headers, body}} ->
          assert status == 200
          assert is_binary(body)

        {:error, reason} ->
          flunk("Request failed: #{inspect(reason)}")
      end
    end

    test "async POST request" do
      headers = [{"Content-Type", "application/json"}]
      body = ~s({"async":"test"})

      case RustReq.post_async("https://httpbin.org/post", headers, body) do
        {:ok, {status, _headers, response_body}} ->
          assert status == 200
          assert String.contains?(response_body, "async")

        {:error, reason} ->
          flunk("Request failed: #{inspect(reason)}")
      end
    end
  end

  describe "Batch operations" do
    test "batch GET requests" do
      urls = [
        "https://httpbin.org/get?id=1",
        "https://httpbin.org/get?id=2",
        "https://httpbin.org/get?id=3"
      ]

      results = RustReq.get_batch(urls)

      assert length(results) == 3

      successful_results =
        Enum.filter(results, fn
          {:ok, {200, _headers, _body}} -> true
          _ -> false
        end)

      # At least some requests should succeed
      assert length(successful_results) > 0
    end

    test "batch GET with custom headers" do
      urls = [
        "https://httpbin.org/headers",
        "https://httpbin.org/user-agent"
      ]

      headers = [{"User-Agent", "RustReq-Batch/0.1.0"}]
      results = RustReq.get_batch(urls, headers)

      assert length(results) == 2
    end
  end

  describe "Error handling" do
    test "invalid URL" do
      case RustReq.get("not-a-valid-url") do
        {:ok, _} ->
          flunk("Expected error for invalid URL")

        {:error, _reason} ->
          assert true
      end
    end

    test "non-existent domain" do
      case RustReq.get("https://this-domain-definitely-does-not-exist-12345.com") do
        {:ok, _} ->
          flunk("Expected error for non-existent domain")

        {:error, _reason} ->
          assert true
      end
    end
  end

  describe "Options" do
    test "default options" do
      opts = %RustReq.Options{}
      assert opts.timeout_ms == 30_000
      assert opts.follow_redirects == true
      assert opts.max_redirects == 10
      assert opts.proxy == nil
    end

    test "custom timeout" do
      opts = %RustReq.Options{timeout_ms: 5000}

      case RustReq.get("https://httpbin.org/get", [], opts) do
        {:ok, {status, _headers, _body}} ->
          assert status == 200

        {:error, reason} ->
          flunk("Request failed: #{inspect(reason)}")
      end
    end

    test "disable redirects" do
      opts = %RustReq.Options{follow_redirects: false}

      # httpbin.org/redirect/1 returns a 302 redirect
      case RustReq.get("https://httpbin.org/redirect/1", [], opts) do
        {:ok, {status, _headers, _body}} ->
          # Should get redirect status code, not the final page
          assert status in [301, 302, 303, 307, 308]

        {:error, reason} ->
          flunk("Request failed: #{inspect(reason)}")
      end
    end
  end
end

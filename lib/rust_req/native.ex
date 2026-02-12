defmodule RustReq.Native do
  @moduledoc false

  version = Mix.Project.config()[:version]

  use RustlerPrecompiled,
    otp_app: :rust_req,
    crate: "rust_req_nif",
    base_url:
      "https://github.com/kanishkablack/rust_req/releases/download/v#{version}/",
    force_build: System.get_env("RUST_REQ_BUILD") in ["1", "true"],
    version: version,
    targets: ~w(
      aarch64-apple-darwin
      x86_64-apple-darwin
      x86_64-unknown-linux-gnu
      x86_64-unknown-linux-musl
      arm-unknown-linux-gnueabihf
    )

  # Synchronous operations
  def http_get(_url, _headers, _options), do: :erlang.nif_error(:nif_not_loaded)
  def http_post(_url, _headers, _body, _options), do: :erlang.nif_error(:nif_not_loaded)

  # Async operations
  def http_get_async(_url, _headers, _options), do: :erlang.nif_error(:nif_not_loaded)
  def http_post_async(_url, _headers, _body, _options), do: :erlang.nif_error(:nif_not_loaded)

  # Batch operations
  def http_get_batch(_urls, _headers, _options), do: :erlang.nif_error(:nif_not_loaded)
end

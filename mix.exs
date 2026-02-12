defmodule RustReq.MixProject do
  use Mix.Project

  @version "0.2.5"

  def project do
    [
      app: :rust_req,
      version: @version,
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:rustler, ">= 0.0.0"},
      {:rustler_precompiled, "~> 0.8"}
    ]
  end

  defp package do
    [
      files: [
        "lib",
        "native/rust_req_nif/.cargo",
        "native/rust_req_nif/src",
        "native/rust_req_nif/Cargo*",
        "checksum-*.exs",
        ".formatter.exs",
        "mix.exs",
        "README.md"
      ]
    ]
  end
end

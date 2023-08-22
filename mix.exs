defmodule BunnyCdnSigner.MixProject do
  use Mix.Project

  @version "0.1.0"

  def project do
    [
      app: :bunny_cdn_signer,
      name: "Bunny CDN URL Signer",
      description: "Signs URLs for Bunny CDN using v2 token authentication",
      source_url: "https://github.com/ntodd/bunny_cdn_signer",
      version: @version,
      elixir: "~> 1.15",
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
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
    ]
  end

  defp package do
    [
      maintainers: ["Nate Todd"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/ntodd/bunny_cdn_signer"}
    ]
  end
end

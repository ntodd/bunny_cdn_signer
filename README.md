# Bunny CDN Signer

Signs URLs for Bunny CDN using [v2 token
authentication](https://support.bunny.net/hc/en-us/articles/360016055099-How-to-sign-URLs-for-BunnyCDN-Token-Authentication).

The docs can be found at <https://hexdocs.pm/bunny_cdn_signer>.

## Installation

The package can be installed by adding `bunny_cdn_signer` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:bunny_cdn_signer, "~> 0.1.1"}
  ]
end
```

Get your "Url Token Authentication Key" in the Security > Token Authentication
settings for your pull zone. Set it up in your application config

```
config :bunny_cdn_signer, authentication_key: "auth_key_here"
```

**Be sure to keep this secret either with a `dev.secret.exs` file or by using ENV
variables.**

## Usage

Sign a URL to a resource in your pull zone:

```
BunnyCDNSigner.sign_url("https://example.com/file.txt")
```

Create a signed url in the directory format:

```
BunnyCDNSigner.sign_url("https://example.com/file.txt", directory: true)
```

Expiration defaults to 1 hour, but can be configured with the `expiration` option.

Be sure to check the docs for all the available options.

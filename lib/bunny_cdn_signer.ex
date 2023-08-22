defmodule BunnyCDNSigner do
  @moduledoc """
  BunnyCDN signed urls using token authentication.

  See https://support.bunny.net/hc/en-us/articles/360016055099-How-to-sign-URLs-for-BunnyCDN-Token-Authentication for more information.
  """

  @doc """
  Signs a URL with the given parameters.

  ## Parameters

  * `url` - The URL to sign
  * `opts` - A keyword list of options
    * `:user_ip` - The user's IP address
    * `:expiration` - The number of seconds until the token expires, defaults to 3,600 (1 hour)
    * `:directory` - Whether the URL is a directory (defaults to false)
    * `:path_allowed` - The path to allow
    * `:countries_allowed` - A comma-separated list of countries to allow
    * `:countries_blocked` - A comma-separated list of countries to block

  ## Examples

      sign_url("https://example.com/test.mp4")
      "https://...?token=...&expires=..."

      sign_url("https://example.com/test.mp4", directory: true)
      "https://.../bcdn_token=...&expires=.../test.mp4"

  """
  def sign_url(url, opts \\ []) do
    authentication_key =
      Application.get_env(:bunny_cdn, :authentication_key) ||
        raise "Bunny CDN authentication_key not set in Application config"

    user_ip = Keyword.get(opts, :user_ip, "")
    expiration_time = Keyword.get(opts, :expiration, 3600)
    is_directory = Keyword.get(opts, :directory, false)
    path_allowed = Keyword.get(opts, :path_allowed, "")
    countries_allowed = Keyword.get(opts, :countries_allowed, "")
    countries_blocked = Keyword.get(opts, :countries_blocked, "")

    expires = :os.system_time(:second) + expiration_time
    url = add_countries(url, countries_allowed, countries_blocked)

    {signature_path, parameter_data} = process_parameters(url, path_allowed)
    hashable_base = "#{authentication_key}#{signature_path}#{expires}#{user_ip}#{parameter_data}"

    token =
      :crypto.hash(:sha256, hashable_base)
      |> Base.encode64()
      |> String.replace("\n", "")
      |> String.replace("+", "-")
      |> String.replace("/", "_")
      |> String.replace("=", "")

    signed_url =
      if is_directory do
        "#{URI.parse(url).scheme}://#{URI.parse(url).host}/bcdn_token=#{token}#{parameter_data}&expires=#{expires}#{URI.parse(url).path}"
      else
        "#{URI.parse(url).scheme}://#{URI.parse(url).host}#{URI.parse(url).path}?token=#{token}#{parameter_data}&expires=#{expires}"
      end

    signed_url
  end

  defp add_countries(url, countries_allowed, countries_blocked) do
    url =
      if countries_allowed != "",
        do:
          "#{url}#{if URI.parse(url).query == nil, do: "?", else: "&"}token_countries=#{countries_allowed}",
        else: url

    url =
      if countries_blocked != "",
        do:
          "#{url}#{if URI.parse(url).query == nil, do: "?", else: "&"}token_countries_blocked=#{countries_blocked}",
        else: url

    url
  end

  defp process_parameters(url, path_allowed) do
    parsed_url = URI.parse(url)
    parameters = URI.decode_query(parsed_url.query || "")

    signature_path =
      if path_allowed != "",
        do: path_allowed,
        else: URI.decode(parsed_url.path)

    parameter_data =
      Enum.sort(parameters) |> Enum.map_join("&", fn {k, v} -> "#{k}=#{URI.encode(v)}" end)

    {signature_path, parameter_data}
  end
end

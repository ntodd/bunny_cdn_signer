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
      Application.get_env(:bunny_cdn_signer, :authentication_key) ||
        raise "Bunny CDN authentication_key not set in Application config"

    user_ip = Keyword.get(opts, :user_ip, "")
    expiration_time = Keyword.get(opts, :expiration, 3600)
    is_directory = Keyword.get(opts, :directory, false)
    path_allowed = Keyword.get(opts, :path_allowed, "")
    countries_allowed = Keyword.get(opts, :countries_allowed, "")
    countries_blocked = Keyword.get(opts, :countries_blocked, "")
    expires = :os.system_time(:second) + expiration_time

    # Parse the url into a URI and add the countries to the query params if they are provided
    uri =
      url
      |> URI.parse()
      |> maybe_put_countries_allowed(countries_allowed)
      |> maybe_put_countries_blocked(countries_blocked)
      |> maybe_put_token_path(path_allowed)

    # Process the parameters to get the signature path and parameter data
    {signature_path, parameter_data} = process_parameters(uri, path_allowed)

    # Generate the token
    token = generate_token(authentication_key, signature_path, expires, user_ip, parameter_data)

    uri
    |> put_query_param("expires", expires)
    |> put_query_param("token", token)
    |> to_string(is_directory)
  end

  defp generate_token(authentication_key, signature_path, expires, user_ip, parameter_data) do
    hashable_base = "#{authentication_key}#{signature_path}#{expires}#{user_ip}#{parameter_data}"

    :crypto.hash(:sha256, hashable_base)
    |> Base.encode64()
    |> String.replace("\n", "")
    |> String.replace("+", "-")
    |> String.replace("/", "_")
    |> String.replace("=", "")
  end

  defp maybe_put_countries_allowed(%URI{} = uri, countries_allowed) do
    if countries_allowed != "",
      do: put_query_param(uri, "token_countries", countries_allowed),
      else: uri
  end

  defp maybe_put_countries_blocked(%URI{} = uri, countries_blocked) do
    if countries_blocked != "",
      do: put_query_param(uri, "token_countries_blocked", countries_blocked),
      else: uri
  end

  defp maybe_put_token_path(%URI{} = uri, token_path) do
    if token_path != "",
      do: put_query_param(uri, "token_path", token_path),
      else: uri
  end

  defp to_string(%URI{query: nil}, _),
    do: raise("to_string/2 cannot be called with a nil query")

  defp to_string(%URI{} = uri, false), do: URI.to_string(uri)

  defp to_string(%URI{query: query} = uri, true) do
    # Split the query params into cdn_params and user_params
    {cdn_params, user_params} =
      query
      |> URI.decode_query()
      |> Enum.reduce({%{}, %{}}, fn {k, v}, {new_map, remaining_map} ->
        if k in ["token", "expires", "token_path", "token_countries", "token_countries_blocked"] do
          {Map.put(new_map, k, v), remaining_map}
        else
          {new_map, Map.put(remaining_map, k, v)}
        end
      end)

    cdn_query =
      cdn_params
      # Replace the cdn_params "token" query param with "bcdn_token"
      |> Map.put("bcdn_token", Map.get(cdn_params, "token"))
      |> Map.delete("token")
      |> URI.encode_query()

    # Any user query params that were provided
    user_query =
      user_params
      |> URI.encode_query()
      |> then(fn query -> if query == "", do: nil, else: query end)

    uri
    |> Map.put(:path, "/#{cdn_query}#{uri.path}")
    |> Map.put(:query, user_query)
    |> URI.to_string()
  end

  defp process_parameters(%URI{} = uri, path_allowed) do
    parameters = URI.decode_query(uri.query || "")

    signature_path =
      if path_allowed != "",
        do: path_allowed,
        else: URI.decode(uri.path)

    parameter_data =
      Enum.sort(parameters) |> Enum.map_join("&", fn {k, v} -> "#{k}=#{URI.encode(v)}" end)

    {signature_path, parameter_data}
  end

  defp put_query_param(%URI{query: nil} = uri, key, value) do
    %{uri | query: URI.encode_query(%{key => value})}
  end

  defp put_query_param(%URI{query: query} = uri, key, value) do
    query =
      query
      |> URI.decode_query()
      |> Map.merge(%{key => value})
      |> URI.encode_query()

    %{uri | query: query}
  end
end

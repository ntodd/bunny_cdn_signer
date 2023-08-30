defmodule BunnyCDNSignerTest do
  use ExUnit.Case, async: true

  setup do
    Application.put_env(:bunny_cdn_signer, :authentication_key, "test_key")
  end

  describe "sign_url/2" do
    test "returns correct URL without options" do
      signed_url = BunnyCDNSigner.sign_url("https://example.com/test.mp4")
      assert String.contains?(signed_url, "token=")
      assert String.contains?(signed_url, "expires=")
    end

    test "returns correct URL with directory option" do
      signed_url = BunnyCDNSigner.sign_url("https://example.com/test.mp4", directory: true)
      assert String.contains?(signed_url, "/bcdn_token=")
      assert String.contains?(signed_url, "&expires=")
    end

    test "preserves query params on the url" do
      url = "https://example.com/test.mp4?param1=value1&param2=value2"

      signed_url = BunnyCDNSigner.sign_url(url)

      uri = URI.parse(signed_url)
      params = URI.decode_query(uri.query)

      assert uri.scheme <> "://" <> uri.host <> uri.path == "https://example.com/test.mp4"
      assert Map.has_key?(params, "token")
      assert Map.has_key?(params, "expires")
      assert params["param1"] == "value1"
      assert params["param2"] == "value2"
    end

    test "preserves query params on a directory url" do
      url = "https://example.com/test.mp4?param1=value1&param2=value2"

      signed_url = BunnyCDNSigner.sign_url(url, directory: true)

      uri = URI.parse(signed_url)
      params = URI.decode_query(uri.query)

      assert (uri.scheme <> "://" <> uri.host <> uri.path)
             |> String.contains?("https://example.com/bcdn_token=")

      assert params["param1"] == "value1"
      assert params["param2"] == "value2"
    end

    test "correctly signs URL without options" do
      url = "https://example.com/test.mp4"
      expires = :os.system_time(:second) + 3600

      expected_signature_path = "/test.mp4"
      expected_hashable_base = "test_key#{expected_signature_path}#{expires}"

      expected_token = expected_token(expected_hashable_base)

      signed_url = BunnyCDNSigner.sign_url(url)

      assert String.contains?(signed_url, "token=#{expected_token}")
    end

    test "correctly signs URL with options" do
      url = "https://example.com/test.mp4"
      expires = :os.system_time(:second) + 3600

      options = [
        user_ip: "192.168.1.1",
        countries_allowed: "US,CA",
        countries_blocked: "GB"
      ]

      expected_signature_path = "/test.mp4"
      parameter_data = "token_countries=US,CA&token_countries_blocked=GB"

      expected_hashable_base =
        "test_key#{expected_signature_path}#{expires}192.168.1.1#{parameter_data}"

      expected_token = expected_token(expected_hashable_base)

      signed_url = BunnyCDNSigner.sign_url(url, options)

      signed_uri = URI.parse(signed_url)
      params = URI.decode_query(signed_uri.query)

      assert params["token_countries"] == "US,CA"
      assert params["token_countries_blocked"] == "GB"
      assert String.contains?(signed_url, "token=#{expected_token}")
    end

    test "raises error when authentication key is missing" do
      Application.delete_env(:bunny_cdn_signer, :authentication_key)

      assert_raise RuntimeError,
                   "Bunny CDN authentication_key not set in Application config",
                   fn ->
                     BunnyCDNSigner.sign_url("https://example.com/test.mp4")
                   end
    end
  end

  describe "sign_url/2 in directory mode" do
    test "correctly signs URL in directory mode with multiple user query params" do
      url = "https://example.com/test.mp4?user_param1=value1&user_param2=value2"
      expires = :os.system_time(:second) + 3600

      expected_signature_path = "/test.mp4"

      expected_hashable_base =
        "test_key#{expected_signature_path}#{expires}user_param1=value1&user_param2=value2"

      expected_token = expected_token(expected_hashable_base)

      signed_url = BunnyCDNSigner.sign_url(url, directory: true)
      signed_uri = URI.parse(signed_url)
      user_params = URI.decode_query(signed_uri.query)

      assert user_params["user_param1"] == "value1"
      assert user_params["user_param2"] == "value2"
      assert signed_uri.query != nil
      assert String.contains?(signed_url, "/bcdn_token=#{expected_token}&expires=#{expires}")
    end

    test "correctly signs URL in directory mode with all options" do
      url = "https://example.com/test.mp4?user_param=value"

      options = [
        user_ip: "192.168.1.1",
        expiration: 3600,
        countries_allowed: "US,CA",
        countries_blocked: "GB"
      ]

      expires = :os.system_time(:second) + options[:expiration]

      expected_signature_path = "/test.mp4"

      expected_hashable_base =
        "test_key#{expected_signature_path}#{expires}#{options[:user_ip]}token_countries=#{options[:countries_allowed]}&token_countries_blocked=#{options[:countries_blocked]}&user_param=value"

      expected_token = expected_token(expected_hashable_base)

      signed_url = BunnyCDNSigner.sign_url(url, options ++ [directory: true])
      signed_uri = URI.parse(signed_url)
      user_params = URI.decode_query(signed_uri.query)

      assert user_params["user_param"] == "value"
      assert signed_uri.query != nil
      assert String.contains?(signed_url, "/bcdn_token=#{expected_token}&expires=#{expires}")
    end

    test "correctly signs URL in directory mode without any user query params" do
      url = "https://example.com/test.mp4"
      expires = :os.system_time(:second) + 3600
      expected_signature_path = "/test.mp4"

      expected_hashable_base =
        "test_key#{expected_signature_path}#{expires}"

      expected_token = expected_token(expected_hashable_base)

      signed_url = BunnyCDNSigner.sign_url(url, directory: true)
      signed_uri = URI.parse(signed_url)

      assert signed_uri.query == nil
      assert String.contains?(signed_url, "/bcdn_token=#{expected_token}&expires=#{expires}")
    end
  end

  defp expected_token(expected_hashable_base) do
    :crypto.hash(:sha256, expected_hashable_base)
    |> Base.encode64()
    |> String.replace("\n", "")
    |> String.replace("+", "-")
    |> String.replace("/", "_")
    |> String.replace("=", "")
  end
end

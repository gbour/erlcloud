-module(erlcloud_util).
-export([sha_mac/2, sha256_mac/2,
         md5/1, sha256/1]).
-export([port_to_str/1]).
-export([scheme_to_protocol/1, scheme_to_protocol/2]).

sha_mac(K, S) ->
    try
        crypto:hmac(sha, K, S)
    catch
        error:undef ->
            R0 = crypto:hmac_init(sha, K),
            R1 = crypto:hmac_update(R0, S),
            crypto:hmac_final(R1)
    end.
        
sha256_mac(K, S) ->
    try
        crypto:hmac(sha256, K, S)
    catch
        error:undef ->
            R0 = crypto:hmac_init(sha256, K),
            R1 = crypto:hmac_update(R0, S),
            crypto:hmac_final(R1)
    end.

sha256(V) ->
    crypto:hash(sha256, V).

md5(V) ->
    crypto:hash(md5, V).

-spec port_to_str(pos_integer() | string() | undefined) -> string().
port_to_str(Port) when is_integer(Port) ->
    [$:, integer_to_list(Port)];
port_to_str([$: | _] = PortStr) ->
    PortStr;
port_to_str([_ | _] = PortStr) ->
    [$: | PortStr];
port_to_str(_) ->
    "".

-spec scheme_to_protocol(string()) -> string().
scheme_to_protocol(Scheme) ->
    scheme_to_protocol(Scheme, undefined).

-spec scheme_to_protocol(string(), undefined | [string()]) -> string().
scheme_to_protocol(Scheme, AllowedProto) when is_list(Scheme) ->
    LScheme = string:to_lower(Scheme),
    Protocol = case lists:suffix("://", LScheme) of
                   true -> lists:sublist(LScheme, length(LScheme) - 3);
                   false -> LScheme
               end,
    case AllowedProto == undefined orelse (is_list(AllowedProto) andalso lists:member(Protocol, AllowedProto))  of
        true -> Protocol;
        false -> erlang:error({unsupported_scheme, LScheme})
    end.


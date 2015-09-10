%% @author Ransom Richardson <ransom@ransomr.net>
%% @doc
%%
%% HTTP client abstraction for erlcloud. Simplifies changing http clients.
%% API matches lhttpc, except Config is passed instead of options for
%% future cusomizability.
%%
%% @end
-module(erlcloud_httpc).

-include("erlcloud.hrl").
-include("erlcloud_aws.hrl").
-include_lib("fusco/include/fusco.hrl").

-export([request/6, adhoc_request/6]).

-define(DEFAULT_POOL_SIZE, 10).
-define(DEFAULT_POOL_BASE_NAME, "erlcloud_pool_").

-spec request(URL :: string(), Method0 :: atom(), Headers :: [{string() | binary(), string() | binary()}],
              Body :: binary(), Timeout :: non_neg_integer(), Config :: #aws_config{}) ->
    {ok, {{integer(), binary()}, [{binary(), binary()}], binary()}} | {error, atom()}.
request(URL, Method0, Hdrs, Body, Timeout, _Config) ->
    Method = normalise_method(Method0),
    FuscoURL = fusco_lib:parse_url(URL),
    case fusco:request(get_worker(FuscoURL), list_to_binary(FuscoURL#fusco_url.path),
                       Method, normalise_headers(Hdrs), Body, 0, Timeout) of
        {ok, {{Status, StatusLine}, RespHeaders, RespBody, _, _}} ->
            {ok, {{binary_to_integer(Status), StatusLine}, RespHeaders, RespBody}};
        Error ->
            Error
    end.

-spec adhoc_request(BaseURL :: string(), Path :: string(), Method :: string(),
                    Headers :: [{binary(), binary()}], Body :: binary(),
                    Timeout :: non_neg_integer()) ->
    {ok, {{binary(), binary()}, [{binary(), binary()}], binary()}} | {error, atom()}.
adhoc_request(BaseURL, Path, Method, Hdrs, Body, Timeout) ->
    {ok, ConnPid} = fusco:start(BaseURL, []),
    Result = case fusco:request(ConnPid, Path, Method, Hdrs, Body, 0, Timeout) of
                 {ok, {{Status, StatusLine}, RespHeaders, RespBody, _, _}} ->
                     {ok, {{Status, StatusLine}, RespHeaders, RespBody}};
                 Error ->
                     Error
             end,
    fusco:disconnect(ConnPid),
    Result.

-spec get_worker(#fusco_url{}) -> pid().
get_worker(#fusco_url{ host = Host, port = Port, is_ssl = IsSSL }) ->
    PoolName = case get_pool() of
                   undefined -> list_to_atom(?DEFAULT_POOL_BASE_NAME ++ Host);
                   PoolName0 -> PoolName0
               end,
    case ets:info(PoolName) of
        undefined -> new_pool(PoolName, {Host, Port, IsSSL});
        _ -> ok
    end,
    cuesport:get_worker(PoolName).

-spec get_pool() -> atom().
get_pool() ->
    get(aws_pool).

-spec new_pool(PoolName :: atom(), PoolBase :: string()) -> ok.
new_pool(PoolName, PoolBase) ->
    FuscoOpts = [{connect_timeout, 30000}],
    PoolSize = application:get_env(erlcloud, implicit_pool_size, ?DEFAULT_POOL_SIZE),
    ChildMods = [fusco],
    ChildMF = {fusco, start_link},
    already_started_is_ok(
      supervisor:start_child(
        erlcloud_sup,
        {{fusco_sup, PoolName},
         {cuesport, start_link,
          [PoolName, PoolSize, ChildMods, ChildMF, {for_all, [PoolBase, FuscoOpts]}]},
         transient, 2000, supervisor, [cuesport | ChildMods]})).

-spec already_started_is_ok(Result :: {ok, pid()} | {error, {already_started, pid()}}) -> ok.
already_started_is_ok({ok, _Pid}) -> ok;
already_started_is_ok({error, {already_started, _}}) -> ok.

-spec normalise_method(Method :: atom()) -> string().
normalise_method(Method) ->
    string:to_upper(atom_to_list(Method)).

-spec normalise_headers(RawHeaders :: [{binary() | string(), binary() | string()}]) ->
    [{binary(), binary()}].
normalise_headers(Headers) ->
    [ {ensure_binary(Key), ensure_binary(Value)} || {Key, Value} <- Headers ].

-spec ensure_binary(binary() | string()) -> binary().
ensure_binary(Bin) when is_binary(Bin) -> Bin;
ensure_binary(Str) when is_list(Str) -> list_to_binary(Str).


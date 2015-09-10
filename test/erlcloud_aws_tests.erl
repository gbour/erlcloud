-module(erlcloud_aws_tests).
-include_lib("eunit/include/eunit.hrl").
-include("erlcloud_aws.hrl").

request_test_() ->
    {foreach,
     fun start/0,
     fun stop/1,
     [fun request_default_test/1,
      fun request_prot_host_port_str_test/1,
      fun request_prot_host_port_int_test/1,
      fun retry_handling_tests/1]}.

retry_handling_tests(_) ->
    [
     retry_handling_no_retry(),
     retry_handling_default_retry(),
     retry_handling_httpc_error()
    ].

start() ->
    meck:new(erlcloud_httpc),
    meck:expect(erlcloud_httpc, request, fun(_,_,_,_,_,_) -> {ok, {{200, "OK"}, [], ok}} end),
    ok.

stop(_) ->
    meck:unload(erlcloud_httpc).

request_default_test(_) ->
    ok = erlcloud_aws:aws_request(get, "host", "/", [], "id", "key"),
    Url = get_url_from_history(meck:history(erlcloud_httpc)),
    test_url(https, "host", 443, "/", Url).

request_prot_host_port_str_test(_) ->
    ok = erlcloud_aws:aws_request(get, "http", "host1", ":9999", "/path1", [], "id", "key"),
    Url = get_url_from_history(meck:history(erlcloud_httpc)),
    test_url(http, "host1", 9999, "/path1", Url).

request_prot_host_port_int_test(_) ->
    ok = erlcloud_aws:aws_request(get, "http", "host1", 9999, "/path1", [], "id", "key"),
    Url = get_url_from_history(meck:history(erlcloud_httpc)),
    test_url(http, "host1", 9999, "/path1", Url).

retry_handling_no_retry() ->
    Response = {ok, {{500, "Internal Server Error"}, [], <<"TestBody">>}},
    meck:expect(erlcloud_httpc, request, httpc_expect(Response)),
    Config = erlcloud_aws:default_config(),
    Result = erlcloud_aws:aws_request2(get, "https", "host", 11111, "some/path", [],
                                       Config#aws_config{retry_fun = fun erlcloud_retry:no_retry/1}),
    ?_assertEqual({error,{http_error,500,"Internal Server Error",<<"TestBody">>}}, Result).

retry_handling_default_retry() ->
    Response1 = {ok, {{500, "Internal Server Error"}, [], <<"TestBody">>}},
    Response2 = {ok, {{200, "OK"}, [], <<"TestBody">>}},
    meck:sequence(erlcloud_httpc, request, 6, [Response1, Response2]),
    Config = erlcloud_aws:default_config(),
    Result = erlcloud_aws:aws_request2(get, "https", "host", 11111, "some/path", [],
                                       Config#aws_config{retry_fun = fun erlcloud_retry:default_retry/1}),
    ?_assertEqual({ok, <<"TestBody">>}, Result).

retry_handling_httpc_error() ->
    Response1 = {error, timeout},
    Response2 = {ok, {{200, "OK"}, [], <<"TestBody">>}},
    meck:sequence(erlcloud_httpc, request, 6, [Response1, Response2]),
    Config = erlcloud_aws:default_config(),
    Result = erlcloud_aws:aws_request2(get, "https", "host", 11111, "some/path", [],
                                       Config#aws_config{retry_fun = fun erlcloud_retry:default_retry/1}),
    ?_assertEqual({ok, <<"TestBody">>}, Result).

% ==================
% Internal functions
% ==================

get_url_from_history([{_, {erlcloud_httpc, request, [Url, _, _, _, _, _]}, _}]) ->
    Url.

test_url(ExpScheme, ExpHost, ExpPort, ExpPath, Url) ->
    {ok, {Scheme, _UserInfo, Host, Port, Path, _Query}} = http_uri:parse(Url),
    [?_assertEqual(ExpScheme, Scheme),
     ?_assertEqual(ExpHost, Host),
     ?_assertEqual(ExpPort, Port),
     ?_assertEqual(ExpPath, Path)].

httpc_expect(Response) ->
    httpc_expect(get, Response).

httpc_expect(Method, Response) ->
    fun(_Url, Method2, _Headers, _Body, _Timeout, _Config) ->
            Method = Method2,
            Response
    end.

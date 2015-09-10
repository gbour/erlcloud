%% -*- mode: erlang;erlang-indent-level: 4;indent-tabs-mode: nil -*-
-module(erlcloud_sqs_tests).
-include_lib("eunit/include/eunit.hrl").
-include("erlcloud.hrl").
-include("erlcloud_aws.hrl").

%% Unit tests for sqs.
%% Currently only test async error handling.

%%%===================================================================
%%% Test entry points
%%%===================================================================

operation_test_() ->
    {foreach,
     fun start/0,
     fun stop/1,
     [
      fun send_async_message/1,
      fun error_handling_no_retry/1,
      fun error_handling_default_retry/1,
      fun error_handling_httpc_error/1
     ]}.

start() ->
    {ok, _} = application:ensure_all_started(erlcloud),
    ok = meck:new(erlcloud_httpc).

stop(_) ->
    ok = meck:unload(erlcloud_httpc),
    application:stop(erlcloud).

config(Config) ->
    Config#aws_config{
      access_key_id = string:copies("A", 20),
      secret_access_key = string:copies("a", 40)}.

httpc_expect(Method, Response) ->
    fun(_Url, Method2, _Headers, _Body, _Timeout, _Config) -> 
            Method = Method2,
            Response
    end.
    
send_async_message(_) ->
    Response = {ok, {{200, "OK"}, [{"x-amz-version-id", "version_id"}], <<>>}},
    meck:expect(erlcloud_httpc, request, httpc_expect(post, Response)),
    <<>> = erlcloud_sqs:send_async_message("queue", "message"),
    timer:sleep(500),
    ?_assertEqual(true, meck:validate(erlcloud_httpc)).

error_handling_no_retry(_) ->
    Response = {ok, {{500, "Internal Server Error"}, [], <<"TestBody">>}},
    meck:expect(erlcloud_httpc, request, httpc_expect(post, Response)),
    <<>> = erlcloud_sqs:send_async_message(
           "queue", "message", config(#aws_config{ custom_retry_settings =
                                                   [
                                                    {sqs, fun erlcloud_retry:no_retry/1, undefined}
                                                   ]})),
    timer:sleep(500),
    ?_assertEqual(true, meck:validate(erlcloud_httpc)).

error_handling_default_retry(_) ->
    Response1 = {ok, {{500, "Internal Server Error"}, [], <<"TestBody">>}},
    Response2 = {ok, {{200, "OK"}, [], <<"TestBody">>}},
    meck:sequence(erlcloud_httpc, request, 6, [Response1, Response2]),
    <<>> = erlcloud_sqs:send_async_message(
           "queue", "message", config(#aws_config{ custom_retry_settings =
                                                   [
                                                    {sqs, fun erlcloud_retry:default_retry/1, undefined}
                                                   ]})),
    timer:sleep(1500),
    ?_assertEqual(true, meck:validate(erlcloud_httpc)).

error_handling_httpc_error(_) ->
    Response1 = {error, timeout},
    Response2 = {ok, {{200, "OK"}, [], <<"TestBody">>}},
    meck:sequence(erlcloud_httpc, request, 6, [Response1, Response2]),
    <<>> = erlcloud_sqs:send_async_message(
           "queue", "message", config(#aws_config{ custom_retry_settings =
                                                   [
                                                    {sqs, fun erlcloud_retry:default_retry/1, undefined}
                                                   ]})),
    timer:sleep(1500),
    ?_assertEqual(true, meck:validate(erlcloud_httpc)).


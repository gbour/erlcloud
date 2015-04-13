%% -*- mode: erlang;erlang-indent-level: 4;indent-tabs-mode: nil -*-
%%% Inspired by, and some code taken from https://github.com/wagerlabs/ddb, which is:
%%%
%%% Copyright (C) 2012 Issuu ApS. All rights reserved.
%%%
%%% Redistribution and use in source and binary forms, with or without
%%% modification, are permitted provided that the following conditions
%%% are met:
%%% 1. Redistributions of source code must retain the above copyright
%%%    notice, this list of conditions and the following disclaimer.
%%% 2. Redistributions in binary form must reproduce the above copyright
%%%    notice, this list of conditions and the following disclaimer in the
%%%    documentation and/or other materials provided with the distribution.
%%%
%%% THIS SOFTWARE IS PROVIDED BY AUTHOR AND CONTRIBUTORS ``AS IS'' AND
%%% ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
%%% IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
%%% ARE DISCLAIMED.  IN NO EVENT SHALL AUTHOR OR CONTRIBUTORS BE LIABLE
%%% FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
%%% DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
%%% OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
%%% HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
%%% LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
%%% OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
%%% SUCH DAMAGE.

%% @author Ransom Richardson <ransom@ransomr.net>
%% @doc
%%
%% Implementation of requests to DynamoDB. This code is shared accross
%% all API versions.
%
%% @end

-module(erlcloud_ddb_impl).

-include("erlcloud.hrl").
-include("erlcloud_aws.hrl").
-include("erlcloud_ddb2.hrl").

%% Request API
-export([request/3]).

-export_type([json_return/0]).

-type json_return() :: {ok, jsx:json_term()} | {error, term()}.
-type headers() :: [{string(), string()}].

-type operation() :: string().
-spec request(aws_config(), operation(), jsx:json_term()) -> json_return().
request(Config0, Operation, Json) ->
    Body = case Json of
               [] -> <<"{}">>;
               _ -> jsx:encode(Json)
           end,
    case erlcloud_aws:update_config(Config0) of
        {ok, Config1} ->
            #aws_config{ddb_scheme = Scheme,
                        ddb_host = Host,
                        ddb_port = Port} = Config1,
            Headers = headers(Config1, Operation, Body),
            Config2 = process_timeout(Config1#aws_config{ retry_result = fun check_client_error/1 }),
            case erlcloud_aws:aws_request_form(post, Scheme, Host, Port, "", Body, Headers, Config2) of
                {ok, RespBody} ->
                    %% TODO: check crc
                    {ok, jsx:decode(RespBody)};
                Error ->
                    Error
            end;
        {error, Reason} ->
            {error, Reason}
    end.

-spec check_client_error(#aws_request{}) -> #aws_request{}.
check_client_error(#aws_request{
                      response_type = error,
                      error_type = aws,
                      response_status = Status,
                      response_body = Body
                     } = AWSRequest0) when Status >= 400 andalso Status < 500 ->
    AWSRequest = AWSRequest0#aws_request{ should_retry = false },
    case jsx:is_json(Body) of
        false ->
            AWSRequest;
        true ->
            Json = jsx:decode(Body),
            case proplists:get_value(<<"__type">>, Json) of
                undefined ->
                    AWSRequest;
                FullType ->
                    case binary:split(FullType, <<"#">>) of
                        [_, Type] when
                              Type =:= <<"ProvisionedThroughputExceededException">> orelse
                              Type =:= <<"ThrottlingException">> ->
                            AWSRequest#aws_request{ should_retry = true };
                        _ ->
                            AWSRequest
                    end
            end
    end;
check_client_error(AWSRequest) ->
    erlcloud_retry:default_result(AWSRequest).

-spec headers(aws_config(), string(), binary()) -> headers().
headers(Config, Operation, Body) ->
    Headers = [{"host", Config#aws_config.ddb_host},
               {"x-amz-target", Operation}],
    Region =
        case string:tokens(Config#aws_config.ddb_host, ".") of
            [_, Value, _, _] ->
                Value;
            _ ->
                "us-east-1"
        end,
    [{<<"content-type">>, <<"application/x-amz-json-1.0">>}
     | erlcloud_aws:sign_v4(Config, Headers, Body, Region, "dynamodb")].

%% HTTPC timeout for a request
process_timeout(Config) ->
    %% Shorter timeout on first request. This is to avoid long (5s) failover when first DDB
    %% endpoint doesn't respond
    %% Longer timeout on subsequent requsets - results in less timeouts when system is
    %% under heavy load
    Config#aws_config{ timeout = {1000, Config#aws_config.timeout} }.


%% -*- mode: erlang;erlang-indent-level: 4;indent-tabs-mode: nil -*-

%% @author Ransom Richardson <ransom@ransomr.net>
%% @doc
%%
%% Implementation of retry logic for AWS requests
%%
%% Currently only used for S3, but will be extended to other services in the furture.
%% 
%% The pluggable retry function provides a way to customize the retry behavior, as well
%% as log and customize errors that are generated by erlcloud.
%%
%% @end

-module(erlcloud_retry).

-include("erlcloud.hrl").
-include("erlcloud_aws.hrl").

%% API
-export([request/2, custom_retry/2]).

%% Retry handlers
-export([
         no_retry/1,
         default_retry/1, default_retry/2
        ]).

%% Result handlers
-export([
         default_result/1
        ]).

-type should_retry() :: {retry | error, #aws_request{}}.
-type retry_fun() :: fun((#aws_request{}) -> should_retry()).
-type result_fun() :: fun((#aws_request{}) -> #aws_request{}).
-export_type([should_retry/0, retry_fun/0, result_fun/0]).

%% Default number of retry attempts
%% Currently matches DynamoDB retry
%% It's likely this is too many retries for other services
-define(RETRY_ATTEMPTS, 10).

%% -----------------------------------------------------------------
%% API
%% -----------------------------------------------------------------

-spec request(#aws_config{}, #aws_request{}) -> #aws_request{} | {error, term()}.
request(Config, #aws_request{attempt = 0} = Request) ->
    request_and_retry(Config, Config#aws_config.retry_result_fun, {retry, Request}).

-spec request_and_retry(#aws_config{}, result_fun(), {error | retry, #aws_request{}}) ->
    #aws_request{} | {error, term()}.
request_and_retry(_, _, {error, Request}) ->
    Request;
request_and_retry(Config, ResultFun, {retry, Request}) ->
    #aws_request{
       attempt = Attempt,
       uri = URI,
       method = Method,
       request_headers = Headers,
       request_body = Body
      } = Request,
    Request2 = Request#aws_request{attempt = Attempt + 1},
    RetryFun = Config#aws_config.retry_fun,
    case erlcloud_httpc:request(URI, Method, Headers, Body,
                                parse_timeout(Attempt + 1, Config#aws_config.timeout), Config) of
        {ok, {{Status, StatusLine}, ResponseHeaders, ResponseBody}} ->
            Request3 = Request2#aws_request{
                         response_type = if Status >= 200, Status < 300 -> ok; true -> error end,
                         error_type = aws,
                         response_status = Status,
                         response_status_line = StatusLine,
                         response_headers = ResponseHeaders,
                         response_body = ResponseBody},
            Request4 = ResultFun(Request3),
            case Request4#aws_request.response_type of
                ok ->
                    Request4;
                error ->
                    request_and_retry(Config, ResultFun, RetryFun(Request4))
            end;
        ok ->
            Request2#aws_request{ response_type = ok, error_type = aws };
        {error, Reason} ->
            Request4 = Request2#aws_request{
                         response_type = error,
                         error_type = httpc,
                         httpc_error_reason = Reason},
            request_and_retry(Config, ResultFun, RetryFun(Request4))
    end.

-spec custom_retry(atom(), #aws_config{}) -> #aws_config{}.
custom_retry(Service, Config) ->
    case lists:keyfind(Service, 1, Config#aws_config.custom_retry_settings) of
        false ->
            Config;
        {_, RetryFun, ResultFun} ->
            Config#aws_config{
              retry_fun = case RetryFun of
                              undefined -> Config#aws_config.retry_fun;
                              _ -> RetryFun
                          end,
              retry_result_fun = case ResultFun of
                                     undefined -> Config#aws_config.retry_result_fun;
                                     _ -> ResultFun
                                 end
             }
    end.

%% -----------------------------------------------------------------
%% Retry handlers
%% -----------------------------------------------------------------

%% Error returns maintained for backwards compatibility
-spec no_retry(#aws_request{}) -> should_retry().
no_retry(Request) ->
    {error, Request}.

-spec default_retry(#aws_request{}) -> should_retry().
default_retry(Request) ->
    default_retry(Request, ?RETRY_ATTEMPTS).

-spec default_retry(#aws_request{}, integer()) -> should_retry().
default_retry(#aws_request{attempt = Attempt} = Request, MaxAttempts) 
  when Attempt >= MaxAttempts ->
    {error, Request};
default_retry(#aws_request{should_retry = false} = Request, _) ->
    {error, Request};
default_retry(#aws_request{attempt = Attempt} = Request, _) ->
    backoff(Attempt),
    {retry, Request}.

%% -----------------------------------------------------------------
%% Result handlers
%% -----------------------------------------------------------------

-spec default_result(#aws_request{}) -> #aws_request{}.
default_result(#aws_request{response_type = ok} = Request) ->
    Request;
default_result(#aws_request{response_type = error,
                           error_type = aws,
                           response_status = Status} = Request) when
      Status >= 500 ->
    Request#aws_request{should_retry = true};
default_result(#aws_request{response_type = error, error_type = aws} = Request) ->
    Request#aws_request{should_retry = false}.

%% -----------------------------------------------------------------
%% Internal functions
%% -----------------------------------------------------------------

-spec parse_timeout(pos_integer(), pos_integer() | {pos_integer(), pos_integer()}) -> pos_integer().
parse_timeout(1, {FirstTimeout, _}) ->
    FirstTimeout;
parse_timeout(_, {_, RestTimeout}) ->
    RestTimeout;
parse_timeout(_, Timeout) ->
    Timeout.

%% Sleep after an attempt
-spec backoff(pos_integer()) -> ok.
backoff(1) -> ok;
backoff(Attempt) ->
    timer:sleep(random:uniform((1 bsl (Attempt - 1)) * 100)).


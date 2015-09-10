-module(erlcloud_cloudtrail).

-include("erlcloud.hrl").
-include("erlcloud_aws.hrl").

%% EC2 API Functions
-export([
    %% Users
    create_trail/3, create_trail/4, create_trail/5, create_trail/6,
    delete_trail/1, delete_trail/2,
    describe_trails/0, describe_trails/1, describe_trails/2,
    get_trail_status/1, get_trail_status/2,
    start_logging/1, start_logging/2,
    stop_logging/1, stop_logging/2,
    update_trail/4, update_trail/5, update_trail/6,
    ct_request/3
]).

-define(API_VERSION, "2013-11-01").
-define(SERVICE_NAME, "cloudtrail").

-type headers() :: [{string(), string()}].

-type ct_return() :: {ok, proplist()} | {error, term()}.

%%
%% API
%%
-spec(create_trail/3 :: (string(), string(), aws_config()) -> ct_return()).
create_trail(Trail, S3BucketName, Config) ->
    Json = [{<<"Name">>, list_to_binary(Trail)}, 
            {<<"S3BucketName">>, list_to_binary(S3BucketName)}
           ],
    ct_request("CreateTrail", Json, Config).

-spec(create_trail/4 :: (string(), string(), string(), aws_config()) -> ct_return()).
create_trail(Trail, S3BucketName, SnsTopicName,  Config) ->
    Json = [{<<"Name">>, list_to_binary(Trail)}, 
            {<<"S3BucketName">>, list_to_binary(S3BucketName)},
            {<<"SnsTopicName">>, list_to_binary(SnsTopicName)}
           ],
    ct_request("CreateTrail", Json, Config).

-spec(create_trail/5 :: (string(), string(), string(), boolean(), aws_config()) -> ct_return()).
create_trail(Trail, S3BucketName, SnsTopicName, IncludeGlobalServiceEvents, Config) ->
    Json = [{<<"Name">>, list_to_binary(Trail)}, 
            {<<"S3BucketName">>, list_to_binary(S3BucketName)},
            {<<"SnsTopicName">>, list_to_binary(SnsTopicName)},
            {<<"IncludeGlobalServiceEvents">>, list_to_binary(atom_to_list(IncludeGlobalServiceEvents))}
           ],
    ct_request("CreateTrail", Json, Config).

-spec(create_trail/6 :: (string(), string(), string(), string(), boolean(), aws_config()) -> ct_return()).
create_trail(Trail, S3BucketName, S3KeyPrefix, SnsTopicName, IncludeGlobalServiceEvents, Config) ->
    Json = [{<<"Name">>, list_to_binary(Trail)}, 
            {<<"S3BucketName">>, list_to_binary(S3BucketName)},
            {<<"S3KeyPrefix">>, list_to_binary(S3KeyPrefix)},
            {<<"SnsTopicName">>, list_to_binary(SnsTopicName)},
            {<<"IncludeGlobalServiceEvents">>, list_to_binary(atom_to_list(IncludeGlobalServiceEvents))}
           ],
    ct_request("CreateTrail", Json, Config).

-spec(delete_trail/1 :: ([string()] ) -> ct_return()).
delete_trail(Trail) ->
    delete_trail(Trail, default_config()).

-spec(delete_trail/2 :: ([string()], aws_config()) -> ct_return()).
delete_trail(Trail, Config) ->
    Json = [{<<"Name">>, list_to_binary(Trail)}],
    ct_request("DeleteTrail", Json, Config).

-spec(describe_trails/0 :: () -> ct_return()).
describe_trails() -> describe_trails([]).

-spec(describe_trails/1 :: ([string()] | aws_config()) -> ct_return()).
describe_trails(Config) when is_record(Config, aws_config) ->
    describe_trails([], Config);

%% It appears that CloudTrail API doesn't honor TrailNameList parameter.
%% TODO: Open a ticket with AWS.
describe_trails(Trails) ->
    describe_trails(Trails, default_config()).

-spec(describe_trails/2 :: ([string()], aws_config()) -> ct_return()).
describe_trails([], Config) ->
    ct_request("DescribeTrails", [], Config);

describe_trails(Trails, Config) ->
    %% Json = [{<<"TrailNameList">>, jsx:encode(list_to_binary([Trails]))}],
    Json = [{<<"TrailNameList">>, [list_to_binary(T) || T <- Trails]}],
    ct_request("DescribeTrails", Json, Config).

-spec(get_trail_status/1 :: ([string()] ) -> ct_return()).
get_trail_status(Trail) ->
    get_trail_status(Trail, default_config()).

-spec(get_trail_status/2 :: ([string()], aws_config()) -> ct_return()).
get_trail_status(Trail, Config) ->
    Json = [{<<"Name">>, list_to_binary(Trail)}],
    ct_request("GetTrailStatus", Json, Config).

-spec(start_logging/1 :: ([string()] ) -> ct_return()).
start_logging(Trail) ->
    start_logging(Trail, default_config()).

-spec(start_logging/2 :: ([string()], aws_config()) -> ct_return()).
start_logging(Trail, Config) ->
    Json = [{<<"Name">>, list_to_binary(Trail)}],
    ct_request("StartLogging", Json, Config).

-spec(stop_logging/1 :: ([string()] ) -> ct_return()).
stop_logging(Trail) ->
    stop_logging(Trail, default_config()).

-spec(stop_logging/2 :: ([string()], aws_config()) -> ct_return()).
stop_logging(Trail, Config) ->
    Json = [{<<"Name">>, list_to_binary(Trail)}],
    ct_request("StopLogging", Json, Config).

-spec(update_trail/4 :: (string(), string(), string(), aws_config()) -> ct_return()).
update_trail(Trail, S3BucketName, SnsTopicName, Config) ->
    Json = [{<<"Name">>, list_to_binary(Trail)}, 
            {<<"S3BucketName">>, list_to_binary(S3BucketName)},
            {<<"SnsTopicName">>, list_to_binary(SnsTopicName)}
           ],
    ct_request("UpdateTrail", Json, Config).

-spec(update_trail/5 :: (string(), string(), string(), boolean(), aws_config()) -> ct_return()).
update_trail(Trail, S3BucketName, SnsTopicName, IncludeGlobalServiceEvents, Config) ->
    Json = [{<<"Name">>, list_to_binary(Trail)}, 
            {<<"S3BucketName">>, list_to_binary(S3BucketName)},
            {<<"SnsTopicName">>, list_to_binary(SnsTopicName)},
            {<<"IncludeGlobalServiceEvents">>, list_to_binary(atom_to_list(IncludeGlobalServiceEvents))}
           ],
    ct_request("UpdateTrail", Json, Config).


-spec(update_trail/6 :: (string(), string(), string(), string(), boolean(), aws_config()) -> ct_return()).
update_trail(Trail, S3BucketName, S3KeyPrefix, SnsTopicName, IncludeGlobalServiceEvents, Config) ->
    Json = [{<<"Name">>, list_to_binary(Trail)}, 
            {<<"S3BucketName">>, list_to_binary(S3BucketName)},
            {<<"S3KeyPrefix">>, list_to_binary(S3KeyPrefix)},
            {<<"SnsTopicName">>, list_to_binary(SnsTopicName)},
            {<<"IncludeGlobalServiceEvents">>, list_to_binary(atom_to_list(IncludeGlobalServiceEvents))}
           ],
    ct_request("UpdateTrail", Json, Config).

-spec ct_request(string(), list({binary(), binary()}), #aws_config{}) ->
    {ok, binary(), jsx:json_term()} | {error, term()}.
ct_request(Operation, [], Config) ->
    request_impl(post, Operation, [], <<"{}">>, Config);
ct_request(Operation, Body, Config) ->
    request_impl(post, Operation, [], jsx:encode(Body), Config).
 
request_impl(Method, Operation, Params, Body,
             #aws_config{cloudtrail_scheme = Scheme, cloudtrail_host = Host, cloudtrail_port = Port} = Config) ->
    ApiOperation = lists:flatten(Config#aws_config.cloudtrail_api_prefix, Operation),
    Headers = headers(Config, ApiOperation, Params, Body, ?SERVICE_NAME),

    case erlcloud_aws:aws_request_form(Method, erlcloud_util:scheme_to_protocol(Scheme), Host, Port, "/",
                                       Body, Headers, erlcloud_retry:custom_retry(cloudtrail, Config)) of
       {ok, RespBody} ->
            case Config#aws_config.cloudtrail_raw_result of
                true -> {ok, RespBody};
                _ -> {ok, jsx:decode(RespBody)}
            end;
        Error ->
            Error
    end.

-spec headers(aws_config(), string(), proplist(), binary(), string()) -> headers().
headers(Config, Operation, _Params, Body, Service) ->
    Headers = [
               {"host", Config#aws_config.cloudtrail_host},
               {"x-amz-target", Operation}
               ],
    Region =
        case string:tokens(Config#aws_config.cloudtrail_host, ".") of
            [_, Value, _, _] ->
                Value;
            _ ->
                "us-east-1"
        end,
    
    [{<<"content-type">>, <<"application/x-amz-json-1.1">>}
     | erlcloud_aws:sign_v4(Config, Headers, Body, Region, Service)].


default_config() -> erlcloud_aws:default_config().


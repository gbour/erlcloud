-module(erlcloud_retry_sup).

-include("erlcloud_aws.hrl").

-behaviour(supervisor).

%% API functions
-export([
         start_link/0,
         start_retry_handler/2
        ]).

%% Supervisor callbacks
-export([init/1]).

%%%===================================================================
%%% API functions
%%%===================================================================

-spec start_link() -> supervisor:startlink_ret().
start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

-spec start_retry_handler(#aws_config{}, #aws_request{}) -> ok.
start_retry_handler(Config, Request) ->
    {ok, _Pid} = supervisor:start_child(?MODULE, [Config, Request]),
    ok.

%%%===================================================================
%%% Supervisor callbacks
%%%===================================================================

-spec init(Args :: term()) -> {ok, {{supervisor:strategy(), integer(), integer()},
                                    [supervisor:child_spec()]}}
                              | ignore.
init([]) ->
    ChildSpec = {undefined, {erlcloud_retry, start_link, []}, temporary,
                 5000, worker, [erlcloud_retry]},
    {ok, {{simple_one_for_one, 5, 10}, [ChildSpec]}}.

%%%===================================================================
%%% Internal functions
%%%===================================================================


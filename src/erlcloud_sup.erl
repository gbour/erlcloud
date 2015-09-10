-module(erlcloud_sup).

-behaviour(supervisor).

%% API functions
-export([start_link/0]).

%% Supervisor callbacks
-export([init/1]).

-define(CHILD(Id, Mod, Type, Args), {Id, {Mod, start_link, Args},
                                     permanent, 5000, Type, [Mod]}).

%%%===================================================================
%%% API functions
%%%===================================================================

-spec start_link() -> supervisor:startlink_ret().
start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

%%%===================================================================
%%% Supervisor callbacks
%%%===================================================================

-spec init(Args :: term()) -> {ok, {{supervisor:strategy(), integer(), integer()},
                                    [supervisor:child_spec()]}}
                              | ignore.
init([]) ->
    {ok, {{one_for_one, 5, 10}, 
          [
           ?CHILD(erlcloud_retry_sup, erlcloud_retry_sup, supervisor, [])
          ]}}.

%%%===================================================================
%%% Internal functions
%%%===================================================================


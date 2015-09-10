-module(erlcloud_app).

-behaviour(application).

%% Application callbacks
-export([start/2,
         stop/1]).

%%%===================================================================
%%% Application callbacks
%%%===================================================================

-spec start(application:start_type(), term()) -> {ok, pid()} |
                                                 {ok, pid(), term()} |
                                                 {error, term()}.
start(_StartType, _StartArgs) ->
    case erlcloud_sup:start_link() of
        {error, {already_started, Pid}} -> {ok, Pid};
        Result -> Result
    end.

-spec stop(term()) -> no_return().
stop(_State) ->
    ok.

%%%===================================================================
%%% Internal functions
%%%===================================================================


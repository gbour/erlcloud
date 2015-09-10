-module(erlcloud).
-export([start/0]).

%% Kept for backward compatibility
start() ->
    %% Start the application
    {ok, _} = application:ensure_all_started(erlcloud),
    ok.

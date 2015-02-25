-module(erlcloud).
-export([start/0]).

-define(APP, erlcloud).

-define(DEFAULT_POOLS, [{erlcloud_pool, []}]).

start() ->
    %% start pools
    application:ensure_all_started(hackney_pooler),
    lists:foreach(fun({PoolName, Config}) ->
                          PoolSize = proplists:get_value(workers, Config, 50),
                          MaxConn = proplists:get_value(maxconn, Config, 50),
                          Concurrency = proplists:get_value(concurrency, Config, 50),
                          PoolConfig = [{concurrency, Concurrency},
                                        {maxconn, MaxConn},
                                        {group, erlcloud},
                                        {max_count, PoolSize},
                                        {init_count, PoolSize}],
                          hackney_pooler:new_pool(PoolName, PoolConfig)
                  end, application:get_env(?APP, pools, ?DEFAULT_POOLS)),
    %% start the application
    {ok, _} = application:ensure_all_started(?APP),
    ok.

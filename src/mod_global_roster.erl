-module(mod_global_roster).

-behavior(gen_mod).

-include("ejabberd.hrl").
-export([start/2, stop/1, on_presence_joined/4, on_presence_left/4]).

start(Host, _Opts) ->
  ?INFO_MSG("mod_global_roster starting", []),
  ejabberd_hooks:add(set_presence_hook, Host, ?MODULE, on_presence_joined, 50),
  ejabberd_hooks:add(unset_presence_hook, Host, ?MODULE, on_presence_left, 50),
  ok.

stop(Host) ->
  ?INFO_MSG("mod_global_roster stopping", []),
  ejabberd_hooks:delete(set_presence_hook, Host, ?MODULE, on_presence_joined, 50),
  ejabberd_hooks:delete(unset_presence_hook, Host, ?MODULE, on_presence_left, 50),
  ok.
  
on_presence_joined(User, Server, _Resource, _Packet) ->
  {ok, Client} = client(Server),
  eredis:q(Client, ["SADD", key_name(Server), User]),
  none.

on_presence_left(User, Server, _Resource, _Status) ->
  {ok, Client} = client(Server),
  eredis:q(Client, ["SREM", key_name(Server), User]),
  none.

key_name(Server) ->
  OnlineKey = gen_mod:get_module_opt(Server, ?MODULE, key, "roster:"),
  string:concat(OnlineKey, Server).

redis_host(Server) ->
  gen_mod:get_module_opt(Server, ?MODULE, redis_host, "127.0.0.1").

redis_port(Server) ->
  gen_mod:get_module_opt(Server, ?MODULE, redis_port, 6379).

redis_db(Server) ->
  gen_mod:get_module_opt(Server, ?MODULE, redis_db, 0).

client(Server) ->
  case whereis(list_to_atom("eredis_driver_" ++ Server)) of
    undefined ->
      ?INFO_MSG("~s: Connecting to redis host: ~s port: ~b db: ~b", [Server, redis_host(Server), redis_port(Server), redis_db(Server)]),
      case eredis:start_link(redis_host(Server), redis_port(Server), redis_db(Server)) of
        {ok, Client} ->
          register(list_to_atom("eredis_driver_" ++ Server), Client),
          {ok, Client};
        {error, Reason} ->
          {error, Reason}
      end;
    Pid ->
      {ok, Pid}
  end.
%% TODO
%% Handle redis errors
%% Handle redis returning 0 (if item is in set or cannot be removed)

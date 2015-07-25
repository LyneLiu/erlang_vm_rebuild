%% -*- erlang-indent-level: 2 -*-
%%
%% %CopyrightBegin%
%% 
%% Copyright Ericsson AB 2002-2011. All Rights Reserved.
%% 
%% The contents of this file are subject to the Erlang Public License,
%% Version 1.1, (the "License"); you may not use this file except in
%% compliance with the License. You should have received a copy of the
%% Erlang Public License along with this software. If not, it can be
%% retrieved online at http://www.erlang.org/.
%% 
%% Software distributed under the License is distributed on an "AS IS"
%% basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See
%% the License for the specific language governing rights and limitations
%% under the License.
%% 
%% %CopyrightEnd%
%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Copyright (c) 2001 by Erik Johansson.  All Rights Reserved 
%% Time-stamp: <2008-04-20 14:53:42 richard>
%% ====================================================================
%%  Module   :	hipe_profile
%%  Purpose  :  
%%  History  :	* 2001-07-12 Erik Johansson (happi@it.uu.se): Created.
%% ====================================================================
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

-module(hipe_profile).

-export([%% profile/1, mods_profile/1,
	 prof/0, prof_off/0, clear/0, res/0,
	 mods_res/0,
	 %% clear_module/1, res_module/1,
	 prof_module/1, prof_module_off/1]).

%% %% @spec mods_profile(F) -> [{mod(),calls()}]
%% %%       F = () -> term()
%% %%       mod()  = atom()
%% %%       calls()= integer()
%% %%
%% %% @doc  Returns the number of calls per module generated by
%% %%       applying F().
%% %%       The resulting lists is sorted with the most called
%% %%       module first.
%% mods_profile(F) ->
%%   F(),
%%   prof(),
%%   clear(), 
%%   F(), 
%%   R = mods_res(),
%%   prof_off(), 
%%   R.

-spec mods_res() -> [{atom(), non_neg_integer()}].
%% @doc  Returns the number of calls per module currently 
%%       recordeed since hipe_bifs:call_count_on().
%%       The resulting list is sorted with the most called
%%       module first.
mods_res() ->
  lists:reverse(lists:keysort(2, calls())).

-spec calls() -> [{atom(), non_neg_integer()}].
%% @doc  Returns the number of calls per module currently 
%%       recordeed since hipe_bifs:call_count_on().
calls() ->
  [{Mod, total_calls(Mod)} || Mod <- mods(),
			      total_calls(Mod) > 1,
			      Mod =/= hipe_profile].

%% %% @spec profile(F) -> [{mfa(),calls()}]
%% %%       F = ()    -> term()
%% %%       mfa()      = {mod(),function(),arity()}
%% %%       function() = atom()
%% %%       arity()    = intger()
%% %%
%% %% @doc  Returns the number of calls per module generated by
%% %%       applying F().
%% %%       The resulting lists is sorted with the most called
%% %%       module first.
%% profile(F) ->
%%   %% Make sure all code is loaded.
%%   F(),
%%   %% Turn profiling on.
%%   prof(),
%%   clear(), 
%%   %% Apply the closure to profile.
%%   F(), 
%%   %% Get result.
%%   R = res(),
%%   %% Turn off profiling.
%%   prof_off(),
%%   R.

-spec prof() -> 'ok'.
%% @doc Turns on profiling of all loaded modules.
prof() ->
  lists:foreach(fun prof_module/1, mods()).

-spec prof_off() -> 'ok'.
%% @doc Turns off profiling of all loaded modules.
 prof_off() ->
  lists:foreach(fun prof_module_off/1, mods()).

-spec clear() -> 'ok'.
%% @doc Clears all counters.
clear() ->
  lists:foreach(fun clear_module/1, mods()).

-spec res() -> [{mfa(), non_neg_integer()}].
%% @doc Returns a list of the numbers of calls to each profiled function.
%%      The list is sorted with the most called function first.
res() ->
  lists:reverse(lists:keysort(2, lists:flatten([res_module(M) || M <- mods()]))).

%% --------------------------------------------------------------------
-spec mods() -> [atom()].
%% @doc	 Returns a list of all loaded modules. 
%@ --------------------------------------------------------------------

mods() ->
  [Mod || {Mod,_} <- code:all_loaded()].

%% --------------------------------------------------------------------
-spec prof_module(atom()) -> 'ok'.
%% @doc	 Turns on profiling for given module. 
%@ ____________________________________________________________________

prof_module(Mod) ->
  Funs = Mod:module_info(functions),
  lists:foreach(fun ({F,A}) -> catch hipe_bifs:call_count_on({Mod,F,A}) end,
		Funs),
  ok.

%% --------------------------------------------------------------------
-spec prof_module_off(atom()) -> 'ok'.
%% @doc	 Turns off profiling of the module Mod. 
%@ --------------------------------------------------------------------

prof_module_off(Mod) ->
  Funs = Mod:module_info(functions),
  lists:foreach(fun ({F,A}) -> catch hipe_bifs:call_count_off({Mod,F,A}) end,
		Funs),
  ok.

%% --------------------------------------------------------------------
-spec clear_module(atom()) -> 'ok'.
%% @doc  Clears the call counters for all functions in module Mod.
%@ --------------------------------------------------------------------

clear_module(Mod) ->
  Funs = Mod:module_info(functions),
  lists:foreach(fun ({F,A}) -> catch hipe_bifs:call_count_clear({Mod,F,A}) end,
		Funs),
  ok.

%% --------------------------------------------------------------------
-spec res_module(atom()) -> [{mfa(), non_neg_integer()}].
%% @doc	  Returns the number of profiled calls to each function (MFA) 
%%        in the module Mod.
%@ --------------------------------------------------------------------

res_module(Mod) ->
  Fun = fun ({F,A}) when is_atom(F), is_integer(A) ->
	    MFA = {Mod,F,A},
	    {MFA, try hipe_bifs:call_count_get(MFA) of 
		    N when is_integer(N) -> N; 
		    false -> 0
		  catch
		    _:_ -> 0
		  end
	    }
	end,
  lists:reverse(lists:keysort(2, [Fun(FA) || FA <- Mod:module_info(functions)])).

-spec total_calls(atom()) -> non_neg_integer().

total_calls(Mod) ->
  Funs = Mod:module_info(functions),
  SumF = fun ({F,A}, Acc) -> 
	    MFA = {Mod,F,A},
	    try hipe_bifs:call_count_get(MFA) of 
	      N when is_integer(N) -> N+Acc; 
	      false -> Acc
	    catch
	      _:_ -> Acc
	    end;
	     (_, Acc) -> Acc
	end,
  lists:foldl(SumF, 0, Funs).
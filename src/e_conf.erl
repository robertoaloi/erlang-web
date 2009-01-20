%% The contents of this file are subject to the Erlang Web Public License,
%% Version 1.0, (the "License"); you may not use this file except in
%% compliance with the License. You should have received a copy of the
%% Erlang Web Public License along with this software. If not, it can be
%% retrieved via the world wide web at http://www.erlang-consulting.com/.
%%
%% Software distributed under the License is distributed on an "AS IS"
%% basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See
%% the License for the specific language governing rights and limitations
%% under the License.
%%
%% The Initial Developer of the Original Code is Erlang Training & Consulting
%% Ltd. Portions created by Erlang Training & Consulting Ltd are Copyright 2008,
%% Erlang Training & Consulting Ltd. All Rights Reserved.

%%%-------------------------------------------------------------------
%%% File    : e_conf.erl
%%% @author Michal Ptaszek <michal.ptaszek@erlang.consulting.com>
%%% @doc Module responsible for managing the project configuration.
%%% @end
%%%-------------------------------------------------------------------
-module(e_conf).

%% API
-export([load_conf/0, load_conf/1, install/0, reinstall/0]).
-export([upload_dir/0, template_expander/0, template_root/0]).
-export([default_language/0, cache_dir/0, host/0]).
-export([primitive_types/0, debug_mode/0, fe_servers/0]).
-export([http_port/0, https_port/0, project_name/0]).
-export([couchdb_address/0, dbms/0, server_root/0]).
-export([ecomponents/0]).
-export([get_conf/1, get_conf/2]).

%%====================================================================
%% API
%%====================================================================

%%
%% @spec install() -> none()
%% @doc Loads the configuration from the default path.
%% @see load_conf/0
%%
-spec(install/0 :: () -> none()).
install() ->
    load_conf().

%%
%% @spec reinstall() -> none()
%% @doc Loads the configuration from the default path.
%% @see load_conf/0
%%
-spec(reinstall/0 :: () -> none()).
reinstall() ->
    load_conf().

%%
%% @spec load_conf() -> none()
%% @doc Loads the configuration from the default path.
%% The default path is 
%% <i>e_conf:server_root()/config/project.conf</i>.
%% @end
%% @see load_conf/1
%%
-spec(load_conf/0 :: () -> none()).
load_conf() ->
    load_conf(filename:join([server_root(), "config", "project.conf"])).

%%
%% @spec load_conf(Filename :: string()) -> none()
%% @doc Loads the configuration from the given file.
%% The previous configuration is erased. 
%% File given as a parameter must be parsable by the file:consult call.<br/>
%% The content of the configuration is stored inside the
%% <b>e_conf</b> ets table.
%% @end
%%
-spec(load_conf/1 :: (Filename :: string()) -> none()).
load_conf(Filename) ->
    {ok, Tuples} = file:consult(Filename),
    
    Path = template_root(),
    Ext = Tuples ++ [{template_root, Path}],

    case ets:info(e_conf) of
	undefined ->
	    ets:new(e_conf, [named_table, public]);
	_ ->
	    ets:delete_all_objects(e_conf)
    end,
   
    ets:insert(e_conf, Ext),

    DBMS = case lists:keysearch(dbms, 1, Ext) of
	       false ->
		   e_db_mnesia;
	       {_, {_, mnesia}} ->
		   e_db_mnesia;
	       {_, {_, couchdb}} ->
		   e_db_couchdb;
	       _ ->
		   e_db_mnesia
	   end,
    application:set_env(eptic, dbms, DBMS).

%%
%% @spec upload_dir() -> UploadDir :: string()
%% @doc Returns the path to the upload directory.
%% The project.conf tuple which sets it should look like:
%% ```{upload_dir, Path}'''
%% where <b>Path</b> is a relative path from the server root
%% directory. <br/>
%% The default value is 
%% <i>e_conf:server_root()/docroot/upload</i>
%% @end
%%
-spec(upload_dir/0 :: () -> string()).
upload_dir() ->
    case ets:lookup(e_conf, upload_dir) of
	[] ->
	    filename:join([server_root(), "docroot", "upload"]);
	[{upload_dir, Dir}] ->
	    filename:join([server_root(), "docroot", Dir])
    end.

%%
%% @spec default_language() -> DefaultLanguage :: atom()
%% @doc Returns the default language of the project.
%% During the translation process, if no language is set
%% inside the session variable, this one will be selected.
%% The project.conf tuple which sets it should look like:
%% ```{default_language, Lan}'''
%% where <b>Lan</b> is the atom representing the default language.<br/>
%% The default value is <i>en</i>.
%% @end
%%
-spec(default_language/0 :: () -> atom()).
default_language() ->
    get_conf(default_language, en).

%%
%% @spec cache_dir() -> CacheDirPath :: string()
%% @doc Returns the directory for disk cache.
%% All cached files will be kept there.
%% The specified directory must be writeable for the server.
%% The project.conf tuple which sets it should look like:
%% ```{cache_dir, Dir}'''
%% where <b>Dir</b> is the path to the desired cache directory.
%% Path is relative to the server root.<br/>
%% The default value is <i>templates/cache</i>.
%% @end
%% @see e_cache
%%
-spec(cache_dir/0 :: () -> string()).
cache_dir() ->
    get_conf(cache_dir, ["templates/", "cache"]).

%%
%% @spec host() -> Hostname :: string()
%% @doc Returns the host the server is running on.
%% It could be useful for redirections to the other ports on the
%% same server. The project.conf tuple which sets it should look like:
%% ```{host, Host}'''
%% where <b>Host</b> is the string name of the host.<br/>
%% The default value is <i>localhost</i>.
%% @end
%%
-spec(host/0 :: () -> string()).	     
host() ->
    get_conf(host, "localhost").

%%
%% @private
%%
fe_servers() ->
    get_conf(fe_servers, []).

%%
%% @spec debug_mode() -> IsDebugMode :: bool()
%% @doc Checks if the server is running in the debug mode.
%% If so, all the errors will be displayed in the browser 
%% instead of the nice error 404/501 pages. 
%% The project.conf tuple which sets it should look like:
%% ```{debug_mode, Bool}'''
%% where <b>Bool</b> is either true or false atom.<br/>
%% The default value is <i>false</i>.
%% @end
%%
-spec(debug_mode/0 :: () -> bool()).	     
debug_mode() ->
    get_conf(debug_mode, false).

%%
%% @spec primitive_types() -> List 
%%       List = [atom()]
%% @doc Returns the list of all available primitive types.
%% Each provided type should add at least two modules:
%% <i>wpart_<b>Name</b></i> and <i>wtype_<b>Name</b></i>.
%% The project.conf tuple which sets it should look like:
%% ```{primitive_types, List}'''
%% where <b>List</b> is a list of the user provided primitive types<br/>
%% The default value is <i>[]</i>.
%% @end
%% @see //wpart/wpart
%% @see //wpart/wtype
%%
-spec(primitive_types/0 :: () -> [atom()]).
primitive_types() ->
    get_conf(primitive_types, []).

%%
%% @spec http_port() -> Port :: string()
%% @doc Returns the http port for the server.
%% The specified port will be used for server to bind to.
%% The project.conf tuple which sets it should look like:
%% ```{http_port, Port}'''
%% where <b>Port</b> is a http port number.<br/>
%% The default value is <i>80</i>.
%% @end
%%
-spec(http_port/0 :: () -> string()).	     
http_port() ->
    integer_to_list(get_conf(http_port, 80)).

%%
%% @spec https_port() -> Port :: string()
%% @doc Returns the https port for the server.
%% The specified port will be used for server to bind to.
%% The project.conf tuple which sets it should look like:
%% ```{https_port, Port}'''
%% where <b>Port</b> is a https port number.<br/>
%% The default value is <i>443</i>.
%% @end
%%
-spec(https_port/0 :: () -> string()).	
https_port() ->
    integer_to_list(get_conf(https_port, 443)).

%%
%% @spec project_name() -> Name :: string()
%% @doc Returns the name of the project we are working on.
%% This name is used in naming databases with objects and ids 
%% in e_db_couchdb module.
%% The project.conf tuple which sets it should look like:
%% ```{project_name, Name}'''
%% where <b>Name</b> is the name of the project.<br/>
%% The default value is <i>erlangweb</i>.
%% @end
%% @see e_db_couchdb
%%
-spec(project_name/0 :: () -> string()).	     
project_name() ->
    get_conf(project_name, "erlangweb").

%%
%% @spec couchdb_address() -> URL :: string()
%% @doc Returns the URL of the CouchDB server.
%% The address is used during the connection to the CouchDB server.
%% The project.conf tuple which sets it should look like:
%% ```{couchdb_address, URL}'''
%% where <b>URL</b> is the CouchDB address.<br/>
%% The default value is <i>http://localhost:5984/</i>.
%% @end 
%% @see e_db_couchdb
%%
-spec(couchdb_address/0 :: () -> string()).	     
couchdb_address() ->
    get_conf(couchdb_address, "http://localhost:5984/").

%%
%% @spec dbms() -> DatabaseEngineCallbackModule :: atom()
%% @doc Returns the name of the callback module for database engine.
%% The currently supported engines are for Mnesia and CouchDB (experimental)
%% databases. 
%% The project.conf tuple which sets it should look like:
%% ```{dbms, DBMS}'''
%% where <b>DBMS</b> is atom: <ul>
%% <li>mnesia - for Mnesia support</li>
%% <li>couchdb - for CouchDB support</li>
%% </ul>
%% The default value is <i>mnesia</i>.
%% The callback modules could be either e_db_mnesia or e_db_couchdb.
%% @end
%% @see e_db
%% @see e_db_couchdb
%% @see e_db_mnesia
%%
-spec(dbms/0 :: () -> atom()).	     
dbms() ->
    element(2, application:get_env(eptic, dbms)).

%%
%% @spec template_expander() -> TemplateExpanderCallbackModule :: atom()
%% @doc Returns the name of the callback module for templates expanding.
%% This option could be changed by providing the application environment variable
%% template_expander.
%% Currently now <i>wpart_xs</i> is supported.
%% @end
%% @see //wpart/wpart_xs
%%
-spec(template_expander/0 :: () -> atom()).	     
template_expander() ->
    element(2, application:get_env(eptic, template_expander)).

%%
%% @spec template_root() -> TemplateRootDir :: string()
%% @doc Returns the path to the root of the template directory.
%% The templates which should be expanded must be placed there.
%% This option could be changed by providing the application environment variable
%% template_root.<br/>
%% The default value is <i>server_root()/templates</i>.
%% @end
%%
-spec(template_root/0 :: () -> string()).	     
template_root() ->
    case application:get_env(eptic, template_root) of
	undefined ->
            filename:join([server_root(), "templates"]);
	{ok, TemplateDir} ->
            TemplateDir
    end.

%%
%% @spec server_root() -> ServerRootDir :: string()
%% @doc Returns the path to the server root directory.
%% This option could be changed by providing the application environment variable
%% server_root.<br/>
%% The default value is the parent directory of the eptic application.
%% @end
%%
-spec(server_root/0 :: () -> string()).	     
server_root() ->
    case application:get_env(eptic, server_root) of
        undefined     -> 
	    Eptic = filename:split(code:which(eptic)),
	    ServerRoot = filename:join(lists:sublist(Eptic, length(Eptic)-4)),
	    application:set_env(eptic, server_root, ServerRoot),

	    ServerRoot;
        {ok, RootDir} -> 
	    RootDir
    end.

%%
%% @spec ecomponents() -> Ecomponents :: list({atom(), list(tuple())}) | nil()
%% @doc Returns the list of declared ecomponents with the provided configuration.
%% The ecomponents should be declared inside the <i>project.conf</i> file:
%% ```{ecomponents, [{name_of_ecomponent1, [ListOfConfiguration]},
%%                   {name_of_ecomponent2, [ListOfConfiguration]},
%%                   ...
%%                   {name_of_ecomponentN, [ListOfConfiguration]}]}.'''
%% All declared components will be started during the system start (in the order
%% of listing in configuration file). <br/>
%% If no ecomponents are declared, the empty list is returned.
%% @see //ecomponent/ecompontent
%%
-spec(ecomponents/0 :: () -> list({atom(), list(tuple())}) | nil()).
ecomponents() ->
    get_conf(ecomponents, []).

-spec(get_conf/1 :: (atom()) -> undefined | term()).
get_conf(Key) ->	     
    get_conf(Key, undefined).

-spec(get_conf/2 :: (atom(), term()) -> term()).	     
get_conf(Key, Default) ->
    case ets:lookup(e_conf, Key) of
	[] -> Default;
	[{_, Val}] -> Val;
	[{_, Val} | _] -> Val
    end.

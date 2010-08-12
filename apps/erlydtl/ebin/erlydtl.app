%% -*- mode: erlang -*-
{application, erlydtl,
 [{description, "ErlyDTL implements most but not all of the Django Template Language"},
  {vsn, "0.5.3"},
  {modules, [
             erlydtl,
             erlydtl_compiler,
             erlydtl_dateformat,
             erlydtl_dateformat_tests,  % FIXME
             erlydtl_deps,
             erlydtl_example_variable_storage, % FIXME
             erlydtl_filters,
             erlydtl_functional_tests, % FIXME
             erlydtl_parser,
             erlydtl_runtime,
             erlydtl_scanner,
             erlydtl_unittests % FIXME
            ]},
  {applications, [kernel, stdlib, crypto, syntax_tools, compiler]},
  {registered, []}
 ]}.





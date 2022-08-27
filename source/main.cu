#include <cstdint>

#include <cxxopts.hpp>

#include <astrid/server.hpp>
#include <astrid/user_interface.hpp>

std::int32_t main(const std::int32_t argc, char** argv)
{
  cxxopts::Options configuration("Astrid", "A relativistic ray tracing server and end-user application.");
  configuration.add_options()
    ("s,server", "Launch as headless server.", cxxopts::value<bool>        ()->default_value("false"))
    ("p,port"  , "Server port."              , cxxopts::value<std::int32_t>()->default_value("3000" ));
  const auto options = configuration.parse(argc, argv);

  options.count("server") 
    ? ast::server(options["port"].as<std::int32_t>()).run() 
    : ast::user_interface::run(argc, argv);

  return 0;
}
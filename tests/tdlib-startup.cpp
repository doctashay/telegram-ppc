#include "Sources/TDLibParameters.h"

#include <chrono>
#include <cstdlib>
#include <dlfcn.h>
#include <iostream>
#include <stdexcept>
#include <unistd.h>

using nlohmann::json;

int main(int argc, char **argv) {
  if (argc < 2 || argc > 3 || (argc == 3 && std::string(argv[2]) != "--modern")) {
    std::cerr << "Usage: tdlib-startup /path/to/libtdjson [--modern]\n";
    return 2;
  }
  void *library = dlopen(argv[1], RTLD_NOW | RTLD_LOCAL);
  if (!library) throw std::runtime_error(dlerror());
  auto create = reinterpret_cast<int (*)()>(dlsym(library, "td_create_client_id"));
  auto send = reinterpret_cast<void (*)(int, const char *)>(dlsym(library, "td_send"));
  auto receive = reinterpret_cast<const char *(*)(double)>(dlsym(library, "td_receive"));
  auto execute = reinterpret_cast<const char *(*)(const char *)>(dlsym(library, "td_execute"));
  if (!create || !send || !receive || !execute) throw std::runtime_error("Missing TDLib JSON API");
  execute("{\"@type\":\"setLogVerbosityLevel\",\"new_verbosity_level\":0}");

  char directory[] = "/tmp/sailplane-startup-test.XXXXXX";
  if (!mkdtemp(directory)) throw std::runtime_error("Cannot create test database directory");
  json parameters = {{"database_directory", directory}, {"files_directory", directory}, {"use_test_dc", true},
    {"api_id", 12345}, {"api_hash", std::string(32, '0')},
    {"system_language_code", "en"}, {"device_model", "Startup test"},
    {"system_version", "Test"}, {"application_version", "Test"}};
  const int client = create();
  const bool modern = argc == 3;
  json firstRequest = modern ? TDLibInitializationRequest(parameters) : parameters;
  firstRequest["@type"] = "setTdlibParameters";
  firstRequest["@extra"] = modern ? "compatible" : "flat";
  send(client, firstRequest.dump().c_str());
  bool rejectedFlat = modern, acceptedCompatible = false, phoneReady = false, closed = false;
  auto deadline = std::chrono::steady_clock::now() + std::chrono::seconds(20);
  while (!closed && std::chrono::steady_clock::now() < deadline) {
    const char *response = receive(0.1);
    if (!response) continue;
    json event = json::parse(response);
    if (event.value("@client_id", 0) != client) continue;
    if (event.value("@extra", "") == "flat") {
      rejectedFlat = event.value("@type", "") == "error";
      json request = TDLibInitializationRequest(parameters);
      request["@extra"] = "compatible";
      send(client, request.dump().c_str());
    } else if (event.value("@extra", "") == "compatible") {
      acceptedCompatible = event.value("@type", "") == "ok";
      if (!acceptedCompatible) std::cerr << event.dump() << '\n';
      if (!acceptedCompatible) send(client, "{\"@type\":\"close\"}");
    }
    if (event.value("@type", "") == "updateAuthorizationState") {
      const std::string state = event["authorization_state"].value("@type", "");
      if (state == "authorizationStateWaitEncryptionKey") {
        send(client, "{\"@type\":\"checkDatabaseEncryptionKey\",\"encryption_key\":\"\"}");
      } else if (state == "authorizationStateWaitPhoneNumber") {
        phoneReady = true;
        send(client, "{\"@type\":\"close\"}");
      }
      closed = state == "authorizationStateClosed";
    }
  }
  if (!rejectedFlat || !acceptedCompatible || !phoneReady || !closed) {
    std::cerr << "Startup regression: flat rejected=" << rejectedFlat
              << ", compatible accepted=" << acceptedCompatible << ", phone ready=" << phoneReady
              << ", closed=" << closed << '\n';
    return 1;
  }
  std::cout << (modern ? "Modern TDLib reaches phone sign-in with the compatible request\n"
                       : "TDLib 1.8.0 rejects the old request; the compatible request reaches phone sign-in\n");
  return 0;
}

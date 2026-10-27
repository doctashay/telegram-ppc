#pragma once

#include <nlohmann/json.hpp>
#include <utility>

inline nlohmann::json TDLibInitializationRequest(nlohmann::json parameters) {
  // TDLib 1.8.0 requires the nested object; newer builds use the flat fields.
  parameters["@type"] = "tdlibParameters";
  nlohmann::json request = parameters;
  request["@type"] = "setTdlibParameters";
  request["parameters"] = std::move(parameters);
  return request;
}

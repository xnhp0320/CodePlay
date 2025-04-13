#include "json.pb.h"
#include <google/protobuf/json/json.h>
#include <iostream>


namespace json = google::protobuf::json;

int main() {
    oneofmessage m;
    m.set_id(1);
    std::string output;

    auto ok = json::MessageToJsonString(m, &output, json::PrintOptions()); 
    if (ok.ok()) {
        std::cout << output << std::endl;
    }

    std::cout << m.test_oneof_case() << std::endl;
}

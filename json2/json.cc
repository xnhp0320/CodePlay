#include <google/protobuf/json/json.h>
#include <iostream>
#include "json.pb.h"

namespace json = google::protobuf::json;
namespace gp = google::protobuf;

int main() {
    idcard card;
    auto ret = json::JsonStringToMessage("{ \"id\": 2, \"name\": \"hehe\"}", &card, json::ParseOptions()); 
    if (ret.ok()) {
        std::cout << card.id() << " " << card.name() << std::endl;
    }
    return 0;
}

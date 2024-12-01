#include <absl/base/log_severity.h>
#include <absl/log/log.h>
#include <absl/log/check.h>
#include <absl/log/initialize.h>
#include <absl/log/globals.h>
#include <absl/strings/str_split.h>
#include <absl/strings/str_format.h>

class LinePrinterLogSink : public absl::LogSink {
    public:
        LinePrinterLogSink() : fp_(fopen("./abseil.log", "a")) {
            PCHECK(fp_ != nullptr) << "Failed to open abseil.log";
        }

        ~LinePrinterLogSink() {
            PCHECK(fclose(fp_) == 0) << "Failed to close abseil.log";
        }

        void Send(const absl::LogEntry& entry) override {
            for (absl::string_view line :
                    absl::StrSplit(entry.text_message_with_prefix(), absl::ByChar('\n'))) {
                absl::FPrintF(fp_, "%s\r", line);
            }
            fputc('\n', fp_);
        }

    private:
        FILE* const fp_;
};

static LinePrinterLogSink gLogSink;

int main() {
    absl::InitializeLog();
    //absl::SetStderrThreshold(absl::LogSeverityAtLeast::kInfo);
    LOG(INFO).ToSinkOnly(&gLogSink) << "hello" << " " << "world";

    return 0;
}

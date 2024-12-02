#include <absl/base/log_severity.h>
#include <absl/log/log.h>
#include <absl/log/check.h>
#include <absl/log/initialize.h>
#include <absl/log/globals.h>
#include <absl/strings/str_split.h>
#include <absl/strings/str_format.h>
#include <absl/flags/flag.h>
#include <absl/flags/parse.h>
#include <absl/flags/usage.h>

ABSL_FLAG(std::string, log, "./abseil.log", "log filename");

class LinePrinterLogSink : public absl::LogSink {
  public:
    LinePrinterLogSink(const std::string& filename) : fp_(fopen(filename.c_str(), "a")) {
      PCHECK(fp_ != nullptr) << "Failed to open " << filename;
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



int main(int argc, char *argv[])
{
  absl::SetProgramUsageMessage("");
  absl::ParseCommandLine(argc, argv);
  LinePrinterLogSink gLogSink{absl::GetFlag(FLAGS_log)};
  absl::InitializeLog();
  //absl::SetStderrThreshold(absl::LogSeverityAtLeast::kInfo);
  LOG(INFO).ToSinkOnly(&gLogSink) << "hello" << " " << "world";

  return 0;
}

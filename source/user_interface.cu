#include <astrid/user_interface.hpp>

#include <QApplication>
#include <QProcess>

#include <astrid/window.hpp>

namespace ast
{
std::int32_t user_interface::run(std::int32_t argc, char** argv)
{
  QApplication application(argc, argv);

  // Make local server.
  static QProcess process;
  if (process.state() == QProcess::ProcessState::NotRunning)
  {
    process.start         (argv[0], {"-s"});
    process.waitForStarted();
  }

  window window;
  window.show();

  return QApplication::exec();
}
}
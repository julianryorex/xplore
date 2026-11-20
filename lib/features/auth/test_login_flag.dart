/// Whether this build offers the email/password test login. Off unless built
/// with `--dart-define=ENABLE_TEST_LOGIN=true` (`make run-test-login`), so
/// release and TestFlight builds never show it.
const testLoginEnabled = bool.fromEnvironment('ENABLE_TEST_LOGIN');

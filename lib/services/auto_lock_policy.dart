/// The time the personal wallet may remain open without user interaction.
/// The background/hidden lifecycle still locks immediately.
class AutoLockPolicy {
  static const options = [1, 2, 3];
  static const defaultMinutes = 2;

  static bool valid(int minutes) => options.contains(minutes);

  static Duration timeout(int minutes) {
    if (!valid(minutes)) throw ArgumentError.value(minutes, 'minutes');
    return Duration(minutes: minutes);
  }
}

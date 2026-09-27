/// Pure time-of-day greeting text for the dashboard header. Kept separate
/// from any widget so it can be unit tested without pumping a tree.
String greetingForHour(int hour) {
  if (hour < 5) return 'Good night';
  if (hour < 12) return 'Good morning';
  if (hour < 17) return 'Good afternoon';
  if (hour < 21) return 'Good evening';
  return 'Good night';
}

/// A calendar date, always UTC midnight, so day maths never shifts with time zones or DST.
typedef Day = DateTime;

Day day(int y, int m, int d) => DateTime.utc(y, m, d);
Day dayOf(DateTime t) => DateTime.utc(t.year, t.month, t.day);
Day addDays(Day d, int n) => DateTime.utc(d.year, d.month, d.day + n);
int daysBetween(Day a, Day b) => b.difference(a).inDays;
int daysInMonth(int y, int m) => DateTime.utc(y, m + 1, 0).day;

String dayKey(Day d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
Day parseDayKey(String s) => DateTime.parse('${s}T00:00:00Z');

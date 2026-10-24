import 'package:drift/drift.dart';

/// Columns every row carries so cloud sync can be added without a migration.
/// [updatedAt] is a hybrid-clock stamp in ms, [deletedAt] a soft-delete stamp (so a delete
/// can sync), [dirty] marks rows with changes not yet uploaded.
mixin Meta on Table {
  IntColumn get updatedAt => integer().withDefault(const Constant(0))();
  IntColumn get deletedAt => integer().nullable()();
  BoolColumn get dirty => boolean().withDefault(const Constant(false))();
}

/// Calendar dates are 'YYYY-MM-DD' text; money is int minor units.
class Settings extends Table with Meta {
  TextColumn get id => text()(); // always 'settings'
  TextColumn get currency => text().withDefault(const Constant('BDT'))();
  BoolColumn get lakh => boolean().withDefault(const Constant(true))();
  IntColumn get payday => integer().nullable()();
  IntColumn get everyDays => integer().nullable()();
  IntColumn get budget => integer().withDefault(const Constant(0))();
  IntColumn get baseSalary => integer().withDefault(const Constant(0))();
  TextColumn get tracking => text().withDefault(const Constant('balance'))();
  TextColumn get displayName => text().nullable()();

  /// 'male', 'female', 'other', 'private' (prefers not to say) or null (not set).
  TextColumn get gender => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// id is the date, so two phones can never create two check-ins for one day.
@DataClassName('CheckinRow')
class Checkins extends Table with Meta {
  TextColumn get id => text()();
  IntColumn get balance => integer().nullable()();
  TextColumn get note => text().withDefault(const Constant(''))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('IncomeRow')
class Incomes extends Table with Meta {
  TextColumn get id => text()();
  TextColumn get date => text()();
  IntColumn get amount => integer()();
  TextColumn get source => text().withDefault(const Constant('salary'))();
  TextColumn get note => text().withDefault(const Constant(''))();
  BoolColumn get afterCheckin => boolean().withDefault(const Constant(false))();
  BoolColumn get countsInPrevious =>
      boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('ExpenseRow')
class Expenses extends Table with Meta {
  TextColumn get id => text()();
  TextColumn get date => text()();
  IntColumn get amount => integer()();
  TextColumn get categoryId =>
      text().nullable()(); // soft reference; missing = Uncategorised
  TextColumn get note => text().withDefault(const Constant(''))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class Categories extends Table with Meta {
  TextColumn get id =>
      text()(); // slug for the defaults, uuid for the user's own
  TextColumn get name => text()();
  IntColumn get color => integer()();
  IntColumn get sort => integer().withDefault(const Constant(0))();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// A fixed cost (gym, internet). Pending until paid for the current cycle.
class Bills extends Table with Meta {
  TextColumn get id => text()();
  TextColumn get name => text()();
  IntColumn get amount => integer()();
  TextColumn get paidForCycle =>
      text().nullable()(); // start date of the cycle it was paid in
  BoolColumn get archived => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// A cycle boundary. id is the date.
class CycleStarts extends Table with Meta {
  TextColumn get id => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

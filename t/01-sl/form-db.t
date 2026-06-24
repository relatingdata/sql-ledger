use v5.40;

use utf8;
use open ':std', ':encoding(utf8)';

use FindBin;
use lib "$FindBin::Bin/../..";

use DBI;
use Test::More tests => 5;

chdir "$FindBin::Bin/../..";

use_ok 'SL::Form' or BAIL_OUT 'Unable to load SL::Form';

my $dbh;

sub setup_db {
  $dbh = DBI->connect('dbi:SQLite:dbname=:memory:', '', '',
    {AutoCommit => 1, RaiseError => 1, FetchHashKeyName => 'NAME_lc'});

  $dbh->do('CREATE TABLE defaults (fldname TEXT, fldvalue TEXT)');
  $dbh->do("INSERT INTO defaults VALUES ('company', 'Test Corp')");
  $dbh->do("INSERT INTO defaults VALUES ('precision', '2')");
  $dbh->do("INSERT INTO defaults VALUES ('dateformat', 'yyyy-mm-dd')");

  $dbh->do('CREATE TABLE employee (id INTEGER PRIMARY KEY, login TEXT, name TEXT)');
  $dbh->do("INSERT INTO employee VALUES (1, 'admin', 'Admin User')");
  $dbh->do("INSERT INTO employee VALUES (2, 'jdoe', 'Jane Doe')");

  $dbh->do('CREATE TABLE curr (curr TEXT, prec INTEGER, rn INTEGER)');
  $dbh->do("INSERT INTO curr VALUES ('USD', 2, 1)");
  $dbh->do("INSERT INTO curr VALUES ('EUR', 2, 2)");
  $dbh->do("INSERT INTO curr VALUES ('CHF', 2, 3)");

  $dbh->do('CREATE TABLE parts (id INTEGER PRIMARY KEY, onhand REAL)');
  $dbh->do("INSERT INTO parts VALUES (1, 100.5)");
  $dbh->do("INSERT INTO parts VALUES (2, 0)");

  $dbh->do('CREATE TABLE balances (id INTEGER PRIMARY KEY, amount REAL)');
  $dbh->do("INSERT INTO balances VALUES (1, 500.00)");

  return $dbh;
}

setup_db();

subtest 'get_defaults' => sub {
  my $form = SL::Form->new;

  my %defaults = $form->get_defaults($dbh, ['%']);
  is $defaults{company}, 'Test Corp', 'Company from defaults';
  is $defaults{precision}, '2', 'Precision from defaults';
  is $defaults{dateformat}, 'yyyy-mm-dd', 'Date format from defaults';

  my %partial = $form->get_defaults($dbh, ['precision']);
  is $partial{precision}, '2', 'Partial match works';
  ok !exists $partial{company}, 'Non-matching fields excluded';
};

subtest 'get_employee' => sub {
  my $form = SL::Form->new;

  $form->{login} = 'admin';
  my @result = $form->get_employee($dbh);
  is $result[0], 'Admin User', 'Employee name found';
  is $result[1], 1, 'Employee id found';

  $form->{login} = 'jdoe';
  @result = $form->get_employee($dbh);
  is $result[0], 'Jane Doe', 'Second employee name';
  is $result[1], 2, 'Second employee id';

  $form->{login} = 'nobody';
  @result = $form->get_employee($dbh);
  is $result[0], '', 'Unknown employee returns empty name';
  is $result[1], 0, 'Unknown employee returns 0 id';

  $form->{login} = 'admin@domain.com';
  @result = $form->get_employee($dbh);
  is $result[0], 'Admin User', 'Email-style login strips domain';
};

subtest 'get_currencies' => sub {
  my $form = SL::Form->new;
  $form->{currency} = 'EUR';

  my $currencies = $form->get_currencies({}, $dbh);
  is $currencies, 'USD:EUR:CHF', 'All currencies returned';
  is $form->{precision}, 2, 'Precision set for matching currency';
};

subtest 'get_onhand' => sub {
  my $form = SL::Form->new;
  $form->{rowcount} = 2;
  $form->{id_1} = 1;
  $form->{id_2} = 2;

  $form->get_onhand({}, $dbh);
  is $form->{onhand_1}, 100.5, 'First item onhand';
  is $form->{onhand_2}, 0, 'Second item onhand zero';
};

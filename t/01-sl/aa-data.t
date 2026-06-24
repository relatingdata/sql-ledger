use v5.40;

use utf8;
use open ':std', ':encoding(utf8)';

use FindBin;
use lib "$FindBin::Bin/../..";
use lib "$FindBin::Bin/..";

use TestDB;
use Test::More tests => 3;

chdir "$FindBin::Bin/../..";

use_ok 'SL::AA' or BAIL_OUT 'Unable to load SL::AA';

my $dbh      = TestDB::new_dbh();
TestDB::seed_data($dbh);
my $form     = TestDB::new_form($dbh);
my $myconfig = TestDB::myconfig($dbh);

# Add addresses and contacts for customers/vendors
$dbh->do("INSERT INTO address (id, trans_id, address1, city, country) VALUES (10, 100, '123 Main St', 'Springfield', 'US')");
$dbh->do("INSERT INTO address (id, trans_id, address1, city, country) VALUES (11, 200, '789 Elm Dr', 'Chicago', 'US')");
$dbh->do("INSERT INTO contact (id, trans_id, firstname, lastname) VALUES (1, 100, 'John', 'Smith')");
$dbh->do("INSERT INTO contact (id, trans_id, firstname, lastname) VALUES (2, 200, 'Bob', 'Supply')");

# Create AR transactions
$dbh->do("INSERT INTO ar (id, invnumber, transdate, customer_id, amount, netamount, paid, duedate, approved, curr) VALUES (5001, 'INV-001', '2025-01-15', 100, 500.00, 467.29, 0, '2025-02-15', '1', 'USD')");
$dbh->do("INSERT INTO ar (id, invnumber, transdate, customer_id, amount, netamount, paid, duedate, approved, curr) VALUES (5002, 'INV-002', '2025-02-01', 101, 1000.00, 934.58, 1000.00, '2025-03-01', '1', 'USD')");

# acc_trans for AR transactions
$dbh->do("INSERT INTO acc_trans (trans_id, chart_id, amount, transdate, approved) VALUES (5001, 1100, 500.00, '2025-01-15', '1')");
$dbh->do("INSERT INTO acc_trans (trans_id, chart_id, amount, transdate, approved) VALUES (5001, 4000, -467.29, '2025-01-15', '1')");
$dbh->do("INSERT INTO acc_trans (trans_id, chart_id, amount, transdate, approved) VALUES (5001, 2100, -32.71, '2025-01-15', '1')");
$dbh->do("INSERT INTO acc_trans (trans_id, chart_id, amount, transdate, approved) VALUES (5002, 1100, 1000.00, '2025-02-01', '1')");
$dbh->do("INSERT INTO acc_trans (trans_id, chart_id, amount, transdate, approved) VALUES (5002, 4000, -934.58, '2025-02-01', '1')");
$dbh->do("INSERT INTO acc_trans (trans_id, chart_id, amount, transdate, approved) VALUES (5002, 2100, -65.42, '2025-02-01', '1')");

# Create AP transactions
$dbh->do("INSERT INTO ap (id, invnumber, transdate, vendor_id, amount, netamount, paid, duedate, approved, curr) VALUES (6001, 'BILL-001', '2025-01-20', 200, 300.00, 280.37, 0, '2025-02-20', '1', 'USD')");

$dbh->do("INSERT INTO acc_trans (trans_id, chart_id, amount, transdate, approved) VALUES (6001, 2000, -300.00, '2025-01-20', '1')");
$dbh->do("INSERT INTO acc_trans (trans_id, chart_id, amount, transdate, approved) VALUES (6001, 5000, 280.37, '2025-01-20', '1')");
$dbh->do("INSERT INTO acc_trans (trans_id, chart_id, amount, transdate, approved) VALUES (6001, 2100, 19.63, '2025-01-20', '1')");

# Need address for customer 101 too
$dbh->do("INSERT INTO address (id, trans_id, address1, city, country) VALUES (12, 101, '456 Oak Ave', 'Portland', 'US')");
$dbh->do("INSERT INTO contact (id, trans_id, firstname, lastname) VALUES (3, 101, 'Mary', 'Jones')");

subtest 'AR transactions' => sub {
  $form->{vc} = 'customer';
  $form->{sort} = 'id';
  delete $form->{transactions};

  SL::AA->transactions($myconfig, $form);

  ok $form->{transactions}, 'AR transaction list populated';
  ok scalar @{$form->{transactions}} >= 2, 'Found AR transactions';

  my @invnums = map { $_->{invnumber} } @{$form->{transactions}};
  ok grep(/INV-001/, @invnums), 'INV-001 found';
  ok grep(/INV-002/, @invnums), 'INV-002 found';

  my %by_inv = map { $_->{invnumber} => $_ } @{$form->{transactions}};
  is $by_inv{'INV-001'}{amount}, 500, 'INV-001 amount';
  is $by_inv{'INV-001'}{name}, 'ACME Corp', 'INV-001 customer name';
  is $by_inv{'INV-002'}{amount}, 1000, 'INV-002 amount';
};

subtest 'AP transactions' => sub {
  $form->{vc} = 'vendor';
  $form->{sort} = 'id';
  delete $form->{transactions};

  SL::AA->transactions($myconfig, $form);

  ok $form->{transactions}, 'AP transaction list populated';
  ok scalar @{$form->{transactions}} >= 1, 'Found AP transactions';

  my @invnums = map { $_->{invnumber} } @{$form->{transactions}};
  ok grep(/BILL-001/, @invnums), 'BILL-001 found';

  my %by_inv = map { $_->{invnumber} => $_ } @{$form->{transactions}};
  is $by_inv{'BILL-001'}{amount}, 300, 'BILL-001 amount';
  is $by_inv{'BILL-001'}{name}, 'Supplier Co', 'BILL-001 vendor name';
};

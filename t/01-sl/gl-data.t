use v5.40;

use utf8;
use open ':std', ':encoding(utf8)';

use FindBin;
use lib "$FindBin::Bin/../..";
use lib "$FindBin::Bin/..";

use TestDB;
use Test::More tests => 3;

chdir "$FindBin::Bin/../..";

use_ok 'SL::GL' or BAIL_OUT 'Unable to load SL::GL';

my $dbh      = TestDB::new_dbh();
TestDB::seed_data($dbh);
my $form     = TestDB::new_form($dbh);
my $myconfig = TestDB::myconfig($dbh);

# Add addresses for customer/vendor (needed for GL UNION queries)
$dbh->do("INSERT INTO address (id, trans_id, address1, city, country) VALUES (10, 100, '123 Main St', 'Springfield', 'US')");
$dbh->do("INSERT INTO address (id, trans_id, address1, city, country) VALUES (11, 200, '789 Elm Dr', 'Chicago', 'US')");

# Create GL transactions
$dbh->do("INSERT INTO gl (id, reference, description, transdate, employee_id, approved) VALUES (1001, 'GL-001', 'Office Supplies Purchase', '2025-01-15', 1, '1')");
$dbh->do("INSERT INTO gl (id, reference, description, transdate, employee_id, approved) VALUES (1002, 'GL-002', 'Bank Transfer', '2025-02-01', 1, '1')");

# acc_trans for GL-001
$dbh->do("INSERT INTO acc_trans (trans_id, chart_id, amount, transdate, approved) VALUES (1001, 5100, 150.00, '2025-01-15', '1')");
$dbh->do("INSERT INTO acc_trans (trans_id, chart_id, amount, transdate, approved) VALUES (1001, 1000, -150.00, '2025-01-15', '1')");

# acc_trans for GL-002
$dbh->do("INSERT INTO acc_trans (trans_id, chart_id, amount, transdate, approved) VALUES (1002, 1000, 500.00, '2025-02-01', '1')");
$dbh->do("INSERT INTO acc_trans (trans_id, chart_id, amount, transdate, approved) VALUES (1002, 1100, -500.00, '2025-02-01', '1')");

subtest 'transactions - all GL' => sub {
  $form->{category} = 'X';
  $form->{sort} = 'transdate';
  delete $form->{GL};

  SL::GL->transactions($myconfig, $form);

  ok $form->{GL}, 'GL list populated';
  ok scalar @{$form->{GL}} >= 4, 'Found GL line items';

  my @gl_entries = grep { $_->{type} eq 'gl' } @{$form->{GL}};
  ok scalar @gl_entries >= 4, 'Has GL-type entries';

  my @refs = map { $_->{reference} } @gl_entries;
  ok grep(/GL-001/, @refs), 'GL-001 found';
  ok grep(/GL-002/, @refs), 'GL-002 found';
};

subtest 'transactions - filtered by date' => sub {
  delete $form->{GL};
  $form->{category} = 'X';
  $form->{datefrom} = '2025-01-01';
  $form->{dateto}   = '2025-01-31';

  SL::GL->transactions($myconfig, $form);

  my @gl_entries = grep { $_->{type} eq 'gl' } @{$form->{GL}};
  ok scalar @gl_entries >= 2, 'Found GL entries in date range';

  my @refs = map { $_->{reference} } @gl_entries;
  ok grep(/GL-001/, @refs), 'GL-001 in January';
  ok !grep(/GL-002/, @refs), 'GL-002 not in January (Feb entry)';
};

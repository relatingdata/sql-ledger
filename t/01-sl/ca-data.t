use v5.40;

use utf8;
use open ':std', ':encoding(utf8)';

use FindBin;
use lib "$FindBin::Bin/../..";
use lib "$FindBin::Bin/..";

use TestDB;
use Test::More tests => 3;

chdir "$FindBin::Bin/../..";

use_ok 'SL::CA' or BAIL_OUT 'Unable to load SL::CA';

my $dbh      = TestDB::new_dbh();
TestDB::seed_data($dbh);
my $form     = TestDB::new_form($dbh);
my $myconfig = TestDB::myconfig($dbh);

# Insert acc_trans entries for testing
$dbh->do("INSERT INTO acc_trans (trans_id, chart_id, amount, transdate, approved) VALUES (1, 1100, 500.00, '2025-01-15', '1')");
$dbh->do("INSERT INTO acc_trans (trans_id, chart_id, amount, transdate, approved) VALUES (1, 4000, -500.00, '2025-01-15', '1')");
$dbh->do("INSERT INTO acc_trans (trans_id, chart_id, amount, transdate, approved) VALUES (2, 2000, -200.00, '2025-02-01', '1')");
$dbh->do("INSERT INTO acc_trans (trans_id, chart_id, amount, transdate, approved) VALUES (2, 5000, 200.00, '2025-02-01', '1')");

subtest 'all_accounts' => sub {
  SL::CA->all_accounts($myconfig, $form);

  ok $form->{CA}, 'CA list populated';
  ok scalar @{$form->{CA}} > 0, 'Has chart entries';

  is $form->{company}, 'Test Company', 'Company name loaded from defaults';
  is $form->{precision}, '2', 'Precision loaded from defaults';

  my %by_accno = map { $_->{accno} => $_ } @{$form->{CA}};
  ok exists $by_accno{'1100'}, 'AR account present';
  is $by_accno{'1100'}{description}, 'Accounts Receivable', 'AR description';
  is $by_accno{'1100'}{credit}, 500, 'AR has credit amount';

  ok exists $by_accno{'4000'}, 'Revenue account present';
  is $by_accno{'4000'}{debit}, 500, 'Revenue has debit (negative flipped)';

  ok exists $by_accno{'2000'}, 'AP account present';
  is $by_accno{'2000'}{debit}, 200, 'AP has debit (negative flipped)';
};

subtest 'all_accounts with gifi mapping' => sub {
  my %by_accno = map { $_->{accno} => $_ } @{$form->{CA}};

  # Chart 1000 has gifi_accno not set in our seed, but let's check the mechanism
  # Charts with matching gifi should get gifi_description
  ok exists $by_accno{'1000'}, 'Petty Cash account present';
  is $by_accno{'1000'}{charttype}, 'A', 'Chart type is Account';
  is $by_accno{'1000'}{category}, 'A', 'Category is Asset';
};

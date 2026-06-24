use v5.40;

use utf8;
use open ':std', ':encoding(utf8)';

use FindBin;
use lib "$FindBin::Bin/../..";
use lib "$FindBin::Bin/..";

use TestDB;
use Test::More tests => 2;

chdir "$FindBin::Bin/../..";

use_ok 'SL::RC' or BAIL_OUT 'Unable to load SL::RC';

my $dbh      = TestDB::new_dbh();
TestDB::seed_data($dbh);
my $form     = TestDB::new_form($dbh);
my $myconfig = TestDB::myconfig($dbh);

subtest 'paymentaccounts' => sub {
  SL::RC->paymentaccounts($myconfig, $form);

  ok $form->{PR}, 'Payment account list populated';
  ok scalar @{$form->{PR}} > 0, 'Has payment accounts';

  my @accnos = map { $_->{accno} } @{$form->{PR}};
  ok grep(/^1000$/, @accnos), 'Petty Cash in payment accounts';
  ok grep(/^1100$/, @accnos), 'AR in payment accounts';

  my %by_accno = map { $_->{accno} => $_ } @{$form->{PR}};
  is $by_accno{'1000'}{description}, 'Petty Cash', 'Account description';
};

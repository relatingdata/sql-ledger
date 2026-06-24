use v5.40;

use utf8;
use open ':std', ':encoding(utf8)';

use FindBin;
use lib "$FindBin::Bin/../..";
use lib "$FindBin::Bin/..";

use TestDB;
use Test::More tests => 6;

chdir "$FindBin::Bin/../..";

use_ok 'SL::AM' or BAIL_OUT 'Unable to load SL::AM';

my $dbh      = TestDB::new_dbh();
TestDB::seed_data($dbh);
my $form     = TestDB::new_form($dbh);
my $myconfig = TestDB::myconfig($dbh);

subtest 'departments' => sub {
  delete $form->{ALL};

  SL::AM->departments($myconfig, $form);

  ok $form->{ALL}, 'Department list populated';
  ok scalar @{$form->{ALL}} >= 2, 'Found departments';

  my @descs = sort map { $_->{description} } @{$form->{ALL}};
  ok grep(/Sales/, @descs), 'Sales department found';
  ok grep(/Engineering/, @descs), 'Engineering department found';
};

subtest 'warehouses' => sub {
  delete $form->{ALL};

  SL::AM->warehouses($myconfig, $form);

  ok $form->{ALL}, 'Warehouse list populated';
  ok scalar @{$form->{ALL}} >= 1, 'Found warehouses';

  my @descs = map { $_->{description} } @{$form->{ALL}};
  ok grep(/Main Warehouse/, @descs), 'Main Warehouse found';
};

subtest 'business' => sub {
  delete $form->{ALL};

  SL::AM->business($myconfig, $form);

  ok $form->{ALL}, 'Business list populated';
  ok scalar @{$form->{ALL}} >= 2, 'Found businesses';

  my @descs = map { $_->{description} } @{$form->{ALL}};
  ok grep(/Retail/, @descs), 'Retail business found';
};

subtest 'currencies' => sub {
  delete $form->{ALL};

  SL::AM->currencies($myconfig, $form);

  ok $form->{ALL}, 'Currency list populated';
  ok scalar @{$form->{ALL}} >= 2, 'Found currencies';

  my @currs = map { $_->{curr} } @{$form->{ALL}};
  ok grep(/USD/, @currs), 'USD found';
  ok grep(/EUR/, @currs), 'EUR found';
};

subtest 'gifi_accounts' => sub {
  # Add GIFI data
  $dbh->do("INSERT INTO gifi (accno, description) VALUES ('1000', 'Cash and equivalents')");
  $dbh->do("INSERT INTO gifi (accno, description) VALUES ('2000', 'Liabilities')");

  delete $form->{ALL};

  SL::AM->gifi_accounts($myconfig, $form);

  ok $form->{ALL}, 'GIFI list populated';
  ok scalar @{$form->{ALL}} >= 2, 'Found GIFI entries';

  my @accnos = map { $_->{accno} } @{$form->{ALL}};
  ok grep(/1000/, @accnos), 'GIFI 1000 found';
  ok grep(/2000/, @accnos), 'GIFI 2000 found';
};

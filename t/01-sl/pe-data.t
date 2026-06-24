use v5.40;

use utf8;
use open ':std', ':encoding(utf8)';

use FindBin;
use lib "$FindBin::Bin/../..";
use lib "$FindBin::Bin/..";

use TestDB;
use Test::More tests => 4;

chdir "$FindBin::Bin/../..";

use_ok 'SL::PE' or BAIL_OUT 'Unable to load SL::PE';

my $dbh      = TestDB::new_dbh();
TestDB::seed_data($dbh);
my $form     = TestDB::new_form($dbh);
my $myconfig = TestDB::myconfig($dbh);

# Add extra projects
$dbh->do("INSERT INTO project (id, projectnumber, description, startdate) VALUES (3, 'P-003', 'Marketing Campaign', '2025-03-01')");
$dbh->do("INSERT INTO project (id, projectnumber, description, startdate) VALUES (4, 'P-004', 'IT Infrastructure', '2025-04-01')");

# Add partsgroups
$dbh->do("INSERT INTO partsgroup (id, partsgroup) VALUES (1, 'Electronics')");
$dbh->do("INSERT INTO partsgroup (id, partsgroup) VALUES (2, 'Office Supplies')");
$dbh->do("INSERT INTO partsgroup (id, partsgroup) VALUES (3, 'Hardware')");

# Add pricegroups
$dbh->do("INSERT INTO pricegroup (id, pricegroup) VALUES (1, 'Wholesale')");
$dbh->do("INSERT INTO pricegroup (id, pricegroup) VALUES (2, 'Retail')");

subtest 'projects - list all' => sub {
  delete $form->{all_project};
  $form->{sort} = 'projectnumber';

  my $count = SL::PE->projects($myconfig, $form);

  ok $form->{all_project}, 'Project list populated';
  ok $count >= 3, "Found $count projects (expected >= 3)";

  my @nums = sort map { $_->{projectnumber} } @{$form->{all_project}};
  ok grep(/PRJ-001/, @nums), 'PRJ-001 found';
  ok grep(/P-003/, @nums), 'P-003 found';
};

subtest 'projects - search by number' => sub {
  delete $form->{all_project};
  $form->{projectnumber} = 'P-003';

  my $count = SL::PE->projects($myconfig, $form);

  is $count, 1, 'Found exactly 1 project matching P-003';
  is $form->{all_project}[0]{description}, 'Marketing Campaign', 'Correct project description';

  delete $form->{projectnumber};
};

subtest 'partsgroups' => sub {
  delete $form->{item_list};
  $form->{sort} = 'partsgroup';

  SL::PE->partsgroups($myconfig, $form);

  ok $form->{item_list}, 'Partsgroup list populated';
  ok scalar @{$form->{item_list}} >= 3, 'Found partsgroups';

  my @names = sort map { $_->{partsgroup} } @{$form->{item_list}};
  ok grep(/Electronics/, @names), 'Electronics found';
  ok grep(/Hardware/, @names), 'Hardware found';
};

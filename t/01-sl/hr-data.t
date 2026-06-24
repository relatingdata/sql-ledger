use v5.40;

use utf8;
use open ':std', ':encoding(utf8)';

use FindBin;
use lib "$FindBin::Bin/../..";
use lib "$FindBin::Bin/..";

use TestDB;
use Test::More tests => 4;

chdir "$FindBin::Bin/../..";

use_ok 'SL::HR' or BAIL_OUT 'Unable to load SL::HR';

my $dbh      = TestDB::new_dbh();
TestDB::seed_data($dbh);
my $form     = TestDB::new_form($dbh);
my $myconfig = TestDB::myconfig($dbh);

# Add employee addresses
$dbh->do("INSERT INTO address (id, trans_id, address1, city, country) VALUES (20, 1, '100 Admin Rd', 'Capital', 'US')");
$dbh->do("INSERT INTO address (id, trans_id, address1, city, country) VALUES (21, 2, '200 Sales St', 'Metro', 'US')");
$dbh->do("INSERT INTO address (id, trans_id, address1, city, country) VALUES (22, 3, '300 Sales Blvd', 'Suburb', 'US')");

subtest 'employees - list all' => sub {
  delete $form->{all_employee};
  $form->{sort} = 'name';

  SL::HR->employees($myconfig, $form);

  ok $form->{all_employee}, 'Employee list populated';
  ok scalar @{$form->{all_employee}} >= 3, 'Found employees';

  my @names = sort map { $_->{name} } @{$form->{all_employee}};
  ok grep(/Admin User/, @names), 'Admin User found';
  ok grep(/Jane Doe/, @names), 'Jane Doe found';
  ok grep(/Sales Person/, @names), 'Sales Person found';
};

subtest 'employees - filter sales' => sub {
  delete $form->{all_employee};
  $form->{status} = 'sales';
  $form->{sort} = 'name';

  SL::HR->employees($myconfig, $form);

  ok $form->{all_employee}, 'Sales employee list populated';
  is scalar @{$form->{all_employee}}, 2, 'Found 2 sales employees';

  my @names = sort map { $_->{name} } @{$form->{all_employee}};
  ok grep(/Jane Doe/, @names), 'Jane Doe is sales';
  ok grep(/Sales Person/, @names), 'Sales Person is sales';
  ok !grep(/Admin User/, @names), 'Admin User is not sales';

  delete $form->{status};
};

subtest 'employees - address included' => sub {
  delete $form->{all_employee};
  $form->{sort} = 'name';

  SL::HR->employees($myconfig, $form);

  my %by_name = map { $_->{name} => $_ } @{$form->{all_employee}};
  like $by_name{'Admin User'}{address}, qr/100 Admin Rd/, 'Admin address included';
  like $by_name{'Jane Doe'}{address}, qr/200 Sales St/, 'Jane address included';
};

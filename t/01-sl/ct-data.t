use v5.40;

use utf8;
use open ':std', ':encoding(utf8)';

use FindBin;
use lib "$FindBin::Bin/../..";
use lib "$FindBin::Bin/..";

use TestDB;
use Test::More tests => 3;

chdir "$FindBin::Bin/../..";

use_ok 'SL::CT' or BAIL_OUT 'Unable to load SL::CT';

my $dbh      = TestDB::new_dbh();
TestDB::seed_data($dbh);
my $form     = TestDB::new_form($dbh);
my $myconfig = TestDB::myconfig($dbh);

# Add addresses and contacts for our customers/vendors
$dbh->do("INSERT INTO address (id, trans_id, address1, city, state, zipcode, country) VALUES (10, 100, '123 Main St', 'Springfield', 'IL', '62701', 'US')");
$dbh->do("INSERT INTO address (id, trans_id, address1, city, state, zipcode, country) VALUES (11, 101, '456 Oak Ave', 'Portland', 'OR', '97201', 'US')");
$dbh->do("INSERT INTO address (id, trans_id, address1, city, state, zipcode, country) VALUES (12, 200, '789 Elm Dr', 'Chicago', 'IL', '60601', 'US')");
$dbh->do("INSERT INTO address (id, trans_id, address1, city, state, zipcode, country) VALUES (13, 201, '321 Pine Ln', 'Boston', 'MA', '02101', 'US')");

$dbh->do("INSERT INTO contact (id, trans_id, firstname, lastname, email) VALUES (1, 100, 'John', 'Smith', 'john\@acme.com')");
$dbh->do("INSERT INTO contact (id, trans_id, firstname, lastname, email) VALUES (2, 101, 'Mary', 'Jones', 'mary\@widget.com')");
$dbh->do("INSERT INTO contact (id, trans_id, firstname, lastname, email) VALUES (3, 200, 'Bob', 'Supply', 'bob\@supplier.com')");
$dbh->do("INSERT INTO contact (id, trans_id, firstname, lastname, email) VALUES (4, 201, 'Amy', 'Parts', 'amy\@parts.com')");

subtest 'search customers' => sub {
  $form->{db} = 'customer';
  $form->{ARAP} = 'ar';
  $form->{sort} = 'name';
  $form->{status} = '';
  delete $form->{CT};

  SL::CT->search($myconfig, $form);

  ok $form->{CT}, 'Customer list populated';
  is scalar @{$form->{CT}}, 2, 'Found 2 customers';

  my @names = sort map { $_->{name} } @{$form->{CT}};
  is_deeply \@names, ['ACME Corp', 'Widget Inc'], 'Customer names correct';
};

subtest 'search vendors' => sub {
  $form->{db} = 'vendor';
  $form->{ARAP} = 'ap';
  $form->{sort} = 'name';
  $form->{status} = '';
  delete $form->{CT};

  SL::CT->search($myconfig, $form);

  ok $form->{CT}, 'Vendor list populated';
  is scalar @{$form->{CT}}, 2, 'Found 2 vendors';

  my @names = sort map { $_->{name} } @{$form->{CT}};
  is_deeply \@names, ['Parts Ltd', 'Supplier Co'], 'Vendor names correct';
};

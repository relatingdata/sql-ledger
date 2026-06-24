use v5.40;

use utf8;
use open ':std', ':encoding(utf8)';

use FindBin;
use lib "$FindBin::Bin/../..";

use File::Temp 'tempfile';

use Test::More tests => 5;

chdir "$FindBin::Bin/../..";

use_ok 'SL::Menu' or BAIL_OUT 'Unable to load SL::Menu';

my $menu;

subtest 'Menu inherits from Inifile' => sub {
  isa_ok 'SL::Menu', 'SL::Inifile';
};

subtest 'Load menu from ini file' => sub {
  my ($fh, $filename) = tempfile(UNLINK => 1);
  print $fh <<~'INI';
    [AR]
    module=ar.pl
    action=search

    [AR--Transactions]
    module=ar.pl
    action=transactions

    [AR--Reports]
    module=rp.pl
    action=report

    [AP]
    module=ap.pl
    action=search

    [AP--Transactions]
    module=ap.pl
    action=transactions
    INI
  close $fh;

  $menu = SL::Menu->new($filename);

  is $menu->{AR}{module}, 'ar.pl', 'AR module';
  is $menu->{'AR--Transactions'}{module}, 'ar.pl', 'AR--Transactions module';
  is scalar @{$menu->{ORDER}}, 5, 'Five menu entries in ORDER';
};

subtest 'access_control - top level' => sub {
  my $myconfig = {acs => ''};

  my @items = $menu->access_control($myconfig, '');
  is_deeply \@items, ['AR', 'AP'], 'Top-level items without exclusions';
};

subtest 'access_control - with exclusions' => sub {
  my $myconfig = {acs => 'AR--Transactions'};

  my @items = $menu->access_control($myconfig, 'AR');
  ok !grep(/^AR--Transactions$/, @items), 'Excluded item not in result';
};

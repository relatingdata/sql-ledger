use v5.40;

use utf8;
use open ':std', ':encoding(utf8)';

use FindBin;
use lib "$FindBin::Bin/../..";

use Test::More tests => 3;

chdir "$FindBin::Bin/../..";

use_ok 'SL::JS' or BAIL_OUT 'Unable to load SL::JS';

subtest 'check_all generates correct JavaScript' => sub {
  my $output;
  open my $fh, '>', \$output;
  my $old = select $fh;

  SL::JS->check_all('selectall', 'checked_\d+');

  select $old;
  close $fh;

  like $output, qr/function CheckAll\(\)/, 'Function declaration present';
  like $output, qr/frm\.selectall\.checked/, 'Checkbox name used';
  like $output, qr{/checked_\\d\+/}, 'Match pattern included';
  like $output, qr/<script/, 'Script tag present';
  like $output, qr{</script>}, 'Closing script tag present';
};

subtest 'change_report generates correct JavaScript' => sub {
  my $form = {
    name       => 'Test Report',
    date       => '2025-01-01',
    all_report => [],
  };

  my $output;
  open my $fh, '>', \$output;
  my $old = select $fh;

  SL::JS->change_report($form, ['name'], ['l_date'], {});

  select $old;
  close $fh;

  like $output, qr/function ChangeReport\(\)/, 'Function declaration present';
  like $output, qr/var name = Array/, 'Input variable declared';
  like $output, qr/var l_date = Array/, 'Checked variable declared';
  like $output, qr/name\[0\] = "Test Report"/, 'Input default value set';
  like $output, qr/frm\.name\.value/, 'Input assignment present';
  like $output, qr/frm\.l_date\.checked/, 'Checked assignment present';
};

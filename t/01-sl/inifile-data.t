use v5.40;

use utf8;
use open ':std', ':encoding(utf8)';

use FindBin;
use lib "$FindBin::Bin/../..";

use File::Temp 'tempfile';

use Test::More tests => 5;

chdir "$FindBin::Bin/../..";

use_ok 'SL::Inifile' or BAIL_OUT 'Unable to load SL::Inifile';

subtest 'Parse sections and key-value pairs' => sub {
  my ($fh, $filename) = tempfile(UNLINK => 1);
  print $fh <<~'INI';
    [Section One]
    key1=value1
    key2=value2

    [Section Two]
    alpha=beta
    INI
  close $fh;

  my $ini = SL::Inifile->new($filename);

  is $ini->{'Section One'}{key1}, 'value1', 'First section key1';
  is $ini->{'Section One'}{key2}, 'value2', 'First section key2';
  is $ini->{'Section Two'}{alpha}, 'beta', 'Second section alpha';
  is_deeply $ini->{ORDER}, ['Section One', 'Section Two'], 'ORDER preserved';
};

subtest 'Skip comments and blank lines' => sub {
  my ($fh, $filename) = tempfile(UNLINK => 1);
  print $fh <<~'INI';
    # this is a comment
    ; this is also a comment

    [Data]
    name=test
    count=42 ; inline comment
    INI
  close $fh;

  my $ini = SL::Inifile->new($filename);

  is $ini->{Data}{name}, 'test', 'Key after comments';
  is $ini->{Data}{count}, '42', 'Inline comment stripped';
  is_deeply $ini->{ORDER}, ['Data'], 'Only Data section in ORDER';
};

subtest 'Stop at dot line' => sub {
  my ($fh, $filename) = tempfile(UNLINK => 1);
  print $fh <<~'INI';
    [Before]
    a=1

    .

    [After]
    b=2
    INI
  close $fh;

  my $ini = SL::Inifile->new($filename);

  is $ini->{Before}{a}, '1', 'Section before dot';
  ok !exists $ini->{After}, 'Section after dot not parsed';
};

subtest 'add_file merges into existing' => sub {
  my ($fh1, $f1) = tempfile(UNLINK => 1);
  print $fh1 <<~'INI';
    [First]
    x=1
    INI
  close $fh1;

  my ($fh2, $f2) = tempfile(UNLINK => 1);
  print $fh2 <<~'INI';
    [Second]
    y=2
    INI
  close $fh2;

  my $ini = SL::Inifile->new($f1);
  $ini->add_file($f2);

  is $ini->{First}{x}, '1', 'First file data preserved';
  is $ini->{Second}{y}, '2', 'Second file data added';
  is_deeply $ini->{ORDER}, ['First', 'Second'], 'ORDER has both sections';
};

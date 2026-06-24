use v5.40;

use utf8;
use open ':std', ':encoding(utf8)';

use FindBin;
use lib "$FindBin::Bin/../..";

use SL::Form;

use Test::More tests => 9;

chdir "$FindBin::Bin/../..";

my $form = new_ok 'SL::Form';

subtest 'escape and unescape' => sub {
  my @cases = (
    ['hello',           'hello',           'Simple string'],
    ['hello world',     'hello%20world',   'Space'],
    ['a&b=c',           'a%26b%3dc',       'Special chars'],
    ['',                '',                'Empty string'],
    ['100%',            '100%25',          'Percent sign'],
    ['foo/bar',         'foo%2fbar',       'Slash'],
    ['name@host',       'name%40host',     'At sign'],
  );

  for my $case (@cases) {
    my ($input, $expected, $desc) = @$case;
    is $form->escape($input, 1), $expected, "Escape: $desc";
  }

  for my $case (@cases) {
    my ($expected, $input, $desc) = @$case;
    is $form->unescape($input), $expected, "Unescape: $desc";
  }

  is $form->unescape('hello+world'), 'hello world', 'Unescape plus as space';
};

subtest 'quote and unquote' => sub {
  is $form->quote('hello "world"'), 'hello &quot;world&quot;', 'Quote double quotes';
  is $form->quote('a+b'), 'a&#43;b', 'Quote plus sign';
  is $form->quote(''), '', 'Quote empty string';
  is $form->quote(undef), '', 'Quote undef';
  is $form->unquote('hello &quot;world&quot;'), 'hello "world"', 'Unquote';
  is $form->unquote(''), '', 'Unquote empty string';
  is $form->unquote(undef), '', 'Unquote undef';
};

subtest 'numtextrows' => sub {
  is $form->numtextrows('hello', 80), 1, 'Single short line';
  is $form->numtextrows("line1\nline2\nline3", 80), 3, 'Three lines';
  is $form->numtextrows('', 80), 0, 'Empty string';
  is $form->numtextrows(undef, 80), 0, 'Undef';
  is $form->numtextrows('line1<br>line2', 80), 2, 'BR tags converted to newlines';
  is $form->numtextrows("line1\nline2\nline3", 80, 2), 2, 'Maxrows limits result';
};

subtest 'sort_columns' => sub {
  $form->{sort} = 'name';
  my @sorted = $form->sort_columns('id', 'name', 'date');
  is $sorted[0], 'name', 'Sort column moved to front';
  ok !grep(/^name$/, @sorted[1..$#sorted]), 'Sort column not duplicated';

  $form->{sort} = '';
  my @unsorted = $form->sort_columns('id', 'name', 'date');
  is_deeply \@unsorted, ['id', 'name', 'date'], 'No sort preserves order';
};

subtest 'sort_order' => sub {
  $form->{sort}      = 'name';
  $form->{oldsort}   = '';
  $form->{direction} = '';

  my $order = $form->sort_order(['name', 'id', 'date']);
  like $order, qr/^name ASC/, 'First sort defaults to ASC';

  $form->{oldsort} = 'name';
  $form->{direction} = 'ASC';
  $order = $form->sort_order(['name', 'id', 'date']);
  like $order, qr/^name DESC/, 'Second sort toggles to DESC';

  $form->{oldsort} = 'name';
  $form->{direction} = 'DESC';
  $order = $form->sort_order(['name', 'id', 'date']);
  like $order, qr/^name ASC/, 'Third sort toggles back to ASC';
};

subtest 'dbquote' => sub {
  is $form->dbquote('2025-01-14', 'SQL_DATE'), "'2025-01-14'", 'Date quoted';
  is $form->dbquote('', 'SQL_DATE'), 'NULL', 'Empty date is NULL';
  is $form->dbquote(undef, 'SQL_DATE'), 'NULL', 'Undef date is NULL';
  is $form->dbquote('42', 'SQL_INT'), 42, 'Integer passthrough';
  is $form->dbquote('', 'SQL_INT'), 'NULL', 'Empty int is NULL';
};

subtest 'select_option' => sub {
  my $list = "opt1\nopt2\nopt3";
  my $html = $form->select_option($list, 'opt2');

  like $html, qr/<option value="opt1">opt1/, 'First option rendered';
  like $html, qr/<option value="opt2" selected>opt2/, 'Selected option marked';
  like $html, qr/<option value="opt3">opt3/, 'Third option rendered';
};

subtest 'pad' => sub {
  $form->{filetype} = 'txt';
  is $form->pad('AB', ' ', 'left',  5, 0), 'AB   ', 'Left pad';
  is $form->pad('AB', ' ', 'right', 5, 0), '   AB', 'Right pad';
  is $form->pad('AB', ' ', 'center', 6, 0), '   AB ', 'Center pad';
  is $form->pad('AB', '*', 'left',  5, 0), 'AB***', 'Left pad with stars';
  is $form->pad('AB', '*', 'right', 5, 0), '***AB', 'Right pad with stars';
};

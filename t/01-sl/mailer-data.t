use v5.40;

use utf8;
use open ':std', ':encoding(utf8)';

use FindBin;
use lib "$FindBin::Bin/../..";

use File::Temp 'tempfile';

use Test::More tests => 6;

chdir "$FindBin::Bin/../..";

use_ok 'SL::Mailer' or BAIL_OUT 'Unable to load SL::Mailer';

subtest 'Constructor defaults' => sub {
  my $mailer = SL::Mailer->new;

  isa_ok $mailer, 'SL::Mailer';
  is $mailer->{charset}, 'UTF-8', 'Default charset';
  is $mailer->{contenttype}, 'text/plain', 'Default content type';
  is $mailer->{from}, '', 'From initially empty';
  is $mailer->{to}, '', 'To initially empty';
  is $mailer->{subject}, '', 'Subject initially empty';
  is $mailer->{message}, '', 'Message initially empty';
  is ref $mailer->{attachments}, 'ARRAY', 'Attachments is arrayref';
  is scalar @{$mailer->{attachments}}, 0, 'No attachments initially';
};

subtest 'Set fields' => sub {
  my $mailer = SL::Mailer->new;

  $mailer->{from}    = 'sender@example.com';
  $mailer->{to}      = 'recipient@example.com';
  $mailer->{subject} = 'Test Subject';
  $mailer->{message} = 'Hello World';
  $mailer->{version} = '3.2';

  is $mailer->{from}, 'sender@example.com', 'From set';
  is $mailer->{to}, 'recipient@example.com', 'To set';
  is $mailer->{subject}, 'Test Subject', 'Subject set';
  is $mailer->{message}, 'Hello World', 'Message set';
};

subtest 'Send plain message to file' => sub {
  my $mailer = SL::Mailer->new;
  $mailer->{from}    = 'sender@example.com';
  $mailer->{to}      = 'recipient@example.com';
  $mailer->{subject} = 'Plain Test';
  $mailer->{message} = 'Body text here';
  $mailer->{version} = '3.2';

  my ($fh, $filename) = tempfile(UNLINK => 1);
  close $fh;

  my $err = $mailer->send("| cat > $filename");
  is $err, '', 'No error on send';

  open my $in, '<', $filename or die "Cannot read $filename: $!";
  my $content = do { local $/; <$in> };
  close $in;

  like $content, qr/From: sender\@example\.com/, 'From header present';
  like $content, qr/To: recipient\@example\.com/, 'To header present';
  like $content, qr/Subject: Plain Test/, 'Subject header present';
  like $content, qr/Body text here/, 'Body present';
  like $content, qr/MIME-Version: 1\.0/, 'MIME version present';
  like $content, qr/Content-Type: text\/plain/, 'Content type present';
};

subtest 'Send with CC and BCC' => sub {
  my $mailer = SL::Mailer->new;
  $mailer->{from}    = 'sender@example.com';
  $mailer->{to}      = 'recipient@example.com';
  $mailer->{cc}      = 'cc@example.com';
  $mailer->{bcc}     = 'bcc@example.com';
  $mailer->{subject} = 'CC Test';
  $mailer->{message} = 'With CC';
  $mailer->{version} = '3.2';

  my ($fh, $filename) = tempfile(UNLINK => 1);
  close $fh;

  my $err = $mailer->send("| cat > $filename");
  is $err, '', 'No error on send';

  open my $in, '<', $filename or die "Cannot read $filename: $!";
  my $content = do { local $/; <$in> };
  close $in;

  like $content, qr/Cc: cc\@example\.com/, 'CC header present';
  like $content, qr/Bcc: bcc\@example\.com/, 'BCC header present';
};

subtest 'Send with attachment' => sub {
  my ($att_fh, $att_file) = tempfile(UNLINK => 1, SUFFIX => '.txt');
  print $att_fh "attachment content";
  close $att_fh;

  my $mailer = SL::Mailer->new;
  $mailer->{from}    = 'sender@example.com';
  $mailer->{to}      = 'recipient@example.com';
  $mailer->{subject} = 'Attachment Test';
  $mailer->{message} = 'See attached';
  $mailer->{version} = '3.2';
  push @{$mailer->{attachments}}, $att_file;

  my ($fh, $filename) = tempfile(UNLINK => 1);
  close $fh;

  my $err = $mailer->send("| cat > $filename");
  is $err, '', 'No error on send with attachment';

  open my $in, '<', $filename or die "Cannot read $filename: $!";
  my $content = do { local $/; <$in> };
  close $in;

  like $content, qr/Content-Type: multipart\/mixed/, 'Multipart content type';
  like $content, qr/Content-Transfer-Encoding: BASE64/, 'Base64 encoding for attachment';
  like $content, qr/See attached/, 'Message body present';
};

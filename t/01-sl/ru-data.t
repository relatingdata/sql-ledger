use v5.40;

use utf8;
use open ':std', ':encoding(utf8)';

use FindBin;
use lib "$FindBin::Bin/../..";

use Test::More tests => 5;

chdir "$FindBin::Bin/../..";

use_ok 'SL::RU' or BAIL_OUT 'Unable to load SL::RU';

subtest 'Constants are defined' => sub {
  is SL::RU->MAX_RECENT, 12, 'MAX_RECENT is 12';
  is SL::RU->AR_TRANSACTION, 'a1', 'AR_TRANSACTION code';
  is SL::RU->SALES_INVOICE, 'a2', 'SALES_INVOICE code';
  is SL::RU->CUSTOMER, 'c1', 'CUSTOMER code';
  is SL::RU->AP_TRANSACTION, 'd1', 'AP_TRANSACTION code';
  is SL::RU->VENDOR_INVOICE, 'd2', 'VENDOR_INVOICE code';
  is SL::RU->VENDOR, 'e2', 'VENDOR code';
  is SL::RU->SALES_ORDER, 'i1', 'SALES_ORDER code';
  is SL::RU->PURCHASE_ORDER, 'i2', 'PURCHASE_ORDER code';
  is SL::RU->GL_TRANSACTION, 'j1', 'GL_TRANSACTION code';
  is SL::RU->SALES_QUOTATION, 'k1', 'SALES_QUOTATION code';
  is SL::RU->REQUEST_QUOTATION, 'k2', 'REQUEST_QUOTATION code';
  is SL::RU->ITEM, 'm1', 'ITEM code';
  is SL::RU->PROJECT, 'n1', 'PROJECT code';
  is SL::RU->TIMECARD, 'n2', 'TIMECARD code';
};

subtest 'CODES mapping' => sub {
  my $codes = SL::RU->CODES;
  is ref $codes, 'HASH', 'CODES is a hashref';

  is $codes->{a1}{object}, 'ar.pl?action=edit', 'AR object URL';
  is $codes->{a1}{report}, 'ar.pl?action=search&nextsub=transactions', 'AR report URL';

  is $codes->{m1}{object}, 'ic.pl?action=edit', 'Item object URL';
  is $codes->{m1}{report}, 'ic.pl?action=search&searchitems=all', 'Item report URL';
};

subtest '_object_id' => sub {
  my $form = {script => 'ar.pl', id => 42};
  is SL::RU::_object_id($form), 42, 'Regular script returns positive id';

  $form = {script => 'jc.pl', id => 42};
  is SL::RU::_object_id($form), -42, 'jc.pl returns negative id';

  $form = {script => 'ap.pl', id => 0};
  is SL::RU::_object_id($form), 0, 'Zero id returns 0';
};

subtest '_descr helpers' => sub {
  my $form = {
    invnumber  => 'INV-001',
    customer   => 'ACME Corp',
    vendor     => 'Supplier Inc',
    transdate  => '2025-01-15',
    reference  => 'GL-100',
    partnumber => 'PART-42',
    description => "Widget\nLine 2",
    ordnumber  => 'ORD-55',
    quonumber  => 'QUO-77',
    vc         => 'customer',
    projectnumber => 'PRJ-1',
    startdate  => '2025-01-01',
    enddate    => '2025-12-31',
    id         => 99,
    projectdescription => 'Big Project',
    inhour  => '08',
    inmin   => '00',
    outhour => '17',
    outmin  => '00',
    qty     => 8,
  };

  my @ar = SL::RU::_descr_ar($form);
  is $ar[0], 'INV-001', 'AR number';
  is $ar[1], 'ACME Corp, 2025-01-15', 'AR description';

  my @ap = SL::RU::_descr_ap($form);
  is $ap[0], 'INV-001', 'AP number';
  is $ap[1], 'Supplier Inc, 2025-01-15', 'AP description';

  my @gl = SL::RU::_descr_gl($form);
  is $gl[0], 'GL-100', 'GL reference';
  is $gl[1], '2025-01-15', 'GL date';

  my @ic = SL::RU::_descr_ic($form);
  is $ic[0], 'PART-42', 'IC partnumber';
  is $ic[1], 'Widget', 'IC description takes first line';

  my @oe2 = SL::RU::_descr_oe2($form);
  is $oe2[0], 'ORD-55', 'OE2 order number';
  like $oe2[1], qr/ACME Corp, 2025-01-15/, 'OE2 description';

  my @oe1 = SL::RU::_descr_oe1($form);
  is $oe1[0], 'QUO-77', 'OE1 quote number';

  $form->{db} = 'customer';
  $form->{customernumber} = 'CUST-01';
  my @ct = SL::RU::_descr_ct($form);
  is $ct[0], 'CUST-01', 'CT customer number';
};

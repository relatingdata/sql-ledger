package TestDB;

use v5.40;
use DBI;
use SQL::Translator;
use FindBin;

my $_schema_sql;

sub _build_schema_sql {
  return $_schema_sql if $_schema_sql;

  my $pg_file = "$FindBin::Bin/../../sql/Pg-tables.sql";
  open my $fh, '<', $pg_file or die "Cannot read $pg_file: $!";
  my $sql = do { local $/; <$fh> };
  close $fh;

  # Remove non-DDL statements
  $sql =~ s/CREATE SEQUENCE.*?;\n//g;
  $sql =~ s/SELECT nextval.*?;\n//g;
  $sql =~ s/INSERT INTO.*?;\n//g;

  my $t = SQL::Translator->new(
    from => 'PostgreSQL',
    to   => 'SQLite',
    data => \$sql,
  );
  my $out = $t->translate or die $t->error;

  # Fix PostgreSQL-specific defaults for SQLite
  $out =~ s/DEFAULT 'nextval\(.*?\)'//g;
  $out =~ s/DEFAULT ''nextval\(.*?\)''//g;
  $out =~ s/DEFAULT ''\''nextval\(.*?\)'\'''//g;
  # Catch all remaining nextval patterns
  $out =~ s/DEFAULT\s+'[^']*nextval[^']*'//g;
  $out =~ s/DEFAULT 'current_date'//g;
  $out =~ s/DEFAULT ''current_date''//g;
  $out =~ s/DEFAULT ''\''current_date'\'''//g;
  $out =~ s/DEFAULT 'current_timestamp'//g;
  $out =~ s/DEFAULT ''current_timestamp''//g;
  $out =~ s/DEFAULT ''\''current_timestamp'\'''//g;
  # Convert boolean defaults: 't' -> '1', 'f' -> '0'
  $out =~ s/DEFAULT 't'/DEFAULT '1'/g;
  $out =~ s/DEFAULT 'f'/DEFAULT '0'/g;
  # Remove transaction wrapping
  $out =~ s/BEGIN TRANSACTION;\n//;
  $out =~ s/COMMIT;\n//;

  $_schema_sql = $out;
}

sub new_dbh {
  _build_schema_sql();

  my $dbh = DBI->connect('dbi:SQLite:dbname=:memory:', '', '', {
    AutoCommit          => 1,
    RaiseError          => 1,
    PrintError          => 0,
    FetchHashKeyName    => 'NAME_lc',
    sqlite_unicode      => 1,
  });

  # Strip comments and split on semicolons
  my $clean = $_schema_sql;
  $clean =~ s/^--.*$//mg;

  for my $stmt (split /;/, $clean) {
    $stmt =~ s/^\s+//s;
    $stmt =~ s/\s+$//s;
    next unless $stmt =~ /\S/;
    next unless $stmt =~ /^(CREATE|INSERT|ALTER|DROP)/i;
    eval { $dbh->do($stmt) };
    if ($@) {
      warn "TestDB: Failed to execute: $stmt\n  Error: $@\n";
    }
  }

  return $dbh;
}

sub seed_data ($dbh) {
  # Insert baseline data that many modules expect

  # Currencies
  $dbh->do("INSERT INTO curr (rn, curr, prec) VALUES (1, 'USD', 2)");
  $dbh->do("INSERT INTO curr (rn, curr, prec) VALUES (2, 'EUR', 2)");
  $dbh->do("INSERT INTO curr (rn, curr, prec) VALUES (3, 'CHF', 2)");

  # Defaults
  $dbh->do("INSERT INTO defaults (fldname, fldvalue) VALUES ('version', '4.0.0')");
  $dbh->do("INSERT INTO defaults (fldname, fldvalue) VALUES ('company', 'Test Company')");
  $dbh->do("INSERT INTO defaults (fldname, fldvalue) VALUES ('precision', '2')");
  $dbh->do("INSERT INTO defaults (fldname, fldvalue) VALUES ('dateformat', 'yyyy-mm-dd')");
  $dbh->do("INSERT INTO defaults (fldname, fldvalue) VALUES ('businessnumber', 'BN-001')");

  # Employees
  $dbh->do("INSERT INTO employee (id, login, name, sales) VALUES (1, 'admin', 'Admin User', '0')");
  $dbh->do("INSERT INTO employee (id, login, name, sales) VALUES (2, 'jdoe', 'Jane Doe', '1')");
  $dbh->do("INSERT INTO employee (id, login, name, sales) VALUES (3, 'sales1', 'Sales Person', '1')");

  # Chart of Accounts
  $dbh->do("INSERT INTO chart (id, accno, description, charttype, category, link) VALUES (1000, '1000', 'Petty Cash', 'A', 'A', 'AR_paid:AP_paid')");
  $dbh->do("INSERT INTO chart (id, accno, description, charttype, category, link) VALUES (1100, '1100', 'Accounts Receivable', 'A', 'A', 'AR')");
  $dbh->do("INSERT INTO chart (id, accno, description, charttype, category, link) VALUES (2000, '2000', 'Accounts Payable', 'A', 'L', 'AP')");
  $dbh->do("INSERT INTO chart (id, accno, description, charttype, category, link) VALUES (3000, '3000', 'Retained Earnings', 'A', 'Q', '')");
  $dbh->do("INSERT INTO chart (id, accno, description, charttype, category, link) VALUES (4000, '4000', 'Sales Revenue', 'A', 'I', 'AR_amount:IC_sale:IC_income')");
  $dbh->do("INSERT INTO chart (id, accno, description, charttype, category, link) VALUES (5000, '5000', 'Cost of Goods Sold', 'A', 'E', 'AP_amount:IC_cogs:IC_expense')");
  $dbh->do("INSERT INTO chart (id, accno, description, charttype, category, link) VALUES (5100, '5100', 'Office Supplies', 'A', 'E', 'AP_amount')");
  $dbh->do("INSERT INTO chart (id, accno, description, charttype, category, link) VALUES (2100, '2100', 'Tax Payable', 'A', 'L', '')");

  # GIFI
  $dbh->do("INSERT INTO gifi (accno, description) VALUES ('1000', 'Cash and equivalents')");
  $dbh->do("INSERT INTO gifi (accno, description) VALUES ('2000', 'Payables')");

  # Tax
  $dbh->do("INSERT INTO tax (chart_id, rate, taxnumber) VALUES (2100, 0.07, 'VAT7')");

  # Customers
  $dbh->do("INSERT INTO customer (id, name, customernumber, contact, email, terms) VALUES (100, 'ACME Corp', 'C-001', 'John Smith', 'john\@acme.com', 30)");
  $dbh->do("INSERT INTO customer (id, name, customernumber, contact, email, terms) VALUES (101, 'Widget Inc', 'C-002', 'Mary Jones', 'mary\@widget.com', 15)");

  # Vendors
  $dbh->do("INSERT INTO vendor (id, name, vendornumber, contact, email, terms) VALUES (200, 'Supplier Co', 'V-001', 'Bob Supply', 'bob\@supplier.com', 30)");
  $dbh->do("INSERT INTO vendor (id, name, vendornumber, contact, email, terms) VALUES (201, 'Parts Ltd', 'V-002', 'Amy Parts', 'amy\@parts.com', 45)");

  # Parts
  $dbh->do("INSERT INTO parts (id, partnumber, description, unit, sellprice, lastcost, onhand, income_accno_id, expense_accno_id) VALUES (300, 'P-001', 'Widget A', 'ea', 100.00, 50.00, 25, 4000, 5000)");
  $dbh->do("INSERT INTO parts (id, partnumber, description, unit, sellprice, lastcost, onhand, income_accno_id, expense_accno_id) VALUES (301, 'P-002', 'Widget B', 'ea', 200.00, 100.00, 10, 4000, 5000)");

  # Departments
  $dbh->do("INSERT INTO department (id, description, role, rn) VALUES (1, 'Sales', 'P', 1)");
  $dbh->do("INSERT INTO department (id, description, role, rn) VALUES (2, 'Engineering', 'C', 2)");

  # Projects
  $dbh->do("INSERT INTO project (id, projectnumber, description) VALUES (400, 'PRJ-001', 'Main Project')");

  # Languages
  $dbh->do("INSERT INTO language (code, description) VALUES ('en', 'English')");
  $dbh->do("INSERT INTO language (code, description) VALUES ('de', 'German')");

  # Warehouses
  $dbh->do("INSERT INTO warehouse (id, description, rn) VALUES (500, 'Main Warehouse', 1)");
  # Address for warehouse
  $dbh->do("INSERT INTO address (id, trans_id, address1, city, country) VALUES (1000, 500, '500 Warehouse Ave', 'Industrial City', 'US')");

  # Business
  $dbh->do("INSERT INTO business (id, description, discount, rn) VALUES (1, 'Wholesale', 0.1, 1)");
  $dbh->do("INSERT INTO business (id, description, discount, rn) VALUES (2, 'Retail', 0.05, 2)");

  # Mime types
  $dbh->do("INSERT INTO mimetype (extension, contenttype) VALUES ('pdf', 'application/pdf')");
  $dbh->do("INSERT INTO mimetype (extension, contenttype) VALUES ('csv', 'text/csv')");

  return $dbh;
}

sub new_form ($dbh) {
  require SL::Form;
  my $form = SL::Form->new;
  $form->{login} = 'admin';

  # Create a non-disconnecting wrapper around the dbh
  my $wrapper = bless {_real_dbh => $dbh}, 'TestDB::DBH';

  # Monkey-patch dbconnect/dbconnect_noauto to return our wrapper
  no warnings 'redefine';
  *SL::Form::dbconnect = sub ($self, $myconfig = undef) { return $wrapper };
  *SL::Form::dbconnect_noauto = sub ($self, $myconfig = undef) { return $wrapper };

  return $form;
}

sub myconfig ($dbh) {
  return {
    dbconnect    => 'dbi:SQLite:dbname=:memory:',
    dbuser       => '',
    dbpasswd     => '',
    dboptions    => '',
    dbdriver     => 'SQLite',
    countrycode  => 'en',
    dateformat   => 'yyyy-mm-dd',
    numberformat => '1,000.00',
  };
}

# Thin proxy around DBI handle that suppresses disconnect
# and rewrites PostgreSQL-specific SQL for SQLite
package TestDB::DBH;

use v5.40;

sub disconnect ($self) { 1 }

sub _rewrite_sql ($sql) {
  return $sql unless defined $sql;
  # EXTRACT(YEAR FROM col) -> strftime('%Y', col)
  $sql =~ s/EXTRACT\s*\(\s*YEAR\s+FROM\s+(\w+)\s*\)/strftime('%Y', $1)/gi;
  # EXTRACT(MONTH FROM col) -> strftime('%m', col)
  $sql =~ s/EXTRACT\s*\(\s*MONTH\s+FROM\s+(\w+)\s*\)/strftime('%m', $1)/gi;
  # date 'value' -> 'value'
  $sql =~ s/\bdate\s+'([^']+)'/'$1'/gi;

  # ARRAY_AGG / ARRAY_TO_STRING -> GROUP_CONCAT (SQLite equivalent)
  $sql =~ s/ARRAY_TO_STRING\s*\(\s*ARRAY_AGG\s*\(\s*distinct\s*\(([^)]+)\)\s*\)\s*,\s*'([^']*)'\s*\)/GROUP_CONCAT(DISTINCT $1, '$2')/gi;

  # to_char(col, 'format') -> strftime('format', col) with PG->SQLite format conversion
  $sql =~ s/to_char\s*\(\s*(\w+(?:\.\w+)?)\s*,\s*'[^']*'\s*\)/$1/gi;

  # a.datepaid - a.duedate -> julianday(a.datepaid) - julianday(a.duedate)
  $sql =~ s/(\w+\.\w+)\s*-\s*(\w+\.duedate)\s+AS\s+paymentdiff/CAST(julianday($1) - julianday($2) AS INTEGER) AS paymentdiff/gi;

  # Fix ambiguous columns in ORDER BY for non-UNION queries with JOINs
  # Find the main table alias from "FROM <table> <alias>"
  if ($sql =~ /ORDER BY\s+(.+)$/si && $sql !~ /UNION/i) {
    my $order = $1;
    # Extract all qualified columns from the full SQL (not just SELECT)
    my %col_qualified;
    while ($sql =~ /\b(\w+)\.(\w+)(?:\s+AS\s+(\w+))?/gi) {
      my ($tbl, $col, $alias) = ($1, $2, $3);
      next if lc($col) =~ /^(id|trans_id)$/;  # skip very common columns
      my $name = $alias // $col;
      $col_qualified{$name} //= "$tbl.$col";
    }
    # For common columns that appear in multiple tables, extract from SELECT specifically
    # Look for the main FROM alias (the first FROM not inside a subquery)
    # Find FROM after all subqueries by locating the main FROM clause
    my $temp = $sql;
    # Remove subqueries to find the main FROM
    while ($temp =~ s/\([^()]*\)//g) {}  # strip innermost parens repeatedly
    if ($temp =~ /\bFROM\s+(\w+)\s+(\w+)\b/i) {
      my $main_alias = $2;
      $col_qualified{id} //= "$main_alias.id";
    }
    # Specifically handle vc.name for customer/vendor queries
    if ($sql =~ /\bvc\.name\b/) {
      $col_qualified{name} = "vc.name";
    }

    my @terms = split /,/, $order;
    my @new_terms;
    for my $term (@terms) {
      $term =~ s/^\s+|\s+$//g;
      if ($term =~ /^(\w+)(\s+(?:ASC|DESC))?$/i) {
        my ($col, $dir) = ($1, $2 // '');
        if (exists $col_qualified{$col}) {
          push @new_terms, "$col_qualified{$col}$dir";
        } else {
          push @new_terms, $term;
        }
      } elsif ($term =~ /^(\w+\.\w+)(\s+(?:ASC|DESC))?$/i) {
        push @new_terms, $term;  # already qualified
      } else {
        push @new_terms, $term;
      }
    }
    my $new_order = join(', ', @new_terms);
    $sql =~ s/ORDER BY\s+.+$/ORDER BY $new_order/si;
  }

  # For UNION queries, rewrite ORDER BY column names to positions
  # SQLite can't resolve ambiguous column names across JOINs in UNION ORDER BY
  if ($sql =~ /UNION\s+ALL/i && $sql =~ /ORDER BY\s+(.+)$/si) {
    my $order_clause = $1;
    # Extract column names from the first SELECT
    if ($sql =~ /^SELECT\s+(.+?)\s+FROM\s/si) {
      my $select_part = $1;
      my @cols;
      my $depth = 0;
      my $current = '';
      for my $ch (split //, $select_part) {
        if ($ch eq '(') { $depth++; $current .= $ch; }
        elsif ($ch eq ')') { $depth--; $current .= $ch; }
        elsif ($ch eq ',' && $depth == 0) {
          push @cols, $current;
          $current = '';
        } else {
          $current .= $ch;
        }
      }
      push @cols, $current if $current =~ /\S/;

      # Build name -> position mapping
      my %col_pos;
      for my $i (0 .. $#cols) {
        my $c = $cols[$i];
        $c =~ s/^\s+|\s+$//g;
        # Extract the alias or column name
        if ($c =~ /\bAS\s+(\w+)\s*$/i) {
          $col_pos{$1} = $i + 1;
        } elsif ($c =~ /\.(\w+)\s*$/) {
          $col_pos{$1} = $i + 1;
        } elsif ($c =~ /^(\w+)\s*$/) {
          $col_pos{$1} = $i + 1;
        }
      }

      # Rewrite ORDER BY terms
      my @order_terms = split /,/, $order_clause;
      my @new_terms;
      for my $term (@order_terms) {
        $term =~ s/^\s+|\s+$//g;
        my ($col, $dir) = $term =~ /^(\w+)(?:\s+(ASC|DESC))?$/i;
        if ($col && exists $col_pos{$col}) {
          push @new_terms, $col_pos{$col} . ($dir ? " $dir" : '');
        } else {
          push @new_terms, $term;
        }
      }
      my $new_order = join(', ', @new_terms);
      $sql =~ s/ORDER BY\s+.+$/ORDER BY $new_order/si;
    }
  }

  return $sql;
}

sub prepare ($self, $sql, @rest) {
  $sql = _rewrite_sql($sql);
  return $self->{_real_dbh}->prepare($sql, @rest);
}

sub do ($self, $sql, @rest) {
  $sql = _rewrite_sql($sql);
  return $self->{_real_dbh}->do($sql, @rest);
}

sub selectrow_array ($self, $sql, @rest) {
  $sql = _rewrite_sql($sql);
  return $self->{_real_dbh}->selectrow_array($sql, @rest);
}

sub selectrow_hashref ($self, $sql, @rest) {
  $sql = _rewrite_sql($sql);
  return $self->{_real_dbh}->selectrow_hashref($sql, @rest);
}

sub selectall_arrayref ($self, $sql, @rest) {
  $sql = _rewrite_sql($sql);
  return $self->{_real_dbh}->selectall_arrayref($sql, @rest);
}

our $AUTOLOAD;

sub AUTOLOAD ($self, @args) {
  my $method = $AUTOLOAD =~ s/.*:://r;
  return if $method eq 'DESTROY';
  return $self->{_real_dbh}->$method(@args);
}

sub can ($self, $method) {
  return $self->SUPER::can($method) || $self->{_real_dbh}->can($method);
}

1;

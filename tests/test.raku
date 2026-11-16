use Test;
use Nis2;

my $today = Date.new('2026-11-16');
my $H = "measure,status,owner,evidence,last_review\n";
my @ALL = <risk_analysis incident_handling business_continuity supply_chain secure_development effectiveness hygiene_training cryptography hr_access mfa>;
sub full(&over = { Nil }) {
    my $s = $H;
    for @ALL -> $m { $s ~= "$m,implemented,Owner,evidence.pdf,2026-10-01\n" }
    $s
}
sub rules(Str $t) { audit-text($t, 't.csv', $today).map(*<rule>).sort.join(',') }
sub rules-without(Str $m) { rules(full().lines.grep({ !.starts-with("$m,") }).join("\n") ~ "\n") }

is rules(full()), '', 'complete clean assessment has no findings';
for @ALL -> $m { is rules-without($m), 'NIS001', "missing $m reported" }
is rules($H), 'NIS001,NIS001,NIS001,NIS001,NIS001,NIS001,NIS001,NIS001,NIS001,NIS001', 'header only reports all ten missing';

sub with-row(Str $row) { full().lines.grep({ !.starts-with('mfa,') }).join("\n") ~ "\n$row\n" }
is rules(with-row('mfa,no,CISO,,2026-10-01')), 'NIS002', 'status no';
is rules(with-row('mfa,not_started,CISO,,2026-10-01')), 'NIS002', 'status not_started';
is rules(with-row('mfa,partial,CISO,,2026-10-01')), 'NIS003', 'status partial';
is rules(with-row('mfa,in_progress,CISO,x,2026-10-01')), 'NIS003', 'status in_progress';
is rules(with-row('mfa,implemented,CISO,,2026-10-01')), 'NIS004', 'implemented without evidence';
is rules(with-row('mfa,yes,CISO,x,2026-10-01')), '', 'yes counts as implemented';
is rules(with-row('mfa,done,CISO,x,2026-10-01')), '', 'done counts as implemented';
is rules(with-row('mfa,implemented,,x,2026-10-01')), 'NIS005', 'no owner';
is rules(with-row('mfa,implemented,CISO,x,2025-11-15')), 'NIS006', 'review older than a year';
is rules(with-row('mfa,implemented,CISO,x,2025-11-16')), '', 'exactly one year is still fine';
is rules(with-row('mfa,implemented,CISO,x,')), 'NIS006', 'no review date';
is rules(with-row('mfa,implemented,CISO,x,soon')), 'NIS006', 'invalid review date';
is rules(with-row('mfa,maybe,CISO,x,2026-10-01')), 'NIS007', 'unknown status is reported once';
is rules(with-row('zzz,implemented,CISO,x,2026-10-01')), 'NIS001,NIS007', 'unknown measure leaves the real one missing';
is rules(with-row('MFA,Implemented,CISO,x,2026-10-01')), '', 'case-insensitive keys and status';
is rules(with-row('mfa,no,CISO,,2026-10-01') ~ "\nmfa,implemented,CISO,x,2026-10-01"), 'NIS002', 'first row for a measure wins';
is rules(with-row('mfa,no,,,')), 'NIS002', 'not implemented rows skip owner and date checks';

is rules(""), 'NIS000', 'empty file';
is rules("\n\n"), 'NIS000', 'blank file';
is rules("a,b\n1,2\n"), 'NIS000', 'wrong header';
is audit-text("", 'e.csv', $today)[0]<sev>, 'info', 'NIS000 is info';

my @rows = parse-csv("a,\"b,c\",d\n\"x\ny\",z\r\n");
is @rows.elems, 2, 'two rows parsed';
is @rows[0][1][1], 'b,c', 'comma inside quotes';
is @rows[1][1][0], "x\ny", 'newline inside quotes';
is @rows[1][0], 2, 'second row line number';
is parse-csv("a\n\"x\ny\"\nb")[2][0], 4, 'line number after a quoted newline';
is parse-csv('a,"say ""hi"""')[0][1][1], 'say "hi"', 'escaped quote';
is parse-csv("a,b").elems, 1, 'no trailing newline';
is parse-csv("a,b\r\nc,d\r\n").elems, 2, 'crlf rows';

my $crlf = full().subst("\n", "\r\n", :g);
is rules($crlf), '', 'crlf file is clean';
my $q = $H ~ "risk_analysis,implemented,\"Smith, J\",\"a,b.pdf\",2026-10-01\n";
is audit-text($q, 'q.csv', $today).grep(*<rule> eq 'NIS004').elems, 0, 'quoted commas in fields do not shift columns';

my @f = audit-text(with-row('mfa,no,,,'), 't.csv', $today);
is @f[0]<where>, 't.csv:11', 'where has file and line';
my @s = sort-findings(@f);
is @s[0]<sev>, 'high', 'sorted by severity';
my @mix = sort-findings([%(sev => 'low', file => 'a', line => 1, rule => 'B'), %(sev => 'high', file => 'z', line => 9, rule => 'A'), %(sev => 'high', file => 'a', line => 10, rule => 'A'), %(sev => 'high', file => 'a', line => 2, rule => 'A')]);
is @mix.map({ .<file> ~ .<line> }).join(' '), 'a2 a10 z9 a1', 'severity then file then numeric line';

# fuzz
my @bits = '', ',', '"', "\n", 'measure', 'status', 'mfa', 'implemented', 'no', ' ', "\r", '2026-01-01', 'a,b';
my $ok = True;
for ^3000 {
    my $s = (^(1 + 25.rand.Int)).map({ @bits.pick }).join;
    try { audit-text($s, 'f.csv', $today); CATCH { default { $ok = False; diag "crash on {$s.raku}: $_" } } }
}
ok $ok, '3000 random inputs do not crash';

done-testing;

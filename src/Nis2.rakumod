unit module Nis2;

constant @MEASURES is export = <risk_analysis incident_handling business_continuity supply_chain secure_development effectiveness hygiene_training cryptography hr_access mfa>;
constant %RANK is export = critical => 0, high => 1, medium => 2, low => 3, info => 4;
constant %TITLE = risk_analysis => 'risk analysis and information system security policies',
    incident_handling => 'incident handling', business_continuity => 'business continuity and crisis management',
    supply_chain => 'supply chain security', secure_development => 'secure acquisition, development and maintenance',
    effectiveness => 'assessing the effectiveness of measures', hygiene_training => 'cyber hygiene and training',
    cryptography => 'cryptography and encryption policies', hr_access => 'HR security, access control and asset management',
    mfa => 'multi-factor authentication and secured communications';

sub parse-csv(Str $text --> List) is export {
    my $t = $text.subst("\r\n", "\n", :g).subst("\r", "\n", :g);
    my @rows; my @row; my $f = ''; my $q = False; my $line = 1; my $rowline = 1;
    my @c = $t.comb;
    my $i = 0;
    while $i < @c.elems {
        my $c = @c[$i];
        if $q {
            if $c eq '"' {
                if (@c[$i + 1] // '') eq '"' { $f ~= '"'; $i++ } else { $q = False }
            } else { $f ~= $c; $line++ if $c eq "\n" }
        } else {
            if $c eq '"' { $q = True }
            elsif $c eq ',' { @row.push($f); $f = '' }
            elsif $c eq "\n" {
                @row.push($f); @rows.push((+$rowline, @row.clone)); @row = (); $f = '';
                $line++; $rowline = $line;
            } else { $f ~= $c }
        }
        $i++;
    }
    if $f.chars || @row { @row.push($f); @rows.push((+$rowline, @row.clone)) }
    @rows.List
}

sub finding(Str $sev, Str $rule, Str $file, Int $line, Str $msg) {
    %( :$sev, :$rule, :$file, :$line, :$msg, where => ($line > 0 ?? "$file:$line" !! $file) )
}

sub stale(Str $s, Date $today --> Bool) {
    my $d = try Date.new($s.trim);
    return True without $d;
    $d.later(:years(1)) < $today
}

sub audit-text(Str $text, Str $label, Date $today --> List) is export {
    my @out;
    my @rows = parse-csv($text).grep({ !(.[1].elems == 1 && .[1][0].trim eq '') });
    unless @rows {
        return (finding('info', 'NIS000', $label, 0, 'empty file, nothing to check'),);
    }
    my @head = @rows[0][1].map(*.trim.lc);
    my %col; for @head.kv -> $i, $h { %col{$h} //= $i }
    unless (%col<measure>:exists) && (%col<status>:exists) {
        return (finding('info', 'NIS000', $label, 0, 'no header with measure and status columns'),);
    }
    my %seen;
    for @rows[1..*] -> $r {
        my ($ln, @f) = $r[0], |$r[1];
        my $get = -> $k { (%col{$k}:exists && %col{$k} < @f.elems) ?? @f[%col{$k}].trim !! '' };
        my $m = $get('measure').lc;
        my $st = $get('status').lc;
        unless $m ~~ any(@MEASURES) {
            @out.push(finding('medium', 'NIS007', $label, $ln, "unknown measure '{$get('measure')}': use one of the ten Article 21 keys"));
            next;
        }
        next if %seen{$m}++;
        my $title = %TITLE{$m};
        given $st {
            when 'no' | 'not_started' {
                @out.push(finding('high', 'NIS002', $label, $ln, "$m ($title) is not implemented"));
                next;
            }
            when 'partial' | 'in_progress' {
                @out.push(finding('medium', 'NIS003', $label, $ln, "$m ($title) is only partly implemented"));
            }
            when 'implemented' | 'yes' | 'done' {
                if $get('evidence') eq '' {
                    @out.push(finding('medium', 'NIS004', $label, $ln, "$m is marked implemented with no evidence"));
                }
            }
            default {
                @out.push(finding('medium', 'NIS007', $label, $ln, "unknown status '{$get('status')}' for $m"));
                next;
            }
        }
        if $get('owner') eq '' {
            @out.push(finding('low', 'NIS005', $label, $ln, "$m has no owner"));
        }
        my $lr = $get('last_review');
        if $lr eq '' || stale($lr, $today) {
            @out.push(finding('low', 'NIS006', $label, $ln, $lr eq '' ?? "$m has no review date" !! "$m was last reviewed on $lr, more than 12 months ago"));
        }
    }
    for @MEASURES -> $m {
        next if %seen{$m};
        next if @out.first({ .<rule> eq 'NIS007' && .<msg>.contains("'$m'") });
        @out.push(finding('high', 'NIS001', $label, 0, "$m ({%TITLE{$m}}) has no row in the assessment"));
    }
    @out.List
}

sub sort-findings(@f --> List) is export {
    @f.sort({ %RANK{$^a<sev>} <=> %RANK{$^b<sev>} || $^a<file> cmp $^b<file> || $^a<line> <=> $^b<line> || $^a<rule> cmp $^b<rule> }).List
}

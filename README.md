# nis2-gap-check

nis2-gap-check reads a CSV self-assessment with one row per control (`measure,status,owner,evidence,last_review`) and compares it with the ten minimum measures of NIS2 Article 21(2): risk analysis, incident handling, business continuity, supply chain, secure acquisition and development, effectiveness assessment, cyber hygiene and training, cryptography, HR and access control, and multi-factor authentication. It reports measures that are missing, not implemented, without an owner, without evidence or not reviewed in the last 12 months.

**Live demo:** https://jvch0512.github.io/nis2-gap-check/ (Synthetic data.)

Raku (Rakudo 2022.12 or newer), no modules. The demo page is rendered from the tool's `--tsv` output by `scripts/site.py` (Python 3, only needed to regenerate the page).

## Use

```bash
bin/nis2-gap-check examples
bin/nis2-gap-check assessment.csv --tsv
bin/nis2-gap-check assessment.csv --fail-on high       # exit 1 on any high finding
```

Measure keys: `risk_analysis`, `incident_handling`, `business_continuity`, `supply_chain`, `secure_development`, `effectiveness`, `hygiene_training`, `cryptography`, `hr_access`, `mfa`. Status values: `implemented`, `partial`, `in_progress`, `no`, `not_started`.

Exit codes: 0 ok, 1 findings at or above `--fail-on`, 2 bad input. Output is human text by default and TSV with `--tsv` (`# N files, M findings`, then `SEVERITY<TAB>RULE<TAB>WHERE<TAB>MESSAGE`).

| Rule | Severity | What it catches |
|---|---|---|
| NIS001 | high | a measure of Article 21(2) has no row in the assessment |
| NIS002 | high | status is `not_started` or `no` |
| NIS003 | medium | status is `partial` or `in_progress` |
| NIS004 | medium | status is `implemented` but the evidence column is empty |
| NIS005 | low | no owner named |
| NIS006 | low | last review older than 12 months or missing, using `--today YYYY-MM-DD` or the system date |
| NIS007 | medium | the row names a measure that is not one of the ten (typo or custom control), reported so it is not silently ignored |
| NIS000 | info | the file is empty or has no header |

See [examples](examples) and [docs/sample-output.txt](docs/sample-output.txt).

## Limits

- It checks the self-assessment, not the real environment. A control marked `implemented` with evidence is accepted as stated.
- The ten measure keys are fixed: `risk_analysis`, `incident_handling`, `business_continuity`, `supply_chain`, `secure_development`, `effectiveness`, `hygiene_training`, `cryptography`, `hr_access`, `mfa`.
- National transposition differs. Check the law of the member state that applies to the entity.
- This is a gap list for preparation, not legal advice or a compliance certificate.

## Where it fits

Preparing for a NIS2 readiness workshop or an audit: a quick first view of what is missing before a consultant is called.

## Tests

```bash
make test    # A Raku test script: every rule on good and bad rows, CSV quoting, dates, hostile input, 3000-case fuzzing and CLI exit codes
```

MIT.

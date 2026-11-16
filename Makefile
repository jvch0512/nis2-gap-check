.PHONY: build test sample

test:
	raku -I src tests/test.raku && bash tests/cli.sh

sample:
	mkdir -p docs site
	bin/nis2-gap-check examples --today 2026-11-16 > docs/sample-output.txt; true
	bin/nis2-gap-check examples --today 2026-11-16 --tsv > docs/sample-output.tsv; true
	python3 scripts/site.py docs/sample-output.tsv site/index.html "nis2-gap-check" "Self-assessment gap check against the ten cybersecurity risk-management measures of NIS2 Article 21. Raku." "Synthetic data."

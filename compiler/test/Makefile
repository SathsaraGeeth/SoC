PYTHON ?= python3

.PHONY: test smoke extended clean

test: smoke extended

smoke:
	$(PYTHON) run.py --suite smoke

extended:
	$(PYTHON) run.py --suite extended

clean:
	rm -rf build

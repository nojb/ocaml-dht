.PHONY: update_upstream
update_upstream:
	rm -rf dht
	git clone https://github.com/jech/dht dht
	rm -rf dht/.git

.PHONY: gh-pages
gh-pages: doc
	git clone `git config --get remote.origin.url` .gh-pages --reference .
	git -C .gh-pages checkout --orphan gh-pages
	git -C .gh-pages reset
	git -C .gh-pages clean -dxf
	cp $(DOC_DIR)* .gh-pages/
	git -C .gh-pages add .
	git -C .gh-pages commit -m "Update Pages"
	git -C .gh-pages push origin gh-pages -f
	rm -rf .gh-pages

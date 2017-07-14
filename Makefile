CC       = ./clang
CFLAGS   = -g -fsanitize=address,array-bounds,null,return,shift -fsanitize-coverage=trace-pc-guard -I.

CXX      = ./clang++
CXXFLAGS = $(CFLAGS) -std=c++11

LDFLAGS  = -L.
LDLIBS   = -lwolfssl -lFuzzer

PYTHON   = python2

prefix   = ./out

libFuzzer  = libFuzzer.a
fuzzer_dir = Fuzzer
fuzzer_src = https://chromium.googlesource.com/chromium/llvm-project/llvm/lib/Fuzzer

new_clang      = new_clang
clang_tool_src = https://chromium.googlesource.com/chromium/src/tools/clang
clang_dir      = $(new_clang)/clang/clang
clang_tool     = $(clang_dir)/scripts/update.py
clang_bin      = $(new_clang)/third_party/llvm-build/Release+Asserts/bin/

src = $(wildcard ./*/target.c)
obj = $(patsubst %.c,%.o,$(src))
out = $(patsubst %.c,%,$(src))
trg = $(patsubst ./%/target.c,%,$(src))

targets   = $(patsubst %,$(prefix)/%,$(trg))
corpi     = $(patsubst %,$(prefix)/%_seed_corpus.zip,$(trg))
optionses = $(patsubst %,$(prefix)/%.options,$(trg))

exports = $(targets) $(corpi) $(optionses) $(dictionaries)

all: $(out)                     # make all
export: $(prefix) $(exports)    # not quite install, but close
deps: $(CC) $(CXX) $(libFuzzer) # dependencies
dependencies: deps              # deps alias
%: %.c                          # cancel the implicit rule
%: %.cc                         # cancel the implicit rule

.PHONY: clean spotless export unexport
.INTERMEDIATE: $(obj)



# libFuzzer

$(fuzzer_dir):
	@echo -e "\nRetrieving libFuzzer...\n"
	@git clone $(fuzzer_src) $@ --depth 1

$(libFuzzer): $(fuzzer_dir)
	@bash $</build.sh
	@echo -e "\nlibFuzzer retrieved!\n"



# clang

$(clang_tool):
	@echo -e "\nRetrieving new clang binaries...\n"
	@git clone $(clang_tool_src) $(clang_dir) --depth 1

$(clang_bin): $(clang_tool)
	@$(PYTHON) $<
	@touch $@ #to prevent make from always running this rule
	@echo -e "\nClang retrieved!\n"

$(clang_bin)/$(CC): $(clang_bin)
$(clang_bin)/$(CXX): $(clang_bin)

$(CC): $(clang_bin)/$(CC)
	@ln -s $< $@
$(CXX): $(clang_bin)/$(CXX)
	@ln -s $< $@



# actual source code

$(obj): %.o: %.c
	@echo "CC	$<	-o $@"
	@$(CC) -c $< $(CFLAGS) -o $@

$(out): %: %.o
	@echo "C++	$<	-o $@"
	@$(CXX) $< $(CXXFLAGS) $(LDFLAGS) $(LDLIBS) -o $@

# export

$(prefix):
	@mkdir -p $(prefix)

$(optionses): $(prefix)/%.options:
	@if [ -e "$(wildcard ./$*/*.options)" ]; then \
	    echo "cp	$*/*.options"	$@; \
	    cp $*/*.options $@; \
	fi;

$(corpi): $(prefix)/%_seed_corpus.zip:
	@if [ -n "$(wildcard ./$*/*corpus)" ]; then \
	    echo "zip	$@	$(wildcard $*/*corpus)"; \
	    zip -q -r $@ ./$*/*corpus; \
	fi;

$(targets): $(prefix)/%: ./%/target
	@echo "cp	$<	$@"
	@cp $< $@

# cleanup

clean:
	@rm -f $(out)
	@echo "Cleaned!"
spotless:
	@rm -rf $(fuzzer_dir) $(libFuzzer) $(new_clang) $(CC) $(CXX) $(out)
	@echo "Cleaned harder!"
unexport:
	@rm -rf $(prefix)/*
	@echo "Un-exported!"

#   Copyright 2011, 2012 David Malcolm <dmalcolm@redhat.com>
#   Copyright 2011, 2012 Red Hat, Inc.
#
#   This is free software: you can redistribute it and/or modify it
#   under the terms of the GNU General Public License as published by
#   the Free Software Foundation, either version 3 of the License, or
#   (at your option) any later version.
#
#   This program is distributed in the hope that it will be useful, but
#   WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
#   General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this program.  If not, see
#   <http://www.gnu.org/licenses/>.

.PHONY: all clean debug dump_gimple plugin show-ssa tarball test-suite testcpychecker testcpybuilder

PLUGIN_SOURCE_FILES= \
  gcc-python.c \
  gcc-python-attribute.c \
  gcc-python-callbacks.c \
  gcc-python-callgraph.c \
  gcc-python-cfg.c \
  gcc-python-closure.c \
  gcc-python-diagnostics.c \
  gcc-python-function.c \
  gcc-python-gimple.c \
  gcc-python-location.c \
  gcc-python-option.c \
  gcc-python-parameter.c \
  gcc-python-pass.c \
  gcc-python-pretty-printer.c \
  gcc-python-rtl.c \
  gcc-python-tree.c \
  gcc-python-variable.c \
  gcc-python-version.c \
  gcc-python-wrapper.c \
  autogenerated-callgraph.c \
  autogenerated-cfg.c \
  autogenerated-option.c \
  autogenerated-function.c \
  autogenerated-gimple.c \
  autogenerated-location.c \
  autogenerated-parameter.c \
  autogenerated-pass.c \
  autogenerated-pretty-printer.c \
  autogenerated-rtl.c \
  autogenerated-tree.c \
  autogenerated-variable.c

PLUGIN_OBJECT_FILES= $(patsubst %.c,%.o,$(PLUGIN_SOURCE_FILES))
GCCPLUGINS_DIR:= $(shell $(CC) --print-file-name=plugin)

GENERATOR_DEPS=cpybuilder.py wrapperbuilder.py

# The plugin supports both Python 2 and Python 3
#
# In theory we could have arbitrary combinations of python versions for each
# of:
#   - python version used when running scripts during the build (e.g. to
#     generate code)
#   - python version we compile and link the plugin against
#   - when running the plugin with the cpychecker script, the python version
#     that the code is being compiled against
#
# However, to keep things simple, let's assume for now that all of these are
# the same version: we're building the plugin using the same version of Python
# as we're linking against, and that the cpychecker will be testing that same
# version of Python
#
# By default, build against "python", using "python-config" to query for
# compilation options.  You can override this by passing other values for
# PYTHON and PYTHON_CONFIG when invoking "make" (or by simply hacking up this
# file): e.g.
#    make  PYTHON=python3  PYTHON_CONFIG=python3-config  all

# The python interpreter to use:
PYTHON=python
# The python-config executable to use:
PYTHON_CONFIG=python-config

#PYTHON=python3
#PYTHON_CONFIG=python3-config

#PYTHON=python-debug
#PYTHON_CONFIG=python-debug-config

#PYTHON=python3-debug
#PYTHON_CONFIG=python3.2dmu-config

PYTHON_CFLAGS=$(shell $(PYTHON_CONFIG) --cflags)
PYTHON_LDFLAGS=$(shell $(PYTHON_CONFIG) --ldflags)

CPPFLAGS+= -I$(GCCPLUGINS_DIR)/include
# Allow user to pick optimization, choose whether warnings are fatal,
# and choose debugging information level.
CFLAGS?=-O2 -Werror -g
# Force these settings
CFLAGS+= -fPIC -fno-strict-aliasing -Wall $(PYTHON_CFLAGS)
LDFLAGS+= $(PYTHON_LDFLAGS)
ifneq "$(PLUGIN_PYTHONPATH)" ""
  CPPFLAGS+= -DPLUGIN_PYTHONPATH='"$(PLUGIN_PYTHONPATH)"'
endif

all: autogenerated-config.h testcpybuilder test-suite testcpychecker

plugin: autogenerated-config.h python.so

python.so: $(PLUGIN_OBJECT_FILES)
	$(CC) $(CPPFLAGS) $(CFLAGS) $(LDFLAGS) -shared $^ -o $@

clean:
	$(RM) *.so *.o autogenerated*
	$(RM) -r docs/_build

autogenerated-config.h: configbuilder.py generate-config-h.py
	$(PYTHON) generate-config-h.py -o $@ --gcc=$(CC)

autogenerated-%.txt: %.txt.in
	$(CPP) $(CPPFLAGS) -x c-header $^ -o $@

autogenerated-%.c: generate-%-c.py $(GENERATOR_DEPS)
	$(PYTHON) $< > $@

autogenerated-gimple.c: autogenerated-gimple-types.txt maketreetypes.py
autogenerated-tree.c: autogenerated-tree-types.txt maketreetypes.py
autogenerated-rtl.c: autogenerated-rtl-types.txt maketreetypes.py
autogenerated-variable.c: autogenerated-gimple-types.txt maketreetypes.py

# Hint for debugging: add -v to the gcc options 
# to get a command line for invoking individual subprocesses
# Doing so seems to require that paths be absolute, rather than relative
# to this directory
TEST_CFLAGS= \
  -fplugin=$(CURDIR)/python.so \
  -fplugin-arg-python-script=test.py

# A catch-all test for quick experimentation with the API:
test: plugin
	$(CC) -v $(TEST_CFLAGS) $(CURDIR)/test.c

# Selftest for the cpychecker.py code:
testcpychecker: plugin
	$(PYTHON) testcpychecker.py -v

# Selftest for the cpybuilder code:
testcpybuilder:
	$(PYTHON) testcpybuilder.py -v

dump_gimple:
	$(CC) -fdump-tree-gimple $(CURDIR)/test.c

debug: plugin
	$(CC) -v $(TEST_CFLAGS) $(CURDIR)/test.c

# A simple demo, to make it easy to demonstrate the cpychecker:
demo: plugin
	./gcc-with-cpychecker $(PYTHON_CFLAGS) demo.c

json-examples: plugin
	./gcc-with-cpychecker -I/usr/include/python2.7 libcpychecker/html/test/example1/bug.c

test-suite: plugin
	$(PYTHON) run-test-suite.py

show-ssa: plugin
	./gcc-with-python examples/show-ssa.py test.c

html: docs/tables-of-passes.rst docs/passes.svg
	cd docs && $(MAKE) html

# We commit this generated file to SCM to allow the docs to be built without
# needing to build the plugin:
docs/tables-of-passes.rst: plugin generate-tables-of-passes-rst.py
	./gcc-with-python generate-tables-of-passes-rst.py test.c > $@

# Likewise for this generated file:
docs/passes.svg: plugin generate-passes-svg.py
	./gcc-with-python generate-passes-svg.py test.c

# Utility target, to help me to make releases
#   - creates a tag in git, and pushes it
#   - creates a tarball
#
# The following assumes that VERSION has been set e.g.
#   $ make tarball VERSION=0.4

tarball:
	-git tag -d v$(VERSION)
	git tag -a v$(VERSION) -m"$(VERSION)"
	git archive --format=tar --prefix=gcc-python-plugin-$(VERSION)/ v$(VERSION) | gzip > gcc-python-plugin-$(VERSION).tar.gz
	sha256sum gcc-python-plugin-$(VERSION).tar.gz
	cp gcc-python-plugin-$(VERSION).tar.gz ~/rpmbuild/SOURCES/

# Notes to self on making a release
# ---------------------------------
#
#  Before tagging:
#
#     * update the version/release in docs/conf.py
#
#     * update the version in gcc-python-plugin.spec
#
#     * add release notes to docs
#
#  Test the candidate tarball via a scratch SRPM build locally (this
#  achieves test coverage against python 2 and 3, for both debug and
#  optimized python, on one arch, against the locally-installed version of
#  gcc):
#
#     $ make srpm VERSION=fixme
#
#     $ make rpm VERSION=fixme
#
#  Test the candidate tarball via a scratch SRPM build in Koji (this
#  achieves test coverage against python 2 and 3, for both debug and
#  optimized python, on both i686 and x86_64, against another version of
#  gcc):
#
#     $ make koji VERSION=fixme
#
#  After successful testing of a candidate tarball:
#
#   * push the tag:
#
#         $ git push --tags
#
#   * upload it to https://fedorahosted.org/releases/g/c/gcc-python-plugin/
#    via:
#
#        $ scp gcc-python-plugin-$(VERSION).tar.gz dmalcolm@fedorahosted.org:gcc-python-plugin
#
#  * add version to Trac: https://fedorahosted.org/gcc-python-plugin/admin/ticket/versions
#
#  * update release info at https://fedorahosted.org/gcc-python-plugin/wiki#Code
#
#  * send release announcement:
#
#      To: gcc@gcc.gnu.org, gcc-python-plugin@lists.fedorahosted.org, python-announce-list@python.org
#      Subject: ANN: gcc-python-plugin $(VERSION)
#      (etc)
#
#  * build it into Fedora

# Utility target, for building test rpms:
srpm:
	rpmbuild -bs gcc-python-plugin.spec

# Perform a test rpm build locally:
rpm:
	rpmbuild -ba gcc-python-plugin.spec

# Perform a test (scratch) build in Koji:
# f16: gcc 4.6
# f17: gcc 4.7
koji: srpm
	koji build --scratch f16 ~/rpmbuild/SRPMS/gcc-python-plugin-$(VERSION)-1.fc15.src.rpm

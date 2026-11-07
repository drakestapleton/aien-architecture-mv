# crumb: RFC-0001 Crumb Protocol tool. Needs only a C11 compiler.
CC ?= cc
CFLAGS ?= -std=c11 -O2 -Wall -Wextra -Werror

crumb: crumb.c
	$(CC) $(CFLAGS) -o $@ crumb.c

test: crumb
	sh test.sh ./crumb
	sh test-continuation.sh ./crumb
	sh test-hostile.sh ./crumb
	sh test-namespace.sh ./crumb

clean:
	rm -f crumb
.PHONY: test clean

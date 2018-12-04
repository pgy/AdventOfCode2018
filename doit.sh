#!/usr/bin/env bash

# Opinionated solutions to https://adventofcode.com/2018/ challenges.
# Created by Gyozo Papp. 

# Day 1.1
#
# Just sum the numbers. Bc does not like unary plus operator, so prepend a 0.
#
cat d/1|sed 1i0|paste -s|bc

# Day 1.2
#
# Use yes with sh to loop over the file infinitly and use awk to aggregate.
# Without the -e (errexit) option, sh would never exit. The reason is that 
# once awk exits, the cat process feeding it writes to a broken pipe, thus
# gets SIGPIPE and exits with non-zero. Sh by default ignores non-zero return
# codes and simply continues execution. Errexit prevents that.
#
yes cat d/1|sh -e|awk '{f+=$1;if(s[f]++){print f;exit}}'

# Day 2.1
#
# Pretty straightforward I guess. Here-string (<<<) notation can be handy
# with xargs to pass arguments to stdin.
#
cat d/2|xargs -n1 sh -c 'fold -w1<<<$0|sort|uniq -c|awk "/ [23] /{print \$1}"|sort -u'|sort|uniq -c|tr -d \\n|awk '{print $1*$3}'

# Day 2.2
#
# The first xargs with yes|head simply duplicates every line n-times. The
# xargs replaces the i-th character -- say x -- in the i-th duplicate with
# the not-x regex ([^x]) and greps for that in the file. Prepend grep -q with
# an echo command to see what it does. 
# 
# A nice takeaway is that parameter expansions and arithmetic expressions can
# be nested. I use the old-style arithmetic expression syntax $[...] instead of
# the new one $((...)). I know, it is deprecated -- it's not even present in
# the man page of my shell -- but I don't care as it still works and is shorter
# than the new one.
# 
# You can speed it up somewhat by parallelizing xargs (-P).
#
cat d/2|xargs -n1 sh -c 'yes $0|head -${#0}|nl'|xargs -n2 sh -c 'grep -q ${1:0:$[$0-1]}[^${1:$[$0-1]:1}]${1:$0:${#1}} d/2&&echo ${1:0:$[$0-1]}${1:$0:${#1}}'|sed 1d

# Day 3.1
#
# Yay, 2d arrays! Use brace expansion as a poor man's itertools.product to
# generate every cell in every rectangle. Note that \<space> is the same as
# "<space>". 
#
cat d/3|tr ,:x \ |xargs -n6 sh -c 'eval echo {$2..$[$2+$4-1]}x{$3..$[$3+$5-1]}'|tr \  \\n|sort|uniq -c|grep -vc ' 1 '

# Day 3.2
#
# This one was fun. For every rectangle the first xargs generates a line
# where the first column contains the rectangle id, then n columns contain
# the n cells the rectangle consists of, then the last column stores the
# number n itself. 
#
# The part in <(...) generates very specific sed commands: the i-th command
# removes every cell of the i-th rectangle from every other rectangle, (except
# the i-th rectangle, of course). 
#
# I first wanted to supply the sed command with $(...) on the command line, but
# it was too long, so I had sed read it from a pipe with -f. The reason for the
# underscores is to prevent sed from removing things like 4x32 or 14x31 when I
# want it to remove only 4x3. I don't think sed has negative matches inside 
# regex, but it can negate an "address regex" with an exlamation point after it.
#
# After sed, every line will contain the rectangle id, the cells of the 
# rectangle but with some of them (the overlapping ones) removed, and the
# original cell number of the rectangle. The solution is on the line where this
# number equals the number of remaining cells.
#
# I could have golfed it a little more by relying on the fact that rectangle
# ids are 1-based sequential, but I like my id-agnostic solution better.
#
# I also experimented with splitting the stream with tee after first eval, so
# that I don't have to do it, but I could not find a way to join the streams
# back together for the sed without using external files/fifos.
#
cat d/3|tr \#,:x \ |xargs -n6 sh -c 'eval echo $0 _{$2..$[$2+$4-1]}x{$3..$[$3+$5-1]}_'|awk '{print $0, NF-1}' | sed -rf <(cat d/3|tr \#,:x \ |xargs -n6 sh -c 'eval echo $0 _{$2..$[$2+$4-1]}x{$3..$[$3+$5-1]}_'|sed -r 's@([^ ]*) (.*)@/^\1/!s/\2//g;@' | tr \  \|)|awk 'NF==$NF+2{print $1}'

# Day 4.1
#
# This solution became somewhat over-engineered (even more than the others),
# as I wanted to solve it with opening the input file only once.
#
# The first part until the tee command is just preprocessing, it puts the 3
# values to every line: (guard_id, sleep_start_minute, sleep_end_minute).
#
# The tee command is a workaround so that I don't have to read the file twice,
# it forks the stream into two pipelines (via process substitutions). The
# redirect-with-process substitution idiom "> >(...)" is a hack to prevent
# tee from outputing the input stream on the stdout. By default tee >(A) >(B)
# would pipe the input to both A and B and stdout. By using tee >(A) > >(B),
# the input is piped only to A and stdout, while stdout is redirected into B.
# This works because >(..) just creates a file descriptor with a pseudo name
# and pastes this name into the command line, so I can redirect into it.
#
# The first pipeline in the first >(..) finds the id of the guard that slept the
# most. The strange "sed -n 1s/..." command just takes the first line and removes
# everything before a space.
#
# The second >(..) prints every (G, M) tuple where guard G slept in minute M.
# The two values in the tuples are separated with an underscore. These tuples
# are pasted onto a single line, and the line is prefixed with a capital X.
#
# At the pipe after tee, there are only two lines in the pipeline: a line that
# contains a single number (a guard id) and another line that starts with X
# and contains the tuples. I don't think the order of lines are determined when
# they are generated by two asynchronous processes, so I have to sort these.
# I want the guard id to be on the first line. This is why I put X on the
# second line and sort with LC_ALL=C -- ASCII X is after ASCII numbers.
#
# I use xargs and grep with the here-string trick to filter the tuples so that
# only the minutes of one guard remain. From there it is pretty straightforward
# to find the most common minute and calculate the result.
#
cat d/4|sort|tr '#:] ' \ |awk '/G/{g=$5}/l/{s=$3}/w/{print g,s,$3}'|tee >(awk '{print S[$1]+=$3-$2,$1}'|sort -nr|sed -n '1s/.* //p') > >(awk '{print "echo "$1"_{"$2".."$3-1"}"}'|sh|sed 1iX|paste -s)|LC_ALL=C sort|xargs sh -c 'grep -o $0_"[^ ]*"<<<"$@"'|awk -F_ '{print f[$0]++,$1*$2}'|sort -nr|sed -n '1s/.* //p'

# Day 4.2
#
# Nothing new here.
#
cat d/4|sort|tr ':] ' \ |awk '/G/{g=$5}/l/{s=$3}/w/{print "echo \\"g"_{"s".."$3-1"}"}'|sh|tr ' _#' '\n  '|awk '{print 1+g[$1,$2]++,$1*$2}'|sort -nr|sed -n '1s/.* //p'


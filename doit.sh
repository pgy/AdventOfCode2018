#!/usr/bin/env bash

# Opinionated solutions to https://adventofcode.com/2018/ challenges.
# I skipped challenges that are not fun for some reason (too complex,
# not interesting, I had no idea how to solve).
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
# UPDATE: While this solution worked for me all the time, I don't think
# it is guaranteed to work with every valid input, see comments at day 5.2 
# for the problem with combining the outputs of async processes.
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

# Day 5.1
#
# I learned some great sed tricks here: \u turns the next character uppercase.
# The & references the whole matched pattern. :B creates a label called B, and
# tB can be used to jump to this label if the previous s command succeeded.
cat d/5|tr -d \\n|sed -r ":B;s/$(echo {a..z}|sed 's/./\0\u&|\u&\0/g'|tr -d \ )//g;tB"|wc -c

# Day 5.2
#
# Same as before, but use eval and brace expansion to execute the solution
# of day 5.1 multiple times with minor alteration for each letter.
#
# Originally I wanted to run only the sed s/{a..z}//ig in the >(..) blocks,
# but I could not reliably combine the output of the substituted processes.
# Output of one process always interrupted the output of another. When I
# tried to use one long line per process, they got corruped after the length
# was around 4200 bytes. When I used many short lines per process (1-2 bytes,
# prefixed with source process if and sequence number, altogether 10-20 bytes)
# they got corrupted as well. I don't think there is a reliable way to
# combine the output of tee >(..) >(..) without using explicit pipe files and
# cat.
#
cat d/5|eval $(echo tee \> '>(sed s/'{a..z}'//ig|sed -r ":B;s/$(echo {a..z}|sed "s/./\0\u&|\u&\0/g"|tr -d " ")//g;tB"|wc -c)')|sort -n|awk '{print $0-1;exit}'

# Day 6.1
#
# No idea.
#
echo '¯\_(ツ)_/¯'

# Day 6.2
# 
# Didn't solve 6.1, don't know what this is.
#
echo '¯\_(ツ)_/¯'

# Day 7.1
#
# What we need here is a topological sort with alphabetical ordering of 
# nodes at the same level. There are a few utilities on the command line
# that operate on DAGs and can be used to implement topological sort.
#
# Here is a list of methods I tried. Unfortunately all of these failed,
# as I could only implement regular (non-alphabetically-stable) sorting.
#
# Tsort based attempt (use tsort with pre-sorting):
#
#   cat d/7|sed 1i_|sort -k8|awk 'g!=$8{g=$8}{print "%"$2,$2"\n%"$8,$8"\n"$2,g}'|LC_ALL=C sort -u|grep ...|tr -d %|tsort|paste -sd ""
#
# Makefile based attempt (same, but use makefile instead of tsort, maybe
# it keeps the nodes in alphabetical order (no)):
#
#   cat d/7|egrep -o ' [A-Z]'|sort -u|sed 1iall:|paste -sd ''|cat - <(cat d/7|awk '{print $8": "$2;system("touch "$8".in "$2".in")}'|sort)|sed '$a%: %.in\n\trm -f $@'|make -f -|cut -c7-|paste -sd ''
#
# A desperate try with find (the base idea was that the filesystem is
# basically a DAG itself, directories would represent nodes and the
# algorithm would move directory A into B if A depended on B):
#
#   mkdir {A..Z}
#   cat d/7|cut -c6,37|sort|sed -r 's@(.)(.)@mv $(find -type d -name \2) $(find -type d -not -path "*\2*" -path "*\1*"|awk "{print length, \\$0}"|sort -n|awk "{print \\$2;exit}") @'|sh
#
# Some more stuff I tried:
#
#   - dot with rank=same
#   - gcc -MMD -MF
#
# The solution that worked:
#
# Finally I gave up using these fancy tools and just implemented the desired
# tsort algorithm. Probably this is the solution I like the least so far, for
# it is single-line only on first glance; it generates and evals an iterative
# bash script.
#
# The only useful thing I leared here is that the sort utility is not stable by
# default, it needs the -s option for that.
#
cat d/7 | (cd $(mktemp -d) && sort -k8|awk 'g!=$8{g=$8;print "touch "$2" "$8}{print "echo "$2">>"g}'|cat - <(yes 'wc -l *|sort -ns|xargs sh -c "sed -i /\$1/d * && rm \$1 && echo \$1"'|head -n26)|sh|paste -sd '')

# Day 7.2
#
# Things that might help (in no particular order): &, flock, mkfifo, xargs -P,
# but I really have no idea.
#
echo '¯\_(ツ)_/¯'

# Day 8: this is too recursive to be fun
# Day 9: the rules are too arbitrary
# Day 10: no idea (maybe check for straight lines and then do gocr?)
#
yes '¯\_(ツ)_/¯' | head -6

# Day 11

# Day 12.1
#
# The simulation is done by the sed script, everything else is to calculate the
# numberic result.
# 
# Lets break it down:
#   1!d;        Delete the first line.
#   y/./_/;     Replace . with _, as . has special meaning in regex.
#   :O;         Create a label called (O)uterLoop.
#   p;          Print the line.
#   s/^/:____/; Insert some dead plants to the beginning for "infinit" space.
#               This command also insert a cursor value ":" to the beginning.
#               As the algorithm processes the string, I want this cursor to
#               separate the already processed and unprocessed parts.
#   s/$/____/;  Insert some dead plants to the end for "infinit" space.
#   :I;         Create a label called (I)nnerLoop
#   $(...);     Generate "s" sed commands for every rule. These commands do
#               the actual replacements and advance the cursor.
#   tI;         Repeat from I, if one of the generated commands succeeded.
#   s/://;      The cursor is at the end, no more replacements, repeat from O.
#
# Because I append 4 dead plants to the beginning in every iteration, the
# position of the first visible pot at iteration i can be calculated by this
# function: -(4-2)*i. So after the 20th iteration, the address of the first 
# visible pot is -40.
#
cat d/12|sed -nr '1!d;y/./_/;s/.*: //;:O;p;s/^/:____/;s/$/____/;:I;'"$(cat d/12|sed -rn 'y/./_/;/=/s/(.)(....) => (.)/s@:\1\2@\3:\2@/p')"';tI;s/://;bO'|head -21|tail -n1|fold -w1|paste - <(seq -40 300)|awk '/#/{s+=$2}END{print s}'

# Day 12.2
#
# Actually, after a few generations, the flowers will remain the same, they
# will only move rightward by 1 pot / generation speed. This is not fun to
# calculate in bash.
#
echo '¯\_(ツ)_/¯'

#!/usr/bin/env bash
export LC_ALL=C
cat d/1|tr -d +|paste -sd+|bc
yes cat d/1|sh -e|awk '{f+=$1;if(s[f]++){print f;exit}}'
cat d/2|xargs -n1 sh -c 'fold -w1<<<$0|sort|uniq -c|awk "/ [23] /{print \$1}"|sort -u'|sort|uniq -c|tr -d \\n|awk '{print $1*$3}'
cat d/2|xargs -n1 sh -c 'yes $0|head -${#0}|nl'|xargs -n2 sh -c 'grep -q ${1:0:$[$0-1]}[^${1:$[$0-1]:1}]${1:$0:${#1}} d/2 && echo ${1:0:$[$0-1]}${1:$0:${#1}}'|sed 1d

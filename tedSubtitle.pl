#!/usr/local/bin/perl
################################################################################
#  File: tedSubtitle.pl
#  Desscription: Get ted talk's subtitle from TED.com 
#                and convert subtitle of TED video to SRT format(SubRip Subtitle File)
#  Usage: ted.pl URL languageCode output.src 
#  Creator: Thinkhy
#  Date: 2011.04.30   
#  Online Doc: http://blog.csdn.net/thinkhy/article/details/6564434   
#  Last version of source code: https://gist.github.com/949659 
#  ChangeLog: 1 Add language code. [thinkhy 2011.05.06]
#             2 Read advertisement time from the parameter of introDuration in html.
#               If the time is not correct by intorDuratoin parameter,
#               you can set it up in the last argument of command line($ARGV[3]).    [thinkhy 2011.07.16]
#             3 Optimized code, add  code for checking command arguments. [thinkhy 2011.09.3]
#             4 Ajust Regexp for extraction of Adv. duration [thinkhy 2012.01.26]
#             5 Thanks to doyouwanna's bug report, fixed the problem of inaccurate advertisement duration which is due to  percent-encode in html. [thinkhy 2012.10.21]
#             6. Ted.com changed the vedio page recently, fixed the problem that failed to get talk id.  
#                Thanks to Xianglin  for reporting this problem. [thinkhy 3/23/2013]        
#             7. Specify fileencoding as CP936 when language code is chi_hans
#                Thanks to CYan  for reporting this defect. [thinkhy 12/15/2013]        
#
#             8. @A4: make some changes to accommodate the update of TED.com. 
#                Thanks to Xianglin for throwing me an email and shared his package with me. [thinkhy 3/19/2014]
#
#  LanguageCode     Language  
#   sq              Albanian
#   ar              Arabic
#   hy              Armenian
#   bs              Bosnian
#   bg              Bulgarian
#   zh-cn	        Chinese, Simplified
#   zh-tw	        Chinese, Traditional
#   nl          	Dutch
#   en          	English
#   eo          	Esperanto
#   fr          	French
#   ka          	Georgian
#   de          	German
#   el          	Greek
#   he          	Hebrew
#   hi          	Hindi
#   hu          	Hungarian
#   id          	Indonesian
#   it          	Italian
#   ja          	Japanese
#   ko          	Korean
#   lt          	Lithuanian
#   nb          	Norwegian Bokmal
#   fa          	Persian
#   pl          	Polish
#   pt          	Portuguese
#   pt-br	        Portuguese, Brazilian
#   ro          	Romanian
#   ru          	Russian
#   sr          	Serbian
#   sk          	Slovak
#   es          	Spanish
#   th          	Thai
#   tr          	Turkish
#   uk          	Ukrainian
#   ur          	Urdu
#   vi          	Vietnamese
#
################################################################################
use strict;
use Data::Dumper;
use JSON;
use URI::Escape;

use LWP::Simple qw(get);


# check for argument number
my $argc = @ARGV;
if ($argc < 3)
{
    print "USAGE: ted.pl URL languageCode output.src\n";
    exit -1;
}


# Get content from file
# my $content = GetContentFromFile("back.json");

# The TED talk URL
my $url = $ARGV[0];
print "URL: $url\n";

# languageCode  
my $languageCode = $ARGV[1];

# output file of SRT format
my $outputFile = $ARGV[2];

# !!Note: What you should do is to write URL of TED talks here.
# my $url = "http://www.ted.com/talks/stephen_wolfram_computing_a_theory_of_everything.html";

#open OUT, ">out.html";

# First of all, Get the talkID from the web page.
print "Get the html content from $url\n";
my $html = GetUrl($url); 

#my $html = do { local( @ARGV, $/ ) = "out.html"; <> };
#print OUT $html;

# Fixed the problem that failed to get talk id, it's because Ted.com changed the vedio page recently.
# Thanks to Xianglin for reporting this problem timely. [thinkhy 3/23/2013]        
# $html =~ m/(?<=var talkDetails = \{"id":).*?(\d+)/g;      @A4D

#my $talkID = $1;          @A4D
#chomp($talkID);           @A4D

my $introDuration = 16000; #  seconds of Advertisement time(millisecond).
                           #  depends on talk year     


# to find "introDuration":11.82,"adDuration":"3.33
my ($introDuration, $adDuration) = $html =~ /"introDuration":(.*?),"adDuration":"(.*?)"/i; 
my $headDuration = $introDuration * 1000 + $adDuration * 1000;
print "Introduction duration: $headDuration\n";

my ($talkID) = $url =~ qr(www.ted.com/talks/(.*?)(\.html)?$)im;   # @A4A
die "Failed to extract talk ID." unless $talkID;
print "Speech title: $talkID\n";                                  # @A4A

print "Seems good, go on.\n";

#/(?<=\t)\w+/ 
# print OUT $html;

# Get subtitle content from TED.COM
# my $subtitleUrl = "http://www.ted.com/talks/subtitles/id/$talkID/lang/$languageCode/format/text";  @A4D
my $subtitleUrl = "http://www.ted.com/talks/$talkID/transcript?language=$languageCode";                 #@A4A
print "Subtitle URL: $subtitleUrl\n";
my $content = GetUrl($subtitleUrl);

#open DEBUG, ">out.json";
#print DEBUG $content;

# subtitles in Chinese Hans should be saved using CP936
# Thanks CYAN for reporting this problem [thinkhy 12/15/2013]
open SRT, ">$outputFile";
if ($languageCode =~ /zh-cn/i) {
    print "Set fileencoding=CP936 for chi_hans\n";
    binmode(SRT, ":encoding(CP936)");
}


my $cnt = 0;
my $span = $content =~ /<span class='talk-transcript__fragment'.*?<\/span>/;  # @A4A
my ($datatime1) = $span =~ /data-time='(\d+)'/i;  # @A4A

while ($content =~ /<span class='talk-transcript__fragment'.*?<\/span>/gi) # @A4A
{
    $span = $&;# @A4A
    my ($datatime2) = $span =~ /data-time='(\d+)'/i; # @A4A
    my ($line) = $span =~ /'>(.+?)<\/span>/i;# @A4A
    print "$datatime1 - $datatime2: $line\n";# @A4A

    OutputSrt(1+$cnt, $datatime1, $datatime2, $line);# @A4A

    $datatime1 = $datatime2;
    $cnt++;
}


#OutputSrt(1+$cnt, $startTime, $duration, $subtitle);

#################### End of Main ##########################




###########################################################
# Sub Functions
###########################################################
sub GetTime
{
    my ($time) = @_;

    my $mils = $time%1000;
    my $segs = int($time/1000)%60;
    my $mins = int($time/60000)%60;
    my $hors = int($time/3600000);

    return ($hors, $mins, $segs, $mils);
}

sub OutputSrt
{
    my ($orderNum, $startTime, $endTime, $subtitle) = @_;

    $startTime += $headDuration;
    $endTime += $headDuration;

    # Caculate hour, minute, second, msecond
    my($hour, $minute, $second, $msecond) = GetTime($startTime); 

    print SRT "$orderNum\n"; # order number

    # Begin time
    print SRT $hour.":".$minute.":".$second.",$msecond";

    # delimitation
    print SRT " --> ";

    # End time
    my($hour1, $minute1, $second1) = GetTime($endTime); 
    print SRT $hour1.":".$minute1.":".$second1.",$msecond\n";

    # Subtitle
    print SRT "$subtitle\n\n";
}


sub GetContentFromFile
{
    my $file = shift; 
    my $content;

    open FILE, $file;  
    while(<FILE>) {
        $content .= "$_";
    }

    return $content;
}

# Test URL: http://www.ted.com/talks/subtitles/id/843/lang/eng/format/text
sub GetUrl
{
    my $url = shift;
    my $content = get($url) or die "Can't get $url \n";

    # Thanks to doyouwanna's bug report, 
    # fix the problem of inaccurate advertisement duration which is due to  percent-encode in html. [thinkhy 2012.10.21]
    my $encode = uri_unescape($content);

    return $encode;
}

__END__

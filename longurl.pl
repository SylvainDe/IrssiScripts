# TODO : clean this part
use strict;
use warnings;   
no diagnostics;
use Irssi;
use Data::Dumper;
use CGI;
use IO::Socket;
use LWP::UserAgent;
require LWPx::ParanoidAgent; #http://stackoverflow.com/questions/73308/true-timeout-on-lwpuseragent-request-method sudo apt-get install liblwpx-paranoidagent-perl
use URI::Escape;
use URI::Find;              # sudo apt-get install liburi-find-perl 
use URI::Find::Schemeless;
use XML::Simple;            # sudo apt-get install libxml-simple-perl 
use JSON;                   # sudo apt-get install libjson-perl
use Digest::MD5 qw(md5 md5_hex md5_base64);

#TODOTODAY
# Last update : Jan 2011 so it's all pretty ugly/old but I'd rather save this before I lose it
#
use vars qw($VERSION %IRSSI);
$VERSION = '0.0';
%IRSSI = (
    authors => 'Sylvain Desodt',
    contact => 'sylvain.desodt+irssiscript@gmail.com',
    name => 'urlInfo',
    description => 'Retrieve information about the URLs sent to you and use them',
    license => 'TBD',
    url => 'none',
);

# TODO : version with a threaded retrieval of information
# TODO : good way to handle the cache (select from it, clean it, max_size, etc)
# TODO : security stuff for backup : file size, extension, etc
# TODO : encoding (title) ( http://bit.ly/hy90O6 ) + special characters a la con
# TODO : when backup : type mime
# TODO : url shortener
# TODO : if (image) getExifStuff... ou pas

# ========= Irssi settings ===========

my $regex_empty = '^$';

# Hash of settings
my %settings =
(
    # Settings related to printed results
    '_printIfNotNew'        => { type=>'bool', explanation=>'none',
        paranoid_value      => 0,
        default_value       => 0,
        debug_value         => 1,
        bot_value           => 1},
    '_printOnWin1'          => { type=>'str', explanation=>'none',
        paranoid_value      => '',
        default_value       => '',
        debug_value         => '',
        bot_value           => 'context-backup_url'},
    '_printOnActiveWin'     => { type=>'str', explanation=>'none',
        paranoid_value      => '',
        default_value       => '',
        debug_value         => '',
        bot_value           => ''},
    '_printOnSpecialWin'    => { type=>'str', explanation=>'none',
        paranoid_value      => '',
        default_value       => '',
        debug_value         => '',
        bot_value           => ''},
    '_specialWinName'       => { type=>'str', explanation=>'none',
        paranoid_value      => '',
        default_value       => '',
        debug_value         => '',
        bot_value           => ''},
    '_printOnOriginalWin'   => { type=>'str', explanation=>'none',
        paranoid_value      => '',
        default_value       => 'backup_url-long_url-title',
        debug_value         => 'backup_url-long_url-title',
        bot_value           => ''},
    '_sendOnOriginalWin'    => { type=>'str', explanation=>'none',
        paranoid_value      => '',
        default_value       => '',
        debug_value         => '',
        bot_value           => 'backup_url-title'},

    # Settings related to blacklists
    '_blacklistUrls'        => { type=>'str', explanation=>'none',
        paranoid_value      => '^$',
        default_value       => '^$',
        debug_value         => '^$',
        bot_value           => '^$'},
    '_blacklistServers'     => { type=>'str', explanation=>'none',
        paranoid_value      => '^$',
        default_value       => '^$',
        debug_value         => '^$',
        bot_value           => '^$'},
    '_blacklistChannels'    => { type=>'str', explanation=>'none',
        paranoid_value      => '^$',
        default_value       => '^$',
        debug_value         => '^$',
        bot_value           => '^$'},
    '_blacklistNicks'       => { type=>'str', explanation=>'none',
        paranoid_value      => '^$',
        default_value       => '^$',
        debug_value         => '^$',
        bot_value           => '^$'},

    # Settings related to backup
    '_backupWhenRetrieve'   => { type=>'bool', explanation=>'none',
        paranoid_value      => 0,
        default_value       => 0,
        debug_value         => 0,
        bot_value           => 1},
    '_backupUrlMatch'       => { type=>'str', explanation=>'none',
        paranoid_value      => '^$',
        default_value       => '^$',
        debug_value         => '^$',
        bot_value           => '^$'},
     '_backupServerMatch'   => { type=>'str', explanation=>'none',
        paranoid_value      => '^$',
        default_value       => '^$',
        debug_value         => '^$',
        bot_value           => '^$'},
      '_backupChannelMatch' => { type=>'str', explanation=>'none',
        paranoid_value      => '^$',
        default_value       => '^$',
        debug_value         => '^$',
        bot_value           => '^$'},
      '_backupNickMatch'   => { type=>'str', explanation=>'none',
        paranoid_value      => '^$',
        default_value       => '^$',
        debug_value         => '^$',
        bot_value           => '^$'},
 
    '_backupHtmlFolderPath' => { type=>'str', explanation=>'none',
        paranoid_value      => '',
        default_value       => '/home/josay/html/backup/',
        debug_value         => '/home/josay/html/backup/',
        bot_value           => '/home/josay/html/backup/'},
    '_backupHtmlFolderUrl'  => { type=>'str', explanation=>'none',
        paranoid_value      => '',
        default_value       => 'http://josay.kollok.org/backup/',
        debug_value         => 'http://josay.kollok.org/backup/',
        bot_value           => 'http://josay.kollok.org/backup/'},
    '_backupSafeExtensions' => { type=>'str', explanation=>'none',
        paranoid_value      => '',
        default_value       => 'html-htm-js-txt-png-jpg-jpeg-gif',
        debug_value         => 'html-htm-js-txt-png-jpg-jpeg-gif',
        bot_value           => 'html-htm-js-txt-png-jpg-jpeg-gif'},

    # Settings related to HTTP Requests
    '_useragent'            => { type=>'str', explanation=>'none',
        paranoid_value      => 'ua',
        default_value       => 'urlInfo script',
        debug_value         => 'urlInfo script',
        bot_value           => 'urlInfo bot'},
    '_httpReferer'          => { type=>'str',explanation=>'none',
        paranoid_value      => 'http://www.google.com/',
        default_value       => 'http://www.google.com/',
        debug_value         => 'http://www.google.com/',
        bot_value           => 'http://www.google.com/'},
    '_timeout'              => { type=>'int',explanation=>'none',
        paranoid_value      => 1,
        default_value       => 3,
        debug_value         => 5,
        bot_value           => 3},
    '_maxsize'              => { type=>'int',explanation=>'none',
        paranoid_value      => 500000,
        default_value       => 5000000,
        debug_value         => 50000000,
        bot_value           => 5000000},

    # Settings related to the cache
    '_cacheSize'            => { type=>'int',explanation=>'none',
        paranoid_value      => 1000,
        default_value       => 1000,
        debug_value         => 1000,
        bot_value           => 2000},
    '_storeRedundantData'   => { type=>'bool',explanation=>'none',
        paranoid_value      => 0,
        default_value       => 0,
        debug_value         => 0,
        bot_value           => 1},
    '_storeUselessEntries'  => { type=>'bool',explanation=>'none',
        paranoid_value      => 0,
        default_value       => 0,
        debug_value         => 0,
        bot_value           => 1},
    '_usedMethods'          => { type=>'str',explanation=>'none',
        paranoid_value      => '',
        default_value       => 'cache-direct',
        debug_value         => 'cache-direct-printDebugStuff',
        bot_value           => 'cache-direct'},
);

# Adding settings
foreach my $setting_name (keys %settings)
{
    my $setting = $settings{$setting_name};
    my $type = $setting->{'type'};
    my $value = $setting->{'default_value'};
    my $name=$IRSSI{name} . $setting_name;
    Irssi::settings_remove($name);
    if    ($type eq 'int'   ) { Irssi::settings_add_int   ($IRSSI{name}, $name, $value);}
    elsif ($type eq 'bool'  ) { Irssi::settings_add_bool  ($IRSSI{name}, $name, $value);}
    elsif ($type eq 'time'  ) { Irssi::settings_add_time  ($IRSSI{name}, $name, $value);}
    elsif ($type eq 'size'  ) { Irssi::settings_add_size  ($IRSSI{name}, $name, $value);}
    elsif ($type eq 'level' ) { Irssi::settings_add_level ($IRSSI{name}, $name, $value);}
    else                      { Irssi::settings_add_str   ($IRSSI{name}, $name, $value);}
}


my $default_stringFormats       = ''; #'!last_uri! ( !backup_url! ) - !long_url! (!last_uri!) - !url! [!title!] - < !url! > ';

# Irssi theme
#my $beginLineThemeString = '%R>>%n %_' . $IRSSI{name} . ':%_ ';
my $beginLineThemeString = '%K ' . $IRSSI{name} . ' : ';
Irssi::theme_register([
    $IRSSI{name} . '_loaded', $beginLineThemeString . 'Loaded version $0. Have fun with it !',
    $IRSSI{name} . '_debug',  $beginLineThemeString . '$1 at $0',
    $IRSSI{name} . '_info', $beginLineThemeString . '$0',
    $IRSSI{name} . '_result', $beginLineThemeString . '$0',
    $IRSSI{name} . '_error',  $beginLineThemeString . '$0',
    ]);


# ========= API settings ===========
# longurl http://longurl.org/
my $longurlApiUrl = 'http://api.longurl.org/v2/expand';
my $longurlFavoriteFormat = 'xml'; # xml, json, jsonp and php can be provided but this script only handles xml and json
my $longurlOptions = 'all-redirects=1&content-type=1&response-code=1&title=1&rel-canonical=1&meta-keywords=1&meta-description=1&format=' . $longurlFavoriteFormat;
my $longurlMaxUrlLength = 50;

# expandurl http://expandurl.com/
my $expandurlApiUrl = 'http://expandurl.com/api/v1/';
my $expandurlOptions = '&format=json&detailed=true';
my $expandurlMaxRequests = 100;
my $expandurlTimeRange = 3600;
my @expandurlLastAccesses;

# longurlplease http://www.longurlplease.com/
my $longurlpleaseApiUrl = 'http://www.longurlplease.com/api/v1.1';

# websites with no api, i could use them but...
# knowurl http://knowurl.com/
# checkshorturl http://checkshorturl.com/
# expandmyurl http://www.expandmyurl.com/


# ========= Global objects ===========
# Xml simple
my $xmlSimple = XML::Simple->new();

# Cache
my %url_cache;

# Cache description # TODO : make that list a hash with description/methods/etc
my @data_cache = qw (url long_url backup_url title keywords first_uri first_update first_nick first_channel first_server first_source last_uri last_read last_nick last_channel last_server);

# User agent
#my $ua = LWP::UserAgent->new;
my $ua = LWPx::ParanoidAgent->new; # https://www.socialtext.net/perl5/index.cgi?exception_handling

# Running
my $running = 0;

# Error stuff (temporary, just for debug reasons)
my $error = "";

# ========= Functions ===========

sub help
{
    # Name & Basic description
    print($IRSSI{name} . ' : ' . $IRSSI{description} . '\n');
    # Settings description
    foreach my $setting_name (keys %settings)
    {
        my $setting = $settings{$setting_name};
        my $explanation = $setting->{'explanation'};
        my $name=$IRSSI{name} . $setting_name;
        print($name . ' : ' . $explanation);
    }
}

sub getSettingValue
{
    my ($setting_name) = @_;
    my $setting = $settings{$setting_name};
    my $type = $setting->{'type'};
    my $name=$IRSSI{name} . $setting_name;
    if    ($type eq 'int'   ) { Irssi::settings_get_int   ($name);}
    elsif ($type eq 'bool'  ) { Irssi::settings_get_bool  ($name);}
    elsif ($type eq 'time'  ) { Irssi::settings_get_time  ($name);}
    elsif ($type eq 'size'  ) { Irssi::settings_get_size  ($name);}
    elsif ($type eq 'level' ) { Irssi::settings_get_level ($name);}
    else                      { Irssi::settings_get_str   ($name);}
}

sub loadPredefinedSetOfSettings
{
    #my $set='bot_value';
    my $set='default_value';
    #my $set='debug_value';
    foreach my $setting (keys %settings)
    {
        my $setting_ = $settings{$setting};
        my $type = $setting_->{'type'};
        my $value = $setting_->{$set};
        my $name=$IRSSI{name} . $setting;
        if    ($type eq 'int'   ) { Irssi::settings_set_int   ($name, $value);}
        elsif ($type eq 'bool'  ) { Irssi::settings_set_bool  ($name, $value);}
        elsif ($type eq 'time'  ) { Irssi::settings_set_time  ($name, $value);}
        elsif ($type eq 'size'  ) { Irssi::settings_set_size  ($name, $value);}
        elsif ($type eq 'level' ) { Irssi::settings_set_level ($name, $value);}
        else                      { Irssi::settings_set_str   ($name, $value);}
    }
    Irssi::printformat(MSGLEVEL_CLIENTCRAP, $IRSSI{name} . '_result', 'Predefined set of value ' . $set . ' loaded.');
}
loadPredefinedSetOfSettings();

sub viewCache
{
    Irssi::print(Dumper(%url_cache));
}

sub doesDataMatchRegex
{
    my ($data, $regex) = @_;
    eval { $data =~ /$regex/i and die 'MATCH'; };
    if ($@ =~ /^MATCH/)
    {
        return "yes";
    } elsif ($@)
    {
        return "error"
    } else {
        return "no";
    }
}

sub isInBlacklist
{
    my ($url, $nick, $channel, $server_name) = @_;
    my %blacklist_multihash = 
    (
        url     => { data_to_check => $url,         , blacklist_name => '_blacklistUrls'},
        nick    => { data_to_check => $nick         , blacklist_name => '_blacklistNicks'},
        channel => { data_to_check => $channel      , blacklist_name => '_blacklistChannels'},
        server  => { data_to_check => $server_name  , blacklist_name => '_blacklistServers'},
    );
    foreach my $blacklist (keys %blacklist_multihash)
    {
        my $data            =   $blacklist_multihash{$blacklist}->{'data_to_check'};
        my $blacklist_name  =   $blacklist_multihash{$blacklist}->{'blacklist_name'};
        my $blacklist_regex =   getSettingValue($blacklist_name);
        my $match = doesDataMatchRegex($data,$blacklist_regex);
        if ($match eq 'yes')
        {
            Irssi::print('Blacklist :  \'' . $data . '\' is in the ' . $blacklist . ' blacklist (\'' . $blacklist_regex . '\')'); 
            return 1;
        } elsif ($match eq 'error')
        {
            Irssi::print('Error while trying to use regex \'' . $blacklist_regex . '\' : ' . $@);
            Irssi::print('Changing the value of ' . $IRSSI{name} . $blacklist_name . ' to \'' . $regex_empty . '\'.');
            Irssi::settings_set_str($IRSSI{name} . $blacklist_name, $regex_empty);
        }
    }
    return 0;
}

sub printResultInWindow
{
    my ($data, $window, $send) = @_;
    if ($window)
    {
        if ($send)
        {
            # infinite loop should not happen because of "$running"
            $window->command('MSG ' . $window->{'name'} . ' ' . $data); 
        } else {
            $window->printformat(MSGLEVEL_CLIENTCRAP, $IRSSI{name} . '_result', $data);
        }
    } else {
        Irssi::printformat(MSGLEVEL_CLIENTCRAP, $IRSSI{name} . '_result', $data);
    }
}

sub printNeededResults
{
    my ($url_data, $window_string_or_obj, $send) = @_;
    my $string; my $window;
    if ($window_string_or_obj eq 'win1')
    {
        $string = '_printOnWin1';
        $window = undef;
        $send = 0;
    } elsif ($window_string_or_obj eq 'activeWin')
    {
        $string = '_printOnActiveWin';
        $window = Irssi::active_win();
        $send = 0;
    } elsif ($window_string_or_obj eq 'specialWin')
    {
        my $window_special_name = getSettingValue('_specialWinName');
        if ($window_special_name)
        {
            $window = Irssi::window_find_name($window_special_name);
            if ($window)
            {
                $string = '_printOnSpecialWin';
                $send = 0;
            } else
            {
                Irssi::printformat(MSGLEVEL_CLIENTNOTICE, $IRSSI{name} . '_error', 'Cannot find window ' . $window_special_name . ' . To create it : /window new hide; /window name ' . $window_special_name . ';');
            }
        }
    } elsif ($window_string_or_obj)
    {
        $window = $window_string_or_obj;
        $string = ($send) ? '_sendOnOriginalWin' : '_printOnOriginalWin';
    }
    return unless ($string);

    my @elementsToPrint = split('-', getSettingValue($string));
    foreach my $elementToPrint (@elementsToPrint)
    {
        $elementToPrint =~ s/^\s*(.*)\s*$/$1/; # TODO : cf comment @ data_cache
        if ($elementToPrint eq 'url') {
            printResultInWindow('Url : '        . $url_data->{'url'}, $window, $send)          if ($url_data->{'url'});
        } elsif ($elementToPrint eq 'long_url') {
            printResultInWindow('LongUrl : '    . $url_data->{'long_url'}, $window, $send)     if ($url_data->{'long_url'});
        } elsif ($elementToPrint eq 'title') {
            printResultInWindow('Title : '      . $url_data->{'title'}, $window, $send)        if ($url_data->{'title'});
        } elsif ($elementToPrint eq 'backup_url') {
            printResultInWindow('BackupUrl : '  . $url_data->{'backup_url'}, $window, $send)   if ($url_data->{'backup_url'});
        } elsif ($elementToPrint eq 'keywords') {
            printResultInWindow('Keywords : '   . $url_data->{'keywords'}, $window, $send)     if ($url_data->{'keywords'});
        } elsif ($elementToPrint eq 'context') {
            printResultInWindow('Context : ' . $url_data->{'url'} . ' by ' . $url_data->{'last_nick'} . ' on ' . $url_data->{'last_channel'} . ' ( ' . $url_data->{'last_server'} . ' ) [' . $url_data->{'first_source'} . ']', $window, $send);
#TODOTODAY
        }
    }
}

sub printResult
{
    my ($url_data, $nick, $channel, $server) = @_;
    my $server_name = $server->{'real_address'};

    # We might want not to print old data
#TODOTODAY    return unless ($url_data->{'number'} == 1 or getSettingValue('_printIfNotNew'));

    # Print on win 1
    printNeededResults($url_data, 'win1', 0);

    # Print on active win
    printNeededResults($url_data, 'activeWin', 0);

    # Print on special win
    printNeededResults($url_data, 'specialWin', 0);

    # Print on original win
    my $c = $server->channel_find($channel); 
    if ($c)
    {
        printNeededResults($url_data, $c, 0);
        printNeededResults($url_data, $c, 1);
    }
}

sub fetchUrlInfoFromCache
{
    my ($url, $nick, $channel, $server_name) = @_;
    return $url_cache{$url};
} 

sub fetchUrlInfoLongurl
{
    my ($url, $nick, $channel, $server_name) = @_;
    if (length($url)<= $longurlMaxUrlLength) # Long URLs are not handled by longurl.org
    {
        # Request targetting longurl
        my $url_req = $longurlApiUrl . '?' . $longurlOptions . '&url=' . uri_escape_utf8($url);
        my $req = HTTP::Request->new(GET => $url_req);
        $req->content_type('application/x-www-form-urlencoded');
        my $res = $ua->request($req);
        if ($res->is_success)
        {
            my $res_content = $res->content;
            my $parsedResult = ( $longurlFavoriteFormat eq 'json' ) ?
            decode_json($res_content) : $xmlSimple->XMLin($res_content);
            my $long_url=$parsedResult->{'long-url'};
            my $title=$parsedResult->{'title'};
            my $keywords=$parsedResult->{'meta-keywords'};
            return {
                url             => $url,
                long_url        => $long_url,
                backup_url      => undef,
                title           => $title,
                keywords        => $keywords,
            };
        } else { $error .= 'TODO Longurl ; '; }
    } else { $error .= 'Too long to be checked by Longurl ; '; }
    return;
}

sub fetchUrlInfoLongurlplease
{
    my ($url, $nick, $channel, $server_name) = @_;

    # Request targetting longurlplease
    my $url_req = $longurlpleaseApiUrl . '?q=' . uri_escape_utf8($url);
    my $req = HTTP::Request->new(GET => $url_req);
    $req->content_type('application/x-www-form-urlencoded');
    my $res = $ua->request($req);
    if ($res->is_success)
    {
        my $res_content = $res->content;
        my $parsedJson = decode_json($res_content);
        my $long_url=$parsedJson->{$url};
        return {
            url             => $url,
            long_url        => $long_url,
            backup_url      => undef,
            title           => undef,
            keywords        => undef,
        };
    } else { $error .= 'TODO Longurlplease ; '; }
    return;
}

sub fetchUrlInfoExpandurl
{
    my ($url, $nick, $channel, $server_name) = @_;
    # expandurl allows only expandurlMaxRequests per expandurlTimeRange so we track all the requests sent to expandurl

    # Get current timestamp
    my $current_time = time(); my $begin_time = $current_time - $expandurlTimeRange;
    # Remove the old timestamp based on current timestamp
    grep { $_ > $begin_time } @expandurlLastAccesses;
    # Check the list size
    if (@expandurlLastAccesses < $expandurlMaxRequests)
    {
        # Add current timestamp
        push @expandurlLastAccesses, $current_time;

        # Request targetting expandurl
        my $url_req = $expandurlApiUrl . '?url=' . uri_escape_utf8($url) . $expandurlOptions;
        my $req = HTTP::Request->new(GET => $url_req);
        $req->content_type('application/x-www-form-urlencoded');
        my $res = $ua->request($req);
        if ($res->is_success)
        {
            my $res_content = $res->content;
            my $parsedJson = decode_json($res_content);
            my $long_url=$parsedJson->{'url'};
            return {
                url             => $url,
                long_url        => $long_url,
                backup_url      => undef,
                title           => undef,
                keywords        => undef,
            };
        } else { $error .= 'TODO Expandurl ; '; }
    } else { $error .= 'Too many requests sent to Expandurl ; '; }
    return;
}

sub fetchUrlInfoDirect
{
    my ($url, $nick, $channel, $server_name) = @_;
    # Request targetting the URL
    my $url_req = $url;
    my $req = HTTP::Request->new(GET => $url_req);
    $req->content_type('application/x-www-form-urlencoded');
    #return if ((ref($req->uri) eq 'URI::_Generic' or ref($req->uri) eq 'URI::_generic') and (ref($ua) eq 'LWPx::ParanoidAgent')); # prevent crash
    return unless (ref($req->uri) eq 'URI::http' or (ref($ua) ne 'LWPx::ParanoidAgent')); # prevent crash
    my $res = $ua->request($req);
    if ($res->is_success)
    {
        my $title = $res->header('title');
        # It used to get the title with html headparser but it's actually already done in the headers of the response
        # use HTML::HeadParser; my $h = HTML::HeadParser->new; $h->parse($res_content); my $t = $h->header('Title');
        my $keywords = $res->header('x-meta-keywords');
        my $previous = $res->previous;
        my $long_url;
        if ($previous)
        {
            $long_url = $previous->header('location');
        }
        my $backup_url;
        if (getSettingValue('_backupWhenRetrieve'))
        {
            my $ext = $url;
            #$ext =~ s/^.*\(.[a-zA-Z0-9_]*\)$/$1/; # TODO : that part sucks
            if ($url =~ m/((\.tar)?\.[a-z]+)$/)
            {
                $ext=$1;
            }
            #TODO : safe ext
            # http://www.tek-tips.com/viewthread.cfm?qid=1179871&page=1
            $ext = '.html' if ($ext eq $url);
            my $filename = md5_hex('salt' . $url) . $ext;
            my $filepath = getSettingValue('_backupHtmlFolderPath') . $filename;
            my $fileurl  = getSettingValue('_backupHtmlFolderUrl')  . $filename;
            if (open(FILE, '>' . $filepath))
            {
                my $res_content = $res->content;
                print FILE $res_content;
                close(FILE);
                $backup_url=$fileurl;
            } else {
                Irssi::printformat(MSGLEVEL_CLIENTNOTICE, $IRSSI{name} . '_error', 'cannot open file ' . $filepath);
            }
        }
        return {
            url             => $url,
            long_url        => $long_url, 
            backup_url      => $backup_url,
            keywords        => $keywords,
            title           => $title,
        };
    } else { $error .= 'TODO Direct ; '; }
    return;
}

sub fetchUrlInfoPrintDebugStuff
{
    my ($url, $nick, $channel, $server_name) = @_;
#    Irssi::print('url : ' . $url);
#    Irssi::print('strip_codes(url) : ' . Irssi::strip_codes($url));
#    Irssi::print('uri_escape_utf8(url) : ' . uri_escape_utf8($url));
#    Irssi::print('strip_codes(uri_escape_utf8(url)) : ' . Irssi::strip_codes(uri_escape_utf8($url)));
#    Irssi::printformat(MSGLEVEL_CLIENTNOTICE, $IRSSI{name} . '_error', 'cannot get res from URL ( ' . $url . ' ) from ' . $nick . ' ' . $channel . ' : ' . $error);
    # If problem for an https link : http://bredsaal.dk/lwpuseragent-and-https (also, restard your irssi :-/)
}

sub fetchUrlInfo
{
    my ($url, $uri, $nick, $channel, $server_name) = @_;
    $error = '';
    $ua->timeout    (getSettingValue('_timeout'));
    $ua->max_size   (getSettingValue('_maxsize'));
    $ua->agent      (getSettingValue('_useragent'));
    $ua->default_header('Referer' => getSettingValue('_httpReferer'));
    my $storeRedData    = getSettingValue('_storeRedundantData');
    my $storeUselessData= getSettingValue('_storeUselessEntries');
    my @methods = split('-', getSettingValue('_usedMethods'));
    foreach my $method (@methods)
    {
        # Retrieve data using the right method
        my $url_data;
        $method =~ s/^\s*(.*)\s*$/$1/;
        if ($method eq 'cache') {
            $url_data = fetchUrlInfoFromCache($url, $nick, $channel, $server_name); 
#TODOTODAY            return $url_data if $url_data; # we don't need/want data to be changed (except...)
        } elsif ($method eq 'longurl') {
            $url_data = fetchUrlInfoLongurl($url, $nick, $channel, $server_name); 
        } elsif ($method eq 'longurlplease') {
            $url_data = fetchUrlInfoLongurlplease($url, $nick, $channel, $server_name); 
        } elsif ($method eq 'expandurl') {
            $url_data = fetchUrlInfoExpandurl($url, $nick, $channel, $server_name); 
        } elsif ($method eq 'direct') {
            $url_data = fetchUrlInfoDirect($url, $nick, $channel, $server_name); 
        } elsif ($method eq 'printDebugStuff') {
            fetchUrlInfoPrintDebugStuff($url, $nick, $channel, $server_name); 
        }

        # We got something
        if ($url_data)
        {
            # Clean/Dirty it
            my $long_url =      $url_data->{'long_url'};    $long_url = ''   unless ($long_url);
            my $backup_url =    $url_data->{'backup_url'};  $backup_url = '' unless ($backup_url);
            my $title =         $url_data->{'title'};       $title = ''      unless ($title);
            $title =~ s/\R//g;
            my $keywords =      $url_data->{'keywords'};    $keywords = ''   unless ($keywords);
            
            if ($storeRedData)
            {
                # Add redundant information
                $long_url   = $url      unless ($long_url);
                $backup_url = $long_url unless ($backup_url);
                $title      = $long_url unless ($title);
                $keywords   = $title    unless ($keywords);
            } else {
                # Remove redundant information
                $long_url = undef if ($long_url eq '' or $long_url eq $url); 
                $backup_url = undef if ($backup_url eq '' or $backup_url eq $url); 
                $title = undef if ($title eq '' or $title eq $url); 
                $keywords = undef if ($keywords eq '' or $keywords eq $url);  

                # Do we still want it at all ?
                if ($storeUselessData
                        or defined($long_url)
                        or defined($backup_url)
                        or defined($title)
                        or defined($keywords))
                {
                } else {
                    $error .= $method . ' did not bring anything interesting; ';
                    next;
                }
            }

            # Update it
            # #TODO remove first*, last*, add list of accesses (time, chan, name, source)
#TODOTODAY
            $url_data->{'long_url'}      = $long_url;
            $url_data->{'backup_url'}    = $backup_url;
            $url_data->{'title'}         = $title;
#https://www.socialtext.net/perl5/index.cgi?array_vs_list
            my @history = ();

#            my $new_history_item = (
#                uri => $uri,
#                time => time(),
#                nick => $nick,
#                channel => $channel,
#                server => $server_name,
#                source => $method
#            );
#            $url_data->{'history'} = $new_history_item;
            
#
#            print('---');
#            print(Dumper(@history));
#            print('---');
#            print(Dumper(%new_history_item));
#            print('---');
#            push(@history, %new_history_item);
#            print('---');
#            print(Dumper(@history));
#            print('---');
#            $url_data->{'history'} = (
#                uri => $uri,
#                time => time(),
#                nick => $nick,
#                channel => $channel,
#                server => $server_name,
#                source => $method
#            );
#            
#            $url_data->{'first_uri'}     = $orig_uri;
#            $url_data->{'first_update'}  = time();
#            $url_data->{'first_nick'}    = $nick;
#            $url_data->{'first_channel'} = $channel;
#            $url_data->{'first_server'}  = $server_name;
#            $url_data->{'first_source'}  = $method;
#            $url_data->{'number'}        = 0;
            $url_data->{'error'}         = $error;

            # Return it
            return $url_data;
        }
    }
}

sub getStringToBePrinted # TODO : Irssi::escape/parsespecialvariable je sais pas trop quoi mes couilles
{
# Useless now
#    my ($url_data) = @_; return "" unless $url_data;
    #
#    my @formats = split('-', Irssi::settings_get_str($IRSSI{name} . '_stringFormats'));
#    FORMAT: foreach my $format (@formats)
#    {
#        $format =~ s/^\s*(.*)\s*$/$1/;
#        # Next variable is used because substitution could bring new 'datatypes'.
#        # For that reason, we don't want to change $format. It still not perfect but...
#        my $result = $format;
#        foreach my $datatype (@data_cache)
#        {
#            if ($format =~ m/!$datatype!/)
#            {
#                my $data = $url_data->{$datatype};
#                next FORMAT unless $data;
#                $result =~ s/!$datatype!/$data/;
#            }
#        }
#        return $result;
#    }
    return "";
}

sub processUrl
{
    my ($url, $uri, $nick, $channel, $server) = @_;
    my $server_name = $server->{'real_address'};

    # Handle blacklists
    return if isInBlacklist($url, $nick, $channel, $server_name);

    # Get data
    my $url_data = fetchUrlInfo($url, $uri, $nick, $channel, $server_name);

    # Return if no data retrieved
    return unless ($url_data);

    # Update data
#TODOTODAY
#    $url_data->{'last_uri'} = $orig_uri;
#    $url_data->{'last_nick'} = $nick;
#    $url_data->{'last_channel'} = $channel;
#    $url_data->{'last_server'} = $server_name;
#    $url_data->{'last_read'} = time();
#    $url_data->{'number'} = $url_data->{'number'} + 1;

    # Print data
    printResult($url_data, $nick, $channel, $server);

    # Insert in cache
    $url_cache{$url} = $url_data;

    # Return string
    return getStringToBePrinted($url_data);
}

sub processText
{
    my ($data, $nick, $channel, $server) = @_;
    return $data if ($running); $running = 1;
    # A finder with a function to process each URL
    #my $finder = URI::Find::Schemeless->new( sub {
    my $finder = URI::Find->new( sub {
            my($uri, $orig_uri) = @_;
            my $uri_abs = $uri->abs;
            my $url_string = processUrl("$uri_abs", $orig_uri, $nick, $channel, $server);
            return ($url_string?$url_string:$orig_uri);
        });
    # and process the text through that finder
    $finder->find(\$data);
    $running = 0;
    return $data;
}

sub del_public
{
    my ($server, $data, $nick, $mask, $target) = @_;
    Irssi::signal_continue($server, $data, $nick, $mask, $target);
    $data = processText($data, $nick, $target, $server);
}
sub del_private
{
    my ($server, $data, $nick, $address) = @_;
    Irssi::signal_continue($server, $data, $nick, $address);
    $data = processText($data, $nick, $server->{'nick'}, $server);
}
sub del_own
{
    my ($server, $data, $target) = @_;
    Irssi::signal_continue($server, $data, $target);
    $data=processText($data, $server->{'nick'}, $target, $server);
    #Irssi::printformat(MSGLEVEL_CLIENTCRAP, $IRSSI{name} . '_result', $data2) if ($data2 ne $data);
    # we don't change the signal sent
}
sub del_topic
{
    my ($server, $target, $data, $nick, $mask) = @_;
    Irssi::signal_continue($server, $target, $data, $nick, $mask);
    $data = processText($data, $nick, $target, $server);
}

# ========= Irssi signal handling ===========
Irssi::signal_add_last('message public', 'del_public');
Irssi::signal_add_last('message private', 'del_private');
Irssi::signal_add_last('message own_public', 'del_own');
Irssi::signal_add_last('message topic', 'del_topic');

Irssi::command_bind($IRSSI{name} . '_viewCache', 'viewCache'); # why does this shit doesnt work >_<
Irssi::command_bind('tututu', 'viewCache');                             # For debug mainly
Irssi::command_bind($IRSSI{name} . '_resetSettings', 'resetSettings');  # For debug mainly
Irssi::command_bind('sdhelp', 'help');

# ========= Success ! \o/ ===========
Irssi::printformat(MSGLEVEL_CLIENTCRAP, $IRSSI{name} . '_loaded', $VERSION);

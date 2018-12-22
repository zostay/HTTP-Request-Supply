#!smackup
use v6;

use Test;
use HTTP::Supply::Request;

use lib 't/lib';
use HTTP::Supply::Request::Test;

my @tests =
    {
        source   => 'http-1.0-trailing-garbage.txt',
        quits    => %(:on(X::HTTP::Supply::BadMessage)),
        expected => ({
            REQUEST_METHOD     => 'POST',
            REQUEST_URI        => '/index.html',
            SERVER_PROTOCOL    => 'HTTP/1.0',
            CONTENT_TYPE       => 'application/x-www-form-urlencoded; charset=utf8',
            CONTENT_LENGTH     => '11',
            HTTP_AUTHORIZATION => 'Basic QWxhZGRpbjpvcGVuIHNlc2FtZQ==',
            HTTP_REFERER       => 'http://example.com/awesome.html',
            HTTP_USER_AGENT    => 'Mozilla/Inf',
            'p6w.input'        => 'a=1&b=2&c=3',
        },),
    },
    {
        source   => 'http-1.1-trailing-garbage.txt',
        quits    => %(:on(X::HTTP::Supply::BadMessage)),
        expected => ({
            REQUEST_METHOD     => 'POST',
            REQUEST_URI        => '/index.html',
            SERVER_PROTOCOL    => 'HTTP/1.1',
            CONTENT_TYPE       => 'application/x-www-form-urlencoded; charset=utf8',
            CONTENT_LENGTH     => '11',
            HTTP_AUTHORIZATION => 'Basic QWxhZGRpbjpvcGVuIHNlc2FtZQ==',
            HTTP_REFERER       => 'http://example.com/awesome.html',
            HTTP_CONNECTION    => 'close',
            HTTP_USER_AGENT    => 'Mozilla/Inf',
            'p6w.input'        => 'a=1&b=2&c=3',
        },),
    },
    ;

my $tester = HTTP::Supply::Request::Test.new(:@tests);
$tester.run-tests;

done-testing;

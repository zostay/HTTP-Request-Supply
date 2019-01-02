#!smackup
use v6;

use Test;
use HTTP::Supply::Request;

use lib 't/lib';
use HTTP::Supply::Request::Test;

my @tests =
    {
        source   => 'http-1.1-close.txt',
        expected => ({
            REQUEST_METHOD     => 'POST',
            REQUEST_URI        => '/index.html',
            SERVER_PROTOCOL    => 'HTTP/1.1',
            CONTENT_TYPE       => 'application/x-www-form-urlencoded; charset=utf8',
            CONTENT_LENGTH     => '13',
            HTTP_AUTHORIZATION => 'Basic QWxhZGRpbjpvcGVuIHNlc2FtZQ==',
            HTTP_REFERER       => 'http://example.com/awesome.html',
            HTTP_CONNECTION    => 'close',
            HTTP_USER_AGENT    => 'Mozilla/Inf',
            'p6w.input'        => "a=1&b=2&c=3\r\n",
        },),
    },
    {
        source   => 'http-1.1-short.txt',
        quits    => %(:body(X::HTTP::Supply::BadMessage)),
        expected => ({
            REQUEST_METHOD     => 'POST',
            REQUEST_URI        => '/index.html',
            SERVER_PROTOCOL    => 'HTTP/1.1',
            CONTENT_TYPE       => 'application/x-www-form-urlencoded; charset=utf8',
            CONTENT_LENGTH     => '13',
            HTTP_AUTHORIZATION => 'Basic QWxhZGRpbjpvcGVuIHNlc2FtZQ==',
            HTTP_REFERER       => 'http://example.com/awesome.html',
            HTTP_CONNECTION    => 'close',
            HTTP_USER_AGENT    => 'Mozilla/Inf',
            'p6w.input'        => "a=1&b=2&c=\r\n",
        },),
    },
    {
        source   => 'http-1.1-pipeline.txt',
        expected => ({
            REQUEST_METHOD     => 'POST',
            REQUEST_URI        => 'http://example.com/index.html',
            SERVER_PROTOCOL    => 'HTTP/1.1',
            HTTP_HOST          => 'example.com',
            CONTENT_TYPE       => 'application/x-www-form-urlencoded; charset=utf8',
            CONTENT_LENGTH     => '15',
            HTTP_AUTHORIZATION => 'Basic QWxhZGRpbjpvcGVuIHNlc2FtZQ==',
            HTTP_REFERER       => 'http://example.com/awesome.html',
            HTTP_USER_AGENT    => 'Mozilla/Inf',
            'p6w.input'        => "a=1&b=2&c=3\r\n\r\n",
       }, {
           REQUEST_METHOD     => 'GET',
           REQUEST_URI        => 'http://example.com/image.png',
           SERVER_PROTOCOL    => 'HTTP/1.1',
           HTTP_HOST          => 'example.com',
           CONTENT_LENGTH     => '0',
           HTTP_ACCEPT        => 'image/png',
           HTTP_TE            => 'chunked',
           HTTP_REFERER       => 'http://example.com/index.html',
           HTTP_USER_AGENT    => 'Mozilla/Inf',
           'p6w.input'        => '',
       }, {
           REQUEST_METHOD     => 'POST',
           REQUEST_URI        => 'http://example.com/form.html',
           SERVER_PROTOCOL    => 'HTTP/1.1',
           HTTP_HOST          => 'example.com',
           CONTENT_TYPE       => 'application/json',
           HTTP_TRANSFER_ENCODING => 'chunked',
           HTTP_USER_AGENT    => 'Mozilla/Inf',
           HTTP_REFERER       => 'http://example.com/index.html',
           HTTP_TRAILER       => 'Magic',
           'p6w.input'        => '{}{"a":1,"b":2,"c",3}',
           'test.trailers'    => [
               'magic' => 'on',
            ],
       }, {
           REQUEST_METHOD     => 'GET',
           REQUEST_URI        => 'http://example.com/main.css',
           SERVER_PROTOCOL    => 'HTTP/1.1',
           HTTP_HOST          => 'example.com',
           CONTENT_LENGTH     => '0',
           HTTP_ACCEPT        => 'text/css',
           HTTP_USER_AGENT    => 'Mozilla/Inf',
           HTTP_REFERER       => 'http://example.com/index.html',
           'p6w.input'        => '',
        }),
    },
    ;

my $tester = HTTP::Supply::Request::Test.new(:@tests);
$tester.run-tests;
$tester.run-tests: :reader<socket>;

done-testing;

#!/usr/bin/perl

# (C) Maxim Dounin

# Tests for try_files directive.

###############################################################################

use warnings;
use strict;

use Test::More;

BEGIN { use FindBin; chdir($FindBin::Bin); }

use lib 'lib';
use Test::Nginx;

###############################################################################

select STDERR; $| = 1;
select STDOUT; $| = 1;

my $t = Test::Nginx->new()->has(qw/http proxy rewrite/)->plan(9)
	->write_file_expand('nginx.conf', <<'EOF');

%%TEST_GLOBALS%%

daemon off;

events {
}

http {
    %%TEST_GLOBALS_HTTP%%

    server {
        listen       127.0.0.1:8080;
        server_name  localhost;

        location / {
            try_files $uri /fallback;
        }

        location /nouri/ {
            try_files $uri /fallback_nouri;
        }

        location /short/ {
            try_files /short $uri =404;
        }

        location /file-file/ {
            try_files /found.html =404;
        }

        location /file-dir/ {
            try_files /found.html/ =404;
        }

        location /dir-dir/ {
            try_files /directory/ =404;
        }

        location /dir-file/ {
            try_files /directory =404;
        }

        location ~ /alias_re.html {
            alias %%TESTDIR%%/directory;
            try_files $uri =404;
        }

        location /fallback {
            proxy_pass http://127.0.0.1:8081/fallback;
        }
        location /fallback_nouri {
            proxy_pass http://127.0.0.1:8081;
        }
    }

    server {
        listen       127.0.0.1:8081;
        server_name  localhost;

        location / {
            add_header X-URI $request_uri;
            return 204;
        }
    }
}

EOF

mkdir($t->testdir() . '/directory');
$t->write_file('directory/alias_re.html', 'SEE THIS');
$t->write_file('found.html', 'SEE THIS');
$t->run();

###############################################################################

like(http_get('/found.html'), qr!SEE THIS!, 'found');
like(http_get('/uri/notfound'), qr!X-URI: /fallback!, 'not found uri');
like(http_get('/nouri/notfound'), qr!X-URI: /fallback!, 'not found nouri');
like(http_get('/short/long'), qr!404 Not!, 'short uri in try_files');

like(http_get('/file-file/'), qr!SEE THIS!, 'file matches file');
like(http_get('/file-dir/'), qr!404 Not!, 'file does not match dir');
like(http_get('/dir-dir/'), qr!301 Moved Permanently!, 'dir matches dir');
like(http_get('/dir-file/'), qr!404 Not!, 'dir does not match file');

SKIP: {
skip 'leaves coredump', 1 unless $t->has_version('1.9.4')
	or $ENV{TEST_NGINX_UNSAFE};

like(http_get('/alias_re.html'), qr!SEE THIS!, 'alias in regex location');

}

###############################################################################

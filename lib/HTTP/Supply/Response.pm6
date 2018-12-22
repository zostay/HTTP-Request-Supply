use v6;

unit class HTTP::Supply::Response:ver<0.2.0>:auth<github:zostay>;

use HTTP::Supply::Body;
use HTTP::Supply::Tools;

method !make-header(@header) {
    my %header;
    for @header {
        if %header{ .key } :exists {
            %header{ .key } ~= ',' ~ .value;
        }
        else {
            %header{ .key } = .value;
        }
    }
    %header;
}

multi method parse-http(Supply:D() $conn, Bool :$debug = False --> Supply:D) {
    sub debug(*@msg) {
        note "# [{now.Rat.fmt("%.5f")}] (#$*THREAD.id()) ", |@msg if $debug
    }

    supply {
        my enum <StatusLine Header Body Close>;
        my $expect;
        my @res;
        my buf8 $acc;
        my Supplier $body-sink;
        my Promise $left-over;

        my sub new-response() {
            $expect = StatusLine;
            $acc = buf8.new;
            $acc ~= .result with $left-over;
            $left-over = Nil;
            $body-sink = Nil;
            @res := [ Nil, [], Nil ];
        }

        new-response();

        whenever $conn -> $chunk {
            # When expected a header add the chunk to the accumulation buffer.
            debug("RECV ", $chunk.perl);
            $acc ~= $chunk if $expect != Body;

            # Otherwise, the chunk will be handled directly below.
            CHUNK_PROCESS: loop {
                given $expect {

                    # Ready to receive the status line
                    when StatusLine {
                        # Decode the response line
                        my $line = crlf-line($acc);

                        # We don't have a complete line yet
                        last CHUNK_PROCESS without $line;
                        debug("STATLINE [$line]");

                        # Break the line up into parts
                        my ($http-version, $status-code, $status-message) = $line.split(' ', 3);

                        # TODO Throw exception on unexpected HTTP version?

                        # TODO Throw exception on non-numeric status-code?

                        # Save the status line
                        @res[0] = $status-code.Int;
                        @res[1].push: 'x-server-protocol' => $http-version;
                        @res[1].push: 'x-server-status-message' => $status-message;

                        $expect = Header;
                    }

                    # Ready to receive a header line
                    when Header {
                        # Decode the next line from the header
                        my $line = crlf-line($acc);

                        # We don't have a complete line yet
                        last CHUNK_PROCESS without $line;

                        # Empty line signals the end of the header
                        my %header := self!make-header(@res[1]);
                        if $line eq '' {
                            debug("HEADER END");

                            # Setup the body decoder itself
                            debug("STATUS", @res[0]);
                            debug("HEAD ", @res[1].perl);
                            my $body-decoder-class = do
                                if %header<transfer-encoding>.defined
                                && %header<transfer-encoding> eq 'chunked' {
                                    HTTP::Supply::Body::ChunkedEncoding
                                }
                                elsif %header<content-length>.defined {
                                    HTTP::Supply::Body::ContentLength
                                }
                                else {
                                    Nil
                                }

                            debug("DECODER CLASS ", $body-decoder-class.^name);

                            # Setup the stream we will send to the P6WAPI response
                            my $body-stream = Supplier::Preserving.new;
                            @res[2] = $body-stream.Supply;

                            # If we expect a body to decode, setup the decoder
                            if $body-decoder-class ~~ HTTP::Supply::Body {
                                debug("DECODE BODY");

                                # Setup the stream we will send to the body decoderk
                                $body-sink = Supplier::Preserving.new;

                                # Setup the promise the body decoder can use to
                                # drop the left-overs
                                $left-over = Promise.new;

                                # Construst the decoder and tap the body-sink
                                my $body-decoder = $body-decoder-class.new(
                                    :$body-stream, :$left-over, :%header,
                                );
                                $body-decoder.decode($body-sink.Supply);

                                # Get the existing chunks and put them into the
                                # body sink
                                $body-sink.emit: $acc;

                                # Emit the resposne, its processing can begin
                                # while we continue to receive the body.
                                debug("EMIT ", @res.perl);
                                emit @res;

                                # Is the body decoder done already?

                                # The request finished and the pipeline is ready
                                # with another response, so begin again.
                                if $left-over.status == Kept {
                                    new-response();
                                    next CHUNK_PROCESS;
                                }

                                # The response is still going. We need more
                                # chunks.
                                else {
                                    $expect = Body;
                                    last CHUNK_PROCESS;
                                }
                            }

                            # No body expected. Emit and move on.
                            else {
                                # Emit the completed response
                                $body-stream.done;
                                emit @res;

                                # Setup to read the next response.
                                new-response();
                            }
                        }

                        # Lines starting with whitespace are folded. Append the
                        # value to the previous header.
                        elsif $line.starts-with(' ') {
                            debug("CONT HEADER ", $line);

                            # TODO Exception here?

                            @res[1][*-1].value ~= $line.trim-leading;
                        }

                        # We have received a new header. Save it.
                        else {
                            debug("START HEADER ", $line);

                            # Break the header line by the :
                            my ($name, $value) = $line.split(": ");

                            # Setup the name for going into the response
                            $name .= fc;

                            # Save the value into the response
                            @res[1].push: $name => $value;
                        }
                    }

                    # Continue to decode the body.
                    when Body {

                        # Send the chunk to the body decoder to continue
                        # decoding.
                        $body-sink.emit: $chunk;

                        # The response finished and the pipeline is ready with
                        # another response, so begin again.
                        if $left-over.status == Kept {
                            new-response();
                            next CHUNK_PROCESS;
                        }

                        # The response is still going. We need more chunks.
                        else {
                            last CHUNK_PROCESS;
                        }
                    }
                }
            }
        }
    }
}
